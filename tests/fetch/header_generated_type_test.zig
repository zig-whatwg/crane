const std = @import("std");
const fetch = @import("fetch");
const Header = fetch.internal.Header;
const HeaderList = fetch.internal.HeaderList;
const generated_type = "multipart/form-data; boundary=CaseSensitive";

test "ordinary headers default to untrusted generated-body provenance" {
    var header = try Header.init(std.testing.allocator, "Content-Type", generated_type);
    defer header.deinit(std.testing.allocator);
    try std.testing.expect(!header.body_generated);
    const literal: Header = .{ .name = "Content-Type", .value = generated_type };
    try std.testing.expect(!literal.body_generated);
}

fn cloneTrial(allocator: std.mem.Allocator) !void {
    var list = HeaderList.init(allocator);
    defer list.deinit();
    try list.appendBodyContentType(generated_type);
    try std.testing.expectEqualStrings(generated_type, list.generatedBodyContentType().?);
    try list.set("X-Other", "value");
    try std.testing.expectEqualStrings(generated_type, list.generatedBodyContentType().?);
    var header = try list.entries.items[0].clone(allocator);
    defer header.deinit(allocator);
    try std.testing.expect(header.body_generated);
    var clone = try list.clone(allocator);
    defer clone.deinit();
    try std.testing.expectEqualStrings(generated_type, clone.generatedBodyContentType().?);
    clone.delete("CONTENT-TYPE");
    try std.testing.expect(clone.generatedBodyContentType() == null);
    try clone.append("Content-Type", generated_type);
    try std.testing.expect(clone.generatedBodyContentType() == null);
    try std.testing.expectEqualStrings(generated_type, list.generatedBodyContentType().?);
}

test "generated Content-Type and clones retain provenance without aliasing" {
    try cloneTrial(std.testing.allocator);
}

test "generated Content-Type cloning releases allocations on every failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, cloneTrial, .{});
}

test "setting or duplicating Content-Type requires MIME extraction" {
    var list = HeaderList.init(std.testing.allocator);
    defer list.deinit();
    try list.appendBodyContentType(generated_type);
    try list.set("cOnTeNt-TyPe", generated_type);
    try std.testing.expect(list.generatedBodyContentType() == null);
    list.delete("Content-Type");
    try list.appendBodyContentType(generated_type);
    try list.append("CONTENT-TYPE", "text/plain");
    try std.testing.expect(list.generatedBodyContentType() == null);
    try list.set("content-type", "text/plain");
    try std.testing.expectEqual(@as(usize, 1), list.entries.items.len);
    try std.testing.expect(list.generatedBodyContentType() == null);
}

test "two generated Content-Type entries are not a single generated value" {
    var list = HeaderList.init(std.testing.allocator);
    defer list.deinit();
    try list.appendBodyContentType(generated_type);
    try list.appendBodyContentType(generated_type);
    try std.testing.expect(list.generatedBodyContentType() == null);
}

fn combineTrial(allocator: std.mem.Allocator) !void {
    var list = HeaderList.init(allocator);
    defer list.deinit();
    try list.appendBodyContentType(generated_type);
    try list.combine("CONTENT-TYPE", "text/plain");
    try std.testing.expect(list.generatedBodyContentType() == null);
    try std.testing.expectEqualStrings(generated_type ++ ", text/plain", list.entries.items[0].value);
}

test "combining Content-Type clears generated provenance" {
    try combineTrial(std.testing.allocator);
}

test "combining a generated header releases storage on allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, combineTrial, .{});
}
