module sdram_arbiter_practice (
    // =========================================================================
    // I/O PORTS: CÁC CỔNG GIAO TIẾP VÀO/RA
    // =========================================================================
    // Xung nhịp và Reset
    input  wire        clk,            // Xung nhịp hệ thống (Ví dụ: 50MHz). Mọi hoạt động của FSM đồng bộ theo xung này.
    input  wire        rst_n,          // Tín hiệu Reset toàn mạch, tích cực mức thấp (Active-Low).

    // Tín hiệu đồng bộ khung hình từ các khối ngoại vi
    input  wire        vga_vsync,      // Xung đồng bộ màn hình từ khối VGA. Báo hiệu màn hình đã quét xong 1 khung.
    input  wire        camera_vsync,   // Xung đồng bộ màn hình từ Camera. Báo hiệu Camera đã chụp xong 1 khung.

    // Giao tiếp W-FIFO (Bơm dữ liệu từ Camera vào)
    input  wire        w_fifo_empty,   // Cờ báo W-FIFO cạn dữ liệu.
    input  wire [10:0] w_fifo_count,   // Số lượng phần tử hiện đang có trong W-FIFO. Dùng để kiểm tra xem đã đủ 1 Burst (256 pixel) chưa.
    output reg         w_fifo_rd_en,   // Tín hiệu yêu cầu đọc dữ liệu từ W-FIFO.
    input  wire [15:0] w_fifo_data,    // Dữ liệu 16-bit lấy ra từ W-FIFO.

    // Giao tiếp R-FIFO (Rút dữ liệu xuất ra VGA)
    input  wire [10:0] r_fifo_count,   // Số lượng phần tử hiện đang có trong R-FIFO. Dùng để kiểm tra ngưỡng.
    output reg         r_fifo_wr_en,   // Tín hiệu cho phép ghi dữ liệu mới vào R-FIFO.
    output reg         r_fifo_clear,   // Tín hiệu xóa toàn bộ dữ liệu trong R-FIFO (dùng khi chuyển khung hình).
    output reg  [15:0] r_fifo_data,    // Dữ liệu 16-bit đi thẳng vào R-FIFO.

    // Giao tiếp SDRAM Controller (Điều khiển chip nhớ vật lý)
    input  wire        sys_ready,      // SDRAM Controller báo sẵn sàng nhận lệnh mới.
    input  wire        sys_valid,      // Dữ liệu từ SDRAM đang hợp lệ trên bus (phục vụ quá trình Đọc).
    input  wire        sys_wr_ack,     // SDRAM Controller xác nhận và yêu cầu từ tiếp theo (phục vụ quá trình Ghi Burst).
    output reg         sys_write_req,  // Yêu cầu SDRAM Controller thực hiện quá trình Ghi (Write).
    output reg         sys_read_req,   // Yêu cầu SDRAM Controller thực hiện quá trình Đọc (Read).
    output reg  [21:0] sys_addr,       // Địa chỉ bộ nhớ 22-bit (Gồm Bank Select + Tọa độ bộ nhớ).
    output wire [15:0] sys_data_in,    // Dữ liệu 16-bit cần ghi vào SDRAM.
    input  wire [15:0] sys_data_out    // Dữ liệu 16-bit đọc ra từ SDRAM.
);

    // =========================================================================
    // 1. ĐỊNH NGHĨA TRẠNG THÁI FSM (LOCALPARAM)
    // =========================================================================
    // Ý nghĩa các trạng thái:
    // - IDLE           : Trạng thái nghỉ, chờ các điều kiện kích hoạt (VGA cần khung hình, W-FIFO đầy, hoặc R-FIFO cạn).
    // - ASSERT_READ    : Kích hoạt tín hiệu Đọc tới SDRAM Controller.
    // - WAIT_READ      : Chờ SDRAM Controller thực hiện xong tác vụ Đọc (Burst Read) và trả dữ liệu về.
    // - FETCH_W_FIFO_1 : Trạng thái đệm (Latency) để rút phần tử đầu tiên ra khỏi W-FIFO trước khi Ghi.
    // - FETCH_W_FIFO_2 : Trạng thái đệm thứ hai đảm bảo dữ liệu W-FIFO đã sẵn sàng trên bus.
    // - ASSERT_WRITE   : Kích hoạt tín hiệu Ghi tới SDRAM Controller.
    // - WAIT_WRITE     : Chờ SDRAM Controller thực hiện xong tác vụ Ghi (Burst Write) toàn bộ block dữ liệu.
    localparam IDLE           = 3'd0;
    localparam ASSERT_READ    = 3'd1;
    localparam WAIT_READ      = 3'd2;
    localparam FETCH_W_FIFO_1 = 3'd3;
    localparam FETCH_W_FIFO_2 = 3'd4;
    localparam ASSERT_WRITE   = 3'd5;
    localparam WAIT_WRITE     = 3'd6;

    reg [2:0] state;

    // =========================================================================
    // 2. KHAI BÁO CÁC THANH GHI LƯU TRỮ VÀ CON TRỎ
    // =========================================================================
    reg bank_write;       // Bank SDRAM mục tiêu cho quá trình Ghi.
    reg bank_read;        // Bank SDRAM mục tiêu cho quá trình Đọc.
    reg bank_completed;   // Bank SDRAM lưu trữ khung hình hoàn chỉnh gần nhất.
    
    reg [18:0] write_addr;       // Con trỏ tọa độ bộ nhớ cho quá trình Ghi.
    reg [18:0] read_addr;        // Con trỏ tọa độ bộ nhớ cho quá trình Đọc.

    reg [23:0] write_timeout_cnt;

    // =========================================================================
    // [TODO 1]: MẠCH DOUBLE-FLOP SYNCHRONIZER VÀ EDGE DETECTOR
    // =========================================================================
    // Vấn đề: Tín hiệu `camera_vsync` và `vga_vsync` đến từ các miền xung nhịp khác nhau.
    // Nếu đưa trực tiếp vào FSM (chạy bằng `clk`) sẽ gây ra hiện tượng Metastability.
    // Ngoài ra, hệ thống cần phát hiện chính xác thời điểm các tín hiệu VSYNC kết thúc
    // (chuyển từ 1 xuống 0) để xác định ranh giới giữa các khung hình.
    //
    // Yêu cầu: Xây dựng mạch đồng bộ (Synchronizer) và phát hiện sườn xuống (Falling Edge)
    // cho cả 2 tín hiệu VSYNC.

    // --> Khởi tạo các thanh ghi và viết logic xử lý tại đây.
    reg camera_vsync_FF1;
    reg camera_vsync_FF2;
    wire camera_vsync_falling;
    reg camera_vsync_falling_past;
    
    reg vsync_d1;
    reg vsync_d2;
    wire vsync_falling;
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            camera_vsync_FF1 <= 1'b0;
            camera_vsync_FF2 <= 1'b0;
            camera_vsync_falling_past <= 1'b0;
            
            vsync_d1 <= 1'b0;
            vsync_d2 <= 1'b0;
        end
        else begin
            camera_vsync_FF1 <= camera_vsync ;
            camera_vsync_FF2 <= camera_vsync_FF1;
            camera_vsync_falling_past <= camera_vsync_FF2;
            
            vsync_d1 <= vga_vsync;
            vsync_d2 <= vsync_d1;
        end
    end
    
    assign camera_vsync_falling = (~camera_vsync_FF2 && camera_vsync_falling_past);
    assign vsync_falling = (vsync_d2 && !vsync_d1);

    // =========================================================================
    // [TODO 2]: LOGIC ĐIỀU KHIỂN CƠ CHẾ PING-PONG (GHI)
    // =========================================================================
    // Vấn đề: Để tránh hiện tượng xé hình, luồng dữ liệu Ghi không được phép ghi đè lên 
    // Bank mà luồng Đọc đang sử dụng. Khi một khung hình kết thúc, hệ thống cần đánh dấu 
    // Bank hiện tại là "Thành phẩm" và lập tức chuyển con trỏ Ghi sang Bank đối diện.
    //
    // Yêu cầu: Viết khối `always` phản hồi với sự kiện kết thúc khung hình Ghi,
    // thực hiện cập nhật các thanh ghi quản lý Bank Ghi và reset con trỏ tọa độ Ghi.

    // --> Viết logic điều khiển Ping-Pong (Ghi) tại đây.
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            bank_write <= 1'b0;
            bank_completed <= 1'b0;
            write_addr <= 19'd0;
            write_timeout_cnt <= 24'd0;
        end
        else begin
            if(camera_vsync_falling == 1'b1) begin
                bank_completed <= bank_write;
                bank_write <= ~bank_write;
                write_addr <= 19'd0;
                write_timeout_cnt <= 24'd0;
            end
            else begin
                if (w_fifo_empty) begin
                    if (write_timeout_cnt < 24'd5_000_000) begin
                        write_timeout_cnt <= write_timeout_cnt + 1'b1;
                    end else if (state == IDLE) begin
                        write_addr <= 19'd0;
                    end
                end else begin
                    write_timeout_cnt <= 24'd0;
                end
                
                if (state == WAIT_WRITE && sys_ready == 1'b1) begin
                    if (write_addr >= 19'd306944) begin
                        write_addr <= 19'd0;
                    end else begin
                        write_addr <= write_addr + 19'd256;
                    end
                end
            end
        end
    end

    // =========================================================================
    // [TODO 3]: LOGIC ĐIỀU KHIỂN CƠ CHẾ PING-PONG (ĐỌC)
    // =========================================================================
    // Vấn đề: Khối hiển thị cần một bức ảnh nguyên vẹn. Khi bắt đầu quét một khung 
    // hình mới, hệ thống cần chuyển hướng đọc sang Bank chứa "Thành phẩm" mới nhất.
    //
    // Yêu cầu: Viết khối `always` phản hồi với sự kiện kết thúc khung hình Đọc,
    // thực hiện cập nhật thanh ghi quản lý Bank Đọc.

    // --> Viết logic điều khiển Ping-Pong (Đọc) tại đây.
    reg vsync_req;
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            bank_read <= 1'b0;
            read_addr <= 19'd0;
        end
        else begin
            if (state == IDLE && vsync_req == 1'b1 && !vsync_falling) begin
                bank_read <= bank_completed;
                read_addr <= 19'd0;
            end
            else if (sys_valid) begin
                read_addr <= read_addr + 19'd1;
            end
        end
    end

    // =========================================================================
    // [TODO 4]: ĐỊNH TUYẾN DỮ LIỆU (DATA ROUTING)
    // =========================================================================
    // Vấn đề: Dữ liệu pixel đi từ W-FIFO vào SDRAM và từ SDRAM ra R-FIFO cần
    // được định tuyến liên tục không qua trung gian.
    //
    // Yêu cầu: Sử dụng các lệnh gán liên tục để nối thông các bus dữ liệu
    // tương ứng giữa FIFO và SDRAM Controller.

    // --> Viết các lệnh gán dữ liệu tại đây.
    assign sys_data_in = w_fifo_data;

    // =========================================================================
    // [TODO 5]: MÁY TRẠNG THÁI (FSM) ĐIỀU PHỐI GIAO THÔNG
    // =========================================================================
    // Vấn đề: SDRAM chỉ có 1 bus dữ liệu, không thể Đọc và Ghi cùng lúc. Trọng tài 
    // cần quan sát trạng thái của W-FIFO, R-FIFO và các yêu cầu đồng bộ khung hình 
    // để cấp quyền truy cập SDRAM theo mức độ ưu tiên hợp lý.
    //
    // Yêu cầu: Xây dựng khối `always` tuần tự quản lý chuyển đổi giữa 7 trạng thái.
    // Cần giải quyết các bài toán:
    // - Xử lý sự kiện chuyển khung hình (Reset địa chỉ, xóa FIFO rác).
    // - Ưu tiên cấp quyền Đọc nếu R-FIFO cạn đến mức ngưỡng.
    // - Ưu tiên cấp quyền Ghi nếu W-FIFO đã tích đủ 1 Burst.
    // - Điều khiển các cờ giao tiếp với SDRAM Controller theo đúng trình tự State Machine.

    // --> Viết logic Máy trạng thái (FSM) tại đây.
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= IDLE ;
            w_fifo_rd_en  <= 1'b0;
            r_fifo_wr_en  <= 1'b0;
            r_fifo_clear  <= 1'b0;
            r_fifo_data   <= 16'd0;
            sys_write_req <= 1'b0;
            sys_read_req  <= 1'b0;
            sys_addr      <= 22'd0;
            vsync_req     <= 1'b0;
        end
        else begin
            w_fifo_rd_en <= 1'b0;
            r_fifo_wr_en <= 1'b0;
            r_fifo_clear <= 1'b0;
            
            if (sys_valid) begin
                r_fifo_wr_en <= 1'b1;
                r_fifo_data <= sys_data_out;
            end
            
            if (vsync_falling) begin
                vsync_req <= 1'b1;
            end

            case (state)
                IDLE: begin
                    if (vsync_req) begin
                        r_fifo_clear <= 1'b1;
                        vsync_req <= 1'b0;
                    end
                    else if (sys_ready) begin
                        if (r_fifo_count <= 768) begin
                            sys_addr <= {2'b00, bank_read, read_addr[18:0]};
                            sys_read_req <= 1'b1;
                            state <= ASSERT_READ;
                        end
                        else if (w_fifo_count >= 256) begin
                            w_fifo_rd_en <= 1'b1;
                            state <= FETCH_W_FIFO_1;
                        end
                    end
                end

                ASSERT_READ: begin
                    sys_read_req <= 1'b1;
                    if (sys_ready == 1'b0) begin
                        sys_read_req <= 1'b0;
                        state <= WAIT_READ;
                    end
                end

                WAIT_READ: begin
                    if (sys_ready == 1'b1) begin
                        state <= IDLE;
                    end
                end

                FETCH_W_FIFO_1: begin
                    state <= FETCH_W_FIFO_2;
                end

                FETCH_W_FIFO_2: begin
                    if (sys_ready == 1'b1) begin
                        sys_addr <= {2'b00, bank_write, write_addr[18:0]};
                        sys_write_req <= 1'b1;
                        state <= ASSERT_WRITE;
                    end
                end

                ASSERT_WRITE: begin
                    sys_write_req <= 1'b1;
                    if (sys_ready == 1'b0) begin
                        sys_write_req <= 1'b0;
                        state <= WAIT_WRITE;
                    end
                end

                WAIT_WRITE: begin
                    w_fifo_rd_en <= sys_wr_ack;
                    if (sys_ready == 1'b1) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule
