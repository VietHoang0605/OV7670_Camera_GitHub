module dual_port_ram #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    // --- Các cổng thuộc Miền Ghi (Bắt đầu bằng chữ 'w') ---
    input  wire wclk,                  // Xung nhịp Ghi (Write Clock)
    input  wire wclken,                // Tín hiệu cho phép Ghi (Write Clock Enable - tương đương với Write Enable)
    input  wire [ADDR_WIDTH-1:0] waddr,// Địa chỉ Ghi (Chỉ dùng ADDR_WIDTH bit, cắt bỏ bit MSB)
    input  wire [DATA_WIDTH-1:0] wdata,// Dữ liệu cần Ghi vào RAM
    
    // --- Các cổng thuộc Miền Đọc (Bắt đầu bằng chữ 'r') ---
    input  wire rclk,                  // Xung nhịp Đọc (Read Clock)
    input  wire rclken,                // Tín hiệu cho phép Đọc (Read Clock Enable)
    input  wire [ADDR_WIDTH-1:0] raddr,// Địa chỉ Đọc (Chỉ dùng ADDR_WIDTH bit, cắt bỏ bit MSB)
    output wire [DATA_WIDTH-1:0] rdata // Dữ liệu Đọc từ RAM xuất ra ngoài
);
    // Tính toán chiều sâu của bồn chứa dựa trên số bit địa chỉ
    localparam DEPTH = 1 << ADDR_WIDTH; 
    
    // TODO: 1. Khai báo mảng bộ nhớ (mem) với chiều rộng là DATA_WIDTH và chiều sâu là DEPTH.
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    // TODO: 2. Viết khối always @(posedge wclk) để xử lý việc GHI dữ liệu.
    // Nếu có wclken, ghi wdata vào mem tại vị trí waddr.
    always @(posedge wclk) begin
        if(wclken) begin
            mem[waddr] <= wdata;
        end
    end

    // TODO: 3. Viết khối always @(posedge rclk) để xử lý việc ĐỌC dữ liệu.
    // Khai báo 1 thanh ghi rdata_reg. Nếu có rclken, lấy dữ liệu từ mem tại vị trí raddr bỏ vào rdata_reg.
    // Cuối cùng gán ngõ ra rdata = rdata_reg.
    // (Đây là cơ chế Synchronous Read bắt buộc để Quartus hiểu và lôi M4K RAM ra dùng).
    reg [DATA_WIDTH-1:0] rdata_reg;
    always @(posedge rclk) begin
        if(rclken) begin
            rdata_reg <= mem[raddr];
        end
    end
    assign rdata = rdata_reg;
 

endmodule
