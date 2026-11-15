s = open(r"D:\OpenCode\silly-os\src\kernel.zig", encoding="utf-8").read()
old = '    serialPrint("the bread foundation remains operational.\\n\\n");'
new = '    serialPrint("serial output enabled\\n\\n");'
# try simpler
if old not in s:
    # try without escaping
    import re
    s = re.sub(r'serialPrint\("the bread foundation remains operational\.\\n\\n"\);', 'serialPrint("serial output enabled\\n\\n");', s)
else:
    s = s.replace(old, new, 1)
open(r"D:\OpenCode\silly-os\src\kernel.zig", "w", encoding="utf-8").write(s)
print("bread" in s.lower())
