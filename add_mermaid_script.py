import re

target_file = r'D:\FPGA\Projects\OV7670_Camera_GitHub\Web_Deployment\index.html'

with open(target_file, 'r', encoding='utf-8') as f:
    html = f.read()

# Add script just before </body>
script_to_add = """
    <script>
        // Mermaid Lightbox Integration
        document.addEventListener("DOMContentLoaded", function() {
            setTimeout(() => {
                document.querySelectorAll('.mermaid svg').forEach(svg => {
                    svg.parentElement.addEventListener('click', function(e) {
                        e.stopPropagation();
                        // Serialize SVG
                        const serializer = new XMLSerializer();
                        let svgStr = serializer.serializeToString(svg);
                        if (!svgStr.match(/^<svg[^>]+xmlns="http\:\/\/www\.w3\.org\/2000\/svg"/)) {
                            svgStr = svgStr.replace(/^<svg/, '<svg xmlns="http://www.w3.org/2000/svg"');
                        }
                        const svgBlob = new Blob([svgStr], {type: "image/svg+xml;charset=utf-8"});
                        const url = URL.createObjectURL(svgBlob);
                        
                        const lightbox = document.getElementById('img-lightbox');
                        const lightboxImg = document.getElementById('lightbox-img-element');
                        
                        lightboxImg.src = url;
                        lightbox.style.display = 'flex';
                        
                        // Default scale logic for lightbox
                        if (typeof scale !== 'undefined') {
                            scale = 1;
                            translateX = 0;
                            translateY = 0;
                            if(typeof updateTransform === 'function') updateTransform();
                        }
                    });
                });
            }, 1000); // Wait for mermaid to render
        });
    </script>
"""

if "Mermaid Lightbox Integration" not in html:
    html = html.replace("</body>", script_to_add + "\n</body>")
    with open(target_file, 'w', encoding='utf-8') as f:
        f.write(html)
    print("Added Mermaid Lightbox Script")
else:
    print("Script already present")
