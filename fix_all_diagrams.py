import base64
import zlib
import urllib.request
import re

# ==========================================
# 1. GENERATE DIAGRAM 1: DATA FLOW
# ==========================================
text1 = """graph TD
    classDef module fill:#222,stroke:#4CAF50,stroke-width:2px,color:#fff,rx:8px,ry:8px;
    classDef memory fill:#222,stroke:#FF9800,stroke-width:2px,color:#fff,rx:8px,ry:8px;
    
    CAM[Camera OV7670]:::module
    WFIFO[(W-FIFO async_fifo)]:::memory
    ARB[SDRAM Arbiter]:::module
    CTRL[SDRAM Controller]:::module
    SDRAM[(Chip nhớ SDRAM)]:::memory

    CAM -->|Data: 1 pixel/80ns| WFIFO
    WFIFO -->|Data: Hút 256 words| ARB
    ARB -->|Data: Bơm tốc độ cao| CTRL
    CTRL -->|Data: 50 MWords/s| SDRAM

    WFIFO -.->|Cờ: w_fifo_count >= 256| ARB
    ARB -.->|Cờ: sys_wr_req| CTRL
    CTRL -.->|Cờ: sys_wr_ack == 1| ARB

    linkStyle 0,1,2,3 stroke:#4CAF50,stroke-width:2px,color:#4CAF50;
    linkStyle 4,5,6 stroke:#FF9800,stroke-width:2px,stroke-dasharray: 5 5,color:#FF9800;
"""
req1 = urllib.request.Request(f"https://kroki.io/mermaid/svg/{base64.urlsafe_b64encode(zlib.compress(text1.encode('utf-8'), 9)).decode('ascii')}", headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req1) as response:
    with open('Web_Deployment/assets/DATA_FLOW_BURST.svg', 'wb') as f:
        f.write(response.read())

# ==========================================
# 2. GENERATE DIAGRAM 2: FSM STATE DIAGRAM
# ==========================================
text2 = """graph TD
    classDef default fill:#222,stroke:#FF9800,stroke-width:2px,color:#fff,rx:8px,ry:8px;
    classDef initial fill:#333,stroke:#fff,stroke-width:2px,color:#fff;
    
    START(( )):::initial --> IDLE
    
    IDLE -->|Cờ: refresh_req == 1<br/>Ưu tiên 1| ARB_REFRESH
    IDLE -->|Cờ: vsync_req == 1<br/>Ưu tiên 2| ARB_READ
    IDLE -->|Cờ: w_fifo_count >= 256<br/>Ưu tiên 3| ARB_WRITE
    
    ARB_WRITE -->|Đang truyền dữ liệu<br/>Chờ xác nhận| ARB_WRITE
    ARB_WRITE -->|Cờ: sys_wr_ack == 1<br/>Hoàn tất ghi| IDLE
    
    ARB_READ -->|Hoàn tất đọc| IDLE
    ARB_REFRESH -->|Hoàn tất Refresh| IDLE

    linkStyle 0 stroke:#4CAF50,stroke-width:2px,color:#4CAF50;
    linkStyle 1,2,3 stroke:#FF9800,stroke-width:2px,stroke-dasharray: 5 5,color:#FF9800;
    linkStyle 4 stroke:#4CAF50,stroke-width:2px,color:#4CAF50;
    linkStyle 5 stroke:#FF9800,stroke-width:2px,stroke-dasharray: 5 5,color:#FF9800;
    linkStyle 6,7 stroke:#4CAF50,stroke-width:2px,color:#4CAF50;
"""
req2 = urllib.request.Request(f"https://kroki.io/mermaid/svg/{base64.urlsafe_b64encode(zlib.compress(text2.encode('utf-8'), 9)).decode('ascii')}", headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req2) as response:
    with open('Web_Deployment/assets/FSM_SDRAM_ARBITER.svg', 'wb') as f:
        f.write(response.read())

# ==========================================
# 3. UPDATE HTML TO USE IMAGES
# ==========================================
target_file = r'D:\FPGA\Projects\OV7670_Camera_GitHub\Web_Deployment\index.html'
with open(target_file, 'r', encoding='utf-8') as f:
    html = f.read()

# Replace Diagram 1 (Data Flow) - currently a <div class="mermaid"> block
html = re.sub(
    r'<div class="mermaid">\s*graph TD[\s\S]*?</div>',
    r'<p><img class="zoomable-img" alt="Sơ đồ Luồng Dữ liệu Burst Write" src="assets/DATA_FLOW_BURST.svg" style="background: white; border-radius: 16px; padding: 20px; box-shadow: 0 10px 30px rgba(0,0,0,0.2);" /></p>',
    html,
    count=1
)

# Diagram 2 is already an image pointing to FSM_SDRAM_ARBITER.svg, so we just need to make sure its style matches
html = html.replace(
    'src="assets/FSM_SDRAM_ARBITER.svg" style="background: white; border-radius: 16px; padding: 20px;"',
    'src="assets/FSM_SDRAM_ARBITER.svg" style="background: white; border-radius: 16px; padding: 20px; box-shadow: 0 10px 30px rgba(0,0,0,0.2);"'
)

with open(target_file, 'w', encoding='utf-8') as f:
    f.write(html)
    
print("Successfully generated SVGs and updated HTML.")
