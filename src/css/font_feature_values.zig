//! Fonts 4 §§4.9.1, 6.9 and 12.2: native @font-feature-values data.
//! The existing Syntax and font-family parsers supply its parsed inputs.
const std = @import("std");
const properties = @import("properties.zig");
const rules = @import("rules.zig");
const families = @import("font_family.zig");
const values = @import("style_values.zig");
const serialize = @import("serialize.zig");
const tokens = @import("tokenizer.zig");
const Allocator = std.mem.Allocator;

pub const Block = enum {
    swash,
    stylistic,
    ornaments,
    annotation,
    character_variant,
    styleset,

    pub fn name(self: Block) []const u8 {
        return if (self == .character_variant) "character-variant" else @tagName(self);
    }

    pub fn parse(name_text: []const u8) ?Block {
        inline for (@typeInfo(Block).@"enum".field_values) |field_value| {
            const block: Block = @enumFromInt(field_value);
            if (std.mem.eql(u8, name_text, block.name())) return block;
        }
        // Q33 probe (Chrome 156, Firefox 158, Safari 27, 2026-10-27):
        // all three drop @historical-forms and expose no corresponding map.
        return null;
    }

    fn sourceLimit(self: Block) usize {
        return switch (self) {
            .character_variant => 2,
            .styleset => std.math.maxInt(usize),
            else => 1,
        };
    }
};

pub const Map = struct {
    entries: std.StringArrayHashMapUnmanaged([]u32) = .empty,

    pub fn deinit(self: *Map, allocator: Allocator) void {
        self.clear(allocator);
        self.entries.deinit(allocator);
    }

    pub fn clear(self: *Map, allocator: Allocator) void {
        for (self.entries.keys(), self.entries.values()) |key, indexes| {
            allocator.free(key);
            allocator.free(indexes);
        }
        self.entries.clearRetainingCapacity();
    }

    pub fn get(self: *const Map, name_text: []const u8) ?[]const u32 {
        return self.entries.get(name_text);
    }

    /// Maplike set preserves position when replacing a name. Allocate the
    /// replacement before changing anything, so an OOM leaves it unchanged.
    /// Q33: the sole map shipper, Chrome, accepts every sequence length;
    /// parsed source declarations still use the block's grammar below.
    pub fn set(self: *Map, allocator: Allocator, name_text: []const u8, indexes: []const u32) Allocator.Error!void {
        const copy = try allocator.dupe(u32, indexes);
        errdefer allocator.free(copy);
        if (self.entries.getPtr(name_text)) |previous| {
            allocator.free(previous.*);
            previous.* = copy;
            return;
        }
        const key = try allocator.dupe(u8, name_text);
        errdefer allocator.free(key);
        try self.entries.put(allocator, key, copy);
    }

    pub fn remove(self: *Map, allocator: Allocator, name_text: []const u8) bool {
        const previous = self.entries.fetchOrderedRemove(name_text) orelse return false;
        allocator.free(previous.key);
        allocator.free(previous.value);
        return true;
    }

    fn appendCss(self: *const Map, allocator: Allocator, out: *std.ArrayList(u8)) Allocator.Error!void {
        for (self.entries.keys(), self.entries.values()) |name_text, indexes| {
            const identifier = try serialize.serializeIdentifier(allocator, name_text);
            defer allocator.free(identifier);
            try out.appendSlice(allocator, identifier);
            try out.append(allocator, ':');
            for (indexes) |index| {
                try out.append(allocator, ' ');
                try values.appendNumber(@floatFromInt(index), out, allocator);
            }
            try out.appendSlice(allocator, "; ");
        }
    }
};

pub const FontDisplay = enum { auto, block, swap, fallback, optional };

pub const Data = struct {
    allocator: Allocator,
    font_families: *families.Families,
    font_display: ?FontDisplay = null,
    maps: [6]Map = [1]Map{.{}} ** 6,

    pub fn deinit(self: *Data) void {
        self.font_families.unref();
        for (&self.maps) |*map_value| map_value.deinit(self.allocator);
    }

    pub fn map(self: *Data, block: Block) *Map {
        return &self.maps[@intFromEnum(block)];
    }

    pub fn setFamily(self: *Data, text: []const u8) Allocator.Error!bool {
        const replacement = try parseFamily(self.allocator, text) orelse return false;
        self.font_families.unref();
        self.font_families = replacement;
        return true;
    }

    pub fn cssText(self: *const Data, allocator: Allocator) Allocator.Error![]u8 {
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try out.appendSlice(allocator, "@font-feature-values ");
        try out.appendSlice(allocator, self.font_families.text.bytes);
        try out.appendSlice(allocator, " { ");
        if (self.font_display) |display| {
            try out.appendSlice(allocator, "font-display: ");
            try out.appendSlice(allocator, @tagName(display));
            try out.appendSlice(allocator, "; ");
        }
        inline for (@typeInfo(Block).@"enum".field_values) |field_value| {
            const block: Block = @enumFromInt(field_value);
            const entries = &self.maps[field_value];
            if (entries.entries.count() != 0) {
                try out.append(allocator, '@');
                try out.appendSlice(allocator, block.name());
                try out.appendSlice(allocator, " { ");
                try entries.appendCss(allocator, &out);
                try out.appendSlice(allocator, "} ");
            }
        }
        try out.append(allocator, '}');
        return out.toOwnedSlice(allocator);
    }
};

pub fn parseFamily(allocator: Allocator, text: []const u8) Allocator.Error!?*families.Families {
    var stream = properties.Stream.init(text);
    const value = try families.parse(.{ .allocator = allocator }, &stream) orelse return null;
    const result = value.font_family;
    if (!stream.atEnd()) {
        result.unref();
        return null;
    }
    for (result.items) |family| if (family == .generic) {
        result.unref();
        return null;
    };
    return result;
}

pub fn fromParsed(allocator: Allocator, parsed: *const rules.Rule) Allocator.Error!?Data {
    if (!parsed.has_block) return null;
    var data: Data = .{ .allocator = allocator, .font_families = try parseFamily(allocator, parsed.prelude) orelse return null };
    errdefer data.deinit();
    for (parsed.declarations) |declaration| {
        if (declaration.important or !std.mem.eql(u8, declaration.name, "font-display")) continue;
        var stream = properties.Stream.init(declaration.value);
        const token = stream.next();
        if (token.token_type != .ident or !stream.atEnd()) continue;
        inline for (@typeInfo(FontDisplay).@"enum".field_names, @typeInfo(FontDisplay).@"enum".field_values) |field_name, field_value| {
            if (tokens.nameEql(token.value, field_name)) data.font_display = @enumFromInt(field_value);
        }
    }
    for (parsed.children) |child| {
        if (child.kind != .at_rule or !child.has_block or child.prelude.len != 0) continue;
        const block = Block.parse(child.name) orelse continue;
        for (child.declarations) |declaration| {
            if (declaration.important) continue;
            const indexes = try parseIndexes(allocator, block, declaration.value) orelse continue;
            defer allocator.free(indexes);
            try data.map(block).set(allocator, declaration.name, indexes);
        }
    }
    return data;
}

fn parseIndexes(allocator: Allocator, block: Block, text: []const u8) Allocator.Error!?[]u32 {
    var stream = properties.Stream.init(text);
    var indexes: std.ArrayList(u32) = .empty;
    defer indexes.deinit(allocator);
    while (!stream.atEnd()) {
        const token = stream.next();
        if (token.token_type != .number or !token.is_integer) return null;
        const value = token.numeric_value orelse return null;
        if (value < 0 or indexes.items.len == block.sourceLimit()) return null;
        // Q37 settles the representation limit separately from the small
        // OpenType index ranges (Q33 explicitly keeps values beyond those).
        try indexes.append(allocator, @intFromFloat(@min(value, std.math.maxInt(i32))));
    }
    if (indexes.items.len == 0) return null;
    return try indexes.toOwnedSlice(allocator);
}
