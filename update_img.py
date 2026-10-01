import re

target_file = r'D:\FPGA\Projects\OV7670_Camera_GitHub\Web_Deployment\index.html'

with open(target_file, 'r', encoding='utf-8') as f:
    html = f.read()

start_marker = '<div class="mermaid">'
end_marker = '</div>'

start_idx = html.find(start_marker)
end_idx = html.find(end_marker, start_idx)

if start_idx != -1 and end_idx != -1:
    end_idx += len(end_marker)
    
    new_content = """<p><img class="zoomable-img" alt="Sơ đồ Trạng thái FSM của SDRAM Arbiter" src="assets/FSM_SDRAM_ARBITER.svg" style="background: white; border-radius: 16px; padding: 20px;" /></p>"""
    
    new_html = html[:start_idx] + new_content + html[end_idx:]
    
    with open(target_file, 'w', encoding='utf-8') as f:
        f.write(new_html)
    print("Successfully replaced mermaid with SVG image.")
else:
    print("Could not find markers")
