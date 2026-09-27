# 🗺️ SƠ ĐỒ KHỐI HỆ THỐNG TOÀN DIỆN (FULL SYSTEM TOPOLOGY)

Dưới đây là hình ảnh toàn cảnh hệ thống:
![Sơ đồ khối hệ thống OV7670 - Tối ưu Khoảng cách và Mở rộng Module](SYSTEM_BLOCK_DIAGRAM_FINAL_SPACED.png)

## Chú thích luồng hệ thống:
1. **Luồng Cấu Hình (I2C):** Mạch `ov7670_config` nạp mã từ ROM vào `i2c_master` để thiết lập các thanh ghi Camera (phân giải, màu sắc) ngay sau khi boot.
2. **Luồng Video Thu Nhận:** Camera phun dữ liệu 8-bit. Mạch `ov7670_capture` gom 2 byte thành 1 Pixel 16-bit và đẩy vào ngõ ghi của `W-FIFO` (chạy theo xung 24MHz của camera).
3. **Bộ Đệm Trung Tâm (SDRAM Arbiter):** Đóng vai trò tổng chỉ huy (Gác đập). Arbiter bơm nước (Video data) từ W-FIFO lên SDRAM, đồng thời hút nước từ SDRAM rót vào R-FIFO (chạy theo xung 50MHz).
4. **Luồng Xuất Hình VGA:** Khối `vga_sync` sinh ra tọa độ quét (25MHz). Khi tới vùng hiển thị (video_on), khối DAC hút data từ R-FIFO, tách thành kênh R-G-B xuất ra màn hình vật lý.
5. **Cơ Chế Đồng Bộ:** Mọi thứ được thắt nút bằng tín hiệu `vsync`. Vsync reset hàng loạt các con trỏ địa chỉ, đảm bảo khung hình luôn được quét từ điểm đầu tiên ở góc trên cùng bên trái.
