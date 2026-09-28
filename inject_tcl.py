import re
import os

target_file = r'D:\FPGA\Projects\OV7670_Camera_GitHub\Web_Deployment\index.html'

with open(target_file, 'r', encoding='utf-8') as f:
    html = f.read()

# Locate the insertion point
target_str = 'thông qua lệnh cấu hình QSF: <code>set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON</code>.'

code_block = """thông qua lệnh cấu hình QSF: <code>set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON</code>.</p>
<pre><code class="language-tcl">set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to cam_sda
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to cam_scl</code></pre>
<p>"""

if target_str in html:
    html = html.replace(target_str, code_block)
    
    # Optional: add a bit of CSS for pre code if not exists, but we know verilog code blocks exist so CSS is probably already there.
    # Let's verify and just save.
    with open(target_file, 'w', encoding='utf-8') as f:
        f.write(html)
    print("Code block successfully injected into Web_Deployment HTML!")
else:
    print("Could not find the exact string to replace. Checking alternative encodings...")
    
    # Try finding without exact match in case of formatting
    target_str_alt = 'WEAK_PULL_UP_RESISTOR ON</code>.\nNhưng 40k'
    
    if target_str_alt in html:
        print("Found alternative")
