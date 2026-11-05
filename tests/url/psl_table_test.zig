//! The Public Suffix List's embedded rule table (tools/url/psl_table.zig, a
//! build step; lane compiletime1) holds exactly the rules of the compile-time
//! map it replaced (public_suffix_data.zig's PSL_RULES), and answers every
//! lookup the map answered.
const std = @import("std");
const url = @import("url");
const public_suffix = url.public_suffix;

test "the embedded table holds every rule of today's compile-time map, and nothing else" {
    const map = public_suffix.source_rules;
    const table = public_suffix.rules;
    // Every key of the map is in the table. The map keeps a repeated rule
    // twice; the table once.
    var distinct: std.StringHashMapUnmanaged(void) = .empty;
    defer distinct.deinit(std.testing.allocator);
    for (map.keys()) |key| {
        try std.testing.expect(table.has(key));
        try distinct.put(std.testing.allocator, key, {});
    }
    // Every rule of the table is a key of the map, in bytewise order.
    try std.testing.expectEqual(@as(usize, distinct.count()), table.count());
    for (0..table.count()) |i| {
        try std.testing.expect(map.has(table.rule(i)));
        if (i > 0) try std.testing.expect(std.mem.lessThan(u8, table.rule(i - 1), table.rule(i)));
    }
    try std.testing.expectEqual(@as(usize, map.max_len), table.maxLen());
}

test "the table and the map agree on lookups that are not rules" {
    const map = public_suffix.source_rules;
    const table = public_suffix.rules;
    const probes = [_][]const u8{ "", "c", "co", "example.com", "com.", ".com", "*.com", "!com", "github", "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz" };
    for (probes) |probe| try std.testing.expectEqual(map.has(probe), table.has(probe));
    // A prefix and an extension of each rule.
    for (map.keys()) |key| {
        try std.testing.expectEqual(map.has(key[0 .. key.len - 1]), table.has(key[0 .. key.len - 1]));
        var longer: [128]u8 = undefined;
        if (key.len + 1 <= longer.len) {
            @memcpy(longer[0..key.len], key);
            longer[key.len] = 'x';
            try std.testing.expectEqual(map.has(longer[0 .. key.len + 1]), table.has(longer[0 .. key.len + 1]));
        }
    }
}
