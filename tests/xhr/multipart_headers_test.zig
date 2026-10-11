const std = @import("std");
const xhr = @import("xhr");

fn expectHeaderCase(allocator: std.mem.Allocator) !void {
    const body = "--boundary\r\ncontent-disposition: form-data; name=\"TextName\"\r\n\r\nTextValue\r\n" ++
        "--boundary\r\ncOnTeNt-DiSpOsItIoN: form-data; name=\"FileName\"; filename=\"Upload.TXT\"\r\n" ++
        "cOnTeNt-TyPe: Text/Plain; Charset=UTF-8\r\n\r\nFileData\x00\r\n--boundary--\r\n";
    const entries = try xhr.multipart_parser.parseMultipartFormData(allocator, body, "boundary");
    defer {
        for (entries) |*entry| entry.deinit(allocator);
        allocator.free(entries);
    }
    try std.testing.expectEqual(@as(usize, 2), entries.len);
    try std.testing.expectEqualStrings("TextName", entries[0].name);
    try std.testing.expectEqualStrings("TextValue", entries[0].value.string);
    try std.testing.expectEqualStrings("FileName", entries[1].name);
    try std.testing.expectEqualStrings("Upload.TXT", entries[1].filename.?);
    try std.testing.expectEqualStrings("Text/Plain; Charset=UTF-8", entries[1].value.file.content_type.?);
    try std.testing.expectEqualStrings("FileData\x00", entries[1].value.file.data);
}

test "multipart header names ignore ASCII case without changing values or bytes" {
    try expectHeaderCase(std.testing.allocator);
}

test "multipart mixed-case headers release partial entries on allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, expectHeaderCase, .{});
}
