//! The engine boundary, as a ratchet: `zig build lint-engine` (and so `zig
//! build test`) fails when any file outside the V8 adapter references V8 more
//! often than tools/engine_boundary_baseline.txt records.
//!
//! AGENTS.md, "The engine boundary": Crane's JavaScript engine is an adapter.
//! V8 is one implementation, statically linked on desktop and server; on iOS
//! the system JavaScriptCore is linked dynamically instead. V8 types and calls
//! belong in src/runtime/engines/v8/ (and its tests, tests/v8/) and nowhere
//! else. Everything else reaches the engine through runtime's engine-neutral
//! surface - runtime.Instance, runtime.JSValue, runtime.Context and the Engine
//! table in src/runtime/engine_interface.zig.
//!
//! What is counted, per file and per name:
//!   * every `@import` whose path names V8 - `@import("v8")`,
//!     `@import("v8_promise_chaining")`, `@import("realm_v8.zig")` - keyed with
//!     the first member an inline import reaches (`@import("v8").JsScope`);
//!   * every `v8_*` identifier - the FFI's functions, and the V8 concepts
//!     (`v8_ctx`) that travel with them;
//!   * every member reached through an alias of such an import - `v8.ffi`,
//!     `v8.context_manager`, and through `const ffi = v8.ffi;`, `v8.ffi.Isolate`.
//!
//! Keying on the name, not just a per-file total, is what catches a swap:
//! trading one call for a new one leaves the total unchanged.
//!
//! The baseline only goes down. After moving a file's calls behind the Engine
//! table:
//!     zig build lint-engine -- --update
//! which refuses to record an increase. When it reaches zero, "v8" leaves the
//! non-adapter modules' imports in build.zig and the module graph enforces the
//! rule; this lint then only guards it.

const std = @import("std");

const baseline_path = "tools/engine_boundary_baseline.txt";

/// Directories scanned for .zig files.
const scanned_roots = [_][]const u8{ "src", "tests", "tools" };

/// The adapter and its tests, where V8 belongs - and code that is not Crane's.
const exempt_prefixes = [_][]const u8{
    "src/runtime/engines/v8/",
    "tests/v8/",
    // The WPT checkout (a submodule): upstream code, not Crane's.
    "tests/wpt/",
};

/// This tool: its tests spell out the references it counts.
const exempt_files = [_][]const u8{"tools/lint_engine_boundary.zig"};

/// Whether `path` (repo-relative, `/`-separated) is held to the boundary.
pub fn inScope(path: []const u8) bool {
    if (!std.mem.endsWith(u8, path, ".zig")) return false;
    for (exempt_prefixes) |prefix| if (std.mem.startsWith(u8, path, prefix)) return false;
    for (exempt_files) |file| if (std.mem.eql(u8, path, file)) return false;
    return true;
}

/// One V8 reference: its line and the key it is counted under.
pub const Reference = struct {
    line: u32,
    name: []const u8,
    /// The line's code, for the report.
    code: []const u8 = "",
};

fn isIdentChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

/// A line without its `//` comment. A `//` inside a string cuts the line
/// short too, which undercounts consistently in the baseline and the check.
fn codeOf(line: []const u8) []const u8 {
    const cut = std.mem.indexOf(u8, line, "//") orelse line.len;
    return line[0..cut];
}

fn identAt(text: []const u8, start: usize) []const u8 {
    var end = start;
    while (end < text.len and isIdentChar(text[end])) end += 1;
    return text[start..end];
}

/// Whether an import path names V8.
fn namesV8(path: []const u8) bool {
    return std.mem.indexOf(u8, path, "v8") != null;
}

/// An alias bound to a V8 import, and what it stands for: `v8` -> "v8",
/// `ffi` -> "v8.ffi".
const Alias = struct { name: []const u8, target: []const u8 };

fn aliasTarget(aliases: []const Alias, name: []const u8) ?[]const u8 {
    for (aliases) |alias| if (std.mem.eql(u8, alias.name, name)) return alias.target;
    return null;
}

/// `code` with the contents of every "..." string blanked, so identifiers
/// inside a log message are not counted as references. Same length.
fn blankStrings(buf: []u8, code: []const u8) []const u8 {
    const out = buf[0..code.len];
    @memcpy(out, code);
    var in_string = false;
    var i: usize = 0;
    while (i < out.len) : (i += 1) {
        const c = out[i];
        if (in_string) {
            if (c == '\\' and i + 1 < out.len) {
                out[i] = ' ';
                out[i + 1] = ' ';
                i += 1;
                continue;
            }
            if (c == '"') {
                in_string = false;
                continue;
            }
            out[i] = ' ';
        } else if (c == '"') in_string = true;
    }
    return out;
}

/// Every V8 reference in `text`, in line order. Keys are allocated with `gpa`.
pub fn references(gpa: std.mem.Allocator, text: []const u8) !std.ArrayList(Reference) {
    var out: std.ArrayList(Reference) = .empty;
    errdefer out.deinit(gpa);
    var aliases: std.ArrayList(Alias) = .empty;
    defer aliases.deinit(gpa);

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(gpa);

    var lines = std.mem.splitScalar(u8, text, '\n');
    var line_no: u32 = 0;
    while (lines.next()) |raw| {
        line_no += 1;
        const code = codeOf(raw);
        const trimmed = std.mem.trim(u8, code, " \t\r");
        // A multiline string literal: text, not code.
        if (std.mem.startsWith(u8, trimmed, "\\\\")) continue;
        if (trimmed.len == 0) continue;

        // 1. Imports whose path names V8, keyed with the first member an
        // inline import reaches.
        var search: usize = 0;
        const open = "@import(\"";
        while (std.mem.indexOfPos(u8, code, search, open)) |at| {
            const path_start = at + open.len;
            const path_end = std.mem.indexOfScalarPos(u8, code, path_start, '"') orelse break;
            search = path_end + 1;
            const path = code[path_start..path_end];
            if (!namesV8(path)) continue;
            // `@import("x")` then an optional `.member`.
            var key_end = path_end + 2; // past `")`
            if (key_end < code.len and code[key_end] == '.') {
                const member = identAt(code, key_end + 1);
                if (member.len > 0) key_end += 1 + member.len;
            }
            const key = try gpa.dupe(u8, code[at..@min(key_end, code.len)]);
            try out.append(gpa, .{ .line = line_no, .name = key, .code = trimmed });
        }

        try buf.resize(gpa, code.len);
        const plain = blankStrings(buf.items, code);

        // A `const name = <V8 import or alias>[.path];` binds a new alias.
        try bindAlias(gpa, &aliases, code, plain);

        // 2. `v8_*` identifiers, and 3. members reached through an alias.
        var i: usize = 0;
        while (i < plain.len) {
            if (!isIdentChar(plain[i]) or (i > 0 and (isIdentChar(plain[i - 1]) or plain[i - 1] == '@'))) {
                i += 1;
                continue;
            }
            const ident = identAt(plain, i);
            defer i += ident.len;
            // A `v8_` identifier counts wherever it stands, `v8.ffi.v8_Foo` too.
            if (std.mem.startsWith(u8, ident, "v8_")) {
                try out.append(gpa, .{ .line = line_no, .name = try gpa.dupe(u8, ident), .code = trimmed });
                continue;
            }
            // An alias only at the head of a member path, not as `x.v8`.
            if (i > 0 and plain[i - 1] == '.') continue;
            const target = aliasTarget(aliases.items, ident) orelse continue;
            const after = i + ident.len;
            if (after >= plain.len or plain[after] != '.') continue;
            const member = identAt(plain, after + 1);
            if (member.len == 0) continue;
            // `v8.v8_Foo` is counted once, by rule 2, on its own identifier.
            if (std.mem.startsWith(u8, member, "v8_")) continue;
            const key = try std.fmt.allocPrint(gpa, "{s}.{s}", .{ target, member });
            try out.append(gpa, .{ .line = line_no, .name = key, .code = trimmed });
        }
    }
    return out;
}

/// `[pub] const name = @import("<v8 path>")[.a.b];` or `const name = alias[.a];`
fn bindAlias(gpa: std.mem.Allocator, aliases: *std.ArrayList(Alias), code: []const u8, plain: []const u8) !void {
    var s = std.mem.trim(u8, plain, " \t\r");
    if (std.mem.startsWith(u8, s, "pub ")) s = std.mem.trimStart(u8, s[4..], " ");
    if (!std.mem.startsWith(u8, s, "const ")) return;
    s = std.mem.trimStart(u8, s[6..], " ");
    const name_at = @intFromPtr(s.ptr) - @intFromPtr(plain.ptr);
    // From the source text, which outlives this line's scratch buffer.
    const name = identAt(code, name_at);
    if (name.len == 0) return;
    s = std.mem.trimStart(u8, s[name.len..], " ");
    if (s.len == 0 or s[0] != '=') return;
    s = std.mem.trim(u8, s[1..], " \t;");

    // The same span of the original code, strings intact.
    const rhs_start = @intFromPtr(s.ptr) - @intFromPtr(plain.ptr);
    const rhs = code[rhs_start .. rhs_start + s.len];

    var target: []const u8 = undefined;
    var rest: []const u8 = undefined;
    const open = "@import(\"";
    if (std.mem.startsWith(u8, rhs, open)) {
        const end = std.mem.indexOfScalarPos(u8, rhs, open.len, '"') orelse return;
        const path = rhs[open.len..end];
        if (!namesV8(path)) return;
        target = path;
        rest = if (end + 2 <= rhs.len) rhs[end + 2 ..] else "";
    } else {
        const head = identAt(rhs, 0);
        target = aliasTarget(aliases.items, head) orelse return;
        rest = rhs[head.len..];
    }
    // Only a plain member path (`.ffi`, `.ffi.Isolate`) makes an alias; a call
    // or anything else is a use, counted where it is.
    for (rest) |c| if (!(isIdentChar(c) or c == '.')) return;
    const full = try std.fmt.allocPrint(gpa, "{s}{s}", .{ target, rest });
    try aliases.append(gpa, .{ .name = name, .target = full });
}

/// Counts per "path name" key.
pub const Counts = std.StringHashMapUnmanaged(u32);

/// A key the current tree has more of than the baseline allows.
pub const Violation = struct { key: []const u8, allowed: u32, found: u32 };

fn lessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

fn violationLessThan(_: void, a: Violation, b: Violation) bool {
    return std.mem.lessThan(u8, a.key, b.key);
}

/// Every key in `current` above its baseline count - a key absent from the
/// baseline is allowed zero - sorted by key.
pub fn violations(gpa: std.mem.Allocator, current: *const Counts, baseline: *const Counts) !std.ArrayList(Violation) {
    var out: std.ArrayList(Violation) = .empty;
    errdefer out.deinit(gpa);
    var it = current.iterator();
    while (it.next()) |entry| {
        const allowed = baseline.get(entry.key_ptr.*) orelse 0;
        if (entry.value_ptr.* > allowed) {
            try out.append(gpa, .{ .key = entry.key_ptr.*, .allowed = allowed, .found = entry.value_ptr.* });
        }
    }
    std.mem.sort(Violation, out.items, {}, violationLessThan);
    return out;
}

/// Parse a baseline file: `path name count` per line, `#` comments. Keys are
/// allocated with `gpa` and owned by the map.
pub fn parseBaseline(gpa: std.mem.Allocator, text: []const u8) !Counts {
    var counts: Counts = .empty;
    errdefer {
        var keys = counts.keyIterator();
        while (keys.next()) |key| gpa.free(key.*);
        counts.deinit(gpa);
    }
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        const space = std.mem.lastIndexOfScalar(u8, line, ' ') orelse return error.MalformedBaseline;
        const count = std.fmt.parseInt(u32, line[space + 1 ..], 10) catch return error.MalformedBaseline;
        const key = try gpa.dupe(u8, std.mem.trimEnd(u8, line[0..space], " "));
        errdefer gpa.free(key);
        const gop = try counts.getOrPut(gpa, key);
        if (gop.found_existing) {
            gpa.free(key);
            gop.value_ptr.* += count;
        } else gop.value_ptr.* = count;
    }
    return counts;
}

const header =
    \\# V8 references outside the V8 adapter (src/runtime/engines/v8/): path name count.
    \\# A ratchet - `zig build lint-engine`, part of `zig build test`, fails if any
    \\# count rises or a new pair appears. After moving calls behind the Engine table
    \\# (src/runtime/engine_interface.zig), lower it with
    \\# `zig build lint-engine -- --update`. Never raise it by hand.
    \\
;

/// Format counts as a baseline file, keys sorted.
pub fn formatBaseline(gpa: std.mem.Allocator, counts: *const Counts) ![]u8 {
    var keys: std.ArrayList([]const u8) = .empty;
    defer keys.deinit(gpa);
    var it = counts.keyIterator();
    while (it.next()) |key| try keys.append(gpa, key.*);
    std.mem.sort([]const u8, keys.items, {}, lessThan);

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(gpa);
    try out.appendSlice(gpa, header);
    for (keys.items) |key| {
        const line = try std.fmt.allocPrint(gpa, "{s} {d}\n", .{ key, counts.get(key).? });
        defer gpa.free(line);
        try out.appendSlice(gpa, line);
    }
    return out.toOwnedSlice(gpa);
}

fn scanDir(
    arena: std.mem.Allocator,
    io: std.Io,
    root: []const u8,
    current: *Counts,
    sites: *std.StringHashMapUnmanaged(std.ArrayList(Reference)),
    files: *std.StringHashMapUnmanaged(void),
) !void {
    var dir = std.Io.Dir.cwd().openDir(io, root, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer dir.close(io);
    var walker = try dir.walk(arena);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;
        const path = try std.fmt.allocPrint(arena, "{s}/{s}", .{ root, entry.path });
        std.mem.replaceScalar(u8, path, '\\', '/');
        if (!inScope(path)) continue;
        // Build caches under a scanned root are not source.
        if (std.mem.indexOf(u8, path, ".zig-cache/") != null) continue;
        const text = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(64 << 20));
        var refs = try references(arena, text);
        if (refs.items.len > 0) try files.put(arena, path, {});
        for (refs.items) |ref| {
            const key = try std.fmt.allocPrint(arena, "{s} {s}", .{ path, ref.name });
            const gop = try current.getOrPut(arena, key);
            if (!gop.found_existing) gop.value_ptr.* = 0;
            gop.value_ptr.* += 1;
            const site = try sites.getOrPut(arena, key);
            if (!site.found_existing) site.value_ptr.* = .empty;
            try site.value_ptr.append(arena, ref);
        }
        refs.deinit(arena);
    }
}

pub fn main(init: std.process.Init) !void {
    var arena_state = std.heap.ArenaAllocator.init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = init.io;

    var update = false;
    var args = try init.minimal.args.iterateAllocator(arena);
    defer args.deinit();
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--update")) {
            update = true;
        } else {
            std.debug.print("usage: lint_engine_boundary [--update]\n", .{});
            std.process.exit(2);
        }
    }

    var current: Counts = .empty;
    var sites = std.StringHashMapUnmanaged(std.ArrayList(Reference)).empty;
    var files: std.StringHashMapUnmanaged(void) = .empty;
    for (scanned_roots) |root| try scanDir(arena, io, root, &current, &sites, &files);

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buf);
    const out = &stdout_writer.interface;
    defer out.flush() catch {};

    var total: usize = 0;
    var values = current.valueIterator();
    while (values.next()) |value| total += value.*;

    const text: ?[]u8 = std.Io.Dir.cwd().readFileAlloc(io, baseline_path, arena, .limited(64 << 20)) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    if (text == null) {
        if (!update) {
            try out.print("engine boundary: no {s}; record one with `zig build lint-engine -- --update`.\n", .{baseline_path});
            try out.flush();
            std.process.exit(1);
        }
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = baseline_path, .data = try formatBaseline(arena, &current) });
        try out.print("engine boundary: first baseline recorded - {d} references in {d} files, {d} keys.\n", .{ total, files.count(), current.count() });
        return;
    }
    const baseline = try parseBaseline(arena, text.?);

    const found = try violations(arena, &current, &baseline);
    if (found.items.len > 0) {
        try out.print("engine boundary: {d} key(s) above the baseline.\n\n", .{found.items.len});
        for (found.items) |v| {
            try out.print("  {s}: allowed {d}, found {d}\n", .{ v.key, v.allowed, v.found });
            if (sites.get(v.key)) |list| {
                const path_end = std.mem.indexOfScalar(u8, v.key, ' ') orelse v.key.len;
                for (list.items) |ref| try out.print("      {s}:{d}: {s}\n", .{ v.key[0..path_end], ref.line, ref.code });
            }
        }
        try out.print(
            \\
            \\V8 belongs in src/runtime/engines/v8/ only (AGENTS.md, "The engine boundary").
            \\Reach the engine through runtime.Instance / runtime.JSValue / runtime.Context
            \\and the Engine table in src/runtime/engine_interface.zig; an operation it lacks
            \\is added there, named after the spec concept, with a V8 implementation and an
            \\explicit NotSupported entry for the other engines.
            \\
        , .{});
        try out.flush();
        std.process.exit(1);
    }

    var lowered: usize = 0;
    var base_it = baseline.iterator();
    while (base_it.next()) |entry| {
        if ((current.get(entry.key_ptr.*) orelse 0) < entry.value_ptr.*) lowered += 1;
    }
    if (update) {
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = baseline_path, .data = try formatBaseline(arena, &current) });
        try out.print("engine boundary: baseline lowered - {d} references in {d} files, {d} keys.\n", .{ total, files.count(), current.count() });
    } else if (lowered > 0) {
        try out.print("engine boundary: {d} key(s) paid down; record it with `zig build lint-engine -- --update`.\n", .{lowered});
    } else {
        try out.print("engine boundary: {d} references in {d} files, none above the baseline.\n", .{ total, files.count() });
    }
}

// ============================================================================
// Tests - the rules
// ============================================================================

const testing = std.testing;

fn expectRefs(text: []const u8, expected: []const []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const refs = try references(arena.allocator(), text);
    var got: std.ArrayList(u8) = .empty;
    for (refs.items) |ref| {
        try got.print(arena.allocator(), "{d}:{s}\n", .{ ref.line, ref.name });
    }
    var want: std.ArrayList(u8) = .empty;
    for (expected) |e| try want.print(arena.allocator(), "{s}\n", .{e});
    try testing.expectEqualStrings(want.items, got.items);
}

test "the adapter, its tests and the WPT checkout are exempt; everything else is in scope" {
    try testing.expect(!inScope("src/runtime/engines/v8/interface.zig"));
    try testing.expect(!inScope("tests/v8/snapshot_stamp_test.zig"));
    try testing.expect(!inScope("tests/wpt/tools/x.zig"));
    try testing.expect(!inScope("tools/lint_engine_boundary.zig"));
    try testing.expect(inScope("src/webidl/impls/Worker.zig"));
    try testing.expect(inScope("src/runtime/engine_interface.zig"));
    try testing.expect(inScope("src/runtime/engines/jsc/binding.zig"));
    try testing.expect(inScope("tests/wpt_runner/main.zig"));
    try testing.expect(inScope("tools/snapshot_generator.zig"));
    try testing.expect(!inScope("src/runtime/engines/v8/v8_wrapper.cpp"));
}

test "imports that name V8 are counted, inline ones with the member they reach" {
    try expectRefs(
        \\const std = @import("std");
        \\const v8 = @import("v8");
        \\const chaining = @import("v8_promise_chaining");
        \\const realm = @import("realm_v8.zig");
        \\const scope = @import("v8").JsScope.init(ctx);
    , &.{
        "2:@import(\"v8\")",
        "3:@import(\"v8_promise_chaining\")",
        "4:@import(\"realm_v8.zig\")",
        "5:@import(\"v8\").JsScope",
    });
}

test "v8_ identifiers are counted once each, and members through an alias" {
    try expectRefs(
        \\const v8 = @import("v8");
        \\fn f() void {
        \\    const iso = v8.ffi.v8_Isolate_GetCurrent();
        \\    v8.context_manager.getWindowForContext(v8_ctx);
        \\}
    , &.{
        "1:@import(\"v8\")",
        "3:v8.ffi",
        "3:v8_Isolate_GetCurrent",
        "4:v8.context_manager",
        "4:v8_ctx",
    });
}

test "an alias of an alias keeps its full target, so V8 types are counted" {
    try expectRefs(
        \\const v8 = @import("v8");
        \\const ffi = v8.ffi;
        \\fn f(i: *ffi.Isolate) void { _ = i; }
    , &.{
        "1:@import(\"v8\")",
        "2:v8.ffi",
        "3:v8.ffi.Isolate",
    });
}

test "comments, strings and multiline string literals are not references" {
    try expectRefs(
        \\// v8.ffi.v8_Object_Get is how this used to work
        \\const msg = "call v8_Object_Get";
        \\const doc =
        \\    \\const v8 = @import("v8");
        \\;
        \\const v8_free = 1; // a v8_ name in code IS counted
    , &.{
        "6:v8_free",
    });
}

test "a name that merely contains v8, or a member named like an alias, is not counted" {
    try expectRefs(
        \\const engine = @import("engine");
        \\const x = engine.v8;
        \\const nv8_y = 2;
        \\const s = self.v8.ffi;
    , &.{});
}

test "a violation is any key above its baseline, including a key the baseline lacks" {
    var current: Counts = .empty;
    defer current.deinit(testing.allocator);
    var baseline: Counts = .empty;
    defer baseline.deinit(testing.allocator);

    try baseline.put(testing.allocator, "a.zig v8_Object_Get", 2);
    try baseline.put(testing.allocator, "a.zig v8_Value_Dispose", 1);
    // Same total as the baseline - one call swapped for another - which a
    // count alone could not see.
    try current.put(testing.allocator, "a.zig v8_Object_Get", 2);
    try current.put(testing.allocator, "a.zig v8_Object_Set", 1);
    // Paid down: fewer is always allowed.
    try baseline.put(testing.allocator, "b.zig v8.ffi", 3);
    try current.put(testing.allocator, "b.zig v8.ffi", 1);
    // Grown.
    try baseline.put(testing.allocator, "c.zig @import(\"v8\")", 1);
    try current.put(testing.allocator, "c.zig @import(\"v8\")", 2);

    var found = try violations(testing.allocator, &current, &baseline);
    defer found.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 2), found.items.len);
    try testing.expectEqualStrings("a.zig v8_Object_Set", found.items[0].key);
    try testing.expectEqual(@as(u32, 0), found.items[0].allowed);
    try testing.expectEqualStrings("c.zig @import(\"v8\")", found.items[1].key);
    try testing.expectEqual(@as(u32, 1), found.items[1].allowed);
}

test "the baseline round-trips, sorted, and ignores comments" {
    var counts: Counts = .empty;
    defer counts.deinit(testing.allocator);
    try counts.put(testing.allocator, "src/b.zig v8.ffi", 2);
    try counts.put(testing.allocator, "src/a.zig @import(\"v8\")", 1);

    const text = try formatBaseline(testing.allocator, &counts);
    defer testing.allocator.free(text);
    try testing.expect(std.mem.indexOf(u8, text, "src/a.zig @import(\"v8\") 1\nsrc/b.zig v8.ffi 2\n") != null);

    var parsed = try parseBaseline(testing.allocator, text);
    defer {
        var it = parsed.keyIterator();
        while (it.next()) |key| testing.allocator.free(key.*);
        parsed.deinit(testing.allocator);
    }
    try testing.expectEqual(@as(u32, 2), parsed.get("src/b.zig v8.ffi").?);
    try testing.expectEqual(@as(u32, 1), parsed.get("src/a.zig @import(\"v8\")").?);
    try testing.expectEqual(@as(u32, 2), parsed.count());
}
