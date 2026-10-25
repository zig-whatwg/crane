//! CSS Properties and Values API §§2.4, 5: matching and computing syntax values.
//! Input has already passed substitution. Existing value owners parse each
//! component, and every successful result owns its strings and references.
const std = @import("std");
const syntax = @import("syntax_definitions.zig");
const properties = @import("properties.zig");
const style = @import("style_values.zig");
const math = @import("math_values.zig");
const tokens = @import("tokenizer.zig");
const transforms = @import("transform_functions.zig");
const Number = @import("numeric_values.zig").Number;
const Allocator = std.mem.Allocator;

pub const ComputeContext = struct {
    math: math.Context = .{},
    color: style.Color.Context = .{},
    writing_mode: style.Keyword = .horizontal_tb,
    direction: style.Keyword = .ltr,
};

/// Resource values retain their frozen provenance through computation.
pub const Resource = struct { value: style.Value, computed: bool = false };

pub const Item = union(enum) {
    numeric: struct { data_type: syntax.DataType, number: Number },
    color: style.Color,
    image: Resource,
    url: Resource,
    ident: []const u8,
    string: []const u8,
    transform: transforms.Function,

    fn deinit(self: *Item, allocator: Allocator) void {
        switch (self.*) {
            .numeric => |n| n.number.unref(),
            .color => |c| c.release(),
            .image, .url => |r| r.value.release(),
            .ident, .string => |s| allocator.free(s),
            .transform => |*f| f.deinit(),
        }
        self.* = undefined;
    }

    fn serialize(self: Item, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self) {
            .numeric => |n| try n.number.serialize(out, allocator),
            .color => |c| try c.serializeSpecified(out, allocator),
            .image, .url => |r| if (r.computed)
                try @import("resolved_urls.zig").serialize(.list_style_image, r.value, out, allocator)
            else
                try properties.serializeValue(.list_style_image, r.value, out, allocator),
            .ident => |s| {
                const escaped = try @import("serialize.zig").serializeIdentifier(allocator, s);
                defer allocator.free(escaped);
                try out.appendSlice(allocator, escaped);
            },
            .string => |s| try style.appendString(s, out, allocator),
            .transform => |f| try f.serialize(out, allocator),
        }
    }

    fn compute(self: Item, allocator: Allocator, context: ComputeContext) Allocator.Error!Item {
        var number_context = context.math;
        number_context.percentage_basis = null;
        var color_context = context.color;
        color_context.math = number_context;
        return switch (self) {
            .numeric => |n| .{ .numeric = .{ .data_type = n.data_type, .number = try n.number.compute(allocator, number_context) } },
            .color => |c| .{ .color = try c.resolveComputed(allocator, color_context) },
            .image => |r| .{ .image = .{ .value = try (ImageContext{
                .allocator = allocator,
                .context = context,
                .writing_mode = context.writing_mode,
                .direction = context.direction,
            }).component(.list_style_image, r.value), .computed = true } },
            .url => |r| blk: {
                r.value.retain();
                break :blk .{ .url = .{ .value = r.value, .computed = true } };
            },
            .ident => |s| .{ .ident = try allocator.dupe(u8, s) },
            .string => |s| .{ .string = try allocator.dupe(u8, s) },
            .transform => |f| .{ .transform = try f.compute(allocator, number_context) },
        };
    }
};

pub const Value = struct {
    allocator: Allocator,
    data: union(enum) {
        universal: []const u8,
        single: Item,
        list: struct { separator: enum { space, comma }, items: []Item },
    },

    pub fn deinit(self: *Value) void {
        switch (self.data) {
            .universal => |s| self.allocator.free(s),
            .single => |*item| item.deinit(self.allocator),
            .list => |list| {
                for (list.items) |*item| item.deinit(self.allocator);
                self.allocator.free(list.items);
            },
        }
        self.* = undefined;
    }

    pub fn serialize(self: Value, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self.data) {
            .universal => |s| try out.appendSlice(allocator, s),
            .single => |item| try item.serialize(out, allocator),
            .list => |list| for (list.items, 0..) |item, i| {
                if (i != 0) try out.appendSlice(allocator, if (list.separator == .comma) ", " else " ");
                try item.serialize(out, allocator);
            },
        }
    }

    pub fn compute(self: Value, allocator: Allocator, context: ComputeContext) Allocator.Error!Value {
        return .{ .allocator = allocator, .data = switch (self.data) {
            .universal => |s| .{ .universal = try allocator.dupe(u8, s) },
            .single => |item| .{ .single = try item.compute(allocator, context) },
            .list => |list| blk: {
                const items = try allocator.alloc(Item, list.items.len);
                errdefer allocator.free(items);
                var count: usize = 0;
                errdefer for (items[0..count]) |*item| item.deinit(allocator);
                for (list.items, items) |item, *dest| {
                    dest.* = try item.compute(allocator, context);
                    count += 1;
                }
                break :blk .{ .list = .{ .separator = list.separator, .items = items } };
            },
        } };
    }

    /// Registration validation only, on the EXACT source parseValue matched.
    /// The source is necessary: math simplification may cancel relative units.
    /// Q7 keeps this work off ordinary matching and computation paths.
    pub fn isComputationallyIndependent(self: Value, source: []const u8) bool {
        const universal = self.data == .universal;
        if (!universal) {
            const item = switch (self.data) {
                .single => |item| item,
                .list => |list| list.items[0], // A repetition has one base type.
                .universal => unreachable,
            };
            // Browser ruling Q5: images and colors are not traversed, even
            // when they contain relative lengths or currentcolor.
            if (item != .numeric and item != .transform) return true;
        }
        var tokenizer = tokens.Tokenizer.init(source);
        while (true) {
            const token = tokenizer.next();
            if (token.token_type == .eof) return true;
            if (token.token_type == .function) {
                if (universal) {
                    inline for (.{ "var", "env", "attr" }) |name| if (tokens.nameEql(token.value, name)) return false;
                } else {
                    inline for (.{ "random", "random-item", "sibling-index", "sibling-count" }) |name| if (tokens.nameEql(token.value, name)) return false;
                }
            }
            if (!universal and token.token_type == .dimension) {
                const unit = token.unit orelse continue;
                inline for (.{ "em", "rem", "ex", "rex", "cap", "rcap", "ch", "rch", "ic", "ric", "lh", "rlh", "cqw", "cqh", "cqi", "cqb", "cqmin", "cqmax" }) |name|
                    if (tokens.nameEql(unit, name)) return false;
            }
        }
    }
};

/// §5.3: alternatives are tried in order; each must consume the whole value.
pub fn parse(definition: *const syntax.Definition, options: properties.ParseOptions, text: []const u8) Allocator.Error!?Value {
    if (!@import("rules.zig").isDeclarationValue(text)) return null;
    var stream = properties.Stream.init(text);
    const first = stream.next();
    if (first.token_type == .ident and stream.atEnd()) {
        const decoded = try tokens.decode(options.allocator, first.value);
        defer options.allocator.free(decoded);
        if (style.CssWide.parse(decoded) != null) return null;
    }
    if (definition.universal) return .{ .allocator = options.allocator, .data = .{ .universal = try options.allocator.dupe(u8, text) } };
    for (definition.components) |component| {
        stream = properties.Stream.init(text);
        var strict = options;
        strict.quirks = false;
        strict.svg_presentation = false;
        if (try parseComponent(component, strict, &stream)) |value| return value;
    }
    return null;
}

fn parseComponent(component: syntax.Component, options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    const transform_list = component.name == .data_type and component.name.data_type == .transform_list;
    if (component.multiplier == .single and !transform_list) {
        var item = try consumeItem(component, options, stream) orelse return null;
        if (!stream.atEnd()) {
            item.deinit(options.allocator);
            return null;
        }
        return .{ .allocator = options.allocator, .data = .{ .single = item } };
    }
    var items: std.ArrayList(Item) = .empty;
    defer {
        for (items.items) |*item| item.deinit(options.allocator);
        items.deinit(options.allocator);
    }
    const comma = component.multiplier == .comma_list;
    while (true) {
        var item = try consumeItem(component, options, stream) orelse return null;
        items.append(options.allocator, item) catch |err| {
            item.deinit(options.allocator);
            return err;
        };
        if (stream.atEnd()) break;
        if (comma and stream.next().token_type != .comma) return null;
    }
    return .{ .allocator = options.allocator, .data = .{ .list = .{
        .separator = if (comma) .comma else .space,
        .items = try items.toOwnedSlice(options.allocator),
    } } };
}

fn consumeItem(component: syntax.Component, options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Item {
    if (component.name == .ident) return consumeIdent(options.allocator, stream, component.name.ident);
    const data_type = component.name.data_type;
    const grammar: ?math.Grammar = switch (data_type) {
        .length => .{ .kind = .length },
        .number => .{ .kind = .number },
        .percentage => .{ .kind = .percentage },
        .length_percentage => .{ .kind = .length_percentage },
        .integer => .{ .kind = .integer },
        .angle => .{ .kind = .angle },
        .time => .{ .kind = .time },
        .resolution => .{ .kind = .resolution, .minimum = 0 },
        else => null,
    };
    if (grammar) |g| {
        const number = try Number.consume(options, stream, g, data_type == .length or data_type == .length_percentage) orelse return null;
        return .{ .numeric = .{ .data_type = data_type, .number = number } };
    }
    return switch (data_type) {
        .color => if (try properties.parseLonghand(options, .color, stream)) |value| .{ .color = value.color } else null,
        .image => if (try @import("image_values.zig").parse(options, stream, .{})) |value| .{ .image = .{ .value = value } } else null,
        .url => blk: {
            const token = stream.peek();
            if (token.token_type != .url and !token.isFunction("url") and !token.isFunction("src")) break :blk null;
            const value = try properties.parseImageLeaf(options, stream) orelse break :blk null;
            break :blk .{ .url = .{ .value = value } };
        },
        .custom_ident => try consumeIdent(options.allocator, stream, null),
        .string => blk: {
            const token = stream.next();
            if (token.token_type != .string) break :blk null;
            break :blk .{ .string = try tokens.decode(options.allocator, token.stringContents()) };
        },
        .transform_function, .transform_list => if (try transforms.consume(options, stream)) |function| .{ .transform = function } else null,
        else => unreachable,
    };
}

fn consumeIdent(allocator: Allocator, stream: *properties.Stream, expected: ?[]const u8) Allocator.Error!?Item {
    const token = stream.next();
    if (token.token_type != .ident) return null;
    const decoded = try tokens.decode(allocator, token.value);
    if (!syntax.isCustomIdent(decoded) or (expected != null and !std.mem.eql(u8, decoded, expected.?))) {
        allocator.free(decoded);
        return null;
    }
    return .{ .ident = decoded };
}

// Adapter to existing image component computation; no borrowed context is
// retained by the resulting image. URL resolution is never repeated here.
const ImageContext = struct {
    allocator: Allocator,
    context: ComputeContext,
    writing_mode: style.Keyword,
    direction: style.Keyword,

    pub fn color(self: ImageContext, value: style.Color) Allocator.Error!style.Color {
        var ctx = self.context.color;
        ctx.math = self.context.math;
        ctx.math.percentage_basis = null;
        return value.resolveComputed(self.allocator, ctx);
    }

    pub fn length(self: ImageContext, value: style.Value) Allocator.Error!style.Value {
        var ctx = self.context.math;
        ctx.percentage_basis = null;
        if (value == .calculation) return .{ .calculation = try value.calculation.compute(self.allocator, ctx) };
        if (value == .length) {
            const unit: math.Unit = if (value.length.unit == .percent) .percent else math.Unit.parse(value.length.unit.toString()).?;
            const number = ctx.resolve(.{ .value = value.length.value, .unit = unit });
            return .{ .length = .init(number.value, if (number.unit == .percent) .percent else .px) };
        }
        value.retain();
        return value;
    }

    pub fn component(self: ImageContext, _: properties.Longhand, value: style.Value) Allocator.Error!style.Value {
        if (value == .image) return value.image.compute(self.allocator, self.context.color.scheme, self);
        value.retain();
        return value;
    }
};
