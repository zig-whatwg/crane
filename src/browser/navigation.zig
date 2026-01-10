//! Navigation - URL Fetching, HTML Parsing, and Script Execution
//!
//! Implements the navigation algorithm for the browser module.
//! Handles fetching URL content, parsing HTML, and executing scripts.
//!
//! ## Navigation Flow
//!
//! 1. Parse URL and determine scheme
//! 2. Fetch content (HTTP, file://, data:, about:blank)
//! 3. Parse HTML into DOM tree
//! 4. Execute inline and external scripts
//! 5. Fire DOMContentLoaded event
//! 6. Load external resources (stylesheets, images)
//! 7. Fire load event
//!
//! ## Specification References
//!
//! - HTML Standard: https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigate
//! - Fetch Standard: https://fetch.spec.whatwg.org/

const std = @import("std");
const Allocator = std.mem.Allocator;
const v8 = @import("v8");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");

const html_parser = @import("html").parser;
const parser_script_execution = @import("html").parser_script_execution;
const certificate_trust = @import("fetch").network.certificate_trust;

/// Navigation result containing parsed content info
pub const NavigationResult = struct {
    /// HTTP status code (or synthetic for non-HTTP)
    status_code: u16,
    /// Content type (MIME type)
    content_type: []const u8,
    /// Response body
    body: []const u8,
    /// Final URL (after redirects)
    final_url: []const u8,
    /// Allocator used for result
    allocator: Allocator,

    pub fn deinit(self: *NavigationResult) void {
        self.allocator.free(self.body);
        self.allocator.free(self.final_url);
        self.allocator.free(self.content_type);
    }
};

/// Navigation options
pub const NavigationOptions = struct {
    /// HTTP method (default: GET)
    method: []const u8 = "GET",
    /// Request headers
    headers: ?[]const Header = null,
    /// Request body
    body: ?[]const u8 = null,
    /// Timeout in milliseconds (0 = no timeout)
    timeout_ms: u64 = 30000,
    /// Follow redirects
    follow_redirects: bool = true,
    /// Maximum redirects to follow
    max_redirects: u8 = 20,
    /// Certificate trust store for HTTPS (for WPT self-signed certs)
    trust_store: ?*const certificate_trust.CertificateTrustStore = null,

    pub const Header = struct {
        name: []const u8,
        value: []const u8,
    };
};

/// Navigation errors
pub const NavigationError = error{
    /// URL parsing failed
    InvalidUrl,
    /// Network request failed
    NetworkError,
    /// Timeout exceeded
    Timeout,
    /// Too many redirects
    TooManyRedirects,
    /// Unsupported scheme
    UnsupportedScheme,
    /// Response parsing failed
    ParseError,
    /// Out of memory
    OutOfMemory,
    /// Script execution failed
    ScriptError,
    /// File not found (for file:// URLs)
    FileNotFound,
    /// Access denied
    AccessDenied,
};

/// Fetch content from a URL
///
/// Handles different URL schemes:
/// - http:// / https:// - Network fetch via libcurl
/// - file:// - Local filesystem access
/// - data: - Data URL parsing
/// - about:blank - Empty document
pub fn fetchUrl(
    allocator: Allocator,
    url: []const u8,
    options: NavigationOptions,
) NavigationError!NavigationResult {
    // Parse URL to determine scheme
    const scheme = extractScheme(url);

    if (std.mem.eql(u8, scheme, "about")) {
        return fetchAboutUrl(allocator, url);
    } else if (std.mem.eql(u8, scheme, "data")) {
        return fetchDataUrl(allocator, url);
    } else if (std.mem.eql(u8, scheme, "file")) {
        return fetchFileUrl(allocator, url);
    } else if (std.mem.eql(u8, scheme, "http") or std.mem.eql(u8, scheme, "https")) {
        return fetchHttpUrl(allocator, url, options);
    } else {
        return NavigationError.UnsupportedScheme;
    }
}

/// Fetch about: URLs (about:blank, about:srcdoc, etc.)
fn fetchAboutUrl(allocator: Allocator, url: []const u8) NavigationError!NavigationResult {
    const path = if (std.mem.indexOf(u8, url, ":")) |pos| url[pos + 1 ..] else "";

    if (std.mem.eql(u8, path, "blank") or path.len == 0) {
        // about:blank returns empty HTML document
        const body = try allocator.dupe(u8, "<!DOCTYPE html><html><head></head><body></body></html>");
        errdefer allocator.free(body);

        const final_url = try allocator.dupe(u8, url);
        errdefer allocator.free(final_url);

        const content_type = try allocator.dupe(u8, "text/html;charset=utf-8");

        return NavigationResult{
            .status_code = 200,
            .content_type = content_type,
            .body = body,
            .final_url = final_url,
            .allocator = allocator,
        };
    }

    // Other about: URLs not supported
    return NavigationError.UnsupportedScheme;
}

/// Fetch data: URLs
fn fetchDataUrl(allocator: Allocator, url: []const u8) NavigationError!NavigationResult {
    // Parse data URL: data:[<mediatype>][;base64],<data>
    const data_start = std.mem.indexOf(u8, url, ":") orelse return NavigationError.InvalidUrl;
    const rest = url[data_start + 1 ..];

    // Find comma separating metadata from data
    const comma_pos = std.mem.indexOf(u8, rest, ",") orelse return NavigationError.InvalidUrl;
    const metadata = rest[0..comma_pos];
    const encoded_data = rest[comma_pos + 1 ..];

    // Parse metadata
    var content_type: []const u8 = "text/plain;charset=US-ASCII";
    var is_base64 = false;

    if (metadata.len > 0) {
        // Check for base64 encoding
        if (std.mem.endsWith(u8, metadata, ";base64")) {
            is_base64 = true;
            const mime_part = metadata[0 .. metadata.len - 7];
            if (mime_part.len > 0) {
                content_type = mime_part;
            }
        } else {
            content_type = metadata;
        }
    }

    // Decode data
    var body: []u8 = undefined;
    if (is_base64) {
        // Base64 decode
        const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(encoded_data) catch {
            return NavigationError.ParseError;
        };
        body = try allocator.alloc(u8, decoded_len);
        errdefer allocator.free(body);

        _ = std.base64.standard.Decoder.decode(body, encoded_data) catch {
            allocator.free(body);
            return NavigationError.ParseError;
        };
    } else {
        // URL decode
        body = try percentDecode(allocator, encoded_data);
    }
    errdefer allocator.free(body);

    const final_url = try allocator.dupe(u8, url);
    errdefer allocator.free(final_url);

    const ct = try allocator.dupe(u8, content_type);

    return NavigationResult{
        .status_code = 200,
        .content_type = ct,
        .body = body,
        .final_url = final_url,
        .allocator = allocator,
    };
}

/// Fetch file:// URLs
fn fetchFileUrl(allocator: Allocator, url: []const u8) NavigationError!NavigationResult {
    // Extract path from file:// URL
    const path = if (std.mem.startsWith(u8, url, "file://")) blk: {
        var p = url[7..];
        // Handle file:///path (triple slash for absolute path)
        if (std.mem.startsWith(u8, p, "/")) {
            break :blk p;
        }
        // Handle file://localhost/path
        if (std.mem.startsWith(u8, p, "localhost/")) {
            break :blk p[9..];
        }
        break :blk p;
    } else url;

    // URL decode the path
    const decoded_path = percentDecode(allocator, path) catch return NavigationError.OutOfMemory;
    defer allocator.free(decoded_path);

    // Read file
    const file = std.fs.openFileAbsolute(decoded_path, .{}) catch |err| {
        return switch (err) {
            error.FileNotFound => NavigationError.FileNotFound,
            error.AccessDenied => NavigationError.AccessDenied,
            else => NavigationError.NetworkError,
        };
    };
    defer file.close();

    const stat = file.stat() catch return NavigationError.NetworkError;
    const body = allocator.alloc(u8, stat.size) catch return NavigationError.OutOfMemory;
    errdefer allocator.free(body);

    const bytes_read = file.readAll(body) catch return NavigationError.NetworkError;
    if (bytes_read != stat.size) {
        allocator.free(body);
        return NavigationError.NetworkError;
    }

    // Guess content type from extension
    const content_type = guessContentType(path);
    const ct = try allocator.dupe(u8, content_type);
    errdefer allocator.free(ct);

    const final_url = try allocator.dupe(u8, url);

    return NavigationResult{
        .status_code = 200,
        .content_type = ct,
        .body = body,
        .final_url = final_url,
        .allocator = allocator,
    };
}

/// Fetch HTTP/HTTPS URLs via libcurl
///
/// Note: This implementation uses the fetch module when available (full build),
/// or returns a stub response for testing.
fn fetchHttpUrl(
    allocator: Allocator,
    url: []const u8,
    options: NavigationOptions,
) NavigationError!NavigationResult {
    std.debug.print("[FETCH_HTTP] Fetching URL: {s}\n", .{url});

    // For HTTP URLs, we need to use libcurl which is set up in the full build.
    // In the browser module context, we'll use the fetch module via imports.
    // For standalone testing, return a stub indicating HTTP is not available.

    // Try to use the fetch module if available through the build system
    const fetch_mod = @import("fetch");
    const fetch_internal = fetch_mod.internal;
    const InternalRequest = fetch_internal.InternalRequest;

    var request = InternalRequest.init(allocator, url) catch return NavigationError.OutOfMemory;
    defer request.deinit();

    // Perform fetch using the fetch algorithms, passing through certificate trust store
    var result = fetch_mod.algorithms.fetch(allocator, request, .{
        .trust_store = options.trust_store,
    }) catch |err| {
        std.debug.print("[FETCH_HTTP] Fetch error: {}\n", .{err});
        return switch (err) {
            error.NetworkError => NavigationError.NetworkError,
            error.AbortError => NavigationError.Timeout,
            error.OutOfMemory => NavigationError.OutOfMemory,
        };
    };
    defer result.timing_info.deinit();

    const response = result.response;
    defer response.deinit();

    std.debug.print("[FETCH_HTTP] Response status: {d}, has_body: {}\n", .{ response.status, response.body != null });

    // Extract body
    const body = if (response.body) |b| blk: {
        const data = b.getBytes();
        std.debug.print("[FETCH_HTTP] Body bytes: {d}\n", .{data.len});
        break :blk try allocator.dupe(u8, data);
    } else blk: {
        std.debug.print("[FETCH_HTTP] No body in response\n", .{});
        break :blk try allocator.dupe(u8, "");
    };
    errdefer allocator.free(body);

    // Extract content type
    const ct = response.header_list.getFirstValue("Content-Type") orelse "text/html";
    const content_type = try allocator.dupe(u8, ct);
    errdefer allocator.free(content_type);

    const final_url = try allocator.dupe(u8, url);

    return NavigationResult{
        .status_code = response.status,
        .content_type = content_type,
        .body = body,
        .final_url = final_url,
        .allocator = allocator,
    };
}

/// Parse HTML content and return a document tree
pub fn parseHtml(
    allocator: Allocator,
    html: []const u8,
    base_url: []const u8,
) !*html_parser.TreeBuilder {
    _ = base_url; // TODO: Use for resolving relative URLs

    // Create tokenizer
    var tokenizer = html_parser.Tokenizer.init(allocator);
    defer tokenizer.deinit();

    // Feed HTML to tokenizer
    tokenizer.feed(html);

    // Create tree builder
    var tree_builder = try html_parser.TreeBuilder.init(allocator);
    errdefer tree_builder.deinit();

    // Set up script execution callback for during-parse script execution
    // This is critical for proper script execution order per HTML spec
    tree_builder.setScriptExecutionCallback(
        parser_script_execution.parserScriptCallback,
        null, // context - not needed for this callback
    );

    // Process tokens
    while (tokenizer.next()) |token| {
        try tree_builder.processToken(token);
    }

    return tree_builder;
}

/// Execute scripts in the parsed document
pub fn executeScripts(
    allocator: Allocator,
    tree_builder: *html_parser.TreeBuilder,
    isolate: *v8.ffi.Isolate,
    context: *v8.ffi.Context,
) !void {
    _ = allocator;

    // Find all script elements
    const doc = tree_builder.document orelse return;

    // Process script elements in document order
    try executeScriptsInSubtree(doc, isolate, context);
}

fn executeScriptsInSubtree(
    node: *html_parser.TreeNode,
    isolate: *v8.ffi.Isolate,
    context: *v8.ffi.Context,
) !void {
    // Check if this is a script element
    if (node.node_type == .element) {
        if (node.local_name) |name| {
            if (std.mem.eql(u8, name, "script")) {
                try executeScriptElement(node, isolate, context);
            }
        }
    }

    // Recurse to children
    var child = node.first_child;
    while (child) |c| {
        try executeScriptsInSubtree(c, isolate, context);
        child = c.next_sibling;
    }
}

fn executeScriptElement(
    script_node: *html_parser.TreeNode,
    isolate: *v8.ffi.Isolate,
    context: *v8.ffi.Context,
) !void {
    // Get script content from child text nodes
    var script_content = std.ArrayList(u8).init(script_node.allocator);
    defer script_content.deinit();

    var child = script_node.first_child;
    while (child) |c| {
        if (c.node_type == .text) {
            const text = c.text_content.items;
            try script_content.appendSlice(text);
        }
        child = c.next_sibling;
    }

    if (script_content.items.len == 0) return;

    // Execute the script
    const source_str = v8.ffi.v8_String_NewFromUtf8(
        isolate,
        script_content.items.ptr,
        @intCast(script_content.items.len),
    ) orelse return;

    const compiled = v8.ffi.v8_Script_Compile(context, source_str) orelse return;
    _ = v8.ffi.v8_Script_Run(context, compiled);

    // Run microtasks
    v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);
}

/// Fire DOMContentLoaded event
pub fn fireDOMContentLoaded(
    _: std.mem.Allocator,
    document_instance: *runtime.Instance,
) void {
    // Fire DOMContentLoaded event directly from Zig (not through JavaScript)
    // Per HTML spec, DOMContentLoaded fires on document, bubbles, not cancelable
    // Use call_constructor to properly initialize internal state (including path for dispatch)
    const event_type = runtime.DOMString.initInterned("DOMContentLoaded");
    const event_init = dictionaries.EventInit{
        .bubbles = true,
        .cancelable = false,
        .composed = false,
    };
    const event = interfaces.Event.call_constructor(document_instance.ctx, event_type, webidl.Opt(dictionaries.EventInit).passed(event_init)) catch |err| {
        std.debug.print("[fireDOMContentLoaded] Failed to create event: {}\n", .{err});
        return;
    };
    defer interfaces.Event.deinit(event);

    _ = interfaces.EventTarget.call_dispatchEvent(document_instance, event) catch |err| {
        std.debug.print("[fireDOMContentLoaded] Failed to dispatch event: {}\n", .{err});
        return;
    };
}

/// Fire load event
pub fn fireLoad(
    _: std.mem.Allocator,
    window_instance: *runtime.Instance,
) void {
    std.debug.print("[fireLoad] Starting - dispatching load event to window\n", .{});

    // Fire load event directly from Zig (not through JavaScript)
    // Per HTML spec, load fires on window, does not bubble, not cancelable
    // Use call_constructor to properly initialize internal state (including path for dispatch)
    const event_type = runtime.DOMString.initInterned("load");
    const event_init = dictionaries.EventInit{
        .bubbles = false,
        .cancelable = false,
        .composed = false,
    };
    const event = interfaces.Event.call_constructor(window_instance.ctx, event_type, webidl.Opt(dictionaries.EventInit).passed(event_init)) catch |err| {
        std.debug.print("[fireLoad] Failed to create event: {}\n", .{err});
        return;
    };
    defer interfaces.Event.deinit(event);

    std.debug.print("[fireLoad] Event created, dispatching...\n", .{});
    const result = interfaces.EventTarget.call_dispatchEvent(window_instance, event) catch |err| {
        std.debug.print("[fireLoad] Failed to dispatch event: {}\n", .{err});
        return;
    };
    std.debug.print("[fireLoad] Dispatch complete, result: {}\n", .{result});
}

// =============================================================================
// Helper Functions
// =============================================================================

fn extractScheme(url: []const u8) []const u8 {
    const colon_pos = std.mem.indexOf(u8, url, ":");
    if (colon_pos) |pos| {
        return url[0..pos];
    }
    return "";
}

fn percentDecode(allocator: Allocator, input: []const u8) ![]u8 {
    var result = std.ArrayListUnmanaged(u8){};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        if (input[i] == '%' and i + 2 < input.len) {
            const hex = input[i + 1 .. i + 3];
            const byte = std.fmt.parseInt(u8, hex, 16) catch {
                try result.append(allocator, input[i]);
                i += 1;
                continue;
            };
            try result.append(allocator, byte);
            i += 3;
        } else if (input[i] == '+') {
            try result.append(allocator, ' ');
            i += 1;
        } else {
            try result.append(allocator, input[i]);
            i += 1;
        }
    }

    return result.toOwnedSlice(allocator);
}

fn guessContentType(path: []const u8) []const u8 {
    // Get file extension
    const ext = blk: {
        const last_dot = std.mem.lastIndexOf(u8, path, ".");
        if (last_dot) |pos| {
            break :blk path[pos..];
        }
        break :blk "";
    };

    if (std.mem.eql(u8, ext, ".html") or std.mem.eql(u8, ext, ".htm")) {
        return "text/html;charset=utf-8";
    } else if (std.mem.eql(u8, ext, ".js")) {
        return "text/javascript;charset=utf-8";
    } else if (std.mem.eql(u8, ext, ".css")) {
        return "text/css;charset=utf-8";
    } else if (std.mem.eql(u8, ext, ".json")) {
        return "application/json;charset=utf-8";
    } else if (std.mem.eql(u8, ext, ".xml")) {
        return "application/xml;charset=utf-8";
    } else if (std.mem.eql(u8, ext, ".txt")) {
        return "text/plain;charset=utf-8";
    } else if (std.mem.eql(u8, ext, ".png")) {
        return "image/png";
    } else if (std.mem.eql(u8, ext, ".jpg") or std.mem.eql(u8, ext, ".jpeg")) {
        return "image/jpeg";
    } else if (std.mem.eql(u8, ext, ".gif")) {
        return "image/gif";
    } else if (std.mem.eql(u8, ext, ".svg")) {
        return "image/svg+xml";
    } else {
        return "application/octet-stream";
    }
}

// =============================================================================
// Tests
// =============================================================================

test "navigation - about:blank" {
    const allocator = std.testing.allocator;

    var result = try fetchUrl(allocator, "about:blank", .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(u16, 200), result.status_code);
    try std.testing.expectEqualStrings("text/html;charset=utf-8", result.content_type);
    try std.testing.expect(result.body.len > 0);
}

test "navigation - data URL text" {
    const allocator = std.testing.allocator;

    var result = try fetchUrl(allocator, "data:text/plain,Hello%20World", .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(u16, 200), result.status_code);
    try std.testing.expectEqualStrings("text/plain", result.content_type);
    try std.testing.expectEqualStrings("Hello World", result.body);
}

test "navigation - data URL base64" {
    const allocator = std.testing.allocator;

    // "Hello" in base64 is "SGVsbG8="
    var result = try fetchUrl(allocator, "data:text/plain;base64,SGVsbG8=", .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(u16, 200), result.status_code);
    try std.testing.expectEqualStrings("Hello", result.body);
}

test "navigation - extract scheme" {
    try std.testing.expectEqualStrings("https", extractScheme("https://example.com"));
    try std.testing.expectEqualStrings("http", extractScheme("http://example.com"));
    try std.testing.expectEqualStrings("file", extractScheme("file:///path"));
    try std.testing.expectEqualStrings("data", extractScheme("data:text/plain,Hello"));
    try std.testing.expectEqualStrings("about", extractScheme("about:blank"));
}

test "navigation - percent decode" {
    const allocator = std.testing.allocator;

    const decoded = try percentDecode(allocator, "Hello%20World%21");
    defer allocator.free(decoded);

    try std.testing.expectEqualStrings("Hello World!", decoded);
}

test "navigation - guess content type" {
    try std.testing.expectEqualStrings("text/html;charset=utf-8", guessContentType("page.html"));
    try std.testing.expectEqualStrings("text/javascript;charset=utf-8", guessContentType("script.js"));
    try std.testing.expectEqualStrings("text/css;charset=utf-8", guessContentType("style.css"));
    try std.testing.expectEqualStrings("application/json;charset=utf-8", guessContentType("data.json"));
    try std.testing.expectEqualStrings("image/png", guessContentType("image.png"));
}
