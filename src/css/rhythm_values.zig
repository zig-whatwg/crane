//! CSS Rhythm 1 §2.5: block-step expansion and shortest reconstruction.
const std = @import("std");
const properties = @import("properties.zig");
const Value = @import("style_values.zig").Value;
const Allocator = std.mem.Allocator;

pub const longhands = [_]properties.Longhand{ .block_step_size, .block_step_insert, .block_step_align, .block_step_round };

pub fn consume(options: properties.ParseOptions, stream: *properties.Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    // §2.5: four unordered independent components, each occurring at most
    // once. Omitted components take their initial value, including size.
    var parsed: [longhands.len]?Value = @splat(null);
    defer for (parsed) |item| if (item) |value| value.release();
    var any = false;
    while (!stream.atEnd()) {
        var matched = false;
        for (longhands, 0..) |longhand, index| {
            if (parsed[index] != null) continue;
            var trial = stream.*;
            if (try properties.parseLonghand(options, longhand, &trial)) |value| {
                parsed[index] = value;
                stream.* = trial;
                matched = true;
                any = true;
                break;
            }
        }
        if (!matched) return false;
    }
    if (!any) return false;
    try out.ensureUnusedCapacity(options.allocator, longhands.len);
    for (longhands, parsed) |longhand, item| {
        const value = item orelse longhand.info().initial;
        value.retain();
        out.appendAssumeCapacity(.{ .longhand = longhand, .value = .{ .value = value } });
    }
    return true;
}

pub fn serialize(assigned: []const properties.Assigned, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    // §2.5's canonical order, with initial components omitted in either
    // mode. `none` is the shortest spelling when all four are initial.
    var wrote = false;
    for (longhands, assigned) |longhand, item| {
        if (item.value.eql(longhand.info().initial)) continue;
        if (wrote) try out.append(allocator, ' ');
        try properties.serializeValue(longhand, item.value, out, allocator);
        wrote = true;
    }
    if (!wrote) try out.appendSlice(allocator, "none");
    return true;
}
