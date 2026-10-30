//! Generate Unicode 17.0.0 full case mappings and their context properties.
//! Fetch the hash-pinned inputs below into scratch, then run:
//! zig build case-tables -j2 -- <input-directory> src/infra/unicode_case.zig
//! The generator never downloads files. Normal tests use inline fixtures.
const std = @import("std");
const Allocator = std.mem.Allocator;
const Mapping = struct {
    points: [3]u21 = .{ 0, 0, 0 },
    len: u8 = 0,
    fn identity(cp: u21) Mapping {
        return .{ .points = .{ cp, 0, 0 }, .len = 1 };
    }
};
const Case = struct { cp: u21, lower: Mapping, title: Mapping, upper: Mapping };
const Condition = enum { always, Final_Sigma, After_Soft_Dotted, More_Above, Before_Dot, After_I };
const Language = enum { any, tr, az, lt };
const Conditional = struct { value: Case, language: Language = .any, condition: Condition = .always, negated: bool = false };
const Range = struct { start: u21, end: u21 };
const Property = struct { start: u21, end: u21, ccc: u8, word: bool, letter: bool };
const Wide = struct { cp: u21, full: u21 };
const Fold = struct { cp: u21, mapping: Mapping };
const Tables = struct {
    cases: std.AutoHashMapUnmanaged(u21, Case) = .empty,
    folds: std.AutoHashMapUnmanaged(u21, Mapping) = .empty,
    conditional: std.ArrayList(Conditional) = .empty,
    properties: std.ArrayList(Property) = .empty,
    wide: std.ArrayList(Wide) = .empty,
    fn deinit(self: *Tables, a: Allocator) void {
        self.cases.deinit(a);
        self.folds.deinit(a);
        self.conditional.deinit(a);
        self.properties.deinit(a);
        self.wide.deinit(a);
    }
};
const Input = struct { name: []const u8, sha256: []const u8 };
const inputs = [_]Input{
    .{ .name = "UnicodeData.txt", .sha256 = "2e1efc1dcb59c575eedf5ccae60f95229f706ee6d031835247d843c11d96470c" },
    .{ .name = "SpecialCasing.txt", .sha256 = "efc25faf19de21b92c1194c111c932e03d2a5eaf18194e33f1156e96de4c9588" },
    .{ .name = "DerivedCoreProperties.txt", .sha256 = "24c7fed1195c482faaefd5c1e7eb821c5ee1fb6de07ecdbaa64b56a99da22c08" },
    .{ .name = "PropList.txt", .sha256 = "130dcddcaadaf071008bdfce1e7743e04fdfbc910886f017d9f9ac931d8c64dd" },
    .{ .name = "CaseFolding.txt", .sha256 = "ff8d8fefbf123574205085d6714c36149eb946d717a0c585c27f0f4ef58c4183" },
};

fn trim(text: []const u8) []const u8 {
    return std.mem.trim(u8, text, " \t\r");
}

fn parseMapping(text: []const u8) !Mapping {
    var result = Mapping{};
    var parts = std.mem.tokenizeAny(u8, text, " \t");
    while (parts.next()) |part| {
        if (result.len == result.points.len) return error.MappingTooLong;
        const cp = try std.fmt.parseInt(u21, part, 16);
        if (cp > 0x10ffff) return error.InvalidCodePoint;
        result.points[result.len] = cp;
        result.len += 1;
    }
    return result;
}

fn parseSimple(text: []const u8, fallback: Mapping) !Mapping {
    return if (text.len == 0) fallback else try parseMapping(text);
}

/// Unicode Default Caseless Matching uses full C/F mappings. S is the
/// alternative simple mapping and T is locale-specific Turkic tailoring.
fn parseCaseFolding(a: Allocator, tables: *Tables, text: []const u8) !void {
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        const content = trim(line[0 .. std.mem.indexOfScalar(u8, line, '#') orelse line.len]);
        if (content.len == 0) continue;
        var fields = std.mem.splitScalar(u8, content, ';');
        const cp = try std.fmt.parseInt(u21, trim(fields.next().?), 16);
        if (cp > 0x10ffff) return error.InvalidCodePoint;
        const status = trim(fields.next() orelse return error.InvalidCaseFolding);
        const mapping = try parseMapping(trim(fields.next() orelse return error.InvalidCaseFolding));
        if (mapping.len == 0) return error.InvalidCaseFolding;
        if (fields.next()) |rest| {
            if (trim(rest).len != 0 or fields.next() != null) return error.InvalidCaseFolding;
        }
        if (std.mem.eql(u8, status, "S") or std.mem.eql(u8, status, "T")) continue;
        if (!std.mem.eql(u8, status, "C") and !std.mem.eql(u8, status, "F")) return error.InvalidCaseFolding;
        const entry = try tables.folds.getOrPut(a, cp);
        if (entry.found_existing) return error.DuplicateCaseFolding;
        entry.value_ptr.* = mapping;
    }
}

fn appendProperty(a: Allocator, list: *std.ArrayList(Property), property: Property) !void {
    if (list.items.len > 0) {
        const last = &list.items[list.items.len - 1];
        if (last.end + 1 == property.start and last.ccc == property.ccc and last.word == property.word and last.letter == property.letter) {
            last.end = property.end;
            return;
        }
    }
    if (property.word or property.ccc != 0) try list.append(a, property);
}

fn parseUnicodeData(a: Allocator, tables: *Tables, text: []const u8) !void {
    var lines = std.mem.splitScalar(u8, text, '\n');
    var range_start: ?u21 = null;
    while (lines.next()) |line| {
        if (trim(line).len == 0) continue;
        var fields: [15][]const u8 = undefined;
        var parts = std.mem.splitScalar(u8, trim(line), ';');
        for (&fields) |*field| field.* = parts.next() orelse return error.InvalidUnicodeData;
        if (parts.next() != null) return error.InvalidUnicodeData;
        const cp = try std.fmt.parseInt(u21, fields[0], 16);
        const identity = Mapping.identity(cp);
        const upper = try parseSimple(fields[12], identity);
        const lower = try parseSimple(fields[13], identity);
        const title = try parseSimple(fields[14], upper);
        if (!std.meta.eql(identity, upper) or !std.meta.eql(identity, lower) or !std.meta.eql(identity, title)) {
            try tables.cases.put(a, cp, .{ .cp = cp, .upper = upper, .lower = lower, .title = title });
        }
        const category = fields[2];
        if (category.len != 2) return error.InvalidUnicodeData;
        var property = Property{
            .start = cp,
            .end = cp,
            .ccc = try std.fmt.parseInt(u8, fields[3], 10),
            // CSS Text's typographic letter unit includes Numbers too.
            .letter = category[0] == 'L' or category[0] == 'N',
            .word = category[0] == 'L' or category[0] == 'M' or category[0] == 'N' or std.mem.eql(u8, category, "Pc") or std.mem.eql(u8, category, "Cf"),
        };
        if (std.mem.endsWith(u8, fields[1], ", First>")) {
            if (range_start != null) return error.InvalidUnicodeData;
            range_start = cp;
            continue;
        }
        if (std.mem.endsWith(u8, fields[1], ", Last>")) {
            property.start = range_start orelse return error.InvalidUnicodeData;
            range_start = null;
        } else if (range_start != null) return error.InvalidUnicodeData;
        try appendProperty(a, &tables.properties, property);
        // CSS Text 4 full-width: reverse <wide>, apply <narrow> directly.
        const decomposition = fields[5];
        if (std.mem.startsWith(u8, decomposition, "<wide> ") or std.mem.startsWith(u8, decomposition, "<narrow> ")) {
            const wide = std.mem.startsWith(u8, decomposition, "<wide>");
            const mapped = try parseMapping(decomposition[if (wide) 7 else 9..]);
            if (mapped.len != 1) return error.InvalidWidthMapping;
            try tables.wide.append(a, if (wide) .{ .cp = mapped.points[0], .full = cp } else .{ .cp = cp, .full = mapped.points[0] });
        }
    }
    if (range_start != null) return error.InvalidUnicodeData;
}

fn parseSpecialCasing(a: Allocator, tables: *Tables, text: []const u8) !void {
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        const content = trim(line[0 .. std.mem.indexOfScalar(u8, line, '#') orelse line.len]);
        if (content.len == 0) continue;
        var fields = std.mem.splitScalar(u8, content, ';');
        const cp = try std.fmt.parseInt(u21, trim(fields.next().?), 16);
        const value = Case{
            .cp = cp,
            .lower = try parseMapping(trim(fields.next() orelse return error.InvalidSpecialCasing)),
            .title = try parseMapping(trim(fields.next() orelse return error.InvalidSpecialCasing)),
            .upper = try parseMapping(trim(fields.next() orelse return error.InvalidSpecialCasing)),
        };
        const conditions = trim(fields.next() orelse "");
        if (conditions.len == 0) {
            // Full mappings override simple UnicodeData mappings, including
            // mappings that expand and mappings to the empty string.
            try tables.cases.put(a, cp, value);
            continue;
        }
        var result = Conditional{ .value = value };
        var names = std.mem.tokenizeAny(u8, conditions, " \t");
        while (names.next()) |name| {
            if (std.meta.stringToEnum(Language, name)) |language| {
                if (result.language != .any) return error.InvalidCondition;
                result.language = language;
            } else {
                if (result.condition != .always) return error.InvalidCondition;
                result.negated = std.mem.startsWith(u8, name, "Not_");
                result.condition = std.meta.stringToEnum(Condition, if (result.negated) name[4..] else name) orelse return error.UnknownCondition;
            }
        }
        try tables.conditional.append(a, result);
    }
}

fn parseProperty(a: Allocator, text: []const u8, wanted: []const u8) ![]Range {
    var result: std.ArrayList(Range) = .empty;
    errdefer result.deinit(a);
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        const content = trim(line[0 .. std.mem.indexOfScalar(u8, line, '#') orelse line.len]);
        if (content.len == 0) continue;
        var fields = std.mem.splitScalar(u8, content, ';');
        const range = trim(fields.next().?);
        const property = trim(fields.next() orelse return error.InvalidProperty);
        if (!std.mem.eql(u8, property, wanted)) continue;
        const split = std.mem.indexOf(u8, range, "..");
        const start = try std.fmt.parseInt(u21, if (split) |i| range[0..i] else range, 16);
        const end = if (split) |i| try std.fmt.parseInt(u21, range[i + 2 ..], 16) else start;
        if (start > end or end > 0x10ffff) return error.InvalidRange;
        if (result.items.len > 0) {
            const last = &result.items[result.items.len - 1];
            if (start <= last.end) return error.UnsortedProperty;
            if (last.end + 1 == start) {
                last.end = end;
                continue;
            }
        }
        try result.append(a, .{ .start = start, .end = end });
    }
    return result.toOwnedSlice(a);
}

fn writeMapping(w: *std.Io.Writer, value: Mapping) !void {
    try w.print(".{{ .points = .{{ 0x{X}, 0x{X}, 0x{X} }}, .len = {} }}", .{ value.points[0], value.points[1], value.points[2], value.len });
}

fn writeCase(w: *std.Io.Writer, value: Case) !void {
    try w.print(".{{ .cp = 0x{X}, .lower = ", .{value.cp});
    try writeMapping(w, value.lower);
    try w.writeAll(", .title = ");
    try writeMapping(w, value.title);
    try w.writeAll(", .upper = ");
    try writeMapping(w, value.upper);
    try w.writeAll(" }");
}

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
    defer for (contents[0..read]) |text| a.free(text);
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
    var tables = Tables{};
    defer tables.deinit(a);
    try parseUnicodeData(a, &tables, contents[0]);
    try parseSpecialCasing(a, &tables, contents[1]);
    try parseCaseFolding(a, &tables, contents[4]);
    const cased = try parseProperty(a, contents[2], "Cased");
    defer a.free(cased);
    const ignorable = try parseProperty(a, contents[2], "Case_Ignorable");
    defer a.free(ignorable);
    const soft_dotted = try parseProperty(a, contents[3], "Soft_Dotted");
    defer a.free(soft_dotted);
    const cases = try a.alloc(Case, tables.cases.count());
    defer a.free(cases);
    var it = tables.cases.valueIterator();
    var i: usize = 0;
    while (it.next()) |value| : (i += 1) cases[i] = value.*;
    std.mem.sort(Case, cases, {}, struct {
        fn less(_: void, lhs: Case, rhs: Case) bool {
            return lhs.cp < rhs.cp;
        }
    }.less);
    std.mem.sort(Wide, tables.wide.items, {}, struct {
        fn less(_: void, lhs: Wide, rhs: Wide) bool {
            return lhs.cp < rhs.cp;
        }
    }.less);
    const folds = try a.alloc(Fold, tables.folds.count());
    defer a.free(folds);
    var fold_it = tables.folds.iterator();
    i = 0;
    while (fold_it.next()) |entry| : (i += 1) folds[i] = .{ .cp = entry.key_ptr.*, .mapping = entry.value_ptr.* };
    std.mem.sort(Fold, folds, {}, struct {
        fn less(_: void, lhs: Fold, rhs: Fold) bool {
            return lhs.cp < rhs.cp;
        }
    }.less);
    var output: std.Io.Writer.Allocating = .init(a);
    defer output.deinit();
    const w = &output.writer;
    try w.writeAll("//! Generated by tools/unicode/generate_case_tables.zig; DO NOT EDIT.\n//! Unicode 17.0.0 full case mappings, context properties, and width mappings.\n//! Regenerate: zig build case-tables -j2 -- <inputs> src/infra/unicode_case.zig\n");
    for (inputs) |input| try w.print("//! https://www.unicode.org/Public/17.0.0/ucd/{s}\n//! SHA256: {s}\n", .{ input.name, input.sha256 });
    try w.writeAll(license);
    try w.writeAll(runtime_source);
    try w.writeAll("\nconst cases = [_]Case{\n");
    for (cases) |value| {
        try writeCase(w, value);
        try w.writeAll(",\n");
    }
    try w.writeAll("};\nconst conditional = [_]Conditional{\n");
    for (tables.conditional.items) |entry| {
        try w.writeAll(".{ .value = ");
        try writeCase(w, entry.value);
        try w.print(", .language = .{s}, .condition = .{s}, .negated = {} }},\n", .{ @tagName(entry.language), @tagName(entry.condition), entry.negated });
    }
    try w.writeAll("};\nconst properties = [_]Property{\n");
    for (tables.properties.items) |p| try w.print(".{{ .start = 0x{X}, .end = 0x{X}, .ccc = {}, .word = {}, .letter = {} }},\n", .{ p.start, p.end, p.ccc, p.word, p.letter });
    try w.writeAll("};\nconst widths = [_]Wide{\n");
    for (tables.wide.items) |entry| try w.print(".{{ .cp = 0x{X}, .full = 0x{X} }},\n", .{ entry.cp, entry.full });
    try w.writeAll("};\n");
    inline for (.{ .{ "cased", cased }, .{ "ignorable", ignorable }, .{ "soft_dotted", soft_dotted } }) |table| {
        try w.print("const {s} = [_]Range{{\n", .{table[0]});
        for (table[1]) |range| try w.print(".{{ .start = 0x{X}, .end = 0x{X} }},\n", .{ range.start, range.end });
        try w.writeAll("};\n");
    }
    // Append only: existing generated functions and tables stay identical.
    try w.writeAll(fold_runtime_source);
    try w.writeAll("\nconst folds = [_]Fold{\n");
    for (folds) |entry| {
        try w.print(".{{ .cp = 0x{X}, .mapping = ", .{entry.cp});
        try writeMapping(w, entry.mapping);
        try w.writeAll(" },\n");
    }
    try w.writeAll("};\n");
    const source = try a.dupeSentinel(u8, output.written(), 0);
    defer a.free(source);
    var tree = try std.zig.Ast.parse(a, source, .zig);
    defer tree.deinit(a);
    if (tree.errors.len != 0) return error.InvalidGeneratedZig;
    const formatted = try tree.renderAlloc(a);
    defer a.free(formatted);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = formatted });
}

test "full mappings override simple mappings and conditional empty mappings survive" {
    var tables = Tables{};
    defer tables.deinit(std.testing.allocator);
    try parseUnicodeData(std.testing.allocator, &tables, "0049;LATIN CAPITAL LETTER I;Lu;0;L;;;;;N;;;;0069;\n00DF;LATIN SMALL LETTER SHARP S;Ll;0;L;;;;;N;;;;;\n");
    try parseSpecialCasing(std.testing.allocator, &tables, "00DF; 00DF; 0053 0073; 0053 0053; # sharp s\n0307; ; 0307; 0307; tr After_I;\n0049; 0131; 0049; 0049; tr Not_Before_Dot;\n");
    try std.testing.expectEqual(@as(u8, 2), tables.cases.get(0xdf).?.upper.len);
    try std.testing.expectEqual(@as(u21, 's'), tables.cases.get(0xdf).?.title.points[1]);
    try std.testing.expectEqual(@as(u8, 0), tables.conditional.items[0].value.lower.len);
    try std.testing.expect(tables.conditional.items[1].negated);
    try std.testing.expectEqual(Condition.Before_Dot, tables.conditional.items[1].condition);
}

test "Unicode ranges, combining classes and width directions are retained" {
    var tables = Tables{};
    defer tables.deinit(std.testing.allocator);
    try parseUnicodeData(std.testing.allocator, &tables, "0307;COMBINING DOT ABOVE;Mn;230;NSM;;;;;N;;;;;\n3400;<CJK Ideograph Extension A, First>;Lo;0;L;;;;;N;;;;;\n4DBF;<CJK Ideograph Extension A, Last>;Lo;0;L;;;;;N;;;;;\nFF21;FULLWIDTH LATIN CAPITAL LETTER A;Lu;0;L;<wide> 0041;;;;N;;;;FF41;\nFF76;HALFWIDTH KATAKANA LETTER KA;Lo;0;L;<narrow> 30AB;;;;N;;;;;\n");
    try std.testing.expectEqual(@as(u8, 230), tables.properties.items[0].ccc);
    try std.testing.expectEqual(@as(u21, 0x4dbf), tables.properties.items[1].end);
    try std.testing.expectEqual(@as(u21, 'A'), tables.wide.items[0].cp);
    try std.testing.expectEqual(@as(u21, 0xff21), tables.wide.items[0].full);
    try std.testing.expectEqual(@as(u21, 0x30ab), tables.wide.items[1].full);
}

test "context properties merge adjacent ranges and reject a future unknown condition" {
    const ranges = try parseProperty(std.testing.allocator, "0041..005A ; Cased\n005B ; Cased\n0061 ; Case_Ignorable\n", "Cased");
    defer std.testing.allocator.free(ranges);
    try std.testing.expectEqual(@as(usize, 1), ranges.len);
    try std.testing.expectEqual(@as(u21, 0x5b), ranges[0].end);
    var tables = Tables{};
    defer tables.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnknownCondition, parseSpecialCasing(std.testing.allocator, &tables, "0049; 0069; 0049; 0049; Future_Context;\n"));
}

test "generator parsing frees all storage on allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationFailures, .{});
}

fn allocationFailures(a: Allocator) !void {
    var tables = Tables{};
    defer tables.deinit(a);
    try parseUnicodeData(a, &tables, "0049;LATIN CAPITAL LETTER I;Lu;0;L;;;;;N;;;;0069;\n");
    try parseSpecialCasing(a, &tables, "0049; 0131; 0049; 0049; tr Not_Before_Dot;\n");
    const ranges = try parseProperty(a, "0041..005A ; Cased\n0061..007A ; Cased\n", "Cased");
    defer a.free(ranges);
}

const runtime_source =
    \\const std = @import("std");
    \\pub const CaseMode = enum { lower, upper, title };
    \\pub const Mapping = struct {
    \\    points: [3]u21 = .{ 0, 0, 0 },
    \\    len: u8 = 0,
    \\    pub fn identity(cp: u21) Mapping { return .{ .points = .{ cp, 0, 0 }, .len = 1 }; }
    \\};
    \\const Case = struct { cp: u21, lower: Mapping, title: Mapping, upper: Mapping };
    \\const Condition = enum { always, Final_Sigma, After_Soft_Dotted, More_Above, Before_Dot, After_I };
    \\const Language = enum { any, tr, az, lt };
    \\const Conditional = struct { value: Case, language: Language = .any, condition: Condition = .always, negated: bool = false };
    \\const Range = struct { start: u21, end: u21 };
    \\const Property = struct { start: u21, end: u21, ccc: u8, word: bool, letter: bool };
    \\const Wide = struct { cp: u21, full: u21 };
    \\
    \\fn rangeIndex(comptime T: type, table: []const T, cp: u21) ?usize {
    \\    var low: usize = 0;
    \\    var high = table.len;
    \\    while (low < high) {
    \\        const middle = low + (high - low) / 2;
    \\        if (cp < table[middle].start) high = middle else if (cp > table[middle].end) low = middle + 1 else return middle;
    \\    }
    \\    return null;
    \\}
    \\fn pointIndex(comptime T: type, table: []const T, cp: u21) ?usize {
    \\    var low: usize = 0;
    \\    var high = table.len;
    \\    while (low < high) {
    \\        const middle = low + (high - low) / 2;
    \\        if (cp < table[middle].cp) high = middle else if (cp > table[middle].cp) low = middle + 1 else return middle;
    \\    }
    \\    return null;
    \\}
    \\pub fn combiningClass(cp: u21) u8 { return if (rangeIndex(Property, &properties, cp)) |i| properties[i].ccc else 0; }
    \\/// CSS Text 4 §1.4: eligible bases of typographic letter units.
    \\pub fn isLetterOrNumber(cp: u21) bool { return if (rangeIndex(Property, &properties, cp)) |i| properties[i].letter else false; }
    \\pub fn isWordCharacter(cp: u21) bool { return if (rangeIndex(Property, &properties, cp)) |i| properties[i].word else false; }
    \\pub fn isCased(cp: u21) bool { return rangeIndex(Range, &cased, cp) != null; }
    \\pub fn isCaseIgnorable(cp: u21) bool { return rangeIndex(Range, &ignorable, cp) != null; }
    \\pub fn isSoftDotted(cp: u21) bool { return rangeIndex(Range, &soft_dotted, cp) != null; }
    \\/// CSS Text 4's width mapping, independent of casing. Unknowns are identity.
    \\pub fn fullWidth(cp: u21) u21 { return if (pointIndex(Wide, &widths, cp)) |i| widths[i].full else cp; }
    \\
    \\fn languageOf(tag: []const u8) Language {
    \\    const end = std.mem.indexOfAny(u8, tag, "-_") orelse tag.len;
    \\    inline for (.{ Language.tr, Language.az, Language.lt }) |language| {
    \\        if (std.ascii.eqlIgnoreCase(tag[0..end], @tagName(language))) return language;
    \\    }
    \\    return .any;
    \\}
    \\
    \\/// Unicode 17 chapter 3, table 3-17. Context always reads the ORIGINAL
    \\/// input, never a transformed prefix. The possessive Case_Ignorable
    \\/// scan precedes Cased (the properties overlap, e.g. U+0345).
    \\fn conditionMatches(condition: Condition, original: []const u21, index: usize) bool {
    \\    switch (condition) {
    \\        .always => return true,
    \\        .Final_Sigma => {
    \\            var before = index;
    \\            while (before > 0 and isCaseIgnorable(original[before - 1])) before -= 1;
    \\            if (before == 0 or !isCased(original[before - 1])) return false;
    \\            var after = index + 1;
    \\            while (after < original.len and isCaseIgnorable(original[after])) after += 1;
    \\            return after == original.len or !isCased(original[after]);
    \\        },
    \\        .After_I, .After_Soft_Dotted => {
    \\            var before = index;
    \\            while (before > 0) {
    \\                before -= 1;
    \\                const cp = original[before];
    \\                if (if (condition == .After_I) cp == 'I' else isSoftDotted(cp)) return true;
    \\                const ccc = combiningClass(cp);
    \\                if (ccc == 0 or ccc == 230) return false;
    \\            }
    \\            return false;
    \\        },
    \\        .More_Above, .Before_Dot => {
    \\            for (original[index + 1 ..]) |cp| {
    \\                const ccc = combiningClass(cp);
    \\                if (if (condition == .Before_Dot) cp == 0x307 else ccc == 230) return true;
    \\                if (ccc == 0 or ccc == 230) return false;
    \\            }
    \\            return false;
    \\        },
    \\    }
    \\}
    \\
    \\fn choose(value: Case, mode: CaseMode) Mapping {
    \\    return switch (mode) { .lower => value.lower, .upper => value.upper, .title => value.title };
    \\}
    \\/// Full Unicode upper/lower/title mapping, including every conditional
    \\/// SpecialCasing rule. Callers provide the original string, never an
    \\/// already-transformed prefix. The result owns no storage.
    \\pub fn map(original: []const u21, index: usize, mode: CaseMode, language: []const u8) Mapping {
    \\    const cp = original[index];
    \\    const lang = languageOf(language);
    \\    for (conditional) |entry| {
    \\        if (entry.value.cp != cp or (entry.language != .any and entry.language != lang)) continue;
    \\        if (conditionMatches(entry.condition, original, index) != entry.negated) return choose(entry.value, mode);
    \\    }
    \\    return if (pointIndex(Case, &cases, cp)) |i| choose(cases[i], mode) else Mapping.identity(cp);
    \\}
    \\
    \\test "full upper, lower and title mappings expand sharp s and ligatures" {
    \\    const sharp = [_]u21{0xdf};
    \\    const upper = map(&sharp, 0, .upper, "");
    \\    const title = map(&sharp, 0, .title, "");
    \\    try std.testing.expectEqualSlices(u21, &.{ 'S', 'S' }, upper.points[0..upper.len]);
    \\    try std.testing.expectEqualSlices(u21, &.{ 'S', 's' }, title.points[0..title.len]);
    \\    const ligature = map(&.{0xfb03}, 0, .upper, "");
    \\    try std.testing.expectEqualSlices(u21, &.{ 'F', 'F', 'I' }, ligature.points[0..ligature.len]);
    \\    try std.testing.expectEqual(@as(u21, 0x1c5), map(&.{0x1c6}, 0, .title, "").points[0]);
    \\    try std.testing.expectEqual(@as(u21, 0xff21), map(&.{0xff41}, 0, .upper, "").points[0]);
    \\    try std.testing.expectEqual(@as(u21, 0x10428), map(&.{0x10400}, 0, .lower, "").points[0]);
    \\}
    \\test "Turkish and Azeri casing uses the original context and language subtags" {
    \\    try std.testing.expectEqual(@as(u21, 0x130), map(&.{'i'}, 0, .upper, "TR-tr").points[0]);
    \\    try std.testing.expectEqual(@as(u21, 'I'), map(&.{0x131}, 0, .upper, "az").points[0]);
    \\    try std.testing.expectEqual(@as(u21, 0x131), map(&.{'I'}, 0, .lower, "az_Latn").points[0]);
    \\    const original = [_]u21{ 'I', 0x323, 0x307 };
    \\    try std.testing.expectEqual(@as(u21, 'i'), map(&original, 0, .lower, "tr").points[0]);
    \\    try std.testing.expectEqual(@as(u8, 0), map(&original, 2, .lower, "tr").len);
    \\    const english = map(&.{0x130}, 0, .lower, "en");
    \\    try std.testing.expectEqualSlices(u21, &.{ 'i', 0x307 }, english.points[0..english.len]);
    \\    const blocked = [_]u21{ 'I', 0x301, 0x307 };
    \\    try std.testing.expectEqual(@as(u21, 0x131), map(&blocked, 0, .lower, "tr").points[0]);
    \\    try std.testing.expectEqual(@as(u8, 1), map(&blocked, 2, .lower, "tr").len);
    \\}
    \\test "final sigma skips case-ignorable codepoints even when they are cased" {
    \\    try std.testing.expectEqual(@as(u21, 0x3c2), map(&.{ 0x391, 0x3a3 }, 1, .lower, "").points[0]);
    \\    try std.testing.expectEqual(@as(u21, 0x3c3), map(&.{ 0x391, 0x3a3, 0x391 }, 1, .lower, "").points[0]);
    \\    try std.testing.expectEqual(@as(u21, 0x3c3), map(&.{ 0x345, 0x3a3 }, 1, .lower, "").points[0]);
    \\    try std.testing.expectEqual(@as(u21, 0x3c2), map(&.{ 0x391, 0x345, 0x3a3, 0x345 }, 2, .lower, "").points[0]);
    \\    try std.testing.expectEqual(@as(u21, 0x3c3), map(&.{ 0x391, 0x3a3, 0x345, 0x391 }, 1, .lower, "").points[0]);
    \\}
    \\test "Lithuanian dots survive lowercasing and disappear after soft-dotted capitals" {
    \\    const lower = map(&.{ 'I', 0x301 }, 0, .lower, "lt");
    \\    try std.testing.expectEqualSlices(u21, &.{ 'i', 0x307 }, lower.points[0..lower.len]);
    \\    try std.testing.expectEqual(@as(u8, 0), map(&.{ 'i', 0x323, 0x307 }, 2, .upper, "lt").len);
    \\    try std.testing.expectEqual(@as(u8, 1), map(&.{ 'i', 0x301, 0x307 }, 2, .upper, "lt").len);
    \\    try std.testing.expectEqual(@as(u8, 1), map(&.{ 'i', 0x307 }, 1, .upper, "").len);
    \\}
    \\test "full-width maps both decomposition directions and unknown casing is identity" {
    \\    try std.testing.expect(isLetterOrNumber('1'));
    \\    try std.testing.expect(isLetterOrNumber(0x2170));
    \\    try std.testing.expect(!isLetterOrNumber(0x345));
    \\    try std.testing.expect(isWordCharacter(0x345));
    \\    try std.testing.expectEqual(@as(u21, 0xff21), fullWidth('A'));
    \\    try std.testing.expectEqual(@as(u21, 0x30ab), fullWidth(0xff76));
    \\    try std.testing.expectEqual(@as(u21, 0x3000), fullWidth(' '));
    \\    try std.testing.expectEqual(@as(u21, 0x1f600), map(&.{0x1f600}, 0, .upper, "tr").points[0]);
    \\    try std.testing.expectEqual(@as(u21, 0xd800), map(&.{0xd800}, 0, .lower, "").points[0]);
    \\}
    \\
;

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

test "full folding accepts C and F while excluding S and Turkic T" {
    var tables = Tables{};
    defer tables.deinit(std.testing.allocator);
    try parseCaseFolding(std.testing.allocator, &tables,
        \\0049; C; 0069; # I
        \\0049; T; 0131; # Turkic I
        \\00DF; F; 0073 0073; # sharp s
        \\0130; F; 0069 0307; # dotted I
        \\0130; T; 0069;
        \\1E9E; F; 0073 0073;
        \\1E9E; S; 00DF;
    );
    try std.testing.expectEqual(@as(usize, 4), tables.folds.count());
    try std.testing.expectEqual(@as(u21, 'i'), tables.folds.get(0x49).?.points[0]);
    try std.testing.expectEqual(@as(u8, 2), tables.folds.get(0xdf).?.len);
    try std.testing.expectEqual(@as(u21, 0x307), tables.folds.get(0x130).?.points[1]);
    try std.testing.expectEqual(@as(u8, 2), tables.folds.get(0x1e9e).?.len);
}

test "folding parser validates records and rolls back allocations" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn exercise(a: Allocator) !void {
            var tables = Tables{};
            defer tables.deinit(a);
            try parseCaseFolding(a, &tables, "0041; C; 0061;\n00DF; F; 0073 0073;\n");
        }
    }.exercise, .{});
    var tables = Tables{};
    defer tables.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidCaseFolding, parseCaseFolding(std.testing.allocator, &tables, "0041; X; 0061;\n"));
    try std.testing.expectError(error.InvalidCaseFolding, parseCaseFolding(std.testing.allocator, &tables, "0041; C; ;\n"));
    try std.testing.expectError(error.InvalidCodePoint, parseCaseFolding(std.testing.allocator, &tables, "110000; C; 0061;\n"));
}

const fold_runtime_source =
    \\
    \\const Fold = struct { cp: u21, mapping: Mapping };
    \\/// Unicode 17 Default Caseless Matching: C/F mappings, with neither
    \\/// normalization nor locale tailoring. Unknown codepoints are identity.
    \\pub fn fold(cp: u21) Mapping {
    \\    return if (pointIndex(Fold, &folds, cp)) |i| folds[i].mapping else Mapping.identity(cp);
    \\}
    \\
    \\const FoldIterator = struct {
    \\    input: std.unicode.Utf8Iterator,
    \\    mapping: Mapping = .{},
    \\    position: u8 = 0,
    \\    fn next(self: *FoldIterator) ?u21 {
    \\        if (self.position == self.mapping.len) {
    \\            self.mapping = fold(self.input.nextCodepoint() orelse return null);
    \\            self.position = 0;
    \\        }
    \\        const cp = self.mapping.points[self.position];
    \\        self.position += 1;
    \\        return cp;
    \\    }
    \\};
    \\
    \\/// CSS Fonts 4 §5.1: compare the full folded strings, including
    \\/// expansions. This performs no allocations. Inputs must be UTF-8;
    \\/// malformed strings do not compare equal, even to themselves.
    \\pub fn eqlFold(lhs: []const u8, rhs: []const u8) bool {
    \\    const left = std.unicode.Utf8View.init(lhs) catch return false;
    \\    const right = std.unicode.Utf8View.init(rhs) catch return false;
    \\    var a = FoldIterator{ .input = left.iterator() };
    \\    var b = FoldIterator{ .input = right.iterator() };
    \\    while (a.next()) |cp| {
    \\        if (cp != (b.next() orelse return false)) return false;
    \\    }
    \\    return b.next() == null;
    \\}
    \\
    \\test "default case folding expands and excludes normalization and Turkic tailoring" {
    \\    try std.testing.expect(eqlFold("Straße", "STRASSE"));
    \\    try std.testing.expect(eqlFold("ŉ", "ʼN"));
    \\    try std.testing.expect(eqlFold("ﬃ", "FFI"));
    \\    try std.testing.expect(eqlFold("Σ", "ς"));
    \\    try std.testing.expect(eqlFold("I", "i"));
    \\    try std.testing.expect(eqlFold("İ", "i\u{307}"));
    \\    try std.testing.expect(!eqlFold("I", "ı"));
    \\    try std.testing.expect(!eqlFold("İ", "i"));
    \\    try std.testing.expect(!eqlFold("å", "a\u{30a}"));
    \\    try std.testing.expect(!eqlFold("s", "ß"));
    \\    try std.testing.expect(!eqlFold("\xff", "\xff"));
    \\}
    \\
;
