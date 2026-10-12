const std = @import("std");
const Header = @import("fetch").internal.Header;
const HeaderList = @import("fetch").internal.HeaderList;
const content_type = "Text/Plain; a=First;a=Second";

test "a header contains only the name and value slices" {
    try std.testing.expectEqual(2 * @sizeOf([]const u8), @sizeOf(Header));
}

fn headerTrial(allocator: std.mem.Allocator) !void {
    var original = try Header.init(allocator, "Content-Type", content_type);
    defer original.deinit(allocator);
    var clone = try original.clone(allocator);
    defer clone.deinit(allocator);
    try std.testing.expectEqualStrings("Content-Type", clone.name);
    try std.testing.expectEqualStrings(content_type, clone.value);
    try std.testing.expect(original.name.ptr != clone.name.ptr);
    try std.testing.expect(original.value.ptr != clone.value.ptr);
}

fn listTrial(allocator: std.mem.Allocator) !void {
    var original = HeaderList.init(allocator);
    defer original.deinit();
    try original.append("Content-Type", content_type);
    var clone = try original.clone(allocator);
    defer clone.deinit();
    try clone.set("content-type", content_type);
    try clone.append("CONTENT-TYPE", "text/html");
    const combined = (try clone.get(allocator, "Content-Type")).?;
    defer allocator.free(combined);
    try std.testing.expectEqualStrings(content_type ++ ", text/html", combined);
    const unchanged = (try original.get(allocator, "Content-Type")).?;
    defer allocator.free(unchanged);
    try std.testing.expectEqualStrings(content_type, unchanged);
    clone.delete("Content-Type");
    try std.testing.expect((try clone.get(allocator, "Content-Type")) == null);
}

fn combineTrial(allocator: std.mem.Allocator) !void {
    var list = HeaderList.init(allocator);
    defer list.deinit();
    try list.append("Content-Type", content_type);
    try list.combine("content-type", "text/html");
    const combined = (try list.get(allocator, "CONTENT-TYPE")).?;
    defer allocator.free(combined);
    try std.testing.expectEqualStrings(content_type ++ ", text/html", combined);
}

test "Header clone owns exact copies of the original bytes" {
    try headerTrial(std.testing.allocator);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, headerTrial, .{});
}

test "HeaderList cloning and mutation preserve raw values and independent storage" {
    try listTrial(std.testing.allocator);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, listTrial, .{});
}

test "HeaderList combine keeps raw Content-Type formatting through allocation failures" {
    try combineTrial(std.testing.allocator);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, combineTrial, .{});
}
