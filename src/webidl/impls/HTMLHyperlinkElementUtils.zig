//! Implementation for HTMLHyperlinkElementUtils mixin
//!
//! WHATWG HTML Standard: https://html.spec.whatwg.org/multipage/links.html#htmlhyperlinkelementutils
//!
//! This mixin provides URL decomposition attributes for <a> and <area> elements.
//! The key insight is that these elements have a "url" internal slot that is
//! parsed from the href attribute against the document's base URL.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLHyperlinkElementUtils = interfaces.HTMLHyperlinkElementUtils;

// Import URL infrastructure
const URLRecord = @import("url_record").URLRecord;
const api_parser = @import("api_parser");
const url_serializer = @import("url_serializer");
const host_serializer = @import("host_serializer");
const path_serializer = @import("path_serializer");
const origin_module = @import("origin");

// Import Element for attribute access
const ElementImpl = @import("Element.zig");
const NodeImpl = @import("Node.zig");
const DocumentImpl = @import("Document.zig");

pub const State = HTMLHyperlinkElementUtils.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
};

/// Internal state for implementation-specific data
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Helper: Get the href attribute value from the element
/// Returns empty string if href is not set.
fn getHrefAttribute(instance: *runtime.Instance) []const u8 {
    const elem_internal = ElementImpl.getInternal(instance) orelse return "";
    if (elem_internal.findAttribute(null, "href")) |entry| {
        return entry.value;
    }
    return "";
}

/// Helper: Get the document's base URL for relative URL resolution
/// Per HTML spec: https://html.spec.whatwg.org/multipage/urls-and-fetching.html#document-base-url
/// 1. If there's a <base> element with an href attribute, use that (parsed against fallback)
/// 2. Otherwise use the document's fallback base URL (document.url)
fn getBaseUrl(instance: *runtime.Instance) ?[]const u8 {
    // Get owner document
    const owner_doc = NodeImpl.getOwnerDocument(instance) orelse return null;

    // Get document's internal state
    const doc_internal = DocumentImpl.getInternal(owner_doc) orelse return null;

    // Step 1: Check for a <base> element with an href attribute
    // Search the document for the first <base> element with href
    if (findFirstBaseElementHref(owner_doc)) |base_href| {
        // Return the base element's href value
        // (The caller will parse it against the document URL)
        return base_href;
    }

    // Step 2: Fall back to document's URL
    if (doc_internal.url.len > 0) {
        return doc_internal.url;
    }

    // Step 3: Fall back to base_uri if set
    if (doc_internal.base_uri.len > 0) {
        return doc_internal.base_uri;
    }

    return null;
}

/// Find the first <base> element with an href attribute in the document
fn findFirstBaseElementHref(doc_instance: *runtime.Instance) ?[]const u8 {
    // Get the document element (html)
    const doc_internal = DocumentImpl.getInternal(doc_instance) orelse return null;
    const doc_element = doc_internal.document_element orelse return null;

    // Search for <head> in the document element's children
    var current_child = NodeImpl.get_firstChild(doc_element) catch null;
    while (current_child) |child| {
        const child_internal = ElementImpl.getInternal(child) orelse {
            current_child = NodeImpl.get_nextSibling(child) catch null;
            continue;
        };

        if (std.mem.eql(u8, child_internal.local_name.asSlice(), "head")) {
            // Found <head>, now search for <base>
            return findBaseInHead(child);
        }
        current_child = NodeImpl.get_nextSibling(child) catch null;
    }

    return null;
}

/// Find the first <base> element with href inside <head>
fn findBaseInHead(head_instance: *runtime.Instance) ?[]const u8 {
    var current_child = NodeImpl.get_firstChild(head_instance) catch null;
    while (current_child) |child| {
        const child_internal = ElementImpl.getInternal(child) orelse {
            current_child = NodeImpl.get_nextSibling(child) catch null;
            continue;
        };

        if (std.mem.eql(u8, child_internal.local_name.asSlice(), "base")) {
            // Found <base>, check for href attribute
            if (child_internal.findAttribute(null, "href")) |entry| {
                if (entry.value.len > 0) {
                    return entry.value;
                }
            }
        }
        current_child = NodeImpl.get_nextSibling(child) catch null;
    }

    return null;
}

/// Helper: Parse the element's URL (href attribute resolved against base URL)
/// Returns null if parsing fails.
/// Caller owns the returned URLRecord and must call deinit().
fn parseElementUrl(instance: *runtime.Instance, allocator: std.mem.Allocator) ?URLRecord {
    const href_attr = getHrefAttribute(instance);

    // Get owner document for fallback URL
    const owner_doc = NodeImpl.getOwnerDocument(instance) orelse return null;
    const doc_internal = DocumentImpl.getInternal(owner_doc) orelse return null;

    // Get the document's fallback base URL (used to parse <base> href)
    const fallback_base: []const u8 = if (doc_internal.url.len > 0)
        doc_internal.url
    else if (doc_internal.base_uri.len > 0)
        doc_internal.base_uri
    else
        "";

    // Parse fallback base URL
    var fallback_record: ?URLRecord = null;
    if (fallback_base.len > 0) {
        fallback_record = api_parser.parseURL(allocator, fallback_base, null) catch null;
    }
    defer if (fallback_record) |*fr| fr.deinit();

    // Check for <base> element
    var base_record: ?URLRecord = null;
    if (findFirstBaseElementHref(owner_doc)) |base_href| {
        // Parse <base> href against the fallback base URL
        base_record = api_parser.parseURL(
            allocator,
            base_href,
            if (fallback_record) |*fr| fr else null,
        ) catch null;
    }
    defer if (base_record) |*br| br.deinit();

    // Determine which base URL to use for parsing href
    // Priority: <base> element > fallback base URL
    const effective_base: ?*URLRecord = if (base_record) |*br|
        br
    else if (fallback_record) |*fr|
        fr
    else
        null;

    // Parse href against the effective base
    return api_parser.parseURL(allocator, href_attr, effective_base) catch null;
}

/// Getter for href
/// Spec: https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-href
/// Returns the element's href content attribute's value, if it has one, resolved
/// against the document base URL, otherwise returns empty string.
pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
    const allocator = instance.ctx.allocator;

    // Get href attribute
    const href_attr = getHrefAttribute(instance);
    if (href_attr.len == 0) {
        return try allocator.dupe(u8, "");
    }

    // Parse and serialize URL
    var url_record = parseElementUrl(instance, allocator) orelse {
        // If parsing fails, return the raw href attribute value
        return try allocator.dupe(u8, href_attr);
    };
    defer url_record.deinit();

    return url_serializer.serialize(allocator, &url_record, false);
}

/// Getter for origin
/// Spec: https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-origin
/// Returns the origin of the element's URL, serialized.
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    const allocator = instance.ctx.allocator;

    // Parse the element's URL
    var url_record = parseElementUrl(instance, allocator) orelse {
        // If parsing fails or no URL, return "null" (opaque origin serialization)
        return try allocator.dupe(u8, "null");
    };
    defer url_record.deinit();

    // Get and serialize origin
    const url_origin = try origin_module.getOrigin(allocator, &url_record);
    defer url_origin.deinit(allocator);

    return url_origin.serialize(allocator);
}

/// Getter for protocol
/// Spec: https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-protocol
/// Returns the scheme followed by ":"
pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
    const allocator = instance.ctx.allocator;

    var url_record = parseElementUrl(instance, allocator) orelse {
        return try allocator.dupe(u8, ":");
    };
    defer url_record.deinit();

    const scheme = url_record.scheme();
    const result = try allocator.alloc(u8, scheme.len + 1);
    @memcpy(result[0..scheme.len], scheme);
    result[scheme.len] = ':';
    return result;
}

/// Getter for username
/// Spec: https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-username
pub fn get_username(instance: *runtime.Instance) anyerror!runtime.USVString {
    const allocator = instance.ctx.allocator;

    var url_record = parseElementUrl(instance, allocator) orelse {
        return try allocator.dupe(u8, "");
    };
    defer url_record.deinit();

    return try allocator.dupe(u8, url_record.username());
}

/// Getter for password
/// Spec: https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-password
pub fn get_password(instance: *runtime.Instance) anyerror!runtime.USVString {
    const allocator = instance.ctx.allocator;

    var url_record = parseElementUrl(instance, allocator) orelse {
        return try allocator.dupe(u8, "");
    };
    defer url_record.deinit();

    return try allocator.dupe(u8, url_record.password());
}

/// Getter for host
/// Spec: https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-host
/// Returns host:port (port omitted if default for scheme)
pub fn get_host(instance: *runtime.Instance) anyerror!runtime.USVString {
    const allocator = instance.ctx.allocator;

    var url_record = parseElementUrl(instance, allocator) orelse {
        return try allocator.dupe(u8, "");
    };
    defer url_record.deinit();

    // If host is null, return empty string
    const h = url_record.host orelse return try allocator.dupe(u8, "");

    // If port is null, return just the host
    const p = url_record.port orelse {
        return host_serializer.serializeHost(allocator, h);
    };

    // Return host:port
    const host_str = try host_serializer.serializeHost(allocator, h);
    defer allocator.free(host_str);

    return std.fmt.allocPrint(allocator, "{s}:{d}", .{ host_str, p });
}

/// Getter for hostname
/// Spec: https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-hostname
/// Returns just the host (without port)
pub fn get_hostname(instance: *runtime.Instance) anyerror!runtime.USVString {
    const allocator = instance.ctx.allocator;

    var url_record = parseElementUrl(instance, allocator) orelse {
        return try allocator.dupe(u8, "");
    };
    defer url_record.deinit();

    const h = url_record.host orelse return try allocator.dupe(u8, "");
    return host_serializer.serializeHost(allocator, h);
}

/// Getter for port
/// Spec: https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-port
/// Returns the port as a string, or empty string if no port
pub fn get_port(instance: *runtime.Instance) anyerror!runtime.USVString {
    const allocator = instance.ctx.allocator;

    var url_record = parseElementUrl(instance, allocator) orelse {
        return try allocator.dupe(u8, "");
    };
    defer url_record.deinit();

    const p = url_record.port orelse return try allocator.dupe(u8, "");
    return std.fmt.allocPrint(allocator, "{d}", .{p});
}

/// Getter for pathname
/// Spec: https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-pathname
pub fn get_pathname(instance: *runtime.Instance) anyerror!runtime.USVString {
    const allocator = instance.ctx.allocator;

    var url_record = parseElementUrl(instance, allocator) orelse {
        return try allocator.dupe(u8, "");
    };
    defer url_record.deinit();

    return path_serializer.serializePath(allocator, &url_record);
}

/// Getter for search
/// Spec: https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-search
/// Returns "?" followed by query, or empty string if no query
pub fn get_search(instance: *runtime.Instance) anyerror!runtime.USVString {
    const allocator = instance.ctx.allocator;

    var url_record = parseElementUrl(instance, allocator) orelse {
        return try allocator.dupe(u8, "");
    };
    defer url_record.deinit();

    const q = url_record.query() orelse return try allocator.dupe(u8, "");
    if (q.len == 0) return try allocator.dupe(u8, "");

    return std.fmt.allocPrint(allocator, "?{s}", .{q});
}

/// Getter for hash
/// Spec: https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-hash
/// Returns "#" followed by fragment, or empty string if no fragment
pub fn get_hash(instance: *runtime.Instance) anyerror!runtime.USVString {
    const allocator = instance.ctx.allocator;

    var url_record = parseElementUrl(instance, allocator) orelse {
        return try allocator.dupe(u8, "");
    };
    defer url_record.deinit();

    const f = url_record.fragment() orelse return try allocator.dupe(u8, "");
    if (f.len == 0) return try allocator.dupe(u8, "");

    return std.fmt.allocPrint(allocator, "#{s}", .{f});
}

/// Setter for href
/// Spec: https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-href
pub fn set_href(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    // Set the href attribute on the element
    try interfaces.Element.call_setAttribute(
        instance,
        runtime.DOMString.initInterned("href"),
        runtime.DOMString.initDupe(instance.ctx.allocator, value) catch return error.InvalidState,
    );
}

/// Setter for protocol
/// Spec: https://html.spec.whatwg.org/multipage/links.html#dom-hyperlink-protocol
pub fn set_protocol(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    // TODO: Implement protocol setter (parse URL, update scheme, reserialize)
}

/// Setter for username
pub fn set_username(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    // TODO: Implement username setter
}

/// Setter for password
pub fn set_password(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    // TODO: Implement password setter
}

/// Setter for host
pub fn set_host(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    // TODO: Implement host setter
}

/// Setter for hostname
pub fn set_hostname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    // TODO: Implement hostname setter
}

/// Setter for port
pub fn set_port(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    // TODO: Implement port setter
}

/// Setter for pathname
pub fn set_pathname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    // TODO: Implement pathname setter
}

/// Setter for search
pub fn set_search(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    // TODO: Implement search setter
}

/// Setter for hash
pub fn set_hash(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    // TODO: Implement hash setter
}
