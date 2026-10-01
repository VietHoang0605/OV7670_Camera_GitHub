import re

target_file = r'D:\FPGA\Projects\OV7670_Camera_GitHub\Web_Deployment\index.html'

with open(target_file, 'r', encoding='utf-8') as f:
    html = f.read()

start_marker = "<h3>Câu hỏi 1: Tại sao chỉ bơm được ~1/3 màn hình?</h3>"
end_marker = "[ Chip nhớ SDRAM ] ────── Ghi xong cả khung 640x480 chỉ mất 6,5ms!\n</code></pre>"

start_idx = html.find(start_marker)
end_idx = html.find(end_marker)

if start_idx != -1 and end_idx != -1:
    end_idx += len(end_marker)
    
    new_content = """<h3>1. Tại sao chỉ bơm được ~1/3 màn hình? (Nút thắt cổ chai W-FIFO)</h3>
<p>Nguyên nhân gốc rễ không nằm ở xung đột với VGA, mà nằm ở <strong>sự nghẽn mạch tại W-FIFO (Bể chứa đầu vào)</strong> do tốc độ "Hút" không theo kịp tốc độ "Bơm".</p>
<ul>
<li><strong>Tốc độ Camera bơm vào:</strong> Camera đẩy dữ liệu liên tục vào W-FIFO với tốc độ 1 pixel / 80ns (Tương đương <strong>12 triệu pixel/giây</strong>).</li>
<li><strong>Tốc độ Trọng tài (Arbiter) hút ra:</strong> Ở thiết kế cũ, chiều ghi của SDRAM bị đặt ở chế độ ghi đơn lẻ (Single Access). Việc rút 1 pixel từ W-FIFO đem đi cất vào SDRAM diễn ra rất chậm chạp, tốc độ hút ra tối đa chỉ đạt <strong>5 triệu pixel/giây</strong>.</li>
<li><strong>Hậu quả (Tràn W-FIFO):</strong> Vì tốc độ bơm (12M) lớn hơn gấp đôi tốc độ hút (5M), W-FIFO nhanh chóng bị đầy ứ (Overflow) chỉ sau vài dòng quét. Các pixel sinh ra sau đó không còn chỗ chứa nên bị phần cứng vứt bỏ (Drop) vĩnh viễn. Khi xung <code>VSYNC</code> mới ập tới để bắt đầu khung hình tiếp theo, con trỏ ghi bị giật về 0 trong khi lượng điểm ảnh sống sót mới chỉ đủ lấp đầy khoảng 1/3 chiều cao màn hình.</li>
</ul>

<h3>2. Tại sao hình ảnh lại bị nhiễu sọc ngang rất nặng?</h3>
<ul>
<li><strong>Mất đồng bộ không gian do rớt Pixel:</strong> Khi W-FIFO bị đầy và các điểm ảnh bị vứt bỏ, hệ thống ghi SDRAM không hề biết điều đó. Nó vẫn tiếp tục xếp các điểm ảnh "sống sót" kế tiếp vào ngay sát cạnh nhau.</li>
<li>Hệ quả là tọa độ của các điểm ảnh bị thụt lùi, xô lệch và tràn từ dòng này sang dòng khác. Khung hình bị xé toạc theo phương ngang, tạo thành các vệt sóng gợn và sọc chuyển động liên tục.</li>
</ul>

<h3>3. Giải pháp: Mở rộng đường ống với Burst Write 256</h3>
<p>Để giải quyết nút thắt này, hệ thống Arbiter và SDRAM Controller được thiết kế lại để thay vì rút từng giọt nước, nó sẽ chờ phao báo đủ nước và <strong>Hút một lèo 256 pixel liên tục (Burst Write)</strong>.</p>
<pre><code>[Camera OV7670]
  | 
  | (Bơm liên tục: 1 pixel / 80ns ~ 12M pixels/s)
  v
[ W-FIFO (Bể đệm đầu vào) ] 
  | --- (Lắp thêm phao đo 'rcount' ở miền 50MHz để theo dõi)
  | 
  | (Khi phao báo đầy 256 giọt: Gọi Trọng tài tới xử lý)
  v
[ SDRAM Arbiter (Trọng tài) ] 
  | --- (Hành động 1: HÚT 1 lèo 256 words từ W-FIFO)
  | --- (Hành động 2: BƠM tốc độ cao vào SDRAM Controller)
  v
[ SDRAM Controller ] 
  | --- (Cấu hình Mode Register: 12'h037 - Kích hoạt Burst Write)
  |
  v (Cánh cổng mở rộng: Tốc độ xả nước vọt lên 50 MWords/s!)
[ Chip nhớ SDRAM ]</code></pre>"""

    # Do the replacement
    new_html = html[:start_idx] + new_content + html[end_idx:]
    
    # Write back
    with open(target_file, 'w', encoding='utf-8') as f:
        f.write(new_html)
    print("Successfully replaced content")
else:
    print(f"Could not find markers. start_idx: {start_idx}, end_idx: {end_idx}")

