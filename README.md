# sillyos

a from-scratch operating system in zig. actually useful.

built by the silly team. the bread foundation remains operational.

## status

🚧 **extremely early** 🚧

currently implements:
- multiboot header (boots via grub)
- vga text mode (80x25, 16 colors)
- kernel entry point in zig
- clear screen + print text
- basic cursor management

## building

requires [zig 0.13.0+](https://ziglang.org/download/) and grub-mkrescue (for ISO)

```sh
zig build          # build kernel
zig build iso      # build bootable ISO (requires grub-mkrescue)
```

## running

```sh
# with qemu
qemu-system-x86_64 -cdrom sillyos.iso

# or use the .elf directly
qemu-system-x86_64 -kernel zig-out/bin/sillyos
```

## roadmap

- [x] multiboot header
- [x] vga text mode
- [x] kernel entry point
- [ ] keyboard input (ps/2 or usb)
- [ ] memory management (paging, heap)
- [ ] interrupt handling (idt, isr)
- [ ] timer (pit/apic)
- [ ] filesystem (fat32 or ext2)
- [ ] shell
- [ ] network (e1000 or rtl8139)
- [ ] gui (framebuffer)
- [ ] silly browser integration
- [ ] brain liquidation inc. as a system service

## license

MIT

<div align="center">
  <p>built with <code>:3</code> and a concerning amount of coffee.....</p>
  <p>
    <a href="https://github.com/the-silly-team">github.com/the-silly-team</a>
  </p>
</div>
