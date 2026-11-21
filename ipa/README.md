# App quản lý HOÀN cho iPhone — IPA

Đặt các file `.ipa` của HOÀN vào thư mục này, ví dụ:

```text
ipa/
  README.md
  HOAN-Admin-1.0.0-1-unsigned.ipa
  HOAN-Admin-1.0.0-1-unsigned.ipa.sha256
  HOAN-Admin-1.0.0-1-unsigned.json
```

Tên trên là ví dụ của output theo phiên bản/build. Script
`scripts/build-admin-ipa.ps1` chạy GitHub Actions và tải IPA, checksum cùng
metadata về thư mục này. Xem kết quả thực tế trong
[báo cáo kiểm chứng](../specs/009-admin-ipa/verification.md).

IPA chưa ký phân phối cần được ký lại bằng phương thức cài đặt phù hợp, chẳng hạn
AltStore/SideStore. Chứng chỉ và khóa ký được giữ riêng với gói cài đặt.

Xem [hướng dẫn build và cài IPA/APK](../docs/BUILD_IPA_APK.md).
