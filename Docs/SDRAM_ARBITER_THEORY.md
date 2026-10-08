# PHÂN TÍCH CHUYÊN SÂU: SDRAM ARBITER VÀ CƠ CHẾ PING-PONG BUFFER

## 1. BẢNG PHÂN VAI (TỪ ĐIỂN CÁC BIẾN QUAN TRỌNG)

Trong mô hình "Hệ thống Trạm Bơm", con chip SDRAM khổng lồ được chia làm 2 bể (Bể 0 và Bể 1). Dưới đây là các "diễn viên" vận hành hệ thống này:

*   **`bank_write` (Vòi Bơm của Suối):** Cờ quyết định dòng nước (Pixel) từ Camera sẽ đổ vào Bể 0 hay Bể 1. Cơ chế này do tín hiệu Camera tự quản lý ngầm.
*   **`bank_read` (Vòi Hút của VGA):** Cờ quyết định dòng nước hút ra màn hình sẽ lấy từ Bể 0 hay Bể 1. Biến này do Máy trạng thái (FSM) - tức "Bác Gác Đập" - quản lý.
*   **`bank_completed` (Con Dấu "THÀNH PHẨM"):** Luôn trỏ vào cái Bể vừa được Camera bơm đầy đặn và nguyên vẹn nhất. Đây là điểm neo duy nhất để hệ thống VGA biết nên hút nước ở đâu.
*   **`camera_vsync_falling` (Tiếng Còi Báo Đầy của Suối):** Chớp lên mức 1 trong đúng 1 nhịp xung nhịp khi Camera vừa chụp xong 1 bức ảnh.
*   **`vsync_falling` (Tiếng Còi Báo Cạn của VGA):** Chớp lên mức 1 trong đúng 1 nhịp xung nhịp khi màn hình VGA vừa quét xong 1 khung hình.
*   **`vsync_req` (Tờ Giấy Note "Nhắc Dọn Dẹp"):** Được sinh ra ngay khi còi VGA (`vsync_falling`) kêu. Nó đóng vai trò như một tờ giấy note dán dính trên bàn làm việc của Bác Gác Đập (FSM) để đảm bảo Bác không bao giờ quên nhiệm vụ Reset (dọn dẹp R-FIFO và cập nhật Bể hút) dù đang bận rộn điều khiển SDRAM ngoài công trường.

---

## 2. KỊCH BẢN THỜI GIAN THỰC (BÍ MẬT HIỂN THỊ 30FPS LÊN MÀN HÌNH 60HZ)

Có một nghịch lý về tốc độ: Camera (30fps) mất tới ~33ms để bơm đầy một Bể, trong khi VGA (60fps) chỉ mất ~16ms để hút cạn Bể. Nếu gạt cần hoán đổi Bể mù quáng, VGA sẽ hút trúng Bể đang bơm dở dang gây xé hình. 
Dưới đây là kịch bản thời gian thực giải quyết bài toán này:

*(Giả sử lúc bắt đầu: Camera đang bơm Bể 0 (`bank_write=0`). VGA đang hút Bể 1 (`bank_read=1`). Con dấu Thành phẩm đang đóng ở Bể 1 (`bank_completed=1`).)*

*   **Sự kiện 1: VGA vẽ xong sớm (Mốc 16ms)**
    Khu dân cư VGA chạy với tốc độ 60fps nên hút cạn Bể rất nhanh. Vừa vẽ xong khung hình, còi **`vsync_falling`** rít lên. Lập tức mạch điện viết một Tờ Giấy Note **`vsync_req = 1`** dán lên bàn FSM.
    Bác gác đập FSM làm xong việc, bước về chòi (`IDLE`), thấy Giấy Note liền thi hành thủ tục:
    *   Nhìn xem Bể nào đang có con dấu Thành Phẩm (`bank_read <= bank_completed`). 
    *   *Vì Camera (30fps) mới bơm được một nửa Bể 0, chưa hú còi, nên `bank_completed` VẪN LÀ 1.*
    *   Bác gác đập cắm lại vòi hút vào Bể 1, sau đó tự tay xé giấy Note (`vsync_req <= 0`).
    $\rightarrow$ **Kết quả:** VGA ngậm vòi ở Bể 1 và tiếp tục vẽ lại khung hình cũ thêm một lần nữa! Màn hình hoàn toàn nguyên vẹn, không hề bị xé.

*   **Sự kiện 2: Suối bơm xong (Mốc 33ms)**
    Sau khi hì hục, Camera cũng bơm đầy trọn vẹn Bể 0. Còi **`camera_vsync_falling`** kêu lên. 
    Không cần Bác gác đập (FSM) can thiệp, một mạch tự động ngầm lập tức giập con dấu Thành phẩm mới: **`bank_completed <= 0`** (Báo hiệu Bể 0 đã được bơm đầy!). Đồng thời bẻ Vòi Bơm sang Bể mới: **`bank_write <= 1`** để chuẩn bị hứng ảnh tiếp theo.

*   **Sự kiện 3: VGA vẽ xong lần 2 (Mốc 33ms)**
    VGA vừa vẽ xong bức hình cũ lần thứ 2. Còi **`vsync_falling`** lại rít. Tờ Giấy Note **`vsync_req = 1`** lại được dán lên bàn.
    Bác gác đập FSM bước về chòi, lại làm thủ tục lấy Thành phẩm: `bank_read <= bank_completed`.
    Nhưng lần này, con dấu `bank_completed` ĐÃ LÀ 0!
    $\rightarrow$ **Kết quả:** Vòi Hút `bank_read` lập tức được Bác rút ra và cắm sang Bể 0. Giấy Note được xé. Khu dân cư chính thức được tận hưởng khung hình mới toanh nguyên vẹn!


## 3. BÚT KÝ CỦA BÁC GÁC ĐẬP (MÔ HÌNH TRỪU TƯỢNG MÁY TRẠNG THÁI FSM)

Để dễ hình dung về thuật toán điều khiển của FSM, chúng ta hãy coi SDRAM như một Đại Hồ Thủy Điện, W-FIFO là Hồ Thu Thập (chứa nước từ Suối Camera), R-FIFO là Tháp Phân Phối (cấp nước cho Khu Dân Cư VGA). Dưới đây là "bút ký" làm việc của Bác Gác Đập (FSM):

**I. TRONG CHÒI ĐIỀU HÀNH (Trạng thái `IDLE`)**
Bác gác đập ngồi trong chòi. Trên bàn làm việc có một cái **Đèn Báo Động Đỏ** (`vsync_req`), bên trái là thước đo mực nước của **Tháp Phân Phối** (`r_fifo_count`), bên phải là thước đo của **Hồ Thu Thập** (`w_fifo_count`). Bác làm việc theo nguyên tắc sinh tử sau:

*   **Lệnh Bài Tuyệt Đối: Đèn Báo Động Đỏ rực sáng (`vsync_req == 1`)**
    Đèn đỏ báo hiệu ngày hôm nay đã kết thúc, Khu dân cư đã xài xong một chu kỳ nước. Bác gác đập lập tức kéo cần **Xả Đáy Tháp** (`r_fifo_clear <= 1`) để sục rửa cặn. Sau đó, Bác đưa cả **Tuabin Hút** và **Tuabin Bơm** về lại độ sâu xuất phát (`read_addr` và `write_addr` = 0). Xong xuôi, Bác tự tay đập tắt Đèn Đỏ (`vsync_req <= 0`) và tiếp tục ngồi chờ.
*   **Ưu tiên Số 1: Dự Trữ Nước (`r_fifo_count <= 768`)**
    Nếu Tháp Phân Phối (sức chứa 1024) vừa tụt xuống đủ chỗ trống để chứa đúng 1 mẻ bơm (1024 - 256 = 768), Bác phải bơm bù ngay lập tức! Bác không bao giờ được phép để Tháp cạn kiệt, vì nếu Bác bận rộn với Tuabin Bơm, Khu dân cư sẽ chết khát (Underflow). Bác đóng van xả đáy lại (`r_fifo_clear <= 0`), cầm chìa khóa phóng ra đập để vận hành quy trình Hút Nước (`ASSERT_READ`).
*   **Ưu tiên Số 2: Cứu Tràn (`w_fifo_count >= 256`)**
    Nếu Tháp Phân Phối vẫn đủ nước, nhưng Hồ Thu Thập từ Suối đã đầy dềnh lên, Bác phải xả bớt nước vào Đại Hồ SDRAM để tránh tràn. Bác phóng ra đập chạy quy trình Bơm Nước (`FETCH_W_FIFO_1`).

**II. QUY TRÌNH HÚT NƯỚC LÊN THÁP (`READ`)**
*   **Mở Cửa Cống (`ASSERT_READ`):** Bác định vị đầu vòi của Tuabin Hút vào cái Bể đang được chốt là Thành phẩm (`bank_read`) và hạ vòi xuống đúng độ sâu hiện tại (`read_addr`). Bác nhấn nút Kích hoạt Tuabin (`sys_read_req <= 1`), lùi lại chờ đợi (`WAIT_READ`).
*   **Chờ Tuabin Gầm Rú (`WAIT_READ`):** Bác thả tay khỏi nút bấm (`sys_read_req <= 0`). Tuabin tự động hút chính xác 256 khối nước đẩy lên Tháp. Khi cỗ máy xả tiếng hơi dài báo hoàn tất (`sys_ready == 1`), Bác ghi sổ hạ độ sâu của Tuabin Hút xuống thêm 256 nấc (`read_addr <= read_addr + 256`), rồi lững thững quay về Chòi (`IDLE`).

**III. QUY TRÌNH BƠM NƯỚC VÀO ĐẠI HỒ (`WRITE`)**
*   **Mồi Nước (`FETCH_1` và `FETCH_2`):** Bác phải tự tay vặn van xả đáy của Hồ Thu Thập đúng 1 tích tắc (`w_fifo_rd_en <= 1` ở `FETCH_1`, rồi vặn đóng lại `= 0` ở `FETCH_2`) để khối nước đầu tiên tứa ra nằm ngoan ngoãn chờ tại miệng cống.
*   **Mở Cửa Nạp (`ASSERT_WRITE`):** Bác định vị đầu vòi của Tuabin Bơm vào Bể đang hứng nước (`bank_write`) và hạ vòi xuống đúng độ sâu hiện tại (`write_addr`). Bác nhấn nút Yêu cầu Nạp (`sys_write_req <= 1`) và lùi lại (`WAIT_WRITE`).
*   **Bơm Nhịp Nhàng (`WAIT_WRITE`):** Bác thả tay khỏi nút nạp (`sys_write_req <= 0`). Ở bên trong, cỗ máy SDRAM khổng lồ vẫy tay gọi: *"Đưa nước đây!"* (`sys_wr_ack == 1`). Cứ mỗi lần nghe tiếng gọi đó, Bác lại nhịp nhàng gạt van Hồ Thu Thập đúng 1 lần (`w_fifo_rd_en <= sys_wr_ack`) để rỏ xuống đúng 1 khối nước. Hai bên phối hợp bóp - nhả cho đến khi cỗ máy nuốt đủ 256 khối nước (`sys_ready == 1`). Bác vặn khóa cứng van xả lại (`w_fifo_rd_en <= 0`), hạ độ sâu Tuabin Bơm xuống 256 nấc (`write_addr <= write_addr + 256`), quệt mồ hôi trán và quay về Chòi (`IDLE`).
