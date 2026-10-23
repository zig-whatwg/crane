//! SVG2 §13.2: paint servers retain their URL and optional fallback paint.
//! No resource is fetched here; URL provenance survives every value copy.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokenizer = @import("tokenizer.zig");
const Color = values.Color;
const Allocator = std.mem.Allocator;
const Value = values.Value;

pub const Paint = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    /// An owned URL value, with its ResourceUrl metadata.
    url: Value,
    /// null means no explicit fallback; otherwise only none or a color.
    fallback: ?Value,

    /// Retains both borrowed arguments. Failure leaves ownership unchanged.
    pub fn create(allocator: Allocator, url: Value, fallback: ?Value) Allocator.Error!*Paint {
        const self = try allocator.create(Paint);
        self.* = .{ .allocator = allocator, .url = url, .fallback = fallback };
        url.retain();
        if (fallback) |f| retainFallback(f);
        return self;
    }

    pub fn ref(self: *Paint) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }

    pub fn unref(self: *Paint) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        self.url.release();
        if (self.fallback) |f| releaseFallback(f);
        self.allocator.destroy(self);
    }

    pub fn needsTreeCounts(self: *const Paint) bool {
        return if (self.fallback) |f| f == .color and f.color.needsTreeCounts() else false;
    }

    pub fn needsRandomBase(self: *const Paint) bool {
        return if (self.fallback) |f| f == .color and f.color.needsRandomBase() else false;
    }

    pub fn needsUnavailableMetrics(self: *const Paint, geometry_length: bool) bool {
        return if (self.fallback) |f| f == .color and f.color.needsUnavailableMetrics(geometry_length) else false;
    }

    pub fn eql(self: *const Paint, other: *const Paint) bool {
        if (self == other) return true;
        if (!self.url.eql(other.url)) return false;
        if (self.fallback) |f| return if (other.fallback) |o| f.eql(o) else false;
        return other.fallback == null;
    }

    pub fn serialize(self: *const Paint, out: *std.ArrayList(u8), allocator: Allocator, current: ?Color) Allocator.Error!void {
        if (current != null) {
            try @import("resolved_urls.zig").serialize(.list_style_image, self.url, out, allocator);
        } else try properties.serializeValue(.list_style_image, self.url, out, allocator);
        if (self.fallback) |f| {
            try out.append(allocator, ' ');
            try serializeColorOrKeyword(f, out, allocator, current);
        }
    }
};

pub fn isUrl(token: tokenizer.Token) bool {
    return token.token_type == .url or (token.token_type == .function and
        (tokenizer.nameEql(token.value, "url") or tokenizer.nameEql(token.value, "src")));
}

/// SVG2 §13.7.4 marker reference: none or one URL, never an arbitrary image.
pub fn parseReference(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    if (takeKeyword(stream, .none)) return Value.kw(.none);
    if (!isUrl(stream.peek())) return null;
    return properties.parseLonghand(options, .list_style_image, stream);
}

/// SVG2 §13.2: none | color | url [none | color]? | context-fill | context-stroke.
/// Blink ConsumeSVGPaint uses the same ordering; no engine code is copied.
pub fn parse(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    // Color4 Appendix B limits hashless-color quirks to its named properties.
    var strict = options;
    strict.quirks = false;
    for ([_]values.Keyword{ .none, .context_fill, .context_stroke }) |k| {
        if (takeKeyword(stream, k)) return Value.kw(k);
    }
    if (isUrl(stream.peek())) {
        const url = (try parseReference(options, stream)) orelse return null;
        defer url.release();
        var fallback: ?Value = null;
        defer if (fallback) |f| releaseFallback(f);
        if (takeKeyword(stream, .none)) {
            fallback = Value.kw(.none);
        } else {
            const saved = stream.*;
            fallback = try properties.parseLonghand(strict, .color, stream);
            if (fallback == null) stream.* = saved;
        }
        return .{ .paint = try Paint.create(options.allocator, url, fallback) };
    }
    return properties.parseLonghand(strict, .color, stream);
}

fn takeKeyword(stream: *properties.Stream, k: values.Keyword) bool {
    const t = stream.peek();
    if (t.token_type != .ident or !tokenizer.nameEql(t.value, k.name())) return false;
    _ = stream.next();
    return true;
}

/// SVG2's computed paint keeps currentcolor for inheritance. CSSOM resolves
/// that color against the receiver when a resolved value is requested.
pub fn compute(value: Value, allocator: Allocator, context: Color.Context) Allocator.Error!Value {
    if (value == .paint) {
        if (value.paint.fallback) |fallback| {
            const computed = try computeColor(fallback, allocator, context);
            defer releaseFallback(computed);
            if (!computed.eql(fallback)) return .{ .paint = try Paint.create(allocator, value.paint.url, computed) };
        }
        value.retain();
        return value;
    }
    return computeColor(value, allocator, context);
}

fn computeColor(value: Value, allocator: Allocator, context: Color.Context) Allocator.Error!Value {
    if (value == .color) return .{ .color = try value.color.resolveComputed(allocator, context) };
    value.retain();
    return value;
}

fn retainFallback(value: Value) void {
    if (value == .color) value.color.retain() else value.retain();
}

fn releaseFallback(value: Value) void {
    if (value == .color) value.color.release() else value.release();
}

pub fn serializeResolved(value: Value, current: Color, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    if (value == .paint) return value.paint.serialize(out, allocator, current);
    return serializeColorOrKeyword(value, out, allocator, current);
}

fn serializeColorOrKeyword(value: Value, out: *std.ArrayList(u8), allocator: Allocator, current: ?Color) Allocator.Error!void {
    if (value == .color) {
        if (current) |color| {
            const resolved = try value.color.resolveComputed(allocator, .{ .current = color });
            defer resolved.release();
            return resolved.serializeComputed(out, allocator);
        }
        return value.color.serializeSpecified(out, allocator);
    }
    return properties.serializeValue(.color, value, out, allocator);
}

/// SVG2 §13.7.4: marker is exactly the same reference on all three positions.
pub fn parseMarker(options: properties.ParseOptions, stream: *properties.Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    const value = (try parseReference(options, stream)) orelse return false;
    defer value.release();
    if (!stream.atEnd()) return false;
    try out.ensureUnusedCapacity(options.allocator, 3);
    for (properties.Shorthand.marker.longhands()) |longhand| {
        value.retain();
        out.appendAssumeCapacity(.{ .longhand = longhand, .value = .{ .value = value } });
    }
    return true;
}

pub fn serializeMarker(vs: []const properties.Assigned, mode: properties.ShorthandMode, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    if (mode == .computed) {
        // CSSOM compares computed longhands, whose resolved references may
        // differ from their authored text in either direction.
        var first: std.ArrayList(u8) = .empty;
        defer first.deinit(allocator);
        var other: std.ArrayList(u8) = .empty;
        defer other.deinit(allocator);
        try @import("resolved_urls.zig").serialize(.marker_start, vs[0].value, &first, allocator);
        for (vs[1..]) |v| {
            other.clearRetainingCapacity();
            try @import("resolved_urls.zig").serialize(.marker_start, v.value, &other, allocator);
            if (!std.mem.eql(u8, first.items, other.items)) return false;
        }
        try out.appendSlice(allocator, first.items);
        return true;
    }
    for (vs[1..]) |v| if (!v.value.eql(vs[0].value)) return false;
    try properties.serializeValue(.marker_start, vs[0].value, out, allocator);
    return true;
}

/// SVG2 §13.5.3 includes <number> in stroke-width's CSS grammar itself.
/// Number-to-px computation is independent of presentation attributes.
pub fn parseStrokeWidth(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    const token = stream.peek();
    if (token.token_type == .number) {
        const number = token.numeric_value orelse return null;
        if (!std.math.isFinite(number) or number < 0) return null;
        _ = stream.next();
        // Firefox/Safari preserve zero as a length; other numbers stay numbers.
        return if (number == 0) Value.px(0) else .{ .number = number };
    }
    return properties.parseLonghand(options, .padding_left, stream);
}
