//! CSS Fonts5 §3.4: typed metric/aspect values and the optional metric input.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokens = @import("tokenizer.zig");
const math = @import("math_values.zig");
const request = @import("font_request.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;
pub const Metric = enum {
    ex_height,
    cap_height,
    ch_width,
    ic_width,
    ic_height,

    pub fn name(self: Metric) []const u8 {
        return switch (self) {
            .ex_height => "ex-height",
            .cap_height => "cap-height",
            .ch_width => "ch-width",
            .ic_width => "ic-width",
            .ic_height => "ic-height",
        };
    }
    fn parse(stream: *properties.Stream) ?Metric {
        const token = stream.peek();
        if (token.token_type != .ident) return null;
        inline for (@typeInfo(Metric).@"enum".fields) |field| {
            const metric: Metric = @enumFromInt(field.value);
            if (tokens.nameEql(token.value, metric.name())) {
                _ = stream.next();
                return metric;
            }
        }
        return null;
    }
};
pub const MetricResolver = struct {
    context: ?*anyopaque = null,
    /// Null RETURN is a known missing font. A null RESOLVER is an unavailable
    /// capability, and the cascade skips that candidate before computation.
    /// The selected face's absent-metric fallback belongs to this provider.
    resolve: *const fn (?*anyopaque, request.View, Metric) ?f64,
};

/// The caller owns value; unavailable carries no computed value.
const ComputeResult = union(enum) { value: Value, unavailable };

pub const Adjust = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    metric: Metric,
    /// null is from-font; otherwise a nonnegative number/calculation.
    aspect: ?Value,

    pub fn create(allocator: Allocator, metric: Metric, aspect: ?Value) Allocator.Error!*Adjust {
        const self = try allocator.create(Adjust);
        self.* = .{ .allocator = allocator, .metric = metric, .aspect = aspect };
        if (aspect) |v| v.retain();
        return self;
    }
    pub fn ref(self: *Adjust) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Adjust) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        if (self.aspect) |v| v.release();
        self.allocator.destroy(self);
    }
    pub fn eql(self: *const Adjust, other: *const Adjust) bool {
        if (self == other) return true;
        if (self.metric != other.metric) return false;
        if (self.aspect) |v| return if (other.aspect) |o| v.eql(o) else false;
        return other.aspect == null;
    }
    pub fn serialize(self: *const Adjust, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        if (self.metric != .ex_height) {
            try out.appendSlice(allocator, self.metric.name());
            try out.append(allocator, ' ');
        }
        if (self.aspect) |v| try properties.serializeValue(.font_weight, v, out, allocator) else try out.appendSlice(allocator, "from-font");
    }
    pub fn fromFont(self: *const Adjust) bool {
        return self.aspect == null;
    }
    pub fn needsUnavailableMetrics(self: *const Adjust) bool {
        const aspect = self.aspect orelse return false;
        return aspect == .calculation and aspect.calculation.needsUnavailableMetrics(false);
    }

    /// Only a calculated aspect can depend on element tree counts.
    pub fn needsTreeCounts(self: *const Adjust) bool {
        const aspect = self.aspect orelse return false;
        return aspect == .calculation and aspect.calculation.needsTreeCounts();
    }

    /// Literal aspects, fixed random and from-font need no random provider.
    pub fn needsRandomBase(self: *const Adjust) bool {
        const aspect = self.aspect orelse return false;
        return aspect == .calculation and aspect.calculation.needsRandomBase();
    }

    /// §3.4: from-font's unknown capability has already been filtered by the
    /// cascade. Known missing font means none; a ratio never changes font-size.
    pub fn compute(self: *const Adjust, allocator: Allocator, context: math.Context, resolver: ?MetricResolver, font: ?request.View) Allocator.Error!ComputeResult {
        if (self.aspect) |aspect| {
            if (aspect != .calculation) {
                @constCast(self).ref();
                return .{ .value = .{ .font_size_adjust = @constCast(self) } };
            }
            const expression = try aspect.calculation.compute(allocator, context);
            defer expression.unref();
            const v: Value = if (expression.computedNumber()) |n| .{ .number = n.value } else .{ .calculation = expression };
            return .{ .value = .{ .font_size_adjust = try create(allocator, self.metric, v) } };
        }
        // Q84/Q87: the cascade's single predicate excludes these missing
        // inputs; direct callers still receive the explicit defensive result.
        const provider = resolver orelse return .unavailable;
        const request_view = font orelse return .unavailable;
        const ratio = provider.resolve(provider.context, request_view, self.metric) orelse return .{ .value = Value.kw(.none) };
        std.debug.assert(std.math.isFinite(ratio) and ratio >= 0);
        return .{ .value = .{ .font_size_adjust = try create(allocator, self.metric, .{ .number = ratio }) } };
    }
};

pub fn parse(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    if (take(stream, "none")) return Value.kw(.none);
    const metric = Metric.parse(stream) orelse .ex_height;
    if (take(stream, "from-font")) return .{ .font_size_adjust = try Adjust.create(options.allocator, metric, null) };
    const token = stream.peek();
    const aspect: Value = if (math.isFunction(token))
        (try properties.mathValue(options, stream, .{ .kind = .number, .minimum = 0 })) orelse return null
    else blk: {
        if (token.token_type != .number) return null;
        const n = token.numeric_value orelse return null;
        if (!std.math.isFinite(n) or n < 0) return null;
        _ = stream.next();
        break :blk .{ .number = n };
    };
    defer aspect.release();
    return .{ .font_size_adjust = try Adjust.create(options.allocator, metric, aspect) };
}
fn take(stream: *properties.Stream, name: []const u8) bool {
    const token = stream.peek();
    if (token.token_type != .ident or !tokens.nameEql(token.value, name)) return false;
    _ = stream.next();
    return true;
}

// Q84: these new inline controls precede the result-contract implementation.
// They run after the shared Source prerequisite makes the font modules buildable.
test "from font reports unavailable for absent request or resolver without calling the provider" {
    const Probe = struct {
        fn resolve(context: ?*anyopaque, _: request.View, _: Metric) ?f64 {
            const calls: *usize = @ptrCast(@alignCast(context.?));
            calls.* += 1;
            return 0.5;
        }
    };
    const allocator = std.testing.allocator;
    const adjust = try Adjust.create(allocator, .ex_height, null);
    defer adjust.unref();
    var calls: usize = 0;
    const resolver = MetricResolver{ .context = &calls, .resolve = Probe.resolve };
    const missing_request = try adjust.compute(allocator, .{}, resolver, null);
    try std.testing.expect(missing_request == .unavailable);
    try std.testing.expectEqual(@as(usize, 0), calls);
    const font = request.View{
        .families = &.{.{ .generic = .serif }},
        .style = .normal,
        .weight = 400,
        .stretch_pct = 100,
        .size_px = 16,
    };
    const missing_resolver = try adjust.compute(allocator, .{}, null, font);
    try std.testing.expect(missing_resolver == .unavailable);
}

test "numeric size adjust does not require request data or a metric provider" {
    const allocator = std.testing.allocator;
    const adjust = try Adjust.create(allocator, .cap_height, .{ .number = 0.6 });
    defer adjust.unref();
    const result = try adjust.compute(allocator, .{}, null, null);
    try std.testing.expect(result == .value);
    defer result.value.release();
    try std.testing.expect(result.value == .font_size_adjust);
    try std.testing.expectEqual(adjust, result.value.font_size_adjust);
    try std.testing.expectEqual(@as(f64, 0.6), result.value.font_size_adjust.aspect.?.number);
}
