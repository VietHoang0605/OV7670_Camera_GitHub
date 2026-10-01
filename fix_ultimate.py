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
    classDef stateNode fill:#222,stroke:#FF9800,stroke-width:2px,color:#fff,rx:8px,ry:8px;
    classDef initialNode fill:#333,stroke:#fff,stroke-width:2px,color:#fff;
    
    START((Bắt đầu)):::initialNode
    IDLE[Trạng thái IDLE]:::stateNode
    ARB_REFRESH[ARB_REFRESH]:::stateNode
    ARB_READ[ARB_READ]:::stateNode
    ARB_WRITE[ARB_WRITE]:::stateNode

    START --> IDLE
    IDLE -->|Cờ báo refresh_req bật| ARB_REFRESH
    IDLE -->|Cờ báo vsync_req bật| ARB_READ
    IDLE -->|Cờ báo w_fifo_count đạt 256| ARB_WRITE
    
    ARB_WRITE -->|Đang truyền dữ liệu| ARB_WRITE
    ARB_WRITE -->|Cờ báo sys_wr_ack bật| IDLE
    
    ARB_READ -->|Hoàn tất đọc| IDLE
    ARB_REFRESH -->|Hoàn tất Refresh| IDLE

    linkStyle 0 stroke:#4CAF50,stroke-width:2px,color:#4CAF50;
    linkStyle 1 stroke:#FF9800,stroke-width:2px,stroke-dasharray:5 5,color:#FF9800;
    linkStyle 2 stroke:#FF9800,stroke-width:2px,stroke-dasharray:5 5,color:#FF9800;
    linkStyle 3 stroke:#FF9800,stroke-width:2px,stroke-dasharray:5 5,color:#FF9800;
    linkStyle 4 stroke:#4CAF50,stroke-width:2px,color:#4CAF50;
    linkStyle 5 stroke:#FF9800,stroke-width:2px,stroke-dasharray:5 5,color:#FF9800;
    linkStyle 6 stroke:#4CAF50,stroke-width:2px,color:#4CAF50;
    linkStyle 7 stroke:#4CAF50,stroke-width:2px,color:#4CAF50;
</div>"""
        html = html[:start_idx] + new_fsm + html[end_idx + len(end_marker):]
        with open(target_file, 'w', encoding='utf-8') as f:
            f.write(html)
        print("Replaced mermaid with ultimate safe syntax.")
else:
    print("No mermaid block found.")
