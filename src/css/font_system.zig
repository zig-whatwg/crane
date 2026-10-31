//! CSS Fonts4 §2.7 system-font tokens. Resolver contract is coordinated in Q46.
const properties = @import("properties.zig");
const tokens = @import("tokenizer.zig");

pub const Keyword = enum {
    caption,
    icon,
    menu,
    message_box,
    small_caption,
    status_bar,

    pub fn name(self: Keyword) []const u8 {
        return switch (self) {
            .message_box => "message-box",
            .small_caption => "small-caption",
            .status_bar => "status-bar",
            inline else => |k| @tagName(k),
        };
    }
    pub fn parse(stream: *properties.Stream) ?Keyword {
        const token = stream.peek();
        if (token.token_type != .ident) return null;
        inline for (@typeInfo(Keyword).@"enum".field_values) |field_value| {
            const k: Keyword = @fromBackingInt(@intCast(field_value));
            if (tokens.nameEql(token.value, k.name())) {
                _ = stream.next();
                return k;
            }
        }
        return null;
    }
};

const std = @import("std");
const values = @import("style_values.zig");
const family = @import("font_family.zig");
const font_style = @import("font_style.zig");

pub const Style = union(enum) { normal, italic, oblique: f32 };
pub const SystemValues = struct {
    families: []const family.FamilyRef,
    style: Style = .normal,
    weight: f32 = 400,
    stretch_pct: f32 = 100,
    size_px: f32 = 16,
};
pub const Resolver = struct {
    context: ?*anyopaque = null,
    /// Returned names are borrowed for the immediate copy. No native font
    /// handle, DOM pointer or borrowed callback result is saved by CSS.
    resolve: *const fn (?*anyopaque, Keyword) ?SystemValues,
};
pub const fallback = SystemValues{ .families = &.{.{ .generic = .sans_serif }} };

/// Fonts4 §2.7 permits a UA default when the requested system font does not
/// exist. Q23 pins this headless fallback; a future platform adapter supplies
/// actual host settings through Resolver, never an OS call from CSS.
pub fn resolve(resolver: ?Resolver, keyword: Keyword) SystemValues {
    if (resolver) |provider| return provider.resolve(provider.context, keyword) orelse fallback;
    return fallback;
}

/// The result owns every family/angle allocation; the resolver's pointers
/// are neither stored nor retained. All reset-only longhands stay initial.
pub fn compute(allocator: std.mem.Allocator, resolver: ?Resolver, keyword: Keyword, longhand: properties.Longhand) std.mem.Allocator.Error!values.Value {
    const selected = resolve(resolver, keyword);
    return switch (longhand) {
        .font_family => .{ .font_family = try family.Families.create(allocator, selected.families) },
        .font_size => values.Value.px(selected.size_px),
        .font_weight => .{ .number = selected.weight },
        .font_width => .{ .length = .percent(selected.stretch_pct) },
        .font_style => switch (selected.style) {
            .normal => values.Value.kw(.normal),
            .italic => values.Value.kw(.italic),
            .oblique => |angle| if (angle == 0) values.Value.kw(.normal) else .{ .font_oblique = try font_style.Oblique.create(allocator, .{ .angle = .{ .number = angle, .unit = .deg } }) },
        },
        else => blk: {
            const initial = longhand.info().initial;
            initial.retain();
            break :blk initial;
        },
    };
}
