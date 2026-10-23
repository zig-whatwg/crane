//! kit/sfnt: Crane's web font sanitizer and reader, in Zig (decision 20).
//! Every built-in platform runs it on web font data before anything else
//! sees it - as Blink and Gecko run the OpenType Sanitizer first (Blink's
//! DecodeWebFont in web_font_decoder.cc, Gecko's
//! gfxUserFontEntry::SanitizeOpenTypeData) - so which fonts load is the same
//! on every platform; the testing and linux platforms also describe faces
//! with it, and darwin takes its metrics from CoreText.
//!
//! | Format | Read by | Checked as |
//! |---|---|---|
//! | sfnt (TrueType, OpenType CFF, 'true') | sfnt.zig, tables.zig | OTS ProcessTTF, ProcessGeneric and the per-table sanitizers of the tables a face needs |
//! | collection ('ttcf' 1.0, 2.0) | sfnt.zig | OTS ProcessTTC; every face checked, as OTS checks every face Blink loads |
//! | WOFF 1.0 | woff.zig, over kit/inflate | OTS ProcessWOFF in full |
//! | WOFF 2.0, and WOFF2 collections | woff2.zig, over kit/brotli | the WOFF2 Recommendation's decoder requirements |
//!
//! What OTS checks that kit/sfnt does not is listed at tables.zig: the
//! tables a face does not need. A collection's face is the one whose
//! PostScript name the caller gives, else the first (protocol `decodeFont`).

const std = @import("std");
const platform = @import("platform");
const bytes = @import("bytes.zig");
pub const sfnt = @import("sfnt.zig");
pub const tables = @import("tables.zig");
const names = @import("names.zig");
const describe_ = @import("describe.zig");
const woff = @import("woff.zig");
const woff2 = @import("woff2.zig");
pub const caseless = @import("caseless.zig");

const tag = bytes.tag;
const FontError = platform.FontError;

/// The protocol's decodeFont, on kit/sfnt alone (the testing and linux
/// platforms).
pub fn decodeFont(allocator: std.mem.Allocator, data: platform.Bytes, postscript_name: platform.Str, limits: platform.FontLimits) FontError!platform.DecodedFont {
    const decoded = try decode(allocator, data.slice(), postscript_name.slice(), limits, .{});
    return decoded.font;
}

pub const Options = struct {
    /// Also return the chosen face as a standalone sfnt (darwin hands it to
    /// CoreText).
    standalone: bool = false,
};

pub const Decoded = struct {
    font: platform.DecodedFont,
    /// OWNED: the chosen face's tables as a standalone sfnt, when asked.
    standalone: ?[]u8 = null,
};

/// Validate one web font resource and describe the face it gives.
pub fn decode(allocator: std.mem.Allocator, data: []const u8, postscript_name: []const u8, limits: platform.FontLimits, options: Options) FontError!Decoded {
    if (data.len > limits.max_bytes or data.len > sfnt.max_file) return error.TooLarge;
    if (data.len < 4) return error.UnsupportedFormat;
    const magic = std.mem.readInt(u32, data[0..4], .big);
    var unwrapped: ?[]u8 = null;
    defer if (unwrapped) |u| allocator.free(u);
    const font_data: []const u8 = if (sfnt.isSfntVersion(magic) or magic == tag("ttcf"))
        data
    else if (magic == tag("wOFF")) blk: {
        unwrapped = try woff.decode(allocator, data, limits.max_sfnt_bytes);
        break :blk unwrapped.?;
    } else if (magic == tag("wOF2")) blk: {
        unwrapped = try woff2.decode(allocator, data, limits.max_sfnt_bytes);
        break :blk unwrapped.?;
    } else return error.UnsupportedFormat;
    return decodeSfnt(allocator, font_data, postscript_name, options) catch |err| switch (err) {
        error.Corrupt => error.Corrupt,
        error.OutOfMemory => error.OutOfMemory,
    };
}

fn decodeSfnt(allocator: std.mem.Allocator, data: []const u8, postscript_name: []const u8, options: Options) (error{ Corrupt, OutOfMemory })!Decoded {
    var single = [_]u32{0};
    var collection: ?[]u32 = null;
    defer if (collection) |c| allocator.free(c);
    const offsets: []const u32 = if (std.mem.readInt(u32, data[0..4], .big) == tag("ttcf")) blk: {
        collection = try sfnt.collectionOffsets(allocator, data);
        break :blk collection.?;
    } else &single;
    if (offsets.len == 0) return error.Corrupt;

    // Every face is checked (OTS processes a whole collection); the one
    // the PostScript name selects, else the first, is described.
    var chosen: usize = 0;
    var matched = false;
    for (offsets, 0..) |offset, i| {
        var face = try sfnt.parseFace(allocator, data, offset);
        defer face.deinit(allocator);
        const checked = try tables.check(allocator, face);
        if (!matched and postscript_name.len > 0 and describe_.hasPostScriptName(checked, postscript_name)) {
            chosen = i;
            matched = true;
        }
    }
    var face = try sfnt.parseFace(allocator, data, offsets[chosen]);
    defer face.deinit(allocator);
    const checked = try tables.check(allocator, face);
    var font = try describe_.describe(allocator, checked, try describe_.metrics(allocator, checked));
    errdefer font.deinit(allocator);
    font.matched_name = matched;
    const standalone = if (options.standalone) try sfnt.writeStandalone(allocator, face) else null;
    return .{ .font = font, .standalone = standalone };
}

/// An installed font file's face `index`, checked and described (the
/// linux platform's installed and generic faces). Corrupt when the file
/// does not hold that face, or it does not check.
pub fn describeFile(allocator: std.mem.Allocator, data: []const u8, index: u32) FontError!platform.DecodedFont {
    return describeFileInner(allocator, data, index) catch |err| switch (err) {
        error.Corrupt => error.Corrupt,
        error.OutOfMemory => error.OutOfMemory,
    };
}

fn describeFileInner(allocator: std.mem.Allocator, data: []const u8, index: u32) (error{ Corrupt, OutOfMemory })!platform.DecodedFont {
    if (data.len < 4) return error.Corrupt;
    var offset: u32 = 0;
    if (std.mem.readInt(u32, data[0..4], .big) == tag("ttcf")) {
        const offsets = try sfnt.collectionOffsets(allocator, data);
        defer allocator.free(offsets);
        if (index >= offsets.len) return error.Corrupt;
        offset = offsets[index];
    } else if (index != 0) return error.Corrupt;
    var face = try sfnt.parseFace(allocator, data, offset);
    defer face.deinit(allocator);
    const checked = try tables.check(allocator, face);
    return describe_.describe(allocator, checked, try describe_.metrics(allocator, checked));
}

/// A face given as its tables (darwin reads an installed face's tables
/// from CoreText): checked and described, `face_metrics` in place of the
/// tables' own when given.
pub fn describeTables(allocator: std.mem.Allocator, face: sfnt.Face, face_metrics: ?platform.FontMetrics) FontError!platform.DecodedFont {
    const checked = tables.check(allocator, face) catch |err| return switch (err) {
        error.Corrupt => error.Corrupt,
        error.OutOfMemory => error.OutOfMemory,
    };
    const m = face_metrics orelse describe_.metrics(allocator, checked) catch |err| return switch (err) {
        error.Corrupt => error.Corrupt,
        error.OutOfMemory => error.OutOfMemory,
    };
    return describe_.describe(allocator, checked, m) catch |err| switch (err) {
        error.Corrupt => error.Corrupt,
        error.OutOfMemory => error.OutOfMemory,
    };
}

test {
    _ = bytes;
    _ = sfnt;
    _ = tables;
    _ = names;
    _ = caseless;
    _ = woff;
    _ = woff2;
}

pub const Traits = describe_.Traits;
pub const traitsFromOs2 = describe_.traitsFromOs2;
pub const fromParts = describe_.fromParts;
