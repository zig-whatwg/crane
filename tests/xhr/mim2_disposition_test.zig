//! Content-Disposition parameters are delimited fields, never substring matches.
const std = @import("std");
const parser = @import("xhr").multipart_parser;

fn check(allocator: std.mem.Allocator, disposition: []const u8, name: []const u8, filename: ?[]const u8) !void {
    const body = try std.fmt.allocPrint(allocator, "--b\r\nContent-Disposition: {s}\r\n\r\nvalue\r\n--b--\r\n", .{disposition});
    defer allocator.free(body);
    const entries = try parser.parseMultipartFormData(allocator, body, "b");
    defer {
        for (entries) |*entry| entry.deinit(allocator);
        allocator.free(entries);
    }
    try std.testing.expectEqual(@as(usize, 1), entries.len);
    try std.testing.expectEqualStrings(name, entries[0].name);
    if (filename) |expected| {
        try std.testing.expect(entries[0].filename != null);
        try std.testing.expectEqualStrings(expected, entries[0].filename.?);
        try std.testing.expectEqualStrings("value", entries[0].value.file.data);
    } else {
        try std.testing.expect(entries[0].filename == null);
        try std.testing.expectEqualStrings("value", entries[0].value.string);
    }
}

fn reject(disposition: []const u8) !void {
    const allocator = std.testing.allocator;
    const body = try std.fmt.allocPrint(allocator, "--b\r\nContent-Disposition: {s}\r\n\r\nvalue\r\n--b--\r\n", .{disposition});
    defer allocator.free(body);
    const result = parser.parseMultipartFormData(allocator, body, "b");
    if (result) |entries| {
        defer {
            for (entries) |*entry| entry.deinit(allocator);
            allocator.free(entries);
        }
        return error.ExpectedInvalidHeaders;
    } else |err| try std.testing.expectEqual(error.InvalidHeaders, err);
}

test "unquoted disposition parameters include text and file entries" {
    try check(std.testing.allocator, "form-data; name=field", "field", null);
    try check(std.testing.allocator, "form-data; name=field; filename=upload.txt", "field", "upload.txt");
}

test "filename before name cannot supply the field name" {
    try check(std.testing.allocator, "form-data; filename=\"upload.txt\"; name=\"field\"", "field", "upload.txt");
    try reject("form-data; filename=\"upload.txt\"");
    try reject("form-data; xname=\"not-a-name\"");
}

test "parameter names follow the WebKit Gecko lowercase majority" {
    try reject("form-data; NAME=\"field\"");
    try check(std.testing.allocator, "form-data; name=field; FILENAME=upload.txt", "field", null);
}

test "quoted values keep ordinary backslashes literally" {
    try check(std.testing.allocator, "form-data; name=\"a\\b\"; filename=\"x\\y.txt\"", "a\\b", "x\\y.txt");
    try check(std.testing.allocator, "form-data; name=\"a\\\\\"; filename=b", "a\\\\", "b");
}

test "the last duplicate parameter wins in Blink and Gecko" {
    try check(std.testing.allocator, "form-data; name=\"first\"; filename=\"one\"; name=last; filename=two", "last", "two");
}

test "whitespace between a parameter name and equals does not match" {
    try reject("form-data; name =field");
    try reject("form-data; name\t=field");
    try reject("form-data; name =\"value\"");
}

test "whitespace after equals precedes either kind of value" {
    try check(std.testing.allocator, "form-data; name= value ", "value", null);
    try check(std.testing.allocator, "form-data; name= \"value\"", "value", null);
}

test "disposition type handling remains unchanged" {
    try check(std.testing.allocator, "attachment; name=\"value\"", "value", null);
    try check(std.testing.allocator, "name=\"value\"", "value", null);
}

test "escaped quotes use the RFC fallback for the three-way browser split" {
    try check(std.testing.allocator, "form-data; name=\"a\\\"b\"; filename=\"x\\\"y\"", "a\"b", "x\"y");
}

test "semicolons and parameter-looking text inside quotes are data" {
    try check(std.testing.allocator, "form-data; note=\"name=wrong; filename=wrong\"; name=\"a;b\"", "a;b", null);
}

test "closed quoted parameters require a separator before another parameter" {
    try reject("form-data; name=\"a\"filename=\"b\"");
    try check(std.testing.allocator, "form-data; name=\"a\" \t; filename=\"b\" \t", "a", "b");
}

test "empty quoted names and filenames remain present" {
    try check(std.testing.allocator, "form-data; name=\"\"; filename=\"\"", "", "");
}

test "unterminated quotes follow the WebKit Gecko majority" {
    try check(std.testing.allocator, "form-data; name=\"value", "value", null);
}

test "an equals sign at end of input has no value" {
    try reject("form-data; name=");
}

test "a delimited empty unquoted value remains present" {
    try check(std.testing.allocator, "form-data; name=; filename=x", "", "x");
}

fn allocationTrial(allocator: std.mem.Allocator) !void {
    try check(allocator, "form-data; filename=one; name=first; name=\"a\\\"b\"; filename=\"x;y\"", "a\"b", "x;y");
}

test "disposition parsing frees replaced and partial values on allocation failure" {
    try allocationTrial(std.testing.allocator);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationTrial, .{});
}
