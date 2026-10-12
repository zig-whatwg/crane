//! WebIDL 2.5.6.1: an anonymous indexed property getter, `getter T
//! (unsigned long index)`, is bound as `call_getter(instance, u32)`. Most
//! impls of such interfaces (AudioTrackList, SourceBufferList, the CSS typed
//! OM lists, HTMLAllCollection, ...) do not implement it yet, so its
//! delegate is gated the way a later overload's is - it answers
//! error.NotImplemented until the impl declares `call_getter` - and
//! Meta.special_operations' `.implemented` (`@hasDecl(<X>Impl,
//! "call_getter")`) tells the binding whether to install indexed access
//! through it. Before, the binding installed indexed access only for
//! `call_item`, so `dataTransfer.items[0]` read undefined.
//!
//! Not for: a named `item` getter (call_item, ungated, no constant); an
//! anonymous indexed getter beside an anonymous named one (HTMLFormElement:
//! `call_getter` and `call_getter__1`, both gated); an anonymous named getter
//! (DOMStringMap, gated). Meta.special_operations covers them all
//! (special_operations_metadata_test.zig).
const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

fn generated(root: []const u8, name: []const u8) ![]u8 {
    const file = try std.fmt.allocPrint(testing.allocator, "{s}/interfaces/{s}.zig", .{ root, name });
    defer testing.allocator.free(file);
    return std.Io.Dir.cwd().readFileAlloc(testing.io, file, testing.allocator, .limited(65536));
}

const Generated = struct {
    tmp: testing.TmpDir,
    root: [:0]u8,

    fn init() !Generated {
        var tmp = testing.tmpDir(.{});
        errdefer tmp.cleanup();
        const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
        errdefer testing.allocator.free(root);
        var config = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
        defer config.deinit();
        try codegen.processSources(testing.allocator, &.{"tests/codegen/fixtures/anonymous_indexed_getter"}, &config);
        return .{ .tmp = tmp, .root = root };
    }

    fn deinit(self: *Generated) void {
        testing.allocator.free(self.root);
        self.tmp.cleanup();
    }
};

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

test "an anonymous indexed getter's delegate is gated, and Meta says whether the impl has it" {
    var out = try Generated.init();
    defer out.deinit();
    const list = try generated(out.root, "ThingList");
    defer testing.allocator.free(list);
    // Implemented or not is the impl's @hasDecl, evaluated where the impl is.
    try testing.expect(contains(list, ".indexed_getter = .{ .function = \"call_getter\", .implemented = @hasDecl(ThingListImpl, \"call_getter\") },"));
    try testing.expect(!contains(list, "indexed_getter_implemented"));
    try testing.expect(contains(list, "pub fn call_getter(instance: *runtime.Instance, index: u32) anyerror!*runtime.Instance {"));
    // Unimplemented: the delegate still compiles, and answers NotImplemented.
    try testing.expect(contains(list, "if (comptime @hasDecl(ThingListImpl, \"call_getter\")) {"));
    try testing.expect(contains(list, "return try ThingListImpl.call_getter(instance, index);"));
    try testing.expect(contains(list, "return error.NotImplemented;"));
}

test "a named item getter is not gated, and its entry has no implemented test" {
    var out = try Generated.init();
    defer out.deinit();
    const items = try generated(out.root, "ThingItems");
    defer testing.allocator.free(items);
    try testing.expect(contains(items, ".indexed_getter = .{ .function = \"call_item\" },"));
    try testing.expect(contains(items, "pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {"));
    try testing.expect(!contains(items, "@hasDecl(ThingItemsImpl, \"call_item\")"));
}

test "an indexed getter beside an anonymous named one, and an anonymous named getter, have no constant, and are gated" {
    var out = try Generated.init();
    defer out.deinit();
    const form = try generated(out.root, "ThingForm");
    defer testing.allocator.free(form);
    try testing.expect(!contains(form, "indexed_getter_implemented"));
    // One gated delegate per variety (special_operations_metadata_test.zig).
    try testing.expect(contains(form, "if (comptime @hasDecl(ThingFormImpl, \"call_getter\")) {"));
    try testing.expect(contains(form, "if (comptime @hasDecl(ThingFormImpl, \"call_getter__1\")) {"));
    const map = try generated(out.root, "ThingMap");
    defer testing.allocator.free(map);
    try testing.expect(!contains(map, "indexed_getter_implemented"));
    // Every anonymous special operation's delegate is gated; Meta says
    // whether the impl has it.
    try testing.expect(contains(map, "if (comptime @hasDecl(ThingMapImpl, \"call_getter\")) {"));
}
