# 📚 BÀI GIẢNG: KHAI MỞ BÍ ẨN KHỐI DVP CAPTURE - CAMERA OV7670 📚

Chào các bạn sinh viên và kỹ sư tương lai! Hôm nay, chúng ta sẽ bước vào thế giới vi mạch với một trong những dự án kinh điển nhất: Giao tiếp hệ thống Camera OV7670. Trong đó, khối DVP (Digital Video Port) Capture chính là cánh cổng đầu tiên, nơi chúng ta "bắt" lấy từng điểm ảnh mỏng manh từ thế giới thực. Hãy tập trung cao độ, vì chỉ một nhịp xung sai lệch, cả bức ảnh sẽ biến thành một màn hình nhiễu loạn!

## 1. Kiến trúc tổng thể và Giải phẫu tín hiệu DVP chi tiết

**A. Nhận diện Đầu vào (Input) – "Nguyên liệu thô từ mỏ":**
Khối DVP Capture không tự sinh ra dữ liệu, nó đóng vai trò là "trạm kiểm lâm" đứng ở cửa rừng.
- **Nguồn gốc:** Tín hiệu đến *trực tiếp từ phần cứng của Camera Sensor* đi qua các chân GPIO vật lý trên board mạch FPGA.
- **Thành phần cốt lõi:**
  - `PCLK` (Pixel Clock): Nhịp tim của camera (~24MHz). Cứ mỗi xung nhịp, camera sẽ nhả ra một khối dữ liệu nhỏ.
  - `VSYNC` (Vertical Sync): Cờ lệnh của tổng tư lệnh báo hiệu bắt đầu một khung hình (Frame) mới. (High = Blanking, Low = Active Frame).
  - `HREF` (Horizontal Reference): Cờ báo hiệu của đội trưởng dòng (Line) cho biết dữ liệu đang truyền là hợp lệ.
  - `D[7:0]`: Bus dữ liệu 8-bit, chở từng mảnh màu sắc thô.

> [!NOTE]
> **Góc Nhìn Lịch Sử & Bản Chất Vật Lý: Tại sao lại có Vùng Đen (Blanking)?**
> 
> Tín hiệu điều khiển DVP thực chất mang theo "DNA" di truyền từ thời đại **Tivi CRT (Ống phóng tia âm cực)**. Trong hệ thống CRT cổ điển, súng bắn electron sau khi quét xong một dòng (từ trái sang phải) cần một khoảng thời gian tắt tia sáng để "lùi nòng" về lề trái chuẩn bị quét dòng tiếp theo (H-Blanking), cũng như lùi từ đáy màn hình chạy ngược lên đỉnh màn hình (V-Blanking).
> 
> Camera OV7670 tuy là chip cảm biến CMOS kỹ thuật số hiện đại, nhưng vẫn được thiết kế để **giả lập y chang** chuẩn Analog truyền thống này nhằm đảm bảo tính tương thích vạn năng.
> 
> **Nguy cơ phần cứng tiềm ẩn:** Trong khoảng thời gian "súng đang lùi" này (khi `HREF = 0`), các đường dây dữ liệu `D[7:0]` bị thả nổi và xả ra toàn "rác" điện tử (Garbage Data). Do đó, việc thiết kế bẫy **`if (href == 1'b1)` chính là màng lọc sinh tử** — nếu bỏ qua cờ này, bộ đệm Async FIFO của bạn sẽ nuốt trọn rác, làm xô lệch tọa độ của toàn bộ các điểm ảnh ở các hàng bên dưới!

**B. Nhận diện Đầu ra (Output) – "Sản phẩm tinh chế xuất xưởng":**
Khối này đứng trước Async FIFO và làm nhiệm vụ nhồi dữ liệu vào FIFO.
- **Đích đến:** Đẩy thẳng vào cửa ngõ của **Async FIFO** (Khối đệm chuyển vùng Clock).
- **Thành phần:**
  - `pixel_data` (16-bit): Dữ liệu điểm ảnh RGB565 đã được lắp ráp hoàn chỉnh.
  - `pixel_valid` (1-bit): Tín hiệu Write Enable (WEN) ra lệnh cho Async FIFO: "Có điểm ảnh chuẩn rồi, mở cửa cất vào kho ngay!".

**C. Mô hình hóa Luồng dữ liệu (Data Flow) – "Trạm đóng gói kẹo trên băng chuyền":**
Hãy tưởng tượng luồng chảy dữ liệu của khối DVP Capture giống như một **Trạm đóng gói kẹo 16-gram** nằm trên một băng chuyền chạy với tốc độ `PCLK`.
1. **Băng chuyền chạy:** Camera liên tục ném lên băng chuyền từng viên kẹo 8-gram (`D[7:0]`).
2. **Luật chơi (HREF):** Trạm đóng gói chỉ được phép gắp kẹo đưa vào phễu khi đèn báo hiệu `HREF` sáng (dữ liệu hợp lệ).
3. **Nhào nặn (Lắp ráp):** Vì mục tiêu là đóng gói 16-gram (Pixel RGB565), máy phải chờ gắp viên kẹo thứ nhất (Byte cao - cất vào túi tạm), sau đó đợi đến nhịp tiếp theo để gắp viên kẹo thứ hai (Byte thấp). 
4. **Xuất xưởng:** Ngay tại nhịp thứ 2, máy ép 2 viên kẹo 8-gram lại với nhau thành 1 gói 16-gram (`pixel_data`), lập tức bật đèn xanh (`pixel_valid`) và quăng tọt vào thùng chứa phía sau (chính là Async FIFO). Quá trình này lặp lại liên tục cho đến hết hàng.
5. **Qua ngày mới (VSYNC):** Khi cờ `VSYNC` phất lên, giám đốc xưởng hô to: "Xong một bức tranh kẹo! Quét sạch phễu chứa, reset bộ đếm, chuẩn bị đón ca mới!".

## 2. Nghệ thuật ghép ảnh RGB565: Bức Tranh 16-bit Từ Mảnh Ghép 8-bit
Camera truyền dữ liệu theo chuẩn màu RGB565, tức là một điểm ảnh (Pixel) cần 16-bit (5 bit Đỏ, 6 bit Xanh lá, 5 bit Xanh dương). Nhưng dây chuyền D[7:0] chỉ rộng 8-bit!
**Cách giải quyết của luồng dữ liệu (Data flow):** 1 Pixel (16-bit) = 2 nhịp PCLK.
- **Nhịp PCLK thứ 1 (Bắt Byte Cao):** Khi `HREF = 1`, ta bắt lấy 8-bit đầu tiên (R[4:0] và G[5:3]). Logic cần phải lưu nó vào một thanh ghi tạm (latch/buffer).
- **Nhịp PCLK thứ 2 (Bắt Byte Thấp):** Bắt lấy 8-bit tiếp theo (G[2:0] và B[4:0]).
- **Đóng gói (Packing):** Khối DVP sẽ ghép "Byte Cao" đang chờ sẵn và "Byte Thấp" vừa tới thành một từ 16-bit hoàn chỉnh và bật cờ tín hiệu `pixel_valid` để đẩy đi tiếp.

## 3. Cầu nối Async FIFO: Vượt Qua Khoảng Cách Không Gian - Thời Gian (Clock Domain)
Khối DVP Capture hoạt động **HOÀN TOÀN** dựa trên xung **PCLK của Camera**, KHÔNG DÙNG xung nội hệ thống của FPGA. 
Nó đem dữ liệu 16-bit đóng gói đẩy vào một **Async FIFO** (Bộ đệm FIFO bất đồng bộ). Đầu kia của FIFO (Read Domain) sẽ được điều khiển bởi khối xử lý hệ thống bằng xung nhịp 50/100MHz. Thiết kế này giúp hai miền xung nhịp (Clock Domains) độc lập, không dẫm đạp lên nhau!

---

> [!CAUTION]
> ## ⚠️ LUẬT THÉP: CẠM BẪY DỄ SAI VÀ LƯU Ý SỐNG CÒN
> 1. **CẠM BẪY CLOCK DOMAIN CROSSING (CDC):** Tuyệt đối không lấy tín hiệu `pixel_data` ném thẳng vào RAM hoặc bộ xử lý ảnh mà bỏ qua Async FIFO. Hậu quả: Vi phạm Setup/Hold time sinh ra Metastability, màn hình sẽ nhiễu sọc (Tearing) hoặc hệ thống sập hoàn toàn!
> 2. **LỖI LỆCH BYTE (BYTE MISALIGNMENT):** Lúc khởi động, tín hiệu chưa ổn định, bạn rất dễ bắt nhầm "Byte Thấp" làm "Byte Cao". Hệ quả: Màu sắc loạn xạ, nhiễu hột cát. *Luật thép:* Phải luôn dựa vào sườn xuống của VSYNC (bắt đầu khung hình mới) để Reset lại cờ chọn Byte, đảm bảo Byte đầu tiên sau VSYNC chắc chắn là Byte Cao.
> 3. **BÓNG MA RÁC ĐẦU KHUNG HÌNH:** Khi VSYNC vừa chuyển trạng thái, đường truyền từ sensor mất một vài xung nhịp `PCLK` để thực sự ổn định. Nếu logic bắt ngay pixel đầu tiên không có độ trễ an toàn, bạn sẽ bắt nhầm "nhiễu" thành điểm ảnh đầu tiên.
> 4. **CẠM BẪY PHÂN CỰC (POLARITY TRAP):** Các loại sensor khác nhau quy định phân cực VSYNC/HREF khác nhau. Phải soi Datasheet kỹ xem Active-High hay Active-Low, nếu code mù quáng thì "trạm đóng gói kẹo" của bạn sẽ đứng gói rác!

## 4. Sự Khác Biệt Cốt Lõi: Đọc Ảnh Tĩnh (Static) vs. Xử Lý Camera Thời Gian Thực (Real-time)

**Sự ngỡ ngàng thường gặp:** Tại sao khối Camera (Capture) chỉ nhận dữ liệu vào mà lại phải xuất ra địa chỉ `addr`? Để hiểu rõ, chúng ta cần nhìn vào sự khác biệt căn bản giữa hai hệ thống:

**1. Đọc ảnh tĩnh từ ROM/Thẻ nhớ (Static)**
- Dữ liệu hình ảnh đã có sẵn và nằm im trong bộ nhớ.
- Hệ thống chỉ có **1 "công nhân" duy nhất** là khối VGA Controller. 
- Khối VGA tự động sinh ra tọa độ quét (Read Address) để móc dữ liệu từ bộ nhớ ra và hiển thị lên màn hình một cách tuần tự. Không ai tranh giành quyền truy cập bộ nhớ với nó.

**2. Xử lý Camera thời gian thực (Real-time)**
- Đây là một "trận chiến" của **2 người công nhân độc lập** cùng hoạt động trên một cái kho SDRAM duy nhất (Shared Memory).
  - **Khối Camera (Đầu Bơm):** Không chỉ nhận luồng tín hiệu từ OV7670, khối DVP Capture phải làm nhiệm vụ "Tiền xử lý": đóng gói các byte dữ liệu thành 1 pixel 16-bit RGB565 và quan trọng nhất là **TỰ ĐỘNG sinh ra tọa độ cất kho (Write Address)** để điền kín dữ liệu vào Frame Buffer một cách chính xác theo thời gian thực.
  - **Khối VGA (Đầu Hút):** Chạy hoàn toàn độc lập với tốc độ riêng của màn hình. Nhiệm vụ của nó là liên tục sinh ra tọa độ lấy kho (Read Address) để hút dữ liệu ra và vẽ lên màn hình.

**Nhấn mạnh:** Việc giao phó cho khối DVP Capture đảm nhận vai trò "Tiền xử lý" (đóng gói 16-bit và cấp Write Address) là một thiết kế tối ưu. Nó giúp **giảm tải hoàn toàn** gánh nặng tính toán địa chỉ cất giữ cho SDRAM Controller và khối VGA, cho phép hệ thống vận hành trơn tru trong điều kiện thời gian thực khắt khe.

## 5. Nâng cấp Kiến trúc: Tại sao phải chuyển từ Line Buffer lên Ping-Pong Frame Buffer?

Trong các thiết kế xử lý ảnh tĩnh cơ bản, người ta thường dùng **Line Buffer** (chỉ đệm 1-2 hàng điểm ảnh) hoặc **Single Buffer** (chỉ dùng 1 kho duy nhất). Nhưng đối với hệ thống Camera thời gian thực, đây là một thiết kế tiềm ẩn rủi ro rất lớn mang tên **Xé hình (Screen Tearing)**.

**1. Thảm họa chênh lệch tốc độ (Tearing Disaster)**
- Tốc độ "bơm" của Camera (Write): Chạy bằng xung `PCLK` ~24MHz, nhưng cần 2 nhịp mới ra được 1 pixel. Tốc độ bơm thực tế chỉ khoảng **12 Triệu pixel/giây (30fps)**.
- Tốc độ "hút" của VGA (Read): Màn hình 640x480@60Hz yêu cầu chốt pixel liên tục ở mức **25 Triệu pixel/giây (60fps)**.
- **Hệ quả:** Đầu hút VGA chạy nhanh gấp đôi đầu bơm Camera! Nếu bắt chúng dùng chung 1 cái Line Buffer hoặc 1 Frame Buffer duy nhất, VGA sẽ nhanh chóng "chạy vượt mặt" Camera. Khi đó trên màn hình, nửa trên sẽ là ảnh của khung hình mới, nửa dưới lại là ảnh của khung hình cũ chắp vá lại, gây giật lag và xé hình trầm trọng.

**2. Giải pháp tối thượng: Ping-Pong Frame Buffer (Đệm kép luân phiên)**
Để giải quyết triệt để, chúng ta quy hoạch chip SDRAM thành 2 "mảnh đất" khổng lồ: **Bank 0** và **Bank 1** (sử dụng bit cao nhất của địa chỉ làm cờ chọn Bank).
- **Cơ chế cách ly:** Khối Camera cứ việc hì hục đổ đất (Write) vào **Bank 0**, trong khi khối VGA cứ ung dung lấy đất (Read) từ **Bank 1** ra vẽ. Hai người công nhân làm việc ở 2 kho hoàn toàn cách biệt, không bao giờ dẫm chân lên nhau.
- **Cơ chế đổi ca (Swap Bank):** Ngay khi sườn xuống của tín hiệu `camera_vsync` xuất hiện (báo hiệu Camera đã chụp xong trọn vẹn 1 bức ảnh vào Bank 0), khối SDRAM Arbiter sẽ lập tức hoán đổi vị trí:
  - Khung hình tiếp theo, Camera chuyển sang cày cuốc ở **Bank 1**.
  - VGA được cấp quyền sang **Bank 0** để hút bức ảnh mới nhất vừa ra lò.

Thiết kế Ping-Pong Buffer này là tiêu chuẩn vàng (Golden Standard) trong công nghiệp truyền phát Video, giúp luồng ảnh chảy mượt mà 100% bất chấp sự sai lệch tốc độ giữa thiết bị thu và thiết bị phát!
