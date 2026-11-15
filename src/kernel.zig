// SillyOS - Kernel entry point
// Written in Zig, booted via multiboot

const std = @import("std");

// VGA text mode constants
const VGA_BUFFER: [*]volatile u16 = @ptrFromInt(0xB8000);
const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;

// Colors
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

fn putChar(c: u8) void {
    if (c == '\n') {
        cursor_x = 0;
        cursor_y += 1;
        if (cursor_y >= VGA_HEIGHT) cursor_y = VGA_HEIGHT - 1;
        return;
    }
    if (c == '\r') {
        cursor_x = 0;
        return;
    }
    if (cursor_x >= VGA_WIDTH) {
        cursor_x = 0;
        cursor_y += 1;
        if (cursor_y >= VGA_HEIGHT) cursor_y = VGA_HEIGHT - 1;
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

// Kernel entry point (called by bootloader)
export fn kernelMain() callconv(.C) void {
    clearScreen();
    setColor(.light_cyan, .black);
    print("=== SillyOS v0.1 ===\n");
    setColor(.light_gray, .black);
    print("a from-scratch OS in zig\n");
    print("the bread foundation remains operational.\n\n");

    setColor(.yellow, .black);
    print("system info:\n");
    setColor(.light_gray, .black);
    print("  cpu: x86_64\n");
    print("  memory: detecting...\n");
    print("  kernel: zig\n");

    setColor(.green, .black);
    print("\n> sillyos kernel booted successfully\n");
    setColor(.light_gray, .black);
    print("> type 'help' for commands\n");

    // Halt
    while (true) {
        asm volatile ("hlt");
    }
}

// Multiboot header
export const multiboot_header align(4) linksection(".multiboot") = MultibootHeader{
    .magic = 0x1BADB002,
    .flags = 0,
    .checksum = @as(u32, 0) -% 0x1BADB002 -% 0,
};

const MultibootHeader = packed struct {
    magic: u32,
    flags: u32,
    checksum: u32,
};
