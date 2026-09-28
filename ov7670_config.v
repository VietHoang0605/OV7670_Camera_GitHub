// ============================================================================
// Module Name: ov7670_config
// NGUYÊN LÝ HOẠT ĐỘNG & DỊCH CHUYỂN TRẠNG THÁI (FSM):
// - Khối này lấy dữ liệu từ một Soft-ROM chứa 156 lệnh cấu hình OV7670 (VGA RGB565).
// - Chu trình FSM thực hiện Handshake với i2c_master như sau:
//   1. IDLE: Chờ hệ thống sẵn sàng và đợi 10ms sau khi cấp nguồn.
//   2. CHECK: Đọc lệnh từ ROM. Nếu gặp mã 16'hFFFF thì nhảy sang DONE. Nếu không, sang SEND.
//   3. SEND: Nạp lệnh, nháy cờ i2c_start = 1 (chỉ trong 1 nhịp đồng hồ) rồi nhảy sang WAIT_BUSY.
//   4. WAIT_BUSY: Chờ i2c_ready rớt xuống 0 (i2c_master đã nhận lệnh và bắt đầu bận truyền I2C).
//   5. WAIT_READY: Chờ i2c_ready lên lại 1 (i2c_master đã truyền xong 3 bytes I2C). Tăng chỉ số ROM lên 1.
//   6. DONE: Cấu hình xong, giương cờ config_done lên 1 để báo cho hệ thống.
// ============================================================================

`timescale 1ns / 1ps

module ov7670_config (
    // Đồng hồ và Reset
    input  wire        clk,          // Xung nhịp hệ thống 50MHz từ bộ dao động. FSM hoạt động theo xung này.
    input  wire        rst_n,        // Tín hiệu reset toàn mạch (Active-low). Kéo xuống 0 để reset khối cấu hình.

    // Giao tiếp với I2C Master
    input  wire        i2c_ready,    // Tín hiệu báo trạng thái từ i2c_master: 1 = Rảnh (sẵn sàng nhận lệnh), 0 = Bận (đang truyền I2C).
    output reg         i2c_start,    // Cờ vỗ vai kích hoạt i2c_master bắt đầu gửi lệnh. Nháy lên 1 trong 1 chu kỳ clock.
    output reg  [15:0] i2c_data,     // Dữ liệu 16-bit gửi cho i2c_master (8-bit địa chỉ thanh ghi + 8-bit giá trị cần ghi vào thanh ghi).

    // Trạng thái hệ thống
    output reg         config_done   // Cờ báo hiệu đã nạp xong toàn bộ băng đạn ROM cấu hình cho camera. 1 = Xong.
);

    // ========================================================================
    // CÁC HẰNG SỐ VÀ BIẾN STATE MACHINE (FSM)
    // ========================================================================
    localparam [15:0] END_OF_ROM_CMD = 16'hFFFF; // Mã chốt hạ băng đạn. Khi đọc được mã này, quá trình cấu hình kết thúc.

    // Khai báo các trạng thái của FSM bằng localparam để code dễ đọc hơn.
    localparam [2:0] 
        STATE_IDLE       = 3'd0, // Trạng thái nghỉ ban đầu, chờ delay.
        STATE_CHECK      = 3'd1, // Trạng thái kiểm tra mã lệnh (xem đã là FFFF chưa).
        STATE_SEND       = 3'd2, // Trạng thái gửi lệnh qua i2c_master.
        STATE_WAIT_BUSY  = 3'd3, // Trạng thái chờ i2c_master phản hồi bận (i2c_ready = 0).
        STATE_WAIT_READY = 3'd4, // Trạng thái chờ i2c_master truyền xong (i2c_ready = 1).
        STATE_DONE       = 3'd5; // Trạng thái hoàn thành cấu hình.

    reg [2:0] state_current; // Thanh ghi lưu trạng thái hiện tại của FSM.
    reg [2:0] state_next;    // Biến trung gian (wire) lưu trạng thái tiếp theo sẽ chuyển tới.
    
    reg [7:0] rom_index;     // Con trỏ / Lò xo đẩy đạn lên nòng, trỏ tới địa chỉ của mảng ROM chứa lệnh cấu hình.
    reg       rom_index_inc; // Cờ kích hoạt tăng con trỏ thêm 1 (khi 1 lệnh đã được cấu hình thành công).
    
    reg [15:0] rom_data;     // Biến trung gian (wire) lưu giá trị viên đạn 16-bit đọc được từ ROM tại vị trí rom_index.

    // ========================================================================
    // KHỐI 1: ROM CHỨA MÃ LỆNH CẤU HÌNH (VGA 640x480, RGB565, 30fps)
    // ========================================================================
    // MASTER ROM: OV7670 VGA RGB565 (FULL DSP + HARDWARE WINDOW + TRUE MATRIX)
    // LƯU Ý SỐNG CÒN: Tuyệt đối không thay đổi thứ tự và giá trị các lệnh này!
    // ========================================================================
    always @(*) begin
        case(rom_index)
            8'd0  : rom_data = 16'h1280;
            8'd1  : rom_data = 16'h1280;
            8'd2  : rom_data = 16'h1101;
            8'd3  : rom_data = 16'h3A04;
            8'd4  : rom_data = 16'h1204;
            8'd5  : rom_data = 16'h4010;
            8'd6  : rom_data = 16'h40D0;
            8'd7  : rom_data = 16'h1204;
            8'd8  : rom_data = 16'h3E00;
            8'd9  : rom_data = 16'h703A;
            8'd10 : rom_data = 16'h7135;
            8'd11 : rom_data = 16'h7211;
            8'd12 : rom_data = 16'h73F0;
            8'd13 : rom_data = 16'hA202;
            8'd14 : rom_data = 16'h1101;
            8'd15 : rom_data = 16'h1714;
            8'd16 : rom_data = 16'h1802;
            8'd17 : rom_data = 16'h3240;
            8'd18 : rom_data = 16'h1903;
            8'd19 : rom_data = 16'h1A7B;
            8'd20 : rom_data = 16'h030A;
            8'd21 : rom_data = 16'h1500;
            8'd22 : rom_data = 16'h7A20;
            8'd23 : rom_data = 16'h7B10;
            8'd24 : rom_data = 16'h7C1E;
            8'd25 : rom_data = 16'h7D35;
            8'd26 : rom_data = 16'h7E5A;
            8'd27 : rom_data = 16'h7F69;
            8'd28 : rom_data = 16'h8076;
            8'd29 : rom_data = 16'h8180;
            8'd30 : rom_data = 16'h8288;
            8'd31 : rom_data = 16'h838F;
            8'd32 : rom_data = 16'h8496;
            8'd33 : rom_data = 16'h85A3;
            8'd34 : rom_data = 16'h86AF;
            8'd35 : rom_data = 16'h87C4;
            8'd36 : rom_data = 16'h88D7;
            8'd37 : rom_data = 16'h89E8;
            8'd38 : rom_data = 16'h13E0;
            8'd39 : rom_data = 16'h0000;
            8'd40 : rom_data = 16'h1000;
            8'd41 : rom_data = 16'h0D40;
            8'd42 : rom_data = 16'h1418;
            8'd43 : rom_data = 16'hA505;
            8'd44 : rom_data = 16'hAB07;
            8'd45 : rom_data = 16'h2495;
            8'd46 : rom_data = 16'h2533;
            8'd47 : rom_data = 16'h26E3;
            8'd48 : rom_data = 16'h9F78;
            8'd49 : rom_data = 16'hA068;
            8'd50 : rom_data = 16'hA103;
            8'd51 : rom_data = 16'hA6D8;
            8'd52 : rom_data = 16'hA7D8;
            8'd53 : rom_data = 16'hA8F0;
            8'd54 : rom_data = 16'hA990;
            8'd55 : rom_data = 16'hAA94;
            8'd56 : rom_data = 16'h13E5;
            8'd57 : rom_data = 16'h0E61;
            8'd58 : rom_data = 16'h0F4B;
            8'd59 : rom_data = 16'h1602;
            8'd60 : rom_data = 16'h1E37;
            8'd61 : rom_data = 16'h2102;
            8'd62 : rom_data = 16'h2291;
            8'd63 : rom_data = 16'h2907;
            8'd64 : rom_data = 16'h330B;
            8'd65 : rom_data = 16'h350B;
            8'd66 : rom_data = 16'h371D;
            8'd67 : rom_data = 16'h3871;
            8'd68 : rom_data = 16'h392A;
            8'd69 : rom_data = 16'h3C78;
            8'd70 : rom_data = 16'h4D40;
            8'd71 : rom_data = 16'h4E20;
            8'd72 : rom_data = 16'h6900;
            8'd73 : rom_data = 16'h6B4A;
            8'd74 : rom_data = 16'h7410;
            8'd75 : rom_data = 16'h8D4F;
            8'd76 : rom_data = 16'h8E00;
            8'd77 : rom_data = 16'h8F00;
            8'd78 : rom_data = 16'h9000;
            8'd79 : rom_data = 16'h9100;
            8'd80 : rom_data = 16'h9600;
            8'd81 : rom_data = 16'h9A00;
            8'd82 : rom_data = 16'hB084;
            8'd83 : rom_data = 16'hB10C;
            8'd84 : rom_data = 16'hB20E;
            8'd85 : rom_data = 16'hB382;
            8'd86 : rom_data = 16'hB80A;
            8'd87 : rom_data = 16'h430A;
            8'd88 : rom_data = 16'h44F0;
            8'd89 : rom_data = 16'h4534;
            8'd90 : rom_data = 16'h4658;
            8'd91 : rom_data = 16'h4728;
            8'd92 : rom_data = 16'h483A;
            8'd93 : rom_data = 16'h5988;
            8'd94 : rom_data = 16'h5A88;
            8'd95 : rom_data = 16'h5B44;
            8'd96 : rom_data = 16'h5C67;
            8'd97 : rom_data = 16'h5D49;
            8'd98 : rom_data = 16'h5E0E;
            8'd99 : rom_data = 16'h6C0A;
            8'd100: rom_data = 16'h6D55;
            8'd101: rom_data = 16'h6E11;
            8'd102: rom_data = 16'h6F9F;
            8'd103: rom_data = 16'h6A40;
            8'd104: rom_data = 16'h0140;
            8'd105: rom_data = 16'h0260;
            8'd106: rom_data = 16'h13E7;
            8'd107: rom_data = 16'h4FB3;
            8'd108: rom_data = 16'h50B3;
            8'd109: rom_data = 16'h5100;
            8'd110: rom_data = 16'h523D;
            8'd111: rom_data = 16'h53A7;
            8'd112: rom_data = 16'h54E4;
            8'd113: rom_data = 16'h589E;
            8'd114: rom_data = 16'h4108;
            8'd115: rom_data = 16'h3F00;
            8'd116: rom_data = 16'h7505;
            8'd117: rom_data = 16'h76E1;
            8'd118: rom_data = 16'h4C00;
            8'd119: rom_data = 16'h7701;
            8'd120: rom_data = 16'h3D48;
            8'd121: rom_data = 16'h4B09;
            8'd122: rom_data = 16'hC960;
            8'd123: rom_data = 16'h4138;
            8'd124: rom_data = 16'h5640;
            8'd125: rom_data = 16'h3411;
            8'd126: rom_data = 16'h3B12;
            8'd127: rom_data = 16'hA488;
            8'd128: rom_data = 16'h9600;
            8'd129: rom_data = 16'h9730;
            8'd130: rom_data = 16'h9820;
            8'd131: rom_data = 16'h9930;
            8'd132: rom_data = 16'h9A84;
            8'd133: rom_data = 16'h9B29;
            8'd134: rom_data = 16'h9C03;
            8'd135: rom_data = 16'h9D4C;
            8'd136: rom_data = 16'h9E3F;
            8'd137: rom_data = 16'h7804;
            8'd138: rom_data = 16'h7901;
            8'd139: rom_data = 16'hC8F0;
            8'd140: rom_data = 16'h790F;
            8'd141: rom_data = 16'hC800;
            8'd142: rom_data = 16'h7910;
            8'd143: rom_data = 16'hC87E;
            8'd144: rom_data = 16'h790A;
            8'd145: rom_data = 16'hC880;
            8'd146: rom_data = 16'h790B;
            8'd147: rom_data = 16'hC801;
            8'd148: rom_data = 16'h790C;
            8'd149: rom_data = 16'hC80F;
            8'd150: rom_data = 16'h790D;
            8'd151: rom_data = 16'hC820;
            8'd152: rom_data = 16'h7909;
            8'd153: rom_data = 16'hC880;
            8'd154: rom_data = 16'h7902;
            8'd155: rom_data = 16'hC8C0;
            8'd156: rom_data = 16'h7903;
            8'd157: rom_data = 16'hC840;
            8'd158: rom_data = 16'h7905;
            8'd159: rom_data = 16'hC830;
            8'd160: rom_data = 16'h7926;
            8'd161: rom_data = 16'h0903;
            8'd162: rom_data = 16'h3B42;
            
            // ================================================================
            // [CẤU HÌNH TỐI ƯU VÀ CÂN BẰNG NHẤT]
            // Giải quyết: Nhòe (Bật lại Edge), Đốm tím (Bật Denoise nhẹ), Tối (Bật Night Mode)
            // ================================================================
            8'd163: rom_data = 16'h4138; // COM16: BẬT LẠI Edge Enhancement (Lấy lại độ NÉT CĂNG như ban đầu)
            8'd164: rom_data = 16'h4C04; // DNSTH: Denoise nhẹ (0x04). Đủ để xóa đốm tím nhưng không làm nhòe ảnh.
            8'd165: rom_data = 16'h1418; // COM9: Ép AGC Ceiling ở mức thấp (4x) giống nguyên bản để dập tắt nhiễu hạt.
            8'd166: rom_data = 16'h3B8A; // COM11: Bật Night Mode (Tự động kéo dài thời gian phơi sáng). Sáng bừng mà không bị nhiễu!
            8'd167: rom_data = 16'h13E7; // COM8: Bật Auto Exposure, Auto Gain, Auto White Balance
            
            default: rom_data = END_OF_ROM_CMD; // Trả về lệnh 16'hFFFF (kết thúc cấu hình) nếu vượt quá chỉ số ROM
        endcase
    end

    // =========================================================================
    // KHỐI 2: CẬP NHẬT TRẠNG THÁI (Sequential Logic)
    // =========================================================================
    reg [19:0] delay_cnt; // Bộ đếm 20-bit (lên tới 1.04 triệu). 500,000 xung clk 50MHz tương đương 10ms.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset các thanh ghi về trạng thái khởi tạo
            state_current <= STATE_IDLE;
            rom_index     <= 8'd0;
            delay_cnt     <= 20'd0;
        end else begin
            // Cập nhật trạng thái tiếp theo cho FSM
            state_current <= state_next;
            
            // Tăng con trỏ ROM nếu cờ kích hoạt bằng 1
            if (rom_index_inc) begin
                rom_index <= rom_index + 8'd1;
            end

            // Xử lý bộ đếm delay (thời gian trễ)
            // Cần trễ 10ms ở trạng thái IDLE (khi khởi động) hoặc khi gửi lệnh reset camera (1280)
            if (state_current == STATE_IDLE || (state_current == STATE_SEND && rom_data == 16'h1280)) begin
                delay_cnt <= 20'd500_000; // Đặt giá trị 500,000 để đếm ngược tạo trễ 10ms
            end else if (delay_cnt > 0) begin
                delay_cnt <= delay_cnt - 1'b1; // Giảm dần bộ đếm
            end
        end
    end
    
    // =========================================================================
    // KHỐI 3: DỊCH CHUYỂN TRẠNG THÁI (Next State Logic)
    // =========================================================================
    always @(*) begin
        // Khởi tạo các giá trị mặc định để tránh chốt (latch)
        state_next    = state_current;
        rom_index_inc = 1'b0;

        case (state_current)
            STATE_IDLE: begin
                // Đợi 10ms sau khi cấp nguồn rồi mới bắt đầu (i2c_ready = 1 và delay_cnt = 0)
                if(i2c_ready && delay_cnt == 0) begin
                    state_next = STATE_CHECK;
                end
            end
            STATE_CHECK: begin
                // Kiểm tra xem lệnh cấu hình đã hết chưa
                if(rom_data == END_OF_ROM_CMD) begin
                    state_next = STATE_DONE; // Chuyển sang DONE nếu đọc được mã FFFF
                end
                else begin
                    state_next = STATE_SEND; // Chuyển sang SEND để gửi lệnh
                end
            end
            STATE_SEND: begin
                // Sau khi ra lệnh gửi, chuyển sang WAIT_BUSY ngay
                state_next = STATE_WAIT_BUSY;
            end
            STATE_WAIT_BUSY: begin
                // Chờ i2c_master báo bận (i2c_ready = 0)
                // Phải chờ i2c_master nhận được tín hiệu start và kéo ready xuống 0
                if(i2c_ready == 1'b0) begin
                    state_next = STATE_WAIT_READY;
                end
            end
            STATE_WAIT_READY: begin
                // Chờ i2c_master truyền xong và báo rảnh (i2c_ready = 1)
                if(i2c_ready == 1'b1) begin
                    // Nếu là lệnh reset (1280), bắt buộc chờ delay_cnt cạn mới đi tiếp để camera kịp khởi động lại
                    if (rom_data == 16'h1280 && delay_cnt > 0) begin
                        state_next = STATE_WAIT_READY;
                    end else begin
                        rom_index_inc = 1'b1; // Bật cờ tăng chỉ số ROM lên 1
                        state_next = STATE_CHECK;  // Quay lại CHECK để lấy lệnh tiếp theo
                    end
                end
            end
            STATE_DONE: begin
                // Mắc kẹt ở trạng thái này sau khi cấu hình xong
                state_next = STATE_DONE;
            end
            default: state_next = STATE_IDLE; // Bảo vệ FSM khỏi trạng thái lạ
        endcase
    end
    
    // =========================================================================
    // KHỐI 4: ĐIỀU KHIỂN ĐẦU RA (Output Logic)
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Xóa sạch các tín hiệu đầu ra khi reset
            i2c_start   <= 1'b0;
            i2c_data    <= 16'd0;
            config_done <= 1'd0;
        end else begin
            case (state_current)
                STATE_SEND: begin
                    i2c_start <= 1'b1;       // Kích hoạt cờ gửi lệnh
                    i2c_data  <= rom_data;   // Nạp dữ liệu lệnh cấu hình vào bus
                end
                STATE_WAIT_BUSY: begin
                    i2c_start <= 1'b0;       // Tắt cờ i2c_start ngay nhịp sau đó để tránh i2c_master gửi lặp lại
                end
                STATE_DONE: begin
                    config_done <= 1'b1;     // Giương cờ báo cấu hình xong
                end
                default: begin
                    i2c_start <= 1'b0;       // Giữ i2c_start ở 0 ở các trạng thái khác
                end
            endcase
        end
    end

endmodule
