# 🧠 SILLYOS 🧠

## A FROM-SCRATCH OPERATING SYSTEM IN ZIG. ACTUALLY USEFUL. (PROBABLY.)

built by the silly team. the bread foundation remains operational. 🥖

## STATUS

🚧 **EXTREMELY EARLY** 🚧

currently implements:
- multiboot header (boots via grub)
- vga text mode (80x25, 16 colors)
- kernel entry point in zig
- clear screen + print text
- basic cursor management
- a window that says "Silly Engine" (wait that's the other project)

## BUILDING

requires [zig 0.13.0+](https://ziglang.org/download/) and grub-mkrescue (for ISO)

```sh
zig build          # build kernel
zig build iso      # build bootable ISO (requires grub-mkrescue)
```

## RUNNING

```sh
# with qemu
qemu-system-x86_64 -cdrom sillyos.iso

# or use the .elf directly
qemu-system-x86_64 -kernel zig-out/bin/sillyos
```

## ROADMAP

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

## WHY ZIG?

because it sounds silly. and we are all about silly.

also it's fast, memory-safe, has great c interop, and doesn't have a garbage collector. perfect for an operating system.

## THE CORPORATE OVERLORDS

sillyos is a product of **brain liquidation inc.**, a fictional corporation whose primary business is supposedly liquidating brains. its ceo is half a braincell. its subsidiaries include potato computing, the bread foundation, silly systems, neuron destruction llc, and nobro technologies.

applesoft has sued brain liquidation inc. for solidifying brains instead of liquidating them. nobro technologies has no bro. the bread foundation controls the entire economy.

the breadening is inevitable. 🥖

## LICENSE

MIT

<div align="center">
  <p>built with <code>:3</code> and a concerning amount of coffee..... and also a tiny bit of brain liquidation</p>
  <p>
    <a href="https://github.com/the-silly-team">github.com/the-silly-team</a>
  </p>
  <p><sub>the bread foundation remains operational 🥖</sub></p>
</div>
