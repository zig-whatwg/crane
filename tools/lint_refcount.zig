//! Reference counting's structural rules, and node state's exits, as a ratchet: `zig build
//! lint-refcount` (and so `zig build test`) fails when src/ breaks them more
//! than tools/refcount_baseline.txt records (tmp/plans/refcount-design.md,
//! section 7 step 2; src/dom/refcount.zig).
//!
//! 1. `parent-write`: every `<expr>.parent_node = <expr>` assignment outside
//!    src/dom/node_base.zig. A node's parent link and the count word's parent
//!    bit (and `subtree_holds` of every host-including ancestor) change
//!    together, in ONE setter that NodeBase owns; a second writer leaves the
//!    counts wrong and the tree freed or kept by mistake. The writers that
//!    exist today are in the baseline and step 3 ("Tree links") funnels them
//!    into the setter, which lowers it to zero. Struct initialisers
//!    (`.{ .parent_node = null }`) are not assignments: a node is born
//!    parentless.
//! 2. `ref-in-node-state`: a field of a node's own state whose type holds a
//!    counted reference (`Ref(...)`, `?Ref(...)`, `GCReachableRef(...)`,
//!    however wrapped). A tree is the unit of lifetime (decision D1): a node
//!    that counts another node makes a native cycle no collector breaks.
//!    Node relations outside the tree (form owner, label, popover invoker,
//!    assigned slot) are `WeakRef` or raw pointers, never counted. Node state
//!    is NodeBase, any struct with a NodeBase field (every concrete node type
//!    has NodeBase first), and every container in the node interfaces' impl
//!    files (src/webidl/impls: Node, Element, CharacterData, Text, Comment,
//!    CDATASection, ProcessingInstruction, Document, XMLDocument,
//!    DocumentFragment, ShadowRoot, DocumentType, Attr, and every `*Element`).
//!    `structural_links` below names fields that may hold one (none: a child, a
//!    shadow root and a template's contents live with their tree and carry no
//!    count of their own).
//! 3. A node's own state block has an exit (lane orphanleak). A node removed
//!    from its tree while script held no wrapper of it is an ORPHAN that no
//!    tree teardown and no collector reaches before refcounting lands, so
//!    its deinit never runs; its state's exit is then its type's teardown
//!    sweep at its Browser's end, or the runtime arena's end for a block
//!    that owns nothing more (src/dom/orphan_states.zig). In a node
//!    interface's impl:
//!    - `state-heap-block`: `<allocator>.create(InternalState)` with an
//!      allocator that is not an arena - a block whose one exit is the
//!      deinit an orphan never runs (twelve such leaked, one per orphan).
//!    - `state-no-sweep`: an `InternalState` whose `deinit` frees anything
//!      (a body of more than `_ = x;` discards) in a file that installs no
//!      teardown sweep (`teardown_sweeps.install`, a `Swept` type's
//!      `installSweep`, `orphan_states.installRegistrySweep`): what the state
//!      owns has no exit for an orphan.
//!    The default is the rule: a new node type's state has an exit or the
//!    check fails. A state that frees what it owns inline in the node's
//!    deinit, with no `InternalState.deinit`, is not seen - give it one.
//!
//! Key: `path rule` or `path ref-in-node-state.<Container>.<field>`. The
//! baseline only goes down: after paying some off, `zig build lint-refcount --
//! --update` records it and refuses to record an increase.

const std = @import("std");

const baseline_path = "tools/refcount_baseline.txt";

/// Fields allowed to hold a counted reference in node state: `Container.field`.
pub const structural_links = [_][]const u8{};

/// Where the one parent setter lives, and the types themselves.
const parent_owner_files = [_][]const u8{ "src/dom/node_base.zig", "src/dom/refcount.zig" };

/// The tree held to the rules.
const scanned_root = "src";

/// Not built: codegen's stubs for hand merging.
const exempt_prefixes = [_][]const u8{"src/webidl/impls_tmp/"};

pub fn isScanned(path: []const u8) bool {
    if (!std.mem.endsWith(u8, path, ".zig")) return false;
    if (!std.mem.startsWith(u8, path, scanned_root ++ "/")) return false;
    for (exempt_prefixes) |prefix| if (std.mem.startsWith(u8, path, prefix)) return false;
    return true;
}

const node_state_impls = [_][]const u8{
    "Node",             "CharacterData",         "Text",         "Comment",
    "CDATASection",     "ProcessingInstruction", "Document",     "XMLDocument",
    "DocumentFragment", "ShadowRoot",            "DocumentType", "Attr",
};

/// Whether every container in `path` is node state: a node interface's impl.
pub fn isNodeStateFile(path: []const u8) bool {
    const impls = "src/webidl/impls/";
    if (!std.mem.startsWith(u8, path, impls)) return false;
    const rest = path[impls.len..];
    if (std.mem.indexOfScalar(u8, rest, '/') != null) return false;
    if (!std.mem.endsWith(u8, rest, ".zig")) return false;
    const stem = rest[0 .. rest.len - ".zig".len];
    for (node_state_impls) |name| if (std.mem.eql(u8, stem, name)) return true;
    return std.mem.endsWith(u8, stem, "Element");
}

/// One finding: its line and the key it is counted under (after the path).
pub const Finding = struct {
    line: u32,
    key: []const u8,
    /// The offending code, for the report.
    code: []const u8,
};

fn nodeText(tree: *const std.zig.Ast, node: std.zig.Ast.Node.Index) []const u8 {
    const start = tree.tokenStart(tree.firstToken(node));
    const last = tree.lastToken(node);
    const end = tree.tokenStart(last) + tree.tokenSlice(last).len;
    return tree.source[start..end];
}

/// Whether the tokens of `node` name a counted reference type: the identifier
/// `Ref` or `GCReachableRef` followed by `(` (so `WeakRef(...)`, a different
/// identifier, is not one).
fn mentionsCountedRef(tree: *const std.zig.Ast, node: std.zig.Ast.Node.Index) bool {
    var token = tree.firstToken(node);
    const last = tree.lastToken(node);
    while (token <= last) : (token += 1) {
        if (tree.tokenTag(token) != .identifier) continue;
        const name = tree.tokenSlice(token);
        const is_ref = std.mem.eql(u8, name, "Ref") or std.mem.eql(u8, name, "GCReachableRef");
        if (is_ref and token + 1 <= last and tree.tokenTag(token + 1) == .l_paren) return true;
    }
    return false;
}

/// Whether a field type is NodeBase by value: `NodeBase`, `dom.NodeBase`,
/// `node_base.NodeBase`.
fn isNodeBaseType(text: []const u8) bool {
    if (std.mem.eql(u8, text, "NodeBase")) return true;
    return std.mem.endsWith(u8, text, ".NodeBase") and std.mem.indexOfAny(u8, text, "?*[]() ") == null;
}

fn isAllowedLink(container: []const u8, field: []const u8, gpa: std.mem.Allocator) !bool {
    const key = try std.fmt.allocPrint(gpa, "{s}.{s}", .{ container, field });
    defer gpa.free(key);
    for (structural_links) |allowed| if (std.mem.eql(u8, allowed, key)) return true;
    return false;
}

/// The findings of one file. `path` is repo-relative with `/`. Strings are
/// allocated with `gpa`; a file that does not parse is an error, so a file the
/// ratchet cannot read never passes silently.
pub fn findings(gpa: std.mem.Allocator, path: []const u8, source: [:0]const u8) !std.ArrayList(Finding) {
    var out: std.ArrayList(Finding) = .empty;
    errdefer {
        for (out.items) |f| gpa.free(f.key);
        out.deinit(gpa);
    }
    if (!isScanned(path)) return out;

    var tree = try std.zig.Ast.parse(gpa, source, .zig);
    defer tree.deinit(gpa);
    if (tree.errors.len > 0) return error.ParseError;

    const writes_allowed = blk: {
        for (parent_owner_files) |owner| if (std.mem.eql(u8, path, owner)) break :blk true;
        break :blk false;
    };
    const every_container_is_node_state = isNodeStateFile(path);

    // The names containers are bound to: `const Name = struct { ... }`.
    var names: std.AutoHashMapUnmanaged(std.zig.Ast.Node.Index, []const u8) = .empty;
    defer names.deinit(gpa);
    // Test declarations are not production code.
    var tests: std.ArrayList([2]u32) = .empty;
    defer tests.deinit(gpa);

    var i: u32 = 0;
    while (i < tree.nodes.len) : (i += 1) {
        const node: std.zig.Ast.Node.Index = @enumFromInt(i);
        if (tree.nodeTag(node) == .test_decl) try tests.append(gpa, .{ tree.firstToken(node), tree.lastToken(node) });
        if (tree.fullVarDecl(node)) |decl| {
            if (decl.ast.init_node.unwrap()) |init_node| {
                try names.put(gpa, init_node, tree.tokenSlice(decl.ast.mut_token + 1));
            }
        }
    }

    // Rule 3's facts about the file: whether it installs a teardown sweep,
    // and its InternalState's deinit, if it has one.
    var installs_sweep = false;
    var state_deinit: ?std.zig.Ast.Node.Index = null;

    i = 0;
    while (i < tree.nodes.len) : (i += 1) {
        const node: std.zig.Ast.Node.Index = @enumFromInt(i);
        const first = tree.firstToken(node);
        var in_test = false;
        for (tests.items) |range| {
            if (first >= range[0] and first <= range[1]) in_test = true;
        }
        if (in_test) continue;

        // Rule 1: `<expr>.parent_node = <expr>`.
        if (!writes_allowed and tree.nodeTag(node) == .assign) {
            const lhs, _ = tree.nodeData(node).node_and_node;
            if (tree.nodeTag(lhs) == .field_access) {
                const field_token = tree.nodeData(lhs).node_and_token[1];
                if (std.mem.eql(u8, tree.tokenSlice(field_token), "parent_node")) {
                    try out.append(gpa, .{
                        .line = @intCast(tree.tokenLocation(0, first).line + 1),
                        .key = try gpa.dupe(u8, "parent-write"),
                        .code = nodeText(&tree, node),
                    });
                }
            }
        }

        // Rule 3: a node's own state block has an exit.
        if (every_container_is_node_state) {
            var call_buffer: [1]std.zig.Ast.Node.Index = undefined;
            if (tree.fullCall(&call_buffer, node)) |call| {
                const callee = nodeText(&tree, call.ast.fn_expr);
                if (isSweepInstall(callee)) installs_sweep = true;
                if (isHeapStateBlock(&tree, call)) try out.append(gpa, .{
                    .line = @intCast(tree.tokenLocation(0, first).line + 1),
                    .key = try gpa.dupe(u8, "state-heap-block"),
                    .code = nodeText(&tree, node),
                });
            }
        }

        // Rule 2: a counted reference in node state.
        var buffer: [2]std.zig.Ast.Node.Index = undefined;
        const container = tree.fullContainerDecl(&buffer, node) orelse continue;
        const container_name = names.get(node) orelse "(anonymous)";
        if (every_container_is_node_state and std.mem.eql(u8, container_name, "InternalState")) {
            if (deinitMember(&tree, container.ast.members)) |member| state_deinit = member;
        }
        var has_node_base = false;
        for (container.ast.members) |member| {
            const field = tree.fullContainerField(member) orelse continue;
            const type_node = field.ast.type_expr.unwrap() orelse continue;
            if (isNodeBaseType(nodeText(&tree, type_node))) has_node_base = true;
        }
        const is_node_state = every_container_is_node_state or has_node_base or
            (std.mem.eql(u8, container_name, "NodeBase") and std.mem.eql(u8, path, "src/dom/node_base.zig"));
        if (!is_node_state) continue;
        for (container.ast.members) |member| {
            const field = tree.fullContainerField(member) orelse continue;
            const type_node = field.ast.type_expr.unwrap() orelse continue;
            if (!mentionsCountedRef(&tree, type_node)) continue;
            const field_name = tree.tokenSlice(field.ast.main_token);
            if (try isAllowedLink(container_name, field_name, gpa)) continue;
            try out.append(gpa, .{
                .line = @intCast(tree.tokenLocation(0, tree.firstToken(member)).line + 1),
                .key = try std.fmt.allocPrint(gpa, "ref-in-node-state.{s}.{s}", .{ container_name, field_name }),
                .code = nodeText(&tree, member),
            });
        }
    }
    if (state_deinit) |member| if (!installs_sweep) try out.append(gpa, .{
        .line = @intCast(tree.tokenLocation(0, tree.firstToken(member)).line + 1),
        .key = try gpa.dupe(u8, "state-no-sweep"),
        .code = firstLine(nodeText(&tree, member)),
    });
    return out;
}

fn firstLine(text: []const u8) []const u8 {
    return text[0 .. std.mem.indexOfScalar(u8, text, '\n') orelse text.len];
}

/// Rule 3: whether `call` makes a node's InternalState block outside the
/// runtime arena - `<allocator>.create(InternalState)` with an allocator
/// that is not an arena (`runtime.arenaOf(instance)`, an `arena` local, a
/// registry's `createIn(instance, arena)`). Such a block's one exit is the
/// node's deinit, which an orphan never runs.
fn isHeapStateBlock(tree: *const std.zig.Ast, call: std.zig.Ast.full.Call) bool {
    if (call.ast.params.len != 1) return false;
    if (!std.mem.eql(u8, nodeText(tree, call.ast.params[0]), "InternalState")) return false;
    if (tree.nodeTag(call.ast.fn_expr) != .field_access) return false;
    const object, const field_token = tree.nodeData(call.ast.fn_expr).node_and_token;
    if (!std.mem.eql(u8, tree.tokenSlice(field_token), "create")) return false;
    return std.ascii.indexOfIgnoreCase(nodeText(tree, object), "arena") == null;
}

/// Rule 3: whether a callee installs a teardown sweep - `dom.teardown_sweeps`'
/// `install`, a `dom.orphan_states.Swept` type's `installSweep`, or
/// `dom.orphan_states.installRegistrySweep`.
fn isSweepInstall(callee: []const u8) bool {
    return std.mem.endsWith(u8, callee, "teardown_sweeps.install") or
        std.mem.endsWith(u8, callee, ".installSweep") or
        std.mem.endsWith(u8, callee, "orphan_states.installRegistrySweep");
}

/// Rule 3: the `deinit` function among a container's members, if any.
fn deinitMember(tree: *const std.zig.Ast, members: []const std.zig.Ast.Node.Index) ?std.zig.Ast.Node.Index {
    for (members) |member| {
        if (tree.nodeTag(member) != .fn_decl) continue;
        const proto = tree.nodeData(member).node_and_node[0];
        var buffer: [1]std.zig.Ast.Node.Index = undefined;
        const fn_proto = tree.fullFnProto(&buffer, proto) orelse continue;
        const name = fn_proto.name_token orelse continue;
        if (!std.mem.eql(u8, tree.tokenSlice(name), "deinit")) continue;
        if (discardsOnly(tree, tree.nodeData(member).node_and_node[1])) return null;
        return member;
    }
    return null;
}

/// Whether a function body does nothing: no statements, or only `_ = x;`
/// discards - a deinit that frees nothing owns nothing.
fn discardsOnly(tree: *const std.zig.Ast, body: std.zig.Ast.Node.Index) bool {
    var buffer: [2]std.zig.Ast.Node.Index = undefined;
    const statements = tree.blockStatements(&buffer, body) orelse return false;
    for (statements) |statement| {
        if (tree.nodeTag(statement) != .assign) return false;
        const lhs, _ = tree.nodeData(statement).node_and_node;
        if (!std.mem.eql(u8, nodeText(tree, lhs), "_")) return false;
    }
    return true;
}

// ============================================================================
// Baseline
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

/// Parse a baseline file: `path key count` per line, `#` comments.
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
    \\# Reference-counting rule breaches in src/: path rule count. Rules: `parent-write` (an
    \\# assignment to `.parent_node` outside NodeBase's setter),
    \\# `ref-in-node-state.<Container>.<field>` (a counted reference inside node state), and
    \\# `state-heap-block` / `state-no-sweep` (a node state with no exit for an orphan); see
    \\# tools/lint_refcount.zig. A ratchet - `zig build lint-refcount`, part of `zig build
    \\# test`, fails if any count rises or a new pair appears. After paying some off, lower it
    \\# with `zig build lint-refcount -- --update`. Never raise it by hand.
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

const Site = struct { line: u32, code: []const u8 };

fn scanDir(
    arena: std.mem.Allocator,
    io: std.Io,
    current: *Counts,
    sites: *std.StringHashMapUnmanaged(std.ArrayList(Site)),
) !void {
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
        if (std.mem.indexOf(u8, path, ".zig-cache/") != null) continue;
        const text = try std.Io.Dir.cwd().readFileAllocOptions(io, path, arena, .limited(64 << 20), .of(u8), 0);
        const found = try findings(arena, path, text);
        for (found.items) |finding| {
            const key = try std.fmt.allocPrint(arena, "{s} {s}", .{ path, finding.key });
            const gop = try current.getOrPut(arena, key);
            if (!gop.found_existing) gop.value_ptr.* = 0;
            gop.value_ptr.* += 1;
            const site = try sites.getOrPut(arena, key);
            if (!site.found_existing) site.value_ptr.* = .empty;
            try site.value_ptr.append(arena, .{ .line = finding.line, .code = finding.code });
        }
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
            std.debug.print("usage: lint_refcount [--update]\n", .{});
            std.process.exit(2);
        }
    }

    var current: Counts = .empty;
    var sites: std.StringHashMapUnmanaged(std.ArrayList(Site)) = .empty;
    try scanDir(arena, io, &current, &sites);

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
            try out.print("refcount rules: no {s}; record one with `zig build lint-refcount -- --update`.\n", .{baseline_path});
            try out.flush();
            std.process.exit(1);
        }
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = baseline_path, .data = try formatBaseline(arena, &current) });
        try out.print("refcount rules: first baseline recorded - {d} breaches, {d} keys.\n", .{ total, current.count() });
        return;
    }
    const baseline = try parseBaseline(arena, text.?);

    const found = try violations(arena, &current, &baseline);
    if (found.items.len > 0) {
        try out.print("refcount rules: {d} key(s) above the baseline.\n\n", .{found.items.len});
        for (found.items) |v| {
            try out.print("  {s}: allowed {d}, found {d}\n", .{ v.key, v.allowed, v.found });
            if (sites.get(v.key)) |list| {
                const path_end = std.mem.indexOfScalar(u8, v.key, ' ') orelse v.key.len;
                for (list.items) |site| try out.print("      {s}:{d}: {s}\n", .{ v.key[0..path_end], site.line, site.code });
            }
        }
        try out.print(
            \\
            \\A node's parent link changes through NodeBase's one setter, which keeps the
            \\count word's parent bit and every ancestor's `subtree_holds` in step; node
            \\state never holds a counted reference to a node (a native cycle): use WeakRef
            \\or a raw pointer. tmp/plans/refcount-design.md sections 1.3 and 7. A node's
            \\own state has an exit for an orphan: a block of the runtime arena, and a
            \\teardown sweep for what it owns (src/dom/orphan_states.zig).
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
        try out.print("refcount rules: baseline lowered - {d} breaches, {d} keys.\n", .{ total, current.count() });
    } else if (lowered > 0) {
        try out.print("refcount rules: {d} key(s) paid down; record it with `zig build lint-refcount -- --update`.\n", .{lowered});
    } else {
        try out.print("refcount rules: {d} breaches, none above the baseline.\n", .{total});
    }
}

// ============================================================================
// Tests - the rules
// ============================================================================

const testing = std.testing;

fn expectFindings(path: []const u8, source: [:0]const u8, expected: []const []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const found = try findings(arena.allocator(), path, source);
    var got: std.ArrayList(u8) = .empty;
    for (found.items) |f| try got.print(arena.allocator(), "{d}:{s}\n", .{ f.line, f.key });
    var want: std.ArrayList(u8) = .empty;
    for (expected) |line| try want.print(arena.allocator(), "{s}\n", .{line});
    try testing.expectEqualStrings(want.items, got.items);
}

test "parent-write: an assignment to .parent_node outside NodeBase's setter" {
    try expectFindings("src/dom/mutation.zig",
        \\fn insert(child: *NodeBase, parent: *NodeBase) void {
        \\    child.parent_node = parent;
        \\    child.next_sibling = null;
        \\    other.base.parent_node = null;
        \\}
    , &.{ "2:parent-write", "4:parent-write" });
}

test "parent-write: struct initialisers, reads and comparisons are not writes" {
    try expectFindings("src/dom/mutation.zig",
        \\fn f(child: *NodeBase) bool {
        \\    const n: NodeBase = .{ .parent_node = null, .node_type = 1 };
        \\    const p = child.parent_node;
        \\    return child.parent_node == null and p != null;
        \\}
    , &.{});
}

test "parent-write: NodeBase's own file and the counting types may write it" {
    const source =
        \\pub fn setParentNode(node: *NodeBase, parent: ?*NodeBase) void {
        \\    node.parent_node = parent;
        \\}
    ;
    try expectFindings("src/dom/node_base.zig", source, &.{});
    try expectFindings("src/dom/refcount.zig", source, &.{});
    try expectFindings("src/dom/tree.zig", source, &.{"2:parent-write"});
}

test "parent-write: test declarations are not production code; tests/ and tools/ are not scanned" {
    try expectFindings("src/dom/tree.zig",
        \\test "links by hand" {
        \\    child.parent_node = parent;
        \\}
    , &.{});
    try expectFindings("tests/dom/tree_test.zig", "fn f() void { child.parent_node = parent; }", &.{});
}

test "ref-in-node-state: a counted reference in a struct with a NodeBase field" {
    try expectFindings("src/dom/element_with_base.zig",
        \\pub const ElementWithBase = struct {
        \\    base: NodeBase,
        \\    owner: Ref(NodeBase),
        \\    maybe: ?Ref(Foo),
        \\    kept: GCReachableRef(NodeBase),
        \\    list: std.ArrayList(Ref(NodeBase)),
        \\    weak: WeakRef(NodeBase),
        \\    raw: ?*NodeBase,
        \\};
    , &.{
        "3:ref-in-node-state.ElementWithBase.owner",
        "4:ref-in-node-state.ElementWithBase.maybe",
        "5:ref-in-node-state.ElementWithBase.kept",
        "6:ref-in-node-state.ElementWithBase.list",
    });
}

test "ref-in-node-state: every container in a node interface's impl is node state" {
    try expectFindings("src/webidl/impls/HTMLLabelElement.zig",
        \\pub const State = struct {
        \\    control: Ref(NodeBase),
        \\    other: WeakRef(NodeBase),
        \\};
        \\const Helper = struct { held: refcount.Ref(NodeBase) };
    , &.{
        "2:ref-in-node-state.State.control",
        "5:ref-in-node-state.Helper.held",
    });
    // A holder that is not a node: a MutationRecord holds its nodes.
    try expectFindings("src/webidl/impls/MutationRecord.zig",
        \\pub const State = struct { target: Ref(NodeBase), added: []Ref(NodeBase) };
    , &.{});
    try expectFindings("src/webidl/impls/Range.zig", "const State = struct { start: Ref(NodeBase) };", &.{});
}

test "ref-in-node-state: a holder struct that is not node state is free to count" {
    try expectFindings("src/dom/range_boundaries.zig",
        \\pub const Boundary = struct { node: Ref(NodeBase), offset: u32 };
    , &.{});
}

test "state-heap-block: a node's InternalState from a non-arena allocator" {
    try expectFindings("src/webidl/impls/HTMLNewElement.zig",
        \\pub const InternalState = struct { flag: bool = false };
        \\fn make(instance: *Instance, allocator: Allocator) !void {
        \\    const a = try allocator.create(InternalState);
        \\    const b = try instance.ctx.allocator.create(InternalState);
        \\    const c = try runtime.arenaOf(instance).create(InternalState);
        \\    const d = try arena.create(InternalState);
        \\    const e = try Registry.createIn(instance, runtime.arenaOf(instance));
        \\    const f = try allocator.create(OtherState);
        \\    _ = .{ a, b, c, d, e, f };
        \\}
    , &.{ "3:state-heap-block", "4:state-heap-block" });
    // Not node state: a non-node impl's block has its wrapper's exit.
    try expectFindings("src/webidl/impls/Blob.zig",
        \\fn make(allocator: Allocator) !void { _ = try allocator.create(InternalState); }
    , &.{});
}

test "state-no-sweep: an InternalState that frees anything needs a sweep; a no-op deinit owns nothing" {
    const frees =
        \\pub const InternalState = struct {
        \\    allocator: Allocator,
        \\    name: []u8,
        \\    pub fn deinit(self: *InternalState) void {
        \\        self.allocator.free(self.name);
        \\    }
        \\};
    ;
    // The default: a node type's state that owns something has no exit for
    // an orphan until its file installs a sweep.
    try expectFindings("src/webidl/impls/HTMLNewElement.zig", frees, &.{"4:state-no-sweep"});
    try expectFindings("src/webidl/impls/HTMLNewElement.zig", frees ++
        \\
        \\pub fn installHooks() void { States.installSweep(); }
    , &.{});
    try expectFindings("src/webidl/impls/HTMLNewElement.zig", frees ++
        \\
        \\pub fn installHooks() void { dom.orphan_states.installRegistrySweep(Registry); }
    , &.{});
    try expectFindings("src/webidl/impls/HTMLNewElement.zig", frees ++
        \\
        \\pub fn installHooks() void { dom.teardown_sweeps.install(.element_types, &sweep); }
    , &.{});
    // A deinit that frees nothing - empty, or only discards - is not a
    // reason to sweep.
    try expectFindings("src/webidl/impls/HTMLAnchorLikeElement.zig",
        \\pub const InternalState = struct {
        \\    rel_list: ?*Instance = null,
        \\    pub fn deinit(self: *InternalState) void {
        \\        _ = self;
        \\    }
        \\};
        \\const Other = struct { pub fn deinit(self: *Other) void {} };
    , &.{});
    try expectFindings("src/webidl/impls/HTMLNewElement.zig",
        \\pub const InternalState = struct { pub fn deinit(_: *InternalState) void {} };
    , &.{});
    // Only a node's InternalState: another container's deinit is not one.
    try expectFindings("src/webidl/impls/HTMLNewElement.zig",
        \\const Cache = struct { list: []u8, pub fn deinit(self: *Cache) void { gpa.free(self.list); } };
    , &.{});
    try expectFindings("src/webidl/impls/Range.zig", frees, &.{});
}

test "state rules: test declarations are not production code" {
    try expectFindings("src/webidl/impls/HTMLNewElement.zig",
        \\test "a heap block in a test" {
        \\    _ = try std.testing.allocator.create(InternalState);
        \\}
    , &.{});
}

test "which impls are node state" {
    try testing.expect(isNodeStateFile("src/webidl/impls/Node.zig"));
    try testing.expect(isNodeStateFile("src/webidl/impls/Element.zig"));
    try testing.expect(isNodeStateFile("src/webidl/impls/HTMLInputElement.zig"));
    try testing.expect(isNodeStateFile("src/webidl/impls/SVGSVGElement.zig"));
    try testing.expect(isNodeStateFile("src/webidl/impls/Document.zig"));
    try testing.expect(isNodeStateFile("src/webidl/impls/ShadowRoot.zig"));
    try testing.expect(!isNodeStateFile("src/webidl/impls/MutationRecord.zig"));
    try testing.expect(!isNodeStateFile("src/webidl/impls/NodeList.zig"));
    try testing.expect(!isNodeStateFile("src/webidl/impls/NodeIterator.zig"));
    try testing.expect(!isNodeStateFile("src/webidl/impls/Range.zig"));
    try testing.expect(!isNodeStateFile("src/webidl/interfaces/Element.zig"));
}

test "a file that does not parse is an error, not a pass" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    try testing.expectError(error.ParseError, findings(arena.allocator(), "src/dom/x.zig", "const = ;"));
}

test "a violation is any key above its baseline, including a key the baseline lacks (a swap)" {
    var current: Counts = .empty;
    defer current.deinit(testing.allocator);
    var baseline: Counts = .empty;
    defer baseline.deinit(testing.allocator);
    try baseline.put(testing.allocator, "a.zig parent-write", 2);
    try current.put(testing.allocator, "a.zig parent-write", 1); // paid down
    try current.put(testing.allocator, "b.zig parent-write", 1); // the same total, moved
    try baseline.put(testing.allocator, "c.zig parent-write", 1);
    try current.put(testing.allocator, "c.zig parent-write", 2); // grown

    var found = try violations(testing.allocator, &current, &baseline);
    defer found.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 2), found.items.len);
    try testing.expectEqualStrings("b.zig parent-write", found.items[0].key);
    try testing.expectEqual(@as(u32, 0), found.items[0].allowed);
    try testing.expectEqualStrings("c.zig parent-write", found.items[1].key);
    try testing.expectEqual(@as(u32, 1), found.items[1].allowed);
}

test "the baseline round-trips, sorted, and ignores comments" {
    var counts: Counts = .empty;
    defer counts.deinit(testing.allocator);
    try counts.put(testing.allocator, "src/b.zig parent-write", 2);
    try counts.put(testing.allocator, "src/a.zig ref-in-node-state.State.x", 1);
    const text = try formatBaseline(testing.allocator, &counts);
    defer testing.allocator.free(text);
    try testing.expect(std.mem.indexOf(u8, text, "src/a.zig ref-in-node-state.State.x 1\nsrc/b.zig parent-write 2\n") != null);
    var parsed = try parseBaseline(testing.allocator, text);
    defer {
        var it = parsed.keyIterator();
        while (it.next()) |key| testing.allocator.free(key.*);
        parsed.deinit(testing.allocator);
    }
    try testing.expectEqual(@as(u32, 2), parsed.get("src/b.zig parent-write").?);
    try testing.expectEqual(@as(u32, 2), parsed.count());
}
