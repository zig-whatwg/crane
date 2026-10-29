//! CSS Multicol 2 §4.5 and Multicol 1 §4.5 shorthand values.
//! Column geometry is a used-value concern; this module never supplies it.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokenizer = @import("tokenizer.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Stream = properties.Stream;

fn slash(token: tokenizer.Token) bool {
    return token.token_type == .delim and std.mem.eql(u8, token.value, "/");
}

pub fn parseColumns(options: properties.ParseOptions, stream: *Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    // Multicol 2 §4.5: [ <column-width> || <column-count> ] [ / <column-height> ]?.
    // An auto can fill either component. Defer that choice until the explicit
    // width/count is known, so both `auto 10px` and `auto 3` are accepted.
    var width: ?Value = null;
    var count: ?Value = null;
    var height = Value.kw(.auto);
    defer {
        if (width) |v| v.release();
        if (count) |v| v.release();
        height.release();
    }
    var parts: usize = 0;
    while (!stream.atEnd() and !slash(stream.peek())) {
        if (parts == 2) return false;
        parts += 1;
        const token = stream.peek();
        if (token.token_type == .ident and tokenizer.nameEql(token.value, "auto")) {
            _ = stream.next();
            continue;
        }
        if (width == null) {
            var trial = stream.*;
            width = try properties.parseLonghand(options, .column_width, &trial);
            if (width != null) {
                stream.* = trial;
                continue;
            }
        }
        if (count == null) {
            var trial = stream.*;
            count = try properties.parseLonghand(options, .column_count, &trial);
            if (count != null) {
                stream.* = trial;
                continue;
            }
        }
        return false;
    }
    if (parts == 0) return false;
    if (slash(stream.peek())) {
        _ = stream.next();
        height = try properties.parseLonghand(options, .column_height, stream) orelse return false;
    }
    if (!stream.atEnd()) return false;
    // Q9: column-wrap's reset waits with its held grammar (CSSWG #11754).
    // Every currently registered constituent is reset by the shorthand.
    const components = [_]Value{ width orelse Value.kw(.auto), count orelse Value.kw(.auto), height };
    try out.ensureUnusedCapacity(options.allocator, components.len);
    for (properties.Shorthand.columns.longhands(), components) |longhand, value| {
        value.retain();
        out.appendAssumeCapacity(.{ .longhand = longhand, .value = .{ .value = value } });
    }
    return true;
}

pub fn serializeColumns(assigned: []const properties.Assigned, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    // CSSOM's shortest serialization omits auto components in either mode.
    const width = assigned[0].value;
    const count = assigned[1].value;
    const height = assigned[2].value;
    const write_width = !width.isKeyword(.auto);
    const write_count = !count.isKeyword(.auto);
    if (write_width) try properties.serializeValue(.column_width, width, out, allocator);
    if (write_count) {
        if (write_width) try out.append(allocator, ' ');
        try properties.serializeValue(.column_count, count, out, allocator);
    }
    if (!write_width and !write_count) try out.appendSlice(allocator, "auto");
    if (!height.isKeyword(.auto)) {
        try out.appendSlice(allocator, " / ");
        try properties.serializeValue(.column_height, height, out, allocator);
    }
    return true;
}

pub fn serializeRule(assigned: []const properties.Assigned, mode: properties.ShorthandMode, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    // Multicol 1 §4.5 / CSSOM: omit initial specified components; none is
    // omitted even in computed readback. The rule's width is not zeroed
    // when its style is none or hidden (Multicol 1 §4.4, pinned WPT).
    var wrote = false;
    for (properties.Shorthand.column_rule.longhands(), assigned) |longhand, assigned_value| {
        const value = assigned_value.value;
        if (longhand == .column_rule_style and value.isKeyword(.none)) continue;
        if (mode == .specified and value.eql(longhand.info().initial)) continue;
        if (wrote) try out.append(allocator, ' ');
        try properties.serializeValue(longhand, value, out, allocator);
        wrote = true;
    }
    // The shortest declaration setting all three initials is medium.
    if (!wrote) try properties.serializeValue(.column_rule_width, assigned[0].value, out, allocator);
    return true;
}
