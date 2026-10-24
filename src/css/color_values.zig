//! CSS Color 4/5: owned, unquantized color expressions. Components and child
//! colors survive declaration teardown; a borrowed Context never escapes.
//! Design references: WebKit CSSRelativeColorResolver and CSSColorMixResolver.
const std = @import("std");
const values = @import("style_values.zig");
const properties = @import("properties.zig");
const math = @import("math_values.zig");
const Number = @import("numeric_values.zig").Number;
const tokens = @import("tokenizer.zig");
const spaces = @import("color_spaces.zig");
const Allocator = std.mem.Allocator;
const Color = values.Color;
const Space = spaces.Space;
const Components = spaces.Components;
const Error = Allocator.Error || error{Invalid};

const Function = enum {
    rgb,
    hsl,
    hwb,
    lab,
    lch,
    oklab,
    oklch,
    color,

    fn parse(name: []const u8) ?Function {
        if (tokens.nameEql(name, "rgba")) return .rgb;
        if (tokens.nameEql(name, "hsla")) return .hsl;
        inline for (@typeInfo(Function).@"enum".fields) |field|
            if (tokens.nameEql(name, field.name)) return @enumFromInt(field.value);
        return null;
    }
    fn space(self: Function) Space {
        return switch (self) {
            .rgb, .color => .srgb,
            .hsl => .hsl,
            .hwb => .hwb,
            .lab => .lab,
            .lch => .lch,
            .oklab => .oklab,
            .oklch => .oklch,
        };
    }
    fn legacy(self: Function) bool {
        return self == .rgb or self == .hsl or self == .hwb;
    }
};

const Component = union(enum) {
    none,
    number: Number,
    channel: math.Symbol,

    fn release(self: Component) void {
        if (self == .number) self.number.unref();
    }
    fn retain(self: Component) void {
        if (self == .number) self.number.ref();
    }
    fn eql(a: Component, b: Component) bool {
        if (std.meta.activeTag(a) != std.meta.activeTag(b)) return false;
        return switch (a) {
            .none => true,
            .channel => |c| c == b.channel,
            .number => |n| n.eql(b.number),
        };
    }
    fn needsTreeCounts(self: Component) bool {
        return self == .number and self.number.needsTreeCounts();
    }

    fn needsRandomBase(self: Component) bool {
        return self == .number and self.number.needsRandomBase();
    }
    fn needsUnavailableMetrics(self: Component, geometry: bool) bool {
        return self == .number and self.number.needsUnavailableMetrics(geometry);
    }
    fn known(self: Component) ?math.Numeric {
        if (self != .number) return null;
        return switch (self.number) {
            .literal => |number| number,
            .calculation => |expression| expression.knownNumber(),
        };
    }

    /// Color4 §15 retains unbounded infinity. The general numeric scalar
    /// adapter clamps to its machine limit, so use the computed tree's raw
    /// canonical number here and apply this component's own range afterward.
    fn compute(self: Component, allocator: Allocator, context: math.Context) Allocator.Error!Component {
        if (self != .number or self.number != .calculation) return self;
        const expression = try self.number.calculation.compute(allocator, context);
        if (expression.knownNumber()) |number| {
            expression.unref();
            return .{ .number = .{ .literal = number } };
        }
        return .{ .number = .{ .calculation = expression } };
    }
    fn serialize(self: Component, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self) {
            .none => try out.appendSlice(allocator, "none"),
            .channel => |symbol| try out.appendSlice(allocator, @tagName(symbol)),
            .number => |number| try number.serialize(out, allocator),
        }
    }
};

const Channels = struct {
    function: Function,
    space: Space,
    origin: ?Color = null,
    components: [4]Component,
    explicit_alpha: bool = false,
    fn release(self: Channels) void {
        if (self.origin) |origin| origin.release();
        for (self.components) |component| component.release();
    }
};
const MixItem = struct { color: Color, weight: ?Number = null };
const Mix = struct {
    space: Space = .oklab,
    hue: spaces.HueMethod = .shorter,
    items: []MixItem,
    fn release(self: Mix, allocator: Allocator) void {
        for (self.items) |item| {
            item.color.release();
            if (item.weight) |weight| weight.unref();
        }
        allocator.free(self.items);
    }
};
const Resolved = struct { value: Components, legacy: bool = false };
const Alpha = struct { origin: Color, override: ?Component = null };
const Data = union(enum) {
    resolved: Resolved,
    channels: Channels,
    mix: Mix,
    light_dark: [2]Color,
    contrast: Color,
    alpha: Alpha,

    fn release(self: Data, allocator: Allocator) void {
        switch (self) {
            .resolved => {},
            .channels => |channels| channels.release(),
            .mix => |mix| mix.release(allocator),
            .light_dark => |pair| for (pair) |color| color.release(),
            .contrast => |color| color.release(),
            .alpha => |alpha| {
                alpha.origin.release();
                if (alpha.override) |component| component.release();
            },
        }
    }
};

pub const Expression = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    data: Data,

    /// Consumes every owned child even when allocation fails.
    fn create(allocator: Allocator, data: Data) Allocator.Error!Color {
        errdefer data.release(allocator);
        const self = try allocator.create(Expression);
        self.* = .{ .allocator = allocator, .data = data };
        if (self.data == .resolved) {
            // Color4 §§15.2–15.3: normalize the final Lab-family value,
            // after Color5's extended relative-channel calculations.
            // Specified expressions and extended RGB/a/b remain unchanged.
            const color = &self.data.resolved.value;
            switch (color.space) {
                .lab, .lch => color.channels[0] = std.math.clamp(color.channels[0], 0, 100),
                .oklab, .oklch => color.channels[0] = std.math.clamp(color.channels[0], 0, 1),
                else => {},
            }
            if (color.space == .lch or color.space == .oklch) color.channels[1] = @max(0, color.channels[1]);
        }
        return .{ .expression = self };
    }
    pub fn ref(self: *Expression) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Expression) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        const allocator = self.allocator;
        self.data.release(allocator);
        allocator.destroy(self);
    }
    pub fn eql(a: *const Expression, b: *const Expression) bool {
        if (a == b) return true;
        if (std.meta.activeTag(a.data) != std.meta.activeTag(b.data)) return false;
        return switch (a.data) {
            .resolved => |r| r.legacy == b.data.resolved.legacy and r.value.eql(b.data.resolved.value),
            .channels => |c| blk: {
                const other = b.data.channels;
                if (c.function != other.function or c.space != other.space or c.explicit_alpha != other.explicit_alpha or !optionalColorEql(c.origin, other.origin)) break :blk false;
                for (c.components, other.components) |x, y| if (!x.eql(y)) break :blk false;
                break :blk true;
            },
            .mix => |mix| blk: {
                const other = b.data.mix;
                if (mix.space != other.space or mix.hue != other.hue or mix.items.len != other.items.len) break :blk false;
                for (mix.items, other.items) |x, y| {
                    if (!x.color.eql(y.color) or (x.weight == null) != (y.weight == null)) break :blk false;
                    if (x.weight) |weight| if (!weight.eql(y.weight.?)) break :blk false;
                }
                break :blk true;
            },
            .light_dark => |pair| pair[0].eql(b.data.light_dark[0]) and pair[1].eql(b.data.light_dark[1]),
            .contrast => |color| color.eql(b.data.contrast),
            .alpha => |alpha| alpha.origin.eql(b.data.alpha.origin) and optionalComponentEql(alpha.override, b.data.alpha.override),
        };
    }
    /// Color dependencies follow the typed graph, without resolving it or
    /// allocating. Numeric components and weights cannot contain a Color.
    /// After light-dark computation only the selected branch remains.
    pub fn containsCurrentColor(self: *const Expression) bool {
        return switch (self.data) {
            .resolved => false,
            .channels => |channels| if (channels.origin) |origin| origin.containsCurrentColor() else false,
            .mix => |mix| blk: {
                for (mix.items) |item| if (item.color.containsCurrentColor()) break :blk true;
                break :blk false;
            },
            .light_dark => |pair| pair[0].containsCurrentColor() or pair[1].containsCurrentColor(),
            .contrast => |color| color.containsCurrentColor(),
            .alpha => |alpha| alpha.origin.containsCurrentColor(),
        };
    }

    pub fn needsTreeCounts(self: *const Expression) bool {
        return switch (self.data) {
            .resolved => false,
            .channels => |channels| blk: {
                if (channels.origin) |origin| if (origin.needsTreeCounts()) break :blk true;
                for (channels.components) |component| if (component.needsTreeCounts()) break :blk true;
                break :blk false;
            },
            .mix => |mix| blk: {
                for (mix.items) |item| {
                    if (item.color.needsTreeCounts()) break :blk true;
                    if (item.weight) |weight| if (weight.needsTreeCounts()) break :blk true;
                }
                break :blk false;
            },
            .light_dark => |pair| pair[0].needsTreeCounts() or pair[1].needsTreeCounts(),
            .contrast => |color| color.needsTreeCounts(),
            .alpha => |alpha| alpha.origin.needsTreeCounts() or (if (alpha.override) |component| component.needsTreeCounts() else false),
        };
    }

    pub fn needsRandomBase(self: *const Expression) bool {
        return switch (self.data) {
            .resolved => false,
            .channels => |channels| blk: {
                if (channels.origin) |origin| if (origin.needsRandomBase()) break :blk true;
                for (channels.components) |component| if (component.needsRandomBase()) break :blk true;
                break :blk false;
            },
            .mix => |mix| blk: {
                for (mix.items) |item| {
                    if (item.color.needsRandomBase()) break :blk true;
                    if (item.weight) |weight| if (weight.needsRandomBase()) break :blk true;
                }
                break :blk false;
            },
            .light_dark => |pair| pair[0].needsRandomBase() or pair[1].needsRandomBase(),
            .contrast => |color| color.needsRandomBase(),
            .alpha => |alpha| alpha.origin.needsRandomBase() or (if (alpha.override) |component| component.needsRandomBase() else false),
        };
    }

    /// Color4 §13.2 / Images4 §3.5.2, Q56/Q92 browser probes1023j/k/l:
    /// the per-case majority combines Chrome's selected light-dark branch,
    /// Firefox/Safari's currentcolor and relative syntax, and Chrome/Firefox's
    /// computed mixes. No one browser implements this entire rule alone.
    /// This classifies the original syntax, never its resolved byte channels.
    pub fn usesLegacyGradientInterpolation(self: *const Expression, stage: Color.GradientStage) bool {
        return switch (self.data) {
            .resolved => |resolved| resolved.legacy,
            .channels => |channels| channels.origin != null or channels.function.legacy(),
            .mix => stage == .specified,
            .light_dark => |pair| switch (stage) {
                .specified => true,
                .computed => |scheme| pair[if (scheme == .dark) @as(usize, 1) else 0].usesLegacyGradientInterpolation(stage),
            },
            .contrast, .alpha => true,
        };
    }
    pub fn needsUnavailableMetrics(self: *const Expression, geometry: bool) bool {
        return switch (self.data) {
            .resolved => false,
            .channels => |channels| blk: {
                if (channels.origin) |origin| if (origin.needsUnavailableMetrics(geometry)) break :blk true;
                for (channels.components) |component| if (component.needsUnavailableMetrics(geometry)) break :blk true;
                break :blk false;
            },
            .mix => |mix| blk: {
                for (mix.items) |item| {
                    if (item.color.needsUnavailableMetrics(geometry)) break :blk true;
                    if (item.weight) |weight| if (weight.needsUnavailableMetrics(geometry)) break :blk true;
                }
                break :blk false;
            },
            .light_dark => |pair| pair[0].needsUnavailableMetrics(geometry) or pair[1].needsUnavailableMetrics(geometry),
            .contrast => |color| color.needsUnavailableMetrics(geometry),
            .alpha => |alpha| alpha.origin.needsUnavailableMetrics(geometry) or (if (alpha.override) |component| component.needsUnavailableMetrics(geometry) else false),
        };
    }
    pub fn serialize(self: *const Expression, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self.data) {
            .resolved => |resolved| try serializeResolved(resolved, out, allocator),
            .channels => |channels| try serializeChannels(channels, out, allocator),
            .mix => |mix| try serializeMix(mix, out, allocator),
            .light_dark => |pair| {
                try out.appendSlice(allocator, "light-dark(");
                try pair[0].serializeSpecified(out, allocator);
                try out.appendSlice(allocator, ", ");
                try pair[1].serializeSpecified(out, allocator);
                try out.append(allocator, ')');
            },
            .contrast => |color| {
                try out.appendSlice(allocator, "contrast-color(");
                try color.serializeSpecified(out, allocator);
                try out.append(allocator, ')');
            },
            .alpha => |alpha| {
                // Q77: declared alpha() keeps every explicit override,
                // including 1/100%; it never invents a color-space token.
                try out.appendSlice(allocator, "alpha(from ");
                try alpha.origin.serializeSpecified(out, allocator);
                if (alpha.override) |component| {
                    try out.appendSlice(allocator, " / ");
                    try component.serialize(out, allocator);
                }
                try out.append(allocator, ')');
            },
        }
    }

    pub fn resolve(self: *Expression, allocator: Allocator, context: Color.Context) Allocator.Error!Color {
        switch (self.data) {
            .resolved => {
                self.ref();
                return .{ .expression = self };
            },
            .light_dark => |pair| return pair[if (context.scheme == .dark) @as(usize, 1) else 0].resolveComputed(allocator, context),
            .contrast => |origin| {
                const computed = try origin.resolveComputed(allocator, context);
                if (resolvedComponents(computed)) |components| {
                    defer computed.release();
                    // Color5§8: maximum contrast; alpha is ignored. The
                    // white-on-tie rule follows the newer normative text.
                    return .{ .rgba = if (spaces.contrastChoosesBlack(components)) .black else .{ .r = 255, .g = 255, .b = 255, .a = 1 } };
                }
                return create(allocator, .{ .contrast = computed });
            },
            .channels => |channels| return create(allocator, try computeChannels(channels, allocator, context)),
            .mix => |mix| return create(allocator, try computeMix(mix, allocator, context)),
            .alpha => |alpha| return create(allocator, try computeAlpha(alpha, allocator, context)),
        }
    }

    /// This is the explicitly lossy destination API, never CSSOM's color
    /// serialization and never the origin for another color expression.
    pub fn bytes(self: *const Expression) ?values.RgbaColor {
        if (self.data != .resolved) return null;
        const components = self.data.resolved.value;
        const rgb = spaces.gamutMapSrgb(components);
        return .{ .r = byte(rgb[0]), .g = byte(rgb[1]), .b = byte(rgb[2]), .a = @floatCast(std.math.clamp(components.channel(3), 0, 1)) };
    }
};

fn optionalColorEql(a: ?Color, b: ?Color) bool {
    return if (a) |color| b != null and color.eql(b.?) else b == null;
}
fn optionalComponentEql(a: ?Component, b: ?Component) bool {
    return if (a) |component| b != null and component.eql(b.?) else b == null;
}

fn appendScalar(value: f64, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    if (std.math.isFinite(value)) return values.appendNumber(if (value == 0) 0 else value, out, allocator);
    try out.appendSlice(allocator, if (std.math.isNan(value)) "calc(NaN)" else if (value < 0) "calc(-infinity)" else "calc(infinity)");
}
fn serializeResolved(resolved: Resolved, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    var color = resolved.value;
    if (resolved.legacy and color.missing == 0) {
        // Legacy CSSOM rounding is distinct from physical gamut mapping.
        return values.serializeRgba(legacyBytes(color), out, allocator);
    }
    if ((color.space == .hsl or color.space == .hwb) and color.missing == 0) color = color.convert(.srgb);
    if (color.space.predefined()) {
        try out.appendSlice(allocator, "color(");
        try out.appendSlice(allocator, color.space.name());
        try out.append(allocator, ' ');
    } else {
        try out.appendSlice(allocator, color.space.name());
        try out.append(allocator, '(');
    }
    for (0..3) |index| {
        if (index > 0) try out.append(allocator, ' ');
        if (color.absent(index)) try out.appendSlice(allocator, "none") else {
            try appendScalar(color.channels[index], out, allocator);
            if ((color.space == .hsl or color.space == .hwb) and index > 0) try out.append(allocator, '%');
        }
    }
    if (color.absent(3) or color.alpha != 1) {
        try out.appendSlice(allocator, " / ");
        if (color.absent(3)) try out.appendSlice(allocator, "none") else try appendScalar(color.alpha, out, allocator);
    }
    try out.append(allocator, ')');
}
fn byte(channel: f64) u8 {
    return @intFromFloat(@round((if (std.math.isNan(channel)) 0 else std.math.clamp(channel, 0, 1)) * 255));
}

fn serializeChannels(channels: Channels, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    try out.appendSlice(allocator, @tagName(channels.function));
    try out.append(allocator, '(');
    if (channels.origin) |origin| {
        try out.appendSlice(allocator, "from ");
        try origin.serializeSpecified(out, allocator);
        try out.append(allocator, ' ');
    }
    if (channels.function == .color) {
        try out.appendSlice(allocator, channels.space.name());
        try out.append(allocator, ' ');
    }
    for (channels.components[0..3], 0..) |component, index| {
        if (index > 0) try out.append(allocator, ' ');
        try component.serialize(out, allocator);
    }
    const alpha = channels.components[3];
    // Color5 §11.3: an explicit channel keyword remains an argument; it
    // cannot be distinguished from an omitted default by value alone.
    const initial_alpha = if (channels.origin != null) !channels.explicit_alpha else if (alpha.known()) |number| number.value == (if (number.unit == .percent) @as(f64, 100) else 1) else false;
    if (!initial_alpha) {
        try out.appendSlice(allocator, " / ");
        try alpha.serialize(out, allocator);
    }
    try out.append(allocator, ')');
}

fn serializeMix(mix: Mix, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    try out.appendSlice(allocator, "color-mix(");
    if (mix.space != .oklab) {
        try out.appendSlice(allocator, "in ");
        try out.appendSlice(allocator, mix.space.name());
        if (mix.hue != .shorter) {
            try out.append(allocator, ' ');
            try out.appendSlice(allocator, @tagName(mix.hue));
            try out.appendSlice(allocator, " hue");
        }
        try out.appendSlice(allocator, ", ");
    }
    var specified_sum: f64 = 0;
    var omitted: usize = 0;
    var known = true;
    for (mix.items) |item| {
        if (item.weight) |weight| {
            if (weight == .calculation) known = false else specified_sum += weight.literal.value;
        } else omitted += 1;
    }
    const omitted_weight = if (omitted > 0) (100 - specified_sum) / @as(f64, @floatFromInt(omitted)) else 0;
    const equal_share = 100 / @as(f64, @floatFromInt(mix.items.len));
    var omit_all = known;
    for (mix.items) |item| {
        const weight = if (item.weight) |w| (if (w == .literal) w.literal.value else -1) else omitted_weight;
        // Q76's unanimous browser rule: equality, not draft's erroneous >=.
        if (weight != equal_share) omit_all = false;
    }
    for (mix.items, 0..) |item, index| {
        if (index > 0) try out.appendSlice(allocator, ", ");
        try item.color.serializeSpecified(out, allocator);
        if (omit_all) continue;
        if (item.weight) |weight| {
            try out.append(allocator, ' ');
            try weight.serialize(out, allocator);
        } else if (known) {
            try out.append(allocator, ' ');
            try values.appendNumber(omitted_weight, out, allocator);
            try out.append(allocator, '%');
        }
    }
    try out.append(allocator, ')');
}

pub fn isFunction(token: tokens.Token) bool {
    if (token.token_type != .function) return false;
    if (Function.parse(token.value) != null) return true;
    inline for (.{ "color-mix", "light-dark", "contrast-color", "alpha" }) |name|
        if (tokens.nameEql(token.value, name)) return true;
    return false;
}

pub fn parse(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Color {
    if (!isFunction(stream.peek())) return null;
    const before = stream.*;
    var parser = Parser{ .options = options, .stream = stream };
    return parser.consumeColor(false) catch |err| switch (err) {
        error.Invalid => {
            stream.* = before;
            return null;
        },
        error.OutOfMemory => return error.OutOfMemory,
    };
}

const Parser = struct {
    options: properties.ParseOptions,
    stream: *properties.Stream,
    depth: usize = 0,

    fn require(self: *Parser, kind: tokens.TokenType) Error!void {
        const actual = self.stream.next().token_type;
        // Syntax3 §§5.5.9–10: EOF closes an open function.
        if (actual != kind and !(kind == .right_paren and actual == .eof)) return error.Invalid;
    }
    fn ident(self: *Parser, name: []const u8) bool {
        const token = self.stream.peek();
        if (token.token_type != .ident or !tokens.nameEql(token.value, name)) return false;
        _ = self.stream.next();
        return true;
    }
    fn slash(self: *Parser) bool {
        const token = self.stream.peek();
        if (token.token_type != .delim or !std.mem.eql(u8, token.value, "/")) return false;
        _ = self.stream.next();
        return true;
    }
    fn consumeColor(self: *Parser, keep_precision: bool) Error!Color {
        self.depth += 1;
        defer self.depth -= 1;
        if (self.depth > 128) return error.Invalid;
        const token = self.stream.peek();
        if (token.token_type != .function) {
            const result = try properties.parseLonghand(self.options, .color, self.stream) orelse return error.Invalid;
            if (result != .color) {
                result.release();
                return error.Invalid;
            }
            return result.color;
        }
        if (!isFunction(token)) return error.Invalid;
        _ = self.stream.next();
        try self.require(.left_paren);
        const data = if (Function.parse(token.value)) |function| try self.channels(function) else if (tokens.nameEql(token.value, "color-mix")) try self.mix() else if (tokens.nameEql(token.value, "light-dark")) try self.lightDark() else if (tokens.nameEql(token.value, "contrast-color")) try self.contrast() else try self.alpha();
        // Ordinary top-level rgb/hsl/hwb keeps the scalar fast path. A
        // nested color always retains floating channels for its consumer.
        if (!keep_precision and data == .resolved and data.resolved.legacy and data.resolved.value.missing == 0)
            return .{ .rgba = legacyBytes(data.resolved.value) };
        return Expression.create(self.options.allocator, data);
    }
    fn lightDark(self: *Parser) Error!Data {
        const light = try self.consumeColor(true);
        errdefer light.release();
        try self.require(.comma);
        const dark = try self.consumeColor(true);
        errdefer dark.release();
        try self.require(.right_paren);
        return .{ .light_dark = .{ light, dark } };
    }
    fn contrast(self: *Parser) Error!Data {
        const origin = try self.consumeColor(true);
        errdefer origin.release();
        try self.require(.right_paren);
        return .{ .contrast = origin };
    }
    fn alpha(self: *Parser) Error!Data {
        if (!self.ident("from")) return error.Invalid;
        const origin = try self.consumeColor(true);
        errdefer origin.release();
        // Color5 §4.10: the slash and replacement alpha are required.
        if (!self.slash()) return error.Invalid;
        const amount = try self.consumeComponent(false, math.Symbol.alpha.bit());
        errdefer amount.release();
        try self.require(.right_paren);
        return .{ .alpha = .{ .origin = origin, .override = amount } };
    }
    fn channels(self: *Parser, function: Function) Error!Data {
        var result = Channels{ .function = function, .space = function.space(), .components = .{ .none, .none, .none, .none } };
        errdefer result.release();
        if (self.ident("from")) result.origin = try self.consumeColor(true);
        if (function == .color) {
            const token = self.stream.next();
            if (token.token_type != .ident) return error.Invalid;
            result.space = Space.parse(token.value) orelse return error.Invalid;
            if (!result.space.predefined()) return error.Invalid;
        }
        const symbols = if (result.origin != null) allowedSymbols(result.space) else 0;
        result.components[0] = try self.consumeComponent(result.space.hue() == 0, symbols);
        const legacy = self.stream.peek().token_type == .comma;
        if (legacy and (!(function == .rgb or function == .hsl) or result.origin != null)) return error.Invalid;
        for (1..3) |index| {
            if (legacy) try self.require(.comma);
            result.components[index] = try self.consumeComponent(result.space.hue() == index, symbols);
        }
        if (legacy) {
            for (result.components[0..3]) |component| if (component == .none) return error.Invalid;
            if (function == .rgb) {
                const unit = componentUnit(result.components[0]);
                if (unit != componentUnit(result.components[1]) or unit != componentUnit(result.components[2])) return error.Invalid;
            } else if (componentUnit(result.components[1]) != .percent or componentUnit(result.components[2]) != .percent) return error.Invalid;
        }
        const has_alpha = if (legacy) blk: {
            if (self.stream.peek().token_type != .comma) break :blk false;
            _ = self.stream.next();
            break :blk true;
        } else self.slash();
        result.explicit_alpha = result.origin != null and has_alpha;
        result.components[3] = if (has_alpha) try self.consumeComponent(false, symbols) else if (result.origin != null) .{ .channel = .alpha } else .{ .number = Number.scalar(1) };
        if (legacy and result.components[3] == .none) return error.Invalid;
        try self.require(.right_paren);
        if (result.origin == null) {
            // Color4 §§5,7–10: literal components clamp at parse time;
            // calc() keeps its expression and clamps only when computed.
            for (&result.components, 0..) |*component, index| {
                if (component.* == .number and component.number == .literal)
                    component.* = .{ .number = Number.scalar(normalizeComponent(result, index, component.number.literal)) };
            }
            if (channelsValue(result)) |color| {
                const has_math = for (result.components) |component| {
                    if (component == .number and component.number == .calculation) break true;
                } else false;
                if (!has_math or function.legacy()) {
                    result.release();
                    return .{ .resolved = .{ .value = color, .legacy = function.legacy() } };
                }
            }
        }
        return .{ .channels = result };
    }
    fn consumeComponent(self: *Parser, hue: bool, symbols: u16) Error!Component {
        const token = self.stream.peek();
        if (self.ident("none")) return .none;
        if (token.token_type == .ident) if (math.Symbol.parse(token.value)) |symbol| {
            if (symbols & symbol.bit() == 0) return error.Invalid;
            _ = self.stream.next();
            return .{ .channel = symbol };
        };
        const before = self.stream.*;
        for ([_]math.Kind{ .number, .percentage, .angle }) |kind| {
            if ((kind == .percentage and hue) or (kind == .angle and !hue)) continue;
            self.stream.* = before;
            if (try Number.consume(self.options, self.stream, .{ .kind = kind, .allowed_symbols = symbols }, false)) |number|
                return .{ .number = number };
        }
        return error.Invalid;
    }
    fn mix(self: *Parser) Error!Data {
        var result = Mix{ .items = &.{} };
        if (self.ident("in")) {
            const token = self.stream.next();
            if (token.token_type != .ident) return error.Invalid;
            result.space = Space.parse(token.value) orelse return error.Invalid;
            if (self.stream.peek().token_type == .ident) {
                if (result.space.hue() == null) return error.Invalid;
                const method = self.stream.next();
                result.hue = inline for (@typeInfo(spaces.HueMethod).@"enum".fields) |field| {
                    if (tokens.nameEql(method.value, field.name)) break @enumFromInt(field.value);
                } else return error.Invalid;
                if (!self.ident("hue")) return error.Invalid;
            }
            try self.require(.comma);
        }
        var list: std.ArrayList(MixItem) = .empty;
        defer list.deinit(self.options.allocator);
        errdefer for (list.items) |item| {
            item.color.release();
            if (item.weight) |weight| weight.unref();
        };
        while (true) {
            const item = try self.mixItem();
            list.append(self.options.allocator, item) catch |err| {
                item.color.release();
                if (item.weight) |weight| weight.unref();
                return err;
            };
            if (list.items.len > 4096) return error.Invalid;
            if (self.stream.peek().token_type != .comma) break;
            _ = self.stream.next();
        }
        try self.require(.right_paren);
        if (list.items.len == 0) return error.Invalid;
        result.items = try list.toOwnedSlice(self.options.allocator);
        return .{ .mix = result };
    }
    fn mixItem(self: *Parser) Error!MixItem {
        const before = self.stream.*;
        var weight = try Number.consume(self.options, self.stream, .{ .kind = .percentage, .minimum = 0, .maximum = 100 }, false);
        errdefer if (weight) |number| number.unref();
        if (weight == null) self.stream.* = before;
        const color = try self.consumeColor(true);
        errdefer color.release();
        if (weight == null) {
            const after_color = self.stream.*;
            weight = try Number.consume(self.options, self.stream, .{ .kind = .percentage, .minimum = 0, .maximum = 100 }, false);
            if (weight == null) self.stream.* = after_color;
        }
        return .{ .color = color, .weight = weight };
    }
};

fn channelSymbols(space: Space) [3]math.Symbol {
    return switch (space) {
        .xyz_d50, .xyz_d65 => .{ .x, .y, .z },
        .lab, .oklab => .{ .l, .a, .b },
        .lch, .oklch => .{ .l, .c, .h },
        .hsl => .{ .h, .s, .l },
        .hwb => .{ .h, .w, .b },
        else => .{ .r, .g, .b },
    };
}
fn allowedSymbols(space: Space) u16 {
    var mask = math.Symbol.alpha.bit();
    for (channelSymbols(space)) |symbol| mask |= symbol.bit();
    return mask;
}
fn componentUnit(component: Component) ?math.Unit {
    if (component != .number) return null;
    return switch (component.number) {
        .literal => |number| number.unit,
        .calculation => |expression| if (expression.grammar.kind == .percentage) .percent else .number,
    };
}
fn percentReference(channels: Channels, index: usize) f64 {
    if (index == 3) return 1;
    return switch (channels.function) {
        .rgb => 255,
        .hsl, .hwb => 100,
        .lab => if (index == 0) 100 else 125,
        .lch => if (index == 0) 100 else 150,
        .oklab, .oklch => if (index == 0) 1 else 0.4,
        .color => 1,
    };
}
fn normalizeComponent(channels: Channels, index: usize, raw: math.Numeric) f64 {
    var value = raw.value;
    if (std.math.isNan(value)) value = 0;
    if (raw.unit == .percent) value = (value / 100) * percentReference(channels, index);
    if (index == 3) return std.math.clamp(value, 0, 1);
    if (channels.space.hue() == index) {
        if (raw.unit.base() == .angle) value = (math.Context{}).resolve(raw).value;
        return spaces.normalizeHue(value);
    }
    // Relative channels keep extended ranges, except alpha and hue (Color5§4.1).
    if (channels.origin != null) return value;
    return switch (channels.function) {
        .rgb => std.math.clamp(value, 0, 255),
        .hsl => if (index == 1) @max(0, value) else value,
        // Color4 §8: white and black may exceed 100; conversion normalizes
        // their ratio when their sum is at least 100.
        .hwb => @max(0, value),
        .lab, .lch => if (index == 0) std.math.clamp(value, 0, 100) else if (channels.function == .lch and index == 1) @max(0, value) else value,
        .oklab, .oklch => if (index == 0) std.math.clamp(value, 0, 1) else if (channels.function == .oklch and index == 1) @max(0, value) else value,
        .color => value,
    };
}

fn channelsValue(channels: Channels) ?Components {
    var result = Components{ .space = channels.space, .channels = undefined };
    for (channels.components, 0..) |component, index| {
        var value: f64 = 0;
        switch (component) {
            .none => result.setMissing(index),
            .channel => return null,
            .number => value = normalizeComponent(channels, index, component.known() orelse return null),
        }
        if (index == 3) result.alpha = value else result.channels[index] = if (channels.function == .rgb) value / 255 else value;
    }
    return result;
}

fn resolvedComponents(color: Color) ?Components {
    return switch (color) {
        .rgba => |rgba| fromBytes(rgba),
        .transparent_keyword => fromBytes(values.RgbaColor.transparent),
        .named => |named| fromBytes(named.rgba),
        .system => |system| fromBytes(system.color(.light)),
        .current => null,
        .expression => |expression| if (expression.data == .resolved) expression.data.resolved.value else null,
    };
}
fn fromBytes(rgba: values.RgbaColor) Components {
    return .{ .space = .srgb, .channels = .{ @as(f64, @floatFromInt(rgba.r)) / 255, @as(f64, @floatFromInt(rgba.g)) / 255, @as(f64, @floatFromInt(rgba.b)) / 255 }, .alpha = rgba.a };
}
fn symbolIndex(space: Space, symbol: math.Symbol) usize {
    if (symbol == .alpha) return 3;
    for (channelSymbols(space), 0..) |candidate, index| if (candidate == symbol) return index;
    unreachable; // The relative function's allowlist validated this symbol.
}
fn fillSymbols(origin: Components, function: Function) math.SymbolValues {
    var result = math.SymbolValues{};
    for (channelSymbols(origin.space), 0..) |symbol, index|
        result.values[@intFromEnum(symbol)] = origin.channel(index) * (if (function == .rgb) @as(f64, 255) else 1);
    result.values[@intFromEnum(math.Symbol.alpha)] = origin.channel(3);
    return result;
}

fn computeChannels(input: Channels, allocator: Allocator, context: Color.Context) Allocator.Error!Data {
    var output = Channels{ .function = input.function, .space = input.space, .components = .{ .none, .none, .none, .none }, .explicit_alpha = input.explicit_alpha };
    errdefer output.release();
    if (input.origin) |origin| output.origin = try origin.resolveComputed(allocator, context);
    const origin_components: ?Components = if (output.origin) |origin| (if (resolvedComponents(origin)) |components| components.convert(input.space) else null) else null;
    var symbols: math.SymbolValues = if (origin_components) |origin| fillSymbols(origin, input.function) else .{};
    var numeric_context = context.math;
    numeric_context.percentage_basis = null;
    numeric_context.symbols = if (origin_components != null) &symbols else null;
    for (input.components, &output.components) |component, *destination| {
        if (component == .channel and origin_components != null) {
            const index = symbolIndex(input.space, component.channel);
            destination.* = if (origin_components.?.absent(index)) .none else .{ .number = Number.scalar(symbols.values[@intFromEnum(component.channel)]) };
        } else destination.* = try component.compute(allocator, numeric_context);
    }
    if (channelsValue(output)) |components| {
        output.release();
        return .{ .resolved = .{ .value = components, .legacy = input.origin == null and input.function.legacy() } };
    }
    return .{ .channels = output };
}

fn computeAlpha(input: Alpha, allocator: Allocator, context: Color.Context) Allocator.Error!Data {
    var output = Alpha{ .origin = try input.origin.resolveComputed(allocator, context) };
    errdefer {
        output.origin.release();
        if (output.override) |component| component.release();
    }
    const origin = resolvedComponents(output.origin);
    var symbols = math.SymbolValues{};
    if (origin) |components| symbols.values[@intFromEnum(math.Symbol.alpha)] = components.channel(3);
    var numeric_context = context.math;
    numeric_context.percentage_basis = null;
    numeric_context.symbols = if (origin != null) &symbols else null;
    if (input.override) |component| {
        output.override = if (component == .channel and origin != null)
            (if (origin.?.absent(3)) Component.none else Component{ .number = Number.scalar(origin.?.alpha) })
        else
            try component.compute(allocator, numeric_context);
    }
    if (origin) |components| {
        var result = components;
        if (output.override) |amount| {
            if (amount == .none) {
                result.setMissing(3);
                result.alpha = 0;
            } else if (amount.known()) |number| {
                result.missing &= 7;
                const raw = number.value / (if (number.unit == .percent) @as(f64, 100) else 1);
                result.alpha = if (std.math.isNan(raw)) 0 else std.math.clamp(raw, 0, 1);
            } else return .{ .alpha = output };
        }
        output.origin.release();
        if (output.override) |component| component.release();
        return .{ .resolved = .{ .value = result } };
    }
    return .{ .alpha = output };
}

fn computeMix(input: Mix, allocator: Allocator, context: Color.Context) Allocator.Error!Data {
    const items = try allocator.alloc(MixItem, input.items.len);
    var count: usize = 0;
    errdefer {
        for (items[0..count]) |item| {
            item.color.release();
            if (item.weight) |weight| weight.unref();
        }
        allocator.free(items);
    }
    var numeric_context = context.math;
    numeric_context.percentage_basis = null;
    for (input.items, items) |original, *item| {
        item.* = .{ .color = try original.color.resolveComputed(allocator, context) };
        count += 1;
        if (original.weight) |weight| item.weight = try weight.compute(allocator, numeric_context);
    }
    const output = Mix{ .space = input.space, .hue = input.hue, .items = items };
    if (mixValue(output)) |components| {
        output.release(allocator);
        return .{ .resolved = .{ .value = components } };
    }
    return .{ .mix = output };
}
fn mixValue(mix: Mix) ?Components {
    var provided_sum: f64 = 0;
    var omitted: usize = 0;
    for (mix.items) |item| {
        if (resolvedComponents(item.color) == null) return null;
        if (item.weight) |weight| {
            const number = weight.known() orelse return null;
            provided_sum += if (std.math.isNan(number.value)) 0 else std.math.clamp(number.value, 0, 100);
        } else omitted += 1;
    }
    const omitted_weight = if (omitted > 0) @max(0, 100 - provided_sum) / @as(f64, @floatFromInt(omitted)) else 0;
    const total = provided_sum + omitted_weight * @as(f64, @floatFromInt(omitted));
    const alpha_multiplier = @min(1, total / 100);
    var accumulator = resolvedComponents(mix.items[0].color).?.convert(mix.space);
    var combined: f64 = 0;
    // Color5 §3.3: left-to-right stack reduction, with .5 progress when
    // both weights are zero. Forced normalization keeps a zero sum zero.
    for (mix.items, 0..) |item, index| {
        const weight = if (item.weight) |number| (if (std.math.isNan(number.known().?.value)) @as(f64, 0) else std.math.clamp(number.known().?.value, 0, 100)) else omitted_weight;
        if (index > 0) accumulator = spaces.interpolate(accumulator, resolvedComponents(item.color).?, mix.space, mix.hue, if (combined + weight > 0) weight / (combined + weight) else 0.5);
        combined += weight;
    }
    accumulator.alpha *= alpha_multiplier;
    return accumulator;
}

fn legacyBytes(components: Components) values.RgbaColor {
    const rgb = components.convert(.srgb);
    return .{ .r = byte(rgb.channel(0)), .g = byte(rgb.channel(1)), .b = byte(rgb.channel(2)), .a = @floatCast(std.math.clamp(rgb.channel(3), 0, 1)) };
}
