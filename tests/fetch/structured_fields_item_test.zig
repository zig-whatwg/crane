//! RFC 9651 §4.2 with field type "item", as Fetch's "get a structured field
//! value" given "item" parses a header - projected onto the Boolean that
//! HTML's `Origin-Agent-Cluster` reads ("create and initialize a Document
//! object" steps 7.1-7.2: the header's item is the Boolean true).

const std = @import("std");
const fetch = @import("fetch");

const structured_fields = fetch.internal.structured_fields;

fn expectBoolean(input: []const u8, expected: ?bool) !void {
    const parsed = try structured_fields.parseItemBoolean(std.testing.allocator, input);
    try std.testing.expectEqual(expected, parsed);
}

fn expectInvalid(input: []const u8) !void {
    try std.testing.expectError(error.InvalidField, structured_fields.parseItemBoolean(std.testing.allocator, input));
}

test "a Boolean item: ?1 and ?0, around SP, with parameters" {
    try expectBoolean("?1", true);
    try expectBoolean("?0", false);
    // §4.2 steps 2 and 6: leading and trailing SP are discarded.
    try expectBoolean("  ?1  ", true);
    // §4.2.3: an item's parameters follow its bare item; a parameter with no
    // value is the Boolean true, and a later one of the same key replaces it.
    try expectBoolean("?1;param1;param2=value2", true);
    try expectBoolean("?1; a=1; a=\"x\"", true);
    try expectBoolean("?0;a", false);
}

test "a valid item of another type is not a Boolean" {
    try expectBoolean("1", null);
    try expectBoolean("-1.5", null);
    try expectBoolean("\"?1\"", null);
    try expectBoolean("true", null);
    try expectBoolean(":cHJldGVuZCB0aGlzIGlzIGJpbmFyeQ==:", null);
    try expectBoolean("@1659578233", null);
    try expectBoolean("%\"f%c3%bc%c3%bc\"", null);
}

test "a field that is not exactly one item fails" {
    try expectInvalid("");
    try expectInvalid("   ");
    // Two values, combined with ", " by the header list's get: a list, not
    // an item.
    try expectInvalid("?1, ?1");
    try expectInvalid("?1 ?1");
    try expectInvalid("?2");
    try expectInvalid("?");
    // After the Boolean, "a" is neither a parameter nor the end.
    try expectInvalid("?1a");
    try expectInvalid("?1;");
    try expectInvalid("?1;A");
    // §4.2 step 2 discards SP only: a leading tab fails.
    try expectInvalid("\t?1");
    try expectInvalid("(?1)");
    try expectInvalid("?1\xc3\xa9");
}

test "parsing an item frees what it validates" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn run(allocator: std.mem.Allocator) !void {
            _ = structured_fields.parseItemBoolean(allocator, "\"a string\";p=\"another\"") catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.InvalidField => return error.TestUnexpectedResult,
            };
        }
    }.run, .{});
}
