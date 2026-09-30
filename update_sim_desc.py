import re

target_file = r'D:\FPGA\Projects\OV7670_Camera_GitHub\Web_Deployment\index.html'

with open(target_file, 'r', encoding='utf-8') as f:
    html = f.read()

# Define the new descriptions mapping
new_desc_1 = """<b>Chặng 1: Nhiễu rác & "Cái bồn không phao".</b><br>Arbiter bị treo do dùng nhầm Async FIFO không có cổng báo mực nước, khiến nó chỉ cắm cúi xả ảnh ra VGA mà không hút ảnh mới. Kèm theo lệnh I2C gửi quá sớm làm Camera "chết lâm sàng"."""

new_desc_2 = """<b>Chặng 2: Nghẽn băng thông SDRAM.</b><br>SDRAM bị kẹt ở chế độ Single Write (ghi chậm hơn Camera 2,5 lần). W-FIFO tràn liên tục khiến màn hình chỉ vẽ được 1/3 phía trên, phần dưới là rác tĩnh và xé sọc ngang."""

new_desc_3 = """<b>Chặng 3: Rác đọng & Nứt dọc chia đôi.</b><br>Lúc khởi động, 280 pixel rác lọt vào W-FIFO và vĩnh viễn không bị ghi đè. Lượng rác này tạo ra độ dời địa chỉ làm lệch khung hình, sinh ra vết nứt dọc. Sửa bằng cách Xả đáy (Flush) W-FIFO mỗi khi VSYNC chuyển khung."""

new_desc_4 = """<b>Chặng 4: Áo ảnh I2C & Thiếu Pull-up.</b><br>Màn hình ám màu Neon/Tím dù mô phỏng Waveform đúng 100%. SignalTap phát hiện dây I2C SDA bị kẹt bẹp ở mức 0V do thiếu điện trở kéo lên, khiến Camera "mù điếc" trước 156 lệnh cấu hình. Sửa bằng Weak Pull-Up."""

new_desc_5 = """<b>Chặng 5: 5 Sọc dọc CAS Latency.</b><br>Màn hình vỡ thành 5 sọc nứt phân bố đều. SDRAM Controller bị thiết kế nôn nóng, lấy mẫu sớm 1 nhịp so với CAS Latency=3, dẫn đến mỗi khối Burst 256 đều đớp nhầm 1 pixel rác ở đầu và hụt 1 pixel thật ở đuôi."""

new_desc_6 = """<b>✅ KẾT QUẢ HOÀN THIỆN.</b><br>Hệ thống vượt qua mọi bài test khắc nghiệt: Đóng gói RGB565 chuẩn xác, Pipeline SDRAM Ping-Pong hoạt động mượt mà, I2C ổn định. Hình ảnh hiển thị Pixel-perfect, không nhiễu, không trôi."""

# Construct regex replacements for each stage block
import re

# Stage 1
html = re.sub(r'if \(stageNum === 1\) desc\.innerHTML = ".*?";',
              f'if (stageNum === 1) desc.innerHTML = \'{new_desc_1}\';', html)

# Stage 2
html = re.sub(r'else if \(stageNum === 2\) desc\.innerHTML = ".*?";',
              f'else if (stageNum === 2) desc.innerHTML = \'{new_desc_2}\';', html)

# Stage 3
html = re.sub(r'else if \(stageNum === 3\) desc\.innerHTML = ".*?";',
              f'else if (stageNum === 3) desc.innerHTML = \'{new_desc_3}\';', html)

# Stage 4
html = re.sub(r'else if \(stageNum === 4\) desc\.innerHTML = ".*?";',
              f'else if (stageNum === 4) desc.innerHTML = \'{new_desc_4}\';', html)

# Stage 5
html = re.sub(r'else if \(stageNum === 5\) desc\.innerHTML = ".*?";',
              f'else if (stageNum === 5) desc.innerHTML = \'{new_desc_5}\';', html)

# Stage 6
html = re.sub(r'else if \(stageNum === 6\) desc\.innerHTML = ".*?";',
              f'else if (stageNum === 6) desc.innerHTML = \'{new_desc_6}\';', html)

with open(target_file, 'w', encoding='utf-8') as f:
    f.write(html)
    
print("Descriptions updated successfully!")
