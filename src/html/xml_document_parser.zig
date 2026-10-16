//! HTML §14.2 "Parsing XML documents": the XML parser's tree builder.
//!
//! Spec: specs/whatwg/html.md §14.2; the XML itself is src/xml (XML 1.0
//! Fifth Edition, Namespaces in XML 1.0).
//!
//! `parseInto` runs the XML parser over a document's source and builds its
//! nodes into the Document it is given, as HTML §14.2 says an XML parser
//! does: elements made by "create an element" with the namespace and prefix
//! the source gives them (the equivalent of "create an element for a token"),
//! their attributes appended with theirs, each node made in the node
//! document of the node it is inserted into, and appended - not built aside
//! and attached - so insertion steps and mutation observers see each one.
//! A template's children go to its template contents.
//!
//! What happens on a well-formedness error is the caller's: DOMParser and a
//! navigation keep the tree built up to the error and insert the error
//! message block (`insertErrorMessageBlock`); XHR's document response
//! becomes null.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const xml = @import("xml");
const html_core = @import("html_core");
const engine = @import("engine");
const creation = @import("custom_elements/creation.zig");
const parser_ce = @import("custom_elements/parser.zig");
const script_execution = @import("script_execution.zig");

const html_namespace = "http://www.w3.org/1999/xhtml";
const svg_namespace = "http://www.w3.org/2000/svg";

pub const Options = struct {
    /// HTML §14.2 "XML scripting support". Disabled for DOMParser and for
    /// XHR's document response: every script element the parser makes is
    /// then inert - parser-inserted and already started, as every browser
    /// leaves it (domparsing/DOMParser-parseFromString-xml-scripting-support-
    /// disabled.html, xhr/responseXML-xml-scripting-support-disabled.html).
    scripting: bool = false,
    /// With scripting: the embedder's loader for the external classic
    /// scripts the parser prepares (as the HTML parser's; the WPT runner
    /// serves testharness.js through it).
    script_loader: ?script_execution.ParserScriptLoader = null,
};

/// A well-formedness error: where, and libxml2's words for what.
pub const Failure = struct {
    line: u32,
    column: u32,
    message_buffer: [256]u8 = undefined,
    message_len: usize = 0,

    pub fn message(self: *const Failure) []const u8 {
        return self.message_buffer[0..self.message_len];
    }

    fn from(failure: xml.Failure) Failure {
        var result: Failure = .{ .line = failure.position.line, .column = failure.position.column };
        const len = @min(failure.message.len, result.message_buffer.len);
        @memcpy(result.message_buffer[0..len], failure.message[0..len]);
        result.message_len = len;
        return result;
    }
};

/// Parse `source` (UTF-8) into `document`, which has no children yet.
/// Returns null when the source is a well-formed XML document, else its first
/// well-formedness or namespace well-formedness error - the nodes before it
/// built.
pub fn parseInto(document: *runtime.Instance, source: []const u8, options: Options) !?Failure {
    const allocator = document.ctx.allocator;
    var builder: Builder = .{ .allocator = allocator, .document = document, .options = options };
    defer builder.stack.deinit(allocator);
    var parser = xml.Parser.init(allocator, .{ .xhtml_entities = htmlNamedReference });
    defer parser.deinit();
    const failure = try parser.parse(source, &builder);
    return if (failure) |f| Failure.from(f) else null;
}

/// HTML §14.2: the named character references the XHTML DTDs declare - the
/// HTML ones - for a document whose doctype names one of them.
fn htmlNamedReference(name: []const u8) ?[]const u21 {
    var buffer: [64]u8 = undefined;
    if (name.len + 1 > buffer.len) return null;
    @memcpy(buffer[0..name.len], name);
    buffer[name.len] = ';';
    const key = buffer[0 .. name.len + 1];
    const table = html_core.parser.entities.entities;
    var low: usize = 0;
    var high: usize = table.len;
    while (low < high) {
        const mid = low + (high - low) / 2;
        switch (std.mem.order(u8, table[mid].name, key)) {
            .eq => return table[mid].codepoints,
            .lt => low = mid + 1,
            .gt => high = mid,
        }
    }
    return null;
}

const Open = struct {
    element: *runtime.Instance,
    /// An HTML or SVG script element, prepared at its end tag when the
    /// parser has XML scripting support.
    script: bool = false,
    /// Where its children go: the element, or a template's contents.
    target: *runtime.Instance,
    /// The node document its children are made in: the target's.
    document: *runtime.Instance,
};

/// The sink the XML parser reports to (src/xml/parser.zig's interface).
const Builder = struct {
    allocator: std.mem.Allocator,
    document: *runtime.Instance,
    options: Options,
    stack: std.ArrayList(Open) = .empty,

    fn parent(self: *const Builder) Open {
        if (self.stack.items.len == 0) return .{ .element = self.document, .target = self.document, .document = self.document };
        return self.stack.items[self.stack.items.len - 1];
    }

    /// Append `node`, which nothing else holds yet, to the current parent;
    /// when that fails, it is destroyed.
    fn insert(self: *Builder, node: *runtime.Instance) !void {
        _ = interfaces.Node.call_appendChild(self.parent().target, node) catch |err| {
            dom.node_creation.destroyUninserted(node);
            return err;
        };
    }

    pub fn doctype(self: *Builder, name: []const u8, public_id: []const u8, system_id: []const u8) !void {
        const node = try interfaces.DocumentType.init(self.allocator, self.document.ctx);
        dom.node_creation.setDoctypeIds(node, name, public_id, system_id);
        dom.node_document.set(node, self.document) catch |err| {
            dom.node_creation.destroyUninserted(node);
            return err;
        };
        try self.insert(node);
        dom.document_internals.setDoctype(self.document, node);
    }

    pub fn startElement(self: *Builder, name: xml.Name, attributes: []const xml.Attribute) !void {
        const at = self.parent();
        // "Create an element for a token", in XML's terms: the token's is
        // attribute (no namespace) is its is value.
        var is_value: ?[]const u8 = null;
        for (attributes) |attr| {
            if (attr.name.namespace == null and std.mem.eql(u8, attr.name.local, "is")) is_value = attr.value;
        }
        const scope = try parser_ce.Scope.begin(at.document, name.local, name.namespace, is_value, false);
        defer scope.end();
        const element = try creation.create(.{
            .document = at.document,
            .local_name = name.local,
            .namespace = name.namespace,
            .prefix = name.prefix,
            .is_value = is_value,
            .synchronous = scope.synchronous,
        });
        const script = isScript(name);
        if (script) {
            // HTML §14.2: "When an XML parser with XML scripting support
            // enabled creates a script element, it must have its parser
            // document set and its force async set to false."
            dom.script_elements.markParserInserted(element, at.document);
            // XML scripting support disabled: the parser's script elements
            // never run, wherever they are later inserted, adopted or
            // cloned to.
            if (!self.options.scripting) dom.script_elements.markAlreadyStarted(element);
        }
        for (attributes) |attr| {
            dom.element_attributes.append(element, .{
                .namespace = attr.name.namespace,
                .prefix = attr.name.prefix,
                .local_name = attr.name.local,
                .value = attr.value,
            }) catch |err| {
                dom.node_creation.destroyUninserted(element);
                return err;
            };
        }
        try self.insert(element);
        const target = try dom.template_contents.insertionTarget(element);
        const children_document = if (target != element)
            (try interfaces.Node.get_ownerDocument(target)) orelse at.document
        else
            at.document;
        try self.stack.append(self.allocator, .{ .element = element, .script = script and self.options.scripting, .target = target, .document = children_document });
    }

    pub fn endElement(self: *Builder, _: xml.Name) !void {
        const open = self.stack.pop().?;
        if (open.script) try self.runScript(open.element);
    }

    /// HTML §14.2, a script element's end tag with XML scripting support:
    /// "the user agent must perform a microtask checkpoint, and then prepare
    /// the script element. If this causes there to be a pending
    /// parsing-blocking script", block the parser until it is ready, then
    /// execute it. The embedder's loader answers an external script at its
    /// fetch step, so a parsing-blocking script is ready here or never.
    fn runScript(self: *Builder, element: *runtime.Instance) !void {
        const document = self.document;
        // Trusted Types 4.1.2.6: the script text is its child text content.
        try dom.script_elements.setScriptTextToChildTextContent(self.allocator, element);
        if (isSvgElement(element)) {
            script_execution.processSvgScriptElement(self.allocator, element);
            return;
        }
        const realm = document.ctx;
        if (realm.agent) |agent| {
            if (realm.hasEngine() and !engine.hasRunningScript(agent)) engine.performMicrotaskCheckpoint(agent) catch {};
        }
        _ = script_execution.prepareScriptElementWithLoader(self.allocator, element, self.options.script_loader) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => {},
        };
        while (script_execution.pendingParsingBlockingScript(document) != null) {
            if (!script_execution.executePendingParserBlockingScript(self.allocator, document)) break;
        }
    }

    pub fn text(self: *Builder, data: []const u8) !void {
        const node = try interfaces.Document.call_createTextNode(self.parent().document, runtime.DOMString.initInterned(data));
        try self.insert(node);
    }

    pub fn cdata(self: *Builder, data: []const u8) !void {
        const node = try interfaces.Document.call_createCDATASection(self.parent().document, runtime.DOMString.initInterned(data));
        try self.insert(node);
    }

    pub fn comment(self: *Builder, data: []const u8) !void {
        const node = try interfaces.Document.call_createComment(self.parent().document, runtime.DOMString.initInterned(data));
        try self.insert(node);
    }

    pub fn processingInstruction(self: *Builder, target: []const u8, data: []const u8) !void {
        const node = try interfaces.Document.call_createProcessingInstruction(self.parent().document, runtime.DOMString.initInterned(target), runtime.DOMString.initInterned(data));
        try self.insert(node);
    }
};

fn isSvgElement(element: *runtime.Instance) bool {
    var ns = (interfaces.Element.get_namespaceURI(element) catch return false) orelse return false;
    defer ns.deinit(element.ctx.allocator);
    return std.mem.eql(u8, ns.asSlice(), svg_namespace);
}

/// An HTML script element or an SVG one.
fn isScript(name: xml.Name) bool {
    const ns = name.namespace orelse return false;
    if (!std.mem.eql(u8, name.local, "script")) return false;
    return std.mem.eql(u8, ns, html_namespace) or std.mem.eql(u8, ns, svg_namespace);
}

// ---------------------------------------------------------------------------
// HTML §14.4 "Parsing XML fragments"

/// The XML fragment parsing algorithm given the element `context` and the
/// string `input`: a DocumentFragment in context's node document holding
/// what `input` parses to inside context's start and end tags, with the
/// namespace prefixes and default namespace in scope on context declared.
/// A well-formedness error is a "SyntaxError" DOMException (step 7).
pub fn parseFragment(context: *runtime.Instance, input: []const u8) !*runtime.Instance {
    const allocator = context.ctx.allocator;
    var markup: std.ArrayList(u8) = .empty;
    defer markup.deinit(allocator);
    // Step 4: context's start tag, declaring every namespace prefix in scope
    // on it in the DOM, and the default namespace.
    var qualified = try interfaces.Element.get_localName(context);
    defer qualified.deinit(allocator);
    var prefix = try interfaces.Element.get_prefix(context);
    defer if (prefix) |*p| p.deinit(allocator);
    try markup.append(allocator, '<');
    if (prefix) |p| try markup.print(allocator, "{s}:", .{p.asSlice()});
    try markup.appendSlice(allocator, qualified.asSlice());
    var scope = try namespacesInScope(allocator, context);
    defer scope.deinit(allocator);
    for (scope.items) |binding| {
        const uri = binding.uri orelse continue;
        if (binding.prefix) |p| {
            try markup.print(allocator, " xmlns:{s}=\"", .{p});
        } else try markup.appendSlice(allocator, " xmlns=\"");
        try appendEscaped(&markup, allocator, uri);
        try markup.append(allocator, '"');
    }
    try markup.append(allocator, '>');
    // Step 5: input.
    try markup.appendSlice(allocator, input);
    // Step 6: context's end tag.
    try markup.appendSlice(allocator, "</");
    if (prefix) |p| try markup.print(allocator, "{s}:", .{p.asSlice()});
    try markup.appendSlice(allocator, qualified.asSlice());
    try markup.append(allocator, '>');

    // Step 3: a new XML parser, with a document of its own. Its script
    // elements are already started (HTML §14.2: "If the parser was created as
    // part of the XML fragment parsing algorithm").
    const document = try interfaces.Document.init(allocator, context.ctx);
    defer dom.node_creation.destroyUninserted(document);
    try dom.document_internals.setDocumentType(document, .xml);
    // Step 7: a well-formedness or namespace well-formedness error.
    if (try parseInto(document, markup.items, .{ .scripting = false }) != null) return error.SyntaxError;
    // Step 8 holds by construction: input sits inside the root's tags.
    const root = (try interfaces.Document.get_documentElement(document)) orelse return error.SyntaxError;
    // Steps 10-12: a fragment in context's node document, and newChildren -
    // the root's children - appended to it in tree order.
    const owner = (try interfaces.Node.get_ownerDocument(context)) orelse return error.InvalidStateError;
    const fragment = try interfaces.Document.call_createDocumentFragment(owner);
    errdefer dom.node_creation.destroyUninserted(fragment);
    while (try interfaces.Node.get_firstChild(root)) |child| {
        _ = try interfaces.Node.call_appendChild(fragment, child);
    }
    // The elements take the context's custom element registry, as the HTML
    // fragment parser's create-for-token step 6 gives them the intended
    // parent's. Browser behaviour where the XML text is silent: WebKit's
    // XMLDocumentParser parses straight into the context's fragment, and
    // Chrome 154 and Safari 27 pass
    // custom-elements/registries/scoped-registry-initialize.html 27/27
    // (wpt.fyi). Building in a document of our own and adopting would leave a
    // scoped registry's elements with none (DOM adopt sets the effective
    // global registry, null for a scoped one).
    if (try interfaces.Element.get_customElementRegistry(context)) |registry| {
        try assignRegistry(fragment, registry);
    }
    return fragment;
}

/// Give every element under `root` (not template contents, which are inert
/// and look up no registry) `registry`. Iterative preorder: a deeply nested
/// fragment costs no native stack.
fn assignRegistry(root: *runtime.Instance, registry: *runtime.Instance) !void {
    var cursor = try interfaces.Node.get_firstChild(root);
    while (cursor) |current| {
        if (current.stateAs(interfaces.Element.State) != null) {
            try dom.custom_elements.setElementRegistry(current, registry);
        }
        if (try interfaces.Node.get_firstChild(current)) |first| {
            cursor = first;
            continue;
        }
        var node = current;
        cursor = null;
        while (node != root) {
            if (try interfaces.Node.get_nextSibling(node)) |next| {
                cursor = next;
                break;
            }
            node = (try interfaces.Node.get_parentNode(node)) orelse break;
        }
    }
}

const ScopeBinding = struct { prefix: ?[]const u8, uri: ?[]const u8 };

/// The namespace prefixes, and the default namespace, DOM's "locate a
/// namespace" finds for `element`: from the element out through its
/// ancestors, the nearest declaration of each - an element's own prefix and
/// namespace, or its xmlns attributes. Borrowed from the elements.
fn namespacesInScope(allocator: std.mem.Allocator, element: *runtime.Instance) !std.ArrayList(ScopeBinding) {
    var bindings: std.ArrayList(ScopeBinding) = .empty;
    errdefer bindings.deinit(allocator);
    var current: ?*runtime.Instance = element;
    while (current) |node| : (current = try interfaces.Node.get_parentElement(node)) {
        if (dom.node_creation.elementNames(node)) |names| {
            if (names.namespace) |ns| try bind(&bindings, allocator, elementPrefix(node), ns);
        }
        var i: usize = 0;
        while (dom.element_attributes.at(node, i)) |attr| : (i += 1) {
            const ns = attr.namespace orelse continue;
            if (!std.mem.eql(u8, ns, xml.xmlns_namespace)) continue;
            if (attr.prefix) |p| {
                if (std.mem.eql(u8, p, "xmlns")) try bind(&bindings, allocator, attr.local_name, if (attr.value.len == 0) null else attr.value);
            } else if (std.mem.eql(u8, attr.local_name, "xmlns")) {
                try bind(&bindings, allocator, null, if (attr.value.len == 0) null else attr.value);
            }
        }
    }
    return bindings;
}

fn elementPrefix(element: *runtime.Instance) ?[]const u8 {
    const names = dom.node_creation.elementNames(element) orelse return null;
    return names.prefix;
}

/// Record `prefix` -> `uri` unless a nearer element bound `prefix` already.
/// The xml and xmlns prefixes are never declared.
fn bind(bindings: *std.ArrayList(ScopeBinding), allocator: std.mem.Allocator, prefix: ?[]const u8, uri: ?[]const u8) !void {
    if (prefix) |p| if (std.mem.eql(u8, p, "xml") or std.mem.eql(u8, p, "xmlns")) return;
    for (bindings.items) |existing| {
        if (existing.prefix == null and prefix == null) return;
        if (existing.prefix != null and prefix != null and std.mem.eql(u8, existing.prefix.?, prefix.?)) return;
    }
    try bindings.append(allocator, .{ .prefix = prefix, .uri = uri });
}

/// `value` as attribute value text: '&', '<' and '"' escaped.
fn appendEscaped(out: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void {
    for (value) |b| switch (b) {
        '&' => try out.appendSlice(allocator, "&amp;"),
        '<' => try out.appendSlice(allocator, "&lt;"),
        '"' => try out.appendSlice(allocator, "&quot;"),
        else => try out.append(allocator, b),
    };
}

// ---------------------------------------------------------------------------
// Bytes to characters

const sniffing = html_core.parser.encoding_sniffing;

pub const Decoded = struct {
    /// The document's characters, UTF-8, owned by the caller's allocator.
    text: []u8,
    /// The encoding they were decoded from: the document's encoding.
    encoding: sniffing.Encoding,
};

/// An XML document's bytes as characters. The encoding is, in the order
/// browsers take them (HTML §7.5.3 "the actual HTTP headers ... are the ones
/// that must be used when determining the character encoding according to
/// the rules given in the above specifications"; RFC 7303 §3; XML Appendix
/// F): a byte order mark; the transport's charset (`transport`); UTF-16
/// detected from "<?" with no mark; the XML declaration's encoding; else
/// UTF-8. Null where the declaration names an encoding there is none of -
/// libxml2's fatal "Unsupported encoding", a parse that fails.
pub fn decodeBytes(allocator: std.mem.Allocator, bytes: []const u8, transport: ?sniffing.Encoding) !?Decoded {
    const encoding = chooseEncoding(bytes, transport) orelse return null;
    return .{ .text = try sniffing.decode(allocator, bytes, encoding), .encoding = encoding };
}

fn chooseEncoding(bytes: []const u8, transport: ?sniffing.Encoding) ?sniffing.Encoding {
    // Encoding's BOM sniff.
    if (std.mem.startsWith(u8, bytes, "\xEF\xBB\xBF")) return sniffing.utf_8;
    if (std.mem.startsWith(u8, bytes, "\xFE\xFF")) return sniffing.lookup("utf-16be").?;
    if (std.mem.startsWith(u8, bytes, "\xFF\xFE")) return sniffing.lookup("utf-16le").?;
    if (transport) |chosen| return chosen;
    // XML Appendix F.1: "<?" in UTF-16 with no byte order mark.
    if (std.mem.startsWith(u8, bytes, "\x3C\x00\x3F\x00")) return sniffing.lookup("utf-16le").?;
    if (std.mem.startsWith(u8, bytes, "\x00\x3C\x00\x3F")) return sniffing.lookup("utf-16be").?;
    const label = xml.declaredEncoding(bytes) orelse return sniffing.utf_8;
    const declared = sniffing.lookup(label) orelse return null;
    // A declaration read as ASCII is not in UTF-16, whatever it says (as
    // HTML's prescan treats one).
    if (declared == sniffing.lookup("utf-16le").? or declared == sniffing.lookup("utf-16be").?) return sniffing.utf_8;
    return declared;
}

// ---------------------------------------------------------------------------
// The error document

/// The error message block Chrome and Safari put in a document whose XML
/// is not well-formed, where the tree built up to the error stays.
///
/// Golden rule 2, a 2-1 split: HTML's DOMParser.parseFromString step 4 (and
/// Firefox) make a document holding only `<parsererror xmlns=
/// "http://www.mozilla.org/newlayout/xml/parsererror.xml">`. Chrome and
/// Safari keep the partial tree and insert this XHTML block as the document
/// element's first child; with no document element they make html and body
/// to hold it, and an SVG root moves into such a body after it (WebKit
/// Source/WebCore/xml/XMLErrors.cpp and Blink
/// third_party/blink/renderer/core/xml/parser/xml_errors.cc,
/// XMLErrors::insertErrorMessageBlock; createXHTMLParserErrorHeader).
/// wpt.fyi (cc74d2669f): Chrome and Safari fail, as Crane does, the four
/// "Should return an error document ..." subtests of
/// domparsing/DOMParser-parseFromString-xml.html and the four of
/// domparsing/DOMParser-xml-character-entities.html, which assert the spec's
/// shape; all three pass DOMParser-parseFromString-xml-parsererror.html.
pub fn insertErrorMessageBlock(document: *runtime.Instance, failure: Failure) !void {
    var holder = try interfaces.Document.get_documentElement(document);
    if (holder == null) {
        const root = try makeHtml(document, "html");
        try append(document, root);
        const body = try makeHtml(document, "body");
        try append(root, body);
        holder = body;
    } else if (try isSvgRoot(holder.?)) {
        const svg = holder.?;
        const root = try makeHtml(document, "html");
        const head = try makeHtml(document, "head");
        try append(root, head);
        const style = try makeHtml(document, "style");
        try append(head, style);
        try appendText(style, "html, body { height: 100% } parsererror + svg { width: 100%; height: 100% }");
        const body = try makeHtml(document, "body");
        try append(root, body);
        _ = try interfaces.Node.call_removeChild(document, svg);
        try append(body, svg);
        try append(document, root);
        holder = body;
    }

    // createXHTMLParserErrorHeader.
    const report = try makeHtml(document, "parsererror");
    errdefer dom.node_creation.destroyUninserted(report);
    try setStyle(report, "display: block; white-space: pre; border: 2px solid #c77; padding: 0 1em 0 1em; margin: 1em; background-color: #fdd; color: black");
    const heading = try makeHtml(document, "h3");
    try append(report, heading);
    try appendText(heading, "This page contains the following errors:");
    const fixed = try makeHtml(document, "div");
    try setStyle(fixed, "font-family:monospace;font-size:12px");
    try append(report, fixed);
    // XMLErrors::appendErrorMessage: "<type> on line <L> at column <C>:
    // <message>", libxml2's message ending in a newline.
    var buffer: [512]u8 = undefined;
    const line = std.fmt.bufPrint(&buffer, "error on line {d} at column {d}: {s}\n", .{ failure.line, failure.column, failure.message() }) catch &buffer;
    try appendText(fixed, line);
    const trailer = try makeHtml(document, "h3");
    try append(report, trailer);
    try appendText(trailer, "Below is a rendering of the page up to the first error.");

    const first = try interfaces.Node.get_firstChild(holder.?);
    _ = try interfaces.Node.call_insertBefore(holder.?, report, first);
}

fn makeHtml(document: *runtime.Instance, local_name: []const u8) !*runtime.Instance {
    return creation.create(.{ .document = document, .local_name = local_name, .namespace = html_namespace });
}

fn append(parent_node: *runtime.Instance, child: *runtime.Instance) !void {
    _ = interfaces.Node.call_appendChild(parent_node, child) catch |err| {
        if (try interfaces.Node.get_parentNode(child) == null) dom.node_creation.destroyUninserted(child);
        return err;
    };
}

fn appendText(parent_node: *runtime.Instance, data: []const u8) !void {
    const document = (try interfaces.Node.get_ownerDocument(parent_node)).?;
    const node = try interfaces.Document.call_createTextNode(document, runtime.DOMString.initInterned(data));
    try append(parent_node, node);
}

fn setStyle(element: *runtime.Instance, value: []const u8) !void {
    try dom.element_attributes.append(element, .{ .namespace = null, .prefix = null, .local_name = "style", .value = value });
}

fn isSvgRoot(element: *runtime.Instance) !bool {
    var ns = (try interfaces.Element.get_namespaceURI(element)) orelse return false;
    defer ns.deinit(element.ctx.allocator);
    return std.mem.eql(u8, ns.asSlice(), svg_namespace);
}
