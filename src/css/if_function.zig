//! CSS Values 5 §8.3 if() argument grammar and §3.2 boolean expressions.
//!
//! The table adapter parses the shared component-value Nodes without turning
//! them back into source tokens. The shared resolver performs every substitution;
//! its Host computes query values. Only visited query leaves and the chosen
//! branch are substituted. The text parsing API is also available to callers.
//!
//! Design reference (not copied): Blink CSSIfParser::ConsumeIfCondition and
//! ConsumeFunction, and StyleCascade::EvalIfCondition / ResolveIfInto.
//! https://drafts.csswg.org/css-values-5/#if-notation

const std = @import("std");
const tokens = @import("tokenizer.zig");
const rules = @import("rules.zig");
const properties = @import("properties.zig");
const substitution = @import("substitution.zig");
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

        fn evaluate(self: *const Self, context: anytype) @TypeOf(if (Leaf == Query) context.evaluate(.style, "") else context.evaluate(@as(Leaf, undefined))) {
            return switch (self.*) {
                .literal => |value| value,
                .leaf => |leaf| if (Leaf == Query)
                    try context.evaluate(leaf.kind, leaf.text)
                else if (Leaf != StyleFeature or isQueryableStyleFeature(leaf))
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

// The runtime adapter consumes substitution.Nodes. In particular, parsing a
// condition never renders/re-tokenizes a query value: that would erase both
// token boundaries and taint before the lazy leaf reaches the shared resolver.
const Component = substitution.Node;
const Error = substitution.Error;
const Feature = union(enum) {
    boolean: []const u8,
    plain: struct { name: []const u8, value: []const Component },
    range: struct { operands: []const []const Component, comparisons: []const Comparison },
};
const ComponentLeaf = union(enum) {
    query: struct { kind: QueryKind, nodes: []const Component },
    feature: Feature,
};
const Expr = Expression(ComponentLeaf);

/// CSS Values 5 §8.3 argument grammar, called by the shared function table.
/// Alternating condition/value spans; an empty value is still one argument.
pub fn arguments(allocator: Allocator, contents: []const Component, _: substitution.Phase) Error![]const []const Component {
    var result: std.ArrayList([]const Component) = .empty;
    const nodes = contents;
    var start: usize = 0;
    var colon: ?usize = null;
    for (0..nodes.len + 1) |i| {
        if (i == nodes.len or nodes[i].kind == .semicolon) {
            if (i == nodes.len and colon == null and result.items.len != 0 and substitution.trim(nodes[start..i]).len == 0) break;
            const split = colon orelse return error.Invalid;
            const condition = try argument(nodes[start..split], true);
            if (condition.len == 0) return error.Invalid;
            try result.append(allocator, condition);
            try result.append(allocator, try argument(nodes[split + 1 .. i], false));
            start = i + 1;
            colon = null;
        } else if (nodes[i].kind == .colon and colon == null) colon = i;
    }
    return result.toOwnedSlice(allocator);
}

fn argument(raw: []const Component, condition: bool) Error![]const Component {
    const nodes = substitution.trim(raw);
    const value = try substitution.freeForm(nodes);
    const wrapped = nodes.len == 1 and nodes[0].kind == .left_brace;
    for (value) |node| {
        if (!wrapped and node.kind == .comma) return error.Invalid;
        if (condition and node.kind == .colon) return error.Invalid;
    }
    // Golden rule 2, integrator probe 1025d2: shipping if() retains braces.
    // A braced condition is consequently rejected at the late grammar step.
    if (condition) return nodes;
    // Consume the grammar whitespace after the colon, preserving the final
    // whitespace of a nonempty value (if-conditionals.html subtest 1).
    var start: usize = 0;
    skipSpace(raw, &start);
    return raw[start..];
}

/// CSS Values 5 §8.3 "replace an if() function". The shared walk supplies
/// early invocation, guards, splicing and limits; this adapter chooses a branch.
pub fn replace(resolver: *substitution.Resolver, _: Component, args: []const []const Component) Error!substitution.Replacement {
    var evaluator = Evaluation{ .resolver = resolver };
    var parser = ComponentParser{ .resolver = resolver, .tainted = &evaluator.tainted };
    var i: usize = 0;
    while (i < args.len) : (i += 2) {
        // 1.1: expand condition syntax, keeping query children opaque. Invalid
        // syntax/substitution skips this branch; OOM/unavailable propagate.
        const condition = parser.condition(args[i], false, true, 0) catch |err| switch (err) {
            error.Invalid => continue,
            else => |e| return e,
        } orelse continue;
        // 1.2: Kleene logic evaluates only visited leaves. Host custom-property
        // reads take the normal marking guard (probe 1025d2), not would_cycle.
        if (!(try condition.evaluate(&evaluator)).matches()) continue;
        // 1.3: only this value is substituted. Keep whole-result taint even
        // for an empty result, including taint read by prior false conditions.
        var selected = try resolver.substituteWithTaint(args[i + 1], false);
        selected.tainted = selected.tainted or evaluator.tainted;
        return selected;
    }
    // Golden rule 2 (probe 1025d2, Blink ResolveIfInto): no match is IACVT.
    return error.Invalid;
}

const ComponentParser = struct {
    resolver: *substitution.Resolver,
    tainted: *bool,

    fn make(self: *@This(), value: Expr) Allocator.Error!*const Expr {
        const result = try self.resolver.allocator.create(Expr);
        result.* = value;
        return result;
    }

    // Q19's grammar cursor: only condition-level substitution functions are
    // handed to the shared walk. Query function children stay opaque. Nodes
    // already carry token boundaries; concatenating grammar spans does not
    // serialize/splice CSS text or implement another replacement algorithm.
    fn expand(self: *@This(), nodes: []const Component) Error![]const Component {
        var expanded: std.ArrayList(Component) = .empty;
        var start: usize = 0;
        for (nodes, 0..) |node, i| {
            if (node.kind != .function or substitution.functionId(node.value) == null) continue;
            try expanded.appendSlice(self.resolver.allocator, nodes[start..i]);
            const replacement = try self.resolver.substituteWithTaint(nodes[i .. i + 1], false);
            self.tainted.* = self.tainted.* or replacement.tainted;
            try expanded.appendSlice(self.resolver.allocator, replacement.nodes);
            start = i + 1;
        }
        if (start == 0) return nodes;
        try expanded.appendSlice(self.resolver.allocator, nodes[start..]);
        return expanded.toOwnedSlice(self.resolver.allocator);
    }

    fn condition(self: *@This(), raw: []const Component, style: bool, allow_else: bool, depth: usize) Error!?*const Expr {
        if (depth >= substitution.max_depth) return null;
        const nodes = substitution.trim(if (style) raw else try self.expand(raw));
        if (allow_else and nodes.len == 1 and keyword(nodes[0], "else")) return try self.make(.{ .literal = .true });
        if (style) if (try self.parseFeature(nodes)) |feature| return try self.make(.{ .leaf = .{ .feature = feature } });
        if (nodes.len == 0) return null;
        var i: usize = 0;
        if (keyword(nodes[0], "not")) {
            i = 1;
            const child = try self.group(nodes, &i, style, depth) orelse return null;
            skipSpace(nodes, &i);
            if (i != nodes.len) return null;
            return try self.make(.{ .not = child });
        }
        const first = try self.group(nodes, &i, style, depth) orelse return null;
        skipSpace(nodes, &i);
        if (i == nodes.len) return first;
        const is_and = keyword(nodes[i], "and");
        if (!is_and and !keyword(nodes[i], "or")) return null;
        var children: std.ArrayList(*const Expr) = .empty;
        try children.append(self.resolver.allocator, first);
        while (i < nodes.len) {
            if (!keyword(nodes[i], if (is_and) "and" else "or")) return null;
            i += 1;
            const child = try self.group(nodes, &i, style, depth) orelse return null;
            try children.append(self.resolver.allocator, child);
            skipSpace(nodes, &i);
        }
        const owned = try children.toOwnedSlice(self.resolver.allocator);
        return try self.make(if (is_and) .{ .all = owned } else .{ .any = owned });
    }

    fn group(self: *@This(), nodes: []const Component, i: *usize, style: bool, depth: usize) Error!?*const Expr {
        skipSpace(nodes, i);
        if (i.* == nodes.len) return null;
        const node = nodes[i.*];
        i.* += 1;
        if (node.kind == .left_paren) {
            if (try self.condition(node.children, style, false, depth + 1)) |child| return child;
            return try self.make(.{ .literal = .unknown }); // general-enclosed, tried last
        }
        if (node.kind != .function) return null;
        if (style) return try self.make(.{ .literal = .unknown });
        const kind: QueryKind = if (tokens.nameEql(node.value, "style")) .style else if (tokens.nameEql(node.value, "media")) .media else if (tokens.nameEql(node.value, "supports")) .supports else return try self.make(.{ .literal = .unknown });
        return try self.make(.{ .leaf = .{ .query = .{ .kind = kind, .nodes = node.children } } });
    }

    fn parseFeature(self: *@This(), nodes: []const Component) Allocator.Error!?Feature {
        if (nodes.len != 0 and nodes[0].kind == .ident) {
            const name = try tokens.decode(self.resolver.allocator, nodes[0].value);
            if ((name.len > 2 and std.mem.startsWith(u8, name, "--")) or properties.lookup(name) != null) {
                var i: usize = 1;
                skipSpace(nodes, &i);
                if (i == nodes.len) return .{ .boolean = name };
                if (nodes[i].kind == .colon) {
                    const value = substitution.trim(nodes[i + 1 ..]);
                    if (!featureValue(value)) return null;
                    return .{ .plain = .{ .name = name, .value = value } };
                }
            }
        }
        var operands: [3][]const Component = undefined;
        var comparisons: [2]Comparison = undefined;
        var count: usize = 0;
        var start: usize = 0;
        var i: usize = 0;
        while (i < nodes.len) : (i += 1) {
            const node = nodes[i];
            if (node.kind != .delim or node.value.len != 1 or std.mem.indexOfScalar(u8, "<>=", node.value[0]) == null) continue;
            if (count == 2) return null;
            const value = substitution.trim(nodes[start..i]);
            if (value.len == 0 or !featureValue(value)) return null;
            operands[count] = value;
            const equals = node.value[0] != '=' and i + 1 < nodes.len and nodes[i + 1].kind == .delim and std.mem.eql(u8, nodes[i + 1].value, "=");
            comparisons[count] = switch (node.value[0]) {
                '<' => if (equals) .less_equal else .less,
                '>' => if (equals) .greater_equal else .greater,
                else => .equal,
            };
            if (equals) i += 1;
            count += 1;
            start = i + 1;
        }
        if (count == 0) return null;
        const last = substitution.trim(nodes[start..]);
        if (last.len == 0 or !featureValue(last)) return null;
        operands[count] = last;
        if (count == 2 and !chainAccepted(comparisons[0], comparisons[1])) return null;
        return .{ .range = .{ .operands = try self.resolver.allocator.dupe([]const Component, operands[0 .. count + 1]), .comparisons = try self.resolver.allocator.dupe(Comparison, comparisons[0..count]) } };
    }
};

fn keyword(node: Component, word: []const u8) bool {
    return node.kind == .ident and tokens.nameEql(node.value, word);
}

fn skipSpace(nodes: []const Component, i: *usize) void {
    while (i.* < nodes.len and substitution.isSpace(nodes[i.*])) i.* += 1;
}

fn featureValue(nodes: []const Component) bool {
    for (nodes) |node| {
        if (node.kind == .semicolon) return false;
        if (node.kind == .delim and std.mem.indexOfAny(u8, node.value, "!<>=") != null) return false;
    }
    return true;
}

const Evaluation = struct {
    resolver: *substitution.Resolver,
    tainted: bool = false,

    fn text(self: *@This(), nodes: []const Component) Error![]const u8 {
        const result = try self.resolver.substituteWithTaint(nodes, false);
        self.tainted = self.tainted or result.tainted;
        return (try substitution.render(self.resolver.allocator, result.nodes)).text;
    }

    fn flagged(self: *@This(), result: substitution.Flagged(bool)) Truth {
        self.tainted = self.tainted or result.tainted;
        return if (result.value) .true else .false;
    }

    fn evaluate(self: *@This(), leaf: ComponentLeaf) Error!Truth {
        const host = self.resolver.host;
        return switch (leaf) {
            .query => |query| blk: {
                if (query.kind == .style) {
                    var parser = ComponentParser{ .resolver = self.resolver, .tainted = &self.tainted };
                    const expression = try parser.condition(query.nodes, true, false, 0) orelse break :blk .unknown;
                    break :blk try expression.evaluate(self);
                }
                const value = self.text(query.nodes) catch |err| switch (err) {
                    error.Invalid => break :blk .unknown,
                    else => |e| return e,
                };
                const result = (switch (query.kind) {
                    .media => (host.media orelse break :blk .unknown)(host.context, value),
                    .supports => (host.supports orelse break :blk .unknown)(host.context, value, self.resolver.quirks),
                    .style => unreachable,
                }) catch |err| switch (err) {
                    error.Invalid => break :blk .unknown,
                    else => |e| return e,
                };
                break :blk if (result) .true else .false;
            },
            .feature => |feature| self.evaluateFeature(feature) catch |err| switch (err) {
                // Q9: substitution failure makes a FEATURE false, so a
                // surrounding not can still invert it. OOM never becomes CSS.
                error.Invalid => .false,
                else => |e| return e,
            },
        };
    }

    fn evaluateFeature(self: *@This(), feature: Feature) Error!Truth {
        const host = self.resolver.host;
        switch (feature) {
            .boolean => |name| {
                if (!std.mem.startsWith(u8, name, "--")) return .unknown;
                const callback = host.has_value orelse return .false;
                return self.flagged(try callback(host.context, name));
            },
            .plain => |plain| {
                if (!std.mem.startsWith(u8, plain.name, "--")) return .unknown;
                const callback = host.query_value_matches orelse return .unknown;
                const value = try self.text(plain.value);
                const result = try callback(host.context, plain.name, value) orelse return .unknown;
                return self.flagged(result);
            },
            .range => |range| {
                // Conditional 5 §6.2; Blink EvalIfStyleFeature resolves the
                // reference (operand 1), then left and right. A false first
                // comparison still evaluates the right bound; a nonnumeric
                // operand returns false immediately. Host owns all CSS math.
                var values: [3]substitution.Numeric = undefined;
                const order = [_]usize{ 1, 0, 2 };
                const callback = host.numeric_value orelse return .false;
                for (order[0..range.operands.len]) |i| {
                    const value = try self.text(range.operands[i]);
                    const result = try callback(host.context, value) orelse return .false;
                    self.tainted = self.tainted or result.tainted;
                    values[i] = result.value;
                }
                return compareRange(values[0..range.operands.len], range.comparisons);
            },
        }
    }
};
