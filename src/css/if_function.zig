//! CSS Values 5 §8.3 if() argument grammar and §3.2 boolean expressions.
//!
//! This module parses borrowed CSS text. It does not perform substitutions,
//! own a cascade, or fetch property values. The arbitrary-substitution engine
//! substitutes visited conditions, evaluates them with its host, and substitutes
//! only the selected branch. Query leaves keep their own grammar and context.
//!
//! Design reference (not copied): Blink CSSIfParser::ConsumeIfCondition and
//! ConsumeFunction, and StyleCascade::EvalIfCondition / ResolveIfInto.
//! https://drafts.csswg.org/css-values-5/#if-notation

const std = @import("std");
const tokens = @import("tokenizer.zig");
const rules = @import("rules.zig");
const properties = @import("properties.zig");
const Allocator = std.mem.Allocator;
const Tokenizer = tokens.Tokenizer;
const TokenType = tokens.TokenType;

/// A branch's borrowed source ranges. Curly-braced values retain their braces.
pub const Branch = struct {
    condition: []const u8,
    value: []const u8,
};

/// Owns the branch array, but not the source text. Keep the input alive.
pub const Arguments = struct {
    allocator: Allocator,
    branches: []Branch,

    /// Release the array returned by parseArguments().
    pub fn deinit(self: *Arguments) void {
        self.allocator.free(self.branches);
        self.* = undefined;
    }
};

/// The query types permitted by <if-test>. Their host evaluates their bodies.
pub const QueryKind = enum { style, media, supports };

/// Appendix B: unknown remains distinct until the complete condition is used.
pub const Truth = enum {
    false,
    true,
    unknown,

    /// A top-level unknown condition does not select its branch.
    pub fn matches(self: Truth) bool {
        return self == .true;
    }

    fn negate(self: Truth) Truth {
        return switch (self) {
            .false => .true,
            .true => .false,
            .unknown => .unknown,
        };
    }
};

const Query = struct { kind: QueryKind, text: []const u8 };
fn Expression(comptime Leaf: type) type {
    return union(enum) {
        const Self = @This();
        literal: Truth,
        leaf: Leaf,
        not: *const Self,
        all: []const *const Self,
        any: []const *const Self,

        fn evaluate(self: *const Self, context: anytype) anyerror!Truth {
            return switch (self.*) {
                .literal => |value| value,
                .leaf => |leaf| if (Leaf == Query)
                    try context.evaluate(leaf.kind, leaf.text)
                else if (isQueryableStyleFeature(leaf))
                    try context.evaluate(leaf)
                else
                    .unknown,
                .not => |operand| (try operand.evaluate(context)).negate(),
                .all => |operands| blk: {
                    var result: Truth = .true;
                    for (operands) |operand| {
                        const value = try operand.evaluate(context);
                        if (value == .false) break :blk .false;
                        if (value == .unknown) result = .unknown;
                    }
                    break :blk result;
                },
                .any => |operands| blk: {
                    var result: Truth = .false;
                    for (operands) |operand| {
                        const value = try operand.evaluate(context);
                        if (value == .true) break :blk .true;
                        if (value == .unknown) result = .unknown;
                    }
                    break :blk result;
                },
            };
        }
    };
}

fn ParsedCondition(comptime Leaf: type) type {
    return struct {
        arena: std.heap.ArenaAllocator,
        expression: *const Expression(Leaf),

        /// Release the parsed expression and all its children.
        pub fn deinit(self: *@This()) void {
            self.arena.deinit();
            self.* = undefined;
        }

        /// Evaluate with a caller-owned context. Query errors propagate; the
        /// caller retains substitution, cycle guards and dependency taints.
        pub fn evaluate(self: *const @This(), context: anytype) anyerror!Truth {
            return self.expression.evaluate(context);
        }
    };
}

/// An owned if-condition tree over borrowed query text. The context implements
/// `pub fn evaluate(self, QueryKind, []const u8) !Truth`. Keep the input alive.
pub const Condition = ParsedCondition(Query);

/// CSS Conditional 5 §5.4 range comparisons. Chained operators use the shipping
/// acceptance matrix below, including its equality and mixed-direction cases.
pub const Comparison = enum { equal, less, less_equal, greater, greater_equal };

/// A style-feature leaf. Names are decoded; values and operands borrow input.
/// The host computes current/initial/query values using the existing cascade.
pub const StyleFeature = union(enum) {
    boolean: []const u8,
    plain: struct { name: []const u8, value: []const u8 },
    range: struct { operands: []const []const u8, comparisons: []const Comparison },
};

/// An owned style-query tree. The context implements
/// `pub fn evaluate(self, StyleFeature) !Truth`. Keep the input alive.
pub const StyleQuery = ParsedCondition(StyleFeature);

/// CSS Conditional 5 §6.2 steps 3–5: compare host-computed numeric operands.
/// Each value has a `value: f64` and a `dimension` enum with number, percentage,
/// length, angle, time, frequency and resolution tags. The host supplies the
/// canonical units; this module does not parse or compute numeric CSS values.
pub fn compareRange(values: anytype, comparisons: []const Comparison) Truth {
    if (values.len < 2 or values.len > 3 or comparisons.len != values.len - 1) return .false;
    for (comparisons, 0..) |comparison, i| {
        const left = values[i];
        const right = values[i + 1];
        if (left.dimension != right.dimension) {
            // Step 4 permits a unitless zero to stand for a zero length only.
            const left_zero = left.dimension == .number and left.value == 0 and right.dimension == .length;
            const right_zero = right.dimension == .number and right.value == 0 and left.dimension == .length;
            if (!left_zero and !right_zero) return .false;
        }
        const matches = switch (comparison) {
            .equal => left.value == right.value,
            .less => left.value < right.value,
            .less_equal => left.value <= right.value,
            .greater => left.value > right.value,
            .greater_equal => left.value >= right.value,
        };
        if (!matches) return .false;
    }
    return .true;
}

// Shipping style queries accept custom properties only (probe 1025i). Keep
// standard properties unknown before consulting the host, also under `not`.
fn isQueryableStyleFeature(feature: StyleFeature) bool {
    const name = switch (feature) {
        .boolean => |name| name,
        .plain => |plain| plain.name,
        .range => return true,
    };
    return name.len > 2 and std.mem.startsWith(u8, name, "--");
}

/// Parse <if-args> contents, without the surrounding if(...).
/// Null means invalid argument grammar; OOM is an error, never invalid CSS.
/// Nested substitution functions remain untouched, including unused branches.
pub fn parseArguments(allocator: Allocator, text: []const u8) Allocator.Error!?Arguments {
    var branches: std.ArrayList(Branch) = .empty;
    defer branches.deinit(allocator);
    var tokenizer = Tokenizer.init(text);
    tokenizer.skipWhitespace();
    var start = tokenizer.pos;
    var colon: ?usize = null;
    while (true) {
        const token = tokenizer.next();
        switch (token.token_type) {
            .function => {
                if (tokenizer.next().token_type != .left_paren) return null;
                _ = block(&tokenizer, .left_paren) orelse return null;
            },
            .left_paren, .left_bracket, .left_brace => {
                _ = block(&tokenizer, token.token_type) orelse return null;
            },
            .right_paren, .right_bracket, .right_brace, .bad_string, .bad_url => return null,
            .colon => if (colon == null) {
                colon = tokenizer.pos - 1;
            },
            .semicolon, .eof => {
                const end = if (token.token_type == .eof) text.len else tokenizer.pos - 1;
                const separator = colon orelse return null;
                const condition = freeForm(text[start..separator], true) orelse return null;
                if (isEmpty(condition)) return null;
                const value = freeForm(text[separator + 1 .. end], false) orelse return null;
                try branches.append(allocator, .{ .condition = condition, .value = value });
                if (token.token_type == .eof) break;
                tokenizer.skipWhitespace();
                if (tokenizer.peek().token_type == .eof) break; // One optional trailing ';'.
                start = tokenizer.pos;
                colon = null;
            },
            else => {},
        }
    }
    return .{ .allocator = allocator, .branches = try branches.toOwnedSlice(allocator) };
}

/// Parse an <if-condition> after expanding condition-level substitutions.
/// Query-value text stays unresolved until its leaf is evaluated by the host.
/// Invalid boolean syntax returns null. <general-enclosed> produces unknown.
pub fn parseCondition(allocator: Allocator, text: []const u8) Allocator.Error!?Condition {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    var parser = BooleanParser(Query){ .allocator = arena.allocator() };
    var tokenizer = Tokenizer.init(text);
    tokenizer.skipWhitespace();
    const first = tokenizer.next();
    if (first.token_type == .ident and tokens.nameEql(first.value, "else")) {
        tokenizer.skipWhitespace();
        if (tokenizer.next().token_type == .eof) {
            const expression = try parser.make(.{ .literal = .true });
            return .{ .arena = arena, .expression = expression };
        }
    }
    const expression = try parser.condition(text, 0) orelse {
        arena.deinit();
        return null;
    };
    return .{ .arena = arena, .expression = expression };
}

/// Parse a style() body, retaining feature values for lazy host substitution.
/// A malformed feature is invalid; general-enclosed expressions stay unknown.
pub fn parseStyleQuery(allocator: Allocator, text: []const u8) Allocator.Error!?StyleQuery {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    var parser = BooleanParser(StyleFeature){ .allocator = arena.allocator() };
    const expression = try parser.condition(text, 0) orelse {
        arena.deinit();
        return null;
    };
    return .{ .arena = arena, .expression = expression };
}

fn BooleanParser(comptime Leaf: type) type {
    return struct {
        const Self = @This();
        const Node = Expression(Leaf);
        allocator: Allocator,

        fn make(self: *Self, value: Node) Allocator.Error!*const Node {
            const expression = try self.allocator.create(Node);
            expression.* = value;
            return expression;
        }

        fn condition(self: *Self, text: []const u8, depth: usize) Allocator.Error!?*const Node {
            if (depth >= 128) return null;
            if (Leaf == StyleFeature) {
                if (try styleFeature(self.allocator, text)) |feature| return try self.make(.{ .leaf = feature });
            }
            var tokenizer = Tokenizer.init(text);
            tokenizer.skipWhitespace();
            const first = tokenizer.peek();
            if (first.token_type == .ident and tokens.nameEql(first.value, "not")) {
                _ = tokenizer.next();
                const operand = try self.group(&tokenizer, depth) orelse return null;
                tokenizer.skipWhitespace();
                if (tokenizer.next().token_type != .eof) return null;
                return try self.make(.{ .not = operand });
            }
            const first_operand = try self.group(&tokenizer, depth) orelse return null;
            tokenizer.skipWhitespace();
            if (tokenizer.peek().token_type == .eof) return first_operand;
            const operator = tokenizer.next();
            if (operator.token_type != .ident) return null;
            const is_and = tokens.nameEql(operator.value, "and");
            if (!is_and and !tokens.nameEql(operator.value, "or")) return null;
            var operands: std.ArrayList(*const Node) = .empty;
            defer operands.deinit(self.allocator);
            try operands.append(self.allocator, first_operand);
            while (true) {
                const operand = try self.group(&tokenizer, depth) orelse return null;
                try operands.append(self.allocator, operand);
                tokenizer.skipWhitespace();
                const next = tokenizer.next();
                if (next.token_type == .eof) break;
                if (next.token_type != .ident or !tokens.nameEql(next.value, if (is_and) "and" else "or")) return null;
            }
            const children = try operands.toOwnedSlice(self.allocator);
            return try self.make(if (is_and) .{ .all = children } else .{ .any = children });
        }

        fn group(self: *Self, tokenizer: *Tokenizer, depth: usize) Allocator.Error!?*const Node {
            tokenizer.skipWhitespace();
            const token = tokenizer.next();
            if (token.token_type == .left_paren) {
                const contents = block(tokenizer, .left_paren) orelse return null;
                if (try self.condition(contents, depth + 1)) |condition_value| return condition_value;
                // CSS Values 5 §3.2 / MQ5 §3: general-enclosed is tried last.
                return try self.make(.{ .literal = .unknown });
            }
            if (token.token_type != .function) return null;
            if (tokenizer.next().token_type != .left_paren) return null;
            const contents = block(tokenizer, .left_paren) orelse return null;
            if (Leaf == StyleFeature) return try self.make(.{ .literal = .unknown });
            const kind: QueryKind = if (tokens.nameEql(token.value, "style")) .style else if (tokens.nameEql(token.value, "media")) .media else if (tokens.nameEql(token.value, "supports")) .supports else return try self.make(.{ .literal = .unknown });
            return try self.make(.{ .leaf = .{ .kind = kind, .text = trim(contents) } });
        }
    };
}

// CSS Conditional 5 §5.4: a whole feature is tried before boolean syntax.
// Unknown property names cannot become valid boolean features (e.g. "not").
fn styleFeature(allocator: Allocator, text: []const u8) Allocator.Error!?StyleFeature {
    var tokenizer = Tokenizer.init(text);
    tokenizer.skipWhitespace();
    const first = tokenizer.next();
    if (first.token_type == .ident) {
        const name = try tokens.decode(allocator, first.value);
        const is_name = (name.len > 2 and std.mem.startsWith(u8, name, "--")) or properties.lookup(name) != null;
        if (is_name) {
            tokenizer.skipWhitespace();
            const next = tokenizer.next();
            if (next.token_type == .eof) return .{ .boolean = name };
            if (next.token_type == .colon) {
                const value = trim(text[tokenizer.pos..]);
                if (!styleValue(value)) return null;
                return .{ .plain = .{ .name = name, .value = value } };
            }
        }
    }

    // <style-range>: split only at top-level comparisons. Each operand is a
    // declaration value; numeric validity is checked after host computation.
    tokenizer = Tokenizer.init(text);
    var start: usize = 0;
    var operands: [3][]const u8 = undefined;
    var comparisons: [2]Comparison = undefined;
    var count: usize = 0;
    while (true) {
        tokenizer.skipWhitespace();
        const token_start = tokenizer.pos;
        const token = tokenizer.next();
        switch (token.token_type) {
            .eof => break,
            .function => {
                if (tokenizer.next().token_type != .left_paren) return null;
                _ = block(&tokenizer, .left_paren) orelse return null;
            },
            .left_paren, .left_bracket, .left_brace => {
                _ = block(&tokenizer, token.token_type) orelse return null;
            },
            .bad_url, .bad_string, .right_paren, .right_bracket, .right_brace => return null,
            .delim => {
                const symbol = token.value[0];
                if (symbol != '<' and symbol != '>' and symbol != '=') continue;
                if (count == comparisons.len) return null;
                const operand = trim(text[start..token_start]);
                if (isEmpty(operand) or !styleValue(operand)) return null;
                operands[count] = operand;
                // Adjacent delim tokens may have comments between them, but
                // never whitespace (MQ5 <mf-lt>/<mf-gt>; probe 1025j).
                const next = tokenizer.peek();
                const equals = symbol != '=' and next.token_type == .delim and std.mem.eql(u8, next.value, "=");
                if (equals) _ = tokenizer.next();
                comparisons[count] = switch (symbol) {
                    '<' => if (equals) .less_equal else .less,
                    '>' => if (equals) .greater_equal else .greater,
                    else => .equal,
                };
                count += 1;
                start = tokenizer.pos;
            },
            else => {},
        }
    }
    if (count == 0) return null;
    const last = trim(text[start..]);
    if (isEmpty(last) or !styleValue(last)) return null;
    operands[count] = last;
    if (count == 2 and !chainAccepted(comparisons[0], comparisons[1])) return null;
    return .{ .range = .{
        .operands = try allocator.dupe([]const u8, operands[0 .. count + 1]),
        .comparisons = try allocator.dupe(Comparison, comparisons[0..count]),
    } };
}

// Probe 1025k measured every pair and its negation. This is the shipping
// grammar, not a mathematical direction rule or a dependency on our enum's
// ordinals: =/< and <=/> are accepted, while =/<= is not.
fn chainAccepted(first: Comparison, second: Comparison) bool {
    if (first == second) return true;
    return switch (first) {
        .equal => second == .less,
        .less => second == .equal or second == .less_equal,
        .less_equal => second == .less or second == .greater,
        .greater => second == .less_equal or second == .greater_equal,
        .greater_equal => second == .greater,
    };
}

// §6.2: the comparison tokens exclude top-level values, not tokens inside a
// nested component block (e.g. attr(data-foo type(<length>))).
fn styleValue(text: []const u8) bool {
    if (!rules.isDeclarationValue(text)) return false;
    var tokenizer = Tokenizer.init(text);
    while (true) {
        const token = tokenizer.next();
        switch (token.token_type) {
            .eof => return true,
            .delim => if (std.mem.indexOfAny(u8, token.value, "<>=") != null) return false,
            .function => {
                if (tokenizer.next().token_type != .left_paren) return false;
                _ = block(&tokenizer, .left_paren) orelse return false;
            },
            .left_paren, .left_bracket, .left_brace => {
                _ = block(&tokenizer, token.token_type) orelse return false;
            },
            else => {},
        }
    }
}

fn closer(opener: TokenType) TokenType {
    return switch (opener) {
        .left_bracket => .right_bracket,
        .left_brace => .right_brace,
        else => .right_paren,
    };
}

// CSS Syntax 3 §5.4.8: consume a simple block. Function tokens leave their
// '(' for this tokenizer's next token. EOF closes open blocks; bad tokens and
// mismatched closers never turn into valid declaration/any-value contents.
fn block(tokenizer: *Tokenizer, opener: TokenType) ?[]const u8 {
    const start = tokenizer.pos;
    var closers: [128]TokenType = undefined;
    closers[0] = closer(opener);
    var depth: usize = 1;
    while (true) {
        const token = tokenizer.next();
        switch (token.token_type) {
            .eof => return tokenizer.input[start..],
            .bad_string, .bad_url => return null,
            .left_paren, .left_bracket, .left_brace => {
                if (depth == closers.len) return null;
                closers[depth] = closer(token.token_type);
                depth += 1;
            },
            .right_paren, .right_bracket, .right_brace => {
                if (closers[depth - 1] != token.token_type) return null;
                depth -= 1;
                if (depth == 0) return tokenizer.input[start .. tokenizer.pos - 1];
            },
            else => {},
        }
    }
}

fn isEmpty(text: []const u8) bool {
    var tokenizer = Tokenizer.init(text);
    tokenizer.skipWhitespace();
    return tokenizer.next().token_type == .eof;
}

fn trim(text: []const u8) []const u8 {
    return std.mem.trim(u8, text, " \t\n\r\x0c");
}

// §3.1.1 restricts commas and curly blocks in an unwrapped argument, not
// round/square blocks. Keep curly braces per the shipping-browser ruling
// (integrator-probes-1025d2); a wrapped condition is then invalid when parsed
// late. §8.3 additionally excludes a top-level colon from the condition.
fn freeForm(raw: []const u8, is_condition: bool) ?[]const u8 {
    var tokenizer = Tokenizer.init(raw);
    tokenizer.skipWhitespace();
    const original = raw[tokenizer.pos..];
    var value = original;
    const wrapped = tokenizer.peek().token_type == .left_brace;
    if (wrapped) {
        _ = tokenizer.next();
        value = block(&tokenizer, .left_brace) orelse return null;
        tokenizer.skipWhitespace();
        if (tokenizer.next().token_type != .eof) return null;
    }
    tokenizer = Tokenizer.init(value);
    while (true) {
        const token = tokenizer.next();
        switch (token.token_type) {
            .eof => return if (is_condition) trim(original) else original,
            .bad_string, .bad_url, .right_paren, .right_bracket, .right_brace, .semicolon => return null,
            .colon => if (is_condition) return null,
            .comma => if (!wrapped) return null,
            .delim => if (std.mem.eql(u8, token.value, "!")) return null,
            .function => {
                if (tokenizer.next().token_type != .left_paren) return null;
                _ = block(&tokenizer, .left_paren) orelse return null;
            },
            .left_brace, .left_bracket, .left_paren => {
                if (!wrapped and token.token_type == .left_brace) return null;
                _ = block(&tokenizer, token.token_type) orelse return null;
            },
            else => {},
        }
    }
}
