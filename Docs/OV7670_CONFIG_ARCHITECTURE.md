# BẢN CHẤT KHỐI CẤU HÌNH (OV7670_CONFIG): SOFT-ROM VÀ REGISTERS

Tài liệu này đính chính và làm rõ bản chất vật lý của khối cấu hình Camera OV7670, phân biệt rõ ràng giữa "ROM của FPGA" và "Registers của Camera".

## 1. Soft-ROM trên FPGA (Băng đạn / Cuốn kịch bản)

Khối ROM trong file `ov7670_config.v` **KHÔNG PHẢI** là một con chip nhớ ROM vật lý (Hard-ROM) bị nung chết. 

Thực chất, nó là **Soft-ROM** - một mạng lưới các cổng Logic (LUTs) được phần mềm Quartus tổng hợp tự động từ lệnh `case (rom_index)`.
*   **Ví von:** Nó giống như một **"Băng Đạn"** chứa 200 viên (các lệnh cấu hình).
*   **Đặc quyền của FPGA:** Sếp hoàn toàn có quyền sửa đổi mã lệnh (từ RGB565 sang YUV, từ VGA sang QVGA) chỉ bằng cách gõ lại mã Hex trên bàn phím và bấm Compile. FPGA sẽ lập tức đập bỏ ROM cũ và đấu nối lại thành một chiếc ROM mới ngay trên bo mạch.

## 2. Registers của Camera (Bảng công tắc điều khiển)

Chúng ta **KHÔNG THỂ** ghi đè lệnh vào ROM của Camera (vì đó là đồ chết do nhà máy đúc). Đích đến thực sự của mã I2C là các **Thanh Ghi (Registers)** bên trong Camera.

*   **Ví von:** Thanh ghi giống như một **"Bảng Công Tắc Điện"** khổng lồ bên trong Camera.
*   **Hoạt động:** Mỗi khi FPGA gửi 1 mã lệnh (VD: `16'h1280`), thực chất nó đang dò tìm đến công tắc số `0x12` (thanh ghi COM7) và gạt giá trị của công tắc đó thành `0x80` (lệnh Reset).

## 3. Bức Tranh Toàn Cảnh (Chu trình nạp đạn 4 bước)

Để hiểu luồng đi của dữ liệu từ FPGA sang Camera, hãy nhớ quy trình "nã đạn" sau:

1. **Lò xo (`rom_index`):** Đẩy từng viên đạn (mã lệnh 16-bit) từ dưới đáy Soft-ROM lên nòng.
2. **Băng đạn (Soft-ROM FPGA):** Nơi chứa kịch bản/danh sách mã Hex chờ sẵn.
3. **Người bóp cò (Khối FSM):** Gắp viên đạn 16-bit, đẩy vào nòng súng và giật cò (`i2c_start`).
4. **Đường đạn bay (`i2c_master` & Dây SDA/SCL):** Truyền tín hiệu I2C bay sang Camera. Đập trúng các **Thanh ghi (Registers)** để gạt công tắc kích hoạt hệ thống!

> *Nhận định từ Sếp:* "Mình sẽ dùng cái khối config này để bắn từng mã lệnh vào trong camera nhằm kích hoạt nó." -> Cực kỳ chuẩn xác, chỉ cần thay chữ "ROM camera" thành "Registers camera"!
