//! The impls boundary, as a ratchet: `zig build lint-impls` (and so `zig build
//! test`) fails when any file references an impl it may not, more often than
//! tools/impls_boundary_baseline.txt records.
//!
//! AGENTS.md, "The impls boundary": impls are private. Another impl, and all
//! code outside src/webidl/, reaches a type through its interface
//! (src/webidl/interfaces/) - or, for a spec step with no IDL surface, through
//! a hook module in src/dom/ that the owning impl installs
//! (abort_algorithms.zig, range_boundaries.zig, node_document.zig,
//! traversal.zig, live_collections.zig).
//!
//! What is counted, per file and per `Impl.member`:
//!   * in an impl (src/webidl/impls/Name.zig): every reference through an
//!     alias of ANOTHER impl - `const NodeImpl = @import("Node.zig");` then
//!     `NodeImpl.getParent(...)`, `NodeImpl.InternalState` - and every inline
//!     `@import("Other.zig").member`. Lower-case files there are helper
//!     modules (same_object.zig, node_filter.zig), not impls. Inheritance
//!     chaining - a call to `ParentImpl.init`, `.deinit` or `.initWithState` -
//!     is how an impl builds its own parent state and is not counted.
//!   * everywhere else in src/ except the generated layers: every reference
//!     through the `impls` module.
//!
//! Keying on the member, not just a per-file total, is what catches a swap:
//! trading one reference for a new one leaves the total unchanged.
//!
//! The baseline only goes down. After paying debt down:
//!     zig build lint-impls -- --update
//! which refuses to record an increase.

const std = @import("std");

const baseline_path = "tools/impls_boundary_baseline.txt";
const impls_dir = "src/webidl/impls/";

/// Generated or unbuilt code: the layers that are MEANT to call impls.
const skipped_prefixes = [_][]const u8{
    "src/webidl/interfaces/",
    "src/webidl/mixins/",
    "src/webidl/namespaces/",
    "src/webidl/codegen/",
    "src/webidl/impls_tmp/",
};

/// One reference from a file into an impl: `Node.getParent`.
pub const Reference = struct {
    line: u32,
    impl: []const u8,
    member: []const u8,
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

const Decl = struct { name: []const u8, rhs: []const u8 };

/// `[pub] const name = rhs;`
fn constDecl(code: []const u8) ?Decl {
    var s = std.mem.trim(u8, code, " \t\r");
    if (std.mem.startsWith(u8, s, "pub ")) s = std.mem.trimStart(u8, s[4..], " ");
    if (!std.mem.startsWith(u8, s, "const ")) return null;
    s = std.mem.trimStart(u8, s[6..], " ");
    const name = identAt(s, 0);
    if (name.len == 0) return null;
    s = std.mem.trimStart(u8, s[name.len..], " ");
    if (s.len == 0 or s[0] != '=') return null;
    return .{ .name = name, .rhs = std.mem.trim(u8, s[1..], " \t;") };
}

/// `@import("X.zig")`, exactly: "X".
fn fileImport(rhs: []const u8) ?[]const u8 {
    const open = "@import(\"";
    const close = ".zig\")";
    if (!std.mem.startsWith(u8, rhs, open) or !std.mem.endsWith(u8, rhs, close)) return null;
    if (rhs.len < open.len + close.len + 1) return null;
    return rhs[open.len .. rhs.len - close.len];
}

/// `@import("impls").Name`, exactly: "Name".
fn implsMember(rhs: []const u8) ?[]const u8 {
    const prefix = "@import(\"impls\").";
    if (!std.mem.startsWith(u8, rhs, prefix)) return null;
    const name = identAt(rhs, prefix.len);
    if (name.len == 0 or prefix.len + name.len != rhs.len) return null;
    return name;
}

/// `module.Name`, exactly, where `module` is one of `modules`: "Name".
fn moduleMember(rhs: []const u8, modules: []const []const u8) ?[]const u8 {
    for (modules) |module| {
        if (rhs.len <= module.len + 1) continue;
        if (!std.mem.startsWith(u8, rhs, module) or rhs[module.len] != '.') continue;
        const name = identAt(rhs, module.len + 1);
        if (name.len != 0 and module.len + 1 + name.len == rhs.len and std.ascii.isUpper(name[0])) return name;
    }
    return null;
}

const Alias = struct { name: []const u8, impl: []const u8 };

/// Record every `needle.member` in `code` - `needle` on a whole identifier,
/// not preceded by `.` - as a reference to `impl`. A null `impl` means
/// `needle` is the impls module itself, so the first member names the impl
/// (`impls.Node.getParent`). References to the file's own types - itself and
/// its ancestors, `itself` - are not references into ANOTHER impl.
fn collect(
    gpa: std.mem.Allocator,
    out: *std.ArrayList(Reference),
    line: u32,
    code: []const u8,
    needle: []const u8,
    impl: ?[]const u8,
    itself: []const []const u8,
) !void {
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, code, pos, needle)) |at| {
        pos = at + needle.len;
        if (at > 0 and (isIdentChar(code[at - 1]) or code[at - 1] == '.')) continue;
        if (pos >= code.len or code[pos] != '.') continue;
        var target = impl;
        var member_start = pos + 1;
        if (target == null) {
            const name = identAt(code, member_start);
            if (name.len == 0 or !std.ascii.isUpper(name[0])) continue;
            target = name;
            member_start += name.len;
            if (member_start >= code.len or code[member_start] != '.') {
                if (!contains(itself, name)) try out.append(gpa, .{ .line = line, .impl = name, .member = "", .code = std.mem.trim(u8, code, " \t") });
                continue;
            }
            member_start += 1;
        }
        if (contains(itself, target.?)) continue;
        const member = identAt(code, member_start);
        try out.append(gpa, .{ .line = line, .impl = target.?, .member = member, .code = std.mem.trim(u8, code, " \t") });
    }
}

pub fn contains(items: []const []const u8, name: []const u8) bool {
    for (items) |item| {
        if (std.mem.eql(u8, item, name)) return true;
    }
    return false;
}

/// References an impl file (`own`.zig) makes into OTHER impls, counting only
/// `own` itself as its own - the command passes its ancestors too.
pub fn implReferences(gpa: std.mem.Allocator, own: []const u8, text: []const u8) !std.ArrayList(Reference) {
    return references(gpa, &.{own}, text);
}

/// References a file outside the impls makes through the `impls` module.
pub fn externalReferences(gpa: std.mem.Allocator, text: []const u8) !std.ArrayList(Reference) {
    return references(gpa, &.{}, text);
}

/// The one scanner. `itself` holds the types a file IS - an impl's own type
/// and its ancestors (see `Hierarchy.itselfTypes`); it is empty outside the
/// impls. Only an impl may name other impls by file (`@import("X.zig")`),
/// and a reference to any of `itself` is the file reaching its own state.
fn references(gpa: std.mem.Allocator, itself: []const []const u8, text: []const u8) !std.ArrayList(Reference) {
    var modules: std.ArrayList([]const u8) = .empty;
    defer modules.deinit(gpa);
    var aliases: std.ArrayList(Alias) = .empty;
    defer aliases.deinit(gpa);
    var declarations: std.ArrayList(u32) = .empty;
    defer declarations.deinit(gpa);

    // Pass 1: `const impls = @import("impls");`
    var lines = std.mem.splitScalar(u8, text, '\n');
    var number: u32 = 0;
    while (lines.next()) |raw| {
        number += 1;
        const decl = constDecl(codeOf(raw)) orelse continue;
        if (std.mem.eql(u8, decl.rhs, "@import(\"impls\")")) {
            try modules.append(gpa, decl.name);
            try declarations.append(gpa, number);
        }
    }
    // Pass 2: aliases - `const NodeImpl = @import("Node.zig");` (an impl
    // only), `= @import("impls").Node;`, `= impls.Node;`.
    lines = std.mem.splitScalar(u8, text, '\n');
    number = 0;
    while (lines.next()) |raw| {
        number += 1;
        const decl = constDecl(codeOf(raw)) orelse continue;
        const by_file = if (itself.len > 0) fileImport(decl.rhs) else null;
        const target = by_file orelse implsMember(decl.rhs) orelse moduleMember(decl.rhs, modules.items) orelse continue;
        try declarations.append(gpa, number);
        if (target.len == 0 or !std.ascii.isUpper(target[0])) continue;
        try aliases.append(gpa, .{ .name = decl.name, .impl = target });
    }

    var out: std.ArrayList(Reference) = .empty;
    errdefer out.deinit(gpa);
    lines = std.mem.splitScalar(u8, text, '\n');
    number = 0;
    while (lines.next()) |raw| {
        number += 1;
        if (std.mem.indexOfScalar(u32, declarations.items, number) != null) continue;
        const code = codeOf(raw);
        for (modules.items) |module| try collect(gpa, &out, number, code, module, null, itself);
        for (aliases.items) |alias| try collect(gpa, &out, number, code, alias.name, alias.impl, itself);
        try inlineImports(gpa, &out, number, code, itself);
    }
    return out;
}

/// `@import("Other.zig").member` (in an impl) and `@import("impls").Name.member`.
fn inlineImports(gpa: std.mem.Allocator, out: *std.ArrayList(Reference), line: u32, code: []const u8, itself: []const []const u8) !void {
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, code, pos, "@import(\"")) |at| {
        pos = at + "@import(\"".len;
        const close = std.mem.indexOfPos(u8, code, pos, "\")") orelse break;
        const imported = code[pos..close];
        const after = close + 2;
        pos = after;
        if (after >= code.len or code[after] != '.') continue;
        if (std.mem.eql(u8, imported, "impls")) {
            const name = identAt(code, after + 1);
            if (name.len == 0 or !std.ascii.isUpper(name[0]) or contains(itself, name)) continue;
            const member_start = after + 1 + name.len;
            const member = if (member_start < code.len and code[member_start] == '.') identAt(code, member_start + 1) else "";
            try out.append(gpa, .{ .line = line, .impl = name, .member = member, .code = std.mem.trim(u8, code, " \t") });
        } else if (itself.len > 0 and std.mem.endsWith(u8, imported, ".zig")) {
            const name = imported[0 .. imported.len - 4];
            if (name.len == 0 or !std.ascii.isUpper(name[0]) or contains(itself, name)) continue;
            try out.append(gpa, .{ .line = line, .impl = name, .member = identAt(code, after + 1), .code = std.mem.trim(u8, code, " \t") });
        }
    }
}

// ---------------------------------------------------------------------------
// The type hierarchy, read from the generated interfaces
// ---------------------------------------------------------------------------

/// What a generated interface's Meta says about its place in the hierarchy.
pub const Shape = struct {
    parent: ?[]const u8,
    /// The text between `MixinTypes = &.{` and its `}`: identifiers and commas.
    mixins: []const u8,
};

pub fn parseInterface(text: []const u8) Shape {
    var shape: Shape = .{ .parent = null, .mixins = "" };
    const parent_key = "pub const ParentInterface = ";
    if (std.mem.indexOf(u8, text, parent_key)) |at| {
        const name = identAt(text, at + parent_key.len);
        if (name.len > 0) shape.parent = name;
    }
    const mixin_key = "pub const MixinTypes = &.{";
    if (std.mem.indexOf(u8, text, mixin_key)) |at| {
        const start = at + mixin_key.len;
        if (std.mem.indexOfScalarPos(u8, text, start, '}')) |end| shape.mixins = text[start..end];
    }
    return shape;
}

/// Parents and mixin includers of every interface.
pub const Hierarchy = struct {
    parents: std.StringHashMapUnmanaged(?[]const u8) = .empty,
    includers: std.StringHashMapUnmanaged(std.ArrayList([]const u8)) = .empty,

    pub fn addInterface(self: *Hierarchy, gpa: std.mem.Allocator, name: []const u8, parent: ?[]const u8, mixins: []const u8) !void {
        try self.parents.put(gpa, name, parent);
        var parts = std.mem.tokenizeAny(u8, mixins, " \t\r\n,");
        while (parts.next()) |mixin| {
            const gop = try self.includers.getOrPut(gpa, mixin);
            if (!gop.found_existing) gop.value_ptr.* = .empty;
            try gop.value_ptr.append(gpa, name);
        }
    }

    pub fn deinit(self: *Hierarchy, gpa: std.mem.Allocator) void {
        var it = self.includers.valueIterator();
        while (it.next()) |list| list.deinit(gpa);
        self.includers.deinit(gpa);
        self.parents.deinit(gpa);
    }

    fn ancestorsOrSelf(self: *const Hierarchy, gpa: std.mem.Allocator, name: []const u8) !std.ArrayList([]const u8) {
        var out: std.ArrayList([]const u8) = .empty;
        errdefer out.deinit(gpa);
        var current: ?[]const u8 = name;
        var guard: usize = 0;
        while (current) |c| : (guard += 1) {
            if (guard > 64 or contains(out.items, c)) break;
            try out.append(gpa, c);
            current = self.parents.get(c) orelse null;
        }
        return out;
    }

    /// The types a file implementing `name` IS: itself and its ancestors. For
    /// a mixin, whose functions run on every interface that includes it, the
    /// ancestors ALL its includers share - ParentNode is included only by Node
    /// types, so Node is an ancestor of ParentNode's; Element is not.
    pub fn itselfTypes(self: *const Hierarchy, gpa: std.mem.Allocator, name: []const u8) !std.ArrayList([]const u8) {
        const includers = self.includers.get(name) orelse return self.ancestorsOrSelf(gpa, name);
        if (includers.items.len == 0) return self.ancestorsOrSelf(gpa, name);

        var shared = try self.ancestorsOrSelf(gpa, includers.items[0]);
        defer shared.deinit(gpa);
        for (includers.items[1..]) |includer| {
            var chain = try self.ancestorsOrSelf(gpa, includer);
            defer chain.deinit(gpa);
            var i: usize = 0;
            while (i < shared.items.len) {
                if (contains(chain.items, shared.items[i])) i += 1 else _ = shared.orderedRemove(i);
            }
        }
        var out: std.ArrayList([]const u8) = .empty;
        errdefer out.deinit(gpa);
        try out.append(gpa, name);
        // An includer itself is not something every includer IS.
        for (shared.items) |t| {
            if (!contains(out.items, t) and !contains(includers.items, t)) try out.append(gpa, t);
        }
        return out;
    }
};

// ---------------------------------------------------------------------------
// Hook modules in src/dom/
// ---------------------------------------------------------------------------

/// A hook module and the impls whose state it reaches.
pub const Hook = struct { module: []const u8, owners: []const []const u8 };

/// A hook module declares its owners on a `//! lint-impls: hook for A, B` line.
pub fn parseHookOwners(gpa: std.mem.Allocator, text: []const u8) !std.ArrayList([]const u8) {
    var out: std.ArrayList([]const u8) = .empty;
    errdefer out.deinit(gpa);
    const key = "//! lint-impls: hook for ";
    const at = std.mem.indexOf(u8, text, key) orelse return out;
    const end = std.mem.indexOfScalarPos(u8, text, at, '\n') orelse text.len;
    var names = std.mem.tokenizeAny(u8, text[at + key.len .. end], " \t\r,");
    while (names.next()) |name| try out.append(gpa, name);
    return out;
}

/// Uses of a hook by a file that is itself - or descends from - the hook's
/// owner. Such a file reaches that state through the owning impl, directly:
/// the hook exists for code OUTSIDE the owner's hierarchy. Installing the
/// implementation (`install*`) is the owner's own business and is allowed.
pub fn hookViolations(gpa: std.mem.Allocator, itself: []const []const u8, hooks: []const Hook, text: []const u8) !std.ArrayList(Reference) {
    var out: std.ArrayList(Reference) = .empty;
    errdefer out.deinit(gpa);
    for (hooks) |hook| {
        var owned = false;
        for (hook.owners) |owner| {
            if (contains(itself, owner)) owned = true;
        }
        if (!owned) continue;

        var dom_modules: std.ArrayList([]const u8) = .empty;
        defer dom_modules.deinit(gpa);
        var hook_aliases: std.ArrayList([]const u8) = .empty;
        defer hook_aliases.deinit(gpa);
        var declarations: std.ArrayList(u32) = .empty;
        defer declarations.deinit(gpa);

        var lines = std.mem.splitScalar(u8, text, '\n');
        var number: u32 = 0;
        while (lines.next()) |raw| {
            number += 1;
            const decl = constDecl(codeOf(raw)) orelse continue;
            if (std.mem.eql(u8, decl.rhs, "@import(\"dom\")")) {
                try dom_modules.append(gpa, decl.name);
                try declarations.append(gpa, number);
            }
        }
        lines = std.mem.splitScalar(u8, text, '\n');
        number = 0;
        while (lines.next()) |raw| {
            number += 1;
            const decl = constDecl(codeOf(raw)) orelse continue;
            const direct = std.mem.startsWith(u8, decl.rhs, "@import(\"dom\").") and std.mem.eql(u8, decl.rhs["@import(\"dom\").".len..], hook.module);
            var via_module = false;
            for (dom_modules.items) |m| {
                if (decl.rhs.len == m.len + 1 + hook.module.len and std.mem.startsWith(u8, decl.rhs, m) and decl.rhs[m.len] == '.' and std.mem.endsWith(u8, decl.rhs, hook.module)) via_module = true;
            }
            if (direct or via_module) {
                try hook_aliases.append(gpa, decl.name);
                try declarations.append(gpa, number);
            }
        }

        lines = std.mem.splitScalar(u8, text, '\n');
        number = 0;
        while (lines.next()) |raw| {
            number += 1;
            if (std.mem.indexOfScalar(u32, declarations.items, number) != null) continue;
            const code = codeOf(raw);
            for (hook_aliases.items) |alias| try collectHook(gpa, &out, number, code, alias, hook.module);
            for (dom_modules.items) |m| {
                const prefix = try std.fmt.allocPrint(gpa, "{s}.{s}", .{ m, hook.module });
                defer gpa.free(prefix);
                try collectHook(gpa, &out, number, code, prefix, hook.module);
            }
            const inline_prefix = try std.fmt.allocPrint(gpa, "@import(\"dom\").{s}", .{hook.module});
            defer gpa.free(inline_prefix);
            try collectHook(gpa, &out, number, code, inline_prefix, hook.module);
        }
    }
    return out;
}

fn collectHook(gpa: std.mem.Allocator, out: *std.ArrayList(Reference), line: u32, code: []const u8, needle: []const u8, module: []const u8) !void {
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, code, pos, needle)) |at| {
        pos = at + needle.len;
        if (at > 0 and (isIdentChar(code[at - 1]) or code[at - 1] == '.')) continue;
        if (pos >= code.len or code[pos] != '.') continue;
        const member = identAt(code, pos + 1);
        // Installing is the owner's business, and a TitleCase member is one
        // of the hook's types - the contract an owner implements - not a
        // function that reaches state.
        if (std.mem.startsWith(u8, member, "install")) continue;
        if (member.len > 0 and std.ascii.isUpper(member[0])) continue;
        try out.append(gpa, .{ .line = line, .impl = module, .member = member, .code = std.mem.trim(u8, code, " \t") });
    }
}

/// Counts per "path Impl.member" key.
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

/// Parse a baseline file: `path Impl.member count` per line, `#` comments.
/// Keys are allocated with `gpa` and owned by the map.
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

/// Format counts as a baseline file, keys sorted.
pub fn formatBaseline(gpa: std.mem.Allocator, counts: *const Counts) ![]u8 {
    var keys: std.ArrayList([]const u8) = .empty;
    defer keys.deinit(gpa);
    var it = counts.keyIterator();
    while (it.next()) |key| try keys.append(gpa, key.*);
    std.mem.sort([]const u8, keys.items, {}, lessThan);

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(gpa);
    try out.appendSlice(gpa,
        \\# References into impls from code that does not own them: path Impl.member count.
        \\# A ratchet - `zig build lint-impls`, part of `zig build test`, fails if any
        \\# count rises or a new pair appears. After paying debt down, lower it with
        \\# `zig build lint-impls -- --update`. Never raise it by hand.
        \\
    );
    for (keys.items) |key| {
        const line = try std.fmt.allocPrint(gpa, "{s} {d}\n", .{ key, counts.get(key).? });
        defer gpa.free(line);
        try out.appendSlice(gpa, line);
    }
    return out.toOwnedSlice(gpa);
}

// ============================================================================
// The command
// ============================================================================

fn implName(path: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, path, impls_dir)) return null;
    const rest = path[impls_dir.len..];
    if (std.mem.indexOfScalar(u8, rest, '/') != null) return null;
    if (rest.len < 5 or !std.ascii.isUpper(rest[0]) or !std.mem.endsWith(u8, rest, ".zig")) return null;
    return rest[0 .. rest.len - 4];
}

fn skipped(path: []const u8) bool {
    for (skipped_prefixes) |prefix| {
        if (std.mem.startsWith(u8, path, prefix)) return true;
    }
    return false;
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
            std.debug.print("usage: lint_impls_boundary [--update]\n", .{});
            std.process.exit(2);
        }
    }

    // The type hierarchy, from the generated interfaces.
    var hierarchy: Hierarchy = .{};
    {
        var dir = try std.Io.Dir.cwd().openDir(io, "src/webidl/interfaces", .{ .iterate = true });
        defer dir.close(io);
        var it = dir.iterate();
        while (try it.next(io)) |entry| {
            if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".zig")) continue;
            if (std.mem.eql(u8, entry.name, "root.zig")) continue;
            const name = try arena.dupe(u8, entry.name[0 .. entry.name.len - 4]);
            const path = try std.fmt.allocPrint(arena, "src/webidl/interfaces/{s}", .{entry.name});
            const text = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(16 << 20));
            const shape = parseInterface(text);
            try hierarchy.addInterface(arena, name, shape.parent, shape.mixins);
        }
    }

    // Hook modules and the impls whose state each reaches.
    var hooks: std.ArrayList(Hook) = .empty;
    {
        var dir = try std.Io.Dir.cwd().openDir(io, "src/dom", .{ .iterate = true });
        defer dir.close(io);
        var it = dir.iterate();
        while (try it.next(io)) |entry| {
            if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".zig")) continue;
            const path = try std.fmt.allocPrint(arena, "src/dom/{s}", .{entry.name});
            const text = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(16 << 20));
            const owners = try parseHookOwners(arena, text);
            if (owners.items.len == 0) continue;
            try hooks.append(arena, .{ .module = try arena.dupe(u8, entry.name[0 .. entry.name.len - 4]), .owners = owners.items });
        }
    }

    // Scan src/.
    var current: Counts = .empty;
    var sites = std.StringHashMapUnmanaged(std.ArrayList(Reference)).empty;
    var hook_misuse: std.ArrayList(struct { path: []const u8, ref: Reference }) = .empty;
    var src = try std.Io.Dir.cwd().openDir(io, "src", .{ .iterate = true });
    defer src.close(io);
    var walker = try src.walk(arena);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.path, ".zig")) continue;
        const path = try std.fmt.allocPrint(arena, "src/{s}", .{entry.path});
        if (skipped(path)) continue;
        const text = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(64 << 20));
        const refs = if (implName(path)) |own| blk: {
            const itself = try hierarchy.itselfTypes(arena, own);
            const misuse = try hookViolations(arena, itself.items, hooks.items, text);
            for (misuse.items) |ref| try hook_misuse.append(arena, .{ .path = path, .ref = ref });
            break :blk try references(arena, itself.items, text);
        } else if (std.mem.indexOf(u8, text, "impls") != null)
            try externalReferences(arena, text)
        else
            continue;
        for (refs.items) |ref| {
            const key = try std.fmt.allocPrint(arena, "{s} {s}.{s}", .{ path, ref.impl, ref.member });
            const gop = try current.getOrPut(arena, key);
            if (!gop.found_existing) gop.value_ptr.* = 0;
            gop.value_ptr.* += 1;
            const site = try sites.getOrPut(arena, key);
            if (!site.found_existing) site.value_ptr.* = .empty;
            try site.value_ptr.append(arena, ref);
        }
    }

    var total: usize = 0;
    var values = current.valueIterator();
    while (values.next()) |value| total += value.*;

    var buffer: [8192]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &buffer);
    const out = &stdout_writer.interface;

    // Strict, not a ratchet: a hook used from inside its owner's hierarchy.
    if (hook_misuse.items.len > 0) {
        try out.print("impls boundary: {d} use(s) of a hook from inside the hierarchy that owns its state.\n\n", .{hook_misuse.items.len});
        for (hook_misuse.items) |m| try out.print("  {s}:{d}: {s}.{s} - {s}\n", .{ m.path, m.ref.line, m.ref.impl, m.ref.member, m.ref.code });
        try out.print(
            \\
            \\A type reaches state its own ancestors own through their impls, directly
            \\(AGENTS.md "The impls boundary"). A src/dom/ hook is only for code OUTSIDE
            \\the owner's hierarchy; e.g. Text sets a node's document with
            \\NodeImpl.setOwnerDocument, DOMImplementation with node_document.set.
            \\
        , .{});
        try out.flush();
        std.process.exit(1);
    }

    const baseline_text: ?[]u8 = std.Io.Dir.cwd().readFileAlloc(io, baseline_path, arena, .limited(64 << 20)) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    if (baseline_text == null and update) {
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = baseline_path, .data = try formatBaseline(arena, &current) });
        try out.print("impls boundary: first baseline recorded - {d} references, {d} keys.\n", .{ total, current.count() });
        try out.flush();
        return;
    }
    if (baseline_text == null) {
        try out.print("impls boundary: no {s}; record one with `zig build lint-impls -- --update`.\n", .{baseline_path});
        try out.flush();
        std.process.exit(1);
    }
    const baseline = try parseBaseline(arena, baseline_text.?);

    const found = try violations(arena, &current, &baseline);
    if (found.items.len > 0) {
        try out.print("impls boundary: {d} reference(s) into impls above the baseline.\n\n", .{found.items.len});
        for (found.items) |v| {
            try out.print("  {s}: allowed {d}, found {d}\n", .{ v.key, v.allowed, v.found });
            if (sites.get(v.key)) |list| {
                const path_end = std.mem.indexOfScalar(u8, v.key, ' ') orelse v.key.len;
                for (list.items) |ref| try out.print("      {s}:{d}: {s}\n", .{ v.key[0..path_end], ref.line, ref.code });
            }
        }
        try out.print(
            \\
            \\Impls are private (AGENTS.md, "The impls boundary"). Reach another type
            \\through its interface - interfaces.X - or, for a spec step with no IDL
            \\surface, through a hook module in src/dom/ that its impl installs.
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
        try out.print("impls boundary: baseline lowered - {d} references, {d} keys.\n", .{ total, current.count() });
    } else if (lowered > 0) {
        try out.print("impls boundary: {d} key(s) paid down; record it with `zig build lint-impls -- --update`.\n", .{lowered});
    } else {
        try out.print("impls boundary: {d} references, none above the baseline.\n", .{total});
    }
    try out.flush();
}

// ============================================================================
// Tests - the rules
// ============================================================================

const testing = std.testing;

fn expectRefs(refs: []const Reference, expected: []const []const u8) !void {
    try testing.expectEqual(expected.len, refs.len);
    for (refs, expected) |ref, want| {
        var buf: [128]u8 = undefined;
        const got = try std.fmt.bufPrint(&buf, "{d}:{s}.{s}", .{ ref.line, ref.impl, ref.member });
        try testing.expectEqualStrings(want, got);
    }
}

test "an impl's references into another impl are counted, by impl and member" {
    const text =
        \\const std = @import("std");
        \\const NodeImpl = @import("Node.zig");
        \\const RangeImpl = @import("Range.zig");
        \\pub fn f(n: *runtime.Instance) void {
        \\    _ = NodeImpl.getParent(n);
        \\    const s: *RangeImpl.InternalState = undefined;
        \\    _ = s;
        \\}
    ;
    var refs = try implReferences(testing.allocator, "Document", text);
    defer refs.deinit(testing.allocator);
    try expectRefs(refs.items, &.{ "5:Node.getParent", "6:Range.InternalState" });
}

test "the file itself, lower-case helper modules and interfaces are not impls" {
    const text =
        \\const Self = @import("Document.zig");
        \\const same_object = @import("same_object.zig");
        \\const interfaces = @import("interfaces");
        \\fn f() void {
        \\    _ = Self.getInternal;
        \\    same_object.Pin.hold(x);
        \\    _ = interfaces.Node.get_parentNode(x);
        \\}
    ;
    var refs = try implReferences(testing.allocator, "Document", text);
    defer refs.deinit(testing.allocator);
    try expectRefs(refs.items, &.{});
}

test "an ancestor impl is the file's own: chaining and every other call to it are not counted" {
    const text =
        \\const NodeImpl = @import("Node.zig");
        \\const ElementImpl = @import("Element.zig");
        \\pub fn init(a: A) !*I {
        \\    const i = try NodeImpl.init(a, State, vtable, ctx);
        \\    errdefer NodeImpl.deinit(i);
        \\    _ = NodeImpl.getFirstChild(i);
        \\    return ElementImpl.init(a, State, vtable, ctx);
        \\}
    ;
    // Element is not an ancestor of Text: creating one through its impl is a
    // reference into another type, `init` or not.
    var refs = try references(testing.allocator, &.{ "Text", "CharacterData", "Node", "EventTarget" }, text);
    defer refs.deinit(testing.allocator);
    try expectRefs(refs.items, &.{"7:Element.init"});
}

test "comments do not count, and an alias is matched on a whole identifier" {
    const text =
        \\const NodeImpl = @import("Node.zig");
        \\// NodeImpl.getParent is what used to be called here
        \\fn f() void {
        \\    x(); // then NodeImpl.getFirstChild
        \\    _ = MyNodeImpl.getParent(n);
        \\    _ = foo.NodeImpl.bar;
        \\}
    ;
    var refs = try implReferences(testing.allocator, "Document", text);
    defer refs.deinit(testing.allocator);
    try expectRefs(refs.items, &.{});
}

test "an inline import of another impl is counted" {
    const text =
        \\fn f() void {
        \\    const t = @import("Node.zig").getNodeType(x);
        \\    _ = @import("impls").Range.call_detach(r);
        \\    _ = @import("Document.zig").own;
        \\}
    ;
    var refs = try implReferences(testing.allocator, "Document", text);
    defer refs.deinit(testing.allocator);
    try expectRefs(refs.items, &.{ "2:Node.getNodeType", "3:Range.call_detach" });
}

test "an impl reaching another through the impls module is counted, its own types are not" {
    const text =
        \\const impls = @import("impls");
        \\const RangeImpl = impls.Range;
        \\fn f() void {
        \\    _ = impls.Node.getParent(n);
        \\    _ = impls.Document.getInternal(d);
        \\    _ = RangeImpl.call_detach(r);
        \\    const x = try impls.Node.init(a, S, v, c);
        \\}
    ;
    var refs = try references(testing.allocator, &.{ "Document", "Node", "EventTarget" }, text);
    defer refs.deinit(testing.allocator);
    try expectRefs(refs.items, &.{"6:Range.call_detach"});
}

test "outside the impls, every use of the impls module is counted" {
    const text =
        \\const impls = @import("impls");
        \\const interfaces = @import("interfaces");
        \\fn f() void {
        \\    const NodeImpl = impls.Node;
        \\    _ = impls.Document.getInternal(d);
        \\    _ = NodeImpl.getOwnerDocument(n);
        \\    const T = NodeImpl.InternalState;
        \\    _ = interfaces.Node.get_ownerDocument(n);
        \\    _ = @import("impls").Element.getInternalState(e);
        \\}
    ;
    var refs = try externalReferences(testing.allocator, text);
    defer refs.deinit(testing.allocator);
    try expectRefs(refs.items, &.{
        "5:Document.getInternal",
        "6:Node.getOwnerDocument",
        "7:Node.InternalState",
        "9:Element.getInternalState",
    });
}

test "a violation is any key above its baseline, including a key the baseline lacks" {
    var current: Counts = .empty;
    defer current.deinit(testing.allocator);
    var baseline: Counts = .empty;
    defer baseline.deinit(testing.allocator);

    try baseline.put(testing.allocator, "a.zig Node.getParent", 2);
    try baseline.put(testing.allocator, "a.zig Node.InternalState", 1);
    // Same total as the baseline - one InternalState swapped for getNodeType -
    // which a count alone could not see.
    try current.put(testing.allocator, "a.zig Node.getParent", 2);
    try current.put(testing.allocator, "a.zig Node.getNodeType", 1);
    // Paid down: fewer is always allowed.
    try baseline.put(testing.allocator, "b.zig Range.call_x", 3);
    try current.put(testing.allocator, "b.zig Range.call_x", 1);
    // Grown.
    try baseline.put(testing.allocator, "c.zig Node.getFirstChild", 1);
    try current.put(testing.allocator, "c.zig Node.getFirstChild", 2);

    var found = try violations(testing.allocator, &current, &baseline);
    defer found.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 2), found.items.len);
    try testing.expectEqualStrings("a.zig Node.getNodeType", found.items[0].key);
    try testing.expectEqual(@as(u32, 0), found.items[0].allowed);
    try testing.expectEqualStrings("c.zig Node.getFirstChild", found.items[1].key);
    try testing.expectEqual(@as(u32, 1), found.items[1].allowed);
    try testing.expectEqual(@as(u32, 2), found.items[1].found);
}

test "the baseline round-trips, sorted, and ignores comments" {
    var counts: Counts = .empty;
    defer counts.deinit(testing.allocator);
    try counts.put(testing.allocator, "src/b.zig Node.x", 2);
    try counts.put(testing.allocator, "src/a.zig Range.y", 1);

    const text = try formatBaseline(testing.allocator, &counts);
    defer testing.allocator.free(text);
    try testing.expect(std.mem.indexOf(u8, text, "src/a.zig Range.y 1\nsrc/b.zig Node.x 2\n") != null);

    var parsed = try parseBaseline(testing.allocator, text);
    defer {
        var it = parsed.keyIterator();
        while (it.next()) |key| testing.allocator.free(key.*);
        parsed.deinit(testing.allocator);
    }
    try testing.expectEqual(@as(u32, 2), parsed.get("src/b.zig Node.x").?);
    try testing.expectEqual(@as(u32, 1), parsed.get("src/a.zig Range.y").?);
    try testing.expectEqual(@as(u32, 2), parsed.count());
}

// ---------------------------------------------------------------------------
// Rule A - the inheritance chain (AGENTS.md "The impls boundary")
// ---------------------------------------------------------------------------

test "an interface's parent and mixins are read from its generated Meta" {
    const text =
        \\    pub const Meta = struct {
        \\        pub const BaseType = CharacterData.State;
        \\        pub const ParentInterface = CharacterData;
        \\        pub const MixinTypes = &.{
        \\            Slottable,
        \\            GeometryUtils,
        \\        };
        \\    };
    ;
    const shape = parseInterface(text);
    try testing.expectEqualStrings("CharacterData", shape.parent.?);
    try testing.expectEqualStrings("\n            Slottable,\n            GeometryUtils,\n        ", shape.mixins);

    const bare = parseInterface("        pub const BaseType = null;\n        pub const MixinTypes = &.{};\n");
    try testing.expect(bare.parent == null);
    try testing.expectEqual(@as(usize, 0), std.mem.trim(u8, bare.mixins, " \n").len);
}

fn testHierarchy() !Hierarchy {
    var h: Hierarchy = .{};
    try h.addInterface(testing.allocator, "EventTarget", null, "");
    try h.addInterface(testing.allocator, "Node", "EventTarget", "");
    try h.addInterface(testing.allocator, "CharacterData", "Node", "");
    try h.addInterface(testing.allocator, "Text", "CharacterData", "Slottable,");
    try h.addInterface(testing.allocator, "Document", "Node", "ParentNode, NonElementParentNode,");
    try h.addInterface(testing.allocator, "Element", "Node", "ParentNode,");
    try h.addInterface(testing.allocator, "Window", "EventTarget", "WindowOrWorkerGlobalScope,");
    try h.addInterface(testing.allocator, "WorkerGlobalScope", "EventTarget", "WindowOrWorkerGlobalScope,");
    try h.addInterface(testing.allocator, "AbstractRange", null, "");
    try h.addInterface(testing.allocator, "Range", "AbstractRange", "");
    try h.addInterface(testing.allocator, "DOMImplementation", null, "");
    return h;
}

test "a type is itself and its ancestors; a mixin is the ancestors every includer shares" {
    var h = try testHierarchy();
    defer h.deinit(testing.allocator);

    var text = try h.itselfTypes(testing.allocator, "Text");
    defer text.deinit(testing.allocator);
    try testing.expect(contains(text.items, "Text"));
    try testing.expect(contains(text.items, "CharacterData"));
    try testing.expect(contains(text.items, "Node"));
    try testing.expect(contains(text.items, "EventTarget"));
    try testing.expect(!contains(text.items, "Document"));

    var parent_node = try h.itselfTypes(testing.allocator, "ParentNode");
    defer parent_node.deinit(testing.allocator);
    try testing.expect(contains(parent_node.items, "ParentNode"));
    try testing.expect(contains(parent_node.items, "Node"));
    try testing.expect(!contains(parent_node.items, "Document"));
    try testing.expect(!contains(parent_node.items, "Element"));

    var shared = try h.itselfTypes(testing.allocator, "WindowOrWorkerGlobalScope");
    defer shared.deinit(testing.allocator);
    try testing.expect(contains(shared.items, "EventTarget"));
    try testing.expect(!contains(shared.items, "Window"));
}

test "references to the file's own ancestors are not counted; other types are" {
    const text =
        \\const NodeImpl = @import("Node.zig");
        \\const RangeImpl = @import("Range.zig");
        \\fn f() void {
        \\    _ = NodeImpl.getOwnerDocument(i);
        \\    _ = RangeImpl.call_detach(r);
        \\}
    ;
    var refs = try references(testing.allocator, &.{ "Text", "CharacterData", "Node", "EventTarget" }, text);
    defer refs.deinit(testing.allocator);
    try expectRefs(refs.items, &.{"5:Range.call_detach"});
}

test "a hook's owner is declared in its module" {
    var owners = try parseHookOwners(testing.allocator, "//! DOM stuff\n//! lint-impls: hook for Range, StaticRange\nconst std = 1;\n");
    defer owners.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 2), owners.items.len);
    try testing.expectEqualStrings("Range", owners.items[0]);
    try testing.expectEqualStrings("StaticRange", owners.items[1]);

    var none = try parseHookOwners(testing.allocator, "//! not a hook\n");
    defer none.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 0), none.items.len);
}

test "a hook used from inside its owner's hierarchy is a violation; outside, installing, and dispatch down are not" {
    const hooks = [_]Hook{
        .{ .module = "node_document", .owners = &.{"Node"} },
        .{ .module = "range_boundaries", .owners = &.{ "Range", "StaticRange" } },
    };
    const text_zig =
        \\const node_document = @import("dom").node_document;
        \\fn split() void {
        \\    try node_document.set(new_node, doc);
        \\}
    ;
    var v1 = try hookViolations(testing.allocator, &.{ "Text", "CharacterData", "Node", "EventTarget" }, &hooks, text_zig);
    defer v1.deinit(testing.allocator);
    try expectRefs(v1.items, &.{"3:node_document.set"});

    // DOMImplementation is not a Node: outside the hierarchy, the hook is its route.
    var v2 = try hookViolations(testing.allocator, &.{"DOMImplementation"}, &hooks, text_zig);
    defer v2.deinit(testing.allocator);
    try expectRefs(v2.items, &.{});

    // The owner installs its implementation.
    const node_zig =
        \\const dom_module = @import("dom");
        \\fn init() void {
        \\    dom_module.node_document.install(.{ .set = &hook });
        \\}
    ;
    var v3 = try hookViolations(testing.allocator, &.{ "Node", "EventTarget" }, &hooks, node_zig);
    defer v3.deinit(testing.allocator);
    try expectRefs(v3.items, &.{});

    // AbstractRange is Range's ANCESTOR: reading a subclass's state through
    // the hook is dispatch downward, which an ancestor cannot do otherwise.
    const abstract_zig =
        \\const range_boundaries = @import("dom").range_boundaries;
        \\fn get() void {
        \\    _ = range_boundaries.of(instance);
        \\}
    ;
    var v4 = try hookViolations(testing.allocator, &.{"AbstractRange"}, &hooks, abstract_zig);
    defer v4.deinit(testing.allocator);
    try expectRefs(v4.items, &.{});

    // Range reaching its own state through its own hook is not.
    var v5 = try hookViolations(testing.allocator, &.{ "Range", "AbstractRange" }, &hooks, abstract_zig);
    defer v5.deinit(testing.allocator);
    try expectRefs(v5.items, &.{"3:range_boundaries.of"});
}

test "an owner naming its hook's types implements the contract - not a use" {
    const hooks = [_]Hook{.{ .module = "node_document", .owners = &.{"Node"} }};
    const text =
        \\const dom_module = @import("dom");
        \\fn hook(node: *I, document: ?*I) dom_module.node_document.Error!void {
        \\    return setOwnerDocument(node, document);
        \\}
        \\fn init() void {
        \\    dom_module.node_document.install(.{ .set = &hook });
        \\    _ = dom_module.node_document.set(node, document);
        \\}
    ;
    var v = try hookViolations(testing.allocator, &.{ "Node", "EventTarget" }, &hooks, text);
    defer v.deinit(testing.allocator);
    try expectRefs(v.items, &.{"7:node_document.set"});
}
