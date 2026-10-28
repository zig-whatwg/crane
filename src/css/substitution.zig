//! CSS Values 5 Appendix A, "Arbitrary Substitution Functions": the engine
//! every such function shares. A declaration whose value contains one is
//! valid at parse time when every one of them matches its ARGUMENT GRAMMAR
//! ("Resolving in Properties"), is stored as a pending-substitution value
//! (pending_values.zig) and is substituted at computed-value time.
//!
//! What does not depend on any one function lives here, once: the component
//! value tree of a value (`Node`), the parse that builds it and checks each
//! function's argument grammar, the free-form argument productions of
//! Values 5 §3.1.1, "substitute arbitrary substitution functions" (the
//! depth-first walk, early invocation by spread, guaranteed-invalid
//! propagation, the over-long limit), token-boundary splicing and the taint
//! provenance of §8.7.2. A function is one row of `functions`: its argument
//! grammar and its "replace an arbitrary substitution function". var()
//! (CSS Variables 1 §3), env() (CSS Environment Variables 1 §3), attr()
//! (Values 5 §8.7), random-item() (Values 5 §9.2) and if() (Values 5 §8.3)
//! are the rows today; inherit() joins the table the same way.
//!
//! What a replacement reads from the element being styled comes through a
//! `Host` the caller supplies (the cascade's Builder; a test host in the
//! tests): custom property values (resolved on demand under the guard of
//! "property" substitution contexts), the environment, and the math
//! context random-item() draws from.
//!
//! Design: WebKit Style::SubstitutionResolver and Blink StyleCascade
//! ResolveTokensInto/ResolveVarInto (design: tmp/plans/vars1-design.md §13).
//!
//! Spec: https://drafts.csswg.org/css-values-5/#arbitrary-substitution
//! Spec: https://drafts.csswg.org/css-values-5/#component-function-commas
//! Spec: https://drafts.csswg.org/css-variables-1/#using-variables
//! Spec: https://drafts.csswg.org/css-env-1/#env-function
const std = @import("std");
const tokens = @import("tokenizer.zig");
const math = @import("math_values.zig");
const random = @import("random_values.zig");
const if_function = @import("if_function.zig");
const attr = @import("attr_function.zig");
const Allocator = std.mem.Allocator;

pub const Error = Allocator.Error || error{ Invalid, Unavailable };

/// CSS Values 5 §8.7.2: where a token's taint comes from.
pub const Taint = enum(u2) {
    none,
    /// The token was substituted from a tainted source (attr(), or a var()
    /// whose value was tainted), and so is everything inside it.
    own,
    /// A function or block that CONTAINS a tainted argument: only its own
    /// span (a function's name and "(") is marked, never its untainted
    /// arguments.
    container,
};

/// A tainted byte range of rendered text.
pub const TaintRange = struct {
    start: usize,
    end: usize,
    kind: Taint,
};

/// One component value of a value: a token, or a function or block with its
/// contents. `raw` is the token's source text including the comments
/// directly before it (a function's includes its "("), and `close_raw` the
/// closing token's, so rendering the tree gives back the source as written.
pub const Node = struct {
    kind: tokens.TokenType,
    raw: []const u8,
    value: []const u8 = "",
    children: []const Node = &.{},
    close: ?u8 = null,
    close_raw: []const u8 = "",
    /// The arbitrary substitution function this function token names.
    function: ?Id = null,
    /// random-item()'s per-declaration ordinal (Values 5 §9.4).
    item_index: ?usize = null,
    taint: Taint = .none,
};

/// The arbitrary substitution functions Crane implements.
pub const Id = enum {
    /// CSS Variables 1 §3.
    @"var",
    /// CSS Environment Variables 1 §3.
    env,
    /// CSS Values 5 §9.2.
    random_item,
    /// CSS Values 5 §8.3.
    @"if",
    /// CSS Values 5 §8.7.
    attr,

    pub fn name(self: Id) []const u8 {
        return switch (self) {
            .@"var" => "var",
            .env => "env",
            .random_item => "random-item",
            .@"if" => "if",
            .attr => "attr",
        };
    }
};

/// When a function's arguments are split: at parse time from the literal
/// tokens, or at computed-value time after early invocation (a spread may
/// have brought in what the literal text did not show). attr() rejects a
/// literally malformed header only at parse time (Codex row 122 Q22).
pub const Phase = enum { parse, substituted };

/// One row per function.
pub const Function = struct {
    id: Id,
    /// Values 5 "Argument Grammars": split the function's contents into its
    /// arguments, or error.Invalid. Tokens only; nothing is substituted.
    /// An omitted optional argument is absent from the list; one present
    /// but empty is an empty slice (`var(--x,)` has two arguments).
    arguments: *const fn (Allocator, []const Node, Phase) Error![]const []const Node,
    /// Values 5 "replace an arbitrary substitution function": the fully
    /// substituted nodes this function is replaced by, or error.Invalid for
    /// the guaranteed-invalid value. It substitutes only the arguments it
    /// evaluates (resolver.substitute), so unvisited branches stay lazy.
    replace: *const fn (*Resolver, Node, []const []const Node) Error!Replacement,
};

/// A function's replacement.
pub const Replacement = struct {
    nodes: []const Node,
    /// The replacement came from a tainted source as a whole (§8.7.2): every
    /// node is marked `own`, and the enclosing function a container - even
    /// when `nodes` is empty.
    tainted: bool = false,
};

pub const functions = [_]Function{
    .{ .id = .@"var", .arguments = varArguments, .replace = replaceVar },
    .{ .id = .env, .arguments = envArguments, .replace = replaceEnv },
    .{ .id = .random_item, .arguments = randomItemArguments, .replace = replaceRandomItem },
    .{ .id = .@"if", .arguments = if_function.arguments, .replace = if_function.replace },
    .{ .id = .attr, .arguments = attr.arguments, .replace = attr.replace },
};

/// The rows a parse or a substitution uses: `functions`, except in tests
/// that stand a recording row in for one.
pub const Table = []const Function;
pub const default_table: Table = &functions;

pub fn function(id: Id) Function {
    inline for (functions) |f| if (f.id == id) return f;
    unreachable;
}

fn functionIn(table: Table, id: Id) Function {
    for (table) |f| if (f.id == id) return f;
    unreachable;
}

/// The arbitrary substitution function a function token names, ASCII
/// case-insensitively (CSS Syntax 3: function names are).
pub fn functionId(token_value: []const u8) ?Id {
    inline for (functions) |f| if (tokens.nameEql(token_value, f.id.name())) return f.id;
    return null;
}

/// Whether `text` contains a function token of an arbitrary substitution
/// function, at any depth. Function tokens only are compared.
pub fn mentionsFunction(text: []const u8) bool {
    var tokenizer = tokens.Tokenizer.init(text);
    while (true) {
        const token = tokenizer.next();
        switch (token.token_type) {
            .eof => return false,
            .function => if (functionId(token.value) != null) return true,
            else => {},
        }
    }
}

/// The component value tree of `text`, every arbitrary substitution
/// function in it checked against its argument grammar (Values 5 "Resolving
/// in Properties": "If a property value contains one or more arbitrary
/// substitution functions, and all of those functions are themselves
/// syntactically valid according to their argument grammars, the entire
/// value's grammar must be assumed to be valid at parse time.").
/// error.Invalid when the text is not a <declaration-value> (CSS Syntax 3
/// §7.2: no bad tokens, no unmatched closer, no top-level `!` or `;`), when
/// a function's arguments do not match, or past the nesting and size
/// limits. Allocations belong to `allocator` (an arena).
pub fn parse(allocator: Allocator, text: []const u8) Error![]const Node {
    return parseLimited(allocator, text, max_nodes);
}

fn parseLimited(allocator: Allocator, text: []const u8, limit: usize) Error![]const Node {
    return parseWith(allocator, text, limit, default_table);
}

/// `parse` with a table of rows (tests stand a recording row in).
pub fn parseWith(allocator: Allocator, text: []const u8, limit: usize, table: Table) Error![]const Node {
    var parser: Parser = .{ .allocator = allocator, .tokenizer = tokens.Tokenizer.init(text), .limit = limit, .table = table };
    const nodes = (try parser.sequence(null)).nodes;
    try checkDeclarationTokens(nodes);
    return nodes;
}

/// Parse-time validity alone: whether `text` is a valid value with
/// arbitrary substitution functions (see `parse`). Allocation failure is
/// reported, never taken for invalid syntax.
pub fn validate(allocator: Allocator, text: []const u8) Allocator.Error!bool {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    _ = parse(arena.allocator(), text) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.Invalid, error.Unavailable => return false,
    };
    return true;
}

/// The source segment of a value from its first to its last non-whitespace
/// token: whitespace and comments at either end trimmed, everything between
/// kept as written (CSS Syntax 3 "consume a declaration", a custom
/// property's original text; css-variables-1 §4.1).
pub fn originalText(text: []const u8) []const u8 {
    var tokenizer = tokens.Tokenizer.init(text);
    tokenizer.skipWhitespace();
    const start = tokenizer.pos;
    var end = start;
    while (true) {
        const token = tokenizer.next();
        if (token.token_type == .eof) break;
        if (token.token_type != .whitespace) end = tokenizer.pos;
    }
    return text[start..end];
}

/// `segment` (original text that runs to the end of its input) as the
/// tokens read it there: CSS Syntax 3 §4.3.7, an escaped EOF is U+FFFD (in
/// a string it is ignored); EOF ends a string, a url() and every open block,
/// whose closers are appended. Chrome 156 and Safari 27 serialize a custom
/// property cut off this way so (css/css-syntax/escaped-eof.html; Firefox
/// 158 keeps the source: golden rule 2, the majority). Owned by `allocator`.
pub fn closeAtEof(allocator: Allocator, segment: []const u8) Allocator.Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, segment);
    var closers: std.ArrayList(u8) = .empty;
    defer closers.deinit(allocator);
    var tokenizer = tokens.Tokenizer.init(segment);
    var last: tokens.TokenType = .eof;
    var last_start: usize = 0;
    while (true) {
        const start = tokenizer.pos;
        const token = tokenizer.next();
        if (token.token_type == .eof) break;
        last = token.token_type;
        last_start = start;
        switch (token.token_type) {
            // A function token's "(" is the next token (tokenizer.zig).
            .left_paren => try closers.append(allocator, ')'),
            .left_bracket => try closers.append(allocator, ']'),
            .left_brace => try closers.append(allocator, '}'),
            .right_paren, .right_bracket, .right_brace => {
                if (closers.items.len != 0) _ = closers.pop();
            },
            else => {},
        }
    }
    const tail = segment[last_start..];
    const escaped = trailingBackslashes(segment) % 2 == 1;
    switch (last) {
        .string, .bad_string => {
            // The token's raw text may start with the comments before it.
            const quote = tail[std.mem.indexOfAny(u8, tail, "\"'") orelse return out.toOwnedSlice(allocator)];
            const closed = tail.len >= 2 and tail[tail.len - 1] == quote and !escaped and !(trailingBackslashes(tail[0 .. tail.len - 1]) % 2 == 1);
            if (!closed) {
                // "If the next input code point is EOF, do nothing" (the
                // escaped EOF in a string is ignored).
                if (escaped) out.items.len -= 1;
                try out.append(allocator, quote);
            }
        },
        .url, .bad_url => {
            if (out.items.len == 0 or out.items[out.items.len - 1] != ')' or escaped) {
                if (escaped) {
                    out.items.len -= 1;
                    try out.appendSlice(allocator, "\u{FFFD}");
                }
                try out.append(allocator, ')');
            }
        },
        else => if (escaped) {
            out.items.len -= 1;
            try out.appendSlice(allocator, "\u{FFFD}");
        },
    }
    var i = closers.items.len;
    while (i > 0) {
        i -= 1;
        try out.append(allocator, closers.items[i]);
    }
    return out.toOwnedSlice(allocator);
}

fn trailingBackslashes(text: []const u8) usize {
    var n: usize = 0;
    while (n < text.len and text[text.len - 1 - n] == '\\') n += 1;
    return n;
}

/// The nesting and size limits a stored value may reach. Past them the
/// value is invalid, not truncated.
pub const max_depth = 128;
pub const max_nodes = 65536;
/// A substituted value re-parsed for splicing may be longer.
pub const max_substituted_nodes = 262144;
/// Values 5 "Safely Handling Overly-Long Substitution": a substitution
/// longer than this is the guaranteed-invalid value. Blink's limit
/// (CSSVariableData::kMaxVariableBytes, 2 MiB).
pub const max_substituted_bytes = 2 * 1024 * 1024;

const Sequence = struct { nodes: []const Node, close_raw: []const u8 = "" };

const Parser = struct {
    allocator: Allocator,
    tokenizer: tokens.Tokenizer,
    limit: usize,
    table: Table = default_table,
    depth: usize = 0,
    count: usize = 0,
    item_index: usize = 0,

    fn sequence(self: *Parser, closing: ?tokens.TokenType) Error!Sequence {
        self.depth += 1;
        defer self.depth -= 1;
        if (self.depth > max_depth) return error.Invalid;
        var nodes: std.ArrayList(Node) = .empty;
        var close_raw: []const u8 = "";
        while (true) {
            const start = self.tokenizer.pos;
            const token = self.tokenizer.next();
            if (token.token_type == .eof) {
                // Syntax 3 closes blocks at EOF. Comments before it are kept
                // as a whitespace-like node, so rendering keeps them too.
                if (self.tokenizer.pos > start) try nodes.append(self.allocator, .{ .kind = .whitespace, .raw = self.tokenizer.input[start..self.tokenizer.pos] });
                break;
            }
            if (closing != null and token.token_type == closing.?) {
                close_raw = self.tokenizer.input[start..self.tokenizer.pos];
                break;
            }
            switch (token.token_type) {
                .right_paren, .right_bracket, .right_brace, .bad_string, .bad_url => return error.Invalid,
                else => {},
            }
            self.count += 1;
            if (self.count > self.limit) return error.Invalid;
            var node = Node{ .kind = token.token_type, .raw = self.tokenizer.input[start..self.tokenizer.pos], .value = token.value };
            const close: ?tokens.TokenType = switch (token.token_type) {
                .function => blk: {
                    if (self.tokenizer.next().token_type != .left_paren) return error.Invalid;
                    node.raw = self.tokenizer.input[start..self.tokenizer.pos];
                    node.function = functionId(token.value);
                    if (node.function == .random_item) {
                        self.item_index += 1;
                        node.item_index = self.item_index;
                    }
                    break :blk .right_paren;
                },
                .left_paren => .right_paren,
                .left_bracket => .right_bracket,
                .left_brace => .right_brace,
                else => null,
            };
            if (close) |end| {
                node.close = switch (end) {
                    .right_paren => ')',
                    .right_bracket => ']',
                    .right_brace => '}',
                    else => unreachable,
                };
                const inner = try self.sequence(end);
                node.children = inner.nodes;
                node.close_raw = inner.close_raw;
                // Values 5 Appendix A: a spread (`...f()`) among the
                // contents is substituted before the split, so its
                // arguments are known only then.
                if (node.function) |id| if (!hasSpread(node.children)) {
                    _ = try functionIn(self.table, id).arguments(self.allocator, node.children, .parse);
                };
            }
            try nodes.append(self.allocator, node);
        }
        return .{ .nodes = try nodes.toOwnedSlice(self.allocator), .close_raw = close_raw };
    }
};

pub fn isSpace(node: Node) bool {
    return node.kind == .whitespace;
}

pub fn trim(nodes: []const Node) []const Node {
    var start: usize = 0;
    var end = nodes.len;
    while (start < end and isSpace(nodes[start])) start += 1;
    while (end > start and isSpace(nodes[end - 1])) end -= 1;
    return nodes[start..end];
}

/// Values 5 Appendix A: three adjacent `.` delims directly before an
/// arbitrary substitution function, with nothing between them.
pub fn spreadAt(nodes: []const Node, index: usize) bool {
    if (index < 3 or nodes[index].function == null) return false;
    for (nodes[index - 3 .. index]) |node| if (node.kind != .delim or !std.mem.eql(u8, node.raw, ".")) return false;
    // Comments and whitespace between tokens do not count as adjacency.
    for (index - 3..index) |i| if (@intFromPtr(nodes[i].raw.ptr) + nodes[i].raw.len != @intFromPtr(nodes[i + 1].raw.ptr)) return false;
    // The function token's own raw starts right after the third period.
    return true;
}

pub fn hasSpread(nodes: []const Node) bool {
    for (nodes, 0..) |node, index| {
        if (node.function != null) {
            if (spreadAt(nodes, index)) return true;
        } else if (hasSpread(node.children)) return true;
    }
    return false;
}

/// The arguments of `contents` split at its top-level commas.
fn splitCommas(allocator: Allocator, contents: []const Node) Allocator.Error![]const []const Node {
    var list: std.ArrayList([]const Node) = .empty;
    var start: usize = 0;
    for (contents, 0..) |node, index| if (node.kind == .comma) {
        try list.append(allocator, contents[start..index]);
        start = index + 1;
    };
    try list.append(allocator, contents[start..]);
    return list.toOwnedSlice(allocator);
}

/// <declaration-value>'s own restriction, CSS Syntax 3 §7.2: no top-level
/// `;` or `!` delim. It holds inside any wrapper too (Values 5 §3.1.1:
/// "General restrictions defined for a particular free-form production ...
/// apply regardless of whether it's {}-wrapped or not").
fn checkDeclarationTokens(nodes: []const Node) Error!void {
    for (nodes) |node| {
        if (node.kind == .semicolon) return error.Invalid;
        if (node.kind == .delim and std.mem.eql(u8, node.value, "!")) return error.Invalid;
    }
}

/// Values 5 §3.1.1, a free-form production: one {}-block (its contents are
/// the argument) or, when it does not start with "{", a sequence that
/// matches no top-level comma (the caller split those) or {}-block.
pub fn freeForm(raw: []const Node) Error![]const Node {
    const nodes = trim(raw);
    if (nodes.len > 0 and nodes[0].kind == .left_brace) {
        if (nodes.len != 1) return error.Invalid;
        const contents = trim(nodes[0].children);
        try checkDeclarationTokens(contents);
        return contents;
    }
    for (nodes) |node| if (node.kind == .left_brace) return error.Invalid;
    try checkDeclarationTokens(nodes);
    return nodes;
}

/// Values 5 §3.1.1, "For legacy compat reasons, the <declaration-value>
/// defined for the fallback value of var() is a non-strict free-form
/// production": without a leading "{" it may contain commas and blocks; with
/// one, it is that block's contents.
pub fn nonStrictFreeForm(raw: []const Node) Error![]const Node {
    const nodes = trim(raw);
    if (nodes.len > 0 and nodes[0].kind == .left_brace) return freeForm(nodes);
    try checkDeclarationTokens(nodes);
    return nodes;
}

/// The contents after the first top-level comma, or null without one.
fn afterFirstComma(contents: []const Node) struct { first: []const Node, rest: ?[]const Node } {
    for (contents, 0..) |node, index| if (node.kind == .comma) return .{ .first = contents[0..index], .rest = contents[index + 1 ..] };
    return .{ .first = contents, .rest = null };
}

// ============================================================================
// var() - CSS Variables 1 §3
// ============================================================================

/// `<var-args> = var( <declaration-value> , <declaration-value>? )`. The
/// name argument is substituted and only then parsed as a
/// <custom-property-name> (replace a var() function, step 2), so
/// `var(--x ())` is valid at parse time and `var()` is not (a
/// <declaration-value> is one or more tokens).
///
/// Golden rule 2 (integrator, 2026-10-25, Q1): this is the newer grammar.
/// css-variables-1 ED §3 defines it; WebKit implemented it in trunk (bug
/// 320896, RESOLVED FIXED, 318912@main, 2026-08, exported as wpt#61857:
/// css/css-variables/var-parsing.html); Chrome 156, Firefox 158 and Safari 27
/// stable fail the same eight names of that file - a lag, not a refusal.
fn varArguments(allocator: Allocator, contents: []const Node, _: Phase) Error![]const []const Node {
    const split = afterFirstComma(contents);
    const name = try freeForm(split.first);
    if (name.len == 0) return error.Invalid;
    const rest = split.rest orelse {
        const out = try allocator.alloc([]const Node, 1);
        out[0] = name;
        return out;
    };
    const out = try allocator.alloc([]const Node, 2);
    out[0] = name;
    out[1] = try nonStrictFreeForm(rest);
    return out;
}

/// CSS Variables 1 §3, "replace a var() function".
fn replaceVar(resolver: *Resolver, _: Node, args: []const []const Node) Error!Replacement {
    // 1-2. "Substitute arbitrary substitution functions in first arg, then
    // parse it as a <custom-property-name>. If parsing returned a
    // <custom-property-name>, let result be the computed value of the
    // corresponding custom property on el. Otherwise, let result be the
    // guaranteed-invalid value."
    var result: ?Computed = null;
    var tainted = false;
    if (resolver.substituteWithTaint(args[0], false)) |name_argument| {
        // A name a tainted substitution produced taints what it names.
        if (name_argument.tainted) tainted = true;
        const rendered = try render(resolver.allocator, name_argument.nodes);
        if (try customPropertyName(resolver.allocator, rendered.text)) |name| {
            const lookup = resolver.host.custom_value orelse return error.Invalid;
            result = try lookup(resolver.host.context, name);
        }
    } else |err| switch (err) {
        error.Invalid => {},
        else => |e| return e,
    }
    // 3. Animation-tainted values: Crane has no animation origin, so no
    // value is animation-tainted (cascade.zig).
    // 4. "If result contains the guaranteed-invalid value, and second arg was
    // provided, set result to the result of substitute arbitrary
    // substitution functions on second arg." (Lazily: the fallback is never
    // substituted otherwise, so it creates no dependency.)
    const value = result orelse {
        if (args.len < 2) return error.Invalid;
        const fallback = try resolver.substituteWithTaint(args[1], false);
        return .{ .nodes = fallback.nodes, .tainted = tainted or fallback.tainted };
    };
    // §8.7.2: a var() whose value was tainted is tainted as a whole.
    if (value.taint.len != 0) tainted = true;
    const nodes = try parseLimited(resolver.allocator, value.text, max_substituted_nodes);
    return .{ .nodes = nodes, .tainted = tainted };
}

/// CSS Variables 1 §2: a <custom-property-name> is a <dashed-ident> other
/// than `--`. The decoded name, or null.
pub fn customPropertyName(allocator: Allocator, text: []const u8) Allocator.Error!?[]const u8 {
    var tokenizer = tokens.Tokenizer.init(text);
    tokenizer.skipWhitespace();
    const token = tokenizer.next();
    if (token.token_type != .ident) return null;
    tokenizer.skipWhitespace();
    if (tokenizer.next().token_type != .eof) return null;
    const name = try tokens.decode(allocator, token.value);
    if (name.len < 3 or name[0] != '-' or name[1] != '-') return null;
    return name;
}

// ============================================================================
// env() - CSS Environment Variables 1 §3
// ============================================================================

/// `env( <custom-ident> <integer [0,∞]>*, <declaration-value>? )`, checked
/// at parse time. css-env-1's newer `<env-args>` line would accept any
/// <declaration-value> name, but all three browsers keep the strict grammar
/// and WPT pins it (css/css-env/env-parsing.html rejects `env(x ())`;
/// Chrome 156, Firefox 158 and Safari 27 pass it), so the strict one stands
/// (golden rule 2, no browser ships the newer behaviour; integrator Q1).
/// Integer indices are css-env-1's; Chrome ships them (integrator,
/// 2026-10-25, tmp/analysis/integrator-probes-1025a/RULINGS.md).
fn envArguments(allocator: Allocator, contents: []const Node, _: Phase) Error![]const []const Node {
    const split = afterFirstComma(contents);
    const name = trim(split.first);
    _ = try envName(name);
    const count: usize = if (split.rest == null) 1 else 2;
    const out = try allocator.alloc([]const Node, count);
    out[0] = name;
    if (split.rest) |rest| out[1] = try nonStrictFreeForm(rest);
    return out;
}

/// An env() name argument: its <custom-ident> and its indices.
pub const EnvName = struct {
    ident: Node,
    indices: []const Node,
};

/// `<custom-ident> <integer [0,∞]>*`, whitespace between components.
pub fn envName(nodes: []const Node) Error!EnvName {
    if (nodes.len == 0 or nodes[0].kind != .ident) return error.Invalid;
    if (!isCustomIdent(nodes[0].value)) return error.Invalid;
    for (nodes[1..]) |node| {
        if (isSpace(node)) continue;
        if (node.kind != .number or !isNonNegativeInteger(node.value)) return error.Invalid;
    }
    return .{ .ident = nodes[0], .indices = nodes[1..] };
}

/// CSS Values 4 §4.2: a <custom-ident> is any identifier except the
/// CSS-wide keywords and `default`, ASCII case-insensitively.
fn isCustomIdent(raw: []const u8) bool {
    for ([_][]const u8{ "initial", "inherit", "unset", "revert", "revert-layer", "revert-rule", "default" }) |reserved| {
        if (tokens.nameEql(raw, reserved)) return false;
    }
    return true;
}

/// An <integer> number token that is at least zero: digits with an
/// optional sign and no fraction or exponent.
fn isNonNegativeInteger(text: []const u8) bool {
    var digits = text;
    if (digits.len > 0 and (digits[0] == '+' or digits[0] == '-')) {
        const negative = digits[0] == '-';
        digits = digits[1..];
        if (negative) {
            for (digits) |c| if (c != '0') return false;
        }
    }
    if (digits.len == 0) return false;
    for (digits) |c| if (c < '0' or c > '9') return false;
    return true;
}

/// The environment variables env() reads (CSS Environment Variables 1 §2),
/// supplied by the host. Codex row 121 installs the provider.
pub const Environment = struct {
    context: *const anyopaque,
    /// §3 step 1: the value of `name` at `indices` as CSS token text, OWNED
    /// by `allocator`; null when `name` is not a recognized environment
    /// variable, the number of indices is not its number of dimensions, or
    /// they name no known sub-value. Allocation failure propagates; it is
    /// never taken for "undefined".
    lookup: *const fn (context: *const anyopaque, allocator: Allocator, name: []const u8, indices: []const u32) Allocator.Error!?[]u8,
};

/// CSS Environment Variables 1 §3, "substitute an env()".
fn replaceEnv(resolver: *Resolver, _: Node, args: []const []const Node) Error!Replacement {
    const parsed = try envName(args[0]);
    const name = try tokens.decode(resolver.allocator, parsed.ident.value);
    var indices: std.ArrayList(u32) = .empty;
    // An index too large for u32 names no known sub-value: it is not
    // looked up at all (4294967295 is a valid index of a sparse host
    // list, so clamping to it would read the wrong value).
    var addressable = true;
    for (parsed.indices) |node| {
        if (isSpace(node)) continue;
        var digits = node.value;
        while (digits.len > 0 and (digits[0] == '+' or digits[0] == '-')) digits = digits[1..];
        const index = std.fmt.parseInt(u32, digits, 10) catch {
            addressable = false;
            break;
        };
        try indices.append(resolver.allocator, index);
    }
    // 1. A recognized variable, the right number of indices, a known
    // sub-value: its value.
    if (addressable) if (resolver.host.environment) |environment| {
        if (try environment.lookup(environment.context, resolver.allocator, name, indices.items)) |text| {
            return .{ .nodes = try parseLimited(resolver.allocator, text, max_substituted_nodes) };
        }
    };
    // 2. "Otherwise, if the env() function has a fallback value as its
    // second argument, replace the env() function by the fallback value. If
    // there are any env() references in the fallback, substitute them as
    // well." 3. "Otherwise, the property or descriptor containing the env()
    // function is invalid at computed-value time."
    if (args.len < 2) return error.Invalid;
    return resolver.substituteWithTaint(args[1], false);
}

// ============================================================================
// random-item() - CSS Values 5 §9.2 (row 118's algorithm)
// ============================================================================

/// `random-item( <random-key>, [<declaration-value>?]# )`, each item a
/// free-form argument whose top-level `!`/`;` restriction survives
/// unwrapping. Only the key must be nonempty at parse time. (Row 118's
/// grammar, unchanged: an unwrapped item matches no top-level block of any
/// kind.)
fn randomItemArguments(allocator: Allocator, contents: []const Node, _: Phase) Error![]const []const Node {
    const list = try splitCommas(allocator, contents);
    var out = try allocator.alloc([]const Node, list.len);
    for (list, 0..) |raw, index| out[index] = try strictItem(raw);
    if (out.len < 2 or out[0].len == 0) return error.Invalid;
    return out;
}

fn strictItem(raw: []const Node) Error![]const Node {
    const nodes = trim(raw);
    const value = if (nodes.len == 1 and nodes[0].kind == .left_brace) nodes[0].children else nodes;
    for (value) |node| {
        if (node.kind == .semicolon or (node.kind == .delim and std.mem.eql(u8, node.value, "!"))) return error.Invalid;
        if (value.ptr == nodes.ptr) switch (node.kind) {
            .left_brace, .left_bracket, .left_paren => return error.Invalid,
            else => {},
        };
    }
    return trim(value);
}

fn replaceRandomItem(resolver: *Resolver, node: Node, args: []const []const Node) Error!Replacement {
    // §9.2 step 2: evaluate the key only; unused items remain untouched.
    const key_nodes = (try resolver.substituteWithTaint(args[0], false)).nodes;
    const key_text = (try render(resolver.allocator, key_nodes)).text;
    var stream = @import("properties.zig").Stream.init(key_text);
    const first = stream.peek();
    const base = if (first.token_type == .ident and tokens.nameEql(first.value, "fixed")) blk: {
        _ = stream.next();
        var scope = try random.ParseScope.init(resolver.allocator, key_text, resolver.property, .{ .early = true, .numeric_offset = resolver.early_numeric });
        defer scope.deinit();
        for (scope.entries) |entry| if (entry.source.function == .numeric) {
            resolver.early_numeric += 1;
        };
        const number = try @import("numeric_values.zig").Number.consume(.{ .allocator = resolver.allocator, .random_scope = &scope }, &stream, .{ .kind = .number, .minimum = 0, .maximum = 1 }, false) orelse return error.Invalid;
        defer number.unref();
        if (!stream.atEnd()) return error.Invalid;
        if ((number.needsRandomBase() and resolver.host.math.random_base == null) or number.needsUnavailableMetrics(false)) return error.Unavailable;
        const computed = try number.compute(resolver.allocator, resolver.host.math);
        defer computed.unref();
        const scalar = computed.known() orelse return error.Unavailable;
        break :blk random.fixedBase(scalar.value);
    } else blk: {
        const key = try random.parseCacheKey(resolver.allocator, key_text, .{ .property = resolver.property, .index = node.item_index.?, .function = .item }) orelse return error.Invalid;
        defer key.deinit(resolver.allocator);
        const provider = resolver.host.math.random_base orelse return error.Unavailable;
        break :blk random.fixedBase(try provider.get(provider.context, key));
    };
    // §§9.2 step 3, 9.3: equal-width [0,1) buckets, then resolve ONLY the
    // chosen item. An empty item is a real option, not a missing one.
    const count = args.len - 1;
    const selected = @min(count - 1, @as(usize, @intFromFloat(@floor(base * @as(f64, @floatFromInt(count))))));
    return resolver.substituteWithTaint(args[selected + 1], false);
}

// ============================================================================
// Substitution (Values 5 Appendix A)
// ============================================================================

/// A custom property's computed value as substitution reads it. `text` ""
/// is the empty value, which is NOT the guaranteed-invalid value (that is
/// a null Computed).
pub const Computed = struct {
    text: []const u8,
    taint: []const TaintRange = &.{},
};

pub const NamespaceMap = @import("namespace_map.zig").NamespaceMap;

/// An attribute as attr() reads it: its value and expanded name (namespace
/// URI, null for none; the canonical local name).
pub const Attribute = struct {
    /// Identity of the actual element read, borrowed for synchronous resolution.
    origin: usize = 0,
    value: []const u8,
    namespace: ?[]const u8,
    local_name: []const u8,
};

/// A style() query's answer and whether what it read was tainted (Values 5
/// §8.7.2): the custom property's computed value, or a substituted operand,
/// carried taint. The caller marks its branch from the flag.
pub fn Flagged(comptime T: type) type {
    return struct { value: T, tainted: bool };
}

/// A numeric value in canonical units, for range comparisons.
pub const Numeric = struct {
    value: f64,
    dimension: Dimension,

    pub const Dimension = enum { number, percentage, length, angle, time, frequency, resolution };
};

/// Values 5 Appendix A: the dependency types of substitution contexts.
pub const GuardKind = enum { property, attribute, function };

/// What a replacement reads from the element being styled, all borrowed for
/// the call. A null member answers "nothing": every custom property is the
/// guaranteed-invalid value, every environment variable is undefined.
pub const Host = struct {
    context: *anyopaque,
    /// attr() (Values 5 §8.7, Codex row 122): the element's attribute -
    /// the originating element's for a pseudo-element - named by `prefix`
    /// (resolved through `map`, the consuming declaration's sheet's
    /// namespaces; an undeclared prefix gives null) and `local_name`, with
    /// its expanded name for the guard key. Borrowed for the call.
    attribute: ?*const fn (context: *anyopaque, tree_scope: u64, map: ?*const NamespaceMap, prefix: ?[]const u8, local_name: []const u8) ?Attribute = null,
    /// The WINNING declaration's tree scope (cascade.ValueSource.tree_scope,
    /// opaque): attr() on a pseudo-element reads the originating element
    /// that scope determines (csswg-drafts#12721; WebKit
    /// hostForScopeOrdinal). The caller sets it per substituted declaration.
    tree_scope: u64 = 0,
    /// var(): the computed value of custom property `name` (decoded) on the
    /// element, resolved on demand under its "property" guard; null for the
    /// guaranteed-invalid value. The text is valid for the cascade call.
    custom_value: ?*const fn (context: *anyopaque, name: []const u8) Error!?Computed = null,
    /// inherit() (Values 5 §8.6, Codex row 123): the parent's computed value
    /// of custom property `name`; at the root, its initial value (the
    /// guaranteed-invalid value, null, for an unregistered one).
    parent_custom_value: ?*const fn (context: *anyopaque, name: []const u8) Error!?Computed = null,
    /// Values 5 Appendix A, "guard" a substitution context (attr() guards
    /// ("attribute", expanded name), a custom function ("function", name)):
    /// a context already guarded marks every context from it to the top
    /// cyclic. Returns the token `unguard` takes.
    guard: ?*const fn (context: *anyopaque, kind: GuardKind, name: []const u8) Allocator.Error!usize = null,
    /// The guard's end: whether its context was marked cyclic.
    unguard: ?*const fn (context: *anyopaque, token: usize) bool = null,
    /// Whether guarding (kind, name) now would be cyclic - a query that marks
    /// nothing.
    would_cycle: ?*const fn (context: *anyopaque, kind: GuardKind, name: []const u8) bool = null,
    /// if()'s style(--x) (Codex row 123): whether custom property `name`
    /// has a value that is not the guaranteed-invalid value. Custom
    /// properties only (a standard property's feature is row 123's unknown).
    has_value: ?*const fn (context: *anyopaque, name: []const u8) Error!Flagged(bool) = null,
    /// if()'s style(--x: value): whether `value_text`, substituted (a failure
    /// there is an error the caller catches), equals the computed value of
    /// custom property `name` - for an unregistered one, token by token with
    /// whitespace normalized. Null: unknown (not a custom property name).
    /// Batch 2 compares a registered property's computed values.
    query_value_matches: ?*const fn (context: *anyopaque, name: []const u8, value_text: []const u8) Error!?Flagged(bool) = null,
    /// if()'s range queries (style(--x > 10px)): `operand` - a custom
    /// property name or a literal value text, substituted first (a failure is
    /// an error the caller catches) - as a number in canonical units (px,
    /// deg, s, Hz, dppx), computed in the element's context with the shared
    /// math. Null: a guaranteed-invalid property, or no single numeric value.
    numeric_value: ?*const fn (context: *anyopaque, operand: []const u8) Error!?Flagged(Numeric) = null,
    /// if()'s media() test: `query_text` (a <media-feature> body or a
    /// <media-condition>) against the element's document. error.Invalid for
    /// a malformed or unknown test, false for a valid one that does not
    /// match (css.media_queries.MediaQueryList.evaluateTest).
    media: ?*const fn (context: *anyopaque, query_text: []const u8) Error!bool = null,
    /// if()'s supports() test with the CONSUMING declaration's quirks mode
    /// (Resolver.quirks). error.Invalid for a malformed test, false for an
    /// unsupported one (css.supports.evaluateTest).
    supports: ?*const fn (context: *anyopaque, text: []const u8, quirks: bool) Error!bool = null,
    /// env(): the host's environment variables.
    environment: ?Environment = null,
    /// random-item()'s random base and tree counts; numeric math.
    math: math.Context = .{},
};

/// One substitution: a declaration's value walked once, its functions
/// replaced. Its allocations belong to `allocator` (an arena the caller
/// frees).
pub const Resolver = struct {
    allocator: Allocator,
    host: Host,
    /// The property being substituted (random-item()'s cache key).
    property: []const u8,
    /// The consuming declaration's sheet's namespace map (attr()), or null.
    namespaces: ?*const NamespaceMap = null,
    /// The consuming declaration's sheet's quirks mode (if()'s supports()).
    quirks: bool = false,
    /// The function rows (tests stand a recording row in).
    table: Table = default_table,
    early_numeric: usize = 0,
    depth: usize = 0,
    emitted: usize = 0,

    /// Values 5 Appendix A, "substitute arbitrary substitution functions" in
    /// `nodes` (the guard is the caller's: a "property" context for the
    /// declaration being substituted). `early_only` is "substitute
    /// early-invoked functions": only spread functions are replaced.
    /// error.Invalid is the guaranteed-invalid value. The result says
    /// whether it is tainted as a whole (Values 5 §8.7.2) - true for an
    /// empty result a tainted substitution produced, which no node can
    /// carry. One walk; this is the only entry, so no path drops the flag.
    pub fn substituteWithTaint(self: *Resolver, nodes: []const Node, early_only: bool) Error!Replacement {
        const walked = try self.walk(nodes, early_only);
        return .{ .nodes = walked.nodes, .tainted = walked.tainted };
    }

    const Walked = struct { nodes: []const Node, tainted: bool };

    fn walk(self: *Resolver, nodes: []const Node, early_only: bool) Error!Walked {
        self.depth += 1;
        defer self.depth -= 1;
        if (self.depth > max_depth) return error.Invalid;
        var result: std.ArrayList(Node) = .empty;
        var tainted = false;
        var invalid = false;
        // A replacement's last node must not merge with what follows it.
        var spliced_end: ?Node = null;
        for (nodes, 0..) |node, index| {
            if (node.function) |id| {
                const spread = spreadAt(nodes, index);
                if (early_only and !spread) {
                    try self.append(&result, &spliced_end, node);
                    continue;
                }
                if (spread) result.items.len -= 3;
                // 2.5 "If result contains the guaranteed-invalid value,
                // replace func in values with the guaranteed-invalid value"
                // - and continue: the remaining functions are still
                // substituted, so their dependencies (and cycles) count, as
                // in all three browsers (variable-substitution-variable-
                // declaration.html target5's --varC).
                const replacement = self.replace(id, node) catch |err| switch (err) {
                    error.Invalid => {
                        invalid = true;
                        continue;
                    },
                    else => |e| return e,
                };
                var replaced = replacement.nodes;
                if (replacement.tainted) {
                    replaced = try markOwn(self.allocator, replaced);
                    tainted = true;
                } else if (anyTaint(replaced)) tainted = true;
                // Appendix A: substitution is at token boundaries.
                if (replaced.len != 0) {
                    if (result.items.len != 0 and needsSeparator(lastToken(result.items), firstToken(replaced))) try result.append(self.allocator, barrier);
                    try result.appendSlice(self.allocator, replaced);
                    spliced_end = lastToken(replaced);
                }
            } else {
                var copy = node;
                if (node.close != null) {
                    const inner = try self.walk(node.children, early_only);
                    copy.children = inner.nodes;
                    // §8.7.2: a function or block containing a tainted
                    // argument is a container, its own span only.
                    if (inner.tainted and copy.taint == .none) copy.taint = .container;
                    if (inner.tainted) tainted = true;
                } else if (node.taint != .none) tainted = true;
                try self.append(&result, &spliced_end, copy);
            }
            self.emitted += 1;
            if (self.emitted > max_substituted_nodes) return error.Invalid;
        }
        if (invalid) return error.Invalid;
        return .{ .nodes = try result.toOwnedSlice(self.allocator), .tainted = tainted };
    }

    fn append(self: *Resolver, result: *std.ArrayList(Node), spliced_end: *?Node, node: Node) Allocator.Error!void {
        if (spliced_end.*) |end| {
            if (needsSeparator(end, firstToken(&.{node}))) try result.append(self.allocator, barrier);
            spliced_end.* = null;
        }
        try result.append(self.allocator, node);
    }

    /// Steps 2.1-2.5 for one function.
    fn replace(self: *Resolver, id: Id, node: Node) Error!Replacement {
        // 2.1 "Substitute early-invoked functions in func's contents."
        const early = try self.substituteWithTaint(node.children, true);
        // 2.3 "Parse early result according to func's argument grammar."
        const args = try functionIn(self.table, id).arguments(self.allocator, early.nodes, .substituted);
        // 2.4 "Replace an arbitrary substitution function for func." A
        // tainted early substitution taints the replacement.
        var replacement = try functionIn(self.table, id).replace(self, node, args);
        if (early.tainted) replacement.tainted = true;
        return replacement;
    }
};

/// A comment separating two tokens that would otherwise re-tokenize as one
/// (CSS Syntax 3 §9; an empty comment is not whitespace).
const barrier = Node{ .kind = .whitespace, .raw = "/**/" };

fn markOwn(allocator: Allocator, nodes: []const Node) Allocator.Error![]const Node {
    const out = try allocator.alloc(Node, nodes.len);
    for (nodes, out) |node, *copy| {
        copy.* = node;
        copy.taint = .own;
        if (node.children.len != 0) copy.children = try markOwn(allocator, node.children);
    }
    return out;
}

fn anyTaint(nodes: []const Node) bool {
    for (nodes) |node| {
        if (node.taint != .none) return true;
        if (anyTaint(node.children)) return true;
    }
    return false;
}

fn firstToken(nodes: []const Node) Node {
    return nodes[0];
}

/// The last token of a sequence: a block's or function's closing token
/// counts as a `)`-like token, which never merges with what follows.
fn lastToken(nodes: []const Node) Node {
    return nodes[nodes.len - 1];
}

/// CSS Syntax 3 §9's table of token pairs that need a comment between them
/// when serialized side by side (the same table rules.zig's Serializer
/// uses for its own output).
fn needsSeparator(before: Node, after: Node) bool {
    // A function or block ends with its closing token, which is safe.
    if (before.close != null) return false;
    // Text that begins with a comment or whitespace is already separated.
    if (after.raw.len != 0 and (std.mem.startsWith(u8, after.raw, "/*") or isSpaceByte(after.raw[0]))) return false;
    if (before.raw.len != 0 and std.mem.endsWith(u8, before.raw, "*/")) return false;
    const b = boundary(before);
    if (b == .none) return false;
    return switch (after.kind) {
        .ident, .function, .url, .bad_url, .cdc => b == .ident or b == .name or b == .number or b == .at,
        .number, .percentage, .dimension => b == .ident or b == .name or b == .number or b == .sign,
        .left_paren => b == .ident,
        .delim => if (after.value.len == 1) switch (after.value[0]) {
            '-' => b == .ident or b == .name or b == .at,
            '*' => b == .slash,
            '%' => b == .number,
            else => false,
        } else false,
        else => false,
    };
}

fn isSpaceByte(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == 0x0C;
}

const Boundary = enum { none, ident, name, number, at, sign, slash };

fn boundary(node: Node) Boundary {
    return switch (node.kind) {
        .ident => .ident,
        .at_keyword, .hash, .dimension => .name,
        .number => .number,
        .delim => if (node.value.len == 1) switch (node.value[0]) {
            '#', '-' => .name,
            '@' => .at,
            '.', '+' => .sign,
            '/' => .slash,
            else => .none,
        } else .none,
        else => .none,
    };
}

/// Rendered text and its tainted ranges.
pub const Rendered = struct {
    text: []const u8,
    taint: []const TaintRange = &.{},
};

/// The text of `nodes` as written, and where each tainted token lies: an
/// `own` node's whole span (its contents included), a `container` node's
/// own span (a function's name and "(") only.
pub fn render(allocator: Allocator, nodes: []const Node) Allocator.Error!Rendered {
    var out: std.ArrayList(u8) = .empty;
    var ranges: std.ArrayList(TaintRange) = .empty;
    try appendNodes(allocator, nodes, &out, &ranges);
    return .{ .text = try out.toOwnedSlice(allocator), .taint = try ranges.toOwnedSlice(allocator) };
}

fn appendNodes(allocator: Allocator, nodes: []const Node, out: *std.ArrayList(u8), ranges: *std.ArrayList(TaintRange)) Allocator.Error!void {
    for (nodes) |node| {
        const start = out.items.len;
        try out.appendSlice(allocator, node.raw);
        if (node.taint == .container) try ranges.append(allocator, .{ .start = start, .end = out.items.len, .kind = .container });
        if (node.close) |close| {
            try appendNodes(allocator, node.children, out, ranges);
            if (node.close_raw.len != 0) try out.appendSlice(allocator, node.close_raw) else try out.append(allocator, close);
        }
        if (node.taint == .own) try ranges.append(allocator, .{ .start = start, .end = out.items.len, .kind = .own });
    }
}

/// Values 5 "Resolving in Properties": a value that after substitution is
/// only one CSS-wide keyword (and possibly whitespace or comments) is that
/// keyword. Its name, or null.
pub fn soleKeyword(text: []const u8) ?[]const u8 {
    var tokenizer = tokens.Tokenizer.init(text);
    tokenizer.skipWhitespace();
    const token = tokenizer.next();
    if (token.token_type != .ident) return null;
    tokenizer.skipWhitespace();
    if (tokenizer.next().token_type != .eof) return null;
    for ([_][]const u8{ "initial", "inherit", "unset", "revert", "revert-layer", "revert-rule" }) |keyword| {
        if (tokens.nameEql(token.value, keyword)) return keyword;
    }
    return null;
}

/// What substitution knows of the declaration whose value it substitutes.
pub const Declaration = struct {
    /// The property (random-item()'s cache key); "" when there is none.
    property: []const u8 = "",
    namespaces: ?*const NamespaceMap = null,
    quirks: bool = false,
};

/// Substitute `text` (a stored value's original text, already parsed into
/// `nodes`) with `host`, and render it: the substituted text, or
/// error.Invalid for the guaranteed-invalid value (an invalid function, or
/// a result past the over-long limit).
pub fn substituteAndRender(allocator: Allocator, nodes: []const Node, host: Host, declaration: Declaration) Error!Rendered {
    var resolver: Resolver = .{ .allocator = allocator, .host = host, .property = declaration.property, .namespaces = declaration.namespaces, .quirks = declaration.quirks };
    const substituted = (try resolver.substituteWithTaint(nodes, false)).nodes;
    const rendered = try render(allocator, substituted);
    if (rendered.text.len > max_substituted_bytes) return error.Invalid;
    return rendered;
}

/// A function's arguments at computed-value time, after early substitution.
pub fn arguments(allocator: Allocator, id: Id, contents: []const Node, phase: Phase) Error![]const []const Node {
    return function(id).arguments(allocator, contents, phase);
}
