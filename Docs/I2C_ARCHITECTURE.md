# BÁO CÁO KIẾN TRÚC: LÕI GIAO TIẾP I2C (OVERSAMPLING 4X)

Báo cáo này tổng hợp lại những nguyên lý thiết kế cốt lõi của khối `i2c_master` và `i2c_clk_gen`, giải thích tại sao kiến trúc này đạt chuẩn công nghiệp và an toàn tuyệt đối về mặt định thời (Timing).

---

## 1. Bản chất Vật lý của I2C và Giới hạn Tần số

Dù FPGA (Master) chạy ở xung nhịp hệ thống rất cao (50MHz), ta tuyệt đối không thể ném 50MHz ra đường dây SCL của I2C. Có 2 lý do chí mạng:

1. **Giới hạn của Camera (Slave):** Mạch giải mã SCCB/I2C của phần lớn cảm biến (như OV7670) chỉ hỗ trợ tốc độ tối đa là **400 KHz**. 
2. **Đặc tính Mạch Cực máng (Open-Drain):** Giao thức I2C bắt buộc phải dùng điện trở kéo lên (Pull-up Resistor). Khi FPGA thả dây SCL, điện áp mất một khoảng thời gian đáng kể để "bò" từ 0V lên 3.3V (do hằng số thời gian RC). Nếu chạy ở 50MHz, điện áp chưa kịp nhích lên đã bị dập xuống, dẫn đến tín hiệu bị phẳng lỳ ở 0V.

Do đó, FPGA đóng vai trò như một **Hộp số (Gearbox)**, lấy xung 50MHz đếm chậm lại để gõ nhịp 400 KHz ra đường dây SCL.

---

## 2. Bí kíp "Clock Enable" (Tick 4x) - Tại sao không dùng bộ chia Clock?

Để tạo ra 400 KHz, cách ngây thơ nhất là chia 50MHz ra một xung vuông 400 KHz (Ripple Clock) và dùng nó cấp cho FSM. Tuy nhiên, kỹ thuật này gây ra trễ pha và lỗi Timing trầm trọng. 

Kiến trúc chuẩn công nghiệp giải quyết bằng cách **chia hệ thống thành 2 khối đồng bộ hoàn toàn với 50MHz**:

### Khối `i2c_clk_gen` (Nhạc trưởng)
Khối này đếm xung 50MHz và tạo ra một xung chớp nhoáng (Tick) kéo dài đúng 1 chu kỳ 50MHz. Xung chớp này xuất hiện với tần số nhanh gấp **4 LẦN** tần số I2C cần thiết (ví dụ: I2C là 400KHz thì Tick là 1.6MHz).

### Khối `i2c_master` (Nhạc công)
Bên trong `i2c_master` có một bộ đếm `tick_cnt` chạy từ **0 đến 3**. Mỗi lần nghe tiếng Tick, nó tăng thêm 1. Nhờ chia 1 chu kỳ I2C ra làm 4 phách, Master có thể vẽ ra sóng SCL và chốt dữ liệu SDA một cách an toàn tuyệt đối:

*   **Phách 0 (`tick_cnt == 0`):** Kéo `SCL = 0`. Tín hiệu chạm đáy. Đây là lúc an toàn để Master **thay đổi dữ liệu trên dây SDA**.
*   **Phách 1 (`tick_cnt == 1`):** Kéo `SCL = 1`. Tín hiệu vọt lên đỉnh (Cạnh lên).
*   **Phách 2 (`tick_cnt == 2`):** Giữ `SCL = 1`. Đỉnh điểm của sóng. Dữ liệu SDA lúc này ổn định nhất, không có nhiễu. Đây là **thời điểm vàng để đọc SDA** (VD: đọc bit ACK từ Slave).
*   **Phách 3 (`tick_cnt == 3`):** Kéo `SCL = 0`. Tín hiệu rơi xuống đáy (Cạnh xuống), kết thúc 1 chu kỳ bit.

Nhìn từ bên ngoài, SCL lên xuống như một xung Clock 400KHz. Nhưng nhìn từ bên trong FPGA, SCL chỉ là một chân tín hiệu (Data) đang bật tắt dưới sự kiểm soát của FSM 50MHz.

---

## 3. Phân biệt "Đồng bộ (Synchronous)" và "Bất đồng bộ (Async CDC)"

Khối Hộp số I2C này **KHÔNG** hề sử dụng FIFO Bất đồng bộ (Dual-Clock Async FIFO), và cũng **KHÔNG** xử lý nhiễu đa xung nhịp (Clock Domain Crossing - CDC). 

*   Toàn bộ quá trình tạo sóng SCL đều nằm hoàn toàn trong **"Vương quốc 50MHz"** của FPGA. Thiết kế này là Đồng bộ hoàn toàn (Fully Synchronous).
*   **Khi nào mới cần Async FIFO?** Async FIFO chỉ xuất hiện khi có 2 vương quốc độc lập. Cụ thể trong dự án OV7670 này, Async FIFO sẽ được dùng ở khối **Hứng ảnh (DVP Capture)**, nơi mà xung nhịp `PCLK` (do Camera tự sinh ra) đụng độ với xung nhịp `50MHz` của FPGA. Lúc đó, FIFO đóng vai trò làm bãi đệm triệt tiêu sự lệch pha giữa 2 hệ thống độc lập này.
