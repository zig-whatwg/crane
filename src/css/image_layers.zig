//! Owned comma-separated image/property layers, reused by masks/backgrounds.
//! Each Value keeps its own metadata; the aggregate keeps CSSOM byte ranges.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const resources = @import("resource_values.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;

pub const Layers = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    items: []const Value,
    text: *values.SharedText,

    /// Retain borrowed components only after all fallible operations succeed.
    pub fn create(allocator: Allocator, longhand: properties.Longhand, items: []const Value) Allocator.Error!*Layers {
        std.debug.assert(items.len != 0);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        var urls = resources.Builder{ .allocator = allocator };
        defer urls.deinit();
        for (items, 0..) |v, i| {
            if (i > 0) try out.appendSlice(allocator, ", ");
            try urls.append(v.resourceUrls(), out.items.len);
            try properties.serializeValue(longhand, v, &out, allocator);
        }
        const text = try values.SharedText.create(allocator, out.items);
        errdefer text.unref();
        text.resource_urls = try urls.take();
        const owned = try allocator.dupe(Value, items);
        errdefer allocator.free(owned);
        const self = try allocator.create(Layers);
        self.* = .{ .allocator = allocator, .items = owned, .text = text };
        for (owned) |v| v.retain();
        return self;
    }
    pub fn ref(self: *Layers) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Layers) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        for (self.items) |v| v.release();
        self.allocator.free(self.items);
        self.text.unref();
        self.allocator.destroy(self);
    }
    pub fn needsUnavailableMetrics(self: *const Layers, geometry_length: bool) bool {
        for (self.items) |value| if (value.needsUnavailableMetrics(geometry_length)) return true;
        return false;
    }

    pub fn needsTreeCounts(self: *const Layers) bool {
        for (self.items) |value| if (value.needsTreeCounts()) return true;
        return false;
    }

    pub fn needsRandomBase(self: *const Layers) bool {
        for (self.items) |value| if (value.needsRandomBase()) return true;
        return false;
    }

    pub fn eql(self: *const Layers, other: *const Layers) bool {
        if (self == other) return true;
        if (self.items.len != other.items.len) return false;
        for (self.items, other.items) |a, b| if (!a.eql(b)) return false;
        return true;
    }

    pub fn compute(self: *const Layers, allocator: Allocator, longhand: properties.Longhand, context: anytype) Allocator.Error!*Layers {
        // Values4 Appendix A / csswg-drafts#12791: computed lists keep
        // their own lengths. WebKit 314242@main and WPT 1203773547 ship
        // this newer rule; Chrome/Firefox's used-list expansion lags it.
        const items = try allocator.alloc(Value, self.items.len);
        var initialized: usize = 0;
        defer {
            for (items[0..initialized]) |v| v.release();
            allocator.free(items);
        }
        while (initialized < items.len) : (initialized += 1) items[initialized] = try context.component(longhand, self.items[initialized]);
        return create(allocator, longhand, items);
    }
};

/// A scalar is the one-layer representation used by initial values too.
pub fn count(value: Value) usize {
    return if (value == .layers) value.layers.items.len else 1;
}
/// Borrowed; caller supplies an index below count(). This does not perform
/// USED-list matching, which is a separate image-count-based operation.
pub fn at(value: Value, index: usize) Value {
    if (value == .layers) return value.layers.items[index];
    std.debug.assert(index == 0);
    return value;
}

/// Masking §7.10.2 / Backgrounds §2.1: call for each IMAGE layer only.
/// Repetition never adds images, and excess ancillary entries stay unused.
pub fn atUsed(value: Value, image_index: usize) Value {
    return at(value, image_index % count(value));
}

/// Parse a nonempty list with a property's component parser. A scalar keeps
/// its existing representation; two or more components acquire a Layers.
pub fn parse(options: properties.ParseOptions, longhand: properties.Longhand, stream: *properties.Stream, comptime parseOne: anytype) Allocator.Error!?Value {
    var items: std.ArrayList(Value) = .empty;
    defer {
        for (items.items) |v| v.release();
        items.deinit(options.allocator);
    }
    while (true) {
        const v = (try parseOne(options, longhand, stream)) orelse return null;
        errdefer v.release();
        try items.append(options.allocator, v);
        if (stream.peek().token_type != .comma) break;
        _ = stream.next();
    }
    if (items.items.len == 1) {
        items.items[0].retain();
        return items.items[0];
    }
    return .{ .layers = try Layers.create(options.allocator, longhand, items.items) };
}
