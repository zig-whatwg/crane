//! WebIDL 3.7.9: an iterable declaration's entries, keys, values, forEach and
//! %Symbol.iterator% are not operations. "Define the iteration methods" makes
//! them: for a value iterator (an interface that supports indexed
//! properties) the realm's %Array.prototype.entries%, keys, values and
//! forEach; for a pair iterator functions of its own, over the value pairs to
//! iterate over. Neither reaches an impl through the binding map.
//!
//! Codegen used to add a synthetic `forEach` operation for every iterable
//! interface - twice in `Meta.methods`, a `call_forEach` delegate, and an
//! impl stub that returned NotImplemented - so NodeList and DOMTokenList bound
//! forEach to stubs that never called the callback.
const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

fn generated(root: []const u8, comptime dir: []const u8, name: []const u8) ![]u8 {
    const file = try std.fmt.allocPrint(testing.allocator, "{s}/" ++ dir ++ "/{s}.zig", .{ root, name });
    defer testing.allocator.free(file);
    return std.Io.Dir.cwd().readFileAlloc(testing.io, file, testing.allocator, .limited(65536));
}

test "an iterable declaration emits no forEach operation, delegate or impl stub" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);
    var config = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
    defer config.deinit();
    try codegen.processSources(testing.allocator, &.{"tests/codegen/fixtures/iterable_members"}, &config);
    for ([_][]const u8{ "ValueList", "PairList" }) |name| {
        const interface = try generated(root, "interfaces", name);
        defer testing.allocator.free(interface);
        // The declaration itself still reaches the binding.
        try testing.expect(std.mem.indexOf(u8, interface, "pub const iterable = .{") != null);
        try testing.expect(std.mem.indexOf(u8, interface, "forEach") == null);
        const stub = try generated(root, "impls_tmp", name);
        defer testing.allocator.free(stub);
        try testing.expect(std.mem.indexOf(u8, stub, "forEach") == null);
    }
}

test "a value iterator says so: no key type" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);
    var config = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
    defer config.deinit();
    try codegen.processSources(testing.allocator, &.{"tests/codegen/fixtures/iterable_members"}, &config);
    const value_list = try generated(root, "interfaces", "ValueList");
    defer testing.allocator.free(value_list);
    try testing.expect(std.mem.indexOf(u8, value_list, ".key_type = null,") != null);
    const pair_list = try generated(root, "interfaces", "PairList");
    defer testing.allocator.free(pair_list);
    try testing.expect(std.mem.indexOf(u8, pair_list, ".key_type = \"runtime.DOMString\",") != null);
}
