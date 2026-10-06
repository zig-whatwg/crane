const std = @import("std");
const xhr = @import("xhr");

const body = "--ce2\r\nContent-Disposition: form-data; name=\"upload\"; filename=\"first.bin\"\r\n" ++
    "Content-Type: application/octet-stream\r\n\r\ncontents\x00\x01\r\n" ++
    "--ce2\r\nContent-Disposition: form-data; name=\"upload\"; filename=\"\"\r\n\r\nsecond\r\n" ++
    "--ce2\r\nContent-Disposition: form-data; name=\"text\"\r\n\r\nplain\r\n--ce2--\r\n";

fn parseWithFailures(allocator: std.mem.Allocator) !void {
    const entries = try xhr.multipart_parser.parseMultipartFormData(allocator, body, "ce2");
    defer {
        for (entries) |*entry| entry.deinit(allocator);
        allocator.free(entries);
    }
    try std.testing.expectEqual(@as(usize, 3), entries.len);
    try std.testing.expectEqualStrings("contents\x00\x01", entries[0].value.file.data);
    try std.testing.expectEqualStrings("", entries[1].filename.?);
    try std.testing.expectEqualStrings("plain", entries[2].value.string);
}

test "CE2 multipart: parsed files retain their MIME type and its default" {
    const allocator = std.testing.allocator;
    const entries = try xhr.multipart_parser.parseMultipartFormData(allocator, body, "ce2");
    defer {
        for (entries) |*entry| entry.deinit(allocator);
        allocator.free(entries);
    }
    try std.testing.expect(@hasField(xhr.form_data.File, "content_type"));
    if (comptime @hasField(xhr.form_data.File, "content_type")) {
        try std.testing.expectEqualStrings("application/octet-stream", entries[0].value.file.content_type.?);
        try std.testing.expect(entries[1].value.file.content_type == null);
    }
}

test "CE2 multipart: every parser allocation failure releases partial entries" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, parseWithFailures, .{});
}

fn copyWithFailures(allocator: std.mem.Allocator) !void {
    const entries = try xhr.multipart_parser.parseMultipartFormData(std.testing.allocator, body, "ce2");
    defer {
        for (entries) |*entry| entry.deinit(std.testing.allocator);
        std.testing.allocator.free(entries);
    }
    const data = try xhr.form_data.FormData.init(allocator);
    defer data.deinit();
    try data.appendFile(entries[0].name, entries[0].value.file, entries[0].filename);
    try std.testing.expectEqualStrings("contents\x00\x01", data.entries.items[0].value.file.data);
    if (comptime @hasField(xhr.form_data.File, "content_type")) {
        try std.testing.expectEqualStrings("application/octet-stream", data.entries.items[0].value.file.content_type.?);
    }
}

test "CE2 multipart: cloning a parsed file preserves metadata without allocation leaks" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, copyWithFailures, .{});
}
