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
    /// The why of a `// process-wide: <why>` line directly above the
    /// declaration, if it has one (see `processWideWhy`).
    why: ?[]const u8 = null,
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

/// The non-empty why of a `// process-wide: <why>` line directly above line
/// `line` (1-based) of `source`, or null. A blank line, a doc comment or any
/// other line in between breaks it.
pub fn processWideWhy(source: []const u8, line: u32) ?[]const u8 {
    if (line < 2) return null;
    var lines = std.mem.splitScalar(u8, source, '\n');
    var at: u32 = 1;
    while (lines.next()) |text| : (at += 1) {
        if (at != line - 1) continue;
        const trimmed = std.mem.trim(u8, text, " \t\r");
        if (!std.mem.startsWith(u8, trimmed, process_wide_marker)) return null;
        const why = std.mem.trim(u8, trimmed[process_wide_marker.len..], " \t");
        return if (why.len == 0) null else why;
    }
    return null;
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
    var tree = try std.zig.Ast.parse(gpa, source, .zig);
    defer tree.deinit(gpa);
    if (tree.errors.len > 0) return error.ParseError;

    var named: std.ArrayList(Named) = .empty;
    defer named.deinit(gpa);
    var tests: std.ArrayList([2]u32) = .empty;
    defer tests.deinit(gpa);

    // 1. The ranges that qualify a name, and the test declarations.
    const node_count = tree.nodes.len;
    var i: u32 = 0;
    while (i < node_count) : (i += 1) {
        const node: std.zig.Ast.Node.Index = @enumFromInt(i);
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
        const node: std.zig.Ast.Node.Index = @enumFromInt(i);
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
            try out.append(gpa, .{
                .line = line,
                .why = processWideWhy(source, line),
                .decl_hash = declHash(&.{ nodeText(&tree, vd.ast.type_node), nodeText(&tree, vd.ast.init_node) }),
                .name = name,
                .kind = if (vd.threadlocal_token != null) .zig_threadlocal else .zig_global,
            });
        }
    }
    std.mem.sort(Variable, out.items, {}, variableLessThan);
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
                try out.append(gpa, .{ .line = line, .name = owned, .kind = found.kind, .why = processWideWhy(text, line), .decl_hash = decl_hash });
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

/// What the current tree holds under one key.
pub const Found = struct {
    count: u32,
    kind: Kind,
    /// Declarations under the key without a `// process-wide: <why>` line.
    unmarked: u32 = 0,
    /// The declarations' `declHash`es, combined (order does not matter).
    decl: u64 = 0,
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

/// A key the current tree has more of than the baseline allows.
pub const Violation = struct { key: []const u8, allowed: u32, found: u32 };

fn violationLessThan(_: void, a: Violation, b: Violation) bool {
    return std.mem.lessThan(u8, a.key, b.key);
}

/// Every key in `current` above its baseline count - a key absent from the
/// baseline is allowed zero - sorted by key.
pub fn violations(gpa: std.mem.Allocator, current: *const Counts, baseline: *const Baseline) !std.ArrayList(Violation) {
    var out: std.ArrayList(Violation) = .empty;
    errdefer out.deinit(gpa);
    var it = current.iterator();
    while (it.next()) |entry| {
        const allowed = if (baseline.get(entry.key_ptr.*)) |b| b.count else 0;
        if (entry.value_ptr.count > allowed) {
            try out.append(gpa, .{ .key = entry.key_ptr.*, .allowed = allowed, .found = entry.value_ptr.count });
        }
    }
    std.mem.sort(Violation, out.items, {}, violationLessThan);
    return out;
}

/// Whether a run may write the baseline: `--update` when nothing is above it.
/// An increase is never recorded.
pub fn mayRecord(update: bool, above_baseline: usize) bool {
    return update and above_baseline == 0;
}

/// The violations `--update` refuses: all of them, except a key the baseline
/// lacks whose every declaration carries a `// process-wide: <why>` line. An
/// increase for a key the baseline has is refused, marked or not. (The check
/// without --update fails on every violation, so a process-wide variable
/// enters the baseline only through a recorded update.)
pub fn refusedByUpdate(gpa: std.mem.Allocator, found: []const Violation, current: *const Counts, baseline: *const Baseline) !std.ArrayList(Violation) {
    var out: std.ArrayList(Violation) = .empty;
    errdefer out.deinit(gpa);
    for (found) |v| {
        const marked = if (current.get(v.key)) |f| f.unmarked == 0 else false;
        if (!baseline.contains(v.key) and marked) continue;
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
        // A key new to the baseline was recorded through its process-wide
        // marker: a process resource until someone classifies it further.
        const new_class = if (found.unmarked == 0) "P-res" else "?";
        const class = if (previous) |p| (if (p.get(key)) |e| e.class else new_class) else "?";
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
            .zig => zigVariables(arena, text) catch |err| switch (err) {
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
            gop.value_ptr.count += 1;
            if (variable.why == null) gop.value_ptr.unmarked += 1;
            gop.value_ptr.decl +%= variable.decl_hash;
            const site = try sites.getOrPut(arena, key);
            if (!site.found_existing) site.value_ptr.* = .empty;
            try site.value_ptr.append(arena, .{ .path = path, .variable = variable });
        }
    }
}

/// Totals per kind and per class.
fn printTotals(out: *std.Io.Writer, arena: std.mem.Allocator, current: *const Counts, baseline: ?*const Baseline) !void {
    var per_kind = [_]u32{0} ** std.meta.fields(Kind).len;
    var per_class: std.StringArrayHashMapUnmanaged(u32) = .empty;
    var it = current.iterator();
    while (it.next()) |entry| {
        per_kind[@intFromEnum(entry.value_ptr.kind)] += entry.value_ptr.count;
        const class = if (baseline) |b| (if (b.get(entry.key_ptr.*)) |e| e.class else "?") else "?";
        const gop = try per_class.getOrPut(arena, class);
        if (!gop.found_existing) gop.value_ptr.* = 0;
        gop.value_ptr.* += entry.value_ptr.count;
    }
    try out.print("  by kind:", .{});
    inline for (std.meta.fields(Kind)) |field| {
        const kind: Kind = @enumFromInt(field.value);
        try out.print(" {s} {d}", .{ kind.label(), per_kind[field.value] });
    }
    try out.print("\n  by class:", .{});
    const classes = try arena.dupe([]const u8, per_class.keys());
    std.mem.sort([]const u8, classes, {}, lessThan);
    for (classes) |class| try out.print(" {s} {d}", .{ class, per_class.get(class).? });
    try out.print("\n", .{});
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
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buf);
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

    const found = try violations(arena, &current, &baseline);
    // Without --update every violation fails; --update records new keys
    // whose declarations all say why they are process-wide, and nothing else.
    const blocking = if (update) try refusedByUpdate(arena, found.items, &current, &baseline) else found;
    if (blocking.items.len > 0) {
        try out.print("global state: {d} key(s) above the baseline ({d} variables, baseline {d}).\n\n", .{ blocking.items.len, total, baseline_total });
        for (blocking.items) |v| {
            try out.print("  {s}: allowed {d}, found {d}\n", .{ v.key, v.allowed, v.found });
            if (sites.get(v.key)) |list| {
                for (list.items) |site| try out.print("      {s}:{d} ({s})\n", .{ site.path, site.variable.line, site.variable.kind.label() });
            }
        }
        try out.print(
            \\
            \\A container-level `var` or `threadlocal` is shared by every instance, or
            \\by every page on a thread (docs/instances.md, "Rules for new state"). Put
            \\the state on its owner - the Browser, the Tab, the agent, the realm - and
            \\reach it through the realm the code runs in. A hook is written once at
            \\process start. A variable that genuinely belongs to the process says so
            \\on a `// process-wide: <why>` line directly above its declaration, and
            \\enters the baseline through `zig build lint-global-state -- --update`
            \\(the integrator reviews it). Nothing else raises the baseline.
            \\{s}
        , .{if (update) "--update refuses to record an increase.\n" else ""});
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
            for (list.items) |site| try out.print("global state: recorded process-wide {s} ({s}:{d}): {s}\n", .{ v.key, site.path, site.variable.line, site.variable.why orelse "" });
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

test "--update records a new key only when every declaration is marked process-wide; an increase is refused" {
    var current: Counts = .empty;
    defer current.deinit(testing.allocator);
    // New and marked: recordable.
    try current.put(testing.allocator, "src/dom/process_phase.zig phase", .{ .count = 1, .kind = .zig_global, .unmarked = 0 });
    // New, without a marker (or with an empty why, which leaves it unmarked).
    try current.put(testing.allocator, "src/dom/x.zig cache", .{ .count = 1, .kind = .zig_global, .unmarked = 1 });
    // An existing key grown - marked or not, an increase.
    try current.put(testing.allocator, "src/a.zig counter", .{ .count = 2, .kind = .zig_global, .unmarked = 0 });
    var baseline: Baseline = .empty;
    defer baseline.deinit(testing.allocator);
    try baseline.put(testing.allocator, "src/a.zig counter", .{ .count = 1, .kind = "G", .class = "D" });

    var found = try violations(testing.allocator, &current, &baseline);
    defer found.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 3), found.items.len);

    var refused = try refusedByUpdate(testing.allocator, found.items, &current, &baseline);
    defer refused.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 2), refused.items.len);
    try testing.expectEqualStrings("src/a.zig counter", refused.items[0].key);
    try testing.expectEqualStrings("src/dom/x.zig cache", refused.items[1].key);
    try testing.expect(!mayRecord(true, refused.items.len));

    // With only the marked key new, --update records it - as a process resource.
    _ = current.remove("src/dom/x.zig cache");
    current.getPtr("src/a.zig counter").?.count = 1;
    var found2 = try violations(testing.allocator, &current, &baseline);
    defer found2.deinit(testing.allocator);
    var refused2 = try refusedByUpdate(testing.allocator, found2.items, &current, &baseline);
    defer refused2.deinit(testing.allocator);
    try testing.expect(mayRecord(true, refused2.items.len));
    const text = try formatBaseline(testing.allocator, &current, &baseline);
    defer testing.allocator.free(text);
    try testing.expect(std.mem.indexOf(u8, text, "src/dom/process_phase.zig phase 1 G P-res decl:") != null);
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

    var found = try violations(testing.allocator, &current, &baseline);
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
    var found = try violations(testing.allocator, &current, &baseline);
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
