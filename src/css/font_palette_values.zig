//! CSS Fonts 4 §9.1 and Color 5 §11.1: owned palette mixes, without rendering.
//! Q8/Q22 retain authored weights; Q33 simplifies only equivalent palettes.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokens = @import("tokenizer.zig");
const math = @import("math_values.zig");
const Number = @import("numeric_values.zig").Number;
const gradients = @import("gradient_values.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Stream = properties.Stream;

// Q29: an engine recursion bound, not a limit in the CSS grammar. It agrees
// with the existing image/color owners; no limit on the component count.
const max_mix_depth = 128;
const Entry = struct {
    palette: Value,
    weight: ?Number,

    fn release(self: Entry) void {
        self.palette.release();
        if (self.weight) |weight| weight.unref();
    }
};

pub const Mix = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    method: gradients.Method,
    entries: []const Entry,

    /// Takes the owned list on success; failure leaves it with the caller.
    fn take(allocator: Allocator, method: gradients.Method, entries: *std.ArrayList(Entry)) Allocator.Error!*Mix {
        const result = try allocator.create(Mix);
        errdefer allocator.destroy(result);
        result.* = .{ .allocator = allocator, .method = method, .entries = try entries.toOwnedSlice(allocator) };
        return result;
    }
    pub fn ref(self: *Mix) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Mix) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        for (self.entries) |entry| entry.release();
        self.allocator.free(self.entries);
        self.allocator.destroy(self);
    }
    pub fn eql(self: *const Mix, other: *const Mix) bool {
        if (self == other) return true;
        if (!std.meta.eql(self.method, other.method) or self.entries.len != other.entries.len) return false;
        for (self.entries, other.entries) |a, b| {
            if (!a.palette.eql(b.palette) or (a.weight == null) != (b.weight == null)) return false;
            if (a.weight) |weight| if (!weight.eql(b.weight.?)) return false;
        }
        return true;
    }
    pub fn needsUnavailableMetrics(self: *const Mix) bool {
        for (self.entries) |entry| {
            if (entry.palette.needsUnavailableMetrics(false)) return true;
            if (entry.weight) |weight| if (weight.needsUnavailableMetrics(false)) return true;
        }
        return false;
    }
    pub fn needsTreeCounts(self: *const Mix) bool {
        for (self.entries) |entry| {
            if (entry.palette.needsTreeCounts()) return true;
            if (entry.weight) |weight| if (weight.needsTreeCounts()) return true;
        }
        return false;
    }
    pub fn needsRandomBase(self: *const Mix) bool {
        for (self.entries) |entry| {
            if (entry.palette.needsRandomBase()) return true;
            if (entry.weight) |weight| if (weight.needsRandomBase()) return true;
        }
        return false;
    }

    pub fn compute(self: *const Mix, allocator: Allocator, context: math.Context) Allocator.Error!Value {
        var entries: std.ArrayList(Entry) = .empty;
        defer {
            for (entries.items) |entry| entry.release();
            entries.deinit(allocator);
        }
        for (self.entries) |entry| {
            // Fonts4 §9.1: recursively resolve the innermost palettes first.
            const palette = if (entry.palette == .palette_mix)
                try entry.palette.palette_mix.compute(allocator, context)
            else blk: {
                entry.palette.retain();
                break :blk entry.palette;
            };
            errdefer palette.release();
            const weight = if (entry.weight) |number| try number.compute(allocator, context) else null;
            errdefer if (weight) |number| number.unref();
            try entries.append(allocator, .{ .palette = palette, .weight = weight });
        }
        if (equivalent(self.method, entries.items)) |palette| {
            palette.retain();
            return palette;
        }
        return .{ .palette_mix = try Mix.take(allocator, self.method, &entries) };
    }

    pub fn serialize(self: *const Mix, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        try out.appendSlice(allocator, "palette-mix(");
        if (self.method.space != .oklab) {
            try out.appendSlice(allocator, "in ");
            try out.appendSlice(allocator, self.method.space.name());
            if (self.method.hue != .shorter) {
                try out.append(allocator, ' ');
                try out.appendSlice(allocator, @tagName(self.method.hue));
                try out.appendSlice(allocator, " hue");
            }
            try out.appendSlice(allocator, ", ");
        }
        const weights = Weights.of(self.entries);
        var omit_all = weights.known;
        const equal_share = 100.0 / @as(f64, @floatFromInt(self.entries.len));
        for (self.entries) |entry| {
            if (!weights.known or weights.effective(entry) != equal_share) omit_all = false;
        }
        for (self.entries, 0..) |entry, index| {
            if (index != 0) try out.appendSlice(allocator, ", ");
            try properties.serializeValue(.font_palette, entry.palette, out, allocator);
            if (omit_all) continue;
            if (entry.weight) |weight| {
                try out.append(allocator, ' ');
                try weight.serialize(out, allocator);
            } else if (weights.known) {
                try out.append(allocator, ' ');
                try Number.percent(weights.omitted).serialize(out, allocator);
            }
        }
        try out.append(allocator, ')');
    }
};

const Weights = struct {
    known: bool = true,
    sum: f64 = 0,
    missing: usize = 0,
    omitted: f64 = 0,

    fn of(entries: []const Entry) Weights {
        var result = Weights{};
        for (entries) |entry| {
            if (entry.weight) |weight| {
                // Color5 §11.1: even calc(50%) is unknown in specified
                // serialization. Compute() turns resolved math into literals.
                if (weight == .literal) result.sum += weight.literal.value else result.known = false;
            } else result.missing += 1;
        }
        if (result.known and result.missing != 0) {
            // Q22 / Values5 §6.1: the specified sum is clamped before
            // distributing omitted weights. Never serialize a negative one.
            result.omitted = @max(0, 100 - result.sum) / @as(f64, @floatFromInt(result.missing));
        }
        return result;
    }
    fn effective(self: Weights, entry: Entry) f64 {
        std.debug.assert(self.known);
        return if (entry.weight) |weight| weight.literal.value else self.omitted;
    }
};

fn equivalent(method: gradients.Method, entries: []const Entry) ?Value {
    const weights = Weights.of(entries);
    if (!weights.known) return null;
    // With omitted weights the remaining share makes the total >=100.
    // Without them, a total below100 applies alpha and is not equivalent.
    if (weights.missing == 0 and weights.sum < 100) return null;
    var candidate: ?Value = null;
    var positive: usize = 0;
    for (entries) |entry| {
        if (weights.effective(entry) <= 0) continue;
        if (entry.palette != .keyword and entry.palette != .text) return null;
        if (candidate) |palette| {
            if (!palette.eql(entry.palette)) return null;
        } else candidate = entry.palette;
        positive += 1;
    }
    // Q33 / Color4 §13.5.2: equal polar hues under longer hue traverse a
    // full circle. A single positive endpoint remains equivalent.
    if (positive > 1 and method.space.hue() != null and method.hue == .longer) return null;
    return candidate;
}

pub fn consume(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    return consumeAtDepth(options, stream, 0);
}

fn consumeAtDepth(options: properties.ParseOptions, stream: *Stream, depth: usize) Allocator.Error!?Value {
    const token = stream.peek();
    if (token.token_type == .ident) {
        inline for ([_]values.Keyword{ .normal, .light, .dark }) |keyword| {
            if (tokens.nameEql(token.value, keyword.name())) {
                _ = stream.next();
                return Value.kw(keyword);
            }
        }
        const decoded = try tokens.decode(options.allocator, token.value);
        defer options.allocator.free(decoded);
        if (!std.mem.startsWith(u8, decoded, "--")) return null;
        _ = stream.next();
        const name = try @import("serialize.zig").serializeIdentifier(options.allocator, decoded);
        defer options.allocator.free(name);
        return .{ .text = try values.SharedText.create(options.allocator, name) };
    }
    if (token.token_type != .function or !tokens.nameEql(token.value, "palette-mix")) return null;
    // Check before allocating the next composite. Depth0 is the first mix.
    if (depth >= max_mix_depth) return null;
    _ = stream.next();
    if (!take(stream, .left_paren)) return null;
    var method: gradients.Method = .{ .space = .oklab };
    const header = stream.peek();
    if (header.token_type == .ident and tokens.nameEql(header.value, "in")) {
        _ = stream.next();
        method = gradients.interpolation(stream) orelse return null;
        if (!take(stream, .comma)) return null;
    }
    var entries: std.ArrayList(Entry) = .empty;
    defer {
        for (entries.items) |entry| entry.release();
        entries.deinit(options.allocator);
    }
    while (true) {
        var weight = try percentage(options, stream);
        var owned = true;
        defer if (owned) if (weight) |number| number.unref();
        const palette = try consumeAtDepth(options, stream, depth + 1) orelse return null;
        defer if (owned) palette.release();
        if (weight == null) weight = try percentage(options, stream);
        try entries.append(options.allocator, .{ .palette = palette, .weight = weight });
        owned = false;
        if (take(stream, .right_paren) or stream.atEnd()) break;
        if (!take(stream, .comma)) return null;
    }
    return .{ .palette_mix = try Mix.take(options.allocator, method, &entries) };
}

fn percentage(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Number {
    return Number.consume(options, stream, .{ .kind = .percentage, .minimum = 0, .maximum = 100 }, false);
}
fn take(stream: *Stream, kind: tokens.TokenType) bool {
    if (stream.peek().token_type != kind) return false;
    _ = stream.next();
    return true;
}

/// CSS Fonts 4 9.1 font-palette, "Animation type: by computed value": two
/// computed palettes interpolate as `palette-mix(in oklab, A, B p%)`
/// (Fonts 4 9.2 palette-mix(); WPT css/css-fonts/animations/font-palette-
/// interpolation.html, which Chrome and Safari pass), which simplifies to the
/// palette when both sides are equivalent (Q33's `equivalent`, as computing a
/// palette-mix() does). For 0 < p < 1; the caller keeps the endpoints. OWNED.
pub fn interpolatePalettes(allocator: Allocator, a: Value, b: Value, p: f64) Allocator.Error!Value {
    var entries: std.ArrayList(Entry) = .empty;
    defer {
        for (entries.items) |entry| entry.release();
        entries.deinit(allocator);
    }
    try entries.ensureTotalCapacity(allocator, 2);
    a.retain();
    entries.appendAssumeCapacity(.{ .palette = a, .weight = null });
    b.retain();
    entries.appendAssumeCapacity(.{ .palette = b, .weight = Number.percent(p * 100) });
    const method: gradients.Method = .{ .space = .oklab };
    if (equivalent(method, entries.items)) |palette| {
        palette.retain();
        return palette;
    }
    return .{ .palette_mix = try Mix.take(allocator, method, &entries) };
}
