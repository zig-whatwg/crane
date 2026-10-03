//! [EnforceRange] and [Clamp] are steps of an integer conversion (WebIDL 3.2.4
//! ConvertToInt steps 6 and 7), which the binding runs: codegen lists the
//! arguments, attribute values, constructor arguments and dictionary members
//! that carry them, and writes no check on the already-converted value - that
//! check passed every wrapped value and failed every omitted optional.

const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

const fixture = "tests/codegen/fixtures/integer_conversions";

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

fn expectIn(text: []const u8, what: []const u8, needle: []const u8) !void {
    if (!contains(text, needle)) {
        std.debug.print("{s} lacks `{s}`:\n{s}\n", .{ what, needle, text });
        return error.TestExpectedEqual;
    }
}

fn expectNotIn(text: []const u8, what: []const u8, needle: []const u8) !void {
    if (contains(text, needle)) {
        std.debug.print("{s} has `{s}`:\n{s}\n", .{ what, needle, text });
        return error.TestUnexpectedResult;
    }
}

fn readOut(root: []const u8, sub_path: []const u8) ![]u8 {
    const path = try std.fs.path.join(testing.allocator, &.{ root, sub_path });
    defer testing.allocator.free(path);
    return std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(1024 * 1024));
}

test "the binding learns [EnforceRange] and [Clamp] from tables, and no generated check remains" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);
    var cfg = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
    defer cfg.deinit();
    try codegen.processSources(testing.allocator, &.{fixture}, &cfg);

    const iface = try readOut(root, "interfaces/Counter.zig");
    defer testing.allocator.free(iface);
    const what = "interfaces/Counter.zig";
    try expectIn(iface, what, "pub const enforce_range = .{");
    try expectIn(iface, what, ".{ \"set_limit\", 0b1 },");
    try expectIn(iface, what, ".{ \"call_open\", 0b10 },");
    try expectIn(iface, what, ".{ \"call_static_timeout\", 0b1 },");
    try expectIn(iface, what, "pub const clamp = .{");
    try expectIn(iface, what, ".{ \"call_slice\", 0b11 },");
    try expectIn(iface, what, "pub const constructor_enforce_range: u32 = 0b1;");
    try expectIn(iface, what, "pub const constructor_clamp: u32 = 0b10;");
    try expectNotIn(iface, what, "call_plain\", 0b");
    // The values go to the impl as the binding converted them.
    try expectNotIn(iface, what, "isInRange");
    try expectNotIn(iface, what, "runtime.clamp");
    try expectIn(iface, what, "return try CounterImpl.call_open(instance, name, version);");
    try expectIn(iface, what, "return try CounterImpl.call_slice(instance, start, end);");

    const dictionary = try readOut(root, "dictionaries/Ranged.zig");
    defer testing.allocator.free(dictionary);
    try expectIn(dictionary, "dictionaries/Ranged.zig", "pub const enforce_range_members = .{\"count\"};");
    try expectIn(dictionary, "dictionaries/Ranged.zig", "pub const clamp_members = .{\"level\"};");
}
