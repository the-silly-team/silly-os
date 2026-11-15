// SillyOS - Kernel with VGA + serial output
// Written in Zig, booted via multiboot

const std = @import("std");

// VGA text mode constants
const VGA_BUFFER: [*]volatile u16 = @ptrFromInt(0xB8000);
const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;

// Serial port (COM1)
const COM1: u16 = 0x3F8;

const Color = enum(u8) {
    black = 0,
    blue = 1,
    green = 2,
    cyan = 3,
    red = 4,
    magenta = 5,
    brown = 6,
    light_gray = 7,
    dark_gray = 8,
    light_blue = 9,
    light_green = 10,
    light_cyan = 11,
    light_red = 12,
    light_magenta = 13,
    yellow = 14,
    white = 15,
};

fn vgaEntry(char: u8, fg: Color, bg: Color) u16 {
    return @as(u16, char) | (@as(u16, @intFromEnum(fg)) | (@as(u16, @intFromEnum(bg)) << 4)) << 8;
}

var cursor_x: usize = 0;
var cursor_y: usize = 0;
var current_fg: Color = .light_green;
var current_bg: Color = .black;

// Port I/O
fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[result]"
        : [result] "={al}" (-> u8),
        : [port] "N{dx}" (port),
    );
}

fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "N{dx}" (port),
    );
}

// Serial output
fn serialInit() void {
    outb(COM1 + 1, 0x00); // Disable interrupts
    outb(COM1 + 3, 0x80); // Enable DLAB
    outb(COM1 + 0, 0x03); // 38400 baud (divisor = 3)
    outb(COM1 + 1, 0x00);
    outb(COM1 + 3, 0x03); // 8 bits, no parity, 1 stop bit
    outb(COM1 + 2, 0xC7); // Enable FIFO
    outb(COM1 + 4, 0x0B); // IRQs enabled, RTS/DSR set
}

fn serialPutChar(c: u8) void {
    // Wait for transmit holding register to be empty
    while (inb(COM1 + 5) & 0x20 == 0) {}
    outb(COM1, c);
}

fn serialPrint(s: []const u8) void {
    for (s) |c| serialPutChar(c);
}

fn putChar(c: u8) void {
    // Also send to serial
    serialPutChar(c);

    if (c == '\n') {
        cursor_x = 0;
        cursor_y += 1;
        if (cursor_y >= VGA_HEIGHT) {
            scrollScreen();
            cursor_y = VGA_HEIGHT - 1;
        }
        return;
    }
    if (c == '\r') {
        cursor_x = 0;
        return;
    }
    if (cursor_x >= VGA_WIDTH) {
        cursor_x = 0;
        cursor_y += 1;
        if (cursor_y >= VGA_HEIGHT) {
            scrollScreen();
            cursor_y = VGA_HEIGHT - 1;
        }
    }
    const idx = cursor_y * VGA_WIDTH + cursor_x;
    VGA_BUFFER[idx] = vgaEntry(c, current_fg, current_bg);
    cursor_x += 1;
}

fn print(s: []const u8) void {
    for (s) |c| putChar(c);
}

fn setColor(fg: Color, bg: Color) void {
    current_fg = fg;
    current_bg = bg;
}

fn clearScreen() void {
    var y: usize = 0;
    while (y < VGA_HEIGHT) : (y += 1) {
        var x: usize = 0;
        while (x < VGA_WIDTH) : (x += 1) {
            VGA_BUFFER[y * VGA_WIDTH + x] = vgaEntry(' ', .light_gray, .black);
        }
    }
    cursor_x = 0;
    cursor_y = 0;
}

fn scrollScreen() void {
    var y: usize = 1;
    while (y < VGA_HEIGHT) : (y += 1) {
        var x: usize = 0;
        while (x < VGA_WIDTH) : (x += 1) {
            VGA_BUFFER[(y - 1) * VGA_WIDTH + x] = VGA_BUFFER[y * VGA_WIDTH + x];
        }
    }
    var x: usize = 0;
    while (x < VGA_WIDTH) : (x += 1) {
        VGA_BUFFER[(VGA_HEIGHT - 1) * VGA_WIDTH + x] = vgaEntry(' ', .light_gray, .black);
    }
}

// Multiboot header
export const multiboot_header align(4) linksection(".multiboot") = MultibootHeader{
    .magic = 0x1BADB002,
    .flags = 0,
    .checksum = @as(u32, 0) -% 0x1BADB002 -% 0,
};

const MultibootHeader = extern struct {
    magic: u32,
    flags: u32,
    checksum: u32,
};

// Kernel entry point
export fn _start() callconv(.C) void {
    kernelMain();
}

export fn kernelMain() callconv(.C) void {
    serialInit();
    clearScreen();

    serialPrint("=== SillyOS v0.3 ===\n");
    serialPrint("a from-scratch OS in zig\n");
    serialPrint("serial output enabled\n\n");

    setColor(.light_cyan, .black);
    print("=== SillyOS v0.3 ===\n");
    setColor(.light_gray, .black);
    print("a from-scratch OS in zig\n");
    print("serial output enabled\n\n");

    setColor(.yellow, .black);
    print("system info:\n");
    setColor(.light_gray, .black);
    print("  cpu: x86_32\n");
    print("  vga: 80x25 text mode\n");
    print("  serial: COM1 38400 baud\n");

    setColor(.green, .black);
    print("\n> SillyOS booted successfully\n");
    setColor(.light_gray, .black);
    print("> type 'help' for commands (keyboard not yet implemented)\n");

    // Halt
    while (true) {
        asm volatile ("hlt");
    }
}
