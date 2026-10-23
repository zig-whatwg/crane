//! A face's tables, checked as the OpenType Sanitizer checks the ones a face
//! needs (OTS head.cc, maxp.cc, os2.cc, cmap.cc, metrics.cc, hhea.cc,
//! vhea.cc, name.cc, post.cc, loca.cc, glyf.cc and cff.cc), and read into
//! the values a description needs - the values OTS's sanitized output holds,
//! which is what Blink and Gecko hand their font engines: a negative hhea
//! ascent or line gap reads 0, as do a negative sTypoLineGap, sxHeight and
//! sCapHeight; usWeightClass is clamped to 1-1000 and usWidthClass to 1-9.
//!
//! What is checked is what OTS fails a font for in these tables. What is not
//! (documented in kit/sfnt's root): hinting and instructions beyond their
//! lengths (cvt, fpgm, prep), the layout tables (GDEF, GPOS, GSUB - Blink
//! passes them through to HarfBuzz), the variation tables, the color and
//! bitmap tables, kern, hdmx, VDMX, LTSH, gasp and VORG, and CFF charstrings,
//! FDSelect and Private DICTs: an optional table OTS would fail passes here.
//! Crane draws nothing, so a damaged optional table harms nothing.

const std = @import("std");
const bytes = @import("bytes.zig");
const sfnt = @import("sfnt.zig");

pub const Error = error{ Corrupt, OutOfMemory };

const tag = bytes.tag;
const Reader = bytes.Reader;

pub const Outlines = enum { truetype, cff, cff2, bitmap };

/// hhea's or vhea's metrics (OTS OpenTypeMetricsHeader).
pub const MetricsHeader = struct {
    ascent: i16,
    descent: i16,
    line_gap: i16,
    num_metrics: u16,
};

/// The OS/2 values a description reads.
pub const Os2 = struct {
    version: u16,
    weight_class: u16,
    width_class: u16,
    selection: u16,
    typo_ascender: i16,
    typo_descender: i16,
    typo_line_gap: i16,
    win_ascent: u16,
    win_descent: u16,
    /// 0 below version 2 (absent).
    x_height: i16 = 0,
    cap_height: i16 = 0,
};

/// A Unicode cmap subtable a lookup reads (format 4 or 12).
pub const Subtable = struct {
    format: u16,
    data: []const u8,
};

/// A face, checked: what it needs to be described.
pub const Checked = struct {
    num_glyphs: u16,
    units_per_em: u16,
    index_to_loc_format: i16,
    hhea: MetricsHeader,
    hmtx: []const u8,
    vertical: ?struct { header: MetricsHeader, vmtx: []const u8 } = null,
    os2: Os2,
    name: []const u8,
    /// The best Unicode subtables, best first (fontTools' getBestCmap
    /// order): a full-repertoire format 12, then a BMP format 4.
    cmap: [2]?Subtable = .{ null, null },
    loca: ?[]const u8 = null,
    glyf: ?[]const u8 = null,
    outlines: Outlines,
};

/// OTS ProcessGeneric's table checks for one face, in OTS's order: the
/// required tables (maxp, head, OS/2, cmap, hhea, hmtx, name, post), loca and
/// glyf, CFF and CFF2, vhea and vmtx; then that the face has glyph data.
pub fn check(allocator: std.mem.Allocator, face: sfnt.Face) Error!Checked {
    const maxp = try checkMaxp(face.find(tag("maxp")) orelse return error.Corrupt);
    const head = try checkHead(face.find(tag("head")) orelse return error.Corrupt);
    const os2 = try checkOs2(face.find(tag("OS/2")) orelse return error.Corrupt);
    const cmap_table = face.find(tag("cmap")) orelse return error.Corrupt;
    const cmap = try checkCmap(allocator, cmap_table, maxp.num_glyphs);
    const hhea = try checkMetricsHeader(face.find(tag("hhea")) orelse return error.Corrupt, maxp.num_glyphs, .horizontal);
    const hmtx = face.find(tag("hmtx")) orelse return error.Corrupt;
    try checkMetrics(hmtx, hhea.num_metrics, maxp.num_glyphs);
    const name = face.find(tag("name")) orelse return error.Corrupt;
    try checkName(name);
    try checkPost(face.find(tag("post")) orelse return error.Corrupt, maxp.num_glyphs);

    var checked: Checked = .{
        .num_glyphs = maxp.num_glyphs,
        .units_per_em = head.units_per_em,
        .index_to_loc_format = head.index_to_loc_format,
        .hhea = hhea,
        .hmtx = hmtx,
        .os2 = os2,
        .name = name,
        .cmap = cmap,
        .outlines = .truetype,
    };

    const loca = face.find(tag("loca"));
    const glyf = face.find(tag("glyf"));
    if (loca) |l| try checkLoca(l, maxp.num_glyphs, head.index_to_loc_format);
    if (glyf) |g| {
        // OTS's glyf parser needs loca: without it, the table fails.
        const l = loca orelse return error.Corrupt;
        try checkGlyf(allocator, g, l, maxp.num_glyphs, head.index_to_loc_format);
    }
    const cff = face.find(tag("CFF "));
    const cff2 = face.find(tag("CFF2"));
    if (cff) |c| try checkCff(c, maxp.num_glyphs);
    if (cff2) |c| try checkCff2(c);
    const vhea_table = face.find(tag("vhea"));
    const vmtx = face.find(tag("vmtx"));
    if (vhea_table) |v| {
        const vhea = try checkMetricsHeader(v, maxp.num_glyphs, .vertical);
        if (vmtx) |m| {
            try checkMetrics(m, vhea.num_metrics, maxp.num_glyphs);
            checked.vertical = .{ .header = vhea, .vmtx = m };
        }
    } else if (vmtx != null) {
        // OTS's vmtx parser needs vhea: without it, the table fails.
        return error.Corrupt;
    }

    // OTS: glyph data - glyf and loca (with a version 1.0 maxp), else CFF or
    // CFF2, else a bitmap-only font; anything else fails.
    if (glyf != null and loca != null) {
        if (!maxp.version_1) return error.Corrupt;
        checked.loca = loca;
        checked.glyf = glyf;
        checked.outlines = .truetype;
    } else if (cff != null) {
        checked.outlines = .cff;
    } else if (cff2 != null) {
        checked.outlines = .cff2;
    } else if ((face.find(tag("CBDT")) != null and face.find(tag("CBLC")) != null) or
        (face.find(tag("EBDT")) != null and face.find(tag("EBLC")) != null))
    {
        checked.outlines = .bitmap;
    } else {
        return error.Corrupt;
    }
    return checked;
}

// ---------------------------------------------------------------------------
// maxp, head, OS/2
// ---------------------------------------------------------------------------

const Maxp = struct { num_glyphs: u16, version_1: bool };

/// OTS maxp.cc: version 0.5 or 1.0, numGlyphs at least 1. A version 1.0 table
/// too short for its fields is read as 0.5.
fn checkMaxp(data: []const u8) Error!Maxp {
    var r = Reader.init(data);
    const version = try r.u32_();
    if (version >> 16 > 1) return error.Corrupt;
    const num_glyphs = try r.u16_();
    if (num_glyphs == 0) return error.Corrupt;
    if (version == 0x00005000) return .{ .num_glyphs = num_glyphs, .version_1 = false };
    return .{ .num_glyphs = num_glyphs, .version_1 = r.remaining() >= 13 * 2 };
}

const Head = struct { units_per_em: u16, index_to_loc_format: i16 };

/// OTS head.cc.
fn checkHead(data: []const u8) Error!Head {
    var r = Reader.init(data);
    const version = try r.u32_();
    _ = try r.u32_(); // fontRevision
    if (version >> 16 != 1) return error.Corrupt;
    try r.skip(4); // checksumAdjustment
    if (try r.u32_() != 0x5F0F3CF5) return error.Corrupt;
    _ = try r.u16_(); // flags
    const units_per_em = try r.u16_();
    if (units_per_em < 16 or units_per_em > 16384) return error.Corrupt;
    try r.skip(16); // created, modified
    const x_min = try r.i16_();
    const y_min = try r.i16_();
    const x_max = try r.i16_();
    const y_max = try r.i16_();
    if (x_min > x_max or y_min > y_max) return error.Corrupt;
    _ = try r.u16_(); // macStyle
    _ = try r.u16_(); // lowestRecPPEM
    try r.skip(2); // fontDirectionHint
    const index_to_loc_format = try r.i16_();
    if (index_to_loc_format < 0 or index_to_loc_format > 1) return error.Corrupt;
    if (try r.i16_() != 0) return error.Corrupt; // glyphDataFormat
    return .{ .units_per_em = units_per_em, .index_to_loc_format = index_to_loc_format };
}

/// OTS os2.cc. A table too short for its version's fields is read as the
/// version its length allows (OTS's "weird version" fixes) - except where
/// OTS fails it: the code page ranges or the version 2 or 5 fields cut short.
fn checkOs2(data: []const u8) Error!Os2 {
    var r = Reader.init(data);
    var os2: Os2 = undefined;
    os2.version = try r.u16_();
    _ = try r.i16_(); // xAvgCharWidth
    os2.weight_class = try r.u16_();
    os2.width_class = try r.u16_();
    try r.skip(2 + 11 * 2); // fsType, the sub/superscript and strikeout fields, sFamilyClass
    if (os2.version > 5) return error.Corrupt;
    os2.weight_class = std.math.clamp(os2.weight_class, 1, 1000);
    os2.width_class = std.math.clamp(os2.width_class, 1, 9);
    try r.skip(10 + 16 + 4); // panose, ulUnicodeRange1-4, achVendID
    os2.selection = try r.u16_();
    try r.skip(4); // usFirstCharIndex, usLastCharIndex
    os2.typo_ascender = try r.i16_();
    os2.typo_descender = try r.i16_();
    os2.typo_line_gap = @max(try r.i16_(), 0);
    os2.win_ascent = try r.u16_();
    os2.win_descent = try r.u16_();
    // fsSelection: REGULAR clears ITALIC and BOLD; bits 10-15 are reserved.
    if (os2.selection & 0x40 != 0) os2.selection &= 0xffde;
    os2.selection &= 0x3ff;
    os2.x_height = 0;
    os2.cap_height = 0;
    if (os2.version < 1) return os2;
    // OTS compares lengths with its C struct's field offsets.
    if (data.len < 84) {
        os2.version = 0;
        return os2;
    }
    try r.skip(8); // ulCodePageRange1-2
    if (os2.version < 2) return os2;
    if (data.len < 96) {
        os2.version = 1;
        return os2;
    }
    os2.x_height = @max(try r.i16_(), 0);
    os2.cap_height = @max(try r.i16_(), 0);
    try r.skip(6); // usDefaultChar, usBreakChar, usMaxContext
    if (os2.version < 5) return os2;
    try r.skip(4); // usLower/UpperOpticalPointSize
    return os2;
}

// ---------------------------------------------------------------------------
// hhea, vhea, hmtx, vmtx
// ---------------------------------------------------------------------------

const Direction = enum { horizontal, vertical };

/// OTS hhea.cc / vhea.cc and OpenTypeMetricsHeader.
fn checkMetricsHeader(data: []const u8, num_glyphs: u16, direction: Direction) Error!MetricsHeader {
    var r = Reader.init(data);
    const version = try r.u32_();
    switch (direction) {
        .horizontal => if (version >> 16 != 1) return error.Corrupt,
        .vertical => if (version != 0x00010000 and version != 0x00011000) return error.Corrupt,
    }
    var header: MetricsHeader = undefined;
    header.ascent = @max(try r.i16_(), 0);
    header.descent = try r.i16_();
    header.line_gap = @max(try r.i16_(), 0);
    try r.skip(7 * 2 + 8); // advanceMax ... caretOffset, reserved
    if (try r.i16_() != 0) return error.Corrupt; // metricDataFormat
    header.num_metrics = try r.u16_();
    if (header.num_metrics > num_glyphs) return error.Corrupt;
    return header;
}

/// OTS OpenTypeMetricsTable: numberOfMetrics (advance, side bearing) pairs,
/// then a side bearing for every other glyph.
fn checkMetrics(data: []const u8, num_metrics: u16, num_glyphs: u16) Error!void {
    if (num_metrics == 0) return error.Corrupt;
    const needed = @as(usize, num_metrics) * 4 + @as(usize, num_glyphs - num_metrics) * 2;
    if (data.len < needed) return error.Corrupt;
}

/// A glyph's advance in hmtx or vmtx: the last advance repeats for the
/// glyphs past numberOfMetrics.
pub fn advance(metrics: []const u8, num_metrics: u16, glyph: u16) u16 {
    const index = @min(glyph, num_metrics - 1);
    return bytes.u16At(metrics, @as(usize, index) * 4) catch unreachable;
}

// ---------------------------------------------------------------------------
// name, post
// ---------------------------------------------------------------------------

/// OTS name.cc: format 0 or 1, every record readable, format 1's language
/// tags in range, and the strings after the records. Records with an
/// unknown platform or encoding, or strings outside the table, are skipped
/// (names.zig), as OTS discards them.
fn checkName(data: []const u8) Error!void {
    var r = Reader.init(data);
    const format = try r.u16_();
    if (format > 1) return error.Corrupt;
    const count = try r.u16_();
    const string_offset = try r.u16_();
    if (string_offset > data.len) return error.Corrupt;
    try r.skip(@as(usize, count) * 12);
    if (format == 1) {
        const tag_count = try r.u16_();
        for (0..tag_count) |_| {
            const tag_length = try r.u16_();
            const tag_offset = try r.u16_();
            if (@as(usize, string_offset) + tag_offset + tag_length > data.len) return error.Corrupt;
            if (tag_length > 100 * 2) return error.Corrupt;
        }
    }
    if (r.pos > string_offset) return error.Corrupt;
}

/// OTS post.cc: version 1, 2 or 3; a version 2 table's glyph names in range.
fn checkPost(data: []const u8, num_glyphs: u16) Error!void {
    var r = Reader.init(data);
    const version = try r.u32_();
    if (version != 0x00010000 and version != 0x00020000 and version != 0x00030000) return error.Corrupt;
    try r.skip(4 + 2 + 2 + 4 + 16);
    if (version != 0x00020000) return;
    const count = try r.u16_();
    if (count == 0) {
        if (num_glyphs > 258) return error.Corrupt;
        return; // OTS reads it as version 1.
    }
    if (count != num_glyphs) return error.Corrupt;
    const indexes = try r.take(@as(usize, count) * 2);
    // The Pascal strings: each within the table, with no NUL in it.
    var strings: usize = 0;
    var s = r.pos;
    while (s != data.len) {
        const length = data[s];
        if (s + 1 + length > data.len) return error.Corrupt;
        if (std.mem.indexOfScalar(u8, data[s + 1 ..][0..length], 0) != null) return error.Corrupt;
        s += 1 + length;
        strings += 1;
    }
    var i: usize = 0;
    while (i < indexes.len) : (i += 2) {
        const index = std.mem.readInt(u16, indexes[i..][0..2], .big);
        if (index >= 258 and index - 258 >= strings) return error.Corrupt;
    }
}

// ---------------------------------------------------------------------------
// cmap
// ---------------------------------------------------------------------------

const Header = struct { platform: u16, encoding: u16, offset: u32, format: u16 = 0, length: u32 = 0 };

/// OTS cmap.cc: version 0, at least one subtable, offsets and lengths in
/// the table, subtables not overlapping (two may share exactly), and each
/// subtable OTS reads - (0,0|1|3,4), (3,0|1,4), (0,3|4,12), (3,10,12),
/// (3,10,13), (0,5,14), (1,0,0) - valid. Returns the subtables a Unicode
/// lookup uses.
fn checkCmap(allocator: std.mem.Allocator, data: []const u8, num_glyphs: u16) Error![2]?Subtable {
    var r = Reader.init(data);
    if (try r.u16_() != 0) return error.Corrupt;
    const count = try r.u16_();
    if (count == 0) return error.Corrupt;
    if (r.remaining() / 8 < count) return error.Corrupt;
    const headers = try allocator.alloc(Header, count);
    defer allocator.free(headers);
    for (headers) |*h| h.* = .{ .platform = try r.u16_(), .encoding = try r.u16_(), .offset = try r.u32_() };
    const data_offset = r.pos;
    for (headers) |h| {
        if (h.offset > sfnt.max_file or h.offset < data_offset or h.offset >= data.len) return error.Corrupt;
    }
    for (headers) |*h| {
        var s = try Reader.at(data, h.offset);
        h.format = try s.u16_();
        switch (h.format) {
            0, 4 => {
                h.length = try s.u16_();
                _ = try s.u16_(); // language
            },
            12, 13 => {
                try s.skip(2);
                h.length = try s.u32_();
                _ = try s.u32_(); // language
            },
            14 => h.length = try s.u32_(),
            else => h.length = 0,
        }
    }
    for (headers) |h| {
        if (h.length == 0) continue;
        if (h.length > sfnt.max_file) return error.Corrupt;
        if (@as(u64, h.offset) + h.length > data.len) return error.Corrupt;
    }
    // Overlap: identical ranges may repeat (a Unicode and a Windows
    // subtable often share their data); any other overlap fails.
    const Edge = struct {
        at: u64,
        start: u1,
        fn less(_: void, a: @This(), b: @This()) bool {
            return a.at < b.at or (a.at == b.at and a.start < b.start);
        }
    };
    var edges: std.ArrayList(Edge) = .empty;
    defer edges.deinit(allocator);
    for (headers, 0..) |h, i| {
        const end = @as(u64, h.offset) + h.length;
        const repeated = for (headers[0..i]) |earlier| {
            if (earlier.offset == h.offset and @as(u64, earlier.offset) + earlier.length == end) break true;
        } else false;
        if (repeated) continue;
        try edges.append(allocator, .{ .at = h.offset, .start = 1 });
        try edges.append(allocator, .{ .at = end, .start = 0 });
    }
    std.mem.sort(Edge, edges.items, {}, Edge.less);
    var open: i32 = 0;
    for (edges.items) |edge| {
        open += if (edge.start == 1) 1 else -1;
        if (open > 1) return error.Corrupt;
    }

    var full: ?Subtable = null; // format 12
    var full_rank: u8 = 0;
    var bmp: ?Subtable = null; // format 4
    var bmp_rank: u8 = 0;
    for (headers) |h| {
        const sub = data[h.offset..][0..@intCast(if (h.length != 0) h.length else data.len - h.offset)];
        switch (h.platform) {
            0 => {
                if ((h.encoding == 0 or h.encoding == 1 or h.encoding == 3) and h.format == 4) {
                    try checkFormat4(sub, num_glyphs);
                    const rank: u8 = if (h.encoding == 3) 2 else 1;
                    if (rank > bmp_rank) {
                        bmp = .{ .format = 4, .data = sub };
                        bmp_rank = rank;
                    }
                } else if ((h.encoding == 3 or h.encoding == 4) and h.format == 12) {
                    try checkFormat12(sub, num_glyphs);
                    if (full_rank < 1) {
                        full = .{ .format = 12, .data = sub };
                        full_rank = 1;
                    }
                } else if (h.encoding == 5 and h.format == 14) {
                    try checkFormat14(sub);
                }
            },
            1 => if (h.encoding == 0 and h.format == 0) {
                if (sub.len < 262) return error.Corrupt;
            },
            3 => switch (h.encoding) {
                0, 1 => if (h.format == 4) {
                    try checkFormat4(sub, num_glyphs);
                    // (3,0) is a symbol font's: not a Unicode lookup.
                    if (h.encoding == 1 and bmp_rank < 3) {
                        bmp = .{ .format = 4, .data = sub };
                        bmp_rank = 3;
                    }
                },
                10 => if (h.format == 12) {
                    try checkFormat12(sub, num_glyphs);
                    full = .{ .format = 12, .data = sub };
                    full_rank = 2;
                } else if (h.format == 13) {
                    try checkFormat13(sub, num_glyphs);
                },
                else => {},
            },
            else => {},
        }
    }
    return .{ full, bmp };
}

/// OTS ParseFormat4: language 0; segCountX2 and searchRange even and the
/// search fields exact; segments in order, ending with 0xFFFF; every code
/// point's glyph below numGlyphs.
fn checkFormat4(data: []const u8, num_glyphs: u16) Error!void {
    var r = Reader.init(data);
    try r.skip(4);
    if (try r.u16_() != 0) return error.Corrupt; // language
    const seg_count_x2 = try r.u16_();
    const search_range = try r.u16_();
    const entry_selector = try r.u16_();
    const range_shift = try r.u16_();
    if (seg_count_x2 & 1 != 0 or search_range & 1 != 0) return error.Corrupt;
    const seg_count = seg_count_x2 >> 1;
    if (seg_count < 1) return error.Corrupt;
    var log2: u16 = 0;
    while (@as(u32, 1) << @intCast(log2 + 1) <= seg_count) log2 += 1;
    if (search_range != @as(u32, 2) << @intCast(log2)) return error.Corrupt;
    if (entry_selector != log2) return error.Corrupt;
    if (range_shift != seg_count_x2 -% search_range) return error.Corrupt;
    const ends = try r.take(seg_count_x2);
    if (try r.u16_() != 0) return error.Corrupt; // reservedPad
    const starts = try r.take(seg_count_x2);
    const deltas = try r.take(seg_count_x2);
    const range_offsets_at = r.pos;
    const range_offsets = try r.take(seg_count_x2);
    const segment = struct {
        fn get(table: []const u8, i: usize) u16 {
            return std.mem.readInt(u16, table[2 * i ..][0..2], .big);
        }
    }.get;
    for (0..seg_count) |i| {
        if (segment(range_offsets, i) & 1 != 0 and i != seg_count - 1) return error.Corrupt;
    }
    for (1..seg_count) |i| {
        if (i == seg_count - 1 and segment(starts, i - 1) == 0xffff and segment(ends, i - 1) == 0xffff and
            segment(starts, i) == 0xffff and segment(ends, i) == 0xffff) continue;
        if (segment(ends, i) <= segment(ends, i - 1)) return error.Corrupt;
        if (segment(starts, i) <= segment(ends, i - 1)) return error.Corrupt;
    }
    if (segment(starts, seg_count - 1) != 0xffff or segment(ends, seg_count - 1) != 0xffff) return error.Corrupt;
    for (0..seg_count) |i| {
        const start = segment(starts, i);
        const end = segment(ends, i);
        const delta = segment(deltas, i);
        var range_offset = segment(range_offsets, i);
        // OTS's one fix: an odd offset in the final segment reads as 0.
        if (range_offset & 1 != 0) range_offset = 0;
        var cp: u32 = start;
        while (cp <= end) : (cp += 1) {
            const glyph: u16 = if (range_offset == 0)
                @as(u16, @truncate(cp)) +% delta
            else blk: {
                const at = range_offsets_at + 2 * i + range_offset + (cp - start) * 2;
                if (at + 1 >= data.len) return error.Corrupt;
                break :blk std.mem.readInt(u16, data[at..][0..2], .big);
            };
            if (glyph >= num_glyphs) return error.Corrupt;
        }
    }
}

/// OTS Parse31012: language 0; groups present, within Unicode, in order,
/// not overlapping, their glyphs below numGlyphs.
fn checkFormat12(data: []const u8, num_glyphs: u16) Error!void {
    var r = Reader.init(data);
    try r.skip(8);
    if (try r.u32_() != 0) return error.Corrupt;
    const groups = try r.u32_();
    if (groups == 0 or r.remaining() / 12 < groups) return error.Corrupt;
    var previous_start: u32 = 0;
    var previous_end: u32 = 0;
    for (0..groups) |i| {
        const start = try r.u32_();
        const end = try r.u32_();
        const glyph = try r.u32_();
        if (start > 0x10FFFF or end > 0x10FFFF or glyph > 0xFFFF) return error.Corrupt;
        if (end < start) return error.Corrupt;
        if (@as(u64, end - start) + glyph >= num_glyphs) return error.Corrupt;
        if (i > 0 and (start <= previous_start or start <= previous_end)) return error.Corrupt;
        previous_start = start;
        previous_end = end;
    }
}

/// OTS Parse31013: as format 12, each group mapping its range to one glyph.
fn checkFormat13(data: []const u8, num_glyphs: u16) Error!void {
    var r = Reader.init(data);
    try r.skip(8);
    if (try r.u32_() != 0) return error.Corrupt;
    const groups = try r.u32_();
    if (groups == 0 or r.remaining() / 12 < groups) return error.Corrupt;
    var previous_end: u32 = 0;
    for (0..groups) |i| {
        const start = try r.u32_();
        const end = try r.u32_();
        const glyph = try r.u32_();
        if (start > 0x10FFFF or end > 0x10FFFF or glyph >= num_glyphs) return error.Corrupt;
        if (end < start) return error.Corrupt;
        if (i > 0 and start <= previous_end) return error.Corrupt;
        previous_end = end;
    }
}

/// OTS Parse0514: the variation selector records in order and in range,
/// and their default and non-default tables in range and in order.
fn checkFormat14(data: []const u8) Error!void {
    var r = Reader.init(data);
    try r.skip(2);
    const length = try r.u32_();
    if (length > data.len) return error.Corrupt;
    const table = data[0..length];
    const records = try r.u32_();
    if (records == 0 or records > 256 or r.remaining() / 11 < records) return error.Corrupt;
    var previous: u32 = 0;
    for (0..records) |i| {
        const selector = try r.u24_();
        const default_offset = try r.u32_();
        const non_default_offset = try r.u32_();
        if (selector > 0x10FFFF) return error.Corrupt;
        if (i > 0 and selector <= previous) return error.Corrupt;
        previous = selector;
        if (default_offset == 0 and non_default_offset == 0) return error.Corrupt;
        if (default_offset != 0) {
            var d = try Reader.at(table, default_offset);
            const ranges = try d.u32_();
            if (ranges == 0 or d.remaining() / 4 < ranges) return error.Corrupt;
            var last: u32 = 0;
            for (0..ranges) |j| {
                const start = try d.u24_();
                const extra = try d.u8_();
                if (start + extra > 0x10FFFF) return error.Corrupt;
                if (j > 0 and start <= last) return error.Corrupt;
                last = start + extra;
            }
        }
        if (non_default_offset != 0) {
            var n = try Reader.at(table, non_default_offset);
            const mappings = try n.u32_();
            if (mappings == 0 or n.remaining() / 5 < mappings) return error.Corrupt;
            var last: u32 = 0;
            for (0..mappings) |j| {
                const code = try n.u24_();
                _ = try n.u16_();
                if (code > 0x10FFFF) return error.Corrupt;
                if (j > 0 and code <= last) return error.Corrupt;
                last = code;
            }
        }
    }
}

/// The glyph `code_point` maps to through the face's Unicode subtables, or
/// null (glyph 0, .notdef, is no glyph).
pub fn glyphFor(checked: Checked, code_point: u21) ?u16 {
    for (checked.cmap) |maybe| {
        const sub = maybe orelse continue;
        const glyph = switch (sub.format) {
            12 => lookup12(sub.data, code_point),
            else => if (code_point <= 0xFFFF) lookup4(sub.data, @intCast(code_point)) else null,
        };
        if (glyph) |g| {
            if (g != 0) return g;
        }
    }
    return null;
}

fn lookup4(data: []const u8, code_point: u16) ?u16 {
    const seg_count = (bytes.u16At(data, 6) catch return null) >> 1;
    const ends = 14;
    const starts = ends + 2 * @as(usize, seg_count) + 2;
    const deltas = starts + 2 * @as(usize, seg_count);
    const offsets = deltas + 2 * @as(usize, seg_count);
    for (0..seg_count) |i| {
        const end = bytes.u16At(data, ends + 2 * i) catch return null;
        if (code_point > end) continue;
        const start = bytes.u16At(data, starts + 2 * i) catch return null;
        if (code_point < start) return null;
        const delta = bytes.u16At(data, deltas + 2 * i) catch return null;
        var range_offset = bytes.u16At(data, offsets + 2 * i) catch return null;
        if (range_offset & 1 != 0) range_offset = 0;
        if (range_offset == 0) return code_point +% delta;
        const at = offsets + 2 * i + range_offset + 2 * @as(usize, code_point - start);
        const glyph = bytes.u16At(data, at) catch return null;
        return if (glyph == 0) 0 else glyph +% delta;
    }
    return null;
}

fn lookup12(data: []const u8, code_point: u21) ?u16 {
    const groups = bytes.u32At(data, 12) catch return null;
    for (0..groups) |i| {
        const at = 16 + 12 * i;
        const start = bytes.u32At(data, at) catch return null;
        const end = bytes.u32At(data, at + 4) catch return null;
        if (code_point < start or code_point > end) continue;
        const glyph = bytes.u32At(data, at + 8) catch return null;
        return @intCast(glyph + (code_point - start));
    }
    return null;
}

// ---------------------------------------------------------------------------
// loca, glyf
// ---------------------------------------------------------------------------

/// OTS loca.cc: numGlyphs + 1 offsets in the head's format, never
/// decreasing.
fn checkLoca(data: []const u8, num_glyphs: u16, format: i16) Error!void {
    var last: u32 = 0;
    for (0..@as(usize, num_glyphs) + 1) |i| {
        const offset: u32 = if (format == 0) @as(u32, try bytes.u16At(data, 2 * i)) * 2 else try bytes.u32At(data, 4 * i);
        if (offset < last) return error.Corrupt;
        last = offset;
    }
}

/// Glyph `glyph`'s data in glyf: OTS GetGlyphBufferSection.
pub fn glyphData(glyf: []const u8, loca: []const u8, format: i16, glyph: u16) Error![]const u8 {
    const start: u32 = if (format == 0) @as(u32, try bytes.u16At(loca, 2 * @as(usize, glyph))) * 2 else try bytes.u32At(loca, 4 * @as(usize, glyph));
    const end: u32 = if (format == 0) @as(u32, try bytes.u16At(loca, 2 * (@as(usize, glyph) + 1))) * 2 else try bytes.u32At(loca, 4 * (@as(usize, glyph) + 1));
    const length = end - start; // checkLoca: never decreasing
    if (length == 0) return glyf[0..0];
    if (start >= glyf.len or @as(u64, start) + length > glyf.len) return error.Corrupt;
    return glyf[start..][0..length];
}

const ARG_1_AND_2_ARE_WORDS = 1 << 0;
const WE_HAVE_A_SCALE = 1 << 3;
const MORE_COMPONENTS = 1 << 5;
const WE_HAVE_AN_X_AND_Y_SCALE = 1 << 6;
const WE_HAVE_A_TWO_BY_TWO = 1 << 7;
const WE_HAVE_INSTRUCTIONS = 1 << 8;

/// OTS glyf.cc: every glyph's header, a simple glyph's contours, flags and
/// coordinates within its data, a composite's components in range and their
/// nesting and point total at most 0xFFFF.
fn checkGlyf(allocator: std.mem.Allocator, glyf: []const u8, loca: []const u8, num_glyphs: u16, format: i16) Error!void {
    for (0..num_glyphs) |i| {
        const glyph = try glyphData(glyf, loca, format, @intCast(i));
        if (glyph.len == 0) continue;
        var r = Reader.init(glyph);
        const contours = try r.i16_();
        var x_min = try r.i16_();
        var y_min = try r.i16_();
        var x_max = try r.i16_();
        var y_max = try r.i16_();
        if (contours <= -2) return error.Corrupt;
        if (x_min == 32767 and x_max == -32767 and y_min == 32767 and y_max == -32767) {
            x_min = 0;
            x_max = 0;
            y_min = 0;
            y_max = 0;
        }
        if (x_min > x_max or y_min > y_max) return error.Corrupt;
        if (contours == 0) continue;
        if (contours > 0) {
            _ = try simpleGlyph(allocator, glyph);
        } else {
            try compositeGlyph(glyph, num_glyphs);
            try countComponentPoints(allocator, glyf, loca, format, glyph);
        }
    }
}

/// A simple glyph (OTS ParseSimpleGlyph): its contour ends increasing, its
/// instructions, flags and coordinates within its data. Returns the highest
/// point's y - the outline top a missing x-height or cap-height is measured
/// from, as FreeType's control box gives Skia and Gecko (OTS widens a header
/// bbox that misses a point, so the points are what counts).
pub fn simpleGlyph(allocator: std.mem.Allocator, glyph: []const u8) Error!i32 {
    var r = Reader.init(glyph);
    const contours: u16 = @intCast(try r.i16_());
    try r.skip(8);
    var num_points: u32 = 0;
    for (0..contours) |i| {
        const end = try r.u16_();
        if (end == 0xffff) return error.Corrupt;
        if (i > 0 and @as(u32, end) + 1 <= num_points) return error.Corrupt;
        num_points = @as(u32, end) + 1;
    }
    const instructions = try r.u16_();
    try r.skip(instructions);
    const flags = try allocator.alloc(u8, num_points);
    defer allocator.free(flags);
    var coordinates: u32 = 0;
    var i: u32 = 0;
    while (i < num_points) : (i += 1) {
        const flag = try r.u8_();
        var delta: u32 = 0;
        if (flag & 0x02 != 0) delta += 1 else if (flag & 0x10 == 0) delta += 2;
        if (flag & 0x04 != 0) delta += 1 else if (flag & 0x20 == 0) delta += 2;
        if (flag & 0x40 != 0 and i != 0) return error.Corrupt;
        flags[i] = flag & ~@as(u8, 0x08);
        if (flag & 0x08 != 0) {
            if (i + 1 >= num_points) return error.Corrupt;
            const repeat = try r.u8_();
            if (repeat == 0) return error.Corrupt;
            delta += delta * repeat;
            if (i + repeat >= num_points) return error.Corrupt;
            for (0..repeat) |_| {
                i += 1;
                flags[i] = flag & ~@as(u8, 0x08);
            }
        }
        if (flag & 0x80 != 0) return error.Corrupt;
        coordinates += delta;
        if (glyph.len < coordinates) return error.Corrupt;
    }
    for (flags) |flag| {
        if (flag & 0x02 != 0) {
            _ = try r.u8_();
        } else if (flag & 0x10 == 0) {
            _ = try r.i16_();
        }
    }
    var y: i32 = 0;
    var top: i32 = std.math.minInt(i32);
    for (flags) |flag| {
        if (flag & 0x04 != 0) {
            const dy = try r.u8_();
            y += if (flag & 0x20 != 0) @as(i32, dy) else -@as(i32, dy);
        } else if (flag & 0x20 == 0) {
            y += try r.i16_();
        }
        // OTS's coordinates are int16_t and wrap.
        y = @as(i16, @truncate(y));
        top = @max(top, y);
    }
    return top;
}

/// OTS ParseCompositeGlyph: each component's flags, glyph (below numGlyphs),
/// arguments and transform readable; instructions after the last.
fn compositeGlyph(glyph: []const u8, num_glyphs: u16) Error!void {
    var r = Reader.init(glyph);
    try r.skip(10);
    var instructions = false;
    var components: u32 = 0;
    while (true) {
        components += 1;
        if (components > 0x7fff) return; // OTS drops the glyph's data
        const flags = try r.u16_();
        const component = try r.u16_();
        if (component >= num_glyphs) return error.Corrupt;
        try r.skip(if (flags & ARG_1_AND_2_ARE_WORDS != 0) 4 else 2);
        if (flags & WE_HAVE_A_SCALE != 0) {
            try r.skip(2);
        } else if (flags & WE_HAVE_AN_X_AND_Y_SCALE != 0) {
            try r.skip(4);
        } else if (flags & WE_HAVE_A_TWO_BY_TWO != 0) {
            try r.skip(8);
        }
        instructions = instructions or flags & WE_HAVE_INSTRUCTIONS != 0;
        if (flags & MORE_COMPONENTS == 0) break;
    }
    if (instructions) {
        const length = try r.u16_();
        try r.skip(length);
    }
}

/// OTS TraverseComponentsCountingPoints: the components of a composite,
/// nested, are at most 0xFFFF levels deep and add up to at most 0xFFFF
/// points. Bounded here also in the work it does: a component graph that
/// would make more visits than any font needs is Corrupt.
fn countComponentPoints(allocator: std.mem.Allocator, glyf: []const u8, loca: []const u8, format: i16, root: []const u8) Error!void {
    const Pending = struct { glyph: u16, level: u32 };
    var stack: std.ArrayList(Pending) = .empty;
    defer stack.deinit(allocator);
    try pushComponents(allocator, &stack, root, 1);
    var points: u32 = 0;
    var visits: u32 = 0;
    while (stack.pop()) |pending| {
        visits += 1;
        if (visits > 1 << 20) return error.Corrupt;
        const data = try glyphData(glyf, loca, format, pending.glyph);
        if (data.len == 0) continue;
        if (data.len < 10) return error.Corrupt;
        const contours = try bytes.i16At(data, 0);
        if (contours <= -2) return error.Corrupt;
        if (contours >= 0) {
            if (contours > 0) {
                const last_end = try bytes.u16At(data, 10 + 2 * (@as(usize, @intCast(contours)) - 1));
                points += @as(u32, last_end) + 1;
                if (points > 0xffff) return error.Corrupt;
            }
            continue;
        }
        if (pending.level > 0xffff) return error.Corrupt;
        try pushComponents(allocator, &stack, data, pending.level + 1);
    }
}

fn pushComponents(allocator: std.mem.Allocator, stack: anytype, glyph: []const u8, level: u32) Error!void {
    var r = Reader.init(glyph);
    try r.skip(10);
    while (true) {
        const flags = try r.u16_();
        const component = try r.u16_();
        try stack.append(allocator, .{ .glyph = component, .level = level });
        try r.skip(if (flags & ARG_1_AND_2_ARE_WORDS != 0) 4 else 2);
        if (flags & WE_HAVE_A_SCALE != 0) {
            try r.skip(2);
        } else if (flags & WE_HAVE_AN_X_AND_Y_SCALE != 0) {
            try r.skip(4);
        } else if (flags & WE_HAVE_A_TWO_BY_TWO != 0) {
            try r.skip(8);
        }
        if (flags & MORE_COMPONENTS == 0) break;
    }
}

/// The top of glyph `glyph`'s outline, or null for an empty glyph. A
/// composite's is its header's yMax (OTS adjusts only simple glyphs).
pub fn outlineTop(allocator: std.mem.Allocator, checked: Checked, glyph: u16) Error!?i32 {
    const glyf = checked.glyf orelse return null;
    const loca = checked.loca orelse return null;
    const data = try glyphData(glyf, loca, checked.index_to_loc_format, glyph);
    if (data.len == 0) return null;
    const contours = try bytes.i16At(data, 0);
    if (contours == 0) return null;
    if (contours < 0) return try bytes.i16At(data, 8);
    return try simpleGlyph(allocator, data);
}

// ---------------------------------------------------------------------------
// CFF, CFF2
// ---------------------------------------------------------------------------

/// A CFF INDEX (OTS ParseIndex): count, offSize 1-4, offsets from 1, never
/// decreasing, within the table. Returns the offset just past it and each
/// object's bounds through `objects` when asked.
const Index = struct { count: u32, data_start: usize, offsets_at: usize, off_size: u8, next: usize };

fn readIndex(table: []const u8, at: usize) Error!Index {
    var r = try Reader.at(table, at);
    const count = try r.u16_();
    if (count == 0) return .{ .count = 0, .data_start = r.pos, .offsets_at = r.pos, .off_size = 0, .next = r.pos };
    const off_size = try r.u8_();
    if (off_size < 1 or off_size > 4) return error.Corrupt;
    const offsets_at = r.pos;
    const array_size = (@as(usize, count) + 1) * off_size;
    const data_start = r.pos + array_size;
    if (data_start >= table.len) return error.Corrupt;
    var previous: usize = 0;
    var last: usize = 0;
    for (0..@as(usize, count) + 1) |i| {
        var offset: u32 = 0;
        for (0..off_size) |_| offset = offset << 8 | try r.u8_();
        if (offset < 1) return error.Corrupt;
        if (i == 0 and offset != 1) return error.Corrupt;
        if (offset > table.len) return error.Corrupt;
        if (data_start > table.len - (offset - 1)) return error.Corrupt;
        const absolute = data_start + offset - 1;
        if (i > 0 and absolute < previous) return error.Corrupt;
        previous = absolute;
        last = absolute;
    }
    return .{ .count = count, .data_start = data_start, .offsets_at = offsets_at, .off_size = off_size, .next = last };
}

fn indexObject(table: []const u8, index: Index, i: usize) Error![]const u8 {
    const read = struct {
        fn at(t: []const u8, idx: Index, n: usize) Error!usize {
            var r = try Reader.at(t, idx.offsets_at + n * idx.off_size);
            var offset: u32 = 0;
            for (0..idx.off_size) |_| offset = offset << 8 | try r.u8_();
            return idx.data_start + offset - 1;
        }
    }.at;
    const start = try read(table, index, i);
    const end = try read(table, index, i + 1);
    return bytes.slice(table, start, end - start);
}

/// OTS cff.cc's structure: the header (1.0, hdrSize 4, offSize 1-4), a Name
/// INDEX of one, a Top DICT INDEX of one, the String INDEX, the Global
/// Subrs INDEX, and the Top DICT's CharStrings INDEX holding one charstring
/// per glyph. The charstrings themselves are not checked.
fn checkCff(table: []const u8, num_glyphs: u16) Error!void {
    var r = Reader.init(table);
    const major = try r.u8_();
    const minor = try r.u8_();
    const header_size = try r.u8_();
    const off_size = try r.u8_();
    if (off_size < 1 or off_size > 4) return error.Corrupt;
    if (major != 1 or minor != 0) return error.Corrupt;
    if (header_size != 4 or header_size >= table.len) return error.Corrupt;
    const names = try readIndex(table, header_size);
    if (names.count != 1) return error.Corrupt;
    const top = try readIndex(table, names.next);
    if (top.count != 1) return error.Corrupt;
    const strings = try readIndex(table, top.next);
    if (strings.count >= 65000 - 391) return error.Corrupt;
    _ = try readIndex(table, strings.next); // Global Subrs
    const charstrings_at = try topDictCharStrings(try indexObject(table, top, 0));
    if (charstrings_at == 0 or charstrings_at >= table.len) return error.Corrupt;
    const charstrings = try readIndex(table, charstrings_at);
    if (charstrings.count != num_glyphs) return error.Corrupt;
}

/// The CharStrings operand (operator 17) of a Top DICT (CFF 4: DICT data).
fn topDictCharStrings(dict: []const u8) Error!usize {
    var operands: [48]i64 = undefined;
    var count: usize = 0;
    var i: usize = 0;
    var charstrings: usize = 0;
    while (i < dict.len) {
        const b0 = dict[i];
        i += 1;
        if (b0 <= 21) {
            var op: u16 = b0;
            if (b0 == 12) {
                if (i >= dict.len) return error.Corrupt;
                op = 0x0c00 | @as(u16, dict[i]);
                i += 1;
            }
            if (op == 17) {
                if (count < 1 or operands[count - 1] < 0) return error.Corrupt;
                charstrings = @intCast(operands[count - 1]);
            }
            count = 0;
            continue;
        }
        if (count == operands.len) return error.Corrupt;
        const value: i64 = switch (b0) {
            28 => blk: {
                if (i + 2 > dict.len) return error.Corrupt;
                defer i += 2;
                break :blk std.mem.readInt(i16, dict[i..][0..2], .big);
            },
            29 => blk: {
                if (i + 4 > dict.len) return error.Corrupt;
                defer i += 4;
                break :blk std.mem.readInt(i32, dict[i..][0..4], .big);
            },
            30 => blk: {
                // A real: nibbles to 0xf.
                while (true) {
                    if (i >= dict.len) return error.Corrupt;
                    const b = dict[i];
                    i += 1;
                    if (b >> 4 == 0xf or b & 0xf == 0xf) break;
                }
                break :blk 0;
            },
            32...246 => @as(i64, b0) - 139,
            247...250 => blk: {
                if (i >= dict.len) return error.Corrupt;
                defer i += 1;
                break :blk (@as(i64, b0) - 247) * 256 + dict[i] + 108;
            },
            251...254 => blk: {
                if (i >= dict.len) return error.Corrupt;
                defer i += 1;
                break :blk -(@as(i64, b0) - 251) * 256 - dict[i] - 108;
            },
            else => return error.Corrupt,
        };
        operands[count] = value;
        count += 1;
    }
    return charstrings;
}

/// CFF2: Blink passes it through unchecked; its header is checked here.
fn checkCff2(table: []const u8) Error!void {
    var r = Reader.init(table);
    const major = try r.u8_();
    const minor = try r.u8_();
    const header_size = try r.u8_();
    _ = try r.u16_(); // topDictLength
    if (major != 2 or minor != 0 or header_size < 5 or header_size > table.len) return error.Corrupt;
}

const testing = std.testing;

test "maxp: numGlyphs at least 1, version 0.5 or 1.0" {
    try testing.expectError(error.Corrupt, checkMaxp(&.{ 0, 0, 0x50, 0, 0, 0 }));
    const half = try checkMaxp(&.{ 0, 0, 0x50, 0, 0, 3 });
    try testing.expectEqual(@as(u16, 3), half.num_glyphs);
    try testing.expect(!half.version_1);
    try testing.expectError(error.Corrupt, checkMaxp(&.{ 0, 2, 0, 0, 0, 3 }));
}

test "head: the magic number and unitsPerEm's range" {
    var head = [_]u8{0} ** 54;
    head[1] = 1;
    std.mem.writeInt(u32, head[12..16], 0x5F0F3CF5, .big);
    std.mem.writeInt(u16, head[18..20], 1000, .big);
    _ = try checkHead(&head);
    std.mem.writeInt(u16, head[18..20], 15, .big);
    try testing.expectError(error.Corrupt, checkHead(&head));
    std.mem.writeInt(u16, head[18..20], 1000, .big);
    std.mem.writeInt(u32, head[12..16], 0, .big);
    try testing.expectError(error.Corrupt, checkHead(&head));
}
