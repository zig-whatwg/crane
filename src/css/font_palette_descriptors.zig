//! Fonts4 §§9.2–9.2.3 and 12.3: owned palette descriptors for CSSOM.
//! Palette selection and painting do not run in the descriptor parser.
const std = @import("std");
const rules = @import("rules.zig");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokenizer = @import("tokenizer.zig");
const serialize = @import("serialize.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;

pub const Descriptor = enum {
    font_family,
    base_palette,
    override_colors,

    fn name(self: Descriptor) []const u8 {
        return switch (self) {
            .font_family => "font-family",
            .base_palette => "base-palette",
            .override_colors => "override-colors",
        };
    }
    fn parse(text: []const u8) ?Descriptor {
        inline for (@typeInfo(Descriptor).@"enum".field_values) |field_value| {
            const descriptor: Descriptor = @fromBackingInt(@intCast(field_value));
            if (std.mem.eql(u8, text, descriptor.name())) return descriptor;
        }
        return null;
    }
};

const Parsed = struct {
    text: []u8,
    /// Owned existing values, including unresolved typed math. No element
    /// or root context is manufactured for specified descriptor CSSOM.
    components: []Value,

    fn deinit(self: Parsed, allocator: Allocator) void {
        allocator.free(self.text);
        for (self.components) |component| component.release();
        allocator.free(self.components);
    }
};

pub const Data = struct {
    allocator: Allocator,
    /// Decoded for CSSFontPaletteValuesRule.name; cssText escapes it.
    name: []u8,
    descriptors: [3]?Parsed = @splat(null),

    pub fn deinit(self: *Data) void {
        self.allocator.free(self.name);
        for (self.descriptors) |descriptor| if (descriptor) |parsed| parsed.deinit(self.allocator);
    }

    pub fn get(self: *const Data, descriptor: Descriptor) []const u8 {
        return if (self.descriptors[@backingInt(descriptor)]) |parsed| parsed.text else "";
    }

    pub fn cssText(self: *const Data, allocator: Allocator) Allocator.Error![]u8 {
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        const name = try serialize.serializeIdentifier(allocator, self.name);
        defer allocator.free(name);
        try out.appendSlice(allocator, "@font-palette-values ");
        try out.appendSlice(allocator, name);
        try out.appendSlice(allocator, " { ");
        inline for (@typeInfo(Descriptor).@"enum".field_values) |field_value| {
            const descriptor: Descriptor = @fromBackingInt(@intCast(field_value));
            if (self.descriptors[field_value]) |parsed| {
                try out.appendSlice(allocator, descriptor.name());
                try out.appendSlice(allocator, ": ");
                try out.appendSlice(allocator, parsed.text);
                try out.appendSlice(allocator, "; ");
            }
        }
        try out.append(allocator, '}');
        return out.toOwnedSlice(allocator);
    }
};

pub fn fromParsed(allocator: Allocator, rule: *const rules.Rule) Allocator.Error!?Data {
    // Fonts4 §9.2: one dashed identifier and a declaration block.
    if (!rule.has_block) return null;
    var stream = properties.Stream.init(rule.prelude);
    const token = stream.next();
    if (token.token_type != .ident or !stream.atEnd()) return null;
    const name = try tokenizer.decode(allocator, token.value);
    if (!std.mem.startsWith(u8, name, "--")) {
        allocator.free(name);
        return null;
    }
    var result: Data = .{ .allocator = allocator, .name = name };
    errdefer result.deinit();
    for (rule.declarations) |declaration| {
        if (declaration.important) continue;
        const descriptor = Descriptor.parse(declaration.name) orelse continue;
        const parsed = try parseDescriptor(allocator, descriptor, declaration.value) orelse continue;
        if (result.descriptors[@backingInt(descriptor)]) |old| old.deinit(allocator);
        result.descriptors[@backingInt(descriptor)] = parsed;
    }
    // Row131 Q8: all three browsers retain a rule with no font-family in
    // cssRules. It has no used-palette effect; its CSSOM still survives.
    return result;
}

/// Consumes one owned value, including on allocation failure.
fn appendOwned(allocator: Allocator, components: *std.ArrayList(Value), value: Value) Allocator.Error!void {
    errdefer value.release();
    try components.append(allocator, value);
}

fn parseDescriptor(allocator: Allocator, descriptor: Descriptor, text: []const u8) Allocator.Error!?Parsed {
    const options: properties.ParseOptions = .{ .allocator = allocator };
    var stream = properties.Stream.init(text);
    var components: std.ArrayList(Value) = .empty;
    defer {
        for (components.items) |value| value.release();
        components.deinit(allocator);
    }
    switch (descriptor) {
        .font_family => {
            // §9.2.1: <family-name># excludes unquoted generic families.
            const families = try @import("font_feature_values.zig").parseFamily(allocator, text) orelse return null;
            try appendOwned(allocator, &components, .{ .font_family = families });
            stream = properties.Stream.init("");
        },
        .base_palette => {
            const token = stream.peek();
            if (token.token_type == .ident and (tokenizer.nameEql(token.value, "light") or tokenizer.nameEql(token.value, "dark"))) {
                _ = stream.next();
                try appendOwned(allocator, &components, Value.kw(if (tokenizer.nameEql(token.value, "light")) .light else .dark));
            } else {
                const integer = try @import("box_values.zig").consumeInteger(options, &stream, 0) orelse return null;
                try appendOwned(allocator, &components, integer);
            }
        },
        .override_colors => while (true) {
            // §9.2.3: duplicate indices remain ordered for serialization.
            const index = try @import("box_values.zig").consumeInteger(options, &stream, 0) orelse return null;
            try appendOwned(allocator, &components, index);
            const color = try properties.colorValue(options, &stream, properties.Longhand.color.info()) orelse return null;
            try appendOwned(allocator, &components, color);
            if (!color.color.isAbsolute()) return null;
            if (stream.peek().token_type != .comma) break;
            _ = stream.next();
        },
    }
    if (!stream.atEnd()) return null;
    // Values5 tree-counting functions are element-only. As in the shared
    // counter-style descriptor owner, inspect their typed dependency.
    for (components.items) |value| if (value.needsTreeCounts()) return null;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    for (components.items, 0..) |value, index| {
        if (descriptor == .override_colors and index > 0)
            try out.appendSlice(allocator, if (index % 2 == 0) ", " else " ");
        switch (value) {
            .font_family => |families| try out.appendSlice(allocator, families.text.bytes),
            .keyword => |keyword| try out.appendSlice(allocator, keyword.name()),
            .integer => |integer| try out.print(allocator, "{d}", .{integer}),
            .calculation => |expression| try expression.serialize(&out, allocator),
            .color => |color| try color.serializeSpecified(&out, allocator),
            else => unreachable, // Only the typed parsers above add components.
        }
    }
    const canonical = try out.toOwnedSlice(allocator);
    errdefer allocator.free(canonical);
    return .{ .text = canonical, .components = try components.toOwnedSlice(allocator) };
}
