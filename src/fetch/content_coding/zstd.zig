//! The "zstd" content coding (RFC 8878, with RFC 9659's window limit for
//! HTTP), decoded as it arrives.
//!
//! Blocks are std.compress.zstd's decoder, a pull decoder that cannot stop
//! in the middle of a block when its input runs out. Zstandard says how
//! long every part of a frame is before it starts - the frame header's
//! size is in its first byte, a block's in its 3-byte header (RFC 8878
//! 3.1.1) - so the framing is read here and the decoder is handed one whole
//! part at a time: a frame's magic, header and first block, then each next
//! block, each with the checksum when it is the frame's last. It never
//! meets the end of its input, and nothing is rolled back.
//!
//! What the browsers do (both decode with libzstd):
//!
//! - Window_Size at most 8 MiB: RFC 9659 3 ("decoders MUST support a
//!   Window_Size of up to and including 8 MB"); Chromium's ZstdSourceStream
//!   ("Following RFC 9659, use a maximum 8MB memory buffer", window_log_max
//!   23) and Firefox (ZSTD_d_windowLogMax 23) refuse a larger window - for a
//!   single-segment frame too, whose window is its content size (libzstd's
//!   frameParameter_windowTooLarge). WPT big-window-zstd-body.tentative.
//! - Content_Checksum checked: libzstd verifies it by default (the std
//!   decoder does not - `Frame.hasher_opt` - so it is checked here).
//! - Frames follow each other, skippable frames are skipped (RFC 8878
//!   3.1.2), and bytes after a frame that start no frame are an error, as
//!   soon as they show they cannot (libzstd's prefix_unknown, checked on a
//!   partial magic) - unlike gzip, Chromium does not ignore them.
//! - A frame with a Dictionary_ID: no dictionary was offered, so it fails
//!   (libzstd's dictionary_wrong; dictionary transport is "dcz").
//! - A body that stops inside a frame is not an error (root.zig `Stage`;
//!   ZstdSourceStream only records it).
const std = @import("std");
const Allocator = std.mem.Allocator;
const zstd = std.compress.zstd;
const root = @import("root.zig");
const Error = root.Error;
const Sink = root.Sink;

/// RFC 9659's limit: 8 MiB, libzstd's window log 23.
pub const max_window_len: u64 = 8 * 1024 * 1024;
/// RFC 8878 3.1.1.1.2: the smallest Window_Size, 1 KB (libzstd raises a
/// smaller one to it).
const min_window_len: u64 = 1024;

const magic_zstd: u32 = 0xFD2FB528;
/// 0x184D2A50 to 0x184D2A5F.
const magic_skippable_min: u32 = 0x184D2A50;

pub const Decoder = struct {
    allocator: Allocator,
    /// Input not handed to the decoder yet.
    pending: std.ArrayListUnmanaged(u8) = .empty,
    phase: union(enum) {
        /// A frame's magic is next (or the body's end).
        magic,
        /// A skippable frame's user data: this many bytes still to skip.
        skipping: u64,
        /// Inside a Zstandard frame.
        frame: Frame,
    } = .magic,
    /// The decoder's buffer: the window, then room for a block. Kept
    /// across frames that fit in it.
    buffer: []u8 = &.{},
    input: std.Io.Reader = .fixed(&.{}),
    decompress: zstd.Decompress = undefined,

    const Frame = struct {
        /// Bytes of magic and Frame_Header that go to the decoder with the
        /// frame's first block; 0 after it.
        header_len: usize,
        /// The frame's Block_Maximum_Size (RFC 8878 3.1.1.2.4).
        block_max: usize,
        checksum: bool,
        hasher: std.hash.XxHash64,
    };

    pub fn create(allocator: Allocator) Error!*Decoder {
        const self = try allocator.create(Decoder);
        self.* = .{ .allocator = allocator };
        return self;
    }

    pub fn destroy(self: *Decoder) void {
        self.pending.deinit(self.allocator);
        self.allocator.free(self.buffer);
        self.allocator.destroy(self);
    }

    pub fn push(self: *Decoder, bytes: []const u8, sink: Sink) Error!void {
        try self.pending.appendSlice(self.allocator, bytes);
        var used: usize = 0;
        defer {
            const rest = self.pending.items[used..];
            std.mem.copyForwards(u8, self.pending.items[0..rest.len], rest);
            self.pending.items.len = rest.len;
        }
        while (true) {
            const available = self.pending.items[used..];
            switch (self.phase) {
                .magic => {
                    const n = try self.frameStart(available) orelse return;
                    used += n;
                },
                .skipping => |*left| {
                    const n: usize = @intCast(@min(left.*, available.len));
                    used += n;
                    left.* -= n;
                    if (left.* != 0) return;
                    self.phase = .magic;
                },
                .frame => |*frame| {
                    const n = try self.block(frame, available, sink) orelse return;
                    used += n;
                },
            }
        }
    }

    /// The start of a frame at `bytes`: the bytes it takes now (a
    /// skippable frame's magic and size; none for a Zstandard frame, whose
    /// header goes to the decoder with its first block), or null when more
    /// input is needed.
    fn frameStart(self: *Decoder, bytes: []const u8) Error!?usize {
        if (bytes.len < 4) {
            // libzstd refuses a partial magic that cannot start a frame
            // (ZSTD_getFrameHeader_advanced: "control these bytes at least
            // correspond to a supported magic number in order to error out
            // early").
            if (!couldStartFrame(bytes)) return error.InvalidData;
            return null;
        }
        const magic = std.mem.readInt(u32, bytes[0..4], .little);
        if (magic & 0xFFFFFFF0 == magic_skippable_min) {
            if (bytes.len < 8) return null;
            self.phase = .{ .skipping = std.mem.readInt(u32, bytes[4..8], .little) };
            return 8;
        }
        if (magic != magic_zstd) return error.InvalidData;
        // RFC 8878 3.1.1.1.1: the Frame_Header_Descriptor says how long the
        // header is.
        if (bytes.len < 5) return null;
        const descriptor = bytes[4];
        const content_size_flag: u2 = @intCast(descriptor >> 6);
        const single_segment = descriptor & 0x20 != 0;
        const reserved = descriptor & 0x08 != 0;
        const checksum = descriptor & 0x04 != 0;
        const dictionary_flag: u2 = @intCast(descriptor & 0x03);
        if (reserved) return error.InvalidData;
        // No dictionary is offered (see the file's comment).
        if (dictionary_flag != 0) return error.InvalidData;
        const window_descriptor_len: usize = if (single_segment) 0 else 1;
        const content_size_len: usize = switch (content_size_flag) {
            0 => if (single_segment) 1 else 0,
            1 => 2,
            2 => 4,
            3 => 8,
        };
        const header_len = 4 + 1 + window_descriptor_len + content_size_len;
        if (bytes.len < header_len) return null;
        // 3.1.1.1.2: Window_Size, or for a single segment the
        // Frame_Content_Size (3.1.1.1.4: a 2-byte field is offset by 256).
        const window: u64 = if (single_segment) blk: {
            const field = bytes[5..][0..content_size_len];
            const size = std.mem.readVarInt(u64, field, .little);
            break :blk if (content_size_len == 2) size + 256 else size;
        } else blk: {
            const window_descriptor = bytes[5];
            const exponent: u6 = @intCast(window_descriptor >> 3);
            const mantissa: u64 = window_descriptor & 7;
            const base = @as(u64, 1) << (10 + exponent);
            break :blk base + (base / 8) * mantissa;
        };
        if (window > max_window_len) return error.InvalidData;
        const window_len: u32 = @intCast(@max(window, min_window_len));
        // The decoder's buffer: the window and a whole block after it.
        const needed = window_len + zstd.block_size_max;
        if (self.buffer.len < needed) {
            self.allocator.free(self.buffer);
            self.buffer = &.{};
            self.buffer = try self.allocator.alloc(u8, needed);
        }
        self.decompress = .init(&self.input, self.buffer, .{ .window_len = window_len });
        self.phase = .{ .frame = .{
            .header_len = header_len,
            .block_max = @intCast(@min(window, zstd.block_size_max)),
            .checksum = checksum,
            .hasher = .init(0),
        } };
        return 0;
    }

    /// The frame's next block at `bytes` (after its magic and header, for
    /// the first): the bytes it took, or null when it has not all come.
    fn block(self: *Decoder, frame: *Frame, bytes: []const u8, sink: Sink) Error!?usize {
        const at = frame.header_len;
        if (bytes.len < at + 3) return null;
        // RFC 8878 3.1.1.2: Last_Block (bit 0), Block_Type (bits 1-2),
        // Block_Size (bits 3-23), little-endian.
        const header = std.mem.readInt(u24, bytes[at..][0..3], .little);
        const last = header & 1 != 0;
        const block_type: u2 = @intCast((header >> 1) & 3);
        const size: usize = header >> 3;
        // 3.1.1.2.2: Reserved is corrupt data; 3.1.1.2.3: Block_Size at
        // most Block_Maximum_Size.
        if (block_type == 3 or size > frame.block_max) return error.InvalidData;
        // An RLE block's content is its one byte.
        const content: usize = if (block_type == 1) 1 else size;
        const checksum_len: usize = if (last and frame.checksum) 4 else 0;
        const unit = at + 3 + content + checksum_len;
        if (bytes.len < unit) return null;

        self.input = .fixed(bytes[0..unit]);
        const reader = &self.decompress.reader;
        // One call decodes one block (with, the first time, the frame's
        // magic and header) into the buffer, after its window.
        var no_vectors: [0][]u8 = .{};
        _ = reader.vtable.readVec(reader, &no_vectors) catch return error.InvalidData;
        // The decoder read exactly the part: the framing read here and its
        // own agree.
        if (self.input.seek != unit) return error.InvalidData;
        const decoded = reader.buffer[reader.seek..reader.end];
        reader.seek = reader.end;
        if (frame.checksum) frame.hasher.update(decoded);
        if (decoded.len > 0) try sink.write(sink.context, decoded);
        frame.header_len = 0;
        if (last) {
            // 3.1.1: Content_Checksum, the low 4 bytes of XXH64 (seed 0) of
            // the frame's decoded data, little-endian.
            if (frame.checksum) {
                const expected = std.mem.readInt(u32, bytes[unit - 4 ..][0..4], .little);
                if (@as(u32, @truncate(frame.hasher.final())) != expected) return error.InvalidData;
            }
            self.phase = .magic;
        }
        return unit;
    }
};

/// Whether `bytes` (fewer than 4) could begin a Zstandard or skippable
/// frame's magic, little-endian.
fn couldStartFrame(bytes: []const u8) bool {
    const zstd_magic = std.mem.toBytes(std.mem.nativeToLittle(u32, magic_zstd));
    if (std.mem.startsWith(u8, &zstd_magic, bytes)) return true;
    const skippable = std.mem.toBytes(std.mem.nativeToLittle(u32, magic_skippable_min));
    // The skippable magic's low nibble is free.
    for (bytes, 0..) |byte, i| {
        const want = skippable[i];
        if (i == 0) {
            if (byte & 0xF0 != want) return false;
        } else if (byte != want) return false;
    }
    return true;
}
