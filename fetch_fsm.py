import base64
import zlib
import urllib.request

text = """stateDiagram-v2
    [*] --> IDLE
    
    IDLE --> ARB_REFRESH : Cờ refresh_req == 1<br/>(Ưu tiên Cao nhất - Bảo vệ dữ liệu SDRAM)
    IDLE --> ARB_READ : Cờ vsync_req == 1<br/>(Ưu tiên 2 - Đảm bảo VGA không bị đói)
    
    IDLE --> ARB_WRITE : Cờ w_fifo_count >= 256<br/>(Ưu tiên 3 - Đợi dồn đủ khối Burst)
    
    ARB_WRITE --> ARB_WRITE : Đang truyền dữ liệu<br/>(Chờ Controller xác nhận)
    ARB_WRITE --> IDLE : Nhận cờ sys_wr_ack == 1<br/>(Hoàn tất ghi 256 Words)
    
    ARB_READ --> IDLE : Hoàn tất đọc Burst
    ARB_REFRESH --> IDLE : Hoàn tất Refresh
"""

compressed = zlib.compress(text.encode('utf-8'), 9)
b64 = base64.urlsafe_b64encode(compressed).decode('ascii')
url = f"https://kroki.io/mermaid/svg/{b64}"

req = urllib.request.Request(
    url, 
    headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'}
)
try:
    with urllib.request.urlopen(req) as response:
        content = response.read()
        with open('Web_Deployment/assets/FSM_SDRAM_ARBITER.svg', 'wb') as f:
            f.write(content)
    print("SVG Downloaded!")
except Exception as e:
    print(e)
