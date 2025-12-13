//! IFrame Browsing Context Integration - HTML Standard §7.5
//!
//! This module handles the lifecycle management of browsing contexts for iframe elements.
//! When an iframe is inserted into the DOM, a nested browsing context is created.
//! When removed, the browsing context is destroyed.
//!
//! Spec: https://html.spec.whatwg.org/multipage/iframe-embed-object.html
//!
//! ## Key Algorithms
//!
//! - Create a nested browsing context (§7.1)
//! - Process the iframe attributes (src, srcdoc, sandbox)
//! - Navigate to the initial URL or create about:blank
//!
//! ## Architecture
//!
//! IFrameIntegration provides the glue between:
//! - HTMLIFrameElement (the DOM element)
//! - BrowsingContext (the environment for documents)
//! - WindowProxy (the cross-origin access control)

const std = @import("std");
const Allocator = std.mem.Allocator;
const browsing_context = @import("browsing_context.zig");
const BrowsingContext = browsing_context.BrowsingContext;
const SandboxFlags = browsing_context.SandboxFlags;
const WindowProxy = @import("window_proxy.zig").WindowProxy;
const Origin = @import("window_proxy.zig").Origin;
const encoding_mod = @import("encoding");
const html_parser = @import("../parser/root.zig");

/// Error types for iframe integration
pub const IFrameError = error{
    /// Failed to create browsing context
    ContextCreationFailed,
    /// Navigation failed
    NavigationFailed,
    /// Invalid src URL
    InvalidURL,
    /// Sandbox policy violation
    SandboxViolation,
    /// Out of memory
    OutOfMemory,
    /// Failed to read file
    FileReadError,
    /// Unsupported URL scheme
    UnsupportedScheme,
    /// Parse error during HTML parsing
    ParseError,
};

/// State of the iframe's nested browsing context
pub const IFrameState = enum {
    /// No browsing context yet (element not in document)
    uninitialized,
    /// Browsing context exists, navigating to about:blank
    creating_initial_document,
    /// Initial about:blank document loaded
    initial_document_ready,
    /// Navigating to src or srcdoc content
    navigating,
    /// Content loaded and ready
    ready,
    /// Browsing context discarded (element removed from document)
    discarded,
};

/// Result of fetching content from a URL
pub const FetchedContent = struct {
    /// The raw bytes fetched
    bytes: []u8,
    /// Content-Type header value (null if not available)
    content_type: ?[]u8,
    /// Allocator used for bytes (for cleanup)
    allocator: Allocator,

    pub fn deinit(self: *FetchedContent) void {
        self.allocator.free(self.bytes);
        if (self.content_type) |ct| {
            self.allocator.free(ct);
        }
    }
};

// ============================================================================
// Encoding Detection - HTML Standard §13.2.3.2
// ============================================================================

/// Detect encoding from BOM and Content-Type header
/// Per HTML Standard §13.2.3.2 "Determining the character encoding"
///
/// The algorithm checks in order:
/// 1. BOM (Byte Order Mark)
/// 2. Content-Type header charset parameter
/// 3. Default to UTF-8
pub fn detectEncoding(bytes: []const u8, content_type: ?[]const u8) *const encoding_mod.Encoding {
    // Step 1: Check for BOM
    if (encoding_mod.bom.sniff(bytes)) |bom_encoding| {
        return switch (bom_encoding) {
            .utf8 => encoding_mod.UTF_8,
            .utf16be => &encoding_mod.encoding.UTF_16BE,
            .utf16le => &encoding_mod.encoding.UTF_16LE,
        };
    }

    // Step 2: Check Content-Type header charset
    if (content_type) |ct| {
        if (parseCharsetFromContentType(ct)) |charset| {
            if (encoding_mod.getEncoding(charset)) |enc| {
                return enc;
            }
        }
    }

    // Step 3: Default to UTF-8
    return encoding_mod.UTF_8;
}

/// Percent-decode a string (simplified URL decoding)
/// Decodes %XX sequences to their byte values
fn percentDecode(allocator: Allocator, input: []const u8) ![]u8 {
    // Calculate output size (will be <= input size)
    var output_size: usize = 0;
    var i: usize = 0;
    while (i < input.len) {
        if (input[i] == '%' and i + 2 < input.len) {
            // Check if next two chars are hex digits
            if (std.fmt.parseInt(u8, input[i + 1 .. i + 3], 16)) |_| {
                output_size += 1;
                i += 3;
                continue;
            } else |_| {}
        }
        output_size += 1;
        i += 1;
    }

    const output = try allocator.alloc(u8, output_size);
    errdefer allocator.free(output);

    i = 0;
    var j: usize = 0;
    while (i < input.len) {
        if (input[i] == '%' and i + 2 < input.len) {
            if (std.fmt.parseInt(u8, input[i + 1 .. i + 3], 16)) |byte| {
                output[j] = byte;
                j += 1;
                i += 3;
                continue;
            } else |_| {}
        }
        output[j] = input[i];
        j += 1;
        i += 1;
    }

    return output;
}

/// Parse charset parameter from Content-Type header
/// Handles formats like:
/// - "text/html; charset=utf-8"
/// - "text/html;charset=utf-8"
/// - "text/html; charset=\"utf-8\""
pub fn parseCharsetFromContentType(content_type: []const u8) ?[]const u8 {
    // Look for "charset=" (case-insensitive)
    var lower_buf: [256]u8 = undefined;
    const len = @min(content_type.len, lower_buf.len);
    for (content_type[0..len], 0..) |c, idx| {
        lower_buf[idx] = std.ascii.toLower(c);
    }
    const lower = lower_buf[0..len];

    // Find "charset="
    const charset_prefix = "charset=";
    const idx = std.mem.indexOf(u8, lower, charset_prefix) orelse return null;

    // Extract the value
    const value_start = idx + charset_prefix.len;
    if (value_start >= content_type.len) return null;

    var value = content_type[value_start..];

    // Handle quoted value
    if (value.len > 0 and (value[0] == '"' or value[0] == '\'')) {
        const quote = value[0];
        value = value[1..];
        if (std.mem.indexOfScalar(u8, value, quote)) |end_quote| {
            return value[0..end_quote];
        }
        return value; // No closing quote, return rest
    }

    // Find end of value (semicolon, space, or end of string)
    for (value, 0..) |c, vi| {
        if (c == ';' or c == ' ' or c == '\t') {
            return value[0..vi];
        }
    }

    return value;
}

/// Integration state for an iframe element
/// This struct manages the relationship between HTMLIFrameElement and BrowsingContext
pub const IFrameIntegration = struct {
    /// Allocator for this integration's resources
    allocator: Allocator,

    /// The nested browsing context (null until element is inserted)
    browsing_context: ?*BrowsingContext,

    /// The WindowProxy for accessing the nested window
    window_proxy: ?WindowProxy,

    /// Current state of the iframe
    state: IFrameState,

    /// The parent browsing context (container document's context)
    parent_context: ?*BrowsingContext,

    /// Cached src URL (null if no src attribute)
    src_url: ?[]const u8,

    /// Cached srcdoc content (null if no srcdoc attribute)
    srcdoc_content: ?[]const u8,

    /// The iframe's name attribute
    name: []const u8,

    /// Origin of the container document (for same-origin checks)
    container_origin: Origin,

    /// Sandbox flags for this iframe (null if no sandbox attribute)
    sandbox_flags: ?SandboxFlags,

    /// Whether this iframe is sandboxed
    is_sandboxed: bool,

    // ========================================================================
    // Cross-Realm Support (Phase 3)
    // ========================================================================
    //
    // Engine-agnostic fields for cross-realm support.
    // V8-specific context creation is handled by the module with V8 access
    // (e.g., HTMLIFrameElement impl) using the setRealmContext method.

    /// Opaque pointer to the engine-specific context (e.g., V8 Context*)
    /// Set by modules with engine access (e.g., impls/HTMLIFrameElement.zig)
    engine_context: ?*anyopaque,

    /// Opaque pointer to the realm (e.g., runtime.Realm*)
    /// Contains intrinsics, global object, etc.
    realm: ?*anyopaque,

    /// Opaque pointer to cleanup data (e.g., ContextEntry* for cleanup)
    context_cleanup_data: ?*anyopaque,

    /// Callback to clean up the realm and context
    /// Set by the module that created the context
    cleanup_callback: ?*const fn (*IFrameIntegration) void,

    /// Guard flag to prevent recursive cleanup during context teardown
    /// Set to true when cleanupRealmContext is entered
    cleanup_in_progress: bool,

    /// Create a new IFrameIntegration (element not yet in document)
    pub fn init(allocator: Allocator) IFrameIntegration {
        return .{
            .allocator = allocator,
            .browsing_context = null,
            .window_proxy = null,
            .state = .uninitialized,
            .parent_context = null,
            .src_url = null,
            .srcdoc_content = null,
            .name = "",
            .container_origin = Origin.createOpaque(),
            .sandbox_flags = null,
            .is_sandboxed = false,
            // Cross-realm fields (engine-agnostic)
            .engine_context = null,
            .realm = null,
            .context_cleanup_data = null,
            .cleanup_callback = null,
            .cleanup_in_progress = false,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *IFrameIntegration) void {
        // Clean up engine-specific context (Phase 3)
        self.cleanupRealmContext();

        // Destroy the browsing context if it exists
        if (self.browsing_context) |ctx| {
            ctx.deinit();
        }

        // Free allocated strings
        if (self.src_url) |url| {
            self.allocator.free(url);
        }
        if (self.srcdoc_content) |content| {
            self.allocator.free(content);
        }
        if (self.name.len > 0) {
            self.allocator.free(self.name);
        }
    }

    // ========================================================================
    // Realm and Context Management (Phase 3: Cross-Realm Support)
    // ========================================================================
    //
    // Engine-agnostic interface for realm/context management.
    // Actual V8-specific implementation is in HTMLIFrameElement impl.

    /// Set the realm context data (called from engine-specific code)
    ///
    /// This is called by modules with V8 access (e.g., HTMLIFrameElement impl)
    /// to associate engine-specific context data with this integration.
    ///
    /// Parameters:
    /// - context: Opaque pointer to engine context (e.g., V8 Context*)
    /// - realm_ptr: Opaque pointer to realm (e.g., runtime.Realm*)
    /// - cleanup_data: Opaque pointer to cleanup data (e.g., ContextEntry*)
    /// - cleanup_fn: Callback to clean up context when iframe is removed
    pub fn setRealmContext(
        self: *IFrameIntegration,
        context: ?*anyopaque,
        realm_ptr: ?*anyopaque,
        cleanup_data: ?*anyopaque,
        cleanup_fn: ?*const fn (*IFrameIntegration) void,
    ) void {
        self.engine_context = context;
        self.realm = realm_ptr;
        self.context_cleanup_data = cleanup_data;
        self.cleanup_callback = cleanup_fn;
    }

    /// Clean up the realm and engine context
    fn cleanupRealmContext(self: *IFrameIntegration) void {
        // Guard against recursive cleanup during context teardown
        // This can happen when:
        // 1. context_manager.deinit() cleans up wrapper cache
        // 2. Wrapper cache cleanup triggers HTMLIFrameElement.deinit()
        // 3. HTMLIFrameElement.deinit() calls integration.deinit()
        // 4. integration.deinit() calls cleanupRealmContext()
        // 5. cleanupRealmContext() tries to call destroyChildContext()
        //    which is already being torn down by context_manager.deinit()
        if (self.cleanup_in_progress) return;
        self.cleanup_in_progress = true;

        if (self.cleanup_callback) |callback| {
            callback(self);
        }
        self.engine_context = null;
        self.realm = null;
        self.context_cleanup_data = null;
        self.cleanup_callback = null;
        // Note: cleanup_in_progress stays true to prevent any further cleanup attempts
    }

    /// Get the realm for this iframe (as opaque pointer)
    ///
    /// Returns the Realm associated with this iframe's browsing context.
    /// The caller is responsible for casting to the correct type.
    pub fn getRealmOpaque(self: *IFrameIntegration) ?*anyopaque {
        return self.realm;
    }

    /// Get the engine context (as opaque pointer)
    ///
    /// Returns the engine-specific context (e.g., V8 Context).
    /// The caller is responsible for casting to the correct type.
    pub fn getEngineContext(self: *IFrameIntegration) ?*anyopaque {
        return self.engine_context;
    }

    /// Check if this iframe has a realm context
    pub fn hasRealmContext(self: *const IFrameIntegration) bool {
        return self.realm != null;
    }

    /// Called when iframe is inserted into a document
    /// Creates the nested browsing context per HTML §7.5.4
    pub fn onInsertedIntoDocument(
        self: *IFrameIntegration,
        parent_ctx: *BrowsingContext,
        container_origin: Origin,
    ) IFrameError!void {
        if (self.state != .uninitialized) {
            // Already initialized - this shouldn't happen but handle gracefully
            return;
        }

        self.parent_context = parent_ctx;
        self.container_origin = container_origin;

        // Create the nested browsing context
        const nested_ctx = BrowsingContext.initChild(self.allocator, parent_ctx) catch {
            return IFrameError.ContextCreationFailed;
        };

        self.browsing_context = nested_ctx;

        // Set the target name if we have one
        if (self.name.len > 0) {
            nested_ctx.setTargetName(self.name) catch {
                return IFrameError.OutOfMemory;
            };
        }

        // Create the WindowProxy
        self.window_proxy = WindowProxy.init(self.allocator, nested_ctx);

        self.state = .creating_initial_document;

        // Navigate to initial content
        try self.navigateToInitialContent();
    }

    /// Called when iframe is removed from a document
    /// Destroys the nested browsing context per HTML §7.1
    pub fn onRemovedFromDocument(self: *IFrameIntegration) void {
        // Clean up engine-specific realm context first (Phase 3)
        self.cleanupRealmContext();

        if (self.browsing_context) |ctx| {
            // Close the browsing context (marks as discarded)
            ctx.close();
            // Deinit will happen when IFrameIntegration is cleaned up
        }
        self.state = .discarded;
    }

    /// Navigate to the initial content based on src/srcdoc attributes
    fn navigateToInitialContent(self: *IFrameIntegration) IFrameError!void {
        // Per spec: srcdoc takes precedence over src
        if (self.srcdoc_content) |content| {
            try self.navigateToSrcdoc(content);
            return;
        }

        if (self.src_url) |url| {
            try self.navigateToSrc(url);
            return;
        }

        // No src or srcdoc - navigate to about:blank
        try self.navigateToAboutBlank();
    }

    /// Navigate to about:blank
    fn navigateToAboutBlank(self: *IFrameIntegration) IFrameError!void {
        // Set the origin to inherit from container document
        // Per spec, about:blank inherits origin from container
        if (self.window_proxy) |*proxy| {
            proxy.setDocumentOrigin(self.container_origin);
        }

        self.state = .initial_document_ready;
        // In a full implementation, we would create the about:blank Document here
        // For now, we just mark the state
    }

    /// Navigate to srcdoc content
    /// Per HTML Standard §4.8.5.1 - srcdoc attribute processing
    ///
    /// srcdoc content is always treated as UTF-8 since it comes from the
    /// parent document's parsing (which normalizes to UTF-8).
    fn navigateToSrcdoc(self: *IFrameIntegration, content: []const u8) IFrameError!void {
        // srcdoc documents inherit origin from container
        if (self.window_proxy) |*proxy| {
            proxy.setDocumentOrigin(self.container_origin);
        }

        self.state = .navigating;

        // Parse the srcdoc HTML content using UTF-8 encoding (always)
        // Per spec, srcdoc content has already been parsed by the parent document
        // so it's guaranteed to be valid UTF-8
        const tree_builder = html_parser.parseHTMLFromString(self.allocator, content) catch {
            self.state = .ready;
            return IFrameError.ParseError;
        };
        defer {
            tree_builder.deinit();
            self.allocator.destroy(tree_builder);
        }

        // TODO: Convert TreeBuilder.document to runtime.Instance when we have
        // full Document interface implementation. The parsed DOM tree exists
        // in tree_builder.document but we need runtime.Instance for storage.
        //
        // When Document interface is fully implemented:
        //   const doc = try createDocumentFromTreeBuilder(self.allocator, tree_builder);
        //   const window = try createWindowForDocument(self.allocator, doc);
        //   if (self.browsing_context) |ctx| {
        //       ctx.setActiveDocument(doc, window);
        //   }

        self.state = .ready;
    }

    /// Navigate to src URL
    /// Per HTML Standard §7.4.2 - Navigate algorithm
    ///
    /// This function:
    /// 1. Resolves the URL
    /// 2. Fetches the content (for file:// URLs, reads from disk)
    /// 3. Detects encoding (BOM → Content-Type → default UTF-8)
    /// 4. Parses the HTML content
    /// 5. Stores the parsed Document in the browsing context
    fn navigateToSrc(self: *IFrameIntegration, url: []const u8) IFrameError!void {
        self.state = .navigating;

        // Parse the URL to determine origin
        const new_origin = self.parseOriginFromURL(url);

        if (self.window_proxy) |*proxy| {
            proxy.setDocumentOrigin(new_origin);
        }

        // Determine the URL scheme and fetch content
        var content: FetchedContent = undefined;

        if (std.mem.startsWith(u8, url, "file://")) {
            // File URL - read from local filesystem
            content = self.fetchFileContent(url) catch {
                self.state = .ready;
                return IFrameError.FileReadError;
            };
        } else if (std.mem.startsWith(u8, url, "data:")) {
            // data: URL - parse the data URL
            content = self.parseDataUrl(url) catch {
                self.state = .ready;
                return IFrameError.InvalidURL;
            };
        } else if (std.mem.startsWith(u8, url, "http://") or std.mem.startsWith(u8, url, "https://")) {
            // HTTP(S) URLs - not implemented yet, would need fetch API
            // For now, mark as ready without loading (stub behavior)
            self.state = .ready;
            return;
        } else if (std.mem.startsWith(u8, url, "about:")) {
            // about: URLs are handled by navigateToAboutBlank
            self.state = .ready;
            return;
        } else {
            // Unsupported scheme
            self.state = .ready;
            return IFrameError.UnsupportedScheme;
        }
        defer content.deinit();

        // Detect encoding from BOM and Content-Type
        const detected_encoding = detectEncoding(content.bytes, content.content_type);

        // Parse the HTML content
        // Note: For now, we parse but don't create runtime.Instance objects
        // The tree builder creates TreeNode objects which represent the DOM structure
        // Full integration with runtime.Instance will be done when we have
        // Document/Window WebIDL interface implementations
        const tree_builder = html_parser.parseHTMLFromString(self.allocator, content.bytes) catch {
            self.state = .ready;
            return IFrameError.ParseError;
        };
        defer {
            tree_builder.deinit();
            self.allocator.destroy(tree_builder);
        }

        // Store encoding info for potential use by scripts
        _ = detected_encoding;

        // TODO: Convert TreeBuilder.document to runtime.Instance when we have
        // full Document interface implementation. For now, the parsed DOM tree
        // exists in tree_builder.document (TreeNode) but we can't store it
        // in browsing_context.active_document (requires runtime.Instance).
        //
        // When Document interface is fully implemented:
        //   const doc = try createDocumentFromTreeBuilder(self.allocator, tree_builder);
        //   const window = try createWindowForDocument(self.allocator, doc);
        //   if (self.browsing_context) |ctx| {
        //       ctx.setActiveDocument(doc, window);
        //   }

        self.state = .ready;
    }

    /// Fetch content from a file:// URL
    fn fetchFileContent(self: *IFrameIntegration, url: []const u8) !FetchedContent {
        // Extract file path from file:// URL
        var file_path: []const u8 = undefined;

        if (std.mem.startsWith(u8, url, "file:///")) {
            // file:///path/to/file -> /path/to/file
            file_path = url[7..];
        } else if (std.mem.startsWith(u8, url, "file://")) {
            // file://host/path (network path) - not supported
            return error.UnsupportedScheme;
        } else {
            return error.InvalidURL;
        }

        // Read the file
        const file = std.fs.cwd().openFile(file_path, .{}) catch {
            return error.FileReadError;
        };
        defer file.close();

        // Read up to 10MB (reasonable limit for iframe content)
        const max_size = 10 * 1024 * 1024;
        const bytes = file.readToEndAlloc(self.allocator, max_size) catch {
            return error.FileReadError;
        };

        // Try to read .headers file for Content-Type
        var content_type: ?[]u8 = null;
        const headers_path = std.fmt.allocPrint(self.allocator, "{s}.headers", .{file_path}) catch null;
        if (headers_path) |hp| {
            defer self.allocator.free(hp);
            content_type = self.readContentTypeFromHeadersFile(hp);
        }

        return FetchedContent{
            .bytes = bytes,
            .content_type = content_type,
            .allocator = self.allocator,
        };
    }

    /// Read Content-Type from a .headers file (WPT convention)
    /// Format: "Content-Type: text/html; charset=big5"
    fn readContentTypeFromHeadersFile(self: *IFrameIntegration, headers_path: []const u8) ?[]u8 {
        const file = std.fs.cwd().openFile(headers_path, .{}) catch return null;
        defer file.close();

        // Read headers file (usually small)
        var buf: [4096]u8 = undefined;
        const bytes_read = file.read(&buf) catch return null;
        const content = buf[0..bytes_read];

        // Parse Content-Type header
        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, &[_]u8{ ' ', '\t', '\r' });
            if (std.ascii.startsWithIgnoreCase(trimmed, "content-type:")) {
                const value = std.mem.trim(u8, trimmed["content-type:".len..], &[_]u8{ ' ', '\t' });
                return self.allocator.dupe(u8, value) catch null;
            }
        }

        return null;
    }

    /// Parse a data: URL and return the content
    /// Format: data:[<mediatype>][;base64],<data>
    fn parseDataUrl(self: *IFrameIntegration, url: []const u8) !FetchedContent {
        if (!std.mem.startsWith(u8, url, "data:")) {
            return error.InvalidURL;
        }

        const rest = url[5..]; // Skip "data:"

        // Find the comma separating metadata from data
        const comma_idx = std.mem.indexOf(u8, rest, ",") orelse return error.InvalidURL;

        const metadata = rest[0..comma_idx];
        const data = rest[comma_idx + 1 ..];

        // Check for base64 encoding
        const is_base64 = std.mem.endsWith(u8, metadata, ";base64");

        // Extract content type
        var content_type: ?[]u8 = null;
        const ct_end = if (is_base64) metadata.len - 7 else metadata.len;
        if (ct_end > 0) {
            content_type = try self.allocator.dupe(u8, metadata[0..ct_end]);
        }

        // Decode the data
        const bytes = if (is_base64) blk: {
            // Base64 decode
            const decoded_size = std.base64.standard.Decoder.calcSizeForSlice(data) catch return error.InvalidURL;
            const decoded = try self.allocator.alloc(u8, decoded_size);
            errdefer self.allocator.free(decoded);
            std.base64.standard.Decoder.decode(decoded, data) catch return error.InvalidURL;
            break :blk decoded;
        } else blk: {
            // Percent-decode (simplified: just unescape %XX sequences)
            const decoded = try percentDecode(self.allocator, data);
            break :blk decoded;
        };

        return FetchedContent{
            .bytes = bytes,
            .content_type = content_type,
            .allocator = self.allocator,
        };
    }

    /// Parse origin from URL (simplified)
    fn parseOriginFromURL(self: *IFrameIntegration, url: []const u8) Origin {
        // Simplified parsing - in real implementation, use full URL parser
        // For data: and blob: URLs, return opaque origin
        if (std.mem.startsWith(u8, url, "data:") or
            std.mem.startsWith(u8, url, "blob:") or
            std.mem.startsWith(u8, url, "javascript:"))
        {
            return Origin.createOpaque();
        }

        // For about:blank and about:srcdoc, inherit container origin
        if (std.mem.startsWith(u8, url, "about:")) {
            return self.container_origin;
        }

        // For http(s) URLs, extract origin components
        if (std.mem.startsWith(u8, url, "https://")) {
            const rest = url[8..];
            if (std.mem.indexOf(u8, rest, "/")) |slash_idx| {
                const host = rest[0..slash_idx];
                return Origin.init("https", host, 443);
            }
            return Origin.init("https", rest, 443);
        }

        if (std.mem.startsWith(u8, url, "http://")) {
            const rest = url[7..];
            if (std.mem.indexOf(u8, rest, "/")) |slash_idx| {
                const host = rest[0..slash_idx];
                return Origin.init("http", host, 80);
            }
            return Origin.init("http", rest, 80);
        }

        // Unknown scheme - opaque origin
        return Origin.createOpaque();
    }

    /// Set the src attribute value
    /// Per spec, setting src triggers navigation
    pub fn setSrc(self: *IFrameIntegration, url: []const u8) IFrameError!void {
        // Free old URL if any
        if (self.src_url) |old_url| {
            self.allocator.free(old_url);
        }

        // Copy new URL
        self.src_url = self.allocator.dupe(u8, url) catch {
            return IFrameError.OutOfMemory;
        };

        // If we have a browsing context, navigate
        if (self.browsing_context != null and self.state != .uninitialized and self.state != .discarded) {
            try self.navigateToSrc(url);
        }
    }

    /// Get the src attribute value
    pub fn getSrc(self: *const IFrameIntegration) ?[]const u8 {
        return self.src_url;
    }

    /// Set the srcdoc attribute value
    /// Per spec, srcdoc takes precedence over src
    pub fn setSrcdoc(self: *IFrameIntegration, content: []const u8) IFrameError!void {
        // Free old content if any
        if (self.srcdoc_content) |old_content| {
            self.allocator.free(old_content);
        }

        // Copy new content
        self.srcdoc_content = self.allocator.dupe(u8, content) catch {
            return IFrameError.OutOfMemory;
        };

        // If we have a browsing context, navigate
        if (self.browsing_context != null and self.state != .uninitialized and self.state != .discarded) {
            try self.navigateToSrcdoc(content);
        }
    }

    /// Get the srcdoc attribute value
    pub fn getSrcdoc(self: *const IFrameIntegration) ?[]const u8 {
        return self.srcdoc_content;
    }

    /// Set the name attribute value
    pub fn setName(self: *IFrameIntegration, name: []const u8) IFrameError!void {
        // Free old name if any
        if (self.name.len > 0) {
            self.allocator.free(self.name);
        }

        // Copy new name
        self.name = self.allocator.dupe(u8, name) catch {
            return IFrameError.OutOfMemory;
        };

        // Update browsing context target name if it exists
        if (self.browsing_context) |ctx| {
            ctx.setTargetName(name) catch {
                return IFrameError.OutOfMemory;
            };
        }
    }

    /// Get the name attribute value
    pub fn getName(self: *const IFrameIntegration) []const u8 {
        return self.name;
    }

    /// Get the contentWindow (WindowProxy)
    /// Returns null if no browsing context or discarded
    pub fn getContentWindow(self: *IFrameIntegration) ?*WindowProxy {
        if (self.state == .uninitialized or self.state == .discarded) {
            return null;
        }
        if (self.window_proxy) |*proxy| {
            return proxy;
        }
        return null;
    }

    /// Check if contentDocument should be accessible (same-origin check)
    pub fn isContentDocumentAccessible(self: *const IFrameIntegration, accessor_origin: Origin) bool {
        if (self.state == .uninitialized or self.state == .discarded) {
            return false;
        }
        if (self.window_proxy) |proxy| {
            return proxy.isSameOriginAccess(accessor_origin);
        }
        return false;
    }

    /// Get whether the iframe's browsing context is closed
    pub fn isClosed(self: *const IFrameIntegration) bool {
        if (self.browsing_context) |ctx| {
            return ctx.is_closed;
        }
        return self.state == .discarded;
    }

    // ========================================================================
    // Sandbox Attribute (§4.8.5.4)
    // ========================================================================

    /// Set sandbox flags from the sandbox attribute value
    /// Per HTML Standard §4.8.5.4
    /// Empty value means all restrictions apply.
    /// "allow-*" tokens lift specific restrictions.
    pub fn setSandbox(self: *IFrameIntegration, value: []const u8) IFrameError!void {
        const flags = SandboxFlags.parseAlloc(self.allocator, value) catch {
            return IFrameError.OutOfMemory;
        };
        self.sandbox_flags = flags;
        self.is_sandboxed = true;

        // Apply to browsing context if it exists
        if (self.browsing_context) |ctx| {
            ctx.setSandboxFlags(flags);
        }
    }

    /// Remove sandbox (clear the sandbox attribute)
    pub fn clearSandbox(self: *IFrameIntegration) void {
        self.sandbox_flags = null;
        self.is_sandboxed = false;

        // Clear from browsing context if it exists
        if (self.browsing_context) |ctx| {
            ctx.clearSandboxFlags();
        }
    }

    /// Get the current sandbox flags (null if not sandboxed)
    pub fn getSandboxFlags(self: *const IFrameIntegration) ?SandboxFlags {
        return self.sandbox_flags;
    }

    /// Check if this iframe is sandboxed
    pub fn isSandboxed(self: *const IFrameIntegration) bool {
        return self.is_sandboxed;
    }

    /// Check if scripts are allowed in this iframe
    pub fn allowsScripts(self: *const IFrameIntegration) bool {
        if (self.sandbox_flags) |flags| {
            return flags.allow_scripts;
        }
        return true; // Not sandboxed
    }

    /// Check if forms are allowed in this iframe
    pub fn allowsForms(self: *const IFrameIntegration) bool {
        if (self.sandbox_flags) |flags| {
            return flags.allow_forms;
        }
        return true;
    }

    /// Check if popups are allowed in this iframe
    pub fn allowsPopups(self: *const IFrameIntegration) bool {
        if (self.sandbox_flags) |flags| {
            return flags.allow_popups;
        }
        return true;
    }

    /// Check if top navigation is allowed in this iframe
    pub fn allowsTopNavigation(self: *const IFrameIntegration) bool {
        if (self.sandbox_flags) |flags| {
            return flags.allow_top_navigation;
        }
        return true;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "IFrameIntegration - init creates uninitialized state" {
    const allocator = std.testing.allocator;

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    try std.testing.expectEqual(IFrameState.uninitialized, integration.state);
    try std.testing.expect(integration.browsing_context == null);
    try std.testing.expect(integration.window_proxy == null);
}

test "IFrameIntegration - insertion creates browsing context" {
    const allocator = std.testing.allocator;

    const parent_ctx = try BrowsingContext.initTopLevel(allocator);
    defer parent_ctx.deinit();

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    const container_origin = Origin.init("https", "example.com", 443);

    try integration.onInsertedIntoDocument(parent_ctx, container_origin);

    // Should have created nested browsing context
    try std.testing.expect(integration.browsing_context != null);
    try std.testing.expect(integration.window_proxy != null);
    try std.testing.expect(integration.state != .uninitialized);

    // Should be child of parent
    if (integration.browsing_context) |ctx| {
        try std.testing.expect(ctx.parent == parent_ctx);
    }
}

test "IFrameIntegration - removal discards browsing context" {
    const allocator = std.testing.allocator;

    const parent_ctx = try BrowsingContext.initTopLevel(allocator);
    defer parent_ctx.deinit();

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    try integration.onInsertedIntoDocument(parent_ctx, Origin.createOpaque());

    integration.onRemovedFromDocument();

    try std.testing.expectEqual(IFrameState.discarded, integration.state);
    if (integration.browsing_context) |ctx| {
        try std.testing.expect(ctx.is_closed);
    }
}

test "IFrameIntegration - setSrc triggers navigation" {
    const allocator = std.testing.allocator;

    const parent_ctx = try BrowsingContext.initTopLevel(allocator);
    defer parent_ctx.deinit();

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    try integration.onInsertedIntoDocument(parent_ctx, Origin.init("https", "example.com", 443));

    try integration.setSrc("https://example.com/page");

    try std.testing.expect(integration.getSrc() != null);
    try std.testing.expectEqualStrings("https://example.com/page", integration.getSrc().?);
}

test "IFrameIntegration - setSrcdoc" {
    const allocator = std.testing.allocator;

    const parent_ctx = try BrowsingContext.initTopLevel(allocator);
    defer parent_ctx.deinit();

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    try integration.onInsertedIntoDocument(parent_ctx, Origin.init("https", "example.com", 443));

    try integration.setSrcdoc("<html><body>Hello</body></html>");

    try std.testing.expect(integration.getSrcdoc() != null);
}

test "IFrameIntegration - setName updates browsing context" {
    const allocator = std.testing.allocator;

    const parent_ctx = try BrowsingContext.initTopLevel(allocator);
    defer parent_ctx.deinit();

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    try integration.onInsertedIntoDocument(parent_ctx, Origin.createOpaque());

    try integration.setName("myframe");

    try std.testing.expectEqualStrings("myframe", integration.getName());
    if (integration.browsing_context) |ctx| {
        try std.testing.expectEqualStrings("myframe", ctx.target_name);
    }
}

test "IFrameIntegration - getContentWindow returns null when uninitialized" {
    const allocator = std.testing.allocator;

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    try std.testing.expect(integration.getContentWindow() == null);
}

test "IFrameIntegration - getContentWindow returns proxy when initialized" {
    const allocator = std.testing.allocator;

    const parent_ctx = try BrowsingContext.initTopLevel(allocator);
    defer parent_ctx.deinit();

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    try integration.onInsertedIntoDocument(parent_ctx, Origin.createOpaque());

    try std.testing.expect(integration.getContentWindow() != null);
}

test "IFrameIntegration - contentDocument access same-origin" {
    const allocator = std.testing.allocator;

    const parent_ctx = try BrowsingContext.initTopLevel(allocator);
    defer parent_ctx.deinit();

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    const origin = Origin.init("https", "example.com", 443);
    try integration.onInsertedIntoDocument(parent_ctx, origin);

    // Same origin should allow access
    try std.testing.expect(integration.isContentDocumentAccessible(origin));

    // Cross-origin should deny access
    const cross_origin = Origin.init("https", "other.com", 443);
    try std.testing.expect(!integration.isContentDocumentAccessible(cross_origin));
}

test "IFrameIntegration - parseOriginFromURL" {
    const allocator = std.testing.allocator;

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    // HTTPS URL
    const https_origin = integration.parseOriginFromURL("https://example.com/path");
    try std.testing.expectEqualStrings("https", https_origin.scheme);
    try std.testing.expectEqualStrings("example.com", https_origin.host);

    // HTTP URL
    const http_origin = integration.parseOriginFromURL("http://example.com/path");
    try std.testing.expectEqualStrings("http", http_origin.scheme);

    // data: URL returns opaque
    const data_origin = integration.parseOriginFromURL("data:text/html,<h1>Hi</h1>");
    try std.testing.expect(data_origin.is_opaque);

    // javascript: URL returns opaque
    const js_origin = integration.parseOriginFromURL("javascript:void(0)");
    try std.testing.expect(js_origin.is_opaque);
}

test "IFrameIntegration - about:blank inherits origin" {
    const allocator = std.testing.allocator;

    const parent_ctx = try BrowsingContext.initTopLevel(allocator);
    defer parent_ctx.deinit();

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    const container_origin = Origin.init("https", "example.com", 443);
    try integration.onInsertedIntoDocument(parent_ctx, container_origin);

    // about:blank should inherit container origin
    if (integration.window_proxy) |proxy| {
        try std.testing.expect(proxy.isSameOriginAccess(container_origin));
    }
}

// ============================================================================
// Sandbox Tests
// ============================================================================

test "IFrameIntegration - setSandbox with empty value blocks all" {
    const allocator = std.testing.allocator;

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    // Empty sandbox = all restrictions
    try integration.setSandbox("");

    try std.testing.expect(integration.isSandboxed());
    try std.testing.expect(!integration.allowsScripts());
    try std.testing.expect(!integration.allowsForms());
    try std.testing.expect(!integration.allowsPopups());
    try std.testing.expect(!integration.allowsTopNavigation());
}

test "IFrameIntegration - setSandbox with allow-scripts" {
    const allocator = std.testing.allocator;

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    try integration.setSandbox("allow-scripts");

    try std.testing.expect(integration.isSandboxed());
    try std.testing.expect(integration.allowsScripts());
    try std.testing.expect(!integration.allowsForms());
}

test "IFrameIntegration - setSandbox with multiple flags" {
    const allocator = std.testing.allocator;

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    try integration.setSandbox("allow-scripts allow-forms allow-same-origin");

    try std.testing.expect(integration.isSandboxed());
    try std.testing.expect(integration.allowsScripts());
    try std.testing.expect(integration.allowsForms());

    const flags = integration.getSandboxFlags().?;
    try std.testing.expect(flags.allow_same_origin);
}

test "IFrameIntegration - clearSandbox removes restrictions" {
    const allocator = std.testing.allocator;

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    try integration.setSandbox("allow-scripts");
    try std.testing.expect(integration.isSandboxed());

    integration.clearSandbox();
    try std.testing.expect(!integration.isSandboxed());
    try std.testing.expect(integration.allowsScripts()); // No sandbox = allow all
    try std.testing.expect(integration.allowsForms());
}

test "IFrameIntegration - sandbox applied to browsing context" {
    const allocator = std.testing.allocator;

    const parent_ctx = try BrowsingContext.initTopLevel(allocator);
    defer parent_ctx.deinit();

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    // Set sandbox before insertion
    try integration.setSandbox("allow-scripts");

    // Insert into document
    try integration.onInsertedIntoDocument(parent_ctx, Origin.createOpaque());

    // Apply sandbox to browsing context
    if (integration.browsing_context) |ctx| {
        // The sandbox flags should be applied
        ctx.setSandboxFlags(integration.sandbox_flags.?);
        try std.testing.expect(ctx.is_sandboxed);
        try std.testing.expect(ctx.allowsScripts());
        try std.testing.expect(!ctx.allowsForms());
    }
}

// ============================================================================
// Encoding Detection Tests (Phase 2)
// ============================================================================

test "detectEncoding - UTF-8 BOM" {
    // UTF-8 BOM: 0xEF 0xBB 0xBF
    const utf8_bom = [_]u8{ 0xEF, 0xBB, 0xBF, '<', 'h', 't', 'm', 'l', '>' };
    const enc = detectEncoding(&utf8_bom, null);
    try std.testing.expectEqualStrings("utf-8", enc.whatwg_name);
}

test "detectEncoding - UTF-16BE BOM" {
    // UTF-16BE BOM: 0xFE 0xFF
    const utf16be_bom = [_]u8{ 0xFE, 0xFF, 0x00, '<' };
    const enc = detectEncoding(&utf16be_bom, null);
    try std.testing.expectEqualStrings("UTF-16BE", enc.whatwg_name);
}

test "detectEncoding - UTF-16LE BOM" {
    // UTF-16LE BOM: 0xFF 0xFE
    const utf16le_bom = [_]u8{ 0xFF, 0xFE, '<', 0x00 };
    const enc = detectEncoding(&utf16le_bom, null);
    try std.testing.expectEqualStrings("UTF-16LE", enc.whatwg_name);
}

test "detectEncoding - Content-Type charset utf-8" {
    const html = "<html>";
    const enc = detectEncoding(html, "text/html; charset=utf-8");
    try std.testing.expectEqualStrings("utf-8", enc.whatwg_name);
}

test "detectEncoding - Content-Type charset Big5" {
    const html = "<html>";
    const enc = detectEncoding(html, "text/html; charset=big5");
    try std.testing.expectEqualStrings("Big5", enc.whatwg_name);
}

test "detectEncoding - Content-Type charset Shift_JIS" {
    const html = "<html>";
    const enc = detectEncoding(html, "text/html; charset=shift_jis");
    try std.testing.expectEqualStrings("Shift_JIS", enc.whatwg_name);
}

test "detectEncoding - defaults to UTF-8" {
    const html = "<html>";
    const enc = detectEncoding(html, null);
    try std.testing.expectEqualStrings("utf-8", enc.whatwg_name);
}

test "detectEncoding - BOM takes precedence over Content-Type" {
    // UTF-8 BOM but Content-Type says Big5
    const utf8_bom = [_]u8{ 0xEF, 0xBB, 0xBF, '<', 'h', 't', 'm', 'l', '>' };
    const enc = detectEncoding(&utf8_bom, "text/html; charset=big5");
    // BOM should win
    try std.testing.expectEqualStrings("utf-8", enc.whatwg_name);
}

// ============================================================================
// Content-Type Charset Parsing Tests (Phase 2)
// ============================================================================

test "parseCharsetFromContentType - simple charset" {
    const ct = "text/html; charset=utf-8";
    const charset = parseCharsetFromContentType(ct);
    try std.testing.expectEqualStrings("utf-8", charset.?);
}

test "parseCharsetFromContentType - no space after semicolon" {
    const ct = "text/html;charset=utf-8";
    const charset = parseCharsetFromContentType(ct);
    try std.testing.expectEqualStrings("utf-8", charset.?);
}

test "parseCharsetFromContentType - quoted charset" {
    const ct = "text/html; charset=\"utf-8\"";
    const charset = parseCharsetFromContentType(ct);
    try std.testing.expectEqualStrings("utf-8", charset.?);
}

test "parseCharsetFromContentType - single quoted charset" {
    const ct = "text/html; charset='big5'";
    const charset = parseCharsetFromContentType(ct);
    try std.testing.expectEqualStrings("big5", charset.?);
}

test "parseCharsetFromContentType - uppercase CHARSET" {
    const ct = "text/html; CHARSET=utf-8";
    const charset = parseCharsetFromContentType(ct);
    try std.testing.expectEqualStrings("utf-8", charset.?);
}

test "parseCharsetFromContentType - mixed case" {
    const ct = "text/html; CharSet=ISO-8859-1";
    const charset = parseCharsetFromContentType(ct);
    try std.testing.expectEqualStrings("ISO-8859-1", charset.?);
}

test "parseCharsetFromContentType - no charset" {
    const ct = "text/html";
    const charset = parseCharsetFromContentType(ct);
    try std.testing.expect(charset == null);
}

test "parseCharsetFromContentType - charset with additional params" {
    const ct = "text/html; charset=utf-8; boundary=something";
    const charset = parseCharsetFromContentType(ct);
    try std.testing.expectEqualStrings("utf-8", charset.?);
}

// ============================================================================
// Percent Decode Tests (Phase 2)
// ============================================================================

test "percentDecode - no escapes" {
    const allocator = std.testing.allocator;
    const result = try percentDecode(allocator, "hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "percentDecode - simple escape" {
    const allocator = std.testing.allocator;
    const result = try percentDecode(allocator, "hello%20world");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello world", result);
}

test "percentDecode - multiple escapes" {
    const allocator = std.testing.allocator;
    const result = try percentDecode(allocator, "%3C%3E");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("<>", result);
}
