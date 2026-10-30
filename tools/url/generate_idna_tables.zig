//! Generate Unicode 17.0.0 IDNA tables (the version of WPT's IdnaTestV2.json).
//! Fetch the five URLs in inputs below into a scratch directory, then run:
//! zig build idna-tables -j2 -- <input-directory> <output-file>
//! The usual output is src/url/idna/unicode_data.zig. Inputs are hash pinned.
const std = @import("std");
const Allocator = std.mem.Allocator;
const IdnaStatus = enum { valid, ignored, mapped, deviation, disallowed, disallowed_std3_valid, disallowed_std3_mapped };
const BidiClass = enum { L, R, AL, EN, ES, ET, AN, CS, NSM, BN, B, S, WS, ON, LRE, LRO, RLE, RLO, PDF, LRI, RLI, FSI, PDI };
const JoiningType = enum { U, L, R, D, C, T };
const Range = struct { start: u21, end: u21 };
const IdnaMapping = struct { start: u21, end: u21, status: IdnaStatus, mapping: ?[]const u8 };
const BidiRange = struct { start: u21, end: u21, class: BidiClass };
const JoiningRange = struct { start: u21, end: u21, class: JoiningType };
const DecompositionMapping = struct { codepoint: u21, decomposition: []const u21 };
const CompositionPair = struct { first: u21, second: u21, composed: u21 };
const CombiningClass = struct { codepoint: u21, class: u8 };
const PropertyRecord = struct { start: u21, end: u21, property: []const u8, extra: []const u8 };
const UnicodeData = struct {
    decompositions: []DecompositionMapping,
    compositions: []CompositionPair,
    combining_classes: []CombiningClass,
    marks: []u21,
    fn deinit(self: *UnicodeData, a: Allocator) void {
        for (self.decompositions) |d| a.free(d.decomposition);
        a.free(self.decompositions);
        a.free(self.compositions);
        a.free(self.combining_classes);
        a.free(self.marks);
    }
};
const Input = struct { name: []const u8, url: []const u8, sha256: []const u8 };
const inputs = [_]Input{
    .{ .name = "IdnaMappingTable.txt", .url = "https://www.unicode.org/Public/17.0.0/idna/IdnaMappingTable.txt", .sha256 = "87f05505dc026fdb2bff16132bdc68a8014675836882a9a2b1844540ad3be382" },
    .{ .name = "DerivedBidiClass.txt", .url = "https://www.unicode.org/Public/17.0.0/ucd/extracted/DerivedBidiClass.txt", .sha256 = "4867b4b7f0731ed1bfcd34cc6251211ff1542541fce0734b6fbda139ee80b3a4" },
    .{ .name = "UnicodeData.txt", .url = "https://www.unicode.org/Public/17.0.0/ucd/UnicodeData.txt", .sha256 = "2e1efc1dcb59c575eedf5ccae60f95229f706ee6d031835247d843c11d96470c" },
    .{ .name = "DerivedNormalizationProps.txt", .url = "https://www.unicode.org/Public/17.0.0/ucd/DerivedNormalizationProps.txt", .sha256 = "71fd6a206a2c0cdd41feb6b7f656aa31091db45e9cedc926985d718397f9e488" },
    .{ .name = "DerivedJoiningType.txt", .url = "https://www.unicode.org/Public/17.0.0/ucd/extracted/DerivedJoiningType.txt", .sha256 = "f39ebe974825d6736aee15582250307aa532b2cfab3caf3f86bd23fddc9c5c4d" },
};
fn trim(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \t\r");
}
fn parseRange(s: []const u8) !Range {
    const split = std.mem.indexOf(u8, s, "..");
    const start = try std.fmt.parseInt(u21, if (split) |i| s[0..i] else s, 16);
    const end = if (split) |i| try std.fmt.parseInt(u21, s[i + 2 ..], 16) else start;
    if (start > end or end > 0x10ffff) return error.InvalidRange;
    return .{ .start = start, .end = end };
}
fn parsePropertyLine(line: []const u8) !?PropertyRecord {
    const content = trim(line[0 .. std.mem.indexOfScalar(u8, line, '#') orelse line.len]);
    if (content.len == 0) return null;
    var fields = std.mem.splitScalar(u8, content, ';');
    const range = try parseRange(trim(fields.next().?));
    const property = trim(fields.next() orelse return error.InvalidProperty);
    return .{ .start = range.start, .end = range.end, .property = property, .extra = trim(fields.next() orelse "") };
}
fn freeMappings(a: Allocator, mappings: []IdnaMapping) void {
    for (mappings) |m| if (m.mapping) |s| a.free(s);
    a.free(mappings);
}
fn parseIdnaMappings(a: Allocator, text: []const u8) ![]IdnaMapping {
    var list: std.ArrayList(IdnaMapping) = .empty;
    errdefer {
        for (list.items) |m| if (m.mapping) |s| a.free(s);
        list.deinit(a);
    }
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        const r = (try parsePropertyLine(line)) orelse continue;
        const status = std.meta.stringToEnum(IdnaStatus, r.property) orelse return error.InvalidStatus;
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(a);
        var parts = std.mem.tokenizeAny(u8, r.extra, " \t");
        while (parts.next()) |part| {
            const cp = try std.fmt.parseInt(u21, part, 16);
            var bytes: [4]u8 = undefined;
            const len = try std.unicode.utf8Encode(cp, &bytes);
            try encoded.appendSlice(a, bytes[0..len]);
        }
        const mapping = if (encoded.items.len != 0) try encoded.toOwnedSlice(a) else null;
        errdefer if (mapping) |s| a.free(s);
        try list.append(a, .{ .start = r.start, .end = r.end, .status = status, .mapping = mapping });
    }
    return list.toOwnedSlice(a);
}
fn parseUnicodeData(a: Allocator, text: []const u8) !UnicodeData {
    var decompositions: std.ArrayList(DecompositionMapping) = .empty;
    errdefer {
        for (decompositions.items) |d| a.free(d.decomposition);
        decompositions.deinit(a);
    }
    var compositions: std.ArrayList(CompositionPair) = .empty;
    errdefer compositions.deinit(a);
    var classes: std.ArrayList(CombiningClass) = .empty;
    errdefer classes.deinit(a);
    var marks: std.ArrayList(u21) = .empty;
    errdefer marks.deinit(a);
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var fields = std.mem.splitScalar(u8, line, ';');
        const cp = try std.fmt.parseInt(u21, fields.next().?, 16);
        _ = fields.next() orelse return error.InvalidUnicodeData;
        const category = fields.next() orelse return error.InvalidUnicodeData;
        const cc = try std.fmt.parseInt(u8, fields.next() orelse return error.InvalidUnicodeData, 10);
        _ = fields.next() orelse return error.InvalidUnicodeData;
        const decomp = fields.next() orelse return error.InvalidUnicodeData;
        if (category.len != 2) return error.InvalidUnicodeData;
        if (category[0] == 'M') try marks.append(a, cp);
        if (cc != 0) try classes.append(a, .{ .codepoint = cp, .class = cc });
        if (decomp.len == 0 or decomp[0] == '<') continue;
        var cps: std.ArrayList(u21) = .empty;
        defer cps.deinit(a);
        var parts = std.mem.tokenizeScalar(u8, decomp, ' ');
        while (parts.next()) |part| try cps.append(a, try std.fmt.parseInt(u21, part, 16));
        if (cps.items.len == 2) try compositions.append(a, .{ .first = cps.items[0], .second = cps.items[1], .composed = cp });
        const owned = try cps.toOwnedSlice(a);
        errdefer a.free(owned);
        try decompositions.append(a, .{ .codepoint = cp, .decomposition = owned });
    }
    std.mem.sort(CompositionPair, compositions.items, {}, struct {
        fn less(_: void, x: CompositionPair, y: CompositionPair) bool {
            return x.first < y.first or (x.first == y.first and x.second < y.second);
        }
    }.less);
    const ds = try decompositions.toOwnedSlice(a);
    errdefer {
        for (ds) |d| a.free(d.decomposition);
        a.free(ds);
    }
    const cs = try compositions.toOwnedSlice(a);
    errdefer a.free(cs);
    const ccs = try classes.toOwnedSlice(a);
    errdefer a.free(ccs);
    return .{ .decompositions = ds, .compositions = cs, .combining_classes = ccs, .marks = try marks.toOwnedSlice(a) };
}
fn parseExclusions(a: Allocator, text: []const u8) ![]Range {
    var list: std.ArrayList(Range) = .empty;
    errdefer list.deinit(a);
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        const r = (try parsePropertyLine(line)) orelse continue;
        if (std.mem.eql(u8, r.property, "Full_Composition_Exclusion")) try list.append(a, .{ .start = r.start, .end = r.end });
    }
    return list.toOwnedSlice(a);
}
fn bidiClass(s: []const u8) !BidiClass {
    if (std.mem.eql(u8, s, "Left_To_Right")) return .L;
    if (std.mem.eql(u8, s, "Right_To_Left")) return .R;
    if (std.mem.eql(u8, s, "Arabic_Letter")) return .AL;
    if (std.mem.eql(u8, s, "European_Terminator")) return .ET;
    return std.meta.stringToEnum(BidiClass, s) orelse error.InvalidBidiClass;
}
fn parseBidiClasses(a: Allocator, text: []const u8) ![]BidiRange {
    const classes = try a.alloc(BidiClass, 0x110000);
    defer a.free(classes);
    @memset(classes, .L);
    // Defaults may overlap; later, narrower @missing records override the global default.
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| if (std.mem.indexOf(u8, line, "@missing:")) |i| {
        const r = (try parsePropertyLine(line[i + 9 ..])).?;
        @memset(classes[r.start .. @as(usize, r.end) + 1], try bidiClass(r.property));
    };
    lines.reset();
    while (lines.next()) |line| {
        const r = (try parsePropertyLine(line)) orelse continue;
        @memset(classes[r.start .. @as(usize, r.end) + 1], try bidiClass(r.property));
    }
    var list: std.ArrayList(BidiRange) = .empty;
    errdefer list.deinit(a);
    var start: usize = 0;
    while (start < classes.len) {
        var end = start + 1;
        while (end < classes.len and classes[end] == classes[start]) : (end += 1) {}
        if (classes[start] != .L) try list.append(a, .{ .start = @intCast(start), .end = @intCast(end - 1), .class = classes[start] });
        start = end;
    }
    return list.toOwnedSlice(a);
}
fn parseJoiningTypes(a: Allocator, text: []const u8) ![]JoiningRange {
    var list: std.ArrayList(JoiningRange) = .empty;
    errdefer list.deinit(a);
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        const r = (try parsePropertyLine(line)) orelse continue;
        try list.append(a, .{ .start = r.start, .end = r.end, .class = std.meta.stringToEnum(JoiningType, r.property) orelse return error.InvalidJoiningType });
    }
    std.mem.sort(JoiningRange, list.items, {}, struct {
        fn less(_: void, x: JoiningRange, y: JoiningRange) bool {
            return x.start < y.start;
        }
    }.less);
    return list.toOwnedSlice(a);
}
fn lookupRange(comptime T: type, ranges: []const T, cp: u21, default: @FieldType(T, "class")) @FieldType(T, "class") {
    var low: usize = 0;
    var high = ranges.len;
    while (low < high) {
        const mid = low + (high - low) / 2;
        const r = ranges[mid];
        if (cp < r.start) high = mid else if (cp > r.end) low = mid + 1 else return r.class;
    }
    return default;
}
/// Regenerate the pinned data; this step never downloads files.
pub fn main(init: std.process.Init) !void {
    const a = init.gpa;
    var args = try init.minimal.args.iterateAllocator(a);
    defer args.deinit();
    _ = args.next();
    const input_dir = args.next() orelse return error.InputDirectoryRequired;
    const output_path = args.next() orelse return error.OutputPathRequired;
    if (args.next() != null) return error.TooManyArguments;
    var contents: [inputs.len][]u8 = undefined;
    var read: usize = 0;
    defer for (contents[0..read]) |s| a.free(s);
    for (inputs, 0..) |input, i| {
        const path = try std.fs.path.join(a, &.{ input_dir, input.name });
        defer a.free(path);
        const file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
        defer file.close(init.io);
        var reader = file.reader(init.io, &.{});
        contents[i] = try reader.interface.allocRemaining(a, .limited(8 * 1024 * 1024));
        read += 1;
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(contents[i], &hash, .{});
        if (!std.mem.eql(u8, &std.fmt.bytesToHex(hash, .lower), input.sha256)) return error.InputHashMismatch;
    }
    const mappings = try parseIdnaMappings(a, contents[0]);
    defer freeMappings(a, mappings);
    const bidi = try parseBidiClasses(a, contents[1]);
    defer a.free(bidi);
    var unicode = try parseUnicodeData(a, contents[2]);
    defer unicode.deinit(a);
    const exclusions = try parseExclusions(a, contents[3]);
    defer a.free(exclusions);
    const joining = try parseJoiningTypes(a, contents[4]);
    defer a.free(joining);
    var output: std.Io.Writer.Allocating = .init(a);
    defer output.deinit();
    const w = &output.writer;
    try w.writeAll("//! Generated by tools/url/generate_idna_tables.zig; DO NOT EDIT.\n//! Unicode 17.0.0, matching WPT's url/resources/IdnaTestV2.json.\n//! Regenerate: zig build idna-tables -j2 -- <input-directory> src/url/idna/unicode_data.zig\n");
    for (inputs) |input| try w.print("//! {s}\n//! SHA256: {s}\n", .{ input.url, input.sha256 });
    try w.writeAll(license);
    try w.writeAll(declarations);
    try w.writeAll("pub const idna_mappings = [_]IdnaMapping{\n");
    for (mappings) |m| {
        try w.print("    .{{ .start = 0x{X}, .end = 0x{X}, .status = .{s}, .mapping = ", .{ m.start, m.end, @tagName(m.status) });
        if (m.mapping) |s| {
            try w.writeByte('"');
            for (s) |byte| try w.print("\\x{X:0>2}", .{byte});
            try w.writeByte('"');
        } else try w.writeAll("null");
        try w.writeAll(" },\n");
    }
    try w.writeAll("};\n");
    inline for (.{ .{ "bidi_ranges", "BidiRange", bidi }, .{ "joining_ranges", "JoiningRange", joining } }) |table| {
        try w.print("pub const {s} = [_]{s}{{\n", .{ table[0], table[1] });
        for (table[2]) |r| try w.print("    .{{ .start = 0x{X}, .end = 0x{X}, .class = .{s} }},\n", .{ r.start, r.end, @tagName(r.class) });
        try w.writeAll("};\n");
    }
    try w.writeAll("pub const decompositions = [_]DecompositionMapping{\n");
    for (unicode.decompositions) |d| {
        try w.print("    .{{ .codepoint = 0x{X}, .decomposition = &.{{", .{d.codepoint});
        for (d.decomposition) |cp| try w.print("0x{X},", .{cp});
        try w.writeAll("} },\n");
    }
    try w.writeAll("};\npub const compositions = [_]CompositionPair{\n");
    for (unicode.compositions) |c| try w.print("    .{{ .first = 0x{X}, .second = 0x{X}, .composed = 0x{X} }},\n", .{ c.first, c.second, c.composed });
    try w.writeAll("};\npub const combining_classes = [_]CombiningClass{\n");
    for (unicode.combining_classes) |c| try w.print("    .{{ .codepoint = 0x{X}, .class = {} }},\n", .{ c.codepoint, c.class });
    try w.writeAll("};\npub const composition_exclusions = [_]Range{\n");
    for (exclusions) |r| try w.print("    .{{ .start = 0x{X}, .end = 0x{X} }},\n", .{ r.start, r.end });
    try w.writeAll("};\npub const marks = [_]u21{\n");
    for (unicode.marks) |cp| try w.print("    0x{X},\n", .{cp});
    try w.writeAll("};\n");
    try w.writeAll(lookups);
    // Emit exactly the formatter's canonical representation.
    const source = try a.dupeSentinel(u8, output.written(), 0);
    defer a.free(source);
    var tree = try std.zig.Ast.parse(a, source, .zig);
    defer tree.deinit(a);
    if (tree.errors.len != 0) return error.InvalidGeneratedZig;
    const formatted = try tree.renderAlloc(a);
    defer a.free(formatted);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = formatted });
}
test "property records preserve ranges and reject malformed input" {
    const r = (try parsePropertyLine("0620..063F ; D # Arabic")).?;
    try std.testing.expectEqual(@as(u21, 0x620), r.start);
    try std.testing.expectEqual(@as(u21, 0x63f), r.end);
    try std.testing.expectEqualStrings("D", r.property);
    try std.testing.expectEqual(@as(?PropertyRecord, null), try parsePropertyLine("# comment"));
    try std.testing.expectError(error.InvalidRange, parsePropertyLine("0042..0041 ; L"));
}

test "UnicodeData keeps class-zero marks and canonical-only decompositions" {
    var data = try parseUnicodeData(std.testing.allocator, "0903;DEVANAGARI SIGN VISARGA;Mc;0;L;;;;;N;;;;;\n" ++
        "00C0;LATIN CAPITAL LETTER A WITH GRAVE;Lu;0;L;0041 0300;;;;N;;;;;\n" ++
        "00A0;NO-BREAK SPACE;Zs;0;CS;<noBreak> 0020;;;;N;;;;;\n");
    defer data.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u21, &.{0x903}, data.marks);
    try std.testing.expectEqual(@as(usize, 1), data.decompositions.len);
    try std.testing.expectEqualSlices(u21, &.{ 0x41, 0x300 }, data.decompositions[0].decomposition);
}

test "joining and bidi properties honor defaults and explicit overrides" {
    const a = std.testing.allocator;
    const joining = try parseJoiningTypes(a, "0628 ; D\n064E..0650 ; T\n");
    defer a.free(joining);
    try std.testing.expectEqual(JoiningType.U, lookupRange(JoiningRange, joining, 0x627, .U));
    try std.testing.expectEqual(JoiningType.D, lookupRange(JoiningRange, joining, 0x628, .U));
    try std.testing.expectEqual(JoiningType.T, lookupRange(JoiningRange, joining, 0x650, .U));
    try std.testing.expectEqual(JoiningType.U, lookupRange(JoiningRange, joining, 0x651, .U));
    const bidi = try parseBidiClasses(a, "# @missing: 0000..10FFFF; Left_To_Right\n# @missing: 0600..07BF; Arabic_Letter\n0628; AL\n064E; NSM\n");
    defer a.free(bidi);
    try std.testing.expectEqual(BidiClass.AL, lookupRange(BidiRange, bidi, 0x627, .L));
    try std.testing.expectEqual(BidiClass.NSM, lookupRange(BidiRange, bidi, 0x64e, .L));
    try std.testing.expectEqual(BidiClass.L, lookupRange(BidiRange, bidi, 0x7c0, .L));
}

test "IDNA mappings decode UTF8 and normalization exclusions filter properties" {
    const a = std.testing.allocator;
    const mappings = try parseIdnaMappings(a, "0041 ; mapped ; 0061 # A\n1E9E ; mapped ; 00DF\n0378..0379 ; disallowed\n");
    defer freeMappings(a, mappings);
    try std.testing.expectEqualStrings("a", mappings[0].mapping.?);
    try std.testing.expectEqualStrings("ß", mappings[1].mapping.?);
    try std.testing.expectEqual(IdnaStatus.disallowed, mappings[2].status);
    const exclusions = try parseExclusions(a, "0340..0341 ; Full_Composition_Exclusion\n0300; NFC_QC; M\n");
    defer a.free(exclusions);
    try std.testing.expectEqual(@as(usize, 1), exclusions.len);
    try std.testing.expectEqual(@as(u21, 0x341), exclusions[0].end);
}

const license =
    \\//! UNICODE LICENSE V3
    \\//! Copyright © 1991-2025 Unicode, Inc.
    \\//!
    \\//! Permission is hereby granted, free of charge, to any person obtaining a
    \\//! copy of data files and any associated documentation (the "Data Files") or
    \\//! software and any associated documentation (the "Software") to deal in the
    \\//! Data Files or Software without restriction, including without limitation
    \\//! the rights to use, copy, modify, merge, publish, distribute, and/or sell
    \\//! copies of the Data Files or Software, and to permit persons to whom the
    \\//! Data Files or Software are furnished to do so, provided that either (a)
    \\//! this copyright and permission notice appear with all copies of the Data
    \\//! Files or Software, or (b) this copyright and permission notice appear in
    \\//! associated Documentation.
    \\//!
    \\//! THE DATA FILES AND SOFTWARE ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
    \\//! KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    \\//! MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF
    \\//! THIRD PARTY RIGHTS.
    \\//!
    \\//! IN NO EVENT SHALL THE COPYRIGHT HOLDER OR HOLDERS INCLUDED IN THIS NOTICE
    \\//! BE LIABLE FOR ANY CLAIM, OR ANY SPECIAL INDIRECT OR CONSEQUENTIAL DAMAGES,
    \\//! OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
    \\//! WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
    \\//! ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THE DATA
    \\//! FILES OR SOFTWARE.
    \\//!
    \\//! Except as contained in this notice, the name of a copyright holder shall
    \\//! not be used in advertising or otherwise to promote the sale, use or other
    \\//! dealings in these Data Files or Software without prior written
    \\//! authorization of the copyright holder.
    \\
;

const declarations =
    \\pub const IdnaStatus = enum { valid, ignored, mapped, deviation, disallowed, disallowed_std3_valid, disallowed_std3_mapped };
    \\pub const BidiClass = enum { L, R, AL, EN, ES, ET, AN, CS, NSM, BN, B, S, WS, ON, LRE, LRO, RLE, RLO, PDF, LRI, RLI, FSI, PDI };
    \\pub const JoiningType = enum { U, L, R, D, C, T };
    \\pub const Range = struct { start: u21, end: u21 };
    \\pub const IdnaMapping = struct { start: u21, end: u21, status: IdnaStatus, mapping: ?[]const u8 };
    \\pub const BidiRange = struct { start: u21, end: u21, class: BidiClass };
    \\pub const JoiningRange = struct { start: u21, end: u21, class: JoiningType };
    \\pub const DecompositionMapping = struct { codepoint: u21, decomposition: []const u21 };
    \\pub const CompositionPair = struct { first: u21, second: u21, composed: u21 };
    \\pub const CombiningClass = struct { codepoint: u21, class: u8 };
    \\pub const CompositionExclusion = Range;
    \\
;

const lookups =
    \\fn rangeIndex(comptime T: type, ranges: []const T, cp: u21) ?usize {
    \\    var low: usize = 0;
    \\    var high = ranges.len;
    \\    while (low < high) {
    \\        const mid = low + (high - low) / 2;
    \\        if (cp < ranges[mid].start) high = mid else if (cp > ranges[mid].end) low = mid + 1 else return mid;
    \\    }
    \\    return null;
    \\}
    \\fn pointIndex(comptime T: type, points: []const T, cp: u21) ?usize {
    \\    var low: usize = 0;
    \\    var high = points.len;
    \\    while (low < high) {
    \\        const mid = low + (high - low) / 2;
    \\        const key = if (T == u21) points[mid] else points[mid].codepoint;
    \\        if (cp < key) high = mid else if (cp > key) low = mid + 1 else return mid;
    \\    }
    \\    return null;
    \\}
    \\/// UTS #46 status and replacement; unknown code points are disallowed.
    \\pub fn lookupIdnaStatus(cp: u21) struct { status: IdnaStatus, mapping: ?[]const u8 } {
    \\    if (rangeIndex(IdnaMapping, &idna_mappings, cp)) |i| {
    \\        const m = idna_mappings[i];
    \\        return .{ .status = m.status, .mapping = m.mapping };
    \\    }
    \\    return .{ .status = .disallowed, .mapping = null };
    \\}
    \\/// Unicode Bidi_Class including the derived defaults for reserved ranges.
    \\pub fn lookupBidiClass(cp: u21) BidiClass {
    \\    return if (rangeIndex(BidiRange, &bidi_ranges, cp)) |i| bidi_ranges[i].class else .L;
    \\}
    \\/// Unicode Joining_Type; an omitted code point is Non_Joining (U).
    \\pub fn lookupJoiningType(cp: u21) JoiningType {
    \\    return if (rangeIndex(JoiningRange, &joining_ranges, cp)) |i| joining_ranges[i].class else .U;
    \\}
    \\/// Whether General_Category is Mn, Mc or Me (including class-zero marks).
    \\pub fn isMark(cp: u21) bool { return pointIndex(u21, &marks, cp) != null; }
    \\/// Canonical decomposition, excluding compatibility mappings.
    \\pub fn lookupDecomposition(cp: u21) ?[]const u21 {
    \\    return if (pointIndex(DecompositionMapping, &decompositions, cp)) |i| decompositions[i].decomposition else null;
    \\}
    \\/// Reverse canonical decomposition; callers must check composition exclusions.
    \\pub fn lookupComposition(first: u21, second: u21) ?u21 {
    \\    var low: usize = 0;
    \\    var high = compositions.len;
    \\    while (low < high) {
    \\        const mid = low + (high - low) / 2;
    \\        const c = compositions[mid];
    \\        if (first < c.first or (first == c.first and second < c.second)) high = mid else if (first > c.first or (first == c.first and second > c.second)) low = mid + 1 else return c.composed;
    \\    }
    \\    return null;
    \\}
    \\/// Canonical_Combining_Class, defaulting to zero.
    \\pub fn lookupCombiningClass(cp: u21) u8 {
    \\    return if (pointIndex(CombiningClass, &combining_classes, cp)) |i| combining_classes[i].class else 0;
    \\}
    \\/// Full_Composition_Exclusion from DerivedNormalizationProps.
    \\pub fn isCompositionExcluded(cp: u21) bool { return rangeIndex(Range, &composition_exclusions, cp) != null; }
    \\
;
