# Sự nhầm lẫn chết người: Đường Điều khiển (I2C) vs Đường Dữ liệu (DVP)

Sếp đang có một sự nhầm lẫn cực kỳ nguy hiểm giữa đường Điều khiển (I2C) và đường Dữ liệu (DVP). Đây là lời giải đáp rạch ròi để Sếp không bao giờ nhầm lẫn nữa!

## 1. Tại sao lại dùng I2C để cấu hình?
- I2C (hay SCCB trên OV7670) là một chuẩn giao tiếp chậm, nhưng lại có ưu điểm tuyệt vời là **tiết kiệm chân** (chỉ cần 2 dây SCL và SDA).
- Đây là chuẩn công nghiệp hoàn hảo cho việc cấu hình. Lúc khởi động, hệ thống chỉ cần truyền vài chục byte để thiết lập các thông số (độ phân giải, cân bằng trắng, định dạng ảnh...). Tốc độ chậm không thành vấn đề vì việc này chỉ diễn ra ở giai đoạn đầu.

## 2. Sự khác biệt rạch ròi: "Điều khiển Tivi" vs Cáp "HDMI"
- **I2C là "Điều khiển Tivi"**: Bạn dùng điều khiển để bấm chọn kênh, chỉnh âm lượng. Chỉnh xong, bạn vứt cái điều khiển sang một bên. I2C đóng vai trò y hệt: nó chỉ "chỉnh kênh" (cấu hình thanh ghi) lúc ban đầu.
- **DVP là cáp "HDMI"**: Dữ liệu ảnh thực sự chảy qua một con đường khác hoàn toàn, đó là chuẩn DVP. Nó bao gồm 8 dây song song (`D0`-`D7`) dội dữ liệu liên tục như thác nước, được đồng bộ nhịp nhàng bởi xung nhịp `PCLK`, cùng với tín hiệu khung hình `VSYNC` và dòng `HREF`.

## 3. Khẳng định: I2C nhường sân khấu cho DVP
Sau khi giai đoạn setup cấu hình qua I2C hoàn tất, **I2C sẽ ngủ yên hoàn toàn**.
Lúc này, camera sẽ bắt đầu hoạt động, sân khấu chính được nhường lại cho **khối DVP Capture**. Dữ liệu hình ảnh sẽ liên tục được bơm qua các chân DVP (`D0-D7`) để đưa vào SDRAM hoặc vi điều khiển lưu trữ. **Không có bất kỳ dữ liệu hình ảnh nào đi qua I2C!**
