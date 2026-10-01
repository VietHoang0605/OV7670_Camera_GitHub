import re

target_file = r'D:\FPGA\Projects\OV7670_Camera_GitHub\Web_Deployment\index.html'

with open(target_file, 'r', encoding='utf-8') as f:
    html = f.read()

# 1. REMOVE THE FIRST DIAGRAM
# Find the start of the first diagram and remove it.
# It is located after "<h3>3. Giải pháp: Mở rộng đường ống với Burst Write 256</h3>\n<p>...</p>\n"
start_mermaid_1 = '<div class="mermaid">\ngraph TD\n    %% Định nghĩa CSS'
end_mermaid_1 = '</div>'

start_idx1 = html.find(start_mermaid_1)
if start_idx1 != -1:
    end_idx1 = html.find(end_mermaid_1, start_idx1)
    if end_idx1 != -1:
        # Remove the block entirely, including the div
        html = html[:start_idx1] + html[end_idx1 + len(end_mermaid_1):]
        print("Removed the first diagram.")

# 2. FIX THE SECOND DIAGRAM
# The second diagram is currently a graph TD but with unquoted labels that cause syntax error.
start_mermaid_2 = '<div class="mermaid">\ngraph TD\n    classDef state'
start_idx2 = html.find(start_mermaid_2)

if start_idx2 != -1:
    end_idx2 = html.find(end_mermaid_1, start_idx2)
    if end_idx2 != -1:
        new_fsm = """<div class="mermaid">
graph TD
    classDef state fill:#222,stroke:#FF9800,stroke-width:2px,color:#fff,rx:8px,ry:8px;
    classDef initial fill:#333,stroke:#fff,stroke-width:2px,color:#fff;
    
    START(( )):::initial --> IDLE:::state
    
    IDLE -->|"Cờ: refresh_req == 1<br/>Ưu tiên 1"| ARB_REFRESH:::state
    IDLE -->|"Cờ: vsync_req == 1<br/>Ưu tiên 2"| ARB_READ:::state
    IDLE -->|"Cờ: w_fifo_count >= 256<br/>Ưu tiên 3"| ARB_WRITE:::state
    
    ARB_WRITE -->|"Đang truyền dữ liệu<br/>Chờ xác nhận"| ARB_WRITE
    ARB_WRITE -->|"Cờ: sys_wr_ack == 1<br/>Hoàn tất ghi"| IDLE
    
    ARB_READ -->|"Hoàn tất đọc"| IDLE
    ARB_REFRESH -->|"Hoàn tất Refresh"| IDLE

    linkStyle 0 stroke:#4CAF50,stroke-width:2px,color:#4CAF50;
    linkStyle 1,2,3 stroke:#FF9800,stroke-width:2px,stroke-dasharray: 5,color:#FF9800;
    linkStyle 4 stroke:#4CAF50,stroke-width:2px,color:#4CAF50;
    linkStyle 5 stroke:#FF9800,stroke-width:2px,stroke-dasharray: 5,color:#FF9800;
    linkStyle 6,7 stroke:#4CAF50,stroke-width:2px,color:#4CAF50;
</div>"""
        html = html[:start_idx2] + new_fsm + html[end_idx2 + len(end_mermaid_1):]
        print("Fixed the second diagram (FSM).")
else:
    print("Could not find the second diagram.")

with open(target_file, 'w', encoding='utf-8') as f:
    f.write(html)
