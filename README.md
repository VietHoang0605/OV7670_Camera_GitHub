# OV7670 REAL-TIME CAMERA SYSTEM ON FPGA

## 1. TỔNG QUAN DỰ ÁN (PROJECT OVERVIEW)

Hệ thống thu thập, xử lý và hiển thị hình ảnh thời gian thực (Real-time Video Processing) trên nền tảng FPGA, sử dụng cảm biến quang học CMOS OV7670. Hệ thống được thiết kế hoàn toàn bằng ngôn ngữ mô tả phần cứng Verilog, quản lý luồng dữ liệu hình ảnh tốc độ cao từ Camera, lưu trữ qua bộ nhớ SDRAM và xuất ra màn hình chuẩn VGA (640x480).

**Liên kết Tài liệu Kỹ thuật Chi tiết:**
> Báo cáo chuyên sâu về kiến trúc, nhật ký xử lý tín hiệu vật lý và khắc phục sự cố (Bug Hunting) được trình bày chi tiết tại trang Web UI nội bộ của dự án:
> **[👉 Xem Báo cáo Kỹ thuật (Web Report)](https://de1-fpga-camera-ov7670.vercel.app/)**

---

## 2. KIẾN TRÚC HỆ THỐNG VÀ LUỒNG DỮ LIỆU (SYSTEM ARCHITECTURE & DATA FLOW)

Hệ thống được vận hành bởi hai luồng xử lý hoàn toàn độc lập, giao tiếp với nhau thông qua bộ nhớ chia sẻ (Shared Memory) SDRAM.

### 2.1. Luồng Điều khiển Cấu hình (Control Pipeline - I2C/SCCB)
*   **Mục đích:** Đánh thức và lập trình các thanh ghi bên trong Camera OV7670.
*   **Luồng hoạt động:** Ngay khi hệ thống được cấp nguồn, khối ROM nội bộ (chứa 156 lệnh cấu hình) sẽ tuần tự truyền dữ liệu sang khối I2C Master. Khối I2C Master sẽ đóng gói và truyền nối tiếp (Serial) các lệnh này qua giao thức I2C/SCCB để cài đặt Camera (định dạng RGB565, cân bằng trắng, tự động phơi sáng).

### 2.2. Luồng Dữ liệu Hình ảnh (Image Data Pipeline - DVP to VGA)
*   **Mục đích:** Thu thập dữ liệu điểm ảnh (Pixel), đồng bộ hóa xuyên miền xung nhịp (Clock Domain Crossing - CDC) và hiển thị lên màn hình.
*   **Luồng hoạt động:** 
    1. Camera xuất dữ liệu 8-bit liên tục thông qua giao thức DVP (Digital Video Port).
    2. Khối Capture tiến hành gắp và ghép 2 byte liên tiếp thành một điểm ảnh 16-bit hoàn chỉnh (chuẩn RGB565).
    3. Điểm ảnh được đẩy vào W-FIFO (Asynchronous FIFO) để vượt qua ranh giới xung nhịp từ miền Camera (24MHz) sang miền Hệ thống (50MHz).
    4. Trọng tài bộ nhớ (Arbiter) hút dữ liệu từ W-FIFO, đóng gói thành các khối lớn (Burst 256 words) và ghi tốc độ cao vào SDRAM.
    5. Ở đầu ra, Arbiter đọc dữ liệu từ SDRAM đẩy vào R-FIFO. Khối điều khiển VGA sẽ lấy dữ liệu từ R-FIFO, phối hợp với các xung HSYNC/VSYNC để quét lên màn hình.

### 2.3. Cơ chế Đệm Kép (Ping-Pong Frame Buffering)
*   Để giải quyết triệt để hiện tượng xé hình (Screen Tearing) do sự chênh lệch tốc độ giữa Camera (30fps) và VGA (60fps), không gian nhớ SDRAM được phân lô thành 2 Bank độc lập (Bank 0 và Bank 1).
*   Khối Camera luôn ghi khung hình mới vào một Bank, trong khi khối VGA luôn đọc khung hình cũ từ Bank còn lại. Hoạt động hoán đổi (Swap) chỉ diễn ra trong khoảng thời gian Blanking, đảm bảo luồng Video thời gian thực mượt mà và toàn vẹn tuyệt đối.

---

## 3. CÁC MODULE THÀNH PHẦN (SYSTEM MODULES)

Hệ thống được chia nhỏ thành các Module độc lập, tối ưu hóa theo nguyên tắc thiết kế Top-Down:

*   **`ov7670_top.v`**: Module tích hợp cấp cao nhất, phụ trách kết nối vật lý (Instantiation) toàn bộ hệ thống với các chân I/O của chip FPGA.
*   **`ov7670_config.v`**: Khối lưu trữ ma trận lệnh cấu hình (ROM) và máy trạng thái (FSM) điều phối thời gian khởi động của Camera.
*   **`i2c_master.v`**: Module giao tiếp vật lý I2C Master, xử lý nhịp tín hiệu SCL/SDA, quản lý trạng thái Open-Drain, định hướng xung nhịp và thu nhận tín hiệu phản hồi (ACK/NACK).
*   **`ov7670_capture.v`**: Khối tiền xử lý hình ảnh, xử lý bộ đếm địa chỉ (Address Generator), phát hiện vùng dữ liệu rác (Blanking) thông qua cờ HREF, và thực hiện đóng gói Byte-Swap.
*   **`async_fifo.v`**: Hàng đợi FIFO phi đồng bộ. Đây là vùng đệm chống sốc dữ liệu (Buffer) sử dụng mã Gray để đảm bảo an toàn băng thông khi chuyển giao dữ liệu giữa các miền Clock (CDC).
*   **`sdram_arbiter.v`**: Khối Trọng tài điều phối quyền truy cập bộ nhớ. Sử dụng thuật toán State Machine để quyết định thời điểm Ghi (Write) từ Camera, Đọc (Read) cho VGA, hoặc Nạp lại (Refresh) cho SDRAM.
*   **`sdram_controller.v`**: Trình điều khiển cấp thấp (Low-level Driver) giao tiếp trực tiếp với SDRAM. Tuân thủ nghiêm ngặt giản đồ định thời (Timing Diagram) của SDRAM bao gồm các lệnh ACT, NOP, READ, WRITE, PRE, REF.
*   **`vga_sync.v`**: Trình xuất tín hiệu màn hình, sinh tọa độ đồng bộ ngang/dọc (HSYNC/VSYNC) theo chuẩn VGA công nghiệp.

---

## 4. ĐÁNH GIÁ ĐỘ PHỨC TẠP VÀ THÁCH THỨC KỸ THUẬT

Dự án OV7670 trên FPGA là một hệ thống mang tính thử thách cao, đòi hỏi sự phối hợp chặt chẽ giữa kiến thức thiết kế logic số (Digital Design) và hiểu biết về điện tử phần cứng (Physical Hardware Layer).

1.  **Quản trị Đa miền Xung nhịp (Multi-Clock Domain Management):** Hệ thống tồn tại đồng thời 3 miền xung nhịp riêng biệt (24MHz Camera, 25MHz VGA, 50MHz System). Việc xử lý triệt để hiện tượng Metastability bằng Async FIFO và bộ đồng bộ 2 tầng (2-stage synchronizer) là bắt buộc.
2.  **Khắc nghiệt về Băng thông (Bandwidth Bottleneck):** Bộ nhớ SDRAM chỉ có một cổng truy cập duy nhất (Single Port) nhưng phải phục vụ đồng thời 3 tác vụ khổng lồ: Ghi từ Camera, Đọc ra VGA và Tự làm tươi (Auto-Refresh). Kỹ thuật Burst Write/Read 256 words phải được triển khai để tối đa hóa thông lượng (Throughput).
3.  **Toàn vẹn Tín hiệu Mức Vật lý (Signal Integrity):** Quá trình giao tiếp với phần cứng ngoại vi chịu ảnh hưởng nặng nề bởi tính chất Analog. Việc kích hoạt thành công các điện trở nội kéo lên (Weak Pull-up) cho đường I2C, hoặc tạo độ trễ 10ms khởi động (Power-on Reset) là minh chứng cho tư duy gỡ lỗi (Hardware Debugging) kết hợp với công cụ SignalTap II Logic Analyzer. 

Hệ thống hoạt động ổn định và đáp ứng xuất sắc các tiêu chuẩn kỹ thuật thời gian thực khắt khe nhất.

