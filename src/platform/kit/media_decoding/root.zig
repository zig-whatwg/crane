//! kit/media_decoding: the media decoders Crane's default platforms build in
//! - darwin, linux and testing compose it behind `media_decoding` (6.10.5
//! of the protocol: mediaCanPlayType, openMediaDecoder, pushMediaData,
//! mediaVideoSize, closeMediaDecoder). The user, 2026-11-09 (lane wptcfg, D4):
//! "our default platform for running wpt should get its own implementation of
//! these things ... The platform itself that is compiled in will decide if
//! these features are built within the platform or dynamically link out to
//! existing capabilities on the platform." So Crane's own browser - the
//! console - plays what WPT plays, through the same path: HTML's media
//! element asks the platform, never a decoder a host passes in. An adapter
//! that links out to the OS's decoders later (AVFoundation, GStreamer)
//! answers the same operations instead.
//!
//! One format today: RIFF/WAVE linear PCM, which a headless engine decodes
//! for real - the samples are the data. WPT's media tests need it: every
//! audio request common/security-features/resources/common.sub.js makes is a
//! `<source type="audio/wav">` serving webaudio/resources/sin_440Hz_-6dBFS_1s.wav.
//! WebM, Ogg and MP4 are not decoded, so canPlayType answers "" for them and
//! their bytes are unsupported; real VP8/VP9/Vorbis/Opus decoding is its own
//! item (the header-only WebM code is set aside, never claimed).
//!
//! What it really does, and so what it may answer for:
//! - canPlayType: the WAV MIME spellings the browsers accept, with no codecs
//!   ("maybe") or with codecs="1" (PCM, "probably"); everything else "".
//!   The type is parsed with MIME Sniffing's own parser (module `mimesniff`,
//!   this part's one import beyond the facade): one parser in Crane, not a
//!   second copy to keep in step with it.
//! - the decoder parses the RIFF header - the `fmt ` chunk (PCM, or
//!   WAVE_FORMAT_EXTENSIBLE with the PCM subformat), skipping every unknown
//!   chunk with its pad byte, then the `data` chunk - and reports metadata
//!   (duration = data bytes / byte rate) once the header is complete;
//!   current_data only once the sample frame at the playback position (the
//!   start: Crane opens a decoder per resource fetch, before playback) has
//!   arrived. A float, A-law or mu-law file is unsupported: it is WAV, but
//!   this decoder does not decode it. What it decodes is decided by the
//!   bytes, whatever the resource's Content-Type, as the media element sniffs
//!   a resource.
//! It plays nothing out loud (audio_output is unsupported): playback runs on
//! Crane's media clock.
const std = @import("std");
const platform = @import("platform");
const mimesniff = @import("mimesniff");

// ============================================================================
// The protocol's media operations (6.10.5), for an adapter to compose
// ============================================================================

/// mediaCanPlayType: HTML canPlayType for `mime`. Stateless: the answer is
/// the same for every Browser.
pub fn mediaCanPlayType(browser: *platform.BrowserPlatform, mime: platform.Str) platform.MediaSupport {
    _ = browser;
    return canPlayType(mime.slice());
}

/// openMediaDecoder, with the Browser's allocator - the adapter passes its
/// per-Browser state's (kit/browser_state), which outlives every decoder of
/// its Browser. `mime` is not read: the bytes decide. OWNED until
/// `closeMediaDecoder`.
pub fn openMediaDecoder(allocator: std.mem.Allocator, mime: platform.Str) platform.Error!*platform.MediaDecoder {
    _ = mime;
    const decoder = try allocator.create(Decoder);
    decoder.* = .{ .allocator = allocator };
    return @ptrCast(decoder);
}

/// pushMediaData: on `metadata` and `current_data` it has written `metadata`
/// (the duration; no frame size - WAV has no video).
pub fn pushMediaData(decoder: *platform.MediaDecoder, bytes: platform.Bytes, end_of_stream: bool, metadata: *platform.MediaMetadata) platform.MediaResult {
    const self: *Decoder = @ptrCast(@alignCast(decoder));
    return switch (self.feed(bytes.slice(), end_of_stream)) {
        .need_more => .need_more,
        .unsupported => .unsupported,
        .decode_error => .decode_error,
        .metadata => |known| blk: {
            metadata.* = .{ .duration = known.duration };
            break :blk .metadata;
        },
        .current_data => |known| blk: {
            metadata.* = .{ .duration = known.duration };
            break :blk .current_data;
        },
    };
}

/// mediaVideoSize: audio only, so the decoder never has a frame size.
pub fn mediaVideoSize(decoder: *platform.MediaDecoder, seconds: f64, size: *platform.VideoSize) bool {
    _ = .{ decoder, seconds, size };
    return false;
}

pub fn closeMediaDecoder(decoder: *platform.MediaDecoder) void {
    const self: *Decoder = @ptrCast(@alignCast(decoder));
    self.allocator.destroy(self);
}

// ============================================================================
// WAV
// ============================================================================

/// What the decoder holds after a push: the protocol's MediaResult, with the
/// metadata it writes.
pub const Result = union(enum) {
    need_more,
    unsupported,
    decode_error,
    metadata: Metadata,
    /// The decoder really has data at the current playback position: the
    /// sample frame there has arrived. A header alone never produces this.
    current_data: Metadata,
};

pub const Metadata = struct { duration: f64 };

/// The MIME spellings of WAV the browsers recognise.
/// - audio/wav, audio/x-wav: Chromium media/base/mime_util_internal.cc
///   (`AddContainerWithCodecs("audio/wav", wav_codecs)` and "audio/x-wav",
///   with `wav_codecs{PCM}`), and Gecko dom/media/wave/WaveDecoder.cpp
///   (WaveDecoder::IsSupportedType).
/// - audio/wave: Gecko's WaveDecoder::IsSupportedType (Chromium does not list
///   it); it is also the type MIME Sniffing's audio/video pattern table
///   computes for a RIFF....WAVE signature, so a sniffed WAV resource reaches
///   openMediaDecoder with it.
/// Gecko's fourth spelling, audio/x-pn-wav, is Gecko-only and left out.
const subtypes = [_][]const u8{ "wav", "wave", "x-wav" };

/// "Can play type" for `mime`, a valid MIME type string or not:
/// - no codecs parameter: "maybe" - the container is WAV, but which codec is
///   unknown (Chromium IsSupportedMediaFormat: a container that expects codecs
///   and got none is kMaybeSupported; Gecko answers maybe for an empty codecs
///   list);
/// - codecs="1" (WAVE_FORMAT_PCM, Chromium's kStringToCodecMap {"1", PCM}, and
///   Gecko's "1"): "probably". A list is PCM only if every entry is "1".
/// - any other codec: "" - Gecko also accepts "3" (IEEE float), "6" (A-law)
///   and "7" (mu-law), but this decoder does not decode them.
/// WPT html/semantics/embedded-content/media-elements/mime-types/canPlayType.html
/// pins these answers for audio/wav; Chrome, Firefox and Safari pass all four
/// of its audio/wav subtests (wpt.fyi, 2026-10-09).
pub fn canPlayType(mime: []const u8) platform.MediaSupport {
    // The operation takes no allocator: a MIME type longer than this buffer
    // holds is no type this decoder plays.
    var buffer: [16 * 1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&buffer);
    var parsed = (mimesniff.parseMimeType(fixed.allocator(), mime) catch return .unsupported) orelse return .unsupported;
    defer parsed.deinit();
    if (!utf16Eql(parsed.type, "audio")) return .unsupported;
    const known = for (subtypes) |subtype| {
        if (utf16Eql(parsed.subtype, subtype)) break true;
    } else false;
    if (!known) return .unsupported;
    const codecs = for (parsed.parameters.entries.items()) |entry| {
        if (utf16Eql(entry.key, "codecs")) break entry.value;
    } else return .maybe;
    // RFC 6381 codecs: a comma-separated list. Every entry must be PCM.
    var entries = std.mem.splitScalar(u16, codecs, ',');
    while (entries.next()) |raw| {
        if (!utf16Eql(std.mem.trim(u16, raw, &.{ ' ', '\t', '\n', '\r' }), "1")) return .unsupported;
    }
    return .probably;
}

fn utf16Eql(units: []const u16, ascii: []const u8) bool {
    if (units.len != ascii.len) return false;
    for (units, ascii) |unit, byte| if (unit != byte) return false;
    return true;
}

/// WAVE_FORMAT_PCM and WAVE_FORMAT_EXTENSIBLE (mmreg.h).
const format_pcm: u16 = 0x0001;
const format_extensible: u16 = 0xFFFE;
/// KSDATAFORMAT_SUBTYPE_PCM, {00000001-0000-0010-8000-00aa00389b71}, as the
/// 16 bytes an extensible fmt chunk stores it in (the GUID's first three
/// fields little-endian).
const subtype_pcm = [16]u8{ 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x00, 0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71 };
/// The largest fmt chunk this decoder buffers: an extensible one is 40 bytes.
const max_fmt_size = 1024;

pub const Format = struct {
    channels: u16,
    sample_rate: u32,
    byte_rate: u32,
    block_align: u16,
    bits_per_sample: u16,
};

/// A decoder for one resource, whatever its Content-Type says: what it
/// decodes is decided by the bytes (a RIFF/WAVE header), the way the media
/// element decides a resource's format by sniffing it.
pub const Decoder = struct {
    /// The Browser's, from openMediaDecoder; closeMediaDecoder frees with it.
    allocator: std.mem.Allocator,
    state: State = .riff,
    /// The bytes of the structure being read: the RIFF header, a chunk
    /// header, or the fmt chunk's body.
    pending: [max_fmt_size]u8 = undefined,
    pending_len: usize = 0,
    /// Bytes of the current fmt body still to read, including its pad byte.
    fmt_size: usize = 0,
    fmt_padded: bool = false,
    /// Bytes of an unknown chunk (with its pad byte) still to skip.
    skip: u64 = 0,
    format: ?Format = null,
    /// The data chunk's declared size, and how much of it has arrived.
    data_size: u64 = 0,
    data_received: u64 = 0,
    /// A sticky outcome: once a resource is unsupported or broken, it stays so.
    failed: ?Result = null,

    const State = enum { riff, chunk_header, fmt, skip, data };

    pub fn feed(self: *Decoder, bytes: []const u8, end_of_stream: bool) Result {
        if (self.failed) |outcome| return outcome;
        var rest = bytes;
        while (rest.len != 0) {
            switch (self.state) {
                .riff => {
                    rest = self.collect(rest, 12);
                    // A resource that does not start "RIFF" is not this
                    // host's to decode, however few bytes have arrived.
                    const seen = @min(self.pending_len, 4);
                    if (!std.mem.eql(u8, self.pending[0..seen], "RIFF"[0..seen])) return self.fail(.unsupported);
                    if (self.pending_len < 12) break;
                    // "RIFF", the size of the rest, "WAVE". RIFX (big-endian)
                    // and RF64 are WAV too; this host does not decode them.
                    if (!std.mem.eql(u8, self.pending[0..4], "RIFF") or !std.mem.eql(u8, self.pending[8..12], "WAVE")) return self.fail(.unsupported);
                    self.pending_len = 0;
                    self.state = .chunk_header;
                },
                .chunk_header => {
                    rest = self.collect(rest, 8);
                    if (self.pending_len < 8) break;
                    const size = std.mem.readInt(u32, self.pending[4..8], .little);
                    const id = self.pending[0..4].*;
                    self.pending_len = 0;
                    if (std.mem.eql(u8, &id, "fmt ") and self.format == null) {
                        if (size < 16 or size > max_fmt_size) return self.fail(.decode_error);
                        self.fmt_size = size;
                        self.fmt_padded = size % 2 == 1;
                        self.state = .fmt;
                    } else if (std.mem.eql(u8, &id, "data")) {
                        // A data chunk before any fmt chunk has no format.
                        if (self.format == null) return self.fail(.decode_error);
                        self.data_size = size;
                        self.state = .data;
                    } else {
                        // An unknown chunk (or a second fmt): skip it and its
                        // pad byte - RIFF chunks are word-aligned.
                        self.skip = @as(u64, size) + (size % 2);
                        self.state = .skip;
                    }
                },
                .fmt => {
                    rest = self.collect(rest, self.fmt_size);
                    if (self.pending_len < self.fmt_size) break;
                    const outcome = self.parseFormat(self.pending[0..self.fmt_size]);
                    self.pending_len = 0;
                    if (outcome) |failure| return self.fail(failure);
                    if (self.fmt_padded) {
                        self.skip = 1;
                        self.state = .skip;
                    } else self.state = .chunk_header;
                },
                .skip => {
                    const take: usize = @intCast(@min(self.skip, rest.len));
                    self.skip -= take;
                    rest = rest[take..];
                    if (self.skip == 0) self.state = .chunk_header;
                },
                .data => {
                    // Bytes past the data chunk (trailing chunks) are not media.
                    const wanted = self.data_size - self.data_received;
                    self.data_received += @min(wanted, rest.len);
                    rest = rest[rest.len..];
                },
            }
        }
        return self.result(end_of_stream);
    }

    /// Append to `pending` until it holds `want` bytes; returns what is left.
    fn collect(self: *Decoder, bytes: []const u8, want: usize) []const u8 {
        const take = @min(want - self.pending_len, bytes.len);
        @memcpy(self.pending[self.pending_len..][0..take], bytes[0..take]);
        self.pending_len += take;
        return bytes[take..];
    }

    /// The fmt chunk: null when it is linear PCM this decoder can play.
    fn parseFormat(self: *Decoder, body: []const u8) ?Result {
        const tag = std.mem.readInt(u16, body[0..2], .little);
        const format: Format = .{
            .channels = std.mem.readInt(u16, body[2..4], .little),
            .sample_rate = std.mem.readInt(u32, body[4..8], .little),
            .byte_rate = std.mem.readInt(u32, body[8..12], .little),
            .block_align = std.mem.readInt(u16, body[12..14], .little),
            .bits_per_sample = std.mem.readInt(u16, body[14..16], .little),
        };
        switch (tag) {
            format_pcm => {},
            format_extensible => {
                // cbSize (22 for extensible), valid bits, channel mask, then
                // the subformat GUID.
                if (body.len < 40 or std.mem.readInt(u16, body[16..18], .little) < 22) return .decode_error;
                if (!std.mem.eql(u8, body[24..40], &subtype_pcm)) return .unsupported;
            },
            else => return .unsupported,
        }
        const bits = format.bits_per_sample;
        if (format.channels == 0 or format.sample_rate == 0) return .decode_error;
        if (bits != 8 and bits != 16 and bits != 24 and bits != 32) return .unsupported;
        if (@as(u32, format.block_align) != @as(u32, format.channels) * (bits / 8)) return .decode_error;
        if (@as(u64, format.byte_rate) != @as(u64, format.sample_rate) * format.block_align) return .decode_error;
        self.format = format;
        return null;
    }

    fn fail(self: *Decoder, outcome: Result) Result {
        self.failed = outcome;
        return outcome;
    }

    /// What the decoder holds now.
    fn result(self: *Decoder, end_of_stream: bool) Result {
        if (self.state != .data) {
            // The resource ended inside its header: never a RIFF/WAVE file,
            // or a truncated one.
            if (!end_of_stream) return .need_more;
            return self.fail(if (self.state == .riff) .unsupported else .decode_error);
        }
        const format = self.format.?;
        var duration_bytes = self.data_size;
        if (end_of_stream and self.data_received < self.data_size) {
            // Truncated in its data: what arrived is all there is to play.
            duration_bytes = self.data_received - self.data_received % format.block_align;
        }
        const metadata: Metadata = .{ .duration = @as(f64, @floatFromInt(duration_bytes)) / @as(f64, @floatFromInt(format.byte_rate)) };
        // The sample frame at the playback position - the first - has arrived.
        if (self.data_received >= format.block_align) return .{ .current_data = metadata };
        // The resource ended with no complete sample frame: nothing to play.
        if (end_of_stream) return self.fail(.decode_error);
        return .{ .metadata = metadata };
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

/// A canonical 44-byte header (PCM unless `tag` says otherwise) followed by
/// `data_size` bytes of samples.
fn wavFile(allocator: std.mem.Allocator, channels: u16, rate: u32, bits: u16, data_size: u32) ![]u8 {
    const block: u16 = channels * (bits / 8);
    var list: std.ArrayList(u8) = .empty;
    errdefer list.deinit(allocator);
    try list.appendSlice(allocator, "RIFF");
    try appendInt(allocator, &list, u32, 36 + data_size);
    try list.appendSlice(allocator, "WAVEfmt ");
    try appendInt(allocator, &list, u32, 16);
    try appendInt(allocator, &list, u16, format_pcm);
    try appendInt(allocator, &list, u16, channels);
    try appendInt(allocator, &list, u32, rate);
    try appendInt(allocator, &list, u32, rate * block);
    try appendInt(allocator, &list, u16, block);
    try appendInt(allocator, &list, u16, bits);
    try list.appendSlice(allocator, "data");
    try appendInt(allocator, &list, u32, data_size);
    try list.appendNTimes(allocator, 0x80, data_size);
    return list.toOwnedSlice(allocator);
}

fn appendInt(allocator: std.mem.Allocator, list: *std.ArrayList(u8), comptime T: type, value: T) !void {
    var bytes: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &bytes, value, .little);
    try list.appendSlice(allocator, &bytes);
}

/// A decoder opened and closed through the protocol's operations, fed
/// through `feed` so a test reads each push's Result whole.
const TestDecoder = struct {
    handle: *platform.MediaDecoder,

    fn push(self: TestDecoder, bytes: []const u8, end_of_stream: bool) Result {
        const decoder: *Decoder = @ptrCast(@alignCast(self.handle));
        return decoder.feed(bytes, end_of_stream);
    }

    fn deinit(self: *TestDecoder) void {
        closeMediaDecoder(self.handle);
    }
};

fn openDecoder() !TestDecoder {
    return .{ .handle = try openMediaDecoder(testing.allocator, .from("audio/wav")) };
}

test "canPlayType answers for the WAV spellings the browsers accept, and only PCM" {
    const maybe = [_][]const u8{ "audio/wav", "audio/wave", "audio/x-wav", "AUDIO/WAV", "audio/wav;", "audio/wav;codecs", "audio/wav;codecs=", " audio/wav ; foo=bar" };
    for (maybe) |mime| try testing.expectEqual(platform.MediaSupport.maybe, canPlayType(mime));
    const probably = [_][]const u8{ "audio/wav; codecs=\"1\"", "audio/wav; codecs=1", "audio/x-wav;codecs=\"1\"", "audio/wave; codecs=\"1, 1\"" };
    for (probably) |mime| try testing.expectEqual(platform.MediaSupport.probably, canPlayType(mime));
    const unsupported = [_][]const u8{
        "",
        "audio/wav; codecs=\"bogus\"",
        // WAV, but float, A-law and mu-law: Gecko decodes them, this host does not.
        "audio/wav; codecs=\"3\"",
        "audio/wav; codecs=\"6\"",
        "audio/wav; codecs=\"7\"",
        "audio/wav; codecs=\"1, vorbis\"",
        "audio/x-pn-wav",
        "video/wav",
        "audio/ogg",
        "audio/webm",
        "video/webm",
        "audio/mpeg",
        "application/octet-stream",
        "audio/",
        "wav",
    };
    for (unsupported) |mime| try testing.expectEqual(platform.MediaSupport.unsupported, canPlayType(mime));
}

test "the header split across pushes reports need_more, then metadata, then current data" {
    const file = try wavFile(testing.allocator, 1, 8000, 16, 16000);
    defer testing.allocator.free(file);
    var decoder = try openDecoder();
    defer decoder.deinit();
    // One byte at a time through the 44-byte header.
    for (file[0..43]) |byte| try testing.expectEqual(Result.need_more, decoder.push(&.{byte}, false));
    const header = decoder.push(file[43..44], false);
    try testing.expect(header == .metadata);
    try testing.expectEqual(@as(f64, 1), header.metadata.duration);
    // Half a sample frame is not data at the playback position.
    try testing.expect(decoder.push(file[44..45], false) == .metadata);
    const first = decoder.push(file[45..46], false);
    try testing.expect(first == .current_data);
    try testing.expectEqual(@as(f64, 1), first.current_data.duration);
    const last = decoder.push(file[46..], true);
    try testing.expect(last == .current_data);
    try testing.expectEqual(@as(f64, 1), last.current_data.duration);
}

test "the whole file in one push, as WPT serves sin_440Hz_-6dBFS_1s.wav" {
    // 44.1 kHz mono 16-bit, 88,202 data bytes: 1.0000226... seconds.
    const file = try wavFile(testing.allocator, 1, 44100, 16, 88202);
    defer testing.allocator.free(file);
    var decoder = try openDecoder();
    defer decoder.deinit();
    const outcome = decoder.push(file, true);
    try testing.expect(outcome == .current_data);
    try testing.expectApproxEqAbs(@as(f64, 88202.0 / 88200.0), outcome.current_data.duration, 1e-12);
}

test "WAVE_FORMAT_EXTENSIBLE with the PCM subformat plays; another subformat does not" {
    for ([_]bool{ true, false }) |pcm| {
        var list: std.ArrayList(u8) = .empty;
        defer list.deinit(testing.allocator);
        const a = testing.allocator;
        try list.appendSlice(a, "RIFF");
        try appendInt(a, &list, u32, 60 + 8);
        try list.appendSlice(a, "WAVEfmt ");
        try appendInt(a, &list, u32, 40);
        try appendInt(a, &list, u16, format_extensible);
        try appendInt(a, &list, u16, 2); // channels
        try appendInt(a, &list, u32, 48000);
        try appendInt(a, &list, u32, 48000 * 6);
        try appendInt(a, &list, u16, 6);
        try appendInt(a, &list, u16, 24);
        try appendInt(a, &list, u16, 22); // cbSize
        try appendInt(a, &list, u16, 24); // valid bits
        try appendInt(a, &list, u32, 3); // front left, front right
        var subformat = subtype_pcm;
        if (!pcm) subformat[0] = 0x03; // KSDATAFORMAT_SUBTYPE_IEEE_FLOAT
        try list.appendSlice(a, &subformat);
        try list.appendSlice(a, "data");
        try appendInt(a, &list, u32, 12);
        try list.appendNTimes(a, 0, 12);
        var decoder = try openDecoder();
        defer decoder.deinit();
        const outcome = decoder.push(list.items, true);
        if (pcm) {
            try testing.expect(outcome == .current_data);
            try testing.expectApproxEqAbs(@as(f64, 12.0 / 288000.0), outcome.current_data.duration, 1e-15);
        } else {
            try testing.expectEqual(Result.unsupported, outcome);
        }
    }
}

test "a truncated file: inside the header is a decode error, inside the data plays what arrived" {
    const file = try wavFile(testing.allocator, 1, 8000, 16, 16000);
    defer testing.allocator.free(file);
    {
        var decoder = try openDecoder();
        defer decoder.deinit();
        try testing.expectEqual(Result.need_more, decoder.push(file[0..30], false));
        try testing.expectEqual(Result.decode_error, decoder.push("", true));
        // Sticky: nothing after a failure changes it.
        try testing.expectEqual(Result.decode_error, decoder.push(file[30..], true));
    }
    {
        var decoder = try openDecoder();
        defer decoder.deinit();
        // 4,001 of the 16,000 data bytes: 2,000 whole frames, a quarter second.
        const outcome = decoder.push(file[0 .. 44 + 4001], true);
        try testing.expect(outcome == .current_data);
        try testing.expectEqual(@as(f64, 0.25), outcome.current_data.duration);
    }
    {
        // The header and no complete sample frame: nothing to play.
        var decoder = try openDecoder();
        defer decoder.deinit();
        try testing.expect(decoder.push(file[0..45], false) == .metadata);
        try testing.expectEqual(Result.decode_error, decoder.push("", true));
    }
    {
        // Not even a RIFF header: never recognized, so unsupported.
        var decoder = try openDecoder();
        defer decoder.deinit();
        try testing.expectEqual(Result.unsupported, decoder.push("RIF", true));
    }
}

test "a non-PCM format is unsupported, and so is a file that is not RIFF/WAVE" {
    const file = try wavFile(testing.allocator, 1, 8000, 8, 100);
    defer testing.allocator.free(file);
    // WAVE_FORMAT_IEEE_FLOAT (3), A-law (6), mu-law (7), MPEG Layer 3 (0x55).
    for ([_]u16{ 3, 6, 7, 0x55 }) |tag| {
        std.mem.writeInt(u16, file[20..22], tag, .little);
        var decoder = try openDecoder();
        defer decoder.deinit();
        try testing.expectEqual(Result.unsupported, decoder.push(file, false));
    }
    const others = [_][]const u8{ "ID3\x04\x00\x00\x00\x00\x00\x00 an mp3", "OggS\x00\x02 an ogg file", "\x1a\x45\xdf\xa3 webm", "RIFF\x10\x00\x00\x00AVI LIST" };
    for (others) |bytes| {
        var decoder = try openDecoder();
        defer decoder.deinit();
        try testing.expectEqual(Result.unsupported, decoder.push(bytes, false));
    }
}

test "an odd-sized unknown chunk is skipped with its pad byte" {
    const a = testing.allocator;
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(a);
    try list.appendSlice(a, "RIFF");
    try appendInt(a, &list, u32, 0); // a wrong RIFF size is not fatal
    try list.appendSlice(a, "WAVE");
    // A LIST chunk of 5 bytes, padded to 6.
    try list.appendSlice(a, "LIST");
    try appendInt(a, &list, u32, 5);
    try list.appendSlice(a, "INFO!");
    try list.append(a, 0);
    // An odd-sized fmt chunk (17 bytes, padded): its extra byte is ignored.
    try list.appendSlice(a, "fmt ");
    try appendInt(a, &list, u32, 17);
    try appendInt(a, &list, u16, format_pcm);
    try appendInt(a, &list, u16, 1);
    try appendInt(a, &list, u32, 1000);
    try appendInt(a, &list, u32, 1000);
    try appendInt(a, &list, u16, 1);
    try appendInt(a, &list, u16, 8);
    try list.appendSlice(a, &.{ 0xEE, 0 });
    try list.appendSlice(a, "data");
    try appendInt(a, &list, u32, 500);
    try list.appendNTimes(a, 0x80, 500);
    // Split at every position: chunk boundaries never change the outcome.
    for (1..list.items.len) |split| {
        var decoder = try openDecoder();
        defer decoder.deinit();
        _ = decoder.push(list.items[0..split], false);
        const outcome = decoder.push(list.items[split..], true);
        try testing.expect(outcome == .current_data);
        try testing.expectEqual(@as(f64, 0.5), outcome.current_data.duration);
    }
}

test "a data chunk before its fmt chunk, or an inconsistent fmt, is a decode error" {
    {
        var decoder = try openDecoder();
        defer decoder.deinit();
        try testing.expectEqual(Result.decode_error, decoder.push("RIFF\x00\x00\x00\x00WAVEdata\x04\x00\x00\x00abcd", true));
    }
    {
        const file = try wavFile(testing.allocator, 2, 8000, 16, 100);
        defer testing.allocator.free(file);
        std.mem.writeInt(u16, file[32..34], 3, .little); // block align should be 4
        var decoder = try openDecoder();
        defer decoder.deinit();
        try testing.expectEqual(Result.decode_error, decoder.push(file, true));
    }
}

test "a WAV decoder has no video: mediaVideoSize never answers" {
    const file = try wavFile(testing.allocator, 1, 8000, 16, 1600);
    defer testing.allocator.free(file);
    var decoder = try openDecoder();
    defer decoder.deinit();
    try testing.expect(decoder.push(file, true) == .current_data);
    var size: platform.VideoSize = .{ .width = 7, .height = 7 };
    try testing.expect(!mediaVideoSize(decoder.handle, 0, &size));
    try testing.expect(!mediaVideoSize(decoder.handle, 0.1, &size));
    try testing.expectEqual(platform.VideoSize{ .width = 7, .height = 7 }, size);
}

test "pushMediaData writes the metadata on metadata and current_data, and nothing else" {
    const file = try wavFile(testing.allocator, 1, 8000, 16, 16000);
    defer testing.allocator.free(file);
    const decoder = try openMediaDecoder(testing.allocator, .from(""));
    defer closeMediaDecoder(decoder);
    var metadata: platform.MediaMetadata = .{ .duration = -1, .width = 9, .height = 9 };
    try testing.expectEqual(platform.MediaResult.need_more, pushMediaData(decoder, .from(file[0..20]), false, &metadata));
    try testing.expectEqual(@as(f64, -1), metadata.duration);
    try testing.expectEqual(platform.MediaResult.metadata, pushMediaData(decoder, .from(file[20..44]), false, &metadata));
    try testing.expectEqual(platform.MediaMetadata{ .duration = 1 }, metadata);
    metadata = .{ .duration = -1 };
    try testing.expectEqual(platform.MediaResult.current_data, pushMediaData(decoder, .from(file[44..]), true, &metadata));
    try testing.expectEqual(platform.MediaMetadata{ .duration = 1 }, metadata);
}

test "mediaCanPlayType is canPlayType, for every Browser alike" {
    var dummy: u8 = 0;
    const browser: *platform.BrowserPlatform = @ptrCast(&dummy);
    try testing.expectEqual(platform.MediaSupport.maybe, mediaCanPlayType(browser, .from("audio/wav")));
    try testing.expectEqual(platform.MediaSupport.probably, mediaCanPlayType(browser, .from("audio/wav; codecs=1")));
    try testing.expectEqual(platform.MediaSupport.unsupported, mediaCanPlayType(browser, .from("video/webm")));
}
