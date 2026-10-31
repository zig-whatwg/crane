//! Geometry retry checks shared by the new CSS property families.
const std = @import("std");
const css = @import("css");
const math = css.math_values;

const Probe = struct {
    calls: usize = 0,
    fn get(raw: *anyopaque, _: math.Context.ContainerAxis) math.Context.ContainerEligibility {
        const self: *Probe = @ptrCast(@alignCast(raw));
        self.calls += 1;
        return .eligible_geometry_unavailable;
    }
};

pub fn check(allocator: std.mem.Allocator, name: []const u8, input: []const u8, fallback: []const u8, retain: bool) !void {
    const property = css.properties.lookup(name) orelse return error.MissingFamilyProperty;
    var low = css.declarations.DeclarationBlock.init(allocator);
    defer low.deinit();
    try std.testing.expect(try low.setProperty(.{ .allocator = allocator }, name, fallback, ""));
    var high = css.declarations.DeclarationBlock.init(allocator);
    defer high.deinit();
    try std.testing.expect(try high.setProperty(.{ .allocator = allocator }, name, input, ""));
    var probe: Probe = .{};
    var note: math.UnavailableNote = .{};
    const style = try css.cascade.cascade(.{
        .allocator = allocator,
        .parent = null,
        .container = .{ .context = &probe, .get = Probe.get, .note = &note },
    }, &.{
        .{ .block = &low, .source = .{ .origin = .author, .order = 1 } },
        .{ .block = &high, .source = .{ .origin = .author, .order = 2 } },
    });
    defer style.destroy();
    try std.testing.expect(probe.calls > 0);
    try std.testing.expect(!note.scalar and !note.retained_length);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(property.longhand, &out, allocator);
    if (retain)
        try std.testing.expect(std.mem.indexOf(u8, out.items, "10cqw") != null)
    else
        try std.testing.expectEqualStrings(fallback, out.items);
}
