module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    // --- Miền Ghi (Write Domain) ---
    input  wire wclk,
    input  wire wrst_n,
    input  wire winc,
    input  wire [DATA_WIDTH-1:0] wdata,
    output wire wfull,

    // --- Miền Đọc (Read Domain) ---
    input  wire rclk,
    input  wire rrst_n,
    input  wire rinc,
    output wire [DATA_WIDTH-1:0] rdata,
    output wire rempty,
    output wire [ADDR_WIDTH:0] rcount
);

    // ==========================================
    // KHAI BÁO CÁC SỢI DÂY NỘI BỘ (INTERNAL WIRES)
    // ==========================================
    
    // 1. Dây nối Địa chỉ (Từ khối Quản đốc sang RAM)
    wire [ADDR_WIDTH-1:0] waddr;
    wire [ADDR_WIDTH-1:0] raddr;
    
    // 2. Dây nối Mã Gray (Đi ra từ khối Quản đốc)
    wire [ADDR_WIDTH:0] wptr_gray;
    wire [ADDR_WIDTH:0] rptr_gray;
    
    // 3. Dây nối tín hiệu Đã Đồng Bộ (Đi ra từ Trạm kiểm dịch)
    wire [ADDR_WIDTH:0] wq2_rptr;
    wire [ADDR_WIDTH:0] rq2_wptr;

    // 4. Mạch bảo vệ RAM (Chống ghi khi Đầy, chống đọc khi Rỗng)
    wire wclken = winc & ~wfull;
    wire rclken = rinc & ~rempty;

    // ==========================================
    // GỌI 5 MODULE VÀ HÀN DÂY (INSTANTIATION)
    // ==========================================

    // 1. Trái tim lưu trữ: Dual Port RAM
    dual_port_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_dual_port_ram (
        .wclk   (wclk),
        .wclken (wclken),
        .waddr  (waddr),
        .wdata  (wdata),
        
        .rclk   (rclk),
        .rclken (rclken),
        .raddr  (raddr),
        .rdata  (rdata)
    );

    // 2. Quản đốc Ghi: wptr_full
    wptr_full #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_wptr_full (
        .wclk      (wclk),
        .wrst_n    (wrst_n),
        .winc      (winc),
        .wq2_rptr  (wq2_rptr), // Nhận con trỏ đọc (đã đồng bộ)
        .wfull     (wfull),    // Báo cờ Đầy ra ngoài
        .waddr     (waddr),    // Gửi địa chỉ Ghi cho RAM
        .wptr_gray (wptr_gray) // Gửi mã Gray Ghi đi đồng bộ
    );

    // 3. Quản đốc Đọc: rptr_empty
    rptr_empty #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_rptr_empty (
        .rclk      (rclk),
        .rrst_n    (rrst_n),
        .rinc      (rinc),
        .rq2_wptr  (rq2_wptr), // Nhận con trỏ ghi (đã đồng bộ)
        .rempty    (rempty),   // Báo cờ Rỗng ra ngoài
        .raddr     (raddr),    // Gửi địa chỉ Đọc cho RAM
        .rptr_gray (rptr_gray), // Gửi mã Gray Đọc đi đồng bộ
        .rcount    (rcount)    // Xuất số lượng từ miền Đọc ra ngoài
    );

    // 4. Trạm kiểm dịch miền Ghi (Nhận rptr_gray, nhả ra wq2_rptr)
    sync_r2w #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_sync_r2w (
        .wclk      (wclk),
        .wrst_n    (wrst_n),
        .rptr_gray (rptr_gray),
        .wq2_rptr  (wq2_rptr)
    );

    // 5. Trạm kiểm dịch miền Đọc (Nhận wptr_gray, nhả ra rq2_wptr)
    sync_w2r #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_sync_w2r (
        .rclk      (rclk),
        .rrst_n    (rrst_n),
        .wptr_gray (wptr_gray),
        .rq2_wptr  (rq2_wptr)
    );

endmodule
