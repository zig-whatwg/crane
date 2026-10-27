//! CSS Syntax 3 section 3.2: network bytes use the CSS encoding cascade.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn check(bytes: []const u8, protocol: ?[]const u8, environment: ?[]const u8, expected_encoding: []const u8, expected_text: []const u8) !void {
    var decoded = try css.rules.stylesheet_encoding.decode(testing.allocator, bytes, .{
        .protocol_label = protocol,
        .environment_label = environment,
    });
    defer decoded.deinit(testing.allocator);
    try testing.expectEqualStrings(expected_encoding, decoded.encoding.name);
    try testing.expectEqualStrings(expected_text, decoded.text);
}

test "stylesheet bytes - BOM overrides transport and charset" {
    try check("\xff\xfe\xe9\x00", "windows-1251", "windows-1250", "UTF-16LE", "é");
    try check("\xfe\xff\x00\xe9", "windows-1251", "windows-1250", "UTF-16BE", "é");
    try check("\xef\xbb\xbf@charset \"windows-1251\";é", "windows-1250", null, "UTF-8", "@charset \"windows-1251\";é");
}

test "stylesheet bytes - transport then exact charset then environment" {
    try check("@charset \"windows-1250\";\xe0", "windows-1251", "windows-1252", "windows-1251", "@charset \"windows-1250\";а");
    try check("@charset \"windows-1250\";\xe0", "bogus", "windows-1251", "windows-1250", "@charset \"windows-1250\";ŕ");
    try check("\xe0", "bogus", "windows-1251", "windows-1251", "а");
    try check("\xe0", null, null, "UTF-8", "�");
}

test "stylesheet bytes - utf16 charset is utf8 while transport is utf16" {
    try check("@charset \"utf-16\";é", null, "windows-1251", "UTF-8", "@charset \"utf-16\";é");
    try check("@charset \"utf-16be\";é", null, "windows-1251", "UTF-8", "@charset \"utf-16be\";é");
    try check("\xe9\x00", "utf-16le", null, "UTF-16LE", "é");
}

test "stylesheet bytes - charset syntax is exact and bounded" {
    for ([_][]const u8{ " @charset \"windows-1250\";", "@CHARSET \"windows-1250\";", "@charset  \"windows-1250\";", "@charset 'windows-1250';", "@charset \"bogus\";" }) |prefix| {
        const input = try std.mem.concat(testing.allocator, u8, &.{ prefix, "\xe0" });
        defer testing.allocator.free(input);
        const wanted = try std.mem.concat(testing.allocator, u8, &.{ prefix, "а" });
        defer testing.allocator.free(wanted);
        try check(input, null, "windows-1251", "windows-1251", wanted);
    }
    var boundary: [1027]u8 = @splat(' ');
    @memcpy(boundary[0..10], "@charset \"");
    @memcpy(boundary[10..22], "windows-1250");
    boundary[1022] = '"';
    boundary[1023] = ';';
    boundary[1024] = 0xe0;
    var decoded = try css.rules.stylesheet_encoding.decode(testing.allocator, boundary[0..1025], .{ .environment_label = "windows-1251" });
    defer decoded.deinit(testing.allocator);
    try testing.expectEqualStrings("windows-1250", decoded.encoding.name);
    boundary[1022] = ' ';
    boundary[1023] = '"';
    boundary[1024] = ';';
    boundary[1025] = 0xe0;
    var outside = try css.rules.stylesheet_encoding.decode(testing.allocator, boundary[0..1026], .{ .environment_label = "windows-1251" });
    defer outside.deinit(testing.allocator);
    try testing.expectEqualStrings("windows-1251", outside.encoding.name);
}

test "stylesheet bytes - replacement errors preserve legacy decoder state" {
    try check("\x82\x20\xa6", "shift_jis", null, "shift_jis", "� ｦ");
    try check("\xff\xfe\x00\xd8", null, null, "UTF-16LE", "�");
    try check("", null, null, "UTF-8", "");
}
