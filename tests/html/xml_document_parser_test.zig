//! HTML §14.2's XML parser building a Document (src/html/xml_document_parser.zig):
//! elements made with their namespaces and prefixes, attributes in theirs,
//! the doctype, character data, CDATA sections, comments and processing
//! instructions; template contents; and the error document Chrome and Safari
//! make on a well-formedness error (golden rule 2: their shape, the majority).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const xml_document_parser = @import("html").xml_document_parser;

const xhtml = "http://www.w3.org/1999/xhtml";

const Harness = struct {
    context: runtime.ContextData,
    document: *runtime.Instance,

    fn init(self: *Harness) !void {
        const allocator = std.testing.allocator;
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(allocator);
        self.context = try runtime.ContextData.init(allocator, .{});
        self.document = try interfaces.Document.call_constructor(&self.context);
        try dom.document_internals.setDocumentType(self.document, .xml);
    }

    fn deinit(self: *Harness) void {
        interfaces.Document.deinit(self.document);
        self.context.deinit();
        runtime.deinitializeRuntime();
    }
};

fn appendString(out: *std.ArrayList(u8), value: anytype) !void {
    var s = value;
    defer s.deinit(std.testing.allocator);
    try out.appendSlice(std.testing.allocator, s.asSlice());
}

/// The tree under `node`, one compact form per node:
/// element `{ns}prefix:local[{ns}name=value ...](children)`, `"text"`,
/// `<![CDATA[data]]>`, `<!--data-->`, `<?target data?>`, `<!DOCTYPE name "pub" "sys">`.
fn describe(out: *std.ArrayList(u8), node: *runtime.Instance) anyerror!void {
    const a = std.testing.allocator;
    switch (try interfaces.Node.get_nodeType(node)) {
        1 => {
            try out.append(a, '{');
            if (try interfaces.Element.get_namespaceURI(node)) |ns| try appendString(out, ns);
            try out.append(a, '}');
            if (try interfaces.Element.get_prefix(node)) |prefix| {
                try appendString(out, prefix);
                try out.append(a, ':');
            }
            try appendString(out, try interfaces.Element.get_localName(node));
            const count = dom.element_attributes.count(node);
            if (count > 0) {
                try out.append(a, '[');
                for (0..count) |i| {
                    const attr = dom.element_attributes.at(node, i).?;
                    if (i > 0) try out.append(a, ' ');
                    try out.print(a, "{{{s}}}", .{attr.namespace orelse ""});
                    if (attr.prefix) |prefix| try out.print(a, "{s}:", .{prefix});
                    try out.print(a, "{s}={s}", .{ attr.local_name, attr.value });
                }
                try out.append(a, ']');
            }
            const holder = if (try interfaces.Element.get_namespaceURI(node)) |ns_value| blk: {
                var ns = ns_value;
                defer ns.deinit(a);
                var local = try interfaces.Element.get_localName(node);
                defer local.deinit(a);
                break :blk if (std.mem.eql(u8, ns.asSlice(), xhtml) and std.mem.eql(u8, local.asSlice(), "template"))
                    try interfaces.HTMLTemplateElement.get_content(node)
                else
                    node;
            } else node;
            try children(out, holder);
        },
        3 => {
            try out.append(a, '"');
            try appendString(out, (try interfaces.Node.get_textContent(node)).?);
            try out.append(a, '"');
        },
        4 => {
            try out.appendSlice(a, "<![CDATA[");
            try appendString(out, (try interfaces.Node.get_textContent(node)).?);
            try out.appendSlice(a, "]]>");
        },
        7 => {
            try out.appendSlice(a, "<?");
            try appendString(out, try interfaces.Node.get_nodeName(node));
            try out.append(a, ' ');
            try appendString(out, (try interfaces.Node.get_textContent(node)).?);
            try out.appendSlice(a, "?>");
        },
        8 => {
            try out.appendSlice(a, "<!--");
            try appendString(out, (try interfaces.Node.get_textContent(node)).?);
            try out.appendSlice(a, "-->");
        },
        10 => {
            try out.appendSlice(a, "<!DOCTYPE ");
            try appendString(out, try interfaces.DocumentType.get_name(node));
            try out.appendSlice(a, " \"");
            try appendString(out, try interfaces.DocumentType.get_publicId(node));
            try out.appendSlice(a, "\" \"");
            try appendString(out, try interfaces.DocumentType.get_systemId(node));
            try out.appendSlice(a, "\">");
        },
        else => try out.appendSlice(a, "?"),
    }
}

fn children(out: *std.ArrayList(u8), node: *runtime.Instance) anyerror!void {
    const a = std.testing.allocator;
    var child = try interfaces.Node.get_firstChild(node);
    if (child == null) return;
    try out.append(a, '(');
    var first = true;
    while (child) |c| : (child = try interfaces.Node.get_nextSibling(c)) {
        if (!first) try out.append(a, ' ');
        first = false;
        try describe(out, c);
    }
    try out.append(a, ')');
}

fn expectTree(document: *runtime.Instance, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(std.testing.allocator);
    var child = try interfaces.Node.get_firstChild(document);
    var first = true;
    while (child) |c| : (child = try interfaces.Node.get_nextSibling(c)) {
        if (!first) try out.append(std.testing.allocator, ' ');
        first = false;
        try describe(&out, c);
    }
    try std.testing.expectEqualStrings(expected, out.items);
}

test "a well-formed document becomes its tree, names and namespaces as written" {
    var h: Harness = undefined;
    try h.init();
    defer h.deinit();
    const failure = try xml_document_parser.parseInto(h.document, "<?xml version='1.0'?><!DOCTYPE r PUBLIC \"p\" \"s\"><?top here?>" ++
        "<r xmlns=\"urn:r\" a=\"1\" xml:lang=\"en\"><b:c xmlns:b=\"urn:b\" b:d=\"2\">t&amp;u</b:c><![CDATA[<x>]]><!--c--><?pi d?></r><!--after-->", .{});
    try std.testing.expect(failure == null);
    try expectTree(h.document, "<!DOCTYPE r \"p\" \"s\"> <?top here?> " ++
        "{urn:r}r[{http://www.w3.org/2000/xmlns/}xmlns=urn:r {}a=1 {http://www.w3.org/XML/1998/namespace}xml:lang=en]" ++
        "({urn:b}b:c[{http://www.w3.org/2000/xmlns/}xmlns:b=urn:b {urn:b}b:d=2](\"t&u\") <![CDATA[<x>]]> <!--c--> <?pi d?>) <!--after-->");
    // The doctype is the document's.
    try std.testing.expect(try interfaces.Document.get_doctype(h.document) != null);
}

test "a template's children go to its contents" {
    var h: Harness = undefined;
    try h.init();
    defer h.deinit();
    const failure = try xml_document_parser.parseInto(h.document, "<html xmlns=\"http://www.w3.org/1999/xhtml\"><template><p>x</p></template></html>", .{});
    try std.testing.expect(failure == null);
    try expectTree(h.document, "{http://www.w3.org/1999/xhtml}html[{http://www.w3.org/2000/xmlns/}xmlns=http://www.w3.org/1999/xhtml]" ++
        "({http://www.w3.org/1999/xhtml}template({http://www.w3.org/1999/xhtml}p(\"x\")))");
    const html = (try interfaces.Document.get_documentElement(h.document)).?;
    const template = (try interfaces.Node.get_firstChild(html)).?;
    // The template element itself has no children.
    try std.testing.expect(try interfaces.Node.get_firstChild(template) == null);
}

test "an error keeps the tree so far and puts Chrome's and Safari's parsererror block first in the root" {
    var h: Harness = undefined;
    try h.init();
    defer h.deinit();
    const failure = (try xml_document_parser.parseInto(h.document, "<foo><bar>x</bar>", .{})) orelse return error.TestExpectedFailure;
    try xml_document_parser.insertErrorMessageBlock(h.document, failure);
    try expectTree(h.document, "{}foo(" ++
        "{http://www.w3.org/1999/xhtml}parsererror[{}style=display: block; white-space: pre; border: 2px solid #c77; padding: 0 1em 0 1em; margin: 1em; background-color: #fdd; color: black](" ++
        "{http://www.w3.org/1999/xhtml}h3(\"This page contains the following errors:\") " ++
        "{http://www.w3.org/1999/xhtml}div[{}style=font-family:monospace;font-size:12px](\"error on line 1 at column 18: Premature end of data in tag foo line 1\n\") " ++
        "{http://www.w3.org/1999/xhtml}h3(\"Below is a rendering of the page up to the first error.\")) " ++
        "{}bar(\"x\"))");
}

test "an error before any root makes html and body to hold the block" {
    var h: Harness = undefined;
    try h.init();
    defer h.deinit();
    const failure = (try xml_document_parser.parseInto(h.document, "", .{})) orelse return error.TestExpectedFailure;
    try xml_document_parser.insertErrorMessageBlock(h.document, failure);
    var root = (try interfaces.Document.get_documentElement(h.document)).?;
    var name = try interfaces.Element.get_localName(root);
    defer name.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("html", name.asSlice());
    const body = (try interfaces.Node.get_firstChild(root)).?;
    var body_name = try interfaces.Element.get_localName(body);
    defer body_name.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("body", body_name.asSlice());
    const block = (try interfaces.Node.get_firstChild(body)).?;
    var block_name = try interfaces.Element.get_localName(block);
    defer block_name.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("parsererror", block_name.asSlice());
    root = root;
}

test "an SVG root is moved into a body after the block, with a head and style before" {
    var h: Harness = undefined;
    try h.init();
    defer h.deinit();
    const failure = (try xml_document_parser.parseInto(h.document, "<svg xmlns=\"http://www.w3.org/2000/svg\"><g>", .{})) orelse return error.TestExpectedFailure;
    try xml_document_parser.insertErrorMessageBlock(h.document, failure);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(std.testing.allocator);
    try describe(&out, (try interfaces.Document.get_documentElement(h.document)).?);
    try std.testing.expect(std.mem.startsWith(u8, out.items, "{http://www.w3.org/1999/xhtml}html(" ++
        "{http://www.w3.org/1999/xhtml}head({http://www.w3.org/1999/xhtml}style(\"html, body { height: 100% } parsererror + svg { width: 100%; height: 100% }\")) " ++
        "{http://www.w3.org/1999/xhtml}body({http://www.w3.org/1999/xhtml}parsererror["));
    try std.testing.expect(std.mem.endsWith(u8, out.items, "{http://www.w3.org/2000/svg}svg[{http://www.w3.org/2000/xmlns/}xmlns=http://www.w3.org/2000/svg]({http://www.w3.org/2000/svg}g)))"));
}

test "XML bytes decode by BOM, then the transport's charset, then the declaration, then UTF-8" {
    const allocator = std.testing.allocator;
    const sniffing = @import("html_core").parser.encoding_sniffing;
    const xml = "<?xml version='1.0' encoding='windows-1252'?><x>\xe6\xa9\x9f</x>";
    {
        const decoded = (try xml_document_parser.decodeBytes(allocator, xml, null)).?;
        defer allocator.free(decoded.text);
        try std.testing.expectEqualStrings("windows-1252", sniffing.canonicalName(decoded.encoding));
        try std.testing.expect(std.mem.indexOf(u8, decoded.text, "<x>\u{e6}\u{a9}\u{178}</x>") != null);
    }
    {
        const decoded = (try xml_document_parser.decodeBytes(allocator, xml, sniffing.utf_8)).?;
        defer allocator.free(decoded.text);
        try std.testing.expectEqualStrings("UTF-8", sniffing.canonicalName(decoded.encoding));
        try std.testing.expect(std.mem.indexOf(u8, decoded.text, "<x>\u{6a5f}</x>") != null);
    }
    {
        const decoded = (try xml_document_parser.decodeBytes(allocator, "\xFF\xFE<\x00a\x00/\x00>\x00", null)).?;
        defer allocator.free(decoded.text);
        try std.testing.expectEqualStrings("UTF-16LE", sniffing.canonicalName(decoded.encoding));
        try std.testing.expectEqualStrings("<a/>", decoded.text);
    }
    {
        const decoded = (try xml_document_parser.decodeBytes(allocator, "<a/>", null)).?;
        defer allocator.free(decoded.text);
        try std.testing.expectEqualStrings("UTF-8", sniffing.canonicalName(decoded.encoding));
    }
    try std.testing.expect(try xml_document_parser.decodeBytes(allocator, "<?xml version='1.0' encoding='no-such-encoding'?><a/>", null) == null);
}

test "the XML fragment parsing algorithm parses in the context's namespaces" {
    var h: Harness = undefined;
    try h.init();
    defer h.deinit();
    try std.testing.expect(try xml_document_parser.parseInto(h.document, "<r xmlns=\"urn:r\" xmlns:p=\"urn:p\"><c xmlns:q=\"urn:q&amp;&quot;\"/></r>", .{}) == null);
    const root = (try interfaces.Document.get_documentElement(h.document)).?;
    const context = (try interfaces.Node.get_firstChild(root)).?;
    const fragment = try xml_document_parser.parseFragment(context, "<d/><p:e q:f=\"1\"/>t<!--c-->");
    defer dom.node_creation.destroyUninserted(fragment);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(std.testing.allocator);
    try children(&out, fragment);
    try std.testing.expectEqualStrings("({urn:r}d {urn:p}p:e[{urn:q&\"}q:f=1] \"t\" <!--c-->)", out.items);
    // The fragment's nodes are the context's document's.
    const first = (try interfaces.Node.get_firstChild(fragment)).?;
    try std.testing.expectEqual(h.document, (try interfaces.Node.get_ownerDocument(first)).?);
    // Not well-formed: a SyntaxError.
    try std.testing.expectError(error.SyntaxError, xml_document_parser.parseFragment(context, "<d>"));
    try std.testing.expectError(error.SyntaxError, xml_document_parser.parseFragment(context, "<x:d/>"));
}
