//! Generate IDNA data tables from Unicode data files
//!
//! Reads Unicode data files and generates Zig source code with lookup tables:
//! - IdnaMappingTable.txt -> IDNA character mappings
//! - DerivedNormalizationProps.txt -> NFC Quick_Check data
//! - DerivedBidiClass.txt -> Bidirectional character classes
//! - UnicodeData.txt -> Character properties
//!
//! Usage: zig run tools/generate_idna_tables.zig > src/idna/unicode_data.zig

const std = @import("std");

const IdnaStatus = enum {
    valid,
    ignored,
    mapped,
    deviation,
    disallowed,
    disallowed_std3_valid,
    disallowed_std3_mapped,
};

const IdnaMapping = struct {
    start: u21,
    end: u21,
    status: IdnaStatus,
    mapping: ?[]const u8, // For mapped characters
};

const BidiClass = enum {
    L, // Left-to-Right
    R, // Right-to-Left
    AL, // Right-to-Left Arabic
    EN, // European Number
    ES, // European Number Separator
    ET, // European Number Terminator
    AN, // Arabic Number
    CS, // Common Number Separator
    NSM, // Nonspacing Mark
    BN, // Boundary Neutral
    B, // Paragraph Separator
    S, // Segment Separator
    WS, // Whitespace
    ON, // Other Neutrals
    LRE, // Left-to-Right Embedding
    LRO, // Left-to-Right Override
    RLE, // Right-to-Left Embedding
    RLO, // Right-to-Left Override
    PDF, // Pop Directional Format
    LRI, // Left-to-Right Isolate
    RLI, // Right-to-Left Isolate
    FSI, // First Strong Isolate
    PDI, // Pop Directional Isolate
};

const BidiRange = struct {
    start: u21,
    end: u21,
    class: BidiClass,
};

const DecompositionMapping = struct {
    codepoint: u21,
    decomposition: []const u21,
};

const CompositionPair = struct {
    first: u21,
    second: u21,
    composed: u21,
};

const CombiningClass = struct {
    codepoint: u21,
    class: u8,
};

const CompositionExclusion = struct {
    start: u21,
    end: u21,
};

fn parseCodePoint(s: []const u8) !u21 {
    return std.fmt.parseInt(u21, s, 16);
}

fn parseCodePointRange(s: []const u8) !struct { start: u21, end: u21 } {
    if (std.mem.indexOf(u8, s, "..")) |idx| {
        const start = try parseCodePoint(s[0..idx]);
        const end = try parseCodePoint(s[idx + 2 ..]);
        return .{ .start = start, .end = end };
    } else {
        const cp = try parseCodePoint(s);
        return .{ .start = cp, .end = cp };
    }
}

fn parseBidiClass(s: []const u8) !BidiClass {
    var trimmed = std.mem.trim(u8, s, " \t");
    // Strip comment (after #)
    if (std.mem.indexOf(u8, trimmed, "#")) |idx| {
        trimmed = std.mem.trim(u8, trimmed[0..idx], " \t");
    }
    return std.meta.stringToEnum(BidiClass, trimmed) orelse return error.InvalidBidiClass;
}

fn readUnicodeData(allocator: std.mem.Allocator, path: []const u8) !struct {
    decompositions: []DecompositionMapping,
    compositions: []CompositionPair,
    combining_classes: []CombiningClass,
} {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);

    var decomp_list = std.ArrayList(DecompositionMapping).empty;
    var comp_list = std.ArrayList(CompositionPair).empty;
    var cc_list = std.ArrayList(CombiningClass).empty;

    defer {
        for (decomp_list.items) |d| allocator.free(d.decomposition);
        decomp_list.deinit(allocator);
        comp_list.deinit(allocator);
        cc_list.deinit(allocator);
    }

    var line_iter = std.mem.splitScalar(u8, content, '\n');
    while (line_iter.next()) |line| {
        if (line.len == 0) continue;

        // Format: codepoint;name;category;combining_class;bidi_class;decomposition;...
        var parts = std.mem.splitScalar(u8, line, ';');
        const cp_str = parts.next() orelse continue;
        _ = parts.next(); // name
        _ = parts.next(); // category
        const cc_str = parts.next() orelse continue;
        _ = parts.next(); // bidi class
        const decomp_str = parts.next() orelse continue;

        const codepoint = parseCodePoint(cp_str) catch continue;

        // Parse combining class
        const cc_trimmed = std.mem.trim(u8, cc_str, " \t");
        if (cc_trimmed.len > 0) {
            const cc = std.fmt.parseInt(u8, cc_trimmed, 10) catch 0;
            if (cc != 0) {
                try cc_list.append(allocator, .{
                    .codepoint = codepoint,
                    .class = cc,
                });
            }
        }

        // Parse decomposition if present
        const decomp_trimmed = std.mem.trim(u8, decomp_str, " \t");
        if (decomp_trimmed.len == 0) continue;

        // Skip compatibility decompositions (start with <tag>)
        if (decomp_trimmed[0] == '<') continue;

        // Parse canonical decomposition (space-separated hex values)
        var decomp_cps = std.ArrayList(u21).empty;
        defer decomp_cps.deinit(allocator);

        var cp_iter = std.mem.splitScalar(u8, decomp_trimmed, ' ');
        while (cp_iter.next()) |cp_hex| {
            const trimmed = std.mem.trim(u8, cp_hex, " \t");
            if (trimmed.len == 0) continue;
            const cp = parseCodePoint(trimmed) catch continue;
            try decomp_cps.append(allocator, cp);
        }

        if (decomp_cps.items.len == 0) continue;

        // Add decomposition mapping
        const owned_decomp = try decomp_cps.toOwnedSlice(allocator);

        // Create composition mapping (reverse of decomposition)
        // Only for 2-codepoint decompositions
        if (owned_decomp.len == 2) {
            try comp_list.append(allocator, .{
                .first = owned_decomp[0],
                .second = owned_decomp[1],
                .composed = codepoint,
            });
        }

        try decomp_list.append(allocator, .{
            .codepoint = codepoint,
            .decomposition = owned_decomp,
        });
    }

    return .{
        .decompositions = try decomp_list.toOwnedSlice(allocator),
        .compositions = try comp_list.toOwnedSlice(allocator),
        .combining_classes = try cc_list.toOwnedSlice(allocator),
    };
}

fn parseIdnaStatus(s: []const u8) !IdnaStatus {
    var trimmed = std.mem.trim(u8, s, " \t");
    // Strip comment (after #)
    if (std.mem.indexOf(u8, trimmed, "#")) |idx| {
        trimmed = std.mem.trim(u8, trimmed[0..idx], " \t");
    }
    if (std.mem.eql(u8, trimmed, "valid")) return .valid;
    if (std.mem.eql(u8, trimmed, "ignored")) return .ignored;
    if (std.mem.eql(u8, trimmed, "mapped")) return .mapped;
    if (std.mem.eql(u8, trimmed, "deviation")) return .deviation;
    if (std.mem.eql(u8, trimmed, "disallowed")) return .disallowed;
    if (std.mem.eql(u8, trimmed, "disallowed_STD3_valid")) return .disallowed_std3_valid;
    if (std.mem.eql(u8, trimmed, "disallowed_STD3_mapped")) return .disallowed_std3_mapped;
    return error.InvalidIdnaStatus;
}

fn readIdnaMappingTable(allocator: std.mem.Allocator, path: []const u8) ![]IdnaMapping {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);

    var mappings = std.ArrayList(IdnaMapping).empty;
    errdefer {
        for (mappings.items) |m| {
            if (m.mapping) |map| allocator.free(map);
        }
        mappings.deinit(allocator);
    }

    var line_iter = std.mem.splitScalar(u8, content, '\n');
    while (line_iter.next()) |line| {
        if (line.len == 0 or line[0] == '#') continue;

        // Format: codepoint(s) ; status [ ; mapping ]
        var parts_iter = std.mem.splitScalar(u8, line, ';');
        const range_str = std.mem.trim(u8, parts_iter.next() orelse continue, " \t");
        const status_str = parts_iter.next() orelse continue;
        const mapping_str = if (parts_iter.next()) |m| std.mem.trim(u8, m, " \t") else null;

        const range = parseCodePointRange(range_str) catch continue;
        const status = parseIdnaStatus(status_str) catch continue;

        // Parse mapping if present (convert hex codepoints to UTF-8)
        var mapping: ?[]const u8 = null;
        if (mapping_str) |ms| {
            if (ms.len > 0 and ms[0] != '#') {
                // Split off comment
                const map_part = if (std.mem.indexOf(u8, ms, "#")) |idx|
                    std.mem.trim(u8, ms[0..idx], " \t")
                else
                    std.mem.trim(u8, ms, " \t");

                if (map_part.len > 0) {
                    // Convert hex codepoints to UTF-8 string
                    var result = std.ArrayList(u8).empty;
                    defer result.deinit(allocator);

                    var cp_iter = std.mem.splitScalar(u8, map_part, ' ');
                    while (cp_iter.next()) |cp_str| {
                        const trimmed = std.mem.trim(u8, cp_str, " \t");
                        if (trimmed.len == 0) continue;

                        const cp = std.fmt.parseInt(u21, trimmed, 16) catch continue;
                        var buf: [4]u8 = undefined;
                        const len = std.unicode.utf8Encode(cp, &buf) catch continue;
                        try result.appendSlice(allocator, buf[0..len]);
                    }

                    if (result.items.len > 0) {
                        mapping = try result.toOwnedSlice(allocator);
                    }
                }
            }
        }

        try mappings.append(allocator, .{
            .start = range.start,
            .end = range.end,
            .status = status,
            .mapping = mapping,
        });
    }

    return mappings.toOwnedSlice(allocator);
}

fn readCompositionExclusions(allocator: std.mem.Allocator, path: []const u8) ![]CompositionExclusion {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);

    var exclusions = std.ArrayList(CompositionExclusion).empty;
    errdefer exclusions.deinit(allocator);

    var line_iter = std.mem.splitScalar(u8, content, '\n');
    while (line_iter.next()) |line| {
        if (line.len == 0 or line[0] == '#') continue;
        if (std.mem.indexOf(u8, line, "Full_Composition_Exclusion") == null) continue;

        // Format: codepoint(s) ; Full_Composition_Exclusion
        var parts_iter = std.mem.splitScalar(u8, line, ';');
        const range_str = std.mem.trim(u8, parts_iter.next() orelse continue, " \t");

        const range = parseCodePointRange(range_str) catch continue;
        try exclusions.append(allocator, .{
            .start = range.start,
            .end = range.end,
        });
    }

    return exclusions.toOwnedSlice(allocator);
}

fn readBidiClasses(allocator: std.mem.Allocator, path: []const u8) ![]BidiRange {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);

    var ranges = std.ArrayList(BidiRange).empty;
    errdefer ranges.deinit(allocator);

    var line_iter = std.mem.splitScalar(u8, content, '\n');
    while (line_iter.next()) |line| {
        if (line.len == 0 or line[0] == '#') continue;

        // Format: codepoint(s) ; bidi_class
        var parts_iter = std.mem.splitScalar(u8, line, ';');
        const range_str = std.mem.trim(u8, parts_iter.next() orelse continue, " \t");
        const class_str = parts_iter.next() orelse continue;

        const range = parseCodePointRange(range_str) catch continue;
        const class = parseBidiClass(class_str) catch continue;

        try ranges.append(allocator, .{
            .start = range.start,
            .end = range.end,
            .class = class,
        });
    }

    return ranges.toOwnedSlice(allocator);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("[IDNA Tables Generator] Starting...\n", .{});

    // Read IDNA mapping table
    std.debug.print("[IDNA Tables Generator] Reading IdnaMappingTable.txt...\n", .{});
    const idna_mappings = try readIdnaMappingTable(allocator, "data/unicode/IdnaMappingTable.txt");
    defer {
        for (idna_mappings) |m| {
            if (m.mapping) |map| allocator.free(map);
        }
        allocator.free(idna_mappings);
    }
    std.debug.print("[IDNA Tables Generator] Loaded {} IDNA mappings\n", .{idna_mappings.len});

    // Read bidi classes
    std.debug.print("[IDNA Tables Generator] Reading DerivedBidiClass.txt...\n", .{});
    const bidi_ranges = try readBidiClasses(allocator, "data/unicode/DerivedBidiClass.txt");
    defer allocator.free(bidi_ranges);
    std.debug.print("[IDNA Tables Generator] Loaded {} bidi ranges\n", .{bidi_ranges.len});

    // Read Unicode decomposition/composition data
    std.debug.print("[IDNA Tables Generator] Reading UnicodeData.txt...\n", .{});
    const unicode_data = try readUnicodeData(allocator, "data/unicode/UnicodeData.txt");
    defer {
        for (unicode_data.decompositions) |d| allocator.free(d.decomposition);
        allocator.free(unicode_data.decompositions);
        allocator.free(unicode_data.compositions);
        allocator.free(unicode_data.combining_classes);
    }
    std.debug.print("[IDNA Tables Generator] Loaded {} decompositions, {} compositions, {} combining classes\n", .{
        unicode_data.decompositions.len,
        unicode_data.compositions.len,
        unicode_data.combining_classes.len,
    });

    // Read composition exclusions
    std.debug.print("[IDNA Tables Generator] Reading DerivedNormalizationProps.txt...\n", .{});
    const exclusions = try readCompositionExclusions(allocator, "data/unicode/DerivedNormalizationProps.txt");
    defer allocator.free(exclusions);
    std.debug.print("[IDNA Tables Generator] Loaded {} composition exclusions\n", .{exclusions.len});

    // Create output file
    std.debug.print("[IDNA Tables Generator] Generating src/idna/unicode_data.zig...\n", .{});

    // Build output in memory
    var output = std.ArrayList(u8).empty;
    defer output.deinit(allocator);

    const writer = output.writer(allocator);

    // Generate Zig source code
    try writer.writeAll(
        \\//! Generated IDNA Unicode data tables
        \\//!
        \\//! Generated from Unicode 15.1.0 data files:
        \\//! - IdnaMappingTable.txt
        \\//! - DerivedBidiClass.txt
        \\//! - UnicodeData.txt
        \\//!
        \\//! DO NOT EDIT - This file is auto-generated by tools/generate_idna_tables.zig
        \\
        \\const std = @import("std");
        \\
        \\pub const IdnaStatus = enum {
        \\    valid,
        \\    ignored,
        \\    mapped,
        \\    deviation,
        \\    disallowed,
        \\    disallowed_std3_valid,
        \\    disallowed_std3_mapped,
        \\};
        \\
        \\pub const BidiClass = enum {
        \\    L, R, AL, EN, ES, ET, AN, CS, NSM, BN, B, S, WS, ON,
        \\    LRE, LRO, RLE, RLO, PDF, LRI, RLI, FSI, PDI,
        \\};
        \\
        \\pub const IdnaMapping = struct {
        \\    start: u21,
        \\    end: u21,
        \\    status: IdnaStatus,
        \\    mapping: ?[]const u8,
        \\};
        \\
        \\pub const BidiRange = struct {
        \\    start: u21,
        \\    end: u21,
        \\    class: BidiClass,
        \\};
        \\
        \\pub const DecompositionMapping = struct {
        \\    codepoint: u21,
        \\    decomposition: []const u21,
        \\};
        \\
        \\pub const CompositionPair = struct {
        \\    first: u21,
        \\    second: u21,
        \\    composed: u21,
        \\};
        \\
        \\pub const CombiningClass = struct {
        \\    codepoint: u21,
        \\    class: u8,
        \\};
        \\
        \\pub const CompositionExclusion = struct {
        \\    start: u21,
        \\    end: u21,
        \\};
        \\
        \\/// IDNA character mappings
        \\
    );

    try writer.print("pub const idna_mappings = [_]IdnaMapping{{\n", .{});
    for (idna_mappings) |m| {
        try writer.print("    .{{ .start = 0x{X:0>4}, .end = 0x{X:0>4}, .status = .{s}", .{
            m.start,
            m.end,
            @tagName(m.status),
        });
        if (m.mapping) |map| {
            // Escape special characters in string literal
            try writer.writeAll(", .mapping = \"");
            for (map) |byte| {
                switch (byte) {
                    '\n' => try writer.writeAll("\\n"),
                    '\r' => try writer.writeAll("\\r"),
                    '\t' => try writer.writeAll("\\t"),
                    '\\' => try writer.writeAll("\\\\"),
                    '"' => try writer.writeAll("\\\""),
                    else => try writer.writeByte(byte),
                }
            }
            try writer.writeAll("\" },\n");
        } else {
            try writer.print(", .mapping = null }},\n", .{});
        }
    }
    try writer.print("}};\n\n", .{});

    try writer.print("/// Bidirectional character classes\n", .{});
    try writer.print("pub const bidi_ranges = [_]BidiRange{{\n", .{});
    for (bidi_ranges) |r| {
        try writer.print("    .{{ .start = 0x{X:0>4}, .end = 0x{X:0>4}, .class = .{s} }},\n", .{
            r.start,
            r.end,
            @tagName(r.class),
        });
    }
    try writer.print("}};\n\n", .{});

    // Write decomposition mappings
    try writer.print("/// Unicode canonical decompositions\n", .{});
    try writer.print("pub const decompositions = [_]DecompositionMapping{{\n", .{});
    for (unicode_data.decompositions) |d| {
        try writer.print("    .{{ .codepoint = 0x{X:0>4}, .decomposition = &[_]u21{{", .{d.codepoint});
        for (d.decomposition, 0..) |cp, i| {
            if (i > 0) try writer.writeAll(", ");
            try writer.print("0x{X:0>4}", .{cp});
        }
        try writer.print("}} }},\n", .{});
    }
    try writer.print("}};\n\n", .{});

    // Write composition pairs
    try writer.print("/// Unicode canonical compositions\n", .{});
    try writer.print("pub const compositions = [_]CompositionPair{{\n", .{});
    for (unicode_data.compositions) |c| {
        try writer.print("    .{{ .first = 0x{X:0>4}, .second = 0x{X:0>4}, .composed = 0x{X:0>4} }},\n", .{
            c.first,
            c.second,
            c.composed,
        });
    }
    try writer.print("}};\n\n", .{});

    // Write combining classes
    try writer.print("/// Unicode canonical combining classes\n", .{});
    try writer.print("pub const combining_classes = [_]CombiningClass{{\n", .{});
    for (unicode_data.combining_classes) |cc| {
        try writer.print("    .{{ .codepoint = 0x{X:0>4}, .class = {} }},\n", .{
            cc.codepoint,
            cc.class,
        });
    }
    try writer.print("}};\n\n", .{});

    // Write composition exclusions
    try writer.print("/// Unicode composition exclusions\n", .{});
    try writer.print("pub const composition_exclusions = [_]CompositionExclusion{{\n", .{});
    for (exclusions) |ex| {
        try writer.print("    .{{ .start = 0x{X:0>4}, .end = 0x{X:0>4} }},\n", .{
            ex.start,
            ex.end,
        });
    }
    try writer.print("}};\n\n", .{});

    try writer.writeAll(
        \\/// Look up IDNA status for a code point
        \\pub fn lookupIdnaStatus(cp: u21) struct { status: IdnaStatus, mapping: ?[]const u8 } {
        \\    for (idna_mappings) |m| {
        \\        if (cp >= m.start and cp <= m.end) {
        \\            return .{ .status = m.status, .mapping = m.mapping };
        \\        }
        \\    }
        \\    // Default: unmapped code points
        \\    // ASCII (0x00-0x7F): Most are valid unless explicitly mapped/disallowed
        \\    // Period (.) is valid as label separator
        \\    if (cp == 0x002E) return .{ .status = .valid, .mapping = null }; // .
        \\    if (cp == 0x002D) return .{ .status = .valid, .mapping = null }; // -
        \\    if (cp >= '0' and cp <= '9') return .{ .status = .valid, .mapping = null };
        \\    if (cp >= 'a' and cp <= 'z') return .{ .status = .valid, .mapping = null };
        \\    // Non-ASCII: default to valid for now (full IDNA would have complete tables)
        \\    if (cp >= 0x80) return .{ .status = .valid, .mapping = null };
        \\    // Other ASCII: disallowed
        \\    return .{ .status = .disallowed, .mapping = null };
        \\}
        \\
        \\/// Look up bidi class for a code point
        \\pub fn lookupBidiClass(cp: u21) BidiClass {
        \\    for (bidi_ranges) |r| {
        \\        if (cp >= r.start and cp <= r.end) {
        \\            return r.class;
        \\        }
        \\    }
        \\    return .L; // Default to LTR
        \\}
        \\
        \\/// Look up canonical decomposition for a code point
        \\pub fn lookupDecomposition(cp: u21) ?[]const u21 {
        \\    for (decompositions) |d| {
        \\        if (d.codepoint == cp) {
        \\            return d.decomposition;
        \\        }
        \\    }
        \\    return null;
        \\}
        \\
        \\/// Look up canonical composition for a pair of code points
        \\pub fn lookupComposition(first: u21, second: u21) ?u21 {
        \\    for (compositions) |c| {
        \\        if (c.first == first and c.second == second) {
        \\            return c.composed;
        \\        }
        \\    }
        \\    return null;
        \\}
        \\
        \\/// Look up combining class for a code point
        \\pub fn lookupCombiningClass(cp: u21) u8 {
        \\    for (combining_classes) |cc| {
        \\        if (cc.codepoint == cp) {
        \\            return cc.class;
        \\        }
        \\    }
        \\    return 0; // Default combining class
        \\}
        \\
        \\/// Check if a code point is excluded from composition
        \\pub fn isCompositionExcluded(cp: u21) bool {
        \\    for (composition_exclusions) |ex| {
        \\        if (cp >= ex.start and cp <= ex.end) {
        \\            return true;
        \\        }
        \\    }
        \\    return false;
        \\}
        \\
    );

    // Write output to file
    try std.fs.cwd().writeFile(.{
        .sub_path = "src/idna/unicode_data.zig",
        .data = output.items,
    });

    std.debug.print("[IDNA Tables Generator] ✅ Complete!\n", .{});
    std.debug.print("  - {} IDNA mappings\n", .{idna_mappings.len});
    std.debug.print("  - {} bidi ranges\n", .{bidi_ranges.len});
    std.debug.print("  - {} decompositions\n", .{unicode_data.decompositions.len});
    std.debug.print("  - {} compositions\n", .{unicode_data.compositions.len});
    std.debug.print("  - {} combining classes\n", .{unicode_data.combining_classes.len});
    std.debug.print("  - {} composition exclusions\n", .{exclusions.len});
}
