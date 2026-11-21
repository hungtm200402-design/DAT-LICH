# HOÀN Admin — ứng dụng quản lý iPhone

App iOS mở thẳng `/?mobile=1&native=ios#/admin` trên dịch vụ HOÀN đã cấu hình,
tái sử dụng giao diện trong `public/mobile-admin.js`: tổng quan, lịch hẹn, tiền
cọc, lịch làm việc và khách hàng. Source native dùng UIKit/WKWebView, iOS 15+.

## Cấu hình

Sửa các giá trị public trong [`ios/build-config.json`](ios/build-config.json),
hoặc truyền `HOAN_ADMIN_URL`, `HOAN_APP_VERSION`, `HOAN_BUILD_NUMBER` khi build.
URL phải là HTTPS, không chứa thông tin đăng nhập. App giữ phiên bằng cookie
của dịch vụ online; khóa local trong `.dev.vars` không được đóng vào app.

Icon được biên dịch từ [`../public/assets/hoan-app-icon-v1.png`](../public/assets/hoan-app-icon-v1.png).

## Build từ Windows

Cần GitHub CLI đã đăng nhập bằng tài khoản có quyền ghi repository dùng để chạy
CI. Dùng `gh auth login --hostname github.com --git-protocol https --web --scopes workflow`.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-admin-ipa.ps1 -Repository hungtm200402-design/DAT-LICH
```

Chạy từ gốc dự án. Script tạo commit build bằng index tạm, push lên nhánh
`build/hoan-admin-ipa-...`, theo dõi Actions, xác minh checksum rồi tải file về
`ipa/`. Index đang stage và nhánh local hiện tại được giữ nguyên. Repository
trên là fork có quyền ghi của tài khoản đã xác nhận trong phiên làm việc này.

## Build trực tiếp trên macOS

Cài Xcode và XcodeGen, rồi chạy từ gốc repo:

```bash
bash mobile/scripts/build-ipa.sh
```

Script sinh asset catalog và Info.plist trong `ios/.generated/`, tạo project
Xcode từ `ios/project.yml`, build mới cho iPhone ARM64 và chỉ xuất IPA khi bundle
và archive hợp lệ. IPA chưa ký phân phối; cần ký lại bằng công cụ sideload.

## Kiểm tra

```bash
python3 -m unittest discover -s mobile/tests -v
python3 mobile/scripts/prepare-ios.py --check
python3 mobile/scripts/verify-ipa.py ipa/TEN_FILE.ipa
```

Trên Windows dùng Python 3 thực tế thay `python3`, hoặc đặt biến `PYTHON` rồi
chạy `node --test tests/admin-ipa.test.mjs tests/security.test.mjs`.

Compile thành công không thay cho kiểm tra đăng nhập trên thiết bị: dịch vụ
online phải có bản API tương thích và khóa quản trị riêng của môi trường online.

Xem [hướng dẫn IPA/APK](../docs/BUILD_IPA_APK.md) và
[báo cáo kiểm chứng](../specs/009-admin-ipa/verification.md).
