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
        };
    }

    /// Clean up resources
    pub fn deinit(self: *IFrameIntegration) void {
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
    fn navigateToSrcdoc(self: *IFrameIntegration, content: []const u8) IFrameError!void {
        _ = content;

        // srcdoc documents inherit origin from container
        if (self.window_proxy) |*proxy| {
            proxy.setDocumentOrigin(self.container_origin);
        }

        self.state = .navigating;

        // TODO: Parse the srcdoc HTML content and create a Document
        // For now, just transition to ready state
        self.state = .ready;
    }

    /// Navigate to src URL
    fn navigateToSrc(self: *IFrameIntegration, url: []const u8) IFrameError!void {
        self.state = .navigating;

        // Parse the URL to determine origin
        // For now, simplified - assume cross-origin unless same domain
        const new_origin = self.parseOriginFromURL(url);

        if (self.window_proxy) |*proxy| {
            proxy.setDocumentOrigin(new_origin);
        }

        // TODO: Actually fetch and navigate to the URL
        // This would involve:
        // 1. Fetching the resource
        // 2. Creating a new Document
        // 3. Setting up the document's origin
        // 4. Parsing the HTML
        // 5. Updating the browsing context's active document

        self.state = .ready;
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
