//! HTML 13.3 fragment serialization and DOM Parsing 5.2.1 XML serialization.
//! The namespace stack and output belong to one operation. All DOM state is
//! reached through interfaces or owner-installed hooks.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const html_ns = "http://www.w3.org/1999/xhtml";
const xml_ns = "http://www.w3.org/XML/1998/namespace";
const xmlns_ns = "http://www.w3.org/2000/xmlns/";
const xlink_ns = "http://www.w3.org/1999/xlink";
const svg_ns = "http://www.w3.org/2000/svg";
const math_ns = "http://www.w3.org/1998/Math/MathML";

pub fn fragment(node: *runtime.Instance, force_html: bool) !runtime.DOMString {
    return serialize(node.ctx.allocator, node, true, force_html or try isHtmlDocument(node), true);
}

pub fn outer(node: *runtime.Instance) !runtime.DOMString {
    return serialize(node.ctx.allocator, node, false, try isHtmlDocument(node), true);
}

pub fn xml(allocator: std.mem.Allocator, node: *runtime.Instance) !runtime.DOMString {
    // HTML XMLSerializer.serializeToString: require well-formed is false.
    return serialize(allocator, node, false, false, false);
}

fn isHtmlDocument(node: *runtime.Instance) !bool {
    const document = if (try interfaces.Node.get_nodeType(node) == interfaces.Node.get_DOCUMENT_NODE()) node else (try interfaces.Node.get_ownerDocument(node)) orelse return false;
    return dom.document_internals.getDocumentType(document) == .html;
}

fn serialize(allocator: std.mem.Allocator, node: *runtime.Instance, children_only: bool, html: bool, well_formed: bool) !runtime.DOMString {
    var writer = Writer{ .allocator = allocator, .html = html, .well_formed = well_formed };
    defer writer.deinit();
    if (!html) try writer.bindings.append(writer.allocator, .{ .prefix = "xml", .namespace = xml_ns });
    if (children_only) try writer.children(node, null) else try writer.node(node, null);
    return runtime.DOMString.initOwned(try writer.output.toOwnedSlice(writer.allocator));
}

fn same(a: ?[]const u8, b: ?[]const u8) bool {
    if (a) |left| return if (b) |right| std.mem.eql(u8, left, right) else false;
    return b == null;
}

fn optionalString(value: ?runtime.DOMString) ?[]const u8 {
    return if (value) |s| s.asSlice() else null;
}

fn nullable(value: []const u8) ?[]const u8 {
    return if (value.len == 0) null else value;
}

fn isVoid(name: []const u8) bool {
    return std.StaticStringMap(void).initComptime(.{
        .{ "area", {} },  .{ "base", {} }, .{ "basefont", {} }, .{ "bgsound", {} },
        .{ "br", {} },    .{ "col", {} },  .{ "embed", {} },    .{ "frame", {} },
        .{ "hr", {} },    .{ "img", {} },  .{ "input", {} },    .{ "keygen", {} },
        .{ "link", {} },  .{ "meta", {} }, .{ "param", {} },    .{ "source", {} },
        .{ "track", {} }, .{ "wbr", {} },
    }).has(name);
}

const Binding = struct { prefix: []const u8, namespace: ?[]const u8 };

const Writer = struct {
    allocator: std.mem.Allocator,
    html: bool,
    well_formed: bool,
    output: std.ArrayList(u8) = .empty,
    bindings: std.ArrayList(Binding) = .empty,
    generated: std.ArrayList([]u8) = .empty,
    prefix_index: usize = 1,

    fn deinit(self: *Writer) void {
        self.output.deinit(self.allocator);
        self.bindings.deinit(self.allocator);
        for (self.generated.items) |s| self.allocator.free(s);
        self.generated.deinit(self.allocator);
    }

    fn add(self: *Writer, text: []const u8) !void {
        try self.output.appendSlice(self.allocator, text);
    }

    fn qualified(self: *Writer, prefix: ?[]const u8, name: []const u8) !void {
        if (prefix) |p| {
            try self.add(p);
            try self.add(":");
        }
        try self.add(name);
    }

    fn escaped(self: *Writer, text: []const u8, attribute_mode: bool) !void {
        if (!self.html and self.well_formed and !xmlCharacters(text)) return error.InvalidStateError;
        var position: usize = 0;
        while (position < text.len) : (position += 1) {
            const replacement: ?[]const u8 = switch (text[position]) {
                '&' => "&amp;",
                '<' => "&lt;",
                // DOM Parsing's attribute-value note and WPT require '>' too.
                '>' => "&gt;",
                '"' => if (attribute_mode) "&quot;" else null,
                '\t' => if (!self.html and attribute_mode) "&#9;" else null,
                '\n' => if (!self.html and attribute_mode) "&#xA;" else null,
                '\r' => if (!self.html and attribute_mode) "&#xD;" else null,
                0xc2 => if (self.html and position + 1 < text.len and text[position + 1] == 0xa0) blk: {
                    position += 1;
                    break :blk "&nbsp;";
                } else null,
                else => null,
            };
            if (replacement) |s| try self.add(s) else try self.output.append(self.allocator, text[position]);
        }
    }

    fn attribute(self: *Writer, prefix: ?[]const u8, name: []const u8, value: []const u8) !void {
        try self.add(" ");
        try self.qualified(prefix, name);
        try self.add("=\"");
        try self.escaped(value, true);
        try self.add("\"");
    }

    fn children(self: *Writer, parent: *runtime.Instance, namespace: ?[]const u8) anyerror!void {
        // HTML fragment steps 1 and 3; XML element steps 18–19.
        if (self.html and parent.stateAs(interfaces.Element.State) != null) {
            var ns = try interfaces.Element.get_namespaceURI(parent);
            defer if (ns) |*s| s.deinit(parent.ctx.allocator);
            var name = try interfaces.Element.get_localName(parent);
            defer name.deinit(parent.ctx.allocator);
            if (same(optionalString(ns), html_ns) and isVoid(name.asSlice())) return;
        }
        const target = try dom.template_contents.insertionTarget(parent);
        var child = try interfaces.Node.get_firstChild(target);
        while (child) |current| : (child = try interfaces.Node.get_nextSibling(current))
            try self.node(current, namespace);
    }

    fn rawText(node_value: *runtime.Instance) !bool {
        const parent = (try interfaces.Node.get_parentNode(node_value)) orelse return false;
        if (parent.stateAs(interfaces.Element.State) == null) return false;
        var namespace = try interfaces.Element.get_namespaceURI(parent);
        defer if (namespace) |*s| s.deinit(parent.ctx.allocator);
        if (!same(optionalString(namespace), html_ns)) return false;
        var name = try interfaces.Element.get_localName(parent);
        defer name.deinit(parent.ctx.allocator);
        const local = name.asSlice();
        if (std.StaticStringMap(void).initComptime(.{
            .{ "style", {} },   .{ "script", {} },   .{ "xmp", {} },       .{ "iframe", {} },
            .{ "noembed", {} }, .{ "noframes", {} }, .{ "plaintext", {} },
        }).has(local)) return true;
        if (std.mem.eql(u8, local, "noscript")) {
            const doc = (try interfaces.Node.get_ownerDocument(node_value)) orelse return false;
            // HTML 8.1.3.4: a node whose document has no browsing context
            // has scripting disabled (including template owner documents).
            return dom.document_internals.isScriptingEnabled(doc) and try interfaces.Document.get_defaultView(doc) != null;
        }
        return false;
    }

    fn node(self: *Writer, value: *runtime.Instance, namespace: ?[]const u8) anyerror!void {
        const kind = try interfaces.Node.get_nodeType(value);
        if (kind == interfaces.Node.get_ELEMENT_NODE()) return self.element(value, namespace);
        if (kind == interfaces.Node.get_DOCUMENT_NODE() or kind == interfaces.Node.get_DOCUMENT_FRAGMENT_NODE()) {
            // XML Document step 1.
            if (!self.html and self.well_formed and kind == interfaces.Node.get_DOCUMENT_NODE() and
                try interfaces.Document.get_documentElement(value) == null) return error.InvalidStateError;
            return self.children(value, namespace);
        }
        if (kind == interfaces.Node.get_ATTRIBUTE_NODE()) return;
        if (kind == interfaces.Node.get_DOCUMENT_TYPE_NODE()) return self.doctype(value);
        var data = try interfaces.CharacterData.get_data(value);
        defer data.deinit(value.ctx.allocator);
        const text = data.asSlice();
        switch (kind) {
            interfaces.Node.get_TEXT_NODE() => {
                if (self.html and try rawText(value)) try self.add(text) else try self.escaped(text, false);
            },
            interfaces.Node.get_CDATA_SECTION_NODE() => {
                if (self.html) {
                    if (try rawText(value)) try self.add(text) else try self.escaped(text, false);
                    return;
                }
                try self.add("<![CDATA[");
                try self.add(text);
                try self.add("]]>");
            },
            interfaces.Node.get_COMMENT_NODE() => {
                // XML Comment step 1.
                if (!self.html and self.well_formed and (!xmlCharacters(text) or
                    std.mem.indexOf(u8, text, "--") != null or std.mem.endsWith(u8, text, "-"))) return error.InvalidStateError;
                try self.add("<!--");
                try self.add(text);
                try self.add("-->");
            },
            interfaces.Node.get_PROCESSING_INSTRUCTION_NODE() => {
                var target = try interfaces.ProcessingInstruction.get_target(value);
                defer target.deinit(value.ctx.allocator);
                if (!self.html and self.well_formed and (std.mem.indexOfScalar(u8, target.asSlice(), ':') != null or
                    std.ascii.eqlIgnoreCase(target.asSlice(), "xml") or !xmlCharacters(text) or
                    std.mem.indexOf(u8, text, "?>") != null)) return error.InvalidStateError;
                try self.add("<?");
                try self.add(target.asSlice());
                try self.add(" ");
                try self.add(text);
                try self.add("?>");
            },
            else => return error.TypeError,
        }
    }

    fn element(self: *Writer, value: *runtime.Instance, inherited: ?[]const u8) anyerror!void {
        var local = try interfaces.Element.get_localName(value);
        defer local.deinit(value.ctx.allocator);
        var ns_string = try interfaces.Element.get_namespaceURI(value);
        defer if (ns_string) |*s| s.deinit(value.ctx.allocator);
        var prefix_string = try interfaces.Element.get_prefix(value);
        defer if (prefix_string) |*s| s.deinit(value.ctx.allocator);
        const name = local.asSlice();
        const ns = optionalString(ns_string);
        var prefix = optionalString(prefix_string);
        var child_ns = inherited;
        const scope_start = self.bindings.items.len;
        defer self.bindings.items.len = scope_start;
        var default_ns: ?[]const u8 = null;
        var ignore_default = false;
        var declare: ?Binding = null;

        if (self.html) {
            // HTML fragment step 5.2: local names in HTML, SVG and MathML.
            if (same(ns, html_ns) or same(ns, svg_ns) or same(ns, math_ns)) prefix = null;
        } else {
            // XML element steps 1 and 6–8: a scoped prefix map, recording xmlns.
            if (self.well_formed and !xmlLocalName(name)) return error.InvalidStateError;
            var index: usize = 0;
            while (dom.element_attributes.at(value, index)) |attr| : (index += 1) {
                if (!same(attr.namespace, xmlns_ns)) continue;
                if (attr.prefix == null) {
                    default_ns = attr.value;
                    continue;
                }
                if (std.mem.eql(u8, attr.value, xml_ns)) continue;
                const attr_ns = nullable(attr.value);
                if (!self.found(attr.local_name, attr_ns))
                    try self.bindings.append(self.allocator, .{ .prefix = attr.local_name, .namespace = attr_ns });
            }
            // XML element steps 11–12: choose a prefix or a default declaration.
            if (same(inherited, ns)) {
                ignore_default = default_ns != null;
                prefix = if (same(ns, xml_ns)) "xml" else null;
            } else {
                var candidate = self.preferred(prefix, ns);
                if (same(prefix, "xmlns")) {
                    if (self.well_formed) return error.InvalidStateError;
                    candidate = prefix;
                }
                if (candidate) |p| {
                    prefix = p;
                    if (default_ns) |d| {
                        if (!std.mem.eql(u8, d, xml_ns)) child_ns = nullable(d);
                    }
                } else if (prefix) |p| {
                    if (self.localPrefix(scope_start, p) != null) prefix = try self.generatePrefix(ns);
                    try self.bindings.append(self.allocator, .{ .prefix = prefix.?, .namespace = ns });
                    declare = .{ .prefix = prefix.?, .namespace = ns };
                    if (default_ns) |d| child_ns = nullable(d);
                } else if (default_ns == null or !same(default_ns, ns)) {
                    ignore_default = true;
                    child_ns = ns;
                    declare = .{ .prefix = "", .namespace = ns };
                } else child_ns = ns;
            }
        }
        try self.add("<");
        try self.qualified(prefix, name);
        if (declare) |binding| try self.namespaceAttribute(binding);
        // HTML fragment step 5.2: the is value need not have an attribute.
        if (self.html) {
            if (dom.node_creation.elementIsValue(value)) |is_value| {
                var has_is = false;
                var attr_index: usize = 0;
                while (dom.element_attributes.at(value, attr_index)) |attr| : (attr_index += 1) {
                    if (attr.namespace == null and std.mem.eql(u8, attr.local_name, "is")) {
                        has_is = true;
                        break;
                    }
                }
                if (!has_is) try self.attribute(null, "is", is_value);
            }
        }
        var index: usize = 0;
        while (dom.element_attributes.at(value, index)) |attr| : (index += 1) {
            if (self.html) {
                const p: ?[]const u8 = if (attr.namespace == null) null else if (same(attr.namespace, xml_ns)) "xml" else if (same(attr.namespace, xmlns_ns)) (if (std.mem.eql(u8, attr.local_name, "xmlns")) null else "xmlns") else if (same(attr.namespace, xlink_ns)) "xlink" else attr.prefix;
                try self.attribute(p, attr.local_name, attr.value);
            } else try self.xmlAttribute(value, index, attr, scope_start, ignore_default);
        }
        // XML element steps 14–17; HTML void elements ignore all children.
        const empty = (try interfaces.Node.get_firstChild(value)) == null;
        if (!self.html and empty and (!same(ns, html_ns) or isVoid(name) or std.mem.eql(u8, name, "menuitem"))) {
            try self.add(if (same(ns, html_ns)) " />" else "/>");
            return;
        }
        try self.add(">");
        if (self.html and same(ns, html_ns) and isVoid(name)) return;
        try self.children(value, child_ns);
        try self.add("</");
        try self.qualified(prefix, name);
        try self.add(">");
    }

    fn found(self: *Writer, prefix: []const u8, namespace: ?[]const u8) bool {
        for (self.bindings.items) |binding|
            if (std.mem.eql(u8, binding.prefix, prefix) and same(binding.namespace, namespace)) return true;
        return false;
    }

    fn preferred(self: *Writer, prefix: ?[]const u8, namespace: ?[]const u8) ?[]const u8 {
        var result: ?[]const u8 = null;
        for (self.bindings.items) |binding| {
            if (!same(binding.namespace, namespace)) continue;
            if (same(prefix, binding.prefix)) return binding.prefix;
            result = binding.prefix;
        }
        return result;
    }

    fn localPrefix(self: *Writer, start: usize, prefix: []const u8) ?Binding {
        var index = self.bindings.items.len;
        while (index > start) {
            index -= 1;
            const binding = self.bindings.items[index];
            if (std.mem.eql(u8, binding.prefix, prefix)) return binding;
        }
        return null;
    }

    fn generatePrefix(self: *Writer, namespace: ?[]const u8) ![]const u8 {
        // DOM Parsing "generate a prefix", steps 1–4.
        const prefix = try std.fmt.allocPrint(self.allocator, "ns{d}", .{self.prefix_index});
        errdefer self.allocator.free(prefix);
        try self.generated.append(self.allocator, prefix);
        errdefer _ = self.generated.pop();
        self.prefix_index += 1;
        try self.bindings.append(self.allocator, .{ .prefix = prefix, .namespace = namespace });
        return prefix;
    }

    fn namespaceAttribute(self: *Writer, binding: Binding) !void {
        try self.attribute(if (binding.prefix.len == 0) null else "xmlns", if (binding.prefix.len == 0) "xmlns" else binding.prefix, binding.namespace orelse "");
    }

    fn xmlAttribute(self: *Writer, element_value: *runtime.Instance, index: usize, attr: dom.element_attributes.Attribute, start: usize, ignore_default: bool) !void {
        // XML attributes steps 3.1–3.4: uniqueness by (namespace, local name).
        if (self.well_formed) {
            for (0..index) |i| {
                const earlier = dom.element_attributes.at(element_value, i).?;
                if (same(earlier.namespace, attr.namespace) and std.mem.eql(u8, earlier.local_name, attr.local_name)) return error.InvalidStateError;
            }
        }
        var prefix: ?[]const u8 = null;
        if (attr.namespace) |ns| {
            prefix = self.preferred(attr.prefix, ns);
            if (std.mem.eql(u8, ns, xmlns_ns)) {
                // Steps 3.6.3: omit redundant declarations and reserved XML mappings.
                if (std.mem.eql(u8, attr.value, xml_ns) or (attr.prefix == null and ignore_default)) return;
                if (attr.prefix != null) {
                    const local = self.localPrefix(start, attr.local_name);
                    if ((local == null or !same(local.?.namespace, nullable(attr.value))) and self.found(attr.local_name, nullable(attr.value))) return;
                }
                if (self.well_formed and (std.mem.eql(u8, attr.value, xmlns_ns) or attr.value.len == 0)) return error.InvalidStateError;
                if (same(attr.prefix, "xmlns")) prefix = "xmlns";
            } else if (prefix == null) {
                prefix = if (attr.prefix != null and self.localPrefix(start, attr.prefix.?) == null) attr.prefix else try self.generatePrefix(ns);
                try self.bindings.append(self.allocator, .{ .prefix = prefix.?, .namespace = ns });
                try self.namespaceAttribute(.{ .prefix = prefix.?, .namespace = ns });
            }
        }
        // Step 3.9: XML names are stricter than DOM's contemporary name rules.
        if (self.well_formed and (!xmlLocalName(attr.local_name) or (attr.namespace == null and std.mem.eql(u8, attr.local_name, "xmlns")))) return error.InvalidStateError;
        try self.attribute(prefix, attr.local_name, attr.value);
    }

    fn doctype(self: *Writer, value: *runtime.Instance) !void {
        var name = try interfaces.DocumentType.get_name(value);
        defer name.deinit(value.ctx.allocator);
        try self.add("<!DOCTYPE ");
        try self.add(name.asSlice());
        if (!self.html) {
            var public = try interfaces.DocumentType.get_publicId(value);
            defer public.deinit(value.ctx.allocator);
            var system = try interfaces.DocumentType.get_systemId(value);
            defer system.deinit(value.ctx.allocator);
            const p = public.asSlice();
            const s = system.asSlice();
            if (self.well_formed) {
                for (p) |c| if (!std.ascii.isAlphanumeric(c) and std.mem.indexOfScalar(u8, " \r\n-'()+,./:=?;!*#@$_%", c) == null) return error.InvalidStateError;
                if (!xmlCharacters(s) or (std.mem.indexOfScalar(u8, s, '\'') != null and std.mem.indexOfScalar(u8, s, '"') != null)) return error.InvalidStateError;
            }
            if (p.len != 0) {
                try self.add(" PUBLIC ");
                try self.identifier(p);
            }
            if (s.len != 0) {
                try self.add(if (p.len == 0) " SYSTEM " else " ");
                try self.identifier(s);
            }
        }
        try self.add(">");
    }

    fn identifier(self: *Writer, text: []const u8) !void {
        const quote: []const u8 = if (std.mem.indexOfScalar(u8, text, '"') != null) "'" else "\"";
        try self.add(quote);
        try self.add(text);
        try self.add(quote);
    }
};

// XML 1.0 (Fifth Edition), productions Char, NameStartChar and NameChar.
fn xmlCharacters(text: []const u8) bool {
    const view = std.unicode.Utf8View.init(text) catch return false;
    var iterator = view.iterator();
    while (iterator.nextCodepoint()) |c| {
        if (!(c == 9 or c == 10 or c == 13 or (c >= 0x20 and c <= 0xd7ff) or
            (c >= 0xe000 and c <= 0xfffd) or c >= 0x10000)) return false;
    }
    return true;
}

fn xmlLocalName(text: []const u8) bool {
    const view = std.unicode.Utf8View.init(text) catch return false;
    var iterator = view.iterator();
    const first = iterator.nextCodepoint() orelse return false;
    if (!xmlNameStart(first)) return false;
    while (iterator.nextCodepoint()) |c| {
        if (!(xmlNameStart(c) or c == '-' or c == '.' or (c >= '0' and c <= '9') or
            c == 0xb7 or (c >= 0x300 and c <= 0x36f) or (c >= 0x203f and c <= 0x2040))) return false;
    }
    return true;
}

fn xmlNameStart(c: u21) bool {
    // Serialization forbids ':' in local names even though XML Name allows it.
    return (c >= 'A' and c <= 'Z') or c == '_' or (c >= 'a' and c <= 'z') or
        (c >= 0xc0 and c <= 0xd6) or (c >= 0xd8 and c <= 0xf6) or
        (c >= 0xf8 and c <= 0x2ff) or (c >= 0x370 and c <= 0x37d) or
        (c >= 0x37f and c <= 0x1fff) or (c >= 0x200c and c <= 0x200d) or
        (c >= 0x2070 and c <= 0x218f) or (c >= 0x2c00 and c <= 0x2fef) or
        (c >= 0x3001 and c <= 0xd7ff) or (c >= 0xf900 and c <= 0xfdcf) or
        (c >= 0xfdf0 and c <= 0xfffd) or (c >= 0x10000 and c <= 0xeffff);
}
