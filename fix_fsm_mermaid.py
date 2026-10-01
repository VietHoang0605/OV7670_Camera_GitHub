import re

target_file = r'D:\FPGA\Projects\OV7670_Camera_GitHub\Web_Deployment\index.html'

with open(target_file, 'r', encoding='utf-8') as f:
    html = f.read()

# The FSM diagram is currently an <img src="assets/FSM_SDRAM_ARBITER.svg">. 
# We need to replace it with a styled <div class="mermaid"> block using graph TD.

start_marker = '<p><img class="zoomable-img" alt="Sơ đồ Trạng thái FSM của SDRAM Arbiter"'
end_marker = '/></p>'

start_idx = html.find(start_marker)
end_idx = html.find(end_marker, start_idx)

if start_idx != -1 and end_idx != -1:
    end_idx += len(end_marker)
    
    new_content = """<div class="mermaid">
graph TD
    classDef state fill:#222,stroke:#FF9800,stroke-width:2px,color:#fff,rx:8px,ry:8px;
    classDef initial fill:#333,stroke:#fff,stroke-width:2px,color:#fff;
    
    START(( )):::initial --> IDLE:::state
    
    IDLE -->|Cờ: refresh_req == 1<br/>Ưu tiên 1| ARB_REFRESH:::state
    IDLE -->|Cờ: vsync_req == 1<br/>Ưu tiên 2| ARB_READ:::state
    IDLE -->|Cờ: w_fifo_count >= 256<br/>Ưu tiên 3| ARB_WRITE:::state
    
    ARB_WRITE -->|Đang truyền dữ liệu<br/>Chờ xác nhận| ARB_WRITE
    ARB_WRITE -->|Cờ: sys_wr_ack == 1<br/>Hoàn tất ghi| IDLE
    
    ARB_READ -->|Hoàn tất đọc| IDLE
    ARB_REFRESH -->|Hoàn tất Refresh| IDLE

    %% Styling links
    %% 0: START -> IDLE (Green, solid)
    linkStyle 0 stroke:#4CAF50,stroke-width:2px,color:#4CAF50;
    
    %% 1,2,3: IDLE -> states (Conditions/Control -> Orange dashed)
    linkStyle 1,2,3 stroke:#FF9800,stroke-width:2px,stroke-dasharray: 5,color:#FF9800;
    
    %% 4: ARB_WRITE -> ARB_WRITE (Data transmitting -> Green solid)
    linkStyle 4 stroke:#4CAF50,stroke-width:2px,color:#4CAF50;
    
    %% 5: ARB_WRITE -> IDLE (Condition ack -> Orange dashed)
    linkStyle 5 stroke:#FF9800,stroke-width:2px,stroke-dasharray: 5,color:#FF9800;
    
    %% 6,7: ARB_READ -> IDLE, ARB_REFRESH -> IDLE (Return to idle -> Green solid)
    linkStyle 6,7 stroke:#4CAF50,stroke-width:2px,color:#4CAF50;
</div>"""
    
    new_html = html[:start_idx] + new_content + html[end_idx:]
    with open(target_file, 'w', encoding='utf-8') as f:
        f.write(new_html)
    print("Replaced SVG with styled Mermaid graph TD.")
else:
    print("Could not find the SVG img tag.")
