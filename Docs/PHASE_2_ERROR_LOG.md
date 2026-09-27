# BÁO CÁO KỸ THUẬT CHẶNG 2: NGHẼN BĂNG THÔNG GHI SDRAM & BẢN ĐỒ SỬA CHỮA HỆ THỐNG

## 1. Hình ảnh thực tế chặng 2
![Kết quả thực tế chặng 2](/C:/Users/ADMIN/.gemini/antigravity/brain/f70173ee-de75-4c0f-9230-f9c5a93ddc97/.user_uploaded/media_1789806907093.jpg)
- **Hiện trạng quan sát:** 
  - Khoảng **1/3 màn hình phía trên** (~160 - 180 dòng quét) đã hiển thị tín hiệu thực tế từ ống kính Camera (có phân vùng sáng tối thực của trần nhà/phòng làm việc).
  - Tuy nhiên, hình ảnh bị **nhiễu sọc ngang rất nặng, xé hình và ám sắc tím**.
  - **2/3 màn hình phía dưới** vẫn trơ trơ dải nhiễu tĩnh mặc định của chip SDRAM.

---

## 2. Minh chứng đối chiếu: Tại sao Project Đọc Ảnh (UART) chạy được mà Project Camera lại gãy?

Để minh định rõ ràng vì sao hệ thống SDRAM hiện tại bị coi là đang chạy ở chế độ **Single Write**, chúng ta hãy trích xuất trực tiếp code gốc từ `D:\FPGA\Projects\project_2_SDRAM_VGA\SDRAM_VGA_final`:

### Bằng chứng code gốc trong `sdram_controller.v`:
Tại dòng 134-135 của file gốc Project 2:
```verilog
// Mode: CAS=3, Read=Full Page, Write=Single Access (Bit 9 = 1)
sdram_addr <= 12'h237; 
```
Và tại dòng 203-204:
```verilog
WRITE_DATA: begin
    // Write là Single Access
```
> **Ý nghĩa phần cứng:** Chuẩn JEDEC của chip SDRAM quy định: Khi nạp Mode Register với **Bit 9 = 1** (giá trị `12'h237`), SDRAM được thiết lập ở chế độ **"Burst Read & Single Write"**. Nghĩa là: **Chỉ có chiều ĐỌC (ra VGA) là chạy Burst 256, còn chiều GHI vẫn là ghi từng từ đơn lẻ (Single Access)!**

### Bảng so sánh tương quan tốc độ giữa 2 Project:

| Tiêu chí so sánh | Project 2: Đọc ảnh qua UART | Project 3: Camera OV7670 | Nhận xét chênh lệch |
| :--- | :--- | :--- | :--- |
| **Nguồn phát dữ liệu** | Cổng UART máy tính (115.200 baud) | Cảm biến ảnh OV7670 (PCLK ~24MHz) | Bản chất nguồn phát |
| **Tốc độ sinh điểm ảnh** | $\approx 5.760$ pixel / giây | $\approx 12.500.000$ pixel / giây | **Camera bắn nhanh gấp 2.170 lần UART!** |
| **Thời gian giữa 2 pixel** | $\approx 173.600\,\text{ns}$ ($173,6\,\mu\text{s}$) | $\approx 80\,\text{ns}$ | Khoảng cách dòng dữ liệu |
| **Cơ chế ghi SDRAM** | Single Write ($200\,\text{ns}$ / pixel) | Single Write ($200\,\text{ns}$ / pixel) | Tái sử dụng nguyên vẹn từ Project 2 |
| **Tương quan Băng thông** | SDRAM ghi **nhanh gấp 868 lần** UART | SDRAM ghi **chậm hơn 2,5 lần** Camera! | **Điểm nghẽn chí tử xuất hiện!** |
| **Trạng thái Bồn W-FIFO** | Luôn rỗng (vừa có pixel là ghi ngay) | **Tràn bồn liên tục (`wfull = 1`)** | Vỡ trận bồn đệm |
| **Kết quả hiển thị** | Ảnh tĩnh mượt mà, đủ khung hình | Chỉ ghi kịp 1/3 khung hình + xé sọc | 2/3 dưới là rác tĩnh |

---

## 3. Phân tích 2 câu hỏi kỹ thuật của Sếp

### Câu hỏi 1: Tại sao chỉ bơm được ~1/3 màn hình?
- **Thời gian 1 khung hình Camera (30 fps):** $33,3\,\text{ms}$.
- **Thời gian VGA đọc chiếm bus SDRAM:** Khoảng $6,4\,\text{ms}$ (ưu tiên cao hơn để không mất đồng bộ hiển thị).
- **Thời gian còn lại để ghi:** $33,3\,\text{ms} - 6,4\,\text{ms} = 26,9\,\text{ms}$.
- **Tốc độ ghi Single Access:** Mỗi pixel tốn 10 chu kỳ xung 50MHz ($200\,\text{ns}$).
- **Số pixel tối đa ghi kịp:** $\frac{26,9\,\text{ms}}{200\,\text{ns}} \approx 134.500\,\text{pixel}$.
- **Tỷ lệ khung hình:** $\frac{134.500}{307.200} \approx \mathbf{43,7\%}$ (Gần đúng 1/3 đến 2/5 chiều cao màn hình, khoảng 180 dòng đầu).
- **Lý do bị cắt ngang:** Hết $33,3\,\text{ms}$, Camera phát xung `vsync_falling` kết thúc khung. Lệnh `write_addr <= 0` trong Arbiter lập tức giật con trỏ về đỉnh màn hình để vẽ khung mới. Con trỏ ghi **chưa bao giờ kịp chạm tới 2/3 diện tích phía dưới**.

### Câu hỏi 2: Tại sao hình ảnh lại bị nhiễu sọc ngang rất nặng?
1. **Tràn bồn W-FIFO gây vứt bỏ pixel:** Nước vào bồn nhanh gấp 2,5 lần nước múc ra. Sau 2-3 dòng quét, W-FIFO bị đầy tràn. Mạch logic bắt buộc phải thả trôi (drop) các pixel tiếp theo.
2. **Sụp đổ đồng bộ trục ngang (H-Sync Desynchronization):** Khi bị rớt điểm ảnh, vị trí tọa độ của dòng này bị thụt lùi và tràn sang dòng khác, khiến các đường quét bị xé toạc theo phương ngang, tạo thành các vệt sóng gợn và sọc chuyển động liên tục.
3. **Nhiễu hạt cảm biến:** Thiếu sáng trong phòng kích hoạt AGC của OV7670 đẩy Gain lên cực đại, cộng thêm việc rớt byte làm sai lệch hệ màu RGB565 sinh ra sắc tím.

---

## 4. BẢN ĐỒ SỬA CHỮA HỆ THỐNG (SYSTEM REPAIR BLUEPRINT)

Để biến chiều GHI thành **Burst Write (256 Words)** tương đương với chiều ĐỌC, hệ thống sẽ được nâng cấp theo sơ đồ sau:

```
[Camera OV7670] 
       │ (1 pixel / 80ns)
       ▼
[ W-FIFO (async_fifo) ] ── (Thêm cổng rcount báo mực nước ở miền 50MHz)
       │
       │ (Khi rcount >= 256 words: Phát lệnh BURST WRITE)
       ▼
[ SDRAM Arbiter ] ─────── (Bắn 1 gói 256 words liên tục)
       │
       ▼
[ SDRAM Controller ] ──── (Chuyển Mode Register sang 12'h037 - Burst Write)
       │
       ▼ (Tốc độ ghi tăng vọt lên 50 MWords/s: 1 pixel / 20ns!)
[ Chip nhớ SDRAM ] ────── Ghi xong cả khung 640x480 chỉ mất 6,5ms!
```

### Chi tiết các bước thực hiện:

1. **Module `rptr_empty.v` & `async_fifo.v`:**
   - Xây dựng mạch giải mã Gray-to-Binary để chuyển `rq2_wptr` thành nhị phân.
   - Tính toán `rcount = wptr_bin - rbin_reg` (mực nước khả dụng của W-FIFO ở miền 50MHz).
   - Xuất cổng `output wire [10:0] rcount`.

2. **Module `sdram_controller.v`:**
   - Cấu hình lại Mode Register: Đổi `12'h237` (Single Write) $\rightarrow$ `12'h037` (Full Page / Programmed Burst Write).
   - Thiết kế trạng thái `WRITE_STREAM`: Bơm liên tục 256 pixel trong 256 nhịp xung nhịp (chỉ mất $5,12\,\mu\text{s}$ cho một khối 256 pixel thay vì $51,2\,\mu\text{s}$ như trước).

3. **Module `sdram_arbiter.v`:**
   - Thay đổi điều kiện ghi: Không ghi nhắt gừng từng pixel khi `!w_fifo_empty` nữa, mà chờ `w_fifo_count >= 256` mới kích hoạt 1 Burst Ghi.
   - Tăng địa chỉ theo khối: `write_addr <= write_addr + 256`.

4. **Module `ov7670_top.v`:**
   - Nối chân `rcount` từ `u_w_fifo` sang `w_fifo_count` của `u_sdram_arbiter`.
