//! lint-constructors: a WebIDL constructor's object is freed WHOLE when its
//! construction fails (lane ctor1; queue item 9 of the 0.1 audit, found by
//! lane hard1).
//!
//! WebIDL 3.7.1 (the interface object's steps 1.8-1.9) makes the object,
//! then runs the constructor steps with it as `this`. The generated
//! `call_constructor` does exactly that for an impl whose constructor steps
//! take the object - `pub fn call_constructor(instance: *runtime.Instance,
//! ...) !void`, the THIS FORM: it makes the object with the interface's own
//! construction chain, holds it under `errdefer runtime.gc.releaseOwned`,
//! and runs the steps. The construction is the object's only owner until it
//! returns it, so a failed step frees the object, storage and all. Before,
//! about 370 impls made the object themselves and on failure ran only their
//! own deinit - a destructor, not a free (docs/lessons/architecture-an-
//! interfaces-deinit-is-a-destructor-not-a-free.md) - and the slot and State
//! stayed until the Browser ended.
//!
//! What is flagged, in src/webidl/impls/*.zig through std.zig.Ast, in each
//! top-level `call_constructor`:
//! 1. FACTORY FORM - steps that take `ctx: runtime.Context` and return the
//!    object they made - for an impl not in the baseline's `factory` list.
//!    A factory is for a constructor whose object cannot be made before its
//!    steps (a node, made with its node document; an object made by a
//!    shared factory); it frees what it made itself, by rule 3.
//! 2. In the this form, a call that releases or destroys the receiver
//!    (`deinit(instance)`, `X.deinit(instance)`, `runtime.gc.releaseOwned(
//!    instance)`, `releaseStorage`, `releaseSevered`,
//!    `instance.releaseIfUnwrapped(...)`): the generated constructor frees
//!    it, so a second release is a double free.
//! 3. In either form, a bare destructor on an object: a call of `deinit(x)`,
//!    `Name.deinit(x)` (a capitalized type: an impl or an interface) or
//!    `interfaces.Name.deinit(x)` with one identifier argument. A failure
//!    path frees what it made with `runtime.gc.releaseOwned` (or
//!    `releaseIfUnwrapped` with its generation), never with a destructor
//!    alone.
//!
//! Exempt: a call whose line has a `// lint-constructors: <why>` line
//! directly above it. Say why.
//!
//! A ratchet: tools/constructors_baseline.txt records the factory-form
//! constructors (`factory Name`) and the bare destructors (`destructor Name
//! callee(arg)`). A new one fails, and so does an entry that no longer
//! holds - the baseline only goes down:
//!
//!   zig build lint-constructors                  (part of `zig build test`)
//!   zig build lint-constructors -- --list        every finding, with its line
//!   zig build lint-constructors -- --update      record fewer

const std = @import("std");
const Ast = std.zig.Ast;
const stdout_stream = @import("stdout_stream.zig");

/// The directory whose constructors are held to the rules.
pub const scanned_dir = "src/webidl/impls";

pub const baseline_path = "tools/constructors_baseline.txt";

/// The marker that exempts the call on the line below it.
pub const marker = "// lint-constructors:";

/// The receiver's type in the this form.
const receiver_type = "*runtime.Instance";

pub const Kind = enum {
    /// Rule 1: a factory-form constructor.
    factory,
    /// Rule 2: the this form releases its receiver.
    releases_receiver,
    /// Rule 3: a bare destructor.
    destructor,
};

pub const Finding = struct {
    kind: Kind,
    /// factory: empty; otherwise the call, `callee(argument)`.
    call: []const u8,
    line: u32,
};

/// Calls that free or destroy their first argument.
const release_callees = [_][]const u8{ "deinit", "releaseOwned", "releaseStorage", "releaseSevered" };

fn lastSegment(callee: []const u8) []const u8 {
    const dot = std.mem.lastIndexOfScalar(u8, callee, '.') orelse return callee;
    return callee[dot + 1 ..];
}

fn isIdentifier(text: []const u8) bool {
    if (text.len == 0) return false;
    if (!(std.ascii.isAlphabetic(text[0]) or text[0] == '_')) return false;
    for (text) |c| if (!(std.ascii.isAlphanumeric(c) or c == '_')) return false;
    return true;
}

/// `deinit`, `Name.deinit` (a capitalized type) or `interfaces.Name.deinit`.
pub fn isBareDestructor(callee: []const u8) bool {
    if (std.mem.eql(u8, callee, "deinit")) return true;
    if (!std.mem.endsWith(u8, callee, ".deinit")) return false;
    var type_name = callee[0 .. callee.len - ".deinit".len];
    if (std.mem.startsWith(u8, type_name, "interfaces.")) type_name = type_name["interfaces.".len..];
    return isIdentifier(type_name) and std.ascii.isUpper(type_name[0]);
}

fn lineOf(source: []const u8, offset: usize) u32 {
    return @intCast(std.mem.count(u8, source[0..offset], "\n") + 1);
}

/// Whether the line before the one holding `offset` is the marker.
fn exempt(source: []const u8, offset: usize) bool {
    const line_start = if (std.mem.lastIndexOfScalar(u8, source[0..offset], '\n')) |nl| nl + 1 else 0;
    if (line_start == 0) return false;
    const prev_end = line_start - 1;
    const prev_start = if (std.mem.lastIndexOfScalar(u8, source[0..prev_end], '\n')) |nl| nl + 1 else 0;
    const prev = std.mem.trim(u8, source[prev_start..prev_end], " \t\r");
    return std.mem.startsWith(u8, prev, marker);
}

/// Every finding in one impl's `source`, in source order; text in `arena`.
/// A file that does not parse is an error.
pub fn findings(arena: std.mem.Allocator, source: [:0]const u8) !std.ArrayList(Finding) {
    var tree = try Ast.parse(arena, source, .{ .mode = .zig });
    defer tree.deinit(arena);
    if (tree.errors.len > 0) return error.ParseError;

    var out: std.ArrayList(Finding) = .empty;
    for (tree.rootDecls()) |decl| {
        if (tree.nodeTag(decl) != .fn_decl) continue;
        var buf: [1]Ast.Node.Index = undefined;
        const proto = tree.fullFnProto(&buf, decl) orelse continue;
        const name_token = proto.name_token orelse continue;
        if (!std.mem.eql(u8, tree.tokenSlice(name_token), "call_constructor")) continue;

        // The form, from the first parameter.
        var receiver: ?[]const u8 = null;
        var params = proto.iterate(&tree);
        if (params.next()) |first| {
            if (first.type_expr) |type_expr| {
                if (std.mem.eql(u8, tree.getNodeSource(type_expr), receiver_type)) {
                    receiver = if (first.name_token) |t| tree.tokenSlice(t) else null;
                }
            }
        }
        if (receiver == null) try out.append(arena, .{
            .kind = .factory,
            .call = "",
            .line = lineOf(source, tree.tokenStart(name_token)),
        });

        // The calls in its body.
        const body = tree.nodeData(decl).node_and_node[1];
        const first_token = tree.firstToken(body);
        const last_token = tree.lastToken(body);
        const node_count: u32 = @intCast(tree.nodes.len);
        var i: u32 = 0;
        while (i < node_count) : (i += 1) {
            const node: Ast.Node.Index = @fromBackingInt(@intCast(i));
            var call_buf: [1]Ast.Node.Index = undefined;
            const call = tree.fullCall(&call_buf, node) orelse continue;
            const at = tree.firstToken(node);
            if (at < first_token or at > last_token) continue;
            const callee = tree.getNodeSource(call.ast.fn_expr);
            const argument: []const u8 = if (call.ast.params.len > 0) tree.getNodeSource(call.ast.params[0]) else "";
            const offset = tree.tokenStart(at);
            if (exempt(source, offset)) continue;
            const text = try std.fmt.allocPrint(arena, "{s}({s})", .{ callee, if (call.ast.params.len == 1) argument else if (call.ast.params.len == 0) "" else try std.fmt.allocPrint(arena, "{s}, ...", .{argument}) });

            if (receiver) |r| {
                const releases = for (release_callees) |name| {
                    if (std.mem.eql(u8, lastSegment(callee), name) and std.mem.eql(u8, argument, r)) break true;
                } else std.mem.startsWith(u8, callee, r) and std.mem.eql(u8, callee[r.len..], ".releaseIfUnwrapped");
                if (releases) {
                    try out.append(arena, .{ .kind = .releases_receiver, .call = text, .line = lineOf(source, offset) });
                    continue;
                }
            }
            if (isBareDestructor(callee) and call.ast.params.len == 1 and isIdentifier(argument)) {
                try out.append(arena, .{ .kind = .destructor, .call = text, .line = lineOf(source, offset) });
            }
        }
    }
    std.mem.sort(Finding, out.items, {}, struct {
        fn less(_: void, x: Finding, y: Finding) bool {
            return x.line < y.line;
        }
    }.less);
    return out;
}

// ============================================================================
// The baseline
// ============================================================================

/// The recorded keys: `factory Name`, `destructor Name callee(arg)`.
pub const Keys = std.StringHashMapUnmanaged(void);

pub fn parseBaseline(arena: std.mem.Allocator, text: []const u8) !Keys {
    var keys: Keys = .empty;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        if (!std.mem.startsWith(u8, line, "factory ") and !std.mem.startsWith(u8, line, "destructor ")) return error.BadBaseline;
        try keys.put(arena, try arena.dupe(u8, line), {});
    }
    return keys;
}

const header =
    \\# WebIDL constructors held to tools/lint_constructors.zig: a construction that
    \\# fails frees its object WHOLE (lane ctor1). `factory Name`: an impl whose
    \\# call_constructor still makes its own object (the factory form) instead of
    \\# taking the one the generated constructor made (`instance: *runtime.Instance`,
    \\# the this form). `destructor Name callee(arg)`: a bare destructor in a
    \\# constructor - a destructor, not a free. A ratchet: `zig build lint-constructors`,
    \\# part of `zig build test`, fails on a new one and on an entry that no longer
    \\# holds; after converting some, `zig build lint-constructors -- --update`. Never
    \\# raise it by hand.
    \\
;

fn lessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

pub fn formatBaseline(arena: std.mem.Allocator, keys: *const Keys) ![]u8 {
    var list: std.ArrayList([]const u8) = .empty;
    var it = keys.keyIterator();
    while (it.next()) |key| try list.append(arena, key.*);
    std.mem.sort([]const u8, list.items, {}, lessThan);
    var out: std.ArrayList(u8) = .empty;
    try out.appendSlice(arena, header);
    for (list.items) |key| try out.print(arena, "{s}\n", .{key});
    return out.items;
}

/// The keys of `a` that `b` lacks, sorted.
pub fn missingFrom(arena: std.mem.Allocator, a: *const Keys, b: *const Keys) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    var it = a.keyIterator();
    while (it.next()) |key| if (!b.contains(key.*)) try out.append(arena, key.*);
    std.mem.sort([]const u8, out.items, {}, lessThan);
    return out.items;
}

/// The baseline key of `finding` in the impl `name`.
pub fn keyOf(arena: std.mem.Allocator, name: []const u8, finding: Finding) ![]const u8 {
    return switch (finding.kind) {
        .factory => std.fmt.allocPrint(arena, "factory {s}", .{name}),
        .destructor => std.fmt.allocPrint(arena, "destructor {s} {s}", .{ name, finding.call }),
        // Never recorded: always an error.
        .releases_receiver => std.fmt.allocPrint(arena, "releases-receiver {s} {s}", .{ name, finding.call }),
    };
}

// ============================================================================
// The tool
// ============================================================================

const Site = struct { path: []const u8, line: u32, key: []const u8, kind: Kind };

fn scan(arena: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, current: *Keys, sites: *std.ArrayList(Site)) !void {
    var impls = try dir.openDir(io, scanned_dir, .{ .iterate = true });
    defer impls.close(io);
    var it = impls.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".zig")) continue;
        const name = try arena.dupe(u8, entry.name[0 .. entry.name.len - ".zig".len]);
        const path = try std.fmt.allocPrint(arena, "{s}/{s}", .{ scanned_dir, entry.name });
        const source = try dir.readFileAllocOptions(io, path, arena, .limited(64 << 20), .of(u8), 0);
        const found = findings(arena, source) catch |err| switch (err) {
            error.ParseError => {
                std.debug.print("lint-constructors: {s} does not parse\n", .{path});
                return err;
            },
            else => return err,
        };
        for (found.items) |f| {
            var key = try keyOf(arena, name, f);
            // Two of one call in a constructor: numbered in source order.
            var n: u32 = 2;
            while (current.contains(key)) : (n += 1) key = try std.fmt.allocPrint(arena, "{s}#{d}", .{ try keyOf(arena, name, f), n });
            try current.put(arena, key, {});
            try sites.append(arena, .{ .path = path, .line = f.line, .key = key, .kind = f.kind });
        }
    }
    std.mem.sort(Site, sites.items, {}, struct {
        fn less(_: void, a: Site, b: Site) bool {
            const order = std.mem.order(u8, a.path, b.path);
            return order == .lt or (order == .eq and a.line < b.line);
        }
    }.less);
}

fn usage() noreturn {
    std.debug.print("usage: lint_constructors [--update | --list]\n", .{});
    std.process.exit(2);
}

fn explain(kind: Kind) []const u8 {
    return switch (kind) {
        .factory => "a constructor in the factory form (it makes its own object): take the object the generated constructor made - `pub fn call_constructor(instance: *runtime.Instance, ...) !void` - which frees it whole when a step fails",
        .releases_receiver => "the this form releases its receiver: the generated constructor frees it whole when a step fails, so this is a double free",
        .destructor => "a bare destructor in a constructor - a destructor, not a free: free what the construction made whole (runtime.gc.releaseOwned) (docs/lessons/architecture-an-interfaces-deinit-is-a-destructor-not-a-free.md)",
    };
}

pub fn main(init: std.process.Init) !void {
    var arena_state = std.heap.ArenaAllocator.init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = init.io;

    var update = false;
    var list = false;
    var args = try init.minimal.args.iterateAllocator(arena);
    defer args.deinit();
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--update")) update = true else if (std.mem.eql(u8, arg, "--list")) list = true else usage();
    }

    const cwd = std.Io.Dir.cwd();
    var current: Keys = .empty;
    var sites: std.ArrayList(Site) = .empty;
    try scan(arena, io, cwd, &current, &sites);

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = stdout_stream.writer(io, &stdout_buf);
    const out = &stdout_writer.interface;
    defer out.flush() catch {};

    if (list) {
        for (sites.items) |site| try out.print("{s}:{d}: {s}\n", .{ site.path, site.line, site.key });
        return;
    }

    const baseline_text: ?[]const u8 = cwd.readFileAlloc(io, baseline_path, arena, .limited(16 << 20)) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    var baseline = if (baseline_text) |text| try parseBaseline(arena, text) else Keys.empty;
    const new = try missingFrom(arena, &current, &baseline);
    const stale = try missingFrom(arena, &baseline, &current);

    // A receiver released twice is never recorded.
    var double_frees: usize = 0;
    for (sites.items) |site| if (site.kind == .releases_receiver) {
        try out.print("{s}:{d}: error: {s} (tools/lint_constructors.zig)\n", .{ site.path, site.line, explain(site.kind) });
        double_frees += 1;
    };

    if (update) {
        if (double_frees > 0 or (baseline_text != null and new.len > 0)) {
            for (new) |key| if (!std.mem.startsWith(u8, key, "releases-receiver ")) try out.print("lint-constructors: refusing to record {s}: new\n", .{key});
            try out.flush();
            std.process.exit(1);
        }
        try cwd.writeFile(io, .{ .sub_path = baseline_path, .data = try formatBaseline(arena, &current) });
        try out.print("lint-constructors: recorded {d} entr{s} in {s}\n", .{ current.count(), if (current.count() == 1) "y" else "ies", baseline_path });
        return;
    }

    var failed = double_frees > 0;
    for (new) |key| {
        if (std.mem.startsWith(u8, key, "releases-receiver ")) continue;
        for (sites.items) |site| if (std.mem.eql(u8, site.key, key)) {
            try out.print("{s}:{d}: error: {s} (tools/lint_constructors.zig)\n", .{ site.path, site.line, explain(site.kind) });
        };
        failed = true;
    }
    for (stale) |key| {
        try out.print("{s}: error: `{s}` no longer holds - record the smaller baseline: zig build lint-constructors -- --update\n", .{ baseline_path, key });
        failed = true;
    }
    if (failed) {
        try out.print("\nlint-constructors: {d} new, {d} stale, {d} double free(s) against {s}.\n", .{ new.len - double_frees, stale.len, double_frees, baseline_path });
        try out.flush();
        std.process.exit(1);
    }
    var factories: usize = 0;
    var destructors: usize = 0;
    var it = current.keyIterator();
    while (it.next()) |key| {
        if (std.mem.startsWith(u8, key.*, "factory ")) factories += 1 else destructors += 1;
    }
    try out.print("lint-constructors: {d} factory-form constructor(s), {d} bare destructor(s), as recorded.\n", .{ factories, destructors });
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

fn findingsOf(arena: std.mem.Allocator, source: [:0]const u8) ![]const Finding {
    return (try findings(arena, source)).items;
}

test "the factory form with a bare destructor on its failure path: both flagged (hard1's TextDecoder before its fix)" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const found = try findingsOf(arena,
        \\pub fn call_constructor(ctx: runtime.Context, label: webidl.Opt(runtime.DOMString)) !*runtime.Instance {
        \\    const instance = try init(ctx.allocator, State, &TextDecoder.vtable, ctx);
        \\    errdefer deinit(instance);
        \\    try steps(instance, label);
        \\    return instance;
        \\}
    );
    try testing.expectEqual(@as(usize, 2), found.len);
    try testing.expectEqual(Kind.factory, found[0].kind);
    try testing.expectEqual(@as(u32, 1), found[0].line);
    try testing.expectEqual(Kind.destructor, found[1].kind);
    try testing.expectEqualStrings("deinit(instance)", found[1].call);
    try testing.expectEqual(@as(u32, 3), found[1].line);
}

test "a factory that frees what it made whole is only a factory" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const found = try findingsOf(arena,
        \\pub fn call_constructor(ctx: runtime.Context, data: webidl.Opt(runtime.DOMString)) !*runtime.Instance {
        \\    const instance = try Text.initWith(ctx.allocator, ctx, .{ .data = data });
        \\    errdefer runtime.gc.releaseOwned(instance);
        \\    const generation = runtime.SlabAllocator.generationOf(instance);
        \\    steps(instance) catch |err| {
        \\        instance.releaseIfUnwrapped(generation);
        \\        return err;
        \\    };
        \\    var list = try List.init(ctx.allocator);
        \\    errdefer list.deinit(ctx.allocator);
        \\    errdefer state.internal.deinit();
        \\    return instance;
        \\}
    );
    try testing.expectEqual(@as(usize, 1), found.len);
    try testing.expectEqual(Kind.factory, found[0].kind);
}

test "the this form: a release of the receiver is a double free; a child's bare destructor is flagged" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const found = try findingsOf(arena,
        \\pub fn call_constructor(instance: *runtime.Instance) !void {
        \\    const port1 = try adopt(instance.ctx, channel.end(0));
        \\    errdefer MessagePortInterface.deinit(port1);
        \\    errdefer interfaces.MessagePort.deinit(port1);
        \\    errdefer runtime.gc.releaseOwned(port1);
        \\    errdefer deinit(instance);
        \\    errdefer runtime.gc.releaseOwned(instance);
        \\    errdefer instance.releaseIfUnwrapped(generation);
        \\    errdefer runtime.Instance.deinit(instance);
        \\    try more(instance);
        \\}
    );
    var kinds: std.ArrayList(Kind) = .empty;
    for (found) |f| try kinds.append(arena, f.kind);
    try testing.expectEqualSlices(Kind, &.{ .destructor, .destructor, .releases_receiver, .releases_receiver, .releases_receiver, .releases_receiver }, kinds.items);
    try testing.expectEqualStrings("MessagePortInterface.deinit(port1)", found[0].call);
    try testing.expectEqualStrings("interfaces.MessagePort.deinit(port1)", found[1].call);
}

test "a marked call is exempt; other functions and methods named deinit are not destructors" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const found = try findingsOf(arena,
        \\fn helper(instance: *runtime.Instance) void {
        \\    deinit(instance);
        \\}
        \\pub fn call_constructor(instance: *runtime.Instance, x: f64) !void {
        \\    // lint-constructors: a test of the marker.
        \\    errdefer Other.deinit(child);
        \\    errdefer internal.deinit(child);
        \\    errdefer Other.deinit(child, allocator);
        \\    errdefer Other.deinit(a.b);
        \\    _ = x;
        \\}
    );
    try testing.expectEqual(@as(usize, 0), found.len);
}

test "isBareDestructor: deinit, a capitalized type's, an interface's; not a value's or the runtime's whole free" {
    try testing.expect(isBareDestructor("deinit"));
    try testing.expect(isBareDestructor("Text.deinit"));
    try testing.expect(isBareDestructor("interfaces.MessagePort.deinit"));
    try testing.expect(!isBareDestructor("internal.deinit"));
    try testing.expect(!isBareDestructor("runtime.Instance.deinit"));
    try testing.expect(!isBareDestructor("s.vtable.deinit"));
    try testing.expect(!isBareDestructor("deinitOwn"));
}

test "the baseline: a new key fails, a gone one is stale; it round-trips" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var baseline = try parseBaseline(arena, "# header\nfactory Text\ndestructor Event deinit(instance)\n");
    var current: Keys = .empty;
    try current.put(arena, "factory Text", {});
    try current.put(arena, "factory Comment", {});
    const new = try missingFrom(arena, &current, &baseline);
    try testing.expectEqual(@as(usize, 1), new.len);
    try testing.expectEqualStrings("factory Comment", new[0]);
    const stale = try missingFrom(arena, &baseline, &current);
    try testing.expectEqual(@as(usize, 1), stale.len);
    try testing.expectEqualStrings("destructor Event deinit(instance)", stale[0]);
    const again = try parseBaseline(arena, try formatBaseline(arena, &current));
    try testing.expect(again.contains("factory Comment"));
    try testing.expectEqual(@as(u32, 2), again.count());
    try testing.expectError(error.BadBaseline, parseBaseline(arena, "Text\n"));
}
