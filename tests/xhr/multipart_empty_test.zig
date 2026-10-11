const std = @import("std");
const xhr = @import("xhr");

fn expectEmpty(allocator: std.mem.Allocator) !void {
    for ([_][]const u8{ "--boundary--\r\n", "--boundary--", "--boundary--\r\nepilogue" }) |body| {
        const entries = try xhr.multipart_parser.parseMultipartFormData(allocator, body, "boundary");
        defer {
            for (entries) |*entry| entry.deinit(allocator);
            allocator.free(entries);
        }
        try std.testing.expectEqual(@as(usize, 0), entries.len);
    }
}

test "multipart zero parts require the initial closing delimiter" {
    try expectEmpty(std.testing.allocator);
}

test "multipart zero bytes and unfinished opening delimiters are invalid" {
    for ([_][]const u8{ "", "--boundary\r\n", "--boundary", "--boundary\r\n--" }) |body| {
        const result = xhr.multipart_parser.parseMultipartFormData(std.testing.allocator, body, "boundary");
        if (result) |entries| {
            defer {
                for (entries) |*entry| entry.deinit(std.testing.allocator);
                std.testing.allocator.free(entries);
            }
            return error.ExpectedInvalidMultipartBody;
        } else |err| {
            try std.testing.expectEqual(error.InvalidMultipartBody, err);
        }
    }
}

test "multipart closing delimiter releases temporary delimiters on allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, expectEmpty, .{});
}
