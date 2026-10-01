//! The model does not depend on the order IDL files are read in.
//!
//! WebIDL: "the order of appearance of an interface definition and any of its
//! partial interface definitions does not matter". So the same set of files,
//! read in any order, on any filesystem, gives byte-identical output, by
//! these rules (src/webidl/codegen/ir.zig, "Merging"):
//!
//! 1. Every partial definition (interface, interface mixin, dictionary,
//!    namespace) merges into its definition.
//! 2. Members: the definition's, in declaration order, then each partial's,
//!    in declaration order, partials ordered by (file name, position in the
//!    file). A partial dictionary member replaces a same-named one. An
//!    includer takes its mixins' members in the order of its `includes`
//!    statements, ordered the same way. Extended attributes: the
//!    definition's, then a partial's only where the definition has none of
//!    that name.
//! 3. Two non-partial definitions of one name are an error unless a rule
//!    names the definer (duplicates.zig): webref's canonical definer, or a
//!    file that repeats its own definitions (first occurrence).
//! 4. Overloads are numbered in that member order.

const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

const SourceFile = codegen.pipeline.SourceFile;

const order_dir = "tests/codegen/fixtures/order";
const forward = [_]SourceFile{
    .{ .dir = order_dir, .name = "DOM-Style.idl" },
    .{ .dir = order_dir, .name = "a-partials.idl" },
    .{ .dir = order_dir, .name = "m-base.idl" },
    .{ .dir = order_dir, .name = "shared-storage.idl" },
    .{ .dir = order_dir, .name = "web-locks.idl" },
    .{ .dir = order_dir, .name = "z-partials.idl" },
};
const reversed = [_]SourceFile{ forward[5], forward[4], forward[3], forward[2], forward[1], forward[0] };
const shuffled = [_]SourceFile{ forward[2], forward[5], forward[0], forward[4], forward[1], forward[3] };

const Generated = struct {
    tmp: testing.TmpDir,
    root: [:0]u8,

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

fn generateInOrder(files: []const SourceFile) !Generated {
    var tmp = testing.tmpDir(.{});
    errdefer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    errdefer testing.allocator.free(root);
    var cfg = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
    defer cfg.deinit();
    try codegen.pipeline.processFiles(testing.allocator, files, &cfg);
    return .{ .tmp = tmp, .root = root };
}

fn indexOf(haystack: []const u8, needle: []const u8) !usize {
    return std.mem.indexOf(u8, haystack, needle) orelse {
        std.debug.print("missing: {s}\n", .{needle});
        return error.TestExpectedSubstring;
    };
}

/// `needles` occur in `haystack`, in this order.
fn expectInOrder(haystack: []const u8, needles: []const []const u8) !void {
    var last: usize = 0;
    for (needles, 0..) |needle, i| {
        const at = try indexOf(haystack, needle);
        if (i > 0 and at <= last) {
            std.debug.print("out of order: {s} before {s}\n", .{ needle, needles[i - 1] });
            return error.TestOutOfOrder;
        }
        last = at;
    }
}

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

const outputs = [_][]const u8{
    "interfaces/Thing.zig",       "interfaces/Lock.zig",  "interfaces/Counter.zig", "interfaces/root.zig",
    "dictionaries/ThingInit.zig", "namespaces/Space.zig", "mixins/Mixy.zig",        "impls_tmp/Thing.zig",
    "impls_tmp/Space.zig",
};

test "the same files read forward, reversed and shuffled give byte-identical output" {
    var a = try generateInOrder(&forward);
    defer a.deinit();
    var b = try generateInOrder(&reversed);
    defer b.deinit();
    var c = try generateInOrder(&shuffled);
    defer c.deinit();

    for (outputs) |sub_path| {
        const out_a = try a.read(sub_path);
        defer testing.allocator.free(out_a);
        const out_b = try b.read(sub_path);
        defer testing.allocator.free(out_b);
        const out_c = try c.read(sub_path);
        defer testing.allocator.free(out_c);
        testing.expectEqualStrings(out_a, out_b) catch |err| {
            std.debug.print("{s}: forward and reversed differ\n", .{sub_path});
            return err;
        };
        testing.expectEqualStrings(out_a, out_c) catch |err| {
            std.debug.print("{s}: forward and shuffled differ\n", .{sub_path});
            return err;
        };
    }
}

test "members: the definition's, then each partial's by (file, position), then the included mixins'" {
    var out = try generateInOrder(&reversed);
    defer out.deinit();
    const thing = try out.read("interfaces/Thing.zig");
    defer testing.allocator.free(thing);
    try expectInOrder(thing, &.{ "\"base\"", "\"fromA\"", "\"fromA2\"", "\"fromZ\"", "\"mixed\"", "\"mixedZ\"" });
}

test "overloads are numbered in member order: the definition's act() is call_act, the partial's act(long) call_act__1" {
    var out = try generateInOrder(&reversed);
    defer out.deinit();
    const thing = try out.read("interfaces/Thing.zig");
    defer testing.allocator.free(thing);
    try testing.expect(contains(thing, "pub fn call_act(instance: *runtime.Instance) "));
    try testing.expect(contains(thing, "pub fn call_act__1(instance: *runtime.Instance, x: i32) "));
}

test "extended attributes: the definition's [Exposed] wins over a partial's" {
    var out = try generateInOrder(&forward);
    defer out.deinit();
    const thing = try out.read("interfaces/Thing.zig");
    defer testing.allocator.free(thing);
    try testing.expect(contains(thing, "pub const exposed_in = .{ .Window = true };"));
    try testing.expect(!contains(thing, "DedicatedWorker"));
}

test "a partial dictionary member replaces the definition's member of that name" {
    var out = try generateInOrder(&shuffled);
    defer out.deinit();
    const init = try out.read("dictionaries/ThingInit.zig");
    defer testing.allocator.free(init);
    try expectInOrder(init, &.{ "base:", "fromA:", "shared:" });
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, init, "shared:"));
}

test "partial namespaces merge into the namespace instead of replacing it" {
    var out = try generateInOrder(&shuffled);
    defer out.deinit();
    const space = try out.read("namespaces/Space.zig");
    defer testing.allocator.free(space);
    // (A namespace's operations are written in overload-set order, which
    // follows its members, so the byte-identical test covers their order.)
    for ([_][]const u8{ "pub fn call_base(", "pub fn call_fromA(", "pub fn call_fromZ(" }) |needle| {
        _ = try indexOf(space, needle);
    }
}

test "a duplicate definition resolves to webref's definer, whichever file comes first" {
    var out = try generateInOrder(&forward);
    defer out.deinit();
    const lock = try out.read("interfaces/Lock.zig");
    defer testing.allocator.free(lock);
    try testing.expect(!contains(lock, "fromSharedStorage"));
    try testing.expect(!contains(lock, "SharedStorageWorklet"));
}

test "a file that repeats its own definition uses the first occurrence" {
    var out = try generateInOrder(&reversed);
    defer out.deinit();
    const counter = try out.read("interfaces/Counter.zig");
    defer testing.allocator.free(counter);
    try testing.expect(contains(counter, "identifier"));
    try testing.expect(!contains(counter, "fromSecondCopy"));
}

test "a duplicate definition no rule covers is an error" {
    const files = [_]SourceFile{
        .{ .dir = "tests/codegen/fixtures/duplicate", .name = "x.idl" },
        .{ .dir = "tests/codegen/fixtures/duplicate", .name = "y.idl" },
    };
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);
    var cfg = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
    defer cfg.deinit();
    try testing.expectError(error.DuplicateDefinition, codegen.pipeline.processFiles(testing.allocator, &files, &cfg));
}
