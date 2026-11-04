//! Build step: the Public Suffix List's rules as a sorted table, computed once
//! and embedded (lane compiletime1, 2026-11-04).
//!
//! src/url/public_suffix_data.zig holds the rules as a
//! `std.StaticStringMap(void).initComptime` of 9,969 entries, which sorts them
//! at compile time: 1.3 s of single-threaded Sema in every binary that reached
//! src/url (lane onebin2's time report). build.zig runs this tool on that file
//! once instead (Zig caches the output while the file is unchanged) and
//! src/url/public_suffix.zig @embedFile's the table; the map is analysed only
//! by the test that compares the two (tests/url/psl_table_test.zig).
//!
//! The table, every integer a little-endian u32:
//!   count, max_len, offsets[count + 1], then the rules' bytes back to back -
//!   rule i is bytes[offsets[i]..offsets[i + 1]], the rules sorted bytewise
//!   and each listed once, so a lookup is a binary search.
//!
//!   psl_table <src/url/public_suffix_data.zig> <psl_table.bin>

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const ParseError = error{ MalformedRuleLine, NoRuleCount, RuleCountMismatch, NoRules } || Allocator.Error;

const rule_prefix = "    .{ \"";
const rule_suffix = "\", {} },";
const map_start = "pub const PSL_RULES = std.StaticStringMap(void).initComptime(.{";
const map_end = "});";
const count_prefix = "pub const PSL_RULE_COUNT: usize = ";

/// The rules of public_suffix_data.zig, in its order. Every line between the
/// map's first and last line is one rule entry, and their number is the
/// file's PSL_RULE_COUNT - a file in any other shape is refused, never read
/// partly.
pub fn parseRules(allocator: Allocator, source: []const u8) ParseError![][]const u8 {
    var rules: std.ArrayList([]const u8) = .empty;
    errdefer rules.deinit(allocator);
    var declared: ?usize = null;
    var inside = false;
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trimEnd(u8, raw, "\r");
        if (!inside) {
            if (std.mem.eql(u8, line, map_start)) inside = true;
            if (std.mem.startsWith(u8, line, count_prefix) and std.mem.endsWith(u8, line, ";")) {
                declared = std.fmt.parseInt(usize, line[count_prefix.len .. line.len - 1], 10) catch return error.NoRuleCount;
            }
            continue;
        }
        if (std.mem.eql(u8, line, map_end)) {
            inside = false;
            continue;
        }
        if (!std.mem.startsWith(u8, line, rule_prefix) or !std.mem.endsWith(u8, line, rule_suffix) or line.len <= rule_prefix.len + rule_suffix.len)
            return error.MalformedRuleLine;
        const rule = line[rule_prefix.len .. line.len - rule_suffix.len];
        // A Zig escape would change the rule's bytes; the list has none.
        if (std.mem.indexOfAny(u8, rule, "\\\"") != null) return error.MalformedRuleLine;
        try rules.append(allocator, rule);
    }
    if (rules.items.len == 0) return error.NoRules;
    const count = declared orelse return error.NoRuleCount;
    if (count != rules.items.len) return error.RuleCountMismatch;
    return rules.toOwnedSlice(allocator);
}

fn bytewise(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

/// The embedded table of `rules`: sorted bytewise, each rule once.
pub fn buildTable(allocator: Allocator, rules: []const []const u8) Allocator.Error![]u8 {
    const sorted = try allocator.dupe([]const u8, rules);
    defer allocator.free(sorted);
    std.mem.sort([]const u8, sorted, {}, bytewise);
    var unique: usize = 0;
    var bytes_len: usize = 0;
    var max_len: usize = 0;
    for (sorted, 0..) |rule, i| {
        if (i > 0 and std.mem.eql(u8, rule, sorted[unique - 1])) continue;
        sorted[unique] = rule;
        unique += 1;
        bytes_len += rule.len;
        max_len = @max(max_len, rule.len);
    }
    const header = 8 + 4 * (unique + 1);
    const table = try allocator.alloc(u8, header + bytes_len);
    std.mem.writeInt(u32, table[0..4], @intCast(unique), .little);
    std.mem.writeInt(u32, table[4..8], @intCast(max_len), .little);
    var at: usize = header;
    for (sorted[0..unique], 0..) |rule, i| {
        std.mem.writeInt(u32, table[8 + 4 * i ..][0..4], @intCast(at - header), .little);
        @memcpy(table[at .. at + rule.len], rule);
        at += rule.len;
    }
    std.mem.writeInt(u32, table[8 + 4 * unique ..][0..4], @intCast(at - header), .little);
    return table;
}

pub fn main(init: std.process.Init) !void {
    var arena_state = std.heap.ArenaAllocator.init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(arena);
    if (args.len != 3) {
        std.debug.print("usage: psl_table <public_suffix_data.zig> <psl_table.bin>\n", .{});
        std.process.exit(2);
    }
    const source = try std.Io.Dir.cwd().readFileAlloc(io, args[1], arena, .limited(16 << 20));
    const rules = parseRules(arena, source) catch |err| {
        std.debug.print("psl_table: {s}: {s}\n", .{ args[1], @errorName(err) });
        std.process.exit(1);
    };
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = args[2], .data = try buildTable(arena, rules) });
}

const testing = std.testing;

const fixture =
    \\//! Public Suffix List Data (Auto-generated)
    \\
    \\const std = @import("std");
    \\
    \\/// Public Suffix List rules as a compile-time string map
    \\pub const PSL_RULES = std.StaticStringMap(void).initComptime(.{
    \\    .{ "ac", {} },
    \\    .{ "com.ac", {} },
    \\    .{ "*.ck", {} },
    \\    .{ "!www.ck", {} },
    \\    .{ "公司.cn", {} },
    \\});
    \\
    \\/// Total number of PSL rules
    \\pub const PSL_RULE_COUNT: usize = 5;
    \\
;

test "the rules are read from the map's lines, in the file's order" {
    const rules = try parseRules(testing.allocator, fixture);
    defer testing.allocator.free(rules);
    try testing.expectEqual(@as(usize, 5), rules.len);
    try testing.expectEqualStrings("ac", rules[0]);
    try testing.expectEqualStrings("*.ck", rules[2]);
    try testing.expectEqualStrings("!www.ck", rules[3]);
    try testing.expectEqualStrings("公司.cn", rules[4]);
}

test "a file in another shape is refused, never read partly" {
    const changed_count = try std.mem.replaceOwned(u8, testing.allocator, fixture, "COUNT: usize = 5;", "COUNT: usize = 6;");
    defer testing.allocator.free(changed_count);
    try testing.expectError(error.RuleCountMismatch, parseRules(testing.allocator, changed_count));
    const odd_line = try std.mem.replaceOwned(u8, testing.allocator, fixture, "    .{ \"ac\", {} },", "    .{ \"ac\", void },");
    defer testing.allocator.free(odd_line);
    try testing.expectError(error.MalformedRuleLine, parseRules(testing.allocator, odd_line));
    const escaped = try std.mem.replaceOwned(u8, testing.allocator, fixture, "com.ac", "com\\x2eac");
    defer testing.allocator.free(escaped);
    try testing.expectError(error.MalformedRuleLine, parseRules(testing.allocator, escaped));
    try testing.expectError(error.NoRules, parseRules(testing.allocator, "pub const PSL_RULE_COUNT: usize = 0;\n"));
}

test "the table holds the rules sorted bytewise, each once, with their longest length" {
    const table = try buildTable(testing.allocator, &.{ "com.ac", "ac", "!www.ck", "ac", "*.ck" });
    defer testing.allocator.free(table);
    try testing.expectEqual(@as(u32, 4), std.mem.readInt(u32, table[0..4], .little));
    try testing.expectEqual(@as(u32, 7), std.mem.readInt(u32, table[4..8], .little));
    const header = 8 + 4 * 5;
    const expected = [_][]const u8{ "!www.ck", "*.ck", "ac", "com.ac" };
    for (expected, 0..) |rule, i| {
        const start = std.mem.readInt(u32, table[8 + 4 * i ..][0..4], .little);
        const end = std.mem.readInt(u32, table[8 + 4 * (i + 1) ..][0..4], .little);
        try testing.expectEqualStrings(rule, table[header + start .. header + end]);
    }
    try testing.expectEqual(header + 7 + 4 + 2 + 6, table.len);
}
