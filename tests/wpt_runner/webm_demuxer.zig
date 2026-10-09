//! An incremental WebM (Matroska/EBML) demuxer for the WPT runner's WebM test
//! backend (webm_backend.zig). Pure Zig, no codec library.
//!
//! Bytes are pushed as they arrive; `next` hands out what they complete: the
//! track list once Tracks is read, then each block, with its frames split out
//! of their lacing. It reads only what a player needs to know which frame is
//! at a playback position:
//! - the EBML header: DocType "webm" (Matroska's "matroska" is not WebM), and
//!   the read versions a version-1 EBML / version-4 WebM reader may read;
//! - Segment Info: TimecodeScale and Duration;
//! - Tracks: TrackNumber, TrackType, CodecID, CodecPrivate, FlagEnabled,
//!   DefaultDuration, ContentEncodings (present or not), Video PixelWidth and
//!   PixelHeight, Audio SamplingFrequency and Channels;
//! - Cues: each CuePoint's CueTime;
//! - Clusters: Timecode, SimpleBlock and BlockGroup (Block, BlockDuration,
//!   ReferenceBlock).
//! Everything else is skipped by its size without being buffered.
//!
//! Live streams (MediaRecorder's output, 400x300-red-resize-200x150-green.webm)
//! give the Segment and each Cluster an unknown size. An unknown-sized element
//! ends where an element that cannot be its child starts (Matroska RFC 9559,
//! 6.2 "Unknown Data Size"; EBML RFC 8794, 6.2).
//!
//! Element IDs and semantics: RFC 9559 (Matroska) section 5.1 and the WebM
//! container guidelines (https://www.webmproject.org/docs/container/).
const std = @import("std");

pub const Error = error{
    /// Not an EBML stream, or EBML whose DocType is not "webm": not this
    /// demuxer's to read.
    NotWebM,
    /// WebM, but broken: an element that overruns its parent, a block before
    /// its cluster's timecode, lacing that does not add up, and so on.
    Corrupt,
    OutOfMemory,
};

/// Element IDs, with their length marker bits (RFC 8794 5: an Element ID is
/// read as a VINT whose marker is kept).
pub const id = struct {
    pub const ebml: u32 = 0x1A45DFA3;
    pub const ebml_version: u32 = 0x4286;
    pub const ebml_read_version: u32 = 0x42F7;
    pub const ebml_max_id_length: u32 = 0x42F2;
    pub const ebml_max_size_length: u32 = 0x42F3;
    pub const doc_type: u32 = 0x4282;
    pub const doc_type_version: u32 = 0x4287;
    pub const doc_type_read_version: u32 = 0x4285;
    pub const void_: u32 = 0xEC;
    pub const crc32: u32 = 0xBF;

    pub const segment: u32 = 0x18538067;
    pub const seek_head: u32 = 0x114D9B74;
    pub const info: u32 = 0x1549A966;
    pub const tracks: u32 = 0x1654AE6B;
    pub const cues: u32 = 0x1C53BB6B;
    pub const cluster: u32 = 0x1F43B675;
    pub const chapters: u32 = 0x1043A770;
    pub const tags: u32 = 0x1254C367;
    pub const attachments: u32 = 0x1941A469;

    pub const timecode_scale: u32 = 0x2AD7B1;
    pub const duration: u32 = 0x4489;

    pub const track_entry: u32 = 0xAE;
    pub const track_number: u32 = 0xD7;
    pub const track_type: u32 = 0x83;
    pub const flag_enabled: u32 = 0xB9;
    pub const codec_id: u32 = 0x86;
    pub const codec_private: u32 = 0x63A2;
    pub const default_duration: u32 = 0x23E383;
    pub const content_encodings: u32 = 0x6D80;
    pub const video: u32 = 0xE0;
    pub const pixel_width: u32 = 0xB0;
    pub const pixel_height: u32 = 0xBA;
    pub const audio: u32 = 0xE1;
    pub const sampling_frequency: u32 = 0xB5;
    pub const channels: u32 = 0x9F;

    pub const cue_point: u32 = 0xBB;
    pub const cue_time: u32 = 0xB3;

    pub const timecode: u32 = 0xE7;
    pub const silent_tracks: u32 = 0x5854;
    pub const position: u32 = 0xA7;
    pub const prev_size: u32 = 0xAB;
    pub const simple_block: u32 = 0xA3;
    pub const block_group: u32 = 0xA0;
    pub const block: u32 = 0xA1;
    pub const block_duration: u32 = 0x9B;
    pub const reference_block: u32 = 0xFB;
    pub const encrypted_block: u32 = 0xAF;
};

pub const TrackType = enum { video, audio, other };
pub const Codec = enum { vp8, vp9, vorbis, opus, other };

pub const Track = struct {
    number: u64,
    kind: TrackType,
    codec: Codec,
    enabled: bool = true,
    /// ContentEncodings present: the frames are compressed or encrypted.
    encoded: bool = false,
    /// Owned by the demuxer; empty when the track has none.
    codec_private: []const u8 = "",
    default_duration_ns: u64 = 0,
    pixel_width: u32 = 0,
    pixel_height: u32 = 0,
    sampling_frequency: f64 = 8000,
    channels: u64 = 1,
};

pub const Block = struct {
    track: u64,
    /// Cluster timecode plus the block's relative timecode, in nanoseconds.
    time_ns: i64,
    /// BlockDuration, or 0 when the block has none.
    duration_ns: u64,
    /// A SimpleBlock's keyframe flag; a BlockGroup's "no ReferenceBlock".
    keyframe: bool,
    /// The laced frames, borrowed from the demuxer until its next push or next.
    frames: []const []const u8,
};

pub const Event = union(enum) {
    /// Tracks has been read: `tracks` and `info` are complete.
    tracks,
    block: Block,
};

pub const Info = struct {
    timecode_scale: u64 = 1_000_000,
    /// Duration in seconds, when the Segment Info declared one.
    duration: ?f64 = null,
};

/// The largest element this demuxer buffers whole: a block, Tracks (with its
/// codec privates) or Cues. Larger is not a stream this host plays.
const max_buffered: u64 = 16 * 1024 * 1024;
/// The most frames one block's lacing may hold (the lace count is one byte).
const max_frames = 256;

const Master = struct {
    id: u32,
    /// Absolute end offset, or null for an unknown size.
    end: ?u64,
};

pub const Demuxer = struct {
    allocator: std.mem.Allocator,
    buffer: std.ArrayList(u8) = .empty,
    /// The index in `buffer` of the first unread byte, and its stream offset.
    start: usize = 0,
    offset: u64 = 0,
    /// Bytes of a skipped element still to come.
    skip: u64 = 0,
    stack: std.ArrayList(Master) = .empty,
    header_seen: bool = false,
    info: Info = .{},
    info_seen: bool = false,
    tracks: std.ArrayList(Track) = .empty,
    tracks_seen: bool = false,
    cue_times: std.ArrayList(u64) = .empty,
    cluster_timecode: ?u64 = null,
    frames: [max_frames][]const u8 = undefined,

    pub fn init(allocator: std.mem.Allocator) Demuxer {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Demuxer) void {
        self.buffer.deinit(self.allocator);
        self.stack.deinit(self.allocator);
        for (self.tracks.items) |track| if (track.codec_private.len != 0) self.allocator.free(track.codec_private);
        self.tracks.deinit(self.allocator);
        self.cue_times.deinit(self.allocator);
        self.* = undefined;
    }

    /// Duration in seconds, as declared by the Segment Info.
    pub fn declaredDuration(self: *const Demuxer) ?f64 {
        return self.info.duration;
    }

    pub fn trackNumbered(self: *const Demuxer, number: u64) ?*const Track {
        for (self.tracks.items) |*entry| if (entry.number == number) return entry;
        return null;
    }

    /// Hand the demuxer more of the stream. Slices from earlier events are
    /// invalid afterwards.
    pub fn push(self: *Demuxer, bytes: []const u8) Error!void {
        var rest = bytes;
        if (self.skip != 0 and self.start == self.buffer.items.len) {
            const take: usize = @intCast(@min(self.skip, rest.len));
            self.skip -= take;
            self.offset += take;
            rest = rest[take..];
        }
        if (rest.len == 0) return;
        // Drop what has been read before growing the buffer.
        if (self.start != 0) {
            const live = self.buffer.items.len - self.start;
            std.mem.copyForwards(u8, self.buffer.items[0..live], self.buffer.items[self.start..]);
            self.buffer.shrinkRetainingCapacity(live);
            self.start = 0;
        }
        try self.buffer.appendSlice(self.allocator, rest);
    }

    fn available(self: *const Demuxer) []const u8 {
        return self.buffer.items[self.start..];
    }

    fn consume(self: *Demuxer, count: usize) void {
        self.start += count;
        self.offset += count;
    }

    /// The next event the pushed bytes complete, or null when more are needed.
    pub fn next(self: *Demuxer) Error!?Event {
        while (true) {
            if (self.skip != 0) {
                const take: usize = @intCast(@min(self.skip, self.available().len));
                self.consume(take);
                self.skip -= take;
                if (self.skip != 0) return null;
            }
            // Close every known-sized master that ends here.
            while (self.stack.items.len != 0) {
                const top = self.stack.items[self.stack.items.len - 1];
                const end = top.end orelse break;
                if (self.offset > end) return error.Corrupt;
                if (self.offset < end) break;
                self.close();
            }
            const bytes = self.available();
            if (bytes.len == 0) return null;
            if (!self.header_seen and bytes[0] != 0x1A) return error.NotWebM;
            const header = (try readHeader(bytes)) orelse return null;
            if (!self.header_seen and header.id != id.ebml) return error.NotWebM;

            // An unknown-sized parent ends at the first element that cannot
            // be its child (RFC 9559 6.2).
            if (self.stack.items.len != 0) {
                const top = self.stack.items[self.stack.items.len - 1];
                if (top.end == null and !childOf(top.id, header.id)) {
                    self.close();
                    continue;
                }
                if (top.end) |end| if (header.size) |size| {
                    if (self.offset + header.length + size > end) return error.Corrupt;
                };
            }
            const parent: u32 = if (self.stack.items.len == 0) 0 else self.stack.items[self.stack.items.len - 1].id;
            switch (classify(parent, header.id)) {
                .master => {
                    self.consume(header.length);
                    try self.open(header.id, if (header.size) |size| self.offset + size else null);
                },
                .whole => {
                    const size = header.size orelse return error.Corrupt;
                    if (size > max_buffered) return error.Corrupt;
                    const total = header.length + @as(usize, @intCast(size));
                    if (bytes.len < total) return null;
                    const body = bytes[header.length..total];
                    const event = try self.readElement(header.id, body);
                    self.consume(total);
                    if (event) |value| return value;
                },
                .skip => {
                    const size = header.size orelse return error.Corrupt;
                    self.consume(header.length);
                    self.skip = size;
                },
            }
        }
    }

    /// The stream has ended. Corrupt if it ended inside an element whose size
    /// says more was to come, other than a cluster or the segment (a truncated
    /// file still plays the frames it holds).
    pub fn finish(self: *Demuxer) Error!void {
        if (!self.header_seen) return error.NotWebM;
        if (self.skip != 0 or self.available().len != 0) return error.Corrupt;
    }

    fn open(self: *Demuxer, element: u32, end: ?u64) Error!void {
        try self.stack.append(self.allocator, .{ .id = element, .end = end });
        switch (element) {
            id.cluster => {
                if (!self.tracks_seen) return error.Corrupt;
                self.cluster_timecode = null;
            },
            else => {},
        }
    }

    fn close(self: *Demuxer) void {
        const top = self.stack.pop().?;
        if (top.id == id.cluster) self.cluster_timecode = null;
    }

    /// A whole element, read: what it hands the caller, if anything.
    fn readElement(self: *Demuxer, element_id: u32, body: []const u8) Error!?Event {
        switch (element_id) {
            id.ebml => {
                if (self.header_seen) return error.Corrupt;
                try parseEbmlHeader(body);
                self.header_seen = true;
            },
            id.info => {
                self.info = try parseInfo(body);
                self.info_seen = true;
            },
            id.tracks => {
                // A second Tracks element (a chained segment) is not played.
                if (self.tracks_seen) return null;
                try self.parseTracks(body);
                self.tracks_seen = true;
                return .tracks;
            },
            id.cues => try self.parseCues(body),
            id.timecode => self.cluster_timecode = try readUint(body),
            id.simple_block => return .{ .block = try self.parseBlock(body, null, 0) },
            id.block_group => return try self.parseBlockGroup(body),
            else => {},
        }
        return null;
    }

    fn parseTracks(self: *Demuxer, body: []const u8) Error!void {
        var children = Children{ .bytes = body };
        while (try children.next()) |child| {
            if (child.id != id.track_entry) continue;
            var entry: Track = .{ .number = 0, .kind = .other, .codec = .other };
            var codec_private: []const u8 = "";
            var fields = Children{ .bytes = child.body };
            while (try fields.next()) |field| switch (field.id) {
                id.track_number => entry.number = try readUint(field.body),
                id.track_type => entry.kind = switch (try readUint(field.body)) {
                    1 => .video,
                    2 => .audio,
                    else => .other,
                },
                id.flag_enabled => entry.enabled = try readUint(field.body) != 0,
                id.codec_id => entry.codec = codecFor(readString(field.body)),
                id.codec_private => codec_private = field.body,
                id.default_duration => entry.default_duration_ns = try readUint(field.body),
                id.content_encodings => entry.encoded = true,
                id.video => {
                    var video = Children{ .bytes = field.body };
                    while (try video.next()) |setting| switch (setting.id) {
                        id.pixel_width => entry.pixel_width = std.math.cast(u32, try readUint(setting.body)) orelse return error.Corrupt,
                        id.pixel_height => entry.pixel_height = std.math.cast(u32, try readUint(setting.body)) orelse return error.Corrupt,
                        else => {},
                    };
                },
                id.audio => {
                    var audio = Children{ .bytes = field.body };
                    while (try audio.next()) |setting| switch (setting.id) {
                        id.sampling_frequency => entry.sampling_frequency = try readFloat(setting.body),
                        id.channels => entry.channels = try readUint(setting.body),
                        else => {},
                    };
                },
                else => {},
            };
            // TrackNumber is mandatory and never 0 (RFC 9559 5.1.4.1.1).
            if (entry.number == 0 or self.trackNumbered(entry.number) != null) return error.Corrupt;
            if (codec_private.len != 0) entry.codec_private = try self.allocator.dupe(u8, codec_private);
            errdefer if (entry.codec_private.len != 0) self.allocator.free(entry.codec_private);
            try self.tracks.append(self.allocator, entry);
        }
    }

    fn parseCues(self: *Demuxer, body: []const u8) Error!void {
        var points = Children{ .bytes = body };
        while (try points.next()) |point| {
            if (point.id != id.cue_point) continue;
            var fields = Children{ .bytes = point.body };
            while (try fields.next()) |field| {
                if (field.id == id.cue_time) try self.cue_times.append(self.allocator, try readUint(field.body));
            }
        }
    }

    fn parseBlockGroup(self: *Demuxer, body: []const u8) Error!?Event {
        var block: ?[]const u8 = null;
        var referenced = false;
        var duration: u64 = 0;
        var children = Children{ .bytes = body };
        while (try children.next()) |child| switch (child.id) {
            id.block => block = child.body,
            id.reference_block => referenced = true,
            id.block_duration => duration = try readUint(child.body),
            else => {},
        };
        // A BlockGroup must hold a Block (RFC 9559 5.1.3.5.1).
        const bytes = block orelse return error.Corrupt;
        return .{ .block = try self.parseBlock(bytes, !referenced, duration) };
    }

    /// RFC 9559 10 "Block Structure": track number (VINT), signed 16-bit
    /// relative timecode, flags, then the frames, laced or not.
    fn parseBlock(self: *Demuxer, body: []const u8, keyframe: ?bool, duration: u64) Error!Block {
        const timecode = self.cluster_timecode orelse return error.Corrupt;
        const number = (try readVint(body)) orelse return error.Corrupt;
        const track_number = number.value orelse return error.Corrupt;
        if (body.len < number.length + 3) return error.Corrupt;
        const relative = std.mem.readInt(i16, body[number.length..][0..2], .big);
        const flags = body[number.length + 2];
        const frames = try self.unlace(body[number.length + 3 ..], (flags >> 1) & 0b11);
        const scale = self.info.timecode_scale;
        const ticks = @as(i64, @intCast(timecode)) + relative;
        return .{
            .track = track_number,
            .time_ns = ticks * @as(i64, @intCast(scale)),
            .duration_ns = duration * scale,
            .keyframe = keyframe orelse (flags & 0x80 != 0),
            .frames = frames,
        };
    }

    /// RFC 9559 10.4 "Block Lacing": none, Xiph, fixed-size or EBML.
    fn unlace(self: *Demuxer, data: []const u8, lacing: u8) Error![]const []const u8 {
        if (lacing == 0) {
            self.frames[0] = data;
            return self.frames[0..1];
        }
        if (data.len < 1) return error.Corrupt;
        const count: usize = @as(usize, data[0]) + 1;
        var cursor: usize = 1;
        var sizes: [max_frames]u64 = undefined;
        switch (lacing) {
            // Xiph: each size but the last as a run of 255s and a final byte.
            0b01 => for (0..count - 1) |index| {
                var size: u64 = 0;
                while (true) {
                    if (cursor >= data.len) return error.Corrupt;
                    const byte = data[cursor];
                    cursor += 1;
                    size += byte;
                    if (byte != 255) break;
                }
                sizes[index] = size;
            },
            // Fixed: equal sizes that divide the rest.
            0b10 => {
                const rest = data.len - cursor;
                if (rest % count != 0) return error.Corrupt;
                for (0..count - 1) |index| sizes[index] = rest / count;
            },
            // EBML: the first size as a VINT, then signed differences.
            0b11 => if (count > 1) {
                const first = (try readVint(data[cursor..])) orelse return error.Corrupt;
                sizes[0] = first.value orelse return error.Corrupt;
                cursor += first.length;
                for (1..count - 1) |index| {
                    const delta = (try readVint(data[cursor..])) orelse return error.Corrupt;
                    const raw = delta.value orelse return error.Corrupt;
                    cursor += delta.length;
                    // Signed VINT: subtract half the range (2^(7n-1) - 1).
                    const bias = (@as(i64, 1) << @intCast(7 * delta.length - 1)) - 1;
                    const size = @as(i64, @intCast(sizes[index - 1])) + (@as(i64, @intCast(raw)) - bias);
                    if (size < 0) return error.Corrupt;
                    sizes[index] = @intCast(size);
                }
            },
            else => unreachable,
        }
        var used: u64 = 0;
        for (sizes[0 .. count - 1]) |size| used += size;
        if (cursor > data.len or used > data.len - cursor) return error.Corrupt;
        sizes[count - 1] = data.len - cursor - used;
        for (0..count) |index| {
            const size: usize = @intCast(sizes[index]);
            self.frames[index] = data[cursor..][0..size];
            cursor += size;
        }
        return self.frames[0..count];
    }
};

const Kind = enum { master, whole, skip };

/// How an element is read where it appears.
fn classify(parent: u32, element: u32) Kind {
    return switch (parent) {
        0 => switch (element) {
            id.ebml => .whole,
            id.segment => .master,
            else => .skip,
        },
        id.segment => switch (element) {
            id.info, id.tracks, id.cues => .whole,
            id.cluster => .master,
            else => .skip,
        },
        id.cluster => switch (element) {
            id.timecode, id.simple_block, id.block_group => .whole,
            else => .skip,
        },
        else => .skip,
    };
}

/// Whether `element` may appear directly inside `parent`; decides where an
/// unknown-sized parent ends. Void and CRC-32 may appear in any master.
fn childOf(parent: u32, element: u32) bool {
    if (element == id.void_ or element == id.crc32) return true;
    return switch (parent) {
        id.segment => switch (element) {
            id.seek_head, id.info, id.tracks, id.cues, id.cluster, id.chapters, id.tags, id.attachments => true,
            else => false,
        },
        id.cluster => switch (element) {
            id.timecode, id.silent_tracks, id.position, id.prev_size, id.simple_block, id.block_group, id.encrypted_block => true,
            else => false,
        },
        else => false,
    };
}

fn codecFor(codec_id: []const u8) Codec {
    const map = [_]struct { []const u8, Codec }{
        .{ "V_VP8", .vp8 },
        .{ "V_VP9", .vp9 },
        .{ "A_VORBIS", .vorbis },
        .{ "A_OPUS", .opus },
    };
    for (map) |entry| if (std.mem.eql(u8, codec_id, entry[0])) return entry[1];
    return .other;
}

/// RFC 8794 11.2.1-2: DocType "webm", EBMLReadVersion 1, element IDs of at
/// most 4 bytes and sizes of at most 8, and a DocTypeReadVersion a WebM
/// (Matroska version 4) reader can read.
fn parseEbmlHeader(body: []const u8) Error!void {
    var doc_type: []const u8 = "matroska";
    var read_version: u64 = 1;
    var doc_read_version: u64 = 1;
    var max_id: u64 = 4;
    var max_size: u64 = 8;
    var children = Children{ .bytes = body };
    while (children.next() catch return error.NotWebM) |child| switch (child.id) {
        id.doc_type => doc_type = readString(child.body),
        id.ebml_read_version => read_version = readUint(child.body) catch return error.NotWebM,
        id.doc_type_read_version => doc_read_version = readUint(child.body) catch return error.NotWebM,
        id.ebml_max_id_length => max_id = readUint(child.body) catch return error.NotWebM,
        id.ebml_max_size_length => max_size = readUint(child.body) catch return error.NotWebM,
        else => {},
    };
    if (!std.mem.eql(u8, doc_type, "webm")) return error.NotWebM;
    if (read_version != 1 or max_id > 4 or max_size > 8 or max_size == 0 or doc_read_version > 4) return error.NotWebM;
}

fn parseInfo(body: []const u8) Error!Info {
    var info: Info = .{};
    var ticks: ?f64 = null;
    var children = Children{ .bytes = body };
    while (try children.next()) |child| switch (child.id) {
        id.timecode_scale => info.timecode_scale = try readUint(child.body),
        id.duration => ticks = try readFloat(child.body),
        else => {},
    };
    if (info.timecode_scale == 0) return error.Corrupt;
    if (ticks) |value| {
        if (!(value >= 0) or std.math.isInf(value)) return error.Corrupt;
        info.duration = value * @as(f64, @floatFromInt(info.timecode_scale)) / std.time.ns_per_s;
    }
    return info;
}

pub const Header = struct {
    id: u32,
    /// The element's data size, or null for an unknown size.
    size: ?u64,
    /// The bytes of the ID and the size together.
    length: usize,
};

/// An element's ID and size at the start of `bytes`; null when they have not
/// all arrived.
pub fn readHeader(bytes: []const u8) Error!?Header {
    if (bytes.len == 0) return null;
    const id_length = vintLength(bytes[0]) orelse return error.Corrupt;
    if (id_length > 4) return error.Corrupt;
    if (bytes.len < id_length) return null;
    var element: u32 = 0;
    for (bytes[0..id_length]) |byte| element = (element << 8) | byte;
    const size = (try readVint(bytes[id_length..])) orelse return null;
    return .{ .id = element, .size = size.value, .length = id_length + size.length };
}

const Vint = struct {
    /// The value with its marker removed, or null when every value bit is
    /// set (the reserved "unknown" value).
    value: ?u64,
    length: usize,
};

/// RFC 8794 4: a variable-size integer.
fn readVint(bytes: []const u8) Error!?Vint {
    if (bytes.len == 0) return null;
    const length = vintLength(bytes[0]) orelse return error.Corrupt;
    if (bytes.len < length) return null;
    const marker_bits: u6 = @intCast(8 - length);
    var value: u64 = bytes[0] & ((@as(u64, 1) << marker_bits) - 1);
    for (bytes[1..length]) |byte| value = (value << 8) | byte;
    const all_ones = (@as(u64, 1) << @intCast(7 * length)) - 1;
    return .{ .value = if (value == all_ones) null else value, .length = length };
}

fn vintLength(first: u8) ?usize {
    if (first == 0) return null;
    return @as(usize, @clz(first)) + 1;
}

fn readUint(body: []const u8) Error!u64 {
    if (body.len > 8) return error.Corrupt;
    var value: u64 = 0;
    for (body) |byte| value = (value << 8) | byte;
    return value;
}

fn readFloat(body: []const u8) Error!f64 {
    return switch (body.len) {
        0 => 0,
        4 => @floatCast(@as(f32, @bitCast(std.mem.readInt(u32, body[0..4], .big)))),
        8 => @bitCast(std.mem.readInt(u64, body[0..8], .big)),
        else => error.Corrupt,
    };
}

/// An EBML string: its bytes up to the first NUL (RFC 8794 7.4).
fn readString(body: []const u8) []const u8 {
    const end = std.mem.indexOfScalar(u8, body, 0) orelse body.len;
    return body[0..end];
}

/// The children of a master element held whole.
const Children = struct {
    bytes: []const u8,
    const Child = struct { id: u32, body: []const u8 };
    fn next(self: *Children) Error!?Child {
        if (self.bytes.len == 0) return null;
        const header = (try readHeader(self.bytes)) orelse return error.Corrupt;
        const size = header.size orelse return error.Corrupt;
        if (size > self.bytes.len - header.length) return error.Corrupt;
        const end = header.length + @as(usize, @intCast(size));
        defer self.bytes = self.bytes[end..];
        return .{ .id = header.id, .body = self.bytes[header.length..end] };
    }
};

// ============================================================================
// Tests (WPT's own media files, read from tests/wpt/media at test time)
// ============================================================================

const testing = std.testing;

pub fn readFixture(allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    var path_buffer: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buffer, "tests/wpt/media/{s}", .{name});
    return std.Io.Dir.cwd().readFileAlloc(testing.io, path, allocator, .limited(8 * 1024 * 1024)) catch |err| {
        std.debug.print("webm fixture {s}: {s} (run from the checkout root, with the WPT tree at tests/wpt)\n", .{ path, @errorName(err) });
        return err;
    };
}

const Summary = struct {
    tracks: usize = 0,
    blocks: usize = 0,
    keyframes: usize = 0,
    last_time_ns: i64 = 0,
};

/// Demux `bytes` pushed in pieces of `piece` bytes; summarize what came out.
fn demuxAll(demuxer: *Demuxer, bytes: []const u8, piece: usize) Error!Summary {
    var summary: Summary = .{};
    var rest = bytes;
    while (true) {
        const take = @min(piece, rest.len);
        try demuxer.push(rest[0..take]);
        rest = rest[take..];
        while (try demuxer.next()) |event| switch (event) {
            .tracks => summary.tracks = demuxer.tracks.items.len,
            .block => |block| {
                summary.blocks += 1;
                if (block.keyframe) summary.keyframes += 1;
                summary.last_time_ns = @max(summary.last_time_ns, block.time_ns);
                for (block.frames) |frame| if (frame.len == 0) return error.Corrupt;
            },
        };
        if (rest.len == 0) break;
    }
    try demuxer.finish();
    return summary;
}

test "a VP8 file: header, info, one video track, every block" {
    const file = try readFixture(testing.allocator, "test-v-128k-320x240-24fps-8kfr.webm");
    defer testing.allocator.free(file);
    var demuxer = Demuxer.init(testing.allocator);
    defer demuxer.deinit();
    const summary = try demuxAll(&demuxer, file, file.len);
    try testing.expectEqual(@as(usize, 1), summary.tracks);
    const video = demuxer.tracks.items[0];
    try testing.expectEqual(TrackType.video, video.kind);
    try testing.expectEqual(Codec.vp8, video.codec);
    try testing.expectEqual(@as(u32, 320), video.pixel_width);
    try testing.expectEqual(@as(u32, 240), video.pixel_height);
    try testing.expectApproxEqAbs(@as(f64, 2.0), demuxer.declaredDuration().?, 0.001);
    // 2 s at 24 fps; ffprobe counts 48 video frames.
    try testing.expectEqual(@as(usize, 48), summary.blocks);
    try testing.expect(summary.keyframes >= 1);
}

test "a VP9 + Opus file, pushed one byte at a time, gives what one push gives" {
    const file = try readFixture(testing.allocator, "movie_5.webm");
    defer testing.allocator.free(file);
    var whole = Demuxer.init(testing.allocator);
    defer whole.deinit();
    const expected = try demuxAll(&whole, file, file.len);
    try testing.expectEqual(@as(usize, 2), expected.tracks);
    try testing.expectEqual(Codec.vp9, whole.tracks.items[0].codec);
    try testing.expectEqual(Codec.opus, whole.tracks.items[1].codec);
    // The track header says 24 kHz (ffprobe reports Opus's 48 kHz output rate instead).
    try testing.expectEqual(@as(f64, 24000), whole.tracks.items[1].sampling_frequency);
    try testing.expectEqual(@as(u64, 1), whole.tracks.items[1].channels);
    try testing.expect(std.mem.startsWith(u8, whole.tracks.items[1].codec_private, "OpusHead"));
    try testing.expectApproxEqAbs(@as(f64, 5.008), whole.declaredDuration().?, 0.001);
    try testing.expect(whole.cue_times.items.len >= 1);

    var bytewise = Demuxer.init(testing.allocator);
    defer bytewise.deinit();
    const split = try demuxAll(&bytewise, file, 1);
    try testing.expectEqual(expected.blocks, split.blocks);
    try testing.expectEqual(expected.keyframes, split.keyframes);
    try testing.expectEqual(expected.last_time_ns, split.last_time_ns);
    // Skipped elements are never buffered: the buffer holds at most one block.
    try testing.expect(bytewise.buffer.capacity < file.len);
}

test "a Vorbis file: the codec private and laced blocks" {
    const file = try readFixture(testing.allocator, "test-a-128k-44100Hz-1ch.webm");
    defer testing.allocator.free(file);
    var demuxer = Demuxer.init(testing.allocator);
    defer demuxer.deinit();
    const summary = try demuxAll(&demuxer, file, 4096);
    const audio = demuxer.tracks.items[0];
    try testing.expectEqual(TrackType.audio, audio.kind);
    try testing.expectEqual(Codec.vorbis, audio.codec);
    try testing.expectEqual(@as(f64, 44100), audio.sampling_frequency);
    // Xiph-laced: 2 (three packets), then the identification header's type.
    try testing.expectEqual(@as(u8, 2), audio.codec_private[0]);
    try testing.expect(summary.blocks > 10);
}

test "a live stream: unknown-sized segment and clusters, no duration" {
    const file = try readFixture(testing.allocator, "400x300-red-resize-200x150-green.webm");
    defer testing.allocator.free(file);
    var demuxer = Demuxer.init(testing.allocator);
    defer demuxer.deinit();
    const summary = try demuxAll(&demuxer, file, 777);
    try testing.expectEqual(@as(?f64, null), demuxer.declaredDuration());
    try testing.expectEqual(@as(usize, 1), summary.tracks);
    // ffprobe: 119 video frames, the last at 1.97 s - every cluster was read.
    try testing.expectEqual(@as(usize, 119), summary.blocks);
    try testing.expect(summary.last_time_ns > 1_900_000_000);
}

test "a truncated file ends inside an element" {
    const file = try readFixture(testing.allocator, "test-1s.webm");
    defer testing.allocator.free(file);
    var demuxer = Demuxer.init(testing.allocator);
    defer demuxer.deinit();
    try testing.expectError(error.Corrupt, demuxAll(&demuxer, file[0 .. file.len / 2], 1000));
    // The blocks before the cut were read.
    var counter = Demuxer.init(testing.allocator);
    defer counter.deinit();
    try counter.push(file[0 .. file.len / 2]);
    var blocks: usize = 0;
    while (try counter.next()) |event| {
        if (event == .block) blocks += 1;
    }
    try testing.expect(blocks > 0);
}

/// A demuxer past its header and Tracks (one VP8 track, number 1), inside an
/// unknown-sized Segment: hand-made clusters follow.
fn inSegment(demuxer: *Demuxer) !void {
    try demuxer.tracks.append(testing.allocator, .{ .number = 1, .kind = .video, .codec = .vp8 });
    demuxer.tracks_seen = true;
    demuxer.header_seen = true;
    try demuxer.stack.append(testing.allocator, .{ .id = id.segment, .end = null });
}

test "a corrupt block: lacing that overruns, a block before its timecode, an element past its parent" {
    {
        var bad = Demuxer.init(testing.allocator);
        defer bad.deinit();
        // A hand-made cluster: Timecode 0, then a SimpleBlock on track 1 whose
        // Xiph lacing claims a 255+255+10 byte first frame in 6 bytes.
        try inSegment(&bad);
        const cluster = [_]u8{ 0x1F, 0x43, 0xB6, 0x75, 0x8D, 0xE7, 0x81, 0x00, 0xA3, 0x88, 0x81, 0x00, 0x00, 0x82, 0x01, 0xFF, 0xFF, 0x0A };
        try bad.push(&cluster);
        try testing.expectError(error.Corrupt, bad.next());
    }
    {
        var bad = Demuxer.init(testing.allocator);
        defer bad.deinit();
        try inSegment(&bad);
        // A SimpleBlock with no cluster Timecode before it.
        const cluster = [_]u8{ 0x1F, 0x43, 0xB6, 0x75, 0x86, 0xA3, 0x84, 0x81, 0x00, 0x00, 0x80 };
        try bad.push(&cluster);
        try testing.expectError(error.Corrupt, bad.next());
    }
    {
        var bad = Demuxer.init(testing.allocator);
        defer bad.deinit();
        try inSegment(&bad);
        // A cluster of 4 bytes holding a 6-byte block.
        const cluster = [_]u8{ 0x1F, 0x43, 0xB6, 0x75, 0x84, 0xA3, 0x84, 0x81, 0x00, 0x00, 0x80 };
        try bad.push(&cluster);
        try testing.expectError(error.Corrupt, bad.next());
    }
}

test "not WebM: another format, and Matroska's own DocType" {
    const others = [_][]const u8{ "RIFF\x24\x00\x00\x00WAVEfmt ", "OggS\x00\x02", "\x00\x00\x00\x18ftypmp42" };
    for (others) |bytes| {
        var demuxer = Demuxer.init(testing.allocator);
        defer demuxer.deinit();
        try demuxer.push(bytes);
        try testing.expectError(error.NotWebM, demuxer.next());
    }
    const file = try readFixture(testing.allocator, "2x2-green.webm");
    defer testing.allocator.free(file);
    const copy = try testing.allocator.dupe(u8, file);
    defer testing.allocator.free(copy);
    const at = std.mem.indexOf(u8, copy, "webm").?;
    // DocType "webm" -> "mkv\x00": not "webm" (readString stops at the NUL).
    @memcpy(copy[at..][0..4], "mkv\x00");
    var demuxer = Demuxer.init(testing.allocator);
    defer demuxer.deinit();
    try demuxer.push(copy);
    try testing.expectError(error.NotWebM, demuxer.next());
}

test "an unknown element in a known-sized cluster is skipped" {
    var demuxer = Demuxer.init(testing.allocator);
    defer demuxer.deinit();
    try inSegment(&demuxer);
    // Cluster { Timecode 5, an unknown 0x4FFF element of 3 bytes, SimpleBlock track 1 +2 keyframe "x" }
    const cluster = [_]u8{ 0x1F, 0x43, 0xB6, 0x75, 0x90, 0xE7, 0x81, 0x05, 0x4F, 0xFF, 0x83, 1, 2, 3, 0xA3, 0x85, 0x81, 0x00, 0x02, 0x80, 'x' };
    for (cluster) |byte| try demuxer.push(&.{byte});
    const event = (try demuxer.next()).?;
    try testing.expectEqual(@as(u64, 1), event.block.track);
    try testing.expectEqual(@as(i64, 7_000_000), event.block.time_ns);
    try testing.expect(event.block.keyframe);
    try testing.expectEqualStrings("x", event.block.frames[0]);
    try testing.expectEqual(@as(?Event, null), try demuxer.next());
}

/// Every WebM file in tests/wpt/media (2026-10-09).
pub const media_files = [_][]const u8{
    "2x2-green.webm",                                    "400x300-red-resize-200x150-green.webm",
    "A4.webm",                                           "counting.webm",
    "green-at-15.webm",                                  "movie_300.webm",
    "movie_5.webm",                                      "rgb100.webm",
    "test-1s.webm",                                      "test-a-128k-44100Hz-1ch.webm",
    "test-av-384k-44100Hz-1ch-320x240-30fps-10kfr.webm", "test-v-128k-320x240-24fps-8kfr.webm",
    "test.webm",                                         "video.webm",
    "white.webm",
};

test "every WebM file WPT serves from /media demuxes, in pieces of any size" {
    for (media_files) |name| {
        const file = try readFixture(testing.allocator, name);
        defer testing.allocator.free(file);
        for ([_]usize{ file.len, 4096, 333 }) |piece| {
            var demuxer = Demuxer.init(testing.allocator);
            defer demuxer.deinit();
            const summary = demuxAll(&demuxer, file, piece) catch |err| {
                std.debug.print("{s} (pieces of {d}): {s}\n", .{ name, piece, @errorName(err) });
                return err;
            };
            try testing.expect(summary.tracks >= 1);
            try testing.expect(summary.blocks >= 1);
        }
    }
}
