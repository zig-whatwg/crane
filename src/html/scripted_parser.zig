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
const engine = @import("engine");

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
const StreamedBody = html_core.navigation.fetch_integration.StreamedBody;

// The adapter that builds the DOM as the tree builder builds its tree, and
// the parser's script end-tag steps.
const parser_scripts = @import("parser_script_execution.zig");
const parser_mutation = @import("parser_dom_mutation.zig");
const speculative_fetch = @import("speculative_fetch.zig");
const script_execution = @import("script_execution.zig");
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

    /// The rest of a navigation's response body, still arriving (HTML 7.5.1
    /// "load an HTML document": the networking tasks fill the parser's input
    /// byte stream as the bytes come). The parser takes it - it is the
    /// body's reader from here, until the body ends or the parser stops -
    /// and the input given with these options is empty. Implies a byte
    /// stream: `byte_stream`'s Content-Type and parent encoding still apply.
    body_stream: ?*StreamedBody = null,

    /// The tree builder's "parser cannot change the mode flag": set by "load
    /// a text document" steps 2-3 ("Set document's parser cannot change the
    /// mode flag to true. Set document's mode to "no-quirks"") before the
    /// parse - and by the media document Crane parses from synthesized markup
    /// ("load a media document" step 2's no-quirks) - so the markup's missing
    /// DOCTYPE leaves the mode alone.
    parser_cannot_change_mode: bool = false,
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
const meta_charset_scan = html_core.parser.meta_charset_scan;
const log = std.log.scoped(.scripted_parser);

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
    /// A navigation body's first bytes, kept only while BOM and XML-declaration
    /// prefix checks are unresolved (`NetworkInput.prefix_checked`).
    raw_bytes: std.ArrayListUnmanaged(u8) = .empty,
    /// The response body this navigation parser reads as it arrives, or null
    /// for input given whole (`ParseOptions.body_stream`).
    network: ?NetworkInput = null,
    owned_loader: ?OwnedScriptLoader = null,
    /// Only active native calls root the Document; a suspended parser keeps
    /// no independent root, so an unreachable Document/parser graph collects.
    active_calls: usize = 0,
    active_document: ?engine.Owned = null,
    /// While a call runs (`active_calls` > 0), this parser is linked into its
    /// Document's `parsers_on_stack`, so the Document traces what it holds
    /// even after document.open() replaced it (the wrapper redesign's P6).
    on_stack: bool = false,
    next_on_stack: ?*DocumentParser = null,
    /// The outermost active call's counted reference on the Document,
    /// beside `active_document` (refcount step 5a: a step that can run
    /// script holds what it works on, as WebKit's protect-across-a-call
    /// does). The parser's own link to its Document stays raw: the Document
    /// owns the parser (WebKit HTMLConstructionSite `WeakRef<Document>
    /// m_document`).
    active_document_ref: dom.node_holds.CountedRef = .{},
    /// A terminal failure (an allocation in node creation):
    /// input is discarded and parsing never resumes.
    trace_failure: ?anyerror = null,
    failed_processor_calls: usize = 0,
    /// Document owns one reference. Initiation and each write/close/resume
    /// hold another across callbacks and insertion-limit restoration.
    references: usize = 1,
    pump_depth: usize = 0,
    detached: bool = false,
    document_destroyed: bool = false,
    eof_processed: bool = false,
    on_finished: *const fn (*runtime.Instance, *DocumentParser) void,
    /// What owns a fragment parser that runs over time (streaming HTML:
    /// html.stream_html's parser), for its `on_finished`; null for a
    /// document's own parser.
    owner: ?*anyopaque = null,
    /// A fragment parser that runs over time hears when something it waits
    /// on after its end is ready (a deferred script: html.stream_html's
    /// "execute the deferred scripts"), its input stream processed again
    /// after it stopped parsing (`afterProcess`). Null for a document's own.
    on_resumed_after_end: ?*const fn (*DocumentParser) void = null,
    /// A fragment parser's owner resumes it once its pending
    /// parsing-blocking script is ready (html.stream_html: "execute the
    /// pending parsing-blocking scripts", then "run a fragment parser").
    /// Null: the input stream's inserted characters are processed again.
    on_blocking_script_ready: ?*const fn (*DocumentParser) void = null,
    /// HTML 13.2.8: this parser's speculative HTML parser - active while the
    /// parser waits for a pending parsing-blocking script, kept between waits
    /// while it is still ahead of the parser (speculative_fetch.Speculation).
    /// Null: none started, or stopped.
    speculation: ?*speculative_fetch.Speculation = null,
    /// A task to run the speculation's next slice is queued (`SpeculationTask`).
    speculation_queued: bool = false,

    pub fn create(
        allocator: Allocator,
        ctx: runtime.Context,
        document: *runtime.Instance,
        scripting_enabled: bool,
        on_finished: *const fn (*runtime.Instance, *DocumentParser) void,
    ) !*DocumentParser {
        return createWithInput(allocator, ctx, document, "", .{ .scripting_enabled = scripting_enabled }, true, on_finished);
    }

    /// Copies all input retained beyond initiation. A byte stream is decoded
    /// whole with the encoding the sniffing algorithm decides: no meta the
    /// tree builder meets later changes it (encoding_sniffing.zig, the
    /// browser deviation).
    pub fn createComplete(allocator: Allocator, ctx: runtime.Context, document: *runtime.Instance, html: []const u8, options: ParseOptions) !*DocumentParser {
        var decoded: ?[]u8 = null;
        defer if (decoded) |input| allocator.free(input);
        if (options.byte_stream) |stream| {
            const result = try meta_charset_scan.sniff(allocator, html, .{
                .transport = if (stream.content_type) |ct| encoding_sniffing.transportEncoding(allocator, ct) else null,
                .parent = if (stream.parent_encoding) |name| encoding_sniffing.lookup(name) else null,
            });
            try document_internals.setEncoding(document, encoding_sniffing.canonicalName(result.encoding));
            decoded = try encoding_sniffing.decode(allocator, html, result.encoding);
        }
        return createWithInput(allocator, ctx, document, decoded orelse html, options, false, &navigationFinished);
    }

    /// A navigation parser that reads its input from `options.body_stream`
    /// as the response body arrives (HTML 7.5.1 "load an HTML document").
    /// Takes the body even when it fails. The parser is not script-created:
    /// its insertion point is undefined. Its input is not complete until the
    /// body ends, so the tokenizer suspends at the end of what has arrived
    /// and "the end" waits for the body's end (the implied EOF).
    ///
    /// Design: Blink's DocumentLoader::BodyDataReceived ->
    /// HTMLDocumentParser::AppendBytes and WebKit's DocumentLoader::
    /// dataReceived -> DocumentWriter::addData hand each received chunk to
    /// the document's parser; here the parser itself is the body's reader,
    /// so the body, its decoding state and EOF share the parser's lifetime
    /// (docs/lessons/architecture-complete-input-can-still-suspend-its-parser.md).
    pub fn createStreaming(allocator: Allocator, ctx: runtime.Context, document: *runtime.Instance, options: ParseOptions) !*DocumentParser {
        const body = options.body_stream orelse return error.InvalidInput;
        var body_owned = true;
        errdefer if (body_owned) body.release();
        const pipe = body.reader() orelse return error.InvalidInput;
        const stream = options.byte_stream orelse ByteStream{};
        // The sniffing algorithm's inputs other than the bytes, resolved now:
        // the slices they come from are the caller's.
        const transport = if (stream.content_type) |ct| encoding_sniffing.transportEncoding(allocator, ct) else null;
        const parent = if (stream.parent_encoding) |name| encoding_sniffing.lookup(name) else null;
        const self = try createWithInput(allocator, ctx, document, "", options, false, &navigationFinished);
        errdefer self.release();
        self.input_stream.complete = false;
        self.network = .{ .body = body, .transport = transport, .parent = parent };
        body_owned = false;
        body.handTo(.{ .context = self, .alive = &NetworkInput.holds });
        pipe.consumer = .{ .context = self, .notify = &NetworkInput.notify };
        return self;
    }

    /// A script-created parser - it reaches the end of its input only at an
    /// explicit EOF - for `document`, a fragment parser's Document (HTML
    /// "initialize an HTML fragment parser" step 5, for streaming HTML): the
    /// caller sets up the fragment case on its tree builder and tokenizer
    /// (dom_parser.FragmentCase) and associates it with the document.
    pub fn createFragment(
        allocator: Allocator,
        ctx: runtime.Context,
        document: *runtime.Instance,
        scripting_enabled: bool,
        on_finished: *const fn (*runtime.Instance, *DocumentParser) void,
    ) !*DocumentParser {
        return createWithInput(allocator, ctx, document, "", .{ .scripting_enabled = scripting_enabled }, true, on_finished);
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
        self.adapter.mapDocument(self.tree_builder.document);
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
        // The builder's structures hold their DOM nodes counted (refcount
        // step 5a; WebKit HTMLStackItem / HTMLConstructionSite m_form).
        self.tree_builder.setDomAdapterStructureHoldCallbacks(
            &parser_scripts.domAdapterOnStructureHold,
            &parser_scripts.domAdapterOnStructureRelease,
        );
        self.tree_builder.setDomAdapterDeclarativeShadowCallback(&parser_scripts.domAdapterAttachDeclarativeShadow);
        // "Insert a character" appends to the LIVE DOM's previous sibling.
        self.tree_builder.setDomAdapterTextBeforeCallback(&parser_scripts.domAdapterTextBefore);
        // A <template for> finds its markers in, and patches, the live DOM.
        self.tree_builder.setDomAdapterContentPatchingCallbacks(
            &parser_scripts.domAdapterPrepareContentPatching,
            &parser_scripts.domAdapterFinishContentPatching,
        );
        // A script the input ended inside is already started.
        self.tree_builder.dom_adapter_on_unclosed_script = &parser_scripts.domAdapterOnUnclosedScript;
        // The parser's "allow declarative shadow roots" is its document's:
        // navigation's document and document.open (step 16) create it so.
        self.tree_builder.allow_declarative_shadow_roots = document_internals.allowsDeclarativeShadowRoots(document);
        self.adapter.notifies_children_finished = true;
        if (document_internals.getURL(document)) |url| self.tree_builder.iframe_srcdoc = matchesAboutSrcdoc(url);
        // "Load a text document" steps 2-3 / "load a media document" step 2.
        self.tree_builder.parser_cannot_change_mode = options.parser_cannot_change_mode;
        self.script_context = ParserScriptContext.init(
            allocator,
            ctx,
            document,
            &self.adapter,
            &self.tree_builder,
            options.scripting_enabled,
        );
        // Every document parser - navigation's, a frame's, a popup's and a
        // script-created one - is Document-owned and survives a wait, so a
        // parser-blocking classic script is fetched asynchronously and the
        // parser waits at its end tag while the event loop spins (HTML "an
        // end tag whose tag name is script": "spin the event loop until ...
        // the script's ready to be parser-executed"). The fetch's task marks
        // the script ready, and that resumes this parser (script_execution
        // markReadyNow -> input_stream.processInserted -> pump). The
        // embedder's loader still answers first (script_execution's
        // prepare, step 33.11).
        self.script_context.can_suspend = true;
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
            .resume_after_blocking_script = &resumeAfterBlockingScript,
        };
        errdefer if (self.owned_loader) |*loader| loader.deinit();
        return self;
    }

    fn nodeCreated(node: *TreeNode, context: ?*anyopaque) void {
        const adapter: *DomTreeAdapter = @ptrCast(@alignCast(context orelse return));
        const self: *DocumentParser = @fieldParentPtr("adapter", adapter);
        if (self.trace_failure != null) return;
        // No wrapper and no engine call per node: the parser's structures are
        // its holds (design 5.1).
        adapter.onNodeCreated(node) catch |err| self.failedNode(node, err);
    }

    fn failedNode(self: *DocumentParser, node: *TreeNode, err: anyerror) void {
        // The callback cannot return an error. Revoke this node's published
        // mapping before later callbacks for the same token can use it. An
        // unwrapped orphan stays with the adapter; a made wrapper is GC-owned.
        if (node.dom_node) |opaque_node| {
            const instance: *runtime.Instance = @ptrCast(@alignCast(opaque_node));
            if (runtime.SlabAllocator.generationOf(instance) == node.dom_generation and engine.hasWrapper(instance))
                self.adapter.removeOrphan(node);
        }
        // Its counted references go with the mapping.
        self.adapter.dropReferences(node);
        node.dom_revoked = true;
        self.trace_failure = err;
        self.input_stream.discardInput();
    }

    /// Protect native parser state across an entire call, including
    /// callbacks, input-limit restoration and final native cleanup. The
    /// outermost call roots the Document; a suspended parser roots nothing.
    pub const ActiveCall = struct {
        parser: *DocumentParser,

        pub fn deinit(self: ActiveCall) void {
            const parser = self.parser;
            std.debug.assert(parser.active_calls > 0);
            parser.active_calls -= 1;
            const document = if (parser.active_calls == 0) parser.active_document else null;
            if (parser.active_calls == 0) parser.active_document = null;
            var document_ref: dom.node_holds.CountedRef = .{};
            const document_instance = parser.document;
            if (parser.active_calls == 0) {
                parser.leaveStack();
                document_ref = parser.active_document_ref;
                parser.active_document_ref = .{};
            }
            // release may destroy parser. The extracted root stays alive
            // through adapter cleanup; nothing below dereferences parser.
            parser.release();
            document_ref.release(document_instance);
            if (document) |held| held.release();
        }
    };

    /// Fallibly acquire active-call ownership before anything can run script.
    /// Nested calls share the outer root, but each owns a native reference.
    pub fn protect(self: *DocumentParser) !ActiveCall {
        if (self.trace_failure) |err| return err;
        return self.protectForCleanup();
    }

    /// Acquire only cleanup ownership after a parse failure. This does not
    /// clear that failure or permit the input processor to resume parsing.
    pub fn protectForCleanup(self: *DocumentParser) !ActiveCall {
        if (self.active_calls == 0 and !self.isCurrent()) return error.InvalidStateError;
        if (self.active_calls == 0 and self.ctx.hasEngine()) {
            const document = try engine.retainValue(self.ctx, .{ .instance = self.document });
            errdefer document.release();
            if (!self.isCurrent()) return error.InvalidStateError;
            self.active_document = document;
        }
        if (self.active_calls == 0) {
            self.active_document_ref.take(self.document, dom.instance_bridge.getNodeBase(self.document));
            self.enterStack();
        }
        self.active_calls += 1;
        self.retain();
        return .{ .parser = self };
    }

    /// The outermost call starts: the Document traces this parser's nodes
    /// until it ends (`parsers_on_stack`), replaced or not. The call holds
    /// the Document.
    fn enterStack(self: *DocumentParser) void {
        std.debug.assert(!self.on_stack);
        const internal = document_internals.getInternal(self.document) orelse return;
        self.next_on_stack = internal.parsers_on_stack;
        internal.parsers_on_stack = self;
        self.on_stack = true;
    }

    /// The outermost call ends: off the Document's list - unless the
    /// Document went under the call (a forced realm end), which took the
    /// list with it.
    fn leaveStack(self: *DocumentParser) void {
        if (!self.on_stack) return;
        self.on_stack = false;
        defer self.next_on_stack = null;
        if (runtime.SlabAllocator.generationOf(self.document) != self.document_generation) return;
        const internal = document_internals.getInternal(self.document) orelse return;
        var link = &internal.parsers_on_stack;
        while (link.*) |parser| : (link = &parser.next_on_stack) {
            if (parser != self) continue;
            link.* = self.next_on_stack;
            return;
        }
    }

    pub fn retain(self: *DocumentParser) void {
        self.references += 1;
    }

    pub fn release(self: *DocumentParser) void {
        self.references -= 1;
        if (self.references != 0) return;
        std.debug.assert(self.pump_depth == 0);
        std.debug.assert(self.active_calls == 0);
        // The structures' counted references end while the adapter that
        // took them is still here.
        self.tree_builder.releaseStructureHolds();
        self.adapter.deinit();
        self.tree_builder.deinit();
        self.input_stream.deinit();
        self.tokenizer.deinit();
        if (self.owned_loader) |*loader| loader.deinit();
        self.stopSpeculation();
        self.releaseNetworkInput();
        if (self.network) |*input| input.releaseScanner();
        self.raw_bytes.deinit(self.allocator);
        self.allocator.free(self.base_url);
        self.allocator.destroy(self);
    }

    /// Stop an old parser without freeing a pump a script has reentered.
    /// The document clears its association before dropping its reference.
    pub fn detach(self: *DocumentParser) void {
        if (self.detached) return;
        // Holds stay until release: frames still unwinding through this
        // parser may work on its stack - abort step 4 pops it after a
        // readiness listener replaced the parser (design 5.6; Blink's
        // HTMLConstructionSite::Detach keeps the stack "because
        // HTMLConstructionSite might be on the callstack"). Its Document
        // traces only its active parser: a detached one's nodes are kept by
        // their counted holds, their wrappers by script's own reach.
        self.detached = true;
        self.input_stream.aborted = true;
        self.input_stream.insertion_point = null;
        // HTML "abort a parser" step 4: "Stop the speculative HTML parser for
        // this HTML parser."
        self.stopSpeculation();
        // HTML "abort a document": any further data received from the
        // network is discarded - the body's transfer stops.
        self.releaseNetworkInput();
    }

    /// The Document is being destroyed: nothing of it is touched from here.
    pub fn detachForDocumentDestruction(self: *DocumentParser) void {
        self.document_destroyed = true;
        // Teardown never runs parser callbacks or script. Destroying the
        // private tree below releases its stack storage without observable
        // finished-parsing-children steps against a retired document.
        self.detached = true;
        self.input_stream.aborted = true;
        self.input_stream.insertion_point = null;
        self.stopSpeculation();
        // Releasing the body only cancels its transfer: native, no script.
        self.releaseNetworkInput();
    }

    /// The node `tree_node` names, as the DOM's tree node, if it is alive.
    fn heldBase(self: *const DocumentParser, tree_node: *TreeNode) ?*dom.NodeBase {
        const instance = self.adapter.getDomNode(tree_node) orelse return null;
        if (instance == self.document) return null;
        return dom.instance_bridge.getNodeBase(instance);
    }

    /// HTML "is on a stack of open elements of an HTML parser whose
    /// associated Document is doc" for this parser (Document asks its
    /// active one; WebKit's HTMLDocumentParser::isOnStackOfOpenElements).
    /// The element the tree builder is inserting counts as on the stack: it
    /// pushes it right after the insertion (HTML "insert a foreign element"
    /// steps 3-4), WebKit pushes before its queued attach runs, and Blink's
    /// insertion steps skip an element whose children are not parsed yet - a
    /// parsed expect link's target unblocks when the parser POPS it.
    /// O(stack depth).
    pub fn isOnStackOfOpenElements(self: *const DocumentParser, element: *runtime.Instance) bool {
        if (self.document_destroyed or !self.adapter.isAlive()) return false;
        if (self.adapter.inserting) |tree_node| {
            if (self.adapter.getDomNode(tree_node) == element) return true;
        }
        for (self.tree_builder.heldNodes().stack) |tree_node| {
            if (self.adapter.getDomNode(tree_node) == element) return true;
        }
        return false;
    }

    /// The nodes this parser's structures hold, named to the collector (the
    /// wrapper redesign's P6, design 4.4 "Holders"; refcount step 9a): the
    /// stack of open elements, the head and form element pointers, the list
    /// of active formatting elements, and a patching template's target and
    /// markers - each node's own wrapper and every wrapper of its trees
    /// (dom.wrapper_tracing.traceHeld). Blink's Document::Trace visits its
    /// parser_, whose HTMLConstructionSite::Trace visits open_elements_,
    /// active_formatting_elements_, head_ and form_ (core/html/parser/
    /// html_construction_site.cc, Chromium 131.0.6778.0), and keeps a
    /// patch's parent_ strongly. Called from the Document's own trace while
    /// the collector marks, in its atomic pause: reads only. The stack is
    /// normally a parent chain, so an entry whose parent is the previous
    /// entry is in a tree already named and is not looked up again: O(stack
    /// depth).
    pub fn traceHeldNodes(self: *const DocumentParser, tracer: *engine.Tracer) void {
        if (self.document_destroyed or !self.adapter.isAlive()) return;
        const held = self.tree_builder.heldNodes();
        var previous: ?*dom.NodeBase = null;
        for (held.stack) |tree_node| {
            const base = self.heldBase(tree_node) orelse continue;
            defer previous = base;
            if (previous != null and base.parent_node == previous) continue;
            dom.wrapper_tracing.traceHeld(base, tracer);
        }
        for ([_]?*TreeNode{ held.head, held.form }) |pointer| {
            const base = self.heldBase(pointer orelse continue) orelse continue;
            dom.wrapper_tracing.traceHeld(base, tracer);
        }
        for (held.formatting) |entry| switch (entry) {
            .marker => {},
            .element => |element| {
                const base = self.heldBase(element.node) orelse continue;
                dom.wrapper_tracing.traceHeld(base, tracer);
            },
        };
        for (held.stack) |tree_node| {
            const patch = tree_node.content_patch orelse continue;
            const nodes = [_]struct { ?*anyopaque, u64 }{
                .{ patch.target, patch.target_generation },
                .{ patch.start, patch.start_generation },
                .{ patch.end, patch.end_generation },
            };
            for (nodes) |node| {
                const instance = parser_mutation.liveNode(node[0], node[1]) orelse continue;
                const base = dom.instance_bridge.getNodeBase(instance) orelse continue;
                dom.wrapper_tracing.traceHeld(base, tracer);
            }
        }
    }

    fn retainProcessor(context: *anyopaque) void {
        const self: *DocumentParser = @ptrCast(@alignCast(context));
        _ = self.protect() catch |err| {
            // Processor's callback cannot fail. Keep its native storage for
            // restoration, but never enter parsing after root acquisition failed.
            self.retain();
            self.failed_processor_calls += 1;
            self.trace_failure = err;
            self.input_stream.discardInput();
            return;
        };
    }

    fn releaseProcessor(context: *anyopaque) void {
        const self: *DocumentParser = @ptrCast(@alignCast(context));
        if (self.failed_processor_calls != 0) {
            self.failed_processor_calls -= 1;
            self.release();
        } else (ActiveCall{ .parser = self }).deinit();
    }

    fn afterProcess(context: *anyopaque) void {
        const self: *DocumentParser = @ptrCast(@alignCast(context));
        if (self.eof_processed) {
            if (self.on_resumed_after_end) |resumed| resumed(self);
            return;
        }
        self.finishIfPossible() catch |err| log.warn("document.close(): the parser stopped: {}", .{err});
    }

    fn resumeAfterBlockingScript(context: *anyopaque) void {
        const self: *DocumentParser = @ptrCast(@alignCast(context));
        if (self.on_blocking_script_ready) |resumed| return resumed(self);
        self.input_stream.processInserted();
    }

    /// HTML "execute the pending parsing-blocking scripts" for this parser,
    /// alone: the parser does not read on (its owner runs it after).
    pub fn executePendingParsingBlockingScripts(self: *DocumentParser) void {
        if (self.trace_failure != null or self.detached or self.eof_processed) return;
        if (!self.isCurrent()) return;
        const call = self.protect() catch return;
        defer call.deinit();
        parser_scripts.resumeAfterBlockingScript(&self.script_context);
    }

    fn abortProcessor(context: *anyopaque) void {
        const self: *DocumentParser = @ptrCast(@alignCast(context));
        if (self.trace_failure != null) return;
        self.tree_builder.abort();
    }

    fn process(context: *anyopaque) void {
        const self: *DocumentParser = @ptrCast(@alignCast(context));
        self.pump() catch |err| log.warn("document.write(): the parser stopped: {}", .{err});
    }

    fn pump(self: *DocumentParser) !void {
        if (self.trace_failure) |err| return err;
        if (self.detached or self.eof_processed) return;
        if (!self.isCurrent()) {
            self.detach();
            return;
        }
        const call = try self.protect();
        defer call.deinit();
        self.pump_depth += 1;
        defer self.pump_depth -= 1;
        // "Execute the pending parsing-blocking scripts" step 7: the wait is
        // over - "stop the speculative HTML parser" - before the script runs.
        if (self.pump_depth == 1 and script_execution.pendingParserBlockingScriptReady(self.document)) self.pauseSpeculation();
        parser_scripts.resumeAfterBlockingScript(&self.script_context);
        if (self.detached or !self.isCurrent()) return;
        try self.tree_builder.parse();
        if (self.trace_failure) |err| return err;
        if (self.pump_depth == 1) self.speculateWhileWaiting();
    }

    /// "Execute the pending parsing-blocking scripts" step 3, "start the
    /// speculative HTML parser for parser", when this parser has stopped to
    /// wait for its document's pending parsing-blocking script: a
    /// speculative parser starts at the parser's next input character "with
    /// the same state as parser", reads to the end of the input there is,
    /// and fetches what it finds (speculative_fetch). One still ahead of the
    /// parser over an unchanged stream goes on instead (Speculation.covers).
    /// Step 2: never for a fragment parser (streaming HTML's - `owner`); "an
    /// element created in an inert Document" fetches nothing, which the
    /// speculation checks; with scripting disabled no script waits.
    fn speculateWhileWaiting(self: *DocumentParser) void {
        if (self.owner != null or !self.tree_builder.scripting_enabled) return;
        if (self.detached or self.eof_processed or !self.isCurrent()) return;
        if (!self.tree_builder.waiting_for_parser_blocking_script or self.tree_builder.script_nesting_level != 0) return;
        if (script_execution.pendingParsingBlockingScript(self.document) == null) return;
        if (script_execution.pendingParserBlockingScriptReady(self.document)) return;
        const stream = &self.input_stream;
        const position = self.tokenizer.nextInputPosition();
        if (self.speculation) |current| {
            if (!current.covers(position, stream.insertions)) self.stopSpeculation();
        }
        if (self.speculation == null) {
            const options: @import("speculative_parser.zig").Options = .{
                .input = stream.buffer.items[@min(position, stream.buffer.items.len)..],
                .complete = stream.complete,
                .scripting = self.tree_builder.scripting_enabled,
                .media = dom.style.hooks.mediaValues(self.document),
                .in_body = (interfaces.Document.get_body(self.document) catch null) != null,
                .base_known = document_internals.getFrozenBaseURL(self.document) != null,
            };
            self.speculation = speculative_fetch.Speculation.create(self.allocator, self.document, options, position, stream.insertions) catch return;
        }
        self.speculation.?.active = true;
        self.queueSpeculationSlice(.give_way);
    }

    /// What a speculation task does when it runs.
    const SpeculationStep = enum {
        /// Queue the slice behind what was queued meanwhile: the event loop's
        /// network step queues a response's task after the tasks of its turn,
        /// so a slice queued in that turn would run ahead of it - and the
        /// pending parsing-blocking script's response, a cache hit's
        /// included, would wait for a slice it does not need.
        give_way,
        /// Read one slice.
        scan,
    };

    /// The speculative parser reads on in slices, a task each, while the
    /// parser waits (speculative_fetch.Speculation.scanSlice), each slice
    /// behind a task that gives way to what the network delivered; with no
    /// event loop, at once.
    fn queueSpeculationSlice(self: *DocumentParser, step: SpeculationStep) void {
        const speculation = self.speculation orelse return;
        if (!speculation.active or self.speculation_queued) return;
        const loop = self.ctx.getOptionalEventLoop() orelse {
            _ = speculation.scanSlice(std.math.maxInt(usize));
            return;
        };
        const task = self.allocator.create(SpeculationTask) catch return;
        task.* = .{ .parser = self, .step = step };
        self.speculation_queued = true;
        self.retain();
        // A task on the networking task source given the document's relevant
        // global, as the parser's own reads are (HTML 7.5.1).
        loop.queueTask(.{
            .callback = &SpeculationTask.run,
            .context = task,
            .drop = &SpeculationTask.drop,
            .document = self.document,
            .document_generation = self.document_generation,
        });
    }

    const SpeculationTask = struct {
        parser: *DocumentParser,
        step: SpeculationStep,

        fn run(context: ?*anyopaque) void {
            const self: *SpeculationTask = @ptrCast(@alignCast(context.?));
            const parser = self.parser;
            const step = self.step;
            parser.allocator.destroy(self);
            defer parser.release();
            parser.speculation_queued = false;
            if (parser.detached or parser.eof_processed or !parser.isCurrent()) return;
            const speculation = parser.speculation orelse return;
            switch (step) {
                .give_way => parser.queueSpeculationSlice(.scan),
                .scan => if (speculation.scanSlice(speculative_fetch.Speculation.slice_bytes)) parser.queueSpeculationSlice(.give_way),
            }
        }

        fn drop(context: ?*anyopaque) void {
            const self: *SpeculationTask = @ptrCast(@alignCast(context.?));
            const parser = self.parser;
            parser.allocator.destroy(self);
            parser.speculation_queued = false;
            parser.release();
        }
    };

    /// The wait is over (step 7): the speculation stops reading. It is kept
    /// while it is ahead of the parser, for the next wait.
    fn pauseSpeculation(self: *DocumentParser) void {
        if (self.speculation) |speculation| speculation.active = false;
    }

    /// "Stop the speculative HTML parser": its input and what it found to
    /// fetch go (the fetches it started run on, for the document's map).
    fn stopSpeculation(self: *DocumentParser) void {
        const speculation = self.speculation orelse return;
        self.speculation = null;
        speculation.destroy();
    }

    fn isCurrent(self: *const DocumentParser) bool {
        if (self.detached or self.document_destroyed or (self.had_engine and !self.ctx.hasEngine())) return false;
        if (runtime.SlabAllocator.generationOf(self.document) != self.document_generation) return false;
        const internal = document_internals.getInternal(self.document) orelse return false;
        // HTML open steps 16-17 may associate a new parser with a retained
        // document after its navigable was destroyed. That lifecycle flag
        // governs activity, not native ownership; destruction already detached
        // the preceding parser. Keep the association/epoch/generation checks.
        return internal.active_parser == self and internal.parser_epoch == self.document_epoch;
    }

    /// Called after the input stream restored a write's stop position. A
    /// nested close only marks EOF; the outermost write finishes the parser.
    pub fn finishIfPossible(self: *DocumentParser) !void {
        if (self.trace_failure) |err| return err;
        if (self.detached or self.eof_processed or !self.input_stream.complete or self.pump_depth != 0) return;
        if (!self.isCurrent()) return;
        const internal = document_internals.getInternal(self.document) orelse return;
        if (internal.scripts.pending_parsing_blocking_script != null) return;
        const call = try self.protect();
        defer call.deinit();
        try self.pump();
        if (self.detached or !self.isCurrent() or !self.input_stream.eof_processed) return;
        self.eof_processed = true;
        // "Stop parsing" step 1: "If the active speculative HTML parser is not
        // null, then stop the speculative HTML parser" - and what it fetched
        // that no element took leaves the document's map (Blink
        // Document::FinishedParsing -> ClearPreloads(kClearSpeculativeMarkupPreloads)).
        if (self.speculation != null) {
            self.stopSpeculation();
            if (dom.document_resources.of(self.document)) |resources| resources.dropSpeculative();
        }
        // The parse is over: the document's shared attribute blocks start
        // their 10 s (dom.attribute_block_cache).
        self.adapter.finishedParsing();
        self.on_finished(self.document, self);
    }

    /// The networking task of a body still arriving: what has arrived goes
    /// into the input byte stream, and the parser processes it (HTML 7.5.1
    /// "load an HTML document"). Once the body has ended, the input is
    /// complete: the parser processes the implied EOF, which runs "the end"
    /// once no parsing-blocking script holds it. A parser that stopped (a
    /// document.open, an abort, a destroyed document) lets the body go.
    pub fn readNetworkInput(self: *DocumentParser) void {
        self.retain();
        defer self.release();
        self.readArrived() catch |err| {
            log.warn("navigation body: the parser stopped reading: {}", .{err});
            self.releaseNetworkInput();
            self.input_stream.complete = true;
            self.finishIfPossible() catch {};
        };
    }

    fn readArrived(self: *DocumentParser) !void {
        const input = if (self.network) |*n| n else return;
        const body = input.body orelse return;
        const pipe = body.reader() orelse return;
        if (self.trace_failure != null or self.detached or self.eof_processed or !self.isCurrent()) {
            self.releaseNetworkInput();
            return;
        }
        // Coalesce all chunks currently sitting in the pipe before calling
        // receiveBytes so that a single networking task scans all already-
        // arrived bytes ahead of decoding (zero extra copy for the common
        // single-chunk case). Taking may let a paused transfer deliver more.
        const pipe_alloc = pipe.allocator;
        var batch: std.ArrayListUnmanaged(u8) = .empty;
        defer batch.deinit(self.allocator);
        var first_chunk: ?[]u8 = null;
        defer if (first_chunk) |c| pipe_alloc.free(c);
        while (pipe.hasBytes()) {
            const bytes = try pipe.take();
            input.received += bytes.len;
            if (first_chunk == null and batch.items.len == 0) {
                first_chunk = bytes;
            } else {
                if (first_chunk) |c| {
                    try batch.appendSlice(self.allocator, c);
                    pipe_alloc.free(c);
                    first_chunk = null;
                }
                defer pipe_alloc.free(bytes);
                try batch.appendSlice(self.allocator, bytes);
            }
        }
        const ended = pipe.state != .open;
        const arrived: []const u8 = if (first_chunk) |c| c else batch.items;
        if (ended) {
            // HTML 7.5.1: "When no more bytes are available", the implied
            // EOF. A body that failed part-way ends the same way, with what
            // arrived: Blink's DocumentLoader::BodyLoadingFinished finishes
            // the parser on an error after data (FinishedLoading), and
            // WebKit's DocumentLoader::mainReceivedError ->
            // FrameLoader::receivedMainResourceError commits what was
            // received; both then fire load.
            self.releaseNetworkInput();
        }
        if (arrived.len > 0 or ended) try self.receiveBytes(arrived, ended);
        if (ended) {
            self.input_stream.complete = true;
            // The navigation timing entry was made with the body arriving;
            // its sizes are the body's now (fetch decoded any content coding,
            // so both are what arrived, as for a body read whole).
            dom.performance_timeline.navigationBodyEnded(self.ctx, input.received, input.received);
        }
        if (ended) if (self.speculation) |speculation| speculation.complete();
        // A parsing-blocking script holds the parser: the bytes wait in the
        // input stream until the script's ready task resumes it - and the
        // speculative parser reads them.
        if (self.pump_depth != 0) return;
        const internal = document_internals.getInternal(self.document) orelse return;
        if (internal.scripts.pending_parsing_blocking_script != null) {
            self.queueSpeculationSlice(.give_way);
            return;
        }
        if (ended) try self.finishIfPossible() else try self.pump();
    }

    /// The byte stream's next `bytes` (`last`: its end), decoded into the
    /// input stream while the meta charset scan runs in parallel.
    ///
    /// Design & browser evidence (golden rule 2; HTML §13.2.3.2 step 3 &
    /// §13.2.3.4 step 5):
    /// - Blink (`third_party/blink/renderer/core/html/parser/text_resource_decoder.cc`
    ///   `TextResourceDecoder::Decode`, `CheckForBOM`, `CheckForXMLCharset`,
    ///   `CheckForMetaCharset`; `core/dom/document.cc` `Document::SetEncodingData`):
    ///   buffers only while BOM (<=3 bytes) or XML declaration (`<?xml...>` /
    ///   UTF-16 `<?x`) is unresolved. Once resolved, each chunk is scanned by
    ///   `HTMLMetaCharsetParser` ahead of decoding and immediately decoded and
    ///   parsed with the active encoding (tentative parent/XML/windows-1252
    ///   until a meta switches it). A late `<meta charset>` switches the codec
    ///   on the fly, updates `document.characterSet`, and re-decodes an
    ///   already-parsed `<title>` if non-ASCII bytes were tentatively decoded
    ///   as `windows-1252`.
    /// - WebKit (`Source/WebCore/loader/TextResourceDecoder.cpp` `decode`,
    ///   `checkForHeadCharset`) buffers all bytes until the meta scan ends;
    ///   Gecko (`parser/html/nsHtml5StreamParser.cpp` `SniffStreamBytes`,
    ///   `SwitchDecoderIfAsciiSoFar`, `ProcessLookingForMetaCharset`) buffers
    ///   speculative tree ops until the meta scan ends and switches in place
    ///   for ASCII prefixes.
    /// Following Blink avoids stalling small streamed responses (<1024 B)
    /// until EOF so early `<title>` and head markup parse immediately.
    fn receiveBytes(self: *DocumentParser, bytes: []const u8, last: bool) !void {
        const input = &self.network.?;
        var chars: std.ArrayListUnmanaged(u8) = .empty;
        defer chars.deinit(self.allocator);

        var chunk: []const u8 = bytes;
        var clear_raw = false;
        defer if (clear_raw) self.raw_bytes.clearAndFree(self.allocator);

        if (!input.prefix_checked) {
            try self.raw_bytes.appendSlice(self.allocator, bytes);
            const prefix = self.raw_bytes.items;
            // Wait only for BOM (<=3 bytes) and XML declaration (UTF-16 `<?x`
            // or `<?xml...>`), never for the meta charset scan.
            if (!last and encoding_sniffing.mayStartBom(prefix)) return;
            const bom_len = encoding_sniffing.bomLength(prefix);
            if (bom_len == 0 and input.transport == null and !last and encoding_sniffing.mayStartXmlDeclaration(prefix)) {
                return;
            }

            // HTML §13.2.3.2 initial encoding determination:
            // Step 1: BOM -> certain (skip XML decl and meta scan).
            // Step 4: transport charset -> certain (skip XML decl and meta scan).
            // Step 5 (UTF-16 XML decl prefix) -> certain (skip meta scan).
            // Otherwise: XML encoding > same-origin non-UTF-16 parent > default
            // windows-1252, all tentative with the meta scan running in parallel.
            if (bom_len != 0) {
                const sniffed = encoding_sniffing.sniff(prefix, .{});
                input.encoding = sniffed.encoding;
                input.confidence = .certain;
                input.meta_done = true;
            } else if (input.transport) |transport| {
                input.encoding = transport;
                input.confidence = .certain;
                input.meta_done = true;
            } else if (encoding_sniffing.utf16XmlDeclaration(prefix)) |utf16_enc| {
                input.encoding = utf16_enc;
                input.confidence = .certain;
                input.meta_done = true;
            } else {
                const initial = encoding_sniffing.getXmlEncoding(prefix) orelse
                    (if (input.parent) |p| if (!encoding_sniffing.isUtf16(p)) p else null else null) orelse
                    encoding_sniffing.default_encoding;
                input.encoding = initial;
                input.confidence = .tentative;
                input.meta_done = false;
            }

            input.prefix_checked = true;
            try document_internals.setEncoding(self.document, encoding_sniffing.canonicalName(input.encoding));
            input.decoder = encoding_sniffing.StreamDecoder.init(input.encoding);
            // Encoding "decode" steps 1-2: a BOM is not part of the text.
            chunk = prefix[bom_len..];
            clear_raw = true;
        }

        // Feed the meta charset scanner ahead of decoding this chunk without
        // blocking on `.need_more` (Blink `TextResourceDecoder::CheckForMetaCharset`).
        if (!input.meta_done) {
            const scanner = input.scanner orelse blk: {
                const created = try meta_charset_scan.Scanner.create(self.allocator);
                input.scanner = created;
                break :blk created;
            };
            const outcome = try scanner.feed(chunk, last);
            switch (outcome) {
                .found => |found| {
                    input.meta_done = true;
                    input.releaseScanner();
                    // HTML §13.2.3.4 "change the encoding" (steps 1-5:
                    // MetaAttributes already mapped UTF-16 -> UTF-8 and
                    // x-user-defined -> windows-1252; current encoding is
                    // never UTF-16 here).
                    if (found != input.encoding) {
                        const old_encoding = input.encoding;
                        input.encoding = found;
                        input.decoder = encoding_sniffing.StreamDecoder.init(found);
                        try document_internals.setEncoding(self.document, encoding_sniffing.canonicalName(found));
                        if (input.decoded_non_ascii and old_encoding == encoding_sniffing.windows_1252) {
                            self.redecodeTitle(found);
                        }
                    }
                    input.confidence = .certain;
                },
                .none => {
                    input.meta_done = true;
                    input.releaseScanner();
                },
                .need_more => {},
            }
            if (!input.meta_done and !input.decoded_non_ascii) {
                for (chunk) |b| {
                    if (b >= 0x80) {
                        input.decoded_non_ascii = true;
                        break;
                    }
                }
            }
        }

        if (input.decoder) |*dec| {
            try dec.decodeInto(self.allocator, &chars, chunk, last);
        }
        if (last) {
            input.decoder = null;
            input.releaseScanner();
        }
        if (chars.items.len == 0) return;
        // Appended at the END of the input stream, past any insertion point:
        // the network's characters follow whatever script wrote.
        const stream = &self.input_stream;
        try stream.buffer.appendSlice(stream.allocator, chars.items);
        stream.sync();
        // 13.2.8: "Bytes pushed into the HTML parser's input byte stream must
        // also be pushed into the speculative HTML parser's input byte stream."
        if (self.speculation) |speculation| speculation.append(chars.items);
    }

    /// Blink `Document::SetEncodingData` (`third_party/blink/renderer/core/dom/
    /// document.cc:7756-7772`): when a late `<meta charset>` changes tentative
    /// `windows-1252` after non-ASCII bytes were already parsed into `<title>`,
    /// reverse the title's text back to its raw bytes and re-decode with
    /// `new_encoding` so `document.title` and CDP targets show the right text.
    fn redecodeTitle(self: *DocumentParser, new_encoding: encoding_sniffing.Encoding) void {
        const title_el = findHtmlTitleElement(self.document) orelse return;
        // Match Blink's `!ElementTraversal::FirstWithin(*title_element_)`:
        // skip if script inserted element children inside `<title>`.
        var single_text_child: ?*runtime.Instance = null;
        if (dom.instance_bridge.getNodeBase(title_el)) |title_base| {
            var child = title_base.firstChild();
            var child_count: usize = 0;
            while (child) |c| : (child = c.next_sibling) {
                if (c.node_type == dom.NodeBase.ELEMENT_NODE) return;
                child_count += 1;
                if (child_count == 1 and c.node_type == dom.NodeBase.TEXT_NODE) {
                    single_text_child = dom.instance_bridge.getInstanceTyped(runtime.Instance, c);
                } else {
                    single_text_child = null;
                }
            }
        }
        var content = (interfaces.Node.get_textContent(title_el) catch return) orelse return;
        defer content.deinit(title_el.ctx.allocator);
        const text = content.asSlice();
        if (text.len == 0) return;
        const raw = (encoding_sniffing.windows1252Reverse(self.allocator, text) catch return) orelse return;
        defer self.allocator.free(raw);
        const redecoded = encoding_sniffing.decodeWith(self.allocator, raw, new_encoding) catch return;
        defer self.allocator.free(redecoded);
        if (std.mem.eql(u8, text, redecoded)) return;
        // Update a single Text child in place (DOM replaceData -> children
        // changed steps -> HTMLTitleElement titleMayHaveChanged) to avoid
        // detaching/allocating a Text node; fall back to set_textContent for
        // multi-child titles.
        if (single_text_child) |text_node| {
            interfaces.CharacterData.set_data(text_node, runtime.DOMString.initInterned(redecoded)) catch {};
        } else {
            interfaces.Node.set_textContent(title_el, runtime.DOMString.initInterned(redecoded)) catch {};
        }
    }

    fn nextNodeInTree(node: *dom.NodeBase, root: *dom.NodeBase) ?*dom.NodeBase {
        if (node.firstChild()) |first| return first;
        var cur: *dom.NodeBase = node;
        while (cur != root) {
            if (cur.next_sibling) |sibling| return sibling;
            cur = cur.parent_node orelse return null;
        }
        return null;
    }

    fn findHtmlTitleElement(document: *runtime.Instance) ?*runtime.Instance {
        const root = dom.instance_bridge.getNodeBase(document) orelse return null;
        const html_ns = "http://www.w3.org/1999/xhtml";
        var current = nextNodeInTree(root, root);
        while (current) |node| : (current = nextNodeInTree(node, root)) {
            if (node.node_type != dom.NodeBase.ELEMENT_NODE) continue;
            const elem = dom.instance_bridge.getInstanceTyped(runtime.Instance, node) orelse continue;
            const alloc = elem.ctx.allocator;
            var local = interfaces.Element.get_localName(elem) catch continue;
            defer local.deinit(alloc);
            if (!std.mem.eql(u8, local.asSlice(), "title")) continue;
            var ns = (interfaces.Element.get_namespaceURI(elem) catch continue) orelse continue;
            defer ns.deinit(alloc);
            if (std.mem.eql(u8, ns.asSlice(), html_ns)) return elem;
        }
        return null;
    }

    /// Stop reading the body: its transfer stops once no reader is left.
    fn releaseNetworkInput(self: *DocumentParser) void {
        const input = if (self.network) |*n| n else return;
        const body = input.body orelse return;
        input.body = null;
        body.release();
    }

    /// HTML 8.4.2 steps 4-6. EOF is explicit and can only be processed once.
    pub fn close(self: *DocumentParser) !void {
        self.input_stream.complete = true;
        try self.finishIfPossible();
    }
};

/// A navigation parser's response body, read as it arrives.
const NetworkInput = struct {
    /// The body and its reader; null once the body has ended or the parser
    /// let it go (`StreamedBody.release`).
    body: ?*StreamedBody,
    /// The transport layer's encoding and a same-origin container
    /// document's (the sniffing algorithm's steps 4 and 6).
    transport: ?encoding_sniffing.Encoding,
    parent: ?encoding_sniffing.Encoding,
    /// A networking task to read the body is queued.
    read_queued: bool = false,
    /// BOM and XML-declaration prefix checks have concluded: `encoding` and
    /// `decoder` are active and `raw_bytes` has been released.
    prefix_checked: bool = false,
    /// The meta charset scan has finished (found a meta, exhausted its window,
    /// or was skipped because BOM / transport / UTF-16 XML decl decided).
    meta_done: bool = false,
    /// The active character encoding and its HTML §13.2.3.2 confidence.
    encoding: encoding_sniffing.Encoding = encoding_sniffing.default_encoding,
    confidence: encoding_sniffing.Confidence = .tentative,
    /// Whether any non-ASCII byte (>= 0x80) was decoded while `!meta_done`.
    decoded_non_ascii: bool = false,
    /// The decoder of the body's bytes once `prefix_checked`; null before and
    /// after EOF.
    decoder: ?encoding_sniffing.StreamDecoder = null,
    /// The incremental meta charset scanner while `!meta_done`.
    scanner: ?*meta_charset_scan.Scanner = null,
    /// The body's bytes received so far.
    received: u64 = 0,

    fn releaseScanner(self: *NetworkInput) void {
        const scanner = self.scanner orelse return;
        self.scanner = null;
        scanner.destroy();
    }

    /// Whether the parser still reads the body (its fetch's holder): not
    /// once it stopped, nor once its realm ended - the agent's next sweep
    /// then terminates the fetch.
    fn holds(context: *anyopaque) bool {
        const parser: *DocumentParser = @ptrCast(@alignCast(context));
        if (parser.detached or parser.document_destroyed) return false;
        return !parser.had_engine or parser.ctx.hasEngine();
    }

    /// The pipe has something new - from the network's turn of the loop,
    /// where no script may run: queue the networking task that reads it,
    /// once until it runs.
    fn notify(context: *anyopaque) void {
        const parser: *DocumentParser = @ptrCast(@alignCast(context));
        const self = if (parser.network) |*input| input else return;
        if (self.read_queued) return;
        const loop = parser.ctx.getOptionalEventLoop() orelse return;
        const task = parser.allocator.create(ReadTask) catch return;
        task.* = .{ .parser = parser };
        self.read_queued = true;
        parser.retain();
        // A global task on the networking task source given the document's
        // relevant global (HTML 7.5.1): runnable while its document is
        // fully active.
        loop.queueTask(.{
            .callback = &ReadTask.run,
            .context = task,
            .drop = &ReadTask.drop,
            .document = parser.document,
            .document_generation = parser.document_generation,
        });
    }

    const ReadTask = struct {
        parser: *DocumentParser,

        fn run(context: ?*anyopaque) void {
            const self: *ReadTask = @ptrCast(@alignCast(context.?));
            const parser = self.parser;
            parser.allocator.destroy(self);
            defer parser.release();
            if (parser.network) |*input| input.read_queued = false;
            parser.readNetworkInput();
        }

        fn drop(context: ?*anyopaque) void {
            const self: *ReadTask = @ptrCast(@alignCast(context.?));
            const parser = self.parser;
            parser.allocator.destroy(self);
            if (parser.network) |*input| input.read_queued = false;
            parser.release();
        }
    };
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
    // A body still arriving is this call's until its parser takes it.
    var body_stream = options.body_stream;
    defer if (body_stream) |pipe| pipe.release();
    // Step 1: Create DOM Document FIRST (before parsing), unless navigation
    // already did. It must exist before any DOM nodes are created.
    const owns_document = options.document == null;
    const document = options.document orelse (interfaces.Document.initWith(
        allocator,
        ctx,
        .{ .ready_state = ._loading_ },
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
    const parser = (if (body_stream) |_| streaming: {
        // createStreaming takes the body, failing or not.
        body_stream = null;
        break :streaming DocumentParser.createStreaming(allocator, ctx, document, options);
    } else DocumentParser.createComplete(allocator, ctx, document, html, options)) catch return error.OutOfMemory;
    var initiating_owner = true;
    defer if (initiating_owner) parser.release();
    if (!dom.document_lifecycle.associateParser(document, parser)) return error.InvalidStateError;
    const call: ?DocumentParser.ActiveCall = if (parser.isCurrent())
        parser.protect() catch {
            if ((!had_engine or ctx.hasEngine()) and
                runtime.SlabAllocator.generationOf(document) == document_generation)
                dom.document_lifecycle.discardParser(document, parser);
            return error.OutOfMemory;
        }
    else
        null;
    defer if (call) |held| held.deinit();
    // On failure detach while the active call still roots its graph; the
    // guard then releases final native state before those roots are dropped.
    errdefer if ((!had_engine or ctx.hasEngine()) and
        runtime.SlabAllocator.generationOf(document) == document_generation)
        dom.document_lifecycle.discardParser(document, parser);
    if (call != null) {
        // The guard replaces initiation's native reference and releases it
        // while its wrapper roots still protect final native cleanup.
        parser.release();
        initiating_owner = false;
    }
    parser.pump() catch return error.TreeBuilderError;
    parser.finishIfPossible() catch return error.TreeBuilderError;
    // What of the body arrived before the parser existed.
    if (parser.network != null) parser.readNetworkInput();

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
