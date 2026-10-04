//! A union argument with a later argument is converted by the binding, in
//! argument order, through a named union typedef (src/webidl/codegen/
//! argument_unions.zig) - when the binding converts its members faithfully.
//! The last argument, and a union with a member the binding cannot take
//! faithfully, stay `runtime.JSValue` for the impl to convert.

const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

const fixture = "tests/codegen/fixtures/argument_unions";

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

const Generated = struct {
    tmp: testing.TmpDir,
    root: [:0]u8,

    fn init() !Generated {
        var tmp = testing.tmpDir(.{});
        errdefer tmp.cleanup();
        const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
        errdefer testing.allocator.free(root);
        var cfg = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
        defer cfg.deinit();
        try codegen.processSources(testing.allocator, &.{fixture}, &cfg);
        return .{ .tmp = tmp, .root = root };
    }

    fn deinit(self: *Generated) void {
        testing.allocator.free(self.root);
        self.tmp.cleanup();
    }

    fn read(self: *const Generated, sub_path: []const u8) ![]u8 {
        const path = try std.fs.path.join(testing.allocator, &.{ self.root, sub_path });
        defer testing.allocator.free(path);
        return std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(1024 * 1024));
    }
};

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

test "a union argument followed by another becomes a named union, one per member list" {
    var out = try Generated.init();
    defer out.deinit();
    const typedef = try out.read("typedefs/BufferSourceOrPlain.zig");
    defer testing.allocator.free(typedef);
    try expectIn(typedef, "typedefs/BufferSourceOrPlain.zig", "pub const BufferSourceOrPlain = union(enum) {");
    try expectIn(typedef, "typedefs/BufferSourceOrPlain.zig", "buffer_source: typedefs.BufferSource,");
    try expectIn(typedef, "typedefs/BufferSourceOrPlain.zig", "plain: dictionaries.Plain,");

    const root = try out.read("typedefs/root.zig");
    defer testing.allocator.free(root);
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, root, "pub const BufferSourceOrPlain = "));
    try expectIn(root, "typedefs/root.zig", "pub const DOMStringOrBufferSource = ");
    try expectIn(root, "typedefs/root.zig", "pub const DOMStringOrDerived = ");
    try expectIn(root, "typedefs/root.zig", "pub const ThingOrDOMString = ");
}

test "the interface and the impl stub take the named union, in its argument's place" {
    var out = try Generated.init();
    defer out.deinit();
    for ([_][]const u8{ "interfaces/Thing.zig", "impls_tmp/Thing.zig" }) |sub_path| {
        const text = try out.read(sub_path);
        defer testing.allocator.free(text);
        try expectIn(text, sub_path, "BufferSourceOrPlain, after: ");
        try expectIn(text, sub_path, "call_again(instance: *runtime.Instance, data: ");
        try expectIn(text, sub_path, "DOMStringOrBufferSource, options: ");
        try expectIn(text, sub_path, "DOMStringOrDerived, after: ");
        // An `any` member's handle is released with the dictionary.
        try expectIn(text, sub_path, "DOMStringOrWithAny, after: ");
        // Nullability stays on the argument.
        try expectIn(text, sub_path, "data: ?");
        try expectIn(text, sub_path, "ThingOrDOMString, after: ");
    }
}

test "the last argument, and a union the binding cannot take faithfully, stay JSValue" {
    var out = try Generated.init();
    defer out.deinit();
    const text = try out.read("interfaces/Thing.zig");
    defer testing.allocator.free(text);
    // Nothing follows it: the impl converts it first thing.
    try expectIn(text, "interfaces/Thing.zig", "call_last(instance: *runtime.Instance, first: runtime.DOMString, data: runtime.JSValue)");
    // A dictionary with a union member leaves it to the impl, later than
    // WebIDL converts it.
    try expectIn(text, "interfaces/Thing.zig", "call_unionDictionary(instance: *runtime.Instance, data: runtime.JSValue, after: ");
    // The binding's union path takes only an Array for a sequence arm.
    try expectIn(text, "interfaces/Thing.zig", "call_sequenceArm(instance: *runtime.Instance, data: runtime.JSValue, after: ");
    const typedefs_root = try out.read("typedefs/root.zig");
    defer testing.allocator.free(typedefs_root);
    try expectNotIn(typedefs_root, "typedefs/root.zig", "WithUnion");
    try expectNotIn(typedefs_root, "typedefs/root.zig", "OrSequence");
    // A Trusted Types union is named too, in every position
    // (trusted_type_unions_test.zig).
    try expectIn(typedefs_root, "typedefs/root.zig", "pub const TrustedHTMLOrDOMString = ");
}

test "unionName joins the member names in upper camel case" {
    const allocator = testing.allocator;
    var members = [_]codegen.types.IDLType{ .{ .type = "unsigned long" }, .{ .type = "DOMString" }, .{ .type = "boolean" } };
    const name = try codegen.argument_unions.unionName(allocator, &members);
    defer allocator.free(name);
    try testing.expectEqualStrings("UnsignedLongOrDOMStringOrBoolean", name);
}
