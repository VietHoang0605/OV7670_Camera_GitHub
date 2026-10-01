import re

target_file = r'D:\FPGA\Projects\OV7670_Camera_GitHub\Web_Deployment\index.html'

with open(target_file, 'r', encoding='utf-8') as f:
    html = f.read()

# Look for the first diagram which contains "WFIFO[(W-FIFO async_fifo)]:::memory"
match = re.search(r'<div class="mermaid">\s*graph TD\s*%% Định nghĩa CSS cho các Node.*?</div>', html, flags=re.DOTALL)
if match:
    html = html[:match.start()] + html[match.end():]
    with open(target_file, 'w', encoding='utf-8') as f:
        f.write(html)
    print("REMOVED Diagram 1 successfully.")
else:
    print("Diagram 1 not found.")