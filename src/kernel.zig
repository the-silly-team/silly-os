// SillyOS - Kernel with BTRFS, disk I/O, keyboard input, and shell
// Written in Zig, booted via multiboot

const std = @import("std");
const disk = @import("disk.zig");
const btrfs = @import("btrfs.zig");

// VGA text mode constants
const VGA_BUFFER: [*]volatile u16 = @ptrFromInt(0xB8000);
const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;

// Serial port (COM1)
const COM1: u16 = 0x3F8;

// PIC ports
const PIC1_COMMAND: u16 = 0x20;
const PIC1_DATA: u16 = 0x21;
const PIC2_COMMAND: u16 = 0xA0;
const PIC2_DATA: u16 = 0xA1;

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

// Keyboard state
var shift_pressed: bool = false;
var caps_lock: bool = false;

// Input buffer for shell
var input_buffer: [256]u8 = undefined;
var input_len: usize = 0;

// Timer
var tick_count: u64 = 0;

// Heap
var heap_start: usize = 0x1000000;
var heap_end: usize = 0x2000000;
var heap_ptr: usize = 0x1000000;

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
    outb(COM1 + 1, 0x00);
    outb(COM1 + 3, 0x80);
    outb(COM1 + 0, 0x03);
    outb(COM1 + 1, 0x00);
    outb(COM1 + 3, 0x03);
    outb(COM1 + 2, 0xC7);
    outb(COM1 + 4, 0x0B);
}

fn serialPutChar(c: u8) void {
    while (inb(COM1 + 5) & 0x20 == 0) {}
    outb(COM1, c);
}

fn serialPrint(s: []const u8) void {
    for (s) |c| serialPutChar(c);
}

fn putChar(c: u8) void {
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

fn backspace() void {
    if (cursor_x > 0) {
        cursor_x -= 1;
        const idx = cursor_y * VGA_WIDTH + cursor_x;
        VGA_BUFFER[idx] = vgaEntry(' ', current_fg, current_bg);
    }
}

fn scancodeToAscii(scancode: u8) u8 {
    const scancode_map = [_]u8{
        0, 0, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 0, 0,
        'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n', 0,
        'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`', 0, '\\',
        'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, '*', 0, ' ',
    };
    const scancode_map_shift = [_]u8{
        0, 0, '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', 0, 0,
        'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', '\n', 0,
        'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~', 0, '|',
        'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0, '*', 0, ' ',
    };
    if (scancode >= scancode_map.len) return 0;
    if (shift_pressed or caps_lock) {
        const c = scancode_map_shift[scancode];
        if (c >= 'a' and c <= 'z' and shift_pressed and !caps_lock) {
            return c - 32;
        }
        if (c >= 'A' and c <= 'Z' and caps_lock and !shift_pressed) {
            return c + 32;
        }
        return c;
    }
    return scancode_map[scancode];
}

fn kmalloc(size: usize) ?[*]u8 {
    if (heap_ptr + size > heap_end) return null;
    const ptr = heap_ptr;
    heap_ptr += size;
    heap_ptr = (heap_ptr + 7) & ~@as(usize, 7);
    return @ptrFromInt(ptr);
}

fn processCommand() void {
    input_buffer[input_len] = 0;
    const cmd = input_buffer[0..input_len];

    if (std.mem.eql(u8, cmd, "help")) {
        print("\nCommands: help, clear, echo <text>, about, uptime, mem, ls, reboot");
    } else if (std.mem.eql(u8, cmd, "clear")) {
        clearScreen();
        print("SillyOS v0.5\n> ");
    } else if (std.mem.startsWith(u8, cmd, "echo ")) {
        print("\n");
        print(cmd[5..]);
    } else if (std.mem.eql(u8, cmd, "about")) {
        print("\nSillyOS - a from-scratch OS in Zig\n");
        print("Built by the silly team\n");
        print("Kernel: zig, VGA text mode, PS/2 keyboard\n");
        print("Filesystem: btrfs (coming soon)\n");
    } else if (std.mem.eql(u8, cmd, "uptime")) {
        print("\nTicks: ");
        var buf: [20]u8 = undefined;
        const s = std.fmt.bufPrint(&buf, "{d}", .{tick_count}) catch "?";
        print(s);
    } else if (std.mem.eql(u8, cmd, "mem")) {
        print("\nHeap: ");
        var buf: [40]u8 = undefined;
        const used = heap_ptr - heap_start;
        const total = heap_end - heap_start;
        const s = std.fmt.bufPrint(&buf, "{d}/{d} bytes used", .{ used, total }) catch "?";
        print(s);
    } else if (std.mem.eql(u8, cmd, "ls")) {
        print("\nFilesystem not yet implemented. Coming soon: btrfs!");
    } else if (std.mem.eql(u8, cmd, "disk")) {
        print("\nReading disk (ATA PIO)...\n");
        var buf: [512]u8 = undefined;
        if (disk.readSectors(0, 1, &buf)) {
            print("Sector 0 read OK. First bytes: ");
            var i: usize = 0;
            while (i < 16) : (i += 1) {
                var hexbuf: [4]u8 = undefined;
                const h = std.fmt.bufPrint(&hexbuf, "{x:0>2} ", .{buf[i]}) catch "?";
                print(h);
            }
            print("\n");
            // Check for btrfs superblock at 64KB
            var sb_buf: [4096]u8 = undefined;
            if (disk.readSectors(128, 8, &sb_buf)) {
                const sb = btrfs.readU64(&sb_buf, 0x40); // magic at offset 64
                if (sb == btrfs.BTRFS_MAGIC) {
                    print("BTRFS superblock found at 64KB!\n");
                    const label = sb_buf[0x120..0x220];
                    print("Label: ");
                    print(label);
                    print("\n");
                } else {
                    print("No btrfs superblock (magic: ");
                    var hbuf: [20]u8 = undefined;
                    const hs = std.fmt.bufPrint(&hbuf, "0x{x}", .{sb}) catch "?";
                    print(hs);
                    print(")\n");
                }
            } else {
                print("Failed to read superblock sector.\n");
            }
        } else {
            print("Disk read failed.\n");
        }
    } else if (std.mem.eql(u8, cmd, "reboot")) {
        print("\nRebooting...\n");
        asm volatile ("cli");
        const null_idt = struct { limit: u16 = 0, base: u64 = 0 }{};
        asm volatile ("lidt (%[ptr])"
            :
            : [ptr] "r" (&null_idt),
        );
        asm volatile ("int $0x03");
    } else if (input_len > 0) {
        print("\nUnknown command: ");
        print(cmd);
        print("\nType 'help' for available commands.");
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

    serialPrint("=== SillyOS v0.6 ===\n");
    serialPrint("a from-scratch OS in zig\n");
    serialPrint("serial output enabled\n\n");

    setColor(.light_cyan, .black);
    print("=== SillyOS v0.5 ===\n");
    setColor(.light_gray, .black);
    print("a from-scratch OS in zig\n");
    print("keyboard input enabled\n");
    print("type 'help' for commands\n\n");

    setColor(.green, .black);
    print("> ");
    setColor(.light_gray, .black);

    // Main loop - poll keyboard
    while (true) {
        const status = inb(0x64);
        if (status & 0x01 != 0) {
            const scancode = inb(0x60);
            if (scancode & 0x80 == 0) {
                if (scancode == 0x2A or scancode == 0x36) {
                    shift_pressed = true;
                } else if (scancode == 0x3A) {
                    caps_lock = !caps_lock;
                } else {
                    const ascii = scancodeToAscii(scancode);
                    if (ascii == '\n') {
                        processCommand();
                        input_len = 0;
                        print("\n> ");
                    } else if (ascii == 0x08) {
                        if (input_len > 0) {
                            input_len -= 1;
                            backspace();
                        }
                    } else if (ascii != 0) {
                        if (input_len < input_buffer.len - 1) {
                            input_buffer[input_len] = ascii;
                            input_len += 1;
                            putChar(ascii);
                        }
                    }
                }
            } else {
                const key = scancode & 0x7F;
                if (key == 0x2A or key == 0x36) {
                    shift_pressed = false;
                }
            }
        }
        tick_count += 1;
        asm volatile ("hlt");
    }
}
