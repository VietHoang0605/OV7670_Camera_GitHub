module i2c_master (
    // =========================================================================
    // KHAI BÁO CÁC TÍN HIỆU (I/O PORTS) - CỔNG GIAO TIẾP VÀO RA
    // =========================================================================
    // clk: Xung nhịp hệ thống cơ sở (thường là 50MHz từ bộ dao động trên board FPGA).
    // Đây là nhịp tim của toàn bộ FSM, dùng để điều khiển mọi hoạt động chuyển trạng thái.
    input  wire        clk,        
    
    // reset_n: Tín hiệu khởi tạo lại toàn bộ module, tích cực ở mức thấp (active low).
    // Khi reset_n = 0, module lập tức dừng hoạt động và quay về trạng thái IDLE an toàn.
    input  wire        reset_n,    
    
    // start: Xung điều khiển bắt đầu quá trình truyền dữ liệu I2C. 
    // Người dùng cấp xung này (mức 1) trong ít nhất 1 chu kỳ clk để kích hoạt FSM.
    input  wire        start,      
    
    // slave_addr: Địa chỉ định danh 7-bit của chip nhận (Slave).
    // Với camera OV7670, địa chỉ thường dùng là 0x42 (cho Write) hoặc 0x21 (nếu chưa dịch bit R/W).
    input  wire [6:0]  slave_addr, 
    
    // rw: Bit quy định chiều giao tiếp dữ liệu. 
    // 0 = Ghi dữ liệu vào Slave (Write), 1 = Đọc dữ liệu từ Slave (Read).
    // Khi cấu hình thanh ghi cho OV7670 thì chân này luôn được gán cứng là 0.
    input  wire        rw,         
    
    // data_in: Dữ liệu 16-bit chuẩn bị truyền.
    // Trong giao thức SCCB, 16 bit này rất vừa vặn:
    // - 8 bit cao [15:8]: Đóng vai trò là Sub-Address (Địa chỉ thanh ghi cần ghi vào).
    // - 8 bit thấp [7:0]: Đóng vai trò là Data (Giá trị muốn ghi vào thanh ghi đó).
    input  wire [15:0] data_in,    
    
    // =========================================================================
    // TÍN HIỆU GIAO TIẾP THỰC TẾ VỚI CHIP SLAVE (VÍ DỤ OV7670)
    // =========================================================================
    // scl: Xung nhịp đồng bộ của chuẩn I2C/SCCB do chính Master (module này) sinh ra.
    // Chân này sẽ liên tục tạo xung vuông để báo cho Slave biết thời điểm đọc/ghi bit.
    output reg         scl,        
    
    // sda: Đường truyền dữ liệu nối tiếp hai chiều (inout).
    // Master phát trên đường này, và Slave cũng phản hồi (ACK) trên đường này.
    // Phải là cấu trúc cực thu hở (Open-Drain), chỉ kéo xuống 0 hoặc thả nổi (High-Z).
    inout  wire        sda,        
    
    // =========================================================================
    // TÍN HIỆU TRẠNG THÁI BÁO CÁO LÊN BỘ ĐIỀU KHIỂN CẤP TRÊN
    // =========================================================================
    // ready: Cờ báo trạng thái rảnh rỗi của khối I2C.
    // 1 = Module đang rảnh, sẵn sàng nhận tín hiệu 'start' mới.
    // 0 = Module đang bận truyền dữ liệu, không thể nhận thêm lệnh.
    output reg         ready,      
    
    // ack_error: Cờ cảnh báo lỗi đường truyền.
    // 1 = Không nhận được phản hồi ACK (kéo sda xuống 0) từ Slave tại các pha kiểm tra.
    // Cờ này rất quan trọng để biết OV7670 có đang kết nối đúng và hoạt động không.
    output reg         ack_error   
);

    // =========================================================================
    // KHAI BÁO BIẾN VÀ CÁC MODULE CON HỖ TRỢ
    // =========================================================================
    // tick_4x: Xung kích hoạt định thời. Tần số của nó bằng 4 lần tần số của scl.
    // Giúp chia một chu kỳ scl ra làm 4 pha rõ rệt để dễ dàng lấy mẫu và xuất dữ liệu.
    wire tick_4x;          
    
    // enable_tick: Cho phép bộ chia clock chạy (chỉ chạy khi không ở trạng thái IDLE).
    reg  enable_tick;      

    // Khởi tạo bộ chia xung 'i2c_clk_gen'.
    i2c_clk_gen clk_gen_inst (
        .clk(clk),
        .reset_n(reset_n),
        .enable(enable_tick),
        .i2c_tick_4x(tick_4x)
    );

    // sda_oe (SDA Output Enable): Thanh ghi điều khiển việc Master có can thiệp vào dây sda không.
    // 1 = Master chủ động kéo sda xuống mức logic 0.
    // 0 = Master buông tay, thả nổi sda (để trở kéo lên pull-up kéo lên 1, hoặc nhường Slave kéo xuống 0).
    reg sda_oe; 
    assign sda = (sda_oe == 1'b1) ? 1'b0 : 1'bz;

    // Các trạng thái của máy trạng thái hữu hạn (FSM)
    localparam IDLE  = 3'd0; // Nghỉ ngơi: Chờ xung 'start' từ người dùng.
    localparam START = 3'd1; // Tạo điều kiện bắt đầu (START condition).
    localparam ADDR  = 3'd2; // Gửi 8-bit thiết bị (7-bit Slave Address + 1-bit R/W).
    localparam ACK1  = 3'd3; // Nghe ngóng Slave trả lời (Acknowledge) lần 1.
    localparam DATA  = 3'd4; // Gửi 8-bit dữ liệu (Byte 1: Sub-Addr, hoặc Byte 2: Data).
    localparam ACK2  = 3'd5; // Nghe ngóng Slave trả lời (Acknowledge) lần 2.
    localparam STOP  = 3'd6; // Tạo điều kiện kết thúc (STOP condition).

    reg [2:0] state, next_state;
    reg [1:0] tick_cnt; // Đếm chu trình tick_4x (0..3) tương ứng 4 pha của một chu kỳ SCL.
    reg [2:0] bit_cnt;  // Đếm ngược chỉ số bit đang truyền của 1 byte (từ 7 về 0).
    reg [7:0] tx_data;  // Thanh ghi dịch 8-bit chứa byte hiện tại đang được tuôn ra dây SDA.
    reg       byte_2nd; // Cờ theo dõi: 0 = Đang truyền Byte 1 (Sub-Addr), 1 = Đang truyền Byte 2 (Data).

    // =========================================================================
    // KHỐI 1: BỘ ĐẾM TICK ĐỘC LẬP TẠO 4 PHA I2C
    // Chức năng: Đếm chu kỳ tick_4x từ 0 đến 3 để tạo ra các pha truyền bit chuẩn.
    // =========================================================================
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            tick_cnt <= 2'd0; // Khi reset, đưa bộ đếm về 0.
        end
        else if (state == IDLE) begin
            tick_cnt <= 2'd0; // Reset bộ đếm khi đang ở trạng thái rảnh rỗi chờ lệnh.
        end
        else if (tick_4x) begin
            tick_cnt <= tick_cnt + 2'd1; // Mỗi xung tick_4x, tăng 1 giá trị (0->1->2->3->0).
        end
    end

    // =========================================================================
    // KHỐI 2: CHUYỂN ĐỔI TRẠNG THÁI TIẾP THEO (TỔ HỢP)
    // Chức năng: Điều khiển máy trạng thái (FSM) rẽ nhánh dựa trên điều kiện hiện tại.
    // =========================================================================
    always @(*) begin
        next_state = state; 
        
        case (state)
            IDLE: begin
                // Bắt đầu quá trình khi có cờ start.
                if (start) next_state = START; 
            end
            START: begin
                // Sau khi hoàn tất 4 tick của tín hiệu START, chuyển sang truyền Địa chỉ (ADDR).
                if (tick_4x && tick_cnt == 3) next_state = ADDR;
            end
            ADDR: begin
                // Nếu đã đếm đủ 4 tick của bit thứ 0 (bit cuối của byte), chuyển sang chờ ACK1.
                if (tick_4x && tick_cnt == 3 && bit_cnt == 0) next_state = ACK1;
            end
            ACK1: begin
                // Hết 4 tick của nhịp chờ ACK1, chuyển sang gửi dữ liệu DATA (Byte 1 - Sub Address).
                if (tick_4x && tick_cnt == 3) next_state = DATA;
            end
            DATA: begin
                // Nếu đã gửi xong bit cuối cùng (bit_cnt = 0) của byte dữ liệu, chuyển sang ACK2.
                if (tick_4x && tick_cnt == 3 && bit_cnt == 0) next_state = ACK2;
            end
            ACK2: begin
                if (tick_4x && tick_cnt == 3) begin
                    // Ở ACK2, logic quyết định liệu ta đã truyền xong cả 2 byte chưa.
                    if (byte_2nd == 1'b0) next_state = DATA; // Mới xong Byte 1 -> Vòng lại truyền Byte 2.
                    else                  next_state = STOP; // Đã xong Byte 2 -> Kết thúc (STOP).
                end
            end
            STOP: begin
                // Tạo xong tín hiệu kết thúc chuẩn, quay trở về IDLE an toàn.
                if (tick_4x && tick_cnt == 3) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // =========================================================================
    // KHỐI 3: LOGIC LƯU TRỮ VÀ XUẤT TÍN HIỆU ĐIỀU KHIỂN (TUẦN TỰ)
    // Chức năng: Điều khiển trực tiếp chân SCL, SDA(sda_oe) tuân thủ chặt chẽ I2C/SCCB.
    // =========================================================================
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            sda_oe <= 1'b0;          
            scl <= 1'b1;             
            enable_tick <= 1'b0; 
            ready <= 1'b1;           
            ack_error <= 1'b0;
            bit_cnt <= 3'd0;
            tx_data <= 8'd0;
            byte_2nd <= 1'b0;
        end
        else begin
            state <= next_state; // Cập nhật trạng thái mới cho FSM.
            
            // ----------------------------------------------------
            // LOGIC SCL CHUNG CHO CÁC PHA BÌNH THƯỜNG
            // Chu kỳ SCL chia 4 pha:
            // tick_cnt=0: SCL kéo xuống 0 (Cho phép SDA thay đổi).
            // tick_cnt=1: SCL kéo lên 1 (Cạnh lên, Slave chốt dữ liệu).
            // tick_cnt=2: SCL giữ ở 1 (Khoảng thời gian an toàn).
            // tick_cnt=3: SCL kéo xuống 0 (Cạnh xuống, chuẩn bị cho bit tiếp theo).
            // ----------------------------------------------------
            if (tick_4x) begin
                if (state == ADDR || state == DATA || state == ACK1 || state == ACK2) begin
                    if      (tick_cnt == 0) scl <= 1'b0; 
                    else if (tick_cnt == 1) scl <= 1'b1; 
                    else if (tick_cnt == 2) scl <= 1'b1; 
                    else if (tick_cnt == 3) scl <= 1'b0; 
                end
            end

            case(state)
                IDLE: begin
                    ready <= 1'b1; // Báo rảnh
                    if (start) begin
                        tx_data <= {slave_addr, rw}; // Gộp Address và R/W vào byte đầu.
                        bit_cnt <= 3'd7;       
                        enable_tick <= 1'b1;   
                        ready <= 1'b0;         // Master đang bận
                        ack_error <= 1'b0;     
                        byte_2nd <= 1'b0;      // Đánh dấu mới bắt đầu, chưa tới Byte 2
                    end
                    else begin
                        enable_tick <= 1'b0;
                        scl <= 1'b1;
                        sda_oe <= 1'b0;        // Đường bus nghỉ, mọi thứ ở mức cao.
                    end
                end

                START: begin
                    // ĐIỀU KIỆN START: SCL = 1 ổn định, nhưng SDA bị Master kéo từ 1 xuống 0.
                    if (tick_4x) begin
                        if      (tick_cnt == 0) sda_oe <= 1'b1; // Master giành quyền, kéo SDA = 0
                        else if (tick_cnt == 1) scl <= 1'b1;    
                        else if (tick_cnt == 2) scl <= 1'b1;    
                        else if (tick_cnt == 3) scl <= 1'b0;    
                    end
                end

                ADDR: begin
                    // Phát từng bit Địa chỉ ra đường SDA từ MSB xuống LSB.
                    if (tick_4x) begin
                        if (tick_cnt == 0) begin
                            // Tại tick 0, SCL đang là 0, an toàn để xuất bit mới.
                            if (tx_data[7] == 1'b1) sda_oe <= 1'b0; // Muốn SDA=1 -> Nhả sda_oe.
                            else                    sda_oe <= 1'b1; // Muốn SDA=0 -> Kéo sda_oe=1.
                        end
                        else if (tick_cnt == 3) begin
                            tx_data <= {tx_data[6:0], 1'b0}; // Dịch thanh ghi 1 bit sang trái.
                            if (bit_cnt != 0) bit_cnt <= bit_cnt - 1'd1;
                        end
                    end
                end
                
                ACK1: begin
                    // Master chờ Slave kéo SDA xuống 0 báo hiệu nhận thành công.
                    if (tick_4x) begin
                        case(tick_cnt)
                            2'd0: begin
                                sda_oe <= 1'b0; // Master bắt buộc nhả SDA để Slave điều khiển.
                            end
                            2'd2: begin
                                // Tại tick 2, SCL đang cao, Master đọc trạng thái SDA
                                if (sda == 1) ack_error <= 1'b1; // NACK! Có lỗi!
                                else          ack_error <= 1'b0; // ACK! Bình thường.
                            end
                            2'd3: begin
                                // Chuẩn bị cho pha DATA. Nạp Sub-Address từ data_in[15:8].
                                tx_data <= data_in[15:8]; 
                                bit_cnt <= 3'd7; 
                            end
                        endcase
                    end
                end

                DATA: begin
                    // Giống hệt pha ADDR, phát 8 bit dữ liệu.
                    if (tick_4x) begin
                        if (tick_cnt == 0) begin
                            if (tx_data[7] == 1'b1) sda_oe <= 1'b0;
                            else                    sda_oe <= 1'b1;
                        end
                        else if (tick_cnt == 3) begin
                            tx_data <= {tx_data[6:0], 1'b0}; 
                            if (bit_cnt != 0) bit_cnt <= bit_cnt - 1'd1;
                        end
                    end
                end

                ACK2: begin
                    // Nhận phản hồi ACK cho 1 Byte dữ liệu (có thể là Byte 1 hoặc Byte 2)
                    if (tick_4x) begin
                        case(tick_cnt)
                            2'd0: begin
                                sda_oe <= 1'b0; 
                            end
                            2'd2: begin
                                if (sda == 1) ack_error <= 1'b1; 
                                else          ack_error <= 1'b0;
                            end
                            2'd3: begin
                                // Cốt lõi của SCCB: Cấu trúc gửi tuần tự 2 Byte dữ liệu.
                                // Nếu mới gửi xong Sub-Address (byte_2nd = 0)...
                                if (byte_2nd == 1'b0) begin
                                    tx_data <= data_in[7:0]; // Nạp Byte dữ liệu trị (Data value).
                                    bit_cnt <= 3'd7;         
                                    byte_2nd <= 1'b1;        // Kích hoạt cờ báo chuyển sang pha Data cuối.
                                end
                            end
                        endcase
                    end
                end

                STOP: begin
                    // ĐIỀU KIỆN STOP: SCL = 1 ổn định, nhưng SDA bị Master thả từ 0 lên 1.
                    if (tick_4x) begin
                        case(tick_cnt)
                            2'd0: begin
                                scl <= 1'b0; 
                                sda_oe <= 1'b1; // Chủ động kéo SDA=0 trước để lát nữa có thể thả lên.
                            end
                            2'd1: begin
                                scl <= 1'b1; 
                            end
                            2'd2: begin
                                scl <= 1'b1; 
                            end
                            2'd3: begin
                                sda_oe <= 1'b0; // Thả nổi SDA, SDA sẽ bị điện trở kéo lên 1 (STOP!).
                                ready <= 1'b1;  // Kết thúc chu kỳ gửi, báo rảnh!
                            end
                        endcase
                    end
                end
            endcase
        end
    end

endmodule
