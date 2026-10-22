//! The XML parser (src/xml/parser.zig) against real inputs: what it reports
//! for well-formed documents, and that each well-formedness and namespace
//! well-formedness error stops it (XML 1.0 Fifth Edition, Namespaces in XML
//! 1.0 Third Edition). The error inputs include every case of WPT's
//! domparsing/DOMParser-parseFromString-xml-parsererror.html.

const std = @import("std");
const xml = @import("xml");

/// A sink that writes each event on its own line.
const Trace = struct {
    out: std.ArrayList(u8) = .empty,
    allocator: std.mem.Allocator,

    fn deinit(self: *Trace) void {
        self.out.deinit(self.allocator);
    }

    fn line(self: *Trace, comptime fmt: []const u8, args: anytype) !void {
        if (self.out.items.len != 0) try self.out.append(self.allocator, '\n');
        try self.out.print(self.allocator, fmt, args);
    }

    pub fn xmlDeclaration(self: *Trace, decl: xml.XmlDeclaration) !void {
        try self.line("xmldecl {s} {s} {s}", .{ decl.version, decl.encoding orelse "-", if (decl.standalone) |s| (if (s) "yes" else "no") else "-" });
    }

    pub fn doctype(self: *Trace, name: []const u8, public_id: []const u8, system_id: []const u8) !void {
        try self.line("doctype {s} \"{s}\" \"{s}\"", .{ name, public_id, system_id });
    }

    pub fn startElement(self: *Trace, name: xml.Name, attributes: []const xml.Attribute) !void {
        try self.line("start {s}|{s}", .{ name.namespace orelse "", name.local });
        if (name.prefix) |prefix| try self.out.print(self.allocator, " prefix={s}", .{prefix});
        for (attributes) |attr| {
            try self.out.print(self.allocator, " {s}|{s}", .{ attr.name.namespace orelse "", attr.name.local });
            if (attr.name.prefix) |prefix| try self.out.print(self.allocator, "({s})", .{prefix});
            try self.out.print(self.allocator, "=\"{s}\"", .{attr.value});
        }
    }

    pub fn endElement(self: *Trace, name: xml.Name) !void {
        try self.line("end {s}", .{name.qualified});
    }

    pub fn text(self: *Trace, data: []const u8) !void {
        try self.line("text \"{s}\"", .{data});
    }

    pub fn cdata(self: *Trace, data: []const u8) !void {
        try self.line("cdata \"{s}\"", .{data});
    }

    pub fn comment(self: *Trace, data: []const u8) !void {
        try self.line("comment \"{s}\"", .{data});
    }

    pub fn processingInstruction(self: *Trace, target: []const u8, data: []const u8) !void {
        try self.line("pi {s} \"{s}\"", .{ target, data });
    }
};

/// Parse `input`; return the trace, ending in "error L:C <message>" when the
/// parse failed.
fn run(input: []const u8, options: xml.Options) ![]u8 {
    const allocator = std.testing.allocator;
    var trace: Trace = .{ .allocator = allocator };
    errdefer trace.deinit();
    var parser = xml.Parser.init(allocator, options);
    defer parser.deinit();
    if (try parser.parse(input, &trace)) |failure| {
        try trace.line("error {d}:{d} {s}", .{ failure.position.line, failure.position.column, failure.message });
    }
    return trace.out.toOwnedSlice(allocator);
}

fn expectTrace(input: []const u8, expected: []const u8) !void {
    const actual = try run(input, .{});
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualStrings(expected, actual);
}

/// The parse fails; return nothing else about it.
fn expectError(input: []const u8) !void {
    const actual = try run(input, .{});
    defer std.testing.allocator.free(actual);
    const last = if (std.mem.lastIndexOfScalar(u8, actual, '\n')) |i| actual[i + 1 ..] else actual;
    if (!std.mem.startsWith(u8, last, "error ")) {
        std.debug.print("expected a well-formedness error for {s}, got:\n{s}\n", .{ input, actual });
        return error.TestExpectedError;
    }
}

test "an element with text" {
    try expectTrace("<foo>bar</foo>",
        \\start |foo
        \\text "bar"
        \\end foo
    );
}

test "an empty-element tag reports a start and an end" {
    try expectTrace("<foo/>",
        \\start |foo
        \\end foo
    );
}

test "the XML declaration is reported and its pseudo-attributes read" {
    try expectTrace("<?xml version=\"1.0\" encoding='UTF-8' standalone=\"yes\"?><a/>",
        \\xmldecl 1.0 UTF-8 yes
        \\start |a
        \\end a
    );
    try expectTrace("<?xml version='1.1'?><a/>",
        \\xmldecl 1.1 - -
        \\start |a
        \\end a
    );
}

test "a default namespace applies to elements, not attributes" {
    try expectTrace("<html xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"en\"><body/></html>",
        \\start http://www.w3.org/1999/xhtml|html http://www.w3.org/2000/xmlns/|xmlns="http://www.w3.org/1999/xhtml" |lang="en"
        \\start http://www.w3.org/1999/xhtml|body
        \\end body
        \\end html
    );
}

test "prefixes bind elements and attributes, and the xml prefix is always bound" {
    try expectTrace("<x:a xmlns:x=\"urn:x\" x:b=\"1\" xml:lang=\"en\"><c/></x:a>",
        \\start urn:x|a prefix=x http://www.w3.org/2000/xmlns/|x(xmlns)="urn:x" urn:x|b(x)="1" http://www.w3.org/XML/1998/namespace|lang(xml)="en"
        \\start |c
        \\end c
        \\end x:a
    );
}

test "a namespace declaration is scoped to its element" {
    try expectTrace("<a><b xmlns=\"urn:b\"/><c/></a>",
        \\start |a
        \\start urn:b|b http://www.w3.org/2000/xmlns/|xmlns="urn:b"
        \\end b
        \\start |c
        \\end c
        \\end a
    );
}

test "xmlns=\"\" undeclares the default namespace" {
    try expectTrace("<a xmlns=\"urn:a\"><b xmlns=\"\"/></a>",
        \\start urn:a|a http://www.w3.org/2000/xmlns/|xmlns="urn:a"
        \\start |b http://www.w3.org/2000/xmlns/|xmlns=""
        \\end b
        \\end a
    );
}

test "attribute values are normalized: literal whitespace to spaces, character references kept" {
    try expectTrace("<a b=\"x\ty\nz&#10;&#x9;w\" c='&lt;&amp;&quot;&apos;&gt;'/>",
        \\start |a |b="x y z
    ++ "\n\tw\" |c=\"<&\"'>\"\n" ++
        \\end a
    );
}

test "character and predefined entity references in content join the surrounding text" {
    try expectTrace("<a>x&amp;y&#215;&#xD7;&lt;</a>",
        \\start |a
        \\text "x&y××<"
        \\end a
    );
}

test "CDATA sections, comments and processing instructions" {
    try expectTrace("<?pi data here?><a><![CDATA[> < \" and &]]><!-- c --><?t?><![CDATA[]]><!----></a><!--after-->",
        \\pi pi "data here"
        \\start |a
        \\cdata "> < " and &"
        \\comment " c "
        \\pi t ""
        \\cdata ""
        \\comment ""
        \\end a
        \\comment "after"
    );
}

test "the doctype reports its name and identifiers, and an internal subset declares entities" {
    try expectTrace("<!DOCTYPE foo [ <!ENTITY x \"y\"> ]><foo>&x;</foo>",
        \\doctype foo "" ""
        \\start |foo
        \\text "y"
        \\end foo
    );
    try expectTrace("<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"x\"><html/>",
        \\doctype html "-//W3C//DTD XHTML 1.0 Strict//EN" "x"
        \\start |html
        \\end html
    );
    try expectTrace("<!DOCTYPE html SYSTEM \"about:legacy-compat\"><html/>",
        \\doctype html "" "about:legacy-compat"
        \\start |html
        \\end html
    );
}

test "an internal entity's replacement text is parsed as content" {
    try expectTrace("<!DOCTYPE r [<!ENTITY e \"<b>t&#38;amp;</b>!\"><!ENTITY f \"&e;&e;\">]><r>[&f;]</r>",
        \\doctype r "" ""
        \\start |r
        \\text "["
        \\start |b
        \\text "t&"
        \\end b
        \\text "!"
        \\start |b
        \\text "t&"
        \\end b
        \\text "!]"
        \\end r
    );
}

test "the first declaration of an entity is binding" {
    try expectTrace("<!DOCTYPE r [<!ENTITY e \"1\"><!ENTITY e \"2\">]><r a=\"&e;\">&e;</r>",
        \\doctype r "" ""
        \\start |r |a="1"
        \\text "1"
        \\end r
    );
}

test "internal parameter entities expand between declarations" {
    // A non-validating parser applies internal-subset defaults it has read.
    try expectTrace("<!DOCTYPE r [<!ENTITY % decl \"<!ENTITY e 'pe'>\"> %decl; <!ELEMENT r ANY><!ATTLIST r a CDATA '>'>]><r>&e;</r>",
        \\doctype r "" ""
        \\start |r |a=">"
        \\text "pe"
        \\end r
    );
}

test "line ends are normalized to LF everywhere" {
    try expectTrace("<a b=\"1\r\n2\">x\r\ny\rz<!--c\r\n--></a>",
        \\start |a |b="1 2"
    ++ "\ntext \"x\ny\nz\"\ncomment \"c\n\"\n" ++
        \\end a
    );
}

test "whitespace around the root element is not reported" {
    try expectTrace("\n <a/> \n",
        \\start |a
        \\end a
    );
}

test "a byte order mark before the document is skipped" {
    try expectTrace("\xEF\xBB\xBF<a/>",
        \\start |a
        \\end a
    );
}

test "named references from the XHTML DTDs resolve only when the doctype names one" {
    const lookup = struct {
        fn html(name: []const u8) ?[]const u21 {
            if (std.mem.eql(u8, name, "nbsp")) return &[_]u21{0xA0};
            if (std.mem.eql(u8, name, "amp")) return &[_]u21{'&'};
            return null;
        }
    }.html;
    const doc = "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"\"><html a=\"&nbsp;\">&nbsp;</html>";
    const actual = try run(doc, .{ .xhtml_entities = lookup });
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualStrings(
        \\doctype html "-//W3C//DTD XHTML 1.0 Transitional//EN" ""
        \\start |html |a="
    ++ "\u{A0}\"\ntext \"\u{A0}\"\nend html", actual);

    const plain = try run("<html>&nbsp;</html>", .{ .xhtml_entities = lookup });
    defer std.testing.allocator.free(plain);
    try std.testing.expect(std.mem.indexOf(u8, plain, "error") != null);
}

test "events before the first error are reported, then the error with its position" {
    try expectTrace("<foo>\n  <bar>",
        \\start |foo
        \\text "
    ++ "\n  \"\nstart |bar\nerror 2:8 Premature end of data in tag bar line 2");
    try expectTrace("<a><b></a>",
        \\start |a
        \\start |b
        \\error 1:7 Opening and ending tag mismatch: b line 1 and a
    );
}

test "the WPT parsererror inputs are each an error" {
    const prologue = "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">\n" ++
        "<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" lang=\"en\">\n<body>\n";
    const epilogue = "</body>\n</html>\n";
    const fragments = [_][]const u8{
        "<span x:test=\"testing\">1</span>",
        "< span>2</span>",
        "<span :test=\"testing\">3</span>",
        "<span><em>4</span></em>",
        "<span>5",
        "6</span>",
        "<span>7< /span>",
        "<span>8</ span>",
        "<span novalue>9</span>",
        "<span =\"noattr\">10</span>",
        "<span ::=\"test\">11</span>",
        "<span xmlns:=\"urn:x-test:test\">12</span>",
        "<span xmlns:xmlns=\"\">13</span>",
        "<span data-test=testing>14</span>",
        "15<span",
        "<8:test xmlns:8=\"urn:x-test:test\">16</8:test>",
        "<span xmlns:p1 xmlns:p2=\"urn:x-test:test\"/>17",
    };
    inline for (fragments) |fragment| try expectError(prologue ++ fragment ++ epilogue);
    // The prologue and epilogue alone are well-formed.
    const whole = try run(prologue ++ epilogue, .{});
    defer std.testing.allocator.free(whole);
    try std.testing.expect(std.mem.indexOf(u8, whole, "error") == null);
}

test "well-formedness errors" {
    const inputs = [_][]const u8{
        "", // no root element
        "   ",
        "<a>", // unclosed
        "<a></b>",
        "<a/><b/>", // two roots
        "<a/>text", // text after the root
        "text<a/>",
        "<a>&undeclared;</a>",
        "<a>&#0;</a>", // not a Char
        "<a>&#xD800;</a>",
        "<a>&#xFFFE;</a>",
        "<a>&amp</a>", // reference without ';'
        "<a>& b</a>",
        "<a>\x01</a>", // control character
        "<a>\xFF</a>", // malformed UTF-8
        "<a>]]></a>", // ']]>' in content
        "<a b=\"<\"/>", // '<' in an attribute value
        "<a b=\"1\" b=\"2\"/>", // duplicate attribute
        "<a xmlns:p=\"urn:1\" xmlns:q=\"urn:1\" p:b=\"1\" q:b=\"2\"/>", // duplicate expanded name
        "<a b='1'c='2'/>", // no space between attributes
        "<a><!-- a -- b --></a>", // '--' in a comment
        "<a><!-- a ---></a>",
        "<a><!-- unterminated</a>",
        "<a><![CDATA[x</a>",
        "<a><?xml version='1.0'?></a>", // the declaration not at the start
        " <?xml version='1.0'?><a/>",
        "<?xml version='2.0'?><a/>",
        "<?xml encoding='UTF-8'?><a/>", // version is required
        "<a><?XmL x?></a>",
        "<a><?p:i x?></a>", // colon in a PI target
        "<a><? x?></a>",
        "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\"><html/>", // PUBLIC needs a system literal
        "<!DOCTYPE a><!DOCTYPE a><a/>",
        "<a/><!DOCTYPE a>",
        "<!DOCTYPE a [<!ENTITY e \"<b>\">]><a>&e;</b></a>", // entity not balanced
        "<!DOCTYPE a [<!ENTITY e \"&e;\">]><a>&e;</a>", // recursion
        "<!DOCTYPE a [<!ENTITY e \"<\">]><a b=\"&e;\"/>", // '<' via an entity in an attribute
        "<!DOCTYPE a [<!ENTITY e SYSTEM \"x\">]><a b=\"&e;\"/>", // external entity in an attribute
        "<!DOCTYPE a [<!ENTITY e SYSTEM \"x\" NDATA n>]><a>&e;</a>", // unparsed entity
        "<!DOCTYPE a [<!ENTITY e \"%p;\">]><a/>", // PE reference inside a declaration
        "<!DOCTYPE a [ junk ]><a/>",
        "<a:b/>", // undeclared element prefix
        "<xmlns:a/>",
        "<a xmlns:xml=\"urn:other\"/>",
        "<a xmlns:p=\"http://www.w3.org/XML/1998/namespace\"/>",
        "<a xmlns=\"http://www.w3.org/2000/xmlns/\"/>",
        "<a:b:c xmlns:a=\"urn:a\"/>",
        "<a b:=\"1\"/>",
        "<a\x01/>",
    };
    for (inputs) |input| try expectError(input);
}

test "an entity that expands past the limit is an error, not a hang" {
    const lol =
        \\<!DOCTYPE lolz [
        \\<!ENTITY lol "lollollollollollollollollollol">
        \\<!ENTITY lol1 "&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;">
        \\<!ENTITY lol2 "&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;">
        \\<!ENTITY lol3 "&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;">
        \\<!ENTITY lol4 "&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;">
        \\<!ENTITY lol5 "&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;">
        \\<!ENTITY lol6 "&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;">
        \\<!ENTITY lol7 "&lol6;&lol6;&lol6;&lol6;&lol6;&lol6;&lol6;&lol6;&lol6;&lol6;">
        \\<!ENTITY lol8 "&lol7;&lol7;&lol7;&lol7;&lol7;&lol7;&lol7;&lol7;&lol7;&lol7;">
        \\<!ENTITY lol9 "&lol8;&lol8;&lol8;&lol8;&lol8;&lol8;&lol8;&lol8;&lol8;&lol8;">
        \\]>
        \\<lolz>&lol9;</lolz>
    ;
    var trace: Trace = .{ .allocator = std.testing.allocator };
    defer trace.deinit();
    var parser = xml.Parser.init(std.testing.allocator, .{});
    defer parser.deinit();
    const failure = (try parser.parse(lol, &trace)) orelse return error.TestExpectedError;
    try std.testing.expect(std.mem.indexOf(u8, failure.message, "amplification") != null);
}

test "a sink's error stops the parse and propagates" {
    const Failing = struct {
        pub fn startElement(_: *@This(), _: xml.Name, _: []const xml.Attribute) !void {
            return error.SinkFailed;
        }
    };
    var sink: Failing = .{};
    var parser = xml.Parser.init(std.testing.allocator, .{});
    defer parser.deinit();
    try std.testing.expectError(error.SinkFailed, parser.parse("<a/>", &sink));
}

test "the encoding a document declares is found in its bytes" {
    try std.testing.expectEqualStrings("ISO-8859-1", xml.declaredEncoding("<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><a/>").?);
    try std.testing.expectEqualStrings("utf-16", xml.declaredEncoding("<?xml version='1.0' encoding='utf-16' ?>").?);
    try std.testing.expectEqual(@as(?[]const u8, null), xml.declaredEncoding("<?xml version=\"1.0\"?><a/>"));
    try std.testing.expectEqual(@as(?[]const u8, null), xml.declaredEncoding("<a encoding=\"x\"/>"));
    try std.testing.expectEqual(@as(?[]const u8, null), xml.declaredEncoding(" <?xml version='1.0' encoding='x'?>"));
}
