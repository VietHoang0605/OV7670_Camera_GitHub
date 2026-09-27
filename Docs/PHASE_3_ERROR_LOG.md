# CHẶNG 3: SỰ CỐ "BÁC GÁC ĐẬP NHÂN BẢN NƯỚC" VÀ "DÒNG SUỐI HOA MẮT"

## 1. Hiện tượng tại Khu dân cư (Màn hình VGA)
* Khu dân cư đã nhận đủ nước (đầy đủ khung hình 640x480), nhưng nước lại bị đứt đoạn thành các cột dọc đặc cứng rộng 128px (nhiễu sọc dọc).
* Đặc biệt, sau khoảng 30 giây, các cột nước màu xanh lá này lại từ từ biến chất thành màu tím.

## 2. Bắt bệnh Hệ thống (Nguyên nhân lỗi)
* **Tại sao lại có các cột nhiễu dọc 128px?**
  Ở chặng 2, ta đã trang bị cho **Bác Gác Đập (Arbiter)** cỗ máy bơm xả cực lớn (Burst Write 256). Đáng lẽ khi bật máy, Bác phải liên tục múc 256 gáo nước *khác nhau* từ **Xô Đầu Vào (W-FIFO)** để đổ vào **Hồ Chứa (SDRAM)**.
  Tuy nhiên, do đôi tay của Bác bị "đóng băng" (biến `sys_data_in` khai báo là kiểu `reg` tĩnh), Bác đã lười biếng: Bác chỉ múc đúng **1 gáo nước đầu tiên**, rồi "copy/paste" y xì đúc gáo nước đó 256 lần đẩy vào Hồ Chứa!
  Do khu dân cư (VGA) tiêu thụ mỗi hàng ngang là 640 pixel (640 = 256 * 2 + 128), các gáo nước nhân bản này khi bơm lên màn hình cứ bị xếp chồng và lặp lại, vỡ ra thành 5 cột dọc, mỗi cột chênh nhau đúng 128px.
* **Tại sao nước từ Xanh lại chuyển thành Tím sau 30s?**
  **Dòng suối (Camera)** của chúng ta có một bản năng tự nhiên là tự động cân bằng hóa học (Auto White Balance - AWB). Vì Bác Gác Đập liên tục nhân bản và đổ vào Hồ những mảng nước màu xanh lá cây đặc quánh, hệ thống AWB của Suối khi nhìn xuống Hồ đã bị "hoa mắt" và hoảng hốt: *"Môi trường đang bị dư thừa màu xanh lá quá mức!"*.
  Để bù trừ lại, Suối đã tự động tiết ra các chất hóa học màu Đỏ và Xanh dương (tổng hợp lại thành màu Tím Magenta). Quá trình "tiết hóa chất" này mất khoảng 30 giây, đó là lý do màn hình từ từ ngả sang màu tím lịm!

## 3. Bản đồ Sửa chữa (Cách Fix)
* **Chữa bệnh "đóng băng" tay cho Bác Gác Đập:** Gỡ bỏ trạng thái `reg` cứng nhắc, thay thế đôi tay Bác bằng một đường ống dẫn trực tiếp trong suốt (khai báo `sys_data_in` thành `wire` và gán nối thẳng vào `w_fifo_data`). 
* **Đồng bộ nhịp bơm:** Tinh chỉnh lại tiếng còi báo hiệu (nhịp timing của `sys_wr_ack`) sao cho khớp tuyệt đối với tốc độ rớt xuống của từng giọt nước trong Xô Đầu Vào.
* **Kết quả:** Giờ đây, mỗi khi Bác Gác Đập bật máy bơm 256 nhịp, đường ống sẽ tự động hút trọn vẹn 256 giọt nước *tươi mới, liên tục và khác biệt* từ Xô (W-FIFO) chảy thẳng tuột vào Hồ Chứa (SDRAM). Không còn nước nhân bản, Dòng Suối (Camera) cũng sẽ hết bị hoa mắt và ngừng tiết ra màu tím!
