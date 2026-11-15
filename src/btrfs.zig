// BTRFS - B-tree File System
// Simplified implementation for SillyOS
// Reference: https://btrfs.readthedocs.io/en/latest/

const std = @import("std");

// BTRFS constants
const BTRFS_SUPER_INFO_OFFSET: usize = 65536; // 64KB
const BTRFS_SUPER_INFO_SIZE: usize = 4096;
pub const BTRFS_MAGIC: u64 = 0x4D5F53665248425F; // "_BHRfS_M" (little-endian)
const BTRFS_FIRST_FREE_OBJECTID: u64 = 256;
const BTRFS_ROOT_TREE_OBJECTID: u64 = 2; // root tree (contains other trees)
const BTRFS_EXTENT_TREE_OBJECTID: u64 = 3; // extent tree
const BTRFS_CHUNK_TREE_OBJECTID: u64 = 4; // chunk tree (maps logical to physical)
const BTRFS_DEV_TREE_OBJECTID: u64 = 5; // device tree
const BTRFS_FS_TREE_OBJECTID: u64 = 6; // filesystem tree (files and dirs)
const BTRFS_ROOT_TREE_DIR_OBJECTID: u64 = 7; // root directory

// Node types
const BTRFS_NODE_ITEM_KEY: u8 = 0x84; // internal node
const BTRFS_LEAF_ITEM_KEY: u8 = 0x84; // leaf node (same, distinguished by header)

// Item types
const BTRFS_INODE_ITEM_KEY: u32 = 0x01; // inode
const BTRFS_DIR_ITEM_KEY: u32 = 0x02; // directory entry
const BTRFS_DIR_INDEX_KEY: u32 = 0x03; // directory index
const BTRFS_EXTENT_DATA_KEY: u32 = 0x04; // file extent (data)
const BTRFS_ROOT_ITEM_KEY: u32 = 0x05; // root item (subvolume)
const BTRFS_EXTENT_ITEM_KEY: u32 = 0x06; // extent item
const BTRFS_CHUNK_ITEM_KEY: u32 = 0x07; // chunk item

// BTRFS Superblock (simplified)
pub const Superblock = struct {
    bytenr: u64, // physical address of this superblock
    fsid: [16]u8, // filesystem UUID
    bytenr_copy: u64, // redundant copy
    flags: u64,
    magic: u64, // BTRFS_MAGIC
    generation: u64, // current generation
    root: u64, // root tree root
    chunk_root: u64, // chunk tree root
    log_root: u64, // log tree root
    log_root_transid: u64,
    total_bytes: u64,
    bytes_used: u64,
    root_dir_objectid: u64, // objectid of root directory
    num_devices: u64,
    sectorsize: u32, // usually 4096
    nodesize: u32, // usually 16384
    leafsize: u32, // usually 16384
    stripesize: u32,
    sys_chunk_array_size: u32,
    chunk_root_generation: u64,
    compat_flags: u64,
    compat_ro_flags: u64,
    incompat_flags: u64,
    csum_type: u16, // 0 = CRC32C
    root_level: u8,
    chunk_root_level: u8,
    log_root_level: u8,
    cache_generation: u64,
    uuid_tree_generation: u64,
    dev_item: DeviceItem,
    label: [256]u8, // filesystem label
    cache_generation_copy: u64,
    uuid_tree_generation_copy: u64,
    super_roots: [4]u64, // backup roots
    // ... (simplified, actual superblock is 4096 bytes)

    pub fn isValid(self: *const Superblock) bool {
        return self.magic == BTRFS_MAGIC;
    }
};

pub const DeviceItem = struct {
    devid: u64,
    total_bytes: u64,
    bytes_used: u64,
    io_align: u32,
    io_width: u32,
    sector_size: u32,
    type_: u32, // device type
    generation: u64,
    start_offset: u64,
    dev_group: u32,
    seek_speed: u8,
    bandwidth: u8,
    uuid: [16]u8,
    fsid: [16]u8,
};

// BTRFS Header (for nodes and leaves)
pub const Header = struct {
    checksum: [32]u8, // CRC32C
    fsid: [16]u8,
    bytenr: u64, // physical address of this node
    flags: u64,
    chunk_tree_uuid: [16]u8,
    generation: u64,
    owner: u64, // objectid of tree owner
    nritems: u32, // number of items
    level: u8, // tree level (0 = leaf)
};

// Key (used in B-trees)
pub const Key = struct {
    objectid: u64,
    type_: u8,
    offset: u64,

    pub fn compare(a: Key, b: Key) i8 {
        if (a.objectid < b.objectid) return -1;
        if (a.objectid > b.objectid) return 1;
        if (a.type_ < b.type_) return -1;
        if (a.type_ > b.type_) return 1;
        if (a.offset < b.offset) return -1;
        if (a.offset > b.offset) return 1;
        return 0;
    }
};

// Item (leaf node entry)
pub const Item = struct {
    key: Key,
    offset: u32, // offset within leaf data
    size: u32, // size of item data
};

// Inode (file metadata)
pub const InodeItem = struct {
    generation: u64,
    transid: u64,
    size: u64, // file size
    nbytes: u64, // total bytes
    block_group: u64,
    mode: u32, // file mode (permissions)
    nlink: u32, // number of hard links
    uid: u32, // user id
    gid: u32, // group id
    rdev: u64,
    flags: u64,
    sequence: u64,
    reserved: [4]u64,
    atime: Timespec,
    ctime: Timespec,
    mtime: Timespec,
    otime: Timespec, // creation time

    pub const Timespec = struct {
        sec: i64,
        nsec: u32,
    };
};

// Directory entry
pub const DirItem = struct {
    location: Key, // key of the target inode
    transid: u64,
    data_len: u16, // length of name
    name_len: u16, // length of name
    type_: u8, // file type (1=regular, 2=dir, etc.)
    // name follows
};

// Extent (file data reference)
pub const ExtentData = struct {
    generation: u64,
    ram_bytes: u64,
    compression: u8,
    encryption: u8,
    other_encoding: u16,
    type_: u8, // 0=inline, 1=regular, 2=prealloc
    // followed by extent info
};

// Disk I/O interface
pub const DiskReader = struct {
    readFn: *const fn (lba: u64, count: u32, buffer: []u8) bool,
    writeFn: *const fn (lba: u64, count: u32, buffer: []const u8) bool,

    pub fn read(self: *const DiskReader, lba: u64, count: u32, buffer: []u8) bool {
        return self.readFn(lba, count, buffer);
    }

    pub fn write(self: *const DiskReader, lba: u64, count: u32, buffer: []const u8) bool {
        return self.writeFn(lba, count, buffer);
    }
};

// BTRFS filesystem handle
pub const BtrfsFs = struct {
    disk: DiskReader,
    superblock: Superblock,
    sectorsize: u32,
    nodesize: u32,

    pub fn init(disk: DiskReader) !BtrfsFs {
        var fs = BtrfsFs{
            .disk = disk,
            .superblock = undefined,
            .sectorsize = 512,
            .nodesize = 16384,
        };

        // Read superblock (at 64KB offset)
        var sb_buf: [BTRFS_SUPER_INFO_SIZE]u8 = undefined;
        const lba = BTRFS_SUPER_INFO_OFFSET / 512;
        if (!disk.read(lba, BTRFS_SUPER_INFO_SIZE / 512, &sb_buf)) {
            return error.DiskReadFailed;
        }

        // Parse superblock (simplified - just check magic)
        const sb = @as(*const Superblock, @ptrCast(&sb_buf));
        if (!sb.isValid()) {
            return error.InvalidSuperblock;
        }

        fs.superblock = sb.*;
        fs.sectorsize = sb.sectorsize;
        fs.nodesize = sb.nodesize;

        return fs;
    }

    pub fn deinit(self: *BtrfsFs) void {
        _ = self;
    }

    // Read a node from disk by physical address
    pub fn readNode(self: *const BtrfsFs, bytenr: u64, buffer: []u8) bool {
        const lba = bytenr / 512;
        const count = (self.nodesize + 511) / 512;
        return self.disk.read(lba, @intCast(count), buffer);
    }

    // Get the root tree root
    pub fn getRootTreeRoot(self: *const BtrfsFs) u64 {
        return self.superblock.root;
    }

    // Get the filesystem tree root
    pub fn getFsTreeRoot(self: *const BtrfsFs) u64 {
        // In a real implementation, we'd look up the FS tree root from the root tree
        // For simplicity, return a placeholder
        return self.superblock.root;
    }
};

// Helper: read a 64-bit value from a byte slice
pub fn readU64(data: []const u8, offset: usize) u64 {
    if (offset + 8 > data.len) return 0;
    return @as(u64, data[offset]) |
        (@as(u64, data[offset + 1]) << 8) |
        (@as(u64, data[offset + 2]) << 16) |
        (@as(u64, data[offset + 3]) << 24) |
        (@as(u64, data[offset + 4]) << 32) |
        (@as(u64, data[offset + 5]) << 40) |
        (@as(u64, data[offset + 6]) << 48) |
        (@as(u64, data[offset + 7]) << 56);
}

// Helper: read a 32-bit value from a byte slice
pub fn readU32(data: []const u8, offset: usize) u32 {
    if (offset + 4 > data.len) return 0;
    return @as(u32, data[offset]) |
        (@as(u32, data[offset + 1]) << 8) |
        (@as(u32, data[offset + 2]) << 16) |
        (@as(u32, data[offset + 3]) << 24);
}

// Helper: read a 16-bit value from a byte slice
pub fn readU16(data: []const u8, offset: usize) u16 {
    if (offset + 2 > data.len) return 0;
    return @as(u16, data[offset]) |
        (@as(u16, data[offset + 1]) << 8);
}
