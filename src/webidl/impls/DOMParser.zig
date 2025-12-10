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
//! const parser = try DOMParser.call_constructor(allocator, ctx);
//! defer DOMParser.deinit(parser);
//!
//! const doc = try DOMParser.call_parseFromString(parser, html_string, ._text_html_);
//! ```

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const DOMParser = interfaces.DOMParser;

// Import HTML parser
const HTMLParser = @import("HTMLParser.zig");

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
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
/// Creates a new DOMParser instance
///
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-domparser-constructor
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &DOMParser.vtable, ctx);
    errdefer deinit(instance);

    return instance;
}

/// Operation: parseFromString
///
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-domparser-parsefromstring
///
/// The parseFromString(string, type) method steps are:
///
/// 1. Let document be a new Document, whose content type is type and url is
///    "about:blank".
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
pub fn call_parseFromString(instance: *runtime.Instance, string: runtime.DOMString, @"type": enums.DOMParserSupportedType) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const html_string = string.asSlice();

    return switch (@"type") {
        ._text_html_ => {
            // Parse as HTML
            const document = HTMLParser.parseHTML(
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

            return document;
        },
        ._text_xml_,
        ._application_xml_,
        ._application_xhtml_xml_,
        ._image_svg_xml_,
        => {
            // XML parsing not yet implemented
            // TODO: Implement XML parser integration
            return error.NotImplemented;
        },
    };
}

// =============================================================================
// Tests
// =============================================================================

test "DOMParser - constructor creates valid instance" {
    const allocator = std.testing.allocator;
    const ctx = runtime.Context{};

    const parser = try call_constructor(allocator, ctx);
    defer deinit(parser);

    try std.testing.expect(parser != null);
}

test "DOMParser - parseFromString with HTML" {
    const allocator = std.testing.allocator;
    const ctx = runtime.Context{};

    const parser = try call_constructor(allocator, ctx);
    defer deinit(parser);

    const html = runtime.DOMString.initStatic("<html><body>Hello World</body></html>");
    const doc = try call_parseFromString(parser, html, ._text_html_);
    defer interfaces.Document.deinit(doc);

    try std.testing.expect(doc != null);

    // Verify content type was set
    if (document_internals.getContentType(doc)) |content_type| {
        try std.testing.expectEqualStrings("text/html", content_type);
    }
}
