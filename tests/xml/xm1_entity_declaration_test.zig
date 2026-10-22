//! XML entity handling: browser majority for missing declarations and standalone errors.
//! Measured Chrome 155, Firefox 158, Safari 27: row 113 Q17/Q18/Q19, 2026-10-22.
const std = @import("std");
const xml = @import("xml");

const Sink = struct {
    allocator: std.mem.Allocator,
    output: std.ArrayList(u8) = .empty,

    pub fn startElement(self: *@This(), _: xml.Name, attributes: []const xml.Attribute) !void {
        for (attributes) |attribute| {
            try self.output.appendSlice(self.allocator, attribute.name.qualified);
            try self.output.append(self.allocator, '=');
            try self.output.appendSlice(self.allocator, attribute.value);
            try self.output.append(self.allocator, ';');
        }
    }

    pub fn text(self: *@This(), value: []const u8) !void {
        try self.output.appendSlice(self.allocator, value);
    }

    pub fn endElement(_: *@This(), _: xml.Name) !void {}
};

fn check(parser: *xml.Parser, allocator: std.mem.Allocator, source: []const u8, expected: ?[]const u8) !void {
    var sink: Sink = .{ .allocator = allocator };
    defer sink.output.deinit(allocator);
    const failure = try parser.parse(source, &sink);
    if (expected) |value| {
        try std.testing.expect(failure == null);
        try std.testing.expectEqualStrings(value, sink.output.items);
    } else try std.testing.expect(failure != null);
}

test "undeclared general entities stay fatal with external declarations or parameter references" {
    var parser = xml.Parser.init(std.testing.allocator, .{});
    defer parser.deinit();
    for ([_][]const u8{
        "<r>&missing;</r>",
        "<r a='&missing;'/>",
        "<!DOCTYPE r SYSTEM 'about:blank'><r>&missing;</r>",
        "<!DOCTYPE r SYSTEM 'about:blank'><r a='&missing;'/>",
        "<!DOCTYPE r SYSTEM 'about:blank' [<!ATTLIST r a CDATA '&missing;'>]><r/>",
        "<!DOCTYPE r [<!ENTITY % p ''>%p;]><r>&missing;</r>",
        "<!DOCTYPE r [<!ENTITY % p ''>%p;]><r a='&missing;'/>",
        "<!DOCTYPE r [<!ENTITY % p ''>%p;<!ATTLIST r a CDATA '&missing;'>]><r/>",
        "<!DOCTYPE r [<!ENTITY % p SYSTEM 'about:blank'>%p;]><r>&missing;</r>",
    }) |source| try check(&parser, std.testing.allocator, source, null);
}

test "non-standalone documents continue skipping declarations after an unread external parameter entity" {
    var parser = xml.Parser.init(std.testing.allocator, .{});
    defer parser.deinit();
    try check(&parser, std.testing.allocator, "<!DOCTYPE r [<!ENTITY % p SYSTEM 'about:blank'>%p;<!ATTLIST r a CDATA 'ok'>]><r/>", "");
    try check(&parser, std.testing.allocator, "<?xml version='1.0' standalone='no'?><!DOCTYPE r [<!ENTITY % p SYSTEM 'about:blank'>%p;<!ATTLIST r a CDATA 'ok'>]><r/>", "");
    try check(&parser, std.testing.allocator, "<!DOCTYPE r [<!ENTITY % p SYSTEM 'about:blank'>%p;<!ENTITY e 'ok'>]><r>&e;</r>", null);
}

test "standalone yes rejects an unread external parameter entity before later declarations" {
    var parser = xml.Parser.init(std.testing.allocator, .{});
    defer parser.deinit();
    for ([_][]const u8{
        "<?xml version='1.0' standalone='yes'?><!DOCTYPE r [<!ENTITY % p SYSTEM 'about:blank'>%p;]><r/>",
        "<?xml version='1.0' standalone='yes'?><!DOCTYPE r [<!ENTITY % p SYSTEM 'about:blank'>%p;<!ENTITY e 'ok'>]><r/>",
        "<?xml version='1.0' standalone='yes'?><!DOCTYPE r [<!ENTITY % p SYSTEM 'about:blank'>%p;<!ATTLIST r a CDATA 'ok'>]><r/>",
    }) |source| try check(&parser, std.testing.allocator, source, null);
}

test "standalone yes still processes internal parameter entities" {
    var parser = xml.Parser.init(std.testing.allocator, .{});
    defer parser.deinit();
    try check(&parser, std.testing.allocator, "<?xml version='1.0' standalone='yes'?><!DOCTYPE r [<!ENTITY % p \"<!ATTLIST r a CDATA 'ok'>\">%p;]><r/>", "a=ok;");
}

fn resetStandalone(allocator: std.mem.Allocator) !void {
    var parser = xml.Parser.init(allocator, .{});
    defer parser.deinit();
    try check(&parser, allocator, "<?xml version='1.0' standalone='yes'?><!DOCTYPE r [<!ENTITY % p SYSTEM 'about:blank'>%p;]><r/>", null);
    try check(&parser, allocator, "<!DOCTYPE r [<!ENTITY % p SYSTEM 'about:blank'>%p;<!ATTLIST r a CDATA 'ok'>]><r/>", "");
    try check(&parser, allocator, "<?xml version='1.0' standalone='yes'?><r/>", "");
    try check(&parser, allocator, "<?xml version='1.0' standalone='no'?><!DOCTYPE r [<!ENTITY % p SYSTEM 'about:blank'>%p;]><r/>", "");
}

test "standalone resets between documents and cleans up on allocation failures" {
    try resetStandalone(std.testing.allocator);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, resetStandalone, .{});
}
