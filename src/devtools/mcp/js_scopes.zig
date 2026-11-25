//! Pure-Zig JavaScript lexer, lexical scope analyzer, source-map variable name
//! resolver, and logpoint expression substituter (batch 4b item 3c),
//! reproducing the DevTools frontend's minified-name substitution pipeline:
//!
//! - Upstream project: Chrome DevTools Frontend (devtools-frontend, bundled in
//!   chrome-devtools-mcp v1.13.0), BSD-3-Clause (Copyright The Chromium
//!   Authors; THIRD_PARTY_NOTICES.md).
//! - Upstream files reproduced (algorithm, not copied verbatim):
//!   - `front_end/models/source_map_scopes/NamesResolver.ts`: `findScopeChain`,
//!     `scopeIdentifiers`, `resolveScope`, `resolveSourceName`,
//!     `extractIdentifier`, `toScopeVariableMapping`, `allVariablesAtPosition`
//!   - `front_end/entrypoints/formatter_worker/ScopeParser.ts`: lexical scope
//!     tree (`Scope`, `ScopeKind`, `DefinitionKind`, `var` hoisting, destructuring,
//!     `for`/`catch`/block/function/arrow scopes, identifier use resolution)
//!   - `front_end/entrypoints/formatter_worker/Substitute.ts`:
//!     `computeSubstitutionMap` (inner-to-outer shadowing of generated names),
//!     `substituteExpression` (free-variable substitution and object shorthand
//!     expansion `{x}` -> `{x: gen}`)

const std = @import("std");
const Allocator = std.mem.Allocator;
const source_map = @import("source_map.zig");
const SourceMap = source_map.SourceMap;
const TextRange = source_map.TextRange;

// ---------------------------------------------------------------------------
// LineIndex: UTF-16 (line, column) <-> byte offset mapping (TextUtils.Text)
// ---------------------------------------------------------------------------

pub const Position = struct {
    line: i64,
    column: i64,
};

pub const LineIndex = struct {
    text: []const u8,
    line_starts: []usize,

    pub fn init(arena: Allocator, text: []const u8) Allocator.Error!LineIndex {
        var starts: std.ArrayList(usize) = .empty;
        try starts.append(arena, 0);
        for (text, 0..) |c, i| {
            if (c == '\n') try starts.append(arena, i + 1);
        }
        return .{ .text = text, .line_starts = starts.items };
    }

    pub fn offsetFromPosition(self: *const LineIndex, line: i64, column: i64) usize {
        if (line < 0 or self.line_starts.len == 0) return 0;
        const line_idx: usize = @intCast(line);
        if (line_idx >= self.line_starts.len) return self.text.len;
        const start = self.line_starts[line_idx];
        const line_end = if (line_idx + 1 < self.line_starts.len)
            self.line_starts[line_idx + 1] - 1
        else
            self.text.len;
        if (column <= 0) return start;
        var target_col: usize = @intCast(column);
        var i = start;
        while (i < line_end and target_col > 0) {
            const b = self.text[i];
            if (b < 0x80) {
                i += 1;
                target_col -= 1;
            } else {
                const cp_len = std.unicode.utf8ByteSequenceLength(b) catch 1;
                const adv = @min(cp_len, line_end - i);
                const units: usize = if (adv == 4) 2 else 1;
                i += adv;
                target_col -|= units;
            }
        }
        return i;
    }

    pub fn positionFromOffset(self: *const LineIndex, raw_offset: usize) Position {
        const offset = @min(raw_offset, self.text.len);
        // Binary search for greatest line_start <= offset.
        var l: usize = 0;
        var r: usize = self.line_starts.len;
        while (l < r) {
            const m = l + (r - l) / 2;
            if (self.line_starts[m] <= offset) {
                l = m + 1;
            } else {
                r = m;
            }
        }
        const line_idx = if (l > 0) l - 1 else 0;
        const start = self.line_starts[line_idx];
        var col: i64 = 0;
        var i = start;
        while (i < offset) {
            const b = self.text[i];
            if (b < 0x80) {
                i += 1;
                col += 1;
            } else {
                const cp_len = std.unicode.utf8ByteSequenceLength(b) catch 1;
                const adv = @min(cp_len, offset - i);
                col += if (adv == 4) 2 else 1;
                i += adv;
            }
        }
        return .{ .line = @intCast(line_idx), .column = col };
    }

    pub fn extractRange(self: *const LineIndex, range: TextRange) []const u8 {
        const start = self.offsetFromPosition(range.start_line, range.start_column);
        const end = self.offsetFromPosition(range.end_line, range.end_column);
        if (end <= start) return "";
        return self.text[start..end];
    }
};

// ---------------------------------------------------------------------------
// ES202x Lexer
// ---------------------------------------------------------------------------

const TokenKind = enum {
    eof,
    ident,
    private_ident,
    number,
    string,
    regex,
    template_no_sub,
    template_head,
    template_middle,
    template_tail,
    lparen,
    rparen,
    lbrace,
    rbrace,
    lbracket,
    rbracket,
    dot,
    qdot,
    ellipsis,
    comma,
    semi,
    colon,
    question,
    arrow,
    assign,
    assign_op,
    inc_dec,
    op,
};

const Token = struct {
    kind: TokenKind,
    start: usize,
    end: usize,
    line_before: bool = false,

    fn slice(self: Token, src: []const u8) []const u8 {
        return src[self.start..self.end];
    }

    fn is(self: Token, src: []const u8, kw: []const u8) bool {
        return self.kind == .ident and std.mem.eql(u8, src[self.start..self.end], kw);
    }
};

fn isIdentStart(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_' or c == '$' or c >= 0x80;
}

fn isIdentContinue(c: u8) bool {
    return isIdentStart(c) or (c >= '0' and c <= '9');
}

fn isLineTerminator(c: u8) bool {
    return c == '\n' or c == '\r';
}

fn isRegexPrecedingKeyword(word: []const u8) bool {
    const kws = [_][]const u8{
        "return", "throw", "case",       "delete", "void",
        "typeof", "in",    "instanceof", "new",    "of",
        "yield",  "await", "else",       "do",
    };
    for (kws) |kw| if (std.mem.eql(u8, word, kw)) return true;
    return false;
}

fn isCondKeyword(word: []const u8) bool {
    return std.mem.eql(u8, word, "if") or
        std.mem.eql(u8, word, "while") or
        std.mem.eql(u8, word, "for") or
        std.mem.eql(u8, word, "with");
}

fn tokenize(arena: Allocator, src: []const u8) Allocator.Error![]Token {
    var tokens: std.ArrayList(Token) = .empty;
    var template_braces: std.ArrayList(usize) = .empty;
    var paren_cond_stack: std.ArrayList(bool) = .empty;

    var pos: usize = 0;
    var brace_depth: usize = 0;
    var allows_regex: bool = true;
    var prev_was_cond_kw: bool = false;

    // Optional hashbang `#!...` at offset 0.
    if (src.len >= 2 and src[0] == '#' and src[1] == '!') {
        while (pos < src.len and !isLineTerminator(src[pos])) pos += 1;
    }

    while (pos < src.len) {
        var line_before = false;
        // Skip whitespace and comments.
        while (pos < src.len) {
            const c = src[pos];
            if (c == ' ' or c == '\t' or c == 0x0b or c == 0x0c) {
                pos += 1;
            } else if (c == '\n' or c == '\r') {
                line_before = true;
                pos += 1;
            } else if (c == '/' and pos + 1 < src.len and src[pos + 1] == '/') {
                pos += 2;
                while (pos < src.len and !isLineTerminator(src[pos])) pos += 1;
            } else if (c == '/' and pos + 1 < src.len and src[pos + 1] == '*') {
                pos += 2;
                while (pos + 1 < src.len and !(src[pos] == '*' and src[pos + 1] == '/')) {
                    if (isLineTerminator(src[pos])) line_before = true;
                    pos += 1;
                }
                pos = if (pos + 1 < src.len) pos + 2 else src.len;
            } else if (c == 0xEF and pos + 2 < src.len and src[pos + 1] == 0xBB and src[pos + 2] == 0xBF) {
                pos += 3;
            } else if (c == 0xE2 and pos + 2 < src.len and src[pos + 1] == 0x80 and (src[pos + 2] == 0xA8 or src[pos + 2] == 0xA9)) {
                line_before = true;
                pos += 3;
            } else {
                break;
            }
        }
        if (pos >= src.len) break;

        const start = pos;
        const c = src[pos];
        var kind: TokenKind = .op;

        if (c == '\'' or c == '"') {
            pos += 1;
            while (pos < src.len) {
                const ch = src[pos];
                if (ch == '\\') {
                    pos = @min(pos + 2, src.len);
                } else if (ch == c) {
                    pos += 1;
                    break;
                } else if (isLineTerminator(ch)) {
                    break;
                } else {
                    pos += 1;
                }
            }
            kind = .string;
            allows_regex = false;
            prev_was_cond_kw = false;
        } else if (c == '`') {
            pos += 1;
            const res = scanTemplateTail(src, &pos);
            if (res == .sub) {
                try template_braces.append(arena, brace_depth);
                kind = .template_head;
                allows_regex = true;
            } else {
                kind = .template_no_sub;
                allows_regex = false;
            }
            prev_was_cond_kw = false;
        } else if (c == '}') {
            if (template_braces.items.len > 0 and template_braces.items[template_braces.items.len - 1] == brace_depth) {
                _ = template_braces.pop();
                pos += 1;
                const res = scanTemplateTail(src, &pos);
                if (res == .sub) {
                    try template_braces.append(arena, brace_depth);
                    kind = .template_middle;
                    allows_regex = true;
                } else {
                    kind = .template_tail;
                    allows_regex = false;
                }
            } else {
                pos += 1;
                brace_depth -|= 1;
                kind = .rbrace;
                allows_regex = true;
            }
            prev_was_cond_kw = false;
        } else if (c == '{') {
            pos += 1;
            brace_depth += 1;
            kind = .lbrace;
            allows_regex = true;
            prev_was_cond_kw = false;
        } else if (c == '(') {
            pos += 1;
            try paren_cond_stack.append(arena, prev_was_cond_kw);
            kind = .lparen;
            allows_regex = true;
            prev_was_cond_kw = false;
        } else if (c == ')') {
            pos += 1;
            const was_cond = if (paren_cond_stack.items.len > 0) paren_cond_stack.pop().? else false;
            kind = .rparen;
            allows_regex = was_cond;
            prev_was_cond_kw = false;
        } else if (c == '[') {
            pos += 1;
            kind = .lbracket;
            allows_regex = true;
            prev_was_cond_kw = false;
        } else if (c == ']') {
            pos += 1;
            kind = .rbracket;
            allows_regex = false;
            prev_was_cond_kw = false;
        } else if (c == '#') {
            pos += 1;
            while (pos < src.len and isIdentContinue(src[pos])) pos += 1;
            kind = .private_ident;
            allows_regex = false;
            prev_was_cond_kw = false;
        } else if (isIdentStart(c) or (c == '\\' and pos + 1 < src.len and src[pos + 1] == 'u')) {
            scanIdentifier(src, &pos);
            kind = .ident;
            const word = src[start..pos];
            allows_regex = isRegexPrecedingKeyword(word);
            prev_was_cond_kw = isCondKeyword(word);
        } else if ((c >= '0' and c <= '9') or (c == '.' and pos + 1 < src.len and src[pos + 1] >= '0' and src[pos + 1] <= '9')) {
            scanNumber(src, &pos);
            kind = .number;
            allows_regex = false;
            prev_was_cond_kw = false;
        } else if (c == '/' and allows_regex) {
            scanRegex(src, &pos);
            kind = .regex;
            allows_regex = false;
            prev_was_cond_kw = false;
        } else {
            prev_was_cond_kw = false;
            kind = scanPunctuator(src, &pos, &allows_regex);
        }

        try tokens.append(arena, .{
            .kind = kind,
            .start = start,
            .end = pos,
            .line_before = line_before,
        });
    }

    try tokens.append(arena, .{ .kind = .eof, .start = src.len, .end = src.len, .line_before = false });
    return tokens.items;
}

fn scanTemplateTail(src: []const u8, pos: *usize) enum { end, sub } {
    while (pos.* < src.len) {
        const ch = src[pos.*];
        if (ch == '\\') {
            pos.* = @min(pos.* + 2, src.len);
        } else if (ch == '`') {
            pos.* += 1;
            return .end;
        } else if (ch == '$' and pos.* + 1 < src.len and src[pos.* + 1] == '{') {
            pos.* += 2;
            return .sub;
        } else {
            pos.* += 1;
        }
    }
    return .end;
}

fn scanIdentifier(src: []const u8, pos: *usize) void {
    while (pos.* < src.len) {
        const ch = src[pos.*];
        if (isIdentContinue(ch)) {
            pos.* += 1;
        } else if (ch == '\\' and pos.* + 1 < src.len and src[pos.* + 1] == 'u') {
            pos.* += 2;
            if (pos.* < src.len and src[pos.*] == '{') {
                pos.* += 1;
                while (pos.* < src.len and src[pos.*] != '}') pos.* += 1;
                if (pos.* < src.len) pos.* += 1;
            } else {
                var n: usize = 0;
                while (n < 4 and pos.* < src.len and std.ascii.isHex(src[pos.*])) : (n += 1) pos.* += 1;
            }
        } else {
            break;
        }
    }
}

fn scanNumber(src: []const u8, pos: *usize) void {
    if (src[pos.*] == '0' and pos.* + 1 < src.len) {
        const n = src[pos.* + 1];
        if (n == 'x' or n == 'X' or n == 'b' or n == 'B' or n == 'o' or n == 'O') {
            pos.* += 2;
            while (pos.* < src.len and (std.ascii.isHex(src[pos.*]) or src[pos.*] == '_')) pos.* += 1;
            if (pos.* < src.len and src[pos.*] == 'n') pos.* += 1;
            return;
        }
    }
    while (pos.* < src.len and (std.ascii.isDigit(src[pos.*]) or src[pos.*] == '_')) pos.* += 1;
    if (pos.* < src.len and src[pos.*] == '.') {
        pos.* += 1;
        while (pos.* < src.len and (std.ascii.isDigit(src[pos.*]) or src[pos.*] == '_')) pos.* += 1;
    }
    if (pos.* < src.len and (src[pos.*] == 'e' or src[pos.*] == 'E')) {
        pos.* += 1;
        if (pos.* < src.len and (src[pos.*] == '+' or src[pos.*] == '-')) pos.* += 1;
        while (pos.* < src.len and (std.ascii.isDigit(src[pos.*]) or src[pos.*] == '_')) pos.* += 1;
    }
    if (pos.* < src.len and src[pos.*] == 'n') pos.* += 1;
}

fn scanRegex(src: []const u8, pos: *usize) void {
    pos.* += 1; // opening '/'
    var in_class = false;
    while (pos.* < src.len) {
        const ch = src[pos.*];
        if (ch == '\\') {
            pos.* = @min(pos.* + 2, src.len);
        } else if (ch == '[') {
            in_class = true;
            pos.* += 1;
        } else if (ch == ']') {
            in_class = false;
            pos.* += 1;
        } else if (ch == '/' and !in_class) {
            pos.* += 1;
            break;
        } else if (isLineTerminator(ch)) {
            break;
        } else {
            pos.* += 1;
        }
    }
    while (pos.* < src.len and isIdentContinue(src[pos.*])) pos.* += 1;
}

fn scanPunctuator(src: []const u8, pos: *usize, allows_regex: *bool) TokenKind {
    const c = src[pos.*];
    const rem = src.len - pos.*;
    allows_regex.* = true;

    if (c == '.') {
        if (rem >= 3 and src[pos.* + 1] == '.' and src[pos.* + 2] == '.') {
            pos.* += 3;
            return .ellipsis;
        }
        pos.* += 1;
        allows_regex.* = false;
        return .dot;
    }
    if (c == '?') {
        if (rem >= 2 and src[pos.* + 1] == '.') {
            if (rem < 3 or !std.ascii.isDigit(src[pos.* + 2])) {
                pos.* += 2;
                allows_regex.* = false;
                return .qdot;
            }
        }
        if (rem >= 3 and src[pos.* + 1] == '?' and src[pos.* + 2] == '=') {
            pos.* += 3;
            return .assign_op;
        }
        if (rem >= 2 and src[pos.* + 1] == '?') {
            pos.* += 2;
            return .op;
        }
        pos.* += 1;
        return .question;
    }
    if (c == ',') {
        pos.* += 1;
        return .comma;
    }
    if (c == ';') {
        pos.* += 1;
        return .semi;
    }
    if (c == ':') {
        pos.* += 1;
        return .colon;
    }
    if (c == '=') {
        if (rem >= 2 and src[pos.* + 1] == '>') {
            pos.* += 2;
            return .arrow;
        }
        if (rem >= 3 and src[pos.* + 1] == '=' and src[pos.* + 2] == '=') {
            pos.* += 3;
            return .op;
        }
        if (rem >= 2 and src[pos.* + 1] == '=') {
            pos.* += 2;
            return .op;
        }
        pos.* += 1;
        return .assign;
    }
    if (c == '+' or c == '-') {
        if (rem >= 2 and src[pos.* + 1] == c) {
            pos.* += 2;
            allows_regex.* = false;
            return .inc_dec;
        }
        if (rem >= 2 and src[pos.* + 1] == '=') {
            pos.* += 2;
            return .assign_op;
        }
        pos.* += 1;
        return .op;
    }
    if (c == '*' or c == '&' or c == '|') {
        if (rem >= 3 and src[pos.* + 1] == c and src[pos.* + 2] == '=') {
            pos.* += 3;
            return .assign_op;
        }
        if (rem >= 2 and src[pos.* + 1] == c) {
            pos.* += 2;
            return .op;
        }
        if (rem >= 2 and src[pos.* + 1] == '=') {
            pos.* += 2;
            return .assign_op;
        }
        pos.* += 1;
        return .op;
    }
    if (c == '<' or c == '>') {
        if (c == '>' and rem >= 4 and src[pos.* + 1] == '>' and src[pos.* + 2] == '>' and src[pos.* + 3] == '=') {
            pos.* += 4;
            return .assign_op;
        }
        if (c == '>' and rem >= 3 and src[pos.* + 1] == '>' and src[pos.* + 2] == '>') {
            pos.* += 3;
            return .op;
        }
        if (rem >= 3 and src[pos.* + 1] == c and src[pos.* + 2] == '=') {
            pos.* += 3;
            return .assign_op;
        }
        if (rem >= 2 and (src[pos.* + 1] == c or src[pos.* + 1] == '=')) {
            pos.* += 2;
            return .op;
        }
        pos.* += 1;
        return .op;
    }
    if (c == '!') {
        if (rem >= 3 and src[pos.* + 1] == '=' and src[pos.* + 2] == '=') {
            pos.* += 3;
            return .op;
        }
        if (rem >= 2 and src[pos.* + 1] == '=') {
            pos.* += 2;
            return .op;
        }
        pos.* += 1;
        return .op;
    }
    if (c == '/' or c == '%' or c == '^') {
        if (rem >= 2 and src[pos.* + 1] == '=') {
            pos.* += 2;
            return .assign_op;
        }
        pos.* += 1;
        return .op;
    }
    pos.* += 1;
    return .op;
}

// ---------------------------------------------------------------------------
// Scope Tree & Binding Analyzer (ScopeParser.ts)
// ---------------------------------------------------------------------------

pub const ScopeKind = enum {
    global,
    function,
    arrow_function,
    block,
};

pub const DefKind = enum {
    none,
    let_kind,
    var_kind,
    fixed,
};

pub const VariableUse = struct {
    offset: usize,
    len: usize,
    is_shorthand_prop: bool = false,
};

pub const Variable = struct {
    name: []const u8,
    kind: DefKind,
    uses: std.ArrayList(VariableUse) = .empty,
};

const PendingUse = struct {
    name: []const u8,
    offset: usize,
    len: usize,
    is_shorthand_prop: bool = false,
};

pub const Scope = struct {
    kind: ScopeKind,
    start: usize,
    end: usize,
    parent: ?usize,
    children: std.ArrayList(usize) = .empty,
    variables: std.ArrayList(Variable) = .empty,
    pending_uses: std.ArrayList(PendingUse) = .empty,
};

pub const ScopeTree = struct {
    scopes: std.ArrayList(Scope) = .empty,

    /// Find the chain of enclosing scopes from global root (index 0) down to
    /// the innermost scope containing `offset`.
    pub fn findScopeChain(self: *const ScopeTree, arena: Allocator, offset: usize) Allocator.Error![]usize {
        if (self.scopes.items.len == 0) return &.{};
        var chain: std.ArrayList(usize) = .empty;
        var cur: usize = 0;
        try chain.append(arena, cur);
        while (true) {
            var found: ?usize = null;
            for (self.scopes.items[cur].children.items) |child_idx| {
                const child = &self.scopes.items[child_idx];
                if (child.start <= offset and offset < child.end) {
                    found = child_idx;
                    break;
                }
            }
            if (found) |next_idx| {
                try chain.append(arena, next_idx);
                cur = next_idx;
            } else {
                break;
            }
        }
        return chain.items;
    }
};

const max_parse_depth: usize = 128;

const Parser = struct {
    arena: Allocator,
    src: []const u8,
    tokens: []const Token,
    idx: usize = 0,
    tree: ScopeTree = .{},
    cur_scope: usize = 0,
    depth: usize = 0,

    fn tok(self: *const Parser) Token {
        return self.tokens[@min(self.idx, self.tokens.len - 1)];
    }

    fn peek(self: *const Parser, ahead: usize) Token {
        return self.tokens[@min(self.idx + ahead, self.tokens.len - 1)];
    }

    fn advance(self: *Parser) Token {
        const t = self.tok();
        if (self.idx + 1 < self.tokens.len) self.idx += 1;
        return t;
    }

    fn isKw(self: *const Parser, kw: []const u8) bool {
        return self.tok().is(self.src, kw);
    }

    fn pushScope(self: *Parser, kind: ScopeKind, start: usize) Allocator.Error!usize {
        const parent = self.cur_scope;
        const new_idx = self.tree.scopes.items.len;
        try self.tree.scopes.append(self.arena, .{
            .kind = kind,
            .start = start,
            .end = self.src.len,
            .parent = parent,
        });
        try self.tree.scopes.items[parent].children.append(self.arena, new_idx);
        self.cur_scope = new_idx;
        return new_idx;
    }

    fn popScope(self: *Parser, scope_idx: usize, end_offset: usize) void {
        self.tree.scopes.items[scope_idx].end = @max(self.tree.scopes.items[scope_idx].start, end_offset);
        self.cur_scope = self.tree.scopes.items[scope_idx].parent orelse 0;
    }

    fn addDecl(self: *Parser, name: []const u8, kind: DefKind, offset: usize, len: usize) Allocator.Error!void {
        var target = self.cur_scope;
        if (kind == .var_kind) {
            while (self.tree.scopes.items[target].kind == .block) {
                target = self.tree.scopes.items[target].parent orelse break;
            }
        }
        const scope = &self.tree.scopes.items[target];
        for (scope.variables.items) |*v| {
            if (std.mem.eql(u8, v.name, name)) {
                if (len > 0) {
                    try v.uses.append(self.arena, .{ .offset = offset, .len = len });
                }
                return;
            }
        }
        var v: Variable = .{ .name = name, .kind = kind };
        if (len > 0) {
            try v.uses.append(self.arena, .{ .offset = offset, .len = len });
        }
        try scope.variables.append(self.arena, v);
    }

    fn addUse(self: *Parser, name: []const u8, offset: usize, len: usize, is_shorthand_prop: bool) Allocator.Error!void {
        try self.tree.scopes.items[self.cur_scope].pending_uses.append(self.arena, .{
            .name = name,
            .offset = offset,
            .len = len,
            .is_shorthand_prop = is_shorthand_prop,
        });
    }

    fn resolveAllUses(self: *Parser) Allocator.Error!void {
        for (self.tree.scopes.items, 0..) |_, s_idx| {
            const pending = self.tree.scopes.items[s_idx].pending_uses.items;
            for (pending) |u| {
                var cur: ?usize = s_idx;
                var bound_scope: ?usize = null;
                var bound_var: usize = 0;
                while (cur) |c_idx| {
                    const scope = &self.tree.scopes.items[c_idx];
                    for (scope.variables.items, 0..) |v, v_idx| {
                        if (v.kind != .none and std.mem.eql(u8, v.name, u.name)) {
                            bound_scope = c_idx;
                            bound_var = v_idx;
                            break;
                        }
                    }
                    if (bound_scope != null) break;
                    cur = scope.parent;
                }
                const use_entry: VariableUse = .{
                    .offset = u.offset,
                    .len = u.len,
                    .is_shorthand_prop = u.is_shorthand_prop,
                };
                if (bound_scope) |bs| {
                    try self.tree.scopes.items[bs].variables.items[bound_var].uses.append(self.arena, use_entry);
                } else {
                    const root = &self.tree.scopes.items[0];
                    var found: ?usize = null;
                    for (root.variables.items, 0..) |v, v_idx| {
                        if (v.kind == .none and std.mem.eql(u8, v.name, u.name)) {
                            found = v_idx;
                            break;
                        }
                    }
                    if (found) |fi| {
                        try root.variables.items[fi].uses.append(self.arena, use_entry);
                    } else {
                        var v: Variable = .{ .name = u.name, .kind = .none };
                        try v.uses.append(self.arena, use_entry);
                        try root.variables.append(self.arena, v);
                    }
                }
            }
        }
    }

    fn parseProgram(self: *Parser) Allocator.Error!void {
        try self.tree.scopes.append(self.arena, .{
            .kind = .global,
            .start = 0,
            .end = self.src.len,
            .parent = null,
        });
        while (self.tok().kind != .eof) {
            const before = self.idx;
            try self.parseStatement();
            if (self.idx == before) _ = self.advance();
        }
        try self.resolveAllUses();
    }

    fn parseStatement(self: *Parser) Allocator.Error!void {
        if (self.depth >= max_parse_depth) {
            _ = self.advance();
            return;
        }
        self.depth += 1;
        defer self.depth -= 1;

        const t = self.tok();
        switch (t.kind) {
            .eof => return,
            .semi => {
                _ = self.advance();
                return;
            },
            .lbrace => {
                const start = t.start;
                _ = self.advance();
                const sc = try self.pushScope(.block, start);
                while (self.tok().kind != .eof and self.tok().kind != .rbrace) {
                    const before = self.idx;
                    try self.parseStatement();
                    if (self.idx == before) _ = self.advance();
                }
                const end_off = if (self.tok().kind == .rbrace) self.advance().end else self.src.len;
                self.popScope(sc, end_off);
                return;
            },
            .ident => {
                const word = t.slice(self.src);
                // Labeled statement: `ident : stmt` (unless reserved keyword handled below).
                if (self.peek(1).kind == .colon and !std.mem.eql(u8, word, "default")) {
                    _ = self.advance();
                    _ = self.advance();
                    try self.parseStatement();
                    return;
                }
                if (std.mem.eql(u8, word, "var")) {
                    _ = self.advance();
                    try self.parseVarDeclList(.var_kind);
                    if (self.tok().kind == .semi) _ = self.advance();
                    return;
                }
                if (std.mem.eql(u8, word, "const")) {
                    _ = self.advance();
                    try self.parseVarDeclList(.let_kind);
                    if (self.tok().kind == .semi) _ = self.advance();
                    return;
                }
                if (std.mem.eql(u8, word, "let") and self.looksLikeLetDecl()) {
                    _ = self.advance();
                    try self.parseVarDeclList(.let_kind);
                    if (self.tok().kind == .semi) _ = self.advance();
                    return;
                }
                if (std.mem.eql(u8, word, "function")) {
                    try self.parseFunctionDeclOrExpr(t.start, true);
                    return;
                }
                if (std.mem.eql(u8, word, "async") and !self.peek(1).line_before and self.peek(1).is(self.src, "function")) {
                    _ = self.advance();
                    try self.parseFunctionDeclOrExpr(t.start, true);
                    return;
                }
                if (std.mem.eql(u8, word, "class")) {
                    try self.parseClassDeclOrExpr(t.start, true);
                    return;
                }
                if (std.mem.eql(u8, word, "for")) {
                    try self.parseForStatement();
                    return;
                }
                if (std.mem.eql(u8, word, "try")) {
                    try self.parseTryStatement();
                    return;
                }
                if (std.mem.eql(u8, word, "if")) {
                    _ = self.advance();
                    try self.parseParenExpr();
                    try self.parseStatement();
                    if (self.isKw("else")) {
                        _ = self.advance();
                        try self.parseStatement();
                    }
                    return;
                }
                if (std.mem.eql(u8, word, "while") or std.mem.eql(u8, word, "with")) {
                    _ = self.advance();
                    try self.parseParenExpr();
                    try self.parseStatement();
                    return;
                }
                if (std.mem.eql(u8, word, "do")) {
                    _ = self.advance();
                    try self.parseStatement();
                    if (self.isKw("while")) {
                        _ = self.advance();
                        try self.parseParenExpr();
                    }
                    if (self.tok().kind == .semi) _ = self.advance();
                    return;
                }
                if (std.mem.eql(u8, word, "switch")) {
                    try self.parseSwitchStatement();
                    return;
                }
                if (std.mem.eql(u8, word, "case")) {
                    _ = self.advance();
                    try self.parseExpression();
                    if (self.tok().kind == .colon) _ = self.advance();
                    return;
                }
                if (std.mem.eql(u8, word, "default") and self.peek(1).kind == .colon) {
                    _ = self.advance();
                    _ = self.advance();
                    return;
                }
                if (std.mem.eql(u8, word, "return") or std.mem.eql(u8, word, "throw")) {
                    _ = self.advance();
                    if (self.tok().kind != .eof and self.tok().kind != .semi and self.tok().kind != .rbrace and !self.tok().line_before) {
                        try self.parseExpression();
                    }
                    if (self.tok().kind == .semi) _ = self.advance();
                    return;
                }
                if (std.mem.eql(u8, word, "break") or std.mem.eql(u8, word, "continue")) {
                    _ = self.advance();
                    if (self.tok().kind == .ident and !self.tok().line_before) _ = self.advance();
                    if (self.tok().kind == .semi) _ = self.advance();
                    return;
                }
                if (std.mem.eql(u8, word, "debugger")) {
                    _ = self.advance();
                    if (self.tok().kind == .semi) _ = self.advance();
                    return;
                }
                if (std.mem.eql(u8, word, "import") and self.peek(1).kind != .lparen and self.peek(1).kind != .dot) {
                    try self.parseImportDecl();
                    return;
                }
                if (std.mem.eql(u8, word, "export")) {
                    try self.parseExportDecl();
                    return;
                }
            },
            else => {},
        }

        try self.parseExpression();
        if (self.tok().kind == .semi) _ = self.advance();
    }

    fn looksLikeLetDecl(self: *const Parser) bool {
        const next = self.peek(1);
        if (next.kind == .lbrace or next.kind == .lbracket) return true;
        if (next.kind != .ident) return false;
        const w = next.slice(self.src);
        return !std.mem.eql(u8, w, "in") and !std.mem.eql(u8, w, "instanceof");
    }

    fn parseVarDeclList(self: *Parser, kind: DefKind) Allocator.Error!void {
        while (self.tok().kind != .eof) {
            try self.parseBindingPattern(kind);
            if (self.tok().kind == .assign) {
                _ = self.advance();
                try self.parseAssignmentExpression();
            }
            if (self.tok().kind == .comma) {
                _ = self.advance();
            } else {
                break;
            }
        }
    }

    fn parseBindingPattern(self: *Parser, kind: DefKind) Allocator.Error!void {
        if (self.depth >= max_parse_depth) {
            _ = self.advance();
            return;
        }
        self.depth += 1;
        defer self.depth -= 1;

        const t = self.tok();
        switch (t.kind) {
            .ident => {
                _ = self.advance();
                try self.addDecl(t.slice(self.src), kind, t.start, t.end - t.start);
            },
            .lbrace => {
                _ = self.advance();
                while (self.tok().kind != .eof and self.tok().kind != .rbrace) {
                    const before = self.idx;
                    if (self.tok().kind == .ellipsis) {
                        _ = self.advance();
                        try self.parseBindingPattern(kind);
                    } else if (self.tok().kind == .lbracket) {
                        _ = self.advance();
                        try self.parseExpression();
                        if (self.tok().kind == .rbracket) _ = self.advance();
                        if (self.tok().kind == .colon) {
                            _ = self.advance();
                            try self.parseBindingPattern(kind);
                        }
                        if (self.tok().kind == .assign) {
                            _ = self.advance();
                            try self.parseAssignmentExpression();
                        }
                    } else if (self.tok().kind == .ident or self.tok().kind == .string or self.tok().kind == .number) {
                        const key = self.advance();
                        if (self.tok().kind == .colon) {
                            _ = self.advance();
                            try self.parseBindingPattern(kind);
                        } else if (key.kind == .ident) {
                            try self.addDecl(key.slice(self.src), kind, key.start, key.end - key.start);
                        }
                        if (self.tok().kind == .assign) {
                            _ = self.advance();
                            try self.parseAssignmentExpression();
                        }
                    } else {
                        _ = self.advance();
                    }
                    if (self.tok().kind == .comma) _ = self.advance();
                    if (self.idx == before) _ = self.advance();
                }
                if (self.tok().kind == .rbrace) _ = self.advance();
            },
            .lbracket => {
                _ = self.advance();
                while (self.tok().kind != .eof and self.tok().kind != .rbracket) {
                    const before = self.idx;
                    if (self.tok().kind == .comma) {
                        _ = self.advance();
                        continue;
                    }
                    if (self.tok().kind == .ellipsis) {
                        _ = self.advance();
                        try self.parseBindingPattern(kind);
                    } else {
                        try self.parseBindingPattern(kind);
                        if (self.tok().kind == .assign) {
                            _ = self.advance();
                            try self.parseAssignmentExpression();
                        }
                    }
                    if (self.tok().kind == .comma) _ = self.advance();
                    if (self.idx == before) _ = self.advance();
                }
                if (self.tok().kind == .rbracket) _ = self.advance();
            },
            else => {},
        }
    }

    fn parseFunctionDeclOrExpr(self: *Parser, start_offset: usize, is_decl: bool) Allocator.Error!void {
        // Consume `function` and optional `*`.
        _ = self.advance();
        if (self.tok().kind == .op and std.mem.eql(u8, self.tok().slice(self.src), "*")) _ = self.advance();

        var fn_name: ?Token = null;
        if (self.tok().kind == .ident) {
            fn_name = self.advance();
        }
        if (is_decl) {
            if (fn_name) |nm| {
                const dk: DefKind = if (self.tree.scopes.items[self.cur_scope].kind == .block) .let_kind else .var_kind;
                try self.addDecl(nm.slice(self.src), dk, nm.start, nm.end - nm.start);
            }
        }

        const sc = try self.pushScope(.function, start_offset);
        if (!is_decl) {
            if (fn_name) |nm| {
                try self.addDecl(nm.slice(self.src), .let_kind, nm.start, nm.end - nm.start);
            }
        }
        try self.addDecl("this", .fixed, start_offset, 0);
        try self.addDecl("arguments", .fixed, start_offset, 0);

        try self.parseParamList();
        const end_off = try self.parseFunctionBody();
        self.popScope(sc, end_off);
    }

    fn parseParamList(self: *Parser) Allocator.Error!void {
        if (self.tok().kind != .lparen) return;
        _ = self.advance();
        while (self.tok().kind != .eof and self.tok().kind != .rparen) {
            const before = self.idx;
            if (self.tok().kind == .ellipsis) _ = self.advance();
            try self.parseBindingPattern(.let_kind);
            if (self.tok().kind == .assign) {
                _ = self.advance();
                try self.parseAssignmentExpression();
            }
            if (self.tok().kind == .comma) _ = self.advance();
            if (self.idx == before) _ = self.advance();
        }
        if (self.tok().kind == .rparen) _ = self.advance();
    }

    fn parseFunctionBody(self: *Parser) Allocator.Error!usize {
        if (self.tok().kind != .lbrace) return self.tok().start;
        _ = self.advance();
        while (self.tok().kind != .eof and self.tok().kind != .rbrace) {
            const before = self.idx;
            try self.parseStatement();
            if (self.idx == before) _ = self.advance();
        }
        return if (self.tok().kind == .rbrace) self.advance().end else self.src.len;
    }

    fn parseClassDeclOrExpr(self: *Parser, start_offset: usize, is_decl: bool) Allocator.Error!void {
        _ = self.advance(); // `class`
        var cls_name: ?Token = null;
        if (self.tok().kind == .ident and !self.isKw("extends")) {
            cls_name = self.advance();
        }
        if (is_decl) {
            if (cls_name) |nm| {
                try self.addDecl(nm.slice(self.src), .let_kind, nm.start, nm.end - nm.start);
            }
        }
        if (self.isKw("extends")) {
            _ = self.advance();
            try self.parseLeftHandSideUntilBrace();
        }
        const sc = if (!is_decl and cls_name != null) blk: {
            const s = try self.pushScope(.block, start_offset);
            const nm = cls_name.?;
            try self.addDecl(nm.slice(self.src), .let_kind, nm.start, nm.end - nm.start);
            break :blk s;
        } else null;

        if (self.tok().kind == .lbrace) {
            _ = self.advance();
            while (self.tok().kind != .eof and self.tok().kind != .rbrace) {
                const before = self.idx;
                if (self.tok().kind == .semi) {
                    _ = self.advance();
                    continue;
                }
                const member_start = self.tok().start;
                if (self.isKw("static") and self.peek(1).kind == .lbrace) {
                    _ = self.advance();
                    const sb = try self.pushScope(.function, member_start);
                    const end_off = try self.parseFunctionBody();
                    self.popScope(sb, end_off);
                    continue;
                }
                // Optional modifiers: static, async, get, set, *
                while (self.tok().kind != .eof) {
                    const m = self.tok();
                    const nxt = self.peek(1);
                    if ((m.is(self.src, "static") or m.is(self.src, "async") or m.is(self.src, "get") or m.is(self.src, "set")) and
                        nxt.kind != .lparen and nxt.kind != .assign and nxt.kind != .semi and nxt.kind != .rbrace)
                    {
                        _ = self.advance();
                    } else if (m.kind == .op and std.mem.eql(u8, m.slice(self.src), "*")) {
                        _ = self.advance();
                    } else break;
                }
                // Property / method key.
                if (self.tok().kind == .lbracket) {
                    _ = self.advance();
                    try self.parseExpression();
                    if (self.tok().kind == .rbracket) _ = self.advance();
                } else if (self.tok().kind == .ident or self.tok().kind == .private_ident or self.tok().kind == .string or self.tok().kind == .number) {
                    _ = self.advance();
                }
                if (self.tok().kind == .lparen) {
                    const ms = try self.pushScope(.function, member_start);
                    try self.addDecl("this", .fixed, member_start, 0);
                    try self.addDecl("arguments", .fixed, member_start, 0);
                    try self.parseParamList();
                    const end_off = try self.parseFunctionBody();
                    self.popScope(ms, end_off);
                } else if (self.tok().kind == .assign) {
                    _ = self.advance();
                    try self.parseAssignmentExpression();
                    if (self.tok().kind == .semi) _ = self.advance();
                } else if (self.tok().kind == .semi) {
                    _ = self.advance();
                }
                if (self.idx == before) _ = self.advance();
            }
            const end_off = if (self.tok().kind == .rbrace) self.advance().end else self.src.len;
            if (sc) |s| self.popScope(s, end_off);
        } else if (sc) |s| {
            self.popScope(s, self.tok().start);
        }
    }

    fn parseLeftHandSideUntilBrace(self: *Parser) Allocator.Error!void {
        while (self.tok().kind != .eof and self.tok().kind != .lbrace and self.tok().kind != .semi) {
            const before = self.idx;
            try self.parsePrimaryAndPostfix();
            if (self.tok().kind == .lbrace or self.tok().kind == .semi or self.tok().kind == .eof) break;
            if (self.idx == before) _ = self.advance();
        }
    }

    fn parseForStatement(self: *Parser) Allocator.Error!void {
        const start = self.advance().start; // `for`
        if (self.isKw("await")) _ = self.advance();
        const sc = try self.pushScope(.block, start);

        if (self.tok().kind == .lparen) {
            _ = self.advance();
            if (self.tok().kind != .semi) {
                if (self.isKw("var") or self.isKw("let") or self.isKw("const")) {
                    const dk: DefKind = if (self.isKw("var")) .var_kind else .let_kind;
                    _ = self.advance();
                    try self.parseBindingPattern(dk);
                    if (self.tok().kind == .assign) {
                        _ = self.advance();
                        try self.parseAssignmentExpression();
                    }
                    while (self.tok().kind == .comma) {
                        _ = self.advance();
                        try self.parseBindingPattern(dk);
                        if (self.tok().kind == .assign) {
                            _ = self.advance();
                            try self.parseAssignmentExpression();
                        }
                    }
                    if (self.isKw("in") or self.isKw("of")) {
                        _ = self.advance();
                        try self.parseExpression();
                    }
                } else {
                    try self.parseExpression();
                }
            }
            while (self.tok().kind == .semi) {
                _ = self.advance();
                if (self.tok().kind != .semi and self.tok().kind != .rparen) {
                    try self.parseExpression();
                }
            }
            if (self.tok().kind == .rparen) _ = self.advance();
        }
        try self.parseStatement();
        const end_off = if (self.idx > 0) self.tokens[self.idx - 1].end else self.src.len;
        self.popScope(sc, end_off);
    }

    fn parseTryStatement(self: *Parser) Allocator.Error!void {
        _ = self.advance(); // `try`
        try self.parseStatement();
        if (self.isKw("catch")) {
            const catch_start = self.advance().start;
            const sc = try self.pushScope(.block, catch_start);
            if (self.tok().kind == .lparen) {
                _ = self.advance();
                try self.parseBindingPattern(.let_kind);
                if (self.tok().kind == .rparen) _ = self.advance();
            }
            const end_off = try self.parseFunctionBody();
            self.popScope(sc, end_off);
        }
        if (self.isKw("finally")) {
            _ = self.advance();
            try self.parseStatement();
        }
    }

    fn parseSwitchStatement(self: *Parser) Allocator.Error!void {
        _ = self.advance(); // `switch`
        try self.parseParenExpr();
        if (self.tok().kind != .lbrace) return;
        const start = self.advance().start;
        const sc = try self.pushScope(.block, start);
        while (self.tok().kind != .eof and self.tok().kind != .rbrace) {
            const before = self.idx;
            try self.parseStatement();
            if (self.idx == before) _ = self.advance();
        }
        const end_off = if (self.tok().kind == .rbrace) self.advance().end else self.src.len;
        self.popScope(sc, end_off);
    }

    fn parseImportDecl(self: *Parser) Allocator.Error!void {
        _ = self.advance(); // `import`
        if (self.tok().kind == .string) {
            _ = self.advance();
            if (self.tok().kind == .semi) _ = self.advance();
            return;
        }
        while (self.tok().kind != .eof and self.tok().kind != .semi) {
            const before = self.idx;
            if (self.isKw("from")) {
                _ = self.advance();
                if (self.tok().kind == .string) _ = self.advance();
                break;
            }
            if (self.tok().kind == .op and std.mem.eql(u8, self.tok().slice(self.src), "*")) {
                _ = self.advance();
                if (self.isKw("as")) _ = self.advance();
                if (self.tok().kind == .ident) {
                    const nm = self.advance();
                    try self.addDecl(nm.slice(self.src), .let_kind, nm.start, nm.end - nm.start);
                }
            } else if (self.tok().kind == .lbrace) {
                _ = self.advance();
                while (self.tok().kind != .eof and self.tok().kind != .rbrace) {
                    const b2 = self.idx;
                    if (self.tok().kind == .ident or self.tok().kind == .string) {
                        const first = self.advance();
                        if (self.isKw("as")) {
                            _ = self.advance();
                            if (self.tok().kind == .ident) {
                                const local = self.advance();
                                try self.addDecl(local.slice(self.src), .let_kind, local.start, local.end - local.start);
                            }
                        } else if (first.kind == .ident) {
                            try self.addDecl(first.slice(self.src), .let_kind, first.start, first.end - first.start);
                        }
                    }
                    if (self.tok().kind == .comma) _ = self.advance();
                    if (self.idx == b2) _ = self.advance();
                }
                if (self.tok().kind == .rbrace) _ = self.advance();
            } else if (self.tok().kind == .ident) {
                const nm = self.advance();
                try self.addDecl(nm.slice(self.src), .let_kind, nm.start, nm.end - nm.start);
            } else if (self.tok().kind == .comma) {
                _ = self.advance();
            } else {
                break;
            }
            if (self.idx == before) _ = self.advance();
        }
        if (self.tok().kind == .semi) _ = self.advance();
    }

    fn parseExportDecl(self: *Parser) Allocator.Error!void {
        _ = self.advance(); // `export`
        if (self.isKw("default")) {
            _ = self.advance();
            if (self.isKw("function")) {
                try self.parseFunctionDeclOrExpr(self.tok().start, true);
            } else if (self.isKw("async") and !self.peek(1).line_before and self.peek(1).is(self.src, "function")) {
                const start = self.advance().start;
                try self.parseFunctionDeclOrExpr(start, true);
            } else if (self.isKw("class")) {
                try self.parseClassDeclOrExpr(self.tok().start, true);
            } else {
                try self.parseAssignmentExpression();
                if (self.tok().kind == .semi) _ = self.advance();
            }
            return;
        }
        if (self.tok().kind == .op and std.mem.eql(u8, self.tok().slice(self.src), "*")) {
            _ = self.advance();
            if (self.isKw("as")) {
                _ = self.advance();
                if (self.tok().kind == .ident or self.tok().kind == .string) _ = self.advance();
            }
            if (self.isKw("from")) {
                _ = self.advance();
                if (self.tok().kind == .string) _ = self.advance();
            }
            if (self.tok().kind == .semi) _ = self.advance();
            return;
        }
        if (self.tok().kind == .lbrace) {
            // Check whether `from "..."` follows `}`; only local exports create uses.
            var scan = self.idx + 1;
            while (scan < self.tokens.len and self.tokens[scan].kind != .eof and self.tokens[scan].kind != .rbrace) scan += 1;
            const has_from = scan + 1 < self.tokens.len and self.tokens[scan + 1].is(self.src, "from");
            _ = self.advance(); // `{`
            while (self.tok().kind != .eof and self.tok().kind != .rbrace) {
                const b2 = self.idx;
                if (self.tok().kind == .ident or self.tok().kind == .string) {
                    const local = self.advance();
                    if (!has_from and local.kind == .ident) {
                        try self.addUse(local.slice(self.src), local.start, local.end - local.start, false);
                    }
                    if (self.isKw("as")) {
                        _ = self.advance();
                        if (self.tok().kind == .ident or self.tok().kind == .string) _ = self.advance();
                    }
                }
                if (self.tok().kind == .comma) _ = self.advance();
                if (self.idx == b2) _ = self.advance();
            }
            if (self.tok().kind == .rbrace) _ = self.advance();
            if (self.isKw("from")) {
                _ = self.advance();
                if (self.tok().kind == .string) _ = self.advance();
            }
            if (self.tok().kind == .semi) _ = self.advance();
            return;
        }
        try self.parseStatement();
    }

    fn parseParenExpr(self: *Parser) Allocator.Error!void {
        if (self.tok().kind != .lparen) return;
        _ = self.advance();
        if (self.tok().kind != .rparen) try self.parseExpression();
        if (self.tok().kind == .rparen) _ = self.advance();
    }

    fn parseExpression(self: *Parser) Allocator.Error!void {
        try self.parseAssignmentExpression();
        while (self.tok().kind == .comma) {
            _ = self.advance();
            try self.parseAssignmentExpression();
        }
    }

    fn parseAssignmentExpression(self: *Parser) Allocator.Error!void {
        if (self.depth >= max_parse_depth) {
            _ = self.advance();
            return;
        }
        self.depth += 1;
        defer self.depth -= 1;

        while (true) {
            try self.parseUnaryAndPostfix();
            const k = self.tok().kind;
            if (k == .question) {
                _ = self.advance();
                try self.parseAssignmentExpression();
                if (self.tok().kind == .colon) {
                    _ = self.advance();
                    try self.parseAssignmentExpression();
                }
                return;
            }
            if (k == .assign or k == .assign_op or k == .op) {
                _ = self.advance();
                continue;
            }
            if (k == .ident and (self.isKw("in") or self.isKw("instanceof") or self.isKw("of"))) {
                _ = self.advance();
                continue;
            }
            break;
        }
    }

    fn parseUnaryAndPostfix(self: *Parser) Allocator.Error!void {
        // Prefix unary operators.
        while (true) {
            const t = self.tok();
            if (t.kind == .op or t.kind == .inc_dec or t.kind == .ellipsis) {
                _ = self.advance();
                continue;
            }
            if (t.kind == .ident) {
                const w = t.slice(self.src);
                if (std.mem.eql(u8, w, "typeof") or std.mem.eql(u8, w, "void") or
                    std.mem.eql(u8, w, "delete") or std.mem.eql(u8, w, "new"))
                {
                    // `new.target`: keep `new` for postfix `.target` skipping.
                    if (std.mem.eql(u8, w, "new") and self.peek(1).kind == .dot) break;
                    _ = self.advance();
                    continue;
                }
                if ((std.mem.eql(u8, w, "await") or std.mem.eql(u8, w, "yield")) and self.canStartExpression(self.peek(1))) {
                    _ = self.advance();
                    if (std.mem.eql(u8, w, "yield") and self.tok().kind == .op and std.mem.eql(u8, self.tok().slice(self.src), "*")) {
                        _ = self.advance();
                    }
                    continue;
                }
            }
            break;
        }
        try self.parsePrimaryAndPostfix();
    }

    fn canStartExpression(self: *const Parser, t: Token) bool {
        return switch (t.kind) {
            .ident, .number, .string, .regex, .template_no_sub, .template_head, .lparen, .lbracket, .lbrace, .inc_dec => true,
            .op => blk: {
                const s = t.slice(self.src);
                break :blk std.mem.eql(u8, s, "+") or std.mem.eql(u8, s, "-") or
                    std.mem.eql(u8, s, "!") or std.mem.eql(u8, s, "~");
            },
            else => false,
        };
    }

    fn isParenArrow(self: *const Parser, lparen_idx: usize) bool {
        var i = lparen_idx + 1;
        var depth: usize = 1;
        while (i < self.tokens.len and depth > 0) : (i += 1) {
            switch (self.tokens[i].kind) {
                .lparen => depth += 1,
                .rparen => depth -= 1,
                .eof => return false,
                else => {},
            }
        }
        return i < self.tokens.len and self.tokens[i].kind == .arrow and !self.tokens[i].line_before;
    }

    fn parseArrowFunction(self: *Parser, start_offset: usize, has_parens: bool) Allocator.Error!void {
        const sc = try self.pushScope(.arrow_function, start_offset);
        if (has_parens) {
            try self.parseParamList();
        } else if (self.tok().kind == .ident) {
            const p = self.advance();
            try self.addDecl(p.slice(self.src), .let_kind, p.start, p.end - p.start);
        }
        if (self.tok().kind == .arrow) _ = self.advance();
        var end_off: usize = self.src.len;
        if (self.tok().kind == .lbrace) {
            end_off = try self.parseFunctionBody();
        } else {
            try self.parseAssignmentExpression();
            end_off = if (self.idx > 0) self.tokens[self.idx - 1].end else self.src.len;
        }
        self.popScope(sc, end_off);
    }

    fn parsePrimaryAndPostfix(self: *Parser) Allocator.Error!void {
        const t = self.tok();
        switch (t.kind) {
            .number, .string, .regex, .template_no_sub, .private_ident => {
                _ = self.advance();
            },
            .template_head => {
                try self.parseTemplateLiteral();
            },
            .lparen => {
                if (self.isParenArrow(self.idx)) {
                    try self.parseArrowFunction(t.start, true);
                    return;
                }
                _ = self.advance();
                if (self.tok().kind != .rparen) try self.parseExpression();
                if (self.tok().kind == .rparen) _ = self.advance();
            },
            .lbracket => {
                _ = self.advance();
                while (self.tok().kind != .eof and self.tok().kind != .rbracket) {
                    const before = self.idx;
                    if (self.tok().kind == .comma) {
                        _ = self.advance();
                        continue;
                    }
                    try self.parseAssignmentExpression();
                    if (self.tok().kind == .comma) _ = self.advance();
                    if (self.idx == before) _ = self.advance();
                }
                if (self.tok().kind == .rbracket) _ = self.advance();
            },
            .lbrace => {
                try self.parseObjectLiteral();
            },
            .ident => {
                const word = t.slice(self.src);
                // Arrow function: `x => ...`
                if (self.peek(1).kind == .arrow and !self.peek(1).line_before) {
                    try self.parseArrowFunction(t.start, false);
                    return;
                }
                // Async arrow or async function expression.
                if (std.mem.eql(u8, word, "async") and !self.peek(1).line_before) {
                    if (self.peek(1).is(self.src, "function")) {
                        _ = self.advance();
                        try self.parseFunctionDeclOrExpr(t.start, false);
                        return;
                    }
                    if (self.peek(1).kind == .ident and self.peek(2).kind == .arrow and !self.peek(2).line_before) {
                        _ = self.advance();
                        try self.parseArrowFunction(t.start, false);
                        return;
                    }
                    if (self.peek(1).kind == .lparen and self.isParenArrow(self.idx + 1)) {
                        _ = self.advance();
                        try self.parseArrowFunction(t.start, true);
                        return;
                    }
                }
                if (std.mem.eql(u8, word, "function")) {
                    try self.parseFunctionDeclOrExpr(t.start, false);
                } else if (std.mem.eql(u8, word, "class")) {
                    try self.parseClassDeclOrExpr(t.start, false);
                } else {
                    _ = self.advance();
                    if (!isNonVariableKeyword(word)) {
                        try self.addUse(word, t.start, t.end - t.start, false);
                    }
                }
            },
            else => return,
        }

        // Postfix chain: `.prop`, `?.prop`, `?.[expr]`, `?.(args)`, `[expr]`, `(args)`, tagged template, `++`/`--`.
        while (true) {
            const p = self.tok();
            switch (p.kind) {
                .dot => {
                    _ = self.advance();
                    if (self.tok().kind == .ident or self.tok().kind == .private_ident) _ = self.advance();
                },
                .qdot => {
                    _ = self.advance();
                    if (self.tok().kind == .ident or self.tok().kind == .private_ident) {
                        _ = self.advance();
                    } else if (self.tok().kind == .lbracket) {
                        _ = self.advance();
                        try self.parseExpression();
                        if (self.tok().kind == .rbracket) _ = self.advance();
                    } else if (self.tok().kind == .lparen) {
                        try self.parseCallArgs();
                    }
                },
                .lbracket => {
                    _ = self.advance();
                    if (self.tok().kind != .rbracket) try self.parseExpression();
                    if (self.tok().kind == .rbracket) _ = self.advance();
                },
                .lparen => {
                    try self.parseCallArgs();
                },
                .template_no_sub => {
                    _ = self.advance();
                },
                .template_head => {
                    try self.parseTemplateLiteral();
                },
                .inc_dec => {
                    if (p.line_before) break;
                    _ = self.advance();
                },
                else => break,
            }
        }
    }

    fn parseCallArgs(self: *Parser) Allocator.Error!void {
        _ = self.advance(); // `(`
        while (self.tok().kind != .eof and self.tok().kind != .rparen) {
            const before = self.idx;
            try self.parseAssignmentExpression();
            if (self.tok().kind == .comma) _ = self.advance();
            if (self.idx == before) _ = self.advance();
        }
        if (self.tok().kind == .rparen) _ = self.advance();
    }

    fn parseTemplateLiteral(self: *Parser) Allocator.Error!void {
        _ = self.advance(); // `.template_head`
        while (self.tok().kind != .eof) {
            const before = self.idx;
            if (self.tok().kind != .template_middle and self.tok().kind != .template_tail) {
                try self.parseExpression();
            }
            if (self.tok().kind == .template_middle) {
                _ = self.advance();
                continue;
            }
            if (self.tok().kind == .template_tail) {
                _ = self.advance();
                break;
            }
            if (self.idx == before) break;
        }
    }

    fn parseObjectLiteral(self: *Parser) Allocator.Error!void {
        _ = self.advance(); // `{`
        while (self.tok().kind != .eof and self.tok().kind != .rbrace) {
            const before = self.idx;
            if (self.tok().kind == .ellipsis) {
                _ = self.advance();
                try self.parseAssignmentExpression();
            } else {
                const prop_start = self.tok().start;
                // Method modifiers: async / get / set / * (only when followed by another property name).
                while (self.tok().kind != .eof) {
                    const m = self.tok();
                    const nxt = self.peek(1);
                    if ((m.is(self.src, "async") or m.is(self.src, "get") or m.is(self.src, "set")) and
                        (nxt.kind == .ident or nxt.kind == .string or nxt.kind == .number or nxt.kind == .lbracket or
                            (nxt.kind == .op and std.mem.eql(u8, nxt.slice(self.src), "*"))))
                    {
                        _ = self.advance();
                    } else if (m.kind == .op and std.mem.eql(u8, m.slice(self.src), "*")) {
                        _ = self.advance();
                    } else break;
                }

                if (self.tok().kind == .lbracket) {
                    // Computed property name `[expr]: val` or `[expr](args) {}`.
                    _ = self.advance();
                    try self.parseExpression();
                    if (self.tok().kind == .rbracket) _ = self.advance();
                    if (self.tok().kind == .lparen) {
                        const ms = try self.pushScope(.function, prop_start);
                        try self.addDecl("this", .fixed, prop_start, 0);
                        try self.addDecl("arguments", .fixed, prop_start, 0);
                        try self.parseParamList();
                        const end_off = try self.parseFunctionBody();
                        self.popScope(ms, end_off);
                    } else if (self.tok().kind == .colon) {
                        _ = self.advance();
                        try self.parseAssignmentExpression();
                    }
                } else if (self.tok().kind == .ident or self.tok().kind == .string or self.tok().kind == .number) {
                    const key = self.advance();
                    if (self.tok().kind == .colon) {
                        // Non-shorthand property `{ key: value }`: key is NOT a variable use.
                        _ = self.advance();
                        try self.parseAssignmentExpression();
                    } else if (self.tok().kind == .lparen) {
                        // Shorthand method `{ foo(a) { ... } }`.
                        const ms = try self.pushScope(.function, prop_start);
                        try self.addDecl("this", .fixed, prop_start, 0);
                        try self.addDecl("arguments", .fixed, prop_start, 0);
                        try self.parseParamList();
                        const end_off = try self.parseFunctionBody();
                        self.popScope(ms, end_off);
                    } else {
                        // Shorthand property `{ ident }` (or cover-initialized `{ ident = def }`).
                        if (key.kind == .ident) {
                            const w = key.slice(self.src);
                            if (!isNonVariableKeyword(w)) {
                                try self.addUse(w, key.start, key.end - key.start, true);
                            }
                        }
                        if (self.tok().kind == .assign) {
                            _ = self.advance();
                            try self.parseAssignmentExpression();
                        }
                    }
                }
            }
            if (self.tok().kind == .comma) _ = self.advance();
            if (self.idx == before) _ = self.advance();
        }
        if (self.tok().kind == .rbrace) _ = self.advance();
    }
};

fn isNonVariableKeyword(word: []const u8) bool {
    const kws = [_][]const u8{
        "true",       "false",  "null",    "this",     "super",
        "void",       "typeof", "delete",  "new",      "in",
        "instanceof", "return", "throw",   "break",    "continue",
        "if",         "else",   "for",     "while",    "do",
        "switch",     "case",   "default", "try",      "catch",
        "finally",    "var",    "const",   "function", "class",
        "extends",    "import", "export",  "debugger", "with",
    };
    for (kws) |kw| if (std.mem.eql(u8, word, kw)) return true;
    return false;
}

pub fn analyzeScopes(arena: Allocator, src: []const u8) Allocator.Error!ScopeTree {
    const tokens = try tokenize(arena, src);
    var parser: Parser = .{
        .arena = arena,
        .src = src,
        .tokens = tokens,
    };
    try parser.parseProgram();
    return parser.tree;
}

// ---------------------------------------------------------------------------
// NamesResolver (NamesResolver.ts): allVariablesAtPosition + resolveSourceName
// ---------------------------------------------------------------------------

pub const ScopeMapping = struct {
    /// Maps authoredName -> generatedName for this scope.
    bindings: std.StringArrayHashMapUnmanaged([]const u8) = .empty,
    /// Every bound generated name in this scope (used for shadow detection).
    generated_names: [][]const u8 = &.{},
};

const Punctuation = enum { none, dot, comma, semicolon, equals };

const ExtractedIdentifier = struct {
    name: []const u8,
    punctuation: Punctuation,
};

/// Reproduces `NamesResolver.ts` `identifierAndPunctuationRegExp`:
/// `/^\s*([A-Za-z_$][A-Za-z_$0-9]*)\s*([.;,=]?)\s*$/`
fn extractIdentifier(token: []const u8) ?ExtractedIdentifier {
    var i: usize = 0;
    while (i < token.len and std.ascii.isWhitespace(token[i])) i += 1;
    if (i >= token.len) return null;
    const c0 = token[i];
    if (!((c0 >= 'a' and c0 <= 'z') or (c0 >= 'A' and c0 <= 'Z') or c0 == '_' or c0 == '$')) return null;
    const name_start = i;
    i += 1;
    while (i < token.len) {
        const ch = token[i];
        if ((ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or (ch >= '0' and ch <= '9') or ch == '_' or ch == '$') {
            i += 1;
        } else break;
    }
    const name = token[name_start..i];
    while (i < token.len and std.ascii.isWhitespace(token[i])) i += 1;
    var punct: Punctuation = .none;
    if (i < token.len) {
        punct = switch (token[i]) {
            '.' => .dot,
            ',' => .comma,
            ';' => .semicolon,
            '=' => .equals,
            else => return null,
        };
        i += 1;
        while (i < token.len and std.ascii.isWhitespace(token[i])) i += 1;
        if (i < token.len) return null;
    }
    return .{ .name = name, .punctuation = punct };
}

/// Reproduces `NamesResolver.ts` `resolveSourceName`: falls back to comparing
/// compiled and original source text slices when `SourceMapEntry.name` is absent.
fn resolveSourceName(
    arena: Allocator,
    compiled_index: *const LineIndex,
    source_indexes: *std.StringHashMapUnmanaged(LineIndex),
    sm: *const SourceMap,
    generated_name: []const u8,
    pos: Position,
) Allocator.Error!?[]const u8 {
    const ranges = sm.findEntryRanges(pos.line, pos.column) orelse return null;
    const compiled_token = compiled_index.extractRange(ranges.range);
    const parsed_compiled = extractIdentifier(compiled_token) orelse return null;
    if (!std.mem.eql(u8, parsed_compiled.name, generated_name)) return null;

    const src_index = if (source_indexes.getPtr(ranges.source_url)) |existing|
        existing
    else blk: {
        const content = sm.embeddedContentByUrl(ranges.source_url) orelse return null;
        const idx = try LineIndex.init(arena, content);
        try source_indexes.put(arena, ranges.source_url, idx);
        break :blk source_indexes.getPtr(ranges.source_url).?;
    };
    const source_token = src_index.extractRange(ranges.source_range);
    const parsed_source = extractIdentifier(source_token) orelse return null;
    if (parsed_compiled.punctuation == parsed_source.punctuation) return parsed_source.name;
    if (parsed_compiled.punctuation == .comma and parsed_source.punctuation == .semicolon) return parsed_source.name;
    return null;
}

/// Reproduces `NamesResolver.allVariablesAtPosition`: returns scope mappings
/// ordered from innermost enclosing scope to outermost (global).
pub fn resolveVariablesAtPosition(
    arena: Allocator,
    script_source: []const u8,
    sm: *const SourceMap,
    rel_line: i64,
    rel_col: i64,
) Allocator.Error![]ScopeMapping {
    if (script_source.len == 0) return &.{};
    const line_index = try LineIndex.init(arena, script_source);
    const tree = try analyzeScopes(arena, script_source);
    const loc_offset = line_index.offsetFromPosition(rel_line, rel_col);
    const chain = try tree.findScopeChain(arena, loc_offset);
    if (chain.len == 0) return &.{};

    var source_indexes: std.StringHashMapUnmanaged(LineIndex) = .empty;
    var out: std.ArrayList(ScopeMapping) = .empty;

    var ci: usize = chain.len;
    while (ci > 0) {
        ci -= 1;
        const scope = &tree.scopes.items[chain[ci]];
        var mapping: ScopeMapping = .{};
        var gen_names: std.ArrayList([]const u8) = .empty;

        for (scope.variables.items) |v| {
            if (v.kind == .none) continue;
            if (v.kind == .fixed and v.uses.items.len <= 1) continue;
            try gen_names.append(arena, v.name);

            // Pass 1: SourceMap V3 `names` entry at any occurrence of this variable.
            var resolved_name: ?[]const u8 = null;
            for (v.uses.items) |u| {
                const pos = line_index.positionFromOffset(u.offset);
                if (sm.findEntry(pos.line, pos.column)) |entry| {
                    if (entry.name) |nm| {
                        resolved_name = nm;
                        break;
                    }
                }
            }
            // Pass 2: `findEntryRanges` + `sourcesContent` identifier fallback.
            if (resolved_name == null) {
                for (v.uses.items) |u| {
                    const pos = line_index.positionFromOffset(u.offset);
                    if (try resolveSourceName(arena, &line_index, &source_indexes, sm, v.name, pos)) |nm| {
                        resolved_name = nm;
                        break;
                    }
                }
            }
            if (resolved_name) |authored| {
                if (!std.mem.eql(u8, authored, "this") and !mapping.bindings.contains(authored)) {
                    try mapping.bindings.put(arena, authored, v.name);
                }
            }
        }
        mapping.generated_names = gen_names.items;
        try out.append(arena, mapping);
    }
    return out.items;
}

// ---------------------------------------------------------------------------
// Expression Substituter (Substitute.ts)
// ---------------------------------------------------------------------------

/// Reproduces `Substitute.ts` `computeSubstitutionMap`: walks scopes from
/// innermost to outermost, mapping `authored -> generated` unless an inner
/// scope declared the same generated identifier (in which case `null` marks
/// the authored name as shadowed and un-substitutable).
pub fn computeSubstitutionMap(
    arena: Allocator,
    scopes: []const ScopeMapping,
) Allocator.Error!std.StringHashMapUnmanaged(?[]const u8) {
    var result: std.StringHashMapUnmanaged(?[]const u8) = .empty;
    var shadowed: std.StringHashMapUnmanaged(void) = .empty;

    for (scopes) |scope| {
        var it = scope.bindings.iterator();
        while (it.next()) |entry| {
            const authored = entry.key_ptr.*;
            const generated = entry.value_ptr.*;
            if (!result.contains(authored)) {
                if (shadowed.contains(generated)) {
                    try result.put(arena, authored, null);
                } else {
                    try result.put(arena, authored, generated);
                }
            }
        }
        for (scope.generated_names) |gen| {
            try shadowed.put(arena, gen, {});
        }
    }
    return result;
}

const Replacement = struct {
    start: usize,
    end: usize,
    authored: []const u8,
    generated: []const u8,
    is_shorthand_prop: bool,
};

/// Reproduces `Substitute.ts` `substituteExpression` for a logpoint argument
/// list (parsed as `console.log(<expression>)`). Free identifier references
/// are rewritten to their minified names; object literal shorthands `{x}`
/// expand to `{x: gen}`; shadowed names fall back to the original expression,
/// matching `Breakpoint.backendCondition`'s `.catch(() => condition)`.
pub fn substituteExpression(
    arena: Allocator,
    expression: []const u8,
    scopes: []const ScopeMapping,
) Allocator.Error![]const u8 {
    if (expression.len == 0 or scopes.len == 0) return expression;
    const rename_map = try computeSubstitutionMap(arena, scopes);
    if (rename_map.count() == 0) return expression;

    const prefix = "console.log(";
    const wrapped = try std.fmt.allocPrint(arena, "{s}{s})", .{ prefix, expression });
    const expr_start = prefix.len;
    const expr_end = prefix.len + expression.len;

    const tree = try analyzeScopes(arena, wrapped);
    if (tree.scopes.items.len == 0) return expression;

    var edits: std.ArrayList(Replacement) = .empty;
    for (tree.scopes.items[0].variables.items) |v| {
        if (v.kind != .none) continue;
        const mapped_opt = rename_map.get(v.name) orelse continue;
        if (mapped_opt) |generated| {
            if (std.mem.eql(u8, v.name, generated)) continue;
            for (v.uses.items) |u| {
                if (u.offset < expr_start or u.offset + u.len > expr_end) continue;
                try edits.append(arena, .{
                    .start = u.offset - expr_start,
                    .end = u.offset + u.len - expr_start,
                    .authored = v.name,
                    .generated = generated,
                    .is_shorthand_prop = u.is_shorthand_prop,
                });
            }
        } else {
            // Shadowed generated name: if the expression actually references
            // this free variable, abort substitution (fall back to `expression`).
            for (v.uses.items) |u| {
                if (u.offset >= expr_start and u.offset + u.len <= expr_end) {
                    return expression;
                }
            }
        }
    }
    if (edits.items.len == 0) return expression;

    std.sort.block(Replacement, edits.items, {}, struct {
        fn lessThan(_: void, a: Replacement, b: Replacement) bool {
            return a.start < b.start;
        }
    }.lessThan);

    var out: std.ArrayList(u8) = .empty;
    var cursor: usize = 0;
    for (edits.items) |edit| {
        if (edit.start < cursor) continue;
        try out.appendSlice(arena, expression[cursor..edit.start]);
        if (edit.is_shorthand_prop) {
            try out.appendSlice(arena, edit.authored);
            try out.appendSlice(arena, ": ");
            try out.appendSlice(arena, edit.generated);
        } else {
            try out.appendSlice(arena, edit.generated);
        }
        cursor = edit.end;
    }
    try out.appendSlice(arena, expression[cursor..]);
    return out.items;
}

/// Convenience end-to-end helper: resolves variables at `(rel_line, rel_col)`
/// in `script_source` via `sm` and substitutes `expression`.
pub fn substituteAtLocation(
    arena: Allocator,
    script_source: []const u8,
    sm: *const SourceMap,
    rel_line: i64,
    rel_col: i64,
    expression: []const u8,
) Allocator.Error![]const u8 {
    const scopes = try resolveVariablesAtPosition(arena, script_source, sm, rel_line, rel_col);
    return substituteExpression(arena, expression, scopes);
}

// ---------------------------------------------------------------------------
// Unit tests
// ---------------------------------------------------------------------------

test "js_scopes: basic V3 names, shorthand expansion, templates, arrow shadowing" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();

    const js = "function checkout(a,b){const c=a-b;return c}window.minCheckout=checkout;";
    const sm = try source_map.parse(t.allocator, "http://h/lp-min/min.js", "http://h/lp-min/min.js.map",
        \\{"version":3,"sources":["src/min.ts"],"sourcesContent":["export function checkout(cartTotal: number, discount: number) {\n  const finalAmount = cartTotal - discount;\n  return finalAmount;\n}\n"],"names":["cartTotal","discount","finalAmount"],"mappings":"AAAA,kBAAyBA,EAAmBC,GAC1C,MAAMC,EAAcF,EAAYC,EAChC,OAAOC"}
    );
    defer sm.deinit();

    const out = try substituteAtLocation(
        a,
        js,
        sm,
        0,
        35,
        "'amt', finalAmount, cartTotal, discount, {finalAmount, cartTotal: cartTotal + 1}, `t=${finalAmount}`, [1].map(finalAmount => finalAmount + discount)[0]",
    );
    try t.expectEqualStrings(
        "'amt', c, a, b, {finalAmount: c, cartTotal: a + 1}, `t=${c}`, [1].map(finalAmount => finalAmount + b)[0]",
        out,
    );
}

test "js_scopes: closures and inner scope shadowing" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();

    const js = "function makeAdder(e){const t=10;return function(n){const r=n*2;const o=e+r;return o}}window.minClosure=makeAdder;";
    const sm = try source_map.parse(t.allocator, "http://h/lp-min/closure.js", "http://h/lp-min/closure.js.map",
        \\{"version":3,"sources":["src/closure.ts"],"sourcesContent":["export function makeAdder(outerBase: number) {\n  const factor = 10;\n  return function inner(step: number) {\n    const factor = step * 2;\n    const result = outerBase + factor;\n    return result;\n  };\n}\n"],"names":["outerBase","factor","step","result"],"mappings":"AAAA,mBAA0BA,GACxB,MAAMC,KACN,gBAAsBC,GACpB,MAAMD,EAASC,IACf,MAAMC,EAASH,EAAYC,EAC3B,OAAOE"}
    );
    defer sm.deinit();

    const out = try substituteAtLocation(a, js, sm, 0, 76, "'cls', outerBase, factor, step, result");
    try t.expectEqualStrings("'cls', e, r, n, o", out);
}

test "js_scopes: destructuring, for-let, try-catch, member property protection" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();

    const js = "function inspectItem(t){const{price:e,label:n}=t;let r=0;for(let o=0;o<2;o++){r+=e}try{throw new Error(n)}catch(i){return r+\":\"+i.message}}window.minSyntax=inspectItem;";
    const sm = try source_map.parse(t.allocator, "http://h/lp-min/syntax.js", "http://h/lp-min/syntax.js.map",
        \\{"version":3,"sources":["src/syntax.ts"],"sourcesContent":["export function inspectItem(item: { price: number; label: string }) {\n  const { price, label } = item;\n  let total = 0;\n  for (let idx = 0; idx < 2; idx++) {\n    total += price;\n  }\n  try {\n    throw new Error(label);\n  } catch (err) {\n    return total + ':' + err.message;\n  }\n}\n"],"names":["item","price","label","total","idx","err"],"mappings":"AAAA,qBAA4BA,GAC1B,YAAQC,QAAOC,GAAUF,EACzB,IAAIG,IACJ,QAASC,aACPD,GAASF,EAEX,oBACkBC,GAChB,MAAOG,GACP,OAAOF,MAAcE"}
    );
    defer sm.deinit();

    const out = try substituteAtLocation(a, js, sm, 0, 115, "'syn', item.price, price, label, total, err.message");
    try t.expectEqualStrings("'syn', t.price, e, n, r, i.message", out);
}

test "js_scopes: names-free findEntryRanges fallback via sourcesContent" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();

    const js = "function calcTax(x){const y=x*2;return y}window.minNoNames=calcTax;";
    const sm = try source_map.parse(t.allocator, "http://h/lp-min/nonames.js", "http://h/lp-min/nonames.js.map",
        \\{"version":3,"sources":["src/nonames.ts"],"sourcesContent":["export function calcTax(subtotal: number) {\n  const tax = subtotal * 2;\n  return tax;\n}\n"],"names":[],"mappings":"AAAA,oBACE,MAAM,CAAG,CAAG,CAAQ,GACpB,OAAO,CAAG"}
    );
    defer sm.deinit();

    const out = try substituteAtLocation(a, js, sm, 0, 32, "'nn', subtotal, tax");
    try t.expectEqualStrings("'nn', x, y", out);
}

test "js_scopes: generated-name collision shadowing and regex/nested-template/malformed resilience" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();

    // Inner scope binds `e` -> `innerVal`, outer scope bound `e` -> `outerVal`.
    // Evaluating `outerVal` must abort substitution (shadowed generated name `e`),
    // while evaluating `innerVal` succeeds (`e`).
    var inner_bindings: std.StringArrayHashMapUnmanaged([]const u8) = .empty;
    try inner_bindings.put(a, "innerVal", "e");
    const inner_gen = try a.dupe([]const u8, &.{"e"});

    var outer_bindings: std.StringArrayHashMapUnmanaged([]const u8) = .empty;
    try outer_bindings.put(a, "outerVal", "e");
    try outer_bindings.put(a, "safeOuter", "t");
    const outer_gen = try a.dupe([]const u8, &.{ "e", "t" });

    const scopes = [_]ScopeMapping{
        .{ .bindings = inner_bindings, .generated_names = inner_gen },
        .{ .bindings = outer_bindings, .generated_names = outer_gen },
    };

    try t.expectEqualStrings("e + t", try substituteExpression(a, "innerVal + safeOuter", &scopes));
    // Shadowed outerVal -> fallback to original expression.
    try t.expectEqualStrings("outerVal + innerVal", try substituteExpression(a, "outerVal + innerVal", &scopes));

    // Regex literal, nested templates, optional chaining, computed keys, var hoisting.
    try t.expectEqualStrings(
        "/innerVal/g.test(`a ${`b ${e}`} ${t?.innerVal}`), {[e]: t}",
        try substituteExpression(a, "/innerVal/g.test(`a ${`b ${innerVal}`} ${safeOuter?.innerVal}`), {[innerVal]: safeOuter}", &scopes),
    );

    // Malformed JS never crashes or loops infinitely.
    _ = try analyzeScopes(a, "function( {{{ /unterminated `unterminated ${ 1 + ");
}

test "js_scopes: var hoisting, class methods, destructured arrow params, UTF-16 LineIndex" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();

    // var inside block hoists to function scope; let inside block does not.
    const hoisted_js = "function f(){if(1){var x=1;let y=2}return x}";
    const tree = try analyzeScopes(a, hoisted_js);
    const chain = try tree.findScopeChain(a, std.mem.indexOf(u8, hoisted_js, "return").?);
    const fn_scope = &tree.scopes.items[chain[chain.len - 1]];
    var saw_x = false;
    var saw_y = false;
    for (fn_scope.variables.items) |v| {
        if (std.mem.eql(u8, v.name, "x")) {
            saw_x = true;
            try t.expectEqual(@as(usize, 2), v.uses.items.len);
        }
        if (std.mem.eql(u8, v.name, "y")) saw_y = true;
    }
    try t.expect(saw_x);
    try t.expect(!saw_y);

    // Destructured arrow parameter shadows outer binding in substituteExpression.
    var bindings: std.StringArrayHashMapUnmanaged([]const u8) = .empty;
    try bindings.put(a, "price", "p");
    try bindings.put(a, "tax", "t");
    const scopes = [_]ScopeMapping{.{ .bindings = bindings, .generated_names = try a.dupe([]const u8, &.{ "p", "t" }) }};
    try t.expectEqualStrings(
        "items.map(({price}) => price + t)",
        try substituteExpression(a, "items.map(({price}) => price + tax)", &scopes),
    );

    // UTF-16 LineIndex with supplementary emoji (4 UTF-8 bytes = 2 UTF-16 code units).
    const utf_src = "const s = '😀'; const x = 1;\nreturn x;";
    const idx = try LineIndex.init(a, utf_src);
    const x_off = std.mem.indexOf(u8, utf_src, "x = 1").?;
    const pos = idx.positionFromOffset(x_off);
    try t.expectEqual(@as(i64, 0), pos.line);
    try t.expectEqual(@as(i64, 22), pos.column); // 11 + 2 (emoji) + 9 = 22 UTF-16 units
    try t.expectEqual(x_off, idx.offsetFromPosition(pos.line, pos.column));
}
