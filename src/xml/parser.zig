//! An XML 1.0 (Fifth Edition) parser with Namespaces in XML 1.0 (Third
//! Edition) processing, for the HTML Standard's "XML parser" (HTML §14.2).
//!
//! Specs: specs/w3c/REC-xml.md, specs/w3c/xml-names.md, and HTML §14.2
//! "Parsing XML documents" (specs/whatwg/html.md).
//!
//! The parser is non-validating and engine-free. It reads a whole document
//! (UTF-8; decoding is the caller's) and reports what it finds to a sink -
//! the XML tree builder - as the document's events in order: the XML
//! declaration, the doctype, each start and end tag with its namespaced
//! name and attributes, character data (adjacent runs, including the
//! replacement text of references, reported as one), CDATA sections,
//! comments and processing instructions. The first well-formedness or
//! namespace well-formedness error stops it, as it stops every browser's
//! parser (libxml2 in Chrome and Safari, expat in Firefox): `parse` then
//! returns the error, and the sink has seen everything before it.
//!
//! The document type declaration's internal subset is read for what a
//! non-validating processor must read (XML §5.1): general and parameter
//! entity declarations, with internal parameter entities expanded between
//! declarations. Element, attribute-list and notation declarations are
//! skipped. External entities are never fetched (HTML §14.2: user agents
//! "should not attempt to retrieve any other external entity's content"),
//! so a reference to an external parsed entity expands to nothing. For a
//! doctype whose public identifier is one of HTML §14.2's list, the HTML
//! named character references resolve through `Options.xhtml_entities` -
//! what that list's DTD declares, and what WebKit and Blink do
//! (XMLDocumentParser::getEntity, externalSubsetHandler).
//!
//! The sink is any pointer to a struct with these methods, each optional
//! and each returning an error union whose error stops the parse and is
//! returned from `parse`. Slices passed to them are valid only during the
//! call.
//!
//!   xmlDeclaration(XmlDeclaration)
//!   doctype(name, public_id, system_id)  ("" for an absent identifier)
//!   startElement(Name, []const Attribute)
//!   endElement(Name)
//!   text(data)
//!   cdata(data)
//!   comment(data)
//!   processingInstruction(target, data)

const std = @import("std");
const chars = @import("chars.zig");
const Allocator = std.mem.Allocator;

/// The XML namespace, bound to the prefix `xml` (Namespaces in XML §3).
pub const xml_namespace = "http://www.w3.org/XML/1998/namespace";
/// The namespace of namespace declarations (Namespaces in XML §3).
pub const xmlns_namespace = "http://www.w3.org/2000/xmlns/";

pub const Options = struct {
    /// The HTML named character references (without the ';'), for a
    /// document whose doctype's public identifier is one of HTML §14.2's
    /// list. Null resolves none of them.
    xhtml_entities: ?*const fn (name: []const u8) ?[]const u21 = null,
    /// The most bytes of entity replacement text one parse may expand;
    /// null is 10 MiB plus five times the input's length (libxml2's
    /// amplification limit has the same shape).
    max_entity_expansion: ?usize = null,
};

/// A namespaced name. `qualified` is the name as written.
pub const Name = struct {
    qualified: []const u8,
    prefix: ?[]const u8,
    local: []const u8,
    namespace: ?[]const u8,
};

pub const Attribute = struct {
    name: Name,
    /// The normalized value (XML §3.3.3), references replaced.
    value: []const u8,
};

pub const XmlDeclaration = struct {
    version: []const u8,
    encoding: ?[]const u8,
    standalone: ?bool,
};

/// A position in the document: 1-based line, and 1-based column in code points.
pub const Position = struct { line: u32, column: u32 };

pub const Failure = struct {
    position: Position,
    /// Valid until the next parse or `deinit`.
    message: []const u8,
};

/// HTML §14.2: the public identifiers whose DTD declares the HTML named
/// character references.
const xhtml_public_ids = [_][]const u8{
    "-//W3C//DTD XHTML 1.0 Transitional//EN",
    "-//W3C//DTD XHTML 1.1//EN",
    "-//W3C//DTD XHTML 1.0 Strict//EN",
    "-//W3C//DTD XHTML 1.0 Frameset//EN",
    "-//W3C//DTD XHTML Basic 1.0//EN",
    "-//W3C//DTD XHTML 1.1 plus MathML 2.0//EN",
    "-//W3C//DTD XHTML 1.1 plus MathML 2.0 plus SVG 1.1//EN",
    "-//W3C//DTD MathML 2.0//EN",
    "-//WAPFORUM//DTD XHTML Mobile 1.0//EN",
    "-//WAPFORUM//DTD XHTML Mobile 1.1//EN",
    "-//WAPFORUM//DTD XHTML Mobile 1.2//EN",
};

/// libxml2's limit on nested entity references.
const max_entity_depth = 40;

const Entity = struct {
    kind: enum { internal, external, unparsed },
    /// The replacement text of an internal entity.
    value: []const u8 = "",
    in_use: bool = false,
};

const Cursor = struct {
    text: []const u8,
    pos: usize = 0,

    fn eof(self: *const Cursor) bool {
        return self.pos >= self.text.len;
    }

    fn rest(self: *const Cursor) []const u8 {
        return self.text[self.pos..];
    }

    fn startsWith(self: *const Cursor, prefix: []const u8) bool {
        return std.mem.startsWith(u8, self.rest(), prefix);
    }

    fn peek(self: *const Cursor) ?u8 {
        return if (self.pos < self.text.len) self.text[self.pos] else null;
    }

    /// Skip [3] S; whether there was any.
    fn skipSpace(self: *Cursor) bool {
        const start = self.pos;
        while (self.pos < self.text.len and isSpaceByte(self.text[self.pos])) self.pos += 1;
        return self.pos != start;
    }

    /// A [5] Name at the cursor, or null (the cursor unmoved).
    fn name(self: *Cursor) ?[]const u8 {
        const start = self.pos;
        var i = self.pos;
        while (i < self.text.len) {
            const d = chars.decodeAt(self.text, i) orelse break;
            const ok = if (i == start) chars.isNameStartChar(d.c) else chars.isNameChar(d.c);
            if (!ok) break;
            i += d.len;
        }
        if (i == start) return null;
        self.pos = i;
        return self.text[start..i];
    }
};

const Frame = struct {
    cursor: Cursor,
    /// The entity whose replacement text this is; null for the document.
    entity: ?*Entity = null,
    /// How many elements were open when the entity's reference was met:
    /// its content must close exactly those it opens.
    depth: usize = 0,
};

const OpenElement = struct {
    name: Name,
    line: u32,
    /// The namespace bindings in scope before this element's own.
    bindings_mark: usize,
};

const Binding = struct {
    /// Null for the default namespace.
    prefix: ?[]const u8,
    /// Null where `xmlns=""` undeclares the default namespace.
    uri: ?[]const u8,
};

const RawAttribute = struct {
    qualified: []const u8,
    value_start: usize,
    value_end: usize,
};

const WellFormedness = error{WellFormedness};

pub const Parser = struct {
    allocator: Allocator,
    options: Options,
    /// Names, entity values and namespace URIs that outlive one tag.
    arena: std.heap.ArenaAllocator,
    normalized: std.ArrayList(u8) = .empty,
    frames: std.ArrayList(Frame) = .empty,
    elements: std.ArrayList(OpenElement) = .empty,
    bindings: std.ArrayList(Binding) = .empty,
    text_buffer: std.ArrayList(u8) = .empty,
    values: std.ArrayList(u8) = .empty,
    raw_attributes: std.ArrayList(RawAttribute) = .empty,
    attributes: std.ArrayList(Attribute) = .empty,
    entities: std.StringHashMapUnmanaged(Entity) = .empty,
    parameter_entities: std.StringHashMapUnmanaged(Entity) = .empty,
    uris: std.StringHashMapUnmanaged(void) = .empty,
    message: std.ArrayList(u8) = .empty,
    failure_offset: usize = 0,
    expanded: usize = 0,
    expansion_limit: usize = 0,
    /// The doctype's public identifier names an XHTML DTD (HTML §14.2).
    xhtml: bool = false,
    /// A parameter entity reference was not read: later declarations are
    /// not processed (XML §5.1).
    skip_declarations: bool = false,
    seen_doctype: bool = false,
    line_offset: usize = 0,
    line_count: u32 = 1,

    pub fn init(allocator: Allocator, options: Options) Parser {
        return .{ .allocator = allocator, .options = options, .arena = std.heap.ArenaAllocator.init(allocator) };
    }

    pub fn deinit(self: *Parser) void {
        const a = self.allocator;
        self.normalized.deinit(a);
        self.frames.deinit(a);
        self.elements.deinit(a);
        self.bindings.deinit(a);
        self.text_buffer.deinit(a);
        self.values.deinit(a);
        self.raw_attributes.deinit(a);
        self.attributes.deinit(a);
        self.entities.deinit(a);
        self.parameter_entities.deinit(a);
        self.uris.deinit(a);
        self.message.deinit(a);
        self.arena.deinit();
    }

    fn reset(self: *Parser) void {
        self.normalized.clearRetainingCapacity();
        self.frames.clearRetainingCapacity();
        self.elements.clearRetainingCapacity();
        self.bindings.clearRetainingCapacity();
        self.text_buffer.clearRetainingCapacity();
        self.entities.clearRetainingCapacity();
        self.parameter_entities.clearRetainingCapacity();
        self.uris.clearRetainingCapacity();
        self.message.clearRetainingCapacity();
        _ = self.arena.reset(.retain_capacity);
        self.expanded = 0;
        self.xhtml = false;
        self.skip_declarations = false;
        self.seen_doctype = false;
        self.line_offset = 0;
        self.line_count = 1;
    }

    /// Parse the document `input` (UTF-8), reporting it to `sink`. Returns
    /// null for a well-formed document, or its first error. An error the
    /// sink returns, or running out of memory, is returned as an error.
    pub fn parse(self: *Parser, input: []const u8, sink: anytype) anyerror!?Failure {
        self.reset();
        // XML §2.11: every CR LF pair and every CR not followed by LF is
        // passed on as one LF.
        var text = input;
        if (std.mem.indexOfScalar(u8, input, '\r') != null) {
            try self.normalized.ensureTotalCapacity(self.allocator, input.len);
            var i: usize = 0;
            while (i < input.len) : (i += 1) {
                if (input[i] == '\r') {
                    self.normalized.appendAssumeCapacity('\n');
                    if (i + 1 < input.len and input[i + 1] == '\n') i += 1;
                } else self.normalized.appendAssumeCapacity(input[i]);
            }
            text = self.normalized.items;
        }
        self.expansion_limit = self.options.max_entity_expansion orelse (10 * 1024 * 1024 + 5 * text.len);
        try self.frames.append(self.allocator, .{ .cursor = .{ .text = text } });
        self.document(sink) catch |err| switch (err) {
            error.WellFormedness => return .{ .position = self.position(self.failure_offset), .message = self.message.items },
            else => return err,
        };
        return null;
    }

    // ------------------------------------------------------------------
    // Errors

    fn fail(self: *Parser, comptime fmt: []const u8, args: anytype) anyerror {
        self.failure_offset = self.frames.items[0].cursor.pos;
        self.message.clearRetainingCapacity();
        self.message.print(self.allocator, fmt, args) catch |err| return err;
        return error.WellFormedness;
    }

    fn position(self: *const Parser, offset: usize) Position {
        const text = self.frames.items[0].cursor.text;
        const end = @min(offset, text.len);
        var line: u32 = 1;
        var line_start: usize = 0;
        for (text[0..end], 0..) |b, i| if (b == '\n') {
            line += 1;
            line_start = i + 1;
        };
        var column: u32 = 1;
        for (text[line_start..end]) |b| {
            if (b & 0xC0 != 0x80) column += 1;
        }
        return .{ .line = line, .column = column };
    }

    /// The line of the document cursor, counted on from the last call (the
    /// cursor only moves forward), so naming each element's line is linear.
    fn lineAt(self: *Parser) u32 {
        const cur = self.frames.items[0].cursor;
        if (cur.pos < self.line_offset) {
            self.line_offset = 0;
            self.line_count = 1;
        }
        self.line_count += @intCast(std.mem.count(u8, cur.text[self.line_offset..cur.pos], "\n"));
        self.line_offset = cur.pos;
        return self.line_count;
    }

    fn top(self: *Parser) *Cursor {
        return &self.frames.items[self.frames.items.len - 1].cursor;
    }

    fn doc(self: *Parser) *Cursor {
        return &self.frames.items[0].cursor;
    }

    // ------------------------------------------------------------------
    // [1] document ::= prolog element Misc*

    fn document(self: *Parser, sink: anytype) anyerror!void {
        const cur = self.doc();
        // A byte order mark is not part of the document.
        if (cur.startsWith("\xEF\xBB\xBF")) cur.pos = 3;
        // [23] XMLDecl, only at the very start.
        if (cur.startsWith("<?xml") and cur.text.len > cur.pos + 5 and isSpaceByte(cur.text[cur.pos + 5])) {
            try self.xmlDeclaration(sink);
        }
        // [22] prolog ::= XMLDecl? Misc* (doctypedecl Misc*)?
        while (true) {
            _ = cur.skipSpace();
            if (cur.eof()) return self.fail("Document is empty", .{});
            if (cur.startsWith("<!--")) {
                try self.comment(sink);
            } else if (cur.startsWith("<?")) {
                try self.processingInstruction(sink);
            } else if (cur.startsWith("<!DOCTYPE")) {
                if (self.seen_doctype) return self.fail("Extra content at the end of the document", .{});
                try self.doctype(sink);
            } else if (cur.peek() == '<') {
                break;
            } else {
                return self.fail("Start tag expected, '<' not found", .{});
            }
        }
        try self.content(sink);
        // Misc* after the root element. (Entity frames may have moved the
        // frame list: take the document's cursor afresh.)
        const after = self.doc();
        while (true) {
            _ = after.skipSpace();
            if (after.eof()) return;
            if (after.startsWith("<!--")) {
                try self.comment(sink);
            } else if (after.startsWith("<?")) {
                try self.processingInstruction(sink);
            } else {
                return self.fail("Extra content at the end of the document", .{});
            }
        }
    }

    // ------------------------------------------------------------------
    // [23] XMLDecl ::= '<?xml' VersionInfo EncodingDecl? SDDecl? S? '?>'

    fn xmlDeclaration(self: *Parser, sink: anytype) anyerror!void {
        const cur = self.doc();
        cur.pos += 5;
        _ = cur.skipSpace();
        var decl: XmlDeclaration = .{ .version = "", .encoding = null, .standalone = null };
        if (!cur.startsWith("version")) return self.fail("Malformed declaration expecting version", .{});
        cur.pos += "version".len;
        decl.version = try self.pseudoAttributeValue(cur);
        // [26] VersionNum ::= '1.' [0-9]+
        if (decl.version.len < 3 or !std.mem.startsWith(u8, decl.version, "1.") or !allDigits(decl.version[2..])) {
            return self.fail("Unsupported version '{s}'", .{decl.version});
        }
        var seen_encoding = false;
        while (true) {
            const spaced = cur.skipSpace();
            if (cur.startsWith("?>")) {
                cur.pos += 2;
                break;
            }
            if (!spaced) return self.fail("parsing XML declaration: '?>' expected", .{});
            if (!seen_encoding and decl.standalone == null and cur.startsWith("encoding")) {
                cur.pos += "encoding".len;
                const value = try self.pseudoAttributeValue(cur);
                if (!isEncName(value)) return self.fail("Invalid XML encoding name", .{});
                decl.encoding = value;
                seen_encoding = true;
            } else if (decl.standalone == null and cur.startsWith("standalone")) {
                cur.pos += "standalone".len;
                const value = try self.pseudoAttributeValue(cur);
                if (std.mem.eql(u8, value, "yes")) {
                    decl.standalone = true;
                } else if (std.mem.eql(u8, value, "no")) {
                    decl.standalone = false;
                } else return self.fail("standalone accepts only 'yes' or 'no'", .{});
            } else return self.fail("parsing XML declaration: '?>' expected", .{});
        }
        const Sink = @typeInfo(@TypeOf(sink)).pointer.child;
        if (@hasDecl(Sink, "xmlDeclaration")) try sink.xmlDeclaration(decl);
    }

    /// [25] Eq, then a quoted value with no references.
    fn pseudoAttributeValue(self: *Parser, cur: *Cursor) anyerror![]const u8 {
        _ = cur.skipSpace();
        if (cur.peek() != '=') return self.fail("Malformed declaration: '=' expected", .{});
        cur.pos += 1;
        _ = cur.skipSpace();
        const quote = cur.peek() orelse return self.fail("Malformed declaration: quote expected", .{});
        if (quote != '"' and quote != '\'') return self.fail("Malformed declaration: quote expected", .{});
        const start = cur.pos + 1;
        const end = std.mem.indexOfScalarPos(u8, cur.text, start, quote) orelse return self.fail("Malformed declaration: quote expected", .{});
        cur.pos = end + 1;
        return cur.text[start..end];
    }

    // ------------------------------------------------------------------
    // [28] doctypedecl ::= '<!DOCTYPE' S Name (S ExternalID)? S? ('[' intSubset ']' S?)? '>'

    fn doctype(self: *Parser, sink: anytype) anyerror!void {
        const cur = self.doc();
        self.seen_doctype = true;
        cur.pos += "<!DOCTYPE".len;
        if (!cur.skipSpace()) return self.fail("Space required after 'DOCTYPE'", .{});
        const name = cur.name() orelse return self.fail("xmlParseDocTypeDecl : no DOCTYPE name !", .{});
        var public_id: []const u8 = "";
        var system_id: []const u8 = "";
        const spaced = cur.skipSpace();
        if (spaced and (cur.startsWith("SYSTEM") or cur.startsWith("PUBLIC"))) {
            const ids = try self.externalId(cur);
            public_id = ids.public_id;
            system_id = ids.system_id;
            _ = cur.skipSpace();
        }
        for (xhtml_public_ids) |id| {
            if (std.mem.eql(u8, public_id, id)) self.xhtml = true;
        }
        if (cur.peek() == '[') {
            cur.pos += 1;
            try self.declarations(cur, true);
            _ = cur.skipSpace();
        }
        if (cur.peek() != '>') return self.fail("DOCTYPE improperly terminated", .{});
        cur.pos += 1;
        const Sink = @typeInfo(@TypeOf(sink)).pointer.child;
        if (@hasDecl(Sink, "doctype")) try sink.doctype(name, public_id, system_id);
    }

    const ExternalId = struct { public_id: []const u8, system_id: []const u8 };

    /// [75] ExternalID ::= 'SYSTEM' S SystemLiteral | 'PUBLIC' S PubidLiteral S SystemLiteral
    fn externalId(self: *Parser, cur: *Cursor) anyerror!ExternalId {
        var ids: ExternalId = .{ .public_id = "", .system_id = "" };
        if (cur.startsWith("PUBLIC")) {
            cur.pos += "PUBLIC".len;
            if (!cur.skipSpace()) return self.fail("Space required after 'PUBLIC'", .{});
            ids.public_id = try self.quoted(cur, "PubidLiteral");
            for (ids.public_id) |b| if (!chars.isPubidChar(b)) return self.fail("Invalid char in PubidLiteral", .{});
            if (!cur.skipSpace()) return self.fail("Space required after the Public Identifier", .{});
            ids.system_id = try self.quoted(cur, "SystemLiteral");
        } else {
            cur.pos += "SYSTEM".len;
            if (!cur.skipSpace()) return self.fail("Space required after 'SYSTEM'", .{});
            ids.system_id = try self.quoted(cur, "SystemLiteral");
        }
        if (chars.firstNonChar(ids.system_id) != null) return self.fail("Invalid char in SystemLiteral", .{});
        return ids;
    }

    fn quoted(self: *Parser, cur: *Cursor, comptime what: []const u8) anyerror![]const u8 {
        const quote = cur.peek() orelse return self.fail(what ++ " \" or ' expected", .{});
        if (quote != '"' and quote != '\'') return self.fail(what ++ " \" or ' expected", .{});
        const start = cur.pos + 1;
        const end = std.mem.indexOfScalarPos(u8, cur.text, start, quote) orelse return self.fail("Unfinished " ++ what, .{});
        cur.pos = end + 1;
        return cur.text[start..end];
    }

    /// [28b] intSubset ::= (markupdecl | DeclSep)*, from `cur` to its ']'
    /// (`subset`) or its end (a parameter entity's replacement text).
    fn declarations(self: *Parser, cur: *Cursor, subset: bool) anyerror!void {
        while (true) {
            _ = cur.skipSpace();
            if (cur.eof()) {
                if (subset) return self.fail("xmlParseInternalSubset: error detected in Markup declaration", .{});
                return;
            }
            if (cur.peek() == ']') {
                if (!subset) return self.fail("xmlParseInternalSubset: error detected in Markup declaration", .{});
                cur.pos += 1;
                return;
            }
            if (cur.peek() == '%') {
                try self.parameterReference(cur);
            } else if (cur.startsWith("<!ENTITY")) {
                try self.entityDeclaration(cur);
            } else if (cur.startsWith("<!ELEMENT") or cur.startsWith("<!ATTLIST") or cur.startsWith("<!NOTATION")) {
                try self.skipDeclaration(cur);
            } else if (cur.startsWith("<!--")) {
                _ = try self.commentData(cur);
            } else if (cur.startsWith("<?")) {
                _ = try self.processingInstructionData(cur);
            } else {
                return self.fail("xmlParseInternalSubset: error detected in Markup declaration", .{});
            }
        }
    }

    /// [69] PEReference between declarations: an internal parameter
    /// entity's replacement text is read as declarations (XML §4.4.8).
    fn parameterReference(self: *Parser, cur: *Cursor) anyerror!void {
        cur.pos += 1;
        const name = cur.name() orelse return self.fail("PEReference: no name", .{});
        if (cur.peek() != ';') return self.fail("PEReference: expecting ';'", .{});
        cur.pos += 1;
        const entity = self.parameter_entities.getPtr(name) orelse {
            // XML §5.1: a non-validating processor that does not read a
            // parameter entity must not process the declarations after it.
            self.skip_declarations = true;
            return;
        };
        if (entity.kind != .internal) {
            self.skip_declarations = true;
            return;
        }
        if (entity.in_use) return self.fail("Detected an entity reference loop", .{});
        try self.spend(entity.value.len);
        entity.in_use = true;
        defer entity.in_use = false;
        var inner: Cursor = .{ .text = entity.value };
        try self.declarations(&inner, false);
    }

    /// Element, attribute-list and notation declarations are read past.
    fn skipDeclaration(self: *Parser, cur: *Cursor) anyerror!void {
        var i = cur.pos + 2;
        while (i < cur.text.len) : (i += 1) {
            switch (cur.text[i]) {
                '>' => {
                    cur.pos = i + 1;
                    return;
                },
                '"', '\'' => |quote| {
                    i = std.mem.indexOfScalarPos(u8, cur.text, i + 1, quote) orelse break;
                },
                else => {},
            }
        }
        return self.fail("xmlParseInternalSubset: error detected in Markup declaration", .{});
    }

    /// [70] EntityDecl ::= GEDecl | PEDecl
    fn entityDeclaration(self: *Parser, cur: *Cursor) anyerror!void {
        cur.pos += "<!ENTITY".len;
        if (!cur.skipSpace()) return self.fail("Space required after '<!ENTITY'", .{});
        var parameter = false;
        if (cur.peek() == '%') {
            cur.pos += 1;
            if (!cur.skipSpace()) return self.fail("Space required after '%'", .{});
            parameter = true;
        }
        const name = cur.name() orelse return self.fail("xmlParseEntityDecl: no name", .{});
        if (!cur.skipSpace()) return self.fail("Space required after the entity name", .{});
        var entity: Entity = .{ .kind = .internal };
        if (cur.peek() == '"' or cur.peek() == '\'') {
            entity.value = try self.entityValue(cur);
        } else if (cur.startsWith("SYSTEM") or cur.startsWith("PUBLIC")) {
            _ = try self.externalId(cur);
            entity.kind = .external;
            const spaced = cur.skipSpace();
            if (!parameter and spaced and cur.startsWith("NDATA")) {
                cur.pos += "NDATA".len;
                if (!cur.skipSpace()) return self.fail("Space required after 'NDATA'", .{});
                _ = cur.name() orelse return self.fail("NDATA: no notation name", .{});
                entity.kind = .unparsed;
            }
        } else return self.fail("Entity value required", .{});
        _ = cur.skipSpace();
        if (cur.peek() != '>') return self.fail("xmlParseEntityDecl: entity {s} not terminated", .{name});
        cur.pos += 1;
        if (self.skip_declarations) return;
        // The predefined entities keep their meaning (XML §4.6).
        if (!parameter and predefined(name) != null) return;
        const map = if (parameter) &self.parameter_entities else &self.entities;
        // XML §4.2: the first declaration of an entity is binding.
        const slot = try map.getOrPut(self.allocator, name);
        if (!slot.found_existing) slot.value_ptr.* = entity;
    }

    /// [9] EntityValue: character references are replaced when the entity
    /// is declared; general entity references are kept for when it is used.
    fn entityValue(self: *Parser, cur: *Cursor) anyerror![]const u8 {
        const quote = cur.text[cur.pos];
        cur.pos += 1;
        var value: std.ArrayList(u8) = .empty;
        const arena = self.arena.allocator();
        while (true) {
            const c = cur.peek() orelse return self.fail("EntityValue: \" or ' expected", .{});
            if (c == quote) {
                cur.pos += 1;
                break;
            }
            switch (c) {
                '%' => return self.fail("PEReferences forbidden in internal subset", .{}),
                '&' => {
                    if (cur.text.len > cur.pos + 1 and cur.text[cur.pos + 1] == '#') {
                        try appendCodePoint(&value, arena, try self.characterReference(cur));
                    } else {
                        const start = cur.pos;
                        cur.pos += 1;
                        _ = cur.name() orelse return self.fail("EntityValue: '&' forbidden except for entities references", .{});
                        if (cur.peek() != ';') return self.fail("EntityValue: '&' forbidden except for entities references", .{});
                        cur.pos += 1;
                        try value.appendSlice(arena, cur.text[start..cur.pos]);
                    }
                },
                else => {
                    const d = try self.char(cur);
                    try value.appendSlice(arena, cur.text[cur.pos..][0..d.len]);
                    cur.pos += d.len;
                },
            }
        }
        return value.items;
    }

    // ------------------------------------------------------------------
    // [39] element, [43] content

    fn content(self: *Parser, sink: anytype) anyerror!void {
        try self.startTag(sink);
        while (self.elements.items.len > 0) {
            const frame = &self.frames.items[self.frames.items.len - 1];
            const cur = &frame.cursor;
            if (cur.eof()) {
                if (frame.entity) |entity| {
                    // XML §4.3.2: an internal parsed entity's content is
                    // well-formed - it closes every element it opens.
                    if (self.elements.items.len != frame.depth) return self.fail("chunk is not well balanced", .{});
                    entity.in_use = false;
                    _ = self.frames.pop();
                    continue;
                }
                try self.flushText(sink);
                const open = self.elements.items[self.elements.items.len - 1];
                return self.fail("Premature end of data in tag {s} line {d}", .{ open.name.qualified, open.line });
            }
            switch (cur.text[cur.pos]) {
                '<' => try self.markup(sink),
                '&' => try self.contentReference(),
                else => try self.characterData(cur),
            }
        }
        try self.flushText(sink);
    }

    fn markup(self: *Parser, sink: anytype) anyerror!void {
        const cur = self.top();
        try self.flushText(sink);
        if (cur.startsWith("</")) {
            try self.endTag(sink);
        } else if (cur.startsWith("<!--")) {
            try self.comment(sink);
        } else if (cur.startsWith("<![CDATA[")) {
            try self.cdataSection(sink);
        } else if (cur.startsWith("<?")) {
            try self.processingInstruction(sink);
        } else {
            try self.startTag(sink);
        }
    }

    /// [14] CharData: up to the next '<' or '&'.
    fn characterData(self: *Parser, cur: *Cursor) anyerror!void {
        const start = cur.pos;
        var end = start;
        while (end < cur.text.len and cur.text[end] != '<' and cur.text[end] != '&') end += 1;
        const run = cur.text[start..end];
        if (chars.firstNonChar(run)) |bad| {
            cur.pos = start + bad;
            return self.failChar(cur);
        }
        if (std.mem.indexOf(u8, run, "]]>") != null) return self.fail("Sequence ']]>' not allowed in content", .{});
        try self.text_buffer.appendSlice(self.allocator, run);
        cur.pos = end;
    }

    fn flushText(self: *Parser, sink: anytype) anyerror!void {
        if (self.text_buffer.items.len == 0) return;
        const Sink = @typeInfo(@TypeOf(sink)).pointer.child;
        if (@hasDecl(Sink, "text")) try sink.text(self.text_buffer.items);
        self.text_buffer.clearRetainingCapacity();
    }

    /// [40] STag / [44] EmptyElemTag, then namespace processing.
    fn startTag(self: *Parser, sink: anytype) anyerror!void {
        const cur = self.top();
        var p: Cursor = cur.*;
        p.pos += 1;
        const qualified = p.name() orelse return self.fail("StartTag: invalid element name", .{});
        self.raw_attributes.clearRetainingCapacity();
        self.values.clearRetainingCapacity();
        var empty = false;
        while (true) {
            const spaced = p.skipSpace();
            const c = p.peek() orelse return self.fail("Couldn't find end of Start Tag {s} line {d}", .{ qualified, self.lineAt() });
            if (c == '>') {
                p.pos += 1;
                break;
            }
            if (c == '/') {
                if (!p.startsWith("/>")) return self.fail("Couldn't find end of Start Tag {s} line {d}", .{ qualified, self.lineAt() });
                p.pos += 2;
                empty = true;
                break;
            }
            if (!spaced) return self.fail("attributes construct error", .{});
            // [41] Attribute ::= Name Eq AttValue
            const attr_name = p.name() orelse return self.fail("error parsing attribute name", .{});
            _ = p.skipSpace();
            if (p.peek() != '=') return self.fail("Specification mandates value for attribute {s}", .{attr_name});
            p.pos += 1;
            _ = p.skipSpace();
            const quote = p.peek() orelse return self.fail("AttValue: \" or ' expected", .{});
            if (quote != '"' and quote != '\'') return self.fail("AttValue: \" or ' expected", .{});
            p.pos += 1;
            const value_start = self.values.items.len;
            try self.attributeValue(&p, quote, 0);
            for (self.raw_attributes.items) |seen| {
                // WFC: Unique Att Spec.
                if (std.mem.eql(u8, seen.qualified, attr_name)) return self.fail("Attribute {s} redefined", .{attr_name});
            }
            try self.raw_attributes.append(self.allocator, .{ .qualified = attr_name, .value_start = value_start, .value_end = self.values.items.len });
        }
        const line = self.lineAt();
        cur.pos = p.pos;
        const name = try self.processNamespaces(qualified);
        const Sink = @typeInfo(@TypeOf(sink)).pointer.child;
        if (@hasDecl(Sink, "startElement")) try sink.startElement(name.element, self.attributes.items);
        if (empty) {
            if (@hasDecl(Sink, "endElement")) try sink.endElement(name.element);
            self.bindings.shrinkRetainingCapacity(name.mark);
        } else {
            try self.elements.append(self.allocator, .{ .name = name.element, .line = line, .bindings_mark = name.mark });
        }
    }

    /// [10] AttValue's content up to `quote` (0: the end of an entity's
    /// replacement text), normalized as XML §3.3.3 says into `values`.
    fn attributeValue(self: *Parser, cur: *Cursor, quote: u8, depth: usize) anyerror!void {
        while (true) {
            const c = cur.peek() orelse {
                if (quote == 0) return;
                return self.fail("AttValue: ' expected", .{});
            };
            if (quote != 0 and c == quote) {
                cur.pos += 1;
                return;
            }
            switch (c) {
                // WFC: No < in Attribute Values.
                '<' => return self.fail("Unescaped '<' not allowed in attributes values", .{}),
                '&' => try self.attributeReference(cur, depth),
                0x20, 0x9, 0xA, 0xD => {
                    try self.values.append(self.allocator, ' ');
                    cur.pos += 1;
                },
                else => {
                    const d = try self.char(cur);
                    try self.values.appendSlice(self.allocator, cur.text[cur.pos..][0..d.len]);
                    cur.pos += d.len;
                },
            }
        }
    }

    fn attributeReference(self: *Parser, cur: *Cursor, depth: usize) anyerror!void {
        if (cur.text.len > cur.pos + 1 and cur.text[cur.pos + 1] == '#') {
            try appendCodePoint(&self.values, self.allocator, try self.characterReference(cur));
            return;
        }
        const name = try self.entityReferenceName(cur);
        if (predefined(name)) |c| return self.values.append(self.allocator, c);
        const entity = self.entities.getPtr(name) orelse {
            if (self.xhtmlEntity(name)) |codepoints| {
                for (codepoints) |cp| try appendCodePoint(&self.values, self.allocator, cp);
                return;
            }
            return self.fail("Entity '{s}' not defined", .{name});
        };
        switch (entity.kind) {
            // WFC: No External Entity References.
            .external => return self.fail("Attribute references external entity '{s}'", .{name}),
            .unparsed => return self.fail("Attribute references unparsed entity '{s}'", .{name}),
            .internal => {},
        }
        // WFC: No Recursion.
        if (entity.in_use) return self.fail("Detected an entity reference loop", .{});
        if (depth >= max_entity_depth) return self.fail("Maximum entity nesting depth exceeded", .{});
        try self.spend(entity.value.len);
        entity.in_use = true;
        defer entity.in_use = false;
        var inner: Cursor = .{ .text = entity.value };
        try self.attributeValue(&inner, 0, depth + 1);
    }

    /// A reference in content: a character or predefined entity joins the
    /// text; an internal entity's replacement text is read in place.
    fn contentReference(self: *Parser) anyerror!void {
        const cur = self.top();
        if (cur.text.len > cur.pos + 1 and cur.text[cur.pos + 1] == '#') {
            try appendCodePoint(&self.text_buffer, self.allocator, try self.characterReference(cur));
            return;
        }
        const name = try self.entityReferenceName(cur);
        if (predefined(name)) |c| return self.text_buffer.append(self.allocator, c);
        const entity = self.entities.getPtr(name) orelse {
            if (self.xhtmlEntity(name)) |codepoints| {
                for (codepoints) |cp| try appendCodePoint(&self.text_buffer, self.allocator, cp);
                return;
            }
            return self.fail("Entity '{s}' not defined", .{name});
        };
        switch (entity.kind) {
            // HTML §14.2: external entities are not retrieved.
            .external => return,
            .unparsed => return self.fail("Entity reference to unparsed entity {s}", .{name}),
            .internal => {},
        }
        if (entity.in_use) return self.fail("Detected an entity reference loop", .{});
        if (self.frames.items.len > max_entity_depth) return self.fail("Maximum entity nesting depth exceeded", .{});
        try self.spend(entity.value.len);
        entity.in_use = true;
        try self.frames.append(self.allocator, .{
            .cursor = .{ .text = entity.value },
            .entity = entity,
            .depth = self.elements.items.len,
        });
    }

    /// [68] EntityRef ::= '&' Name ';' - the name.
    fn entityReferenceName(self: *Parser, cur: *Cursor) anyerror![]const u8 {
        cur.pos += 1;
        const name = cur.name() orelse return self.fail("xmlParseEntityRef: no name", .{});
        if (cur.peek() != ';') return self.fail("EntityRef: expecting ';'", .{});
        cur.pos += 1;
        return name;
    }

    fn xhtmlEntity(self: *const Parser, name: []const u8) ?[]const u21 {
        if (!self.xhtml) return null;
        const resolve = self.options.xhtml_entities orelse return null;
        return resolve(name);
    }

    /// [66] CharRef; WFC: Legal Character.
    fn characterReference(self: *Parser, cur: *Cursor) anyerror!u21 {
        var i = cur.pos + 2;
        const hex = i < cur.text.len and cur.text[i] == 'x';
        if (hex) i += 1;
        const start = i;
        var value: u32 = 0;
        while (i < cur.text.len) : (i += 1) {
            const digit = std.fmt.charToDigit(cur.text[i], if (hex) 16 else 10) catch break;
            value = @min(value *| (if (hex) @as(u32, 16) else 10) +| digit, 0x110000);
        }
        if (i == start or i >= cur.text.len or cur.text[i] != ';') return self.fail("xmlParseCharRef: invalid decimal value", .{});
        if (value > 0x10FFFF or !chars.isChar(@intCast(value))) return self.fail("xmlParseCharRef: invalid xmlChar value {d}", .{value});
        cur.pos = i + 1;
        return @intCast(value);
    }

    /// [42] ETag ::= '</' Name S? '>'
    fn endTag(self: *Parser, sink: anytype) anyerror!void {
        const cur = self.top();
        var p: Cursor = cur.*;
        p.pos += 2;
        const qualified = p.name() orelse return self.fail("xmlParseEndTag: '</' not found", .{});
        _ = p.skipSpace();
        if (p.peek() != '>') return self.fail("expected '>'", .{});
        p.pos += 1;
        const frame = self.frames.items[self.frames.items.len - 1];
        if (frame.entity != null and self.elements.items.len == frame.depth) return self.fail("chunk is not well balanced", .{});
        const open = self.elements.items[self.elements.items.len - 1];
        // WFC: Element Type Match.
        if (!std.mem.eql(u8, open.name.qualified, qualified)) {
            return self.fail("Opening and ending tag mismatch: {s} line {d} and {s}", .{ open.name.qualified, open.line, qualified });
        }
        cur.pos = p.pos;
        const Sink = @typeInfo(@TypeOf(sink)).pointer.child;
        if (@hasDecl(Sink, "endElement")) try sink.endElement(open.name);
        self.bindings.shrinkRetainingCapacity(open.bindings_mark);
        _ = self.elements.pop();
    }

    // ------------------------------------------------------------------
    // Namespaces in XML

    const Processed = struct { element: Name, mark: usize };

    /// Bind the start tag's namespace declarations, then name the element
    /// and its attributes (Namespaces in XML §5-§6), into `attributes`.
    fn processNamespaces(self: *Parser, qualified: []const u8) anyerror!Processed {
        const mark = self.bindings.items.len;
        errdefer self.bindings.shrinkRetainingCapacity(mark);
        for (self.raw_attributes.items) |raw| {
            const value = self.values.items[raw.value_start..raw.value_end];
            if (std.mem.eql(u8, raw.qualified, "xmlns")) {
                // A default namespace declaration; "" undeclares it.
                if (std.mem.eql(u8, value, xml_namespace) or std.mem.eql(u8, value, xmlns_namespace)) {
                    return self.fail("xmlns: URI {s} is not allowed", .{value});
                }
                try self.bindings.append(self.allocator, .{ .prefix = null, .uri = if (value.len == 0) null else try self.intern(value) });
            } else if (std.mem.startsWith(u8, raw.qualified, "xmlns:")) {
                const prefix = raw.qualified["xmlns:".len..];
                if (!chars.isNCName(prefix)) return self.fail("Failed to parse QName '{s}'", .{raw.qualified});
                // Namespace constraints: Reserved Prefixes and Namespace Names.
                if (std.mem.eql(u8, prefix, "xmlns")) return self.fail("redefinition of the xmlns prefix is forbidden", .{});
                if (std.mem.eql(u8, prefix, "xml")) {
                    if (!std.mem.eql(u8, value, xml_namespace)) return self.fail("xml namespace prefix mapped to wrong URI", .{});
                    continue;
                }
                if (std.mem.eql(u8, value, xml_namespace)) return self.fail("xml namespace URI mapped to wrong prefix", .{});
                if (std.mem.eql(u8, value, xmlns_namespace)) return self.fail("reuse of the xmlns namespace name is forbidden", .{});
                // Namespace constraint: No Prefix Undeclaring (XML 1.0).
                if (value.len == 0) return self.fail("xmlns:{s}: Empty XML namespace is not allowed", .{prefix});
                try self.bindings.append(self.allocator, .{ .prefix = prefix, .uri = try self.intern(value) });
            }
        }
        const element_parts = splitQName(qualified) orelse return self.fail("Failed to parse QName '{s}'", .{qualified});
        var element: Name = .{ .qualified = qualified, .prefix = element_parts.prefix, .local = element_parts.local, .namespace = null };
        if (element_parts.prefix) |prefix| {
            // Namespace constraint: Prefix Declared.
            element.namespace = self.lookup(prefix) orelse return self.fail("Namespace prefix {s} on {s} is not defined", .{ prefix, element.local });
        } else element.namespace = self.lookupDefault();

        self.attributes.clearRetainingCapacity();
        for (self.raw_attributes.items) |raw| {
            const value = self.values.items[raw.value_start..raw.value_end];
            var name: Name = undefined;
            if (std.mem.eql(u8, raw.qualified, "xmlns")) {
                name = .{ .qualified = raw.qualified, .prefix = null, .local = "xmlns", .namespace = xmlns_namespace };
            } else if (std.mem.startsWith(u8, raw.qualified, "xmlns:")) {
                name = .{ .qualified = raw.qualified, .prefix = "xmlns", .local = raw.qualified["xmlns:".len..], .namespace = xmlns_namespace };
            } else {
                const parts = splitQName(raw.qualified) orelse return self.fail("Failed to parse QName '{s}'", .{raw.qualified});
                name = .{ .qualified = raw.qualified, .prefix = parts.prefix, .local = parts.local, .namespace = null };
                if (parts.prefix) |prefix| {
                    name.namespace = self.lookup(prefix) orelse return self.fail("Namespace prefix {s} for {s} on {s} is not defined", .{ prefix, parts.local, element.local });
                }
            }
            // Namespace constraint: Attributes Unique.
            for (self.attributes.items) |seen| {
                if (std.mem.eql(u8, seen.name.local, name.local) and eqlOptional(seen.name.namespace, name.namespace)) {
                    return self.fail("Namespaced Attribute {s} in '{s}' redefined", .{ name.local, name.namespace orelse "" });
                }
            }
            try self.attributes.append(self.allocator, .{ .name = name, .value = value });
        }
        return .{ .element = element, .mark = mark };
    }

    fn lookup(self: *const Parser, prefix: []const u8) ?[]const u8 {
        if (std.mem.eql(u8, prefix, "xml")) return xml_namespace;
        var i = self.bindings.items.len;
        while (i > 0) {
            i -= 1;
            const binding = self.bindings.items[i];
            if (binding.prefix) |bound| if (std.mem.eql(u8, bound, prefix)) return binding.uri;
        }
        return null;
    }

    fn lookupDefault(self: *const Parser) ?[]const u8 {
        var i = self.bindings.items.len;
        while (i > 0) {
            i -= 1;
            const binding = self.bindings.items[i];
            if (binding.prefix == null) return binding.uri;
        }
        return null;
    }

    fn intern(self: *Parser, uri: []const u8) anyerror![]const u8 {
        if (self.uris.getKey(uri)) |kept| return kept;
        const kept = try self.arena.allocator().dupe(u8, uri);
        try self.uris.put(self.allocator, kept, {});
        return kept;
    }

    // ------------------------------------------------------------------
    // Comments, CDATA sections, processing instructions

    fn comment(self: *Parser, sink: anytype) anyerror!void {
        const data = try self.commentData(self.top());
        const Sink = @typeInfo(@TypeOf(sink)).pointer.child;
        if (@hasDecl(Sink, "comment")) try sink.comment(data);
    }

    /// [15] Comment ::= '<!--' ((Char - '-') | ('-' (Char - '-')))* '-->'
    fn commentData(self: *Parser, cur: *Cursor) anyerror![]const u8 {
        const start = cur.pos + 4;
        const dashes = std.mem.indexOfPos(u8, cur.text, start, "--") orelse return self.fail("Comment not terminated", .{});
        if (dashes + 2 >= cur.text.len or cur.text[dashes + 2] != '>') return self.fail("Double hyphen within comment", .{});
        const data = cur.text[start..dashes];
        if (chars.firstNonChar(data)) |bad| {
            cur.pos = start + bad;
            return self.failChar(cur);
        }
        cur.pos = dashes + 3;
        return data;
    }

    /// [18] CDSect ::= '<![CDATA[' CData ']]>'
    fn cdataSection(self: *Parser, sink: anytype) anyerror!void {
        const cur = self.top();
        const start = cur.pos + "<![CDATA[".len;
        const end = std.mem.indexOfPos(u8, cur.text, start, "]]>") orelse return self.fail("CData section not finished", .{});
        const data = cur.text[start..end];
        if (chars.firstNonChar(data)) |bad| {
            cur.pos = start + bad;
            return self.failChar(cur);
        }
        cur.pos = end + 3;
        const Sink = @typeInfo(@TypeOf(sink)).pointer.child;
        if (@hasDecl(Sink, "cdata")) try sink.cdata(data);
    }

    fn processingInstruction(self: *Parser, sink: anytype) anyerror!void {
        const pi = try self.processingInstructionData(self.top());
        const Sink = @typeInfo(@TypeOf(sink)).pointer.child;
        if (@hasDecl(Sink, "processingInstruction")) try sink.processingInstruction(pi.target, pi.data);
    }

    const ProcessingInstruction = struct { target: []const u8, data: []const u8 };

    /// [16] PI ::= '<?' PITarget (S (Char* - (Char* '?>' Char*)))? '?>'
    fn processingInstructionData(self: *Parser, cur: *Cursor) anyerror!ProcessingInstruction {
        var p: Cursor = cur.*;
        p.pos += 2;
        const target = p.name() orelse return self.fail("xmlParsePI : no target name", .{});
        // [17] PITarget ::= Name - (('X' | 'x') ('M' | 'm') ('L' | 'l'))
        if (std.ascii.eqlIgnoreCase(target, "xml")) {
            if (std.mem.eql(u8, target, "xml")) return self.fail("XML declaration allowed only at the start of the document", .{});
            return self.fail("xmlParsePITarget: invalid name prefix 'xml'", .{});
        }
        // Namespaces in XML §7: no colons in PI targets.
        if (std.mem.indexOfScalar(u8, target, ':') != null) return self.fail("colons are forbidden from PI names '{s}'", .{target});
        var data: []const u8 = "";
        if (p.startsWith("?>")) {
            p.pos += 2;
        } else {
            if (!p.skipSpace()) return self.fail("ParsePI: PI {s} space expected", .{target});
            const end = std.mem.indexOfPos(u8, p.text, p.pos, "?>") orelse return self.fail("ParsePI: PI {s} never end ...", .{target});
            data = p.text[p.pos..end];
            if (chars.firstNonChar(data)) |bad| {
                cur.pos = p.pos + bad;
                return self.failChar(cur);
            }
            p.pos = end + 2;
        }
        cur.pos = p.pos;
        return .{ .target = target, .data = data };
    }

    // ------------------------------------------------------------------
    // Helpers

    /// The [2] Char at the cursor, or a fatal error.
    fn char(self: *Parser, cur: *Cursor) anyerror!chars.Decoded {
        const d = chars.decodeAt(cur.text, cur.pos) orelse return self.failChar(cur);
        if (!chars.isChar(d.c)) return self.failChar(cur);
        return d;
    }

    fn failChar(self: *Parser, cur: *Cursor) anyerror {
        if (self.frames.items.len == 1) self.frames.items[0].cursor.pos = cur.pos;
        const d = chars.decodeAt(cur.text, cur.pos) orelse return self.fail("Input is not proper UTF-8, indicate encoding !", .{});
        return self.fail("Char 0x{X} out of allowed range", .{d.c});
    }

    /// Count `bytes` of entity replacement text against the expansion limit.
    fn spend(self: *Parser, bytes: usize) anyerror!void {
        self.expanded +|= bytes;
        if (self.expanded > self.expansion_limit) return self.fail("Maximum entity amplification factor exceeded", .{});
    }
};

fn isSpaceByte(b: u8) bool {
    return b == 0x20 or b == 0x9 or b == 0xA or b == 0xD;
}

fn allDigits(s: []const u8) bool {
    for (s) |b| if (!std.ascii.isDigit(b)) return false;
    return true;
}

/// [81] EncName ::= [A-Za-z] ([A-Za-z0-9._] | '-')*
fn isEncName(s: []const u8) bool {
    if (s.len == 0 or !std.ascii.isAlphabetic(s[0])) return false;
    for (s[1..]) |b| if (!(std.ascii.isAlphanumeric(b) or b == '.' or b == '_' or b == '-')) return false;
    return true;
}

/// XML §4.6: the predefined entities.
fn predefined(name: []const u8) ?u8 {
    const table = .{ .{ "lt", '<' }, .{ "gt", '>' }, .{ "amp", '&' }, .{ "apos", '\'' }, .{ "quot", '"' } };
    inline for (table) |entry| if (std.mem.eql(u8, name, entry[0])) return entry[1];
    return null;
}

const QName = struct { prefix: ?[]const u8, local: []const u8 };

/// Namespaces in XML [7] QName ::= PrefixedName | UnprefixedName, or null.
fn splitQName(qualified: []const u8) ?QName {
    const colon = std.mem.indexOfScalar(u8, qualified, ':') orelse {
        return .{ .prefix = null, .local = qualified };
    };
    const prefix = qualified[0..colon];
    const local = qualified[colon + 1 ..];
    if (!chars.isNCName(prefix) or !chars.isNCName(local)) return null;
    return .{ .prefix = prefix, .local = local };
}

fn eqlOptional(a: ?[]const u8, b: ?[]const u8) bool {
    if (a == null or b == null) return a == null and b == null;
    return std.mem.eql(u8, a.?, b.?);
}

fn appendCodePoint(list: *std.ArrayList(u8), allocator: Allocator, c: u21) !void {
    var buf: [4]u8 = undefined;
    const len = std.unicode.utf8Encode(c, &buf) catch unreachable;
    try list.appendSlice(allocator, buf[0..len]);
}

/// The encoding an XML declaration at the very start of `bytes` names, as
/// written (XML §4.3.3), or null. Reads only ASCII-compatible bytes; the
/// caller finds a byte order mark first.
pub fn declaredEncoding(bytes: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, bytes, "<?xml") or bytes.len < 6 or !isSpaceByte(bytes[5])) return null;
    const window = bytes[0..@min(bytes.len, 1024)];
    const end = std.mem.indexOf(u8, window, "?>") orelse return null;
    var cur: Cursor = .{ .text = window[0..end], .pos = 5 };
    while (true) {
        _ = cur.skipSpace();
        const name = cur.name() orelse return null;
        _ = cur.skipSpace();
        if (cur.peek() != '=') return null;
        cur.pos += 1;
        _ = cur.skipSpace();
        const quote = cur.peek() orelse return null;
        if (quote != '"' and quote != '\'') return null;
        const close = std.mem.indexOfScalarPos(u8, cur.text, cur.pos + 1, quote) orelse return null;
        const value = cur.text[cur.pos + 1 .. close];
        cur.pos = close + 1;
        if (std.mem.eql(u8, name, "encoding")) return if (isEncName(value)) value else null;
    }
}

test "splitQName rejects empty parts and extra colons" {
    try std.testing.expect(splitQName("a:b") != null);
    try std.testing.expect(splitQName(":b") == null);
    try std.testing.expect(splitQName("a:") == null);
    try std.testing.expect(splitQName("a:b:c") == null);
    try std.testing.expectEqualStrings("b", splitQName("b").?.local);
}
