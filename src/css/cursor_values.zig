//! CSS UI 4 §5.1.1: ordered image cursors and their mandatory keyword fallback.
//! URL metadata belongs to the value; this module never loads a resource.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const resources = @import("resource_values.zig");
const tokenizer = @import("tokenizer.zig");
const Allocator = std.mem.Allocator;

/// One image alternative, tried only after preceding alternatives fail.
pub const Candidate = struct {
    image: values.Value,
    hotspot: ?[2]f64 = null,
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
        for (self.candidates) |candidate| candidate.image.release();
        self.allocator.free(self.candidates);
        self.text.unref();
        self.allocator.destroy(self);
    }

    pub fn eql(self: *const Cursor, other: *const Cursor) bool {
        if (self == other) return true;
        if (!std.mem.eql(u8, self.text.bytes, other.text.bytes) or self.candidates.len != other.candidates.len) return false;
        for (self.candidates, other.candidates) |a, b| if (!a.image.eql(b.image)) return false;
        return true;
    }

    pub fn needsUnavailableMetrics(self: *const Cursor, geometry_length: bool) bool {
        for (self.candidates) |candidate| if (candidate.image.needsUnavailableMetrics(geometry_length)) return true;
        return false;
    }

    pub fn needsTreeCounts(self: *const Cursor) bool {
        for (self.candidates) |candidate| if (candidate.image.needsTreeCounts()) return true;
        return false;
    }

    pub fn needsRandomBase(self: *const Cursor) bool {
        for (self.candidates) |candidate| if (candidate.image.needsRandomBase()) return true;
        return false;
    }

    pub fn compute(self: *const Cursor, allocator: Allocator, context: anytype) Allocator.Error!*Cursor {
        const items = try allocator.alloc(Candidate, self.candidates.len);
        var initialized: usize = 0;
        errdefer {
            for (items[0..initialized]) |item| item.image.release();
            allocator.free(items);
        }
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        var urls = resources.Builder{ .allocator = allocator };
        defer urls.deinit();
        for (self.candidates, items) |item, *dest| {
            dest.* = .{ .image = try context.component(.list_style_image, item.image), .hotspot = item.hotspot };
            initialized += 1;
            try urls.append(dest.image.resourceUrls(), out.items.len);
            try properties.serializeValue(.list_style_image, dest.image, &out, allocator);
            if (dest.hotspot) |point| for (point) |coordinate| {
                try out.append(allocator, ' ');
                try values.appendNumber(coordinate, &out, allocator);
            };
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
        for (candidates.items) |candidate| candidate.image.release();
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
        defer if (!transferred) image.release();
        // CSS UI4 §5.1.1: a hotspot is an optional PAIR of numbers.
        if (stream.peek().token_type == .number) {
            const x = stream.next().numeric_value orelse return null;
            const y = stream.next();
            if (y.token_type != .number) return null;
            candidate.hotspot = .{ x, y.numeric_value orelse return null };
        }
        if (stream.next().token_type != .comma) return null;
        try urls.append(image.resourceUrls(), output.items.len);
        try properties.serializeValue(.list_style_image, image, &output, allocator);
        if (candidate.hotspot) |point| {
            for (point) |coordinate| {
                try output.append(allocator, ' ');
                try values.appendNumber(coordinate, &output, allocator);
            }
        }
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
                for (owned) |item| item.image.release();
                allocator.free(owned);
            }
            const cursor = try allocator.create(Cursor);
            cursor.* = .{ .allocator = allocator, .candidates = owned, .fallback = fallback, .text = text };
            return .{ .cursor = cursor };
        }
    }
}
