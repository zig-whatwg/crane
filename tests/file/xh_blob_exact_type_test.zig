const std = @import("std");
const Blob = @import("file").BlobData;
fn roundTrip(a: std.mem.Allocator) anyerror!void {
    if (!@hasDecl(Blob, "initWithType")) return error.TestUnexpectedResult;
    const blob = try Blob.initWithType(a, "body", "text/plain;charset=GBK;name=\"\xC3\xBF\"");
    defer blob.deinit();
    try std.testing.expectEqualStrings("text/plain;charset=GBK;name=\"\xC3\xBF\"", blob.getType());
}
test "spec-created Blob preserves serialized MIME values and frees partial allocations" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, roundTrip, .{});
}
