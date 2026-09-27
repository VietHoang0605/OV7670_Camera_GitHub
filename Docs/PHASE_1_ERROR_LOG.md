# NHẬT KÝ SỬA LỖI CHẶNG 1 - HIỆN TƯỢNG MÀN HÌNH RÁC VÀ "CÁI BỒN NƯỚC KHÔNG PHAO"

## 1. Hình ảnh hiện tượng
![Lỗi nhiễu rác chặng 1](/C:/Users/ADMIN/.gemini/antigravity/brain/f70173ee-de75-4c0f-9230-f9c5a93ddc97/.user_uploaded/media_1789806150394.jpg)
*(Miêu tả: Màn hình hiển thị nhiễu hạt sọc ngang, có đường cắt dọc ở giữa X=320, hình ảnh tĩnh không thay đổi dù che hay mở camera).*

## 2. Nguyên nhân gốc rễ (Lỗi Logic Trọng tài & Khởi động Camera)
Dự án gặp phải 2 vấn đề nghiêm trọng chạy song song:

- **Lỗi 1 (Camera chết lâm sàng):** 
  Cấp nguồn xong, vi mạch FPGA chạy quá nhanh, bắn lệnh cấu hình SCCB (I2C) ngay lập tức. Kết quả là Camera không kịp khởi động, chưa sẵn sàng nhận lệnh nên đã "bỏ qua" toàn bộ cấu hình.
  
- **Lỗi 2 (Treo máy trạng thái Arbiter do mất phao đo):** 
  Sử dụng nhầm module `async_fifo` cho R-FIFO (Read FIFO từ SDRAM ra VGA). Vì module `async_fifo` này không có cổng `count` xuất ra, dây tín hiệu `r_fifo_count` bị bỏ lửng (Floating = 0).

## 3. Mô hình Trừu tượng (Mạng Lưới Bơm Nước)
Hãy tưởng tượng hệ thống FPGA của chúng ta là một mạng lưới cấp nước:

- **SDRAM:** Là một cái Hồ Chứa Nước khổng lồ ở giữa.
- **Camera:** Là dòng suối liên tục chảy nước thô vào. Nước này được hứng tạm vào cái Xô Đầu Vào (W-FIFO).
- **Màn hình VGA:** Là một khu dân cư tiêu thụ nước liên tục không ngừng nghỉ. Nước cấp cho dân được chứa trong một cái Tháp Nước Đầu Ra (R-FIFO).
- **SDRAM Arbiter:** Là Bác Gác Đập (Trọng tài). Bác này đứng ở giữa, tay cầm van xả và phải làm cùng lúc 2 nhiệm vụ:
  - Nhiệm vụ 1: Bơm nước từ Hồ Chứa (SDRAM) lên Tháp Nước (R-FIFO) để dân (VGA) có nước xài.
  - Nhiệm vụ 2: Hút nước từ Xô Đầu Vào (W-FIFO) đổ vào Hồ Chứa (SDRAM) để cất trữ ảnh từ Camera.

**Luật làm việc của Bác Gác Đập rất rõ ràng:** Ưu tiên số 1 là dân không được chết khát (VGA mất dữ liệu là xé hình ngay). Bác ấy phải nhìn vào cái phao đo mực nước (`count`) trên Tháp Nước R-FIFO.
- Nếu nước trong Tháp cạn (dưới 768 lít): Bác ấy cuống cuồng bơm nước từ Hồ lên Tháp.
- Nếu nước trong Tháp đã đầy (trên 768 lít): Dân đã đủ nước xài tạm, Bác ấy mới thảnh thơi quay sang hút nước từ Camera đổ vào Hồ.

💥 **Bi kịch của lỗi sọc rác vừa rồi:**
Lúc trước, Agent 2 đã xây cho khu dân cư một cái Tháp Nước loại `async_fifo`. Đặc điểm của cái tháp này là kín bưng, KHÔNG HỀ CÓ phao đo mực nước (`count` bị bỏ trống). Vì không có dây tín hiệu báo về, Bác Gác Đập luôn nhìn thấy thông số "Mực nước = 0". Bác ấy hoảng loạn tột độ, tưởng dân đang chết khát, nên dành 100% thời gian để bơm nước từ Hồ (SDRAM) lên Tháp (VGA). Bác ấy không bao giờ dám quay lưng lại để múc nước từ suối Camera! 
Hậu quả: Camera chảy bao nhiêu nước đều bị vứt bỏ, Hồ chứa SDRAM thì không có giọt nước mới nào, chỉ chứa toàn bùn đất cặn bã từ lúc mới xây (dữ liệu rác lúc cấp nguồn). Khu dân cư VGA thì bị ép uống cái bùn đất đó -> Sinh ra màn hình nhiễu sọc!

## 4. Tại sao lại đem fifo_sync trở lại?
- **Khôi phục Phao Đo Mực Nước (`count`):** Module `fifo_sync` là một cái tháp nước "thông minh" có tích hợp sẵn chân `count` báo mực nước chính xác theo từng chu kỳ. Khi lắp nó vào, Bác Gác Đập (Arbiter) thấy được mức nước thực tế, biết lúc nào tháp đã đầy để yên tâm quay sang xử lý data cho Camera.
- **Về mặt thiết kế Clock:**
  - Cái Xô Đầu Vào (W-FIFO) BẮT BUỘC phải dùng `async_fifo` vì nước từ suối Camera chảy vào theo nhịp riêng (`cam_pclk`), còn Bác Gác Đập làm việc theo nhịp của Hồ (`clk_50m`).
  - Nhưng cái Tháp Nước Đầu Ra (R-FIFO) thì khác! Bác Gác Đập bơm nước vào Tháp bằng nhịp `clk_50m`, và khu dân cư VGA cũng rút nước ra bằng chính nhịp `clk_50m` (có chốt cửa `vga_ce`). Vì Đầu Vào và Đầu Ra chạy cùng một nhịp (Đồng bộ - Sync), chúng ta không cần dùng `async_fifo` phức tạp, mà dùng `fifo_sync` là chuẩn bài toán nhất, vừa nhẹ logic, vừa có sẵn biến `count`.
