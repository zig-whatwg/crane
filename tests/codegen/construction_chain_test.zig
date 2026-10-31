//! The generated interface is the class: it emits the construction and
//! destruction chain (tmp/plans/impls-boundary-design.md 3.2.3, the user's
//! decision Q1 of 2026-10-11).
//!
//! A C++ engine's constructors and destructors chain by the language:
//! `HTMLDivElement::HTMLDivElement(...) : HTMLElement(tagName, document)`, and a
//! derived class never names its base's private parts. Here the generated
//! `initChain` runs the parent interface's chain, then the impl's own steps
//! (`initOwn`); `deinitChain` runs the impl's `deinitOwn`, then the parent's -
//! so no impl names an ancestor's impl, and none can forget to chain.
//!
//! - An impl that still defines `init` / `deinit` chains by hand; the chain
//!   honours it (the legacy route, converted impl by impl).
//! - A level whose own steps fail unwinds its ancestors and frees the slot.
//! - Construction arguments (`initWith`) are facts given at construction - the
//!   C++ constructor's parameters - and every one must be taken by an impl on
//!   the chain (`construction_args`), or it is a compile error.
//! - A mixin is never instantiated: no lifecycle, no vtable.
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
        try codegen.processSources(testing.allocator, &.{"tests/codegen/fixtures/construction_chain"}, &config);
        return .{ .tmp = tmp, .root = root };
    }

    fn deinit(self: *Generated) void {
        testing.allocator.free(self.root);
        self.tmp.cleanup();
    }

    /// The generated file of interface `name`; the caller frees it.
    fn file(self: *Generated, name: []const u8) ![]u8 {
        return self.fileIn("interfaces", name);
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

fn expectBefore(source: []const u8, first: []const u8, second: []const u8) !void {
    const a = std.mem.indexOf(u8, source, first) orelse {
        std.debug.print("no `{s}` in:\n{s}\n", .{ first, source });
        return error.Missing;
    };
    const b = std.mem.indexOf(u8, source, second) orelse {
        std.debug.print("no `{s}` in:\n{s}\n", .{ second, source });
        return error.Missing;
    };
    try testing.expect(a < b);
}

test "a derived interface's init runs its parent's chain, then its impl's own steps" {
    var out = try Generated.init();
    defer out.deinit();
    const leaf = try out.file("Leaf");
    defer testing.allocator.free(leaf);

    // The entry points all run the one chain.
    try testing.expect(contains(leaf, "    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {\n" ++
        "        return initChain(allocator, State, &vtable, ctx, .{});\n"));
    try testing.expect(contains(try body(leaf, "    pub fn initWithState("), "return initChain(allocator, StateType, vtable_ptr, ctx, .{});"));

    const chain = try body(leaf, "    pub inline fn initChain(");
    // Legacy: an impl that still defines init chains by hand, as before.
    try testing.expect(contains(chain, "if (comptime @hasDecl(LeafImpl, \"init\")) return LeafImpl.init(allocator, StateType, vtable_ptr, ctx);"));
    // The parent's chain first - through its generated interface, never its impl.
    try testing.expect(contains(chain, "const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);"));
    try testing.expect(!contains(chain, "MiddleImpl"));
    // Then the own steps; their failure unwinds the parent's part and frees the slot.
    try testing.expect(contains(chain, "if (comptime @hasDecl(LeafImpl, \"initOwn\")) {"));
    try testing.expect(contains(chain, "Meta.ParentInterface.deinitChain(instance);"));
    try testing.expect(contains(chain, "runtime.gc.releaseStorage(instance);"));
    try testing.expect(contains(chain, "try LeafImpl.initOwn(instance, allocator, StateType, args);"));
    try expectBefore(chain, "Meta.ParentInterface.initChain(", "LeafImpl.initOwn(");
    try expectBefore(chain, "errdefer", "LeafImpl.initOwn(");
}

test "a root interface's chain makes the instance itself" {
    var out = try Generated.init();
    defer out.deinit();
    // Not "Root": its file would be root.zig on a case-insensitive disk.
    const root = try out.file("Base");
    defer testing.allocator.free(root);

    const chain = try body(root, "    pub inline fn initChain(");
    try testing.expect(contains(chain, "if (comptime @hasDecl(BaseImpl, \"init\")) return BaseImpl.init(allocator, StateType, vtable_ptr, ctx);"));
    try testing.expect(contains(chain, "const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);"));
    try testing.expect(contains(chain, "runtime.gc.releaseStorage(instance);"));
    try testing.expect(contains(chain, "try BaseImpl.initOwn(instance, allocator, StateType, args);"));
    try testing.expect(!contains(chain, "ParentInterface"));

    const destroy = try body(root, "    pub inline fn deinitChain(");
    try testing.expect(contains(destroy, "if (comptime @hasDecl(BaseImpl, \"deinitOwn\")) BaseImpl.deinitOwn(instance);"));
    try testing.expect(!contains(destroy, "ParentInterface"));
}

test "deinit is the destruction chain: the impl's own part, then the parent's" {
    var out = try Generated.init();
    defer out.deinit();
    const leaf = try out.file("Leaf");
    defer testing.allocator.free(leaf);

    // The vtable's destructor (its address is taken, so it is not inline).
    try testing.expect(contains(leaf, "        .deinit = &deinit,\n"));
    try testing.expect(contains(leaf, "    pub fn deinit(instance: *runtime.Instance) void {\n" ++
        "        deinitChain(instance);\n"));

    const destroy = try body(leaf, "    pub inline fn deinitChain(");
    try testing.expect(contains(destroy, "if (comptime @hasDecl(LeafImpl, \"deinit\")) return LeafImpl.deinit(instance);"));
    try testing.expect(contains(destroy, "if (comptime @hasDecl(LeafImpl, \"deinitOwn\")) LeafImpl.deinitOwn(instance);"));
    try testing.expect(contains(destroy, "Meta.ParentInterface.deinitChain(instance);"));
    try expectBefore(destroy, "LeafImpl.deinitOwn(", "Meta.ParentInterface.deinitChain(");
    try testing.expect(!contains(destroy, "MiddleImpl"));
}

test "an impl defines its steps one way: legacy init with initOwn, or deinit with deinitOwn, is a compile error" {
    var out = try Generated.init();
    defer out.deinit();
    const leaf = try out.file("Leaf");
    defer testing.allocator.free(leaf);

    const chain = try body(leaf, "    pub inline fn initChain(");
    try testing.expect(contains(chain, "if (comptime @hasDecl(LeafImpl, \"init\") and @hasDecl(LeafImpl, \"initOwn\"))"));
    try testing.expect(contains(chain, "@compileError(\"LeafImpl defines both init and initOwn\")"));
    const destroy = try body(leaf, "    pub inline fn deinitChain(");
    try testing.expect(contains(destroy, "if (comptime @hasDecl(LeafImpl, \"deinit\") and @hasDecl(LeafImpl, \"deinitOwn\"))"));
    try testing.expect(contains(destroy, "@compileError(\"LeafImpl defines both deinit and deinitOwn\")"));
}

test "construction arguments travel the chain, and each must be taken by an impl on it" {
    var out = try Generated.init();
    defer out.deinit();
    const leaf = try out.file("Leaf");
    defer testing.allocator.free(leaf);

    const with = try body(leaf, "    pub fn initWith(allocator: std.mem.Allocator, ctx: runtime.Context, args: anytype) !*runtime.Instance {");
    try testing.expect(contains(with, "inline for (@typeInfo(@TypeOf(args)).@\"struct\".field_names) |field_name| {"));
    try testing.expect(contains(with, "if (comptime !takesConstructionArg(field_name)) @compileError(\"Leaf has no construction argument '\" ++ field_name ++ \"'\");"));
    try testing.expect(contains(with, "return initChain(allocator, State, &vtable, ctx, args);"));

    const takes = try body(leaf, "    pub fn takesConstructionArg(comptime name: []const u8) bool {");
    // A level that chains by hand passes nothing on: neither it nor its
    // ancestors receive an argument.
    try testing.expect(contains(takes, "if (comptime @hasDecl(LeafImpl, \"init\")) return false;"));
    try testing.expect(contains(takes, "if (comptime @hasDecl(LeafImpl, \"construction_args\")) {"));
    try testing.expect(contains(takes, "return Meta.ParentInterface.takesConstructionArg(name);"));
    try expectBefore(takes, "\"init\")) return false;", "construction_args");

    // Not "Root": its file would be root.zig on a case-insensitive disk.
    const root = try out.file("Base");
    defer testing.allocator.free(root);
    const root_takes = try body(root, "    pub fn takesConstructionArg(comptime name: []const u8) bool {");
    try testing.expect(contains(root_takes, "return false;"));
    try testing.expect(!contains(root_takes, "ParentInterface"));
}

test "a mixin has no lifecycle and no vtable: it is never instantiated" {
    var out = try Generated.init();
    defer out.deinit();
    const shared = try out.file("Shared");
    defer testing.allocator.free(shared);

    try testing.expect(contains(shared, "pub const is_mixin = true;"));
    try testing.expect(!contains(shared, "pub fn init("));
    try testing.expect(!contains(shared, "initWithState"));
    try testing.expect(!contains(shared, "initChain"));
    try testing.expect(!contains(shared, "pub fn deinit("));
    try testing.expect(!contains(shared, "deinitChain"));
    try testing.expect(!contains(shared, "pub const vtable"));
    try testing.expect(!contains(shared, "const delegates"));
    // Its hooks are still installed, and its members still delegate.
    try testing.expect(contains(shared, "pub fn installHooks() void {"));
    try testing.expect(contains(shared, "pub fn get_sharedName(instance: *runtime.Instance)"));
    // The includer's chain is its own.
    const leaf = try out.file("Leaf");
    defer testing.allocator.free(leaf);
    try testing.expect(!contains(leaf, "SharedImpl.init"));
}

test "an impl stub constructs through the chain: no init or deinit of its own" {
    var out = try Generated.init();
    defer out.deinit();
    const stub = try out.fileIn("impls_tmp", "Leaf");
    defer testing.allocator.free(stub);

    // A stub that made its instance itself (`runtime.Instance.init`) left every
    // ancestor's state unmade: 492 impls of types with a parent were copied
    // from it. Without init and deinit the generated chain runs the parent's.
    try testing.expect(!contains(stub, "pub fn init("));
    try testing.expect(!contains(stub, "pub fn deinit("));
    try testing.expect(!contains(stub, "runtime.Instance.init"));
    // Where its own steps go, when it has any.
    try testing.expect(contains(stub, "initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void"));
    try testing.expect(contains(stub, "deinitOwn(instance: *runtime.Instance) void"));
}
