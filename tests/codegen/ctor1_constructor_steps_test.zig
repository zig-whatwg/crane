//! The generated constructor makes the object and frees it whole when its
//! constructor steps fail (lane ctor1; queue item 9 of the 0.1 audit).
//!
//! WebIDL 3.7.1, the interface object's steps: 1.8 "Let object be the
//! result of internally creating a new object implementing I", 1.9
//! "Perform the constructor steps of constructor with object as this". An
//! impl whose steps take the object (`call_constructor(instance:
//! *runtime.Instance, ...) !void`, the this form) gets it from the generated
//! `call_constructor`, which made it with the interface's own construction
//! chain and holds it under `errdefer runtime.gc.releaseFailedConstruction`
//! until the steps return: the construction is its only owner, so a failed
//! step frees it whole - never the impl's destructor alone, which left the
//! slot and State of ~370 constructors' objects until their Browser ended
//! (docs/lessons/architecture-an-interfaces-deinit-is-a-destructor-not-a-
//! free.md). An impl whose steps take `ctx` still makes its own object (the
//! factory form); tools/lint_constructors.zig keeps that list from growing.
const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

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
        try codegen.processSources(testing.allocator, &.{"tests/codegen/fixtures/ctor1_constructor_steps"}, &config);
        return .{ .tmp = tmp, .root = root };
    }

    fn deinit(self: *Generated) void {
        testing.allocator.free(self.root);
        self.tmp.cleanup();
    }

    /// The generated file `name` in `dir` (interfaces, impls_tmp); the caller frees it.
    fn fileIn(self: *Generated, dir: []const u8, name: []const u8) ![]u8 {
        const path = try std.fmt.allocPrint(testing.allocator, "{s}/{s}/{s}.zig", .{ self.root, dir, name });
        defer testing.allocator.free(path);
        return std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(1024 * 1024));
    }
};

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

/// The body of the generated function whose declaration starts with `header`.
fn body(source: []const u8, header: []const u8) ![]const u8 {
    const start = std.mem.indexOf(u8, source, header) orelse {
        std.debug.print("no `{s}` in:\n{s}\n", .{ header, source });
        return error.FunctionMissing;
    };
    const end = std.mem.indexOfPos(u8, source, start, "\n    }\n") orelse return error.FunctionUnterminated;
    return source[start..end];
}

/// `needles` appear in `source` in this order.
fn expectInOrder(source: []const u8, needles: []const []const u8) !void {
    var at: usize = 0;
    for (needles) |needle| {
        const found = std.mem.indexOfPos(u8, source, at, needle) orelse {
            std.debug.print("no `{s}` after offset {d} in:\n{s}\n", .{ needle, at, source });
            return error.Missing;
        };
        at = found + needle.len;
    }
}

test "the generated constructor makes the object, runs the steps on it, and frees it whole when they fail" {
    var out = try Generated.init();
    defer out.deinit();
    const file = try out.fileIn("interfaces", "Plain");
    defer testing.allocator.free(file);
    const ctor = try body(file, "pub fn call_constructor(ctx: runtime.Context");

    // The binding's signature is unchanged: it hands over the arguments and
    // takes the object.
    try testing.expect(contains(ctor, "!*runtime.Instance {"));
    // The form is the impl's: a this-form impl takes the object first.
    try testing.expect(contains(ctor, "if (comptime @FieldType(std.meta.ArgsTuple(@TypeOf(PlainImpl.call_constructor)), \"0\") == *runtime.Instance) {"));
    // Step 1.8 with the interface's own chain, then the hold, then step
    // 1.9 with the object and every argument in order, then the object.
    try expectInOrder(ctor, &.{
        "const instance = try init(ctx.allocator, ctx);",
        "errdefer runtime.gc.releaseFailedConstruction(instance);",
        "try PlainImpl.call_constructor(instance, @\"type\", count);",
        "return instance;",
        "} else {",
        "return try PlainImpl.call_constructor(ctx, @\"type\", count);",
    });
    // Never the impl's destructor alone.
    try testing.expect(!contains(ctor, "deinit("));
}

test "an overloaded constructor hands its resolved variant to the steps the same way" {
    var out = try Generated.init();
    defer out.deinit();
    const file = try out.fileIn("interfaces", "Overloaded");
    defer testing.allocator.free(file);
    const ctor = try body(file, "pub fn call_constructor(ctx: runtime.Context, args: ConstructorArgs) !*runtime.Instance {");
    try expectInOrder(ctor, &.{
        "if (comptime @FieldType(std.meta.ArgsTuple(@TypeOf(OverloadedImpl.call_constructor)), \"0\") == *runtime.Instance) {",
        "const instance = try init(ctx.allocator, ctx);",
        "errdefer runtime.gc.releaseFailedConstruction(instance);",
        "try OverloadedImpl.call_constructor(instance, args);",
        "return instance;",
        "return try OverloadedImpl.call_constructor(ctx, args);",
    });
}

test "a constructor with no arguments passes the object alone" {
    var out = try Generated.init();
    defer out.deinit();
    const file = try out.fileIn("interfaces", "Bare");
    defer testing.allocator.free(file);
    const ctor = try body(file, "pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {");
    try expectInOrder(ctor, &.{
        "try BareImpl.call_constructor(instance);",
        "return try BareImpl.call_constructor(ctx);",
    });
}

test "an impl stub's constructor steps take the object and release nothing" {
    var out = try Generated.init();
    defer out.deinit();
    const stub = try out.fileIn("impls_tmp", "Plain");
    defer testing.allocator.free(stub);
    try testing.expect(contains(stub, "pub fn call_constructor(instance: *runtime.Instance, "));
    try testing.expect(contains(stub, ") !void {"));
    // The copied template of ~370 constructors: made the object itself and
    // ran a destructor, not a free, when a step failed.
    try testing.expect(!contains(stub, "errdefer"));
    try testing.expect(!contains(stub, "init(ctx.allocator"));
    try testing.expect(!contains(stub, "return instance;"));

    const overloaded = try out.fileIn("impls_tmp", "Overloaded");
    defer testing.allocator.free(overloaded);
    try testing.expect(contains(overloaded, "pub fn call_constructor(instance: *runtime.Instance, args: interfaces.Overloaded.ConstructorArgs) !void {"));
}
