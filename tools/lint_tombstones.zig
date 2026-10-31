//! Long-lived std hash maps whose keys come and go, as a ratchet: `zig build
//! lint-tombstones` (and so `zig build test`) fails when src/ holds such a map
//! with no TombstoneGuard that tools/tombstones_baseline.txt does not record.
//!
//! std.HashMap deletes by tombstone and never counts a tombstone against its
//! load (lib/std/hash_map.zig `removeByIndex`, `growIfNeeded`), so a map whose
//! puts and removes balance never grows, and growing is the only thing that
//! clears tombstones. Its free slots run out; then every insert of a new key
//! and every lookup that misses probes most or all of the table. Found and
//! fixed three times - the InstanceRegistry and its siblings (big5-decode
//! 2.2 s -> 46 s by the thirteenth page), the V8 wrapper cache (gc_bench's
//! teardown at two speeds), the timer maps (lane hashmaps1) - and each time
//! the fix was the same: `infra.tombstones.TombstoneGuard`
//! (src/infra/tombstones.zig), `noteRemoval` after every removal and
//! `beforeInsert` before every insert of a possibly new key.
//!
//! What is flagged, in src/**/*.zig through std.zig.Ast and its tokens:
//!   * A map: a container field, or a container-level `var` (threadlocal or
//!     not), whose type is a std hash map that deletes by tombstone -
//!     `std.HashMap`, `std.AutoHashMap`, `std.StringHashMap` and their
//!     `Unmanaged` forms, optional or not, or a container-level `const` of
//!     the file naming one of them. `std.ArrayHashMap` and friends are not:
//!     they delete by swapping or shifting, with no tombstone. A local `var`
//!     in a function is not long-lived and is not looked at; nor is anything
//!     inside a `test` declaration.
//!   * ...that the same file removes from: a call of `remove`, `fetchRemove`,
//!     `removeByPtr` (or their `Adapted` / `Context` forms) on it. "On it"
//!     means the receiver's last name is the map's (`self.timers.remove`,
//!     `table.map.fetchRemove`, `timer_contexts.?.remove`), or the receiver
//!     is a local bound to it in that function: a `const`/`var` whose
//!     initialiser names the map or calls a function of the file that
//!     returns it (`const map = &self.map;`, `const map = ensure(x);`), or a
//!     capture of an `if`/`while` whose condition names it
//!     (`if (timer_contexts) |*map|`). A map removed from only in another
//!     file is not seen.
//!   * ...and that has no guard: the file does not pass it (by name or such
//!     a local) to both a `.noteRemoval(...)` and a `.beforeInsert(...)`.
//!
//! Exempt: a map whose declaration has a `// tombstones: <why>` line in the
//! comment block directly above it - a map cleared at a natural boundary,
//! bounded, or short-lived. Say which and why.
//!
//! Key: `path Qualified.name` - the name qualified by its enclosing containers
//! and functions (`NativeTimerManager.timers`, `Reactions.pending`). The
//! baseline only goes down. After guarding or exempting maps:
//!     zig build lint-tombstones -- --update
//! which refuses to record an increase. `-- --list` prints every unguarded
//! map with its line.
//!
//! A map whose declaring type moved to another file, unchanged - a state type
//! moved out of an impl into src/dom, with the steps that remove from it - is
//! the same debt under a new path, not a new map:
//!     zig build lint-tombstones -- --move '<old key>' '<new key>'
//! records it (and updates the baseline as --update does) only when the old
//! key has left the scan, the new key is not in the baseline, both keys name
//! the same qualified map, and the counts are equal (`checkMove`).

const std = @import("std");
const Ast = std.zig.Ast;

const baseline_path = "tools/tombstones_baseline.txt";

/// The tree held to the rule.
const scanned_root = "src";

/// Not built: codegen's stubs for hand merging.
const exempt_prefixes = [_][]const u8{"src/webidl/impls_tmp/"};

pub fn isScanned(path: []const u8) bool {
    if (!std.mem.endsWith(u8, path, ".zig")) return false;
    if (!std.mem.startsWith(u8, path, scanned_root ++ "/")) return false;
    if (std.mem.indexOf(u8, path, ".zig-cache/") != null) return false;
    for (exempt_prefixes) |prefix| if (std.mem.startsWith(u8, path, prefix)) return false;
    return true;
}

/// One map the rule flags.
pub const Finding = struct {
    line: u32,
    /// Qualified by its enclosing containers and functions; owned by the
    /// caller's allocator.
    name: []const u8,
};

/// The std hash maps that delete by tombstone, after `std.` or
/// `std.hash_map.`. The ArrayHashMaps delete by swap or shift and are not here.
const tombstoning_types = [_][]const u8{
    "HashMap(",              "HashMapUnmanaged(", "AutoHashMap(",
    "AutoHashMapUnmanaged(", "StringHashMap(",    "StringHashMapUnmanaged(",
};

/// Whether `text` (a type expression with its whitespace removed) is one of
/// `tombstoning_types`, optional or not. A pointer to a map is not the map.
pub fn isTombstoningType(text: []const u8) bool {
    var t = text;
    while (t.len > 0 and t[0] == '?') t = t[1..];
    for ([_][]const u8{ "std.hash_map.", "std." }) |prefix| {
        if (!std.mem.startsWith(u8, t, prefix)) continue;
        const rest = t[prefix.len..];
        for (tombstoning_types) |name| if (std.mem.startsWith(u8, rest, name)) return true;
    }
    return false;
}

/// The method names that remove an entry and leave a tombstone.
const remove_methods = [_][]const u8{
    "remove",             "fetchRemove",        "removeByPtr",
    "removeAdapted",      "fetchRemoveAdapted", "removeContext",
    "fetchRemoveContext",
};

fn isRemoveMethod(name: []const u8) bool {
    for (remove_methods) |m| if (std.mem.eql(u8, m, name)) return true;
    return false;
}

const exempt_marker = "// tombstones:";

/// The why of a `// tombstones: <why>` line in the comment block directly
/// above `line` (1-based), if there is one with a why.
pub fn exemptWhy(source: []const u8, line: u32) ?[]const u8 {
    // The start of `line`.
    var line_start: usize = 0;
    var current: u32 = 1;
    while (current < line) : (current += 1) {
        const nl = std.mem.indexOfScalarPos(u8, source, line_start, '\n') orelse return null;
        line_start = nl + 1;
    }
    // Walk upwards over the comment lines directly above.
    var end = line_start;
    while (end > 0) {
        const prev_end = end - 1; // the '\n' ending the previous line
        const prev_start = if (std.mem.lastIndexOfScalar(u8, source[0..prev_end], '\n')) |i| i + 1 else 0;
        const text = std.mem.trim(u8, source[prev_start..prev_end], " \t\r");
        if (!std.mem.startsWith(u8, text, "//")) return null;
        if (std.mem.startsWith(u8, text, exempt_marker)) {
            const why = std.mem.trim(u8, text[exempt_marker.len..], " \t");
            if (why.len > 0) return why;
        }
        end = prev_start;
    }
    return null;
}

const Named = struct { first: u32, last: u32, name: []const u8 };

fn nodeTextCompact(gpa: std.mem.Allocator, tree: *const Ast, node: Ast.Node.OptionalIndex) ![]u8 {
    const n = node.unwrap() orelse return gpa.alloc(u8, 0);
    const start = tree.tokenStart(tree.firstToken(n));
    const last = tree.lastToken(n);
    const end = tree.tokenStart(last) + tree.tokenSlice(last).len;
    var out: std.ArrayList(u8) = .empty;
    for (tree.source[start..end]) |c| if (!std.ascii.isWhitespace(c)) try out.append(gpa, c);
    return out.toOwnedSlice(gpa);
}

fn inRanges(ranges: []const [2]u32, token: u32) bool {
    for (ranges) |r| if (token >= r[0] and token <= r[1]) return true;
    return false;
}

/// `name` prefixed by every named range strictly enclosing [first, last],
/// outermost first.
fn qualify(gpa: std.mem.Allocator, named: []const Named, first: u32, last: u32, name: []const u8) ![]u8 {
    var enclosing: std.ArrayList(Named) = .empty;
    defer enclosing.deinit(gpa);
    for (named) |range| {
        if (range.first <= first and range.last >= last and !(range.first == first and range.last == last)) {
            try enclosing.append(gpa, range);
        }
    }
    std.mem.sort(Named, enclosing.items, {}, namedOuterFirst);
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(gpa);
    for (enclosing.items) |range| {
        try out.appendSlice(gpa, range.name);
        try out.append(gpa, '.');
    }
    try out.appendSlice(gpa, name);
    return out.toOwnedSlice(gpa);
}

fn namedOuterFirst(_: void, a: Named, b: Named) bool {
    if (a.first != b.first) return a.first < b.first;
    return a.last > b.last;
}

/// A set of map names (borrowed from the source).
const NameSet = std.StringHashMapUnmanaged(void);

/// A declared map.
const MapDecl = struct { name: []const u8, qualified: []const u8, line: u32 };

/// The token scan of one function's own tokens (nested functions and tests
/// left out): which map names each local is bound to.
const Scope = struct {
    tree: *const Ast,
    tokens: []const u32,
    maps: *const NameSet,
    returning: *const std.StringHashMapUnmanaged(NameSet),
    aliases: std.StringHashMapUnmanaged(NameSet) = .empty,

    /// The map names the tokens [from, to) of `tokens` refer to: a map's
    /// name, a local bound to maps, a call of a function returning maps.
    fn refs(self: *const Scope, gpa: std.mem.Allocator, from: usize, to: usize, out: *NameSet) !void {
        var k = from;
        while (k < to) : (k += 1) {
            const tok = self.tokens[k];
            if (self.tree.tokenTag(tok) != .identifier) continue;
            const name = self.tree.tokenSlice(tok);
            if (self.maps.contains(name)) try out.put(gpa, name, {});
            if (self.aliases.get(name)) |set| {
                var it = set.keyIterator();
                while (it.next()) |n| try out.put(gpa, n.*, {});
            }
            if (k + 1 < to and self.tree.tokenTag(self.tokens[k + 1]) == .l_paren) {
                if (self.returning.get(name)) |set| {
                    var it = set.keyIterator();
                    while (it.next()) |n| try out.put(gpa, n.*, {});
                }
            }
        }
    }

    fn tag(self: *const Scope, k: usize) std.zig.Token.Tag {
        return self.tree.tokenTag(self.tokens[k]);
    }

    /// The index past the end of the expression starting at `from`: the `;`
    /// (or `,`, or closing bracket) at depth 0.
    fn exprEnd(self: *const Scope, from: usize) usize {
        var depth: usize = 0;
        var k = from;
        while (k < self.tokens.len) : (k += 1) {
            switch (self.tag(k)) {
                .l_paren, .l_bracket, .l_brace => depth += 1,
                .r_paren, .r_bracket, .r_brace => {
                    if (depth == 0) return k;
                    depth -= 1;
                },
                .semicolon, .comma => if (depth == 0) return k,
                else => {},
            }
        }
        return k;
    }

    /// The index of the bracket matching the opening one at `open`.
    fn matching(self: *const Scope, open: usize) usize {
        var depth: usize = 0;
        var k = open;
        while (k < self.tokens.len) : (k += 1) {
            switch (self.tag(k)) {
                .l_paren, .l_bracket, .l_brace => depth += 1,
                .r_paren, .r_bracket, .r_brace => {
                    depth -= 1;
                    if (depth == 0) return k;
                },
                else => {},
            }
        }
        return k;
    }

    /// The index of the bracket matching the closing one at `close`.
    fn matchingBack(self: *const Scope, close: usize) ?usize {
        var depth: usize = 0;
        var k = close + 1;
        while (k > 0) {
            k -= 1;
            switch (self.tag(k)) {
                .r_paren, .r_bracket, .r_brace => depth += 1,
                .l_paren, .l_bracket, .l_brace => {
                    depth -= 1;
                    if (depth == 0) return k;
                },
                else => {},
            }
        }
        return null;
    }

    /// Bind locals: `const|var a = <expr naming a map>;` and the capture of
    /// an `if`/`while` whose condition names one.
    fn bind(self: *Scope, gpa: std.mem.Allocator) !void {
        var k: usize = 0;
        while (k < self.tokens.len) : (k += 1) {
            switch (self.tag(k)) {
                .keyword_const, .keyword_var => {
                    if (k + 1 >= self.tokens.len or self.tag(k + 1) != .identifier) continue;
                    var e = k + 2;
                    // Past a type annotation to the `=`.
                    while (e < self.tokens.len and self.tag(e) != .equal and self.tag(e) != .semicolon) : (e += 1) {}
                    if (e >= self.tokens.len or self.tag(e) != .equal) continue;
                    var set: NameSet = .empty;
                    try self.refs(gpa, e + 1, self.exprEnd(e + 1), &set);
                    if (set.count() > 0) try self.aliases.put(gpa, self.tree.tokenSlice(self.tokens[k + 1]), set);
                },
                .keyword_if, .keyword_while => {
                    if (k + 1 >= self.tokens.len or self.tag(k + 1) != .l_paren) continue;
                    const close = self.matching(k + 1);
                    var c = close + 1;
                    if (c >= self.tokens.len or self.tag(c) != .pipe) continue;
                    c += 1;
                    if (c < self.tokens.len and self.tag(c) == .asterisk) c += 1;
                    if (c >= self.tokens.len or self.tag(c) != .identifier) continue;
                    var set: NameSet = .empty;
                    try self.refs(gpa, k + 2, close, &set);
                    if (set.count() > 0) try self.aliases.put(gpa, self.tree.tokenSlice(self.tokens[c]), set);
                },
                else => {},
            }
        }
    }

    /// The maps the `return` expressions name.
    fn returned(self: *const Scope, gpa: std.mem.Allocator, out: *NameSet) !void {
        for (0..self.tokens.len) |k| {
            if (self.tag(k) != .keyword_return) continue;
            try self.refs(gpa, k + 1, self.exprEnd(k + 1), out);
        }
    }

    /// The maps a call of a remove method, and a `.noteRemoval(...)` and a
    /// `.beforeInsert(...)`, are made on.
    fn calls(self: *const Scope, gpa: std.mem.Allocator, removed: *NameSet, noted: *NameSet, inserted: *NameSet) !void {
        for (0..self.tokens.len) |k| {
            if (self.tag(k) != .identifier) continue;
            if (k < 1 or self.tag(k - 1) != .period) continue;
            if (k + 1 >= self.tokens.len or self.tag(k + 1) != .l_paren) continue;
            const method = self.tree.tokenSlice(self.tokens[k]);
            if (std.mem.eql(u8, method, "noteRemoval") or std.mem.eql(u8, method, "beforeInsert")) {
                const out = if (method[0] == 'n') noted else inserted;
                try self.refs(gpa, k + 2, self.matching(k + 1), out);
                continue;
            }
            if (!isRemoveMethod(method)) continue;
            if (k < 2) continue;
            var r = k - 2;
            // Past `.?` and `.*`.
            while (r > 0) {
                if (self.tag(r) == .question_mark and self.tag(r - 1) == .period) {
                    r -|= 2;
                } else if (self.tag(r) == .period_asterisk) {
                    r -= 1;
                } else break;
            }
            switch (self.tag(r)) {
                .identifier => {
                    const name = self.tree.tokenSlice(self.tokens[r]);
                    if (self.maps.contains(name)) {
                        try removed.put(gpa, name, {});
                    } else if (r == 0 or self.tag(r - 1) != .period) {
                        // A bare local bound to maps.
                        if (self.aliases.get(name)) |set| {
                            var it = set.keyIterator();
                            while (it.next()) |n| try removed.put(gpa, n.*, {});
                        }
                    }
                },
                .r_paren => {
                    const open = self.matchingBack(r) orelse continue;
                    if (open > 0 and self.tag(open - 1) == .identifier) {
                        // A call: what the function returns.
                        const callee = self.tree.tokenSlice(self.tokens[open - 1]);
                        if (self.returning.get(callee)) |set| {
                            var it = set.keyIterator();
                            while (it.next()) |n| try removed.put(gpa, n.*, {});
                        }
                    } else {
                        try self.refs(gpa, open + 1, r, removed);
                    }
                },
                else => {},
            }
        }
    }
};

/// Every unguarded, unexempt map `source` removes from, in source order.
/// Names are allocated with `gpa`. A file that does not parse is an error: a
/// file the ratchet cannot read must not pass silently.
pub fn findings(gpa: std.mem.Allocator, source: [:0]const u8) !std.ArrayList(Finding) {
    var tree = try Ast.parse(gpa, source, .{ .mode = .zig });
    defer tree.deinit(gpa);
    if (tree.errors.len > 0) return error.ParseError;

    var arena_state = std.heap.ArenaAllocator.init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var named: std.ArrayList(Named) = .empty;
    var tests: std.ArrayList([2]u32) = .empty;
    var fns: std.ArrayList([2]u32) = .empty;
    var fn_names: std.ArrayList([]const u8) = .empty;
    // Container-level `const X = <map type>`: names of map types.
    var type_aliases: NameSet = .empty;

    // 1. The ranges that qualify a name, tests, functions, type aliases.
    const node_count = tree.nodes.len;
    var i: u32 = 0;
    while (i < node_count) : (i += 1) {
        const node: Ast.Node.Index = @enumFromInt(i);
        switch (tree.nodeTag(node)) {
            .test_decl => try tests.append(arena, .{ tree.firstToken(node), tree.lastToken(node) }),
            .fn_decl => {
                const fn_token = tree.nodeMainToken(node);
                const name: []const u8 = if (tree.tokenTag(fn_token + 1) == .identifier) tree.tokenSlice(fn_token + 1) else "";
                if (name.len > 0) try named.append(arena, .{ .first = tree.firstToken(node), .last = tree.lastToken(node), .name = name });
                try fns.append(arena, .{ tree.firstToken(node), tree.lastToken(node) });
                try fn_names.append(arena, name);
            },
            else => if (tree.fullVarDecl(node)) |vd| {
                if (vd.ast.init_node == .none) continue;
                const name = tree.tokenSlice(vd.ast.mut_token + 1);
                try named.append(arena, .{ .first = tree.firstToken(node), .last = tree.lastToken(node), .name = name });
                if (std.mem.eql(u8, tree.tokenSlice(vd.ast.mut_token), "const") and vd.ast.type_node == .none) {
                    const text = try nodeTextCompact(arena, &tree, vd.ast.init_node);
                    if (isTombstoningType(text)) try type_aliases.put(arena, name, {});
                }
            },
        }
    }

    // 2. The maps: container fields and container-level vars.
    var decls: std.ArrayList(MapDecl) = .empty;
    var map_names: NameSet = .empty;
    i = 0;
    while (i < node_count) : (i += 1) {
        const node: Ast.Node.Index = @enumFromInt(i);
        var buf: [2]Ast.Node.Index = undefined;
        const container = tree.fullContainerDecl(&buf, node) orelse if (i == 0) Ast.full.ContainerDecl{
            .layout_token = null,
            .ast = .{ .main_token = 0, .enum_token = null, .members = tree.rootDecls(), .arg = .none },
        } else continue;
        for (container.ast.members) |member| {
            const first = tree.firstToken(member);
            if (inRanges(tests.items, first)) continue;
            var name_token: Ast.TokenIndex = undefined;
            var type_node: Ast.Node.OptionalIndex = .none;
            if (tree.fullContainerField(member)) |field| {
                name_token = field.ast.main_token;
                type_node = field.ast.type_expr;
            } else if (tree.fullVarDecl(member)) |vd| {
                if (!std.mem.eql(u8, tree.tokenSlice(vd.ast.mut_token), "var")) continue;
                name_token = vd.ast.mut_token + 1;
                type_node = vd.ast.type_node;
            } else continue;
            const text = try nodeTextCompact(arena, &tree, type_node);
            var bare = text;
            while (bare.len > 0 and bare[0] == '?') bare = bare[1..];
            if (!isTombstoningType(text) and !type_aliases.contains(bare)) continue;
            const name = tree.tokenSlice(name_token);
            const line: u32 = @intCast(tree.tokenLocation(0, name_token).line + 1);
            if (exemptWhy(source, line) != null) {
                // Exempt maps are still names a removal could be attributed
                // to; they are just not reported.
                try map_names.put(arena, name, {});
                continue;
            }
            try map_names.put(arena, name, {});
            try decls.append(arena, .{
                .name = name,
                .qualified = try qualify(arena, named.items, first, tree.lastToken(member), name),
                .line = line,
            });
        }
    }

    var out: std.ArrayList(Finding) = .empty;
    errdefer {
        for (out.items) |f| gpa.free(f.name);
        out.deinit(gpa);
    }
    if (decls.items.len == 0) return out;

    // 3. Each function's own tokens: its range, minus nested functions and
    // tests.
    var own: std.ArrayList([]const u32) = .empty;
    for (fns.items) |range| {
        var tokens: std.ArrayList(u32) = .empty;
        var t = range[0];
        while (t <= range[1]) : (t += 1) {
            if (inRanges(tests.items, t)) continue;
            var nested = false;
            for (fns.items) |other| {
                if (other[0] == range[0] and other[1] == range[1]) continue;
                if (other[0] >= range[0] and other[1] <= range[1] and t >= other[0] and t <= other[1]) {
                    nested = true;
                    break;
                }
            }
            if (!nested) try tokens.append(arena, t);
        }
        try own.append(arena, tokens.items);
    }

    // 4. Which functions return a map: twice, so a function returning
    // another's result is seen.
    var returning: std.StringHashMapUnmanaged(NameSet) = .empty;
    for (0..2) |_| {
        for (own.items, fn_names.items) |tokens, name| {
            if (name.len == 0) continue;
            var scope: Scope = .{ .tree = &tree, .tokens = tokens, .maps = &map_names, .returning = &returning };
            try scope.bind(arena);
            var set: NameSet = .empty;
            try scope.returned(arena, &set);
            if (set.count() > 0) try returning.put(arena, name, set);
        }
    }

    // 5. Removals and guards.
    var removed: NameSet = .empty;
    var noted: NameSet = .empty;
    var inserted: NameSet = .empty;
    for (own.items) |tokens| {
        var scope: Scope = .{ .tree = &tree, .tokens = tokens, .maps = &map_names, .returning = &returning };
        try scope.bind(arena);
        try scope.calls(arena, &removed, &noted, &inserted);
    }

    for (decls.items) |decl| {
        if (!removed.contains(decl.name)) continue;
        if (noted.contains(decl.name) and inserted.contains(decl.name)) continue;
        const name = try gpa.dupe(u8, decl.qualified);
        errdefer gpa.free(name);
        try out.append(gpa, .{ .line = decl.line, .name = name });
    }
    return out;
}

// ============================================================================
// The baseline
// ============================================================================

pub const Counts = std.StringHashMapUnmanaged(u32);

pub const Violation = struct { key: []const u8, allowed: u32, found: u32 };

fn lessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

fn violationLessThan(_: void, a: Violation, b: Violation) bool {
    return std.mem.lessThan(u8, a.key, b.key);
}

/// Every key in `current` above its baseline count - a key the baseline lacks
/// is allowed zero, which catches a swap - sorted by key.
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

/// Parse a baseline file: `path name count` per line, `#` comments.
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

pub const MoveError = error{
    OldKeyNotInBaseline,
    OldKeyStillPresent,
    NewKeyAbsent,
    NewKeyInBaseline,
    DifferentName,
    DifferentCount,
};

/// A key's qualified name, after its path.
fn nameOf(key: []const u8) []const u8 {
    const space = std.mem.indexOfScalar(u8, key, ' ') orelse return key;
    return key[space + 1 ..];
}

/// Whether `old_key` -> `new_key` is the same map moved to another file with
/// its type (lint-global-state's `--rename` is the model): the old key is in
/// the baseline and gone from the scan, the new key is in the scan and not in
/// the baseline, both name the same qualified map, with the same count. A
/// map renamed, or one more map, is not a move.
pub fn checkMove(old_key: []const u8, new_key: []const u8, current: *const Counts, baseline: *const Counts) MoveError!void {
    const old = baseline.get(old_key) orelse return error.OldKeyNotInBaseline;
    if (current.contains(old_key)) return error.OldKeyStillPresent;
    const new = current.get(new_key) orelse return error.NewKeyAbsent;
    if (baseline.contains(new_key)) return error.NewKeyInBaseline;
    if (!std.mem.eql(u8, nameOf(old_key), nameOf(new_key))) return error.DifferentName;
    if (old != new) return error.DifferentCount;
}

/// Move the baseline's entry from `old_key` to `new_key`. Call only after
/// `checkMove`. The new key is allocated with `gpa`; the old one is freed.
pub fn applyMove(gpa: std.mem.Allocator, baseline: *Counts, old_key: []const u8, new_key: []const u8) !void {
    const removed = baseline.fetchRemove(old_key) orelse return error.OldKeyNotInBaseline;
    gpa.free(removed.key);
    try baseline.put(gpa, try gpa.dupe(u8, new_key), removed.value);
}

const header =
    \\# Long-lived std hash maps in src/ that are removed from and have no TombstoneGuard:
    \\# path Qualified.name count (tools/lint_tombstones.zig). std.HashMap deletes by
    \\# tombstone and never grows while puts and removes balance, so its free slots run out
    \\# and every miss walks the table; guard each map (infra.tombstones.TombstoneGuard), or
    \\# exempt one that is cleared, bounded or short-lived with a `// tombstones: <why>` line
    \\# above it. A ratchet - `zig build lint-tombstones`, part of `zig build test`, fails if
    \\# a count rises or a new key appears. After paying some off, lower it with
    \\# `zig build lint-tombstones -- --update`. Never raise it by hand.
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

// ============================================================================
// The tool
// ============================================================================

const Site = struct { path: []const u8, line: u32, key: []const u8 };

fn scanDir(arena: std.mem.Allocator, io: std.Io, current: *Counts, sites: *std.ArrayList(Site)) !void {
    var dir = std.Io.Dir.cwd().openDir(io, scanned_root, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer dir.close(io);
    var walker = try dir.walk(arena);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;
        const path = try std.fmt.allocPrint(arena, "{s}/{s}", .{ scanned_root, entry.path });
        std.mem.replaceScalar(u8, path, '\\', '/');
        if (!isScanned(path)) continue;
        const text = try std.Io.Dir.cwd().readFileAllocOptions(io, path, arena, .limited(64 << 20), .of(u8), 0);
        const found = findings(arena, text) catch |err| switch (err) {
            error.ParseError => {
                std.debug.print("lint-tombstones: {s} does not parse\n", .{path});
                return err;
            },
            else => return err,
        };
        for (found.items) |finding| {
            const key = try std.fmt.allocPrint(arena, "{s} {s}", .{ path, finding.name });
            const gop = try current.getOrPut(arena, key);
            if (!gop.found_existing) gop.value_ptr.* = 0;
            gop.value_ptr.* += 1;
            try sites.append(arena, .{ .path = path, .line = finding.line, .key = key });
        }
    }
}

fn siteLessThan(_: void, a: Site, b: Site) bool {
    const order = std.mem.order(u8, a.path, b.path);
    if (order != .eq) return order == .lt;
    return a.line < b.line;
}

fn usage() noreturn {
    std.debug.print("usage: lint_tombstones [--update | --list] [--move '<old key>' '<new key>']...\n", .{});
    std.process.exit(2);
}

pub fn main(init: std.process.Init) !void {
    var arena_state = std.heap.ArenaAllocator.init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = init.io;

    var update = false;
    var list = false;
    var moves: std.ArrayList([2][]const u8) = .empty;
    var args = try init.minimal.args.iterateAllocator(arena);
    defer args.deinit();
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--update")) {
            update = true;
        } else if (std.mem.eql(u8, arg, "--list")) {
            list = true;
        } else if (std.mem.eql(u8, arg, "--move")) {
            const old_key = args.next() orelse usage();
            const new_key = args.next() orelse usage();
            try moves.append(arena, .{ try arena.dupe(u8, old_key), try arena.dupe(u8, new_key) });
            // A move is recorded, so it updates the baseline.
            update = true;
        } else usage();
    }

    var current: Counts = .empty;
    var sites: std.ArrayList(Site) = .empty;
    try scanDir(arena, io, &current, &sites);
    std.mem.sort(Site, sites.items, {}, siteLessThan);

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buf);
    const out = &stdout_writer.interface;
    defer out.flush() catch {};

    if (list) {
        for (sites.items) |site| {
            const name = site.key[site.path.len + 1 ..];
            try out.print("{s}:{d} {s}\n", .{ site.path, site.line, name });
        }
        try out.print("{d} unguarded map(s)\n", .{sites.items.len});
        return;
    }

    var total: usize = 0;
    var values = current.valueIterator();
    while (values.next()) |value| total += value.*;

    const text: ?[]u8 = std.Io.Dir.cwd().readFileAlloc(io, baseline_path, arena, .limited(64 << 20)) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    if (text == null) {
        if (!update) {
            try out.print("tombstones: no {s}; record one with `zig build lint-tombstones -- --update`.\n", .{baseline_path});
            try out.flush();
            std.process.exit(1);
        }
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = baseline_path, .data = try formatBaseline(arena, &current) });
        try out.print("tombstones: first baseline recorded - {d} unguarded map(s).\n", .{total});
        return;
    }
    var baseline = try parseBaseline(arena, text.?);
    for (moves.items) |move| {
        checkMove(move[0], move[1], &current, &baseline) catch |err| {
            try out.print("tombstones: --move '{s}' '{s}' refused: {s}.\n", .{ move[0], move[1], @errorName(err) });
            try out.flush();
            std.process.exit(1);
        };
        try applyMove(arena, &baseline, move[0], move[1]);
        try out.print("tombstones: moved '{s}' -> '{s}'.\n", .{ move[0], move[1] });
    }

    const found = try violations(arena, &current, &baseline);
    if (found.items.len > 0) {
        try out.print("tombstones: {d} map(s) above the baseline{s}.\n\n", .{ found.items.len, if (update) " - not recorded: the baseline only goes down" else "" });
        for (found.items) |v| {
            try out.print("  {s}: allowed {d}, found {d}\n", .{ v.key, v.allowed, v.found });
            for (sites.items) |site| {
                if (std.mem.eql(u8, site.key, v.key)) try out.print("      {s}:{d}\n", .{ site.path, site.line });
            }
        }
        try out.print(
            \\
            \\A long-lived std hash map whose keys come and go needs a TombstoneGuard
            \\(infra.tombstones, src/infra/tombstones.zig): `noteRemoval` after every
            \\removal and `beforeInsert` before every insert of a possibly new key, never
            \\rehashing during an iteration. A map cleared at a natural boundary, bounded,
            \\or short-lived says so on a `// tombstones: <why>` line above its declaration.
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
        try out.print("tombstones: baseline lowered - {d} unguarded map(s).\n", .{total});
    } else if (lowered > 0) {
        try out.print("tombstones: {d} map(s) paid down; record it with `zig build lint-tombstones -- --update`.\n", .{lowered});
    } else {
        try out.print("tombstones: {d} unguarded map(s), none above the baseline.\n", .{total});
    }
}

// ============================================================================
// Tests - the rules
// ============================================================================

const testing = std.testing;

fn expectFindings(source: [:0]const u8, expected: []const []const u8) !void {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const found = try findings(arena, source);
    var names: std.ArrayList([]const u8) = .empty;
    for (found.items) |f| try names.append(arena, f.name);
    if (names.items.len != expected.len) {
        std.debug.print("expected {any}\nfound    {any}\n", .{ expected, names.items });
        return error.TestUnexpectedResult;
    }
    for (expected, names.items) |want, got| try testing.expectEqualStrings(want, got);
}

test "a field map removed from with no guard is flagged, qualified by its container" {
    try expectFindings(
        \\const std = @import("std");
        \\pub const Manager = struct {
        \\    timers: std.AutoHashMap(u64, *u8),
        \\    fn clear(self: *Manager, id: u64) void {
        \\        _ = self.timers.fetchRemove(id);
        \\    }
        \\};
    , &.{"Manager.timers"});
}

test "a map guarded by noteRemoval and beforeInsert is not flagged; one of the two is not a guard" {
    try expectFindings(
        \\const std = @import("std");
        \\const Guard = @import("infra").tombstones.TombstoneGuard;
        \\pub const Both = struct {
        \\    map: std.AutoHashMapUnmanaged(usize, u8) = .empty,
        \\    guard: Guard = .{},
        \\    fn put(self: *Both, a: std.mem.Allocator, k: usize) !void {
        \\        self.guard.beforeInsert(&self.map);
        \\        try self.map.put(a, k, 1);
        \\    }
        \\    fn drop(self: *Both, k: usize) void {
        \\        if (self.map.remove(k)) self.guard.noteRemoval(&self.map);
        \\    }
        \\};
        \\pub const Half = struct {
        \\    half: std.AutoHashMapUnmanaged(usize, u8) = .empty,
        \\    guard: Guard = .{},
        \\    fn drop(self: *Half, k: usize) void {
        \\        if (self.half.remove(k)) self.guard.noteRemoval(&self.half);
        \\    }
        \\};
    , &.{"Half.half"});
}

test "a map that is never removed from, and a map cleared whole, are not flagged" {
    try expectFindings(
        \\const std = @import("std");
        \\pub const Grows = struct {
        \\    map: std.StringHashMap(u8),
        \\    fn add(self: *Grows, k: []const u8) !void {
        \\        try self.map.put(k, 1);
        \\    }
        \\    fn reset(self: *Grows) void {
        \\        self.map.clearRetainingCapacity();
        \\    }
        \\};
    , &.{});
}

test "a `// tombstones: <why>` line in the comment block above the declaration exempts it" {
    try expectFindings(
        \\const std = @import("std");
        \\pub const Page = struct {
        \\    /// Ids of the page's pending work.
        \\    // tombstones: cleared at the page's end, and a page holds a handful
        \\    pending: std.AutoHashMap(u64, u8),
        \\    // A comment that says nothing about tombstones.
        \\    other: std.AutoHashMap(u64, u8),
        \\    fn done(self: *Page, id: u64) void {
        \\        _ = self.pending.remove(id);
        \\        _ = self.other.remove(id);
        \\    }
        \\};
    , &.{"Page.other"});
}

test "a container-level threadlocal map, optional, removed from through an if capture" {
    try expectFindings(
        \\const std = @import("std");
        \\threadlocal var timer_contexts: ?std.AutoHashMap(u64, *u8) = null;
        \\fn unregister(id: u64) void {
        \\    if (timer_contexts) |*map| {
        \\        _ = map.fetchRemove(id);
        \\    }
        \\}
    , &.{"timer_contexts"});
}

test "a local bound to the map, directly or through a function that returns it, carries the removal" {
    try expectFindings(
        \\const std = @import("std");
        \\const Table = struct {
        \\    map: std.AutoHashMap(usize, u8),
        \\};
        \\fn existing(scope: *Scope) ?*std.AutoHashMap(usize, u8) {
        \\    const table = scope.table() orelse return null;
        \\    return &table.map;
        \\}
        \\fn remove(scope: *Scope, k: usize) void {
        \\    const states = existing(scope) orelse return;
        \\    _ = states.fetchRemove(k);
        \\}
        \\const Registry = struct {
        \\    entries: ?std.AutoHashMap(usize, u8) = null,
        \\    fn take(self: *Registry, k: usize) void {
        \\        const live = &(self.entries orelse return);
        \\        _ = live.remove(k);
        \\    }
        \\};
    , &.{ "Table.map", "Registry.entries" });
}

test "a type alias of the file names a map; ArrayHashMap and pointers to maps do not" {
    try expectFindings(
        \\const std = @import("std");
        \\const Records = std.AutoHashMapUnmanaged(c_int, u8);
        \\threadlocal var records: Records = .empty;
        \\const Ordered = struct {
        \\    list: std.AutoArrayHashMapUnmanaged(u32, u8) = .empty,
        \\    borrowed: *std.StringHashMap(u8),
        \\    fn drop(self: *Ordered, k: u32) void {
        \\        _ = self.list.swapRemove(k);
        \\        _ = self.list.remove(k);
        \\        _ = self.borrowed.remove("x");
        \\    }
        \\};
        \\fn unregister(k: c_int) void {
        \\    _ = records.remove(k);
        \\}
    , &.{"records"});
}

test "a removal from another field, a local map and a test's map do not count" {
    try expectFindings(
        \\const std = @import("std");
        \\pub const Holder = struct {
        \\    map: std.AutoHashMap(u32, u8),
        \\    list: List,
        \\    fn drop(self: *Holder, i: usize) void {
        \\        _ = self.list.remove(i);
        \\        var scratch = std.AutoHashMap(u32, u8).init(std.heap.page_allocator);
        \\        defer scratch.deinit();
        \\        _ = scratch.remove(1);
        \\    }
        \\};
        \\test "a test's map" {
        \\    const T = struct { m: std.AutoHashMap(u32, u8) };
        \\    var t: T = undefined;
        \\    _ = t.m.remove(1);
        \\}
    , &.{});
}

test "a map in the struct a generic function returns is qualified by the function" {
    try expectFindings(
        \\const std = @import("std");
        \\pub fn Reactions(comptime Element: type) type {
        \\    return struct {
        \\        pending: std.AutoHashMap(Element, u8),
        \\        fn take(self: *@This(), e: Element) void {
        \\            _ = self.pending.remove(e);
        \\        }
        \\    };
        \\}
    , &.{"Reactions.pending"});
}

test "a guard on one map does not cover another; a removal through a call that returns the map counts" {
    try expectFindings(
        \\const std = @import("std");
        \\const Guard = @import("infra").tombstones.TombstoneGuard;
        \\pub const Two = struct {
        \\    a: std.AutoHashMap(u32, u8),
        \\    b: ?std.AutoHashMap(u32, u8) = null,
        \\    guard: Guard = .{},
        \\    fn ensureB(self: *Two) *std.AutoHashMap(u32, u8) {
        \\        return &self.b.?;
        \\    }
        \\    fn put(self: *Two, k: u32) !void {
        \\        self.guard.beforeInsert(&self.a);
        \\        try self.a.put(k, 1);
        \\    }
        \\    fn drop(self: *Two, k: u32) void {
        \\        if (self.a.remove(k)) self.guard.noteRemoval(&self.a);
        \\        _ = self.ensureB().remove(k);
        \\    }
        \\};
    , &.{"Two.b"});
}

test "a file that does not parse is an error, not a pass" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    try testing.expectError(error.ParseError, findings(arena_state.allocator(), "const = ;"));
}

test "which files are scanned" {
    try testing.expect(isScanned("src/runtime/native_timer.zig"));
    try testing.expect(!isScanned("src/webidl/impls_tmp/Node.zig"));
    try testing.expect(!isScanned("tests/runtime/timer_tombstones_test.zig"));
    try testing.expect(!isScanned("tools/lint_tombstones.zig"));
    try testing.expect(!isScanned("src/runtime/.zig-cache/x.zig"));
    try testing.expect(!isScanned("src/runtime/notes.md"));
}

test "a violation is any key above its baseline, including a key the baseline lacks (a swap)" {
    const gpa = testing.allocator;
    var baseline = try parseBaseline(gpa,
        \\# comment
        \\src/a.zig A.map 1
        \\src/b.zig records 1
    );
    defer {
        var keys = baseline.keyIterator();
        while (keys.next()) |key| gpa.free(key.*);
        baseline.deinit(gpa);
    }
    var current: Counts = .empty;
    defer current.deinit(gpa);
    // b's map guarded, a new one unguarded: the total is unchanged, and it
    // is still a violation.
    try current.put(gpa, "src/a.zig A.map", 1);
    try current.put(gpa, "src/c.zig C.timers", 1);
    var found = try violations(gpa, &current, &baseline);
    defer found.deinit(gpa);
    try testing.expectEqual(@as(usize, 1), found.items.len);
    try testing.expectEqualStrings("src/c.zig C.timers", found.items[0].key);
    try testing.expectEqual(@as(u32, 0), found.items[0].allowed);
}

test "a move is recorded only for the same map in another file, with the same count" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var baseline: Counts = .empty;
    try baseline.put(arena, try arena.dupe(u8, "src/a.zig State.map"), 1);
    try baseline.put(arena, try arena.dupe(u8, "src/a.zig State.kept"), 1);
    try baseline.put(arena, try arena.dupe(u8, "src/a.zig State.two"), 2);

    var current: Counts = .empty;
    try current.put(arena, "src/b.zig State.map", 1);
    try current.put(arena, "src/a.zig State.kept", 1);
    try current.put(arena, "src/b.zig State.renamed", 1);
    try current.put(arena, "src/b.zig State.two", 1);

    // Accepted: the same map, gone from one file and found in another.
    try checkMove("src/a.zig State.map", "src/b.zig State.map", &current, &baseline);

    // The old key must be in the baseline, and gone from the scan.
    try testing.expectError(error.OldKeyNotInBaseline, checkMove("src/a.zig State.nowhere", "src/b.zig State.map", &current, &baseline));
    try testing.expectError(error.OldKeyStillPresent, checkMove("src/a.zig State.kept", "src/b.zig State.map", &current, &baseline));
    // The new key must be in the scan, and not in the baseline.
    try testing.expectError(error.NewKeyAbsent, checkMove("src/a.zig State.map", "src/b.zig State.missing", &current, &baseline));
    try baseline.put(arena, try arena.dupe(u8, "src/b.zig State.recorded"), 1);
    try current.put(arena, "src/b.zig State.recorded", 1);
    try testing.expectError(error.NewKeyInBaseline, checkMove("src/a.zig State.map", "src/b.zig State.recorded", &current, &baseline));
    // Another qualified name is another map, not a move.
    try testing.expectError(error.DifferentName, checkMove("src/a.zig State.map", "src/b.zig State.renamed", &current, &baseline));
    // A different count is a map more or fewer.
    try testing.expectError(error.DifferentCount, checkMove("src/a.zig State.two", "src/b.zig State.two", &current, &baseline));

    // Applied: the old key is gone, the new one carries the count.
    try applyMove(arena, &baseline, "src/a.zig State.map", "src/b.zig State.map");
    try testing.expect(!baseline.contains("src/a.zig State.map"));
    try testing.expectEqual(@as(?u32, 1), baseline.get("src/b.zig State.map"));
    // The moved map is no violation now; the unrecorded ones still are.
    const found = try violations(arena, &current, &baseline);
    for (found.items) |v| try testing.expect(!std.mem.eql(u8, v.key, "src/b.zig State.map"));
    try testing.expectEqual(@as(usize, 2), found.items.len);
}

test "the baseline round-trips, sorted, and ignores comments" {
    const gpa = testing.allocator;
    var counts: Counts = .empty;
    defer counts.deinit(gpa);
    try counts.put(gpa, "src/z.zig Z.map", 1);
    try counts.put(gpa, "src/a.zig records", 2);
    const text = try formatBaseline(gpa, &counts);
    defer gpa.free(text);
    try testing.expect(std.mem.indexOf(u8, text, "src/a.zig records 2\nsrc/z.zig Z.map 1\n") != null);
    var parsed = try parseBaseline(gpa, text);
    defer {
        var keys = parsed.keyIterator();
        while (keys.next()) |key| gpa.free(key.*);
        parsed.deinit(gpa);
    }
    try testing.expectEqual(@as(usize, 2), parsed.count());
    try testing.expectEqual(@as(?u32, 2), parsed.get("src/a.zig records"));
}

test "isTombstoningType: the HashMaps, optional or not, under std or std.hash_map; never an ArrayHashMap or a pointer" {
    try testing.expect(isTombstoningType("std.AutoHashMap(u32,u8)"));
    try testing.expect(isTombstoningType("?std.StringHashMapUnmanaged(u8)"));
    try testing.expect(isTombstoningType("std.hash_map.HashMap(K,V,Ctx,80)"));
    try testing.expect(isTombstoningType("std.HashMapUnmanaged(Key,*Node,KeyContext,80)"));
    try testing.expect(!isTombstoningType("std.AutoArrayHashMap(u32,u8)"));
    try testing.expect(!isTombstoningType("std.StringArrayHashMapUnmanaged(u8)"));
    try testing.expect(!isTombstoningType("*std.AutoHashMap(u32,u8)"));
    try testing.expect(!isTombstoningType("std.ArrayList(u8)"));
}

test "exemptWhy: only a why, only in the comment block directly above" {
    const source =
        \\// tombstones: too far up
        \\
        \\/// doc
        \\// tombstones: cleared at the page's end
        \\a: u8,
        \\// tombstones:
        \\b: u8,
    ;
    try testing.expectEqualStrings("cleared at the page's end", exemptWhy(source, 5).?);
    try testing.expectEqual(@as(?[]const u8, null), exemptWhy(source, 7));
    try testing.expectEqual(@as(?[]const u8, null), exemptWhy(source, 3));
}
