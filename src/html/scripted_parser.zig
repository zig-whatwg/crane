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

    /// Set when callbacks detach this parser before its end. The returned
    /// document may have been replaced or destroyed; its caller must skip
    /// this parser's loading-completion steps and all document access.
    parser_canceled: ?*bool = null,

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

    /// The input is the document's byte stream - a navigation's response
    /// body - to decode with the encoding HTML's encoding sniffing algorithm
    /// determines, rather than characters already decoded. Null for a parse
    /// of characters (document.open(), DOMParser), whose document keeps its
    /// encoding.
    byte_stream: ?ByteStream = null,
};

/// What the encoding sniffing algorithm knows about a byte stream besides
/// its bytes (HTML §13.2.3.2).
pub const ByteStream = struct {
    /// The response's Content-Type, as received: its charset parameter is the
    /// encoding the transport layer specifies (step 4).
    content_type: ?[]const u8 = null,
    /// The name of the container document's encoding, when the document is
    /// in a child navigable whose container document is same origin with it
    /// (step 6).
    parent_encoding: ?[]const u8 = null,
};

const encoding_sniffing = html_core.parser.encoding_sniffing;
const log = std.log.scoped(.scripted_parser);

/// A byte stream's decoding while it is parsed: the encoding, its
/// confidence, and what "change the encoding" needs to switch it.
const ByteStreamDecoding = struct {
    allocator: Allocator,
    bytes: []const u8,
    encoding: encoding_sniffing.Encoding,
    confidence: encoding_sniffing.Confidence,
    document: *runtime.Instance,
    input_stream: *InputStreamManager,
    /// The length of the decoded input as decoded: a longer buffer has had
    /// document.write() insert into it, and its offsets are no longer the
    /// decoded bytes'.
    decoded_len: usize,

    /// HTML §13.2.3.4 "change the encoding", which the tree builder runs for
    /// a meta element that declares `requested`.
    fn change(context: *anyopaque, requested: encoding_sniffing.Encoding) void {
        const self: *ByteStreamDecoding = @ptrCast(@alignCast(context));
        // The meta steps: only "if the confidence is currently tentative".
        if (self.confidence != .tentative) return;
        // Steps 1-4: nothing to change - the confidence becomes certain.
        const new = encoding_sniffing.encodingToChangeTo(self.encoding, requested) orelse {
            self.confidence = .certain;
            return;
        };
        // Step 5: every byte converted so far - up to the tokenizer's next
        // input character - means the same in both encodings, so the rest
        // of the stream is decoded with the new one in place.
        const tokenizer = self.input_stream.tokenizer;
        const consumed = if (tokenizer) |t| t.nextInputPosition() else self.input_stream.buffer.items.len;
        if (self.input_stream.buffer.items.len == self.decoded_len and consumed <= self.bytes.len and
            encoding_sniffing.sameInterpretation(self.bytes[0..consumed], self.encoding, new))
        {
            const switched = blk: {
                self.switchAt(consumed, new) catch |err| {
                    log.warn("change the encoding: {}", .{err});
                    break :blk false;
                };
                break :blk true;
            };
            if (switched) {
                self.confidence = .certain;
                return;
            }
        }
        // Step 6 says to navigate to the document again (replace) with the
        // new encoding. Deviation, stated: Crane ignores the new encoding
        // and makes the confidence certain, as Blink does - its decoder
        // switches codecs only for bytes not yet decoded
        // (TextResourceDecoder::Decode -> FinalizeMetaCharsetCheck ->
        // SetEncoding(..., kEncodingFromMetaTag), text_resource_decoder.cc)
        // and nothing in Blink re-decodes or reloads for a meta found later.
        // Re-running a navigation after its scripts ran is not something
        // Crane's synchronous parse can do.
        log.debug("change the encoding to {s} ignored: the bytes already parsed decode differently", .{encoding_sniffing.canonicalName(new)});
        self.confidence = .certain;
    }

    /// Decode the bytes from `at` on with `new` and put them in place of the
    /// input stream's characters from `at` on (whose offsets are the bytes'),
    /// then make `new` the document's encoding.
    fn switchAt(self: *ByteStreamDecoding, at: usize, new: encoding_sniffing.Encoding) !void {
        const tail = try encoding_sniffing.decodeWith(self.allocator, self.bytes[at..], new);
        defer self.allocator.free(tail);
        const stream = self.input_stream;
        stream.buffer.shrinkRetainingCapacity(at);
        try stream.buffer.appendSlice(stream.allocator, tail);
        stream.sync();
        self.decoded_len = stream.buffer.items.len;
        self.encoding = new;
        try document_internals.setEncoding(self.document, encoding_sniffing.canonicalName(new));
    }
};

/// The tree builder's hook for document.write(): process the characters it
/// inserted, up to the insertion point (the stream has set that limit).
fn processInsertedCharacters(context: *anyopaque) void {
    const tree_builder: *TreeBuilder = @ptrCast(@alignCast(context));
    tree_builder.parse() catch |err| std.log.scoped(.scripted_parser).warn("document.write(): the parser stopped: {}", .{err});
}

fn abortParserCharacters(context: *anyopaque) void {
    const tree_builder: *TreeBuilder = @ptrCast(@alignCast(context));
    tree_builder.abort();
}

/// The parser created by document.open(). Its tokenizer, tree construction
/// state and DOM adapter have stable addresses until the parser is detached.
/// A write pumps this same parser; only close marks its input complete.
///
/// Design: WebKit HTMLDocumentParser::insert / finish / shouldDelayEnd:
/// https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/parser/HTMLDocumentParser.cpp
pub const ScriptCreatedParser = struct {
    allocator: Allocator,
    ctx: runtime.Context,
    document: *runtime.Instance,
    document_generation: u64,
    input_stream: InputStreamManager,
    tokenizer: Tokenizer,
    tree_builder: TreeBuilder,
    adapter: DomTreeAdapter,
    script_context: ParserScriptContext,
    traced_slots: @import("infra").List([]u8),
    /// The document owns one reference. A write/close holds another across
    /// every callback and the input stream's insertion-limit restoration.
    references: usize = 1,
    pump_depth: usize = 0,
    detached: bool = false,
    document_destroyed: bool = false,
    eof_processed: bool = false,
    on_finished: *const fn (*runtime.Instance, *ScriptCreatedParser) void,

    pub fn create(
        allocator: Allocator,
        ctx: runtime.Context,
        document: *runtime.Instance,
        scripting_enabled: bool,
        on_finished: *const fn (*runtime.Instance, *ScriptCreatedParser) void,
    ) !*ScriptCreatedParser {
        const self = try allocator.create(ScriptCreatedParser);
        errdefer allocator.destroy(self);
        self.* = .{
            .allocator = allocator,
            .ctx = ctx,
            .document = document,
            .document_generation = runtime.SlabAllocator.generationOf(document),
            .input_stream = try InputStreamManager.init(allocator, ""),
            .tokenizer = undefined,
            .tree_builder = undefined,
            .adapter = undefined,
            .script_context = undefined,
            .traced_slots = @import("infra").List([]u8).init(allocator),
            .on_finished = on_finished,
        };
        errdefer self.input_stream.deinit();
        // HTML 8.4.1 steps 16-17: no implicit EOF, insertion just before
        // the end of an initially empty input stream.
        self.input_stream.complete = false;
        self.input_stream.insertion_point = 0;
        self.tokenizer = Tokenizer.initWithStreamManager(allocator, &self.input_stream);
        errdefer self.tokenizer.deinit();
        self.input_stream.attach(&self.tokenizer);
        self.tree_builder = try TreeBuilder.initWithStreamManager(allocator, &self.tokenizer, &self.input_stream);
        errdefer self.tree_builder.deinit();
        self.tree_builder.scripting_enabled = scripting_enabled;
        self.input_stream.script_nesting_level = &self.tree_builder.script_nesting_level;
        self.adapter = DomTreeAdapter.init(allocator, ctx, document);
        errdefer self.adapter.deinit();
        try self.adapter.node_map.put(self.tree_builder.document, document);
        self.tree_builder.setDomAdapterCallbacks(
            @ptrCast(&self.adapter),
            &nodeCreated,
            &parser_scripts.domAdapterOnChildAppended,
            &parser_scripts.domAdapterOnTextContentChanged,
        );
        self.tree_builder.setDomAdapterAttributeCallback(&parser_scripts.domAdapterOnAttributeAdded);
        self.tree_builder.setDomAdapterModeCallback(&parser_scripts.domAdapterOnModeSet);
        self.tree_builder.setDomAdapterPoppedCallback(&parser_scripts.domAdapterOnElementPopped);
        self.tree_builder.setDomAdapterFinishedCallback(&parser_scripts.domAdapterOnChildrenFinished);
        self.adapter.notifies_children_finished = true;
        if (document_internals.getURL(document)) |url| self.tree_builder.iframe_srcdoc = matchesAboutSrcdoc(url);
        self.script_context = ParserScriptContext.init(
            allocator,
            ctx,
            document,
            &self.adapter.node_map,
            &self.tree_builder,
            scripting_enabled,
        );
        self.script_context.can_suspend = true;
        self.tree_builder.setScriptEndCheckpointCallback(&parser_scripts.parserScriptEndCheckpoint, &self.script_context);
        if (scripting_enabled) self.tree_builder.setScriptExecutionCallback(&parser_scripts.parserScriptCallback, &self.script_context);
        self.input_stream.processor = .{
            .context = self,
            .process = &process,
            .retain = &retainProcessor,
            .release = &releaseProcessor,
            .after_process = &afterProcess,
            .abort = &abortProcessor,
        };
        return self;
    }

    fn nodeCreated(node: *TreeNode, context: ?*anyopaque) void {
        parser_scripts.domAdapterOnNodeCreated(node, context);
        const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return));
        const self: *ScriptCreatedParser = @fieldParentPtr("adapter", adapter);
        const instance = adapter.getDomNode(node) orelse return;
        if (instance == self.document or !self.ctx.hasEngine()) return;
        if (runtime.SlabAllocator.generationOf(self.document) != self.document_generation) return;
        // A parser reference is a collector edge from its document, like
        // Blink HTMLTreeBuilder::Trace visiting its open-element stack.
        // A detached node must survive until this parser releases it, while
        // an unreachable document/parser/node cycle must remain collectable.
        const slot = std.fmt.allocPrint(self.allocator, "script-created-parser:{x}", .{@intFromPtr(node)}) catch return;
        self.traced_slots.append(slot) catch {
            self.allocator.free(slot);
            return;
        };
        @import("engine").traceChild(self.document, instance, .{ .name = slot });
        // traceChild makes the wrapper and transfers this node to the
        // collector, even if its later DOM insertion is rejected. The
        // adapter must never directly destroy a wrapped parser-held node.
        if (@import("engine").hasWrapper(instance)) _ = adapter.unattached_nodes.remove(instance);
    }

    pub fn retain(self: *ScriptCreatedParser) void {
        self.references += 1;
    }

    pub fn release(self: *ScriptCreatedParser) void {
        self.references -= 1;
        if (self.references != 0) return;
        std.debug.assert(self.pump_depth == 0);
        if (!self.document_destroyed) self.forgetParserReferences();
        self.adapter.deinit();
        self.tree_builder.deinit();
        self.input_stream.deinit();
        self.tokenizer.deinit();
        for (self.traced_slots.toSlice()) |slot| self.allocator.free(slot);
        self.traced_slots.deinit();
        self.allocator.destroy(self);
    }

    /// Stop an old parser without freeing a pump a script has reentered.
    /// The document clears its association before dropping its reference.
    pub fn detach(self: *ScriptCreatedParser) void {
        if (self.detached) return;
        self.detached = true;
        self.input_stream.aborted = true;
        self.input_stream.insertion_point = null;
    }

    /// Document's wrapper owns its traced edges. A collector teardown lets
    /// those die with the wrapper, without manipulating edges during GC.
    pub fn detachForDocumentDestruction(self: *ScriptCreatedParser) void {
        self.document_destroyed = true;
        // Teardown never runs parser callbacks or script. Destroying the
        // private tree below releases its stack storage without observable
        // finished-parsing-children steps against a retired document.
        self.detached = true;
        self.input_stream.aborted = true;
        self.input_stream.insertion_point = null;
    }

    fn forgetParserReferences(self: *ScriptCreatedParser) void {
        // A frame can retire its realm while a written script still holds
        // this parser on the stack. The saved context remains allocated;
        // do not dereference a document the collector has already recycled.
        if (!self.ctx.hasEngine()) return;
        if (runtime.SlabAllocator.generationOf(self.document) != self.document_generation) return;
        for (self.traced_slots.toSlice()) |slot| @import("engine").forgetTracedChild(self.document, .{ .name = slot });
    }

    fn retainProcessor(context: *anyopaque) void {
        const self: *ScriptCreatedParser = @ptrCast(@alignCast(context));
        self.retain();
    }

    fn releaseProcessor(context: *anyopaque) void {
        const self: *ScriptCreatedParser = @ptrCast(@alignCast(context));
        self.release();
    }

    fn afterProcess(context: *anyopaque) void {
        const self: *ScriptCreatedParser = @ptrCast(@alignCast(context));
        self.finishIfPossible() catch |err| log.warn("document.close(): the parser stopped: {}", .{err});
    }

    fn abortProcessor(context: *anyopaque) void {
        const self: *ScriptCreatedParser = @ptrCast(@alignCast(context));
        self.tree_builder.abort();
    }

    fn process(context: *anyopaque) void {
        const self: *ScriptCreatedParser = @ptrCast(@alignCast(context));
        self.pump() catch |err| log.warn("document.write(): the parser stopped: {}", .{err});
    }

    fn pump(self: *ScriptCreatedParser) !void {
        if (self.detached or self.eof_processed) return;
        self.pump_depth += 1;
        defer self.pump_depth -= 1;
        parser_scripts.resumeAfterBlockingScript(&self.script_context);
        if (self.detached) return;
        try self.tree_builder.parse();
    }

    /// Called after the input stream restored a write's stop position. A
    /// nested close only marks EOF; the outermost write finishes the parser.
    pub fn finishIfPossible(self: *ScriptCreatedParser) !void {
        if (self.detached or self.eof_processed or !self.input_stream.complete or self.pump_depth != 0) return;
        const internal = document_internals.getInternal(self.document) orelse return;
        if (internal.scripts.pending_parsing_blocking_script != null) return;
        try self.pump();
        if (self.detached or !self.input_stream.eof_processed) return;
        self.eof_processed = true;
        self.on_finished(self.document, self);
    }

    /// HTML 8.4.2 steps 4-6. EOF is explicit and can only be processed once.
    pub fn close(self: *ScriptCreatedParser) !void {
        self.input_stream.complete = true;
        try self.finishIfPossible();
    }
};

/// Parse an HTML document, building its DOM as it goes and running its
/// scripts at their end tags - the complete-input driver for the top-level
/// page (HTMLParser.parseHTMLWithScripting) and a frame (HTMLIFrameElement).
/// Script-created documents use ScriptCreatedParser to retain the same stages
/// across successive writes.
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
    if (options.parser_canceled) |canceled| canceled.* = false;
    // Step 1: Create DOM Document FIRST (before parsing), unless navigation
    // already did. It must exist before any DOM nodes are created.
    const owns_document = options.document == null;
    const document = options.document orelse (interfaces.Document.init(
        allocator,
        ctx,
    ) catch return error.OutOfMemory);
    const document_generation = runtime.SlabAllocator.generationOf(document);
    const had_engine = ctx.hasEngine();
    errdefer if (owns_document) interfaces.Document.deinit(document);

    // Set document type to HTML
    document_internals.setDocumentType(document, .html) catch {};

    // Set defaultView if window was provided (for nested iframes)
    if (options.window) |window| {
        dom.document_browsing_context.setWindow(document, window);
    }

    // A byte stream: HTML §13.2.3.2 "determining the character encoding".
    // "The document's character encoding must immediately be set to the value
    // returned from this algorithm, at the same time as the user agent uses
    // the returned value to select the decoder to use for the input byte
    // stream."
    var decoded: ?[]u8 = null;
    defer if (decoded) |d| allocator.free(d);
    var sniffed: ?encoding_sniffing.Result = null;
    if (options.byte_stream) |byte_stream| {
        const result = encoding_sniffing.sniff(html, .{
            .transport = if (byte_stream.content_type) |ct| encoding_sniffing.transportEncoding(allocator, ct) else null,
            .parent = if (byte_stream.parent_encoding) |name| encoding_sniffing.lookup(name) else null,
        });
        sniffed = result;
        document_internals.setEncoding(document, encoding_sniffing.canonicalName(result.encoding)) catch return error.OutOfMemory;
        decoded = encoding_sniffing.decode(allocator, html, result.encoding) catch return error.OutOfMemory;
    }
    const input = decoded orelse html;

    // Step 2: the input stream, and the tokenizer reading it.
    var input_stream = InputStreamManager.init(allocator, input) catch return error.OutOfMemory;
    defer input_stream.deinit();
    var tokenizer = Tokenizer.initWithStreamManager(allocator, &input_stream);
    defer tokenizer.deinit();
    input_stream.attach(&tokenizer);

    // Step 3: the tree builder.
    var tree_builder = TreeBuilder.initWithStreamManager(allocator, &tokenizer, &input_stream) catch return error.OutOfMemory;
    defer tree_builder.deinit();
    tree_builder.scripting_enabled = options.scripting_enabled;
    input_stream.script_nesting_level = &tree_builder.script_nesting_level;

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
    // Every element the tree builder removes from its stack of open elements:
    // the element types that act on that pop hear it (dom.finish_parsing_children).
    tree_builder.setDomAdapterFinishedCallback(&parser_scripts.domAdapterOnChildrenFinished);
    adapter.notifies_children_finished = true;
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
    tree_builder.setScriptEndCheckpointCallback(&parser_scripts.parserScriptEndCheckpoint, &script_context);
    if (options.scripting_enabled) {
        tree_builder.setScriptExecutionCallback(&parser_scripts.parserScriptCallback, @ptrCast(&script_context));
    }

    // Step 6: document.write() reaches the stream through the document, and
    // has the parser process what it inserted.
    input_stream.processor = .{
        .context = @ptrCast(&tree_builder),
        .process = &processInsertedCharacters,
        .abort = &abortParserCharacters,
    };
    const previous_stream = document_internals.getInputStreamManager(document);
    document_internals.setInputStreamManager(document, &input_stream);
    defer {
        // A reentrant open can replace this parser while it is suspended.
        // Restore only the temporary association this invocation installed.
        if ((!had_engine or ctx.hasEngine()) and
            runtime.SlabAllocator.generationOf(document) == document_generation and
            document_internals.getInputStreamManager(document) == &input_stream)
            document_internals.setInputStreamManager(document, previous_stream);
    }

    // The parser's "change the encoding", while the encoding is tentative.
    var byte_stream_decoding: ByteStreamDecoding = undefined;
    if (sniffed) |result| {
        byte_stream_decoding = .{
            .allocator = allocator,
            .bytes = html,
            .encoding = result.encoding,
            .confidence = result.confidence,
            .document = document,
            .input_stream = &input_stream,
            .decoded_len = input.len,
        };
        tree_builder.change_the_encoding = .{ .context = @ptrCast(&byte_stream_decoding), .change = &ByteStreamDecoding.change };
    }

    // Step 7: parse.
    tree_builder.parse() catch return error.TreeBuilderError;

    // A script-end checkpoint can replace the document before the old
    // script is prepared. Do not restore that parser's stale DOM bindings.
    if ((had_engine and !ctx.hasEngine()) or runtime.SlabAllocator.generationOf(document) != document_generation or
        input_stream.aborted or document_internals.getInputStreamManager(document) != &input_stream)
    {
        if (options.parser_canceled) |canceled| canceled.* = true;
        return document;
    }

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
