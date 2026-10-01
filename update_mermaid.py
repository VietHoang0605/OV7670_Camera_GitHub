import re

target_file = r'D:\FPGA\Projects\OV7670_Camera_GitHub\Web_Deployment\index.html'

with open(target_file, 'r', encoding='utf-8') as f:
    html = f.read()

start_marker = "<pre><code>[Camera OV7670]"
end_marker = "[ Chip nhớ SDRAM ]</code></pre>"

start_idx = html.find(start_marker)
end_idx = html.find(end_marker, start_idx)

if start_idx != -1 and end_idx != -1:
    end_idx += len(end_marker)
    
    new_content = """<div class="mermaid">
graph TD
    %% Định nghĩa CSS cho các Node
    classDef module fill:#222,stroke:#4CAF50,stroke-width:2px,color:#fff,rx:8px,ry:8px;
    classDef memory fill:#222,stroke:#FF9800,stroke-width:2px,color:#fff,rx:8px,ry:8px;
    
    CAM[Camera OV7670]:::module
    WFIFO[(W-FIFO async_fifo)]:::memory
    ARB[SDRAM Arbiter]:::module
    CTRL[SDRAM Controller]:::module
    SDRAM[(Chip nhớ SDRAM)]:::memory

    %% 1. Đường truyền dữ liệu (Data Flow) - MÀU XANH LÁ
    CAM -->|Data: 1 pixel/80ns| WFIFO
    WFIFO -->|Data: Hút 256 words| ARB
    ARB -->|Data: Bơm tốc độ cao| CTRL
    CTRL -->|Data: 50 MWords/s| SDRAM

    %% 2. Đường cờ báo (Control Flow) - MÀU CAM, NÉT ĐỨT
    WFIFO -.->|Cờ: w_fifo_count >= 256| ARB
    ARB -.->|Cờ: sys_wr_req| CTRL
    CTRL -.->|Cờ: sys_wr_ack == 1| ARB

    %% Ép màu cho các mũi tên (0-3 là Data, 4-6 là Control)
    linkStyle 0,1,2,3 stroke:#4CAF50,stroke-width:2px,color:#4CAF50;
    linkStyle 4,5,6 stroke:#FF9800,stroke-width:2px,stroke-dasharray: 5 5,color:#FF9800;
</div>"""
    
    new_html = html[:start_idx] + new_content + html[end_idx:]
    
    with open(target_file, 'w', encoding='utf-8') as f:
        f.write(new_html)
    print("Successfully replaced block diagram with mermaid flow.")
else:
    print("Could not find markers")
