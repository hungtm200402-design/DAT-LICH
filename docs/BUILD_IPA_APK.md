# Build app quản lý HOÀN: IPA / APK

Cập nhật 21/11/2026. Mục tiêu là ứng dụng quản lý: tổng quan, lịch hẹn, tiền cọc,
lịch làm việc và khách hàng. File iPhone lưu tại [`ipa/`](../ipa/README.md),
file Android lưu tại [`apk/`](../apk/README.md).

## Source và trạng thái

Repo đã có source app iOS trong [`mobile/ios/`](../mobile/ios/project.yml),
script build và workflow [`build-admin-ipa.yml`](../.github/workflows/build-admin-ipa.yml).
App dùng UIKit/WKWebView mở thẳng màn quản trị mobile hiện có trên dịch vụ HTTPS.
API, D1, phân quyền và phiên đăng nhập tiếp tục được xử lý tại dịch vụ online.

Kết quả compile và kiểm tra thiết bị được ghi riêng tại
[`specs/009-admin-ipa/verification.md`](../specs/009-admin-ipa/verification.md).
Source Android và workflow APK chưa được triển khai; phần Android bên dưới là
quy trình lưu lại cho bước tiếp theo.

## IPA: build từ Windows qua GitHub Actions

### 1. Cấu hình app quản lý

Sửa [`mobile/ios/build-config.json`](../mobile/ios/build-config.json):

- `admin_url`: URL HTTPS của dịch vụ HOÀN thực tế. Script tự thêm
  `?mobile=1&native=ios#/admin` để mở đúng giao diện quản lý.
- `bundle_id`: `vn.hoanmakeup.admin`.
- `version`: phiên bản hiển thị, mặc định `1.0.0`.
- `build_number`: số build dương; CI dùng số lần chạy workflow.

Có thể ghi đè URL bằng repository variable `HOAN_ADMIN_URL` hoặc input khi chạy
workflow thủ công. URL là cấu hình public, không chứa mật khẩu. `.dev.vars` và
database local không đi vào app. Khóa quản trị khi đăng nhập phải thuộc môi
trường online mà app đang kết nối.

Icon nguồn là [`hoan-app-icon-v1.png`](../public/assets/hoan-app-icon-v1.png).
Quá trình build tạo đủ kích thước iPhone/iPad và icon 1024 px bằng `sips`.

### 2. Đăng nhập GitHub và chạy

Dùng GitHub CLI với tài khoản có quyền ghi repo chạy build:

```powershell
gh auth login --hostname github.com --git-protocol https --web --scopes workflow
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-admin-ipa.ps1 -Repository hungtm200402-design/DAT-LICH
```

Tài khoản đã xác nhận trong phiên này có quyền đọc repo gốc
`hungtm200401-bot/DAT-LICH`; fork `hungtm200402-design/DAT-LICH` được dùng để có
quyền tạo nhánh và chạy Actions. Khi đổi tài khoản/repo, truyền `-Repository`
tương ứng.

Script Windows dùng index Git tạm để tạo một commit chỉ gồm phần build liên
quan, push lên nhánh riêng `build/hoan-admin-ipa-...`, theo dõi CI và tải artifact
về `ipa/`. Không đổi nhánh hiện tại hoặc index đang stage của chủ dự án.

Workflow dùng runner `macos-latest`: cài XcodeGen, chạy test build contract, sinh
asset/project, build Release cho iPhone ARM64 rồi kiểm tra bundle. Gói chỉ được
upload sau khi xác minh cấu trúc IPA, Mach-O cho thiết bị iOS, icon và metadata.
Xem [runner GitHub](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job)
và [Artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts).

### 3. File kết quả

```text
ipa/HOAN-Admin-<version>-<build>-unsigned.ipa
ipa/HOAN-Admin-<version>-<build>-unsigned.ipa.sha256
ipa/HOAN-Admin-<version>-<build>-unsigned.json
ipa/build-run-<run-id>.json
```

Chỉ upload đúng các file của lần build vừa thành công. Script tải về kiểm tra
SHA-256 và không ghi đè một artifact khác cùng tên. Có thể tải thủ công từ
**GitHub → Actions → lần chạy thành công → Artifacts** rồi giải nén vào `ipa/`.

### 4. Ký và cài iPhone

IPA này **chưa ký phân phối**. Dùng AltStore/SideStore để ký lại cho thiết bị
theo hướng dẫn của công cụ. AltStore có
[hướng dẫn Windows](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows).
Việc build không yêu cầu đưa chứng chỉ hay tài khoản Apple lên GitHub.

Ý tưởng đóng gói tham khảo
[`Husk/scripts/package_ipa.sh`](https://github.com/Leviidev/Husk/blob/main/scripts/package_ipa.sh):
build ứng dụng trên macOS/Xcode rồi zip `Payload/*.app` thành IPA để sideload.
HOÀN không dùng các entitlement dành riêng cho trình giả lập của Husk.

### Build trực tiếp trên macOS

Khi đã có Xcode, XcodeGen và Python 3, chạy từ gốc repo:

```bash
bash mobile/scripts/build-ipa.sh
```

Chi tiết và kiểm tra: [`mobile/README.md`](../mobile/README.md).

## APK: hướng triển khai Android tiếp theo

Đưa project Android dùng giao diện quản lý vào repo, khóa phiên bản JDK/SDK và
Gradle tương thích. Nếu dùng Capacitor để đóng gói, chuẩn bị frontend và cấu hình
API/phiên đăng nhập trước khi đồng bộ Android; không chép nguyên output server
của dự án này vào app. Xem [Capacitor Android](https://capacitorjs.com/docs/android).

Sau khi có project Android, chạy tại thư mục chứa Gradle wrapper:

```powershell
.\gradlew.bat assembleDebug
```

Output mặc định: `app/build/outputs/apk/debug/app-debug.apk`. Chép vào `apk/`,
đặt tên theo phiên bản. Bản debug được công cụ Android ký để cài thử. Bản release
dùng `assembleRelease` cùng keystore phát hành; bản cập nhật cần cùng khóa ký.
GitHub Actions có thể dùng runner Linux, JDK/SDK thích hợp, chạy
`./gradlew assembleDebug` rồi upload artifact. Xem
[build Android bằng dòng lệnh](https://developer.android.com/build/building-cmdline).

## Lưu và kiểm chứng

Commit source native, cấu hình, workflow, script, icon và tài liệu để tái tạo
build. Chứng chỉ, private key, mật khẩu và Android keystore được giữ trong kho
secrets phù hợp. Dữ liệu D1 có quy trình sao lưu riêng.

Một lần compile thành công phải có run URL, source commit, artifact và checksum.
Cài thử trên iPhone thật, đăng nhập, xem các màn quản lý và đăng xuất là bước
kiểm chứng riêng; kết quả test fixture không thay cho build hay kiểm tra thiết bị.
