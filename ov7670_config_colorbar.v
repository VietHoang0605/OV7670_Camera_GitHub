// ============================================================================
// Module Name: ov7670_config
// NGUYÃŠN LÃ HOáº T Äá»˜NG & Dá»ŠCH CHUYá»‚N TRáº NG THÃI (FSM):
// - Khá»‘i nÃ y láº¥y dá»¯ liá»‡u tá»« má»™t Soft-ROM chá»©a 156 lá»‡nh cáº¥u hÃ¬nh OV7670 (VGA RGB565).
// - Chu trÃ¬nh FSM thá»±c hiá»‡n Handshake vá»›i i2c_master nhÆ° sau:
//   1. IDLE: Chá» há»‡ thá»‘ng sáºµn sÃ ng.
//   2. CHECK: Äá»c lá»‡nh tá»« ROM. Náº¿u gáº·p mÃ£ 16'hFFFF thÃ¬ nháº£y sang DONE. Náº¿u khÃ´ng, sang SEND.
//   3. SEND: Náº¡p lá»‡nh, nhÃ¡y cá» i2c_start = 1 (chá»‰ trong 1 nhá»‹p) rá»“i nháº£y sang WAIT_BUSY.
//   4. WAIT_BUSY: Chá» i2c_ready rá»›t xuá»‘ng 0 (i2c_master Ä‘Ã£ nháº­n lá»‡nh vÃ  báº¯t Ä‘áº§u báº­n).
//   5. WAIT_READY: Chá» i2c_ready lÃªn láº¡i 1 (i2c_master Ä‘Ã£ truyá»n xong 3 bytes). TÄƒng chá»‰ sá»‘ ROM.
//   6. DONE: Cáº¥u hÃ¬nh xong, giÆ°Æ¡ng cá» config_done.
// ============================================================================

`timescale 1ns / 1ps

module ov7670_config (
    // Äá»“ng há»“ vÃ  Reset
    input  wire        clk,          // Xung nhá»‹p há»‡ thá»‘ng 50MHz
    input  wire        rst_n,        // TÃ­n hiá»‡u reset toÃ n máº¡ch (Active-low)

    // Giao tiáº¿p vá»›i I2C Master
    input  wire        i2c_ready,    // TÃ­n hiá»‡u bÃ¡o tráº¡ng thÃ¡i tá»« i2c_master (1 = Ráº£nh, 0 = Báº­n)
    output reg         i2c_start,    // Cá» vá»— vai kÃ­ch hoáº¡t i2c_master gá»­i lá»‡nh
    output reg  [15:0] i2c_data,     // Dá»¯ liá»‡u 16-bit (8-bit Ä‘á»‹a chá»‰ thanh ghi + 8-bit giÃ¡ trá»‹)

    // Tráº¡ng thÃ¡i há»‡ thá»‘ng
    output reg         config_done   // Cá» bÃ¡o hiá»‡u Ä‘Ã£ náº¡p xong toÃ n bá»™ bÄƒng Ä‘áº¡n ROM
);

    // ========================================================================
    // CÃC Háº°NG Sá» VÃ€ BIáº¾N STATE MACHINE
    // ========================================================================
    localparam [15:0] END_OF_ROM_CMD = 16'hFFFF; // MÃ£ chá»‘t háº¡ bÄƒng Ä‘áº¡n

    localparam [2:0] 
        STATE_IDLE       = 3'd0,
        STATE_CHECK      = 3'd1,
        STATE_SEND       = 3'd2,
        STATE_WAIT_BUSY  = 3'd3,
        STATE_WAIT_READY = 3'd4,
        STATE_DONE       = 3'd5;

    reg [2:0] state_current, state_next; // Thanh ghi tráº¡ng thÃ¡i hiá»‡n táº¡i vÃ  tiáº¿p theo
    
    reg [7:0] rom_index;                 // Con trá» / LÃ² xo Ä‘áº©y Ä‘áº¡n lÃªn nÃ²ng
    reg       rom_index_inc;             // Cá» kÃ­ch hoáº¡t tÄƒng con trá» thÃªm 1
    
    reg [15:0] rom_data;                 // LÆ°u giÃ¡ trá»‹ viÃªn Ä‘áº¡n 16-bit Ä‘á»c Ä‘Æ°á»£c tá»« ROM

    // ========================================================================
    // KHỐI 1: ROM CHỨA MÃ LỆNH CẤU HÌNH (VGA 640x480, RGB565, 30fps)
    // ========================================================================
    always @(*) begin
        case(rom_index)
            8'd0:   rom_data = 16'h1280;
            8'd1:   rom_data = 16'h4208; // COM17: DSP Color Bar
            8'd2:   rom_data = 16'h1100;
            8'd3:   rom_data = 16'h3a04;
            8'd4:   rom_data = 16'h1206; // ENABLE COLOR BAR
            8'd5:   rom_data = 16'h4010;
            8'd6:   rom_data = 16'h40d0;
            8'd7:   rom_data = 16'h1206; // ENABLE COLOR BAR // [FIX] COM7 = 0x04 (VGA, RGB) thay vì 0x14 (QVGA)
            8'd8:   rom_data = 16'h3e00;
            8'd9:   rom_data = 16'h70ba; // SCALING_XSC: Test Pattern
            8'd10:  rom_data = 16'h71b5; // SCALING_YSC: Test Pattern
            8'd11:  rom_data = 16'h7211;
            8'd12:  rom_data = 16'h73f0;
            8'd13:  rom_data = 16'ha202;
            8'd14:  rom_data = 16'h1100; // [FIX] CLKRC = 0x00 (Không chia clock) để chạy mượt 30fps thay vì 0x14
            8'd15:  rom_data = 16'h7a20;
            8'd16:  rom_data = 16'h7b10;
            8'd17:  rom_data = 16'h7c1e;
            8'd18:  rom_data = 16'h7d35;
            8'd19:  rom_data = 16'h7e5a;
            8'd20:  rom_data = 16'h7f69;
            8'd21:  rom_data = 16'h8076;
            8'd22:  rom_data = 16'h8180;
            8'd23:  rom_data = 16'h8288;
            8'd24:  rom_data = 16'h838f;
            8'd25:  rom_data = 16'h8496;
            8'd26:  rom_data = 16'h85a3;
            8'd27:  rom_data = 16'h86af;
            8'd28:  rom_data = 16'h87c4;
            8'd29:  rom_data = 16'h88d7;
            8'd30:  rom_data = 16'h89e8;
            8'd31:  rom_data = 16'h13c0; // COM8: Disable AGC/AEC
            8'd32:  rom_data = 16'h0000;
            8'd33:  rom_data = 16'h1000;
            8'd34:  rom_data = 16'h0d40;
            8'd35:  rom_data = 16'h1418;
            8'd36:  rom_data = 16'ha505;
            8'd37:  rom_data = 16'hab07;
            8'd38:  rom_data = 16'h2495;
            8'd39:  rom_data = 16'h2533;
            8'd40:  rom_data = 16'h26e3;
            8'd41:  rom_data = 16'h9f78;
            8'd42:  rom_data = 16'ha068;
            8'd43:  rom_data = 16'ha103;
            8'd44:  rom_data = 16'ha6d8;
            8'd45:  rom_data = 16'ha7d8;
            8'd46:  rom_data = 16'ha8f0;
            8'd47:  rom_data = 16'ha990;
            8'd48:  rom_data = 16'haa94;
            8'd49:  rom_data = 16'h13c0; // COM8: Disable AGC/AEC
            8'd50:  rom_data = 16'h0e61;
            8'd51:  rom_data = 16'h0f4b;
            8'd52:  rom_data = 16'h1602;
            8'd53:  rom_data = 16'h1e37;
            8'd54:  rom_data = 16'h2102;
            8'd55:  rom_data = 16'h2291;
            8'd56:  rom_data = 16'h2907;
            8'd57:  rom_data = 16'h330b;
            8'd58:  rom_data = 16'h350b;
            8'd59:  rom_data = 16'h371d;
            8'd60:  rom_data = 16'h3871;
            8'd61:  rom_data = 16'h392a;
            8'd62:  rom_data = 16'h3c78;
            8'd63:  rom_data = 16'h4d40;
            8'd64:  rom_data = 16'h4e20;
            8'd65:  rom_data = 16'h6900;
            8'd66:  rom_data = 16'h6b4a;
            8'd67:  rom_data = 16'h7410;
            8'd68:  rom_data = 16'h8d4f;
            8'd69:  rom_data = 16'h8e00;
            8'd70:  rom_data = 16'h8f00;
            8'd71:  rom_data = 16'h9000;
            8'd72:  rom_data = 16'h9100;
            8'd73:  rom_data = 16'h9600;
            8'd74:  rom_data = 16'h9a00;
            8'd75:  rom_data = 16'hb084;
            8'd76:  rom_data = 16'hb10c;
            8'd77:  rom_data = 16'hb20e;
            8'd78:  rom_data = 16'hb382;
            8'd79:  rom_data = 16'hb80a;
            8'd80:  rom_data = 16'h430a;
            8'd81:  rom_data = 16'h44f0;
            8'd82:  rom_data = 16'h4534;
            8'd83:  rom_data = 16'h4658;
            8'd84:  rom_data = 16'h4728;
            8'd85:  rom_data = 16'h483a;
            8'd86:  rom_data = 16'h5988;
            8'd87:  rom_data = 16'h5a88;
            8'd88:  rom_data = 16'h5b44;
            8'd89:  rom_data = 16'h5c67;
            8'd90:  rom_data = 16'h5d49;
            8'd91:  rom_data = 16'h5e0e;
            8'd92:  rom_data = 16'h6c0a;
            8'd93:  rom_data = 16'h6d55;
            8'd94:  rom_data = 16'h6e11;
            8'd95:  rom_data = 16'h6f9f;
            8'd96:  rom_data = 16'h6a40;
            8'd97:  rom_data = 16'h0140;
            8'd98:  rom_data = 16'h0260;
            8'd99:  rom_data = 16'h13c0; // COM8: Disable AGC/AEC
            8'd100: rom_data = 16'h4f80;
            8'd101: rom_data = 16'h5080;
            8'd102: rom_data = 16'h5100;
            8'd103: rom_data = 16'h5222;
            8'd104: rom_data = 16'h535e;
            8'd105: rom_data = 16'h5480;
            8'd106: rom_data = 16'h589e;
            8'd107: rom_data = 16'h4108;
            8'd108: rom_data = 16'h3f00;
            8'd109: rom_data = 16'h7505;
            8'd110: rom_data = 16'h76e1;
            8'd111: rom_data = 16'h4c00;
            8'd112: rom_data = 16'h7701;
            8'd113: rom_data = 16'h3d48;
            8'd114: rom_data = 16'h4b09;
            8'd115: rom_data = 16'hc960;
            8'd116: rom_data = 16'h4138;
            8'd117: rom_data = 16'h5640;
            8'd118: rom_data = 16'h3411;
            8'd119: rom_data = 16'h3b12;
            8'd120: rom_data = 16'ha488;
            8'd121: rom_data = 16'h9600;
            8'd122: rom_data = 16'h9730;
            8'd123: rom_data = 16'h9820;
            8'd124: rom_data = 16'h9930;
            8'd125: rom_data = 16'h9a84;
            8'd126: rom_data = 16'h9b29;
            8'd127: rom_data = 16'h9c03;
            8'd128: rom_data = 16'h9d4c;
            8'd129: rom_data = 16'h9e3f;
            8'd130: rom_data = 16'h7804;
            8'd131: rom_data = 16'h7901;
            8'd132: rom_data = 16'hc8f0;
            8'd133: rom_data = 16'h790f;
            8'd134: rom_data = 16'hc800;
            8'd135: rom_data = 16'h7910;
            8'd136: rom_data = 16'hc87e;
            8'd137: rom_data = 16'h790a;
            8'd138: rom_data = 16'hc880;
            8'd139: rom_data = 16'h790b;
            8'd140: rom_data = 16'hc801;
            8'd141: rom_data = 16'h790c;
            8'd142: rom_data = 16'hc80f;
            8'd143: rom_data = 16'h790d;
            8'd144: rom_data = 16'hc820;
            8'd145: rom_data = 16'h7909;
            8'd146: rom_data = 16'hc880;
            8'd147: rom_data = 16'h7902;
            8'd148: rom_data = 16'hc8c0;
            8'd149: rom_data = 16'h7903;
            8'd150: rom_data = 16'hc840;
            8'd151: rom_data = 16'h7905;
            8'd152: rom_data = 16'hc830;
            8'd153: rom_data = 16'h7926;
            8'd154: rom_data = 16'h0903;
            8'd155: rom_data = 16'h3b42;
            default: rom_data = END_OF_ROM_CMD;
        endcase
    end

    // =========================================================================
    // KHá»I 2: Cáº¬P NHáº¬T TRáº NG THÃI (Sequential Logic)
    // =========================================================================
    reg [19:0] delay_cnt; // Bá»™ Ä‘áº¿m 20-bit (lÃªn tá»›i 1.04 triá»‡u). 500,000 xung = 10ms.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_current <= STATE_IDLE;
            rom_index <= 8'd0;
            delay_cnt <= 20'd0;
        end else begin
            state_current <= state_next;
            
            // TÄƒng con trá» ROM
            if (rom_index_inc) begin
                rom_index <= rom_index + 8'd1;
            end

            // Xá»­ lÃ½ bá»™ Ä‘áº¿m delay
            if (state_current == STATE_IDLE || (state_current == STATE_SEND && rom_data == 16'h1280)) begin
                delay_cnt <= 20'd500_000; // Äáº·t 10ms
            end else if (delay_cnt > 0) begin
                delay_cnt <= delay_cnt - 1'b1;
            end
        end
    end
    
    // =========================================================================
    // KHá»I 3: Dá»ŠCH CHUYá»‚N TRáº NG THÃI (Next State Logic)
    // =========================================================================
    always @(*) begin
        state_next    = state_current;
        rom_index_inc = 1'b0;

        case (state_current)
            STATE_IDLE: begin
                // Äá»£i 10ms sau khi cáº¥p nguá»“n rá»“i má»›i báº¯t Ä‘áº§u
                if(i2c_ready && delay_cnt == 0) begin
                    state_next = STATE_CHECK;
                end
            end
            STATE_CHECK: begin
                if(rom_data == END_OF_ROM_CMD) begin
                    state_next = STATE_DONE;
                end
                else begin
                    state_next = STATE_SEND;
                end
            end
            STATE_SEND: begin
                state_next = STATE_WAIT_BUSY;
            end
            STATE_WAIT_BUSY: begin
                // Náº¿u Ä‘Ã¢y lÃ  lá»‡nh Reset (1280), Ä‘á»£i delay_cnt = 0 má»›i sang WAIT_READY
                // NhÆ°ng i2c_ready sáº½ báº­n trong lÃºc gá»­i. Wait, I2C master nháº­n lá»‡nh máº¥t vÃ i ms.
                if(i2c_ready == 1'b0) begin
                    state_next = STATE_WAIT_READY;
                end
            end
            STATE_WAIT_READY: begin
                if(i2c_ready == 1'b1) begin
                    // Náº¿u lÃ  lá»‡nh 1280, báº¯t buá»™c chá» delay_cnt cáº¡n má»›i Ä‘i tiáº¿p
                    if (rom_data == 16'h1280 && delay_cnt > 0) begin
                        state_next = STATE_WAIT_READY;
                    end else begin
                        rom_index_inc = 1'b1;
                        state_next = STATE_CHECK;  
                    end
                end
            end
            STATE_DONE: begin
                state_next = STATE_DONE;
            end
            default: state_next = STATE_IDLE;
        endcase
    end
    
    // =========================================================================
    // KHá»I 4: ÄIá»€U KHIá»‚N Äáº¦U RA (Output Logic)
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i2c_start <= 1'b0;
            i2c_data <= 16'd0;
            config_done <= 1'd0;
        end else begin
            case (state_current)
                STATE_SEND: begin
                    i2c_start <= 1'b1;
                    i2c_data <= rom_data;
                end
                STATE_WAIT_BUSY: begin
                    i2c_start <= 1'b0;
                end
                STATE_DONE: begin
                    config_done <= 1'b1;
                end
                default: begin
                    i2c_start <= 1'b0;
                end
            endcase
        end
    end

endmodule


