# Lý thuyết nền tảng Camera OV7670

Tài liệu này tổng hợp các kiến thức cốt lõi về cấu trúc và giao thức hoạt động của Camera OV7670.

## 1. Bản đồ 18 chân thực tế
Camera OV7670 thường giao tiếp qua một header 18 chân, bao gồm:
- **Nguồn:** `3.3V` và `GND`.
- **Giao thức điều khiển (I2C/SCCB):** `SCL` (Clock) và `SDA` (Data).
- **Đồng bộ hóa hình ảnh (DVP):** `VS` (VSYNC - Khung hình mới), `HS` (HREF - Dòng dữ liệu mới), `PCLK` (Pixel Clock - Nhịp đẩy dữ liệu).
- **Xung nhịp cung cấp:** `MCLK` (Xung nhịp đầu vào cấp cho Camera hoạt động, thường là 24MHz hoặc 25MHz).
- **Dữ liệu điểm ảnh:** `D0` đến `D7` (Bus dữ liệu 8-bit).
- **Chân trạng thái:** `RST` (Reset) và `PWNN` (Power Down).

## 2. Tầm quan trọng của RST và PWNN
Đây là hai chân thường gây "đau đầu" nếu không được xử lý đúng cách trong thiết kế phần cứng:
- **RST (Reset):** Cần được kéo lên mức cao (`3.3V`) trong quá trình hoạt động bình thường. Nếu thả nổi hoặc kéo xuống GND, module camera sẽ ở trạng thái Reset và không phản hồi bất kỳ giao tiếp nào.
- **PWNN (Power Down):** Chân này quyết định chế độ hoạt động của cảm biến. Nó cần được kéo xuống `GND` để camera hoạt động ở chế độ bình thường (Active mode). Nếu kéo lên cao, camera sẽ đi vào chế độ ngủ (Sleep/Power Down).

## 3. Giao thức cấu hình I2C/SCCB và cạm bẫy "Hội chứng gọi điện sớm"
OV7670 sử dụng chuẩn SCCB (Serial Camera Control Bus), bản chất hoàn toàn tương thích với I2C để cấu hình các thanh ghi nội bộ (độ sáng, cân bằng trắng, định dạng màu...).

**Cạm bẫy "Hội chứng gọi điện sớm":** 
Sau khi cấp nguồn và nhả Reset (RST lên mức cao), cảm biến OV7670 cần một khoảng thời gian trễ nhất định (từ vài ms đến vài chục ms) để ổn định các dao động mạch và khởi tạo hệ thống nội bộ. Nếu vi điều khiển hay FPGA lập tức gửi lệnh I2C/SCCB ngay lúc vừa khởi động, camera sẽ phớt lờ và không trả về tín hiệu `ACK`. Cần phải đưa vào một bộ định thời (Delay) để chờ camera thực sự sẵn sàng trước khi cấu hình thanh ghi.

## 4. Giao thức DVP và Clock Domain Crossing (CDC)
**DVP (Digital Video Port):**
DVP là giao thức xuất luồng video song song, dựa trên 3 tín hiệu đồng bộ chính:
- `VSYNC`: Chuyển trạng thái khi bắt đầu một khung hình (frame) mới.
- `HREF`: Mức cao khi dữ liệu trên bus D0-D7 đang là dữ liệu ảnh hợp lệ của một hàng ngang.
- `PCLK`: Xung nhịp điểm ảnh, mỗi cạnh lên của PCLK chốt một byte dữ liệu hợp lệ.

**Ghép 2 byte RGB565:**
Để hiển thị chuẩn màu RGB565 (16-bit), mỗi điểm ảnh sẽ được truyền qua 2 chu kỳ PCLK. Byte đầu tiên (High Byte) chứa 5 bit Đỏ (Red) và 3 bit Xanh lục (Green). Byte thứ hai (Low Byte) chứa 3 bit Xanh lục còn lại và 5 bit Xanh lam (Blue). FPGA cần có thanh ghi dịch (Shift Register) để gom 2 byte 8-bit này thành 1 từ dữ liệu 16-bit.

**Vấn đề Clock Domain Crossing (CDC):**
Dữ liệu và các tín hiệu đồng bộ (`VSYNC`, `HREF`) đi ra từ camera chạy trên nền xung `PCLK`. Trong khi đó, mạch xử lý bên trong hệ thống (như bộ lưu trữ RAM, bộ điều khiển VGA/HDMI trên FPGA) thường chạy bằng một xung nhịp khác (ví dụ: `clk_50M`). Sự khác biệt về tần số và pha này dẫn đến bài toán Clock Domain Crossing. Nếu không xử lý đúng (sử dụng FIFO không đồng bộ - Async FIFO, hoặc các kỹ thuật đồng bộ 2-stage Flip-Flop), hệ thống sẽ gặp phải lỗi Metastability, dẫn đến rác hình ảnh hoặc mất tín hiệu.
