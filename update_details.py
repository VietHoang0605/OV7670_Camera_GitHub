import re

target_file = r'D:\FPGA\Projects\OV7670_Camera_GitHub\Web_Deployment\index.html'

with open(target_file, 'r', encoding='utf-8') as f:
    html = f.read()

start_marker = "<h3>Chi tiết các bước thực hiện:</h3>"
end_marker = "<h2>CHẶNG 3: SỰ CỐ \"BÁC GÁC ĐẬP NHÂN BẢN NƯỚC\" VÀ \"DÒNG SUỐI HOA MẮT\"</h2>"

start_idx = html.find(start_marker)
end_idx = html.find(end_marker)

if start_idx != -1 and end_idx != -1:
    new_content = """<h3>Chi tiết các bước thực hiện & Đánh giá hiệu quả:</h3>

<h4>1. Nâng cấp Bộ đệm W-FIFO (<code>rptr_empty.v</code> & <code>async_fifo.v</code>)</h4>
<ul>
<li><strong>Thay đổi phần cứng:</strong> Xây dựng mạch giải mã Gray-to-Binary để chuyển đổi con trỏ <code>rq2_wptr</code> thành nhị phân. Tính toán biến <code>rcount = wptr_bin - rbin_reg</code> và xuất ra cổng <code>output wire [10:0] rcount</code>.</li>
<li><strong>Hiệu quả mang lại:</strong> Tạo ra một "phao đo mực nước" chính xác cho W-FIFO. Nhờ có cổng <code>rcount</code>, miền xung nhịp 50MHz giờ đây có thể giám sát theo thời gian thực lượng điểm ảnh (pixel) đang bị tồn đọng bên trong FIFO. Đây là tiền đề bắt buộc để thiết kế logic Burst Write.</li>
</ul>

<h4>2. Nâng cấp Trình điều khiển SDRAM (<code>sdram_controller.v</code>)</h4>
<ul>
<li><strong>Thay đổi phần cứng:</strong> Đổi giá trị nạp Mode Register từ <code>12'h237</code> (Single Write) sang <code>12'h037</code> (Programmed Burst Write). Xây dựng thêm chu kỳ trạng thái <code>WRITE_STREAM</code> để giữ cổng Data mở và ghi liên tục 256 nhịp xung nhịp.</li>
<li><strong>Hiệu quả mang lại (Sửa lỗi 1/3 màn hình):</strong> Kỹ thuật này tăng tốc độ hút dữ liệu từ W-FIFO lên mức tối đa (1 pixel / 20ns). Nút thắt cổ chai bị phá vỡ hoàn toàn, W-FIFO không bao giờ bị đầy tràn (Overflow) nữa, qua đó chấm dứt vĩnh viễn hiện tượng mất 2/3 khung hình và xé sọc ngang do rớt pixel.</li>
</ul>

<h4>3. Nâng cấp Trọng tài Điều phối (<code>sdram_arbiter.v</code>)</h4>
<ul>
<li><strong>Thay đổi phần cứng:</strong> Không còn ghi lắt nhắt khi <code>!w_fifo_empty</code>, Arbiter sẽ chờ điều kiện <code>w_fifo_count >= 256</code> mới phát tín hiệu yêu cầu ghi <code>sys_wr_req</code>. Khi hoàn tất, địa chỉ sẽ nhảy vọt theo khối: <code>write_addr <= write_addr + 256</code>.</li>
<li><strong>Hiệu quả mang lại:</strong> Tối ưu hóa băng thông Bus (Bandwidth Optimization). Việc dồn đủ 256 pixel mới đẩy đi 1 lần giúp giảm thiểu thời gian hao phí (Overhead) khi phải liên tục đóng/mở hàng (Row) của thẻ SDRAM, nhường lại lượng lớn thời gian quý giá cho khối VGA đọc dữ liệu ra màn hình.</li>
</ul>

<h4>4. Tích hợp Hệ thống (<code>ov7670_top.v</code>)</h4>
<ul>
<li><strong>Thay đổi phần cứng:</strong> Khai báo dây tín hiệu và nối trực tiếp cổng <code>rcount</code> từ module <code>u_w_fifo</code> sang cổng đầu vào <code>w_fifo_count</code> của module <code>u_sdram_arbiter</code>.</li>
<li><strong>Hiệu quả mang lại:</strong> Hoàn thiện luồng dữ liệu (Data Flow), kết nối thành công tín hiệu giám sát từ khối đệm đầu vào sang bộ não điều phối trung tâm.</li>
</ul>

<hr />

<h3>Sơ đồ Trạng thái (FSM) của SDRAM Arbiter sau khi cập nhật:</h3>
<p>Sự thay đổi cốt lõi được thể hiện ở nhánh <code>ARB_WRITE</code>, thay vì chỉ cần khác rỗng, máy trạng thái giờ đây đòi hỏi sự tích lũy dữ liệu đủ lớn.</p>

<div class="mermaid">
stateDiagram-v2
    [*] --> IDLE
    
    IDLE --> ARB_REFRESH : Cờ refresh_req == 1\n(Ưu tiên Cao nhất - Bảo vệ dữ liệu SDRAM)
    IDLE --> ARB_READ : Cờ vsync_req == 1\n(Ưu tiên 2 - Đảm bảo VGA không bị đói)
    
    %% ĐIỂM CẬP NHẬT CHÍNH NẰM Ở ĐÂY:
    IDLE --> ARB_WRITE : Cờ w_fifo_count >= 256\n(Ưu tiên 3 - Đợi dồn đủ khối Burst)
    
    ARB_WRITE --> ARB_WRITE : Đang truyền dữ liệu\n(Chờ Controller xác nhận)
    ARB_WRITE --> IDLE : Nhận cờ sys_wr_ack == 1\n(Hoàn tất ghi 256 Words)
    
    ARB_READ --> IDLE : Hoàn tất đọc Burst
    ARB_REFRESH --> IDLE : Hoàn tất Refresh
</div>

"""
    
    new_html = html[:start_idx] + new_content + html[end_idx:]
    with open(target_file, 'w', encoding='utf-8') as f:
        f.write(new_html)
    print("Successfully replaced content")
else:
    print("Could not find markers")
