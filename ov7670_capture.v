`timescale 1ns / 1ps
// ============================================================================
// Module Name:    ov7670_capture
// Project Name:   OV7670 Camera to VGA / SDRAM Display System
// Target Devices: FPGA (Xilinx Artix-7/Spartan-6, Altera Cyclone, Gowin, v.v.)
// Tool Versions:  Vivado / Quartus / Gowin EDA
// Description:    Module Scaffolding thu nhận luồng pixel 8-bit từ Camera OV7670,
//                 ghép 2 byte liên tiếp thành 1 pixel 16-bit (RGB565),
//                 quản lý con trỏ địa chỉ pixel (addr) và xung ghi (we) vào FIFO.
//
// Author:         Agent 2 - Chuyên gia Scaffolding & Review Code
// Reviewer:       Sếp (Hardware Lead)
// ============================================================================

module ov7670_capture (
    // ========================================================================
    // 1. CÁC CỔNG GIAO TIẾP VỚI CẢM BIẾN ẢNH OV7670 (CAMERA INTERFACE)
    // ========================================================================
    input  wire        pclk,   // Pixel Clock: Xung nhịp pixel do Camera phát ra (~12MHz - 24MHz).
                               // Mọi thanh ghi trong module này đều đồng bộ theo sườn dương của PCLK.
    
    input  wire        vsync,  // Vertical Sync: Tín hiệu đồng bộ khung hình từ Camera.
                               // [GHI CHÚ]: Mặc định thanh ghi COM10 của OV7670 xuất VSYNC tích cực HIGH
                               // khi bắt đầu khung hình mới (Frame Blanking/Start).
    
    input  wire        href,   // Horizontal Reference: Tín hiệu báo dữ liệu dòng hợp lệ.
                               // HREF = 1: Camera đang truyền các byte điểm ảnh của dòng hiện tại.
                               // HREF = 0: Khoảng trống quét ngang (Line Blanking), không có dữ liệu.
    
    input  wire [7:0]  d,      // Data Bus [7:0]: Kênh dữ liệu song song 8-bit nhận từ chân D0-D7 Camera.

    // ========================================================================
    // 2. CÁC CỔNG GIAO TIẾP VỚI HỆ THỐNG PHÍA SAU (ASYNC FIFO / SDRAM CONTROLLER)
    // ========================================================================
    output reg  [18:0] addr,   // Pixel Address: Địa chỉ tọa độ điểm ảnh trong bộ đệm khung (Frame Buffer).
                               // [GHI CHÚ]: Độ rộng 19-bit (2^19 = 524,288) vừa vặn chứa toàn bộ
                               // 307,200 pixel của chuẩn VGA 640x480 (640 * 480 = 307,200 < 524,288).
    
    output reg  [15:0] dout,   // Pixel Data Out [15:0]: Dữ liệu màu 16-bit chuẩn RGB565 hoàn chỉnh.
                               // Ghép từ 2 chu kỳ byte:
                               //   - Byte cao [15:8]: { R[4:0], G[5:3] }
                               //   - Byte thấp  [7:0]: { G[2:0], B[4:0] }
    
    output reg         we      // Write Enable: Tín hiệu cho phép ghi vào Async FIFO.
                               // Tích cực HIGH đúng 1 chu kỳ PCLK ngay khi ghép đủ 1 pixel 16-bit.
);

    // ========================================================================
    // 3. CÁC THANH GHI LƯU TRỮ TRẠNG THÁI NỘI BỘ (INTERNAL REGISTERS)
    // ========================================================================
    reg [7:0] byte_high;  // Thanh ghi đệm lưu byte đầu tiên (Byte cao) của cặp pixel
    reg       byte_sel;   // Cờ luân chuyển byte (Phase Toggle):
                          //   - byte_sel = 1'b0: Đang đón byte cao (Byte 1)
                          //   - byte_sel = 1'b1: Đang đón byte thấp (Byte 2) và chuẩn bị xuất pixel

    // ========================================================================
    // 4. KHỞI TẠO GIÁ TRỊ BAN ĐẦU CHO CÁC THANH GHI (SIMULATION & FPGA POWER-UP)
    // ========================================================================
    initial begin
        addr      = 19'd0;
        dout      = 16'd0;
        we        = 1'b0;
        byte_high = 8'd0;
        byte_sel  = 1'b0;
    end

    // ========================================================================
    // 5. KHỐI LOGIC TUẦN TỰ DUY NHẤT (SINGLE SEQUENTIAL ALWAYS BLOCK)
    //    Tuân thủ tuyệt đối quy định: Mọi hành vi đều chốt theo sườn dương PCLK!
    // ========================================================================
    always @(posedge pclk) begin

      

        // --------------------------------------------------------------------
        // NHÁNH 1: XỬ LÝ ĐỒNG BỘ KHUNG HÌNH (VSYNC RESET)
        // --------------------------------------------------------------------
        /*
        *******************************************************************************
        * [CẢNH BÁO ĐỎ TỪ AGENT 2 - CHỐNG LỆCH BYTE (BYTE MISALIGNMENT DISASTER)]     *
        *******************************************************************************
        * - Hiện tượng: Mỗi điểm ảnh RGB565 gồm đúng 2 byte. Nếu trong quá trình chạy,*
        *   Camera bị nhiễu đường truyền, rớt 1 byte hoặc mạch FPGA khởi động giữa    *
        *   chừng, hệ thống sẽ bị LỆCH PHA BYTE: Byte thấp của pixel này bị ghép nhầm *
        *   với Byte cao của pixel sau!                                               *
        *   Hậu quả: Toàn bộ màu sắc bị đảo lộn (kênh Xanh/Đỏ nhảy lung tung, màn hình*
        *   bị sọc hoặc ám tím).                                                      *
        * - Biện pháp: BẮT BUỘC dùng tín hiệu VSYNC ở đầu mỗi khung hình để RESET:    *
        *     + addr     <= 19'd0; (Đưa con trỏ bộ nhớ về đầu khung)                  *
        *     + byte_sel <= 1'b0;  (Cưỡng chế đưa pha về trạng thái đón Byte cao)     *
        *     + we       <= 1'b0;  (Hạ cờ ghi an toàn)                                *
        *******************************************************************************
        */
        if (vsync == 1'b1) begin // Mặc định VSYNC tích cực HIGH lúc chuyển khung hình
            // TODO: [DÀNH CHO SẾP] Reset con trỏ địa chỉ `addr`, cờ `byte_sel` và `we` về trạng thái ban đầu!

              addr     <= 19'd0;
              byte_sel <= 1'b0;
              we       <= 1'b0;
        end

        // --------------------------------------------------------------------
        // NHÁNH 2: XỬ LÝ DỮ LIỆU ĐIỂM ẢNH HỢP LỆ (HREF ACTIVE - DATA STREAMING)
        // --------------------------------------------------------------------
        /*
        *******************************************************************************
        * [CẢNH BÁO ĐỎ TỪ AGENT 2 - THUẬT TOÁN "GẮP KẸO" 2 THÌ (2-BYTE SAMPLING)]     *
        *******************************************************************************
        * Khi HREF = 1, mỗi chu kỳ PCLK sẽ đưa về 1 byte điểm ảnh:                    *
        * - THÌ 1 (byte_sel == 1'b0): Camera đang đẩy Byte CAO ({R[4:0], G[5:3]}).    *
        *   -> Nhiệm vụ: Gắp byte này cất vào thanh ghi tạm `byte_high`.              *
        *   -> Lật cờ: `byte_sel <= 1'b1` để chu kỳ sau đón byte thấp.                *
        *   -> Giữ `we <= 1'b0` (Chưa gom đủ 16-bit thì KHÔNG được kích hoạt ghi FIFO)*
        *                                                                             *
        * - THÌ 2 (byte_sel == 1'b1): Camera đang đẩy Byte THẤP ({G[2:0], B[4:0]}).   *
        *   -> Nhiệm vụ: Ghép `byte_high` và byte mới `d` vào `dout[15:0]`.           *
        *   -> Giương cờ: `we <= 1'b1` trong đúng 1 nhịp PCLK này để FIFO nuốt pixel! *
        *   -> Tăng địa chỉ: `addr <= addr + 1'b1` để chuẩn bị cho pixel kế tiếp.     *
        *   -> Đảo cờ: `byte_sel <= 1'b0` để quay về đón pixel mới.                   *
        *******************************************************************************
        */
        else if (href == 1'b1) begin
            if (byte_sel == 1'b0) begin
                byte_high <= d;
                byte_sel  <= 1'b1;
                we        <= 1'b0;
            end else begin
                dout <= {byte_high, d};
                byte_sel <= 1'b0;
                // [GIA CỐ CHỐNG SỌC DỌC / TRÀN RÁC KHUNG HÌNH 640x480]
                // Tuyệt đối chỉ giương we khi trong ngưỡng 307,200 pixel (640 * 480)
                if (addr < 19'd307200) begin
                    we   <= 1'b1;
                    addr <= addr + 19'd1;
                end else begin
                    we   <= 1'b0;
                end
            end
        end

        // --------------------------------------------------------------------
        // NHÁNH 3: KHOẢNG TRỐNG NGHỈ GIỮA HAI DÒNG QUÉT (HREF INACTIVE - BLANKING)
        // --------------------------------------------------------------------
        else begin
            // TODO: [DÀNH CHO SẾP] Đảm bảo hạ cờ `we <= 1'b0` để không ghi rác vào FIFO
            // Sếp có thể reset lại byte_sel <= 1'b0 tại đây để gia cố thêm tính an toàn!
            we <= 1'b0;
            byte_sel <= 1'b0;
        end 

    end

endmodule
