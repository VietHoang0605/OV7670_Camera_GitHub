import re

target_file = r'D:\FPGA\Projects\OV7670_Camera_GitHub\Web_Deployment\index.html'

with open(target_file, 'r', encoding='utf-8') as f:
    html = f.read()

# Find all <div class="mermaid"> blocks and print their contents to see what we have
matches = re.findall(r'<div class="mermaid">.*?</div>', html, flags=re.DOTALL)
print(f"Found {len(matches)} mermaid blocks.")

for i, m in enumerate(matches):
    print(f'"""\nBlock {i+1}:\n"'")
    print(m)