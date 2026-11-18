//! HTML 8.5.3 "HTML streaming methods": streamHTML, streamAppendHTML,
//! streamPrependHTML, streamBeforeHTML, streamAfterHTML,
//! streamReplaceWithHTML and their Unsafe counterparts, and the "stream
//! HTML" algorithm behind them: a WritableStream whose chunks a fragment
//! parser parses into the live target, before a reference child.
//!
//! The fragment parser is a script-created html.scripted_parser
//! DocumentParser - the live DOM adapter every document parser uses - whose
//! Document is a new html Document of its own ("stream HTML" step 7), set up
//! for the fragment case (dom_parser.FragmentCase: "initialize an HTML
//! fragment parser"). Its root `html` element's insertions are redirected to
//! (target, referenceChild) (TreeNode.insertion_redirect, which
//! parser_dom_mutation.resolve honors: HTML "adjusted insertion location"
//! steps 3-7), so elements are created in, and inserted into, the target's
//! node document as they are parsed.
//!
//! Lifetime: a `StreamParser` is counted. The stream's controller owns one
//! reference (its sink's, released when the controller clears its
//! algorithms or is torn down); a close in flight owns another until the
//! parser stops. It holds the target, the reference child and its Document
//! counted (dom.node_holds.CountedRef); its parser's structures hold what
//! they name, as every document parser's do. Design: Chromium's
//! HTMLStreamingParser / Blink's streaming fragment parser keeps a
//! DocumentFragment-less HTMLDocumentParser whose construction site
//! attaches to the target (third_party/blink/renderer/core/html/parser/,
//! read for structure only).
//!
//! Spec: https://html.spec.whatwg.org/#html-streaming-methods

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const html_core = @import("html_core");
const insertion = @import("html_insertion.zig");
const parser_options = @import("parser_options.zig");
const sanitizer = @import("sanitizer.zig");
const dom_parser = @import("dom_parser.zig");
const scripted_parser = @import("scripted_parser.zig");

const js = dom.streams_js;
const sw = dom.streams_writable;
const DocumentParser = scripted_parser.DocumentParser;
const CountedRef = dom.node_holds.CountedRef;

pub const ContainerPosition = insertion.ContainerPosition;
pub const ChildPosition = insertion.ChildPosition;
const ParserOptions = parser_options.ParserOptions;

const log = std.log.scoped(.stream_html);

// ============================================================================
// The methods
// ============================================================================

/// Element's / ShadowRoot's streamHTML, streamAppendHTML and
/// streamPrependHTML (Safe): `sanitizer_member` is SetHTMLOptions'
/// sanitizer as the binding gave it.
pub fn containerSafe(this: *runtime.Instance, position: ContainerPosition, sanitizer_member: ?runtime.JSValue) !*runtime.Instance {
    var options = try ParserOptions.fromDictionary(this.ctx, sanitizer_member, null);
    defer options.deinit();
    return containerSteps(this, position, &options, .safe);
}

/// Element's / ShadowRoot's streamHTMLUnsafe, streamAppendHTMLUnsafe and
/// streamPrependHTMLUnsafe: 1. "Let compliantOptions be the result of
/// invoking the get trusted type compliant parser options algorithm with
/// this's relevant global object, options, true, and `sink`" - before any
/// other step (the hierarchy checks, the children's removal). `options` is
/// MOVED in.
pub fn containerUnsafe(this: *runtime.Instance, position: ContainerPosition, options: ParserOptions, sink: []const u8) !*runtime.Instance {
    var compliant = try parser_options.compliantParserOptions(dom.trusted_types.relevantGlobalOf(this), options, true, sink, true);
    defer compliant.deinit();
    return containerSteps(this, position, &compliant, .unsafe);
}

/// The container methods' steps after Trusted Types: the target (Element's
/// target for HTML insertion given this; a ShadowRoot itself), the html
/// element check of Append and Prepend, stream HTML given the target and
/// null (set, append) or the target's first child (prepend), then - for
/// set - "replace all with null within target".
fn containerSteps(this: *runtime.Instance, position: ContainerPosition, options: *const ParserOptions, mode: insertion.Mode) !*runtime.Instance {
    const is_shadow = this.stateAs(interfaces.ShadowRoot.State) != null;
    const target = if (is_shadow) this else try insertion.targetFor(this);
    // "If target is an html element, then throw a HierarchyRequestError"
    // (Element's streamAppendHTML / streamPrependHTML step 2).
    if (position != .set and insertion.isHtmlElement(target)) return error.HierarchyRequestError;
    const reference: ?*runtime.Instance = if (position == .prepend) try interfaces.Node.get_firstChild(target) else null;
    const stream = try streamHTML(target, reference, options, mode, this.ctx);
    if (position == .set) {
        // "Replace all with null within target."
        const parent = dom.instance_bridge.getNodeBase(target) orelse return error.InvalidStateError;
        try dom.mutation.replaceAll(@as(?*dom.NodeBase, null), parent);
    }
    return stream;
}

/// NonDocumentTypeChildNode's streamBeforeHTML, streamAfterHTML and
/// streamReplaceWithHTML (Safe).
pub fn childSafe(this: *runtime.Instance, position: ChildPosition, sanitizer_member: ?runtime.JSValue) !*runtime.Instance {
    var options = try ParserOptions.fromDictionary(this.ctx, sanitizer_member, null);
    defer options.deinit();
    return childSteps(this, position, &options, .safe);
}

/// NonDocumentTypeChildNode's streamBeforeHTMLUnsafe and friends: Trusted
/// Types first ("Node <method>" is the sink), as containerUnsafe. `options`
/// is MOVED in.
pub fn childUnsafe(this: *runtime.Instance, position: ChildPosition, options: ParserOptions, sink: []const u8) !*runtime.Instance {
    var compliant = try parser_options.compliantParserOptions(dom.trusted_types.relevantGlobalOf(this), options, true, sink, true);
    defer compliant.deinit();
    return childSteps(this, position, &compliant, .unsafe);
}

/// The child-node methods' steps after Trusted Types: the parent for HTML
/// streaming given this, stream HTML before this (before) or this's next
/// sibling (after, replaceWith), then - for replaceWith - "remove this".
fn childSteps(this: *runtime.Instance, position: ChildPosition, options: *const ParserOptions, mode: insertion.Mode) !*runtime.Instance {
    const parent = try insertion.parentForStreaming(this);
    const reference: ?*runtime.Instance = switch (position) {
        .before => this,
        .after, .replace_with => try interfaces.Node.get_nextSibling(this),
    };
    const stream = try streamHTML(parent, reference, options, mode, this.ctx);
    if (position == .replace_with) {
        // "Remove this."
        const node = dom.instance_bridge.getNodeBase(this) orelse return error.InvalidStateError;
        try dom.mutation.remove(node, false);
    }
    return stream;
}

// ============================================================================
// Stream HTML
// ============================================================================

/// HTML "stream HTML" given `target`, `reference_child`, `options`, `mode`
/// and the realm the stream is created in: a new WritableStream, owned by
/// the wrapper cache (the binding returns it).
fn streamHTML(
    target: *runtime.Instance,
    reference_child: ?*runtime.Instance,
    options: *const ParserOptions,
    mode: insertion.Mode,
    realm_ctx: runtime.Context,
) !*runtime.Instance {
    // 1-2. "Let context be the parser context element given target. If
    // context is an HTML or SVG script element, then throw a
    // NotSupportedError."
    const context = try insertion.contextElementFor(target);
    if (insertion.isScriptElement(context)) return error.NotSupportedError;
    // 3-4. "Let safe be true if mode is Safe"; the sanitizer configuration.
    const safe = mode == .safe;
    var config = try options.sanitizerConfig(realm_ctx, safe);
    errdefer if (config) |*held| held.deinit();
    // 5-6. runScripts, never in Safe mode.
    const run_scripts = options.runScripts();
    std.debug.assert(!run_scripts or !safe);
    // 7-8. The parser, its Document and its fragment case.
    const self = try StreamParser.create(realm_ctx, target, reference_child, context, config, run_scripts);
    config = null; // moved
    errdefer self.release();
    // 9-15. "Let stream be a new WritableStream created in realm", set up
    // with the write, close and abort algorithms. The sink is the stream's
    // reference to the parser from here, failure included.
    const realm = try js.Realm.ofContext(realm_ctx);
    self.retain();
    const stream = try sw.createWritableStream(realm, realm_ctx, .{ .ctx = self, .vtable = &sink_vtable }, 1, .one);
    self.stream = stream;
    self.stream_generation = runtime.SlabAllocator.generationOf(stream);
    // 11. "If referenceChild is non-null, then set parser's invalid reference
    // child steps" (the redirect runs them: parser_dom_mutation.redirected).
    if (reference_child != null) self.invalid_reference_steps = true;
    // The creation's own reference ends; the sink's stays.
    self.release();
    // 16. "Return stream."
    return stream;
}

/// The parser one streaming method made, and what its stream's algorithms
/// share (HTML "stream HTML" steps 8-14).
const StreamParser = struct {
    allocator: Allocator,
    realm: runtime.Context,
    references: u32 = 1,
    /// The fragment parser's Document (step 7), held counted.
    document: *runtime.Instance,
    document_ref: CountedRef = .{},
    /// The fragment parser: one reference ours, one its Document's (the
    /// association), until `discardParser`.
    parser: ?*DocumentParser = null,
    fragment_case: ?dom_parser.FragmentCase = null,
    /// The insertion target redirection map's entry for the root html
    /// element: (target, referenceChild).
    redirect: html_core.parser.InsertionRedirect,
    target: *runtime.Instance,
    target_ref: CountedRef = .{},
    reference_child: ?*runtime.Instance,
    reference_ref: CountedRef = .{},
    /// The parser sanitizer configuration, owned, and the filter the tree
    /// builder reads it through.
    config: ?sanitizer.Config,
    filter: ?sanitizer.ParseFilter = null,
    /// The stream (owned by the wrapper cache), to error it.
    stream: ?*runtime.Instance = null,
    stream_generation: u64 = 0,
    /// Step 10's writeError, owned.
    write_error: ?js.Value = null,
    /// The parser's fragment parser close promise.
    close_promise: ?js.Deferred = null,
    /// Whether the parser's invalid reference child steps are non-null.
    invalid_reference_steps: bool = false,
    /// Whether its script target document is the context's document.
    run_scripts: bool = false,
    /// The deferred scripts' reference on this parser, while any is left
    /// to run after its end.
    deferred_hold: bool = false,
    /// HTML "fragment parser running", "fragment parser abort requested",
    /// and "aborted".
    running: bool = false,
    abort_requested: bool = false,
    aborted: bool = false,

    /// Steps 7-8: a new html Document and "initialize an HTML fragment
    /// parser" given it, target, (target, referenceChild), true,
    /// runScripts and sanitizerConfig (MOVED in).
    fn create(realm: runtime.Context, target: *runtime.Instance, reference_child: ?*runtime.Instance, context: *runtime.Instance, config: ?sanitizer.Config, run_scripts: bool) !*StreamParser {
        const allocator = realm.allocator;
        // 7. "Let document be a Document node whose type is "html"" - with no
        // browsing context, so scripting is disabled for it.
        const document = try interfaces.Document.call_constructor(realm);
        const document_base = dom.instance_bridge.getNodeBase(document);
        var config_owned = config;
        errdefer if (config_owned) |*held| held.deinit();
        const self = allocator.create(StreamParser) catch |err| {
            dom.node_creation.destroyUninserted(document);
            return err;
        };
        self.* = .{
            .allocator = allocator,
            .realm = realm,
            .document = document,
            .redirect = .{ .parent = target, .parent_generation = runtime.SlabAllocator.generationOf(target) },
            .target = target,
            .reference_child = reference_child,
            .config = null,
        };
        // The parser holds its Document counted, taking its born reference
        // over (refcount step 5i: a holder takes over the creator's).
        self.document_ref.take(document, document_base);
        if (document_base) |base| dom.refcount.takeOverCreatorReference(base);
        errdefer self.destroy();
        try dom.document_internals.setDocumentType(document, .html);
        self.target_ref.take(target, dom.instance_bridge.getNodeBase(target));
        if (reference_child) |child| {
            self.reference_ref.take(child, dom.instance_bridge.getNodeBase(child));
            self.redirect.reference = child;
            self.redirect.reference_generation = runtime.SlabAllocator.generationOf(child);
        }
        self.redirect.context = self;
        self.redirect.invalid_reference = &invalidReferenceChild;
        self.config = config_owned;
        config_owned = null;
        if (self.config) |*held| self.filter = .{ .data = &held.data, .allocator = allocator };

        // 1-2. contextElement and its node document.
        const context_document = try interfaces.Node.get_ownerDocument(context);
        // 3-5. "Let parser be a new HTML parser, associated with
        // tempDocument" - a script-created one: it reaches the end of its
        // input only at the explicit EOF closing the stream appends.
        // With runScripts, its script end tags prepare their scripts.
        const parser = try DocumentParser.createFragment(allocator, realm, document, run_scripts, &parserFinished);
        self.parser = parser;
        parser.owner = self;
        if (!dom.document_lifecycle.associateParser(document, parser)) return error.InvalidStateError;
        // 6, 10-19: the fragment case (dom_parser.FragmentCase), its parser
        // scripting disabled flag from contextDocument.
        self.fragment_case = try dom_parser.FragmentCase.setUp(allocator, &parser.tree_builder, &parser.tokenizer, context, context_document);
        // 7. "Set parser's allow declarative shadow roots to
        // allowDeclarativeShadowRoots" (true: Safe and Unsafe).
        parser.tree_builder.allow_declarative_shadow_roots = true;
        // 8. "Set parser's parser sanitizer configuration to sanitizerConfig."
        if (self.filter) |*filter| {
            parser.tree_builder.parser_sanitizer = filter.parserSanitizer();
            parser.adapter.parser_sanitizer = filter.parserSanitizer();
        }
        parser.adapter.fragment_case = true;
        parser.adapter.invalid_reference_context = self;
        parser.adapter.invalid_reference = &invalidReferenceChild;
        // 9. "Set parser's script target document to contextDocument if
        // runScripts is true; otherwise tempDocument" - whose scripts are
        // already started ("in head", a script start tag, step 5).
        if (run_scripts) {
            if (context_document) |live| {
                parser.adapter.script_target_document = live;
                parser.adapter.script_target_generation = runtime.SlabAllocator.generationOf(live);
            }
        } else parser.adapter.inert_scripts = true;
        self.run_scripts = run_scripts;
        // 15. "Set parser's insertion target redirection map[root] to
        // insertionLocation."
        self.fragment_case.?.root.insertion_redirect = &self.redirect;
        return self;
    }

    /// Whether the Document is still the one held: the counted hold keeps
    /// it, but a forced realm end frees a realm's nodes whatever their counts
    /// (CountedRef's own net reads the same).
    fn documentAlive(self: *const StreamParser) bool {
        if (self.document_ref.base == null) return false;
        if (runtime.SlabAllocator.generationOf(self.document) != self.document_ref.generation) return false;
        return !runtime.instance_lifecycle.isCleanupStarted(self.document);
    }

    fn retain(self: *StreamParser) void {
        self.references += 1;
    }

    fn release(self: *StreamParser) void {
        self.references -= 1;
        if (self.references != 0) return;
        self.destroy();
    }

    /// Everything goes: the parser (dissociated from its Document, which
    /// lets its reference go), the stand-in nodes, the holds and the
    /// configuration.
    fn destroy(self: *StreamParser) void {
        // Scripts its Document still queues never run now: discarded while
        // the Document is here (each queue entry's root goes with it).
        if (self.documentAlive()) @import("script_execution.zig").discardDocumentScripts(self.document);
        self.discardParser();
        js.disposeOptional(&self.write_error);
        if (self.close_promise) |deferred| deferred.deinit();
        self.close_promise = null;
        if (self.config) |*held| held.deinit();
        if (self.reference_child) |child| self.reference_ref.release(child);
        self.target_ref.release(self.target);
        self.document_ref.release(self.document);
        self.allocator.destroy(self);
    }

    /// The parser goes: off its Document, its structures' holds released.
    fn discardParser(self: *StreamParser) void {
        const parser = self.parser orelse return;
        self.parser = null;
        if (self.fragment_case) |*fragment_case| {
            fragment_case.root.insertion_redirect = null;
            fragment_case.deinit(&parser.tree_builder);
        }
        self.fragment_case = null;
        parser.owner = null;
        // A forced realm end can free the Document whatever its counts say;
        // it then detached its parser and let its reference go itself.
        if (self.documentAlive()) dom.document_lifecycle.discardParser(self.document, parser);
        parser.release();
    }

    /// HTML "run a fragment parser" given this parser.
    fn run(self: *StreamParser) void {
        // 1. "If parser's fragment parser running is true, then return" -
        // the ongoing run consumes the newly appended input.
        if (self.running) return;
        const parser = self.parser orelse return;
        // 2. "Set parser's fragment parser running to true."
        self.running = true;
        self.retain();
        defer self.release();
        // 3. "Have parser's tokenizer process the characters in its input
        // stream ... until it has consumed all of them or the processing of
        // the tokenizer is aborted." Input appended while it runs (a custom
        // element's constructor writing to the stream) is consumed by
        // running again.
        while (!self.aborted and !self.abort_requested) {
            const before = parser.input_stream.buffer.items.len;
            parser.input_stream.processInserted();
            if (parser.input_stream.complete) parser.finishIfPossible() catch |err| log.debug("stream HTML: the parser stopped: {}", .{err});
            if (self.parser == null or parser.input_stream.buffer.items.len == before) break;
        }
        // 4. "Set parser's fragment parser running to false."
        self.running = false;
        // 5. An abort requested while it ran happens now.
        if (self.abort_requested) {
            self.abort_requested = false;
            if (self.parser) |p| p.adapter.abort_requested = false;
            self.abortParser();
        }
    }

    /// HTML "abort a fragment parser" given this parser.
    fn abortFragmentParser(self: *StreamParser) void {
        // 1. "If parser's aborted is true, then return."
        if (self.aborted) return;
        // 2. While it runs: request the abort, which happens once the run
        // ends. (2.2's scripts on the stack: inert here - TODO G6.)
        if (self.running) {
            self.abort_requested = true;
            if (self.parser) |parser| parser.adapter.abort_requested = true;
            // 2.2. The scripts on the stack of open elements: already
            // started, so none runs.
            self.markOpenScriptsStarted();
            if (self.parser) |parser| parser.input_stream.discardInput();
            return;
        }
        // 3. "Abort parser."
        self.abortParser();
    }

    /// HTML "abort a parser" for the fragment case: no more input, every
    /// open element popped (a style element's sheet is processed as it
    /// leaves the stack).
    fn abortParser(self: *StreamParser) void {
        if (self.aborted) return;
        // 1-2. "Set the parser's aborted to true."
        self.aborted = true;
        const parser = self.parser orelse return;
        // 5.1. The scripts on the stack of open elements: already started.
        self.markOpenScriptsStarted();
        if (if (self.documentAlive()) dom.document_scripts.of(self.document) else null) |scripts| {
            // 5.2. "If the parser's Document's pending parsing-blocking script
            // is non-null, then unblock rendering on it, and set the parser's
            // Document's pending parsing-blocking script to null."
            if (scripts.pending_parsing_blocking_script) |script| {
                dom.document_rendering.unblock(script);
                scripts.pending_parsing_blocking_script = null;
            }
            // 5.3. "For each script of the parser's Document's list of scripts
            // that will execute when the document has finished parsing,
            // unblock rendering on script."
            for (scripts.scripts_to_execute_when_parsing_finished.items) |script| dom.document_rendering.unblock(script);
        }
        // 3, 7. Throw away the input; pop every open element.
        parser.input_stream.abort();
        // An aborted parser's deferred scripts never run.
        if (self.deferred_hold) {
            self.deferred_hold = false;
            self.release();
        }
        // A pending close never settles from here: the stream rejects it.
    }

    /// "For each script element script of the stack of open elements, set
    /// script's already started to true" (its parser and intended document
    /// do not matter once it is: "prepare the script element" step 1).
    fn markOpenScriptsStarted(self: *StreamParser) void {
        const parser = self.parser orelse return;
        for (parser.tree_builder.heldNodes().stack) |tree_node| {
            if (tree_node.node_type != .element or !tree_node.hasTagName("script")) continue;
            const element = parser.adapter.getDomNode(tree_node) orelse continue;
            dom.script_elements.markAlreadyStarted(element);
        }
    }

    // ------------------------------------------------------------------
    // The stream's algorithms
    // ------------------------------------------------------------------

    /// Step 11's "invalid reference child steps" given referenceChild, as
    /// the redirect (parser_dom_mutation.resolve) and step 12.2 run them.
    fn invalidReferenceChild(context: ?*anyopaque, child: *anyopaque) void {
        const self: *StreamParser = @ptrCast(@alignCast(context orelse return));
        // 1. "If child is not referenceChild, or referenceChild's parent is
        // target, then return" - a sanitizer's redirect whose own reference
        // (a foster-parenting table) moved drops its insertion, and nothing
        // more.
        const reference = self.reference_child orelse return;
        if (@as(*anyopaque, reference) != child or !self.referenceChildMoved()) return;
        self.invalidReferenceChildSteps();
    }

    fn invalidReferenceChildSteps(self: *StreamParser) void {
        // Only once: step 2 sets the steps to null.
        if (!self.invalid_reference_steps) return;
        // 2. "Set parser's invalid reference child steps to null."
        self.invalid_reference_steps = false;
        const realm = js.Realm.ofContext(self.realm) catch return;
        // 3. "Let error be a new HierarchyRequestError DOMException created
        // in realm."
        const created = engine.createDOMException(self.realm, "HierarchyRequestError", "The stream's reference child is no longer a child of its target.") catch return;
        const err: js.Value = .{ .value = created.take(), .realm = self.realm };
        // 4. "Set writeError to error."
        js.disposeOptional(&self.write_error);
        self.write_error = err;
        // 5. "Error stream with error."
        if (self.liveStream()) |stream| {
            if (sw.streamOf(stream)) |state| if (state.controller) |controller| sw.controllerErrorIfNeeded(realm, controller, err);
        }
        // 6. A close in flight rejects with error.
        if (self.close_promise) |deferred| {
            self.close_promise = null;
            deferred.reject(realm, err);
            deferred.deinit();
            self.release();
        }
        // 7. "Abort parser."
        self.abortFragmentParser();
    }

    fn liveStream(self: *const StreamParser) ?*runtime.Instance {
        const stream = self.stream orelse return null;
        return if (runtime.SlabAllocator.generationOf(stream) == self.stream_generation) stream else null;
    }

    /// Whether referenceChild is no longer target's child.
    fn referenceChildMoved(self: *const StreamParser) bool {
        const child = self.reference_child orelse return false;
        const child_base = dom.instance_bridge.getNodeBase(child) orelse return true;
        return child_base.parent_node != dom.instance_bridge.getNodeBase(self.target);
    }

    /// Step 12, writeAlgorithm given `chunk`.
    fn write(self: *StreamParser, realm: js.Realm, chunk: js.Value) js.Error!js.Value {
        // 1. "Let chunkString be the result of converting chunk to a
        // DOMString. If this throws an exception e, catch it, abort parser,
        // and return a promise rejected with e in realm."
        // The algorithm holds this parser: a step below can error the
        // stream, which clears its algorithms and lets the sink's go.
        self.retain();
        defer self.release();
        var converted: Converted = .{ .allocator = self.allocator, .realm = self.realm, .value = chunk.value };
        const thrown = engine.completionOf(self.realm, Converted.run, &converted) catch |err| return js.fromEngineError(err);
        if (thrown) |exception| {
            defer exception.release();
            if (converted.string) |s| self.allocator.free(s);
            self.abortFragmentParser();
            return realm.promiseRejectedWith(.{ .value = exception.borrow(), .realm = self.realm });
        }
        const chunk_string = converted.string orelse return realm.promiseResolvedWithUndefined();
        defer self.allocator.free(chunk_string);
        // 2. A reference child moved or removed before the parser runs.
        if (self.invalid_reference_steps and self.referenceChildMoved()) self.invalidReferenceChildSteps();
        // 3. "If writeError is non-null, then return a promise rejected
        // with writeError in realm."
        if (self.write_error) |err| return realm.promiseRejectedWith(err);
        // 4. "Append chunkString to the end of parser's input stream, and
        // run a fragment parser given parser."
        if (!self.aborted) if (self.parser) |parser| {
            parser.input_stream.appendToEnd(chunk_string) catch return error.OutOfMemory;
            self.run();
        };
        // 5. writeError again: the run may have set it.
        if (self.write_error) |err| return realm.promiseRejectedWith(err);
        // 6. "Return a promise resolved with undefined in realm."
        return realm.promiseResolvedWithUndefined();
    }

    /// Step 13, closeAlgorithm.
    fn close(self: *StreamParser, realm: js.Realm) js.Error!js.Value {
        self.retain();
        defer self.release();
        // 1-2. "Let closePromise be a new promise created in realm. Set
        // parser's fragment parser close promise to closePromise." The
        // promise holds this parser until it settles.
        const deferred = try js.Deferred.init(realm);
        const promise = js.clone(deferred.promise) catch |err| {
            deferred.deinit();
            return err;
        };
        self.close_promise = deferred;
        self.retain();
        // 3. "Append an explicit EOF character to the end of parser's input
        // stream, and run a fragment parser given parser."
        if (self.aborted or self.parser == null) {
            // An aborted parser never stops parsing: it settles here.
            self.settleClose(realm);
        } else {
            self.parser.?.input_stream.complete = true;
            self.parser.?.input_stream.sync();
            self.run();
        }
        // 4. "Return closePromise."
        return promise;
    }

    /// The parser stopped parsing ("the end", fragment case step 6.1):
    /// resolve the close promise.
    fn settleClose(self: *StreamParser, realm: js.Realm) void {
        const deferred = self.close_promise orelse return;
        self.close_promise = null;
        deferred.resolveUndefined(realm);
        deferred.deinit();
        self.release();
    }

    /// Step 14, abortAlgorithm given reason.
    fn abort(self: *StreamParser, realm: js.Realm) js.Error!js.Value {
        self.retain();
        defer self.release();
        // 1. "Abort parser."
        self.abortFragmentParser();
        // 2. "Return a promise resolved with undefined in realm."
        return realm.promiseResolvedWithUndefined();
    }

    /// The DocumentParser's `on_finished`: HTML "the end" for the fragment
    /// case - the stack is already popped (step 5); 6.1 resolves the close
    /// promise; the parser's work is over.
    fn parserFinished(document: *runtime.Instance, parser: *DocumentParser) void {
        _ = document;
        const self: *StreamParser = @ptrCast(@alignCast(parser.owner orelse return));
        // 2. "If the parser's fragment parser abort requested is true, then
        // return."
        if (self.abort_requested) return;
        const realm = js.Realm.ofContext(self.realm) catch return;
        self.settleClose(realm);
        // 6.2. "If the parser's Document's list of scripts that will execute
        // when the document has finished parsing is not empty, then queue a
        // global task on the DOM manipulation task source given the parser's
        // script target document's relevant global object to execute the
        // deferred scripts given the parser's Document."
        if (self.run_scripts) self.queueDeferredScripts();
    }

    fn queueDeferredScripts(self: *StreamParser) void {
        if (!self.documentAlive()) return;
        const scripts = dom.document_scripts.of(self.document) orelse return;
        if (scripts.scripts_to_execute_when_parsing_finished.items.len == 0) return;
        const loop = self.realm.getOptionalEventLoop() orelse return;
        // The deferred scripts keep their parser - and its Document, their
        // parser document - until the last has run, whatever becomes of the
        // stream.
        if (!self.deferred_hold) {
            self.deferred_hold = true;
            self.retain();
        }
        if (self.parser) |parser| parser.on_resumed_after_end = &deferredScriptReady;
        self.retain();
        loop.queueTask(.{ .callback = &runDeferredScripts, .context = self, .drop = &dropDeferredScripts });
    }

    fn runDeferredScripts(context: ?*anyopaque) void {
        const self: *StreamParser = @ptrCast(@alignCast(context.?));
        defer self.release();
        self.executeDeferredScripts();
    }

    /// A deferred script became ready to be parser-executed after the end.
    fn deferredScriptReady(parser: *DocumentParser) void {
        const self: *StreamParser = @ptrCast(@alignCast(parser.owner orelse return));
        self.retain();
        defer self.release();
        self.executeDeferredScripts();
    }

    /// HTML "execute the deferred scripts" given the parser's Document: the
    /// ready ones in order; the rest wait for their "mark as ready", which
    /// resumes this (script_execution's resumeParserDocument). Once none is
    /// left, the scripts' hold on this parser ends.
    fn executeDeferredScripts(self: *StreamParser) void {
        const alive = self.documentAlive();
        if (!self.aborted and alive) @import("script_execution.zig").executeScriptsWhenParsingFinished(self.allocator, self.document);
        const scripts = if (alive) dom.document_scripts.of(self.document) else null;
        const left = if (scripts) |s| s.scripts_to_execute_when_parsing_finished.items.len else 0;
        if ((left == 0 or self.aborted) and self.deferred_hold) {
            self.deferred_hold = false;
            self.release();
        }
    }

    fn dropDeferredScripts(context: ?*anyopaque) void {
        const self: *StreamParser = @ptrCast(@alignCast(context.?));
        self.release();
    }
};

/// Step 12.1's conversion, run where an exception it throws is caught.
const Converted = struct {
    allocator: Allocator,
    realm: runtime.Context,
    value: runtime.JSValue,
    string: ?[]u8 = null,

    fn run(data: ?*anyopaque) engine.Error!void {
        const self: *Converted = @ptrCast(@alignCast(data.?));
        self.string = try engine.convertToDOMString(self.realm, self.value, self.allocator);
    }
};

const sink_vtable = sw.Sink.VTable{
    .start = struct {
        fn f(_: ?*anyopaque, realm: js.Realm, _: *runtime.Instance) js.Error!js.Completion {
            return .{ .normal = try realm.undefinedValue() };
        }
    }.f,
    .write = struct {
        fn f(ctx: ?*anyopaque, realm: js.Realm, _: *runtime.Instance, chunk: js.Value) js.Error!js.Value {
            const self: *StreamParser = @ptrCast(@alignCast(ctx.?));
            return self.write(realm, chunk);
        }
    }.f,
    .close = struct {
        fn f(ctx: ?*anyopaque, realm: js.Realm, _: *runtime.Instance) js.Error!js.Value {
            const self: *StreamParser = @ptrCast(@alignCast(ctx.?));
            return self.close(realm);
        }
    }.f,
    .abort = struct {
        fn f(ctx: ?*anyopaque, realm: js.Realm, _: *runtime.Instance, _: js.Value) js.Error!js.Value {
            const self: *StreamParser = @ptrCast(@alignCast(ctx.?));
            return self.abort(realm);
        }
    }.f,
    .deinit = struct {
        fn f(ctx: ?*anyopaque, _: Allocator) void {
            const self: *StreamParser = @ptrCast(@alignCast(ctx.?));
            self.release();
        }
    }.f,
};
