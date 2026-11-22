//! `@hasDecl` probes that can never see their declaration: `zig build
//! lint-hasdecl` (and so `zig build test`) fails when a probe's container
//! declares the probed name only without `pub`.
//!
//! Under the pinned Zig 0.17, `@hasDecl(T, "x")` is false for every non-pub
//! declaration - in the same file as the probe, and from a generic, alike
//! (probed on chat2 with 0.17.1-dev+77c319a0f0, lane tpg 2026-11-22; lesson
//! architecture-hasdecl-does-not-see-a-private-declaration.md). So a generic
//! that calls an optional member only `if (@hasDecl(T, "drop"))` silently
//! skips every type that declares `fn drop` without `pub`: no error, no
//! warning. The devtools server's tasks leaked their connections that way
//! (lane tpf), and CSSStyleDeclaration's state was never handed to
//! InstanceRegistry's deinit hook (lane tpg).
//!
//! What is checked, in src/, tools/ and tests/ (generated code included: it
//! probes the impls for init, deinit, initOwn, ...), through std.zig's
//! tokenizer:
//!   * Every `@hasDecl(X, "name")`, `std.meta.hasFn(X, "name")` and
//!     `std.meta.hasMethod(X, "name")` - and `@hasDecl(X, name)` inside an
//!     `inline for (.{ "a", "b" }) |name|`, once per string.
//!   * X is resolved to the containers it can name: a struct (union, enum,
//!     opaque) declared in scope, `@This()`, an `@import` of a file or of a
//!     module (build.zig's `graphModule` names, and the engine and devtools
//!     facades), a `const` alias of any of these, a field chain through them
//!     (`css.typed_om.Numeric`), and a generic function's `comptime T: type`
//!     parameter - through every call of that function, recursively, the
//!     receiver of a method call counted.
//!   * A resolved probe whose container declares the name, and only without
//!     `pub`, FAILS - no baseline: make the declaration `pub` (or rename it,
//!     when the probe was never meant to find it).
//!   * A probe X cannot be resolved for (an `anytype` argument's type, a
//!     computed type) needs a `// hasdecl: <which types reach it, and that
//!     they declare the name pub>` line on it or in the comment block directly
//!     above. The unannotated ones are a ratchet:
//!     tools/hasdecl_baseline.txt records them per file and only goes down
//!     (`zig build lint-hasdecl -- --update`; `-- --list` prints each with the
//!     private declarations of its name - the suspects to audit).

const std = @import("std");
// stdout as a stream: Zig 0.17's positional File.writer overwrites a shared log.
const stdout_stream = @import("stdout_stream.zig");
const Token = std.zig.Token;

/// A token as the lint keeps it: 12 bytes where std's is 24 - the scanned
/// trees are ~15 million tokens.
const Tok = struct {
    tag: Token.Tag,
    start: u32,
    end: u32,
};
const Allocator = std.mem.Allocator;

const baseline_path = "tools/hasdecl_baseline.txt";
const annotation_marker = "// hasdecl:";

/// The trees held to the rule.
const scanned_roots = [_][]const u8{ "src", "tools", "tests" };

/// Not built (codegen's stubs for hand merging), or not ours (upstream WPT).
const exempt_prefixes = [_][]const u8{ "src/webidl/impls_tmp/", "tests/wpt/" };

/// Whether the walk leaves the directory `path` (no trailing '/') without
/// reading it: an exempt tree, or a build's cache or output.
pub fn skipsDirectory(path: []const u8) bool {
    const base = std.fs.path.basename(path);
    if (std.mem.eql(u8, base, ".zig-cache") or std.mem.eql(u8, base, "zig-out")) return true;
    for (exempt_prefixes) |prefix| {
        // `prefix` names a directory with its trailing '/'.
        if (std.mem.eql(u8, path, prefix[0 .. prefix.len - 1])) return true;
        if (std.mem.startsWith(u8, path, prefix)) return true;
    }
    return false;
}

pub fn isScanned(path: []const u8) bool {
    if (!std.mem.endsWith(u8, path, ".zig")) return false;
    if (std.mem.indexOf(u8, path, ".zig-cache/") != null) return false;
    if (std.mem.indexOf(u8, path, "zig-out/") != null) return false;
    for (exempt_prefixes) |prefix| if (std.mem.startsWith(u8, path, prefix)) return false;
    for (scanned_roots) |root| {
        if (std.mem.startsWith(u8, path, root) and path.len > root.len and path[root.len] == '/') return true;
    }
    return false;
}

/// Modules build.zig makes other than through `graphModule(b, _, "name", .{
/// .root_source_file = b.path("...") ...`: the engine's facade
/// (engineProtocolBinding), the devtools module (its path chosen by -Dcdp)
/// and the impls.
const extra_modules = [_][2][]const u8{
    .{ "engine", "src/runtime/engine_protocol.zig" },
    .{ "devtools", "src/devtools/root.zig" },
    .{ "impls", "src/webidl/impls/root.zig" },
};

// ---------------------------------------------------------------------------
// The model: files, scopes, probes, calls
// ---------------------------------------------------------------------------

pub const SourceFile = struct {
    path: []const u8,
    source: [:0]const u8,
};

const Range = struct { start: u32, end: u32 };

const Decl = struct {
    any_pub: bool,
    line: u32,
};

const Param = struct {
    name: ?[]const u8,
    is_type: bool,
};

const Scope = struct {
    kind: enum { file, container, func },
    file: *File,
    name: []const u8,
    parent: ?*Scope,
    /// Containers: their declarations by name.
    decls: std.StringHashMapUnmanaged(Decl) = .empty,
    /// Containers and functions: the initialiser of each `const` that is
    /// not itself a container.
    inits: std.StringHashMapUnmanaged(Range) = .empty,
    /// Containers: the containers declared in them, by name.
    children: std.StringHashMapUnmanaged(*Scope) = .empty,
    /// Functions: their parameters, and whether a call `x.f(...)` passes the
    /// receiver as the first.
    params: []const Param = &.{},
    is_method: bool = false,

    fn container(self: *Scope) *Scope {
        var s = self;
        while (s.kind == .func) s = s.parent.?;
        return s;
    }

    fn path(self: *const Scope, gpa: Allocator) ![]const u8 {
        var parts: std.ArrayList([]const u8) = .empty;
        var s: ?*const Scope = self;
        while (s) |cur| : (s = cur.parent) {
            if (cur.kind == .file) break;
            try parts.append(gpa, cur.name);
        }
        if (parts.items.len == 0) return "<file>";
        std.mem.reverse([]const u8, parts.items);
        return std.mem.join(gpa, ".", parts.items);
    }
};

const File = struct {
    path: []const u8,
    source: [:0]const u8,
    tokens: []const Tok,
    line_starts: []const u32,
    root: *Scope = undefined,

    fn text(self: *const File, index: u32) []const u8 {
        const t = self.tokens[index];
        return self.source[t.start..t.end];
    }

    fn tag(self: *const File, index: u32) Token.Tag {
        return self.tokens[index].tag;
    }

    /// The contents of a plain string literal (no escapes in a declaration
    /// name).
    fn stringContents(self: *const File, index: u32) []const u8 {
        const t = self.text(index);
        if (t.len < 2) return t;
        return t[1 .. t.len - 1];
    }

    fn lineOf(self: *const File, index: u32) u32 {
        const offset: u32 = self.tokens[index].start;
        var lo: usize = 0;
        var hi: usize = self.line_starts.len;
        while (hi - lo > 1) {
            const mid = (lo + hi) / 2;
            if (self.line_starts[mid] <= offset) lo = mid else hi = mid;
        }
        return @intCast(lo + 1);
    }
};

const Probe = struct {
    file: *File,
    scope: *Scope,
    token: u32,
    builtin: []const u8,
    arg: Range,
    names: []const []const u8,
};

/// A call `f(...)`: where it is. Its arguments are split only when a
/// generic's parameter asks for them (`argsOf`) - a few hundred of the
/// millions of calls the trees make; splitting every one made the parse the
/// lint's cost (lane tpf: minutes on a loaded chat2).
const Call = struct {
    scope: *Scope,
    /// The `(`'s token.
    open: u32,
    dotted: bool,
    args: ?[]const Range = null,

    fn argsOf(self: *Call, arena: Allocator) ![]const Range {
        if (self.args) |known| return known;
        const split = try callArgs(arena, self.scope.file, self.open);
        self.args = split.args;
        return split.args;
    }
};

pub const Model = struct {
    arena: Allocator,
    files: std.StringHashMapUnmanaged(*File) = .empty,
    modules: std.StringHashMapUnmanaged([]const u8) = .empty,
    probes: std.ArrayList(Probe) = .empty,
    calls: std.StringHashMapUnmanaged(std.ArrayList(Call)) = .empty,
    memo: std.AutoHashMapUnmanaged(MemoKey, ?[]const *Scope) = .empty,

    const MemoKey = struct { scope: *Scope, start: u32, end: u32 };
};

// ---------------------------------------------------------------------------
// Reading a file
// ---------------------------------------------------------------------------

fn tokenize(arena: Allocator, source: [:0]const u8) ![]const Tok {
    var list: std.ArrayList(Tok) = .empty;
    // About one token per six bytes: one allocation, mostly.
    try list.ensureTotalCapacity(arena, source.len / 6 + 16);
    var tokenizer = std.zig.Tokenizer.init(source);
    while (true) {
        const tok = tokenizer.next();
        if (tok.tag == .eof) break;
        // Doc comments are tokens; nothing here reads them.
        if (tok.tag == .doc_comment or tok.tag == .container_doc_comment) continue;
        try list.append(arena, .{ .tag = tok.tag, .start = @intCast(tok.loc.start), .end = @intCast(tok.loc.end) });
    }
    return list.items;
}

fn lineStarts(arena: Allocator, source: []const u8) ![]const u32 {
    var list: std.ArrayList(u32) = .empty;
    try list.append(arena, 0);
    for (source, 0..) |c, i| if (c == '\n') try list.append(arena, @intCast(i + 1));
    return list.items;
}

fn isContainerKeyword(tag: Token.Tag) bool {
    return switch (tag) {
        .keyword_struct, .keyword_union, .keyword_enum, .keyword_opaque => true,
        else => false,
    };
}

fn isOpen(tag: Token.Tag) bool {
    return tag == .l_paren or tag == .l_bracket or tag == .l_brace;
}

fn isClose(tag: Token.Tag) bool {
    return tag == .r_paren or tag == .r_bracket or tag == .r_brace;
}

/// The comma-separated arguments of the call whose `(` is at `open`, and the
/// index of its `)`.
fn callArgs(arena: Allocator, file: *const File, open: u32) !struct { args: []const Range, close: u32 } {
    var args: std.ArrayList(Range) = .empty;
    var depth: usize = 0;
    var i = open + 1;
    var start = i;
    const n: u32 = @intCast(file.tokens.len);
    while (i < n) : (i += 1) {
        const tag = file.tag(i);
        if (isOpen(tag)) depth += 1;
        if (isClose(tag)) {
            if (depth == 0) break;
            depth -= 1;
        }
        if (tag == .comma and depth == 0) {
            if (i > start) try args.append(arena, .{ .start = start, .end = i });
            start = i + 1;
        }
    }
    if (i > start) try args.append(arena, .{ .start = start, .end = i });
    return .{ .args = args.items, .close = i };
}

/// The token range of an initialiser starting at `start`: up to the `;` at
/// depth 0, or a container's `{`.
fn initRange(file: *const File, start: u32) Range {
    var depth: usize = 0;
    var i = start;
    const n: u32 = @intCast(file.tokens.len);
    while (i < n) : (i += 1) {
        const tag = file.tag(i);
        if (tag == .l_paren or tag == .l_bracket) depth += 1;
        if (tag == .r_paren or tag == .r_bracket) depth -|= 1;
        if (depth == 0 and (tag == .semicolon or tag == .l_brace)) break;
    }
    return .{ .start = start, .end = i };
}

fn initNamesContainer(file: *const File, range: Range) bool {
    var i = range.start;
    var seen: usize = 0;
    while (i < range.end and seen < 6) : ({
        i += 1;
        seen += 1;
    }) if (isContainerKeyword(file.tag(i))) return true;
    return false;
}

/// A loop binding of `inline for (.{ "a", "b" }) |name|`: active while the
/// brace it opened is.
const LoopBinding = struct { name: []const u8, values: []const []const u8 };

const Brace = struct { scope: ?*Scope, loop: ?LoopBinding };

fn parseFile(model: *Model, file: *File) !void {
    const arena = model.arena;
    const root = try arena.create(Scope);
    root.* = .{ .kind = .file, .file = file, .name = "", .parent = null };
    file.root = root;

    var stack: std.ArrayList(*Scope) = .empty;
    try stack.append(arena, root);
    var braces: std.ArrayList(Brace) = .empty;
    var pending_container: ?[]const u8 = null;
    var pending_fn: ?*Scope = null;
    var pending_loop: ?LoopBinding = null;

    const n: u32 = @intCast(file.tokens.len);
    var i: u32 = 0;
    while (i < n) : (i += 1) {
        const tag = file.tag(i);
        const top = stack.items[stack.items.len - 1];

        if (tag == .l_brace) {
            var pushed: ?*Scope = null;
            if (pending_fn) |f| {
                pushed = f;
                pending_fn = null;
            } else if (pending_container) |name| {
                const sc = try arena.create(Scope);
                sc.* = .{ .kind = .container, .file = file, .name = name, .parent = top };
                const cont = top.container();
                const gop = try cont.children.getOrPut(arena, name);
                if (!gop.found_existing) gop.value_ptr.* = sc;
                // A function-local struct is the function's.
                if (top.kind == .func) {
                    const local = try top.children.getOrPut(arena, name);
                    if (!local.found_existing) local.value_ptr.* = sc;
                }
                pushed = sc;
                pending_container = null;
            } else {
                // An anonymous container: `struct {`, `union(enum) {`.
                var j: i64 = @as(i64, i) - 1;
                var depth: usize = 0;
                while (j >= 0) : (j -= 1) {
                    const t = file.tag(@intCast(j));
                    if (t == .r_paren) depth += 1 else if (t == .l_paren) {
                        if (depth == 0) break;
                        depth -= 1;
                    } else if (depth == 0) break;
                }
                if (j >= 0 and isContainerKeyword(file.tag(@intCast(j)))) {
                    const sc = try arena.create(Scope);
                    sc.* = .{ .kind = .container, .file = file, .name = "<anon>", .parent = top };
                    pushed = sc;
                }
            }
            if (pushed) |sc| try stack.append(arena, sc);
            try braces.append(arena, .{ .scope = pushed, .loop = pending_loop });
            pending_loop = null;
            continue;
        }
        if (tag == .r_brace) {
            if (braces.pop()) |b| {
                if (b.scope != null) _ = stack.pop();
            }
            continue;
        }

        // `inline for (.{ "a", "b" }) |name|`
        if (tag == .keyword_for and i >= 1 and file.tag(i - 1) == .keyword_inline and i + 3 < n and
            file.tag(i + 1) == .l_paren and file.tag(i + 2) == .period and file.tag(i + 3) == .l_brace)
        {
            var values: std.ArrayList([]const u8) = .empty;
            var j = i + 4;
            var ok = true;
            while (j < n and file.tag(j) != .r_brace) : (j += 1) {
                switch (file.tag(j)) {
                    .string_literal => try values.append(arena, file.stringContents(j)),
                    .comma => {},
                    else => {
                        ok = false;
                        break;
                    },
                }
            }
            if (ok and j + 4 < n and file.tag(j + 1) == .r_paren and file.tag(j + 2) == .pipe and file.tag(j + 3) == .identifier and file.tag(j + 4) == .pipe) {
                pending_loop = .{ .name = file.text(j + 3), .values = values.items };
                // Past the tuple's braces: the binding is the body's.
                i = j + 4;
            }
            continue;
        }

        // A function's header: its parameters, then its body's `{`.
        if (tag == .keyword_fn and i + 2 < n and file.tag(i + 1) == .identifier and file.tag(i + 2) == .l_paren) {
            const f = try arena.create(Scope);
            f.* = .{ .kind = .func, .file = file, .name = file.text(i + 1), .parent = top };
            const header = try callArgs(arena, file, i + 2);
            var params: std.ArrayList(Param) = .empty;
            for (header.args, 0..) |range, index| {
                var s = range.start;
                while (s < range.end and (file.tag(s) == .keyword_comptime or file.tag(s) == .keyword_noalias)) s += 1;
                var p: Param = .{ .name = null, .is_type = false };
                if (s + 1 < range.end and file.tag(s) == .identifier and file.tag(s + 1) == .colon) {
                    p.name = file.text(s);
                    p.is_type = s + 3 == range.end and file.tag(s + 2) == .identifier and std.mem.eql(u8, file.text(s + 2), "type");
                    if (index == 0) {
                        if (std.mem.eql(u8, p.name.?, "self")) f.is_method = true;
                        var t = s + 2;
                        while (t < range.end) : (t += 1) {
                            const word = file.text(t);
                            if (std.mem.eql(u8, word, "Self") or std.mem.eql(u8, word, "@This")) f.is_method = true;
                        }
                    }
                }
                try params.append(arena, p);
            }
            f.params = params.items;
            // The body's `{` (a prototype ends with `;`).
            var j = header.close + 1;
            var depth: usize = 0;
            while (j < n) : (j += 1) {
                const t = file.tag(j);
                if (t == .l_paren or t == .l_bracket) depth += 1;
                if (t == .r_paren or t == .r_bracket) depth -|= 1;
                if (depth == 0 and (t == .l_brace or t == .semicolon)) break;
            }
            if (j < n and file.tag(j) == .l_brace) pending_fn = f;
        }

        // A `test` or `comptime` block of a container: a scope of its own, so
        // that its locals are no container's declarations.
        if ((top.kind == .container or top.kind == .file) and (tag == .keyword_test or (tag == .keyword_comptime and i + 1 < n and file.tag(i + 1) == .l_brace))) {
            const f = try arena.create(Scope);
            f.* = .{ .kind = .func, .file = file, .name = if (tag == .keyword_test) "<test>" else "<comptime>", .parent = top };
            pending_fn = f;
            continue;
        }

        // A declaration of a container (or the file).
        if ((top.kind == .container or top.kind == .file) and atDeclStart(file, i)) {
            var j = i;
            var any_pub = false;
            while (j < n) {
                switch (file.tag(j)) {
                    .keyword_pub => any_pub = true,
                    .keyword_inline, .keyword_export, .keyword_threadlocal, .keyword_noinline => {},
                    .keyword_extern => if (j + 1 < n and file.tag(j + 1) == .string_literal) {
                        j += 1;
                    },
                    else => break,
                }
                j += 1;
            }
            const kind = if (j < n) file.tag(j) else .eof;
            if ((kind == .keyword_const or kind == .keyword_var or kind == .keyword_fn) and j + 1 < n and file.tag(j + 1) == .identifier) {
                const name = file.text(j + 1);
                const gop = try top.decls.getOrPut(arena, name);
                if (!gop.found_existing) {
                    gop.value_ptr.* = .{ .any_pub = any_pub, .line = file.lineOf(j + 1) };
                } else if (any_pub) gop.value_ptr.any_pub = true;
                if (kind != .keyword_fn) {
                    var m = j + 2;
                    while (m < n and file.tag(m) != .equal and file.tag(m) != .semicolon) m += 1;
                    if (m < n and file.tag(m) == .equal) {
                        const range = initRange(file, m + 1);
                        if (initNamesContainer(file, range)) {
                            pending_container = name;
                        } else {
                            try top.inits.put(arena, name, range);
                        }
                    }
                    i = j + 1;
                    continue;
                }
            }
        }

        // A function's local `const`: an alias (`const Meta = T.Meta;`) or a
        // local struct.
        if (top.kind == .func and tag == .keyword_const and i + 2 < n and file.tag(i + 1) == .identifier and file.tag(i + 2) == .equal) {
            const range = initRange(file, i + 3);
            if (initNamesContainer(file, range)) {
                pending_container = file.text(i + 1);
            } else {
                try top.inits.put(arena, file.text(i + 1), range);
            }
        }

        // A probe.
        const is_probe = (tag == .builtin and std.mem.eql(u8, file.text(i), "@hasDecl")) or
            (tag == .identifier and i >= 1 and file.tag(i - 1) == .period and
                (std.mem.eql(u8, file.text(i), "hasFn") or std.mem.eql(u8, file.text(i), "hasMethod")));
        if (is_probe and i + 1 < n and file.tag(i + 1) == .l_paren) {
            const call = try callArgs(arena, file, i + 1);
            if (call.args.len == 2) {
                const second = call.args[1];
                var names: []const []const u8 = &.{};
                if (second.end == second.start + 1 and file.tag(second.start) == .string_literal) {
                    const one = try arena.alloc([]const u8, 1);
                    one[0] = file.stringContents(second.start);
                    names = one;
                } else if (second.end == second.start + 1 and file.tag(second.start) == .identifier) {
                    const ident = file.text(second.start);
                    var b = braces.items.len;
                    while (b > 0) {
                        b -= 1;
                        if (braces.items[b].loop) |loop| if (std.mem.eql(u8, loop.name, ident)) {
                            names = loop.values;
                            break;
                        };
                    }
                }
                try model.probes.append(arena, .{
                    .file = file,
                    .scope = top,
                    .token = i,
                    .builtin = file.text(i),
                    .arg = call.args[0],
                    .names = names,
                });
            }
        }

        // A call `f(...)`, `x.f(...)`: what a generic's type parameter is.
        if (tag == .identifier and i + 1 < n and file.tag(i + 1) == .l_paren and !(i >= 1 and file.tag(i - 1) == .keyword_fn)) {
            const gop = try model.calls.getOrPut(arena, file.text(i));
            if (!gop.found_existing) gop.value_ptr.* = .empty;
            try gop.value_ptr.append(arena, .{ .scope = top, .open = i + 1, .dotted = i >= 1 and file.tag(i - 1) == .period });
        }
    }
}

/// Whether token `i` starts a declaration: after `;`, `{`, `}`, a field's
/// `,`, or at the file's start.
fn atDeclStart(file: *const File, i: u32) bool {
    switch (file.tag(i)) {
        .keyword_pub, .keyword_const, .keyword_var, .keyword_fn, .keyword_inline, .keyword_export, .keyword_extern, .keyword_threadlocal, .keyword_noinline => {},
        else => return false,
    }
    if (i == 0) return true;
    // A declaration after a field follows its comma.
    return switch (file.tag(i - 1)) {
        .semicolon, .l_brace, .r_brace, .comma => true,
        else => false,
    };
}

/// build.zig's `graphModule(b, _, "name", .{ .root_source_file = b.path("...")`.
pub fn readModules(model: *Model, build_zig: [:0]const u8) !void {
    const arena = model.arena;
    for (extra_modules) |m| try model.modules.put(arena, m[0], m[1]);
    const tokens = try tokenize(arena, build_zig);
    var file: File = .{ .path = "build.zig", .source = build_zig, .tokens = tokens, .line_starts = &.{} };
    const n: u32 = @intCast(tokens.len);
    var i: u32 = 0;
    while (i + 18 < n) : (i += 1) {
        if (file.tag(i) != .identifier or !std.mem.eql(u8, file.text(i), "graphModule")) continue;
        // graphModule ( b , X , "name" , . { . root_source_file = b . path ( "path"
        //      i      1 2 3 4 5   6    7 8 9 10       11        12 13 14 15 16  17
        if (file.tag(i + 1) != .l_paren or file.tag(i + 6) != .string_literal) continue;
        if (file.tag(i + 11) != .identifier or !std.mem.eql(u8, file.text(i + 11), "root_source_file")) continue;
        if (file.tag(i + 17) != .string_literal) continue;
        const name = file.stringContents(i + 6);
        if (!model.modules.contains(name)) try model.modules.put(arena, name, file.stringContents(i + 17));
    }
}

pub fn addFile(model: *Model, path: []const u8, source: [:0]const u8) !void {
    const arena = model.arena;
    const file = try arena.create(File);
    file.* = .{
        .path = path,
        .source = source,
        .tokens = try tokenize(arena, source),
        .line_starts = try lineStarts(arena, source),
    };
    try model.files.put(arena, path, file);
    try parseFile(model, file);
}

// ---------------------------------------------------------------------------
// Resolving a probe's container
// ---------------------------------------------------------------------------

const Found = union(enum) {
    container: *Scope,
    init: struct { owner: *Scope, range: Range },
    param: struct { func: *Scope, index: usize },
};

fn find(scope: *Scope, ident: []const u8) ?Found {
    var s: ?*Scope = scope;
    while (s) |cur| : (s = cur.parent) {
        if (cur.children.get(ident)) |child| return .{ .container = child };
        if (cur.inits.get(ident)) |range| return .{ .init = .{ .owner = cur, .range = range } };
        if (cur.kind == .func) {
            for (cur.params, 0..) |p, index| {
                if (p.name) |name| if (std.mem.eql(u8, name, ident)) return .{ .param = .{ .func = cur, .index = index } };
            }
        }
    }
    return null;
}

fn normalize(arena: Allocator, base: []const u8, rel: []const u8) ![]const u8 {
    const dir = std.fs.path.dirname(base) orelse ".";
    const joined = try std.fs.path.join(arena, &.{ dir, rel });
    // Resolve `..` and `.` textually, '/' separated.
    var parts: std.ArrayList([]const u8) = .empty;
    var it = std.mem.tokenizeScalar(u8, joined, '/');
    while (it.next()) |part| {
        if (std.mem.eql(u8, part, ".")) continue;
        if (std.mem.eql(u8, part, "..")) {
            _ = parts.pop();
            continue;
        }
        try parts.append(arena, part);
    }
    return std.mem.join(arena, "/", parts.items);
}

fn importTarget(model: *Model, scope: *Scope, spec: []const u8) !?*Scope {
    if (std.mem.endsWith(u8, spec, ".zig")) {
        const p = try normalize(model.arena, scope.file.path, spec);
        const f = model.files.get(p) orelse return null;
        return f.root;
    }
    if (model.modules.get(spec)) |p| {
        const f = model.files.get(p) orelse return null;
        return f.root;
    }
    // Each impl is a module of its own, named by its file
    // (build.zig implModuleNames): src/webidl/impls/root.zig's
    // `pub const Comment = @import("Comment");`.
    const impl_path = try std.fmt.allocPrint(model.arena, "src/webidl/impls/{s}.zig", .{spec});
    const f = model.files.get(impl_path) orelse return null;
    return f.root;
}

fn member(model: *Model, container: *Scope, name: []const u8, depth: usize) anyerror!?[]const *Scope {
    if (container.children.get(name)) |child| {
        const one = try model.arena.alloc(*Scope, 1);
        one[0] = child;
        return one;
    }
    if (container.inits.get(name)) |range| return resolve(model, container.file, container, range, depth + 1);
    return null;
}

/// The containers the expression `range` of `file`, in `scope`, can name;
/// null when it cannot be told.
fn resolve(model: *Model, file: *File, scope: *Scope, range: Range, depth: usize) anyerror!?[]const *Scope {
    const key: Model.MemoKey = .{ .scope = scope, .start = range.start, .end = range.end };
    if (model.memo.get(key)) |known| return known;
    try model.memo.put(model.arena, key, null); // a cycle reads "cannot be told"
    const result = try resolveUncached(model, file, scope, range, depth);
    try model.memo.put(model.arena, key, result);
    return result;
}

/// `items` onto `list`, each container once: a list kept with its
/// duplicates doubled at every generic a type passes through twice, and a
/// chain of them in the tree grew past 10 GB.
fn appendDistinct(arena: Allocator, list: *std.ArrayList(*Scope), items: []const *Scope) !void {
    for (items) |item| {
        if (std.mem.indexOfScalar(*Scope, list.items, item) == null) try list.append(arena, item);
    }
}

fn resolveUncached(model: *Model, file: *File, scope: *Scope, range: Range, depth: usize) anyerror!?[]const *Scope {
    if (depth > 10 or range.end <= range.start) return null;
    const arena = model.arena;
    var at = range.start;
    var current: std.ArrayList(*Scope) = .empty;
    const head = file.tag(at);
    if (head == .builtin and std.mem.eql(u8, file.text(at), "@This") and at + 2 < range.end + 1 and file.tag(at + 1) == .l_paren and file.tag(at + 2) == .r_paren) {
        try current.append(arena, scope.container());
        at += 3;
    } else if (head == .builtin and std.mem.eql(u8, file.text(at), "@import") and at + 3 < range.end + 1 and file.tag(at + 1) == .l_paren and file.tag(at + 2) == .string_literal and file.tag(at + 3) == .r_paren) {
        const target = (try importTarget(model, scope, file.stringContents(at + 2))) orelse return null;
        try current.append(arena, target);
        at += 4;
    } else if (head == .identifier) {
        const found = find(scope, file.text(at)) orelse return null;
        switch (found) {
            .container => |c| try current.append(arena, c),
            .init => |init| {
                const r = (try resolve(model, init.owner.file, init.owner, init.range, depth + 1)) orelse return null;
                try appendDistinct(arena, &current, r);
            },
            .param => |param| {
                const func = param.func;
                if (!func.params[param.index].is_type) return null;
                const sites = model.calls.getPtr(func.name) orelse return null;
                for (sites.items) |*site| {
                    const index = if (func.is_method and site.dotted) (std.math.sub(usize, param.index, 1) catch continue) else param.index;
                    const args = try site.argsOf(arena);
                    if (index >= args.len) continue;
                    const r = (try resolve(model, site.scope.file, site.scope, args[index], depth + 1)) orelse continue;
                    try appendDistinct(arena, &current, r);
                }
                if (current.items.len == 0) return null;
            },
        }
        at += 1;
    } else return null;

    // A field chain.
    while (at < range.end) {
        if (file.tag(at) != .period or at + 1 >= range.end or file.tag(at + 1) != .identifier) return null;
        const name = file.text(at + 1);
        var next: std.ArrayList(*Scope) = .empty;
        for (current.items) |c| {
            const m = (try member(model, c, name, depth)) orelse return null;
            try appendDistinct(arena, &next, m);
        }
        current = next;
        at += 2;
    }
    return current.items;
}

// ---------------------------------------------------------------------------
// The findings
// ---------------------------------------------------------------------------

pub const Private = struct {
    path: []const u8,
    line: u32,
    probe: []const u8,
    name: []const u8,
    target_path: []const u8,
    target_line: u32,
    target: []const u8,
};

pub const Unresolved = struct {
    path: []const u8,
    line: u32,
    probe: []const u8,
    names: []const []const u8,
    annotated: bool,
};

pub const Report = struct {
    private: std.ArrayList(Private) = .empty,
    unresolved: std.ArrayList(Unresolved) = .empty,
};

/// Whether the probe on `line` has a `// hasdecl: <why>` on that line or in
/// the comment block directly above it.
pub fn annotated(source: []const u8, line: u32) bool {
    var line_start: usize = 0;
    var current: u32 = 1;
    while (current < line) : (current += 1) {
        const nl = std.mem.indexOfScalarPos(u8, source, line_start, '\n') orelse return false;
        line_start = nl + 1;
    }
    const line_end = std.mem.indexOfScalarPos(u8, source, line_start, '\n') orelse source.len;
    if (std.mem.indexOf(u8, source[line_start..line_end], annotation_marker)) |at| {
        if (std.mem.trim(u8, source[line_start + at + annotation_marker.len .. line_end], " \t\r").len > 0) return true;
    }
    var end = line_start;
    while (end > 0) {
        const prev_end = end - 1;
        const prev_start = if (std.mem.lastIndexOfScalar(u8, source[0..prev_end], '\n')) |i| i + 1 else 0;
        const text = std.mem.trim(u8, source[prev_start..prev_end], " \t\r");
        if (!std.mem.startsWith(u8, text, "//")) return false;
        if (std.mem.startsWith(u8, text, annotation_marker) and std.mem.trim(u8, text[annotation_marker.len..], " \t").len > 0) return true;
        end = prev_start;
    }
    return false;
}

fn probeText(arena: Allocator, probe: Probe) ![]const u8 {
    var list: std.ArrayList(u8) = .empty;
    try list.appendSlice(arena, probe.builtin);
    try list.append(arena, '(');
    var i = probe.arg.start;
    while (i < probe.arg.end) : (i += 1) try list.appendSlice(arena, probe.file.text(i));
    try list.appendSlice(arena, ", ...)");
    return list.items;
}

pub fn analyze(model: *Model) !Report {
    const arena = model.arena;
    var report: Report = .{};
    for (model.probes.items) |probe| {
        if (probe.names.len == 0) continue; // a computed name: the conformance checks, which fail loudly
        const line = probe.file.lineOf(probe.token);
        const targets = (try resolve(model, probe.file, probe.scope, probe.arg, 0)) orelse {
            try report.unresolved.append(arena, .{
                .path = probe.file.path,
                .line = line,
                .probe = try probeText(arena, probe),
                .names = probe.names,
                .annotated = annotated(probe.file.source, line),
            });
            continue;
        };
        for (probe.names) |name| {
            var seen: std.AutoHashMapUnmanaged(*Scope, void) = .empty;
            for (targets) |target| {
                if ((try seen.getOrPut(arena, target)).found_existing) continue;
                const decl = target.decls.get(name) orelse continue;
                if (decl.any_pub) continue;
                try report.private.append(arena, .{
                    .path = probe.file.path,
                    .line = line,
                    .probe = try probeText(arena, probe),
                    .name = name,
                    .target_path = target.file.path,
                    .target_line = decl.line,
                    .target = try target.path(arena),
                });
            }
        }
    }
    return report;
}

/// Every container declaring `name` only without `pub`: the suspects of an
/// unresolved probe of that name (`--list`).
fn suspects(model: *Model, name: []const u8, out: *std.ArrayList([]const u8)) !void {
    var files = model.files.valueIterator();
    while (files.next()) |file| try suspectsIn(model, file.*.root, name, out);
}

fn suspectsIn(model: *Model, scope: *Scope, name: []const u8, out: *std.ArrayList([]const u8)) !void {
    if (scope.decls.get(name)) |decl| if (!decl.any_pub and scope.kind != .file) {
        try out.append(model.arena, try std.fmt.allocPrint(model.arena, "{s}:{d} {s}", .{ scope.file.path, decl.line, try scope.path(model.arena) }));
    };
    var children = scope.children.valueIterator();
    while (children.next()) |child| if (child.*.parent == scope) try suspectsIn(model, child.*, name, out);
}

// ---------------------------------------------------------------------------
// The baseline: unannotated unresolved probes per file
// ---------------------------------------------------------------------------

pub const Counts = std.StringHashMapUnmanaged(u32);

pub fn countUnannotated(arena: Allocator, report: *const Report) !Counts {
    var counts: Counts = .empty;
    for (report.unresolved.items) |u| {
        if (u.annotated) continue;
        const gop = try counts.getOrPut(arena, u.path);
        if (!gop.found_existing) gop.value_ptr.* = 0;
        gop.value_ptr.* += 1;
    }
    return counts;
}

pub fn parseBaseline(arena: Allocator, text: []const u8) !Counts {
    var counts: Counts = .empty;
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        const space = std.mem.lastIndexOfScalar(u8, line, ' ') orelse return error.BadBaseline;
        const count = std.fmt.parseInt(u32, line[space + 1 ..], 10) catch return error.BadBaseline;
        try counts.put(arena, try arena.dupe(u8, line[0..space]), count);
    }
    return counts;
}

fn lessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.order(u8, a, b) == .lt;
}

pub fn formatBaseline(arena: Allocator, counts: *const Counts) ![]u8 {
    var keys: std.ArrayList([]const u8) = .empty;
    var it = counts.keyIterator();
    while (it.next()) |k| try keys.append(arena, k.*);
    std.mem.sort([]const u8, keys.items, {}, lessThan);
    var out: std.ArrayList(u8) = .empty;
    try out.appendSlice(arena, "# tools/lint_hasdecl.zig: @hasDecl/hasFn/hasMethod probes whose container cannot be resolved and that carry no\n" ++
        "# `// hasdecl: <why>` line, per file. Only goes down: `zig build lint-hasdecl -- --update` after annotating or\n" ++
        "# resolving some (`-- --list` shows each, with the private declarations of its name). Never edited by hand.\n");
    for (keys.items) |k| try out.print(arena, "{s} {d}\n", .{ k, counts.get(k).? });
    return out.items;
}

pub const Violation = struct { path: []const u8, allowed: u32, found: u32 };

pub fn violations(arena: Allocator, current: *const Counts, baseline: *const Counts) !std.ArrayList(Violation) {
    var out: std.ArrayList(Violation) = .empty;
    var it = current.iterator();
    while (it.next()) |entry| {
        const allowed = baseline.get(entry.key_ptr.*) orelse 0;
        if (entry.value_ptr.* > allowed) try out.append(arena, .{ .path = entry.key_ptr.*, .allowed = allowed, .found = entry.value_ptr.* });
    }
    return out;
}

// ---------------------------------------------------------------------------
// The tool
// ---------------------------------------------------------------------------

fn scan(model: *Model, io: std.Io) !void {
    const arena = model.arena;
    const build_zig = try std.Io.Dir.cwd().readFileAllocOptions(io, "build.zig", arena, .limited(64 << 20), .of(u8), 0);
    try readModules(model, build_zig);
    try scanTree(model, io, std.Io.Dir.cwd());
}

/// Every scanned file under `top`, parsed into `model` in path order: what a
/// probe resolves to depends on the order the files were parsed in (the memo
/// cuts a cycle where it is first met), and a walk lists a directory in its
/// file system's order - sorted on APFS, by hash on ext4 - so parsed as
/// listed, one tree gave macOS and Linux different reports.
fn scanTree(model: *Model, io: std.Io, top: std.Io.Dir) !void {
    const arena = model.arena;
    var paths: std.ArrayList([]const u8) = .empty;
    for (scanned_roots) |root| {
        var dir = top.openDir(io, root, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        defer dir.close(io);
        var walker = try dir.walk(arena);
        defer walker.deinit();
        var buffer: [std.Io.Dir.max_path_bytes]u8 = undefined;
        while (try walker.next(io)) |entry| {
            const path = std.fmt.bufPrint(&buffer, "{s}/{s}", .{ root, entry.path }) catch continue;
            std.mem.replaceScalar(u8, path, '\\', '/');
            // Never into a tree no file of is scanned (the WPT checkout under
            // tests/wpt/ is the size of everything else together: walked
            // through, the lint took ten minutes on chat2 - lane tpf).
            if (entry.kind == .directory) {
                if (skipsDirectory(path)) walker.leave(io);
                continue;
            }
            if (entry.kind != .file or !isScanned(path)) continue;
            try paths.append(arena, try arena.dupe(u8, path));
        }
    }
    std.mem.sort([]const u8, paths.items, {}, lessThan);
    for (paths.items) |path| {
        const text = try top.readFileAllocOptions(io, path, arena, .limited(64 << 20), .of(u8), 0);
        try addFile(model, path, text);
    }
}

fn usage() noreturn {
    std.debug.print("usage: lint_hasdecl [--update | --list] [--time]\n", .{});
    std.process.exit(2);
}

pub fn main(init: std.process.Init) !void {
    var arena_state = std.heap.ArenaAllocator.init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = init.io;

    var update = false;
    var list = false;
    var time = false;
    var args = try init.minimal.args.iterateAllocator(arena);
    defer args.deinit();
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--update")) update = true else if (std.mem.eql(u8, arg, "--list")) list = true else if (std.mem.eql(u8, arg, "--time")) time = true else usage();
    }

    var model: Model = .{ .arena = arena };
    const started = std.Io.Timestamp.now(io, .awake);
    try scan(&model, io);
    const scanned = std.Io.Timestamp.now(io, .awake);
    const report = try analyze(&model);
    if (time) {
        // Where the run's time and memory go (`--time`).
        var tokens: usize = 0;
        var bytes: usize = 0;
        var files = model.files.valueIterator();
        while (files.next()) |file| {
            tokens += file.*.tokens.len;
            bytes += file.*.source.len;
        }
        var calls: usize = 0;
        var names = model.calls.valueIterator();
        while (names.next()) |sites| calls += sites.items.len;
        const scan_ns = started.untilNow(io, .awake).toNanoseconds() - scanned.untilNow(io, .awake).toNanoseconds();
        const analyze_ns = scanned.untilNow(io, .awake).toNanoseconds();
        std.debug.print("hasdecl --time: {d} files, {d} bytes, {d} tokens, {d} calls under {d} names, {d} probes, {d} memoized resolutions, arena {d} bytes; scan+parse {d} ms, analysis {d} ms\n", .{
            model.files.count(), bytes, tokens, calls, model.calls.count(), model.probes.items.len, model.memo.count(), arena_state.queryCapacity(), @divTrunc(scan_ns, 1_000_000), @divTrunc(analyze_ns, 1_000_000),
        });
    }

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = stdout_stream.writer(io, &stdout_buf);
    const out = &stdout_writer.interface;
    defer out.flush() catch {};

    if (list) {
        for (report.unresolved.items) |u| {
            try out.print("{s}:{d}: {s} for", .{ u.path, u.line, u.probe });
            for (u.names) |name| try out.print(" \"{s}\"", .{name});
            try out.print("{s}\n", .{if (u.annotated) " (annotated)" else ""});
            for (u.names) |name| {
                var found: std.ArrayList([]const u8) = .empty;
                try suspects(&model, name, &found);
                for (found.items) |s| try out.print("    private \"{s}\": {s}\n", .{ name, s });
            }
        }
        try out.print("{d} unresolved probe(s)\n", .{report.unresolved.items.len});
    }

    if (report.private.items.len > 0) {
        try out.print("hasdecl: {d} probe(s) can never see their declaration - it is not `pub` (Zig 0.17's @hasDecl sees only pub declarations):\n\n", .{report.private.items.len});
        for (report.private.items) |p| {
            try out.print("  {s}:{d}: {s} for \"{s}\": {s}:{d} {s}.{s} is not pub\n", .{ p.path, p.line, p.probe, p.name, p.target_path, p.target_line, p.target, p.name });
        }
        try out.print("\nMake each declaration `pub` - or rename it, when the probe was never meant to find it.\n\n", .{});
    }
    // The baseline step runs either way (an --update records the ratchet);
    // a private finding fails the run after it.
    const ratchet_failed = try baselineStep(arena, io, out, &report, update);
    try out.flush();
    if (report.private.items.len > 0 or ratchet_failed) std.process.exit(1);
}

/// The ratchet of unannotated unresolved probes: check it, or record it with
/// `update`. True when it fails.
fn baselineStep(arena: Allocator, io: std.Io, out: *std.Io.Writer, report: *const Report, update: bool) !bool {
    const current = try countUnannotated(arena, report);
    var total: u32 = 0;
    var values = current.valueIterator();
    while (values.next()) |v| total += v.*;

    const text: ?[]u8 = std.Io.Dir.cwd().readFileAlloc(io, baseline_path, arena, .limited(64 << 20)) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    if (text == null) {
        if (!update) {
            try out.print("hasdecl: no {s}; record one with `zig build lint-hasdecl -- --update`.\n", .{baseline_path});
            return true;
        }
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = baseline_path, .data = try formatBaseline(arena, &current) });
        try out.print("hasdecl: first baseline recorded - {d} unannotated unresolved probe(s).\n", .{total});
        return false;
    }
    const baseline = try parseBaseline(arena, text.?);
    const found = try violations(arena, &current, &baseline);
    if (found.items.len > 0) {
        try out.print("hasdecl: {d} file(s) above the baseline{s}: a probe whose container cannot be resolved needs a `// hasdecl: <why>` line naming the types that reach it.\n\n", .{ found.items.len, if (update) " - not recorded: the baseline only goes down" else "" });
        for (found.items) |v| {
            try out.print("  {s}: allowed {d}, found {d}\n", .{ v.path, v.allowed, v.found });
            for (report.unresolved.items) |u| {
                if (!u.annotated and std.mem.eql(u8, u.path, v.path)) try out.print("      {s}:{d}: {s}\n", .{ u.path, u.line, u.probe });
            }
        }
        return true;
    }
    var base_total: u32 = 0;
    var base_values = baseline.valueIterator();
    while (base_values.next()) |v| base_total += v.*;
    if (update and total < base_total) {
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = baseline_path, .data = try formatBaseline(arena, &current) });
        try out.print("hasdecl: baseline lowered {d} -> {d}.\n", .{ base_total, total });
        return false;
    }
    if (total < base_total) {
        try out.print("hasdecl: {d} unresolved probe(s) annotated or resolved since the baseline ({d} -> {d}); record it with `zig build lint-hasdecl -- --update`.\n", .{ base_total - total, base_total, total });
    } else {
        try out.print("hasdecl: {d} unannotated unresolved probe(s), none above the baseline.\n", .{total});
    }
    return false;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const testing = std.testing;

fn testReport(arena: Allocator, files: []const SourceFile) !struct { model: Model, report: Report } {
    var model: Model = .{ .arena = arena };
    try model.modules.put(arena, "mod", "src/mod/root.zig");
    for (files) |f| try addFile(&model, f.path, f.source);
    const report = try analyze(&model);
    return .{ .model = model, .report = report };
}

test "a generic's probe of a private hook, through the call that names the type, fails" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const r = try testReport(arena_state.allocator(), &.{.{ .path = "src/a.zig", .source =
        \\pub fn post(comptime T: type, value: T) void {
        \\    if (@hasDecl(T, "drop")) value.drop();
        \\}
        \\const Task = struct {
        \\    fn drop(self: Task) void { _ = self; }
        \\};
        \\const Fine = struct {
        \\    pub fn drop(self: Fine) void { _ = self; }
        \\};
        \\fn use() void {
        \\    post(Task, .{});
        \\    post(Fine, .{});
        \\}
    }});
    try testing.expectEqual(@as(usize, 1), r.report.private.items.len);
    try testing.expectEqualStrings("Task", r.report.private.items[0].target);
    try testing.expectEqual(@as(u32, 5), r.report.private.items[0].target_line);
}

test "a method's type parameter counts the receiver; an imported module's container resolves" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const r = try testReport(arena_state.allocator(), &.{
        .{ .path = "src/mod/root.zig", .source =
        \\pub const Hooks = struct {
        \\    fn start() void {}
        \\    pub fn stop() void {}
        \\};
        },
        .{ .path = "src/b.zig", .source =
        \\const mod = @import("mod");
        \\const Server = struct {
        \\    fn run(self: *Server, comptime T: type) void {
        \\        _ = self;
        \\        if (@hasDecl(T, "start")) T.start();
        \\        if (@hasDecl(T, "stop")) T.stop();
        \\    }
        \\};
        \\fn go(s: *Server) void { s.run(mod.Hooks); }
        },
    });
    try testing.expectEqual(@as(usize, 1), r.report.private.items.len);
    try testing.expectEqualStrings("start", r.report.private.items[0].name);
    try testing.expectEqualStrings("src/mod/root.zig", r.report.private.items[0].target_path);
}

test "an inline for over string literals is a probe of each; a pub declaration and an absent one pass" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const r = try testReport(arena_state.allocator(), &.{
        .{ .path = "src/c.zig", .source =
        \\const Node = @import("node.zig").Node;
        \\test "retired" {
        \\    inline for (.{ "asText", "asAttr", "gone" }) |name| {
        \\        if (@hasDecl(Node, name)) return error.Left;
        \\    }
        \\}
        },
        .{ .path = "src/node.zig", .source =
        \\pub const Node = struct {
        \\    pub fn asText() void {}
        \\    fn asAttr() void {}
        \\};
        },
    });
    try testing.expectEqual(@as(usize, 1), r.report.private.items.len);
    try testing.expectEqualStrings("asAttr", r.report.private.items[0].name);
}

test "an anytype's type is unresolved; a // hasdecl: line marks it reviewed" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const r = try testReport(arena_state.allocator(), &.{.{ .path = "src/d.zig", .source =
        \\fn sinkText(sink: anytype) void {
        \\    if (@hasDecl(@TypeOf(sink.*), "text")) sink.text();
        \\}
        \\fn sinkComment(sink: anytype) void {
        \\    // hasdecl: xml_document_parser.Builder and the tests' Capture, both pub
        \\    if (@hasDecl(@TypeOf(sink.*), "comment")) sink.comment();
        \\}
    }});
    try testing.expectEqual(@as(usize, 0), r.report.private.items.len);
    try testing.expectEqual(@as(usize, 2), r.report.unresolved.items.len);
    const counts = try countUnannotated(arena_state.allocator(), &r.report);
    try testing.expectEqual(@as(u32, 1), counts.get("src/d.zig").?);
}

test "a generic struct's parameter, an alias of it and @This() resolve" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const r = try testReport(arena_state.allocator(), &.{.{ .path = "src/e.zig", .source =
        \\pub fn Registry(comptime tag: u8, comptime T: type) type {
        \\    return struct {
        \\        const Self = @This();
        \\        const State = T;
        \\        fn clear() void {
        \\            if (@hasDecl(State, "deinit")) {}
        \\            if (@hasDecl(Self, "clear")) {}
        \\        }
        \\    };
        \\}
        \\const InternalState = struct {
        \\    fn deinit(self: *InternalState, extra: u8) void { _ = self; _ = extra; }
        \\};
        \\const R = Registry(1, InternalState);
    }});
    try testing.expectEqual(@as(usize, 2), r.report.private.items.len);
    var names: [2][]const u8 = .{ r.report.private.items[0].name, r.report.private.items[1].name };
    std.mem.sort([]const u8, &names, {}, lessThan);
    try testing.expectEqualStrings("clear", names[0]);
    try testing.expectEqualStrings("deinit", names[1]);
}

test "a probe reached through many call sites resolves to each container once" {
    // Each level calls the next twice with its own type parameter: kept
    // with its duplicates, the probe's list doubled at every level - 2^5
    // here; in the tree, a chain of generics through busy call sites grew
    // lists past 10 GB on chat2 (in one order of the files, where no cycle
    // cut the expansion short).
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const r = try testReport(arena_state.allocator(), &.{.{ .path = "src/g.zig", .source =
        \\fn level0(comptime T: type) void {
        \\    if (@hasDecl(T, "drop")) {}
        \\}
        \\fn level1(comptime T: type) void { level0(T); level0(T); }
        \\fn level2(comptime T: type) void { level1(T); level1(T); }
        \\fn level3(comptime T: type) void { level2(T); level2(T); }
        \\fn level4(comptime T: type) void { level3(T); level3(T); }
        \\const Task = struct {
        \\    fn drop() void {}
        \\};
        \\fn use() void { level4(Task); level4(Task); }
    }});
    var model = r.model;
    const probe = model.probes.items[0];
    const targets = (try resolve(&model, probe.file, probe.scope, probe.arg, 0)).?;
    try testing.expectEqual(@as(usize, 1), targets.len);
    try testing.expectEqual(@as(usize, 1), r.report.private.items.len);
}

test "the files are read in path order, whatever order the directory lists them in" {
    // The memo cuts a cycle where it is first met, so what a probe resolves
    // to - and the baseline's count - follows the order the files were
    // parsed in. The walk's order is the file system's (APFS lists names
    // sorted, ext4 by hash): parsed as listed, the same tree counted
    // differently on macOS and Linux. Sixteen files, written in reverse.
    var tmp = testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "src/sub");
    var name_buffer: [32]u8 = undefined;
    var i: usize = 16;
    while (i > 0) {
        i -= 1;
        const sub_path = try std.fmt.bufPrint(&name_buffer, "{s}/f{d:0>2}.zig", .{ if (i % 4 == 3) "src/sub" else "src", i });
        try tmp.dir.writeFile(testing.io, .{ .sub_path = sub_path, .data = "fn f(comptime T: type) void { if (@hasDecl(T, \"x\")) {} }\n" });
    }
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    var model: Model = .{ .arena = arena_state.allocator() };
    try scanTree(&model, testing.io, tmp.dir);
    try testing.expectEqual(@as(usize, 16), model.probes.items.len);
    for (model.probes.items[0 .. model.probes.items.len - 1], model.probes.items[1..]) |a, b| {
        try testing.expect(std.mem.order(u8, a.file.path, b.file.path) == .lt);
    }
}

test "the baseline round-trips and only an increase is a violation" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var current: Counts = .empty;
    try current.put(arena, "src/a.zig", 2);
    try current.put(arena, "src/b.zig", 1);
    const text = try formatBaseline(arena, &current);
    const parsed = try parseBaseline(arena, text);
    try testing.expectEqual(@as(u32, 2), parsed.get("src/a.zig").?);
    var more: Counts = .empty;
    try more.put(arena, "src/a.zig", 3);
    try more.put(arena, "src/b.zig", 0);
    const v = try violations(arena, &more, &parsed);
    try testing.expectEqual(@as(usize, 1), v.items.len);
    try testing.expectEqualStrings("src/a.zig", v.items[0].path);
}

test "build.zig's graphModule names map to their root files" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    var model: Model = .{ .arena = arena_state.allocator() };
    try readModules(&model,
        \\const css_mod = graphModule(b, public, "css", .{
        \\    .root_source_file = b.path("src/css/root.zig"),
        \\});
    );
    try testing.expectEqualStrings("src/css/root.zig", model.modules.get("css").?);
    try testing.expectEqualStrings("src/runtime/engine_protocol.zig", model.modules.get("engine").?);
}

test "the walk leaves exempt trees and build output" {
    try testing.expect(skipsDirectory("tests/wpt"));
    try testing.expect(skipsDirectory("tests/wpt/html"));
    try testing.expect(skipsDirectory("src/webidl/impls_tmp"));
    try testing.expect(skipsDirectory("tools/.zig-cache"));
    try testing.expect(skipsDirectory("tests/zig-out"));
    try testing.expect(!skipsDirectory("tests/wpt_runner"));
    try testing.expect(!skipsDirectory("src/webidl/impls"));
    try testing.expect(!skipsDirectory("tests/dom"));
}

test "the scanned trees" {
    try testing.expect(isScanned("src/dom/node.zig"));
    try testing.expect(isScanned("tests/dom/x_test.zig"));
    try testing.expect(isScanned("tools/lint_hasdecl.zig"));
    try testing.expect(!isScanned("tests/wpt/crane/x.zig"));
    try testing.expect(!isScanned("src/webidl/impls_tmp/X.zig"));
    try testing.expect(!isScanned("srcx/a.zig"));
    try testing.expect(!isScanned("src/a.txt"));
}
