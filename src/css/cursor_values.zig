//! CSS UI 4 §5.1.1: ordered image cursors and their mandatory keyword fallback.
//! URL metadata belongs to the value; this module never loads a resource.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const resources = @import("resource_values.zig");
const tokenizer = @import("tokenizer.zig");
const math = @import("math_values.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;

/// One image alternative, tried only after preceding alternatives fail.
pub const Candidate = struct {
    image: values.Value,
    hotspot: ?[2]f64 = null,
    /// Q113: an owned specified math pair. A null hotspot with this present
    /// means pending coordinates, not an absent hotspot. Computation clears it.
    hotspot_values: ?[2]Value = null,

    pub const HotspotView = union(enum) { none, numeric: [2]f64, pending: [2]Value };

    /// Borrowed view; pending Values remain owned by the containing Cursor.
    pub fn hotspotView(self: Candidate) HotspotView {
        if (self.hotspot_values) |pair| return .{ .pending = pair };
        if (self.hotspot) |pair| return .{ .numeric = pair };
        return .none;
    }

    fn release(self: Candidate) void {
        self.image.release();
        if (self.hotspot_values) |pair| for (pair) |value| value.release();
    }

    fn eql(self: Candidate, other: Candidate) bool {
        if (!self.image.eql(other.image) or !std.meta.eql(self.hotspot, other.hotspot)) return false;
        if (self.hotspot_values) |pair| {
            const rhs = other.hotspot_values orelse return false;
            for (pair, rhs) |a, b| if (!a.eql(b)) return false;
        } else if (other.hotspot_values != null) return false;
        return true;
    }
};

/// An immutable owned fallback list, with CSSOM text and URL occurrence ranges.
pub const Cursor = struct {
    // UA declarations can be shared across Browser threads, like Content.
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    candidates: []const Candidate,
    fallback: values.Keyword,
    text: *values.SharedText,

    pub fn ref(self: *Cursor) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }

    pub fn unref(self: *Cursor) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        for (self.candidates) |candidate| candidate.release();
        self.allocator.free(self.candidates);
        self.text.unref();
        self.allocator.destroy(self);
    }

    pub fn eql(self: *const Cursor, other: *const Cursor) bool {
        if (self == other) return true;
        if (!std.mem.eql(u8, self.text.bytes, other.text.bytes) or self.candidates.len != other.candidates.len) return false;
        for (self.candidates, other.candidates) |a, b| if (!a.eql(b)) return false;
        return true;
    }

    pub fn needsUnavailableMetrics(self: *const Cursor, geometry_length: bool) bool {
        for (self.candidates) |candidate| {
            if (candidate.image.needsUnavailableMetrics(geometry_length)) return true;
            if (candidate.hotspot_values) |pair| for (pair) |value| {
                // UI4 §5.1.1 hotspots are numbers, never geometry lengths.
                if (value.needsUnavailableMetrics(false)) return true;
            };
        }
        return false;
    }

    pub fn needsTreeCounts(self: *const Cursor) bool {
        for (self.candidates) |candidate| {
            if (candidate.image.needsTreeCounts()) return true;
            if (candidate.hotspot_values) |pair| for (pair) |value| {
                if (value.needsTreeCounts()) return true;
            };
        }
        return false;
    }

    pub fn needsRandomBase(self: *const Cursor) bool {
        for (self.candidates) |candidate| {
            if (candidate.image.needsRandomBase()) return true;
            if (candidate.hotspot_values) |pair| for (pair) |value| {
                if (value.needsRandomBase()) return true;
            };
        }
        return false;
    }

    pub fn compute(self: *const Cursor, allocator: Allocator, context: anytype) Allocator.Error!*Cursor {
        const items = try allocator.alloc(Candidate, self.candidates.len);
        var initialized: usize = 0;
        errdefer {
            for (items[0..initialized]) |item| item.release();
            allocator.free(items);
        }
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        var urls = resources.Builder{ .allocator = allocator };
        defer urls.deinit();
        for (self.candidates, items) |item, *dest| {
            dest.* = .{ .image = try context.component(.list_style_image, item.image) };
            initialized += 1;
            switch (item.hotspotView()) {
                .none => {},
                .numeric => |point| dest.hotspot = point,
                .pending => |pair| {
                    var point: [2]f64 = undefined;
                    for (pair, &point) |value, *coordinate| {
                        const computed = try context.length(value);
                        defer computed.release();
                        // The parser's number grammar and unavailable-input
                        // gate guarantee a scalar here, with the real Source.
                        std.debug.assert(computed == .number);
                        coordinate.* = computed.number;
                    }
                    dest.hotspot = point;
                },
            }
            try urls.append(dest.image.resourceUrls(), out.items.len);
            try properties.serializeValue(.list_style_image, dest.image, &out, allocator);
            try serializeHotspot(dest.*, &out, allocator);
            try out.appendSlice(allocator, ", ");
        }
        try out.appendSlice(allocator, self.fallback.name());
        const text = try values.SharedText.create(allocator, out.items);
        errdefer text.unref();
        text.resource_urls = try urls.take();
        const result = try allocator.create(Cursor);
        result.* = .{ .allocator = allocator, .candidates = items, .fallback = self.fallback, .text = text };
        return result;
    }
};

const keywords = [_]values.Keyword{
    .auto,        .default,    .none,     .context_menu,  .help,      .pointer,     .progress,    .wait,
    .cell,        .crosshair,  .text,     .vertical_text, .alias,     .copy,        .move,        .no_drop,
    .not_allowed, .grab,       .grabbing, .e_resize,      .n_resize,  .ne_resize,   .nw_resize,   .s_resize,
    .se_resize,   .sw_resize,  .w_resize, .ew_resize,     .ns_resize, .nesw_resize, .nwse_resize, .col_resize,
    .row_resize,  .all_scroll, .zoom_in,  .zoom_out,
};

fn keyword(token: tokenizer.Token) ?values.Keyword {
    if (token.token_type != .ident) return null;
    for (keywords) |k| if (tokenizer.nameEql(token.value, k.name())) return k;
    return null;
}

/// Parse `[ <cursor-image> , ]* <cursor-predefined>` over CSS tokens.
/// Typed image choices retain URL-only restrictions through nested branches.
pub fn parse(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?values.Value {
    const allocator = options.allocator;
    if (keyword(stream.peek())) |k| {
        _ = stream.next();
        return values.Value.kw(k);
    }
    var candidates: std.ArrayList(Candidate) = .empty;
    defer {
        for (candidates.items) |candidate| candidate.release();
        candidates.deinit(allocator);
    }
    // CSSOM §6.7.2 steps 2–5: canonical components, separated by spaces/commas.
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    var urls = resources.Builder{ .allocator = allocator };
    defer urls.deinit();
    while (true) {
        // UI4 §5.1.1: URL-set choices admit no generated cursor images.
        const image = try @import("image_values.zig").parse(options, stream, .{ .generated = false }) orelse return null;
        var candidate = Candidate{ .image = image };
        var transferred = false;
        defer if (!transferred) candidate.release();
        // CSS UI4 §5.1.1: a hotspot is an optional PAIR of numbers.
        if (!try parseHotspot(options, stream, &candidate)) return null;
        if (stream.next().token_type != .comma) return null;
        try urls.append(image.resourceUrls(), output.items.len);
        try properties.serializeValue(.list_style_image, image, &output, allocator);
        try serializeHotspot(candidate, &output, allocator);
        try output.appendSlice(allocator, ", ");
        try candidates.append(allocator, candidate);
        transferred = true;
        if (keyword(stream.peek())) |fallback| {
            _ = stream.next();
            try output.appendSlice(allocator, fallback.name());
            const text = try values.SharedText.create(allocator, output.items);
            errdefer text.unref();
            text.resource_urls = try urls.take();
            const owned = try candidates.toOwnedSlice(allocator);
            errdefer {
                for (owned) |item| item.release();
                allocator.free(owned);
            }
            const cursor = try allocator.create(Cursor);
            cursor.* = .{ .allocator = allocator, .candidates = owned, .fallback = fallback, .text = text };
            return .{ .cursor = cursor };
        }
    }
}

fn hotspotNumber(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    const token = stream.peek();
    if (token.token_type == .number) {
        _ = stream.next();
        return .{ .number = token.numeric_value orelse return null };
    }
    if (math.isFunction(token)) return properties.mathValue(options, stream, .{ .kind = .number });
    return null;
}

fn parseHotspot(options: properties.ParseOptions, stream: *properties.Stream, candidate: *Candidate) Allocator.Error!bool {
    if (stream.peek().token_type != .number and !math.isFunction(stream.peek())) return true;
    const x = try hotspotNumber(options, stream) orelse return false;
    defer x.release();
    const y = try hotspotNumber(options, stream) orelse return false;
    defer y.release();
    if (x == .number and y == .number) {
        candidate.hotspot = .{ x.number, y.number };
    } else {
        x.retain();
        y.retain();
        candidate.hotspot_values = .{ x, y };
    }
    return true;
}

fn serializeHotspot(candidate: Candidate, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    switch (candidate.hotspotView()) {
        .none => {},
        .numeric => |pair| for (pair) |coordinate| {
            try out.append(allocator, ' ');
            try values.appendNumber(coordinate, out, allocator);
        },
        .pending => |pair| for (pair) |value| {
            try out.append(allocator, ' ');
            try properties.serializeValue(.margin_left, value, out, allocator);
        },
    }
}
