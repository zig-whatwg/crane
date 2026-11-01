//! CSS Fonts 4 §2.8.5: the synthesis shorthand maps four constituents.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokens = @import("tokenizer.zig");
const Allocator = std.mem.Allocator;

pub const longhands = [_]properties.Longhand{ .font_synthesis_weight, .font_synthesis_style, .font_synthesis_small_caps, .font_synthesis_position };
const names = [_][]const u8{ "weight", "style", "small-caps", "position" };

pub fn consume(options: properties.ParseOptions, stream: *properties.Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    var enabled: [longhands.len]bool = @splat(false);
    var oblique_only = false;
    const first = stream.peek();
    if (first.token_type == .ident and tokens.nameEql(first.value, "none")) {
        _ = stream.next();
        if (!stream.atEnd()) return false;
    } else {
        var any = false;
        while (!stream.atEnd()) {
            const token = stream.next();
            if (token.token_type != .ident) return false;
            if (tokens.nameEql(token.value, "oblique-only")) {
                if (enabled[1]) return false;
                enabled[1] = true;
                oblique_only = true;
                any = true;
                continue;
            }
            var matched = false;
            for (names, 0..) |name, index| {
                if (tokens.nameEql(token.value, name)) {
                    if (enabled[index]) return false;
                    enabled[index] = true;
                    matched = true;
                    any = true;
                    break;
                }
            }
            if (!matched) return false;
        }
        if (!any) return false;
    }
    // csswg-drafts#9390 resolved to add oblique-only to font-synthesis-style,
    // but the edit updated only the longhand; Fonts 4 §2.8.5's shorthand
    // grammar and mapping table remain unupdated. Firefox 159 passes the
    // shorthand oblique-only cases, while Chrome 156 and Safari 27.2 reject
    // oblique-only even on the longhand and therefore do not ship it. Per
    // Q54, accept it in the mutually exclusive style slot. For shorthand
    // mapping, presence enables a constituent and omission disables it.
    try out.ensureUnusedCapacity(options.allocator, longhands.len);
    for (longhands, enabled, 0..) |longhand, flag, index| {
        const value: values.Keyword = if (!flag) .none else if (index == 1 and oblique_only) .oblique_only else .auto;
        out.appendAssumeCapacity(.{ .longhand = longhand, .value = .{ .value = values.Value.kw(value) } });
    }
    return true;
}

pub fn serialize(assigned: []const properties.Assigned, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    for (assigned, 0..) |item, index| {
        if (item.value.isKeyword(.none)) continue;
        if (index == 1 and item.value.isKeyword(.oblique_only)) continue;
        if (!item.value.isKeyword(.auto)) return false;
    }
    var wrote = false;
    for (names, assigned) |name, item| {
        if (item.value.isKeyword(.none)) continue;
        if (wrote) try out.append(allocator, ' ');
        try out.appendSlice(allocator, if (item.value.isKeyword(.oblique_only)) "oblique-only" else name);
        wrote = true;
    }
    if (!wrote) try out.appendSlice(allocator, "none");
    return true;
}
