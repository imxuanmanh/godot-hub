# Godot Hub — Default settings and per-project overrides

Kế hoạch bàn giao để triển khai trong `D:/Workspace/Tools/godot-hub`.
Trạng thái: chỉ khảo sát và thiết kế; chưa sửa code hoặc cấu hình của Hub/Godot.

## 1. Yêu cầu đã chốt

- Dùng một bộ thiết lập mặc định, tên file `settings.cfg`.
- “Editor mặc định” ở đây là editor viết code: Built-in hoặc External/VSCode, không phải engine được đánh dấu Default trong Hub. Lựa chọn khởi tạo là Built-in.
- Lựa chọn mặc định được đọc từ settings.cfg; không hardcode Built-in trong luồng launch sau khi user đã chọn editor khác. Đánh dấu một engine Godot khác làm Default không tự thay đổi lựa chọn editor viết code.
- Mỗi project chỉ lưu những giá trị ghi đè trong `settings.override.cfg`.
- Chưa ghi đè thì tiếp tục kế thừa mặc định; không sao chép thành một profile độc lập khi người dùng sửa một trường.
- Đổi mặc định phải tác động đến mọi project chưa ghi đè trường đó ở lần mở editor tiếp theo.
- Hai project dùng cùng một engine có thể có thiết lập editor khác nhau và chạy đồng thời.
- Nhu cầu đầu tiên: mặc định dùng editor GDScript tích hợp của Godot; project nào cần VSCode thì override riêng. User vẫn có thể đổi default sang VSCode về sau.
- Không cần màn hình quản lý profile, đặt tên profile hoặc chia sẻ profile trong lần triển khai này.
- Cấu hình có hiệu lực cho lần mở editor tiếp theo; không làm đồng bộ nóng.

Phạm vi UI đầu tiên là lựa chọn editor GDScript và các trường thực thi liên quan. Phần resolve cấu hình phải tổng quát theo key; không hứa hỗ trợ toàn bộ EditorSettings, shortcut và Resource tùy ý ngay từ bản đầu.

## 2. Context đã khảo sát

- Hub viết bằng GDScript, `project.godot` hiện khai báo Godot 4.7, Compatibility.
- `Main.gd` giữ danh sách engine/project và trực tiếp đọc/ghi `user://godot_hub_data.json`.
- Dữ liệu hiện chưa có `schema_version`; ghi trực tiếp vào file chính.
- Project hiện có các trường: name, project_dir, engine_index, pinned, tags.
- `Main.gd::_on_launch_requested()` gọi `OS.create_process(engine_path, ["--path", project_dir, "-e"])`.
- `ui/ProjectsTab.gd` có ba đường mở project: nút Open, double-click, context menu. Tất cả cần đi qua cùng launch service.
- Bộ chọn engine nằm tại `ui/ProjectsTab.tscn`, node `LaunchPanel/Content`.
- i18n dùng `locales/translations.csv` với cột keys, vi, en.
- Main và ProjectsTab đều đã hơn khoảng 200 dòng; tách đúng phần persistence/launch/UI panel liên quan trước khi thêm nghiệp vụ.
- Chưa có process service, settings repository hoặc bộ test độc lập cho tính năng này.
- Lệnh `git status --short` trong lượt khảo sát trả về “must be run in a work tree”. Khi chuyển workspace cần xác minh Git lại; không tự sửa config Git toàn cục hoặc khởi tạo repo mới để né lỗi.

Đọc lại AGENTS.md trong repo đích trước khi triển khai. Quy tắc chính: static typing; code/comment tiếng Anh; UI qua i18n; không thêm C#/GDExtension/dependency; service không tham chiếu UI; thay đổi nhiều file cần plan 3–8 dòng; mỗi bước phải chạy được.

## 3. Semantics của default và override

Thứ tự ưu tiên:

```text
Godot native defaults / existing native baseline
    < settings.cfg do Hub quản lý
    < settings.override.cfg của project
```

Trong phạm vi các key Hub quản lý:

```text
effective[key] = override[key] nếu override có key
                 default[key] nếu default có key
                 native baseline nếu cả hai không có key
```

Quy tắc bắt buộc:

1. Kiểm tra sự tồn tại của key, không kiểm tra truthiness. false, 0 và chuỗi rỗng đều có thể là override hợp lệ.
2. Override giá trị bằng default vẫn là override tường minh và được giữ. Đổi default sau đó không được đổi trường đang ghim này.
3. Nút “Use default” xóa key khỏi file override. Không chép giá trị default hiện tại vào override.
4. Không có file override hoặc file override trống đều hợp lệ.
5. Key không hỗ trợ/giá trị sai kiểu phải có chẩn đoán; không âm thầm làm thành thiết lập khác.
6. Ngoài bước khởi tạo khi file chưa tồn tại, chỉ ghi default khi user chỉnh default. Chỉnh project tuyệt đối không ghi default.
7. Giữ nguyên key không thuộc phạm vi UI khi đọc rồi lưu lại file cấu hình.
8. Không ghi effective settings trở lại file override: làm thế sẽ biến mọi giá trị kế thừa thành giá trị riêng.
9. Không tự tạo file override cho tất cả project khi migrate.

Ví dụ `settings.cfg` được khởi tạo với Built-in:

```ini
[meta]
schema_version=1

[editor]
text_editor/external/use_external_editor=false
```

Không cần path/flags cho default Built-in. Ví dụ override của project muốn dùng VSCode:

```ini
[meta]
schema_version=1

[editor]
text_editor/external/use_external_editor=true
text_editor/external/exec_path="<user-selected-vscode-executable>"
text_editor/external/exec_flags="{project} --goto {file}:{line}:{col}"
```

Project plugin không có override sẽ dùng Built-in. Project game trong ví dụ ghi đè các trường cần thiết để dùng VSCode. Nếu user đổi default về sau, chỉ các trường chưa được override mới đổi theo. Khi chọn Built-in, path/flags có thể được giữ nhưng không được sử dụng; không bắt user nhập chúng.

Lựa chọn external editor cho C# là một setting riêng. Không đồng nhất với lựa chọn editor GDScript và không hứa Godot có editor C# tích hợp. Chỉ thêm UI .NET sau khi xác minh enum/API trên engine mục tiêu; engine Standard phải bỏ qua key .NET không tồn tại với chẩn đoán phù hợp.

## 4. Vị trí dữ liệu

V1 giữ cấu hình cá nhân dưới user:// của Hub; không tạo file trong repo game/plugin:

```text
user://
  godot_hub_data.json
  settings.cfg
  projects/
    <stable-project-id>/
      settings.override.cfg
  runtime/
    <stable-project-id>/
      roaming/
      local/
```

- `<stable-project-id>` là ID do Hub tạo/lưu, không dùng tên hiển thị hoặc vị trí index trong mảng.
- ID không đổi khi rename project, đổi engine, pin, search hoặc reorder danh sách.
- Đường dẫn runtime do Hub tính từ root tin cậy; không nhận path tùy ý từ cfg.
- Validate ID và containment trước mọi ghi file; không cho `../` thoát root.
- Giữ `engine_index` hiện có; không nhân tiện thiết kế lại model engine.
- Tên `settings.cfg`/`settings.override.cfg` là cấu hình của Hub, không phải Godot ProjectSettings override.cfg.
- Không thêm export/import, đồng bộ cloud hoặc cấu hình commit cùng project trong V1.
- Remove project không tự xóa thư mục override/runtime đã có. Dọn dữ liệu là chức năng riêng, cần xác nhận theo AGENTS.md.

## 5. Ranh giới quan trọng: cfg không tự áp dụng vào Godot

Đổi cách lưu thành default + override thay thế tầng quản lý profile độc lập. Nó không tự thay đổi cơ chế Godot đọc EditorSettings.

Godot không được giả định sẽ đọc hai file cfg này. Cần một adapter tạo cấu hình native có hiệu lực và mở editor trong ngữ cảnh riêng khi có override. Không sửa file EditorSettings toàn cục rồi khôi phục sau khi mở: editor còn chạy và có thể tự lưu lại, gây đua giữa các project.

Backend Windows dự kiến là private APPDATA/LOCALAPPDATA cho tiến trình editor. Thư mục runtime chỉ là dữ liệu dẫn xuất/phục vụ engine, không phải nguồn cấu hình người dùng hoặc profile cần quản lý bằng UI.

Thiết kế mong muốn:

```text
settings.cfg + project settings.override.cfg
                 |
             resolve + validate
                 |
       native settings adapter
                 |
        project runtime directory
                 |
            Godot child process
```

Phải có spike xác minh adapter trước khi xây UI; không viết parser tổng quát cho .tres bằng regex. .tres có thể chứa subresource và giá trị nhiều dòng. Không giả định EditorSettings có thể khởi tạo/load bằng runtime export của Hub; đó là editor-only API.

Chọn đường áp dụng nhỏ nhất đã chứng minh được trên engine thật. Ưu tiên cơ chế native nếu phiên bản engine thật có API/flag phù hợp; xác minh bằng --help và hành vi đọc/ghi thực tế, vì Godot có thể bỏ qua flag không tồn tại mà không báo lỗi. Nếu phải dùng editor bootstrap/helper thì chứng minh nó chạy được từ Hub đã export, không cài addon vào project của user và không thêm dependency.

Nếu chưa có adapter hoạt động tin cậy, hoàn thành resolver/test/documentation nhưng báo rõ backend chưa đạt; không tuyên bố tính năng hoàn tất chỉ vì cfg đã merge đúng.

## 6. Spike bắt buộc trước implementation chính

Tạo hai project fixture nhỏ, dùng cùng Godot 4.6.3 .NET; không thử ghi đè cấu hình trên project đang dùng thật.

Chứng minh các điểm sau:

1. Base chọn Built-in, override của B chọn VSCode; engine A/B thực sự đọc hai giá trị khác nhau. Sau đó đổi default sang VSCode và kiểm tra project không override kế thừa lựa chọn mới.
2. Có thể mở đồng thời hai editor, thay đổi ở B không làm thay đổi native settings toàn cục hoặc A.
3. Native settings ngoài nhóm Hub quản lý được bảo toàn theo policy đã chọn; không mất theme/shortcut không liên quan do tạo lại file native.
4. Hub export cũng áp dụng được settings; không chỉ hoạt động khi F5 Hub từ editor.
5. Xác định chính xác phạm vi bị đổi bởi APPDATA/LOCALAPPDATA: editor data, cache, user:// game, external IDE, công cụ .NET và export templates.
6. Chạy project C# có sẵn hoặc fixture được phép: build/run vẫn hoạt động, SDK và NuGet config không bị mất ngoài dự kiến.
7. Engine self-contained có marker _sc_/._sc_: phát hiện và trả lỗi không hỗ trợ, không sửa marker hoặc installation.
8. Kiểm tra phiên bản engine thực bằng --version, không chỉ parse nhãn engine do user đặt.

Đầu ra spike: notes ghi phiên bản thực, cách áp dụng đã chứng minh, các đường dẫn thực tế và giới hạn. Nếu ảnh hưởng đến IDE/.NET làm hỏng luồng hiện có thì sửa backend trước khi tiếp tục; không che bằng silent fallback.

## 7. Luồng launch dự kiến

1. UI phát launch_requested với project/engine hiện tại như trước.
2. Launch service validate executable, project.godot, ID và cấu hình.
3. Repository đọc default và override; resolver tạo effective settings cùng provenance theo key.
4. Nếu không có Hub-managed setting cần áp dụng, dùng launch hiện tại để giữ tương thích.
5. Adapter chuẩn bị native settings vào runtime của project, chỉ áp dụng các key được hỗ trợ và giữ dữ liệu ngoài phạm vi.
6. Chuẩn bị argv bằng PackedStringArray; không nối shell command.
7. Process service chụp trạng thái môi trường gốc, gồm biến tồn tại hay chưa tồn tại.
8. Đặt môi trường launch, gọi OS.create_process, khôi phục ngay môi trường Hub ở mọi nhánh thành công/thất bại.
9. Không await, emit signal, ghi log hoặc gọi callback trong đoạn tạm thay đổi môi trường. Các đường tạo process khác không được chen vào đoạn này; kiểm tra lại thread/process callers.
10. Sau khi môi trường được khôi phục mới trả kết quả/log/hiển thị lỗi.
11. Chỉ thực hiện close_on_launch khi có PID hợp lệ. PID hợp lệ chỉ chứng minh tạo tiến trình thành công, chưa chứng minh editor khởi tạo xong.

Không thay đổi môi trường hệ thống Windows. Không cần chờ editor đóng để khôi phục settings toàn cục. Hub đóng không được làm editor con tắt.

Nếu config không hợp lệ, báo lỗi và giữ file để user sửa; không tự launch bằng settings hệ thống thay cho override đã chọn. Trong các bước triển khai trung gian chưa bật tính năng, giữ launch cũ. Khi tính năng được bật hoàn chỉnh, thiếu settings.cfg thì khởi tạo default Built-in, không âm thầm kế thừa VSCode toàn cục.

## 8. Nguồn ghi cấu hình và thay đổi trong Godot

V1: user chỉnh các trường Hub quản lý trong Hub; settings.cfg và settings.override.cfg là nguồn chính thức.

- Chỉnh trong cửa sổ Godot Editor Settings không tự tạo override trong Hub.
- Lần mở sau, các key Hub quản lý được áp dụng lại theo cfg. UI/docs cần nói rõ điều này.
- Các key native ngoài phạm vi Hub phải được bảo toàn; không được tiện tay ghi đè toàn bộ native settings.
- Không thêm watcher hoặc tiến trình nền chỉ để tự suy ra override trong V1.

Nếu muốn mọi thay đổi trực tiếp trong Godot tự trở thành override, đó là hạng mục mở rộng cụ thể: cần lưu snapshot effective tại lúc launch, nhận thay đổi theo key, phân biệt thay đổi của user với auto-normalization/migration của engine, xử lý Hub đã đóng và default đổi trong lúc editor còn chạy. Không chỉ diff file cuối phiên với default hiện tại, vì sẽ tạo override giả cho giá trị user chưa hề sửa.

## 9. UI tối thiểu

Settings tab:

- Nhóm “Default editor settings”.
- Built-in / External cho GDScript.
- Khởi tạo Built-in khi chưa có settings.cfg; sau đó luôn hiển thị/đọc lựa chọn user đã lưu. Không suy ra lựa chọn này từ engine.is_default hoặc từ settings VSCode toàn cục đang có trên máy.
- Executable picker và arguments khi dùng External.
- Lưu vào settings.cfg bằng ConfigFile; có validation và thông báo lỗi ghi file.

Projects tab:

- Một nút “Editor settings…” ở vùng launch mở dialog nhỏ.
- Mỗi trường có trạng thái Inherit / Override, giá trị effective và nguồn Default / Project / Native.
- Lúc chưa có override, hiển thị “Using default settings”.
- “Use default” cho từng trường xóa key override.
- Có thể thêm “Use defaults for all fields” chỉ xóa các key được UI quản lý, không xóa key chưa hiểu hoặc toàn bộ thư mục.
- Override Built-in chỉ cần ghim use_external_editor=false; không ép người dùng điền path/flags không được dùng.
- Save khi không thay đổi không được tạo file override dư thừa.
- Cancel không đổi file/dữ liệu launch.
- Thay đổi đang mở cần restart editor; thông báo ngắn ở dialog.
- Mọi chuỗi thêm vào translations.csv bằng tiếng Việt và tiếng Anh.

## 10. File dự kiến tạo/sửa

Điều chỉnh tên theo code thực lúc triển khai, không tạo các lớp chỉ để đủ sơ đồ.

| File | Vai trò |
| --- | --- |
| Main.gd | Wiring services/signals, giữ hành vi app, bỏ launch/persistence trực tiếp |
| core/services/hub_data_repository.gd | Load/save/migrate JSON hiện có, ghi an toàn, giữ trường cũ |
| core/services/process_service.gd | Bọc spawn và vòng đời override môi trường, kết quả có cấu trúc |
| features/editor_settings/editor_settings_repository.gd | Đọc/ghi cfg default và project override, validate ID/path |
| features/editor_settings/editor_settings_resolver.gd | Merge thuần, provenance và validation key/type |
| features/editor_settings/editor_launch_service.gd | Validate launch, gọi adapter và process service |
| features/editor_settings/native_settings_adapter.gd | Cầu nối sang engine native đã chứng minh trong spike; chứa platform policy tập trung |
| features/editor_settings/ui/editor_settings_dialog.gd + .tscn | Form dùng cho default hoặc override, không chứa nghiệp vụ file/process |
| ui/ProjectsTab.gd + .tscn | Nút cấu hình và forwarding signal, giữ cả ba đường launch |
| ui/SettingsTab.gd + .tscn | Nút/form chỉnh default |
| ui/project_launch_panel.gd + .tscn, nếu cần | Tách launch panel hiện có để không tiếp tục phình ProjectsTab |
| locales/translations.csv | UI text vi/en |
| tests/ và fixtures cần thiết | Test logic, lỗi I/O, child environment, integration |
| README.md; docs/editor_settings.md | Sử dụng, precedence, vị trí dữ liệu, limits và cách test |

Không tạo Result framework, generic config UI hoặc logging framework. Tái sử dụng hạ tầng nếu repo đã có khi bắt đầu; nếu chưa có, một điểm log nhỏ thống nhất và Dictionary result typed ở ranh giới là đủ.

## 11. Persistence và migration

- JSON không version được coi là schema 0; schema mới thêm stable project ID và schema_version.
- Giữ versions, engine_index, language, close_on_launch, tags, pinned và trường không liên quan.
- Project cũ chưa có override kế thừa default mới. Khi tính năng được bật hoàn chỉnh mà chưa có settings.cfg thì khởi tạo Built-in; việc giữ launch cũ chỉ áp dụng cho các bước triển khai trung gian trước khi bật tính năng.
- Khi kích hoạt tính năng lần đầu mà chưa có settings.cfg, khởi tạo lựa chọn editor GDScript là Built-in theo yêu cầu. Hiển thị default này trong Hub. Cấu hình native toàn cục đang dùng VSCode không được tự ghi đè lựa chọn khởi tạo; không sửa file native gốc. Nếu sau này thêm import native settings, đó là thao tác tường minh và chỉ import key đã xác minh.
- Mỗi cfg có [meta] schema_version riêng. Không tự hạ version không hiểu hoặc ghi đè file có schema mới hơn.
- Save: ghi file tạm, đóng, thay thế an toàn theo API filesystem đã xác minh trên nền tảng; khi thất bại vẫn giữ bản cũ. Test failure path, không gọi rename thành công một cách giả định.
- File hỏng phải được giữ nguyên và báo đường dẫn lỗi. Có thể mở Hub với state read-only/recovery nhưng không ghi defaults đè lên dữ liệu lỗi.
- App UI chỉ nhận thay đổi là thành công sau khi lưu bền vững; không để màn hình nói đã lưu trong khi launch còn dùng bản cũ.

## 12. Trình tự triển khai

### Bước 0 — Baseline và spike

Đọc AGENTS, kiểm tra git/worktree, backup dữ liệu dùng thử; chạy baseline Hub. Thực hiện phần 6 trước. Ghi lại giới hạn backend.

### Bước 1 — Resolver thuần

Thêm merge/provenance/validation và test. Chưa thay launch, chưa ghi file user. Test false/0/empty, key bằng default vẫn ghim, remove override khôi phục kế thừa.

### Bước 2 — Repository và migration

Tách persistence liên quan khỏi Main; thêm cfg repository. Test old JSON, round-trip, atomic save failure, schema mới hơn và file hỏng. Hub vẫn mở project bằng đường cũ.

### Bước 3 — Launch service/backend

Đưa cả ba đường launch qua service, áp dụng adapter đã qua spike. Test environment restore, native global unchanged và lỗi spawn. Chưa cần UI đầy đủ; fixture cfg đủ kiểm chứng.

### Bước 4 — UI default/override

Thêm form dùng chung với mode default/project, trạng thái inherit/override, save/cancel/use-default; tích hợp i18n. Tách launch panel nếu cần để giữ UI script nhỏ.

### Bước 5 — Kiểm thử thật và docs

Chạy matrix dưới đây, gồm Hub export. Chụp lại settings/log cần thiết và ghi kết quả thực tế. Cập nhật README/docs, ghi rõ nền tảng/engine đã test. Không gọi tính năng hỗ trợ Linux/macOS chỉ vì code có nhánh OS.

Mỗi bước chạy import/parse và main scene, báo 1–3 dòng đã làm/còn lại/rủi ro. Không refactor downloader, version manager, model engine hoặc UI khác ngoài phần cần kết nối.

## 13. Ma trận test và tiêu chí đạt

| Test | Kết quả bắt buộc |
| --- | --- |
| Không override | Effective kế thừa default, không tạo snapshot đầy đủ |
| Chưa có settings.cfg | Khởi tạo default Built-in; không tự lấy VSCode từ native settings toàn cục |
| Đổi editor mặc định trong Hub | Đọc lựa chọn đã lưu, project inherited dùng lựa chọn mới ở lần mở sau |
| Đổi engine được đánh dấu Default | Không tự đổi lựa chọn Built-in/VSCode trong settings.cfg |
| Override false/0/empty | Giá trị được giữ đúng |
| Default thay đổi | Trường inherited đổi; trường overridden giữ nguyên |
| Override bằng default rồi đổi default | Override vẫn ghim giá trị cũ |
| Use default | Key biến mất, effective trở về default hiện tại |
| Chỉnh project A | Default và project B không đổi |
| Save/Cancel | Save tồn tại sau restart; Cancel không đổi dữ liệu |
| File thiếu/trống/hỏng/sai kiểu/schema mới | Hành vi đúng policy; không ghi đè dữ liệu lỗi |
| Save lỗi quyền/disk/rename | Báo lỗi, giữ dữ liệu cũ, UI không báo lưu thành công |
| ID/path giả mạo | Không đọc/ghi ra ngoài root được phép |
| Project path có space/Unicode | Mở đúng project, argv không bị tách sai |
| Legacy JSON | Giữ engine, tags, pin, language, close_on_launch |
| Search/reorder/rename/change engine | Override vẫn thuộc đúng stable project ID |
| Nút Open/double-click/context menu | Cùng effective config và cùng validation |
| A VSCode, B built-in, cùng engine | Chạy đồng thời và mở script đúng nơi |
| Hash native settings toàn cục trước/sau | Không đổi do thao tác áp dụng override của Hub |
| Child environment | Child nhận đúng; Hub được restore kể cả spawn thất bại |
| Biến env trước đó chưa tồn tại | Sau launch vẫn chưa tồn tại, không đổi thành chuỗi rỗng |
| close_on_launch | Hub tắt khi spawn thành công; child vẫn hoạt động; lỗi giữ Hub |
| Native setting ngoài nhóm Hub quản lý | Không bị mất khi áp dụng key managed |
| Thay managed key trong Godot | Hành vi lần mở sau đúng tài liệu source-of-truth |
| .NET | Build/run thực; IDE/SDK/NuGet/user:// được kiểm chứng và ghi rõ |
| Engine Standard | GDScript hoạt động; key .NET không gây lỗi |
| Self-contained engine | Từ chối override rõ ràng nếu chưa hỗ trợ; không sửa installation |
| Hub export | Hành vi giống chạy Hub bằng F5 |
| Linux/macOS | Native launch cũ không regression; override bị disable có lý do nếu chưa xác minh backend |

Test thuần dùng script assert GDScript, không thêm framework. Integration dùng thư mục fixture riêng; không viết vào cấu hình native cá nhân để làm test. Manual log ghi engine version, PID, project ID, config paths và error code; không dump toàn bộ environment hoặc file user có thể chứa thông tin riêng.

## 14. Definition of done

- Default ban đầu là Built-in; plugin không cần override, game có thể override sang VSCode.
- User đổi default trong Hub thì settings.cfg lưu lựa chọn mới và project chưa override kế thừa đúng.
- Hai project dùng cùng engine và chạy song song đúng lựa chọn.
- Đổi một default khác được project chưa override kế thừa ở lần mở sau.
- Reset trường về default xóa override thực sự.
- Settings không liên quan và native global settings được bảo toàn.
- Mọi đường launch, restart Hub, migrate và close_on_launch vẫn đúng.
- Có test/report thực tế, docs ghi rõ phạm vi và hạn chế, không còn lỗi parse/warning mới.

Không làm trong V1: profile manager, cloud sync, arbitrary native Resource/shortcut editor, hot reload setting, tự ghi lại mọi thay đổi từ cửa sổ Godot, cleanup dữ liệu cũ, hỗ trợ portable engine chưa được kiểm chứng.

## 15. Nguồn chính thức cần đối chiếu khi triển khai

- EditorSettings: https://docs.godotengine.org/en/4.6/classes/class_editorsettings.html
- OS process/environment: https://docs.godotengine.org/en/4.6/classes/class_os.html
- Data paths/self-contained: https://docs.godotengine.org/en/4.6/tutorials/io/data_paths.html
- CLI: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
- Windows path implementation: https://raw.githubusercontent.com/godotengine/godot/4.6-stable/platform/windows/os_windows.cpp

Đối chiếu engine thực bằng --version/--help; không coi docs stable là bảo đảm cho mọi bản engine đã đăng ký.

## 16. Prompt bàn giao

> Triển khai tính năng default settings + per-project override theo tài liệu này trong repo Godot Hub. Đọc AGENTS.md và khảo sát lại code trước. Dùng settings.cfg mặc định và settings.override.cfg chỉ chứa key user ghi đè; không làm profile manager. Editor mặc định là editor viết code, khởi tạo Built-in thay vì VSCode, không phải engine Godot được đánh dấu Default. Sau khởi tạo luôn đọc lựa chọn đã lưu trong settings.cfg; project chưa override kế thừa default, project muốn VSCode override riêng. Không sửa native global EditorSettings, không cài addon vào project của user. Bắt đầu bằng spike xác minh cách áp dụng vào Godot 4.6.3 .NET và bản Hub export; chỉ sau khi chứng minh backend mới triển khai lần lượt resolver, repository/migration, launch service, UI và integration tests. Ghi rõ khác biệt giữa cfg do Hub quản lý và file native Godot, cũng như giới hạn thay đổi trực tiếp trong Editor Settings. Làm từng bước chạy được, không refactor ngoài phạm vi.
