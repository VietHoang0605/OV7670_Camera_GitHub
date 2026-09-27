module sdram_controller (
    input wire clk,
    input wire rst_n,

    // Giao ti?p v?i m?ch ngo?i (Arbiter)
    input wire read_req,
    input wire write_req,
    input wire [21:0] sys_addr,
    input wire [15:0] sys_data_in,
    output reg [15:0] sys_data_out,
    output reg sys_ready,
    output reg sys_valid, // Báo hiệu dữ liệu đang Trào Ra (Streaming Read)
    output reg sys_wr_ack, // Báo hiệu yêu cầu nạp dữ liệu (Streaming Write)

    // Giao tiếp vật lý với chip SDRAM
    output reg [11:0] sdram_addr,
    output reg [1:0] sdram_ba,
    output reg sdram_cas_n,
    output reg sdram_cke,
    output wire sdram_clk,
    output reg sdram_cs_n,
    inout wire [15:0] sdram_dq,
    output reg sdram_ldqm,
    output reg sdram_udqm,
    output reg sdram_ras_n,
    output reg sdram_we_n
);

    assign sdram_clk = ~clk;

    localparam INIT_DELAY = 4'd0;
    localparam INIT_PRECHARGE = 4'd1;
    localparam INIT_REFRESH_1 = 4'd2;
    localparam INIT_REFRESH_2 = 4'd3;
    localparam INIT_LOAD_MODE_REG = 4'd4;
    localparam IDLE = 4'd5;
    localparam AUTO_REFRESH = 4'd6;
    localparam ACTIVE_ROW = 4'd7;
    localparam WRITE_DATA = 4'd8;
    localparam READ_CMD = 4'd9;
    localparam READ_STREAM = 4'd10;
    localparam BURST_TERM = 4'd11;
    localparam PRECHARGE_ROW = 4'd12;

    reg [3:0] current_state;
    reg [15:0] delay_timer;
    reg [8:0] burst_counter; // ??m t?i 256 pixel

    // B? ??m chu k? refresh (C?n refresh m?i 15.6us)
    reg [9:0] refresh_counter;
    wire refresh_req = (refresh_counter >= 10'd750); // 750 * 20ns = 15us

    reg is_write;
    reg [21:0] latched_addr;
    reg [15:0] latched_data;
    reg out_en;
    assign sdram_dq = out_en ? sys_data_in : 16'bz;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            refresh_counter <= 10'd0;
        end else begin
            if (current_state == AUTO_REFRESH && delay_timer == 16'd0) begin
                refresh_counter <= 10'd0;
            end else begin
                refresh_counter <= refresh_counter + 10'd1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= INIT_DELAY;
            delay_timer <= 16'd0;
            sys_ready <= 1'b0;
            sys_valid <= 1'b0;
            sys_wr_ack <= 1'b0;
            out_en <= 1'b0;
            sdram_cke <= 1'b1;
            sdram_cs_n <= 1'b0;
            sdram_ras_n <= 1'b1;
            sdram_cas_n <= 1'b1;
            sdram_we_n <= 1'b1;
            sdram_ldqm <= 1'b0;
            sdram_udqm <= 1'b0;
            burst_counter <= 0;
            is_write <= 1'b0;
            latched_addr <= 22'd0;
            latched_data <= 16'd0;
        end else begin
            sys_valid <= 1'b0; // M?c ??nh t?t
            
            case (current_state)
                INIT_DELAY: begin
                    if (delay_timer == 16'd5000) begin // 100us
                        current_state <= INIT_PRECHARGE;
                        delay_timer <= 16'd0;
                    end else begin
                        delay_timer <= delay_timer + 16'd1;
                    end
                end
                INIT_PRECHARGE: begin
                    if(delay_timer == 16'd0) begin
                        sdram_ras_n <= 1'b0;
                        sdram_cas_n <= 1'b1;
                        sdram_we_n <= 1'b0;
                        sdram_addr[10] <= 1'b1; // Precharge ALL
                    end else begin
                        sdram_ras_n <= 1'b1;
                        sdram_we_n <= 1'b1;
                    end
                    if(delay_timer == 16'd1) begin
                        current_state <= INIT_REFRESH_1;
                        delay_timer <= 0;
                    end else delay_timer <= delay_timer + 1;
                end
                INIT_REFRESH_1, INIT_REFRESH_2: begin
                    if(delay_timer == 16'd0) begin
                        sdram_ras_n <= 1'b0;
                        sdram_cas_n <= 1'b0;
                        sdram_we_n <= 1'b1;
                    end else begin
                        sdram_ras_n <= 1'b1;
                        sdram_cas_n <= 1'b1;
                    end
                    if(delay_timer == 16'd4) begin
                        current_state <= (current_state == INIT_REFRESH_1) ? INIT_REFRESH_2 : INIT_LOAD_MODE_REG;
                        delay_timer <= 0;
                    end else delay_timer <= delay_timer + 1;
                end
                INIT_LOAD_MODE_REG: begin
                    if(delay_timer == 16'd0) begin
                        sdram_ras_n <= 1'b0;
                        sdram_cas_n <= 1'b0;
                        sdram_we_n <= 1'b0;
                        // Mode: CAS=3, Read=Full Page, Write=Full Page (Bit 9 = 0: Burst Write)
                        sdram_addr <= 12'h037; 
                    end else begin
                        sdram_ras_n <= 1'b1;
                        sdram_cas_n <= 1'b1;
                        sdram_we_n <= 1'b1;
                    end
                    if(delay_timer == 16'd2) begin
                        current_state <= IDLE;
                        delay_timer <= 0;
                    end else delay_timer <= delay_timer + 1;
                end
                
                IDLE: begin
                    sys_ready <= 1'b1; 
                    sdram_ras_n <= 1'b1;
                    sdram_cas_n <= 1'b1;
                    sdram_we_n <= 1'b1;
                    if (refresh_req && !write_req && !read_req) begin
                        sys_ready <= 1'b0;
                        current_state <= AUTO_REFRESH;
                        delay_timer <= 16'd0;
                    end else if (write_req) begin
                        sys_ready <= 1'b0;
                        is_write <= 1'b1;
                        latched_addr <= sys_addr;
                        latched_data <= sys_data_in;
                        current_state <= ACTIVE_ROW;
                        delay_timer <= 16'd0;
                    end else if (read_req) begin
                        sys_ready <= 1'b0;
                        is_write <= 1'b0;
                        latched_addr <= sys_addr;
                        current_state <= ACTIVE_ROW;
                        delay_timer <= 16'd0;
                    end
                end
                
                AUTO_REFRESH: begin
                    if(delay_timer == 16'd0) begin
                        sdram_ras_n <= 1'b0;
                        sdram_cas_n <= 1'b0;
                    end else begin
                        sdram_ras_n <= 1'b1;
                        sdram_cas_n <= 1'b1;
                    end
                    if(delay_timer == 16'd4) begin
                        current_state <= IDLE;
                        delay_timer <= 0;
                    end else delay_timer <= delay_timer + 1;
                end
                
                ACTIVE_ROW: begin
                   if(delay_timer == 16'd0) begin
                        sdram_ras_n <= 1'b0;
                        sdram_cas_n <= 1'b1;
                        sdram_we_n <= 1'b1;
                        sdram_addr <= latched_addr[19:8];
                        sdram_ba <= latched_addr[21:20];
                   end else begin
                        sdram_ras_n <= 1'b1;
                   end
                   if(delay_timer == 16'd1) begin
                        if(is_write) begin
                            current_state <= WRITE_DATA;
                            delay_timer <= 0;
                            burst_counter <= 0;
                            sys_wr_ack <= 1'b1; // Bật sớm để W-FIFO kịp pop Word 1 cho chu kỳ tiếp theo
                        end else begin
                            current_state <= READ_CMD;
                            delay_timer <= 0;
                        end
                   end else delay_timer <= delay_timer + 1;
                end
                
                WRITE_DATA: begin
                    if(burst_counter == 9'd0) begin
                        // Chu kỳ 0: Lệnh WRITE (RAS_N=1, CAS_N=0, WE_N=0) và nạp địa chỉ Column
                        sdram_ras_n <= 1'b1;
                        sdram_cas_n <= 1'b0;
                        sdram_we_n <= 1'b0;
                        sdram_addr <= {4'b0000, latched_addr[7:0]};
                        sdram_ba <= latched_addr[21:20];
                        out_en <= 1'b1;
                    end else begin
                        // Chu kỳ 1 -> 255: NOP (Dữ liệu tiếp tục stream vào SDRAM)
                        sdram_ras_n <= 1'b1;
                        sdram_cas_n <= 1'b1;
                        sdram_we_n <= 1'b1;
                        if(burst_counter == 9'd254) begin
                            sys_wr_ack <= 1'b0; // Đã pop đủ 256 words (1 prefetch + 255 stream)
                        end
                    end
                    if(burst_counter == 9'd255) begin
                        current_state <= BURST_TERM;
                        delay_timer <= 0;
                        burst_counter <= 0;
                    end else begin
                        burst_counter <= burst_counter + 1'b1;
                    end
                end
                
                READ_CMD: begin
                    if(delay_timer == 16'd0) begin
                        sdram_ras_n <= 1'b1;
                        sdram_cas_n <= 1'b0;
                        sdram_we_n <= 1'b1;
                        sdram_addr <= {4'b0000, latched_addr[7:0]};
                        sdram_ba <= latched_addr[21:20];
                    end else begin
                        sdram_cas_n <= 1'b1;
                    end
                    // Chờ CAS=3 (T3 data mới tới)
                    if(delay_timer == 16'd3) begin
                        current_state <= READ_STREAM;
                        delay_timer <= 0;
                        burst_counter <= 0;
                    end else delay_timer <= delay_timer + 1;
                end
                
                READ_STREAM: begin
                    // Data luôn valid mỗi nhịp clock
                    sys_data_out <= sdram_dq;
                    sys_valid <= 1'b1; // Báo hiệu ra Arbiter
                    
                    if (burst_counter == 9'd255) begin
                        current_state <= BURST_TERM;
                        delay_timer <= 0;
                    end else begin
                        burst_counter <= burst_counter + 1'b1;
                    end
                end
                
                BURST_TERM: begin
                    out_en <= 1'b0;
                    sys_wr_ack <= 1'b0;
                    if(delay_timer == 16'd0) begin
                        sdram_ras_n <= 1'b1;
                        sdram_cas_n <= 1'b1;
                        sdram_we_n <= 1'b0; 
                    end else begin
                        sdram_we_n <= 1'b1;
                    end
                    if(delay_timer == 16'd1) begin
                        current_state <= PRECHARGE_ROW;
                        delay_timer <= 0;
                    end else delay_timer <= delay_timer + 1;
                end
                
                PRECHARGE_ROW: begin
                    if(delay_timer == 16'd0) begin
                        sdram_ras_n <= 1'b0;
                        sdram_cas_n <= 1'b1;
                        sdram_we_n <= 1'b0;
                        sdram_addr[10] <= 1'b1; // Precharge ALL
                    end else begin
                        sdram_ras_n <= 1'b1;
                        sdram_we_n <= 1'b1;
                    end
                    if(delay_timer == 16'd1) begin
                        current_state <= IDLE;
                        delay_timer <= 0;
                    end else delay_timer <= delay_timer + 1;
                end
                
            endcase
        end
    end
endmodule
