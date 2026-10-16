//! binding3 item 9(h): a generated [SameObject] getter caches the child its
//! impl made as a bare pointer in the owner's state. A script read wraps the
//! child, and the binding ties its wrapper to the owner's
//! (interface.zig recordSameObjectEdge); a NATIVE read - `interfaces.X.get_y`
//! from engine code - made a child nothing wrapped or freed (Codex row 45
//! Q14: an SVGAnimatedString per SVGAElement whose origin was extracted).
//!
//! So the getter traces the child it just cached from its owner
//! (`dom.same_object_cache.made` -> engine.traceChild): the child's wrapper,
//! made in its relevant realm, is the child's owner, kept by the owner's
//! wrapper - or held until the owner gets one - exactly as after a script
//! read. And the owner's destruction chain ends any edge still waiting for its
//! wrapper (`dom.same_object_cache.end` -> engine.forgetTracedChild), as the
//! protocol asks of an owner that can be freed unwrapped.
//!
//! Not for: an attribute that is not [SameObject], or one whose value is a
//! JSValue (no generated cache: the impl keeps it); an interface with no
//! [SameObject] attribute has no `end` call.
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
        try codegen.processSources(testing.allocator, &.{"tests/codegen/fixtures/same_object_cache"}, &config);
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

/// The text of `name`'s function in `file`, up to the next blank line.
fn function(file: []const u8, comptime name: []const u8) ![]const u8 {
    const start = std.mem.indexOf(u8, file, "pub fn " ++ name ++ "(") orelse
        std.mem.indexOf(u8, file, "pub inline fn " ++ name ++ "(") orelse return error.NoSuchFunction;
    const end = std.mem.indexOfPos(u8, file, start, "\n\n") orelse file.len;
    return file[start..end];
}

test "a [SameObject] getter traces the child it caches from its owner" {
    var out = try Generated.init();
    defer out.deinit();
    const owner = try generated(out.root, "Owner");
    defer testing.allocator.free(owner);

    const part = try function(owner, "get_part");
    try testing.expect(contains(part, "state.own.cached_part = value;"));
    try testing.expect(contains(part, "@import(\"dom\").same_object_cache.made(instance, value, \"part\");"));
    // A cached child is returned as it is: nothing is traced again.
    const cached_return = std.mem.indexOf(u8, part, "return cached;").?;
    try testing.expect(std.mem.indexOf(u8, part, "same_object_cache").? > cached_return);

    // A nullable one traces only a child.
    const maybe = try function(owner, "get_maybePart");
    try testing.expect(contains(maybe, "if (value) |child| @import(\"dom\").same_object_cache.made(instance, child, \"maybePart\");"));

    // A JSValue has no generated cache (the impl keeps it): nothing to trace.
    const value = try function(owner, "get_value");
    try testing.expect(!contains(value, "same_object_cache"));
}

test "an owner's destruction chain ends its [SameObject] edges before its impl's teardown" {
    var out = try Generated.init();
    defer out.deinit();
    const owner = try generated(out.root, "Owner");
    defer testing.allocator.free(owner);
    const chain = try function(owner, "deinitChain");
    const end = std.mem.indexOf(u8, chain, "@import(\"dom\").same_object_cache.end(State, instance);") orelse return error.NoEnd;
    // First: before an impl that chains by hand returns, and before deinitOwn.
    try testing.expect(end < std.mem.indexOf(u8, chain, "OwnerImpl.deinit(instance)").?);
    try testing.expect(end < std.mem.indexOf(u8, chain, "OwnerImpl.deinitOwn(instance)").?);
}

test "an interface with no [SameObject] attribute neither traces nor ends anything" {
    var out = try Generated.init();
    defer out.deinit();
    inline for (.{ "Plain", "Part" }) |name| {
        const file = try generated(out.root, name);
        defer testing.allocator.free(file);
        try testing.expect(!contains(file, "same_object_cache"));
    }
}
