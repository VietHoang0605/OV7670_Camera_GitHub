import re

target_file = r'D:\FPGA\Projects\OV7670_Camera_GitHub\Web_Deployment\index.html'

with open(target_file, 'r', encoding='utf-8') as f:
    html = f.read()

start_marker = "<h2>7. Khóa chặt quang học và Chinh phục nhiễu dây dẫn (Signal Integrity)</h2>"
end_marker = "<p>Và đây là kết quả cuối cùng - minh chứng hùng hồn nhất cho một hệ thống FPGA hoàn hảo (Pixel-perfect):"

start_idx = html.find(start_marker)
end_idx = html.find(end_marker)

if start_idx != -1 and end_idx != -1:
    new_content = """<h2>7. Khóa chặt quang học và Chinh phục nhiễu tổ hợp (Signal Integrity & Output Registering)</h2>
<p>Mặc dù giao tiếp I2C đã hoạt động ổn định, nhưng khi xuất dữ liệu dạng dải màu (Color Bar), hình ảnh hiển thị trên màn hình VGA vẫn xuất hiện hiện tượng giằng co với dữ liệu quang học thực tế và chớp nháy (Flickering) liên tục. Để hệ thống đạt được sự hoàn hảo và triệt tiêu hoàn toàn nhiễu tín hiệu, hai kỹ thuật cốt lõi cuối cùng đã được áp dụng:</p>

<p><strong>Đòn 1: Combo lệnh phong ấn quang học (I2C Configuration)</strong><br />
Hệ thống được cấu hình lại bộ lệnh I2C nhằm cô lập hoàn toàn mạch xử lý tín hiệu số (DSP) nội bộ khỏi cảm biến quang học:</p>
<ul>
<li><code>COM17 = 0x08</code>, <code>SCALING_XSC = 0xBA</code>, <code>SCALING_YSC = 0xB5</code>: Kích hoạt chế độ dải màu thử nghiệm (Test Pattern) trên các khối thu phóng và xử lý số.</li>
<li><code>COM8 = 0xC0</code>: Tắt hoàn toàn các tính năng tự động phơi sáng (AEC), tự động khuếch đại (AGC) và tự động cân bằng trắng (AWB) nhằm ngăn chặn việc Camera liên tục bù trừ sai lệch khi không thu nhận tín hiệu quang học.</li>
</ul>
<p>Lúc này, hệ thống ghi nhận cờ báo lỗi <code>ack_error</code> (LED 8) đã tắt lịm, chứng minh toàn bộ chuỗi lệnh trên đã được truyền tải thành công 100% vào các thanh ghi của Camera.</p>

<p><strong>Đòn 2: Loại bỏ nhiễu tổ hợp bằng tầng chốt dữ liệu ngõ ra (Output Registering - D_FF)</strong><br />
Hiện tượng màn hình chớp nháy và xuất hiện gai nhiễu (glitches) phát sinh do sự chênh lệch thời gian trễ (propagation delay) khi tín hiệu truyền qua mạng logic tổ hợp (combinational logic) trước khi xuất ra cổng VGA. Để giải quyết triệt để sự cố toàn vẹn tín hiệu này, toàn bộ các tín hiệu đầu ra (vga_r, vga_g, vga_b, hsync, vsync) đã được thiết kế đi qua một tầng chốt dữ liệu D Flip-Flop (D_FF).</p>

<p>Kỹ thuật Output Registering giúp gạn lọc mọi gai nhiễu tổ hợp, ép tất cả các tín hiệu xuất ra cổng VGA phải thẳng hàng tuyệt đối tại sườn lên của xung nhịp Clock, đảm bảo chất lượng hình ảnh sắc nét và hoàn toàn ổn định. Bằng chứng thiết kế được thể hiện rõ qua mã nguồn của Module Top:</p>

<pre><code class="language-verilog">    // [FIX PROJECT 2] Tầng Output Registering (D_FF) triệt tiêu nhiễu tổ hợp
    reg [3:0] vga_r_out, vga_g_out, vga_b_out;
    reg vga_hs_out, vga_vs_out;

    always @(posedge clk_50m or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            vga_r_out  <= 4'd0; vga_g_out  <= 4'd0; vga_b_out  <= 4'd0;
            vga_hs_out <= 1'b1; vga_vs_out <= 1'b1;
        end else begin
            // Chốt toàn bộ dữ liệu màu và xung đồng bộ tại sườn lên của Clock
            vga_r_out  <= vga_r_reg; 
            vga_g_out  <= vga_g_reg; 
            vga_b_out  <= vga_b_reg;
            vga_hs_out <= vga_hsync_w; 
            vga_vs_out <= vga_vsync_w;
        end
    end
    
    // Xuất dữ liệu đã được làm sạch ra chân Pin vật lý
    assign vga_r = vga_r_out; 
    assign vga_g = vga_g_out; 
    assign vga_b = vga_b_out; 
    assign vga_hsync = vga_hs_out; 
    assign vga_vsync = vga_vs_out;</code></pre>
"""
    new_html = html[:start_idx] + new_content + html[end_idx:]
    with open(target_file, 'w', encoding='utf-8') as f:
        f.write(new_html)
    print("Successfully replaced content")
else:
    print("Could not find markers")
    print(f"start_idx: {start_idx}, end_idx: {end_idx}")

