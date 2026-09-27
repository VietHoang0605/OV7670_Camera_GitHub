# 📓 NHẬT KÝ DỰ ÁN: CAMERA OV7670 + SDRAM + VGA

Đây là cuốn Nhật ký (Master Journal) được Cô Thư ký Agent 7 ghi chép và cập nhật liên tục theo tiến độ của dự án. Đi đến đâu, chốt đến đó! Các Keyword đắt giá được lưu giữ cẩn thận để lắp ghép cho Bức tranh Báo cáo HTML/Markdown cuối cùng.

---

## 🟢 GIAI ĐOẠN 1: THẤU HIỂU LÝ THUYẾT & CHUẨN BỊ VŨ KHÍ (Đã Hoàn Thành)
*   **[x] Phân tích 18 chân phần cứng:** Đã xác định rõ `MCLK (24MHz)`, `RST (ghim 3.3V)`, `PWNN (ghim GND)` để tránh lỗi chết lâm sàng.
*   **[x] Phân biệt 2 luồng dữ liệu:**
    *   **Luồng Điều khiển (I2C/SCCB):** Dùng 2 dây `SCL`, `SDA` chạy 400kHz. Đóng vai trò "Điều khiển Tivi".
    *   **Luồng Hình ảnh (DVP):** Dùng 8 dây song song `D[7:0]` cùng `PCLK`, `HREF`, `VSYNC`. Đóng vai trò "Cáp HDMI".
*   **[x] Giải quyết giới hạn vật lý I2C:** Hiểu rõ giới hạn RC của Open-Drain, sử dụng kỹ thuật Oversampling 4x.

## 🟢 GIAI ĐOẠN 2: THIẾT KẾ KHỐI ĐIỀU KHIỂN CẤU HÌNH (Đã Hoàn Thành)
*   **[x] Tái sử dụng lõi IP:** Port thành công khối `i2c_master` và `i2c_clk_gen` từ dự án Audio.
*   **[x] Thiết kế FSM One-Shot Config:** Đã hoàn thiện file `ov7670_config.v`.
*   **[x] Sửa 5 lỗi FSM kinh điển:** Đã xử lý triệt để các lỗi: Nhầm lẫn phép gán Blocking/Non-blocking (`=` vs `<=`), lỗi FSM Deadlock (kẹt trạng thái), kẹt cờ điều khiển `i2c_start`, và Multi-driven Net. Bài học đắt giá: FSM cấu hình phải được "chốt hạ" ở `STATE_DONE` (Nguyên lý One-shot).

## 🟡 GIAI ĐOẠN 3: THIẾT KẾ KHỐI HỨNG ẢNH DVP CAPTURE (Đang Tiến Hành)
*   **[x] Khai mở lý thuyết Data Flow & I/O:** Chốt sổ nguyên lý *"Trạm đóng gói kẹo 16-gram từ 2 viên 8-gram"* vô cùng trực quan.
*   **[x] Phân tích Timing DVP:**
    *   `PCLK CDC (Clock Domain Crossing)`: Kỹ thuật vượt rào xung nhịp mượt mà. Khối DVP phải bám sát nhịp 24MHz của camera, độc lập hoàn toàn với 50MHz FPGA.
    *   `VSYNC`: Dùng sườn xuống để chốt/reset Frame chống lỗi lệch byte.
*   **[x] Chiến lược Tái sử dụng IP Core:** Một nước đi chiến thuật tuyệt vời! Đã chốt phương án tái sử dụng lại 90% Backend từ các dự án trước: Dùng `sdram_controller.v` & `vga_sync.v` (từ `project_2_SDRAM_VGA`) làm kho chứa Frame Buffer khổng lồ, và dùng `async_fifo.v` (từ `Day8_AsyncFIFO`) làm trạm trung chuyển chống tràn.
*   `[ ]` Viết sườn (scaffold) và logic code cho file `ov7670_capture.v`.
*   `[ ]` Đấu nối khối Capture với Async FIFO và SDRAM Controller.

## ⚪ GIAI ĐOẠN 4: LẮP RÁP HỆ THỐNG & TEST PHẦN CỨNG
*   `[ ]` Lập Pin Planner (Gán chân GPIO).
*   `[ ]` Chạy Simulation với Agent 3.
*   `[ ]` Nạp board mạch DE1 thực tế và debug.
