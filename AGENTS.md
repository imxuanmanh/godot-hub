# AGENTS.md — Godot Hub (personal tool)

Công cụ cá nhân quản lý project và phiên bản engine Godot, **được viết bằng chính Godot**.
Dự án làm cho vui, được vibecode hoàn toàn: ưu tiên code **nhỏ, rõ, dễ thay thế**, không ưu tiên "thông minh".

---

## 0. Nguyên tắc vận hành với agent (đọc trước tiên)

1. **Không làm theo lệnh một cách máy móc.** Nếu yêu cầu của người dùng dẫn đến thiết kế tệ (coupling chặt, hardcode, một file ôm nhiều việc, API Godot dùng sai...), hãy **dừng lại, nêu vấn đề, đề xuất hướng thay thế kèm lý do**, rồi mới làm. Nếu người dùng phản biện hợp lý, chấp nhận và điều chỉnh.
2. **Plan trước, code sau** cho mọi thay đổi lớn hơn 1 file: liệt kê file sẽ tạo/sửa và vai trò từng file trong 3–8 dòng.
3. **Làm từng bước nhỏ, mỗi bước chạy được.** Không viết 10 file rồi mới thử. Sau mỗi bước phải đảm bảo project mở được trong Godot không lỗi parse.
4. **Không refactor ngoài phạm vi yêu cầu.** Thấy vấn đề ở chỗ khác thì ghi chú lại, đừng tự sửa.
5. **Không bịa API.** Không chắc một hàm/signal của Godot có tồn tại hay không thì nói rõ là không chắc, hoặc dùng cách đơn giản hơn mà chắc chắn đúng.
6. Mỗi lần xong một bước: tóm tắt 1–3 dòng (đã làm gì, còn gì, rủi ro gì).

---

## 1. Tech stack & quy ước nền

- **Godot 4.x (stable mới nhất)**, ngôn ngữ **GDScript**, **static typing bắt buộc** (`var x: int`, `func f(a: String) -> void`).
- Không dùng C#, GDExtension hay plugin bên thứ ba trừ khi người dùng đồng ý rõ ràng.
- Renderer: Compatibility hoặc Forward+ đều được, UI dùng `Control` node thuần.
- Đa nền tảng (Windows / Linux / macOS): **không giả định đường dẫn, dấu phân cách, hay tên file thực thi**.
- Mã nguồn, tên biến, comment: **tiếng Anh**. Chuỗi hiển thị cho người dùng: đi qua hệ thống i18n (xem mục 5).

---

## 2. Kiến trúc: tách lớp, tách module

Cấu trúc thư mục (theo **tính năng**, không theo loại file):

```
res://
├─ core/                 # Hạ tầng dùng chung, KHÔNG biết gì về UI hay feature
│  ├─ services/          # Logic thuần: file I/O, process, http, settings, logging
│  ├─ models/            # Data class (Resource/RefCounted), không chứa logic nặng
│  ├─ events/            # Event bus (signals toàn cục), giữ rất nhỏ
│  └─ util/              # Hàm tiện ích thuần, stateless
├─ features/
│  ├─ projects/          # Mỗi feature = 1 thư mục độc lập
│  │  ├─ projects_service.gd      # Logic/nghiệp vụ
│  │  ├─ projects_repository.gd   # Đọc/ghi dữ liệu
│  │  ├─ ui/                      # Scene + script UI của feature này
│  │  └─ projects_feature.gd      # Điểm đăng ký feature (entry)
│  ├─ engines/           # Quản lý phiên bản engine (list, tải, gỡ, mở)
│  ├─ templates/         # (tùy chọn) Tạo project từ template
│  └─ settings/
├─ ui/
│  ├─ shell/             # Cửa sổ chính, điều hướng giữa các feature
│  ├─ components/        # Widget tái sử dụng (button, dialog, list item...)
│  └─ theme/             # Theme, màu, font
├─ config/               # Giá trị cấu hình mặc định (.tres/.json), KHÔNG nằm trong code
├─ locales/              # File dịch (.csv/.po)
└─ main.tscn
```

### Quy tắc phân lớp

- **UI không chứa nghiệp vụ.** Script UI chỉ: hiển thị state, bắt input, gọi service, lắng nghe signal.
- **Service không biết UI tồn tại.** Không `get_node()` vào scene, không tham chiếu Control.
- **Feature không import trực tiếp feature khác.** Muốn giao tiếp → qua event bus hoặc interface chung ở `core/`.
- **Phụ thuộc chỉ đi một chiều:** `features → core`, `ui → features/core`. `core` không bao giờ phụ thuộc ngược lên.
- **"Call down, signal up":** cha gọi hàm của con; con báo cho cha bằng signal.

---

## 3. Quy tắc module hóa

- **Một file = một trách nhiệm.** Tên file nói rõ nó làm gì (`engine_downloader.gd`, không phải `manager.gd` hay `utils.gd`).
- **Giới hạn kích thước:** script > ~200 dòng hoặc hàm > ~30 dòng → phải cân nhắc tách. Vượt hẳn thì bắt buộc tách trước khi thêm tính năng.
- **Scene nhỏ, lồng nhau:** mỗi item danh sách, dialog, panel là scene riêng; không dựng cả màn hình trong một scene khổng lồ.
- **Autoload (singleton) tối thiểu.** Chỉ dùng cho: event bus, settings, logger. Mọi thứ khác là service được khởi tạo và truyền vào (dependency injection đơn giản qua `setup()` hoặc biến export). Không dùng autoload như thùng chứa tạm.
- **Mỗi service có interface rõ ràng** (hàm public ít, có type), phần còn lại prefix `_`.
- **Thêm tính năng mới = thêm thư mục mới trong `features/`**, đăng ký ở một điểm duy nhất, không phải sửa rải rác nhiều nơi.
- Ưu tiên **composition** (node/component con) hơn kế thừa sâu. Kế thừa tối đa 2 tầng.

---

## 4. Tách logic khỏi side effect

Mọi thứ chạm vào thế giới bên ngoài phải bọc trong service riêng để dễ sửa, dễ mock:

| Việc | Service bọc |
|---|---|
| Đọc/ghi file, thư mục | `file_service` |
| Chạy tiến trình (mở Godot, mở editor) | `process_service` (bọc `OS.create_process` / `OS.execute`) |
| Tải file (engine, template) | `download_service` (bọc `HTTPRequest`) |
| Lưu/đọc settings & dữ liệu app | `settings_service` / repository |
| Ghi log | `logger` |

Logic thuần (parse tên phiên bản, so sánh version, lọc, sắp xếp) viết thành **hàm tĩnh/stateless** trong `core/util/` hoặc trong service, để test được mà không cần chạy UI.

---

## 5. Cấm hardcode

**Không được để trong code:**

- Đường dẫn tuyệt đối, tên thư mục người dùng, URL tải về, tên file thực thi theo OS.
- Magic number / magic string (kích thước, timeout, tên key, tên signal dạng chuỗi lặp lại).
- Màu, font size, margin, tên theme.
- Chuỗi hiển thị cho người dùng.

**Thay bằng:**

- **Đường dẫn:** dùng `user://` cho dữ liệu app, `OS.get_user_data_dir()`, `OS.get_environment()`, `OS.get_name()`; vị trí cài engine do người dùng cấu hình trong settings.
- **Hằng số:** gom vào `const` có tên trong file riêng theo domain (`engine_constants.gd`, `ui_constants.gd`), hoặc `class_name` + `const`.
- **Cấu hình:** file `config/*.json|.tres`, đọc qua `settings_service`. Có giá trị mặc định, cho phép ghi đè bởi người dùng.
- **Khác biệt theo OS:** gom vào một nơi (`platform_service`) trả về tên file/archive/đường dẫn phù hợp, không rải `if OS.get_name() == ...` khắp nơi.
- **UI:** dùng `Theme` + theme variation, không set màu/size trong script. Chuỗi dùng `tr("KEY")` và file `locales/`.
- **Tên signal/event:** dùng signal thật của Godot, không dùng chuỗi tự chế.

---

## 6. Dữ liệu & lưu trữ

- Dữ liệu app (danh sách project, engine đã cài, settings) lưu ở `user://`, định dạng **JSON hoặc ConfigFile**, dễ đọc dễ sửa tay.
- Mỗi file dữ liệu có trường **`schema_version`** và hàm migrate đơn giản khi đổi cấu trúc.
- **Ghi file an toàn:** ghi ra file tạm rồi đổi tên, tránh hỏng dữ liệu khi crash.
- Đọc dữ liệu lỗi/thiếu → rơi về mặc định và log cảnh báo, **không crash**.
- Repository là nơi duy nhất biết định dạng lưu; service chỉ làm việc với model.

---

## 7. Xử lý lỗi & log

- Hàm có thể thất bại trả về kết quả có cấu trúc (ví dụ `{ ok: bool, value: Variant, error: String }` hoặc một class `Result` nhỏ trong `core/util/`), **không** `push_error` rồi bỏ qua im lặng.
- Lỗi cuối cùng hiển thị cho người dùng qua một kênh thống nhất (toast/dialog) do UI shell lo.
- Log qua `logger` có mức (debug/info/warn/error), không rải `print()` bừa bãi. Gỡ `print` debug trước khi kết thúc bước.
- Việc chậm (tải file, giải nén, quét thư mục lớn) phải **không chặn UI**: dùng `await`, signal tiến độ, hoặc `Thread`/`WorkerThreadPool` khi thật cần. Có thể hủy được (cancel) nếu hợp lý.

---

## 8. Phong cách GDScript

- Theo style guide chính thức của Godot: `snake_case` cho biến/hàm/file, `PascalCase` cho `class_name`, `UPPER_SNAKE_CASE` cho hằng, `_private` cho nội bộ.
- Thứ tự trong file: `class_name` → `extends` → docstring → signal → enum → const → `@export` → biến → `_ready` & lifecycle → hàm public → hàm private.
- Dùng `@onready` + `%UniqueName` (unique node name) thay vì đường dẫn node dài dòng.
- Khai báo signal có tham số có type. Ngắt kết nối/giải phóng đúng chỗ, tránh rò rỉ.
- Không dùng `get_node("../../..")`. Cần tham chiếu → `@export` hoặc truyền qua `setup()`.
- Docstring `##` ngắn cho class và hàm public. Comment giải thích **vì sao**, không lặp lại **cái gì**.

---

## 9. Chức năng cốt lõi dự kiến (làm theo thứ tự, mỗi mục là một feature riêng)

1. **Shell & điều hướng** — cửa sổ chính, chuyển tab giữa các feature.
2. **Settings** — thư mục cài engine, thư mục project mặc định, ngôn ngữ, theme.
3. **Engines** — quét/liệt kê phiên bản đã có, đặt mặc định, mở engine.
4. **Projects** — thêm/xóa/tìm project, đọc `project.godot` lấy tên/phiên bản, mở bằng engine phù hợp.
5. **Download engine** — lấy danh sách bản phát hành, tải, giải nén, đăng ký vào Engines.
6. **Templates** (tùy chọn).

Không bắt đầu mục sau khi mục trước chưa chạy ổn.

---

## 10. Kiểm thử & kiểm tra

- Logic thuần (parse version, parse `project.godot`, so sánh, migrate dữ liệu) nên có test nhỏ (GUT hoặc script test đơn giản) nếu người dùng đồng ý dùng.
- Sau mỗi thay đổi: mở project, đảm bảo **không có lỗi parse/warning mới** trong editor, chạy `main.tscn` và thử đường đi chính của tính năng vừa làm.
- Kiểm tra thủ công các trường hợp biên: thư mục không tồn tại, file hỏng, không có mạng, đường dẫn có khoảng trắng/ký tự Unicode.

---

## 11. Tuyệt đối tránh

- God script / `Manager` ôm mọi thứ; file `utils.gd` chứa đủ loại hàm không liên quan.
- Autoload bừa bãi, biến toàn cục.
- Logic nghiệp vụ trong script UI.
- Copy-paste một đoạn code ≥ 3 lần thay vì rút thành hàm/component.
- Chạy lệnh shell thô nối chuỗi từ input người dùng (nguy cơ injection); luôn truyền tham số dạng mảng cho `OS.create_process` / `OS.execute`.
- Xóa file/thư mục của người dùng mà không xác nhận rõ ràng; thao tác phá hủy luôn cần confirm.
- Thêm dependency, đổi cấu trúc thư mục, đổi tên hàng loạt mà không hỏi.

---

## 12. Định nghĩa "xong" cho một bước

- [ ] Chạy được, không lỗi/warning mới.
- [ ] Không hardcode mới (đường dẫn, số, chuỗi, màu).
- [ ] Mỗi file mới có một trách nhiệm rõ, trong giới hạn kích thước.
- [ ] UI không chứa nghiệp vụ; service không chạm UI.
- [ ] Có xử lý lỗi cho trường hợp thất bại hợp lý.
- [ ] Đã tóm tắt thay đổi và rủi ro còn lại cho người dùng.
