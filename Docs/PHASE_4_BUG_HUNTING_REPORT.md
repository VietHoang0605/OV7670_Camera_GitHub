# BÁO CÁO KỸ THUẬT CHẶNG 4 - VƯỢT QUA ẢO ẢNH PHẦN MỀM VÀ CHIẾN THẮNG TRÊN TẦNG VẬT LÝ

**Tác giả:** Kỹ sư Phát triển Hệ thống FPGA (Portfolio Case Study)

## 1. Điểm khởi đầu đánh lừa (The Illusion of Simplicity)
![Ảo ảnh màu sắc](/C:/Users/ADMIN/.gemini/antigravity/brain/f70173ee-de75-4c0f-9230-f9c5a93ddc97/.user_uploaded/media_1789984404120.jpg)

Chặng 4 bắt đầu với một khung cảnh tưởng chừng như chiến thắng đã cận kề: Vết nứt sọc dọc chia đôi màn hình đã biến mất, hình bóng cánh tay người đã hiện rõ trên màn hình VGA. Thứ duy nhất gây khó chịu còn lại là màu sắc bị ám tím và xanh neon dị thường. Nhìn từ góc độ phần mềm, đây có vẻ như chỉ là một lỗi sai ma trận màu hoặc sai định dạng RGB565. Nhưng thực chất, đây lại là khởi đầu cho một chặng đường debug khắc nghiệt nhất của toàn bộ dự án.

## 2. Vòng lặp tuyệt vọng và Sự phản bội của Mô phỏng
Để sửa dải màu, tôi đã tiến hành thay đổi và thử nghiệm vô vàn các tập lệnh cấu hình I2C/SCCB khác nhau. Nhưng bất chấp mọi nỗ lực, màu sắc trên màn hình vẫn không hề suy xuyển.

Với tư duy cô lập hệ thống, tôi đã tạo hẳn một môi trường mô phỏng chuyên sâu (`sim_debug_color`) để rà soát từng dòng code. Kết quả mô phỏng (Waveform trên ModelSim) trả về **hoàn hảo 100%**. Mọi module hoạt động đúng nhịp, dữ liệu trích xuất chính xác. Thế nhưng, khi nạp xuống mạch thật, hình ảnh vẫn giữ nguyên màu sắc hỏng hóc.

Đỉnh điểm của sự hỗn loạn là khi lỗi Chặng 3 (sọc dọc và trôi hình) – một lỗi tưởng chừng đã bị tiêu diệt hoàn toàn – đột ngột quay trở lại. 

![Bệnh cũ tái phát](/C:/Users/ADMIN/.gemini/antigravity/brain/f70173ee-de75-4c0f-9230-f9c5a93ddc97/.user_uploaded/media_1789995593406.jpg)

Việc "Bệnh cũ tái phát cùng bệnh mới" khiến toàn bộ hệ thống trở nên rối tung, đe dọa đánh sập mọi nền tảng logic đã xây dựng.

## 3. Bước ngoặt tư duy (The Paradigm Shift) và Bằng chứng "Color Bar"
Đứng trước mớ bòng bong, tôi quyết định lùi lại một bước và đưa ra một giả thuyết táo bạo: **Cái sọc dọc và trôi hình không phải do module code của chúng ta có vấn đề!**
Để chứng minh điều đó, tôi đã sử dụng phương án "Color Bar": Ép Camera xuất ra dải màu thử nghiệm nội bộ thông qua duy nhất 1 lệnh `COM7 = 0x06`. 

**Tại sao Color Bar lại là bằng chứng ngoại phạm hoàn hảo cho RTL?** 
Chế độ Color Bar là một bộ tạo ảnh nhân tạo tích hợp sẵn bên trong lõi DSP của OV7670, bỏ qua hoàn toàn mắt kính quang học để xuất ra một dải 8 màu sọc dọc hoàn hảo (Trắng, Vàng, Cyan, Lục, Magenta, Đỏ, Lam, Đen). Nếu màn hình VGA hiện lên được dải màu này một cách mượt mà, tĩnh lặng, không trôi, không xé... thì điều đó chứng minh tuyệt đối 100% rằng luồng dữ liệu (Data Pipeline) từ `ov7670_capture -> W-FIFO -> SDRAM Arbiter -> R-FIFO -> VGA` của tôi được thiết kế hoàn hảo.

Tuy nhiên, màn hình vẫn không xuất hiện Color Bar mà vẫn là những hình ảnh ám màu cũ kỹ trôi nổi. Sự thất bại của một lệnh cấu hình đơn giản nhất đã mang lại một kết luận chói lòa: **Mọi lệnh I2C từ FPGA gửi đi đều đang đi vào hư vô. Camera hoàn toàn không nhận được bất kỳ cấu hình nào!**

## 4. SignalTap II - Ánh sáng soi chiếu "Hộp đen" Tầng Vật lý
Để điều tra I2C, ban đầu tôi đã gán các cờ báo vào hệ thống đèn LED của DE1:
* `LED[9]` nối vào cờ `config_done` của module `ov7670_config.v` để xem FSM có đếm hết 156 lệnh hay không.
* `LED[8]` nối vào biến `ack_error` (qua một mạch chốt latch) của module `i2c_master.v` để bắt lỗi từ chối lệnh.

Thực tế là `LED[9]` luôn sáng rực rỡ và `LED[8]` luôn tắt. Nhưng **sự ổn định của các cờ báo này là một lời nói dối**. Chúng chỉ chứng minh rằng Máy trạng thái (FSM) nội bộ bằng Verilog đã chạy xong các vòng lặp logic. Nhưng việc biến nội bộ chuyển từ 0 sang 1 hoàn toàn không đồng nghĩa với việc điện áp vật lý trên các chân PIN `cam_sda` và `cam_scl` ngoài đời thực thực sự giao động 3.3V/0V. Tín hiệu vật lý vẫn là một "hộp đen" mù mịt.

Đó là lúc tôi rút ra vũ khí tối thượng: **SignalTap II Logic Analyzer**. Khác với Waveform lý tưởng hóa của ModelSim, SignalTap cấy trực tiếp vào lõi Silicon để bắt tín hiệu điện áp thực.

**Phân tích kỹ thuật trên SignalTap:**
Để bắt được tín hiệu, tôi đã thiết lập Trigger theo đúng định nghĩa tín hiệu START của giao thức I2C: **SDA tụt từ 1 xuống 0 trong khi SCL vẫn đang giữ ở mức 1**. Khi SignalTap bắt được đúng khoảnh khắc này, nó khẳng định Module Master của tôi đã bắt đầu chu trình truyền tải thành công. 

**Tầm quan trọng của Bit thứ 9 (ACK):**
Trong I2C, 8 chu kỳ xung nhịp đầu tiên dùng để Master truyền 8 bit dữ liệu. Nhưng chu kỳ xung nhịp thứ 9 là khoảnh khắc Master buông tay để Slave (Camera) kéo dây SDA xuống mức 0, gọi là tín hiệu **ACK (Acknowledge - Xác nhận)**. 
Trong module `i2c_master.v`, biến trạng thái này mang tên `ack_error`. Nếu ở chu kỳ thứ 9 mà SDA vẫn ở mức 1 (NACK), biến `ack_error` sẽ dựng lên 1 báo lỗi. Đây là cái bắt tay sinh tử quyết định sự thành bại của toàn bộ chu trình giao tiếp phần cứng.

## 5. Bắt quả tang kẻ thù (The Missing Pull-up)
Khi giăng bẫy SignalTap để đo chân `cam_sda` và `cam_scl`, tôi đã bắt được quả tang một hiện tượng không thể tin nổi:

![Bắt quả tang I2C kẹt 0](/C:/Users/ADMIN/.gemini/antigravity/brain/f70173ee-de75-4c0f-9230-f9c5a93ddc97/.user_uploaded/media_1790416947117.png)

Như bạn có thể thấy ở bức ảnh trên: Ngay sau khi lệnh START được phát ra, tín hiệu SDA tụt xuống mức logic 0 và **nằm lì ở đó trong suốt toàn bộ chu kỳ truyền**, mặc dù SCL vẫn đập liên tục.

**Lý giải nguyên nhân:**
Bản chất của chân SDA trong giao thức I2C là cực máng hở (Open-Drain). Nó chỉ có thể kéo xuống 0V (GND), và cần một **Điện trở kéo lên (Pull-up Resistor)** để nhả về mức 3.3V (Logic 1). Module Camera rẻ tiền đã bị nhà sản xuất cắt bớt con điện trở này!
*Cái bẫy chí mạng:* Vì dây SDA bị chết bẹp ở 0V, mà trong I2C mức 0 lại mang nghĩa là ACK. Bỗng nhiên, cái biến `ack_error` trong module `i2c_master.v` liên tục lấy mẫu được mức 0 và báo cáo với hệ thống rằng: "Mọi thứ vẫn đang hoàn hảo, Camera đã ACK". Hậu quả là FPGA cứ lầm lũi gửi hết 156 lệnh cấu hình vào khoảng không, trong khi Camera thực chất mù điếc!

## 6. Giải pháp Tầng Điện tử và Cú chốt hạ lịch sử
Để khắc phục sự thiếu sót của phần cứng, tôi đã ép FPGA phải tự xuất điện trở nội bộ thông qua lệnh cấu hình QSF: `set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON`.
Nhưng 40k Ohm nội bộ là quá yếu để kéo cáp lên mức 1 kịp thời ở tốc độ 400kHz. Lập luận từ góc độ điện tử tương tự (Analog), tôi đã chủ động hạ xung nhịp I2C xuống **100kHz** để cho tín hiệu có đủ thời gian (Rise time) sạc đầy lên 3.3V.

Và đây là bức tranh tín hiệu SignalTap sau khi được chữa lành:
![Tín hiệu I2C thành công](/C:/Users/ADMIN/.gemini/antigravity/brain/f70173ee-de75-4c0f-9230-f9c5a93ddc97/.user_uploaded/media_1790417358515.png)
Tín hiệu SDA đã lên xuống hoàn hảo! I2C Master báo lỗi NACK chính xác khi có biến. 

## 7. Khóa chặt quang học và Chinh phục nhiễu dây dẫn (Signal Integrity)
Mặc dù I2C đã hoạt động, nhưng khi ép xuất Color Bar, hình ảnh vẫn còn hiện tượng giằng co với quang học thực tế và chớp nháy (Flickering) liên tục. Để đạt được sự hoàn hảo tuyệt đối, tôi đã tung ra 2 đòn đánh cuối cùng:

**Đòn 1: Combo lệnh phong ấn quang học (I2C)**
Tôi cấu hình lại bộ lệnh I2C để cô lập hoàn toàn mạch DSP nội bộ khỏi cảm biến quang:
* `COM17 = 0x08`, `SCALING_XSC = 0xBA`, `SCALING_YSC = 0xB5`: Ép các khối thu phóng và xử lý số kích hoạt Test Pattern.
* `COM8 = 0xC0`: Tắt hoàn toàn bộ phơi sáng (AEC), khuếch đại (AGC) và cân bằng trắng (AWB) để camera ngừng "tẩu hỏa nhập ma" khi bị bịt mắt.
Lúc này, cờ `ack_error` (LED 8) đã tắt lịm, chứng minh combo lệnh khó nhằn trên lọt 100% vào trong camera.

**Đòn 2: Giải quyết nhiễu xung nhịp Jumper (Signal Integrity)**
Màn hình vẫn chớp nháy là do tín hiệu `cam_pclk` (24MHz) chạy qua cáp Jumper sinh ra hiện tượng dội sóng (Ringing). Bộ đệm Clock nhạy bén của FPGA nhận diện nhầm các gợn sóng này thành 2-3 xung chớp nhoáng (Double Clocking), phá vỡ logic đẩy dữ liệu Ping-Pong.
*Giải pháp vật lý:* Rút ngắn tối đa sợi Jumper và xoắn cáp `cam_pclk` chung với một dây Mass (GND) để tạo thành cặp cáp chống nhiễu từ trường (Twisted pair).

Và đây là kết quả cuối cùng - minh chứng hùng hồn nhất cho một hệ thống FPGA hoàn hảo (Pixel-perfect):
![Thành quả Dải màu hoàn hảo](/C:/Users/ADMIN/.gemini/antigravity/brain/f70173ee-de75-4c0f-9230-f9c5a93ddc97/.user_uploaded/media_1790421856390.png)

Dải màu hiện ra tĩnh lặng như một mặt hồ, 160 lệnh cấu hình I2C đã hoạt động hoàn hảo, và toàn bộ luồng dữ liệu Async FIFO + SDRAM Ping-Pong Controller đã chứng minh được sự kiên cố của nó.

## 8. Bài học đắt giá cho một Kỹ sư Hệ thống
Chặng 4 là một bài test tâm lý và kỹ năng cực độ. Nó chứng minh rằng:
1. **Kiến thức liên ngành là sức mạnh:** Một kỹ sư thiết kế Digital (RTL) sẽ kẹt ở đây mãi mãi nếu không có nền tảng về Điện tử Tương tự (Sự xả nạp RC, Open-Drain, Pull-up, Signal Integrity).
2. **Luôn nghi ngờ Hộp đen vật lý:** Đèn LED và Simulation chỉ chứng minh thiết kế logic của bạn đúng, chứ không chứng minh mạch điện vật lý của bạn đang sống. 
3. **Kỹ năng gỡ lỗi là nghệ thuật đặt câu hỏi:** Khi bị lạc giữa muôn trùng bug, việc quay về lệnh đơn giản nhất (Color Bar) và soi chiếu tín hiệu vật lý cơ bản (SignalTap) chính là la bàn dẫn đến thành công.
