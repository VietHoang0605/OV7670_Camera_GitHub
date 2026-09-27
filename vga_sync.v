module vga_sync (
    input  wire clk,      // Xung nhịp hệ thống (Ví dụ: 50MHz từ bộ dao động trên mạch DE1)
    input  wire rst_n,    // Tín hiệu Reset (tích cực mức THẤP - Active Low)
    input  wire ce,       // Clock Enable: Cấp xung 25MHz. Màn hình VGA 640x480 cần tốc độ quét pixel đúng 25MHz.
                          // Nếu clk là 50MHz, ce sẽ chớp (bật 1) cứ sau mỗi 2 chu kỳ clk.
    
    output reg hsync,     // Tín hiệu Đồng bộ ngang (Horizontal Sync) gửi ra màn hình VGA.
                          // Ra lệnh cho tia quét: "Về lại mép trái màn hình để quét hàng mới đi!"
    
    output reg vsync,     // Tín hiệu Đồng bộ dọc (Vertical Sync) gửi ra màn hình VGA.
                          // Ra lệnh cho tia quét: "Về lại góc trên cùng bên trái màn hình để quét khung hình mới đi!"
    
    output wire video_on, // Báo hiệu: "Súng điện tử đang nằm trong vùng có thể hiển thị (640x480)".
                          // Khi video_on = 0 (tức là súng đang quét ở lề đen), ta BẮT BUỘC phải tắt tia màu (R=G=B=0).
    
    output wire [9:0] pixel_x, // Trả về tọa độ X hiện tại của súng điện tử (0 đến 639)
    output wire [9:0] pixel_y, // Trả về tọa độ Y hiện tại của súng điện tử (0 đến 479)
    
    output wire frame_start    // Xung chớp 1 lần khi bắt đầu một khung hình (Pixel 0,0)
);

    // =========================================================================
    // CÁC THÔNG SỐ CHUẨN CỦA MÀN HÌNH VGA 640x480 @ 60Hz
    // =========================================================================
    // Một "hàng" ngang không chỉ có 640 pixel. Súng điện tử cần thời gian "nghỉ" 
    // để lùi về mép trái. Vùng "nghỉ" này bao gồm: Front Porch, Sync Pulse, và Back Porch.
    // Trục ngang (Horizontal)
    parameter H_DISPLAY = 640; // Số điểm ảnh hiển thị thực tế trên 1 hàng (Vùng sáng)
    parameter H_FRONT   = 16;  // Vùng lề đen bên phải (nghỉ ngơi trước khi kéo về)
    parameter H_SYNC    = 96;  // Độ rộng xung HSync (kéo súng điện tử về mép trái)
    parameter H_BACK    = 48;  // Vùng lề đen bên trái (nghỉ ngơi sau khi đã về mép trái)
    parameter H_TOTAL   = 800; // Tổng chiều dài của 1 hàng (640 + 16 + 96 + 48)

    // Tương tự cho Trục dọc (Vertical)
    // Một "khung hình" không chỉ có 480 hàng. Súng cần thời gian để lùi từ đáy lên đỉnh.
    parameter V_DISPLAY = 480; // Số hàng hiển thị thực tế (Vùng sáng)
    parameter V_FRONT   = 10;  // Vùng lề đen dưới đáy
    parameter V_SYNC    = 2;   // Độ rộng xung VSync (Kéo súng từ đáy lên đỉnh)
    parameter V_BACK    = 33;  // Vùng lề đen trên đỉnh
    parameter V_TOTAL   = 525; // Tổng số hàng của 1 khung hình (480 + 10 + 2 + 33)

    // =========================================================================
    // KHỐI BỘ ĐẾM QUÉT MÀN HÌNH (SCANNERS)
    // =========================================================================
    // Thanh ghi lưu trữ vị trí hiện tại của súng điện tử trên toàn màn hình (gồm cả lề đen)
    reg [9:0] h_count_reg; // Đếm từ 0 đến 799
    reg [9:0] v_count_reg; // Đếm từ 0 đến 524

    // 1. Mạch đếm ngang (Pixel Counter)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_count_reg <= 0;
        end else if (ce) begin // Chỉ đếm ở tần số 25MHz
            if(h_count_reg == H_TOTAL - 1) begin
                // Nếu quét đến cuối hàng (799), quay về 0
                h_count_reg <= 10'b0;
            end else begin
                // Nếu chưa, tịnh tiến sang phải 1 pixel
                h_count_reg <= h_count_reg + 1'b1;
            end 
        end
    end

    // 2. Mạch đếm dọc (Line Counter)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_count_reg <= 0;
        end else if (ce) begin // Chỉ đếm ở tần số 25MHz
            // Chỉ nhảy xuống hàng tiếp theo KHI VÀ CHỈ KHI hàng ngang đã quét xong (chạm mốc 799)
            if(h_count_reg == H_TOTAL - 1) begin
                if(v_count_reg == V_TOTAL - 1) begin
                    // Nếu quét đến cuối khung hình (hàng 524), quay về góc trên cùng (0)
                    v_count_reg <= 10'b0;
                end else begin
                    // Nếu chưa, nhảy xuống 1 hàng
                    v_count_reg <= v_count_reg + 1'b1;
                end
            end
        end
    end

    // =========================================================================
    // KHỐI TẠO XUNG ĐỒNG BỘ (SYNC GENERATORS)
    // =========================================================================
    // VGA tiêu chuẩn quy định: Tín hiệu HSync và VSync bình thường ở mức CAO (1).
    // Khi lọt vào vùng H_SYNC hoặc V_SYNC, chúng bị kéo xuống mức THẤP (0).
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            hsync <= 1'b1;
            vsync <= 1'b1;
        end else if (ce) begin
            // Xung HSync tích cực mức Thấp khi đếm lọt vào khoảng H_SYNC
            if (h_count_reg >= (H_DISPLAY + H_FRONT) && 
                h_count_reg <  (H_DISPLAY + H_FRONT + H_SYNC)) begin
                hsync <= 1'b0; // Kéo súng về mép trái
            end else begin
                hsync <= 1'b1; // Giữ nguyên
            end

            // Xung VSync tích cực mức Thấp khi đếm lọt vào khoảng V_SYNC
            if (v_count_reg >= (V_DISPLAY + V_FRONT) && 
                v_count_reg <  (V_DISPLAY + V_FRONT + V_SYNC)) begin
                vsync <= 1'b0; // Kéo súng lên đỉnh
            end else begin
                vsync <= 1'b1; // Giữ nguyên
            end
        end
    end
    
    // =========================================================================
    // CÁC TÍN HIỆU ĐẦU RA CHO MODULE KHÁC SỬ DỤNG
    // =========================================================================
    // Chỉ cho phép vẽ màu khi súng quét nằm trong vùng 640x480 đầu tiên.
    assign video_on = (h_count_reg < H_DISPLAY) && (v_count_reg < V_DISPLAY);
    
    // Xuất tọa độ trực tiếp (với điều kiện video_on = 1, các tọa độ này sẽ chỉ từ 0-639 và 0-479)
    assign pixel_x = h_count_reg;
    assign pixel_y = v_count_reg;
    
    // Xung chớp báo hiệu khoảnh khắc súng điện tử quay trở lại Pixel đầu tiên của màn hình (0,0)
    // Thường dùng để cập nhật logic game (như quả bóng nảy) để tránh xé hình (Tearing).
    assign frame_start = (h_count_reg == 0) && (v_count_reg == 0) && ce;

endmodule
