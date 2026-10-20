# Godot Hub (bản tự chế)

Project Godot 4.x đơn giản, giúp quản lý song song nhiều phiên bản Godot
(Standard và Mono/.NET), mô phỏng ý tưởng Unity Hub nhưng tối giản hơn.

## Cách chạy

1. Mở Godot Editor (khuyến nghị bản 4.2 trở lên).
2. Chọn **Import**, trỏ tới thư mục `godot-hub` này (chọn file `project.godot`).
3. Mở project rồi nhấn F5 (hoặc nút Run ở góc trên).

## Cách dùng

### Tab "Phiên bản"
- **Thêm phiên bản...**: chọn thẳng vào file thực thi Godot bạn đã tải sẵn
  (ví dụ `Godot_v4.3-stable_win64.exe`, `Godot_v4.3-stable_mono_win64.exe`,
  hoặc binary trên Linux/macOS).
- App tự nhận diện bản Mono nếu tên file chứa chữ "mono", còn lại coi là Standard.
- **Đặt mặc định**: phiên bản này sẽ được tự chọn khi bạn thêm project mới.
- **Tải phiên bản mới...**: mở trang download chính thức của Godot trong trình
  duyệt để bạn tải file zip, giải nén thủ công rồi quay lại "Thêm phiên bản...".

### Tab "Project"
- **Thêm project...**: chọn file `project.godot` của dự án bạn muốn quản lý.
- Chọn 1 project trong danh sách, rồi chọn phiên bản Godot muốn dùng ở
  dropdown "Phiên bản Godot", cuối cùng bấm **Mở project** — Hub sẽ gọi đúng
  file thực thi đó với tham số `--path <thư mục project>`.
- Mỗi project nhớ phiên bản Godot đã gán, lần sau mở lại Hub vẫn giữ nguyên.

## Dữ liệu lưu ở đâu

Toàn bộ danh sách phiên bản/project lưu tại
`user://godot_hub_data.json` (trên Windows thường là
`%APPDATA%\Godot\app_userdata\Godot Hub\godot_hub_data.json`).

## Giới hạn hiện tại / có thể mở rộng thêm

- Chưa tự động tải & giải nén bản Godot mới từ GitHub Releases (mới chỉ mở
  trang tải) — nếu muốn, mình có thể thêm `HTTPRequest` + giải nén zip bằng
  `ZIPReader` để tự động hoá bước này.
- Trên macOS, file `.app` là một thư mục — FileDialog có thể cần bạn bấm vào
  trong `.app/Contents/MacOS/` để chọn đúng file thực thi, hoặc mình có thể
  sửa lại để nhận nguyên `.app` làm 1 "phiên bản".
- Chưa có icon riêng, chưa build ra .exe/.app độc lập — bạn export bằng
  Godot (Project > Export) khi cần dùng như 1 app tách rời.
