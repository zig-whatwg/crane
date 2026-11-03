//! Global state, as a ratchet: `zig build lint-global-state` (and so `zig build
//! test`) fails when src/ holds a process-global or threadlocal mutable
//! variable that tools/global_state_baseline.txt does not record.
//!
//! docs/instances.md: Crane runs several isolated instances (Browsers) in one
//! process, each with its tabs. A container-level `var` is shared by every
//! instance; a `threadlocal` is per thread, which is neither per instance nor
//! per tab (docs/lessons/architecture-a-threadlocal-is-per-thread-not-per-instance-or-tab.md).
//! New state belongs to its owner - the Browser, the Tab, the agent, the realm
//! - reached through the realm the code runs in, never to a global.
//!
//! What is counted:
//!   * src/**/*.zig, through std.zig.Ast (not lines): every container-level
//!     `var` - `threadlocal`, `pub`, `export`, and function statics (a `var`
//!     in a `struct { ... }` inside a function) - that is not inside a `test`
//!     declaration. A local `var` in a function body is not container-level
//!     and is not counted; nor is any `const`.
//!   * src/**/*.cpp and src/**/*.h, with a scan of the code (comments,
//!     strings and preprocessor lines blanked, braces tracked): namespace-scope
//!     variable definitions (`static` or not), function-static `static` /
//!     `thread_local` variables, and out-of-class static member definitions
//!     (`T Class::member_ = ...;`). In-class `static` member declarations are
//!     not definitions and are not counted (their definition is). `constexpr`
//!     and `const` objects are not counted; `const char* p` is (the pointer is
//!     mutable). There is no C++ parser to hand: a namespace-scope variable
//!     initialised with a lambda body, or a second declarator after a comma,
//!     is not seen.
//!
//! Key: `path qualified.name` - the name qualified by its enclosing containers
//! and functions (`Arena.global`, `getDefault.State.value`,
//! `armedWeakData.map`). The kind (TL, G, C++ G, C++ TL) is reported but is not
//! part of the key, so turning a threadlocal hook into a process variable
//! written once at start-up is not an increase. A count per key, not a total,
//! is what catches a swap: trading one variable for a new one leaves the total
//! unchanged.
//!
//! The baseline records, per key, its count, kind and class - the class from
//! tmp/plans/instances-inventory.md (P-const, P-res, H, I/profile, I/engine,
//! A, T, R, C, D, X; `?` unclassified), as documentation of where the variable
//! is going. The baseline only goes down. After removing variables:
//!     zig build lint-global-state -- --update
//! which keeps each surviving key's class and refuses to record an increase.

const std = @import("std");
// stdout as a stream: Zig 0.17's positional File.writer overwrites a shared log.
const stdout_stream = @import("stdout_stream.zig");

const baseline_path = "tools/global_state_baseline.txt";

/// The tree held to the rule.
const scanned_root = "src";

/// Not built: codegen's stubs for hand merging.
const exempt_prefixes = [_][]const u8{"src/webidl/impls_tmp/"};

pub const Language = enum { zig, cpp };

/// Which scanner a repo-relative `/`-separated path gets, if any.
pub fn languageOf(path: []const u8) ?Language {
    if (!std.mem.startsWith(u8, path, scanned_root ++ "/")) return null;
    if (std.mem.indexOf(u8, path, ".zig-cache/") != null) return null;
    for (exempt_prefixes) |prefix| if (std.mem.startsWith(u8, path, prefix)) return null;
    if (std.mem.endsWith(u8, path, ".zig")) return .zig;
    for ([_][]const u8{ ".cpp", ".cc", ".h", ".hpp" }) |ext| {
        if (std.mem.endsWith(u8, path, ext)) return .cpp;
    }
    return null;
}

pub const Kind = enum {
    /// Zig `threadlocal var`.
    zig_threadlocal,
    /// Zig container-level `var`.
    zig_global,
    /// C++ static storage: namespace scope, function static, static member.
    cpp_static,
    /// C++ `thread_local`.
    cpp_thread_local,

    pub fn label(kind: Kind) []const u8 {
        return switch (kind) {
            .zig_threadlocal => "TL",
            .zig_global => "G",
            .cpp_static => "C++G",
            .cpp_thread_local => "C++TL",
        };
    }
};

/// One mutable variable with static or thread storage.
pub const Variable = struct {
    line: u32,
    /// Qualified by its enclosing containers and functions.
    name: []const u8,
    kind: Kind,
    /// The why of a reviewed marker line - `// process-wide: <why>` or
    /// `// per-thread: <why>` - directly above the declaration, if it has
    /// one (`markAbove`), and which marker it is.
    why: ?[]const u8 = null,
    marker: ?Marker = null,
    /// Whether the declaration is a hook slot (`Hook(..)`, by its type), and
    /// what is wrong with it if so. Zig only.
    hook: HookCheck = .none,
    /// `declHash` of the declaration with its name taken out: its type and
    /// initialiser. A rename keeps it (`checkRename`).
    decl_hash: u64 = 0,
};

/// A hash of declaration text, whitespace left out, so a rename can be
/// told from a swap: the same type and initialiser under a new name.
pub fn declHash(parts: []const []const u8) u64 {
    var hasher = std.hash.Wyhash.init(0);
    for (parts) |part| {
        for (part) |c| {
            if (!std.ascii.isWhitespace(c)) hasher.update(&.{c});
        }
        hasher.update("\x00");
    }
    return hasher.final();
}

fn nodeText(tree: *const std.zig.Ast, node: std.zig.Ast.Node.OptionalIndex) []const u8 {
    const n = node.unwrap() orelse return "";
    const start = tree.tokenStart(tree.firstToken(n));
    const last = tree.lastToken(n);
    const end = tree.tokenStart(last) + tree.tokenSlice(last).len;
    return tree.source[start..end];
}

/// The marker a variable that genuinely belongs to the process carries on the
/// line directly above its declaration (design 6.4: the end state's ~50
/// process-wide variables each say why). `--update` records a key the
/// baseline lacks only when every declaration under it carries one.
const process_wide_marker = "// process-wide:";

/// The marker state that genuinely is one per THREAD carries instead: a
/// Zig `threadlocal` or C++ `thread_local` whose owner is the thread - a
/// call-stack extent (what is running on this thread's stack), an engine's
/// own thread-local, or the like. The why says what makes the thread the
/// right scope. Valid only on threadlocals, as `// process-wide:` is valid
/// only on container-level variables and C++ globals (the integrator,
/// 2026-11-02: a reviewer must be able to list per-thread state on its own,
/// and "process-wide" on per-thread state is false documentation).
const per_thread_marker = "// per-thread:";

/// The two reviewed markers.
pub const Marker = enum {
    process_wide,
    per_thread,

    pub fn text(marker: Marker) []const u8 {
        return switch (marker) {
            .process_wide => process_wide_marker,
            .per_thread => per_thread_marker,
        };
    }

    /// The marker a declaration of `kind` must carry when it is not a hook
    /// slot.
    pub fn of(kind: Kind) Marker {
        return switch (kind) {
            .zig_global, .cpp_static => .process_wide,
            .zig_threadlocal, .cpp_thread_local => .per_thread,
        };
    }
};

pub const Mark = struct { marker: Marker, why: []const u8 };

/// The reviewed marker line - `// process-wide: <why>` or `// per-thread:
/// <why>` with a non-empty why - directly above line `line` (1-based) of
/// `source`, or null. A blank line, a doc comment or any other line in
/// between breaks it.
pub fn markAbove(source: []const u8, line: u32) ?Mark {
    if (line < 2) return null;
    var lines = std.mem.splitScalar(u8, source, '\n');
    var at: u32 = 1;
    while (lines.next()) |text| : (at += 1) {
        if (at != line - 1) continue;
        const trimmed = std.mem.trim(u8, text, " \t\r");
        inline for (.{ Marker.process_wide, Marker.per_thread }) |marker| {
            if (std.mem.startsWith(u8, trimmed, comptime marker.text())) {
                const why = std.mem.trim(u8, trimmed[comptime marker.text().len..], " \t");
                return if (why.len == 0) null else .{ .marker = marker, .why = why };
            }
        }
        return null;
    }
    return null;
}

/// The why of a `// process-wide: <why>` line directly above line `line`.
pub fn processWideWhy(source: []const u8, line: u32) ?[]const u8 {
    const mark = markAbove(source, line) orelse return null;
    return if (mark.marker == .process_wide) mark.why else null;
}

// ============================================================================
// Hook slots: the frozen-after-start slot type, recognised by its type
// ============================================================================

/// A hook slot is a container-level `var` whose type is a call of `Hook`
/// from the hook module (src/process/hook.zig, the `process` module's,
/// which src/dom/hook.zig re-exports), initialised with `.init(<expr>)` (lane hookfreeze1's proposal,
/// tmp/plans/hookfreeze-design.md "Lint"): its type freezes it after the
/// process start, so it is not debt and needs no marker - it is class H by
/// type. What a hook slot still must not be:
pub const HookCheck = enum {
    /// Not a hook slot.
    none,
    /// A hook slot, as the rule asks.
    slot,
    /// A `threadlocal` Hook: a hook is process-wide.
    threadlocal_hook,
    /// A Hook in src/webidl/impls/: a hook lives in its src/dom (or
    /// subsystem) module, which the owning impl installs into.
    in_impls,
    /// Its `value` or `overrides` assigned or taken by address in its file
    /// - the bypass of install()/installing()/overrideForTest().
    written_directly,
    /// Of the Hook type, but not initialised with `.init(<expr>)`.
    not_initialised,
};

/// A name an expression resolves to: an `@import`'s string, then fields.
const ImportPath = struct {
    import: []const u8,
    fields: [3][]const u8 = undefined,
    len: usize = 0,

    fn push(self: *ImportPath, field: []const u8) bool {
        if (self.len == self.fields.len) return false;
        self.fields[self.len] = field;
        self.len += 1;
        return true;
    }

    fn is(self: ImportPath, import: []const u8, fields: []const []const u8) bool {
        if (!std.mem.eql(u8, self.import, import) or self.len != fields.len) return false;
        for (self.fields[0..self.len], fields) |a, b| if (!std.mem.eql(u8, a, b)) return false;
        return true;
    }
};

const Aliases = std.StringHashMapUnmanaged(std.zig.Ast.Node.Index);

/// What `node` names, through the file's top-level `const` aliases: an
/// `@import("x")` and the fields reached from it. Null for anything else.
fn resolveImportPath(tree: *const std.zig.Ast, aliases: *const Aliases, node: std.zig.Ast.Node.Index, depth: u32) ?ImportPath {
    if (depth > 8) return null;
    switch (tree.nodeTag(node)) {
        .identifier => {
            const target = aliases.get(tree.tokenSlice(tree.nodeMainToken(node))) orelse return null;
            return resolveImportPath(tree, aliases, target, depth + 1);
        },
        .field_access => {
            const lhs, const field = tree.nodeData(node).node_and_token;
            var path = resolveImportPath(tree, aliases, lhs, depth + 1) orelse return null;
            if (!path.push(tree.tokenSlice(field))) return null;
            return path;
        },
        .builtin_call_two, .builtin_call_two_comma => {
            if (!std.mem.eql(u8, tree.tokenSlice(tree.nodeMainToken(node)), "@import")) return null;
            var buf: [2]std.zig.Ast.Node.Index = undefined;
            const params = tree.builtinCallParams(&buf, node) orelse return null;
            if (params.len != 1 or tree.nodeTag(params[0]) != .string_literal) return null;
            const literal = tree.tokenSlice(tree.nodeMainToken(params[0]));
            if (literal.len < 2) return null;
            return .{ .import = literal[1 .. literal.len - 1] };
        },
        else => return null,
    }
}

/// Whether `path`, named in the file at `file`, is the Hook type: `Hook` of
/// the `dom` module (`@import("dom").Hook`), of the `process` module
/// (`@import("process").Hook` or `.hook.Hook`), or of `hook.zig` imported
/// from a file of src/dom or src/process - the hook module's own directory.
pub fn isHookPath(file: []const u8, path: ImportPath) bool {
    if (path.is("dom", &.{"Hook"})) return true;
    if (path.is("process", &.{"Hook"}) or path.is("process", &.{ "hook", "Hook" })) return true;
    if (path.is("hook.zig", &.{"Hook"})) {
        return std.mem.startsWith(u8, file, "src/dom/") or std.mem.startsWith(u8, file, "src/process/");
    }
    return false;
}

/// The file's top-level `const` declarations: alias name -> initialiser.
fn topLevelAliases(gpa: std.mem.Allocator, tree: *const std.zig.Ast) !Aliases {
    var aliases: Aliases = .empty;
    errdefer aliases.deinit(gpa);
    for (tree.rootDecls()) |decl| {
        const vd = tree.fullVarDecl(decl) orelse continue;
        if (!std.mem.eql(u8, tree.tokenSlice(vd.ast.mut_token), "const")) continue;
        const init_node = vd.ast.init_node.unwrap() orelse continue;
        try aliases.put(gpa, tree.tokenSlice(vd.ast.mut_token + 1), init_node);
    }
    return aliases;
}

/// What a container-level `var` declaration is, as a hook slot.
fn hookCheckOf(tree: *const std.zig.Ast, aliases: *const Aliases, file: []const u8, vd: std.zig.Ast.full.VarDecl) HookCheck {
    const type_node = vd.ast.type_node.unwrap() orelse return .none;
    var buf: [1]std.zig.Ast.Node.Index = undefined;
    const call = tree.fullCall(&buf, type_node) orelse return .none;
    const path = resolveImportPath(tree, aliases, call.ast.fn_expr, 0) orelse return .none;
    if (!isHookPath(file, path)) return .none;
    if (vd.threadlocal_token != null) return .threadlocal_hook;
    if (std.mem.startsWith(u8, file, "src/webidl/impls/")) return .in_impls;
    const init_node = vd.ast.init_node.unwrap() orelse return .not_initialised;
    var init_buf: [1]std.zig.Ast.Node.Index = undefined;
    const init_call = tree.fullCall(&init_buf, init_node) orelse return .not_initialised;
    const callee = init_call.ast.fn_expr;
    if (tree.nodeTag(callee) != .enum_literal or !std.mem.eql(u8, tree.tokenSlice(tree.nodeMainToken(callee)), "init")) return .not_initialised;
    return .slot;
}

/// The last name of an access chain: `a` for `a`, `b` for `a.b`.
fn lastName(tree: *const std.zig.Ast, node: std.zig.Ast.Node.Index) ?[]const u8 {
    return switch (tree.nodeTag(node)) {
        .identifier => tree.tokenSlice(tree.nodeMainToken(node)),
        .field_access => tree.tokenSlice(tree.nodeData(node).node_and_token[1]),
        else => null,
    };
}

/// The slot whose `value` or `overrides` the place `node` names - an
/// assignment's left side, an `&`'s operand - reaches through, if any
/// (`slot.value = x`, `slot.value.field = x`, `&slot.overrides`,
/// `Outer.slot.value = x`): the slot's last name, one of `slots`.
fn slotFieldWritten(tree: *const std.zig.Ast, node: std.zig.Ast.Node.Index, slots: []const []const u8) ?[]const u8 {
    var at = node;
    while (true) {
        switch (tree.nodeTag(at)) {
            .field_access => {
                const lhs, const field = tree.nodeData(at).node_and_token;
                const name = tree.tokenSlice(field);
                if (std.mem.eql(u8, name, "value") or std.mem.eql(u8, name, "overrides")) {
                    if (lastName(tree, lhs)) |slot| {
                        for (slots) |s| if (std.mem.eql(u8, s, slot)) return s;
                    }
                }
                at = lhs;
            },
            .unwrap_optional => at = tree.nodeData(at).node_and_token[0],
            .array_access => at = tree.nodeData(at).node_and_node[0],
            .deref => at = tree.nodeData(at).node,
            else => return null,
        }
    }
}

/// The last names of the slots of `slots` whose `value`/`overrides` the
/// file writes or takes by address.
fn slotsWrittenDirectly(gpa: std.mem.Allocator, tree: *const std.zig.Ast, slots: []const []const u8) !std.ArrayList([]const u8) {
    var out: std.ArrayList([]const u8) = .empty;
    errdefer out.deinit(gpa);
    if (slots.len == 0) return out;
    var i: u32 = 0;
    while (i < tree.nodes.len) : (i += 1) {
        const node: std.zig.Ast.Node.Index = @fromBackingInt(@intCast(i));
        const tag = tree.nodeTag(node);
        const place: std.zig.Ast.Node.Index = switch (tag) {
            .address_of => tree.nodeData(node).node,
            .assign_destructure => continue,
            else => if (std.mem.startsWith(u8, @tagName(tag), "assign")) tree.nodeData(node).node_and_node[0] else continue,
        };
        if (slotFieldWritten(tree, place, slots)) |slot| try out.append(gpa, slot);
    }
    return out;
}

// ============================================================================
// Zig: std.zig.Ast
// ============================================================================

/// A token range with a name: a container's `const Name = ...`, a function.
const Named = struct { first: u32, last: u32, name: []const u8 };

/// Every container-level `var` of `source` outside test declarations, in
/// source order. Names are allocated with `gpa`. A file that does not parse is
/// an error: a file the ratchet cannot read must not pass silently.
pub fn zigVariables(gpa: std.mem.Allocator, source: [:0]const u8) !std.ArrayList(Variable) {
    return zigVariablesIn(gpa, "src/file.zig", source);
}

/// `zigVariables` for the file at `file` (repo-relative): where a hook slot
/// may live and what its relative imports name depend on it.
pub fn zigVariablesIn(gpa: std.mem.Allocator, file: []const u8, source: [:0]const u8) !std.ArrayList(Variable) {
    var tree = try std.zig.Ast.parse(gpa, source, .{ .mode = .zig });
    defer tree.deinit(gpa);
    if (tree.errors.len > 0) return error.ParseError;
    var aliases = try topLevelAliases(gpa, &tree);
    defer aliases.deinit(gpa);

    var named: std.ArrayList(Named) = .empty;
    defer named.deinit(gpa);
    var tests: std.ArrayList([2]u32) = .empty;
    defer tests.deinit(gpa);

    // 1. The ranges that qualify a name, and the test declarations.
    const node_count = tree.nodes.len;
    var i: u32 = 0;
    while (i < node_count) : (i += 1) {
        const node: std.zig.Ast.Node.Index = @fromBackingInt(@intCast(i));
        switch (tree.nodeTag(node)) {
            .test_decl => try tests.append(gpa, .{ tree.firstToken(node), tree.lastToken(node) }),
            .fn_decl => {
                const fn_token = tree.nodeMainToken(node);
                if (tree.tokenTag(fn_token + 1) != .identifier) continue;
                try named.append(gpa, .{
                    .first = tree.firstToken(node),
                    .last = tree.lastToken(node),
                    .name = tree.tokenSlice(fn_token + 1),
                });
            },
            else => if (tree.fullVarDecl(node)) |vd| {
                // Only a declaration with an initialiser can hold a container.
                if (vd.ast.init_node == .none) continue;
                try named.append(gpa, .{
                    .first = tree.firstToken(node),
                    .last = tree.lastToken(node),
                    .name = tree.tokenSlice(vd.ast.mut_token + 1),
                });
            },
        }
    }

    // 2. Every container's `var` members.
    var out: std.ArrayList(Variable) = .empty;
    errdefer {
        for (out.items) |v| gpa.free(v.name);
        out.deinit(gpa);
    }
    i = 0;
    while (i < node_count) : (i += 1) {
        const node: std.zig.Ast.Node.Index = @fromBackingInt(@intCast(i));
        var buf: [2]std.zig.Ast.Node.Index = undefined;
        const container = tree.fullContainerDecl(&buf, node) orelse continue;
        members: for (container.ast.members) |member| {
            const vd = tree.fullVarDecl(member) orelse continue;
            if (!std.mem.eql(u8, tree.tokenSlice(vd.ast.mut_token), "var")) continue;
            const first = tree.firstToken(member);
            for (tests.items) |range| {
                if (first >= range[0] and first <= range[1]) continue :members;
            }
            const name = try qualify(gpa, named.items, first, tree.lastToken(member), tree.tokenSlice(vd.ast.mut_token + 1));
            errdefer gpa.free(name);
            const line: u32 = @intCast(tree.tokenLocation(0, first).line + 1);
            const mark = markAbove(source, line);
            try out.append(gpa, .{
                .line = line,
                .why = if (mark) |m| m.why else null,
                .marker = if (mark) |m| m.marker else null,
                .hook = hookCheckOf(&tree, &aliases, file, vd),
                .decl_hash = declHash(&.{ nodeText(&tree, vd.ast.type_node), nodeText(&tree, vd.ast.init_node) }),
                .name = name,
                .kind = if (vd.threadlocal_token != null) .zig_threadlocal else .zig_global,
            });
        }
    }
    std.mem.sort(Variable, out.items, {}, variableLessThan);

    // 3. A slot whose fields the file writes is no slot: install() is the
    // only writer.
    var slot_names: std.ArrayList([]const u8) = .empty;
    defer slot_names.deinit(gpa);
    for (out.items) |v| {
        if (v.hook == .slot) try slot_names.append(gpa, v.name[if (std.mem.lastIndexOfScalar(u8, v.name, '.')) |dot| dot + 1 else 0..]);
    }
    var written = try slotsWrittenDirectly(gpa, &tree, slot_names.items);
    defer written.deinit(gpa);
    for (out.items) |*v| {
        if (v.hook != .slot) continue;
        const last = v.name[if (std.mem.lastIndexOfScalar(u8, v.name, '.')) |dot| dot + 1 else 0..];
        for (written.items) |w| {
            if (std.mem.eql(u8, w, last)) v.hook = .written_directly;
        }
    }
    return out;
}

fn variableLessThan(_: void, a: Variable, b: Variable) bool {
    return a.line < b.line;
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

// ============================================================================
// C++: a scan of the code
// ============================================================================

/// `text` with comments, string and character literals and preprocessor lines
/// replaced by spaces - quotes kept, newlines kept, so offsets and line
/// numbers are the source's.
fn blankNonCode(gpa: std.mem.Allocator, text: []const u8) ![]u8 {
    const out = try gpa.dupe(u8, text);
    var i: usize = 0;
    var line_start = true;
    while (i < out.len) {
        const c = out[i];
        if (c == '\n') {
            line_start = true;
            i += 1;
            continue;
        }
        if (line_start and (c == ' ' or c == '\t' or c == '\r')) {
            i += 1;
            continue;
        }
        if (line_start and c == '#') {
            // A preprocessor line, with its `\` continuations.
            while (i < out.len and out[i] != '\n') {
                if (out[i] == '\\' and i + 1 < out.len and out[i + 1] == '\n') {
                    out[i] = ' ';
                    i += 2;
                    continue;
                }
                out[i] = ' ';
                i += 1;
            }
            continue;
        }
        line_start = false;
        if (c == '/' and i + 1 < out.len and out[i + 1] == '/') {
            while (i < out.len and out[i] != '\n') : (i += 1) out[i] = ' ';
            continue;
        }
        if (c == '/' and i + 1 < out.len and out[i + 1] == '*') {
            out[i] = ' ';
            out[i + 1] = ' ';
            i += 2;
            while (i < out.len and !(out[i] == '*' and i + 1 < out.len and out[i + 1] == '/')) : (i += 1) {
                if (out[i] != '\n') out[i] = ' ';
            }
            if (i < out.len) {
                out[i] = ' ';
                if (i + 1 < out.len) out[i + 1] = ' ';
                i += 2;
            }
            continue;
        }
        if (c == 'R' and i + 1 < out.len and out[i + 1] == '"' and (i == 0 or !isIdentChar(out[i - 1]))) {
            // A raw string: R"delim( ... )delim"
            const open = std.mem.indexOfScalarPos(u8, out, i + 2, '(') orelse return out;
            const delim = text[i + 2 .. open];
            var close = open + 1;
            while (close < out.len) : (close += 1) {
                if (out[close] == ')' and std.mem.startsWith(u8, text[close + 1 ..], delim) and
                    close + 1 + delim.len < out.len and text[close + 1 + delim.len] == '"') break;
            }
            var j = i + 2;
            const end = @min(close + 1 + delim.len, out.len);
            while (j < end) : (j += 1) {
                if (out[j] != '\n') out[j] = ' ';
            }
            i = end + 1;
            continue;
        }
        if (c == '"' or (c == '\'' and !(i > 0 and std.ascii.isHex(out[i - 1]) and i + 1 < out.len and std.ascii.isHex(out[i + 1])))) {
            // A literal; a `'` between hex digits is a digit separator.
            const quote = c;
            i += 1;
            while (i < out.len and out[i] != quote and out[i] != '\n') : (i += 1) {
                if (out[i] == '\\' and i + 1 < out.len) {
                    out[i] = ' ';
                    i += 1;
                }
                out[i] = ' ';
            }
            i += 1;
            continue;
        }
        i += 1;
    }
    return out;
}

fn isIdentChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

const ScopeKind = enum { namespace, class, function, block };
const Scope = struct { kind: ScopeKind, name: []const u8 };

/// Whether `word` appears in `text` as a whole word.
fn hasWord(text: []const u8, word: []const u8) bool {
    var from: usize = 0;
    while (std.mem.indexOfPos(u8, text, from, word)) |at| {
        from = at + 1;
        const before_ok = at == 0 or !isIdentChar(text[at - 1]);
        const after = at + word.len;
        const after_ok = after >= text.len or !isIdentChar(text[after]);
        if (before_ok and after_ok) return true;
    }
    return false;
}

fn startsWithWord(text: []const u8, word: []const u8) bool {
    return std.mem.startsWith(u8, text, word) and (text.len == word.len or !isIdentChar(text[word.len]));
}

/// The index of the first `needle` outside (), [] and <> nesting, if any.
fn topLevelIndex(text: []const u8, needle: u8) ?usize {
    var depth: i32 = 0;
    for (text, 0..) |c, at| {
        if (c == needle and depth == 0) return at;
        switch (c) {
            '(', '[' => depth += 1,
            ')', ']' => depth -= 1,
            else => {},
        }
    }
    return null;
}

/// Whether the parentheses of `text` balance.
fn parensBalanced(text: []const u8) bool {
    var depth: i32 = 0;
    for (text) |c| switch (c) {
        '(' => depth += 1,
        ')' => depth -= 1,
        else => {},
    };
    return depth == 0;
}

/// A top-level `=` that is an assignment or initialiser, not `==`, `<=`,
/// `operator=` or inside parentheses.
fn hasInitializerEquals(text: []const u8) bool {
    var depth: i32 = 0;
    for (text, 0..) |c, at| {
        switch (c) {
            '(', '[' => depth += 1,
            ')', ']' => depth -= 1,
            '=' => if (depth == 0) {
                const prev: u8 = if (at > 0) text[at - 1] else ' ';
                const next: u8 = if (at + 1 < text.len) text[at + 1] else ' ';
                if (next == '=' or prev == '=' or prev == '!' or prev == '<' or prev == '>') continue;
                if (std.mem.endsWith(u8, std.mem.trimEnd(u8, text[0..at], " \t\r\n"), "operator")) continue;
                return true;
            },
            else => {},
        }
    }
    return false;
}

/// What a `{` opens, given the statement text before it.
const Brace = union(enum) { scope: Scope, initializer };

fn classifyBrace(head_raw: []const u8, inside_function: bool) Brace {
    const head = std.mem.trim(u8, head_raw, " \t\r\n");
    if (head.len == 0) return .{ .scope = .{ .kind = .block, .name = "" } };
    if (startsWithWord(head, "namespace") or isLinkageBlock(head)) {
        return .{ .scope = .{ .kind = .namespace, .name = "" } };
    }
    if (hasInitializerEquals(head) or !parensBalanced(head)) return .initializer;
    if (hasWord(head, "enum")) return .{ .scope = .{ .kind = .block, .name = "" } };
    if (!hasWord(head, "operator") and !endsWithCall(head)) {
        for ([_][]const u8{ "class", "struct", "union" }) |keyword| {
            if (classNameAfter(head, keyword)) |name| return .{ .scope = .{ .kind = .class, .name = name } };
        }
    }
    // A constructor with member initialisers: `Foo::Foo(int x) : a_(x), b_{y}`.
    if (!inside_function and (head[head.len - 1] == ')' or head[head.len - 1] == '}') and hasInitializerList(head)) {
        return .{ .scope = .{ .kind = .function, .name = functionName(head) } };
    }
    const last = head[head.len - 1];
    if (last == ':' or last == ';') return .{ .scope = .{ .kind = .block, .name = "" } };
    for ([_][]const u8{ "else", "do", "try" }) |keyword| {
        if (std.mem.endsWith(u8, head, keyword) and (head.len == keyword.len or !isIdentChar(head[head.len - keyword.len - 1]))) {
            return .{ .scope = .{ .kind = .block, .name = "" } };
        }
    }
    if (endsWithCall(head)) {
        if (inside_function) return .{ .scope = .{ .kind = .block, .name = "" } };
        return .{ .scope = .{ .kind = .function, .name = functionName(head) } };
    }
    // `T name{...}`, `return {...}`, `Type{...}`, `[&] {...}`.
    return .initializer;
}

/// `extern "C"` with nothing after the string: a linkage block, not a
/// function definition with C linkage.
fn isLinkageBlock(head: []const u8) bool {
    if (!startsWithWord(head, "extern")) return false;
    const rest = std.mem.trim(u8, head["extern".len..], " \t\r\n");
    if (rest.len < 2 or rest[0] != '"') return false;
    const close = std.mem.indexOfScalarPos(u8, rest, 1, '"') orelse return false;
    return std.mem.trim(u8, rest[close + 1 ..], " \t\r\n").len == 0;
}

/// The name after a class-key, if `head` has one as a word: `class Foo : public
/// Base` -> "Foo". An anonymous class gives "".
fn classNameAfter(head: []const u8, keyword: []const u8) ?[]const u8 {
    var from: usize = 0;
    while (std.mem.indexOfPos(u8, head, from, keyword)) |at| {
        from = at + 1;
        if (at > 0 and isIdentChar(head[at - 1])) continue;
        const after = at + keyword.len;
        if (after < head.len and isIdentChar(head[after])) continue;
        const rest = std.mem.trimStart(u8, head[after..], " \t\r\n");
        var end: usize = 0;
        while (end < rest.len and isIdentChar(rest[end])) end += 1;
        return rest[0..end];
    }
    return null;
}

/// A `)` followed by a single `:` at paren depth zero.
fn hasInitializerList(head: []const u8) bool {
    var depth: i32 = 0;
    var last_close: ?usize = null;
    for (head, 0..) |c, at| {
        switch (c) {
            '(' => depth += 1,
            ')' => {
                depth -= 1;
                if (depth == 0) last_close = at;
            },
            ':' => if (depth == 0) {
                const close = last_close orelse continue;
                const between = std.mem.trim(u8, head[close + 1 .. at], " \t\r\n");
                const double = (at + 1 < head.len and head[at + 1] == ':') or (at > 0 and head[at - 1] == ':');
                if (!double and (between.len == 0 or std.mem.eql(u8, between, "noexcept"))) return true;
            },
            else => {},
        }
    }
    return false;
}

/// Whether `head` ends with a parameter list - after `const`, `override`,
/// `noexcept`, a trailing return type or a constructor's initialiser list.
fn endsWithCall(head: []const u8) bool {
    var s = head;
    // A trailing return type: `auto f(...) -> T`.
    if (std.mem.lastIndexOf(u8, s, "->")) |arrow| {
        if (std.mem.indexOfScalar(u8, s[arrow..], ')') == null) s = std.mem.trimEnd(u8, s[0..arrow], " \t\r\n");
    }
    while (true) {
        var stripped = false;
        for ([_][]const u8{ "const", "override", "final", "noexcept", "mutable", "volatile" }) |word| {
            if (std.mem.endsWith(u8, s, word) and (s.len == word.len or !isIdentChar(s[s.len - word.len - 1]))) {
                s = std.mem.trimEnd(u8, s[0 .. s.len - word.len], " \t\r\n");
                stripped = true;
            }
        }
        if (!stripped) break;
    }
    return s.len > 0 and s[s.len - 1] == ')';
}

/// The (possibly `Class::`-qualified) name before a function head's first
/// top-level `(`: `Type Class::method(args)` -> "Class::method".
fn functionName(head: []const u8) []const u8 {
    const paren = topLevelIndex(head, '(') orelse return "";
    return lastIdentifier(std.mem.trimEnd(u8, head[0..paren], " \t\r\n")) orelse "";
}

/// The last identifier of `text`, with any `A::` qualifiers it carries.
fn lastIdentifier(text: []const u8) ?[]const u8 {
    var end = text.len;
    while (end > 0 and !isIdentChar(text[end - 1])) end -= 1;
    if (end == 0) return null;
    var start = end;
    while (start > 0) {
        if (isIdentChar(text[start - 1])) {
            start -= 1;
        } else if (start >= 2 and text[start - 1] == ':' and text[start - 2] == ':' and start >= 3 and isIdentChar(text[start - 3])) {
            start -= 2;
        } else break;
    }
    return text[start..end];
}

/// Statements that are never variable definitions.
const non_variable_heads = [_][]const u8{
    "template", "typedef",   "using",     "friend", "extern",        "return", "class",    "struct",
    "enum",     "union",     "namespace", "goto",   "static_assert", "break",  "continue", "case",
    "default",  "throw",     "delete",    "if",     "for",           "while",  "switch",   "else",
    "do",       "co_return",
};

/// The variable a statement defines, if it defines one with static or thread
/// storage. `scope` is the innermost non-block scope; in a function only
/// `static` and `thread_local` declarations have static storage.
fn statementVariable(stmt_raw: []const u8, in_function: bool) ?struct { name: []const u8, kind: Kind } {
    var stmt = std.mem.trim(u8, stmt_raw, " \t\r\n");
    // Access specifiers and labels before the declaration.
    for ([_][]const u8{ "public:", "private:", "protected:" }) |spec| {
        if (std.mem.startsWith(u8, stmt, spec)) stmt = std.mem.trimStart(u8, stmt[spec.len..], " \t\r\n");
    }
    if (stmt.len == 0) return null;
    for (non_variable_heads) |word| if (startsWithWord(stmt, word)) return null;

    // The declarator part: up to the initialiser.
    var cut = stmt.len;
    if (topLevelIndex(stmt, '=')) |at| cut = @min(cut, at);
    if (topLevelIndex(stmt, '{')) |at| cut = @min(cut, at);
    if (topLevelIndex(stmt, '[')) |at| cut = @min(cut, at);
    const decl = std.mem.trimEnd(u8, stmt[0..cut], " \t\r\n");

    const is_static = hasWord(decl, "static");
    const is_thread_local = hasWord(decl, "thread_local");
    if (in_function and !is_static and !is_thread_local) return null;
    if (hasWord(decl, "constexpr") or hasWord(decl, "consteval")) return null;

    var name: []const u8 = undefined;
    var type_part: []const u8 = undefined;
    if (parenOutsideAngles(decl)) |paren| {
        // A function pointer, `T (*name)(args)`; anything else with a
        // parenthesis is a function declaration or a call.
        var rest = std.mem.trimStart(u8, decl[paren + 1 ..], " \t");
        if (rest.len == 0 or rest[0] != '*') return null;
        rest = std.mem.trimStart(u8, rest[1..], " \t");
        var end: usize = 0;
        while (end < rest.len and isIdentChar(rest[end])) end += 1;
        if (end == 0 or end >= rest.len) return null;
        if (std.mem.trimStart(u8, rest[end..], " \t")[0] != ')') return null;
        name = rest[0..end];
        type_part = decl[0..paren];
    } else {
        name = lastIdentifier(decl) orelse return null;
        type_part = std.mem.trimEnd(u8, decl[0 .. decl.len - name.len], " \t\r\n");
        // A type and a name: a lone identifier is an expression, a label, or
        // `} name;` after a class body (not seen).
        var has_type = false;
        for (type_part) |c| {
            if (isIdentChar(c)) has_type = true;
        }
        if (!has_type) return null;
        // A reference binds an object; it holds no state of its own here.
        if (std.mem.endsWith(u8, type_part, "&")) return null;
    }
    // `const` qualifies the object when it follows the last `*`, or when there
    // is no `*` at all.
    const star = std.mem.lastIndexOfScalar(u8, type_part, '*');
    const after_star = if (star) |at| type_part[at + 1 ..] else type_part;
    if (hasWord(after_star, "const")) return null;
    // Keywords that cannot start a declaration's type.
    for ([_][]const u8{ "new", "sizeof", "co_await", "co_yield" }) |word| if (hasWord(type_part, word)) return null;
    return .{ .name = name, .kind = if (is_thread_local) .cpp_thread_local else .cpp_static };
}

/// The first `(` outside template arguments: `std::function<void(int)> f`
/// has none.
fn parenOutsideAngles(decl: []const u8) ?usize {
    var angles: i32 = 0;
    for (decl, 0..) |c, at| switch (c) {
        '<' => angles += 1,
        '>' => angles -= 1,
        '(' => if (angles == 0) return at,
        else => {},
    };
    return null;
}

/// Every C++ variable with static or thread storage that `text` defines, in
/// source order. Names are allocated with `gpa`.
pub fn cppVariables(gpa: std.mem.Allocator, text: []const u8) !std.ArrayList(Variable) {
    const code = try blankNonCode(gpa, text);
    defer gpa.free(code);

    var out: std.ArrayList(Variable) = .empty;
    errdefer {
        for (out.items) |v| gpa.free(v.name);
        out.deinit(gpa);
    }
    var scopes: std.ArrayList(Scope) = .empty;
    defer scopes.deinit(gpa);

    var stmt_start: usize = 0;
    // A `;` inside parentheses - `for (a; b; c)` - ends no statement.
    var parens: i32 = 0;
    var i: usize = 0;
    while (i < code.len) : (i += 1) {
        const c = code[i];
        switch (c) {
            '(' => parens += 1,
            ')' => parens -= 1,
            '{' => {
                const inside_function = innermostCode(scopes.items) == .function;
                switch (classifyBrace(code[stmt_start..i], inside_function)) {
                    .initializer => {
                        // Part of the statement: skip to the matching `}`.
                        var depth: usize = 1;
                        i += 1;
                        while (i < code.len and depth > 0) : (i += 1) {
                            if (code[i] == '{') depth += 1;
                            if (code[i] == '}') depth -= 1;
                        }
                        i -= 1;
                    },
                    .scope => |scope| {
                        try scopes.append(gpa, scope);
                        stmt_start = i + 1;
                    },
                }
            },
            '}' => {
                _ = scopes.pop();
                stmt_start = i + 1;
                parens = 0;
            },
            ';' => {
                if (parens > 0) continue;
                defer stmt_start = i + 1;
                const where = innermostCode(scopes.items);
                if (where == .class) continue;
                const found = statementVariable(code[stmt_start..i], where == .function) orelse continue;
                var name: std.ArrayList(u8) = .empty;
                errdefer name.deinit(gpa);
                for (scopes.items) |scope| {
                    if (scope.kind != .function and scope.kind != .class) continue;
                    if (scope.name.len == 0) continue;
                    try name.appendSlice(gpa, scope.name);
                    try name.append(gpa, '.');
                }
                try name.appendSlice(gpa, found.name);
                const owned = try name.toOwnedSlice(gpa);
                // The statement with its name taken out (original text: the
                // blanked code has no string contents).
                const name_at = @intFromPtr(found.name.ptr) - @intFromPtr(code.ptr);
                const decl_hash = declHash(&.{ text[stmt_start..name_at], text[name_at + found.name.len .. i] });
                errdefer gpa.free(owned);
                // The line of the statement's first character.
                var first = stmt_start;
                while (first < i and std.ascii.isWhitespace(code[first])) first += 1;
                const line: u32 = @intCast(std.mem.count(u8, text[0..first], "\n") + 1);
                const mark = markAbove(text, line);
                try out.append(gpa, .{ .line = line, .name = owned, .kind = found.kind, .why = if (mark) |m| m.why else null, .marker = if (mark) |m| m.marker else null, .decl_hash = decl_hash });
            },
            else => {},
        }
    }
    return out;
}

/// Whether code at this point sits in a namespace, a class body or a
/// function: the innermost scope that is not a plain block.
fn innermostCode(scopes: []const Scope) ScopeKind {
    var at = scopes.len;
    while (at > 0) {
        at -= 1;
        if (scopes[at].kind != .block) return scopes[at].kind;
    }
    return .namespace;
}

// ============================================================================
// The baseline
// ============================================================================

/// What the hard rule finds wrong with one declaration, if anything.
pub const Problem = enum {
    /// Neither a hook slot nor marked: debt.
    unmarked,
    /// `// process-wide:` on a threadlocal (Zig) or thread_local (C++).
    process_wide_on_threadlocal,
    /// `// per-thread:` on a container-level `var` or a C++ global.
    per_thread_on_global,
    /// A `threadlocal` Hook slot.
    threadlocal_hook,
    /// A Hook slot in src/webidl/impls/.
    hook_in_impls,
    /// A Hook slot whose `value`/`overrides` its file writes or takes by
    /// address.
    hook_written_directly,
    /// A Hook slot not initialised with `.init(<expr>)`.
    hook_not_initialised,

    pub fn describe(problem: Problem) []const u8 {
        return switch (problem) {
            .unmarked => "no hook type and no reviewed marker",
            .process_wide_on_threadlocal => "`// process-wide:` on a threadlocal - per-thread state says `// per-thread: <why>`",
            .per_thread_on_global => "`// per-thread:` on a process variable - process state says `// process-wide: <why>`",
            .threadlocal_hook => "a threadlocal Hook slot - a hook is process-wide: `var`, not `threadlocal var`",
            .hook_in_impls => "a Hook slot in src/webidl/impls/ - a hook lives in its src/dom (or subsystem) module",
            .hook_written_directly => "the slot's `value`/`overrides` written or taken by address - write through install(), installing() or overrideForTest()",
            .hook_not_initialised => "a Hook slot not initialised with `.init(<expr>)`",
        };
    }
};

/// The hard rule for one declaration: a hook slot, or a declaration marked
/// with its kind's marker (`Marker.of`), passes; anything else is a problem.
pub fn problemOf(v: Variable) ?Problem {
    switch (v.hook) {
        .slot => return null,
        .threadlocal_hook => return .threadlocal_hook,
        .in_impls => return .hook_in_impls,
        .written_directly => return .hook_written_directly,
        .not_initialised => return .hook_not_initialised,
        .none => {},
    }
    const marker = v.marker orelse return .unmarked;
    if (marker == Marker.of(v.kind)) return null;
    return switch (marker) {
        .process_wide => .process_wide_on_threadlocal,
        .per_thread => .per_thread_on_global,
    };
}

/// What the current tree holds under one key.
pub const Found = struct {
    count: u32,
    kind: Kind,
    /// Hook slots: class H by their type.
    hooks: u32 = 0,
    /// Declarations with neither a hook type nor a reviewed marker (debt).
    unmarked: u32 = 0,
    /// Declarations the hard rule rejects whatever the baseline says: a
    /// marker of the wrong kind, a hook slot breaking the slot's rules.
    misplaced: u32 = 0,
    /// Declarations marked `// per-thread:` (reviewed per-thread state).
    per_thread: u32 = 0,
    /// The declarations' `declHash`es, combined (order does not matter).
    decl: u64 = 0,

    /// Count `variable` under this key.
    pub fn add(self: *Found, variable: Variable) void {
        self.count += 1;
        self.decl +%= variable.decl_hash;
        if (variable.hook == .slot) {
            self.hooks += 1;
            return;
        }
        const problem = problemOf(variable) orelse {
            if (variable.marker == .per_thread) self.per_thread += 1;
            return;
        };
        if (problem == .unmarked) self.unmarked += 1 else self.misplaced += 1;
    }
};

/// Current counts per "path name" key.
pub const Counts = std.StringHashMapUnmanaged(Found);

/// One baseline line: its count and the documentation it carries.
pub const Entry = struct {
    count: u32,
    kind: []const u8,
    class: []const u8,
    /// Found.decl when recorded: what `--rename` compares.
    decl: u64 = 0,
};

pub const Baseline = std.StringHashMapUnmanaged(Entry);

/// Why a key fails.
pub const Reason = enum {
    /// A declaration the hard rule rejects outright (`Found.misplaced`).
    misplaced,
    /// A declaration with neither a hook type nor a marker.
    unmarked,
    /// More reviewed declarations than the inventory records - a new key
    /// included: `--update` records them (the integrator reviews each).
    above_baseline,
};

/// A key that fails, and why.
pub const Violation = struct { key: []const u8, allowed: u32, found: u32, reason: Reason = .above_baseline };

/// How strictly `violations` reads the tree.
pub const Options = struct {
    /// The ratchet the hard rule replaces: a key the baseline records may
    /// keep unmarked declarations, up to its count. True only until every
    /// key is a hook slot or reviewed (`recorded_debt_allowed`).
    allow_recorded_debt: bool = false,
};

/// Whether the hard rule is still transitional: true while the tree still
/// held recorded unmarked keys (classes H and P-res not yet Hook slots, the
/// V8 adapter's C++ statics). Lane gstate4 prepared the rule; lane
/// hookfreeze2 converted the last hook slots and registration lists and
/// gave the process resources left their reviewed lines, leaving 0
/// unmarked, and turned it off (2026-11-03): every container-level `var`
/// and threadlocal is a hook slot or reviewed.
pub const recorded_debt_allowed = false;

fn violationLessThan(_: void, a: Violation, b: Violation) bool {
    return std.mem.lessThan(u8, a.key, b.key);
}

/// Every key in `current` that fails, sorted by key, with the first reason:
/// a misplaced declaration; an unmarked one (unless `options` allows
/// recorded debt and the baseline records the key at least that many
/// times); more declarations than the baseline records (a key absent from
/// it is allowed zero) - except hook slots, which the type alone admits.
pub fn violations(gpa: std.mem.Allocator, current: *const Counts, baseline: *const Baseline, options: Options) !std.ArrayList(Violation) {
    var out: std.ArrayList(Violation) = .empty;
    errdefer out.deinit(gpa);
    var it = current.iterator();
    while (it.next()) |entry| {
        const found = entry.value_ptr.*;
        const recorded = baseline.get(entry.key_ptr.*);
        const allowed = if (recorded) |b| b.count else 0;
        const debt_allowed = options.allow_recorded_debt and recorded != null and found.count <= allowed;
        const reason: ?Reason = if (found.misplaced > 0)
            .misplaced
        else if (found.unmarked > 0 and !debt_allowed)
            .unmarked
        else if (found.count > allowed and found.hooks < found.count)
            .above_baseline
        else
            null;
        if (reason) |r| try out.append(gpa, .{ .key = entry.key_ptr.*, .allowed = allowed, .found = found.count, .reason = r });
    }
    std.mem.sort(Violation, out.items, {}, violationLessThan);
    return out;
}

/// Whether a run may write the baseline: `--update` when nothing is above it.
/// An increase is never recorded.
pub fn mayRecord(update: bool, above_baseline: usize) bool {
    return update and above_baseline == 0;
}

/// The violations `--update` refuses: every misplaced or unmarked
/// declaration. It records reviewed declarations above the inventory - a
/// new key whose every declaration is a hook slot or carries its kind's
/// marker. (The check without --update fails on those too, so a reviewed
/// variable enters the inventory only through a recorded update, which the
/// integrator reviews.)
pub fn refusedByUpdate(gpa: std.mem.Allocator, found: []const Violation) !std.ArrayList(Violation) {
    var out: std.ArrayList(Violation) = .empty;
    errdefer out.deinit(gpa);
    for (found) |v| {
        if (v.reason == .above_baseline) continue;
        try out.append(gpa, v);
    }
    return out;
}

pub const RenameError = error{
    OldKeyNotInBaseline,
    OldKeyStillPresent,
    NewKeyAbsent,
    NewKeyInBaseline,
    DifferentFile,
    DifferentKind,
    DifferentDeclaration,
    DifferentCount,
};

fn pathOf(key: []const u8) []const u8 {
    return key[0 .. std.mem.indexOfScalar(u8, key, ' ') orelse key.len];
}

/// Whether `old_key` -> `new_key` is a rename of the same variable, not a
/// swap: the old key is gone from the tree, the new one is in the tree and
/// not in the baseline, both are in the same file, with the same kind, the
/// same declaration (type and initialiser, `declHash`) and the same count.
/// A move to another file is not a rename: a variable moved is deleted from
/// one place, which lowers the count, and is not recorded in another.
pub fn checkRename(old_key: []const u8, new_key: []const u8, current: *const Counts, baseline: *const Baseline) RenameError!void {
    const old = baseline.get(old_key) orelse return error.OldKeyNotInBaseline;
    if (current.contains(old_key)) return error.OldKeyStillPresent;
    const new = current.get(new_key) orelse return error.NewKeyAbsent;
    if (baseline.contains(new_key)) return error.NewKeyInBaseline;
    if (!std.mem.eql(u8, pathOf(old_key), pathOf(new_key))) return error.DifferentFile;
    if (!std.mem.eql(u8, old.kind, new.kind.label())) return error.DifferentKind;
    if (old.decl != new.decl) return error.DifferentDeclaration;
    if (old.count != new.count) return error.DifferentCount;
}

/// Move the baseline's entry from `old_key` to `new_key` (its class with it).
/// Call only after `checkRename`. Keys are allocated with `gpa`.
pub fn applyRename(gpa: std.mem.Allocator, baseline: *Baseline, old_key: []const u8, new_key: []const u8) !void {
    const removed = baseline.fetchRemove(old_key) orelse return error.OldKeyNotInBaseline;
    gpa.free(removed.key);
    try baseline.put(gpa, try gpa.dupe(u8, new_key), removed.value);
}

/// Parse a baseline file: `path name count kind class` per line, `#`
/// comments. Strings are allocated with `gpa`.
pub fn parseBaseline(gpa: std.mem.Allocator, text: []const u8) !Baseline {
    var out: Baseline = .empty;
    errdefer freeBaseline(gpa, &out);
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        var fields = std.mem.tokenizeAny(u8, line, " \t");
        const path = fields.next() orelse return error.MalformedBaseline;
        const name = fields.next() orelse return error.MalformedBaseline;
        const count_text = fields.next() orelse return error.MalformedBaseline;
        const count = std.fmt.parseInt(u32, count_text, 10) catch return error.MalformedBaseline;
        const kind = fields.next() orelse return error.MalformedBaseline;
        const class = fields.next() orelse "?";
        var decl: u64 = 0;
        if (fields.next()) |decl_text| {
            if (!std.mem.startsWith(u8, decl_text, "decl:")) return error.MalformedBaseline;
            decl = std.fmt.parseInt(u64, decl_text["decl:".len..], 16) catch return error.MalformedBaseline;
        }
        if (fields.next() != null) return error.MalformedBaseline;
        const key = try std.fmt.allocPrint(gpa, "{s} {s}", .{ path, name });
        errdefer gpa.free(key);
        if (out.contains(key)) return error.MalformedBaseline;
        const kind_owned = try gpa.dupe(u8, kind);
        errdefer gpa.free(kind_owned);
        const class_owned = try gpa.dupe(u8, class);
        errdefer gpa.free(class_owned);
        try out.put(gpa, key, .{ .count = count, .kind = kind_owned, .class = class_owned, .decl = decl });
    }
    return out;
}

pub fn freeBaseline(gpa: std.mem.Allocator, baseline: *Baseline) void {
    var it = baseline.iterator();
    while (it.next()) |entry| {
        gpa.free(entry.key_ptr.*);
        if (entry.value_ptr.kind.len > 0) gpa.free(entry.value_ptr.kind);
        if (entry.value_ptr.class.len > 0) gpa.free(entry.value_ptr.class);
    }
    baseline.deinit(gpa);
}

const header =
    \\# Mutable process-global and threadlocal variables in src/: path name count kind class decl.
    \\# A ratchet - `zig build lint-global-state`, part of `zig build test`, fails if any
    \\# count rises or a new key appears. kind: TL (Zig threadlocal), G (Zig container-level
    \\# var), C++G, C++TL. class (documentation, tmp/plans/instances-inventory.md and
    \\# docs/instances.md): P-const P-res H I/profile I/engine A T R C D X, `?` unclassified.
    \\# decl: a hash of the declarations' type and initialiser, which `--rename` compares.
    \\# After removing variables, lower it with `zig build lint-global-state -- --update`,
    \\# which keeps each surviving key's class. Rename a variable in place with
    \\# `-- --rename '<old key>' '<new key>'`. Never raise it by hand.
    \\
;

fn lessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

/// Format the current counts as a baseline file, keys sorted, each keeping
/// the class `previous` gives it.
pub fn formatBaseline(gpa: std.mem.Allocator, current: *const Counts, previous: ?*const Baseline) ![]u8 {
    var keys: std.ArrayList([]const u8) = .empty;
    defer keys.deinit(gpa);
    var it = current.keyIterator();
    while (it.next()) |key| try keys.append(gpa, key.*);
    std.mem.sort([]const u8, keys.items, {}, lessThan);

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(gpa);
    try out.appendSlice(gpa, header);
    for (keys.items) |key| {
        const found = current.get(key).?;
        // A hook slot is class H by its type. A key new to the inventory was
        // recorded through its markers: per-thread state is set around a
        // call (C) until someone classifies it further, process state a
        // process resource (P-res).
        const reviewed = found.unmarked == 0 and found.misplaced == 0;
        const new_class = if (found.hooks == found.count)
            "H"
        else if (reviewed and found.per_thread + found.hooks == found.count)
            "C"
        else if (reviewed)
            "P-res"
        else
            "?";
        const class = if (found.hooks == found.count and found.count > 0)
            "H"
        else if (previous) |p| (if (p.get(key)) |e| e.class else new_class) else new_class;
        try out.print(gpa, "{s} {d} {s} {s} decl:{x:0>16}\n", .{ key, found.count, found.kind.label(), class, found.decl });
    }
    return out.toOwnedSlice(gpa);
}

// ============================================================================
// The run
// ============================================================================

const Site = struct { path: []const u8, variable: Variable };

fn scan(
    arena: std.mem.Allocator,
    io: std.Io,
    current: *Counts,
    sites: *std.StringHashMapUnmanaged(std.ArrayList(Site)),
) !void {
    var dir = try std.Io.Dir.cwd().openDir(io, scanned_root, .{ .iterate = true });
    defer dir.close(io);
    var walker = try dir.walk(arena);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;
        const path = try std.fmt.allocPrint(arena, "{s}/{s}", .{ scanned_root, entry.path });
        std.mem.replaceScalar(u8, path, '\\', '/');
        const language = languageOf(path) orelse continue;
        const text = try std.Io.Dir.cwd().readFileAllocOptions(io, path, arena, .limited(64 << 20), .of(u8), 0);
        const found = switch (language) {
            .zig => zigVariablesIn(arena, path, text) catch |err| switch (err) {
                error.ParseError => {
                    std.debug.print("global state: {s} does not parse; fix it so it can be counted.\n", .{path});
                    return err;
                },
                else => return err,
            },
            .cpp => try cppVariables(arena, text),
        };
        for (found.items) |variable| {
            const key = try std.fmt.allocPrint(arena, "{s} {s}", .{ path, variable.name });
            const gop = try current.getOrPut(arena, key);
            if (!gop.found_existing) gop.value_ptr.* = .{ .count = 0, .kind = variable.kind };
            gop.value_ptr.add(variable);
            const site = try sites.getOrPut(arena, key);
            if (!site.found_existing) site.value_ptr.* = .empty;
            try site.value_ptr.append(arena, .{ .path = path, .variable = variable });
        }
    }
}

/// Totals per kind and per class.
fn printTotals(out: *std.Io.Writer, arena: std.mem.Allocator, current: *const Counts, baseline: ?*const Baseline) !void {
    var per_kind = @as([std.meta.fieldNames(Kind).len]u32, @splat(0));
    var per_class: std.StringArrayHashMapUnmanaged(u32) = .empty;
    var it = current.iterator();
    while (it.next()) |entry| {
        per_kind[@backingInt(entry.value_ptr.kind)] += entry.value_ptr.count;
        const class = if (baseline) |b| (if (b.get(entry.key_ptr.*)) |e| e.class else "?") else "?";
        const gop = try per_class.getOrPut(arena, class);
        if (!gop.found_existing) gop.value_ptr.* = 0;
        gop.value_ptr.* += entry.value_ptr.count;
    }
    try out.print("  by kind:", .{});
    inline for (@typeInfo(Kind).@"enum".field_values) |field_value| {
        const kind: Kind = @fromBackingInt(@intCast(field_value));
        try out.print(" {s} {d}", .{ kind.label(), per_kind[field_value] });
    }
    try out.print("\n  by class:", .{});
    const classes = try arena.dupe([]const u8, per_class.keys());
    std.mem.sort([]const u8, classes, {}, lessThan);
    for (classes) |class| try out.print(" {s} {d}", .{ class, per_class.get(class).? });
    var hooks: u32 = 0;
    var per_thread: u32 = 0;
    var unmarked: u32 = 0;
    var misplaced: u32 = 0;
    var total: u32 = 0;
    var values = current.valueIterator();
    while (values.next()) |found| {
        hooks += found.hooks;
        per_thread += found.per_thread;
        unmarked += found.unmarked;
        misplaced += found.misplaced;
        total += found.count;
    }
    const process_wide = total - hooks - per_thread - unmarked - misplaced;
    const debt_note = if (recorded_debt_allowed) " (recorded debt, transitional)" else "";
    try out.print("\n  by rule: H by type {d}, process-wide {d}, per-thread {d}, unmarked {d}{s}, misplaced {d}\n", .{ hooks, process_wide, per_thread, unmarked, debt_note, misplaced });
}

fn totalOf(current: *const Counts) usize {
    var total: usize = 0;
    var values = current.valueIterator();
    while (values.next()) |value| total += value.count;
    return total;
}

fn usage() noreturn {
    std.debug.print("usage: lint_global_state [--update] [--rename '<old key>' '<new key>']...\n", .{});
    std.process.exit(2);
}

pub fn main(init: std.process.Init) !void {
    var arena_state = std.heap.ArenaAllocator.init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = init.io;

    var update = false;
    var renames: std.ArrayList([2][]const u8) = .empty;
    var args = try init.minimal.args.iterateAllocator(arena);
    defer args.deinit();
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--update")) {
            update = true;
        } else if (std.mem.eql(u8, arg, "--rename")) {
            const old_key = args.next() orelse usage();
            const new_key = args.next() orelse usage();
            try renames.append(arena, .{ try arena.dupe(u8, old_key), try arena.dupe(u8, new_key) });
            // A rename is recorded, so it updates the baseline.
            update = true;
        } else usage();
    }

    var current: Counts = .empty;
    var sites = std.StringHashMapUnmanaged(std.ArrayList(Site)).empty;
    try scan(arena, io, &current, &sites);

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = stdout_stream.writer(io, &stdout_buf);
    const out = &stdout_writer.interface;
    defer out.flush() catch {};

    const total = totalOf(&current);

    const text: ?[]u8 = std.Io.Dir.cwd().readFileAlloc(io, baseline_path, arena, .limited(64 << 20)) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    if (text == null) {
        if (!update) {
            try out.print("global state: no {s}; record one with `zig build lint-global-state -- --update`.\n", .{baseline_path});
            try out.flush();
            std.process.exit(1);
        }
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = baseline_path, .data = try formatBaseline(arena, &current, null) });
        try out.print("global state: first baseline recorded - {d} variables, {d} keys.\n", .{ total, current.count() });
        try printTotals(out, arena, &current, null);
        return;
    }
    var baseline = try parseBaseline(arena, text.?);
    for (renames.items) |rename| {
        checkRename(rename[0], rename[1], &current, &baseline) catch |err| {
            try out.print("global state: --rename '{s}' '{s}' refused: {s}.\n", .{ rename[0], rename[1], @errorName(err) });
            try out.flush();
            std.process.exit(1);
        };
        try applyRename(arena, &baseline, rename[0], rename[1]);
        try out.print("global state: renamed '{s}' -> '{s}'.\n", .{ rename[0], rename[1] });
    }

    var baseline_total: usize = 0;
    var base_values = baseline.valueIterator();
    while (base_values.next()) |value| baseline_total += value.count;

    const found = try violations(arena, &current, &baseline, .{ .allow_recorded_debt = recorded_debt_allowed });
    // Without --update every violation fails; --update records reviewed
    // declarations - hook slots and correctly marked ones - and nothing else.
    const blocking = if (update) try refusedByUpdate(arena, found.items) else found;
    if (blocking.items.len > 0) {
        try out.print("global state: {d} key(s) fail ({d} variables, inventory {d}).\n\n", .{ blocking.items.len, total, baseline_total });
        for (blocking.items) |v| {
            switch (v.reason) {
                .above_baseline => try out.print("  {s}: reviewed, not in the inventory (recorded {d}, found {d}) - `-- --update` records it\n", .{ v.key, v.allowed, v.found }),
                .unmarked, .misplaced => try out.print("  {s}:\n", .{v.key}),
            }
            if (sites.get(v.key)) |list| {
                for (list.items) |site| {
                    const problem = problemOf(site.variable);
                    try out.print("      {s}:{d} ({s}){s}{s}\n", .{ site.path, site.variable.line, site.variable.kind.label(), if (problem != null) ": " else "", if (problem) |p| p.describe() else "" });
                }
            }
        }
        try out.print(
            \\
            \\A container-level `var` or `threadlocal` is shared by every instance, or
            \\by every page on a thread (docs/instances.md, "Rules for new state"). Put
            \\the state on its owner - the Browser, the Tab, the agent, the realm - and
            \\reach it through the realm the code runs in. A hook is a `Hook(T)` slot
            \\(src/process/hook.zig), written once at process start: its type is the rule.
            \\Anything else must say why it is not owned: `// process-wide: <why>` directly
            \\above a container-level `var` or C++ global that genuinely is one per process,
            \\`// per-thread: <why>` directly above a threadlocal or C++ thread_local whose
            \\owner is the thread (a call-stack extent, an engine's own thread-local). Writes
            \\from several threads name their safety: atomic, lock or init-once. A reviewed
            \\variable enters the inventory through `zig build lint-global-state -- --update`
            \\(the integrator reviews it).
            \\{s}
        , .{if (update) "--update records only hook slots and reviewed declarations.\n" else ""});
        try out.flush();
        std.process.exit(1);
    }

    var lowered: usize = 0;
    var base_it = baseline.iterator();
    while (base_it.next()) |entry| {
        const now = if (current.get(entry.key_ptr.*)) |f| f.count else 0;
        if (now < entry.value_ptr.count) lowered += 1;
    }
    if (mayRecord(update, blocking.items.len)) {
        for (found.items) |v| {
            const list = sites.get(v.key) orelse continue;
            for (list.items) |site| {
                const what = if (site.variable.hook == .slot) "hook slot" else if (site.variable.marker) |m| m.text() else "";
                try out.print("global state: recorded {s} {s} ({s}:{d}): {s}\n", .{ what, v.key, site.path, site.variable.line, site.variable.why orelse "" });
            }
        }
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = baseline_path, .data = try formatBaseline(arena, &current, &baseline) });
        try out.print("global state: baseline recorded - {d} variables (was {d}), {d} keys.\n", .{ total, baseline_total, current.count() });
    } else if (lowered > 0) {
        try out.print("global state: {d} variables, {d} key(s) paid down (baseline {d}); record it with `zig build lint-global-state -- --update`.\n", .{ total, lowered, baseline_total });
    } else {
        try out.print("global state: {d} variables, none above the baseline ({d}).\n", .{ total, baseline_total });
    }
    try printTotals(out, arena, &current, &baseline);
}

// ============================================================================
// Tests - the rules
// ============================================================================

const testing = std.testing;

fn expectZig(source: [:0]const u8, expected: []const []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const vars = try zigVariables(arena.allocator(), source);
    var got: std.ArrayList(u8) = .empty;
    for (vars.items) |v| try got.print(arena.allocator(), "{d}:{s}:{s}\n", .{ v.line, v.name, v.kind.label() });
    var want: std.ArrayList(u8) = .empty;
    for (expected) |e| try want.print(arena.allocator(), "{s}\n", .{e});
    try testing.expectEqualStrings(want.items, got.items);
}

fn expectCpp(source: []const u8, expected: []const []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const vars = try cppVariables(arena.allocator(), source);
    var got: std.ArrayList(u8) = .empty;
    for (vars.items) |v| try got.print(arena.allocator(), "{d}:{s}:{s}\n", .{ v.line, v.name, v.kind.label() });
    var want: std.ArrayList(u8) = .empty;
    for (expected) |e| try want.print(arena.allocator(), "{s}\n", .{e});
    try testing.expectEqualStrings(want.items, got.items);
}

test "the hard rule allows no recorded debt: an unmarked variable fails even where the inventory records it" {
    try testing.expect(!recorded_debt_allowed);
    var current: Counts = .empty;
    defer current.deinit(testing.allocator);
    var baseline: Baseline = .empty;
    defer baseline.deinit(testing.allocator);
    try current.put(testing.allocator, "src/dom/example.zig slot", .{ .count = 1, .kind = .zig_global, .unmarked = 1 });
    try baseline.put(testing.allocator, "src/dom/example.zig slot", .{ .count = 1, .kind = "G", .class = "P-res" });
    var found = try violations(testing.allocator, &current, &baseline, .{ .allow_recorded_debt = recorded_debt_allowed });
    defer found.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 1), found.items.len);
}

test "src/ .zig, .cpp and .h are scanned; impls_tmp and caches are not" {
    try testing.expectEqual(Language.zig, languageOf("src/dom/abort_algorithms.zig").?);
    try testing.expectEqual(Language.cpp, languageOf("src/runtime/engines/v8/v8_wrapper.cpp").?);
    try testing.expectEqual(Language.cpp, languageOf("src/runtime/engines/v8/v8_helpers.h").?);
    try testing.expect(languageOf("src/webidl/impls_tmp/Node.zig") == null);
    try testing.expect(languageOf("src/.zig-cache/o/x.zig") == null);
    try testing.expect(languageOf("tests/v8/x.zig") == null);
    try testing.expect(languageOf("tools/lint_global_state.zig") == null);
    try testing.expect(languageOf("src/dom/README.md") == null);
}

test "zig: container-level vars are counted - pub, export, threadlocal - and consts are not" {
    try expectZig(
        \\const std = @import("std");
        \\var a: u32 = 0;
        \\pub var b: u32 = 0;
        \\export var c: u32 = 0;
        \\threadlocal var d: ?*u8 = null;
        \\pub threadlocal var e: u32 = 0;
        \\const f: u32 = 1;
        \\pub const g = 2;
    , &.{ "2:a:G", "3:b:G", "4:c:G", "5:d:TL", "6:e:TL" });
}

test "zig: a nested container's var is qualified by its containers" {
    try expectZig(
        \\pub const Arena = struct {
        \\    pub var global: ?*u8 = null;
        \\    const Inner = struct {
        \\        threadlocal var depth: u32 = 0;
        \\    };
        \\    count: u32,
        \\};
    , &.{ "2:Arena.global:G", "4:Arena.Inner.depth:TL" });
}

test "zig: a function static is counted, named by its function; a local var is not" {
    try expectZig(
        \\fn getDefault() *u32 {
        \\    var local: u32 = 0;
        \\    _ = &local;
        \\    const State = struct {
        \\        var value: u32 = 0;
        \\    };
        \\    return &State.value;
        \\}
        \\fn Generic(comptime T: type) type {
        \\    return struct {
        \\        var cache: ?T = null;
        \\    };
        \\}
    , &.{ "5:getDefault.State.value:G", "11:Generic.cache:G" });
}

test "zig: a var inside a test declaration is not counted" {
    try expectZig(
        \\var real: u32 = 0;
        \\test "uses a static" {
        \\    const S = struct {
        \\        var calls: u32 = 0;
        \\    };
        \\    S.calls += 1;
        \\}
    , &.{"1:real:G"});
}

test "zig: a file that does not parse is an error, not zero variables" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    try testing.expectError(error.ParseError, zigVariables(arena.allocator(), "var x: u32 = ;"));
}

test "cpp: namespace-scope and function statics, static thread_local and static member definitions are counted" {
    try expectCpp(
        \\#include <atomic>
        \\static std::unique_ptr<Platform> g_platform = nullptr;
        \\static bool v8_initialized = false;
        \\std::atomic<int64_t> g_live_globals{0};
        \\static std::atomic<uintptr_t> g_site_pc[512];
        \\static void (*g_hook)(Isolate*, int) = nullptr;
        \\static thread_local bool g_in_context_new = false;
        \\class CallbackManager {
        \\    static CallbackManager* instance_;
        \\    static std::mutex instance_mutex_;
        \\  public:
        \\    static CallbackManager* get() {
        \\        static int calls = 0;
        \\        return instance_;
        \\    }
        \\};
        \\CallbackManager* CallbackManager::instance_ = nullptr;
        \\std::mutex CallbackManager::instance_mutex_;
        \\static std::unordered_map<const void*, int>& armedWeakData() {
        \\    static std::unordered_map<const void*, int> map;
        \\    return map;
        \\}
        \\extern "C" {
        \\const char* v8_error(int code) {
        \\    if (code) {
        \\        static thread_local char error_buffer[1024];
        \\        return error_buffer;
        \\    }
        \\    int local = 0;
        \\    return nullptr;
        \\}
        \\}
    , &.{
        "2:g_platform:C++G",
        "3:v8_initialized:C++G",
        "4:g_live_globals:C++G",
        "5:g_site_pc:C++G",
        "6:g_hook:C++G",
        "7:g_in_context_new:C++TL",
        "13:CallbackManager.get.calls:C++G",
        "17:CallbackManager::instance_:C++G",
        "18:CallbackManager::instance_mutex_:C++G",
        "20:armedWeakData.map:C++G",
        "26:v8_error.error_buffer:C++TL",
    });
}

test "cpp: const and constexpr objects, function definitions and declarations are not counted" {
    try expectCpp(
        \\static constexpr int kSlots = 512;
        \\static const size_t element_sizes[] = {1, 1, 2};
        \\static const char* const kName = "x";
        \\const int kLimit = 3;
        \\static V8ErrorInfo* extractException(Isolate* isolate, TryCatch* try_catch) {
        \\    static constexpr char kUndefined[] = "undefined";
        \\    return nullptr;
        \\}
        \\static uint8_t* serializeWithTransfer(
        \\    Isolate* isolate) {
        \\    return nullptr;
        \\}
        \\void declared(int x);
        \\extern "C" int64_t v8_Debug_CreatedGlobals();
        \\using Callback = void (*)(int);
        \\typedef int Handle;
        \\struct Forward;
        \\static const char* kMutablePointer = "y";
    , &.{"18:kMutablePointer:C++G"});
}

test "cpp: comments, strings and preprocessor lines are not code" {
    try expectCpp(
        \\// static int commented = 0;
        \\/* static int blocked = 0;
        \\   static int still = 0; */
        \\#define DECLARE static int from_macro = 0;
        \\static const char* kText = "static int in_string = 0; {";
        \\static int real = 0;
    , &.{ "5:kText:C++G", "6:real:C++G" });
}

test "cpp: braces of initialisers, lambdas and control blocks do not open scopes" {
    try expectCpp(
        \\static std::atomic<int64_t> g_obj_src[6] = {};
        \\void f() {
        \\    auto cb = [&]() { return 1; };
        \\    if (x) { y(); } else { z(); }
        \\    for (int i = 0; i < 3; i++) {
        \\        static int nested = 0;
        \\    }
        \\    Foo foo{1, 2};
        \\}
        \\static int after = 0;
    , &.{ "1:g_obj_src:C++G", "6:f.nested:C++G", "10:after:C++G" });
}

test "cpp: class heads, linkage blocks and constructors open the right scopes" {
    try expectCpp(
        \\extern "C" int64_t v8_Debug_CreatedGlobals() {
        \\    static int calls = 0;
        \\    return calls;
        \\}
        \\enum class Mode : uint8_t { kA = 1, kB = 2 };
        \\class Derived : public Base<int> {
        \\    static int declared_;
        \\    Derived(int x) : a_(x), b_{x} {
        \\        static int built = 0;
        \\    }
        \\    int a_;
        \\};
        \\std::function<void(int)> g_callback = nullptr;
        \\bool operator==(const A& a, const A& b) {
        \\    static int compared = 0;
        \\    return true;
        \\}
    , &.{
        "2:v8_Debug_CreatedGlobals.calls:C++G",
        "9:Derived.Derived.built:C++G",
        "13:g_callback:C++G",
        "15:operator.compared:C++G",
    });
}

test "a `// process-wide: <why>` line directly above a declaration marks it; an empty why or a gap does not" {
    const zig_source =
        \\// process-wide: the start-up phase, written by crane.Process only
        \\var phase: u8 = 0;
        \\// process-wide:
        \\var empty_why: u8 = 0;
        \\// process-wide: two lines up
        \\
        \\var gap: u8 = 0;
        \\var plain: u8 = 0;
    ;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const vars = try zigVariables(arena.allocator(), zig_source);
    try testing.expectEqual(@as(usize, 4), vars.items.len);
    try testing.expectEqualStrings("the start-up phase, written by crane.Process only", vars.items[0].why.?);
    try testing.expect(vars.items[1].why == null);
    try testing.expect(vars.items[2].why == null);
    try testing.expect(vars.items[3].why == null);

    const cpp = try cppVariables(arena.allocator(),
        \\  // process-wide: the V8 platform, one per process
        \\static std::unique_ptr<Platform> g_platform = nullptr;
        \\static bool v8_initialized = false;
    );
    try testing.expectEqualStrings("the V8 platform, one per process", cpp.items[0].why.?);
    try testing.expect(cpp.items[1].why == null);
}

test "--update records reviewed keys - new or grown - and refuses unmarked and misplaced ones" {
    var current: Counts = .empty;
    defer current.deinit(testing.allocator);
    // New and marked: recordable.
    try current.put(testing.allocator, "src/dom/process_phase.zig phase", .{ .count = 1, .kind = .zig_global });
    // New, without a marker (or with an empty why, which leaves it unmarked).
    try current.put(testing.allocator, "src/dom/x.zig cache", .{ .count = 1, .kind = .zig_global, .unmarked = 1 });
    // An existing key grown by a reviewed declaration: recordable.
    try current.put(testing.allocator, "src/a.zig counter", .{ .count = 2, .kind = .zig_global });
    // A marker of the wrong kind: refused, recorded or not.
    try current.put(testing.allocator, "src/b.zig depth", .{ .count = 1, .kind = .zig_threadlocal, .misplaced = 1 });
    var baseline: Baseline = .empty;
    defer baseline.deinit(testing.allocator);
    try baseline.put(testing.allocator, "src/a.zig counter", .{ .count = 1, .kind = "G", .class = "D" });
    try baseline.put(testing.allocator, "src/b.zig depth", .{ .count = 1, .kind = "TL", .class = "C" });

    var found = try violations(testing.allocator, &current, &baseline, .{});
    defer found.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 4), found.items.len);

    var refused = try refusedByUpdate(testing.allocator, found.items);
    defer refused.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 2), refused.items.len);
    try testing.expectEqualStrings("src/b.zig depth", refused.items[0].key);
    try testing.expectEqual(Reason.misplaced, refused.items[0].reason);
    try testing.expectEqualStrings("src/dom/x.zig cache", refused.items[1].key);
    try testing.expectEqual(Reason.unmarked, refused.items[1].reason);
    try testing.expect(!mayRecord(true, refused.items.len));

    // With the unmarked and misplaced keys gone, --update records the rest -
    // a new process-wide key as a process resource.
    _ = current.remove("src/dom/x.zig cache");
    _ = current.remove("src/b.zig depth");
    var found2 = try violations(testing.allocator, &current, &baseline, .{});
    defer found2.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 2), found2.items.len);
    var refused2 = try refusedByUpdate(testing.allocator, found2.items);
    defer refused2.deinit(testing.allocator);
    try testing.expect(mayRecord(true, refused2.items.len));
    const text = try formatBaseline(testing.allocator, &current, &baseline);
    defer testing.allocator.free(text);
    try testing.expect(std.mem.indexOf(u8, text, "src/dom/process_phase.zig phase 1 G P-res decl:") != null);
    try testing.expect(std.mem.indexOf(u8, text, "src/a.zig counter 2 G D decl:") != null);
}

test "a rename is recorded only for the same variable: same file, kind, declaration and count" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const decl = declHash(&.{ "std.ArrayListUnmanaged(*Self)", ".empty" });

    var baseline: Baseline = .empty;
    try baseline.put(arena, try arena.dupe(u8, "src/a.zig call_fetch.Call.live"), .{ .count = 1, .kind = "TL", .class = "R", .decl = decl });
    try baseline.put(arena, try arena.dupe(u8, "src/a.zig kept"), .{ .count = 1, .kind = "G", .class = "C", .decl = decl });

    var current: Counts = .empty;
    try current.put(arena, "src/a.zig FetchCall.live", .{ .count = 1, .kind = .zig_threadlocal, .decl = decl });
    try current.put(arena, "src/a.zig kept", .{ .count = 1, .kind = .zig_global, .decl = decl });

    try checkRename("src/a.zig call_fetch.Call.live", "src/a.zig FetchCall.live", &current, &baseline);

    // The old key must be gone, and in the baseline; the new one present, and not.
    try testing.expectError(error.OldKeyStillPresent, checkRename("src/a.zig kept", "src/a.zig FetchCall.live", &current, &baseline));
    try testing.expectError(error.OldKeyNotInBaseline, checkRename("src/a.zig nowhere", "src/a.zig FetchCall.live", &current, &baseline));
    try testing.expectError(error.NewKeyAbsent, checkRename("src/a.zig call_fetch.Call.live", "src/a.zig missing", &current, &baseline));

    // The same name in another file is a move, not a rename.
    try current.put(arena, "src/b.zig FetchCall.live", .{ .count = 1, .kind = .zig_threadlocal, .decl = decl });
    try testing.expectError(error.DifferentFile, checkRename("src/a.zig call_fetch.Call.live", "src/b.zig FetchCall.live", &current, &baseline));
    // A different type or initialiser is another variable.
    try current.put(arena, "src/a.zig other_type", .{ .count = 1, .kind = .zig_threadlocal, .decl = declHash(&.{ "?*Self", "null" }) });
    try testing.expectError(error.DifferentDeclaration, checkRename("src/a.zig call_fetch.Call.live", "src/a.zig other_type", &current, &baseline));
    // A different kind, or count.
    try current.put(arena, "src/a.zig now_global", .{ .count = 1, .kind = .zig_global, .decl = decl });
    try testing.expectError(error.DifferentKind, checkRename("src/a.zig call_fetch.Call.live", "src/a.zig now_global", &current, &baseline));
    try current.put(arena, "src/a.zig two", .{ .count = 2, .kind = .zig_threadlocal, .decl = decl });
    try testing.expectError(error.DifferentCount, checkRename("src/a.zig call_fetch.Call.live", "src/a.zig two", &current, &baseline));

    // Applied: the class carries over, the old key is gone.
    try applyRename(arena, &baseline, "src/a.zig call_fetch.Call.live", "src/a.zig FetchCall.live");
    try testing.expect(!baseline.contains("src/a.zig call_fetch.Call.live"));
    try testing.expectEqualStrings("R", baseline.get("src/a.zig FetchCall.live").?.class);
    try baseline.put(arena, try arena.dupe(u8, "src/a.zig gone_too"), .{ .count = 1, .kind = "TL", .class = "R", .decl = decl });
    try testing.expectError(error.NewKeyInBaseline, checkRename("src/a.zig gone_too", "src/a.zig FetchCall.live", &current, &baseline));
}

test "the declaration hash sees the type and initialiser, not the name or the layout" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = try zigVariables(arena.allocator(),
        \\fn call_fetch() void {
        \\    const Call = struct {
        \\        threadlocal var live: std.ArrayListUnmanaged(*Self) = .empty;
        \\    };
        \\}
        \\const FetchCall = struct {
        \\    threadlocal var live:   std.ArrayListUnmanaged( *Self ) =   .empty;
        \\    threadlocal var other: std.ArrayListUnmanaged(*Self) = .{};
        \\};
    );
    try testing.expectEqual(@as(usize, 3), a.items.len);
    try testing.expectEqual(a.items[0].decl_hash, a.items[1].decl_hash);
    try testing.expect(a.items[0].decl_hash != a.items[2].decl_hash);

    const c = try cppVariables(arena.allocator(),
        \\static std::atomic<int64_t> g_a{0};
        \\static std::atomic<int64_t>   g_b{0};
        \\static std::atomic<int64_t> g_c{1};
    );
    try testing.expectEqual(c.items[0].decl_hash, c.items[1].decl_hash);
    try testing.expect(c.items[0].decl_hash != c.items[2].decl_hash);
}

fn testCounts(entries: []const struct { []const u8, u32 }) !Counts {
    var counts: Counts = .empty;
    for (entries) |e| try counts.put(testing.allocator, e[0], .{ .count = e[1], .kind = .zig_threadlocal });
    return counts;
}

fn testBaseline(entries: []const struct { []const u8, u32 }) !Baseline {
    var baseline: Baseline = .empty;
    for (entries) |e| try baseline.put(testing.allocator, e[0], .{ .count = e[1], .kind = "", .class = "" });
    return baseline;
}

test "a swap (one variable removed, another added) and an increase are violations; fewer is allowed" {
    var current = try testCounts(&.{
        // Same total as the baseline - one variable swapped for another.
        .{ "src/a.zig hook", 1 },
        .{ "src/a.zig new_hook", 1 },
        // Paid down.
        .{ "src/b.zig registry", 1 },
        // Grown: a second function static of the same name.
        .{ "src/c.zig f.S.x", 2 },
    });
    defer current.deinit(testing.allocator);
    var baseline = try testBaseline(&.{
        .{ "src/a.zig hook", 1 },
        .{ "src/a.zig old_hook", 1 },
        .{ "src/b.zig registry", 3 },
        .{ "src/c.zig f.S.x", 1 },
    });
    defer baseline.deinit(testing.allocator);

    var found = try violations(testing.allocator, &current, &baseline, .{});
    defer found.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 2), found.items.len);
    try testing.expectEqualStrings("src/a.zig new_hook", found.items[0].key);
    try testing.expectEqual(@as(u32, 0), found.items[0].allowed);
    try testing.expectEqualStrings("src/c.zig f.S.x", found.items[1].key);
    try testing.expectEqual(@as(u32, 1), found.items[1].allowed);
}

test "the kind is not part of the key: a threadlocal turned process variable is no increase" {
    var current: Counts = .empty;
    defer current.deinit(testing.allocator);
    try current.put(testing.allocator, "src/dom/hook.zig implementation", .{ .count = 1, .kind = .zig_global });
    var baseline: Baseline = .empty;
    defer baseline.deinit(testing.allocator);
    try baseline.put(testing.allocator, "src/dom/hook.zig implementation", .{ .count = 1, .kind = "TL", .class = "H" });
    var found = try violations(testing.allocator, &current, &baseline, .{});
    defer found.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 0), found.items.len);
}

test "--update records only when nothing is above the baseline" {
    try testing.expect(mayRecord(true, 0));
    try testing.expect(!mayRecord(true, 1));
    try testing.expect(!mayRecord(false, 0));
}

test "the baseline round-trips, sorted, keeps each key's class and ignores comments" {
    var current: Counts = .empty;
    defer current.deinit(testing.allocator);
    try current.put(testing.allocator, "src/b.zig Arena.global", .{ .count = 1, .kind = .zig_global });
    try current.put(testing.allocator, "src/a.zig hook", .{ .count = 2, .kind = .zig_threadlocal });
    try current.put(testing.allocator, "src/c.cpp g_new", .{ .count = 1, .kind = .cpp_static, .unmarked = 1 });

    var previous = try parseBaseline(testing.allocator,
        \\# a comment
        \\src/a.zig hook 3 TL H
        \\src/b.zig Arena.global 1 G I/engine
        \\src/gone.zig x 1 G C
    );
    defer freeBaseline(testing.allocator, &previous);
    try testing.expectEqual(@as(u32, 3), previous.get("src/a.zig hook").?.count);
    try testing.expectEqualStrings("I/engine", previous.get("src/b.zig Arena.global").?.class);

    const text = try formatBaseline(testing.allocator, &current, &previous);
    defer testing.allocator.free(text);
    try testing.expect(std.mem.indexOf(u8, text,
        \\src/a.zig hook 2 TL H decl:0000000000000000
        \\src/b.zig Arena.global 1 G I/engine decl:0000000000000000
        \\src/c.cpp g_new 1 C++G ? decl:0000000000000000
        \\
    ) != null);

    var parsed = try parseBaseline(testing.allocator, text);
    defer freeBaseline(testing.allocator, &parsed);
    try testing.expectEqual(@as(usize, 3), parsed.count());
    try testing.expectEqualStrings("C++G", parsed.get("src/c.cpp g_new").?.kind);
}

test "a malformed or duplicated baseline line is an error" {
    try testing.expectError(error.MalformedBaseline, parseBaseline(testing.allocator, "src/a.zig x notanumber G H\n"));
    try testing.expectError(error.MalformedBaseline, parseBaseline(testing.allocator, "src/a.zig x 1 G H\nsrc/a.zig x 1 G H\n"));
}

// ============================================================================
// Tests - the hard rule: a hook slot by type, or a reviewed marker of the
// declaration's kind
// ============================================================================

/// The problem of each variable `file` declares, in source order, as
/// "name:problem" ("name:ok" for none, "name:hook" for a hook slot).
fn expectRule(file: []const u8, source: [:0]const u8, expected: []const []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const vars = switch (languageOf(file).?) {
        .zig => try zigVariablesIn(arena.allocator(), file, source),
        .cpp => try cppVariables(arena.allocator(), source),
    };
    var got: std.ArrayList(u8) = .empty;
    for (vars.items) |v| {
        const verdict = if (v.hook == .slot) "hook" else if (problemOf(v)) |p| @tagName(p) else "ok";
        try got.print(arena.allocator(), "{s}:{s}\n", .{ v.name, verdict });
    }
    var want: std.ArrayList(u8) = .empty;
    for (expected) |e| try want.print(arena.allocator(), "{s}\n", .{e});
    try testing.expectEqualStrings(want.items, got.items);
}

test "rule: a plain var or threadlocal fails; each passes with its own kind's marker, and fails with the other's" {
    try expectRule("src/html/x.zig",
        \\var plain: u32 = 0;
        \\threadlocal var plain_tl: u32 = 0;
        \\// process-wide: an id counter whose only property is uniqueness; atomic
        \\var counter: std.atomic.Value(u64) = .init(1);
        \\// per-thread: a call-stack extent - the teardown running on this thread's stack
        \\threadlocal var active: ?*u8 = null;
        \\// per-thread: wrong kind - a process variable is not per thread
        \\var wrong_global: u32 = 0;
        \\// process-wide: wrong kind - a threadlocal is not process-wide
        \\threadlocal var wrong_tl: u32 = 0;
        \\// per-thread:
        \\threadlocal var empty_why: u32 = 0;
    , &.{
        "plain:unmarked",
        "plain_tl:unmarked",
        "counter:ok",
        "active:ok",
        "wrong_global:per_thread_on_global",
        "wrong_tl:process_wide_on_threadlocal",
        "empty_why:unmarked",
    });
}

test "rule: a C++ global needs `// process-wide:`, a thread_local `// per-thread:`" {
    try expectRule("src/runtime/engines/v8/v8_wrapper.cpp",
        \\static std::atomic<int64_t> g_plain{0};
        \\// process-wide: the V8 platform, one per process, made at the engine's start
        \\static std::unique_ptr<Platform> g_platform = nullptr;
        \\static thread_local bool t_plain = false;
        \\// per-thread: V8's own current-isolate scope - set around Context::New on this thread
        \\static thread_local bool g_in_context_new = false;
        \\// per-thread: wrong kind
        \\static bool g_wrong = false;
        \\// process-wide: wrong kind
        \\static thread_local int t_wrong = 0;
    , &.{
        "g_plain:unmarked",
        "g_platform:ok",
        "t_plain:unmarked",
        "g_in_context_new:ok",
        "g_wrong:per_thread_on_global",
        "t_wrong:process_wide_on_threadlocal",
    });
}

test "rule: a Hook slot passes by its type, in every spelling of the hook module's Hook" {
    // src/dom: the relative hook module, bare or through a namespace alias.
    try expectRule("src/dom/intersection_targets.zig",
        \\const Hook = @import("hook.zig").Hook;
        \\const hook = @import("hook.zig");
        \\var implementation: Hook(?Implementation) = .init(null);
        \\var steps: hook.Hook(hook.List(Step, 8)) = .init(.empty);
    , &.{ "implementation:hook", "steps:hook" });
    // Anywhere: the dom module's.
    try expectRule("src/html/script_element.zig",
        \\const Hook = @import("dom").Hook;
        \\var implementation: Hook(?Implementation) = .init(null);
        \\var inline_spelling: @import("dom").Hook(u8) = .init(0);
    , &.{ "implementation:hook", "inline_spelling:hook" });
    // Below dom: the process module's, bare, through its `hook`, inline.
    try expectRule("src/fetch/algorithms/scheme_fetch.zig",
        \\const Hook = @import("process").Hook;
        \\const hook = @import("process").hook;
        \\const process = @import("process");
        \\var blob_resolver: Hook(?Resolver) = .init(null);
        \\var lists: hook.Hook(hook.List(Step, 4)) = .init(.empty);
        \\var through_module: process.hook.Hook(u8) = .init(0);
        \\var inline_spelling: @import("process").hook.Hook(u8) = .init(0);
    , &.{ "blob_resolver:hook", "lists:hook", "through_module:hook", "inline_spelling:hook" });
    // src/process itself.
    try expectRule("src/process/start.zig",
        \\const Hook = @import("hook.zig").Hook;
        \\var observer: Hook(?Observer) = .init(null);
    , &.{"observer:hook"});
}

test "rule: a Hook of anything but the hook module is no hook slot" {
    try expectRule("src/html/x.zig",
        \\const Hook = @import("other.zig").Hook;
        \\const LocalHook = @import("hook.zig").Hook;
        \\fn Generic(comptime T: type) type { return T; }
        \\var other: Hook(u8) = .init(0);
        \\var relative_outside_dom: LocalHook(u8) = .init(0);
        \\var generic: Generic(u8) = .init(0);
        \\var dom_namespace_other: @import("dom").Other(u8) = .init(0);
    , &.{
        "other:unmarked",
        "relative_outside_dom:unmarked",
        "generic:unmarked",
        "dom_namespace_other:unmarked",
    });
}

test "rule: a threadlocal Hook, a Hook in an impl, one not made with .init and one written directly fail" {
    try expectRule("src/dom/x.zig",
        \\const Hook = @import("hook.zig").Hook;
        \\threadlocal var per_thread_hook: Hook(u8) = .init(0);
        \\// process-wide: a marker does not excuse a slot's own rules
        \\var not_init: Hook(u8) = undefined;
        \\var written: Hook(u8) = .init(0);
        \\var addressed: Hook(u8) = .init(0);
        \\var nested_write: Hook(Table) = .init(.{});
        \\const Outer = struct {
        \\    var qualified: Hook(u8) = .init(0);
        \\};
        \\var only_read: Hook(u8) = .init(0);
        \\fn bypass() void {
        \\    written.value = 1;
        \\    const p = &addressed.overrides;
        \\    _ = p;
        \\    nested_write.value.step = null;
        \\    Outer.qualified.value += 1;
        \\    const x = only_read.value;
        \\    _ = x;
        \\    only_read.install(2);
        \\}
    , &.{
        "per_thread_hook:threadlocal_hook",
        "not_init:hook_not_initialised",
        "written:hook_written_directly",
        "addressed:hook_written_directly",
        "nested_write:hook_written_directly",
        "Outer.qualified:hook_written_directly",
        "only_read:hook",
    });
    try expectRule("src/webidl/impls/IntersectionObserver.zig",
        \\const Hook = @import("dom").Hook;
        \\var implementation: Hook(?Implementation) = .init(null);
    , &.{"implementation:hook_in_impls"});
}

test "rule: hook slots need no inventory entry; recorded debt passes only while the rule is transitional" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var current: Counts = .empty;
    // A new hook slot: admitted by its type.
    try current.put(arena, "src/dom/a.zig implementation", .{ .count = 1, .kind = .zig_global, .hooks = 1 });
    // Recorded debt: an unmarked key the inventory records.
    try current.put(arena, "src/dom/b.zig registry", .{ .count = 1, .kind = .zig_global, .unmarked = 1 });
    // Misplaced, though recorded.
    try current.put(arena, "src/dom/c.zig depth", .{ .count = 1, .kind = .zig_threadlocal, .misplaced = 1 });
    var baseline: Baseline = .empty;
    try baseline.put(arena, "src/dom/b.zig registry", .{ .count = 1, .kind = "G", .class = "P-res" });
    try baseline.put(arena, "src/dom/c.zig depth", .{ .count = 1, .kind = "TL", .class = "C" });

    const transitional = try violations(arena, &current, &baseline, .{ .allow_recorded_debt = true });
    try testing.expectEqual(@as(usize, 1), transitional.items.len);
    try testing.expectEqualStrings("src/dom/c.zig depth", transitional.items[0].key);

    const hard = try violations(arena, &current, &baseline, .{});
    try testing.expectEqual(@as(usize, 2), hard.items.len);
    try testing.expectEqualStrings("src/dom/b.zig registry", hard.items[0].key);
    try testing.expectEqual(Reason.unmarked, hard.items[0].reason);
    try testing.expectEqualStrings("src/dom/c.zig depth", hard.items[1].key);
    try testing.expectEqual(Reason.misplaced, hard.items[1].reason);

    // Recorded debt that grew is never allowed.
    current.getPtr("src/dom/b.zig registry").?.count = 2;
    current.getPtr("src/dom/b.zig registry").?.unmarked = 2;
    const grown = try violations(arena, &current, &baseline, .{ .allow_recorded_debt = true });
    try testing.expectEqual(@as(usize, 2), grown.items.len);
    try testing.expectEqual(Reason.unmarked, grown.items[0].reason);
}

test "rule: the inventory keeps every variable, with its class - hook slots as H, new per-thread state as C" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var current: Counts = .empty;
    try current.put(arena, "src/dom/a.zig implementation", .{ .count = 1, .kind = .zig_global, .hooks = 1 });
    try current.put(arena, "src/html/b.zig depth", .{ .count = 1, .kind = .zig_threadlocal, .per_thread = 1 });
    try current.put(arena, "src/html/c.zig next_id", .{ .count = 1, .kind = .zig_global });
    // The Crane test runner's digest (tests/test_runner/globals.zig) reads
    // the inventory at compile time and compares a class C variable after
    // every test: a reviewed per-thread variable keeps its entry and class.
    try current.put(arena, "src/runtime/cleanup_coordinator.zig active_coordinator", .{ .count = 1, .kind = .zig_threadlocal, .per_thread = 1 });
    var previous: Baseline = .empty;
    // A slot that was recorded under another class is H by its type now.
    try previous.put(arena, "src/dom/a.zig implementation", .{ .count = 1, .kind = "G", .class = "P-res" });
    try previous.put(arena, "src/runtime/cleanup_coordinator.zig active_coordinator", .{ .count = 1, .kind = "TL", .class = "C" });
    const text = try formatBaseline(arena, &current, &previous);
    try testing.expect(std.mem.indexOf(u8, text, "src/dom/a.zig implementation 1 G H decl:") != null);
    try testing.expect(std.mem.indexOf(u8, text, "src/html/b.zig depth 1 TL C decl:") != null);
    try testing.expect(std.mem.indexOf(u8, text, "src/html/c.zig next_id 1 G P-res decl:") != null);
    try testing.expect(std.mem.indexOf(u8, text, "src/runtime/cleanup_coordinator.zig active_coordinator 1 TL C decl:") != null);
}

test "rule: a found key counts its hook slots, reviewed, unmarked and misplaced declarations" {
    var found: Found = .{ .count = 0, .kind = .zig_global };
    found.add(.{ .line = 1, .name = "a", .kind = .zig_global, .hook = .slot });
    found.add(.{ .line = 2, .name = "a", .kind = .zig_global, .marker = .process_wide, .why = "x" });
    found.add(.{ .line = 3, .name = "a", .kind = .zig_threadlocal, .marker = .per_thread, .why = "y" });
    found.add(.{ .line = 4, .name = "a", .kind = .zig_global });
    found.add(.{ .line = 5, .name = "a", .kind = .zig_threadlocal, .marker = .process_wide, .why = "z" });
    try testing.expectEqual(@as(u32, 5), found.count);
    try testing.expectEqual(@as(u32, 1), found.hooks);
    try testing.expectEqual(@as(u32, 1), found.per_thread);
    try testing.expectEqual(@as(u32, 1), found.unmarked);
    try testing.expectEqual(@as(u32, 1), found.misplaced);
}

test {
    _ = stdout_stream;
}
