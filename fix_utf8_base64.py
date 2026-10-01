import re

target_file = r'D:\FPGA\Projects\OV7670_Camera_GitHub\Web_Deployment\index.html'

with open(target_file, 'r', encoding='utf-8') as f:
    html = f.read()

start_marker = '<div class="mermaid">'
end_marker = '</div>'

start_idx = html.find(start_marker)
if start_idx != -1:
    end_idx = html.find(end_marker, start_idx)
    if end_idx != -1:
        new_fsm = """<div class="mermaid">
graph TD
    classDef state fill:#222,stroke:#FF9800,stroke-width:2px,color:#fff,rx:8px,ry:8px;
    classDef initial fill:#333,stroke:#fff,stroke-width:2px,color:#fff;
    
    START(( )):::initial --> IDLE:::state
    
    IDLE -->|"Đó: refresh_req == 1<br/>Ưu tiên 1"| ARB_REFRESH:::state
    IDLE -->|"Đó: vsync_req == 1<br/>Ưu tiên 2"| ARB_READ:::state
    IDLE -->|"Đó: w_fifo_count >= 256<br/>Ưu tiên 3"| ARB_WRITE:::state
    
    ARB_WRITE -->|"Đang truyền dữ liệu<br/>Chờ xác nhận"| ARB_WRITE
    ARB_WRITE -->|"Đó: sys_wr_ack == 1<br/>Hoàn tất ghi"| IDLE
    
    ARB_READ -->|"Hoàn tất đọc"| IDLE
    ARB_REFRESH -->|"Hoàn tất Refresh"| IDLE

    linkStyle 0 stroke:#4CAF50,stroke-width:2px,color:#4CAF50;
    linkStyle 1,2,3 stroke:#FF9800,stroke-width:2px,stroke-dasharray: 5,color:#FF9800;
    linkStyle 4 stroke:#4CAF50,stroke-width:2px,color:#4CAF50;
    linkStyle 5 stroke:#FF9800,stroke-width:2px,stroke-dasharray: 5,color:#FF9800;
    linkStyle 6,7 stroke:#4CAF50,stroke-width:2px,color:#4CAF50;
</div>"""
        html = html[:start_idx] + new_fsm + html[end_idx + len(end_marker):]
        with open(target_file, 'w', encoding='utf-8') as f:
            f.write(html)
        print("Fixed garbled UTF-8 text.")
else:
    print("Could not find block.")