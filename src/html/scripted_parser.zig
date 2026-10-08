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
/// URL, owned by the parser's allocator, or null to fetch as usual. The
/// descriptor is borrowed; a persistent parser acquires its context. Every
/// caller must supply retention and release, including static contexts.
pub const ScriptLoader = struct {
    context: ?*anyopaque,
    loadScript: parser_scripts.ScriptLoaderFn,
    retain: *const fn (?*anyopaque) void,
    release: *const fn (?*anyopaque) void,

    pub fn load(self: ScriptLoader, url: []const u8) ?[]const u8 {
        return self.loadScript(self.context, url);
    }

    pub fn acquire(self: ScriptLoader) OwnedScriptLoader {
        self.retain(self.context);
        return .{ .loader = self };
    }
};

/// One acquired context reference. Move into its owner once; never copy it.
pub const OwnedScriptLoader = struct {
    loader: ?ScriptLoader,

    pub fn load(self: *const OwnedScriptLoader, url: []const u8) ?[]const u8 {
        return (self.loader orelse unreachable).load(url);
    }

    pub fn deinit(self: *OwnedScriptLoader) void {
        const loader = self.loader orelse unreachable;
        self.loader = null;
        loader.release(loader.context);
    }
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

/// A document's active parser. Its tokenizer, tree construction state and
/// DOM adapter have stable addresses across a stylesheet wait or a write.
/// Navigation supplies complete input; document.open waits for close's EOF.
///
/// Design: WebKit HTMLDocumentParser::insert / finish / shouldDelayEnd:
/// https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/parser/HTMLDocumentParser.cpp
pub const DocumentParser = struct {
    allocator: Allocator,
    ctx: runtime.Context,
    document: *runtime.Instance,
    document_generation: u64,
    document_epoch: u64 = 0,
    had_engine: bool,
    input_stream: InputStreamManager,
    tokenizer: Tokenizer,
    tree_builder: TreeBuilder,
    adapter: DomTreeAdapter,
    script_context: ParserScriptContext,
    base_url: []u8,
    original_bytes: ?[]u8 = null,
    byte_stream_decoding: ?ByteStreamDecoding = null,
    owned_loader: ?OwnedScriptLoader = null,
    traced_slots: @import("infra").List([]u8),
    /// Document owns one reference. Initiation and each write/close/resume
    /// hold another across callbacks and insertion-limit restoration.
    references: usize = 1,
    pump_depth: usize = 0,
    detached: bool = false,
    document_destroyed: bool = false,
    eof_processed: bool = false,
    on_finished: *const fn (*runtime.Instance, *DocumentParser) void,

    pub fn create(
        allocator: Allocator,
        ctx: runtime.Context,
        document: *runtime.Instance,
        scripting_enabled: bool,
        on_finished: *const fn (*runtime.Instance, *DocumentParser) void,
    ) !*DocumentParser {
        return createWithInput(allocator, ctx, document, "", .{ .scripting_enabled = scripting_enabled }, true, on_finished);
    }

    /// Copies all input retained beyond initiation, including original bytes
    /// needed by a meta encoding change after a parser-blocking stylesheet.
    pub fn createComplete(allocator: Allocator, ctx: runtime.Context, document: *runtime.Instance, html: []const u8, options: ParseOptions) !*DocumentParser {
        var decoded: ?[]u8 = null;
        defer if (decoded) |input| allocator.free(input);
        var sniffed: ?encoding_sniffing.Result = null;
        if (options.byte_stream) |stream| {
            const result = encoding_sniffing.sniff(html, .{
                .transport = if (stream.content_type) |ct| encoding_sniffing.transportEncoding(allocator, ct) else null,
                .parent = if (stream.parent_encoding) |name| encoding_sniffing.lookup(name) else null,
            });
            sniffed = result;
            try document_internals.setEncoding(document, encoding_sniffing.canonicalName(result.encoding));
            decoded = try encoding_sniffing.decode(allocator, html, result.encoding);
        }
        const self = try createWithInput(allocator, ctx, document, decoded orelse html, options, false, &navigationFinished);
        errdefer self.release();
        if (sniffed) |result| {
            self.original_bytes = try allocator.dupe(u8, html);
            self.byte_stream_decoding = .{
                .allocator = allocator,
                .bytes = self.original_bytes.?,
                .encoding = result.encoding,
                .confidence = result.confidence,
                .document = document,
                .input_stream = &self.input_stream,
                .decoded_len = self.input_stream.buffer.items.len,
            };
            self.tree_builder.change_the_encoding = .{ .context = @ptrCast(&self.byte_stream_decoding.?), .change = &ByteStreamDecoding.change };
        }
        return self;
    }

    fn navigationFinished(document: *runtime.Instance, self: *DocumentParser) void {
        dom.document_lifecycle.parserFinished(document, self);
    }

    fn createWithInput(allocator: Allocator, ctx: runtime.Context, document: *runtime.Instance, input: []const u8, options: ParseOptions, script_created: bool, on_finished: *const fn (*runtime.Instance, *DocumentParser) void) !*DocumentParser {
        // HTML "load an HTML document" step 1 initializes text/html before
        // creating the parser. A browser singleton may still have no type;
        // supply it before script preparation checks render eligibility.
        // Keep explicit XML/text types when this parser is used as a fallback.
        if (document_internals.getContentType(document)) |content_type| {
            if (content_type.len == 0) try document_internals.setContentType(document, "text/html");
        }
        const self = try allocator.create(DocumentParser);
        errdefer allocator.destroy(self);
        const base_url = try allocator.dupe(u8, options.base_url);
        errdefer allocator.free(base_url);
        self.* = .{
            .allocator = allocator,
            .ctx = ctx,
            .document = document,
            .document_generation = runtime.SlabAllocator.generationOf(document),
            .had_engine = ctx.hasEngine(),
            .input_stream = try InputStreamManager.init(allocator, input),
            .tokenizer = undefined,
            .tree_builder = undefined,
            .adapter = undefined,
            .script_context = undefined,
            .base_url = base_url,
            .traced_slots = @import("infra").List([]u8).init(allocator),
            .on_finished = on_finished,
        };
        errdefer self.input_stream.deinit();
        // HTML 8.4.1 steps 16-17: no implicit EOF, insertion just before
        // the end of an initially empty input stream.
        self.input_stream.complete = !script_created;
        self.input_stream.insertion_point = if (script_created) 0 else null;
        self.tokenizer = Tokenizer.initWithStreamManager(allocator, &self.input_stream);
        errdefer self.tokenizer.deinit();
        self.input_stream.attach(&self.tokenizer);
        self.tree_builder = try TreeBuilder.initWithStreamManager(allocator, &self.tokenizer, &self.input_stream);
        errdefer self.tree_builder.deinit();
        self.tree_builder.scripting_enabled = options.scripting_enabled;
        self.input_stream.script_nesting_level = &self.tree_builder.script_nesting_level;
        self.adapter = DomTreeAdapter.init(allocator, ctx, document);
        errdefer self.adapter.deinit();
        // A suspended Document/parser/node graph must remain collectible.
        // nodeCreated traces each wrapper from the Document; independent
        // adapter roots would keep that graph alive after script drops it.
        self.adapter.ownership_mode = .document_traced;
        try self.adapter.node_map.put(self.tree_builder.document, document);
        self.tree_builder.setDomAdapterCallbacks(
            @ptrCast(&self.adapter),
            &nodeCreated,
            &parser_scripts.domAdapterOnChildAppended,
            &parser_scripts.domAdapterOnTextContentChanged,
        );
        self.tree_builder.setDomAdapterAttributeCallback(&parser_scripts.domAdapterOnAttributeAdded);
        self.tree_builder.setDomAdapterTreeMutationCallbacks(
            &parser_scripts.domAdapterOnInserted,
            &parser_scripts.domAdapterOnRemoved,
            &parser_scripts.domAdapterOnChildrenMoved,
        );
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
            options.scripting_enabled,
        );
        // Preserve the embedder override before navigation classic fetches.
        // Persistent state permits stylesheet waits independently of this.
        self.script_context.can_suspend = script_created;
        self.script_context.setBaseUrl(self.base_url);
        if (options.script_loader) |loader| {
            self.owned_loader = loader.acquire();
            self.script_context.setScriptLoader(loader.loadScript, loader.context);
        }
        self.tree_builder.setScriptEndCheckpointCallback(&parser_scripts.parserScriptEndCheckpoint, &self.script_context);
        if (options.scripting_enabled) self.tree_builder.setScriptExecutionCallback(&parser_scripts.parserScriptCallback, &self.script_context);
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
        const self: *DocumentParser = @fieldParentPtr("adapter", adapter);
        const instance = adapter.getDomNode(node) orelse return;
        if (instance == self.document or !self.ctx.hasEngine()) return;
        if (runtime.SlabAllocator.generationOf(self.document) != self.document_generation) return;
        // A parser reference is a collector edge from its document, like
        // Blink HTMLTreeBuilder::Trace visiting its open-element stack.
        // A detached node must survive until this parser releases it, while
        // an unreachable document/parser/node cycle must remain collectable.
        const slot = std.fmt.allocPrint(self.allocator, "document-parser:{x}", .{@intFromPtr(node)}) catch return;
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

    pub fn retain(self: *DocumentParser) void {
        self.references += 1;
    }

    pub fn release(self: *DocumentParser) void {
        self.references -= 1;
        if (self.references != 0) return;
        std.debug.assert(self.pump_depth == 0);
        if (!self.document_destroyed) self.forgetParserReferences();
        self.adapter.deinit();
        self.tree_builder.deinit();
        self.input_stream.deinit();
        self.tokenizer.deinit();
        if (self.owned_loader) |*loader| loader.deinit();
        if (self.original_bytes) |bytes| self.allocator.free(bytes);
        self.allocator.free(self.base_url);
        for (self.traced_slots.toSlice()) |slot| self.allocator.free(slot);
        self.traced_slots.deinit();
        self.allocator.destroy(self);
    }

    /// Stop an old parser without freeing a pump a script has reentered.
    /// The document clears its association before dropping its reference.
    pub fn detach(self: *DocumentParser) void {
        if (self.detached) return;
        self.detached = true;
        self.input_stream.aborted = true;
        self.input_stream.insertion_point = null;
    }

    /// Document's wrapper owns its traced edges. A collector teardown lets
    /// those die with the wrapper, without manipulating edges during GC.
    pub fn detachForDocumentDestruction(self: *DocumentParser) void {
        self.document_destroyed = true;
        // Teardown never runs parser callbacks or script. Destroying the
        // private tree below releases its stack storage without observable
        // finished-parsing-children steps against a retired document.
        self.detached = true;
        self.input_stream.aborted = true;
        self.input_stream.insertion_point = null;
    }

    fn forgetParserReferences(self: *DocumentParser) void {
        // A frame can retire its realm while a written script still holds
        // this parser on the stack. The saved context remains allocated;
        // do not dereference a document the collector has already recycled.
        if (!self.ctx.hasEngine()) return;
        if (runtime.SlabAllocator.generationOf(self.document) != self.document_generation) return;
        for (self.traced_slots.toSlice()) |slot| @import("engine").forgetTracedChild(self.document, .{ .name = slot });
    }

    fn retainProcessor(context: *anyopaque) void {
        const self: *DocumentParser = @ptrCast(@alignCast(context));
        self.retain();
    }

    fn releaseProcessor(context: *anyopaque) void {
        const self: *DocumentParser = @ptrCast(@alignCast(context));
        self.release();
    }

    fn afterProcess(context: *anyopaque) void {
        const self: *DocumentParser = @ptrCast(@alignCast(context));
        self.finishIfPossible() catch |err| log.warn("document.close(): the parser stopped: {}", .{err});
    }

    fn abortProcessor(context: *anyopaque) void {
        const self: *DocumentParser = @ptrCast(@alignCast(context));
        self.tree_builder.abort();
    }

    fn process(context: *anyopaque) void {
        const self: *DocumentParser = @ptrCast(@alignCast(context));
        self.pump() catch |err| log.warn("document.write(): the parser stopped: {}", .{err});
    }

    fn pump(self: *DocumentParser) !void {
        if (self.detached or self.eof_processed) return;
        if (!self.isCurrent()) {
            self.detach();
            return;
        }
        self.pump_depth += 1;
        defer self.pump_depth -= 1;
        parser_scripts.resumeAfterBlockingScript(&self.script_context);
        if (self.detached or !self.isCurrent()) return;
        try self.tree_builder.parse();
    }

    fn isCurrent(self: *const DocumentParser) bool {
        if (self.document_destroyed or (self.had_engine and !self.ctx.hasEngine())) return false;
        if (runtime.SlabAllocator.generationOf(self.document) != self.document_generation) return false;
        const internal = document_internals.getInternal(self.document) orelse return false;
        return !internal.destroyed and internal.active_parser == self and internal.parser_epoch == self.document_epoch;
    }

    /// Called after the input stream restored a write's stop position. A
    /// nested close only marks EOF; the outermost write finishes the parser.
    pub fn finishIfPossible(self: *DocumentParser) !void {
        if (self.detached or self.eof_processed or !self.input_stream.complete or self.pump_depth != 0) return;
        if (!self.isCurrent()) return;
        const internal = document_internals.getInternal(self.document) orelse return;
        if (internal.scripts.pending_parsing_blocking_script != null) return;
        try self.pump();
        if (self.detached or !self.isCurrent() or !self.input_stream.eof_processed) return;
        self.eof_processed = true;
        self.on_finished(self.document, self);
    }

    /// HTML 8.4.2 steps 4-6. EOF is explicit and can only be processed once.
    pub fn close(self: *DocumentParser) !void {
        self.input_stream.complete = true;
        try self.finishIfPossible();
    }
};

/// Parse an HTML document, building its DOM as it goes and running its
/// scripts at their end tags - the complete-input driver for the top-level
/// page (HTMLParser.parseHTMLWithScripting) and a frame (HTMLIFrameElement).
/// Both navigation and script-created documents retain these stages across
/// waits and successive writes. The Document owns eventual completion.
///
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html
///
/// DOM nodes are created as the tree builder creates their tree nodes, so a
/// script sees everything parsed before it. The input is an input stream
/// document.write() inserts into: while the parser runs, the document holds
/// the stream, a script the parser runs has an insertion point, and what it
/// writes is parsed before write() returns (the document write steps, step
/// 11). Returning may mean a stylesheet wait; only actual EOF runs "the end".
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

    // The initiating call holds its own reference through callbacks. The
    // association acquires another, so either EOF or a reentrant open can
    // release Document's ownership without freeing this invocation's state.
    const parser = DocumentParser.createComplete(allocator, ctx, document, html, options) catch return error.OutOfMemory;
    defer parser.release();
    if (!dom.document_lifecycle.associateParser(document, parser)) return error.InvalidStateError;
    errdefer if ((!had_engine or ctx.hasEngine()) and
        runtime.SlabAllocator.generationOf(document) == document_generation)
        dom.document_lifecycle.discardParser(document, parser);
    parser.pump() catch return error.TreeBuilderError;
    parser.finishIfPossible() catch return error.TreeBuilderError;

    // Actual EOF detaches normally; open/abort/destruction detach without
    // EOF. A returned loading document still owns its suspended parser.
    if ((had_engine and !ctx.hasEngine()) or runtime.SlabAllocator.generationOf(document) != document_generation or
        (parser.detached and !parser.eof_processed) or
        ((!parser.detached or parser.eof_processed) and
            (document_internals.getInternal(document) orelse return document).parser_epoch != parser.document_epoch))
    {
        if (options.parser_canceled) |canceled| canceled.* = true;
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
