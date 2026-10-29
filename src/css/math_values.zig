//! CSS Values 4 §§9.1, 10.1–13: typed numeric expression trees.
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
    // Q84 Chrome156/Safari27 probe,2026-10-27: full WebIDL long powers.
    // Overflow wraps like Chrome; zero powers remain absent from dictionaries.
    powers: [base_count]i32 = .{0} ** base_count,
    hint: ?Base = null,

    pub fn one(base: ?Base) Type {
        var result = Type{};
        if (base) |b| result.powers[@intFromEnum(b)] = 1;
        return result;
    }

    pub fn withHint(self: Type, hint: Base) Type {
        var result = self;
        if (hint != .percent) {
            result.powers[@intFromEnum(hint)] +%= result.powers[@intFromEnum(Base.percent)];
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

    pub fn add(a0: Type, b0: Type) error{Invalid}!Type {
        var a = a0;
        var b = b0;
        try harmonize(&a, &b);
        if (std.mem.eql(i32, &a.powers, &b.powers)) return a;
        // In CSS calculations every percentage already has a context hint
        // (§10.9), so Typed OM's unhinted-percentage search is unnecessary.
        return error.Invalid;
    }

    pub fn multiply(a0: Type, b0: Type) error{Invalid}!Type {
        var a = a0;
        var b = b0;
        try harmonize(&a, &b);
        for (&a.powers, b.powers) |*power, other| {
            power.* +%= other;
        }
        return a;
    }

    pub fn invert(self: Type) Type {
        var result = self;
        for (&result.powers) |*power| power.* = 0 -% power.*;
        return result;
    }

    fn is(self: Type, base: ?Base) bool {
        for (self.powers, 0..) |power, i| {
            const expected: i32 = if (base != null and i == @intFromEnum(base.?)) 1 else 0;
            if (power != expected) return false;
        }
        return true;
    }

    pub fn eql(a: Type, b: Type) bool {
        return a.hint == b.hint and std.mem.eql(i32, &a.powers, &b.powers);
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
    cqw,
    cqh,
    cqi,
    cqb,
    cqmin,
    cqmax,
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

    pub fn canonical(self: Unit) Unit {
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

    pub fn absoluteScale(self: Unit) ?f64 {
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
pub const Kind = enum { length, length_percentage, percentage, number, number_percentage, integer, length_percentage_number, angle, angle_percentage, time, resolution, flex };

/// Color 5 §4: a channel identifier is a scoped <number> leaf. Its grammar
/// explicitly admits symbols; ordinary property math admits none.
pub const Symbol = enum(u4) {
    r,
    g,
    b,
    h,
    s,
    l,
    w,
    c,
    a,
    x,
    y,
    z,
    alpha,

    pub fn bit(self: Symbol) u16 {
        return @as(u16, 1) << @intFromEnum(self);
    }
    pub fn parse(name: []const u8) ?Symbol {
        inline for (@typeInfo(Symbol).@"enum".fields) |field|
            if (tokens.nameEql(name, field.name)) return @enumFromInt(field.value);
        return null;
    }
};

/// Missing origin channels are zero INSIDE a calculation (Color 5 §4.10).
/// Direct channel references retain missingness in the color value itself.
pub const SymbolValues = struct {
    values: [@typeInfo(Symbol).@"enum".fields.len]f64 = .{0} ** @typeInfo(Symbol).@"enum".fields.len,
};

pub const Grammar = struct {
    kind: Kind,
    minimum: f64 = -std.math.floatMax(f64),
    maximum: f64 = std.math.floatMax(f64),
    /// Typed OM native input distinguishes syntactic ranges from clamps.
    /// Existing CSS parsing/computation/serialization never read these tags.
    minimum_kind: BoundKind = .grammar,
    maximum_kind: BoundKind = .grammar,
    anchor_position: bool = false,
    anchor_size: bool = false,
    allowed_symbols: u16 = 0,

    /// Whether a bound restricts syntax, computed values, or representation.
    pub const BoundKind = enum { grammar, computation, representation };

    fn percentHint(self: Grammar) Base {
        return switch (self.kind) {
            .length_percentage, .length_percentage_number => .length,
            .angle_percentage => .angle,
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
            .angle_percentage => typ.is(.angle) and (typ.hint == null or typ.hint == .angle),
            .time => typ.is(.time) and !has_percent,
            .resolution => typ.is(.resolution) and !has_percent,
            .flex => typ.is(.flex) and !has_percent,
        };
    }
};

/// Only information available without layout. null percentage_basis means
/// that a percentage remains a percentage, including a zero percentage.
/// Values 5 §10: scalar DOM sibling information, never a retained node.
pub const TreeCounts = struct { index: usize, count: usize };

const random = @import("random_values.zig");

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
    tree_counts: ?TreeCounts = null,
    /// Pending substitution keys ask lazily, after branch selection. The
    /// borrowed provider caches at the cascade boundary and never escapes.
    tree_count_provider: ?struct { context: *anyopaque, get: *const fn (*anyopaque) TreeCounts } = null,
    /// Borrowed only for compute(); resulting leaves own their scalar value.
    symbols: ?*const SymbolValues = null,
    /// Q83/Q84: callers preflight needsRandomBase(). Missing input skips a
    /// cascade candidate; it never manufactures a draw or a computed key.
    random_base: ?random.Provider = null,

    pub const ContainerAxis = enum { width, height, inline_axis, block_axis };
    pub const ContainerEligibility = enum { no_eligible_container };

    /// Conditional5 §7, per-axis query-container selection. container-type
    /// is unsupported, so no element currently establishes a query container;
    /// elementless contexts have the same default. The container-queries row
    /// must add eligible-but-geometry-unavailable IN THE SAME COMMIT as
    /// container-type support: retain the unresolved length, or skip a scalar
    /// through the cascade's single unavailable-input predicate (Q25/Q96).
    pub fn containerEligibility(self: Context, axis: ContainerAxis) ContainerEligibility {
        _ = self;
        _ = axis;
        return .no_eligible_container;
    }

    fn containerScale(self: Context, axis: ContainerAxis) f64 {
        return switch (self.containerEligibility(axis)) {
            .no_eligible_container => switch (axis) {
                .width => self.viewport_width,
                .height => self.viewport_height,
                .inline_axis => if (self.viewport_vertical) self.viewport_height else self.viewport_width,
                .block_axis => if (self.viewport_vertical) self.viewport_width else self.viewport_height,
            } / 100,
        };
    }

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
            .cqw => self.containerScale(.width),
            .cqh => self.containerScale(.height),
            .cqi => self.containerScale(.inline_axis),
            .cqb => self.containerScale(.block_axis),
            .cqmin => @min(self.containerScale(.inline_axis), self.containerScale(.block_axis)),
            .cqmax => @max(self.containerScale(.inline_axis), self.containerScale(.block_axis)),
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

const Function = enum {
    round,
    mod,
    rem,
    sin,
    cos,
    tan,
    asin,
    acos,
    atan,
    atan2,
    pow,
    sqrt,
    hypot,
    log,
    exp,
    abs,
    sign,
    progress,

    fn parse(name: []const u8) ?Function {
        inline for (@typeInfo(Function).@"enum".fields) |field|
            if (tokens.nameEql(name, field.name)) return @enumFromInt(field.value);
        return null;
    }
};
const Rounding = enum {
    nearest,
    up,
    down,
    to_zero,

    fn name(self: Rounding) []const u8 {
        return if (self == .to_zero) "to-zero" else @tagName(self);
    }
    fn parse(token: tokens.Token) ?Rounding {
        if (token.token_type != .ident) return null;
        inline for (@typeInfo(Rounding).@"enum".fields) |field| {
            const value: Rounding = @enumFromInt(field.value);
            if (tokens.nameEql(token.value, value.name())) return value;
        }
        return null;
    }
};

const Random = struct {
    // The arena owns both the descriptor and all key strings. Child zero
    // is the fixed number, or an unused zero until a cached base is drawn.
    key: ?random.CacheKey = null,
    fixed_math: bool = false,
};

pub const Node = struct {
    tag: Tag,
    typ: Type,
    numeric: Numeric = .{ .value = 0, .unit = .number },
    children: []*Node = &.{},
    anchor: Anchor = .{},
    function_kind: Function = .abs,
    rounding: Rounding = .nearest,
    no_clamp: bool = false,
    symbol: Symbol = .r,
    random_data: ?*Random = null,
    pub const Tag = enum { random, symbol, numeric, sum, product, negate, invert, min, max, clamp, anchor, function, sibling_index, sibling_count };

    fn eql(a: *const Node, b: *const Node) bool {
        if (a.tag != b.tag or !a.typ.eql(b.typ) or a.children.len != b.children.len) return false;
        if (a.tag == .random) {
            const x = a.random_data.?;
            const y = b.random_data.?;
            if ((x.key == null) != (y.key == null) or x.fixed_math != y.fixed_math) return false;
            if (x.key) |key| if (!key.eql(y.key.?)) return false;
        }
        if (a.tag == .anchor and !a.anchor.eql(b.anchor)) return false;
        if (a.tag == .symbol and a.symbol != b.symbol) return false;
        if (a.tag == .function and (a.function_kind != b.function_kind or a.rounding != b.rounding or a.no_clamp != b.no_clamp)) return false;
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

    fn needsRandomBase(self: *const Node) bool {
        if (self.tag == .random and self.random_data.?.key != null) return true;
        for (self.children) |child| if (child.needsRandomBase()) return true;
        return false;
    }

    fn needsTreeCounts(self: *const Node) bool {
        if (self.tag == .sibling_index or self.tag == .sibling_count) return true;
        for (self.children) |child| if (child.needsTreeCounts()) return true;
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

    pub fn needsRandomBase(self: *const Expression) bool {
        return self.root.needsRandomBase();
    }

    pub fn needsTreeCounts(self: *const Expression) bool {
        return self.root.needsTreeCounts();
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
        // Q100 / CSSWG #3482: all three browsers canonicalize this computed
        // length-percentage value, after §10.10.1's ordinary simplification.
        // Keep specified and nested sums, percentage zero, and the original
        // type/hint. Unresolved functions or lengths cannot take this path.
        if (result.typ.is(.length) and result.typ.hint == .length and result.root.tag == .sum and result.root.children.len == 2) {
            const a = result.root.children[0];
            const b = result.root.children[1];
            if (a.tag == .numeric and b.tag == .numeric) {
                if (a.numeric.unit == .percent and b.numeric.unit == .px and b.numeric.value == 0) {
                    result.root = a;
                } else if (b.numeric.unit == .percent and a.numeric.unit == .px and a.numeric.value == 0) {
                    result.root = b;
                }
            }
        }
        return result;
    }

    /// Clone before negating: simplify() may rewrite child arrays, so a new
    /// owner must never negate a tree borrowed from another expression.
    pub fn negated(self: *const Expression, allocator: Allocator) Allocator.Error!*Expression {
        const result = try create(allocator, self.grammar);
        errdefer result.unref();
        result.typ = self.typ;
        result.computed = self.computed;
        result.wrapper = self.wrapper;
        var builder = Builder{ .allocator = result.arena.allocator(), .hint = self.grammar.percentHint() };
        const child = try builder.copy(self.root);
        const root = try builder.uncheckedOperation(.negate, &.{child}, self.typ);
        result.root = try builder.simplify(root);
        return result;
    }

    /// A fully simplified canonical scalar, before property range/NaN/zero
    /// handling. Owning grammars such as easing need this for parse-time
    /// bounds without inventing a font size or resolving a length percentage.
    pub fn knownNumber(self: *const Expression) ?Numeric {
        if (self.root.tag != .numeric) return null;
        const number = self.root.numeric;
        if (number.unit.absoluteScale() == null) return null;
        if (number.unit == .percent and self.typ.hint != .percent) return null;
        return number;
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

pub const ComposeOperation = enum { add, sub };

/// Compose borrowed, immutable operands without serializing or reparsing.
/// The new specified calculation owns every node and preserves the operands'
/// percentage hints. Only the destination grammar clamps the outer result;
/// operand ranges do not become hidden internal clamps.
pub fn compose(allocator: Allocator, grammar: Grammar, operation: ComposeOperation, lhs: *const Expression, rhs: *const Expression) Allocator.Error!?*Expression {
    const typ = Type.add(lhs.typ, rhs.typ) catch return null;
    if (!grammar.accepts(typ)) return null;
    const result = try Expression.create(allocator, grammar);
    errdefer result.unref();
    var builder = Builder{ .allocator = result.arena.allocator(), .hint = grammar.percentHint() };
    const left = try builder.copy(lhs.root);
    var right = try builder.copy(rhs.root);
    if (operation == .sub) right = try builder.uncheckedOperation(.negate, &.{right}, rhs.typ);
    const root = try builder.uncheckedOperation(.sum, &.{ left, right }, typ);
    result.typ = typ;
    result.root = try builder.simplify(root);
    return result;
}

pub const Parsed = struct { expression: *Expression, consumed: usize };

pub fn isFunction(token: tokens.Token) bool {
    if (token.token_type != .function) return false;
    inline for (.{ "calc", "min", "max", "clamp", "anchor", "anchor-size", "sibling-index", "sibling-count", "random" }) |name| if (tokens.nameEql(token.value, name)) return true;
    return Function.parse(token.value) != null;
}

/// Parse one function at the beginning of text; leave following shorthand
/// components to the caller. Invalid syntax/type returns null; OOM propagates.
pub fn parse(allocator: Allocator, text: []const u8, grammar: Grammar) Allocator.Error!?Parsed {
    return parseWithScope(allocator, text, grammar, null);
}

/// The scope is borrowed only during parsing. Context-free callers may use
/// explicit named, element-scoped or fixed keys; property-dependent keys
/// require an actual declaration scope (Q90), never a synthetic property.
pub fn parseWithScope(allocator: Allocator, text: []const u8, grammar: Grammar, scope: ?*const random.ParseScope) Allocator.Error!?Parsed {
    const expression = try Expression.create(allocator, grammar);
    errdefer expression.unref();
    var parser = Parser{
        .builder = .{ .allocator = expression.arena.allocator(), .hint = grammar.percentHint() },
        .tokenizer = tokens.Tokenizer.init(text),
        .anchor_position = grammar.anchor_position,
        .anchor_size = grammar.anchor_size,
        .allowed_symbols = grammar.allowed_symbols,
        .random_scope = scope,
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

/// A context-free calculation owns the same parser's tree without a
/// property's Grammar, bounds, percentage basis, or computation context.
pub const NumericExpression = struct {
    allocator: Allocator,
    arena: std.heap.ArenaAllocator,
    root: *Node = undefined,

    pub fn deinit(self: *NumericExpression) void {
        const allocator = self.allocator;
        self.arena.deinit();
        allocator.destroy(self);
    }
};

/// Typed OM §4.3.1 parse steps 1–4, using this module's Parser/Builder.
/// Chrome 156 / Safari 27 probes, 2026-10-27 (liaison Q22/Q23): both
/// reject newer top-level functions and retain unhinted percentage minima.
/// Ties follow Values 4 §10.10.1 steps 6.1/8.3: simplify FIRST, then reify
/// surviving nodes (§5.6), folding numeric Negate and singleton Sum.
pub fn parseNumeric(allocator: Allocator, text: []const u8) Allocator.Error!?*NumericExpression {
    const expression = try allocator.create(NumericExpression);
    expression.* = .{ .allocator = allocator, .arena = std.heap.ArenaAllocator.init(allocator) };
    errdefer expression.deinit();
    var parser: Parser = .{
        .builder = .{ .allocator = expression.arena.allocator(), .hint = .percent, .context_free = true },
        .tokenizer = tokens.Tokenizer.init(text),
    };
    const token = parser.peek();
    switch (token.token_type) {
        .number, .percentage, .dimension => parser.builder.preserve_units = true,
        .function => {
            if (!tokens.nameEql(token.value, "calc") and !tokens.nameEql(token.value, "min") and
                !tokens.nameEql(token.value, "max") and !tokens.nameEql(token.value, "clamp"))
            {
                expression.deinit();
                return null;
            }
        },
        else => {
            expression.deinit();
            return null;
        },
    }
    const root = parser.primary() catch |err| switch (err) {
        error.Invalid => {
            expression.deinit();
            return null;
        },
        error.OutOfMemory => return error.OutOfMemory,
    };
    if (parser.next().token_type != .eof) {
        expression.deinit();
        return null;
    }
    expression.root = try parser.builder.simplify(root);
    return expression;
}

/// A borrowed Typed OM tree, converted by the property's existing grammar.
/// §5.3 internal representation: an in-range unit stays unwrapped; math
/// values and grammar-range violations acquire the calculation wrapper.
/// The source is never mutated. Q36/Q40 (Chrome 156, Safari 27, 2026-10-27)
/// distinguish grammar bounds from computation and representation clamps.
pub fn fromTypedNumeric(allocator: Allocator, source: *const NumericExpression, is_unit: bool, grammar: Grammar) Allocator.Error!?*Expression {
    const expression = try Expression.create(allocator, grammar);
    errdefer expression.unref();
    var builder = Builder{
        .allocator = expression.arena.allocator(),
        .hint = grammar.percentHint(),
        .preserve_units = is_unit,
    };
    const Frame = struct { source: *const Node, next: usize = 0, base: usize };
    var stack: std.ArrayList(Frame) = .empty;
    defer stack.deinit(allocator);
    var completed: std.ArrayList(*Node) = .empty;
    defer completed.deinit(allocator);
    try stack.append(allocator, .{ .source = source.root, .base = 0 });
    while (stack.items.len != 0) {
        const top = &stack.items[stack.items.len - 1];
        if (top.next < top.source.children.len) {
            const child = top.source.children[top.next];
            top.next += 1;
            try stack.append(allocator, .{ .source = child, .base = completed.items.len });
            continue;
        }
        const root = switch (top.source.tag) {
            .numeric => try builder.numeric(top.source.numeric),
            .sum, .product, .negate, .invert, .min, .max, .clamp => builder.operation(top.source.tag, completed.items[top.base..]) catch |err| switch (err) {
                error.Invalid => {
                    expression.unref();
                    return null;
                },
                error.OutOfMemory => return error.OutOfMemory,
            },
            else => {
                expression.unref();
                return null;
            },
        };
        root.no_clamp = top.source.no_clamp;
        completed.shrinkRetainingCapacity(top.base);
        try completed.append(allocator, root);
        _ = stack.pop();
    }
    const root = completed.items[0];
    if (!grammar.accepts(root.typ)) {
        expression.unref();
        return null;
    }
    expression.typ = root.typ;
    expression.root = try builder.simplify(root);
    expression.wrapper = !is_unit;
    if (is_unit) {
        std.debug.assert(root.tag == .numeric);
        const raw = root.numeric.value;
        const n = raw * (root.numeric.unit.absoluteScale() orelse 1);
        // Fractions in an <integer> context round only at computed time.
        // Percentages use their native scale for grammar bounds. Existing
        // percent-capable grammars only have a zero grammar minimum.
        // Q81: derived non-finite units remain real numeric values, but
        // a property writes them through the existing calculation wrapper.
        expression.wrapper = !std.math.isFinite(raw) or (grammar.minimum_kind == .grammar and n < grammar.minimum) or
            (grammar.maximum_kind == .grammar and n > grammar.maximum) or
            (grammar.kind == .integer and @floor(raw) != raw);
    }
    return expression;
}

/// CSS Values 4 §10.8: TEXT counts nested parser calls (function and
/// primary); PROPERTY input counts non-unit operation depth (Q85/Q89).
pub const calculation_max_depth: usize = 128;
/// CSS Values 4 §10.8: TEXT counts total parser calls; PROPERTY input
/// counts expanded non-unit operation occurrences, including DAG repeats.
pub const calculation_max_nodes: usize = 4096;

const Parser = struct {
    builder: Builder,
    tokenizer: tokens.Tokenizer,
    peeked: ?tokens.Token = null,
    whitespace: bool = false,
    depth: usize = 0,
    count: usize = 0,
    anchor_position: bool = false,
    anchor_size: bool = false,
    allowed_symbols: u16 = 0,
    random_scope: ?*const random.ParseScope = null,

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
        if (self.depth > calculation_max_depth or self.count > calculation_max_nodes) return error.Invalid;
    }

    fn function(self: *Parser) Error!*Node {
        try self.nested();
        defer self.depth -= 1;
        const token = self.next();
        if (!isFunction(token)) return error.Invalid;
        try self.require(.left_paren);
        if (tokens.nameEql(token.value, "random")) return self.randomFunction(token.value);
        // Values 5 §10: both functions have zero arguments and number type.
        if (tokens.nameEql(token.value, "sibling-index") or tokens.nameEql(token.value, "sibling-count")) {
            try self.require(.right_paren);
            const node = try self.builder.allocator.create(Node);
            node.* = .{ .tag = if (tokens.nameEql(token.value, "sibling-index")) .sibling_index else .sibling_count, .typ = Type.one(null) };
            return node;
        }
        if (tokens.nameEql(token.value, "anchor") or tokens.nameEql(token.value, "anchor-size"))
            return self.anchorFunction(tokens.nameEql(token.value, "anchor-size"));
        if (tokens.nameEql(token.value, "calc")) {
            const result = try self.sum();
            try self.require(.right_paren);
            return self.checkedFunction(result);
        }
        if (Function.parse(token.value)) |kind| return self.numericFunction(kind);
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
            if (missing[0] and missing[2]) return self.checkedFunction(list.items[1]);
            if (missing[0]) return self.checkedFunction(try self.builder.operation(.min, list.items[1..]));
            if (missing[2]) return self.checkedFunction(try self.builder.operation(.max, list.items[0..2]));
            return self.checkedFunction(try self.builder.operation(.clamp, list.items));
        }
        return self.checkedFunction(try self.builder.operation(if (tokens.nameEql(token.value, "min")) .min else .max, list.items));
    }

    /// Values5 §9.1: the optional cache key precedes two or three calc-sums.
    /// Q82/Q90 assign every source ordinal before visiting these children.
    fn randomFunction(self: *Parser, function_token: []const u8) Error!*Node {
        const source = if (self.random_scope) |scope| scope.sourceFor(function_token) else null;
        const data = try self.builder.allocator.create(Random);
        data.* = .{};
        var base: *Node = undefined;
        const first = self.peek();
        if (first.token_type == .ident and tokens.nameEql(first.value, "fixed")) {
            _ = self.next();
            const fixed_token = self.peek();
            data.fixed_math = isFunction(fixed_token);
            if (!data.fixed_math and fixed_token.token_type != .number) return error.Invalid;
            base = try self.primary();
            if (!base.typ.is(null) or base.typ.hint != null) return error.Invalid;
            if (!data.fixed_math and (base.numeric.value < 0 or base.numeric.value > 1)) return error.Invalid;
            try self.require(.comma);
        } else {
            var key_text: ?[]const u8 = null;
            const decoded_first = if (first.token_type == .ident) try tokens.decode(self.builder.allocator, first.value) else "";
            const key_start = first.token_type == .ident and
                (tokens.nameEql(first.value, "auto") or tokens.nameEql(first.value, "element-scoped") or
                    tokens.nameEql(first.value, "property-scoped") or tokens.nameEql(first.value, "property-index-scoped") or
                    std.mem.startsWith(u8, decoded_first, "--") or std.mem.startsWith(u8, decoded_first, "ua-"));
            if (key_start) {
                while (true) {
                    const token = self.next();
                    if (token.token_type == .comma) {
                        const length = @intFromPtr(token.value.ptr) - @intFromPtr(first.value.ptr);
                        key_text = first.value.ptr[0..length];
                        break;
                    }
                    if (token.token_type != .ident) return error.Invalid;
                }
            }
            data.key = try random.parseCacheKey(self.builder.allocator, key_text, source) orelse return error.Invalid;
            base = try self.builder.numeric(.{ .value = 0, .unit = .number });
        }
        const lower = try self.sum();
        try self.require(.comma);
        const upper = try self.sum();
        var typ = Type.add(lower.typ, upper.typ) catch return error.Invalid;
        var step: ?*Node = null;
        if (self.peek().token_type == .comma) {
            _ = self.next();
            step = try self.sum();
            typ = Type.add(typ, step.?.typ) catch return error.Invalid;
        }
        try self.require(.right_paren);
        const children = try self.builder.allocator.alloc(*Node, if (step != null) 4 else 3);
        children[0] = base;
        children[1] = lower;
        children[2] = upper;
        if (step) |increment| children[3] = increment;
        const node = try self.builder.allocator.create(Node);
        node.* = .{ .tag = .random, .typ = typ, .children = children, .random_data = data };
        return self.builder.simplify(node);
    }

    /// Values 4 §§10.3–10.6, 10.8–10.9: validate each argument before
    /// simplification, then derive the output type and its percentage hint.
    fn numericFunction(self: *Parser, kind: Function) Error!*Node {
        var rounding: Rounding = .nearest;
        if (kind == .round) if (Rounding.parse(self.peek())) |strategy| {
            rounding = strategy;
            _ = self.next();
            try self.require(.comma);
        };
        // Values5 §5: no-clamp precedes the first calc-sum, without a comma.
        const no_clamp = kind == .progress and self.peek().token_type == .ident and tokens.nameEql(self.peek().value, "no-clamp");
        if (no_clamp) _ = self.next();
        var list: std.ArrayList(*Node) = .empty;
        while (true) {
            const argument = try self.checkedFunction(try self.sum());
            try list.append(self.builder.allocator, argument);
            if (list.items.len > 4096) return error.Invalid;
            const separator = self.next().token_type;
            if (separator == .right_paren or separator == .eof) break;
            if (separator != .comma) return error.Invalid;
        }
        const count = list.items.len;
        switch (kind) {
            .round, .log => if (count != 1 and count != 2) return error.Invalid,
            .mod, .rem, .atan2, .pow => if (count != 2) return error.Invalid,
            .progress => if (count != 3) return error.Invalid,
            .hypot => {},
            else => if (count != 1) return error.Invalid,
        }
        var input_type = list.items[0].typ;
        for (list.items[1..]) |child| input_type = try self.builder.addTypes(input_type, child.typ);
        switch (kind) {
            .sin, .cos, .tan => if (!input_type.is(null) and !input_type.is(.angle)) return error.Invalid,
            .asin, .acos, .atan, .pow, .sqrt, .log, .exp => if (!input_type.is(null)) return error.Invalid,
            else => {},
        }
        if (kind == .round and count == 1) {
            if (!input_type.is(null)) return error.Invalid;
            try list.append(self.builder.allocator, try self.builder.numeric(.{ .value = 1, .unit = .number }));
        }
        var output_type = switch (kind) {
            .asin, .acos, .atan, .atan2 => Type.one(.angle),
            .sign, .sin, .cos, .tan, .pow, .sqrt, .log, .exp, .progress => Type.one(null),
            else => input_type,
        };
        // §10.9 "make a type consistent": retain the input hint without
        // changing the output exponents, including hints on unitless ratios.
        output_type.hint = input_type.hint;
        // A progress ratio of pure percentages is a number. .percent is
        // our marker for percentages with no dimensional context, not a
        // length/angle hint to carry into the result (Values5 §5).
        if (kind == .progress and output_type.hint == .percent) output_type.hint = null;
        const node = try self.builder.allocator.create(Node);
        node.* = .{ .tag = .function, .function_kind = kind, .rounding = rounding, .no_clamp = no_clamp, .typ = output_type, .children = list.items };
        return self.checkedFunction(node);
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

    fn checkedFunction(self: *const Parser, node: *Node) error{Invalid}!*Node {
        // §10.9: each math function must resolve to a CSS numeric type.
        // Parenthesized arithmetic may have compound intermediate units.
        if (self.builder.context_free or node.typ.is(null)) return node;
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
                // Q65: C156/F158/S27 preserve literal -0 inside calculations
                // (signs-abs-computed.html), despite §10.9.2. Only the outer
                // computedNumber boundary censors its sign.
                const value = token.numeric_value orelse return error.Invalid;
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
                if (Symbol.parse(token.value)) |symbol| {
                    if (self.allowed_symbols & symbol.bit() == 0) return error.Invalid;
                    const node = try self.builder.allocator.create(Node);
                    node.* = .{ .tag = .symbol, .typ = Type.one(null), .symbol = symbol };
                    return node;
                }
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
    context_free: bool = false,
    preserve_units: bool = false,

    fn addTypes(self: *const Builder, a: Type, b: Type) error{Invalid}!Type {
        return if (self.context_free) @import("typed_om/numeric.zig").addTypes(a, b) else Type.add(a, b);
    }

    fn multiplyTypes(self: *const Builder, a: Type, b: Type) error{Invalid}!Type {
        return if (self.context_free) @import("typed_om/numeric.zig").multiplyTypes(a, b) else Type.multiply(a, b);
    }

    fn numeric(self: *Builder, raw: Numeric) Allocator.Error!*Node {
        var number = raw;
        if (!self.preserve_units) {
            if (number.unit.absoluteScale()) |scale| {
                number.value *= scale;
                number.unit = number.unit.canonical();
            }
        }
        if (self.context) |context| number = context.resolve(number);
        var typ = Type.one(number.unit.base());
        if (number.unit == .percent and !self.context_free) typ = typ.withHint(self.hint);
        const node = try self.allocator.create(Node);
        node.* = .{ .tag = .numeric, .numeric = number, .typ = typ };
        return node;
    }

    fn operation(self: *Builder, tag: Node.Tag, children: []const *Node) Error!*Node {
        if (children.len == 0) return error.Invalid;
        if (children.len == 1 and (tag == .sum or tag == .product)) return children[0];
        var typ = children[0].typ;
        switch (tag) {
            .random, .numeric, .symbol, .anchor, .function, .sibling_index, .sibling_count => unreachable,
            .negate => {},
            .invert => typ = if (self.context_free) try @import("typed_om/numeric.zig").invertType(typ) else typ.invert(),
            .product => for (children[1..]) |child| {
                typ = try self.multiplyTypes(typ, child.typ);
            },
            else => for (children[1..]) |child| {
                typ = try self.addTypes(typ, child.typ);
            },
        }
        const node = try self.allocator.create(Node);
        node.* = .{ .tag = tag, .typ = typ, .children = try self.allocator.dupe(*Node, children) };
        return node;
    }

    fn copy(self: *Builder, old: *const Node) Allocator.Error!*Node {
        if (old.tag == .numeric) return self.numeric(old.numeric);
        if (old.tag == .symbol) if (self.context) |context| if (context.symbols) |symbols| {
            return self.numeric(.{ .value = symbols.values[@intFromEnum(old.symbol)], .unit = .number });
        };
        if (old.tag == .sibling_index or old.tag == .sibling_count) if (self.context) |context| {
            const counts: TreeCounts = context.tree_counts orelse (if (context.tree_count_provider) |provider| provider.get(provider.context) else .{ .index = 1, .count = 1 });
            return self.numeric(.{ .value = @floatFromInt(if (old.tag == .sibling_index) counts.index else counts.count), .unit = .number });
        };
        const node = try self.allocator.create(Node);
        node.* = .{ .tag = old.tag, .typ = old.typ, .anchor = old.anchor, .function_kind = old.function_kind, .rounding = old.rounding, .no_clamp = old.no_clamp, .symbol = old.symbol, .children = try self.allocator.alloc(*Node, old.children.len) };
        if (old.tag == .anchor and old.anchor.name.len > 0) node.anchor.name = try self.allocator.dupe(u8, old.anchor.name);
        if (old.tag == .random) {
            const data = try self.allocator.create(Random);
            data.* = .{
                .key = if (old.random_data.?.key) |key| try key.clone(self.allocator) else null,
                .fixed_math = old.random_data.?.fixed_math,
            };
            node.random_data = data;
        }
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
            .symbol, .sibling_index, .sibling_count => return root,
            .min, .max, .clamp => return self.comparison(root),
            .function => return self.numericFunction(root),
            .random => return self.randomFunction(root),
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
                // Step 9.4 cancels identical units. Q105 follows the C/F
                // majority beyond its literal "all children numeric": fold
                // the numeric subset around unresolved factors too. Different
                // unresolved units still wait for computed/used information.
                var powers: [@typeInfo(Unit).@"enum".fields.len]i32 = .{0} ** @typeInfo(Unit).@"enum".fields.len;
                var product: f64 = 1;
                var numeric_count: usize = 0;
                var numeric_type = Type.one(null);
                for (root.children) |child| {
                    const invert = child.tag == .invert;
                    const term = if (invert) child.children[0] else child;
                    if (term.tag != .numeric) continue;
                    numeric_count += 1;
                    const term_type = if (invert and self.context_free) (@import("typed_om/numeric.zig").invertType(term.typ) catch return root) else if (invert) term.typ.invert() else term.typ;
                    numeric_type = self.multiplyTypes(numeric_type, term_type) catch return root;
                    product *= if (invert) 1.0 / term.numeric.value else term.numeric.value;
                    if (term.numeric.unit != .number) powers[@intFromEnum(term.numeric.unit)] +%= if (invert) @as(i32, -1) else 1;
                }
                if (numeric_count == 0) return root;
                var unit: Unit = .number;
                for (powers, 0..) |power, index| {
                    if (power == 0) continue;
                    if (power != 1 or unit != .number) return root;
                    unit = @enumFromInt(index);
                }
                if (numeric_count == root.children.len) return self.numeric(.{ .value = product, .unit = unit });
                if (numeric_count == 1) return root;
                const folded = try self.numeric(.{ .value = product, .unit = unit });
                folded.typ = numeric_type;
                var remaining: std.ArrayList(*Node) = .empty;
                try remaining.ensureTotalCapacity(self.allocator, root.children.len - numeric_count + 1);
                remaining.appendAssumeCapacity(folded);
                for (root.children) |child| {
                    const term = if (child.tag == .invert) child.children[0] else child;
                    if (term.tag != .numeric) remaining.appendAssumeCapacity(child);
                }
                root.children = remaining.items;
                return root;
            },
        }
    }

    /// §10.10.1 step 4; Blink CSSMathExpressionNode::CanEagerlySimplify
    /// likewise waits for canonical units. Relative units may have a zero
    /// basis, so even two equal relative units cannot be treated as px.
    fn numericFunction(self: *Builder, root: *Node) Allocator.Error!*Node {
        const first = root.children[0];
        for (root.children) |child| {
            if (child.tag != .numeric or child.numeric.unit.absoluteScale() == null or
                !self.comparable(child.numeric) or child.numeric.unit != first.numeric.unit) return root;
        }
        const a = first.numeric.value;
        const b = if (root.children.len > 1) root.children[1].numeric.value else @as(f64, 0);
        const kind = root.function_kind;
        var unit = first.numeric.unit;
        const value: f64 = switch (kind) {
            .round, .mod, .rem => stepped(kind, root.rounding, a, b),
            .sin, .cos, .tan => trig(kind, a, unit == .deg),
            .asin => std.math.asin(a) * (180.0 / std.math.pi),
            .acos => std.math.acos(a) * (180.0 / std.math.pi),
            .atan => std.math.atan(a) * (180.0 / std.math.pi),
            .atan2 => std.math.atan2(a, b) * (180.0 / std.math.pi),
            .pow => evaluatePower(a, b),
            .sqrt => @sqrt(a),
            .exp => @exp(a),
            .log => logarithm(a, if (root.children.len == 1) std.math.e else b),
            .abs => @abs(a),
            .sign => if (std.math.isNan(a) or a == 0) a else std.math.copysign(@as(f64, 1), a),
            .progress => calculateProgress(a, b, root.children[2].numeric.value, root.no_clamp),
            .hypot => hypot: {
                var result: f64 = 0;
                // Q65: NaN is infectious, including alongside infinity.
                // Accumulate with hypot's rescaling, not a sum of squares
                // that can overflow before taking the square root.
                for (root.children) |child| if (std.math.isNan(child.numeric.value)) break :hypot std.math.nan(f64);
                for (root.children) |child| result = std.math.hypot(result, child.numeric.value);
                break :hypot result;
            },
        };
        switch (kind) {
            .sin, .cos, .tan, .pow, .sqrt, .log, .exp, .sign, .progress => unit = .number,
            .asin, .acos, .atan, .atan2 => unit = .deg,
            else => {},
        }
        return self.numeric(.{ .value = value, .unit = unit });
    }

    /// Values5 §§9.1.1, 9.3, 9.4.1. Freeze the base before inheritance,
    /// even if a layout percentage prevents the final numeric reduction.
    fn randomFunction(self: *Builder, root: *Node) Allocator.Error!*Node {
        const data = root.random_data.?;
        if (data.key) |key| {
            const context = self.context orelse return root;
            const provider = context.random_base orelse return root;
            root.children[0] = try self.numeric(.{ .value = random.fixedBase(try provider.get(provider.context, key)), .unit = .number });
            data.key = null;
            data.fixed_math = false;
        }
        const base = root.children[0];
        if (base.tag != .numeric) return root;
        const value = random.fixedBase(base.numeric.value);
        if (self.context != null) {
            base.numeric.value = value;
            data.fixed_math = false;
        }
        const lower = root.children[1];
        for (root.children[1..]) |child| {
            if (child.tag != .numeric or child.numeric.unit.absoluteScale() == null or
                child.numeric.unit != lower.numeric.unit or !self.comparable(child.numeric)) return root;
        }
        return self.numeric(.{
            .value = random.evaluate(value, lower.numeric.value, root.children[2].numeric.value, if (root.children.len == 4) root.children[3].numeric.value else null),
            .unit = lower.numeric.unit,
        });
    }

    fn uncheckedOperation(self: *Builder, tag: Node.Tag, children: []const *Node, typ: Type) Allocator.Error!*Node {
        const node = try self.allocator.create(Node);
        node.* = .{ .tag = tag, .typ = typ, .children = try self.allocator.dupe(*Node, children) };
        return node;
    }

    fn comparable(self: *const Builder, number: Numeric) bool {
        // §10.10.1 steps 4–5: unresolved percentages can have negative bases.
        return number.unit != .percent or (!self.context_free and self.hint == .percent);
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

/// Values5 §5: calculating a progress function, including equal endpoints.
fn calculateProgress(value: f64, start: f64, end: f64, no_clamp: bool) f64 {
    if (std.math.isNan(value) or std.math.isNan(start) or std.math.isNan(end)) return std.math.nan(f64);
    if (start == end) {
        if (!no_clamp or value == start) return 0;
        return if (value < start) -std.math.inf(f64) else std.math.inf(f64);
    }
    const result = (value - start) / (end - start);
    return if (no_clamp or std.math.isNan(result)) result else std.math.clamp(result, 0, 1);
}

/// Values 4 §10.3.1: special values precede arithmetic. The finite round
/// path uses remainders to avoid overflowing A/B; this is also the design
/// used by Blink platform/geometry/math_functions.h, independently written.
fn stepped(kind: Function, strategy: Rounding, a: f64, b: f64) f64 {
    const nan = std.math.nan(f64);
    if (std.math.isNan(a) or std.math.isNan(b) or b == 0) return nan;
    if (kind != .round) {
        if (std.math.isInf(a)) return nan;
        const opposite = std.math.signbit(a) != std.math.signbit(b);
        if (std.math.isInf(b)) return if (kind == .mod and opposite) nan else a;
        const rem = @rem(a, b);
        if (kind == .rem) return if (rem == 0) std.math.copysign(@as(f64, 0), a) else rem;
        if (rem == 0) return std.math.copysign(@as(f64, 0), b);
        return if (opposite) rem + b else rem;
    }
    if (std.math.isInf(a)) return if (std.math.isInf(b)) nan else a;
    if (a == 0) return a;
    if (std.math.isInf(b)) return switch (strategy) {
        .nearest, .to_zero => std.math.copysign(@as(f64, 0), a),
        .up => if (a > 0) std.math.inf(f64) else -@as(f64, 0),
        .down => if (a < 0) -std.math.inf(f64) else @as(f64, 0),
    };
    const remainder = @rem(a, @abs(b));
    if (remainder == 0) return a;
    const towards_zero = a - remainder;
    // Add the small quantities before A to preserve the step's fraction.
    const away_zero = a + (std.math.copysign(@abs(b), a) - remainder);
    const lo = if (a < 0) away_zero else towards_zero;
    const hi = if (a < 0) towards_zero else away_zero;
    const result = switch (strategy) {
        .up => hi,
        .down => lo,
        .to_zero => towards_zero,
        .nearest => if (a - lo < hi - a) lo else hi,
    };
    return if (result == 0) std.math.copysign(@as(f64, 0), a) else result;
}

/// §10.4: exact quadrants preserve zero and the specified degree asymptotes;
/// other inputs use the platform trigonometry, with radians for numbers.
fn trig(kind: Function, a: f64, angle: bool) f64 {
    if (!std.math.isFinite(a)) return std.math.nan(f64);
    if (a == 0) return if (kind == .cos) 1 else a;
    if (angle) {
        const degrees = @rem(a, 360);
        if (@rem(degrees, 90) == 0) {
            if (kind == .sin) return if (degrees == 90 or degrees == -270) 1 else if (degrees == -90 or degrees == 270) -1 else 0;
            if (kind == .cos) return if (degrees == 0) 1 else if (@abs(degrees) == 180) -1 else 0;
            return if (degrees == 90 or degrees == -270) std.math.inf(f64) else if (degrees == -90 or degrees == 270) -std.math.inf(f64) else 0;
        }
        if (kind == .tan and @rem(degrees, 45) == 0) return if (@rem(degrees, 180) == 45 or @rem(degrees, 180) == -135) 1 else -1;
    }
    const radians = if (angle) @rem(a, 360) * (std.math.pi / 180.0) else a;
    return switch (kind) {
        .sin => @sin(radians),
        .cos => @cos(radians),
        .tan => std.math.tan(radians),
        else => unreachable,
    };
}

fn evaluatePower(a: f64, b: f64) f64 {
    // Q65: aligned C156/F158/S27 agree on these 1 results despite the
    // infectious-NaN rule, csswg-drafts bfdc89260c (2019-07-30), tested by
    // wpt ab1720909f (2026-09-25). Recheck as browser results change:
    // Chromium main math_functions.h has since adopted the spec rule.
    if (b == 0 or a == 1 or (@abs(a) == 1 and std.math.isInf(b))) return 1;
    return std.math.pow(f64, a, b);
}

fn logarithm(a: f64, base: f64) f64 {
    // Q68: C156/F158/S27 agree on ordinary log(A)/log(B), including
    // base 1 and the sign of zero for A=1, 0<B<1. The spec tables are
    // from 2019 (f1a62a0805, e9e7587b7d), not a newer-rule lag.
    // Recheck when two shipping browsers adopt the spec special values.
    if (std.math.isNan(a) or std.math.isNan(base) or a < 0 or base <= 0) return std.math.nan(f64);
    return @log(a) / @log(base);
}

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
    if (root.tag == .random) return serializeRandom(root, out, allocator);
    if (root.tag == .anchor) return serializeAnchor(root, out, allocator);
    if (root.tag == .sibling_index or root.tag == .sibling_count)
        return out.appendSlice(allocator, if (root.tag == .sibling_index) "sibling-index()" else "sibling-count()");
    const comparison = root.tag == .min or root.tag == .max or root.tag == .clamp;
    try out.appendSlice(allocator, if (root.tag == .function) @tagName(root.function_kind) else if (comparison) @tagName(root.tag) else "calc");
    try out.append(allocator, '(');
    if (comparison or root.tag == .function) {
        if (root.tag == .function and root.function_kind == .progress and root.no_clamp)
            try out.appendSlice(allocator, "no-clamp ");
        if (root.tag == .function and root.function_kind == .round and root.rounding != .nearest) {
            try out.appendSlice(allocator, root.rounding.name());
            try out.appendSlice(allocator, ", ");
        }
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
    if (root.tag == .symbol) return out.appendSlice(allocator, @tagName(root.symbol));
    if (root.tag == .anchor) return serializeAnchor(root, out, allocator);
    if (root.tag == .min or root.tag == .max or root.tag == .clamp or root.tag == .function or root.tag == .random or root.tag == .sibling_index or root.tag == .sibling_count) return serializeFunction(root, out, allocator);
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

fn serializeRandom(root: *const Node, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    try out.appendSlice(allocator, "random(");
    const data = root.random_data.?;
    if (data.key) |key| {
        try key.serialize(out, allocator);
    } else {
        try out.appendSlice(allocator, "fixed ");
        const base = root.children[0];
        if (data.fixed_math or base.tag != .numeric or !std.math.isFinite(base.numeric.value)) {
            try serializeFunction(base, out, allocator);
        } else try serializeNumeric(base.numeric, out, allocator);
    }
    for (root.children[1..]) |child| {
        try out.appendSlice(allocator, ", ");
        try serializeTree(child, false, out, allocator);
    }
    try out.append(allocator, ')');
}
