//! CSS Values 5 Appendix A, "Arbitrary Substitution Functions": the engine
//! every such function shares. A declaration whose value contains one is
//! valid at parse time when every one of them matches its ARGUMENT GRAMMAR
//! ("Resolving in Properties"), is stored as a pending-substitution value
//! (pending_values.zig) and is substituted at computed-value time.
//!
//! This file holds what does not depend on any one function: the component
//! value tree of a value (`Node`), the parse that builds it and checks each
//! function's argument grammar, and the free-form argument productions of
//! Values 5 §3.1.1. The functions themselves are rows of `functions`: var()
//! (CSS Variables 1 §3), env() (CSS Environment Variables 1 §3) and
//! random-item() (Values 5 §9.2). attr(), if() and inherit() join the table
//! the same way.
//!
//! Spec: https://drafts.csswg.org/css-values-5/#arbitrary-substitution
//! Spec: https://drafts.csswg.org/css-values-5/#component-function-commas
//! Spec: https://drafts.csswg.org/css-variables-1/#using-variables
//! Spec: https://drafts.csswg.org/css-env-1/#env-function
const std = @import("std");
const tokens = @import("tokenizer.zig");
const Allocator = std.mem.Allocator;

pub const Error = Allocator.Error || error{ Invalid, Unavailable };

/// One component value of a value: a token, or a function or block with its
/// contents. `raw` is the token's source text (a function's includes its
/// "("), so rendering the tree gives back the source between tokens'
/// starts; comments between tokens are dropped by the tokenizer and so are
/// not part of any node (`render` restores the source spacing it needs).
pub const Node = struct {
    kind: tokens.TokenType,
    raw: []const u8,
    value: []const u8 = "",
    children: []const Node = &.{},
    close: ?u8 = null,
    /// The arbitrary substitution function this function token names.
    function: ?Id = null,
    /// random-item()'s per-declaration ordinal (Values 5 §9.4).
    item_index: ?usize = null,
    /// CSS Values 5 §8.7.2: the node came from an attr() substitution.
    taint: bool = false,
};

/// The arbitrary substitution functions Crane implements.
pub const Id = enum {
    /// CSS Variables 1 §3.
    @"var",
    /// CSS Environment Variables 1 §3.
    env,
    /// CSS Values 5 §9.2.
    random_item,

    pub fn name(self: Id) []const u8 {
        return switch (self) {
            .@"var" => "var",
            .env => "env",
            .random_item => "random-item",
        };
    }
};

/// One row per function: its argument grammar, checked at parse time.
pub const Function = struct {
    id: Id,
    /// Values 5 "Argument Grammars": split the function's contents into its
    /// arguments, or error.Invalid. Tokens only; nothing is substituted.
    arguments: *const fn (Allocator, []const Node) Error![]const []const Node,
};

pub const functions = [_]Function{
    .{ .id = .@"var", .arguments = varArguments },
    .{ .id = .env, .arguments = envArguments },
    .{ .id = .random_item, .arguments = randomItemArguments },
};

pub fn function(id: Id) Function {
    inline for (functions) |f| if (f.id == id) return f;
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
    var parser: Parser = .{ .allocator = allocator, .tokenizer = tokens.Tokenizer.init(text) };
    const nodes = try parser.sequence(null);
    try checkDeclarationValue(nodes);
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

/// The nesting and size limits a stored value may reach. Past them the
/// value is invalid, not truncated.
pub const max_depth = 128;
pub const max_nodes = 65536;

const Parser = struct {
    allocator: Allocator,
    tokenizer: tokens.Tokenizer,
    depth: usize = 0,
    count: usize = 0,
    item_index: usize = 0,

    fn sequence(self: *Parser, closing: ?tokens.TokenType) Error![]const Node {
        self.depth += 1;
        defer self.depth -= 1;
        if (self.depth > max_depth) return error.Invalid;
        var nodes: std.ArrayList(Node) = .empty;
        while (true) {
            const start = self.tokenizer.pos;
            const token = self.tokenizer.next();
            if (token.token_type == .eof) break; // Syntax 3 closes blocks at EOF.
            if (closing != null and token.token_type == closing.?) break;
            switch (token.token_type) {
                .right_paren, .right_bracket, .right_brace, .bad_string, .bad_url => return error.Invalid,
                else => {},
            }
            self.count += 1;
            if (self.count > max_nodes) return error.Invalid;
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
                node.children = try self.sequence(end);
                // Values 5 Appendix A: a spread (`...f()`) among the
                // contents is substituted before the split, so its
                // arguments are known only then.
                if (node.function) |id| if (!hasSpread(node.children)) {
                    _ = try function(id).arguments(self.allocator, node.children);
                };
            }
            try nodes.append(self.allocator, node);
        }
        return nodes.toOwnedSlice(self.allocator);
    }
};

/// CSS Syntax 3 §7.2 at the value's top level: no `!` delim and no `;`.
/// (A function's own arguments are checked by its grammar.)
fn checkDeclarationValue(nodes: []const Node) Error!void {
    for (nodes) |node| {
        if (node.kind == .semicolon) return error.Invalid;
        if (node.kind == .delim and std.mem.eql(u8, node.value, "!")) return error.Invalid;
    }
}

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

/// <declaration-value>'s own restriction, inside any wrapper (Values 5
/// §3.1.1: "General restrictions defined for a particular free-form
/// production ... apply regardless of whether it's {}-wrapped or not").
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

/// CSS Variables 1 §3: `<var-args> = var( <declaration-value> ,
/// <declaration-value>? )`. The name argument is substituted and only then
/// parsed as a <custom-property-name> (replace a var() function, step 2), so
/// `var(--x ())` is valid at parse time and `var()` is not (a
/// <declaration-value> is one or more tokens).
///
/// Golden rule 2 (integrator, 2026-10-25, Q1): this is the newer grammar.
/// css-variables-1 ED §3 defines it; WebKit implemented it in trunk (bug
/// 320896, RESOLVED FIXED, 318912@main, 2026-08, exported as wpt#61857:
/// css/css-variables/var-parsing.html); Chrome 156, Firefox 158 and Safari 27
/// stable fail the same eight names of that file - a lag, not a refusal.
fn varArguments(allocator: Allocator, contents: []const Node) Error![]const []const Node {
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

/// CSS Environment Variables 1 §3: `env( <custom-ident> <integer [0,∞]>*,
/// <declaration-value>? )`, checked at parse time. css-env-1's newer
/// `<env-args>` line would accept any <declaration-value> name, but all
/// three browsers keep the strict grammar and WPT pins it
/// (css/css-env/env-parsing.html rejects `env(x ())`; Chrome 156, Firefox
/// 158, Safari 27 pass it), so the strict one stands (golden rule 2, no
/// browser ships the newer behaviour; integrator Q1).
fn envArguments(allocator: Allocator, contents: []const Node) Error![]const []const Node {
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
    var i: usize = 1;
    var integers: usize = 0;
    while (i < nodes.len) : (i += 1) {
        const node = nodes[i];
        if (isSpace(node)) continue;
        if (node.kind != .number or !isNonNegativeInteger(node.value)) return error.Invalid;
        integers += 1;
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

/// Values 5 §9.2: `random-item( <random-key>, [<declaration-value>?]# )`,
/// each item a free-form argument whose top-level `!`/`;` restriction
/// survives unwrapping. Only the key must be nonempty at parse time. (Row
/// 118's grammar, unchanged: an unwrapped item matches no top-level block of
/// any kind.)
fn randomItemArguments(allocator: Allocator, contents: []const Node) Error![]const []const Node {
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

/// A function's arguments at computed-value time, after early substitution.
pub fn arguments(allocator: Allocator, id: Id, contents: []const Node) Error![]const []const Node {
    return function(id).arguments(allocator, contents);
}
