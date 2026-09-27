module sync_w2r #(
    parameter ADDR_WIDTH = 4
)(
    // --- Các cổng nội bộ của Miền Đọc (Bắt đầu bằng 'r') ---
    input  wire rclk,                  // Xung nhịp Đọc (Nơi tín hiệu đi tới)
    input  wire rrst_n,                // Reset của miền Đọc (Tích cực mức thấp)
    
    // --- Tín hiệu từ Miền Ghi gửi sang ---
    input  wire [ADDR_WIDTH:0] wptr_gray, // Con trỏ Ghi mã Gray (Chạy theo wclk, gửi sang rclk)
    
    // --- Tín hiệu xuất ra cho Miền Đọc ---
    output wire [ADDR_WIDTH:0] rq2_wptr   // Con trỏ Ghi ĐÃ ĐƯỢC ĐỒNG BỘ qua 2 tầng FF cho miền Đọc.
                                          // Quy ước đặt tên: 
                                          // r = chạy ở miền Đọc
                                          // q2 = ngõ ra của FF tầng 2
                                          // wptr = dữ liệu bản chất là của con trỏ Ghi
);
    reg [ADDR_WIDTH:0] rq1_wptr, rq2_wptr_reg;

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rq1_wptr <= 0;
            rq2_wptr_reg <= 0;
        end else begin
            rq1_wptr <= wptr_gray;
            rq2_wptr_reg <= rq1_wptr;
        end
    end

    assign rq2_wptr = rq2_wptr_reg;

endmodule
