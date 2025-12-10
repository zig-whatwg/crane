//! HTML Parser with Incremental DOM Conversion
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html
//! HTML Standard §13 "Parsing HTML documents"
//!
//! This module provides HTML parsing with incremental DOM node creation,
//! which is essential for script execution during parsing. When a script
//! element is encountered, DOM nodes that were parsed before it are already
//! available for `document.querySelector()` and similar DOM APIs.
//!
//! ## Why This Exists
//!
//! The standard `parseHTML()` in HTMLParser impl converts the entire TreeNode
//! tree to DOM *after* parsing is complete. This doesn't work for scripting
//! because scripts need access to DOM nodes during parsing.
//!
//! This module solves that by:
//! 1. Creating the Document before parsing begins
//! 2. Using DomTreeAdapter to convert TreeNodes to DOM nodes incrementally
//! 3. Scripts can access DOM nodes as they're created
//!
//! ## Usage
//!
//! ```zig
//! const scripted_parser = @import("html").scripted_parser;
//!
//! const doc = try scripted_parser.parseHTMLWithScripting(
//!     allocator,
//!     ctx,
//!     html_content,
//!     .{ .scripting_enabled = true },
//! );
//! defer interfaces.Document.deinit(doc);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import runtime for DOM types
const runtime = @import("runtime");

// Import interfaces for DOM operations (this module is allowed to use interfaces)
const interfaces = @import("interfaces");

// Import DOM internals for document state access (Golden Rule #12 compliant)
const dom = @import("dom");
const document_internals = dom.document_internals;

// Import html_core for parser types
const html_core = @import("html_core");
const Tokenizer = html_core.parser.Tokenizer;
const TreeBuilder = html_core.parser.TreeBuilder;
const QuirksMode = html_core.parser.QuirksMode;
const InputStreamManager = html_core.parser.document_write.InputStreamManager;

// Import DomTreeAdapter from this module
const dom_tree_adapter = @import("dom_tree_adapter.zig");
const DomTreeAdapter = dom_tree_adapter.DomTreeAdapter;

/// Error type for HTML parsing operations
pub const ParseError = error{
    OutOfMemory,
    InvalidStateError,
    TokenizerError,
    TreeBuilderError,
    InvalidInput,
};

/// Options for HTML parsing
pub const ParseOptions = struct {
    /// Enable scripting (affects parser behavior for <noscript>)
    scripting_enabled: bool = false,
};

/// Parse an HTML string with incremental DOM conversion for script execution.
///
/// This function creates DOM nodes incrementally during parsing, which is essential
/// for script execution during parsing. When a script element is encountered,
/// the DOM nodes that were parsed before it are already available for
/// `document.querySelector()` and similar DOM APIs.
///
/// Use this function when:
/// - Parsing HTML that contains `<script>` elements that need to execute
/// - Running WPT tests that expect browser-like DOM availability during parsing
/// - Any scenario where scripts need access to earlier-parsed DOM nodes
///
/// For non-scripted parsing (faster, simpler), use `HTMLParser.parseHTML()` instead.
///
/// @param allocator Memory allocator for DOM nodes
/// @param ctx Runtime context for DOM instances
/// @param html The HTML string to parse
/// @param options Parsing options (scripting, etc.)
/// @return A Document instance containing the parsed DOM tree
pub fn parseHTMLWithScripting(
    allocator: Allocator,
    ctx: runtime.Context,
    html: []const u8,
    options: ParseOptions,
) ParseError!*runtime.Instance {
    // Step 1: Create DOM Document FIRST (before parsing)
    // This is critical - the document must exist before any DOM nodes are created
    const document = interfaces.Document.init(
        allocator,
        ctx,
    ) catch return error.OutOfMemory;
    errdefer interfaces.Document.deinit(document);

    // Set document type to HTML
    document_internals.setDocumentType(document, .html) catch {};

    // Step 2: Create DOM tree adapter connected to the document
    // The adapter will convert TreeNodes to DOM nodes incrementally during parsing
    var adapter = DomTreeAdapter.init(allocator, ctx, document);
    defer adapter.deinit();

    // Enable/disable script execution based on options
    adapter.execute_scripts = options.scripting_enabled;

    // Step 3: Create InputStreamManager for document.write() support
    // HTML Standard §13.2.3: The input stream manager handles dynamic content insertion
    // via document.write() during script execution.
    var input_stream_manager = InputStreamManager.init(allocator, html);
    defer input_stream_manager.deinit();

    // Step 4: Create tokenizer with InputStreamManager (not static input)
    // This enables document.write() to insert content during parsing
    var tokenizer = Tokenizer.initWithStreamManager(allocator, &input_stream_manager);
    defer tokenizer.deinit();

    // Step 5: Create tree builder
    var tree_builder = TreeBuilder.init(allocator, &tokenizer) catch return error.OutOfMemory;
    defer tree_builder.deinit();

    // Configure tree builder
    tree_builder.scripting_enabled = options.scripting_enabled;

    // Step 6: Connect InputStreamManager to Document for document.write() support
    // HTML Standard §8.4.2: document.write() inserts content at the insertion point
    // in the input stream during parsing.
    document_internals.setInputStreamManager(document, &input_stream_manager);
    // Set insertion point at beginning (will be updated as parsing progresses)
    document_internals.setInsertionPoint(document, 0);

    // Step 7: Connect adapter to tree builder
    // This registers callbacks so DOM nodes are created incrementally during parsing
    adapter.connectToTreeBuilder(&tree_builder);

    // Step 8: Parse the document
    // As parsing progresses, the adapter callbacks create DOM nodes in real-time
    // This means scripts can access earlier-parsed DOM nodes via document.querySelector() etc.
    // document.write() calls during script execution will insert into the input stream.
    tree_builder.parse() catch return error.TreeBuilderError;

    // Step 9: Clear insertion point - parsing is complete
    // HTML Standard §8.4.2: After parsing, document.write() implicitly calls document.open()
    document_internals.clearInsertionPoint(document);
    document_internals.setInputStreamManager(document, null);

    // Step 10: Set quirks mode based on parser result
    if (document_internals.getInternal(document)) |doc_internal| {
        switch (tree_builder.quirks_mode) {
            .quirks => {
                // Set quirks mode (full)
            },
            .limited_quirks => {
                // Set limited quirks mode
            },
            .no_quirks => {
                // Standards mode (default)
            },
        }

        // Set document element if available
        if (tree_builder.document.first_child) |first| {
            if (first.hasTagName("html")) {
                if (adapter.getDomNode(first)) |html_element| {
                    doc_internal.document_element = html_element;
                }
            }
        }
    }

    // Step 11: Execute any pending scripts
    // During parsing, script elements were marked as parser-inserted but may not have
    // been executed yet if they were deferred or had dependencies
    if (options.scripting_enabled) {
        // Inline scripts are executed during parsing via the adapter callbacks
        // Deferred scripts would be executed here after parsing completes
        // For now, we rely on the TreeBuilder's script handling
    }

    return document;
}

// =============================================================================
// Tests
// =============================================================================

// NOTE: Full integration tests for parseHTMLWithScripting require V8 runtime initialization
// and are run as part of the WPT runner tests, not as unit tests.
// The following tests only test components that don't require runtime context.

test "scripted_parser - ParseOptions defaults" {
    const options = ParseOptions{};
    try std.testing.expectEqual(false, options.scripting_enabled);
}

test "scripted_parser - ParseOptions with scripting" {
    const options = ParseOptions{ .scripting_enabled = true };
    try std.testing.expectEqual(true, options.scripting_enabled);
}
