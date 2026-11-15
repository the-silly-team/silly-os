s = open(r"D:\OpenCode\silly-os\build.zig", encoding="utf-8").read()
s = s.replace('.cpu_arch = .x86_64,', '.cpu_arch = .x86,')
s = s.replace('.abi = .none,', '.abi = .none,')
open(r"D:\OpenCode\silly-os\build.zig", "w", encoding="utf-8").write(s)
print("done")
# verify
s = open(r"D:\OpenCode\silly-os\build.zig", encoding="utf-8").read()
for l in s.split(chr(10)):
    if 'cpu_arch' in l or 'os_tag' in l or 'abi' in l:
        print(l.strip())
