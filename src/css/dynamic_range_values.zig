//! CSS Color HDR 1 §3: dynamic-range-limit and dynamic-range-limit-mix().
//!
//! dynamic-range-limit: standard | no-limit | constrained | <dynamic-range-limit-mix()>
//! dynamic-range-limit-mix() = dynamic-range-limit-mix(
//!     [ <'dynamic-range-limit'> && <percentage [0,100]> ]# )
//!
//! A keyword is Value.keyword. A mix is a counted Mix: the specified one
//! keeps its items (a limit - a keyword or a nested mix - and its
//! percentage, a literal or a math function) for serialization and
//! computation; the computed one is §3.3's three percentages for standard,
//! constrained and no-limit, which sum to 100.
//!
//! Golden rule 2: only Chrome ships the function (css/css-color-hdr/
//! parsing.html: Chrome 28/29; Firefox 17/29 and Safari 19/29 reject every
//! mix), and it rejects a mix of one item and one whose percentages are all
//! 0% (parsing.html's "dynamic-range-limit-mix(no-limit 1%)" and
//! "(no-limit 0%, standard 0%)" invalid cases), where the spec's `#` takes
//! one item and §3.3 step 2 leaves an all-zero normalization undefined.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokenizer = @import("tokenizer.zig");
const math_values = @import("math_values.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Keyword = values.Keyword;
const Stream = properties.Stream;

/// §3.3's order: standard, constrained, no-limit.
const limits = [_]Keyword{ .standard, .constrained, .no_limit };

pub const Item = struct {
    /// A keyword, or a nested `dynamic_range` mix.
    limit: Value,
    /// A percentage (`.length` in %) or a math function.
    percentage: Value,
};

pub const Mix = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    data: union(enum) {
        specified: []const Item,
        /// Percentages of standard, constrained and no-limit.
        computed: [3]f64,
    },

    /// Takes ownership of `items` (allocated with `allocator`).
    fn createSpecified(allocator: Allocator, items: []const Item) Allocator.Error!*Mix {
        const self = try allocator.create(Mix);
        self.* = .{ .allocator = allocator, .data = .{ .specified = items } };
        return self;
    }

    pub fn createComputed(allocator: Allocator, shares: [3]f64) Allocator.Error!*Mix {
        const self = try allocator.create(Mix);
        self.* = .{ .allocator = allocator, .data = .{ .computed = shares } };
        return self;
    }

    pub fn ref(self: *Mix) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }

    pub fn unref(self: *Mix) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        switch (self.data) {
            .specified => |items| {
                for (items) |item| {
                    item.limit.release();
                    item.percentage.release();
                }
                self.allocator.free(items);
            },
            .computed => {},
        }
        self.allocator.destroy(self);
    }

    pub fn eql(self: *const Mix, other: *const Mix) bool {
        if (self == other) return true;
        return switch (self.data) {
            .computed => |w| other.data == .computed and std.mem.eql(f64, &w, &other.data.computed),
            .specified => |items| blk: {
                if (other.data != .specified or other.data.specified.len != items.len) break :blk false;
                for (items, other.data.specified) |a, b| if (!a.limit.eql(b.limit) or !a.percentage.eql(b.percentage)) break :blk false;
                break :blk true;
            },
        };
    }

    pub fn needsUnavailableMetrics(self: *const Mix, geometry_length: bool) bool {
        if (self.data == .computed) return false;
        for (self.data.specified) |item| if (item.limit.needsUnavailableMetrics(geometry_length) or item.percentage.needsUnavailableMetrics(geometry_length)) return true;
        return false;
    }

    pub fn needsTreeCounts(self: *const Mix) bool {
        if (self.data == .computed) return false;
        for (self.data.specified) |item| if (item.limit.needsTreeCounts() or item.percentage.needsTreeCounts()) return true;
        return false;
    }

    pub fn needsRandomBase(self: *const Mix) bool {
        if (self.data == .computed) return false;
        for (self.data.specified) |item| if (item.limit.needsRandomBase() or item.percentage.needsRandomBase()) return true;
        return false;
    }

    pub fn serialize(self: *const Mix, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        try out.appendSlice(allocator, "dynamic-range-limit-mix(");
        switch (self.data) {
            .specified => |items| for (items, 0..) |item, i| {
                if (i > 0) try out.appendSlice(allocator, ", ");
                try properties.serializeValue(.dynamic_range_limit, item.limit, out, allocator);
                try out.append(allocator, ' ');
                try properties.serializeValue(.dynamic_range_limit, item.percentage, out, allocator);
            },
            .computed => |weights| {
                var first = true;
                for (limits, weights) |limit, weight| if (weight != 0) {
                    if (!first) try out.appendSlice(allocator, ", ");
                    first = false;
                    try out.appendSlice(allocator, limit.name());
                    try out.append(allocator, ' ');
                    try values.appendNumber(weight, out, allocator);
                    try out.append(allocator, '%');
                };
            },
        }
        try out.append(allocator, ')');
    }

    /// §3.3: the computed value of a specified mix - a keyword when one
    /// limit takes 100%, else a computed mix. `context.component` computes
    /// a percentage's math function. OWNED.
    pub fn compute(self: *Mix, allocator: Allocator, context: anytype) Allocator.Error!Value {
        if (self.data == .computed) {
            self.ref();
            return .{ .dynamic_range = self };
        }
        return fromWeights(allocator, try self.limitShares(context));
    }

    /// The percentages of standard, constrained and no-limit (§3.3 steps
    /// 1-4); all zero when the item percentages sum to zero.
    fn limitShares(self: *const Mix, context: anytype) Allocator.Error![3]f64 {
        const items = switch (self.data) {
            .computed => |w| return w,
            .specified => |items| items,
        };
        // 1. The computed values of the parameters, as percentages of each
        //    limit. 2. Their mixing percentages, normalized to sum to 100%.
        var parts: [3]f64 = .{ 0, 0, 0 };
        var total: f64 = 0;
        for (items) |item| total += try percentOf(item.percentage, context);
        if (!(total > 0)) return parts;
        for (items) |item| {
            const share = (try percentOf(item.percentage, context)) / total * 100;
            const limit = try limitWeights(item.limit, context);
            // 3-4. The weighted sums of each limit's percentage.
            for (&parts, limit) |*part, w| part.* += w * share / 100;
        }
        return parts;
    }
};

/// One parameter's percentages of standard, constrained and no-limit.
fn limitWeights(limit: Value, context: anytype) Allocator.Error![3]f64 {
    return switch (limit) {
        .keyword => |k| blk: {
            var out: [3]f64 = .{ 0, 0, 0 };
            for (limits, 0..) |candidate, i| if (candidate == k) {
                out[i] = 100;
            };
            break :blk out;
        },
        .dynamic_range => |mix| mix.limitShares(context),
        else => .{ 0, 0, 0 },
    };
}

/// A mixing percentage as a number in [0, 100] (Values 4 §10.12 clamps a
/// math function to the range at computed-value time).
fn percentOf(percentage: Value, context: anytype) Allocator.Error!f64 {
    const n: f64 = switch (percentage) {
        .length => |len| len.value,
        .calculation => blk: {
            const computed = try context.component(.dynamic_range_limit, percentage);
            defer computed.release();
            break :blk if (computed == .length) computed.length.value else 0;
        },
        else => 0,
    };
    if (std.math.isNan(n)) return 0;
    return std.math.clamp(n, 0, 100);
}

/// §3.3 steps 5-6: a limit at 100% is that keyword; else a mix of the
/// nonzero ones; "if all parameters are thereby omitted, the computed value
/// is the initial value". OWNED.
pub fn fromWeights(allocator: Allocator, weights: [3]f64) Allocator.Error!Value {
    var cleaned = weights;
    var any = false;
    for (&cleaned, limits) |*w, limit| {
        // Rounding error from normalization is not a share of its own.
        if (@abs(w.* - 100) < 1e-9) return Value.kw(limit);
        if (@abs(w.*) < 1e-9) w.* = 0 else any = true;
    }
    if (!any) return Value.kw(.no_limit);
    return .{ .dynamic_range = try Mix.createComputed(allocator, cleaned) };
}

/// The computed percentages of standard, constrained and no-limit of a
/// computed dynamic-range-limit; null for any other value.
pub fn computedWeights(v: Value) ?[3]f64 {
    return switch (v) {
        .keyword => |k| for (limits, 0..) |limit, i| {
            if (limit == k) {
                var out: [3]f64 = .{ 0, 0, 0 };
                out[i] = 100;
                break out;
            }
        } else null,
        .dynamic_range => |mix| if (mix.data == .computed) mix.data.computed else null,
        else => null,
    };
}

/// The animation type "by dynamic-range-limit-mix()": from and to mixed
/// as dynamic-range-limit-mix(from (1 - p), to p), which §3.3 computes to
/// their weighted percentages. Null when either is not a computed value.
pub fn interpolate(allocator: Allocator, from: Value, to: Value, p: f64) Allocator.Error!?Value {
    const a = computedWeights(from) orelse return null;
    const b = computedWeights(to) orelse return null;
    // A mixing percentage is in [0%, 100%]: an extrapolated p is clamped.
    const t = std.math.clamp(p, 0, 1);
    var mixed: [3]f64 = undefined;
    for (&mixed, a, b) |*m, x, y| m.* = x * (1 - t) + y * t;
    return try fromWeights(allocator, mixed);
}

fn keyword(stream: *Stream) ?Keyword {
    const token = stream.peek();
    if (token.token_type != .ident) return null;
    for (limits) |k| if (tokenizer.nameEql(token.value, k.name())) {
        _ = stream.next();
        return k;
    };
    return null;
}

/// <percentage [0,100]>.
fn consumePercentage(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    const token = stream.peek();
    if (math_values.isFunction(token)) return properties.mathValue(options, stream, .{ .kind = .percentage, .minimum = 0, .maximum = 100, .minimum_kind = .computation, .maximum_kind = .computation });
    if (token.token_type != .percentage) return null;
    const n = token.numeric_value orelse return null;
    if (n < 0 or n > 100) return null;
    _ = stream.next();
    return .{ .length = values.Length.percent(n) };
}

pub fn parse(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    if (keyword(stream)) |k| return Value.kw(k);
    return parseMix(options, stream);
}

fn parseMix(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    const token = stream.peek();
    if (token.token_type != .function or !tokenizer.nameEql(token.value, "dynamic-range-limit-mix")) return null;
    _ = stream.next();
    if (stream.next().token_type != .left_paren) return null;
    const allocator = options.allocator;
    var items: std.ArrayList(Item) = .empty;
    var owned = true;
    defer if (owned) {
        for (items.items) |item| {
            item.limit.release();
            item.percentage.release();
        }
        items.deinit(allocator);
    };
    var all_zero = true;
    while (true) {
        // <'dynamic-range-limit'> && <percentage [0,100]>, in either order.
        var share = try consumePercentage(options, stream);
        errdefer if (share) |v| v.release();
        const limit: Value = if (keyword(stream)) |k| Value.kw(k) else (try parseMix(options, stream)) orelse {
            if (share) |v| v.release();
            return null;
        };
        errdefer limit.release();
        if (share == null) share = try consumePercentage(options, stream);
        const value = share orelse {
            limit.release();
            return null;
        };
        if (!(value == .length and value.length.value == 0)) all_zero = false;
        try items.append(allocator, .{ .limit = limit, .percentage = value });
        const next = stream.next();
        if (next.token_type == .right_paren) break;
        if (next.token_type != .comma) return null;
    }
    if (items.items.len < 2 or all_zero) return null;
    const slice = try items.toOwnedSlice(allocator);
    owned = false;
    errdefer {
        for (slice) |item| {
            item.limit.release();
            item.percentage.release();
        }
        allocator.free(slice);
    }
    return .{ .dynamic_range = try Mix.createSpecified(allocator, slice) };
}
