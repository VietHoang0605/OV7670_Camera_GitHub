# BÁO CÁO KỸ THUẬT CHẶNG 3 - CHIẾN LƯỢC DEBUG BẰNG PHƯƠNG PHÁP CÔ LẬP VÀ PHÂN TÍCH WAVEFORM

## 1. Đặt vấn đề
![Lỗi xé hình và màu Neon](/C:/Users/ADMIN/.gemini/antigravity/brain/f70173ee-de75-4c0f-9230-f9c5a93ddc97/.user_uploaded/media_1789978085169.jpg)

Trong giai đoạn kiểm thử xuất hình, hệ thống gặp phải hiện tượng lỗi hiển thị nghiêm trọng: Hình ảnh xuất ra bị một vết nứt dọc tại cột ~280, khiến nửa trái và nửa phải của màn hình bị đảo lộn vĩnh viễn trên mọi khung hình. Lỗi này xuất hiện ổn định và không tự khắc phục qua các lần quét màn hình tiếp theo, cho thấy đây là một sự sai lệch có tính hệ thống chứ không phải nhiễu ngẫu nhiên. Ngoài ra, hình ảnh còn bị ám màu neon/tím dị thường.

## 2. Phương pháp tiếp cận (Thu hẹp phạm vi - Tối quan trọng)
Thay vì "mò mẫm" thử sai trên phần cứng (vốn tốn thời gian tổng hợp và không xác định được nguyên nhân gốc rễ), chiến lược debug được triển khai với tư duy phân mảnh hệ thống:
* **Cô lập các module:** Tách biệt luồng dữ liệu thành các khối độc lập (Capture, W-FIFO, Arbiter, SDRAM Controller).
* **Mô phỏng chính xác (Cycle-accurate):** Viết Testbench giả lập tín hiệu camera với định dạng DVP và bơm dữ liệu vào hệ thống. Sử dụng ModelSim để soi Waveform đến từng chu kỳ xung nhịp (clock cycle) tại các điểm nút giao tiếp giữa các module.
* Phương pháp này cho phép bắt quả tang hành vi bất thường tại thời điểm tín hiệu chuẩn bị đi vào hoặc đi ra khỏi Async FIFO và SDRAM, mang lại bằng chứng xác đáng thay vì các giả định mơ hồ.

## 3. Phân tích căn nguyên (Root Cause Analysis - Điểm nhấn suy luận)
Quá trình soi Waveform đã làm sáng tỏ hiện tượng "Rác đọng":
* **Nguồn gốc lỗi:** Do quá trình khởi động chưa ổn định hoặc nhiễu chớp nhoáng khi bật nguồn, một lượng pixel rác (cụ thể là 280 pixel) đã lọt vào Write-FIFO (W-FIFO) trước khi khung hình hợp lệ đầu tiên bắt đầu.
* **Toán học đằng sau sự tàn phá:** 
  * Một khung hình độ phân giải VGA chuẩn chứa $640 \times 480 = 307.200$ pixel.
  * Trình điều khiển bộ nhớ (SDRAM Controller) ghi dữ liệu theo Burst Length là 256. 
  * Do $307.200 \bmod 256 = 0$ (chia hết tuyệt đối), chu kỳ đọc/ghi diễn ra hoàn hảo. Tuy nhiên, 280 pixel rác ban đầu **không bao giờ bị quét đi** hay bị ghi đè, vì chúng đóng vai trò như một độ dời (offset) tịnh tiến mọi luồng dữ liệu theo sau nó.
  * Nó tạo thành một **"Độ trễ pha không gian"** ($\Delta = 280$) không đổi. Tọa độ điểm ảnh $(0,0)$ của mọi khung hình hợp lệ tiếp theo đều bị đẩy lệch vĩnh viễn đi 280 nhịp địa chỉ trên bộ nhớ SDRAM. Kết quả là pixel thứ 280 của camera lại trở thành pixel số 0 trên màn hình, sinh ra vết nứt dọc chia đôi khung hình.

## 4. Giải pháp khắc phục
Dựa trên bằng chứng từ Waveform, chiến lược khắc phục tập trung vào việc dọn dẹp FIFO đúng thời điểm:
* **Xả đáy (Flush) FIFO:** Tận dụng khoảng thời gian "Vertical Blanking" (khi tín hiệu `cam_vsync` bật lên High) giữa 2 khung hình để thực hiện thao tác reset toàn bộ W-FIFO. Bất kể có bao nhiêu rác đọng trước đó, FIFO đều được làm sạch trước khi khung hình mới bắt đầu.
* **Xử lý Clock Domain Crossing (CDC) an toàn:** Tín hiệu `cam_vsync` sinh ra từ miền xung nhịp của camera (`PCLK`). Tuy nhiên, mặt đọc/ghi của FIFO và logic reset lại hoạt động trong miền xung nhịp hệ thống (50MHz). Để chống lại hiện tượng Metastability, `cam_vsync` được đi qua 2 tầng Flip-Flop (Double-Flop Synchronizer) trước khi trở thành tín hiệu kích hoạt lệnh reset FIFO.

### Chi tiết mã nguồn (Module `ov7670_top.v`):
```verilog
// ========================================================================
// [FIX CHẶNG 3: XẢ ĐÁY W-FIFO KHI VSYNC CHUYỂN KHUNG HÌNH]
// ========================================================================
// 1. Khi cam_vsync = 1 (Vertical Blanking giữa 2 khung hình), Camera tạm dừng
//    phát dữ liệu. Đây là khoảng lặng vàng để tháo cạn toàn bộ W-FIFO.
// 2. Miền Ghi (wclk = cam_pclk): Dùng trực tiếp (~cam_vsync) làm wrst_n.
// 3. Miền Đọc (rclk = clk_50m): Đồng bộ cam_vsync qua 2 tầng D-FF (CDC chuẩn)
//    để tạo rrst_n an toàn, chống hiện tượng bất ổn định (Metastability).
// ========================================================================

// Khai báo 2 thanh ghi Flip-Flop để hứng tín hiệu từ miền Clock khác sang
reg cam_vsync_r1, cam_vsync_r2;

always @(posedge clk_50m or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        cam_vsync_r1 <= 1'b0;
        cam_vsync_r2 <= 1'b0;
    end else begin
        // Dịch chuyển qua 2 tầng D-FF để lọc nhiễu Metastability
        cam_vsync_r1 <= cam_vsync;
        cam_vsync_r2 <= cam_vsync_r1;
    end
end

// Tạo tín hiệu Reset độc lập cho 2 mặt của Async FIFO
wire w_fifo_wrst_n = sys_rst_n && (~cam_vsync);    // Mặt ghi (Camera domain)
wire w_fifo_rrst_n = sys_rst_n && (~cam_vsync_r2); // Mặt đọc (50MHz domain)
```

