module sdram_arbiter #(
    parameter R_FIFO_DEPTH = 1024,
    parameter BURST_LENGTH = 256
)(
    input wire clk,
    input wire rst_n,
    
    // Đường bộ khung hình
    input wire vga_vsync,
// === [UPDATE PING-PONG] ===
    input wire camera_vsync,
// ==========================
    
    // Giao tiếp W-FIFO
    input wire w_fifo_empty,
    input wire [10:0] w_fifo_count, // Mực nước hiện tại trong W-FIFO
    input wire [15:0] w_fifo_data,
    output reg w_fifo_rd_en,
    
    // Giao tiếp R-FIFO
    input wire [10:0] r_fifo_count,
    output reg [15:0] r_fifo_data,
    output reg r_fifo_wr_en,
    output reg r_fifo_clear,
    
    // Giao tiếp SDRAM Controller
    input wire sys_ready,
    input wire sys_valid, // Cờ dữ liệu Burst Đọc trào ra
    input wire sys_wr_ack, // Cờ yêu cầu data Burst Ghi từ Controller
    output reg sys_write_req,
    output reg sys_read_req,
    output reg [21:0] sys_addr,
    output wire [15:0] sys_data_in,
    input wire [15:0] sys_data_out
);

    assign sys_data_in = w_fifo_data; // Nối thẳng luồng stream từ W-FIFO ra SDRAM Controller (Zero-latency)

    localparam IDLE           = 3'd0;
    localparam ASSERT_READ    = 3'd1;
    localparam WAIT_READ      = 3'd2;
    localparam FETCH_W_FIFO_1 = 3'd3;
    localparam FETCH_W_FIFO_2 = 3'd4;
    localparam ASSERT_WRITE   = 3'd5;
    localparam WAIT_WRITE     = 3'd6;

    reg [2:0] state;
    
// === [UPDATE PING-PONG] ===
    reg [18:0] write_addr;
    reg [18:0] read_addr;
    
    reg bank_write;
    reg bank_read;
    reg bank_completed;

    reg camera_vsync_d1, camera_vsync_d2;
    wire camera_vsync_falling = (camera_vsync_d2 && !camera_vsync_d1);
// ==========================

    reg vsync_d1, vsync_d2;
    wire vsync_falling = (vsync_d2 && !vsync_d1);
    reg vsync_req; // Cờ lưu trạng thái yêu cầu V-Sync
    
    reg [23:0] write_timeout_cnt; // Tự động reset write_addr nếu rảnh rỗi 100ms
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
// === [UPDATE PING-PONG] ===
            write_addr <= 19'd0;
            read_addr <= 19'd0;
            bank_write <= 1'b0;
            bank_read <= 1'b0;
            bank_completed <= 1'b0;
            camera_vsync_d1 <= 0;
            camera_vsync_d2 <= 0;
// ==========================
            w_fifo_rd_en <= 0;
            r_fifo_wr_en <= 0;
            r_fifo_clear <= 0;
            sys_write_req <= 0;
            sys_read_req <= 0;
            sys_addr <= 0;
            r_fifo_data <= 0;
            vsync_d1 <= 0;
            vsync_d2 <= 0;
            vsync_req <= 0;
            write_timeout_cnt <= 24'd0;
        end else begin
            vsync_d1 <= vga_vsync;
            vsync_d2 <= vsync_d1;
            
// === [UPDATE PING-PONG] ===
            camera_vsync_d1 <= camera_vsync;
            camera_vsync_d2 <= camera_vsync_d1;
            
            if (camera_vsync_falling) begin
                bank_completed <= bank_write;
                bank_write <= ~bank_write;
                write_addr <= 19'd0;
            end
// ==========================
            
            // Chờ bắt tín hiệu V-Sync và giương cờ
            if (vsync_falling) begin
                vsync_req <= 1'b1;
            end
            
            // Tự động đồng bộ write_addr nếu không có dữ liệu hơn 100ms
            if (w_fifo_empty) begin
                if (write_timeout_cnt < 24'd5_000_000) begin
                    write_timeout_cnt <= write_timeout_cnt + 1'b1;
                end else if (state == IDLE) begin
// === [UPDATE PING-PONG] ===
                    write_addr <= 19'd0;
// ==========================
                end
            end else begin
                write_timeout_cnt <= 24'd0;
            end
            
            w_fifo_rd_en <= 0;
            r_fifo_wr_en <= 0;
            r_fifo_clear <= 0;
            
            // Streaming trực tiếp từ SDRAM vào R-FIFO mỗi khi có data
            if (sys_valid) begin
                r_fifo_wr_en <= 1;
                r_fifo_data <= sys_data_out;
                read_addr <= read_addr + 1'b1;
            end
            
            case (state)
                IDLE: begin
                    sys_write_req <= 0;
                    sys_read_req <= 0;
                    
                    // Reset read_addr và XẢ SẠCH R-FIFO an toàn khi VSync tới
                    if (vsync_req) begin
// === [UPDATE PING-PONG] ===
                        bank_read <= bank_completed;
                        read_addr <= 19'd0;
// ==========================
                        r_fifo_clear <= 1'b1; // Xả sạch dữ liệu thừa ngoài lề khung hình
                        vsync_req <= 1'b0;
                    end
                    else if (sys_ready) begin
                        // Tính toán độ trống của R-FIFO (1024 - 256 = 768)
                        if (r_fifo_count <= (R_FIFO_DEPTH - BURST_LENGTH)) begin
// === [UPDATE PING-PONG] ===
                            sys_addr <= {2'b00, bank_read, read_addr[18:0]};
// ==========================
                            sys_read_req <= 1;
                            state <= ASSERT_READ;
                        end
                        else if (w_fifo_count >= BURST_LENGTH) begin
                            w_fifo_rd_en <= 1; // Rút trước Word 0
                            state <= FETCH_W_FIFO_1;
                        end
                    end
                end
                
                ASSERT_READ: begin
                    sys_read_req <= 1;
                    if (sys_ready == 1'b0) begin // Chờ SDRAM controller acknowledge
                        sys_read_req <= 0;
                        state <= WAIT_READ;
                    end
                end
                
                WAIT_READ: begin
                    sys_read_req <= 0;
                    if (sys_ready == 1'b1) begin // SDRAM controller tự ngắt sau khi Burst xong
                        state <= IDLE;
                    end
                end
                
                FETCH_W_FIFO_1: begin
                    state <= FETCH_W_FIFO_2; // Chờ latency 1 nhịp của Standard FIFO
                end
                
                FETCH_W_FIFO_2: begin
// === [UPDATE PING-PONG] ===
                    if (sys_ready == 1'b1) begin
                        sys_addr <= {2'b00, bank_write, write_addr[18:0]};
                        sys_write_req <= 1;
                        state <= ASSERT_WRITE;
                    end
// ==========================
                end
                
                ASSERT_WRITE: begin
                    sys_write_req <= 1;
                    if (sys_ready == 1'b0) begin
                        sys_write_req <= 0;
                        state <= WAIT_WRITE;
                    end
                end
                
                WAIT_WRITE: begin
                    w_fifo_rd_en <= sys_wr_ack; // Stream tiếp các words từ W-FIFO khi Controller yêu cầu
                    if (sys_ready == 1'b1) begin
// === [UPDATE PING-PONG BURST 256] ===
                        if (write_addr >= 19'd306944) begin
                            write_addr <= 19'd0;
                        end else begin
                            write_addr <= write_addr + BURST_LENGTH;
                        end
// ==========================
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule
