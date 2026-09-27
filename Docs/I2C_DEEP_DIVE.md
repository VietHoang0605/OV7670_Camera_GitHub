# Nghệ thuật Thiết kế I2C Deep Dive

Giao thức I2C là một tiêu chuẩn phổ biến, nhưng để triển khai nó trên nền tảng logic số (như FPGA) một cách trơn tru, mạnh mẽ thì lại là một "nghệ thuật" thực sự. Tài liệu này chắt lọc những tư duy cốt lõi về thiết kế I2C Master, đặc biệt là khi giao tiếp với các thiết bị như Camera OV7670.

## 1. Cơ chế 4 Ticks của I2C: Tại sao phải chia làm 4 phách?
Khi viết máy trạng thái (FSM) cho I2C, một kỹ thuật cực kỳ hiệu quả là chia một chu kỳ xung nhịp SCL (I2C Clock) thành **4 phách (4 ticks)**. Thay vì cố gắng thay đổi dữ liệu (SDA) và xung nhịp (SCL) cùng một lúc, chúng ta rải chúng ra:

- **Tick 1 (SDA Change):** Đổi trạng thái dây SDA khi dây SCL đang ở mức thấp. Việc thay đổi SDA lúc SCL thấp đảm bảo tính hợp lệ của dữ liệu (tránh vô tình tạo ra điều kiện Start/Stop).
- **Tick 2 (SCL Rise):** Kéo dây SCL lên mức cao.
- **Tick 3 (SDA Sample/Read):** Đọc giá trị trên dây SDA. Khoảng thời gian từ Tick 2 tới Tick 3 là thời gian SCL duy trì ở mức cao và SDA đã cực kỳ ổn định, là thời điểm hoàn hảo nhất để chốt (latch) dữ liệu từ Slave.
- **Tick 4 (SCL Fall):** Kéo dây SCL xuống mức thấp trở lại, chuẩn bị cho chu kỳ tiếp theo.

Việc chia thành 4 phách tạo ra những khoảng Margin an toàn, tránh vi phạm thời gian Setup (Setup time) và Hold (Hold time), giúp đường truyền cực kỳ bền bỉ kể cả khi nhiễu.

## 2. Nghệ thuật Clock Enable: Ảo giác tốc độ
Nhiều kỹ sư nhầm tưởng rằng để tạo ra I2C 400kHz, họ phải dùng mạch chia xung (Clock Divider/PLL) tạo ra một xung nhịp clock 400kHz độc lập để cung cấp cho module I2C. Điều này dẫn đến sự cố tồi tệ về Clock Domain Crossing (CDC).

**Sự thật về ảo giác tốc độ:** Toàn bộ hệ thống logic I2C Master thực chất vẫn chạy hoàn toàn trên xung nhịp gốc (ví dụ: `50MHz` của hệ thống). Để đáp ứng tốc độ `400kHz` của cảm biến, chúng ta sử dụng một bộ đếm (Counter) liên tục đếm trên nền xung 50MHz. Cứ mỗi `(50MHz / (400kHz * 4))` chu kỳ, bộ đếm sẽ bật một cờ `tick_4x` (chỉ kéo dài trong 1 chu kỳ 50MHz).
Biến `tick_4x` này hoạt động như một cờ Clock Enable. Khối I2C Master luôn lấy clock 50MHz, nhưng chỉ chuyển trạng thái (chuyển sang Tick kế tiếp của I2C) khi `tick_4x` được bật. Việc này đảm bảo logic hoạt động hoàn toàn đồng bộ, an toàn, và chính xác mà không sinh ra một xung clock mới.

## 3. Giao tiếp Handshake (Bắt tay): Mối tình giữa Config và Master
Trong thiết kế cấu hình Camera, chúng ta có khối `OV7670_Config` (chứa các thông số thanh ghi ROM) và khối `i2c_master` (thực thi việc truyền I2C). Khối Config chạy cực kỳ nhanh (mỗi xung 50MHz là 1 bước), trong khi I2C Master mất hàng ngàn xung 50MHz mới truyền xong một byte. Làm sao để chúng làm việc với nhau mà không ách tắc?

Giải pháp nằm ở tín hiệu Handshake (Bắt tay) gồm 2 cờ: `start` và `ready`.
- Khối `i2c_master` bình thường luôn giữ cờ `ready = 1` để thông báo "Tôi rảnh".
- Khối `OV7670_Config` khi cần truyền một lệnh cấu hình, nó đặt dữ liệu lên bus và bật cờ `start = 1` trong đúng 1 chu kỳ clock.
- Ngay khi thấy `start`, `i2c_master` lập tức kéo `ready = 0` (Báo bận) và bắt đầu quá trình truyền tốn thời gian của mình.
- Trong lúc đó, khối `OV7670_Config` nằm chờ (Wait State) cho đến khi `ready` quay trở lại mức `1`.
- Khi truyền xong, `i2c_master` trả `ready = 1`. `OV7670_Config` thấy vậy liền lấy dữ liệu kế tiếp ra và chu kỳ lại tiếp tục.

Nhờ cơ chế Handshake tinh tế này, dữ liệu không bao giờ bị dồn ứ hay mất mát, đảm bảo mọi thanh ghi đều được lập trình tuần tự và trọn vẹn, không hề "lỗi nhịp".
