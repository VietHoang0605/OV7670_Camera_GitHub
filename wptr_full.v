module wptr_full #(
    parameter ADDR_WIDTH = 4
)(
    // --- Tín hiệu nội bộ Miền Ghi ---
    input  wire wclk,                  // Xung nhịp Ghi
    input  wire wrst_n,                // Reset miền Ghi
    input  wire winc,                  // Tín hiệu yêu cầu tăng con trỏ Ghi (Write Increment - tương đương với write enable hợp lệ)
    
    // --- Tín hiệu lấy từ Trạm Đồng Bộ ---
    input  wire [ADDR_WIDTH:0] wq2_rptr, // Con trỏ Đọc an toàn (đã đi qua 2-Stage Sync vào miền Ghi)

    // --- Tín hiệu xuất ra Hệ Thống ---
    output wire wfull,                 // Cờ báo Đầy (Xuất ra ngoài cho User biết bồn đã đầy)
    output wire [ADDR_WIDTH-1:0] waddr,// Địa chỉ Ghi xuất ra cho bồn RAM (Bị bỏ đi bit MSB)
    output wire [ADDR_WIDTH:0] wptr_gray // Con trỏ Ghi hệ Gray xuất ra cho trạm đồng bộ gửi sang miền Đọc
);
    // TODO: 1. Khai báo các thanh ghi nội bộ:
    // - wbin_reg: (N+1 bit) Lưu con trỏ Ghi hiện tại theo hệ Nhị phân (Binary) để tính toán địa chỉ RAM.
    // - wgray_reg: (N+1 bit) Lưu con trỏ Ghi hiện tại theo hệ Gray để chuẩn bị gửi sang miền Đọc.
    // - wfull_reg: (1 bit) Lưu trạng thái cờ báo đầy (Sử dụng thanh ghi để tránh lỗi Combinational Loop).
    reg [ADDR_WIDTH:0] wbin_reg;
    reg [ADDR_WIDTH:0] wgray_reg;
    reg wfull_reg;

    // TODO: 2. Tính toán trạng thái CỦA CHU KỲ TIẾP THEO (Next State):
    // Các biến này không cần lưu, chỉ dùng logic tổ hợp (wire/assign):
    // - wbin_next: Bằng wbin_reg hiện tại cộng thêm (winc & ~wfull_reg). Nghĩa là chỉ đếm lên nếu có lệnh ghi và chưa đầy.
    // - wgray_next: Chuyển wbin_next vừa tính được sang mã Gray bằng công thức XOR: (wbin_next >> 1) ^ wbin_next.
    reg [ADDR_WIDTH:0] wbin_next;
    reg [ADDR_WIDTH:0] wgray_next;
     always @(*) begin
        // Nếu (winc & ~wfull_reg) đúng  -> Nó bằng 1 -> Cộng thêm 1
        // Nếu (winc & ~wfull_reg) sai -> Nó bằng 0 -> Cộng thêm 0 (Giữ nguyên wbin_reg)
        wbin_next = wbin_reg + (winc & ~wfull_reg);
        
        // Luôn luôn tính mã Gray mới dựa trên kết quả wbin_next vừa có
        wgray_next = (wbin_next >> 1) ^ wbin_next;
    end
    // TODO: 3. Viết khối always @(posedge wclk or negedge wrst_n):
    // - Khi wrst_n = 0: Xóa tất cả wbin_reg, wgray_reg và wfull_reg về 0.
    // - Khi bình thường: 
    //     Cập nhật wbin_reg = wbin_next; 
    //     Cập nhật wgray_reg = wgray_next; 
    //     Quyết định cờ Full mới: wfull_reg sẽ bật lên NẾU wgray_next có 2 bit cao nhất đảo ngược so với wq2_rptr, các bit còn lại y hệt nhau.
    //     (Gợi ý phép toán so sánh Full: wfull_val = (wgray_next == {~wq2_rptr[ADDR_WIDTH:ADDR_WIDTH-1], wq2_rptr[ADDR_WIDTH-2:0]}); )
    always @(posedge wclk or negedge wrst_n) begin
        if(!wrst_n) begin
            wbin_reg <= 0;
            wfull_reg <= 0;
            wgray_reg <= 0;
        end
        else begin
            wbin_reg <= wbin_next;
            wgray_reg <= wgray_next;
            wfull_reg <= (wgray_next == {~wq2_rptr[ADDR_WIDTH:ADDR_WIDTH-1], wq2_rptr[ADDR_WIDTH-2:0]});
        end
    end
    // TODO: 4. Gán các thanh ghi ra chân nối dây:
    // - waddr lấy từ bit 0 đến ADDR_WIDTH-1 của wbin_reg.
    // - wptr_gray = wgray_reg;
    // - wfull = wfull_reg;
    assign waddr = wbin_reg[ADDR_WIDTH-1:0];
    assign wptr_gray = wgray_reg;
    assign wfull = wfull_reg;

endmodule
