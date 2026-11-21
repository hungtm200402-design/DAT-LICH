param(
    [string]$Repository = 'hungtm200401-bot/DAT-LICH'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
if ($Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'Invalid GitHub repository name.' }
$ghCommand = Get-Command gh -ErrorAction SilentlyContinue
$ghExecutable = if ($ghCommand) { $ghCommand.Source } else { Join-Path $projectRoot '.wrangler\tools\github-cli\unpacked\bin\gh.exe' }
if (-not (Test-Path -LiteralPath $ghExecutable)) { throw 'GitHub CLI is required. Install gh, then run gh auth login --scopes workflow.' }

function Invoke-GhJson([string[]]$Arguments) {
    $result = & $ghExecutable @Arguments
    if ($LASTEXITCODE -ne 0) { throw 'GitHub request failed. Check gh auth status and repository access.' }
    return (($result -join "`n") | ConvertFrom-Json)
}
function Invoke-SourceGit([string[]]$Arguments) {
    $result = & git @Arguments
    if ($LASTEXITCODE -ne 0) { throw ('Git command failed: ' + $Arguments[0]) }
    return ($result -join "`n").Trim()
}

$account = Invoke-GhJson -Arguments @('api', 'user')
$repositoryInfo = Invoke-GhJson -Arguments @('api', "repos/$Repository")
if (-not $repositoryInfo.permissions.push) { throw ('No write access to ' + $Repository) }
Write-Output ('Authenticated: ' + $account.login)

# Temporary index keeps the owner's staged files and current branch untouched.
$sourceParent = Invoke-SourceGit -Arguments @('rev-parse', 'HEAD')
$selectedPaths = @(
    '.gitignore', '.github/workflows/build-admin-ipa.yml',
    'mobile', 'scripts/build-admin-ipa.ps1', 'tests/admin-ipa.test.mjs',
    'public/assets/hoan-app-icon-v1.png', 'ipa/README.md',
    'specs/009-admin-ipa', 'docs/BUILD_IPA_APK.md'
)
$stateDirectory = Join-Path $projectRoot '.wrangler'
New-Item -ItemType Directory -Force -Path $stateDirectory | Out-Null
$temporaryIndex = Join-Path $stateDirectory ('ipa-build-' + [guid]::NewGuid().ToString('N') + '.index')
$previousIndex = [Environment]::GetEnvironmentVariable('GIT_INDEX_FILE', 'Process')
try {
    [Environment]::SetEnvironmentVariable('GIT_INDEX_FILE', $temporaryIndex, 'Process')
    Invoke-SourceGit -Arguments @('read-tree', $sourceParent) | Out-Null
    Invoke-SourceGit -Arguments (@('-c', 'core.autocrlf=false', 'add', '--') + $selectedPaths) | Out-Null
    $tree = Invoke-SourceGit -Arguments @('write-tree')
    $commit = Invoke-SourceGit -Arguments @('-c', 'user.name=HOAN Build', '-c', 'user.email=hoan-build@users.noreply.github.com', 'commit-tree', $tree, '-p', $sourceParent, '-m', 'build: package HOAN Admin for iPhone')
} finally {
    [Environment]::SetEnvironmentVariable('GIT_INDEX_FILE', $previousIndex, 'Process')
    if (Test-Path -LiteralPath $temporaryIndex) { Remove-Item -LiteralPath $temporaryIndex }
}
$branch = 'build/hoan-admin-ipa-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' + $commit.Substring(0, 7)
$helper = 'credential.helper=!"' + $ghExecutable.Replace('\', '/') + '" auth git-credential'
Invoke-SourceGit -Arguments @('-c', 'credential.helper=', '-c', $helper, 'push', "https://github.com/$Repository.git", ($commit + ':refs/heads/' + $branch)) | Out-Null
Write-Output ('Build source: ' + $commit)
Write-Output ('Build branch: ' + $branch)

$run = $null
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    $response = Invoke-GhJson -Arguments @('api', "repos/$Repository/actions/runs?branch=$branch&event=push&per_page=10")
    $matches = @($response.workflow_runs | Where-Object { $_.head_sha -eq $commit -and $_.path -eq '.github/workflows/build-admin-ipa.yml' })
    if ($matches.Count -gt 0) { $run = $matches[0]; break }
    Start-Sleep -Seconds 3
}
if (-not $run) { throw 'GitHub Actions run was not found. Check repository Actions settings.' }
Write-Output ('Run URL: ' + $run.html_url)
$previousStatus = ''
$deadline = [DateTime]::UtcNow.AddMinutes(30)
while ([DateTime]::UtcNow -lt $deadline) {
    $run = Invoke-GhJson -Arguments @('api', "repos/$Repository/actions/runs/$($run.id)")
    if ($run.status -ne $previousStatus) {
        Write-Output ('Build status: ' + $run.status)
        $previousStatus = $run.status
    }
    if ($run.status -eq 'completed') { break }
    Start-Sleep -Seconds 10
}
if ($run.status -ne 'completed') { throw ('Build still running: ' + $run.html_url) }
if ($run.conclusion -ne 'success') {
    $failedLogPath = Join-Path $stateDirectory ('ipa-build-' + $run.id + '-failed.log')
    & $ghExecutable run view $run.id --repo $Repository --log-failed | Out-File -FilePath $failedLogPath -Encoding utf8
    Get-Content -LiteralPath $failedLogPath | Select-String -Pattern 'error:|Error:|Traceback|ValueError|BUILD FAILED|Process completed' -Context 0,2 | Select-Object -Last 12 | ForEach-Object { Write-Output $_.ToString() }
    Write-Output ('Full failed log: ' + $failedLogPath)
    throw ('IPA build failed: ' + $run.html_url)
}

$downloadDirectory = Join-Path $stateDirectory ('ipa-download-' + $run.id)
New-Item -ItemType Directory -Force -Path $downloadDirectory | Out-Null
& $ghExecutable run download $run.id --repo $Repository --name ('HOAN-Admin-iOS-' + $run.id) --dir $downloadDirectory
if ($LASTEXITCODE -ne 0) { throw 'IPA artifact download failed.' }
$ipaFiles = @(Get-ChildItem -LiteralPath $downloadDirectory -Filter '*.ipa' -File -Recurse)
if ($ipaFiles.Count -ne 1) { throw 'Expected exactly one IPA in the artifact.' }
$builtIpa = $ipaFiles[0]
$checksumPath = $builtIpa.FullName + '.sha256'
$expectedHash = ((Get-Content -LiteralPath $checksumPath -Raw).Trim() -split '\s+')[0]
$actualHash = (Get-FileHash -LiteralPath $builtIpa.FullName -Algorithm SHA256).Hash
if ($expectedHash -notmatch '^[a-fA-F0-9]{64}$' -or $expectedHash -ne $actualHash) { throw 'Downloaded IPA checksum mismatch.' }

$targetDirectory = Join-Path $projectRoot 'ipa'
foreach ($artifactFile in (Get-ChildItem -LiteralPath $builtIpa.DirectoryName -File)) {
    if ($artifactFile.Name -notmatch '^HOAN-Admin-[0-9.]+-[0-9]+-unsigned\.(ipa|ipa\.sha256|json)$') { continue }
    $target = Join-Path $targetDirectory $artifactFile.Name
    if (Test-Path -LiteralPath $target) {
        if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $artifactFile.FullName -Algorithm SHA256).Hash) {
            throw ('A different artifact already exists: ' + $target)
        }
    } else {
        Copy-Item -LiteralPath $artifactFile.FullName -Destination $target
    }
}
$evidence = @{run_url=$run.html_url; source_commit=$commit; branch=$branch; conclusion=$run.conclusion; file=$builtIpa.Name; sha256=$actualHash.ToLowerInvariant(); signing='unsigned-requires-sideload-signing'}
$evidencePath = Join-Path $targetDirectory ('build-run-' + $run.id + '.json')
[IO.File]::WriteAllText($evidencePath, ($evidence | ConvertTo-Json) + "`n", [Text.UTF8Encoding]::new($false))
Write-Output ('IPA downloaded: ' + (Join-Path $targetDirectory $builtIpa.Name))
Write-Output ('SHA-256: ' + $actualHash.ToLowerInvariant())
