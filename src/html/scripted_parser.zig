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
const TreeNode = html_core.parser.TreeNode;
const QuirksMode = html_core.parser.QuirksMode;
const InputStreamManager = html_core.parser.document_write.InputStreamManager;

// Import DomTreeAdapter from this module
const dom_tree_adapter = @import("dom_tree_adapter.zig");
const DomTreeAdapter = dom_tree_adapter.DomTreeAdapter;

// Import script execution for executing scripts during parsing
const script_execution = @import("script_execution.zig");

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

/// Context for script execution callback during parsing.
/// This is passed to the tree builder's script callback and provides
/// access to the DOM adapter and allocator needed for script execution.
const ScriptCallbackContext = struct {
    adapter: *DomTreeAdapter,
    allocator: Allocator,
    ctx: runtime.Context,
};

/// Script execution callback invoked by the tree builder when a </script> end tag is processed.
/// This follows the HTML Standard §13.2.5.4.7 "An end tag whose tag name is 'script'"
///
/// The callback:
/// 1. Converts the TreeNode to a DOM Instance via the adapter
/// 2. Prepares the script element (validates, determines type, etc.)
/// 3. Executes the script if it's an inline classic script
fn scriptExecutionCallback(tree_node: *TreeNode, context: ?*anyopaque) void {
    const ctx: *ScriptCallbackContext = @ptrCast(@alignCast(context));

    // Get the DOM node for this script element
    const dom_node = ctx.adapter.getDomNode(tree_node) orelse {
        std.log.warn("Script callback: failed to get DOM node for script element", .{});
        return;
    };

    // Only execute if scripting is enabled for this adapter
    if (!ctx.adapter.execute_scripts) {
        return;
    }

    // Prepare the script element
    // This validates preconditions, determines script type, and sets up for execution
    const should_execute = script_execution.prepareScriptElement(ctx.allocator, dom_node) catch |err| {
        std.log.warn("Script preparation failed: {}", .{err});
        return;
    };

    if (!should_execute) {
        return;
    }

    // Execute the script element
    // For inline classic scripts, this runs the script immediately
    script_execution.executeScriptElement(ctx.allocator, dom_node) catch |err| {
        std.log.warn("Script execution failed: {}", .{err});
    };
}

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

    // Step 7b: Register script execution callback
    // HTML Standard §13.2.5.4.7: When a </script> end tag is encountered,
    // the script element should be prepared and potentially executed.
    // This callback bridges from TreeNode to DOM Instance for script execution.
    var script_callback_ctx = ScriptCallbackContext{
        .adapter = &adapter,
        .allocator = allocator,
        .ctx = ctx,
    };

    if (options.scripting_enabled) {
        tree_builder.setScriptExecutionCallback(
            scriptExecutionCallback,
            @ptrCast(&script_callback_ctx),
        );
    }

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

    // Step 11: Handle deferred scripts
    // Inline scripts were already executed during parsing via the script execution callback
    // registered in Step 7b. Deferred scripts would be executed here after parsing completes.
    if (options.scripting_enabled) {
        // TODO: Execute deferred scripts in order
        // For now, only inline scripts are supported
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
