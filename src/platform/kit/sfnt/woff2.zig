//! WOFF 2.0, decoded to the sfnt (or collection) it carries - as Google's
//! woff2 library decodes it (woff2_dec.cc ConvertWOFF2ToTTF), which Blink,
//! Gecko (through OTS) and WebKit all use, so its acceptance is the
//! browsers': the header and its blocks (ReadWOFF2Header), the table
//! directory with its UIntBase128 lengths (ReadTableDirectory), the
//! collection directory, the Brotli stream inflating to exactly the sum of
//! the table lengths, and the glyf, loca and hmtx transforms
//! (ReconstructGlyf, ReconstructTransformedHmtx). Where the library and the
//! WOFF2 Recommendation differ, the library is what ships in all three:
//!
//! - the reserved field is not checked (the Recommendation agrees);
//! - glyf and loca transform versions 1 and 2 read as the null transform,
//!   and hmtx versions 2 and 3 as version 1 (the Recommendation says an
//!   unknown version MUST be rejected; no browser rejects it);
//! - totalSfntSize: Blink refuses 0, a value below the WOFF2 file's own
//!   size, and one above its limit (web_font_decoder.cc), as OTS does
//!   (ots.cc ProcessWOFF2); Gecko's OTS also refuses an sfnt that grows past
//!   it, which Blink and WebKit do not. The majority by mechanism is
//!   Blink's, followed here (golden rule 2): css/WOFF2/header-totalsfntsize-
//!   001.xht, whose value is below the file size, fails in Chrome and
//!   Firefox on wpt.fyi.
//!
//! The decoded sfnt then goes through kit/sfnt's checks, as Blink runs OTS
//! on woff2's output.

const std = @import("std");
const platform = @import("platform");
const bytes = @import("bytes.zig");
const brotli = @import("kit_brotli");
const sfnt = @import("sfnt.zig");

pub const Error = error{ Corrupt, OutOfMemory, TooLarge, UnsupportedFormat };

const tag = bytes.tag;
const Reader = bytes.Reader;

/// WOFF2 4.1's Known Table Tags.
const known_tags = [63]u32{
    tag("cmap"), tag("head"), tag("hhea"), tag("hmtx"), tag("maxp"), tag("name"), tag("OS/2"), tag("post"),
    tag("cvt "), tag("fpgm"), tag("glyf"), tag("loca"), tag("prep"), tag("CFF "), tag("VORG"), tag("EBDT"),
    tag("EBLC"), tag("gasp"), tag("hdmx"), tag("kern"), tag("LTSH"), tag("PCLT"), tag("VDMX"), tag("vhea"),
    tag("vmtx"), tag("BASE"), tag("GDEF"), tag("GPOS"), tag("GSUB"), tag("EBSC"), tag("JSTF"), tag("MATH"),
    tag("CBDT"), tag("CBLC"), tag("COLR"), tag("CPAL"), tag("SVG "), tag("sbix"), tag("acnt"), tag("avar"),
    tag("bdat"), tag("bloc"), tag("bsln"), tag("cvar"), tag("fdsc"), tag("feat"), tag("fmtx"), tag("fvar"),
    tag("gvar"), tag("hsty"), tag("just"), tag("lcar"), tag("mort"), tag("morx"), tag("opbd"), tag("prop"),
    tag("trak"), tag("Zapf"), tag("Silf"), tag("Glat"), tag("Gloc"), tag("Feat"), tag("Sill"),
};

const glyf_tag = tag("glyf");
const loca_tag = tag("loca");
const hmtx_tag = tag("hmtx");
const hhea_tag = tag("hhea");
const head_tag = tag("head");

/// WOFF2 3.1's UIntBase128: no leading zero byte, at most 5 bytes, no
/// overflow.
pub fn readBase128(r: *Reader) bytes.Error!u32 {
    var value: u32 = 0;
    for (0..5) |i| {
        const b = try r.u8_();
        if (i == 0 and b == 0x80) return error.Corrupt;
        if (value & 0xFE000000 != 0) return error.Corrupt;
        value = value << 7 | (b & 0x7f);
        if (b & 0x80 == 0) return value;
    }
    return error.Corrupt;
}

/// WOFF2 3.1's 255UInt16.
pub fn read255UShort(r: *Reader) bytes.Error!u16 {
    const code = try r.u8_();
    return switch (code) {
        253 => try r.u16_(),
        255 => @as(u16, try r.u8_()) + 253,
        254 => @as(u16, try r.u8_()) + 253 * 2,
        else => code,
    };
}

const Table = struct {
    tag: u32,
    transformed: bool,
    /// The table's place in the decompressed stream.
    src_offset: u32,
    src_length: u32,
    /// origLength.
    dst_length: u32,
    /// Where the decoded table landed, once written.
    out_offset: u32 = 0,
    out_length: u32 = 0,
};

const Font = struct {
    flavor: u32,
    indices: []u16,
};

/// The sfnt or collection `data` carries, OWNED by `allocator`. `max_sfnt`
/// bounds totalSfntSize, the decompressed stream and the decoded font.
pub fn decode(allocator: std.mem.Allocator, data: []const u8, max_sfnt: u64) Error![]u8 {
    var r = Reader.init(data);
    if (try r.u32_() != tag("wOF2")) return error.Corrupt;
    const flavor = try r.u32_();
    if (try r.u32_() != data.len) return error.Corrupt;
    const num_tables = try r.u16_();
    if (num_tables == 0) return error.Corrupt;
    try r.skip(2); // reserved: a decoder MUST NOT reject a non-zero value
    const total_sfnt_size = try r.u32_();
    const compressed_length = try r.u32_();
    try r.skip(4); // majorVersion, minorVersion
    const meta_offset = try r.u32_();
    const meta_length = try r.u32_();
    _ = try r.u32_(); // metaOrigLength
    if (meta_offset != 0 and (meta_offset >= data.len or data.len - meta_offset < meta_length)) return error.Corrupt;
    const private_offset = try r.u32_();
    const private_length = try r.u32_();
    if (private_offset != 0 and (private_offset >= data.len or data.len - private_offset < private_length)) return error.Corrupt;

    // Blink's checks of the declared size (web_font_decoder.cc).
    if (total_sfnt_size == 0 or total_sfnt_size < data.len) return error.Corrupt;
    if (total_sfnt_size > max_sfnt) return error.TooLarge;

    // The table directory (ReadTableDirectory).
    if (r.remaining() < num_tables) return error.Corrupt;
    const tables = try allocator.alloc(Table, num_tables);
    defer allocator.free(tables);
    var src_offset: u32 = 0;
    for (tables) |*t| {
        const flag = try r.u8_();
        t.tag = if (flag & 0x3f == 0x3f) try r.u32_() else known_tags[flag & 0x3f];
        const version: u2 = @intCast(flag >> 6);
        t.transformed = if (t.tag == glyf_tag or t.tag == loca_tag) version == 0 else version != 0;
        t.dst_length = try readBase128(&r);
        var transform_length = t.dst_length;
        if (t.transformed) {
            transform_length = try readBase128(&r);
            if (t.tag == loca_tag and transform_length != 0) return error.Corrupt;
        }
        t.src_offset = src_offset;
        t.src_length = transform_length;
        src_offset = std.math.add(u32, src_offset, transform_length) catch return error.Corrupt;
        t.out_offset = 0;
        t.out_length = 0;
    }
    const uncompressed_size = tables[tables.len - 1].src_offset + tables[tables.len - 1].src_length;

    // A collection's directory.
    var collection_version: u32 = 0;
    var fonts: std.ArrayList(Font) = .empty;
    defer {
        for (fonts.items) |f| allocator.free(f.indices);
        fonts.deinit(allocator);
    }
    if (flavor == tag("ttcf")) {
        collection_version = try r.u32_();
        if (collection_version != 0x00010000 and collection_version != 0x00020000) return error.Corrupt;
        const num_fonts = try read255UShort(&r);
        if (num_fonts == 0) return error.Corrupt;
        try fonts.ensureTotalCapacity(allocator, num_fonts);
        for (0..num_fonts) |_| {
            const count = try read255UShort(&r);
            if (count == 0) return error.Corrupt;
            const font_flavor = try r.u32_();
            if (r.remaining() < count) return error.Corrupt;
            const indices = try allocator.alloc(u16, count);
            fonts.appendAssumeCapacity(.{ .flavor = font_flavor, .indices = indices });
            var glyf_index: u16 = 0;
            var loca_index: u16 = 0;
            for (indices) |*index| {
                index.* = try read255UShort(&r);
                if (index.* >= tables.len) return error.Corrupt;
                if (tables[index.*].tag == loca_tag) loca_index = index.*;
                if (tables[index.*].tag == glyf_tag) glyf_index = index.*;
            }
            // glyf and loca are a pair: consecutive entries.
            if (glyf_index > 0 or loca_index > 0) {
                if (glyf_index > loca_index or loca_index - glyf_index != 1) return error.Corrupt;
            }
        }
    } else {
        try fonts.ensureTotalCapacity(allocator, 1);
        const indices = try allocator.alloc(u16, num_tables);
        fonts.appendAssumeCapacity(.{ .flavor = flavor, .indices = indices });
        for (indices, 0..) |*index, i| index.* = @intCast(i);
    }

    // The blocks: compressed data, then the metadata and the private data,
    // each 4-byte aligned, and nothing after the last.
    const compressed_offset = r.pos;
    var block_end = bytes.round4(@as(u64, compressed_offset) + compressed_length);
    if (block_end > data.len) return error.Corrupt;
    if (meta_offset != 0) {
        if (block_end != meta_offset) return error.Corrupt;
        block_end = bytes.round4(@as(u64, meta_offset) + meta_length);
        if (block_end > std.math.maxInt(u32)) return error.Corrupt;
    }
    if (private_offset != 0) {
        if (block_end != private_offset) return error.Corrupt;
        block_end = bytes.round4(@as(u64, private_offset) + private_length);
        if (block_end > std.math.maxInt(u32)) return error.Corrupt;
    }
    if (block_end != bytes.round4(data.len)) return error.Corrupt;

    // woff2's kMaxPlausibleCompressionRatio.
    if (@as(f64, @floatFromInt(uncompressed_size)) / @as(f64, @floatFromInt(data.len)) > 100.0) return error.Corrupt;
    if (uncompressed_size < 1) return error.Corrupt;
    if (uncompressed_size > max_sfnt) return error.TooLarge;

    // The stream inflates to exactly the tables' lengths.
    const stream = try allocator.alloc(u8, uncompressed_size);
    defer allocator.free(stream);
    try decompress(allocator, data[compressed_offset..][0..compressed_length], stream);

    var out: Output = .{ .allocator = allocator, .max = max_sfnt };
    errdefer out.list.deinit(allocator);
    try rebuild(allocator, &out, tables, fonts.items, collection_version, stream);
    return out.list.toOwnedSlice(allocator);
}

/// Brotli, one shot: success with exactly `out.len` bytes (woff2's
/// Woff2Uncompress). Input after the stream's end is not read, as
/// BrotliDecoderDecompress does not read it.
fn decompress(allocator: std.mem.Allocator, input: []const u8, out: []u8) Error!void {
    const decoder = brotli.createBrotliDecoder(allocator) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        // A build without Brotli reads no WOFF2.
        error.NotSupported => error.UnsupportedFormat,
        error.InvalidData => error.Corrupt,
    };
    defer brotli.destroyBrotliDecoder(decoder);
    const progress = brotli.decompressBrotli(decoder, .from(input), out) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.NotSupported => error.UnsupportedFormat,
        error.InvalidData => error.Corrupt,
    };
    if (progress.status != .finished or progress.produced != out.len) return error.Corrupt;
}

/// The decoded font, bounded.
const Output = struct {
    allocator: std.mem.Allocator,
    list: std.ArrayList(u8) = .empty,
    max: u64,

    fn len(self: *const Output) usize {
        return self.list.items.len;
    }

    fn write(self: *Output, data: []const u8) Error!void {
        if (self.list.items.len + data.len > self.max) return error.TooLarge;
        try self.list.appendSlice(self.allocator, data);
    }

    fn zeros(self: *Output, n: usize) Error!void {
        if (self.list.items.len + n > self.max) return error.TooLarge;
        try self.list.appendNTimes(self.allocator, 0, n);
    }

    fn u16_(self: *Output, value: u16) Error!void {
        var b: [2]u8 = undefined;
        std.mem.writeInt(u16, &b, value, .big);
        try self.write(&b);
    }

    fn u32_(self: *Output, value: u32) Error!void {
        var b: [4]u8 = undefined;
        std.mem.writeInt(u32, &b, value, .big);
        try self.write(&b);
    }

    fn pad4(self: *Output) Error!void {
        try self.zeros(@intCast(bytes.round4(self.list.items.len) - self.list.items.len));
    }

    fn put32(self: *Output, at: usize, value: u32) void {
        std.mem.writeInt(u32, self.list.items[at..][0..4], value, .big);
    }
};

/// WriteHeaders and ReconstructFont: the offset tables (sorted by tag), then
/// each font's tables in its order, shared tables written once.
fn rebuild(allocator: std.mem.Allocator, out: *Output, tables: []Table, fonts: []Font, collection_version: u32, stream: []const u8) Error!void {
    const Less = struct {
        tables: []const Table,
        fn less(self: @This(), a: u16, b: u16) bool {
            return self.tables[a].tag < self.tables[b].tag;
        }
    };
    // Where each font's directory entries are, by table index.
    const entry_at = try allocator.alloc(std.ArrayList(struct { index: u16, at: usize }), fonts.len);
    defer {
        for (entry_at) |*list| list.deinit(allocator);
        allocator.free(entry_at);
    }
    for (entry_at) |*list| list.* = .empty;

    var sorted_order: ?[]u16 = null;
    defer if (sorted_order) |s| allocator.free(s);
    if (collection_version != 0) {
        try out.u32_(tag("ttcf"));
        try out.u32_(collection_version);
        try out.u32_(@intCast(fonts.len));
        const offsets_at = out.len();
        try out.zeros(4 * fonts.len);
        if (collection_version == 0x00020000) try out.zeros(12);
        for (fonts, 0..) |*font, i| {
            // A collection's fonts list their tables in tag order.
            std.mem.sort(u16, font.indices, Less{ .tables = tables }, Less.less);
            out.put32(offsets_at + 4 * i, @intCast(out.len()));
            try writeOffsetTable(out, font.flavor, font.indices.len);
            for (font.indices) |index| {
                try entry_at[i].append(allocator, .{ .index = index, .at = out.len() });
                try out.u32_(tables[index].tag);
                try out.zeros(12);
            }
        }
    } else {
        // A single font: its directory sorted by tag, its tables in the
        // WOFF2 order.
        const sorted = try allocator.dupe(u16, fonts[0].indices);
        sorted_order = sorted;
        std.mem.sort(u16, sorted, Less{ .tables = tables }, Less.less);
        try writeOffsetTable(out, fonts[0].flavor, sorted.len);
        for (sorted) |index| {
            try entry_at[0].append(allocator, .{ .index = index, .at = out.len() });
            try out.u32_(tables[index].tag);
            try out.zeros(12);
        }
    }

    const Key = struct { tag: u32, src_offset: u32 };
    var written: std.AutoHashMapUnmanaged(Key, void) = .empty;
    defer written.deinit(allocator);
    for (fonts, 0..) |font, font_index| {
        var glyf_info: ?GlyfInfo = null;
        defer if (glyf_info) |*g| g.deinit(allocator);
        var num_hmetrics: u16 = 0;
        // glyf without loca, or a transform on one of the pair only.
        var glyf: ?*Table = null;
        var loca: ?*Table = null;
        for (font.indices) |index| {
            if (tables[index].tag == glyf_tag) glyf = &tables[index];
            if (tables[index].tag == loca_tag) loca = &tables[index];
        }
        if ((glyf == null) != (loca == null)) return error.Corrupt;
        if (glyf) |g| if (g.transformed != loca.?.transformed) return error.Corrupt;

        for (font.indices) |index| {
            const t = &tables[index];
            const key: Key = .{ .tag = t.tag, .src_offset = t.src_offset };
            const reused = written.contains(key);
            if (font_index == 0 and reused) return error.Corrupt;
            if (@as(u64, t.src_offset) + t.src_length > stream.len) return error.Corrupt;
            const src = stream[t.src_offset..][0..t.src_length];
            if (t.tag == hhea_tag) {
                var h = try Reader.at(src, 34);
                num_hmetrics = try h.u16_();
            }
            if (!reused) {
                const start = out.len();
                if (!t.transformed) {
                    if (t.tag == head_tag and src.len < 12) return error.Corrupt;
                    try out.write(src);
                    // checkSumAdjustment is recomputed below.
                    if (t.tag == head_tag) out.put32(start + 8, 0);
                    t.out_offset = @intCast(start);
                    t.out_length = @intCast(src.len);
                } else if (t.tag == glyf_tag) {
                    glyf_info = try reconstructGlyf(allocator, out, src, t, loca.?);
                } else if (t.tag == loca_tag) {
                    // Written with its glyf, which comes first.
                    if (glyf_info == null) return error.Corrupt;
                } else if (t.tag == hmtx_tag) {
                    const info = glyf_info orelse return error.Corrupt;
                    try reconstructHmtx(out, src, info, num_hmetrics);
                    t.out_offset = @intCast(start);
                    t.out_length = @intCast(out.len() - start);
                } else {
                    return error.Corrupt; // an unknown transform
                }
                try out.pad4();
                try written.put(allocator, key, {});
            }
        }
        for (entry_at[font_index].items) |entry| {
            const t = tables[entry.index];
            const data = out.list.items[t.out_offset..][0..t.out_length];
            out.put32(entry.at + 4, sfnt.checksum(data));
            out.put32(entry.at + 8, t.out_offset);
            out.put32(entry.at + 12, t.out_length);
        }
    }
    // A single font's head.checkSumAdjustment (WOFF2 5); a collection's
    // fonts share tables, and kit/sfnt reads no checksum.
    if (collection_version == 0) {
        for (tables) |t| {
            if (t.tag != head_tag or t.out_length < 12) continue;
            const sum = sfnt.checksum(out.list.items);
            out.put32(t.out_offset + 8, 0xB1B0AFBA -% sum);
        }
    }
}

fn writeOffsetTable(out: *Output, flavor: u32, num_tables: usize) Error!void {
    const n: u16 = @intCast(num_tables);
    var power: u32 = 1;
    var log2: u16 = 0;
    while (power * 2 <= n) : (log2 += 1) power *= 2;
    try out.u32_(flavor);
    try out.u16_(n);
    try out.u16_(@intCast(power * 16));
    try out.u16_(log2);
    try out.u16_(@intCast(@as(u32, n) * 16 - power * 16));
}

const GlyfInfo = struct {
    num_glyphs: u16,
    x_mins: []i16,

    fn deinit(self: *GlyfInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.x_mins);
    }
};

const Point = struct { x: i32, y: i32, on_curve: bool };

/// WOFF2 5.1 and 5.3 (woff2's ReconstructGlyf): the glyf table from its
/// streams, then loca after it.
fn reconstructGlyf(allocator: std.mem.Allocator, out: *Output, src: []const u8, glyf: *Table, loca: *Table) Error!GlyfInfo {
    var r = Reader.init(src);
    _ = try r.u16_(); // reserved
    const option_flags = try r.u16_();
    const num_glyphs = try r.u16_();
    const index_format = try r.u16_();
    // The loca origLength MUST be the size numGlyphs and indexFormat give.
    const expected_loca: u32 = (if (index_format != 0) @as(u32, 4) else 2) * (@as(u32, num_glyphs) + 1);
    if (loca.dst_length != expected_loca) return error.Corrupt;
    var offset: usize = 36;
    if (offset > src.len) return error.Corrupt;
    var streams: [7][]const u8 = undefined;
    for (&streams) |*s| {
        const size = try r.u32_();
        if (size > src.len - offset) return error.Corrupt;
        s.* = src[offset..][0..size];
        offset += size;
    }
    var n_contours = Reader.init(streams[0]);
    var n_points = Reader.init(streams[1]);
    var flags = Reader.init(streams[2]);
    var glyphs = Reader.init(streams[3]);
    var composites = Reader.init(streams[4]);
    var bboxes = Reader.init(streams[5]);
    var instructions = Reader.init(streams[6]);
    var overlap_bitmap: []const u8 = "";
    if (option_flags & 1 != 0) {
        const length = (@as(usize, num_glyphs) + 7) >> 3;
        if (length > src.len - offset) return error.Corrupt;
        overlap_bitmap = src[offset..][0..length];
    }
    const bbox_bitmap = streams[5];
    try bboxes.skip(((@as(usize, num_glyphs) + 31) >> 5) << 2);

    const loca_values = try allocator.alloc(u32, @as(usize, num_glyphs) + 1);
    defer allocator.free(loca_values);
    const x_mins = try allocator.alloc(i16, num_glyphs);
    errdefer allocator.free(x_mins);
    @memset(x_mins, 0);
    var points: std.ArrayList(Point) = .empty;
    defer points.deinit(allocator);
    var contour_points: std.ArrayList(u16) = .empty;
    defer contour_points.deinit(allocator);

    const glyf_start = out.len();
    glyf.out_offset = @intCast(glyf_start);
    for (0..num_glyphs) |i| {
        const have_bbox = bbox_bitmap[i >> 3] & (@as(u8, 0x80) >> @intCast(i & 7)) != 0;
        const contours = try n_contours.u16_();
        const glyph_start = out.len();
        loca_values[i] = @intCast(glyph_start - glyf_start);
        if (contours == 0xffff) {
            // A composite MUST have an explicit bounding box.
            if (!have_bbox) return error.Corrupt;
            var peek = composites;
            var have_instructions = false;
            while (true) {
                const component_flags = try peek.u16_();
                have_instructions = have_instructions or component_flags & (1 << 8) != 0;
                var arguments: usize = 2;
                arguments += if (component_flags & 1 != 0) 4 else 2;
                if (component_flags & (1 << 3) != 0) {
                    arguments += 2;
                } else if (component_flags & (1 << 6) != 0) {
                    arguments += 4;
                } else if (component_flags & (1 << 7) != 0) {
                    arguments += 8;
                }
                try peek.skip(arguments);
                if (component_flags & (1 << 5) == 0) break;
            }
            const composite_size = peek.pos - composites.pos;
            const instruction_size: u16 = if (have_instructions) try read255UShort(&glyphs) else 0;
            try out.u16_(contours);
            try out.write(try bboxes.take(8));
            try out.write(try composites.take(composite_size));
            if (have_instructions) {
                try out.u16_(instruction_size);
                try out.write(try instructions.take(instruction_size));
            }
        } else if (contours > 0) {
            contour_points.clearRetainingCapacity();
            var total: u32 = 0;
            for (0..contours) |_| {
                const count = try read255UShort(&n_points);
                try contour_points.append(allocator, count);
                total += count;
            }
            if (total > flags.remaining()) return error.Corrupt;
            const flag_bytes = try flags.take(total);
            try points.resize(allocator, total);
            glyphs.pos += try tripletDecode(flag_bytes, glyphs.data[glyphs.pos..], points.items);
            const instruction_size = try read255UShort(&glyphs);
            if (total >= 1 << 27) return error.Corrupt;
            try out.u16_(contours);
            if (have_bbox) {
                try out.write(try bboxes.take(8));
            } else {
                try writeBbox(out, points.items);
            }
            var end_point: i32 = -1;
            for (contour_points.items) |count| {
                end_point += count;
                if (end_point >= 65536) return error.Corrupt;
                try out.u16_(@intCast(end_point));
            }
            try out.u16_(instruction_size);
            try out.write(try instructions.take(instruction_size));
            const overlap = option_flags & 1 != 0 and overlap_bitmap[i >> 3] & (@as(u8, 0x80) >> @intCast(i & 7)) != 0;
            try storePoints(out, points.items, overlap);
        } else {
            // An empty glyph MUST NOT have a bounding box.
            if (have_bbox) return error.Corrupt;
        }
        if (contours > 0) {
            // woff2 reads every non-empty glyph's xMin back for hmtx,
            // composites' too (its count is unsigned).
            x_mins[i] = std.mem.readInt(i16, out.list.items[glyph_start + 2 ..][0..2], .big);
        }
        try out.pad4();
    }
    glyf.out_length = @intCast(out.len() - glyf_start);
    loca_values[num_glyphs] = glyf.out_length;
    // loca, in indexFormat, right after glyf.
    loca.out_offset = @intCast(out.len());
    for (loca_values) |value| {
        if (index_format != 0) try out.u32_(value) else try out.u16_(@truncate(value >> 1));
    }
    loca.out_length = @intCast(out.len() - loca.out_offset);
    return .{ .num_glyphs = num_glyphs, .x_mins = x_mins };
}

/// WOFF2 5.2's triplets: each point's flag picks how many bytes its deltas
/// take and how they decode (woff2's TripletDecode). Returns the bytes used.
fn tripletDecode(flags: []const u8, in: []const u8, points: []Point) Error!usize {
    if (points.len > in.len) return error.Corrupt;
    var x: i32 = 0;
    var y: i32 = 0;
    var at: usize = 0;
    for (flags, points) |raw, *point| {
        const flag: u8 = raw & 0x7f;
        const n: usize = if (flag < 84) 1 else if (flag < 120) 2 else if (flag < 124) 3 else 4;
        if (at + n > in.len) return error.Corrupt;
        const b = in[at..][0..n];
        var dx: i32 = 0;
        var dy: i32 = 0;
        if (flag < 10) {
            dy = withSign(flag, (@as(i32, flag & 14) << 7) + b[0]);
        } else if (flag < 20) {
            dx = withSign(flag, (@as(i32, (flag - 10) & 14) << 7) + b[0]);
        } else if (flag < 84) {
            const b0: i32 = flag - 20;
            dx = withSign(flag, 1 + (b0 & 0x30) + (b[0] >> 4));
            dy = withSign(flag >> 1, 1 + ((b0 & 0x0c) << 2) + (b[0] & 0x0f));
        } else if (flag < 120) {
            const b0: i32 = flag - 84;
            dx = withSign(flag, 1 + (@divTrunc(b0, 12) << 8) + b[0]);
            dy = withSign(flag >> 1, 1 + ((@rem(b0, 12) >> 2) << 8) + b[1]);
        } else if (flag < 124) {
            dx = withSign(flag, (@as(i32, b[0]) << 4) + (b[1] >> 4));
            dy = withSign(flag >> 1, (@as(i32, b[1] & 0x0f) << 8) + b[2]);
        } else {
            dx = withSign(flag, (@as(i32, b[0]) << 8) + b[1]);
            dy = withSign(flag >> 1, (@as(i32, b[2]) << 8) + b[3]);
        }
        at += n;
        x = std.math.add(i32, x, dx) catch return error.Corrupt;
        y = std.math.add(i32, y, dy) catch return error.Corrupt;
        point.* = .{ .x = x, .y = y, .on_curve = raw >> 7 == 0 };
    }
    return at;
}

fn withSign(flag: u8, value: i32) i32 {
    return if (flag & 1 != 0) value else -value;
}

/// woff2's ComputeBbox, stored as Int16s.
fn writeBbox(out: *Output, points: []const Point) Error!void {
    var x_min: i32 = 0;
    var y_min: i32 = 0;
    var x_max: i32 = 0;
    var y_max: i32 = 0;
    if (points.len > 0) {
        x_min = points[0].x;
        x_max = points[0].x;
        y_min = points[0].y;
        y_max = points[0].y;
    }
    for (points[1..]) |p| {
        x_min = @min(x_min, p.x);
        x_max = @max(x_max, p.x);
        y_min = @min(y_min, p.y);
        y_max = @max(y_max, p.y);
    }
    for ([_]i32{ x_min, y_min, x_max, y_max }) |v| try out.u16_(@bitCast(@as(i16, @truncate(v))));
}

/// woff2's StorePoints: TrueType flags (repeats folded) and coordinates.
fn storePoints(out: *Output, points: []const Point, overlap: bool) Error!void {
    var last_flag: i32 = -1;
    var repeat: u8 = 0;
    var last_x: i32 = 0;
    var last_y: i32 = 0;
    for (points, 0..) |p, i| {
        var flag: u8 = if (p.on_curve) 1 else 0;
        if (overlap and i == 0) flag |= 1 << 6;
        const dx = p.x - last_x;
        const dy = p.y - last_y;
        if (dx == 0) {
            flag |= 1 << 4;
        } else if (dx > -256 and dx < 256) {
            flag |= (1 << 1) | @as(u8, if (dx > 0) 1 << 4 else 0);
        }
        if (dy == 0) {
            flag |= 1 << 5;
        } else if (dy > -256 and dy < 256) {
            flag |= (1 << 2) | @as(u8, if (dy > 0) 1 << 5 else 0);
        }
        if (flag == last_flag and repeat != 255) {
            out.list.items[out.len() - 1] |= 1 << 3;
            repeat += 1;
        } else {
            if (repeat != 0) try out.write(&.{repeat});
            try out.write(&.{flag});
            repeat = 0;
        }
        last_x = p.x;
        last_y = p.y;
        last_flag = flag;
    }
    if (repeat != 0) try out.write(&.{repeat});
    for ([_]bool{ true, false }) |is_x| {
        var last: i32 = 0;
        for (points) |p| {
            const v = if (is_x) p.x else p.y;
            const d = v - last;
            if (d == 0) {} else if (d > -256 and d < 256) {
                try out.write(&.{@intCast(@abs(d))});
            } else {
                try out.u16_(@bitCast(@as(i16, @truncate(d))));
            }
            last += d;
        }
    }
}

/// WOFF2 5.4 (woff2's ReconstructTransformedHmtx): the advances, and the
/// side bearings the flags say are glyf's xMins.
fn reconstructHmtx(out: *Output, src: []const u8, info: GlyfInfo, num_hmetrics: u16) Error!void {
    var r = Reader.init(src);
    const flags = try r.u8_();
    // Bits 2-7 reserved; a transform with neither bit is no transform.
    if (flags & 0xfc != 0) return error.Corrupt;
    const proportional = flags & 1 == 0;
    const monospace = flags & 2 == 0;
    if (proportional and monospace) return error.Corrupt;
    if (num_hmetrics > info.num_glyphs or num_hmetrics < 1) return error.Corrupt;
    const advances = try r.take(2 * @as(usize, num_hmetrics));
    const lsbs = if (proportional) try r.take(2 * @as(usize, num_hmetrics)) else "";
    const mono = if (monospace) try r.take(2 * (@as(usize, info.num_glyphs) - num_hmetrics)) else "";
    for (0..info.num_glyphs) |i| {
        if (i < num_hmetrics) {
            try out.write(advances[2 * i ..][0..2]);
            if (proportional) try out.write(lsbs[2 * i ..][0..2]) else try out.u16_(@bitCast(info.x_mins[i]));
        } else if (monospace) {
            try out.write(mono[2 * (i - num_hmetrics) ..][0..2]);
        } else {
            try out.u16_(@bitCast(info.x_mins[i]));
        }
    }
}

const testing = std.testing;

test "UIntBase128: no leading zeros, at most five bytes, no overflow" {
    var r = Reader.init(&.{ 0x3f, 0x81, 0x00, 0x8f, 0xff, 0xff, 0xff, 0x7f });
    try testing.expectEqual(@as(u32, 63), try readBase128(&r));
    try testing.expectEqual(@as(u32, 128), try readBase128(&r));
    try testing.expectEqual(@as(u32, 0xffffffff), try readBase128(&r));
    var leading = Reader.init(&.{ 0x80, 0x3f });
    try testing.expectError(error.Corrupt, readBase128(&leading));
    var overflow = Reader.init(&.{ 0x90, 0x80, 0x80, 0x80, 0x00 });
    try testing.expectError(error.Corrupt, readBase128(&overflow));
    var long = Reader.init(&.{ 0x81, 0x80, 0x80, 0x80, 0x80, 0x00 });
    try testing.expectError(error.Corrupt, readBase128(&long));
}

test "255UInt16: every encoding of a value reads the same" {
    // WOFF2 3.1: 506 as [255, 253], [254, 0] and [253, 1, 250].
    var r = Reader.init(&.{ 255, 253, 254, 0, 253, 1, 250, 7 });
    try testing.expectEqual(@as(u16, 506), try read255UShort(&r));
    try testing.expectEqual(@as(u16, 506), try read255UShort(&r));
    try testing.expectEqual(@as(u16, 506), try read255UShort(&r));
    try testing.expectEqual(@as(u16, 7), try read255UShort(&r));
}

test "triplets: the table's byte counts and signs" {
    var points: [3]Point = undefined;
    // Flag 1: dy = +b; flag 10: dx = -b; flag 124: 16-bit dx, dy, signs -, -.
    const used = try tripletDecode(&.{ 1, 10, 124 }, &.{ 5, 7, 0x01, 0x00, 0x00, 0x02 }, &points);
    try testing.expectEqual(@as(usize, 6), used);
    try testing.expectEqual(Point{ .x = 0, .y = 5, .on_curve = true }, points[0]);
    try testing.expectEqual(Point{ .x = -7, .y = 5, .on_curve = true }, points[1]);
    try testing.expectEqual(Point{ .x = -7 - 256, .y = 5 - 2, .on_curve = true }, points[2]);
    try testing.expectError(error.Corrupt, tripletDecode(&.{124}, &.{ 1, 2, 3 }, points[0..1]));
}
