//! CSS Values 4 §§9.1, 10.1–2, 10.7–13: typed numeric expression trees.
//! Unit algebra follows CSS Typed OM 1 §4.3.2. Trees own their small arena;
//! no expression keeps a document, computed-style pointer or host resource.
//! Design reference: Blink CSSMathExpressionNode's typed comparison and
//! arithmetic simplification (independent implementation, not copied).
const std = @import("std");
const tokens = @import("tokenizer.zig");
const Allocator = std.mem.Allocator;
const Error = Allocator.Error || error{Invalid};

pub const Base = enum(u3) { length, angle, time, frequency, resolution, flex, percent };
const base_count = @typeInfo(Base).@"enum".fields.len;

/// CSS Typed OM §4.3.2: exponents, with the context's percentage hint.
pub const Type = struct {
    powers: [base_count]i16 = .{0} ** base_count,
    hint: ?Base = null,

    fn one(base: ?Base) Type {
        var result = Type{};
        if (base) |b| result.powers[@intFromEnum(b)] = 1;
        return result;
    }

    fn withHint(self: Type, hint: Base) Type {
        var result = self;
        if (hint != .percent) {
            result.powers[@intFromEnum(hint)] += result.powers[@intFromEnum(Base.percent)];
            result.powers[@intFromEnum(Base.percent)] = 0;
        }
        result.hint = hint;
        return result;
    }

    fn harmonize(a: *Type, b: *Type) error{Invalid}!void {
        if (a.hint) |h| {
            if (b.hint) |other| {
                if (h != other) return error.Invalid;
            } else b.* = b.withHint(h);
        } else if (b.hint) |h| a.* = a.withHint(h);
    }

    fn add(a0: Type, b0: Type) error{Invalid}!Type {
        var a = a0;
        var b = b0;
        try harmonize(&a, &b);
        if (std.mem.eql(i16, &a.powers, &b.powers)) return a;
        // In CSS calculations every percentage already has a context hint
        // (§10.9), so Typed OM's unhinted-percentage search is unnecessary.
        return error.Invalid;
    }

    fn multiply(a0: Type, b0: Type) error{Invalid}!Type {
        var a = a0;
        var b = b0;
        try harmonize(&a, &b);
        for (&a.powers, b.powers) |*power, other| {
            power.* = std.math.add(i16, power.*, other) catch return error.Invalid;
        }
        return a;
    }

    fn invert(self: Type) Type {
        var result = self;
        for (&result.powers) |*power| power.* = -power.*;
        return result;
    }

    fn is(self: Type, base: ?Base) bool {
        for (self.powers, 0..) |power, i| {
            const expected: i16 = if (base != null and i == @intFromEnum(base.?)) 1 else 0;
            if (power != expected) return false;
        }
        return true;
    }

    fn eql(a: Type, b: Type) bool {
        return a.hint == b.hint and std.mem.eql(i16, &a.powers, &b.powers);
    }
};

pub const Unit = enum(u8) {
    number,
    percent,
    px,
    cm,
    mm,
    q,
    in,
    pt,
    pc,
    em,
    rem,
    ex,
    rex,
    cap,
    rcap,
    ch,
    rch,
    ic,
    ric,
    lh,
    rlh,
    vw,
    vh,
    vi,
    vb,
    vmin,
    vmax,
    svw,
    svh,
    svi,
    svb,
    svmin,
    svmax,
    lvw,
    lvh,
    lvi,
    lvb,
    lvmin,
    lvmax,
    dvw,
    dvh,
    dvi,
    dvb,
    dvmin,
    dvmax,
    deg,
    grad,
    rad,
    turn,
    s,
    ms,
    hz,
    khz,
    dpi,
    dpcm,
    dppx,
    x,
    fr,

    pub fn name(self: Unit) []const u8 {
        return switch (self) {
            .number => "",
            .percent => "%",
            else => @tagName(self),
        };
    }

    pub fn parse(raw: []const u8) ?Unit {
        inline for (@typeInfo(Unit).@"enum".fields) |field| {
            const unit: Unit = @enumFromInt(field.value);
            if (unit != .number and unit != .percent and tokens.nameEql(raw, unit.name())) return unit;
        }
        return null;
    }

    pub fn base(self: Unit) ?Base {
        return switch (self) {
            .number => null,
            .percent => .percent,
            .deg, .grad, .rad, .turn => .angle,
            .s, .ms => .time,
            .hz, .khz => .frequency,
            .dpi, .dpcm, .dppx, .x => .resolution,
            .fr => .flex,
            else => .length,
        };
    }

    fn canonical(self: Unit) Unit {
        return switch (self.base() orelse return .number) {
            .length => .px,
            .angle => .deg,
            .time => .s,
            .frequency => .hz,
            .resolution => .dppx,
            .flex => .fr,
            .percent => .percent,
        };
    }

    fn absoluteScale(self: Unit) ?f64 {
        return switch (self) {
            .number, .percent, .px, .deg, .s, .hz, .dppx, .x, .fr => 1,
            .cm => 96.0 / 2.54,
            .mm => 96.0 / 25.4,
            .q => 96.0 / 101.6,
            .in => 96,
            .pt => 96.0 / 72.0,
            .pc => 16,
            .grad => 0.9,
            .rad => 180.0 / std.math.pi,
            .turn => 360,
            .ms => 0.001,
            .khz => 1000,
            .dpi => 1.0 / 96.0,
            .dpcm => 2.54 / 96.0,
            else => null,
        };
    }
};

pub const Numeric = struct { value: f64, unit: Unit };
pub const Kind = enum { length, length_percentage, percentage, number, number_percentage, integer, length_percentage_number, angle, time, resolution, flex };

pub const Grammar = struct {
    kind: Kind,
    minimum: f64 = -std.math.floatMax(f64),
    maximum: f64 = std.math.floatMax(f64),
    anchor_position: bool = false,
    anchor_size: bool = false,

    fn percentHint(self: Grammar) Base {
        return switch (self.kind) {
            .length_percentage, .length_percentage_number => .length,
            else => .percent,
        };
    }

    fn accepts(self: Grammar, typ: Type) bool {
        const has_percent = typ.hint != null;
        return switch (self.kind) {
            .length => typ.is(.length) and !has_percent,
            .length_percentage => typ.is(.length) and (typ.hint == null or typ.hint == .length),
            .percentage => typ.is(.percent) and (typ.hint == null or typ.hint == .percent),
            .length_percentage_number => (typ.is(.length) or typ.is(null)) and (typ.hint == null or typ.hint == .length),
            .number, .integer => typ.is(null) and !has_percent,
            .number_percentage => (typ.is(null) or typ.is(.percent)) and (typ.hint == null or typ.hint == .percent),
            .angle => typ.is(.angle) and !has_percent,
            .time => typ.is(.time) and !has_percent,
            .resolution => typ.is(.resolution) and !has_percent,
            .flex => typ.is(.flex) and !has_percent,
        };
    }
};

/// Only information available without layout. null percentage_basis means
/// that a percentage remains a percentage, including a zero percentage.
pub const Context = struct {
    font_size: f64 = 16,
    root_font_size: f64 = 16,
    line_height: f64 = 19.2,
    root_line_height: f64 = 19.2,
    vertical: bool = false,
    upright: bool = false,
    root_vertical: bool = false,
    root_upright: bool = false,
    /// §6.1.2 uses this box's axes even when font metrics come from its parent.
    viewport_vertical: bool = false,
    viewport_width: f64 = 1024,
    viewport_height: f64 = 768,
    percentage_basis: ?f64 = null,

    pub fn resolve(self: Context, number: Numeric) Numeric {
        const scale: f64 = switch (number.unit) {
            .em => self.font_size,
            .rem => self.root_font_size,
            .ex => self.font_size * 0.5,
            .rex => self.root_font_size * 0.5,
            .ch => self.font_size * (if (self.vertical and self.upright) @as(f64, 1) else 0.5),
            .rch => self.root_font_size * (if (self.root_vertical and self.root_upright) @as(f64, 1) else 0.5),
            .ic => self.font_size,
            .ric => self.root_font_size,
            .lh => self.line_height,
            .rlh => self.root_line_height,
            .cap, .rcap => return number, // Needs the host's cap-height/ascent, Q17.
            .vw, .svw, .lvw, .dvw => self.viewport_width / 100,
            .vh, .svh, .lvh, .dvh => self.viewport_height / 100,
            .vi, .svi, .lvi, .dvi => (if (self.viewport_vertical) self.viewport_height else self.viewport_width) / 100,
            .vb, .svb, .lvb, .dvb => (if (self.viewport_vertical) self.viewport_width else self.viewport_height) / 100,
            .vmin, .svmin, .lvmin, .dvmin => @min(self.viewport_width, self.viewport_height) / 100,
            .vmax, .svmax, .lvmax, .dvmax => @max(self.viewport_width, self.viewport_height) / 100,
            .percent => if (self.percentage_basis) |basis| basis / 100 else return number,
            else => return .{ .value = number.value * (number.unit.absoluteScale() orelse 1), .unit = number.unit.canonical() },
        };
        return .{ .value = number.value * scale, .unit = .px };
    }
};

/// Anchor Position 1 §§3.2/5.1. Names are arena-owned, case sensitive and
/// independent of any DOM tree. Children contain an optional percentage
/// followed by an optional fallback; both retain their component-value form.
const Anchor = struct {
    size: bool = false,
    name: []const u8 = "",
    side: ?Side = null,
    percentage: bool = false,
    percentage_math: bool = false,
    fallback: bool = false,
    fallback_math: bool = false,

    const Side = enum {
        inside,
        outside,
        top,
        left,
        right,
        bottom,
        start,
        end,
        self_start,
        self_end,
        center,
        width,
        height,
        block,
        @"inline",
        self_block,
        self_inline,

        fn name(self: Side) []const u8 {
            return switch (self) {
                .self_start => "self-start",
                .self_end => "self-end",
                .self_block => "self-block",
                .self_inline => "self-inline",
                else => @tagName(self),
            };
        }
        fn parse(token: tokens.Token, size: bool) ?Side {
            if (token.token_type != .ident) return null;
            inline for (@typeInfo(Side).@"enum".fields) |field| {
                const side: Side = @enumFromInt(field.value);
                const size_side = @intFromEnum(side) >= @intFromEnum(Side.width);
                if (size == size_side and tokens.nameEql(token.value, side.name())) return side;
            }
            return null;
        }
    };

    fn eql(a: Anchor, b: Anchor) bool {
        return a.size == b.size and std.mem.eql(u8, a.name, b.name) and
            a.side == b.side and a.percentage == b.percentage and
            a.percentage_math == b.percentage_math and a.fallback == b.fallback and
            a.fallback_math == b.fallback_math;
    }
};

const Node = struct {
    tag: Tag,
    typ: Type,
    numeric: Numeric = .{ .value = 0, .unit = .number },
    children: []*Node = &.{},
    anchor: Anchor = .{},
    const Tag = enum { numeric, sum, product, negate, invert, min, max, clamp, anchor };

    fn eql(a: *const Node, b: *const Node) bool {
        if (a.tag != b.tag or !a.typ.eql(b.typ) or a.children.len != b.children.len) return false;
        if (a.tag == .anchor and !a.anchor.eql(b.anchor)) return false;
        if (a.tag == .numeric) return a.numeric.unit == b.numeric.unit and
            (@as(u64, @bitCast(a.numeric.value)) == @as(u64, @bitCast(b.numeric.value)) or
                (std.math.isNan(a.numeric.value) and std.math.isNan(b.numeric.value)));
        for (a.children, b.children) |x, y| if (!x.eql(y)) return false;
        return true;
    }

    fn needsFontMetrics(self: *const Node) bool {
        if (self.tag == .numeric) return self.numeric.unit == .cap or self.numeric.unit == .rcap;
        for (self.children) |child| if (child.needsFontMetrics()) return true;
        return false;
    }
};

pub const Expression = struct {
    // UA declarations can be read by several Browsers. Unlike SharedText,
    // expressions need no immortalization hook in the DOM stylesheet layer.
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    arena: std.heap.ArenaAllocator,
    root: *Node = undefined,
    typ: Type = .{},
    grammar: Grammar,
    computed: bool = false,
    wrapper: bool = true,

    fn create(allocator: Allocator, grammar: Grammar) Allocator.Error!*Expression {
        const self = try allocator.create(Expression);
        self.* = .{ .allocator = allocator, .arena = std.heap.ArenaAllocator.init(allocator), .grammar = grammar };
        return self;
    }

    pub fn ref(self: *Expression) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Expression) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        const allocator = self.allocator;
        self.arena.deinit();
        allocator.destroy(self);
    }

    pub fn eql(a: *const Expression, b: *const Expression) bool {
        return a == b or (a.computed == b.computed and a.wrapper == b.wrapper and a.typ.eql(b.typ) and
            a.grammar.kind == b.grammar.kind and a.grammar.minimum == b.grammar.minimum and
            a.grammar.maximum == b.grammar.maximum and a.root.eql(b.root));
    }

    pub fn needsFontMetrics(self: *const Expression) bool {
        return self.root.needsFontMetrics();
    }

    /// Q17/Q23–25 interim capability rule. Only a geometry length may keep
    /// unknown metrics. The default for every other numeric result type is
    /// to require them, including types added by future property grammars.
    pub fn needsUnavailableMetrics(self: *const Expression, geometry_length: bool) bool {
        return self.needsFontMetrics() and !(geometry_length and self.typ.is(.length));
    }

    /// §10.11: clone and simplify with computed-value inputs. The original
    /// specified expression stays immutable and can be shared by declarations.
    pub fn compute(self: *const Expression, allocator: Allocator, context: Context) Allocator.Error!*Expression {
        const result = try create(allocator, self.grammar);
        errdefer result.unref();
        result.typ = self.typ;
        result.computed = true;
        result.wrapper = self.wrapper;
        var builder = Builder{ .allocator = result.arena.allocator(), .hint = self.grammar.percentHint(), .context = context };
        result.root = try builder.copy(self.root);
        return result;
    }

    /// §10.12: clamp and round only the outer result, never an inner node.
    pub fn computedNumber(self: *const Expression) ?Numeric {
        if (!self.computed or self.root.tag != .numeric) return null;
        var result = self.root.numeric;
        if (result.unit.absoluteScale() == null) return null;
        if (std.math.isNan(result.value)) result.value = 0;
        if (self.grammar.kind == .number_percentage and result.unit == .percent) {
            result.value /= 100;
            result.unit = .number;
        }
        result.value = std.math.clamp(result.value, self.grammar.minimum, self.grammar.maximum);
        if (self.grammar.kind == .integer) result.value = @floor(result.value + 0.5);
        if (result.value == 0) result.value = 0;
        return result;
    }

    pub fn serialize(self: *const Expression, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        if (self.computedNumber()) |number| return serializeNumeric(number, out, allocator);
        if (!self.wrapper and self.root.tag == .numeric) return serializeNumeric(self.root.numeric, out, allocator);
        return serializeFunction(self.root, out, allocator);
    }
};

pub const Parsed = struct { expression: *Expression, consumed: usize };

pub fn isFunction(token: tokens.Token) bool {
    if (token.token_type != .function) return false;
    inline for (.{ "calc", "min", "max", "clamp", "anchor", "anchor-size" }) |name| if (tokens.nameEql(token.value, name)) return true;
    return false;
}

/// Parse one function at the beginning of text; leave following shorthand
/// components to the caller. Invalid syntax/type returns null; OOM propagates.
pub fn parse(allocator: Allocator, text: []const u8, grammar: Grammar) Allocator.Error!?Parsed {
    const expression = try Expression.create(allocator, grammar);
    errdefer expression.unref();
    var parser = Parser{
        .builder = .{ .allocator = expression.arena.allocator(), .hint = grammar.percentHint() },
        .tokenizer = tokens.Tokenizer.init(text),
        .anchor_position = grammar.anchor_position,
        .anchor_size = grammar.anchor_size,
    };
    const root = parser.function() catch |err| switch (err) {
        error.Invalid => {
            expression.unref();
            return null;
        },
        error.OutOfMemory => return error.OutOfMemory,
    };
    if (!grammar.accepts(root.typ)) {
        expression.unref();
        return null;
    }
    expression.typ = root.typ;
    expression.root = try parser.builder.simplify(root);
    return .{ .expression = expression, .consumed = parser.tokenizer.pos };
}

/// A relative dimension outside a math function uses the same computation,
/// but keeps ordinary dimension serialization and parse-time range checking.
pub fn dimension(allocator: Allocator, number: Numeric, grammar: Grammar) Allocator.Error!?*Expression {
    if (number.value < grammar.minimum or number.value > grammar.maximum) return null;
    const expression = try Expression.create(allocator, grammar);
    errdefer expression.unref();
    var builder = Builder{ .allocator = expression.arena.allocator(), .hint = grammar.percentHint() };
    const root = try builder.numeric(number);
    if (!grammar.accepts(root.typ)) {
        expression.unref();
        return null;
    }
    expression.root = root;
    expression.typ = root.typ;
    expression.wrapper = false;
    return expression;
}

const Parser = struct {
    builder: Builder,
    tokenizer: tokens.Tokenizer,
    peeked: ?tokens.Token = null,
    whitespace: bool = false,
    depth: usize = 0,
    count: usize = 0,
    anchor_position: bool = false,
    anchor_size: bool = false,

    fn peek(self: *Parser) tokens.Token {
        if (self.peeked) |token| return token;
        self.whitespace = false;
        while (true) {
            const token = self.tokenizer.next();
            if (token.token_type == .whitespace) {
                self.whitespace = true;
                continue;
            }
            self.peeked = token;
            return token;
        }
    }
    fn next(self: *Parser) tokens.Token {
        const token = self.peek();
        self.peeked = null;
        return token;
    }
    fn require(self: *Parser, kind: tokens.TokenType) Error!void {
        const actual = self.next().token_type;
        // Syntax 3 §§5.5.9–10 close open component blocks/functions at EOF.
        if (actual != kind and !(kind == .right_paren and actual == .eof)) return error.Invalid;
    }
    fn nested(self: *Parser) Error!void {
        // §10.8 minimums: at least 32 nesting levels and 32 terms/arguments.
        // These explicit limits also bound recursive simplification/printing.
        self.depth += 1;
        self.count += 1;
        if (self.depth > 128 or self.count > 4096) return error.Invalid;
    }

    fn function(self: *Parser) Error!*Node {
        try self.nested();
        defer self.depth -= 1;
        const token = self.next();
        if (!isFunction(token)) return error.Invalid;
        try self.require(.left_paren);
        if (tokens.nameEql(token.value, "anchor") or tokens.nameEql(token.value, "anchor-size"))
            return self.anchorFunction(tokens.nameEql(token.value, "anchor-size"));
        if (tokens.nameEql(token.value, "calc")) {
            const result = try self.sum();
            try self.require(.right_paren);
            return checkedFunction(result);
        }
        const clamp = tokens.nameEql(token.value, "clamp");
        var list: std.ArrayList(*Node) = .empty;
        var missing: [3]bool = .{false} ** 3;
        while (true) {
            const next_token = self.peek();
            if (clamp and next_token.token_type == .ident and tokens.nameEql(next_token.value, "none")) {
                if (list.items.len == 1 or list.items.len >= 3) return error.Invalid;
                missing[list.items.len] = true;
                _ = self.next();
                // Placeholder is removed before node construction/type checks.
                try list.append(self.builder.allocator, try self.builder.numeric(.{ .value = 0, .unit = .number }));
            } else try list.append(self.builder.allocator, try self.sum());
            if (list.items.len > 4096) return error.Invalid;
            const separator = self.next();
            if (separator.token_type == .right_paren or separator.token_type == .eof) break;
            if (separator.token_type != .comma) return error.Invalid;
        }
        if (clamp) {
            if (list.items.len != 3) return error.Invalid;
            if (missing[0] and missing[2]) return checkedFunction(list.items[1]);
            if (missing[0]) return checkedFunction(try self.builder.operation(.min, list.items[1..]));
            if (missing[2]) return checkedFunction(try self.builder.operation(.max, list.items[0..2]));
            return checkedFunction(try self.builder.operation(.clamp, list.items));
        }
        return checkedFunction(try self.builder.operation(if (tokens.nameEql(token.value, "min")) .min else .max, list.items));
    }

    fn dashedName(self: *Parser) Error!?[]const u8 {
        const token = self.peek();
        if (token.token_type != .ident) return null;
        const decoded = try tokens.decode(self.builder.allocator, token.value);
        if (!std.mem.startsWith(u8, decoded, "--")) return null;
        _ = self.next();
        return decoded;
    }

    fn anchorFunction(self: *Parser, size: bool) Error!*Node {
        if (!(if (size) self.anchor_size else self.anchor_position)) return error.Invalid;
        var query = Anchor{ .size = size };
        query.name = (try self.dashedName()) orelse "";
        var children: std.ArrayList(*Node) = .empty;
        if (Anchor.Side.parse(self.peek(), size)) |side| {
            query.side = side;
            _ = self.next();
        } else if (!size) {
            const token = self.peek();
            query.percentage_math = token.token_type == .function;
            if (token.token_type != .percentage and !query.percentage_math) return error.Invalid;
            const hint = self.builder.hint;
            self.builder.hint = .percent;
            defer self.builder.hint = hint;
            // Percentage-side math has no anchor capabilities of its own.
            const position_allowed = self.anchor_position;
            const size_allowed = self.anchor_size;
            self.anchor_position = false;
            self.anchor_size = false;
            defer {
                self.anchor_position = position_allowed;
                self.anchor_size = size_allowed;
            }
            const percentage = try self.primary();
            if (!(Grammar{ .kind = .percentage }).accepts(percentage.typ)) return error.Invalid;
            try children.append(self.builder.allocator, percentage);
            query.percentage = true;
        }
        if (query.name.len == 0) query.name = (try self.dashedName()) orelse "";
        const has_first_argument = query.name.len > 0 or query.side != null or query.percentage;
        const next_token = self.peek();
        const comma = next_token.token_type == .comma;
        if (comma and !has_first_argument) return error.Invalid;
        if (comma) _ = self.next();
        if (comma or (!has_first_argument and next_token.token_type != .right_paren and next_token.token_type != .eof)) {
            const token = self.peek();
            query.fallback_math = token.token_type == .function;
            if (token.token_type != .dimension and token.token_type != .percentage and
                token.token_type != .number and !query.fallback_math) return error.Invalid;
            // A fallback is one <length-percentage> component, never a bare
            // sum or parenthesized calculation. Unitless zero is a length.
            const hint = self.builder.hint;
            self.builder.hint = .length;
            defer self.builder.hint = hint;
            const fallback = if (token.token_type == .number) blk: {
                if (token.numeric_value != 0) return error.Invalid;
                _ = self.next();
                break :blk try self.builder.numeric(.{ .value = 0, .unit = .px });
            } else try self.primary();
            if (!(Grammar{ .kind = .length_percentage }).accepts(fallback.typ)) return error.Invalid;
            try children.append(self.builder.allocator, fallback);
            query.fallback = true;
        }
        try self.require(.right_paren);
        const result = try self.builder.allocator.create(Node);
        result.* = .{ .tag = .anchor, .typ = Type.one(.length), .anchor = query, .children = children.items };
        return result;
    }

    fn checkedFunction(node: *Node) error{Invalid}!*Node {
        // §10.9: each math function must resolve to a CSS numeric type.
        // Parenthesized arithmetic may have compound intermediate units.
        if (node.typ.is(null)) return node;
        inline for (@typeInfo(Base).@"enum".fields) |field| {
            if (node.typ.is(@enumFromInt(field.value))) return node;
        }
        return error.Invalid;
    }

    fn sum(self: *Parser) Error!*Node {
        var list: std.ArrayList(*Node) = .empty;
        try list.append(self.builder.allocator, try self.product());
        while (true) {
            const token = self.peek();
            if (token.token_type != .delim or !(std.mem.eql(u8, token.value, "+") or std.mem.eql(u8, token.value, "-"))) break;
            // §10.8: + and - require whitespace on BOTH sides. A comment
            // alone contributes no whitespace token (Syntax 3 §4.3.2).
            if (!self.whitespace) return error.Invalid;
            _ = self.next();
            _ = self.peek();
            if (!self.whitespace) return error.Invalid;
            var rhs = try self.product();
            if (token.value[0] == '-') rhs = try self.builder.operation(.negate, &.{rhs});
            try list.append(self.builder.allocator, rhs);
        }
        return self.builder.operation(.sum, list.items);
    }

    fn product(self: *Parser) Error!*Node {
        var list: std.ArrayList(*Node) = .empty;
        try list.append(self.builder.allocator, try self.primary());
        while (true) {
            const token = self.peek();
            if (token.token_type != .delim or !(std.mem.eql(u8, token.value, "*") or std.mem.eql(u8, token.value, "/"))) break;
            _ = self.next();
            var rhs = try self.primary();
            if (token.value[0] == '/') rhs = try self.builder.operation(.invert, &.{rhs});
            try list.append(self.builder.allocator, rhs);
        }
        return self.builder.operation(.product, list.items);
    }

    fn primary(self: *Parser) Error!*Node {
        try self.nested();
        defer self.depth -= 1;
        const token = self.peek();
        if (token.token_type == .function) return self.function();
        _ = self.next();
        switch (token.token_type) {
            .left_paren => {
                const result = try self.sum();
                try self.require(.right_paren);
                return result;
            },
            .number, .percentage, .dimension => {
                var value = token.numeric_value orelse return error.Invalid;
                if (value == 0) value = 0; // literal -0 is positive zero (§10.9.2)
                const unit: Unit = switch (token.token_type) {
                    .number => .number,
                    .percentage => .percent,
                    else => Unit.parse(token.unit orelse return error.Invalid) orelse return error.Invalid,
                };
                return self.builder.numeric(.{ .value = value, .unit = unit });
            },
            .ident => {
                const constants = .{ .{ "e", std.math.e }, .{ "pi", std.math.pi }, .{ "infinity", std.math.inf(f64) }, .{ "-infinity", -std.math.inf(f64) }, .{ "nan", std.math.nan(f64) } };
                inline for (constants) |constant| if (tokens.nameEql(token.value, constant[0]))
                    return self.builder.numeric(.{ .value = constant[1], .unit = .number });
                return error.Invalid;
            },
            else => return error.Invalid,
        }
    }
};

const Builder = struct {
    allocator: Allocator,
    hint: Base,
    context: ?Context = null,

    fn numeric(self: *Builder, raw: Numeric) Allocator.Error!*Node {
        var number = raw;
        if (number.unit.absoluteScale()) |scale| {
            number.value *= scale;
            number.unit = number.unit.canonical();
        }
        if (self.context) |context| number = context.resolve(number);
        var typ = Type.one(number.unit.base());
        if (number.unit == .percent) typ = typ.withHint(self.hint);
        const node = try self.allocator.create(Node);
        node.* = .{ .tag = .numeric, .numeric = number, .typ = typ };
        return node;
    }

    fn operation(self: *Builder, tag: Node.Tag, children: []const *Node) Error!*Node {
        if (children.len == 0) return error.Invalid;
        if (children.len == 1 and (tag == .sum or tag == .product)) return children[0];
        var typ = children[0].typ;
        switch (tag) {
            .numeric, .anchor => unreachable,
            .negate => {},
            .invert => typ = typ.invert(),
            .product => for (children[1..]) |child| {
                typ = try Type.multiply(typ, child.typ);
            },
            else => for (children[1..]) |child| {
                typ = try Type.add(typ, child.typ);
            },
        }
        const node = try self.allocator.create(Node);
        node.* = .{ .tag = tag, .typ = typ, .children = try self.allocator.dupe(*Node, children) };
        return node;
    }

    fn copy(self: *Builder, old: *const Node) Allocator.Error!*Node {
        if (old.tag == .numeric) return self.numeric(old.numeric);
        const node = try self.allocator.create(Node);
        node.* = .{ .tag = old.tag, .typ = old.typ, .anchor = old.anchor, .children = try self.allocator.alloc(*Node, old.children.len) };
        if (old.tag == .anchor and old.anchor.name.len > 0) node.anchor.name = try self.allocator.dupe(u8, old.anchor.name);
        for (old.children, node.children) |child, *target| target.* = try self.copy(child);
        return self.simplify(node);
    }

    fn simplify(self: *Builder, root: *Node) Allocator.Error!*Node {
        // Values 4 §10.10.1 steps 1–3. Parsing normalizes absolute units;
        // copy() supplies computed context before this recursive pass.
        if (root.tag == .numeric) return root;
        if (root.tag == .anchor) {
            // An anchor side is a pure percentage even when the containing
            // inset's percentages are lengths. Its comparisons are resolvable.
            const hint = self.hint;
            defer self.hint = hint;
            for (root.children, 0..) |*child, index| {
                self.hint = if (root.anchor.percentage and index == 0) .percent else .length;
                child.* = try self.simplify(child.*);
            }
            return root;
        }
        for (root.children) |*child| child.* = try self.simplify(child.*);
        switch (root.tag) {
            .numeric => unreachable,
            .anchor => return root, // Resolving the anchor needs layout (Q15).
            .min, .max, .clamp => return self.comparison(root),
            .negate => {
                const child = root.children[0];
                if (child.tag == .numeric) return self.numeric(.{ .value = -child.numeric.value, .unit = child.numeric.unit });
                if (child.tag == .negate) return child.children[0];
                if (child.tag == .sum) {
                    for (child.children) |*term| {
                        const negated = try self.uncheckedOperation(.negate, &.{term.*}, term.*.typ);
                        term.* = try self.simplify(negated);
                    }
                    return child;
                }
                return root;
            },
            .invert => {
                const child = root.children[0];
                if (child.tag == .numeric and child.numeric.unit == .number)
                    return self.numeric(.{ .value = 1.0 / child.numeric.value, .unit = .number });
                if (child.tag == .invert) return child.children[0];
                return root;
            },
            .sum, .product => {
                // Steps 8.1/9.1: flatten while preserving the original order.
                var list: std.ArrayList(*Node) = .empty;
                for (root.children) |child| {
                    if (child.tag == root.tag) try list.appendSlice(self.allocator, child.children) else try list.append(self.allocator, child);
                }
                root.children = list.items;
                var i: usize = 0;
                while (i < list.items.len) : (i += 1) {
                    const child = list.items[i];
                    if (child.tag != .numeric or (root.tag == .product and child.numeric.unit != .number)) continue;
                    var j = i + 1;
                    while (j < list.items.len) {
                        const other = list.items[j];
                        if (other.tag == .numeric and other.numeric.unit == child.numeric.unit) {
                            child.numeric.value = if (root.tag == .sum) child.numeric.value + other.numeric.value else child.numeric.value * other.numeric.value;
                            _ = list.orderedRemove(j);
                        } else j += 1;
                    }
                }
                root.children = list.items;
                if (root.children.len == 1) return root.children[0];
                if (root.tag == .sum) return root;
                // Step 9.3: number × numeric sum distributes, including zeros.
                if (root.children.len == 2) {
                    const a = root.children[0];
                    const b = root.children[1];
                    const number = if (a.tag == .numeric and a.numeric.unit == .number) a else if (b.tag == .numeric and b.numeric.unit == .number) b else null;
                    const sum = if (a.tag == .sum) a else if (b.tag == .sum) b else null;
                    if (number != null and sum != null) {
                        var all_numeric = true;
                        for (sum.?.children) |child| if (child.tag != .numeric) {
                            all_numeric = false;
                            break;
                        };
                        if (all_numeric) {
                            for (sum.?.children) |child| child.numeric.value *= number.?.numeric.value;
                            return sum.?;
                        }
                    }
                }
                // Step 9.4: cancel identical units; unresolved relative units
                // of different kinds must wait for computed/used information.
                var powers: [@typeInfo(Unit).@"enum".fields.len]i16 = .{0} ** @typeInfo(Unit).@"enum".fields.len;
                var product: f64 = 1;
                for (root.children) |child| {
                    const invert = child.tag == .invert;
                    const term = if (invert) child.children[0] else child;
                    if (term.tag != .numeric) return root;
                    product *= if (invert) 1.0 / term.numeric.value else term.numeric.value;
                    if (term.numeric.unit != .number) powers[@intFromEnum(term.numeric.unit)] += if (invert) @as(i16, -1) else 1;
                }
                var unit: Unit = .number;
                for (powers, 0..) |power, index| {
                    if (power == 0) continue;
                    if (power != 1 or unit != .number) return root;
                    unit = @enumFromInt(index);
                }
                return self.numeric(.{ .value = product, .unit = unit });
            },
        }
    }

    fn uncheckedOperation(self: *Builder, tag: Node.Tag, children: []const *Node, typ: Type) Allocator.Error!*Node {
        const node = try self.allocator.create(Node);
        node.* = .{ .tag = tag, .typ = typ, .children = try self.allocator.dupe(*Node, children) };
        return node;
    }

    fn comparable(self: *const Builder, number: Numeric) bool {
        // §10.10.1 steps 4–5: unresolved percentages can have negative bases.
        return number.unit != .percent or self.hint == .percent;
    }

    fn comparison(self: *Builder, root: *Node) Allocator.Error!*Node {
        if (root.tag == .clamp) {
            const a = root.children[0];
            const b = root.children[1];
            const c = root.children[2];
            if (a.tag == .numeric and b.tag == .numeric and c.tag == .numeric and
                a.numeric.unit == b.numeric.unit and a.numeric.unit == c.numeric.unit and self.comparable(a.numeric))
                return self.numeric(.{ .value = maximum(a.numeric.value, minimum(b.numeric.value, c.numeric.value)), .unit = a.numeric.unit });
            return root;
        }
        var list = std.ArrayList(*Node){ .items = root.children, .capacity = root.children.len };
        var i: usize = 0;
        while (i < list.items.len) : (i += 1) {
            const child = list.items[i];
            if (child.tag != .numeric or !self.comparable(child.numeric)) continue;
            var j = i + 1;
            while (j < list.items.len) {
                const other = list.items[j];
                if (other.tag == .numeric and other.numeric.unit == child.numeric.unit) {
                    child.numeric.value = if (root.tag == .min) minimum(child.numeric.value, other.numeric.value) else maximum(child.numeric.value, other.numeric.value);
                    _ = list.orderedRemove(j);
                } else j += 1;
            }
        }
        root.children = list.items;
        return if (list.items.len == 1) list.items[0] else root;
    }
};

fn minimum(a: f64, b: f64) f64 {
    if (std.math.isNan(a) or std.math.isNan(b)) return std.math.nan(f64);
    if (a == 0 and b == 0) return if (std.math.signbit(a) or std.math.signbit(b)) -@as(f64, 0.0) else 0;
    return @min(a, b);
}
fn maximum(a: f64, b: f64) f64 {
    if (std.math.isNan(a) or std.math.isNan(b)) return std.math.nan(f64);
    if (a == 0 and b == 0) return if (std.math.signbit(a) and std.math.signbit(b)) -@as(f64, 0.0) else 0;
    return @max(a, b);
}

fn serializeNumeric(number: Numeric, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    const values = @import("style_values.zig");
    try values.appendNumber(number.value, out, allocator);
    if (!std.math.isFinite(number.value) and number.unit != .number) try out.appendSlice(allocator, " * 1");
    try out.appendSlice(allocator, number.unit.name());
}

fn serializeFunction(root: *const Node, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    if (root.tag == .anchor) return serializeAnchor(root, out, allocator);
    const comparison = root.tag == .min or root.tag == .max or root.tag == .clamp;
    try out.appendSlice(allocator, if (comparison) @tagName(root.tag) else "calc");
    try out.append(allocator, '(');
    if (comparison) {
        for (root.children, 0..) |child, i| {
            if (i > 0) try out.appendSlice(allocator, ", ");
            try serializeTree(child, false, out, allocator);
        }
    } else if (root.tag == .numeric and !std.math.isFinite(root.numeric.value)) {
        // §10.13 function step 3. Inner numeric leaves retain their unit;
        // only a function which itself represents a non-finite value uses
        // its type's canonical unit (calc-infinity-nan-serialize-length).
        try serializeNumeric(.{ .value = root.numeric.value, .unit = root.numeric.unit.canonical() }, out, allocator);
    } else try serializeTree(root, false, out, allocator);
    try out.append(allocator, ')');
}

fn order(_: void, a: *Node, b: *Node) bool {
    const a_rank: u8 = if (a.tag != .numeric) 3 else switch (a.numeric.unit) {
        .number => 0,
        .percent => 1,
        else => 2,
    };
    const b_rank: u8 = if (b.tag != .numeric) 3 else switch (b.numeric.unit) {
        .number => 0,
        .percent => 1,
        else => 2,
    };
    if (a_rank != b_rank) return a_rank < b_rank;
    if (a_rank == 2) return std.mem.order(u8, a.numeric.unit.name(), b.numeric.unit.name()) == .lt;
    return false;
}

fn serializeTree(root: *const Node, parentheses: bool, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    if (root.tag == .numeric) return serializeNumeric(root.numeric, out, allocator);
    if (root.tag == .anchor) return serializeAnchor(root, out, allocator);
    if (root.tag == .min or root.tag == .max or root.tag == .clamp) return serializeFunction(root, out, allocator);
    if (parentheses) try out.append(allocator, '(');
    if (root.tag == .negate or root.tag == .invert) {
        try out.appendSlice(allocator, if (root.tag == .negate) "-1 * " else "1 / ");
        try serializeTree(root.children[0], true, out, allocator);
    } else {
        // §10.13: stable sort, without mutating a shared expression.
        const sorted = try allocator.dupe(*Node, root.children);
        defer allocator.free(sorted);
        std.mem.sort(*Node, sorted, {}, order);
        for (sorted, 0..) |child, i| {
            if (i > 0) {
                if (root.tag == .sum and child.tag == .negate) {
                    try out.appendSlice(allocator, " - ");
                    try serializeTree(child.children[0], true, out, allocator);
                    continue;
                }
                if (root.tag == .sum and child.tag == .numeric and child.numeric.value < 0) {
                    try out.appendSlice(allocator, " - ");
                    try serializeNumeric(.{ .value = -child.numeric.value, .unit = child.numeric.unit }, out, allocator);
                    continue;
                }
                if (root.tag == .product and child.tag == .invert) {
                    try out.appendSlice(allocator, " / ");
                    try serializeTree(child.children[0], true, out, allocator);
                    continue;
                }
                try out.appendSlice(allocator, if (root.tag == .sum) " + " else " * ");
            }
            try serializeTree(child, true, out, allocator);
        }
    }
    if (parentheses) try out.append(allocator, ')');
}

fn serializeAnchor(root: *const Node, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    const query = root.anchor;
    try out.appendSlice(allocator, if (query.size) "anchor-size(" else "anchor(");
    if (query.name.len > 0) {
        const name = try @import("serialize.zig").serializeIdentifier(allocator, query.name);
        defer allocator.free(name);
        try out.appendSlice(allocator, name);
        if (query.side != null or query.percentage) try out.append(allocator, ' ');
    }
    if (query.side) |side| try out.appendSlice(allocator, side.name());
    if (query.percentage) {
        if (query.percentage_math) try serializeFunction(root.children[0], out, allocator) else try serializeNumeric(root.children[0].numeric, out, allocator);
    }
    if (query.fallback) {
        if (query.name.len > 0 or query.side != null or query.percentage) try out.appendSlice(allocator, ", ");
        const fallback = root.children[root.children.len - 1];
        if (query.fallback_math) try serializeFunction(fallback, out, allocator) else try serializeNumeric(fallback.numeric, out, allocator);
    }
    try out.append(allocator, ')');
}
