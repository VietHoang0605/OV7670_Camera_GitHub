module sync_r2w #(
    parameter ADDR_WIDTH = 4
)(
    // --- Các cổng nội bộ của Miền Ghi (Bắt đầu bằng 'w') ---
    input  wire wclk,                  // Xung nhịp Ghi (Nơi tín hiệu đi tới)
    input  wire wrst_n,                // Reset của miền Ghi (Tích cực mức thấp: _n = active low)
    
    // --- Tín hiệu từ Miền Đọc gửi sang ---
    input  wire [ADDR_WIDTH:0] rptr_gray, // Con trỏ Đọc mã Gray (Chạy theo rclk, gửi sang wclk)
    
    // --- Tín hiệu xuất ra cho Miền Ghi ---
    output wire [ADDR_WIDTH:0] wq2_rptr   // Con trỏ Đọc ĐÃ ĐƯỢC ĐỒNG BỘ qua 2 tầng FF cho miền Ghi.
                                          // Quy ước đặt tên: 
                                          // w = chạy ở miền Ghi
                                          // q2 = ngõ ra của FF tầng 2
                                          // rptr = dữ liệu bản chất là của con trỏ Đọc
);
    // TODO: 1. Khai báo 2 thanh ghi (registers) trung gian: 
    // - wq1_rptr: Thanh ghi tầng 1 (Nhận tín hiệu trực tiếp, dễ dính Metastability)
    // - wq2_rptr_reg: Thanh ghi tầng 2 (Lọc sạch tín hiệu để xuất ra)
    // Lưu ý: Độ rộng là ADDR_WIDTH + 1 bit (Gồm n bit địa chỉ + 1 bit trạng thái vòng lặp).
    reg [ADDR_WIDTH:0] wq1_rptr, wq2_rptr_reg ;
    
        

    // TODO: 2. Viết khối always @(posedge wclk or negedge wrst_n)
    // Nếu wrst_n = 0: Reset cả 2 thanh ghi về 0.
    // Nếu wrst_n = 1: 
    //   - Gán giá trị của rptr_gray vào thanh ghi tầng 1 (wq1_rptr).
    //   - Gán giá trị của thanh ghi tầng 1 vào thanh ghi tầng 2 (wq2_rptr_reg).
    always @(posedge wclk or negedge wrst_n) begin
        if(!wrst_n) begin
            wq1_rptr <= 0;
            wq2_rptr_reg <= 0;
        end
        else begin
        wq1_rptr <= rptr_gray ;
        wq2_rptr_reg <= wq1_rptr ;
        end
    end
    // TODO: 3. Gán ngõ ra wq2_rptr = wq2_rptr_reg;
    assign wq2_rptr = wq2_rptr_reg ;
endmodule
