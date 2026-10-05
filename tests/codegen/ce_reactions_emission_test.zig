//! [CEReactions] brackets name the object whose relevant agent they push onto.
//!
//! HTML 4.13.6 [CEReactions]: "1. Push a new element queue onto this object's
//! relevant agent's custom element reactions stack. ... 3. Let queue be the
//! result of popping from this object's relevant agent's custom element
//! reactions stack." So the generated bracket passes the member's `instance`
//! - `runtime.CEReactions.begin(instance)` / `end(instance)` - and a static
//! member, which has no "this object", passes null (the reactions side then
//! resolves the agent through the current realm).
//!
//! Operations, special operations (a named setter or deleter), regular and
//! [PutForwards] attribute setters, and a mixin's members (which an includer
//! inherits from the mixin's module) all carry it.

const std = @import("std");
const codegen = @import("codegen");
const types = codegen.types;
const writer = codegen.writer;
const testing = std.testing;

const ce_reactions = [_]types.ExtendedAttribute{.{ .name = "CEReactions" }};

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

/// The body of `pub fn <name>(` in `out`, up to the next `pub fn`.
fn body(out: []const u8, name: []const u8) ![]const u8 {
    var header_buf: [128]u8 = undefined;
    const header = try std.fmt.bufPrint(&header_buf, "pub fn {s}(", .{name});
    const start = std.mem.indexOf(u8, out, header) orelse return error.FunctionMissing;
    const after = start + header.len;
    const end = std.mem.indexOfPos(u8, out, after, "pub fn ") orelse out.len;
    return out[start..end];
}

fn expectInstanceBracket(fn_body: []const u8) !void {
    try testing.expect(contains(fn_body, "runtime.CEReactions.begin(instance);"));
    try testing.expect(contains(fn_body, "defer runtime.CEReactions.end(instance);"));
}

fn expectNullBracket(fn_body: []const u8) !void {
    try testing.expect(contains(fn_body, "runtime.CEReactions.begin(null);"));
    try testing.expect(contains(fn_body, "defer runtime.CEReactions.end(null);"));
}

test "a [CEReactions] operation and attribute setter bracket on their instance" {
    const attrs = [_]types.Attribute{
        .{ .name = "slot", .idlType = .{ .type = "DOMString" }, .extAttrs = @constCast(&ce_reactions) },
    };
    const ops = [_]types.Operation{
        .{ .name = "toggleAttribute", .idlType = .{ .type = "boolean" }, .extAttrs = @constCast(&ce_reactions) },
    };
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "CellImpl", null, &attrs, &ops, &ops, .{});
    const out = buffer.written();

    try expectInstanceBracket(try body(out, "call_toggleAttribute"));
    try expectInstanceBracket(try body(out, "set_slot"));
    // The getter runs no reactions: [CEReactions] wraps an attribute's setter steps.
    try testing.expect(!contains(try body(out, "get_slot"), "CEReactions.begin"));
    // No bracket keeps the old no-argument shape.
    try testing.expect(!contains(out, "CEReactions.begin()"));
    try testing.expect(!contains(out, "CEReactions.end()"));
}

test "a [CEReactions] named setter and deleter bracket on their instance" {
    var setter_args = [_]types.Argument{
        .{ .name = "name", .idlType = .{ .type = "DOMString" } },
        .{ .name = "value", .idlType = .{ .type = "DOMString" } },
    };
    var deleter_args = [_]types.Argument{.{ .name = "name", .idlType = .{ .type = "DOMString" } }};
    const ops = [_]types.Operation{
        .{ .idlType = .{ .type = "undefined" }, .special = .setter, .arguments = &setter_args, .extAttrs = @constCast(&ce_reactions) },
        .{ .idlType = .{ .type = "undefined" }, .special = .deleter, .arguments = &deleter_args, .extAttrs = @constCast(&ce_reactions) },
    };
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "MapImpl", null, &.{}, &ops, &ops, .{});
    const out = buffer.written();

    try expectInstanceBracket(try body(out, "call_setter"));
    try expectInstanceBracket(try body(out, "call_deleter"));
}

test "a [CEReactions] [PutForwards] setter brackets on its instance" {
    const put_forwards = [_]types.ExtendedAttribute{
        .{ .name = "CEReactions" },
        .{ .name = "PutForwards", .rhs = .{ .identifier = "value" } },
    };
    const attrs = [_]types.Attribute{
        .{ .name = "classList", .idlType = .{ .type = "DOMTokenList" }, .readonly = true, .extAttrs = @constCast(&put_forwards) },
    };
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "CellImpl", null, &attrs, &.{}, &.{}, .{});

    try expectInstanceBracket(try body(buffer.written(), "set_classList"));
}

test "a static [CEReactions] member has no instance and brackets on null" {
    const attrs = [_]types.Attribute{
        .{ .name = "limit", .idlType = .{ .type = "unsigned long" }, .static = true, .extAttrs = @constCast(&ce_reactions) },
    };
    const ops = [_]types.Operation{
        .{ .name = "make", .idlType = .{ .type = "undefined" }, .static = true, .extAttrs = @constCast(&ce_reactions) },
    };
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "CellImpl", null, &attrs, &ops, &ops, .{});
    const out = buffer.written();

    try expectNullBracket(try body(out, "call_static_make"));
    try expectNullBracket(try body(out, "set_static_limit"));
}

test "a mixin's [CEReactions] member brackets in the mixin module its includers inherit" {
    const attrs = [_]types.Attribute{
        .{ .name = "pace", .idlType = .{ .type = "double" }, .extAttrs = @constCast(&ce_reactions) },
    };
    const ops = [_]types.Operation{
        .{ .name = "walk", .idlType = .{ .type = "undefined" }, .extAttrs = @constCast(&ce_reactions) },
    };
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "WalkableImpl", null, &attrs, &ops, &ops, .{ .same_object_cache = false });
    const out = buffer.written();

    try expectInstanceBracket(try body(out, "call_walk"));
    try expectInstanceBracket(try body(out, "set_pace"));
}

test "a non-inherited mixin's [CEReactions] member brackets in its includer's delegate" {
    const attrs = [_]types.Attribute{
        .{ .name = "ariaLabel", .idlType = .{ .type = "DOMString", .nullable = true }, .mixin = "ARIAMixin", .extAttrs = @constCast(&ce_reactions) },
    };
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "DogImpl", null, &attrs, &.{}, &.{}, .{});

    try expectInstanceBracket(try body(buffer.written(), "set_ariaLabel"));
}

// ---------------------------------------------------------------------------
// The `ce_reactions` table: the functions the binding dispatches in a catch
// scope (engine.takePendingException). It is recorded where each bracket is
// written, so it lists every function that brackets and nothing else - plus
// an inherited mixin member's alias, whose mixin module brackets it.
// ---------------------------------------------------------------------------

const Names = std.ArrayList([]const u8);

/// The entries of `pub const ce_reactions = .{ ... };` in `out` (none when
/// the table is absent). Slices of `out`.
fn tableNames(allocator: std.mem.Allocator, out: []const u8) !Names {
    var names: Names = .empty;
    errdefer names.deinit(allocator);
    const header = "pub const ce_reactions = .{";
    const start = std.mem.indexOf(u8, out, header) orelse return names;
    const end = std.mem.indexOfPos(u8, out, start, "};") orelse return error.TableUnterminated;
    var rest = out[start + header.len .. end];
    while (std.mem.indexOfScalar(u8, rest, '"')) |open| {
        const close = std.mem.indexOfScalarPos(u8, rest, open + 1, '"') orelse return error.UnterminatedName;
        try names.append(allocator, rest[open + 1 .. close]);
        rest = rest[close + 1 ..];
    }
    return names;
}

/// The functions `out` defines whose body runs a [CEReactions] bracket.
fn bracketedFunctions(allocator: std.mem.Allocator, out: []const u8) !Names {
    var names: Names = .empty;
    errdefer names.deinit(allocator);
    var at: usize = 0;
    while (std.mem.indexOfPos(u8, out, at, "pub fn ")) |start| {
        const name_start = start + "pub fn ".len;
        const name_end = std.mem.indexOfScalarPos(u8, out, name_start, '(') orelse break;
        // The body ends where the next declaration starts: a member of an
        // interface's struct, or a mixin module's top-level one.
        const end = @min(
            std.mem.indexOfPos(u8, out, name_end, "\n    pub ") orelse out.len,
            std.mem.indexOfPos(u8, out, name_end, "\npub ") orelse out.len,
        );
        if (contains(out[name_end..end], "CEReactions.begin(")) try names.append(allocator, out[name_start..name_end]);
        at = name_end;
    }
    return names;
}

/// `pub const <name> = mixins.<Mixin>.<name>;` aliases in `out`: (name, Mixin).
const Alias = struct { name: []const u8, mixin: []const u8 };

fn mixinAliases(allocator: std.mem.Allocator, out: []const u8) !std.ArrayList(Alias) {
    var aliases: std.ArrayList(Alias) = .empty;
    errdefer aliases.deinit(allocator);
    var lines = std.mem.splitScalar(u8, out, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " ");
        if (!std.mem.startsWith(u8, trimmed, "pub const ")) continue;
        const eq = std.mem.indexOf(u8, trimmed, " = mixins.") orelse continue;
        const name = trimmed["pub const ".len..eq];
        const target = trimmed[eq + " = mixins.".len ..];
        const dot = std.mem.indexOfScalar(u8, target, '.') orelse continue;
        try aliases.append(allocator, .{ .name = name, .mixin = target[0..dot] });
    }
    return aliases;
}

fn has(names: []const []const u8, name: []const u8) bool {
    for (names) |n| if (std.mem.eql(u8, n, name)) return true;
    return false;
}

fn expectSameNames(what: []const u8, expected: []const []const u8, actual: []const []const u8) !void {
    var ok = expected.len == actual.len;
    for (expected) |n| if (!has(actual, n)) {
        ok = false;
    };
    if (!ok) {
        std.debug.print("{s}: expected {d} names, got {d}\n", .{ what, expected.len, actual.len });
        for (expected) |n| if (!has(actual, n)) std.debug.print("  missing: {s}\n", .{n});
        for (actual) |n| if (!has(expected, n)) std.debug.print("  extra:   {s}\n", .{n});
        return error.TestExpectedEqual;
    }
}

test "the ce_reactions table lists every function that brackets, and nothing else" {
    const replaceable = [_]types.ExtendedAttribute{ .{ .name = "CEReactions" }, .{ .name = "Replaceable" } };
    const attrs = [_]types.Attribute{
        .{ .name = "slot", .idlType = .{ .type = "DOMString" }, .extAttrs = @constCast(&ce_reactions) },
        .{ .name = "title", .idlType = .{ .type = "DOMString" } },
        // Read-only: no setter, so nothing to bracket.
        .{ .name = "tagName", .idlType = .{ .type = "DOMString" }, .readonly = true, .extAttrs = @constCast(&ce_reactions) },
        // [Replaceable]: its setter is a [[DefineOwnProperty]], not the member's steps.
        .{ .name = "self", .idlType = .{ .type = "any" }, .readonly = true, .extAttrs = @constCast(&replaceable) },
        .{ .name = "limit", .idlType = .{ .type = "unsigned long" }, .static = true, .extAttrs = @constCast(&ce_reactions) },
    };
    var one_arg = [_]types.Argument{.{ .name = "a", .idlType = .{ .type = "DOMString" } }};
    var two_args = [_]types.Argument{
        .{ .name = "a", .idlType = .{ .type = "DOMString" } },
        .{ .name = "b", .idlType = .{ .type = "boolean" } },
    };
    var setter_args = [_]types.Argument{
        .{ .name = "name", .idlType = .{ .type = "DOMString" } },
        .{ .name = "value", .idlType = .{ .type = "DOMString" } },
    };
    const ops = [_]types.Operation{
        .{ .name = "toggle", .idlType = .{ .type = "boolean" }, .arguments = &one_arg, .extAttrs = @constCast(&ce_reactions) },
        .{ .name = "toggle", .idlType = .{ .type = "boolean" }, .arguments = &two_args, .extAttrs = @constCast(&ce_reactions) },
        .{ .name = "matches", .idlType = .{ .type = "boolean" }, .arguments = &one_arg },
        .{ .name = "make", .idlType = .{ .type = "undefined" }, .static = true, .extAttrs = @constCast(&ce_reactions) },
        .{ .idlType = .{ .type = "undefined" }, .special = .setter, .arguments = &setter_args, .extAttrs = @constCast(&ce_reactions) },
    };
    // The first of each name, as the generator passes them.
    const own_ops = [_]types.Operation{ ops[0], ops[2], ops[3], ops[4] };
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "CellImpl", null, &attrs, &own_ops, &ops, .{});
    const out = buffer.written();

    var table = try tableNames(testing.allocator, out);
    defer table.deinit(testing.allocator);
    var bracketed = try bracketedFunctions(testing.allocator, out);
    defer bracketed.deinit(testing.allocator);

    try expectSameNames("bracketed functions", bracketed.items, table.items);
    try expectSameNames("the table", &.{ "set_slot", "set_static_limit", "call_toggle", "call_toggle__1", "call_static_make", "call_setter" }, table.items);
}

test "an interface without a [CEReactions] member has no ce_reactions table" {
    const attrs = [_]types.Attribute{.{ .name = "title", .idlType = .{ .type = "DOMString" } }};
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "CellImpl", null, &attrs, &.{}, &.{}, .{});
    try testing.expect(!contains(buffer.written(), "ce_reactions"));
}

test "an inherited mixin member's alias is in its includer's table, and the mixin module brackets it" {
    const attrs = [_]types.Attribute{
        .{ .name = "pace", .idlType = .{ .type = "double" }, .mixin = "Walkable", .extAttrs = @constCast(&ce_reactions) },
        .{ .name = "steps", .idlType = .{ .type = "double" }, .mixin = "Walkable" },
    };
    const ops = [_]types.Operation{
        .{ .name = "walk", .idlType = .{ .type = "undefined" }, .mixin = "Walkable", .extAttrs = @constCast(&ce_reactions) },
        .{ .name = "sit", .idlType = .{ .type = "undefined" }, .mixin = "Walkable" },
    };
    const inherited = [_][]const u8{"Walkable"};

    var includer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer includer.deinit();
    try writer.writeDelegateFunctions(&includer.writer, "DogImpl", null, &attrs, &ops, &ops, .{ .inherited_mixins = &inherited });
    var includer_table = try tableNames(testing.allocator, includer.written());
    defer includer_table.deinit(testing.allocator);
    try testing.expect(contains(includer.written(), "pub const set_pace = mixins.Walkable.set_pace;"));
    try testing.expect(contains(includer.written(), "pub const call_walk = mixins.Walkable.call_walk;"));
    try expectSameNames("the includer's table", &.{ "set_pace", "call_walk" }, includer_table.items);

    // The mixin's own module, as generateMixin writes it.
    var mixin_attrs = attrs;
    for (&mixin_attrs) |*a| a.mixin = null;
    var mixin_ops = ops;
    for (&mixin_ops) |*o| o.mixin = null;
    var mixin: std.Io.Writer.Allocating = .init(testing.allocator);
    defer mixin.deinit();
    try writer.writeDelegateFunctions(&mixin.writer, "WalkableImpl", null, &mixin_attrs, &mixin_ops, &mixin_ops, .{ .same_object_cache = false });
    var mixin_bracketed = try bracketedFunctions(testing.allocator, mixin.written());
    defer mixin_bracketed.deinit(testing.allocator);
    try expectSameNames("the mixin module's bracketed functions", includer_table.items, mixin_bracketed.items);
}

/// The committed tree, file by file: its ce_reactions table is its bracketed
/// functions plus its aliases of bracketed mixin functions.
fn checkCommittedFile(arena: std.mem.Allocator, dir: []const u8, name: []const u8) !void {
    const io = testing.io;
    const path = try std.fmt.allocPrint(arena, "src/webidl/{s}/{s}", .{ dir, name });
    const out = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(16 << 20));
    const table = try tableNames(arena, out);
    var expected = try bracketedFunctions(arena, out);
    const aliases = try mixinAliases(arena, out);
    for (aliases.items) |alias| {
        const mixin_path = try std.fmt.allocPrint(arena, "src/webidl/mixins/{s}.zig", .{alias.mixin});
        const mixin_out = try std.Io.Dir.cwd().readFileAlloc(io, mixin_path, arena, .limited(16 << 20));
        const mixin_bracketed = try bracketedFunctions(arena, mixin_out);
        if (has(mixin_bracketed.items, alias.name)) try expected.append(arena, alias.name);
    }
    expectSameNames(path, expected.items, table.items) catch |err| return err;
}

test "every committed interface and mixin module's table matches its brackets" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = testing.io;
    var checked: usize = 0;
    for ([_][]const u8{ "interfaces", "mixins" }) |dir_name| {
        const dir_path = try std.fmt.allocPrint(arena, "src/webidl/{s}", .{dir_name});
        var dir = try std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true });
        defer dir.close(io);
        var it = dir.iterate();
        while (try it.next(io)) |entry| {
            if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".zig")) continue;
            if (std.mem.eql(u8, entry.name, "root.zig")) continue;
            try checkCommittedFile(arena, dir_name, try arena.dupe(u8, entry.name));
            checked += 1;
        }
    }
    // The tree is there: over a thousand interfaces and mixins.
    try testing.expect(checked > 1000);
}
