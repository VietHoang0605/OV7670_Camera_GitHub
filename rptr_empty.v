module rptr_empty #(
    parameter ADDR_WIDTH = 4
)(
    // --- Tín hiệu nội bộ Miền Đọc ---
    input  wire rclk,                  // Xung nhịp Đọc
    input  wire rrst_n,                // Reset miền Đọc
    input  wire rinc,                  // Tín hiệu yêu cầu tăng con trỏ Đọc (Read Increment - tương đương với read enable hợp lệ)
    
    // --- Tín hiệu lấy từ Trạm Đồng Bộ ---
    input  wire [ADDR_WIDTH:0] rq2_wptr, // Con trỏ Ghi an toàn (đã đi qua 2-Stage Sync vào miền Đọc)

    // --- Tín hiệu xuất ra Hệ Thống ---
    output wire rempty,                // Cờ báo Rỗng (Xuất ra ngoài cho User biết bồn đã hết nước)
    output wire [ADDR_WIDTH-1:0] raddr,// Địa chỉ Đọc xuất ra cho bồn RAM (Bị bỏ đi bit MSB)
    output wire [ADDR_WIDTH:0] rptr_gray, // Con trỏ Đọc hệ Gray xuất ra cho trạm đồng bộ gửi sang miền Ghi
    output wire [ADDR_WIDTH:0] rcount  // Số lượng từ hiện có trong FIFO ở miền Đọc (Read Count)
);
    reg [ADDR_WIDTH:0] rbin_reg;
    reg [ADDR_WIDTH:0] rgray_reg;
    reg rempty_reg;

    wire [ADDR_WIDTH:0] rbin_next;
    wire [ADDR_WIDTH:0] rgray_next;

    assign rbin_next = rbin_reg + (rinc & ~rempty_reg);
    assign rgray_next = (rbin_next >> 1) ^ rbin_next;

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin_reg <= 0;
            rgray_reg <= 0;
            rempty_reg <= 1'b1; // Mặc định khi reset thì bồn rỗng
        end else begin
            rbin_reg <= rbin_next;
            rgray_reg <= rgray_next;
            rempty_reg <= (rgray_next == rq2_wptr);
        end
    end

    // Giải mã rq2_wptr từ mã Gray sang nhị phân
    integer i;
    reg [ADDR_WIDTH:0] wptr_bin;
    always @(*) begin
        wptr_bin[ADDR_WIDTH] = rq2_wptr[ADDR_WIDTH];
        for (i = ADDR_WIDTH - 1; i >= 0; i = i - 1) begin
            wptr_bin[i] = wptr_bin[i+1] ^ rq2_wptr[i];
        end
    end

    assign rcount = wptr_bin - rbin_reg;
    assign raddr = rbin_reg[ADDR_WIDTH-1:0];
    assign rptr_gray = rgray_reg;
    assign rempty = rempty_reg;

endmodule
