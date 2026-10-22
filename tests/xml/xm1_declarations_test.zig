//! XML 1.0 §§3.2, 3.3, 4.7 and Namespaces in XML §§5, 7.
//! Declaration grammar is required even for a non-validating processor.
const std = @import("std");
const xml = @import("xml");

const Capture = struct {
    allocator: std.mem.Allocator,
    attributes: std.ArrayList(u8) = .empty,

    fn deinit(self: *Capture) void {
        self.attributes.deinit(self.allocator);
    }

    pub fn startElement(self: *Capture, name: xml.Name, attributes: []const xml.Attribute) !void {
        try self.attributes.print(self.allocator, "{s}|{s}\n", .{ name.namespace orelse "", name.qualified });
        for (attributes) |a| try self.attributes.print(self.allocator, "{s}|{s}={s}\n", .{ a.name.namespace orelse "", a.name.qualified, a.value });
    }

    pub fn endElement(_: *Capture, _: xml.Name) !void {}
    pub fn text(_: *Capture, _: []const u8) !void {}
};

fn expectAttributes(allocator: std.mem.Allocator, source: []const u8, expected: []const u8) !void {
    var capture: Capture = .{ .allocator = allocator };
    defer capture.deinit();
    var parser = xml.Parser.init(allocator, .{});
    defer parser.deinit();
    if (try parser.parse(source, &capture)) |failure| {
        std.debug.print("unexpected XML error: {s}\n", .{failure.message});
        return error.UnexpectedXmlError;
    }
    try std.testing.expectEqualStrings(expected, capture.attributes.items);
}

fn expectError(source: []const u8) !void {
    var capture: Capture = .{ .allocator = std.testing.allocator };
    defer capture.deinit();
    var parser = xml.Parser.init(std.testing.allocator, .{});
    defer parser.deinit();
    if (try parser.parse(source, &capture) == null) {
        std.debug.print("accepted malformed XML: {s}\n", .{source});
        return error.ExpectedXmlError;
    }
}

test "DTD default attributes are supplied with first-declaration precedence" {
    try expectAttributes(
        std.testing.allocator,
        "<!DOCTYPE r [<!ENTITY e 'first'><!ATTLIST r a CDATA '&e;' b CDATA 'default'><!ATTLIST r a CDATA 'last'>]><r b='explicit'/>",
        "|r\n|b=explicit\n|a=first\n",
    );
}

test "non-CDATA attribute normalization collapses spaces but not character-reference tabs" {
    try expectAttributes(
        std.testing.allocator,
        "<!DOCTYPE r [<!ATTLIST r a NMTOKENS #IMPLIED b NMTOKENS '  one   two  '>]><r a='  one&#9;two  '/>",
        "|r\n|a=one\ttwo\n|b=one two\n",
    );
}

test "default namespace declarations precede expanded-name resolution" {
    try expectAttributes(
        std.testing.allocator,
        "<!DOCTYPE r [<!ATTLIST r xmlns CDATA 'urn:r' xmlns:p CDATA 'urn:p' p:a CDATA 'yes'>]><r/>",
        "urn:r|r\nhttp://www.w3.org/2000/xmlns/|xmlns=urn:r\nhttp://www.w3.org/2000/xmlns/|xmlns:p=urn:p\nurn:p|p:a=yes\n",
    );
}

test "non-validating XML accepts valid declaration grammar without enforcing validity constraints" {
    const subsets = [_][]const u8{
        "<!ELEMENT r EMPTY>",
        "<!ELEMENT r ANY>",
        "<!ELEMENT r (a,(b|c)+,d?)>",
        "<!ELEMENT r (#PCDATA)>",
        "<!ELEMENT r (#PCDATA|a|b)*>",
        "<!ATTLIST r>",
        "<!ATTLIST r a ID #REQUIRED b IDREFS #IMPLIED c (one|two) #IMPLIED>",
        "<!ATTLIST r a NOTATION (n) #IMPLIED><!NOTATION n PUBLIC 'identifier'>",
        "<!NOTATION n SYSTEM 'identifier'>",
    };
    for (subsets) |subset| {
        const source = try std.fmt.allocPrint(std.testing.allocator, "<!DOCTYPE r [{s}]><r/>", .{subset});
        defer std.testing.allocator.free(source);
        try expectAttributes(std.testing.allocator, source, "|r\n");
    }
}

test "malformed DTD declarations fail before the root is parsed" {
    const subsets = [_][]const u8{
        "<!ELEMENT r WHAT>",
        "<!ELEMENT r (a,b|c)>",
        "<!ELEMENT r (#PCDATA|a)>",
        "<!ELEMENT r ()>",
        "<!ELEMENT r (a,)>",
        "<!ATTLIST r a WHATEVER 'x'>",
        "<!ATTLIST r a () 'x'>",
        "<!ATTLIST r a CDATA>",
        "<!ATTLIST r a CDATA '&#0;'>",
        "<!ATTLIST r a CDATA '<'>",
        "<!ATTLIST r a CDATA '&e;'><!ENTITY e 'hello'>",
        "<!NOTATION n WHATEVER>",
        "<!ENTITY % t 'ANY'><!ELEMENT r %t;>",
    };
    for (subsets) |subset| {
        const source = try std.fmt.allocPrint(std.testing.allocator, "<!DOCTYPE r [{s}]><r/>", .{subset});
        defer std.testing.allocator.free(source);
        try expectError(source);
    }
}

test "entity and notation names are NCNames, and declaration element names are QNames" {
    const sources = [_][]const u8{
        "<!DOCTYPE r [<!ENTITY p:e 'text'>]><r>&p:e;</r>",
        "<!DOCTYPE r [<!ENTITY % p:e 'text'>]><r/>",
        "<!DOCTYPE r [<!NOTATION p:n SYSTEM 'x'>]><r/>",
        "<!DOCTYPE a:b:c><r/>",
        "<!DOCTYPE r [<!ELEMENT a:b:c ANY>]><r/>",
        "<!DOCTYPE r [<!ATTLIST r a:b:c CDATA #IMPLIED>]><r/>",
    };
    for (sources) |source| try expectError(source);
}

test "DTD defaults release allocations on every failure path" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, expectAttributes, .{
        "<!DOCTYPE r [<!ENTITY e 'hello'><!ATTLIST r a NMTOKENS ' &e;  world '>]><r/>",
        "|r\n|a=hello world\n",
    });
}

test "parameter entity expansion may grow the declaration table while its caller is active" {
    var source: std.ArrayList(u8) = .empty;
    defer source.deinit(std.testing.allocator);
    try source.appendSlice(std.testing.allocator, "<!DOCTYPE r [<!ENTITY % many \"");
    for (0..48) |i| try source.print(std.testing.allocator, "<!ENTITY &#37; p{d} ''>", .{i});
    try source.appendSlice(std.testing.allocator, "\">%many;%p47;%many;]><r/>");
    // Every declaration is valid. In particular, the parameter-entity map
    // can reallocate while the outer expansion remains active.
    try expectAttributes(std.testing.allocator, source.items, "|r\n");
}
