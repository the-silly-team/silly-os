// ATA PIO Disk Driver for SillyOS
// Simple polled I/O for IDE disks

const std = @import("std");

// ATA ports (primary channel)
const ATA_DATA: u16 = 0x1F0;
const ATA_ERROR: u16 = 0x1F1;
const ATA_SECTOR_COUNT: u16 = 0x1F2;
const ATA_LBA_LOW: u16 = 0x1F3;
const ATA_LBA_MID: u16 = 0x1F4;
const ATA_LBA_HIGH: u16 = 0x1F5;
const ATA_DRIVE: u16 = 0x1F6;
const ATA_STATUS: u16 = 0x1F7;
const ATA_COMMAND: u16 = 0x1F7;

// ATA commands
const ATA_CMD_READ_PIO: u8 = 0x20;
const ATA_CMD_WRITE_PIO: u8 = 0x30;
const ATA_CMD_IDENTIFY: u8 = 0xEC;

// Status bits
const ATA_SR_BSY: u8 = 0x80; // Busy
const ATA_SR_DRDY: u8 = 0x40; // Drive ready
const ATA_SR_DRQ: u8 = 0x08; // Data request ready
const ATA_SR_ERR: u8 = 0x01; // Error

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

fn inw(port: u16) u16 {
    return asm volatile ("inw %[port], %[result]"
        : [result] "={ax}" (-> u16),
        : [port] "N{dx}" (port),
    );
}

fn outw(port: u16, value: u16) void {
    asm volatile ("outw %[value], %[port]"
        :
        : [value] "{ax}" (value),
          [port] "N{dx}" (port),
    );
}

fn waitBusy() void {
    while (inb(ATA_STATUS) & ATA_SR_BSY != 0) {}
}

fn waitReady() bool {
    var timeout: u32 = 100000;
    while (timeout > 0) : (timeout -= 1) {
        const status = inb(ATA_STATUS);
        if (status & ATA_SR_ERR != 0) return false;
        if (status & ATA_SR_DRQ != 0) return true;
    }
    return false;
}

pub fn readSectors(lba: u32, count: u8, buffer: [*]u8) bool {
    waitBusy();

    outb(ATA_DRIVE, 0xE0 | @as(u8, @truncate((lba >> 24) & 0x0F)));
    outb(ATA_SECTOR_COUNT, count);
    outb(ATA_LBA_LOW, @truncate(lba & 0xFF));
    outb(ATA_LBA_MID, @truncate((lba >> 8) & 0xFF));
    outb(ATA_LBA_HIGH, @truncate((lba >> 16) & 0xFF));
    outb(ATA_COMMAND, ATA_CMD_READ_PIO);

    var sector: u8 = 0;
    while (sector < count) : (sector += 1) {
        if (!waitReady()) return false;

        // Read 256 words (512 bytes) per sector
        var i: u16 = 0;
        while (i < 256) : (i += 1) {
            const word = inw(ATA_DATA);
            const offset = (@as(usize, sector) * 512) + (i * 2);
            buffer[offset] = @truncate(word & 0xFF);
            buffer[offset + 1] = @truncate((word >> 8) & 0xFF);
        }
    }

    return true;
}

pub fn writeSectors(lba: u32, count: u8, buffer: [*]const u8) bool {
    waitBusy();

    outb(ATA_DRIVE, 0xE0 | @as(u8, @truncate((lba >> 24) & 0x0F)));
    outb(ATA_SECTOR_COUNT, count);
    outb(ATA_LBA_LOW, @truncate(lba & 0xFF));
    outb(ATA_LBA_MID, @truncate((lba >> 8) & 0xFF));
    outb(ATA_LBA_HIGH, @truncate((lba >> 16) & 0xFF));
    outb(ATA_COMMAND, ATA_CMD_WRITE_PIO);

    var sector: u8 = 0;
    while (sector < count) : (sector += 1) {
        if (!waitReady()) return false;

        var i: u16 = 0;
        while (i < 256) : (i += 1) {
            const offset = (@as(usize, sector) * 512) + (i * 2);
            const word = @as(u16, buffer[offset]) | (@as(u16, buffer[offset + 1]) << 8);
            outw(ATA_DATA, word);
        }
    }

    // Flush cache
    outb(ATA_COMMAND, 0xE7);
    waitBusy();

    return true;
}

pub fn identify(buffer: *[512]u8) bool {
    waitBusy();

    outb(ATA_DRIVE, 0xE0);
    outb(ATA_SECTOR_COUNT, 0);
    outb(ATA_LBA_LOW, 0);
    outb(ATA_LBA_MID, 0);
    outb(ATA_LBA_HIGH, 0);
    outb(ATA_COMMAND, ATA_CMD_IDENTIFY);

    if (!waitReady()) return false;

    var i: u16 = 0;
    while (i < 256) : (i += 1) {
        const word = inw(ATA_DATA);
        buffer[i * 2] = @truncate(word & 0xFF);
        buffer[i * 2 + 1] = @truncate((word >> 8) & 0xFF);
    }

    return true;
}
