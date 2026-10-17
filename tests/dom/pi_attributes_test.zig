//! DOM 4.13 / XML Stylesheet 3: PI pseudo-attributes and XML Name validation.
const std = @import("std");
const pi = @import("dom").pi_attributes;

test "PI target uses the XML Name production, not relaxed DOM names" {
    for ([_][]const u8{ "x", ":", "_", "a:b", "\u{C0}", "a\u{B7}", "\u{10000}", "\u{EFFFF}" }) |name| {
        try std.testing.expect(pi.isXmlName(name));
    }
    for ([_][]const u8{ "", "1name", "a b", "a=", "\u{B7}a", "\u{F0000}", "\xED\xA0\x80", "\xFF" }) |name| {
        try std.testing.expect(!pi.isXmlName(name));
    }
}

test "PI parsing preserves order and decodes XML character references" {
    var attributes = pi.Attributes.init(std.testing.allocator);
    defer attributes.deinit();
    try attributes.parse(" \t a = 'one' b=\"&amp;&lt;&gt;&quot;&apos;&#65;&#x1F600;\" \r\n");
    try std.testing.expectEqual(@as(usize, 2), attributes.entries.size());
    try std.testing.expectEqualStrings("a", attributes.entries.items()[0].name);
    try std.testing.expectEqualStrings("one", attributes.get("a").?);
    try std.testing.expectEqualStrings("&<>\"'A\u{1F600}", attributes.get("b").?);
}

test "malformed pseudo-attributes clear the whole map" {
    var attributes = pi.Attributes.init(std.testing.allocator);
    defer attributes.deinit();
    for ([_][]const u8{
        "a=unquoted",      "a='x'a='y'",       "a='x' a='y'",    "a='<'",          "a='&bogus;'",
        "a='&#0;'",        "a='&#xD800;'",     "a='&#x110000;'", "a='&#X41;'",     "a='&#;'",
        "a='&amp'",        "a='\x01'",         "1a='x'",         "a='x' trailing", "a='x'\x0Cb='y'",
        "a='unterminated", "a='\xED\xA0\x80'",
    }) |data| {
        try attributes.parse("before='present'");
        try std.testing.expectError(error.InvalidPseudoAttributes, attributes.parse(data));
        try std.testing.expectEqual(@as(usize, 0), attributes.entries.size());
    }
}

test "PI attribute replacement, removal and serialization preserve map order" {
    var attributes = pi.Attributes.init(std.testing.allocator);
    defer attributes.deinit();
    try attributes.parse("first='x' second='y'");
    try attributes.set("first", "=&<>\"'");
    try attributes.set("third", "z");
    attributes.remove("second");
    const data = try attributes.serialize();
    defer std.testing.allocator.free(data);
    try std.testing.expectEqualStrings("first=\"=&amp;&lt;&gt;&quot;'\" third=\"z\"", data);
    try std.testing.expectEqualStrings("first", attributes.entries.items()[0].name);
    try std.testing.expectEqualStrings("third", attributes.entries.items()[1].name);
}

test "PI parsing and mutation clean up every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationScenario, .{});
}

fn allocationScenario(allocator: std.mem.Allocator) !void {
    var attributes = pi.Attributes.init(allocator);
    defer attributes.deinit();
    try attributes.parse("a='&amp;' b='2' c='3' d='4' e='&#x10000;'");
    try attributes.set("a", "new");
    try attributes.set("f", "&<>\"");
    const data = try attributes.serialize();
    defer allocator.free(data);
}
