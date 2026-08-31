with open('DC_Bus_Voltage_Regulation_DRL_Report.pdf', 'rb') as f:
    content = f.read()

import re
counts = re.findall(rb'/Count\s+(\d+)', content)
print("PDF Count tags found:", counts)

pages = re.findall(rb'/Type\s*/Page\b', content)
print("Page objects found:", len(pages))
