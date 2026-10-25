//! CSS Font Loading3 §3.1 find-matching-font-faces input, with no DOM state.
//! Requests own names; views borrow only until their ComputedStyle changes.
const std = @import("std");
const properties = @import("properties.zig");
const declarations = @import("declarations.zig");
const cascade = @import("cascade.zig");
const computed = @import("computed_style.zig");
const family = @import("font_family.zig");
const system = @import("font_system.zig");
const tokenizer = @import("tokenizer.zig");
const math = @import("math_values.zig");
const Value = @import("style_values.zig").Value;
const Allocator = std.mem.Allocator;
pub const FamilyRef = family.FamilyRef;
pub const Generic = family.Generic;
pub const Style = system.Style;
pub const PartialStyle = union(enum) { normal, italic, oblique: ?f32 };
pub const LineHeight = union(enum) { normal, number: f32, px: f32 };
pub const Options = struct {
    allocator: Allocator,
    system_fonts: ?system.Resolver = null,
    // Q63: the caller supplies its MediaValues, using cascade's defaults.
    viewport_width: f64 = 1024,
    viewport_height: f64 = 768,
};

pub const View = struct {
    families: []const FamilyRef,
    style: Style,
    weight: f32,
    stretch_pct: f32,
    size_px: f32,
};
pub const FontRequest = struct {
    families: []const FamilyRef,
    style: Style,
    weight: f32,
    stretch_pct: f32,
    size_px: f32,
    line_height: LineHeight,
    owned_families: *family.Families,

    pub fn deinit(self: *FontRequest) void {
        self.owned_families.unref();
        self.* = undefined;
    }
    pub fn view(self: *const FontRequest) View {
        return .{ .families = self.families, .style = self.style, .weight = self.weight, .stretch_pct = self.stretch_pct, .size_px = self.size_px };
    }
};
pub const PartialFontRequest = struct {
    families: []const FamilyRef,
    style: PartialStyle,
    weight: ?f32,
    stretch_pct: ?f32,
    size_px: ?f32,
    line_height: ?LineHeight,
    owned_families: *family.Families,

    pub fn deinit(self: *PartialFontRequest) void {
        self.owned_families.unref();
        self.* = undefined;
    }
};
pub const FontLoadingResult = union(enum) {
    resolved: FontRequest,
    accepted_unavailable: PartialFontRequest,

    pub fn deinit(self: *FontLoadingResult) void {
        switch (self.*) {
            inline else => |*request| request.deinit(),
        }
        self.* = undefined;
    }
};

/// Font Loading §3.1 step 1: parse the font shorthand, then absolutize
/// against INITIAL font values. Q59–Q61: null means only invalid syntax;
/// accepted metric-dependent components are explicitly optional.
pub fn parseForFontLoading(options: Options, text: []const u8) Allocator.Error!?FontLoadingResult {
    // Font Loading §3.1 step 1: no element supplies custom properties.
    // Q112, integrator-probes-1023t: Firefox/Safari reject tree-counting
    // occurrences; Safari (the shipping random implementation) rejects even
    // fixed random. This is a function-token rule, not a live-dependency rule.
    // Decoded names include escapes; strings and family identifiers stay valid.
    var input = tokenizer.Tokenizer.init(text);
    while (true) {
        const token = input.next();
        if (token.token_type == .eof) break;
        if (token.token_type == .function and
            (tokenizer.nameEql(token.value, "var") or
                tokenizer.nameEql(token.value, "random") or
                tokenizer.nameEql(token.value, "sibling-index") or
                tokenizer.nameEql(token.value, "sibling-count"))) return null;
    }
    var assignments: std.ArrayList(properties.Assignment) = .empty;
    defer {
        for (assignments.items) |a| a.value.release();
        assignments.deinit(options.allocator);
    }
    if (!try properties.parseDeclaration(.{ .allocator = options.allocator }, .{ .shorthand = .font }, text, &assignments)) return null;
    if (assignments.items.len == 0) return null;
    for (assignments.items) |a| if (a.value != .value) return null;
    var missing_size = false;
    var missing_weight = false;
    var missing_width = false;
    var missing_angle = false;
    var missing_height = false;
    var specified_height = Value.kw(.normal);
    for (assignments.items) |a| {
        const v = a.value.value;
        const unavailable = v.needsUnavailableMetrics(false);
        switch (a.longhand) {
            .font_size => missing_size = unavailable,
            .font_weight => missing_weight = unavailable,
            .font_width => missing_width = unavailable,
            .font_style => missing_angle = unavailable,
            .line_height => {
                missing_height = unavailable;
                specified_height = v;
            },
            else => {},
        }
    }
    var block = declarations.DeclarationBlock.init(options.allocator);
    defer block.deinit();
    try block.entries.ensureTotalCapacity(options.allocator, assignments.items.len);
    for (assignments.items) |a| {
        a.value.retain();
        block.entries.appendAssumeCapacity(.{ .typed = .{ .longhand = a.longhand, .value = a.value, .important = false } });
    }
    const style = try cascade.cascade(.{
        .allocator = options.allocator,
        .parent = null,
        .system_fonts = options.system_fonts,
        .viewport_width = options.viewport_width,
        .viewport_height = options.viewport_height,
    }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    // The font grammar always supplies a nonempty family list; only scalar
    // components can remain unavailable. No family is inferred from a font
    // name or from the host while constructing this value-only request.
    const entries = familyEntries(style) orelse unreachable;
    const copied = try family.Families.create(options.allocator, entries);
    defer copied.unref();
    // Font Loading §3.1 has no declaration tree: all names get document scope,
    // including borrowed names returned by a system resolver.
    const owned = try copied.capture(options.allocator, .{});
    errdefer owned.unref();
    const size = if (missing_size) null else scalar(style.get(.font_size), .px);
    const weight = if (missing_weight) null else scalar(style.get(.font_weight), .number);
    const width = if (missing_width) null else scalar(style.get(.font_width), .percent);
    const selected_style = if (missing_angle) null else styleValue(style.get(.font_style));
    const height = if (missing_height) null else if (size == null) independentLineHeight(specified_height) else lineHeight(style.get(.line_height));
    if (size) |size_px| if (weight) |weight_value| if (width) |stretch| if (selected_style) |font_style| if (height) |line_height| {
        return .{ .resolved = .{
            .families = owned.items,
            .owned_families = owned,
            .style = font_style,
            .weight = weight_value,
            .stretch_pct = stretch,
            .size_px = size_px,
            .line_height = line_height,
        } };
    };
    // Q60: a consumer may use initial matching values on a host without the
    // font capability (Safari's interim behaviour in probes-1023o). Those
    // fallbacks belong to matching, never to these unresolved request fields.
    return .{ .accepted_unavailable = .{
        .families = owned.items,
        .owned_families = owned,
        .style = if (selected_style) |s| switch (s) {
            .normal => .normal,
            .italic => .italic,
            .oblique => |angle| .{ .oblique = angle },
        } else .{ .oblique = null },
        .weight = weight,
        .stretch_pct = width,
        .size_px = size,
        .line_height = height,
    } };
}

fn familyEntries(style: *const computed.ComputedStyle) ?[]const FamilyRef {
    return switch (style.get(.font_family)) {
        .font_family => |f| f.items,
        .keyword => |k| if (k == .serif) &.{.{ .generic = .serif }} else null,
        else => null,
    };
}

fn scalar(value: Value, unit: math.Unit) ?f32 {
    return switch (value) {
        .number => |n| if (unit == .number) @floatCast(n) else null,
        .length => |length| if ((unit == .px and length.unit == .px) or (unit == .percent and length.unit == .percent)) @floatCast(length.value) else null,
        .calculation => |expression| blk: {
            const number = expression.computedNumber() orelse break :blk null;
            break :blk if (number.unit == unit) @floatCast(number.value) else null;
        },
        else => null,
    };
}

fn styleValue(value: Value) ?Style {
    return switch (value) {
        .font_oblique => |oblique| if (oblique.degrees()) |angle| .{ .oblique = @floatCast(angle) } else null,
        .keyword => |k| switch (k) {
            .normal => .normal,
            .italic => .italic,
            .oblique => .{ .oblique = 14 },
            else => null,
        },
        else => null,
    };
}

fn lineHeight(value: Value) ?LineHeight {
    if (value.isKeyword(.normal)) return .normal;
    if (scalar(value, .number)) |number| return .{ .number = number };
    if (scalar(value, .px)) |px| return .{ .px = px };
    return null;
}

/// Q63: with an unknown requested size, do not expose a line-height that the
/// cascade computed against substituted medium. Keep only these independent
/// typed forms. Precise calc dependency propagation waits for a public query.
fn independentLineHeight(value: Value) ?LineHeight {
    return switch (value) {
        .keyword => |k| if (k == .normal) .normal else null,
        .number => |number| .{ .number = @floatCast(number) },
        .length => |length| switch (length.unit) {
            .px, .cm, .mm, .Q, .in, .pt, .pc => blk: {
                const unit: math.Unit = switch (length.unit) {
                    .Q => .q,
                    inline else => |u| @field(math.Unit, @tagName(u)),
                };
                const absolute = (math.Context{}).resolve(.{ .value = length.value, .unit = unit });
                break :blk .{ .px = @floatCast(absolute.value) };
            },
            else => null,
        },
        else => null,
    };
}

/// The caller must not keep this view after releasing its ComputedStyle.
/// Q59: default candidate filtering makes real computed values scalar; keep
/// the typed checks defensive for callers rather than unwrapping that claim.
pub fn fromComputed(style: *const computed.ComputedStyle) ?View {
    return .{
        .families = familyEntries(style) orelse return null,
        .style = styleValue(style.get(.font_style)) orelse return null,
        .weight = scalar(style.get(.font_weight), .number) orelse return null,
        .stretch_pct = scalar(style.get(.font_width), .percent) orelse return null,
        .size_px = scalar(style.get(.font_size), .px) orelse return null,
    };
}
