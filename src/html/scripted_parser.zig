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

// The adapter that builds the DOM as the tree builder builds its tree, and
// the parser's script end-tag steps.
const parser_scripts = @import("parser_script_execution.zig");
const DomTreeAdapter = parser_scripts.DomTreeAdapter;
const ParserScriptContext = parser_scripts.ParserScriptContext;

// Import impls for Document.setDefaultView (needed for nested iframe support)
const impls = @import("impls");

/// Error type for HTML parsing operations
pub const ParseError = error{
    OutOfMemory,
    InvalidStateError,
    TokenizerError,
    TreeBuilderError,
    InvalidInput,
};

/// The embedder's loader for parser-inserted external scripts: content for a
/// URL, owned by the caller's allocator, or null to let the fetch happen as
/// usual.
pub const ScriptLoader = struct {
    context: ?*anyopaque,
    loadScript: parser_scripts.ScriptLoaderFn,
};

/// Options for HTML parsing
pub const ParseOptions = struct {
    /// Enable scripting (affects parser behavior for <noscript>)
    scripting_enabled: bool = false,

    /// Optional window to set as defaultView BEFORE parsing starts
    window: ?*runtime.Instance = null,

    /// The document to parse into. Navigation creates it, and makes it the
    /// window's associated Document, before the parser exists (HTML "create
    /// and initialize a Document object" steps 9-10) - so the page's own
    /// scripts, run by this parser, see the document they are in. Null
    /// creates one here.
    document: ?*runtime.Instance = null,

    /// A loader for the parser's external scripts (the WPT runner's), and the
    /// URL it resolves their src against.
    script_loader: ?ScriptLoader = null,
    base_url: []const u8 = "",
};

/// The tree builder's hook for document.write(): process the characters it
/// inserted, up to the insertion point (the stream has set that limit).
fn processInsertedCharacters(context: *anyopaque) void {
    const tree_builder: *TreeBuilder = @ptrCast(@alignCast(context));
    tree_builder.parse() catch |err| std.log.scoped(.scripted_parser).warn("document.write(): the parser stopped: {}", .{err});
}

/// Parse an HTML document, building its DOM as it goes and running its
/// scripts at their end tags - the parser every document with scripting uses:
/// the top-level page (impls/HTMLParser.parseHTMLWithScripting), a frame's
/// (HTMLIFrameElement), and a script-created parser's (document.close()).
///
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html
///
/// DOM nodes are created as the tree builder creates their tree nodes, so a
/// script sees everything parsed before it. The input is an input stream
/// document.write() inserts into: while the parser runs, the document holds
/// the stream, a script the parser runs has an insertion point, and what it
/// writes is parsed before write() returns (the document write steps, step
/// 11). "The end" is the caller's.
/// Whether `url` matches about:srcdoc: "about:srcdoc", with nothing after it
/// but a query or a fragment.
///
/// Spec: https://html.spec.whatwg.org/multipage/urls-and-fetching.html#matches-about:srcdoc
fn matchesAboutSrcdoc(url: []const u8) bool {
    const prefix = "about:srcdoc";
    if (!std.mem.startsWith(u8, url, prefix)) return false;
    if (url.len == prefix.len) return true;
    return url[prefix.len] == '?' or url[prefix.len] == '#';
}

pub fn parseHTMLWithScripting(
    allocator: Allocator,
    ctx: runtime.Context,
    html: []const u8,
    options: ParseOptions,
) ParseError!*runtime.Instance {
    // Step 1: Create DOM Document FIRST (before parsing), unless navigation
    // already did. It must exist before any DOM nodes are created.
    const owns_document = options.document == null;
    const document = options.document orelse (interfaces.Document.init(
        allocator,
        ctx,
    ) catch return error.OutOfMemory);
    errdefer if (owns_document) interfaces.Document.deinit(document);

    // Set document type to HTML
    document_internals.setDocumentType(document, .html) catch {};

    // Set defaultView if window was provided (for nested iframes)
    if (options.window) |window| {
        impls.Document.setDefaultView(document, window);
    }

    // Step 2: the input stream, and the tokenizer reading it.
    var input_stream = InputStreamManager.init(allocator, html) catch return error.OutOfMemory;
    defer input_stream.deinit();
    var tokenizer = Tokenizer.initWithStreamManager(allocator, &input_stream);
    defer tokenizer.deinit();
    input_stream.attach(&tokenizer);

    // Step 3: the tree builder.
    var tree_builder = TreeBuilder.initWithStreamManager(allocator, &tokenizer, &input_stream) catch return error.OutOfMemory;
    defer tree_builder.deinit();
    tree_builder.scripting_enabled = options.scripting_enabled;

    // Step 4: the adapter that mirrors the tree into the DOM as it grows. The
    // tree builder's document node is the DOM document.
    var adapter = DomTreeAdapter.init(allocator, ctx, document);
    defer adapter.deinit();
    adapter.node_map.put(tree_builder.document, document) catch return error.OutOfMemory;
    tree_builder.setDomAdapterCallbacks(
        @ptrCast(&adapter),
        &parser_scripts.domAdapterOnNodeCreated,
        &parser_scripts.domAdapterOnChildAppended,
        &parser_scripts.domAdapterOnTextContentChanged,
    );
    tree_builder.setDomAdapterAttributeCallback(&parser_scripts.domAdapterOnAttributeAdded);
    // The document's mode: the "initial" insertion mode sets it on the
    // Document as it parses the DOCTYPE, where script can already read it -
    // except in an iframe srcdoc document, whose URL matches about:srcdoc.
    tree_builder.setDomAdapterModeCallback(&parser_scripts.domAdapterOnModeSet);
    tree_builder.setDomAdapterPoppedCallback(&parser_scripts.domAdapterOnElementPopped);
    if (document_internals.getURL(document)) |url| tree_builder.iframe_srcdoc = matchesAboutSrcdoc(url);

    // Step 5: the script end-tag steps.
    var script_context = ParserScriptContext.init(
        allocator,
        ctx,
        document,
        &adapter.node_map,
        &tree_builder,
        options.scripting_enabled,
    );
    script_context.setBaseUrl(options.base_url);
    if (options.script_loader) |loader| script_context.setScriptLoader(loader.loadScript, loader.context);
    if (options.scripting_enabled) {
        tree_builder.setScriptExecutionCallback(&parser_scripts.parserScriptCallback, @ptrCast(&script_context));
    }

    // Step 6: document.write() reaches the stream through the document, and
    // has the parser process what it inserted.
    input_stream.processor = .{ .context = @ptrCast(&tree_builder), .process = &processInsertedCharacters };
    const previous_stream = document_internals.getInputStreamManager(document);
    document_internals.setInputStreamManager(document, &input_stream);
    defer document_internals.setInputStreamManager(document, previous_stream);

    // Step 7: parse.
    tree_builder.parse() catch return error.TreeBuilderError;

    // The document element, should the adapter not have recorded it.
    if (document_internals.getInternal(document)) |doc_internal| {
        if (tree_builder.document.first_child) |first| {
            if (first.hasTagName("html")) {
                if (adapter.getDomNode(first)) |html_element| {
                    doc_internal.document_element = html_element;
                }
            }
        }
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
