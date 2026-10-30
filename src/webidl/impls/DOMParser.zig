//! Implementation for DOMParser interface
//!
//! Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#domparser
//! HTML Standard §8.4.2 "DOMParser"
//!
//! The DOMParser interface allows parsing HTML and XML documents from strings.
//!
//! ## Usage
//!
//! ```zig
//! const parser = try DOMParser.call_constructor(ctx);
//! defer DOMParser.deinit(parser);
//!
//! const doc = try DOMParser.call_parseFromString(parser, html_string, ._text_html_);
//! ```

const std = @import("std");
const log = std.log.scoped(.dom_parser);
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const DOMParser = interfaces.DOMParser;

// HTML's parser for a document from a string (src/html/dom_parser.zig)
const dom_parser = @import("html").dom_parser;

// Import DOM internals for document state access (Golden Rule #12 compliant)
const dom = @import("dom");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const document_internals = dom.document_internals;

pub const State = DOMParser.State;

pub const ImplError = error{
    NotImplemented,
    NotSupportedError,
    OutOfMemory,
};

/// Internal state for DOMParser implementation
/// DOMParser is stateless - all operations are independent
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *InternalState) void {
        _ = self;
    }
};

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Initialize internal state
    const state = instance.getState(StateType);
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = InternalState.init(allocator);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();

        // Return the block itself, not just what it points to.
        // `internal.deinit()` releases the strings and lists the state
        // OWNS; without this the state struct stays allocated for the
        // life of the process - measured at 208 bytes per discarded
        // element across the impls still doing it this way.
        runtime.arenaOf(instance).destroy(InternalState, internal);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
/// Creates a new DOMParser instance
///
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-domparser-constructor
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &DOMParser.vtable, ctx);
    errdefer deinit(instance);

    return instance;
}

/// Operation: parseFromString
///
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-domparser-parsefromstring
///
/// The parseFromString(string, type) method steps are:
///
/// 1. Let document be a new Document, whose content type is type and URL is
///    this's relevant global object's associated Document's URL.
///
/// 2. Switch on type:
///    - "text/html"
///      Parse string given document using the HTML parser.
///
///    - "text/xml", "application/xml", "application/xhtml+xml", "image/svg+xml"
///      Parse string given document using the XML parser.
///      If that throws an error, or if the root element of document is an html
///      element in the HTML namespace whose local name is "parsererror", set
///      document's error flag.
///
/// 3. Return document.
pub fn call_parseFromString(instance: *runtime.Instance, string: typedefs.TrustedHTMLOrDOMString, @"type": enums.DOMParserSupportedType) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Step 1: "Let compliantString be the result of invoking the get trusted
    // type compliant string algorithm with TrustedHTML, this's relevant
    // global object, string, "DOMParser parseFromString", and "script"."
    const compliant = try dom.trusted_types.compliantStringFor(internal.allocator, .html, instance, string, "DOMParser parseFromString");
    defer internal.allocator.free(compliant);
    const html_string: []const u8 = compliant;

    // Get the DOMParser's relevant global object's document URL
    // Per spec: "URL is this's relevant global object's associated Document's URL"
    // Track whether we allocated the URL so we can free it later
    var allocated_url: ?[]const u8 = null;
    defer if (allocated_url) |url| internal.allocator.free(url);
    // Step 2: relevantDocument, this's relevant global object's associated
    // Document - null with no Window (a test's bare context).
    var relevant_document: ?*runtime.Instance = null;

    const realm_url: []const u8 = blk: {
        // Get the realm from the context (instance.ctx is already ContextData pointer)
        const realm = instance.ctx.realm orelse break :blk "about:blank";

        // Get the global object (Window) from the realm - cast from *anyopaque
        const window_ptr = realm.global_object orelse break :blk "about:blank";
        const window_instance: *runtime.Instance = @ptrCast(@alignCast(window_ptr));

        // Get the Window's document
        const Window = interfaces.Window;
        const doc = Window.get_document(window_instance) catch break :blk "about:blank";
        relevant_document = doc;

        // Get the document's URL (returns allocated []const u8)
        const url = interfaces.Document.get_URL(doc) catch break :blk "about:blank";
        log.debug("DOMParser: inherited realm URL: {s}", .{url});
        allocated_url = url; // Track for cleanup
        break :blk url;
    };

    return switch (@"type") {
        ._text_html_ => {
            // Parse as HTML
            const document = dom_parser.parseHTML(
                internal.allocator,
                instance.ctx,
                html_string,
                .{},
            ) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => return error.NotSupportedError,
            };

            // Set content type to "text/html"
            try document_internals.setContentType(document, "text/html");

            // Set the document's URL to the DOMParser's realm's document URL
            try document_internals.setURL(document, realm_url);

            // Handed to script: its first wrapper takes its born reference
            // (refcount7).
            dom.refcount.offerDocument(document);
            return document;
        },
        ._text_xml_,
        ._application_xml_,
        ._application_xhtml_xml_,
        ._image_svg_xml_,
        => {
            // Step 4's XML parser consumes scalar UTF-8. Chrome and Firefox
            // replace lone DOMString surrogates (wpt.fyi 23b0b89b1a,
            // DOMParser-parseFromString-xml-parsererror); Safari does not.
            // No newer spec change: golden rule 2's majority. Gecko's
            // DOMParser::ParseFromStringInternal converts to UTF-8 before
            // ParseFromStream: dom/base/DOMParser.cpp on searchfox.org.
            // Normalize only our owned compliant string, after Trusted Types.
            // ED starts every WTF-8 surrogate; skip scalar scans when absent.
            if (std.mem.indexOfScalar(u8, compliant, 0xED)) |first| {
                @import("infra").string.replaceLoneSurrogatesWtf8(compliant[first..]);
            }
            return parseXml(internal.allocator, instance.ctx, html_string, @"type", realm_url, relevant_document);
        },
    };
}

/// Step 3 and step 4's "Otherwise" for an XML type: a new XML document
/// whose content type is `type`, origin relevantDocument's and URL
/// `url`, the string parsed into it by an XML parser with XML scripting
/// support disabled - and, where that found a well-formedness error, the
/// error message block Chrome and Safari insert (xml_document_parser.zig,
/// insertErrorMessageBlock, says why their shape and not step 4.3's).
///
/// Browsers make the document an XMLDocument, where step 3 says Document:
/// Chrome, Firefox and Safari all fail the "XMLDocument interface for ...
/// parsed document" subtests of domparsing/DOMParser-parseFromString-xml.html
/// (wpt.fyi cc74d2669f), which assert it is not one. Golden rule 2.
fn parseXml(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    string: []const u8,
    @"type": enums.DOMParserSupportedType,
    url: []const u8,
    relevant_document: ?*runtime.Instance,
) anyerror!*runtime.Instance {
    // Its origin is the relevant global's associated Document's, a
    // construction fact (shared record, borrowed for the call).
    const origin: ?*dom.origin_record.OriginRecord = if (relevant_document) |relevant| try dom.document_origin.shareable(relevant) else null;
    const document = try interfaces.XMLDocument.initWith(allocator, ctx, .{ .origin = origin, .ready_state = ._complete_ });
    errdefer dom.node_creation.destroyUninserted(document);
    // A document no navigation loads is ready at once (as createDocument's).
    dom.document_lifecycle.markReadyForPostLoadTasks(document);
    try document_internals.setDocumentType(document, .xml);
    try document_internals.setContentType(document, switch (@"type") {
        ._text_xml_ => "text/xml",
        ._application_xml_ => "application/xml",
        ._application_xhtml_xml_ => "application/xhtml+xml",
        ._image_svg_xml_ => "image/svg+xml",
        ._text_html_ => unreachable,
    });
    try document_internals.setURL(document, url);
    const xml_parser = @import("html").xml_document_parser;
    if (try xml_parser.parseInto(document, string, .{ .scripting = false })) |failure| {
        try xml_parser.insertErrorMessageBlock(document, failure);
    }
    // Handed to script: its first wrapper takes its born reference (refcount7).
    dom.refcount.offerDocument(document);
    return document;
}

// =============================================================================
// Tests
// =============================================================================

test "DOMParser - constructor creates valid instance" {
    const ctx = runtime.Context{};

    const parser = try call_constructor(ctx);
    defer deinit(parser);

    try std.testing.expect(parser != null);
}

test "DOMParser - parseFromString with HTML" {
    const ctx = runtime.Context{};

    const parser = try call_constructor(ctx);
    defer deinit(parser);

    const html = runtime.DOMString.initStatic("<html><body>Hello World</body></html>");
    const doc = try call_parseFromString(parser, .{ .domstring = html }, ._text_html_);
    defer interfaces.Document.deinit(doc);

    try std.testing.expect(doc != null);

    // Verify content type was set
    if (document_internals.getContentType(doc)) |content_type| {
        try std.testing.expectEqualStrings("text/html", content_type);
    }
}
