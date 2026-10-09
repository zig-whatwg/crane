//! Frame-level validation for the WPT runner's WebM test backend: a frame
//! this host answers for is a real, parseable frame of a codec it knows. It
//! reads each codec's own headers - never pixels or samples, since the runner
//! has no output that could consume them:
//! - VP8: the frame tag, and on a key frame the start code 9d 01 2a and the
//!   dimensions (RFC 6386 9.1 "Uncompressed Data Chunk");
//! - VP9: the uncompressed header - frame marker, profile, show_existing_frame,
//!   frame type, and on a key or intra-only frame the sync code 49 83 42, the
//!   color config and the frame size (VP9 Bitstream Specification v0.7, 6.2
//!   "Uncompressed header syntax"); superframes (Annex B) are split first;
//! - Opus: the identification header "OpusHead" (RFC 7845 5.1) and each
//!   packet's TOC byte and frame packing (RFC 6716 3.1-3.4);
//! - Vorbis: the three header packets of the codec private (identification,
//!   comment, setup; Vorbis I specification 4.2), and the audio packet type bit.
const std = @import("std");

pub const Error = error{
    /// Not a valid frame or header of its codec.
    Invalid,
    /// Valid, but a variant this host does not answer for (an Opus channel
    /// mapping family other than 0 and 1).
    Unsupported,
};

pub const FrameSize = struct { width: u32, height: u32 };

pub const VideoFrame = struct {
    /// A key frame: decodable on its own.
    keyframe: bool,
    /// The frame size, when the frame header carries one (key frames, and VP9
    /// intra-only frames).
    size: ?FrameSize = null,
};

// ----------------------------------------------------------------------------
// VP8
// ----------------------------------------------------------------------------

/// RFC 6386 9.1: a 3-byte little-endian frame tag - key_frame (0 means key
/// frame), version (3 bits), show_frame, first_part_size (19 bits) - then, on
/// a key frame, the start code 9d 01 2a and two 16-bit fields of 14 bits of
/// size and 2 of scale.
pub fn vp8(frame: []const u8) Error!VideoFrame {
    if (frame.len < 3) return error.Invalid;
    const tag = @as(u32, frame[0]) | (@as(u32, frame[1]) << 8) | (@as(u32, frame[2]) << 16);
    const keyframe = tag & 1 == 0;
    const version = (tag >> 1) & 0b111;
    const first_part_size = (tag >> 5) & 0x7FFFF;
    // Versions 0-3 are defined; "decoding behavior ... for versions > 3 is
    // undefined" - libvpx rejects them (vp8_dx: "Invalid frame version").
    if (version > 3) return error.Invalid;
    if (!keyframe) {
        if (first_part_size > frame.len - 3) return error.Invalid;
        return .{ .keyframe = false };
    }
    if (frame.len < 10) return error.Invalid;
    if (!std.mem.eql(u8, frame[3..6], &.{ 0x9d, 0x01, 0x2a })) return error.Invalid;
    const width = std.mem.readInt(u16, frame[6..8], .little) & 0x3FFF;
    const height = std.mem.readInt(u16, frame[8..10], .little) & 0x3FFF;
    if (width == 0 or height == 0) return error.Invalid;
    if (first_part_size > frame.len - 10) return error.Invalid;
    return .{ .keyframe = true, .size = .{ .width = width, .height = height } };
}

// ----------------------------------------------------------------------------
// VP9
// ----------------------------------------------------------------------------

/// The frames of one VP9 block: a superframe (Annex B) holds several, marked
/// by an index at its end whose first and last bytes are the same marker
/// (0b110 | bytes per size - 1 | frames - 1).
pub fn vp9Frames(block: []const u8, out: *[8][]const u8) Error![]const []const u8 {
    if (block.len == 0) return error.Invalid;
    const marker = block[block.len - 1];
    if (marker & 0xE0 == 0xC0) {
        const frames: usize = (marker & 0x7) + 1;
        const magnitude: usize = ((marker >> 3) & 0x3) + 1;
        const index_size = 2 + magnitude * frames;
        if (block.len >= index_size and block[block.len - index_size] == marker) {
            var cursor: usize = 0;
            var index = block.len - index_size + 1;
            for (0..frames) |frame| {
                var size: usize = 0;
                for (0..magnitude) |byte| size |= @as(usize, block[index + byte]) << @intCast(8 * byte);
                index += magnitude;
                if (size == 0 or size > block.len - index_size - cursor) return error.Invalid;
                out[frame] = block[cursor..][0..size];
                cursor += size;
            }
            return out[0..frames];
        }
    }
    out[0] = block;
    return out[0..1];
}

/// The first frame of a VP9 block, by its uncompressed header (6.2).
pub fn vp9(block: []const u8) Error!VideoFrame {
    var frames: [8][]const u8 = undefined;
    const split = try vp9Frames(block, &frames);
    return vp9Frame(split[0]);
}

const color_space_rgb = 7;

fn vp9Frame(frame: []const u8) Error!VideoFrame {
    var bits = BitReader{ .bytes = frame };
    if (try bits.read(2) != 2) return error.Invalid; // frame_marker
    const profile_low = try bits.read(1);
    const profile_high = try bits.read(1);
    const profile = (profile_high << 1) + profile_low;
    if (profile == 3 and try bits.read(1) != 0) return error.Invalid; // reserved_zero
    if (try bits.read(1) == 1) { // show_existing_frame
        _ = try bits.read(3); // frame_to_show_map_idx
        return .{ .keyframe = false };
    }
    const frame_type = try bits.read(1); // 0: KEY_FRAME
    const show_frame = try bits.read(1);
    const error_resilient = try bits.read(1);
    if (frame_type == 0) {
        try syncCode(&bits);
        try colorConfig(&bits, profile);
        return .{ .keyframe = true, .size = try frameSize(&bits) };
    }
    const intra_only = if (show_frame == 1) 0 else try bits.read(1);
    if (error_resilient == 0) _ = try bits.read(2); // reset_frame_context
    if (intra_only == 0) return .{ .keyframe = false };
    try syncCode(&bits);
    // Profile 0 intra-only frames carry no color config (8-bit 4:2:0).
    if (profile > 0) try colorConfig(&bits, profile);
    _ = try bits.read(8); // refresh_frame_flags
    return .{ .keyframe = false, .size = try frameSize(&bits) };
}

fn syncCode(bits: *BitReader) Error!void {
    if (try bits.read(8) != 0x49 or try bits.read(8) != 0x83 or try bits.read(8) != 0x42) return error.Invalid;
}

fn colorConfig(bits: *BitReader, profile: u32) Error!void {
    if (profile >= 2) _ = try bits.read(1); // ten_or_twelve_bit
    const color_space = try bits.read(3);
    if (color_space != color_space_rgb) {
        _ = try bits.read(1); // color_range
        if (profile == 1 or profile == 3) {
            const subsampling_x = try bits.read(1);
            const subsampling_y = try bits.read(1);
            // Profiles 1 and 3 are the non-4:2:0 profiles.
            if (subsampling_x == 1 and subsampling_y == 1) return error.Invalid;
            if (try bits.read(1) != 0) return error.Invalid; // reserved_zero
        }
    } else {
        // "It is a requirement of bitstream conformance that profile is 1 or
        // 3 when color_space is CS_RGB" (4:4:4 only).
        if (profile != 1 and profile != 3) return error.Invalid;
        if (try bits.read(1) != 0) return error.Invalid; // reserved_zero
    }
}

fn frameSize(bits: *BitReader) Error!FrameSize {
    const width = try bits.read(16) + 1;
    const height = try bits.read(16) + 1;
    return .{ .width = width, .height = height };
}

/// Most-significant bit first, as VP9's f(n) reads.
const BitReader = struct {
    bytes: []const u8,
    position: usize = 0,
    fn read(self: *BitReader, count: u5) Error!u32 {
        var value: u32 = 0;
        for (0..count) |_| {
            const byte = self.position / 8;
            if (byte >= self.bytes.len) return error.Invalid;
            const bit = (self.bytes[byte] >> @intCast(7 - self.position % 8)) & 1;
            value = (value << 1) | bit;
            self.position += 1;
        }
        return value;
    }
};

// ----------------------------------------------------------------------------
// Opus
// ----------------------------------------------------------------------------

pub const OpusHead = struct { channels: u8, mapping_family: u8 };

/// RFC 7845 5.1: "OpusHead", version (major 0), channel count (> 0),
/// pre-skip, input sample rate, output gain, channel mapping family, and for
/// a family other than 0 the channel mapping table.
pub fn opusHead(header: []const u8) Error!OpusHead {
    if (header.len < 19 or !std.mem.eql(u8, header[0..8], "OpusHead")) return error.Invalid;
    // "A decoder SHOULD reject any stream whose major version is not 0."
    if (header[8] >> 4 != 0) return error.Invalid;
    const channels = header[9];
    if (channels == 0) return error.Invalid;
    const family = header[18];
    switch (family) {
        // Mono or stereo, no mapping table.
        0 => if (channels > 2) return error.Invalid,
        // Vorbis channel order, 1 to 8 channels.
        1 => {
            if (channels > 8) return error.Invalid;
            if (header.len < 21 + @as(usize, channels)) return error.Invalid;
            const streams = header[19];
            const coupled = header[20];
            if (streams == 0 or coupled > streams or @as(u16, streams) + coupled > 255) return error.Invalid;
            for (header[21..][0..channels]) |entry| {
                if (entry != 255 and entry >= @as(u16, streams) + coupled) return error.Invalid;
            }
        },
        else => return error.Unsupported,
    }
    return .{ .channels = channels, .mapping_family = family };
}

const max_opus_frame = 1275;

/// RFC 6716 3.1-3.4: the TOC byte and the frame packing its code names, with
/// the requirements R1-R7 of 3.4.
pub fn opusPacket(packet: []const u8) Error!void {
    // R1: at least one byte.
    if (packet.len < 1) return error.Invalid;
    const toc = packet[0];
    const config = toc >> 3;
    // Frame duration in 0.1 ms units (Table 2).
    const duration: u32 = switch (config) {
        0...11 => ([_]u32{ 100, 200, 400, 600 })[config % 4],
        12...15 => ([_]u32{ 100, 200 })[config % 2],
        else => ([_]u32{ 25, 50, 100, 200 })[config % 4],
    };
    const rest = packet[1..];
    switch (toc & 0b11) {
        // One frame (R2).
        0 => if (rest.len > max_opus_frame) return error.Invalid,
        // Two frames of equal size (R3).
        1 => if (rest.len % 2 != 0 or rest.len / 2 > max_opus_frame) return error.Invalid,
        // Two frames, the first's length coded (R4).
        2 => {
            const first = try frameLength(rest);
            const after = rest[first.coded..];
            if (first.length > after.len or first.length > max_opus_frame or after.len - first.length > max_opus_frame) return error.Invalid;
        },
        // Any number of frames (R5-R7).
        3 => {
            if (rest.len < 1) return error.Invalid;
            const header = rest[0];
            const vbr = header & 0x80 != 0;
            const padded = header & 0x40 != 0;
            const count: usize = header & 0x3F;
            // R5: at least one frame, at most 120 ms of audio.
            if (count == 0 or count * duration > 1200) return error.Invalid;
            var cursor: usize = 1;
            var padding: usize = 0;
            if (padded) {
                while (true) {
                    if (cursor >= rest.len) return error.Invalid;
                    const byte = rest[cursor];
                    cursor += 1;
                    padding += if (byte == 255) 254 else byte;
                    if (byte != 255) break;
                }
            }
            if (cursor + padding > rest.len) return error.Invalid;
            var data = rest.len - cursor - padding;
            if (vbr) {
                // R6: each of the first M-1 lengths fits, and so does the last.
                for (0..count - 1) |_| {
                    const frame = try frameLength(rest[cursor .. rest.len - padding]);
                    cursor += frame.coded;
                    data -= frame.coded;
                    if (frame.length > data or frame.length > max_opus_frame) return error.Invalid;
                    data -= frame.length;
                }
                if (data > max_opus_frame) return error.Invalid;
            } else {
                // R7: the frames share the data equally.
                if (data % count != 0 or data / count > max_opus_frame) return error.Invalid;
            }
        },
        else => unreachable,
    }
}

const FrameLength = struct { length: usize, coded: usize };

/// RFC 6716 3.2.1: a frame length in one byte (0-251) or two (252-1275).
fn frameLength(bytes: []const u8) Error!FrameLength {
    if (bytes.len < 1) return error.Invalid;
    if (bytes[0] < 252) return .{ .length = bytes[0], .coded = 1 };
    if (bytes.len < 2) return error.Invalid;
    return .{ .length = @as(usize, bytes[1]) * 4 + bytes[0], .coded = 2 };
}

// ----------------------------------------------------------------------------
// Vorbis
// ----------------------------------------------------------------------------

pub const VorbisInfo = struct { channels: u8, sample_rate: u32 };

/// The codec private of a WebM Vorbis track: the three header packets,
/// Xiph-laced - a byte holding the packet count minus one (2), the lengths of
/// the first two, then the packets (Matroska codec mappings, A_VORBIS).
pub fn vorbisHeaders(private: []const u8) Error!VorbisInfo {
    if (private.len < 1 or private[0] != 2) return error.Invalid;
    var cursor: usize = 1;
    var sizes: [2]usize = undefined;
    for (&sizes) |*size| {
        size.* = 0;
        while (true) {
            if (cursor >= private.len) return error.Invalid;
            const byte = private[cursor];
            cursor += 1;
            size.* += byte;
            if (byte != 255) break;
        }
    }
    if (sizes[0] + sizes[1] > private.len - cursor) return error.Invalid;
    const identification = private[cursor..][0..sizes[0]];
    const comment = private[cursor + sizes[0] ..][0..sizes[1]];
    const setup = private[cursor + sizes[0] + sizes[1] ..];
    const info = try vorbisIdentification(identification);
    try vorbisComment(comment);
    if (setup.len < 8 or setup[0] != 5 or !std.mem.eql(u8, setup[1..7], "vorbis")) return error.Invalid;
    return info;
}

/// Vorbis I 4.2.2: type 1, "vorbis", version 0, channels and rate above 0,
/// the three bitrates, the two block sizes (powers of two from 64 to 8192,
/// the first no larger than the second) and the framing flag.
fn vorbisIdentification(packet: []const u8) Error!VorbisInfo {
    if (packet.len < 30 or packet[0] != 1 or !std.mem.eql(u8, packet[1..7], "vorbis")) return error.Invalid;
    if (std.mem.readInt(u32, packet[7..11], .little) != 0) return error.Invalid;
    const channels = packet[11];
    const rate = std.mem.readInt(u32, packet[12..16], .little);
    if (channels == 0 or rate == 0) return error.Invalid;
    const small = packet[28] & 0x0F;
    const large = packet[28] >> 4;
    if (small < 6 or small > 13 or large < 6 or large > 13 or small > large) return error.Invalid;
    if (packet[29] & 1 != 1) return error.Invalid;
    return .{ .channels = channels, .sample_rate = rate };
}

/// Vorbis I 5.2.1: type 3, "vorbis", the vendor string, the user comments,
/// each a 32-bit length and its bytes, then the framing bit.
fn vorbisComment(packet: []const u8) Error!void {
    if (packet.len < 7 or packet[0] != 3 or !std.mem.eql(u8, packet[1..7], "vorbis")) return error.Invalid;
    var cursor: usize = 7;
    const vendor = try readLength(packet, &cursor);
    cursor += vendor;
    const count = try readLength(packet, &cursor);
    for (0..count) |_| {
        const length = try readLength(packet, &cursor);
        cursor += length;
    }
    if (cursor >= packet.len or packet[cursor] & 1 != 1) return error.Invalid;
}

fn readLength(packet: []const u8, cursor: *usize) Error!usize {
    if (cursor.* > packet.len or packet.len - cursor.* < 4) return error.Invalid;
    const length = std.mem.readInt(u32, packet[cursor.*..][0..4], .little);
    cursor.* += 4;
    if (length > packet.len - cursor.*) return error.Invalid;
    return length;
}

/// Vorbis I 4.3.1: an audio packet starts with a 0 packet-type bit (bits are
/// packed least significant first); header packets have odd types.
pub fn vorbisAudioPacket(packet: []const u8) Error!void {
    if (packet.len < 1 or packet[0] & 1 != 0) return error.Invalid;
}

// ============================================================================
// Tests (first frames of WPT's own media files)
// ============================================================================

const testing = std.testing;
const demuxer_mod = @import("webm_demuxer.zig");

const Firsts = struct {
    demuxer: demuxer_mod.Demuxer,
    file: []u8,
    /// Copies of every frame of the given track, in order.
    frames: std.ArrayList([]u8) = .empty,

    fn deinit(self: *Firsts) void {
        for (self.frames.items) |frame| testing.allocator.free(frame);
        self.frames.deinit(testing.allocator);
        self.demuxer.deinit();
        testing.allocator.free(self.file);
    }
};

/// Every block's first frame for `codec`'s track in a WPT media file.
fn framesOf(name: []const u8, codec: demuxer_mod.Codec) !Firsts {
    var result: Firsts = .{ .demuxer = demuxer_mod.Demuxer.init(testing.allocator), .file = try demuxer_mod.readFixture(testing.allocator, name) };
    errdefer result.deinit();
    try result.demuxer.push(result.file);
    var number: ?u64 = null;
    while (try result.demuxer.next()) |event| switch (event) {
        .tracks => for (result.demuxer.tracks.items) |entry| {
            if (entry.codec == codec) number = entry.number;
        },
        .block => |block| if (block.track == number) {
            for (block.frames) |frame| try result.frames.append(testing.allocator, try testing.allocator.dupe(u8, frame));
        },
    };
    return result;
}

test "VP8: a key frame's start code and size, then inter frames" {
    var firsts = try framesOf("test-v-128k-320x240-24fps-8kfr.webm", .vp8);
    defer firsts.deinit();
    const first = try vp8(firsts.frames.items[0]);
    try testing.expect(first.keyframe);
    try testing.expectEqual(FrameSize{ .width = 320, .height = 240 }, first.size.?);
    var inter: usize = 0;
    for (firsts.frames.items[1..]) |frame| {
        const parsed = try vp8(frame);
        if (!parsed.keyframe) inter += 1;
    }
    try testing.expect(inter > 0);

    // A broken start code, a 0 width, a frame shorter than its first
    // partition, a version above 3: not VP8 frames.
    const good = firsts.frames.items[0];
    const bad = try testing.allocator.dupe(u8, good);
    defer testing.allocator.free(bad);
    bad[4] = 0x02;
    try testing.expectError(error.Invalid, vp8(bad));
    @memcpy(bad, good);
    bad[6] = 0;
    bad[7] &= 0xC0;
    try testing.expectError(error.Invalid, vp8(bad));
    try testing.expectError(error.Invalid, vp8(good[0..20]));
    @memcpy(bad, good);
    bad[0] |= 0b1110; // version 7
    try testing.expectError(error.Invalid, vp8(bad));
    try testing.expectError(error.Invalid, vp8(good[0..2]));
}

test "VP8: the key frame where 400x300-red-resize-200x150-green.webm changes size" {
    var firsts = try framesOf("400x300-red-resize-200x150-green.webm", .vp8);
    defer firsts.deinit();
    var sizes: std.ArrayList(FrameSize) = .empty;
    defer sizes.deinit(testing.allocator);
    for (firsts.frames.items) |frame| {
        const parsed = try vp8(frame);
        if (parsed.size) |size| try sizes.append(testing.allocator, size);
    }
    try testing.expectEqual(FrameSize{ .width = 400, .height = 300 }, sizes.items[0]);
    try testing.expectEqual(FrameSize{ .width = 200, .height = 150 }, sizes.items[sizes.items.len - 1]);
}

test "VP9: the uncompressed header of every frame, the key frame's size" {
    for ([_][]const u8{ "movie_5.webm", "counting.webm", "test-1s.webm", "video.webm", "A4.webm", "green-at-15.webm" }) |name| {
        var firsts = try framesOf(name, .vp9);
        defer firsts.deinit();
        const first = try vp9(firsts.frames.items[0]);
        try testing.expect(first.keyframe);
        try testing.expect(first.size.?.width >= 320);
        for (firsts.frames.items) |frame| _ = try vp9(frame);
    }
    var firsts = try framesOf("movie_5.webm", .vp9);
    defer firsts.deinit();
    try testing.expectEqual(FrameSize{ .width = 320, .height = 240 }, (try vp9(firsts.frames.items[0])).size.?);

    const good = firsts.frames.items[0];
    const bad = try testing.allocator.dupe(u8, good);
    defer testing.allocator.free(bad);
    // The frame marker (top two bits) must be 0b10.
    bad[0] = (bad[0] & 0x3F) | 0xC0;
    try testing.expectError(error.Invalid, vp9(bad));
    // A key frame's sync code must be 49 83 42; in profile 0 it is the second byte on.
    @memcpy(bad, good);
    bad[1] ^= 0x10;
    try testing.expectError(error.Invalid, vp9(bad));
    try testing.expectError(error.Invalid, vp9(good[0..3]));
}

test "VP9: a superframe is split by its index; a bad index is not a superframe" {
    // Two frames: a hidden inter frame (2 bytes) and a shown frame (1 byte),
    // with a one-byte-per-size index for 2 frames: marker 0b11000001.
    const block = [_]u8{ 0x86, 0x00, 0x88, 0xC1, 0x02, 0x01, 0xC1 };
    var frames: [8][]const u8 = undefined;
    const split = try vp9Frames(&block, &frames);
    try testing.expectEqual(@as(usize, 2), split.len);
    try testing.expectEqualSlices(u8, &.{ 0x86, 0x00 }, split[0]);
    try testing.expectEqualSlices(u8, &.{0x88}, split[1]);
    // Sizes that overrun the data.
    const overrun = [_]u8{ 0x86, 0x00, 0x88, 0xC1, 0x09, 0x01, 0xC1 };
    try testing.expectError(error.Invalid, vp9Frames(&overrun, &frames));
}

test "Opus: OpusHead and every packet's TOC" {
    var firsts = try framesOf("movie_5.webm", .opus);
    defer firsts.deinit();
    const head = try opusHead(firsts.demuxer.tracks.items[1].codec_private);
    try testing.expectEqual(@as(u8, 1), head.channels);
    try testing.expectEqual(@as(u8, 0), head.mapping_family);
    for (firsts.frames.items) |packet| try opusPacket(packet);

    try testing.expectError(error.Invalid, opusHead("OpusTags\x01\x01\x00\x00\x80\xbb\x00\x00\x00\x00\x00"));
    // Family 0 with three channels; a major version of 1.
    try testing.expectError(error.Invalid, opusHead("OpusHead\x01\x03\x38\x01\x80\xbb\x00\x00\x00\x00\x00"));
    try testing.expectError(error.Invalid, opusHead("OpusHead\x10\x01\x38\x01\x80\xbb\x00\x00\x00\x00\x00"));
    try testing.expectError(error.Unsupported, opusHead("OpusHead\x01\x04\x38\x01\x80\xbb\x00\x00\x00\x00\x02\x01\x01\x00\x01\x02\x03"));
    try testing.expectEqual(OpusHead{ .channels = 2, .mapping_family = 1 }, try opusHead("OpusHead\x01\x02\x38\x01\x80\xbb\x00\x00\x00\x00\x01\x01\x01\x00\x01"));

    try testing.expectError(error.Invalid, opusPacket(""));
    // Code 1 (two equal frames) with an odd payload.
    try testing.expectError(error.Invalid, opusPacket(&.{ 0x01, 1, 2, 3 }));
    // Code 2 whose first frame's length runs past the packet.
    try testing.expectError(error.Invalid, opusPacket(&.{ 0x02, 10, 1, 2 }));
    // Code 3 with no frames; with 49 x 2.5 ms; CBR data not divisible by M.
    try testing.expectError(error.Invalid, opusPacket(&.{ 0x03, 0x00 }));
    try testing.expectError(error.Invalid, opusPacket(&.{ 0x83, 49 }));
    try testing.expectError(error.Invalid, opusPacket(&.{ 0x03, 0x02, 1, 2, 3 }));
    // Valid: a DTX frame (TOC only); code 3 VBR with padding.
    try opusPacket(&.{0xF8});
    try opusPacket(&.{ 0x03, 0xC2, 0x01, 0x02, 0xAA, 0xBB, 0xCC, 0x00 });
}

test "Vorbis: the three header packets and the audio packet bit" {
    var firsts = try framesOf("test-a-128k-44100Hz-1ch.webm", .vorbis);
    defer firsts.deinit();
    const private = firsts.demuxer.tracks.items[0].codec_private;
    const info = try vorbisHeaders(private);
    try testing.expectEqual(VorbisInfo{ .channels = 1, .sample_rate = 44100 }, info);
    for (firsts.frames.items) |packet| try vorbisAudioPacket(packet);

    const bad = try testing.allocator.dupe(u8, private);
    defer testing.allocator.free(bad);
    // The identification packet's magic, after the count and two lengths.
    const at = std.mem.indexOf(u8, private, "\x01vorbis").?;
    bad[at + 1] = 'V';
    try testing.expectError(error.Invalid, vorbisHeaders(bad));
    @memcpy(bad, private);
    bad[0] = 1; // two packets, not three
    try testing.expectError(error.Invalid, vorbisHeaders(bad));
    try testing.expectError(error.Invalid, vorbisHeaders(private[0 .. at + 10]));
    try testing.expectError(error.Invalid, vorbisAudioPacket(&.{0x01}));
    try testing.expectError(error.Invalid, vorbisAudioPacket(""));
}
