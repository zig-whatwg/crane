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

// The adapter that builds the DOM as the tree builder builds its tree, and
// the parser's script end-tag steps.
const parser_scripts = @import("parser_script_execution.zig");
const DomTreeAdapter = parser_scripts.DomTreeAdapter;
const ParserScriptContext = parser_scripts.ParserScriptContext;

/// The Browser's live parsers and the removing steps that rescue a tree
/// script detaches from under one (tmp/plans/parser-holds-design.md 5.3).
pub const holds = @import("parser_holds.zig");

/// Installed once, at process start, by crane.Process.
pub fn installHooks() void {
    holds.installHooks();
}

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
    /// The one fixed Document member under which every parser of the
    /// Document keeps the roots it rescued: a dense, collectible JS array.
    pub const kept_roots_slot: engine.TracedSlot = .{ .name = "document-parser:kept-roots" };

    /// A tree root this parser rooted because script (or a failed insertion)
    /// detached a tree containing a node it holds: the node, its slab
    /// generation, and its index in the Document's kept-roots container.
    pub const Rescue = struct {
        node: *runtime.Instance,
        generation: u64,
        index: usize,
    };

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
    /// The parser holds the nodes its own structures name - the stack of
    /// open elements, the head and form element pointers - natively, with no
    /// wrapper (design 5.1; Blink's HTMLConstructionSite::Trace). A held node
    /// is safe while its tree's root is this parser's Document or one of
    /// these rescued roots, each rooted from the Document's kept-roots
    /// container until `release` clears it (5.2, 5.3).
    rescues: std.ArrayListUnmanaged(Rescue) = .empty,
    /// One past the highest kept-roots index this parser reserved
    /// (`node_holds.Registry.reserveIndex`).
    kept_slot_end: usize = 0,
    /// The Browser's scanning holders, which the removing steps consult;
    /// null in a realm without an engine or a Browser scope.
    registry: ?*holds.Registry = null,
    /// Only active native calls root the Document; a suspended parser keeps
    /// no independent root, so an unreachable Document/parser graph collects.
    active_calls: usize = 0,
    active_document: ?engine.Owned = null,
    /// A terminal failure (an allocation in node creation or a rescue):
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
        // An element whose parser insertion fails is rescued (design 5.3,
        // trigger 2): it may be or become held, parentless.
        self.adapter.rescuer = .{ .context = self, .rescue = &rescueFromAdapter };
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
        self.adapter.notifies_children_finished = true;
        if (document_internals.getURL(document)) |url| self.tree_builder.iframe_srcdoc = matchesAboutSrcdoc(url);
        self.script_context = ParserScriptContext.init(
            allocator,
            ctx,
            document,
            &self.adapter,
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
        errdefer if (self.owned_loader) |*loader| loader.deinit();
        // The removing steps find this parser through its Browser's registry.
        // A realm with an engine but no Browser scope (a bare test realm) has
        // no registry: its parser rescues only failed insertions.
        if (self.had_engine) {
            if (holds.Registry.of(ctx)) |registry| {
                try registry.register(holds.scanner(self));
                self.registry = registry;
            } else log.debug("parser in a realm without a Browser scope: removals are not rescued", .{});
        }
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
            // release may destroy parser. The extracted root stays alive
            // through adapter cleanup; nothing below dereferences parser.
            parser.release();
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
        self.active_calls += 1;
        self.retain();
        return .{ .parser = self };
    }

    pub fn retain(self: *DocumentParser) void {
        self.references += 1;
    }

    pub fn release(self: *DocumentParser) void {
        self.references -= 1;
        if (self.references != 0) return;
        std.debug.assert(self.pump_depth == 0);
        std.debug.assert(self.active_calls == 0);
        self.releaseRescues();
        if (self.registry) |registry| registry.unregister(self);
        self.registry = null;
        self.adapter.deinit();
        self.tree_builder.deinit();
        self.input_stream.deinit();
        self.tokenizer.deinit();
        if (self.owned_loader) |*loader| loader.deinit();
        if (self.original_bytes) |bytes| self.allocator.free(bytes);
        self.allocator.free(self.base_url);
        self.allocator.destroy(self);
    }

    /// Stop an old parser without freeing a pump a script has reentered.
    /// The document clears its association before dropping its reference.
    pub fn detach(self: *DocumentParser) void {
        if (self.detached) return;
        // Holds and rescues stay until release: frames still unwinding through
        // this parser may work on its stack - abort step 4 pops it after a
        // readiness listener replaced the parser - and the removing steps keep
        // asking it (design 5.6; Blink's HTMLConstructionSite::Detach keeps
        // the stack "because HTMLConstructionSite might be on the callstack").
        self.detached = true;
        self.input_stream.aborted = true;
        self.input_stream.insertion_point = null;
    }

    /// Document's wrapper owns its kept-roots container. A collector
    /// teardown lets it die with the wrapper, without engine calls during GC;
    /// the rescue list is then freed natively at release.
    pub fn detachForDocumentDestruction(self: *DocumentParser) void {
        self.document_destroyed = true;
        // Teardown never runs parser callbacks or script. Destroying the
        // private tree below releases its stack storage without observable
        // finished-parsing-children steps against a retired document.
        self.detached = true;
        self.input_stream.aborted = true;
        self.input_stream.insertion_point = null;
    }

    /// Whether this parser can still touch its Document's engine objects:
    /// the Document is the one it was made for, its object is not being torn
    /// down, and its realm has an engine. Never true during a collector
    /// teardown of the Document (`detachForDocumentDestruction` runs first).
    /// HTML's "destroyed" lifecycle flag is not consulted: a retained
    /// document whose navigable was destroyed can still be opened and parsed
    /// (40586ce295), and its kept-roots container lives with its wrapper.
    fn documentEngineUsable(self: *const DocumentParser) bool {
        if (self.document_destroyed or !self.ctx.hasEngine()) return false;
        if (runtime.SlabAllocator.generationOf(self.document) != self.document_generation) return false;
        return document_internals.getInternal(self.document) != null;
    }

    /// The node `tree_node` names, as the DOM's tree node, if it is alive.
    fn heldBase(self: *const DocumentParser, tree_node: *TreeNode) ?*dom.NodeBase {
        const instance = self.adapter.getDomNode(tree_node) orelse return null;
        if (instance == self.document) return null;
        return dom.instance_bridge.getNodeBase(instance);
    }

    /// Whether `root` - left parentless by a removal - is a host-including
    /// inclusive ancestor of a node this parser holds (design 5.3). The
    /// stack is normally a parent chain, so an entry whose parent is the
    /// previous entry shares its (negative) answer: O(stack depth).
    pub fn holdsNodeUnder(self: *const DocumentParser, root: *dom.NodeBase) bool {
        if (self.document_destroyed or !self.adapter.isAlive()) return false;
        const held = self.tree_builder.heldNodes();
        var previous: ?*dom.NodeBase = null;
        for (held.stack) |tree_node| {
            const base = self.heldBase(tree_node) orelse continue;
            if (previous == null or base.parent_node != previous) {
                if (holds.isUnderRoot(base, root, previous)) return true;
            }
            previous = base;
        }
        for ([_]?*TreeNode{ held.head, held.form }) |pointer| {
            const tree_node = pointer orelse continue;
            const base = self.heldBase(tree_node) orelse continue;
            if (holds.isUnderRoot(base, root, null)) return true;
        }
        return false;
    }

    /// Rescue(P, R), design 5.3: root `root`'s wrapper from the Document's
    /// kept-roots container until this parser is released. At most one
    /// wrapper, never one per node: by L2 the root's wrapper keeps its whole
    /// tree, wherever script moves the root later. Runs no script.
    pub fn rescue(self: *DocumentParser, root: *runtime.Instance) void {
        const generation = runtime.SlabAllocator.generationOf(root);
        // Step 1: once per root.
        for (self.rescues.items) |kept| {
            if (kept.node == root and kept.generation == generation) return;
        }
        // Step 2: a failed parser, a destroyed document or a realm without an
        // engine rescues nothing; generation checks govern from there (H9).
        if (self.trace_failure != null) return;
        if (!self.documentEngineUsable() or !root.ctx.hasEngine()) return;
        self.rescues.ensureUnusedCapacity(self.allocator, 1) catch |err| return self.failRescue(err);
        // Step 5, first half: the index, before any engine allocation.
        const index = (if (self.registry) |registry| registry.reserveIndex(self) else null) orelse blk: {
            self.kept_slot_end += 1;
            break :blk self.kept_slot_end - 1;
        };
        // Steps 3-5: the root's wrapper, made if it has none, stored at that
        // index of the Document's container (made on first use) as a dense
        // numeric own property - no prototype setter runs - in one step.
        holds.putRoot(self.document, kept_roots_slot, index, root) catch |err| return self.failRescue(err);
        // Step 6.
        self.rescues.appendAssumeCapacity(.{ .node = root, .generation = generation, .index = index });
    }

    /// Step 7: a rescue that cannot be made stops the parser, as a failed
    /// node creation does; every later reference goes through generation
    /// checks.
    fn failRescue(self: *DocumentParser, err: anyerror) void {
        log.warn("parser rescue failed, parsing stops: {}", .{err});
        self.trace_failure = err;
        self.input_stream.discardInput();
    }

    fn rescueFromAdapter(context: ?*anyopaque, root: *runtime.Instance) void {
        const self: *DocumentParser = @ptrCast(@alignCast(context orelse return));
        self.retain();
        defer self.release();
        self.rescue(root);
    }

    /// At release: clear this parser's slots, so its rescued trees live only
    /// as long as script reaches them. Only while the Document and its realm
    /// are usable; otherwise the container is gone with the Document's
    /// wrapper or the realm, and the list is freed natively.
    fn releaseRescues(self: *DocumentParser) void {
        defer self.rescues.clearAndFree(self.allocator);
        if (self.rescues.items.len == 0 or !self.documentEngineUsable()) return;
        for (self.rescues.items) |kept| holds.clearRoot(self.document, kept_roots_slot, kept.index);
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
        self.finishIfPossible() catch |err| log.warn("document.close(): the parser stopped: {}", .{err});
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
        parser_scripts.resumeAfterBlockingScript(&self.script_context);
        if (self.detached or !self.isCurrent()) return;
        try self.tree_builder.parse();
        if (self.trace_failure) |err| return err;
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
