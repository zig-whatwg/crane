//! Document Creation from Navigation Response - HTML Standard §7.5
//!
//! This module implements the algorithm to create a Document from a navigation response:
//! - Parse HTML from response body
//! - Create Document with proper URL and origin
//! - Replace active document in navigable
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html#create-and-initialize-a-document-object
//!
//! ## Key Algorithms
//!
//! - **createDocument**: Create a Document from navigation params
//! - **initializeDocument**: Set up Document with proper URL, origin, and content type
//! - **parseHtmlDocument**: Parse HTML body into Document DOM tree
//! - **replaceActiveDocument**: Swap active document in navigable
//!
//! ## Integration Points
//!
//! - Uses TreeBuilder from src/html/parser/tree_builder.zig
//! - Uses Tokenizer from src/html/parser/tokenizer.zig
//! - Works with Navigable from navigable.zig
//! - Uses NavigationFetchResult from fetch_integration.zig

const std = @import("std");
const Allocator = std.mem.Allocator;

const session_history = @import("session_history.zig");
const SessionHistoryEntry = session_history.SessionHistoryEntry;
const DocumentState = session_history.DocumentState;

const navigable_mod = @import("navigable.zig");
const Navigable = navigable_mod.Navigable;
const TraversableNavigable = navigable_mod.TraversableNavigable;

const fetch_integration = @import("fetch_integration.zig");
const NavigationFetchResult = fetch_integration.NavigationFetchResult;

// Parser imports - these are accessed through the parent html module
// When standalone testing, we need direct file access; within module context,
// these come from the html_core module's parser export.
const tree_builder = @import("../parser/tree_builder.zig");
const TreeBuilder = tree_builder.TreeBuilder;
const TreeNode = tree_builder.TreeNode;
const QuirksMode = tree_builder.QuirksMode;

const tokenizer_mod = @import("../parser/tokenizer.zig");
const Tokenizer = tokenizer_mod.Tokenizer;

const events = @import("events.zig");
const NavigationType = events.NavigationType;

// ============================================================================
// Document Creation Error
// ============================================================================

pub const DocumentCreationError = error{
    /// Failed to parse HTML
    ParseError,
    /// Invalid content type for document
    InvalidContentType,
    /// Failed to create document
    DocumentCreationFailed,
    /// No response body available
    NoResponseBody,
    /// Memory allocation failure
    OutOfMemory,
    /// Navigable is not in valid state
    InvalidNavigableState,
};

// ============================================================================
// Document Creation Options
// ============================================================================

/// Options for document creation
pub const DocumentCreationOptions = struct {
    /// The URL of the document
    url: []const u8,
    /// The final URL after redirects (may differ from request URL)
    final_url: ?[]const u8 = null,
    /// The document's origin
    origin: ?[]const u8 = null,
    /// Content type from response
    content_type: ?[]const u8 = null,
    /// Whether this is a reload
    is_reload: bool = false,
    /// Navigation type
    navigation_type: NavigationType = .push,
    /// Referrer URL
    referrer: ?[]const u8 = null,
    /// History handling
    history_handling: HistoryHandling = .push,

    pub const HistoryHandling = enum {
        push,
        replace,
    };
};

// ============================================================================
// Created Document Result
// ============================================================================

/// Result of document creation containing the parsed document tree
pub const CreatedDocument = struct {
    allocator: Allocator,

    /// The document root node from parsing
    document_node: *TreeNode,

    /// The document URL
    url: []const u8,

    /// The document's final URL (after redirects)
    final_url: []const u8,

    /// The document's origin
    origin: []const u8,

    /// The document's content type
    content_type: []const u8,

    /// The document's quirks mode
    quirks_mode: QuirksMode,

    /// Whether the document has focus
    has_focus: bool,

    pub fn init(
        allocator: Allocator,
        document_node: *TreeNode,
        url: []const u8,
        final_url: []const u8,
        origin: []const u8,
        content_type: []const u8,
        quirks_mode: QuirksMode,
    ) !CreatedDocument {
        return .{
            .allocator = allocator,
            .document_node = document_node,
            .url = try allocator.dupe(u8, url),
            .final_url = try allocator.dupe(u8, final_url),
            .origin = try allocator.dupe(u8, origin),
            .content_type = try allocator.dupe(u8, content_type),
            .quirks_mode = quirks_mode,
            .has_focus = false,
        };
    }

    pub fn deinit(self: *CreatedDocument) void {
        self.allocator.free(self.url);
        self.allocator.free(self.final_url);
        self.allocator.free(self.origin);
        self.allocator.free(self.content_type);
        self.document_node.deinit();
    }
};

// ============================================================================
// Create Document from Navigation Response
// ============================================================================

/// Create a Document from navigation response
///
/// HTML Standard §7.5.2 "Create and initialize a Document object":
/// 1. Let browsingContext be navigable's active browsing context.
/// 2. Set document to a new Document, marked as an HTML document in quirks mode,
///    whose content type is type, origin is origin, ...
/// 3. Set document's URL to creationURL.
/// 4. ...
///
/// Returns a CreatedDocument containing the parsed document tree.
pub fn createDocumentFromResponse(
    allocator: Allocator,
    response: *const NavigationFetchResult,
    options: DocumentCreationOptions,
) DocumentCreationError!CreatedDocument {
    // Step 1: Check for response body
    if (response.body == null or response.body.?.len == 0) {
        return DocumentCreationError.NoResponseBody;
    }

    // Step 2: Determine content type
    const content_type = response.content_type orelse options.content_type orelse "text/html";

    // Step 3: Check if this is an HTML document
    if (!isHtmlContentType(content_type)) {
        return DocumentCreationError.InvalidContentType;
    }

    // Step 4: Determine final URL (after redirects)
    const final_url = options.final_url orelse response.final_url;

    // Step 5: Determine origin
    const origin = options.origin orelse extractOrigin(final_url);

    // Step 6: Parse the HTML
    const html_body = response.body.?;
    const document = try parseHtmlDocument(allocator, html_body);

    // Step 7: Create the CreatedDocument result
    return try CreatedDocument.init(
        allocator,
        document.document_node,
        options.url,
        final_url,
        origin,
        content_type,
        document.quirks_mode,
    );
}

/// Create a Document from raw HTML content
///
/// This is useful for:
/// - data: URLs
/// - about:blank documents
/// - srcdoc content
pub fn createDocumentFromHtml(
    allocator: Allocator,
    html: []const u8,
    options: DocumentCreationOptions,
) DocumentCreationError!CreatedDocument {
    // Parse the HTML
    const document = try parseHtmlDocument(allocator, html);

    // Determine final URL
    const final_url = options.final_url orelse options.url;

    // Determine origin
    const origin = options.origin orelse extractOrigin(final_url);

    // Create the CreatedDocument result
    return try CreatedDocument.init(
        allocator,
        document.document_node,
        options.url,
        final_url,
        origin,
        options.content_type orelse "text/html",
        document.quirks_mode,
    );
}

// ============================================================================
// Parse HTML Document
// ============================================================================

/// Result of parsing HTML
const ParseResult = struct {
    /// The document root node
    document_node: *TreeNode,
    /// Detected quirks mode
    quirks_mode: QuirksMode,
};

/// Parse HTML content into a document tree
///
/// HTML Standard §13.2 "Parsing HTML documents":
/// Uses the tokenizer and tree construction algorithm to build the DOM.
fn parseHtmlDocument(allocator: Allocator, html: []const u8) DocumentCreationError!ParseResult {
    // Create tokenizer for the HTML input
    var tok = Tokenizer.init(allocator, html) catch {
        return DocumentCreationError.OutOfMemory;
    };
    defer tok.deinit();

    // Create tree builder
    var builder = TreeBuilder.init(allocator, &tok) catch {
        return DocumentCreationError.OutOfMemory;
    };
    // Note: Don't defer deinit - we're returning the document

    // Parse the document
    builder.parse() catch {
        builder.deinit();
        return DocumentCreationError.ParseError;
    };

    return .{
        .document_node = builder.document,
        .quirks_mode = builder.quirks_mode,
    };
}

// ============================================================================
// Replace Active Document
// ============================================================================

/// Replace the active document in a navigable with a new document
///
/// HTML Standard §7.4.2.1 "Populating a session history entry":
/// This updates the navigable's active session history entry with the new document.
pub fn replaceActiveDocument(
    allocator: Allocator,
    navigable: *Navigable,
    document: *CreatedDocument,
    options: DocumentCreationOptions,
) DocumentCreationError!void {
    // Step 1: Check navigable state
    if (navigable.state == .destroyed) {
        return DocumentCreationError.InvalidNavigableState;
    }

    // Step 2: Create or update session history entry
    if (options.history_handling == .push) {
        // Create new session history entry
        const entry = try createSessionHistoryEntry(allocator, document, options);

        // Add to navigable
        navigable.setActiveEntry(entry);
        navigable.setCurrentEntry(entry);
    } else {
        // Replace existing entry
        if (navigable.active_session_history_entry) |entry| {
            try updateSessionHistoryEntry(entry, document, options);
        } else {
            // No existing entry, create new one
            const entry = try createSessionHistoryEntry(allocator, document, options);
            navigable.setActiveEntry(entry);
            navigable.setCurrentEntry(entry);
        }
    }

    // Step 3: Update navigable state
    navigable.state = .active;
}

/// Create a new session history entry for the document
fn createSessionHistoryEntry(
    allocator: Allocator,
    document: *CreatedDocument,
    options: DocumentCreationOptions,
) DocumentCreationError!*SessionHistoryEntry {
    const entry = SessionHistoryEntry.init(allocator, options.url) catch {
        return DocumentCreationError.OutOfMemory;
    };

    // Set up document state
    entry.document_state.ever_populated = true;

    // Set origin
    if (document.origin.len > 0) {
        entry.document_state.origin = allocator.dupe(u8, document.origin) catch {
            return DocumentCreationError.OutOfMemory;
        };
    }

    // Note: The actual Document object would be created and stored here
    // For now, we store the parsed tree node as the document
    // In a full implementation, this would be a webidl Document instance

    return entry;
}

/// Update an existing session history entry with new document
fn updateSessionHistoryEntry(
    entry: *SessionHistoryEntry,
    document: *CreatedDocument,
    options: DocumentCreationOptions,
) DocumentCreationError!void {
    // Update URL if different
    if (!std.mem.eql(u8, entry.url, options.url)) {
        entry.allocator.free(entry.url);
        entry.url = entry.allocator.dupe(u8, options.url) catch {
            return DocumentCreationError.OutOfMemory;
        };
    }

    // Update document state
    entry.document_state.ever_populated = true;

    // Update origin
    if (document.origin.len > 0) {
        if (entry.document_state.origin) |old_origin| {
            entry.allocator.free(old_origin);
        }
        entry.document_state.origin = entry.allocator.dupe(u8, document.origin) catch {
            return DocumentCreationError.OutOfMemory;
        };
    }
}

// ============================================================================
// Create About:Blank Document
// ============================================================================

/// Create an about:blank document
///
/// HTML Standard §7.5.3:
/// "An about:blank document is a Document whose URL is about:blank."
pub fn createAboutBlankDocument(
    allocator: Allocator,
    origin: ?[]const u8,
) DocumentCreationError!CreatedDocument {
    // Minimal HTML for about:blank
    const html = "<!DOCTYPE html><html><head></head><body></body></html>";

    return createDocumentFromHtml(allocator, html, .{
        .url = "about:blank",
        .final_url = "about:blank",
        .origin = origin,
        .content_type = "text/html",
    });
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Check if content type indicates HTML
fn isHtmlContentType(content_type: []const u8) bool {
    // Check for text/html
    if (std.mem.startsWith(u8, content_type, "text/html")) {
        return true;
    }
    // Check for application/xhtml+xml
    if (std.mem.startsWith(u8, content_type, "application/xhtml+xml")) {
        return true;
    }
    return false;
}

/// Extract origin from URL
/// Returns a simplified origin string (scheme://host:port)
fn extractOrigin(url: []const u8) []const u8 {
    // Simple extraction - find scheme and authority
    if (std.mem.indexOf(u8, url, "://")) |scheme_end| {
        const after_scheme = url[scheme_end + 3 ..];
        // Find end of authority (path start)
        if (std.mem.indexOf(u8, after_scheme, "/")) |path_start| {
            return url[0 .. scheme_end + 3 + path_start];
        }
        // No path, whole URL is origin
        return url;
    }
    // No scheme, return as-is (may be relative)
    return url;
}

// ============================================================================
// Run Document Load Completion Steps
// ============================================================================

/// Run the document load completion steps
///
/// HTML Standard §7.5.4 "Finishing the navigation":
/// After document is created and parsed, run completion steps.
pub fn runDocumentLoadCompletionSteps(
    allocator: Allocator,
    navigable: *Navigable,
    document: *CreatedDocument,
) void {
    _ = allocator;
    _ = document;

    // Step 1: Set document's ready state to "interactive"
    // (Would set document.readyState = "interactive")

    // Step 2: Fire DOMContentLoaded event
    // (Would dispatch event to document)

    // Step 3: Wait for scripts, images, etc. to load
    // (In a full implementation, track pending resources)

    // Step 4: Set document's ready state to "complete"
    // (Would set document.readyState = "complete")

    // Step 5: Fire load event on window
    // (Would dispatch load event)

    // Step 6: Mark navigable as fully active
    navigable.state = .active;
}

// ============================================================================
// Tests
// ============================================================================

test "createDocumentFromHtml - basic HTML" {
    const allocator = std.testing.allocator;

    var doc = try createDocumentFromHtml(allocator, "<!DOCTYPE html><html><head><title>Test</title></head><body><p>Hello</p></body></html>", .{
        .url = "https://example.com/test.html",
        .origin = "https://example.com",
    });
    defer doc.deinit();

    try std.testing.expectEqualStrings("https://example.com/test.html", doc.url);
    try std.testing.expectEqualStrings("https://example.com", doc.origin);
    try std.testing.expectEqualStrings("text/html", doc.content_type);
    try std.testing.expect(doc.document_node.node_type == .document);
}

test "createDocumentFromHtml - minimal HTML" {
    const allocator = std.testing.allocator;

    var doc = try createDocumentFromHtml(allocator, "<p>Hello</p>", .{
        .url = "about:blank",
    });
    defer doc.deinit();

    try std.testing.expectEqualStrings("about:blank", doc.url);
    try std.testing.expect(doc.document_node.node_type == .document);
}

test "createAboutBlankDocument" {
    const allocator = std.testing.allocator;

    var doc = try createAboutBlankDocument(allocator, "https://example.com");
    defer doc.deinit();

    try std.testing.expectEqualStrings("about:blank", doc.url);
    try std.testing.expectEqualStrings("https://example.com", doc.origin);
}

test "isHtmlContentType" {
    try std.testing.expect(isHtmlContentType("text/html"));
    try std.testing.expect(isHtmlContentType("text/html; charset=utf-8"));
    try std.testing.expect(isHtmlContentType("application/xhtml+xml"));
    try std.testing.expect(!isHtmlContentType("application/json"));
    try std.testing.expect(!isHtmlContentType("text/plain"));
}

test "extractOrigin" {
    try std.testing.expectEqualStrings("https://example.com", extractOrigin("https://example.com/path"));
    try std.testing.expectEqualStrings("https://example.com:8080", extractOrigin("https://example.com:8080/path"));
    try std.testing.expectEqualStrings("https://example.com", extractOrigin("https://example.com"));
}
