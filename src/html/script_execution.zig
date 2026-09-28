//! Script Execution Module
//!
//! Implements the "prepare the script element" and "execute the script element"
//! algorithms from HTML Standard §4.12.1.1.
//!
//! Spec: https://html.spec.whatwg.org/multipage/scripting.html#script-processing-model
//!
//! This module provides the bridge between the HTML parser and the JavaScript
//! engine (the `engine` protocol) for executing inline and external scripts.
//!
//! ## Architecture Note (Golden Rule #12)
//!
//! Per Golden Rule #12: External code must call through INTERFACES, not impls.
//! This module uses interface delegate methods for all WebIDL type interactions:
//! - HTMLScriptElement interface for script element state
//! - Document interface for document-level script management
//!
//! Impls are only imported for type definitions (InternalState, ScriptType, etc.)
//! that are re-exported through the interfaces.

const std = @import("std");

const log = std.log.scoped(.script_execution);
const runtime = @import("runtime");
const webidl = @import("webidl");

// The JavaScript engine, through its protocol: running scripts, realms.
const engine = @import("engine");

// Module script loading: the module map, graph fetching, linking, running.
const module_script = @import("module_script.zig");

// "Report an exception": where a script's uncaught exception goes.
const report_exception = @import("report_exception.zig");

// WebIDL interfaces - used for all WebIDL type interactions (Golden Rule #12)
const interfaces = @import("interfaces");

// Interface types used in this module
const HTMLScriptElement = interfaces.HTMLScriptElement;
const Document = interfaces.Document;
const Node = interfaces.Node;
const Element = interfaces.Element;
const Text = interfaces.Text;
const CharacterData = interfaces.CharacterData;

// Import impls ONLY for type definitions and internal state access
// (Golden Rule #12 exception: accessing InternalState for direct field reads)
const impls = @import("impls");
const ElementImpl = impls.Element;
const NodeImpl = impls.Node;
const HTMLScriptElementImpl = impls.HTMLScriptElement;

// Script element types from impl (internal implementation types)
const ScriptType = HTMLScriptElementImpl.ScriptType;
const ScriptResult = HTMLScriptElementImpl.ScriptResult;
const ClassicScript = HTMLScriptElementImpl.ClassicScript;
const ModuleScript = HTMLScriptElementImpl.ModuleScript;

// Infra primitives
const infra = @import("infra");

// Fetch for external scripts
const fetch = @import("fetch");

// Content Security Policy
const csp = @import("csp");

// Module graph for async module fetching - accessed via html_core module
const html_core = @import("html_core");
const ModuleGraph = html_core.ModuleGraph;
const ModuleGraphFetcher = html_core.ModuleGraphFetcher;
const ModuleNode = html_core.ModuleNode;
const EventLoop = html_core.EventLoop;
const TaskSource = html_core.TaskSource;

// Document script state - provides access to Document's internal script state.
// NOTE: Per Golden Rule #12, external code should not import impls directly.
// However, Document's internal script state functions (isScriptingEnabled, etc.)
// are not defined in WebIDL and thus have no interface delegates.
// Long-term: These functions should move to internal modules (see whatwg-wvruv).
// Short-term: We use doc_state as an alias for DocumentImpl to clearly mark
// which functions are internal state access vs WebIDL operations.
const doc_state = impls.Document;

pub const ScriptExecutionError = error{
    InvalidScriptElement,
    ScriptingDisabled,
    DocumentMismatch,
    ParseError,
    NetworkError,
    SecurityError,
    AlreadyStarted,
    NotConnected,
    OutOfMemory,
};

/// An embedder's loader for the external classic scripts a parser prepares:
/// given the src attribute's value, their source (allocated with `allocator`),
/// or null for a network error. The WPT runner has one, which serves
/// testharness.js once. A parser sets it around its "prepare the script
/// element" call (`withParserScriptLoader`), and prepare consults it at its
/// fetch step - never before: prefetching at the end tag fetched scripts that
/// prepare then declined to run (html/syntax/speculative-parsing/generated/
/// document-write/script-src-unsupported-type).
pub const ParserScriptLoader = struct {
    context: ?*anyopaque,
    load: *const fn (context: ?*anyopaque, src: []const u8) ?[]const u8,
    allocator: std.mem.Allocator,
};

/// The loader, and the one element it serves: the script the parser is
/// preparing. Preparing that script can run script - a parser-inserted
/// inline script executes inside its prepare - which inserts and prepares
/// other script elements, and those are fetched as any script-inserted script
/// is: relative to the document base URL, data: URLs included.
const ScopedParserScriptLoader = struct {
    element: *runtime.Instance,
    loader: ParserScriptLoader,
};

threadlocal var parser_script_loader: ?ScopedParserScriptLoader = null;

/// "Prepare the script element" for a parser whose embedder loads its
/// external classic scripts with `loader`.
pub fn prepareScriptElementWithLoader(
    allocator: std.mem.Allocator,
    script_element: *runtime.Instance,
    loader: ?ParserScriptLoader,
) ScriptExecutionError!bool {
    const saved = parser_script_loader;
    parser_script_loader = if (loader) |l| .{ .element = script_element, .loader = l } else null;
    defer parser_script_loader = saved;
    return prepareScriptElement(allocator, script_element);
}

/// An external classic script's source, owned by `allocator`: the
/// embedder's loader for the parser preparing it, when it has one and it
/// answers, else "fetch a classic script" for `url` - a data: URL, which the
/// WPT runner's loader resolves as a path (html/semantics/scripting-1/
/// the-script-element/data-url.html), is fetched. Null body: a network error.
const FetchedSource = struct {
    body: ?[]const u8,
    allocator: std.mem.Allocator,

    fn deinit(self: *FetchedSource) void {
        if (self.body) |b| self.allocator.free(b);
        self.body = null;
    }
};

fn fetchClassicScriptSource(allocator: std.mem.Allocator, script_element: *runtime.Instance, src: []const u8, url: []const u8) FetchedSource {
    if (parserScriptLoaderFor(script_element)) |loader| {
        if (loader.load(loader.context, src)) |body| return .{ .body = body, .allocator = loader.allocator };
    }
    var fetch_result = fetchExternalScript(allocator, url);
    const body = fetch_result.body;
    fetch_result.body = null;
    fetch_result.deinit(allocator);
    return .{ .body = body, .allocator = allocator };
}

/// The embedder's loader, if the parser is preparing `script_element` with
/// one.
fn parserScriptLoaderFor(script_element: *runtime.Instance) ?ParserScriptLoader {
    const scoped = parser_script_loader orelse return null;
    if (scoped.element != script_element) return null;
    return scoped.loader;
}

/// Prepare the script element
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#prepare-the-script-element
///
/// This is the main entry point for script preparation. It determines the script type,
/// validates preconditions, and either immediately executes (for inline classic scripts)
/// or queues the script for later execution.
///
/// Returns true if the script was prepared successfully and may need execution,
/// false if preparation was aborted.
pub fn prepareScriptElement(
    allocator: std.mem.Allocator,
    script_element: *runtime.Instance,
) ScriptExecutionError!bool {
    // Step 1: If el's already started is true, then return
    // Note: hasAlreadyStarted is an internal state accessor, so we call the impl directly
    // (Golden Rule #12 exception: accessing InternalState for direct field reads)
    if (HTMLScriptElementImpl.hasAlreadyStarted(script_element)) {
        return false;
    }

    // Step 2: Let parser document be el's parser document
    const parser_document = HTMLScriptElementImpl.getParserDocument(script_element);

    // Step 3: Set el's parser document to null
    HTMLScriptElementImpl.setParserDocument(script_element, null);

    // Step 4: If parser document is non-null and el does not have an async attribute,
    // then set el's force async to true
    if (parser_document != null) {
        if (!hasAsyncAttribute(script_element)) {
            // force_async is already true by default, so this step is a no-op
            // But per spec, if parser_document was null initially, force_async stays as-is
        }
    }

    // Step 5: Let source text be el's child text content
    const source_text = getChildTextContent(allocator, script_element) catch |err| {
        if (err == error.OutOfMemory) return ScriptExecutionError.OutOfMemory;
        return false; // Abort on other errors
    };
    defer if (source_text.len > 0) allocator.free(source_text);

    // Step 6: If el has no src attribute, and source text is empty, then return
    if (!hasSrcAttribute(script_element) and source_text.len == 0) {
        return false;
    }

    // Step 7: If el is not connected, then return
    if (!isConnected(script_element)) {
        return false;
    }

    // Steps 8-13: Determine script type from type attribute
    const script_type = determineScriptType(script_element);
    if (script_type == .null) {
        // Step 13: Otherwise, return (no script is executed)
        return false;
    }

    // Step 14: If parser document is non-null, set el's parser document back
    // and set force_async to false
    if (parser_document) |pd| {
        HTMLScriptElementImpl.setParserDocument(script_element, pd);
        HTMLScriptElementImpl.clearForceAsync(script_element);
    }

    // Step 15: Set el's already started to true
    HTMLScriptElementImpl.setAlreadyStarted(script_element, true);

    // Step 16: Set el's preparation-time document to its node document
    const node_document = getNodeDocument(script_element);
    HTMLScriptElementImpl.setPreparationTimeDocument(script_element, node_document);

    // Step 17: If parser document is non-null and not equal to preparation-time document, return
    if (parser_document) |pd| {
        if (pd != node_document) {
            return false;
        }
    }

    // Step 18: If scripting is disabled for el, then return
    if (node_document) |doc| {
        if (!scriptingEnabled(doc)) {
            return false;
        }
    }

    // Step 19: If el has a nomodule attribute and type is "classic", return
    if (script_type == .classic and hasNoModuleAttribute(script_element)) {
        return false;
    }

    // Step 20: Let cspType be "script" if type is classic/module, "import map" if importmap
    // Step 21: CSP check for inline scripts
    // Spec: https://www.w3.org/TR/CSP3/ §6.7.3
    //
    // For inline scripts, we need to check:
    // - 'unsafe-inline' keyword (only if no nonce/hash in directive)
    // - Nonce matching (nonce attribute)
    // - Hash matching (computed from source text)
    if (!hasSrcAttribute(script_element)) {
        // This is an inline script
        if (node_document) |doc| {
            // Get nonce attribute if present
            const nonce = getNonceAttribute(script_element);

            // TODO: Compute hash of source text for hash-based CSP
            // For now, we only check nonce and 'unsafe-inline'

            // Check if inline script is allowed by CSP
            if (!doc_state.isInlineScriptAllowedByCSP(
                doc,
                if (nonce.len > 0) nonce else null,
                null, // hash_algorithm (TODO: compute from source)
                null, // hash_value (TODO: compute from source)
            )) {
                // CSP blocked inline script
                log.debug("CSP blocked inline script\n", .{});
                return false;
            }
        }
    }

    // Step 22: Handle obsolete event/for attributes for classic scripts
    if (script_type == .classic) {
        if (hasEventAttribute(script_element) and hasForAttribute(script_element)) {
            const for_attr = getForAttribute(script_element);
            const event_attr = getEventAttribute(script_element);

            const trimmed_for = std.mem.trim(u8, for_attr, " \t\n\r\x0c");
            const trimmed_event = std.mem.trim(u8, event_attr, " \t\n\r\x0c");

            // If for is not "window", return
            if (!std.ascii.eqlIgnoreCase(trimmed_for, "window")) {
                return false;
            }

            // If event is not "onload" or "onload()", return
            if (!std.ascii.eqlIgnoreCase(trimmed_event, "onload") and
                !std.ascii.eqlIgnoreCase(trimmed_event, "onload()"))
            {
                return false;
            }
        }
    }

    // Steps 23-31: Build fetch options (encoding, CORS, integrity, etc.)
    // For now, we skip external script fetching

    // Set the script type
    HTMLScriptElementImpl.setScriptType(script_element, script_type);

    // Step 33: If el has a src content attribute
    if (hasSrcAttribute(script_element)) {
        // Step 33.1: an external import map or speculation rule set is not
        // supported - queue an element task to fire error at el, and return.
        if (script_type == .importmap or script_type == .speculationrules) {
            queueErrorEventTask(script_element);
            return false;
        }

        // Step 33.2: Let src be the value of el's src attribute.
        const src = getSrcAttribute(script_element);

        // Step 33.3: If src is the empty string, queue an element task to fire
        // error at el, and return.
        if (src.len == 0) {
            queueErrorEventTask(script_element);
            return false;
        }

        // Step 33.4: Set el's from an external file to true.
        HTMLScriptElementImpl.setFromExternalFile(script_element, true);

        // Step 33.5: Let url be the result of encoding-parsing a URL given src,
        // relative to el's node document.
        const base_url = documentBaseUrlAlloc(allocator, node_document, script_element) orelse
            return ScriptExecutionError.OutOfMemory;
        defer allocator.free(base_url);
        const parsed_url = parseUrl(script_element, src, base_url) orelse {
            // Step 33.6: If url is failure, queue an element task to fire error
            // at el, and return.
            queueErrorEventTask(script_element);
            return false;
        };
        defer script_element.ctx.allocator.free(parsed_url);

        // The element keeps its own copy: the script result points at it, and
        // a deferred or async script runs long after this frame has returned.
        const script_url = (HTMLScriptElementImpl.setScriptUrl(script_element, parsed_url) catch
            return ScriptExecutionError.OutOfMemory) orelse parsed_url;

        // Step 33.11: fetch the script. Crane's fetch is synchronous, so
        // onComplete - "mark as ready el given result" - runs right here, and
        // the scheduling of step 35 below sees a script whose result is known.
        //
        // A request CSP blocks is a network error to Fetch
        // (https://www.w3.org/TR/CSP3/ §4.1.2), so it takes the same path as
        // any other failed fetch: result null, which executing the element
        // turns into an error event.
        const allowed_by_csp = blk: {
            const doc = node_document orelse break :blk true;
            const url_parts = parseUrlForCSP(script_url);
            const nonce = getNonceAttribute(script_element);
            break :blk doc_state.isExternalScriptAllowedByCSP(
                doc,
                url_parts.scheme,
                url_parts.host,
                url_parts.port,
                url_parts.path,
                if (nonce.len > 0) nonce else null,
            );
        };
        if (!allowed_by_csp) log.debug("CSP blocked external script: {s}", .{script_url});

        // Step 33.11 "module": fetch an external module script graph given url,
        // and mark el ready with the result.
        if (script_type == .module) {
            if (allowed_by_csp and node_document != null) {
                prepareExternalModuleScript(script_element, node_document.?, script_url);
            } else {
                HTMLScriptElementImpl.setResult(script_element, .null);
            }
            // Step 35 decides when the result counts as ready.
            return handleScriptScheduling(allocator, script_element, parser_document, script_type);
        }

        // Content already cached for the element is used as-is. Otherwise the
        // embedder's loader for the parser preparing this script, when it has
        // one, stands in for "fetch a classic script" - here, at the fetch
        // step, so a script that prepare returns from earlier (a type that is
        // no JavaScript MIME type, nomodule) is never fetched.
        const cached = if (allowed_by_csp) HTMLScriptElementImpl.getCachedSourceText(script_element) else null;
        if (cached == null and allowed_by_csp) {
            var fetched = fetchClassicScriptSource(allocator, script_element, src, script_url);
            defer fetched.deinit();
            if (fetched.body) |body| {
                HTMLScriptElementImpl.cacheSourceText(script_element, body) catch
                    return ScriptExecutionError.OutOfMemory;
            }
        }

        if (HTMLScriptElementImpl.getCachedSourceText(script_element)) |body| {
            if (allowed_by_csp) {
                HTMLScriptElementImpl.setResult(script_element, .{ .script = ClassicScript.init(body, script_url) });
            } else {
                HTMLScriptElementImpl.setResult(script_element, .null);
            }
        } else {
            // "fetch a classic script" hands onComplete null for a network
            // error or a non-ok status. The element still goes through the
            // scheduling below: executing it is what fires the error event.
            HTMLScriptElementImpl.setResult(script_element, .null);
        }

        // Step 35: scheduling - which also decides when the result, already
        // in hand, is delivered ("mark as ready").
        return handleScriptScheduling(allocator, script_element, parser_document, script_type);
    }

    // Step 34: Inline script (no src attribute)
    if (node_document) |doc| {
        // Step 34.1: "Let base URL be el's node document's document base URL."
        const base_url = documentBaseUrlAlloc(allocator, doc, script_element) orelse
            return ScriptExecutionError.OutOfMemory;
        defer allocator.free(base_url);

        switch (script_type) {
            .classic => {
                // Step 34.2.1: Create a classic script with base URL - the
                // document base URL now, kept by the script's [[HostDefined]]
                // record, which the document owns, so it lives as long as the
                // result. With no record, the document's URL, which the
                // document keeps too. (Its errors report the document's URL
                // as their filename: runClassicScript.)
                const script_base_url = if (classicScriptRecord(doc, base_url)) |record|
                    record.script.base_url
                else
                    documentUrl(doc, script_element);
                const script = ClassicScript.init(source_text, script_base_url);

                // Step 34.2.2: Mark as ready
                HTMLScriptElementImpl.setResult(script_element, .{ .script = script });

                // Cache the source text for execution
                HTMLScriptElementImpl.cacheSourceText(script_element, source_text) catch {
                    return ScriptExecutionError.OutOfMemory;
                };
            },
            .module => {
                // Step 34.2 "module", step 3: fetch an inline module script
                // graph given source text and base URL. Its onComplete queues
                // the task that marks el ready - "even if the inline module
                // script has no dependencies or synchronously results in a
                // parse error, we won't proceed to execute the script element
                // synchronously" - which step 35's scheduling below does.
                prepareInlineModuleScript(script_element, doc, source_text, base_url);
            },
            .importmap => {
                // Parse and register import map
                // Spec: https://html.spec.whatwg.org/multipage/webappapis.html#import-map-parse-result

                // Step 1: Check if import map has already been acquired
                if (doc_state.hasImportMapAcquired(doc)) {
                    // Only one import map per document is allowed
                    // Subsequent import maps are ignored with a console warning
                    log.debug("Import map ignored: document already has an import map\n", .{});
                    return false;
                }

                // Step 2: Parse the import map JSON
                const import_map_result = parseImportMap(allocator, source_text, base_url);
                defer {
                    if (import_map_result.allocator) |alloc| {
                        if (import_map_result.error_message) |msg| {
                            alloc.free(msg);
                        }
                    }
                }

                if (import_map_result.error_message) |err_msg| {
                    log.debug("Import map parse error: {s}\n", .{err_msg});
                    return false;
                }

                // Step 3: Register the import map
                registerImportMap(doc, import_map_result) catch |err| {
                    log.debug("Failed to register import map: {}\n", .{err});
                    return false;
                };

                // Step 4: Mark import map as acquired
                doc_state.setImportMapAcquired(doc);

                return true;
            },
            .speculationrules => {
                // Parse and process speculation rules
                // Spec: https://html.spec.whatwg.org/multipage/speculative-loading.html#speculation-rules

                // Step 1: Parse the speculation rules JSON
                const speculation_result = parseSpeculationRules(allocator, source_text, base_url);
                defer {
                    if (speculation_result.allocator) |alloc| {
                        if (speculation_result.error_message) |msg| {
                            alloc.free(msg);
                        }
                    }
                }

                if (speculation_result.error_message) |err_msg| {
                    log.debug("Speculation rules parse error: {s}\n", .{err_msg});
                    return false;
                }

                // Step 2: Register speculation rules with the document
                registerSpeculationRules(doc, speculation_result) catch |err| {
                    log.debug("Failed to register speculation rules: {}\n", .{err});
                    return false;
                };

                return true;
            },
            .null => return false,
        }
    }

    // Step 35-36: Handle script scheduling based on type and attributes
    // Spec: https://html.spec.whatwg.org/multipage/scripting.html#prepare-the-script-element
    return handleScriptScheduling(allocator, script_element, parser_document, script_type);
}

/// "Prepare the script element" steps 35 and 36: where the element goes, and
/// what happens once its result is ready.
///
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#prepare-the-script-element
///
/// The result is already in hand when this runs - Crane fetches scripts
/// synchronously - so the only question left is WHEN it counts as ready ("mark
/// as ready", which runs the element's "steps to run when the result is
/// ready"):
///
/// - For step 35's first two cases, the async set and the in-order list, the
///   spec's onComplete runs from a task (fetch's processResponseConsumeBody,
///   or the networking task step 34 queues for an inline module), never inside
///   the insertion that prepared the element. So it is queued here too
///   (`queueMarkAsReady`). Marking these ready on the spot ran a
///   script-inserted `<script src>` inside `appendChild`, before the caller's
///   next statement could attach its `onload`.
/// - For the parser's cases (35.4 and 35.5) the parser executes the script,
///   and it reads "ready to be parser-executed" as soon as it asks.
fn handleScriptScheduling(
    allocator: std.mem.Allocator,
    script_element: *runtime.Instance,
    parser_document: ?*runtime.Instance,
    script_type: ScriptType,
) ScriptExecutionError!bool {
    const has_src = hasSrcAttribute(script_element);
    const has_async = hasAsyncAttribute(script_element);
    const has_defer = hasDeferAttribute(script_element);
    const internal = HTMLScriptElementImpl.getInternal(script_element);
    const force_async = if (internal) |int| int.force_async else true;

    // Step 16 made the node document the preparation-time document; its lists
    // are the ones step 35 appends to.
    const node_document = getNodeDocument(script_element);

    const is_parser_inserted = parser_document != null;

    switch (script_type) {
        .classic, .module => {},
        // Import maps are registered and speculation rules parsed during
        // preparation; nothing is left to schedule.
        .importmap, .speculationrules, .null => return false,
    }

    // Step 35: a classic script with a src attribute, or any module script.
    if (script_type == .module or has_src) {
        const doc = node_document orelse return true;

        if (has_async or force_async) {
            // 35.2: the set of scripts that will execute as soon as possible.
            // Tested first, and gated on "async attribute OR force async", so
            // a script the parser never touched lands here whether or not the
            // author wrote `async`.
            doc_state.addScriptToExecuteAsap(doc, script_element) catch {};
            queueMarkAsReady(script_element, doc);
        } else if (!is_parser_inserted) {
            // 35.3: the list of scripts that will execute in order as soon as
            // possible.
            doc_state.addScriptToExecuteInOrderAsap(doc, script_element) catch {};
            queueMarkAsReady(script_element, doc);
        } else if (has_defer or script_type == .module) {
            // 35.4: the list of scripts that will execute when the document
            // has finished parsing; the parser runs it at "the end".
            doc_state.addScriptToExecuteWhenParsingFinished(doc, script_element) catch {};
            markReady(script_element);
        } else {
            // 35.5: "Set el's parser document's pending parsing-blocking
            // script to el", and - its fetch being done - ready to be
            // parser-executed. The parser runs it once the script end tag's
            // steps are over: at once for a script in the document's own
            // markup, but after the enclosing script has finished for one that
            // script's document.write() inserted, which is what sets the
            // parser pause flag and stops the nested parse
            // (parser_script_execution.runPendingParsingBlockingScripts).
            markReady(script_element);
            setPendingParsingBlockingScript(parser_document orelse doc, script_element);
        }
        return true;
    }

    // Step 36: an inline classic script.
    if (is_parser_inserted) {
        // 36.2: a parser-inserted script whose document has a style sheet that
        // is blocking scripts waits for it, as the pending parsing-blocking
        // script.
        // Spec: https://html.spec.whatwg.org/multipage/semantics.html#has-a-style-sheet-that-is-blocking-scripts
        if (node_document) |doc| {
            if (doc_state.hasStyleSheetBlockingScripts(doc)) {
                markReady(script_element);
                setPendingParsingBlockingScript(parser_document orelse doc, script_element);
                return true;
            }
        }
    }

    // 36.3: otherwise, immediately execute the script element.
    _ = executeScriptElement(allocator, script_element) catch {};
    return true;
}

/// "Ready to be parser-executed", which Crane also reads as "the result is no
/// longer uninitialized" for the two as-soon-as-possible queues.
fn markReady(script_element: *runtime.Instance) void {
    HTMLScriptElementImpl.setReadyToBeParserExecuted(script_element, true);
}

/// Deliver the element's result from a task: "mark as ready", then run the
/// steps to run when the result is ready - here, drain the preparation-time
/// document's as-soon-as-possible queues.
///
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#mark-as-ready
/// For a fetched script the task is fetch's (the networking task source runs
/// processResponseConsumeBody); for an inline module, prepare step 34 queues
/// "an element task on the networking task source given el".
fn queueMarkAsReady(script_element: *runtime.Instance, document: *runtime.Instance) void {
    const ctx = script_element.ctx;
    const loop = ctx.getOptionalEventLoop() orelse return markReadyNow(ctx.allocator, script_element, document);
    const task = ctx.allocator.create(QueuedMarkAsReady) catch return markReadyNow(ctx.allocator, script_element, document);
    task.* = .{
        .element = script_element,
        .generation = runtime.SlabAllocator.generationOf(script_element),
        .document = document,
        .document_generation = runtime.SlabAllocator.generationOf(document),
        .allocator = ctx.allocator,
    };
    engine.keepPlatformObjectAlive(script_element);
    loop.queueTask(.{ .callback = &runQueuedMarkAsReady, .context = task, .drop = &dropQueuedMarkAsReady });
}

/// No event loop to queue on (a context built for tests): the result is still
/// owed, so deliver it now rather than lose it.
fn markReadyNow(allocator: std.mem.Allocator, script_element: *runtime.Instance, document: *runtime.Instance) void {
    markReady(script_element);
    drainReadyScripts(allocator, document);
}

/// A queued "mark as ready".
///
/// The element sits in one of its document's script queues until this runs,
/// and the spec's queue keeps it alive: a script removed from the tree before
/// its result arrives still executes (or is skipped by execute step 2) and
/// still leaves the queue. Crane's queues hold bare pointers, which the engine
/// cannot see, so the element has pending activity until the task has run
/// (`engine.keepPlatformObjectAlive`) - otherwise a collection in between
/// would leave a freed element in the queue for the next drain to execute.
/// With the fetch already done, a script's task is queued in the order its
/// element joined the in-order list, so by the time the task has run,
/// everything ahead of the element has run too and the drain has taken it out
/// of its queue.
///
/// The document is held as (address, slab generation), like
/// `QueuedElementEvent`'s element: nothing keeps it alive while the task
/// waits, and the slab reuses a freed Instance's address.
const QueuedMarkAsReady = struct {
    element: *runtime.Instance,
    generation: u64,
    /// The preparation-time document, whose queues hold the element.
    document: *runtime.Instance,
    document_generation: u64,
    allocator: std.mem.Allocator,

    fn destroy(self: *QueuedMarkAsReady) void {
        // The pending activity ends with the task - unless the element went
        // anyway (its tree was freed), and its address is someone else's.
        if (runtime.SlabAllocator.generationOf(self.element) == self.generation)
            engine.releasePlatformObject(self.element);
        self.allocator.destroy(self);
    }
};

/// `Task.drop`: the page ended with the result undelivered.
fn dropQueuedMarkAsReady(data: ?*anyopaque) void {
    const task: *QueuedMarkAsReady = @ptrCast(@alignCast(data orelse return));
    task.destroy();
}

fn runQueuedMarkAsReady(data: ?*anyopaque) void {
    const task: *QueuedMarkAsReady = @ptrCast(@alignCast(data orelse return));
    defer task.destroy();

    if (runtime.SlabAllocator.generationOf(task.element) != task.generation) return;
    if (runtime.SlabAllocator.generationOf(task.document) != task.document_generation) return;

    // A task of the element's realm: executing a script and firing its load
    // or error event run in it. An error means the realm is gone.
    engine.runTaskInRealm(task.element.ctx, markAsReadySteps, task) catch return;
}

fn markAsReadySteps(data: ?*anyopaque) void {
    const task: *QueuedMarkAsReady = @ptrCast(@alignCast(data.?));
    markReadyNow(task.allocator, task.element, task.document);
}

/// The parser's pending parsing-blocking script loop, one turn: if the
/// document's pending parsing-blocking script is ready to be parser-executed,
/// unset it and execute it. Returns whether one ran.
///
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html#scriptEndTag
/// ("Otherwise: While the pending parsing-blocking script is not null: 1. Let
///  the script be the pending parsing-blocking script. 2. Set the pending
///  parsing-blocking script to null. ... 8. Execute the script element the
///  script.")
pub fn executePendingParserBlockingScript(
    allocator: std.mem.Allocator,
    document: *runtime.Instance,
) bool {
    const pending_script = pendingParsingBlockingScript(document) orelse return false;

    // "Spin the event loop until the parser's Document has no style sheet that
    // is blocking scripts and the script's ready to be parser-executed is
    // true." Fetches complete at preparation, so a pending script is ready.
    if (!HTMLScriptElementImpl.isReadyToBeParserExecuted(pending_script)) return false;

    setPendingParsingBlockingScript(document, null);

    _ = executeScriptElement(allocator, pending_script) catch |err| {
        log.debug("Parser-blocking script execution error: {}", .{err});
    };
    return true;
}

/// The document's pending parsing-blocking script, if any.
pub fn pendingParsingBlockingScript(document: *runtime.Instance) ?*runtime.Instance {
    return doc_state.getPendingParsingBlockingScript(document);
}

fn setPendingParsingBlockingScript(document: *runtime.Instance, script: ?*runtime.Instance) void {
    doc_state.setPendingParsingBlockingScript(document, script);
}

/// Execute all scripts that should run when document finishes parsing
/// Called when the parser reaches the end of the document
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html#the-end (step 3)
pub fn executeScriptsWhenParsingFinished(
    allocator: std.mem.Allocator,
    document: *runtime.Instance,
) void {
    // Step 5.1 spins the event loop until the first deferred script is ready,
    // and while it spins, the scripts that execute as soon as possible run as
    // their results arrive. Crane's parser does not yield while it parses and
    // its fetches finish at preparation, so every result in that set has
    // arrived - its delivery is only waiting for the task queued behind this
    // parse. Delivered here, an async script runs before the deferred ones, as
    // it does in a browser whenever it loaded no later than they did
    // (execution-timing/085: a fast async script and a slow deferred one).
    // Deviation, stated: with a real network an async script slower than the
    // deferred scripts would run after them (execution-timing/088 and /112
    // time it that way, and fail either way until fetches are asynchronous).
    // The in-order list waits for its tasks: a script-inserted in-order script
    // is not ahead of the parser's deferred scripts (execution-timing/092).
    var guard: usize = 0;
    while (guard < 1024 and runOneReadyAsapScript(allocator, document, .delivered_or_not)) : (guard += 1) {}

    const scripts = doc_state.getScriptsToExecuteWhenParsingFinished(document);

    for (scripts) |script| {
        // Execute each deferred script in order
        _ = executeScriptElement(allocator, script) catch |err| {
            log.debug("Deferred script execution error: {}\n", .{err});
        };
    }

    // Clear the list
    doc_state.clearScriptsToExecuteWhenParsingFinished(document);
}

/// The document whose ready-script queues a drain is currently walking.
///
/// A script that runs from a drain can insert another script, which re-enters
/// `handleScriptScheduling` and asks for a drain of its own. Letting that
/// recurse would nest arbitrarily deep on a page that appends a script per
/// script, and would run the inner script BEFORE the outer loop had finished
/// its own list.
///
/// It records the DOCUMENT rather than a bare boolean, because a script in one
/// document can insert a script into another - an iframe's, or one from
/// `createHTMLDocument` - and a global flag would suppress that document's
/// drain while nobody was walking its queues, stranding the script forever.
/// The outer loop only ever rescans the document it was given.
var draining_document: ?*runtime.Instance = null;

/// Backstop for a mutually-recursive pair of documents inserting into each
/// other, which the per-document guard alone does not stop.
var drain_depth: usize = 0;
const max_drain_depth = 16;

/// Run the document's ready scripts from both "as soon as possible" queues.
///
/// Spec: the steps to run when the result is ready of "prepare the script
/// element" step 35.2 - execute el, then remove it from the set - and 35.3 -
/// while the list's first script is ready, execute it and remove it. It runs
/// from `runQueuedMarkAsReady`, the task that delivers a result.
///
/// Nothing drained these queues at all before this existed, so every async or
/// force-async script - which is every `<script src>` that script inserted -
/// was queued and then simply forgotten.
fn drainReadyScripts(allocator: std.mem.Allocator, document: *runtime.Instance) void {
    if (draining_document == document) return;
    if (drain_depth >= max_drain_depth) return;

    const previous = draining_document;
    draining_document = document;
    drain_depth += 1;
    defer {
        draining_document = previous;
        drain_depth -= 1;
    }

    // Bounded so a script that reinserts itself cannot spin forever.
    var guard: usize = 0;
    while (guard < 1024) : (guard += 1) {
        if (runOneReadyAsapScript(allocator, document, .delivered)) continue;
        if (runOneReadyInOrderScript(allocator, document)) continue;
        break;
    }
}

/// Which scripts of the as-soon-as-possible set may run.
const AsapResults = enum {
    /// Those marked ready - the task delivering the result has run.
    delivered,
    /// Every one: Crane fetches at preparation, so each result is in hand
    /// and only its delivery task is pending (the end of parsing).
    delivered_or_not,
};

/// Run one ready script from the "execute as soon as possible" SET, if any.
///
/// The list is re-read on every call rather than iterated once.
/// `getScriptsToExecuteAsap` returns the ArrayList's `items` slice, and
/// executing a script can append to that list and reallocate it - walking the
/// original slice would be a use-after-free on the hottest DOM path there is.
fn runOneReadyAsapScript(allocator: std.mem.Allocator, document: *runtime.Instance, which: AsapResults) bool {
    const scripts = doc_state.getScriptsToExecuteAsap(document);
    for (scripts) |script| {
        if (which == .delivered and !HTMLScriptElementImpl.isReadyToBeParserExecuted(script)) continue;
        // Its result is in hand (see `AsapResults`): deliver it now.
        markReady(script);
        _ = doc_state.removeScriptFromExecuteAsap(document, script);
        _ = executeScriptElement(allocator, script) catch |err| {
            log.debug("ASAP script execution error: {}", .{err});
        };
        return true;
    }
    return false;
}

/// Run the head of the "execute in order as soon as possible" LIST, if ready.
///
/// Order is the whole point of this list, so a script that is not ready blocks
/// the ones behind it rather than being skipped.
fn runOneReadyInOrderScript(allocator: std.mem.Allocator, document: *runtime.Instance) bool {
    const script = doc_state.popFirstScriptToExecuteInOrderAsap(document) orelse return false;

    if (!HTMLScriptElementImpl.isReadyToBeParserExecuted(script)) {
        doc_state.addScriptToExecuteInOrderAsap(document, script) catch {};
        return false;
    }

    _ = executeScriptElement(allocator, script) catch |err| {
        log.debug("In-order async script execution error: {}", .{err});
    };
    return true;
}

/// Execute every ready script in the document's "execute ASAP" set.
pub fn executeScriptsAsap(allocator: std.mem.Allocator, document: *runtime.Instance) void {
    drainReadyScripts(allocator, document);
}

/// Execute the head of the document's "execute in order ASAP" list while ready.
pub fn executeScriptsInOrderAsap(allocator: std.mem.Allocator, document: *runtime.Instance) void {
    drainReadyScripts(allocator, document);
}

/// Execute the script element
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#execute-the-script-element
///
/// Executes the prepared script using V8.
pub fn executeScriptElement(
    allocator: std.mem.Allocator,
    script_element: *runtime.Instance,
) ScriptExecutionError!void {
    // Step 1: Let document be el's node document
    const node_document = getNodeDocument(script_element) orelse {
        return ScriptExecutionError.InvalidScriptElement;
    };

    // Step 2: If el's preparation-time document is not equal to document, return
    const prep_time_doc = HTMLScriptElementImpl.getPreparationTimeDocument(script_element);
    if (prep_time_doc != node_document) {
        return;
    }

    // Step 3: Unblock rendering (not implemented - no rendering engine)

    // Step 4: If el's result is null, fire error event and return
    const result = HTMLScriptElementImpl.getResult(script_element);
    switch (result) {
        .null => {
            // Fire error event per spec
            fireErrorEvent(allocator, script_element);
            return;
        },
        .uninitialized => {
            return ScriptExecutionError.InvalidScriptElement;
        },
        else => {},
    }

    // Step 5: If el's from an external file is true or type is "module",
    // increment ignore-destructive-writes counter
    const from_external = HTMLScriptElementImpl.isFromExternalFile(script_element);
    const script_type = HTMLScriptElementImpl.getScriptType(script_element);
    const should_increment_counter = from_external or script_type == .module;

    if (should_increment_counter) {
        doc_state.incrementIgnoreDestructiveWritesCounter(node_document);
    }
    defer if (should_increment_counter) {
        doc_state.decrementIgnoreDestructiveWritesCounter(node_document);
    };

    // Step 6: Execute based on script type
    switch (script_type) {
        .classic => {
            // Step 6.1: Let oldCurrentScript be document's currentScript
            // Step 6.2: If el's root is not a shadow root, set currentScript to el
            // (We'll assume no shadow roots for now)
            const old_current_script = swapCurrentScript(node_document, script_element);

            // Step 6.3: Run the classic script given by el's result.
            runClassicScript(script_element, node_document, from_external);

            // Step 6.4: Set currentScript back to oldCurrentScript
            _ = swapCurrentScript(node_document, old_current_script);
        },
        .module => {
            // Step 6 "module": document's currentScript is null while a module
            // runs (it is never set on this path); run the module script given
            // by el's result.
            runModuleScript(script_element, node_document);
        },
        .importmap => {
            // Step 6.3: Register an import map
            // Not yet implemented
        },
        .speculationrules => {
            // Step 6.4: Register speculation rules
            // Not yet implemented
        },
        .null => {},
    }

    // Step 7: Decrement counter was handled with defer above.
    //
    // No microtask checkpoint here: "run a classic script" and "run a module
    // script" end with "clean up after running script", which performs it
    // when the JavaScript execution context stack is empty - and must not
    // when this script was executed from inside another (appendChild from a
    // script), which a checkpoint here did regardless.

    // Step 8: If el's from an external file is true, fire load event
    if (from_external) {
        fireLoadEvent(allocator, script_element);
    }
}

/// Run a classic script: el's result, in el's realm.
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#run-a-classic-script
///
/// Deviation, stated: the script runs in el's realm, not in the relevant realm
/// of el's node document - the same realm unless el was adopted from another
/// realm's document before it was prepared. Module scripts do the same
/// (`moduleEnvironment`).
fn runClassicScript(script_element: *runtime.Instance, document: *runtime.Instance, from_external: bool) void {
    const script = switch (HTMLScriptElementImpl.getResult(script_element)) {
        .script => |s| s,
        else => return,
    };

    // CRITICAL: Always use getCachedSourceText for the source.
    // The source_text in ClassicScript is a dangling pointer to memory freed
    // at the end of prepareScriptElement. The cached source text is a
    // properly duplicated copy stored in the HTMLScriptElement's internal state.
    const source = HTMLScriptElementImpl.getCachedSourceText(script_element) orelse return;

    // The resource name errors report as their filename: the script's URL for
    // an external script (its base URL), the document's URL for an inline one.
    const url = if (from_external) script.base_url else documentUrl(document, script_element);
    runClassicScriptText(script_element, document, source, url, script.base_url, script.muted_errors);
}

/// "Create a classic script" from `source` with `base_url`, and "run a classic
/// script" with rethrow errors false, in the realm of `element` (an HTML or SVG
/// script): the engine's operation, which prepares to run script, reports a
/// parse error or a thrown exception through `reportClassicScriptError`, and
/// cleans up after running script - the microtask checkpoint, when the
/// JavaScript execution context stack is then empty. `url` is the script's
/// resource name, the filename of what it throws.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#run-a-classic-script
fn runClassicScriptText(element: *runtime.Instance, document: *runtime.Instance, source: []const u8, url: []const u8, base_url: []const u8, muted: bool) void {
    const realm = element.ctx;
    // The script's [[HostDefined]]: what an import() in it resolves against.
    const host_defined: ?*anyopaque = if (classicScriptRecord(document, base_url)) |record| &record.script else null;
    var host = ClassicScriptReport{ .realm = realm, .muted = muted };
    engine.runClassicScript(realm, .{ .utf8 = source }, url, host_defined, .{
        .report = reportClassicScriptError,
        .host = &host,
    }) catch |err| switch (err) {
        // Step 8.3: thrown, and reported.
        error.ExceptionReported => {},
        else => log.debug("classic script not run: {}", .{err}),
    };
}

/// Who "run a classic script" step 8.3 reports to, and how: the global of the
/// realm the script ran in - its settings object's - with the script's muted
/// errors flag.
const ClassicScriptReport = struct {
    realm: runtime.Context,
    muted: bool,
};

/// `engine.Reporter.report` for classic scripts: "report an exception" for the
/// script's global, with its muted errors flag. Step 2's error information is
/// the engine's, extracted where the script threw.
fn reportClassicScriptError(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
    const report: *const ClassicScriptReport = @ptrCast(@alignCast(host orelse return));
    const window = windowOfRealm(report.realm) orelse return;
    const extracted: runtime.ErrorInfo = .{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = if (info.error_value == .undefined) null else info.error_value,
    };
    _ = report_exception.reportErrorInfo(window, &extracted, .{ .muted = report.muted });
}

// =============================================================================
// Classic scripts' [[HostDefined]]
// =============================================================================

/// A classic script's [[HostDefined]] in a Window realm (engine protocol
/// R31): the `module_script.ClassicScript` an import() in the script names as
/// its referrer (`ImportReferrer.script`), whose base URL the specifier
/// resolves against (HostLoadImportedModule step 6).
///
/// HTML's classic script lives for as long as anything can still run it - a
/// function it defined can call import() at any time - which the spec leaves
/// to garbage collection. Crane keeps one record per base URL in the
/// document's module map, under "classic:<base URL>", so it has the owner and
/// the lifetime of the module scripts beside it (an inline module script is
/// in no spec map either): the document frees it, through
/// `disposeModuleMapEntry`. The engine keeps only the record's address, so
/// `classicScriptBaseUrlOf` checks it against the records still alive before
/// reading it; an import() from a function that outlived its document
/// resolves against the realm's document base URL instead. (A freed record's
/// address reused by a new one reads as the new one - a wrong base URL, never
/// freed memory - as `module_script.scriptOf` accepts for module scripts.)
const ClassicScriptRecord = struct {
    /// First, so the engine's pointer to it is the record's.
    script: module_script.ClassicScript,
    /// Links in `live_classic_scripts`.
    live_prev: ?*ClassicScriptRecord = null,
    live_next: ?*ClassicScriptRecord = null,

    fn destroy(self: *ClassicScriptRecord) void {
        if (self.live_prev) |prev| prev.live_next = self.live_next else live_classic_scripts = self.live_next;
        if (self.live_next) |next| next.live_prev = self.live_prev;
        std.heap.c_allocator.free(self.script.base_url);
        std.heap.c_allocator.destroy(self);
    }
};

/// Every ClassicScriptRecord that exists.
var live_classic_scripts: ?*ClassicScriptRecord = null;

const classic_script_key_prefix = "classic:";

/// `document`'s classic script record for `base_url`, made (with its own copy
/// of the URL) if it has none yet. Null when it cannot be made - the script
/// then runs with no [[HostDefined]], and an import() in it resolves against
/// the document's base URL.
fn classicScriptRecord(document: *runtime.Instance, base_url: []const u8) ?*ClassicScriptRecord {
    const allocator = std.heap.c_allocator;
    const map = documentModuleMap(document);
    const key = std.mem.concat(allocator, u8, &.{ classic_script_key_prefix, base_url }) catch return null;
    defer allocator.free(key);
    if (map.getFn(map.context, key)) |value| return @ptrCast(@alignCast(value));

    const record = allocator.create(ClassicScriptRecord) catch return null;
    record.* = .{ .script = .{ .base_url = allocator.dupe(u8, base_url) catch {
        allocator.destroy(record);
        return null;
    } } };
    record.live_next = live_classic_scripts;
    if (live_classic_scripts) |head| head.live_prev = record;
    live_classic_scripts = record;
    if (!map.putFn(map.context, key, record)) {
        record.destroy();
        return null;
    }
    return record;
}

/// The base URL of the classic script whose [[HostDefined]] `host_defined`
/// is, while its record exists.
fn classicScriptBaseUrlOf(host_defined: *anyopaque) ?[]const u8 {
    var it = live_classic_scripts;
    while (it) |record| : (it = record.live_next) {
        if (@as(*anyopaque, @ptrCast(&record.script)) == host_defined) return record.script.base_url;
    }
    return null;
}

/// The document's module map dispose function: its classic script records,
/// and its module scripts.
fn disposeModuleMapEntry(value: *anyopaque) void {
    var it = live_classic_scripts;
    while (it) |record| : (it = record.live_next) {
        if (@as(*anyopaque, @ptrCast(record)) == value) return record.destroy();
    }
    module_script.disposeEntry(value);
}

// =============================================================================
// SVG script elements
// =============================================================================

const xlink_namespace = "http://www.w3.org/1999/xlink";
const script_elements = @import("dom").script_elements;

/// `element`'s script element state - parser-inserted, already started - if
/// it is an SVG script element (SVGScriptElement keeps it; the hook reaches
/// it).
fn svgScriptState(element: *runtime.Instance) ?*script_elements.ScriptFlags {
    return script_elements.svgFlags(element);
}

/// Whether `element` is an SVG script element.
pub fn isSvgScriptElement(element: *runtime.Instance) bool {
    return svgScriptState(element) != null;
}

/// An SVG script became connected, or its children changed while connected:
/// HTML's post-connection and children-changed steps, which prepare a script
/// that is not parser-inserted.
pub fn svgScriptInsertionOrChildrenChanged(allocator: std.mem.Allocator, element: *runtime.Instance) void {
    const state = svgScriptState(element) orelse return;
    if (state.parser_inserted or state.already_started) return;
    if (!isConnected(element)) return;
    prepareSvgScriptElement(allocator, element, false);
}

/// "Process the SVG script element according to the SVG rules" - the parser's
/// end-tag step for an SVG script.
///
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-inforeign
/// ("An end tag whose tag name is "script", if the current node is an SVG
/// script element")
pub fn processSvgScriptElement(allocator: std.mem.Allocator, element: *runtime.Instance) void {
    prepareSvgScriptElement(allocator, element, true);
}

/// "Prepare the script element" for an SVG script.
///
/// SVG 2 §15.2: "A script element is equivalent to the script element in
/// HTML", so this is HTML's algorithm with SVG's differences - Blink runs its
/// SVGScriptElement through the same ScriptLoader as HTMLScriptElement. Its URL
/// is its `href`, or the deprecated `xlink:href`, never `src`; and it has no
/// async or defer. So an external script the parser meets is fetched and run
/// at its end tag, as a parser-blocking HTML script is; one inserted by script
/// is fetched at insertion and run from a task, as a force-async HTML script
/// is.
///
/// Deviation, stated: type="module" is not supported for SVG.
fn prepareSvgScriptElement(allocator: std.mem.Allocator, element: *runtime.Instance, from_parser_end_tag: bool) void {
    const state = svgScriptState(element) orelse return;
    // Step 1.
    if (state.already_started) return;
    // Steps 2-3: the parser document is let go of; step 14 restores it.
    const parser_inserted = state.parser_inserted or from_parser_end_tag;
    state.parser_inserted = false;

    const href = getAttributeNS(element, null, "href") orelse getAttributeNS(element, xlink_namespace, "href");

    // Step 5: child text content. Step 6: no href and no source - return
    // before "already started", so text added later runs it.
    const source = getChildTextContent(allocator, element) catch return;
    defer if (source.len > 0) allocator.free(source);
    if (href == null and source.len == 0) return;

    // Step 7.
    if (!isConnected(element)) return;

    // Steps 8-13: the type. A JavaScript MIME type, or none, is classic.
    if (determineScriptType(element) != .classic) return;

    // Step 14.
    if (parser_inserted) state.parser_inserted = true;
    // Step 15.
    state.already_started = true;

    // Step 18.
    const document = getNodeDocument(element) orelse return;
    if (!scriptingEnabled(document)) return;

    if (href) |raw| {
        // Step 33.3: an empty URL queues an element task to fire error at the
        // element - and fetches nothing: resolved, "" is the document's own
        // URL, which ran the page as script (execution-timing/137).
        if (raw.len == 0) return queueErrorEventTask(element);
        // Step 33.5: the URL, relative to the document base URL. Step 33.6:
        // failure queues the error event too.
        const base_url = documentBaseUrlAlloc(allocator, document, element) orelse return;
        defer allocator.free(base_url);
        const url = parseUrl(element, raw, base_url) orelse return queueErrorEventTask(element);
        defer element.ctx.allocator.free(url);

        var fetched = fetchExternalScript(allocator, url);
        defer fetched.deinit(allocator);
        if (from_parser_end_tag) {
            // A parser-blocking script, whose result is in hand: run it now.
            const body = fetched.body orelse return fireErrorEvent(allocator, element);
            runSvgScriptSource(document, element, body, url, url);
            fireLoadEvent(allocator, element);
        } else {
            // A script-inserted one runs from a task, as step 35's force-async
            // HTML scripts do.
            queueSvgScriptRun(element, fetched.body, url);
        }
        return;
    }

    // Step 36.3: an inline script runs immediately, with the document base URL
    // (step 34.1) as its base URL and the document's URL as its resource name.
    const base_url = documentBaseUrlAlloc(allocator, document, element) orelse return;
    defer allocator.free(base_url);
    runSvgScriptSource(document, element, source, documentUrl(document, element), base_url);
}

/// A script-inserted external SVG script's run, queued: the element as
/// (address, slab generation), the fetched source (owned), and its URL.
const QueuedSvgScript = struct {
    element: *runtime.Instance,
    generation: u64,
    /// Null for a failed fetch: the task fires error.
    source: ?[]u8,
    url: []u8,

    fn destroy(self: *QueuedSvgScript) void {
        if (self.source) |b| std.heap.c_allocator.free(b);
        std.heap.c_allocator.free(self.url);
        std.heap.c_allocator.destroy(self);
    }
};

fn queueSvgScriptRun(element: *runtime.Instance, body: ?[]const u8, url: []const u8) void {
    const loop = element.ctx.getOptionalEventLoop() orelse return;
    const task = std.heap.c_allocator.create(QueuedSvgScript) catch return;
    task.* = .{
        .element = element,
        .generation = runtime.SlabAllocator.generationOf(element),
        .source = if (body) |b| std.heap.c_allocator.dupe(u8, b) catch null else null,
        .url = std.heap.c_allocator.dupe(u8, url) catch {
            std.heap.c_allocator.destroy(task);
            return;
        },
    };
    loop.queueTask(.{ .callback = &runQueuedSvgScript, .context = task, .drop = &dropQueuedSvgScript });
}

fn dropQueuedSvgScript(data: ?*anyopaque) void {
    const task: *QueuedSvgScript = @ptrCast(@alignCast(data orelse return));
    task.destroy();
}

fn runQueuedSvgScript(data: ?*anyopaque) void {
    const task: *QueuedSvgScript = @ptrCast(@alignCast(data orelse return));
    defer task.destroy();
    // The element was collected and its slot reissued: nobody is left to run.
    if (runtime.SlabAllocator.generationOf(task.element) != task.generation) return;
    const document = getNodeDocument(task.element) orelse return;
    const allocator = task.element.ctx.allocator;
    const source = task.source orelse return fireErrorEvent(allocator, task.element);
    runSvgScriptSource(document, task.element, source, task.url, task.url);
    fireLoadEvent(allocator, task.element);
}

/// Set `document`'s currentScript to `script`, returning what it was.
fn swapCurrentScript(document: *runtime.Instance, script: ?*runtime.Instance) ?*runtime.Instance {
    const old = doc_state.getCurrentScript(document);
    doc_state.setCurrentScript(document, script);
    return old;
}

/// "Scripting is enabled" for `document`.
fn scriptingEnabled(document: *runtime.Instance) bool {
    return doc_state.isScriptingEnabled(document);
}

/// Run `source` as a classic script for an SVG script element, with `url` as
/// its resource name and `base_url` as its base URL: currentScript is the
/// element while it runs (it is an HTMLOrSVGScriptElement), and clean-up's
/// microtask checkpoint follows, as for an HTML script.
fn runSvgScriptSource(document: *runtime.Instance, element: *runtime.Instance, source: []const u8, url: []const u8, base_url: []const u8) void {
    const old_current_script = swapCurrentScript(document, element);
    defer _ = swapCurrentScript(document, old_current_script);
    runClassicScriptText(element, document, source, url, base_url, false);
}

// =============================================================================
// Module scripts
// =============================================================================

/// The document's module map, as `module_script` sees it.
///
/// The map lives in the Document's internal state and dies with it: the first
/// store installs `module_script.disposeEntry` as the document's module
/// dispose function, which is the only thing that frees a module script. Keys
/// are "<type>:<url>" for fetched scripts and "inline:<n>" for inline ones -
/// an inline module script is in no spec map, but keeping it here gives it the
/// same owner and the same lifetime as everything it imports.
fn documentModuleMap(document: *runtime.Instance) module_script.ModuleMap {
    return .{
        .context = document,
        .getFn = &documentModuleMapGet,
        .putFn = &documentModuleMapPut,
    };
}

fn documentModuleMapGet(context: *anyopaque, key: []const u8) ?*anyopaque {
    const document: *runtime.Instance = @ptrCast(@alignCast(context));
    return doc_state.getModule(document, key);
}

fn documentModuleMapPut(context: *anyopaque, key: []const u8, value: *anyopaque) bool {
    const document: *runtime.Instance = @ptrCast(@alignCast(context));
    doc_state.setModuleDisposeFunction(document, &disposeModuleMapEntry);
    doc_state.setModule(document, key, value) catch return false;
    return true;
}

fn documentResolveImport(context: *anyopaque, specifier: []const u8, base_url: []const u8) ?[]const u8 {
    const document: *runtime.Instance = @ptrCast(@alignCast(context));
    return doc_state.resolveImportSpecifier(document, specifier, base_url);
}

/// Distinguishes the map keys of inline module scripts. Process-wide, so a key
/// is never reused, even across documents.
var next_inline_module_id: u64 = 0;

/// The module loading environment for a script element's node document.
fn moduleEnvironment(script_element: *runtime.Instance, document: *runtime.Instance) ?module_script.Environment {
    const internal = doc_state.getInternal(document) orelse return null;
    return .{
        .allocator = internal.allocator,
        .context_instance = script_element,
        .map = documentModuleMap(document),
        .resolveImportFn = &documentResolveImport,
    };
}

/// The module loading environment for a Window's document.
fn moduleEnvironmentForWindow(window: *runtime.Instance, document: *runtime.Instance) ?module_script.Environment {
    const internal = doc_state.getInternal(document) orelse return null;
    return .{
        .allocator = internal.allocator,
        .context_instance = window,
        .map = documentModuleMap(document),
        .resolveImportFn = &documentResolveImport,
    };
}

/// The principal realm of `realm` (HTML's ShadowRealm integration): `realm`
/// itself, unless it is a ShadowRealm's - then the realm that created it,
/// followed through ShadowRealms made inside ShadowRealms. Its settings
/// supply a ShadowRealm's API base URL, origin and fetch client.
///
/// Spec: https://github.com/whatwg/html/pull/9893 ("principal realm")
fn principalRealm(realm: runtime.Context) runtime.Context {
    var principal = realm;
    while (principal.principal_realm) |creator| principal = creator;
    return principal;
}

/// The module loading environment for an import() in `realm`, whose
/// principal realm's global is `window`: the Window's document's - or, for a
/// ShadowRealm, its synthetic realm settings object's: a module map of its
/// own (`shadow_realm_map`, which the caller keeps for as long as it uses the
/// environment), no import map, and module records made in the ShadowRealm,
/// while URLs parse against the principal Window.
fn importEnvironment(
    realm: runtime.Context,
    window: *runtime.Instance,
    document: *runtime.Instance,
    shadow_realm_map: *ShadowRealmModuleMap,
) ?module_script.Environment {
    var env = moduleEnvironmentForWindow(window, document) orelse return null;
    if (principalRealm(realm) == realm) return env;
    shadow_realm_map.* = .{ .document = document, .realm = realm };
    env.map = shadow_realm_map.moduleMap();
    env.resolveImportFn = null;
    env.realm_override = realm;
    return env;
}

/// A ShadowRealm's module map. Its entries live in the principal document's
/// module map, under keys that name the ShadowRealm's realm: the document
/// frees them with its own module scripts (a ShadowRealm cannot outlive its
/// principal Window's document in any way that could still import), and no
/// two realms share a module record.
const ShadowRealmModuleMap = struct {
    document: *runtime.Instance,
    realm: runtime.Context,

    fn moduleMap(self: *ShadowRealmModuleMap) module_script.ModuleMap {
        return .{ .context = self, .getFn = &get, .putFn = &put };
    }

    fn realmKey(self: *const ShadowRealmModuleMap, key: []const u8) ?[]u8 {
        return std.fmt.allocPrint(std.heap.c_allocator, "shadowrealm:{x}:{s}", .{ @intFromPtr(self.realm), key }) catch null;
    }

    fn get(context: *anyopaque, key: []const u8) ?*anyopaque {
        const self: *ShadowRealmModuleMap = @ptrCast(@alignCast(context));
        const realm_key = self.realmKey(key) orelse return null;
        defer std.heap.c_allocator.free(realm_key);
        return documentModuleMapGet(self.document, realm_key);
    }

    fn put(context: *anyopaque, key: []const u8, value: *anyopaque) bool {
        const self: *ShadowRealmModuleMap = @ptrCast(@alignCast(context));
        const realm_key = self.realmKey(key) orelse return false;
        defer std.heap.c_allocator.free(realm_key);
        return documentModuleMapPut(self.document, realm_key, value);
    }
};

/// The Window whose realm `realm` is - its settings object's global object -
/// or null for a realm whose global is not a Window.
fn windowOfRealm(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    if (global.stateAs(interfaces.Window.State) == null) return null;
    return global;
}

/// HTML "report an exception" `value` (BORROWED) for the global of `realm`.
fn reportModuleException(realm: runtime.Context, value: runtime.JSValue) void {
    const window = windowOfRealm(realm) orelse return;
    const allocator = window.ctx.allocator;
    // Step 2: extract error information.
    const info = engine.extractErrorInformation(realm, value, allocator) catch return;
    defer allocator.free(info.message);
    defer allocator.free(info.filename);
    const extracted: runtime.ErrorInfo = .{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = info.error_value,
    };
    _ = report_exception.reportErrorInfo(window, &extracted, .{});
}

// =============================================================================
// import() - HostLoadImportedModule for a dynamic import
// =============================================================================

/// The engine's module hooks for a Window agent: HostLoadImportedModule for
/// import(), finished with engine.finishDynamicImport, and
/// HostGetImportMetaProperties. The agent's creator installs them
/// (AgentOptions.hooks), beside rejected_promises.hooks.
pub const module_hooks: engine.HostHooks = .{
    .loadImportedModule = if (module_script.supported) loadImportedModule else null,
    .importMetaUrl = if (module_script.supported) module_script.importMetaUrl else null,
};

/// FinishLoadingImportedModule for an import(): ends the host's hold on
/// `request`. (Only an engine with modules makes one.)
fn finishImport(request: *engine.ImportRequest, outcome: engine.DynamicImportOutcome) void {
    if (module_script.supported) engine.finishDynamicImport(request, outcome);
}

/// What an import()'s specifier resolves against: the referencing script's
/// base URL, or - with none - the settings object's API base URL, the
/// document's base URL as it is now.
const ImportBase = union(enum) {
    /// BORROWED for the call.
    url: []const u8,
    document,
};

/// HTML HostLoadImportedModule(referrer, moduleRequest, loadState: undefined,
/// payload) for an import() - `HostHooks.loadImportedModule`.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#hostloadimportedmodule
fn loadImportedModule(
    host: ?*anyopaque,
    realm: runtime.Context,
    referrer: engine.ImportReferrer,
    specifier: []const u8,
    type_attribute: ?[]const u8,
    request: *engine.ImportRequest,
) void {
    _ = host;
    // Steps 1-6: the settings object is the current one, unless the referrer
    // is a Script or Module Record: then referencingScript is its
    // [[HostDefined]], whose base URL the specifier resolves against. An event
    // handler's, eval's or a timer string's [[ScriptOrModule]] is null.
    const base: ImportBase = switch (referrer) {
        .module => |host_defined| if (module_script.scriptOf(host_defined)) |script| .{ .url = script.base_url } else .document,
        .script => |host_defined| if (classicScriptBaseUrlOf(host_defined)) |url| .{ .url = url } else .document,
        .realm => .document,
    };
    loadImport(realm, base, specifier, type_attribute, request);
}

/// HostLoadImportedModule from step 7 on, for the request of an import() in
/// `realm`: every path finishes `request` (engine.finishDynamicImport).
fn loadImport(realm: runtime.Context, base: ImportBase, specifier: []const u8, type_attribute: ?[]const u8, request: *engine.ImportRequest) void {
    // The settings object's global: a Window - for a ShadowRealm, its
    // principal realm's (its synthetic realm settings object's API base URL
    // and fetch client are that realm's).
    const window = windowOfRealm(principalRealm(realm)) orelse return finishImportWithTypeError(realm, request, "import() is not supported here");
    const document = interfaces.Window.get_document(window) catch
        return finishImportWithTypeError(realm, request, "import() has no document to load for");
    var shadow_realm_map: ShadowRealmModuleMap = undefined;
    const env = importEnvironment(realm, window, document, &shadow_realm_map) orelse
        return finishImportWithTypeError(realm, request, "import() has no document to load for");

    // Steps 7.1.4-7.1.5 (for the one request an import() makes): an
    // unsupported type is a TypeError.
    const module_type = module_script.moduleTypeFromAttribute(type_attribute) orelse
        return finishImportWithTypeError(realm, request, "Unsupported module type");

    // Steps 8-9: resolve a module specifier against the referrer's base URL,
    // or reject with its TypeError.
    const document_base = switch (base) {
        .url => null,
        .document => documentBaseUrlAlloc(window.ctx.allocator, document, window),
    };
    defer if (document_base) |b| window.ctx.allocator.free(b);
    const base_url = switch (base) {
        .url => |url| url,
        .document => document_base orelse "",
    };
    const url = module_script.resolve(&env, specifier, base_url) orelse
        return finishImportWithTypeError(realm, request, "Failed to resolve module specifier");
    defer window.ctx.allocator.free(url);

    // Step 14: fetch - as a task, so the imported module is fetched and
    // evaluated after the script that called import() and its microtasks,
    // the way a real network fetch completes.
    const loop = window.ctx.getOptionalEventLoop() orelse
        return finishImportWithTypeError(realm, request, "No event loop to load the module on");
    const task = std.heap.c_allocator.create(DynamicImportTask) catch
        return finishImportWithTypeError(realm, request, "Out of memory");
    task.* = .{
        .realm = realm,
        .window = window,
        .generation = runtime.SlabAllocator.generationOf(window),
        .url = std.heap.c_allocator.dupe(u8, url) catch {
            std.heap.c_allocator.destroy(task);
            return finishImportWithTypeError(realm, request, "Out of memory");
        },
        .module_type = module_type,
        .request = request,
    };
    loop.queueTask(.{ .callback = &runDynamicImport, .context = task });
}

/// FinishLoadingImportedModule with ThrowCompletion(a new TypeError).
fn finishImportWithTypeError(realm: runtime.Context, request: *engine.ImportRequest, message: []const u8) void {
    const exception = engine.createSimpleException(realm, .TypeError, message) catch
        return finishImport(request, .{ .failure = runtime.JSValue.jsUndefined });
    defer exception.release();
    finishImport(request, .{ .failure = exception.value });
}

const DynamicImportTask = struct {
    /// The realm import() was called in: the module records are made, and
    /// the task runs, in it.
    realm: runtime.Context,
    /// The importing Window - the principal realm's, for a ShadowRealm - as
    /// (address, slab generation).
    window: *runtime.Instance,
    generation: u64,
    /// Owned (c_allocator).
    url: []const u8,
    module_type: module_script.ModuleType,
    /// The host's until finished.
    request: *engine.ImportRequest,
};

fn runDynamicImport(data: ?*anyopaque) void {
    const task: *DynamicImportTask = @ptrCast(@alignCast(data orelse return));
    defer {
        std.heap.c_allocator.free(task.url);
        std.heap.c_allocator.destroy(task);
    }

    // The importing Window is gone: finish the request anyway, to release
    // what it holds; nobody is left to observe how.
    if (runtime.SlabAllocator.generationOf(task.window) != task.generation)
        return finishImport(task.request, .{ .failure = runtime.JSValue.jsUndefined });

    engine.runTaskInRealm(task.realm, dynamicImportSteps, task) catch
        finishImport(task.request, .{ .failure = runtime.JSValue.jsUndefined });
}

/// The fetch task: fetch a single imported module script and its
/// descendants, link, then FinishLoadingImportedModule - ContinueDynamicImport
/// (evaluate, and settle with the namespace or the reason) is the engine's.
fn dynamicImportSteps(data: ?*anyopaque) void {
    const task: *DynamicImportTask = @ptrCast(@alignCast(data.?));
    const realm = task.realm;
    const document = interfaces.Window.get_document(task.window) catch
        return finishImportWithTypeError(realm, task.request, "import() has no document to load for");
    var shadow_realm_map: ShadowRealmModuleMap = undefined;
    const env = importEnvironment(realm, task.window, document, &shadow_realm_map) orelse
        return finishImportWithTypeError(realm, task.request, "import() has no document to load for");

    // A null graph is a failed fetch: TypeError.
    const graph = module_script.fetchImportedModuleScriptGraph(&env, task.url, task.module_type) orelse
        return finishImportWithTypeError(realm, task.request, "Failed to fetch dynamically imported module");

    // A graph that could not be loaded or linked rejects with its error to
    // rethrow; else the engine continues with its record.
    if (graph.error_to_rethrow) |reason| return finishImport(task.request, .{ .failure = reason.value });
    const record = graph.record orelse
        return finishImportWithTypeError(realm, task.request, "Failed to load dynamically imported module");
    finishImport(task.request, .{ .module = record });
}

// =============================================================================
// Module script elements
// =============================================================================

/// Prepare step 33.11 "module": fetch an external module script graph, and
/// mark the element ready with the result.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#fetch-a-module-script-tree
fn prepareExternalModuleScript(script_element: *runtime.Instance, document: *runtime.Instance, url: []const u8) void {
    var result: HTMLScriptElementImpl.ScriptResult = .null;
    defer HTMLScriptElementImpl.setResult(script_element, result);

    const env = moduleEnvironment(script_element, document) orelse return;
    // Module loading parses, links and makes errors in the document's realm:
    // each engine operation enters it.
    const graph = module_script.fetchExternalModuleScriptGraph(&env, url) orelse return;
    result = moduleResult(graph);
}

/// Prepare step 34 "module": fetch an inline module script graph.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#fetch-an-inline-module-script-graph
fn prepareInlineModuleScript(script_element: *runtime.Instance, document: *runtime.Instance, source: []const u8, base_url: []const u8) void {
    var result: HTMLScriptElementImpl.ScriptResult = .null;
    defer HTMLScriptElementImpl.setResult(script_element, result);

    const env = moduleEnvironment(script_element, document) orelse return;

    // Step 1: create a JavaScript module script - a parse error is kept on it.
    // (Where the engine has no modules there is none: the result stays null.)
    const script = module_script.createJavaScriptModuleScript(&env, source, base_url) catch return;

    // Owned by the document from here on, like every fetched module script.
    var key_buf: [32]u8 = undefined;
    const key = std.fmt.bufPrint(&key_buf, "inline:{d}", .{next_inline_module_id}) catch unreachable;
    next_inline_module_id += 1;
    if (!env.map.putFn(env.map.context, key, @ptrCast(script))) {
        script.destroy();
        return;
    }

    // Step 2: fetch the descendants of and link it.
    const graph = module_script.fetchDescendantsAndLink(&env, script) orelse return;
    result = moduleResult(graph);
}

/// A script element result holding a module script. The loader's script rides
/// in `module_record`; `source_text` and `base_url` are unused on this path,
/// and left empty rather than pointing at memory prepare is about to free.
fn moduleResult(script: *module_script.ModuleScript) HTMLScriptElementImpl.ScriptResult {
    var result = ModuleScript.init("", "");
    result.module_record = script;
    return .{ .module_script = result };
}

/// Execute step 6 "module": run the module script given by el's result.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#run-a-module-script
fn runModuleScript(script_element: *runtime.Instance, document: *runtime.Instance) void {
    const script: *module_script.ModuleScript = switch (HTMLScriptElementImpl.getResult(script_element)) {
        .module_script => |m| @ptrCast(@alignCast(m.module_record orelse return)),
        else => return,
    };
    const env = moduleEnvironment(script_element, document) orelse return;
    const realm = env.realm();

    // Step 5: prepare to run script given settings.
    const scope = engine.prepareToRunScript(realm) catch return;
    // Step 9: clean up after running script - after the report, so it comes
    // before the microtask checkpoint, as a classic script's does.
    defer engine.cleanUpAfterRunningScript(scope);

    // Steps 6-8.
    switch (module_script.run(&env, script)) {
        .ok => {},
        // Step 8: report the exception for the script's global.
        .report => |exception| {
            defer exception.release();
            reportModuleException(realm, exception.value);
        },
        // Step 8 "upon rejection" of a promise still waiting on top-level
        // await: react to it, and report the reason if it rejects.
        .pending => |promise| {
            defer promise.release();
            reportModuleRejectionLater(realm, promise.value);
        },
    }
}

/// A top-level-await evaluation promise's reaction data. The Window is held
/// as (address, slab generation): the reaction runs whenever the promise
/// settles, and the slab reuses a freed Window's slot.
const PendingModuleEvaluation = struct {
    realm: runtime.Context,
    global: *runtime.Instance,
    generation: u64,

    const steps: engine.PromiseReactionSteps = .{
        .fulfilled = settled,
        .rejected = rejected,
    };

    fn settled(data: ?*anyopaque, _: runtime.JSValue) void {
        const pending: *PendingModuleEvaluation = @ptrCast(@alignCast(data orelse return));
        std.heap.c_allocator.destroy(pending);
    }

    fn rejected(data: ?*anyopaque, reason: runtime.JSValue) void {
        const pending: *PendingModuleEvaluation = @ptrCast(@alignCast(data orelse return));
        defer std.heap.c_allocator.destroy(pending);
        if (runtime.SlabAllocator.generationOf(pending.global) != pending.generation) return;
        reportModuleException(pending.realm, reason);
    }
};

fn reportModuleRejectionLater(realm: runtime.Context, promise: runtime.JSValue) void {
    const global = windowOfRealm(realm) orelse return;
    const pending = std.heap.c_allocator.create(PendingModuleEvaluation) catch return;
    pending.* = .{ .realm = realm, .global = global, .generation = runtime.SlabAllocator.generationOf(global) };
    engine.reactToPromise(realm, promise, &PendingModuleEvaluation.steps, pending) catch {
        std.heap.c_allocator.destroy(pending);
    };
}

/// Check if a specifier looks like a URL (starts with /, ./, ../, or has a scheme)
fn isUrlLikeSpecifier(specifier: []const u8) bool {
    if (specifier.len == 0) return false;

    // Starts with /
    if (specifier[0] == '/') return true;

    // Starts with ./ or ../
    if (specifier.len >= 2 and specifier[0] == '.') {
        if (specifier[1] == '/') return true;
        if (specifier.len >= 3 and specifier[1] == '.' and specifier[2] == '/') return true;
    }

    // Has a scheme (e.g., https://, http://)
    if (std.mem.indexOf(u8, specifier, "://") != null) return true;

    return false;
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Check if element has async attribute
fn hasAsyncAttribute(element: *runtime.Instance) bool {
    return hasAttribute(element, "async");
}

/// Check if element has defer attribute
fn hasDeferAttribute(element: *runtime.Instance) bool {
    return hasAttribute(element, "defer");
}

/// Check if element has src attribute
fn hasSrcAttribute(element: *runtime.Instance) bool {
    return hasAttribute(element, "src");
}

/// Get src attribute value
fn getSrcAttribute(element: *runtime.Instance) []const u8 {
    return getAttribute(element, "src") orelse "";
}

/// Check if element has nomodule attribute
fn hasNoModuleAttribute(element: *runtime.Instance) bool {
    return hasAttribute(element, "nomodule");
}

/// Get nonce attribute value
/// Spec: https://html.spec.whatwg.org/multipage/urls-and-fetching.html#attr-nonce
fn getNonceAttribute(element: *runtime.Instance) []const u8 {
    return getAttribute(element, "nonce") orelse "";
}

/// Check if element has event attribute (obsolete)
fn hasEventAttribute(element: *runtime.Instance) bool {
    return hasAttribute(element, "event");
}

/// Get event attribute value
fn getEventAttribute(element: *runtime.Instance) []const u8 {
    return getAttribute(element, "event") orelse "";
}

/// Check if element has for attribute (obsolete)
fn hasForAttribute(element: *runtime.Instance) bool {
    return hasAttribute(element, "for");
}

/// Get for attribute value
fn getForAttribute(element: *runtime.Instance) []const u8 {
    return getAttribute(element, "for") orelse "";
}

/// Generic attribute check
fn hasAttribute(element: *runtime.Instance, name: []const u8) bool {
    return getAttributeNS(element, null, name) != null;
}

/// Generic attribute getter, for an attribute in no namespace.
fn getAttribute(element: *runtime.Instance, name: []const u8) ?[]const u8 {
    return getAttributeNS(element, null, name);
}

/// The value of `element`'s attribute with this namespace and local name.
/// Borrowed from the element's attribute list: valid until it changes.
fn getAttributeNS(element: *runtime.Instance, namespace: ?[]const u8, name: []const u8) ?[]const u8 {
    if (ElementImpl.getInternal(element)) |internal| {
        if (internal.findAttribute(namespace, name)) |attr| {
            return attr.value;
        }
    }
    return null;
}

/// Get the type attribute value
fn getTypeAttribute(element: *runtime.Instance) []const u8 {
    return getAttribute(element, "type") orelse "";
}

/// Get the language attribute value (obsolete)
fn getLanguageAttribute(element: *runtime.Instance) []const u8 {
    return getAttribute(element, "language") orelse "";
}

/// Determine script type from type attribute
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#prepare-the-script-element (steps 8-13)
fn determineScriptType(element: *runtime.Instance) ScriptType {
    const type_attr = getTypeAttribute(element);
    const lang_attr = getLanguageAttribute(element);

    // Step 8: Determine the script block's type string
    var type_string: []const u8 = undefined;

    if (type_attr.len == 0) {
        // type attribute is empty or missing
        if (lang_attr.len == 0) {
            // No type, no language -> default to text/javascript
            type_string = "text/javascript";
        } else {
            // Has language attribute -> "text/" + language
            // For simplicity, we'll handle common cases
            if (std.ascii.eqlIgnoreCase(lang_attr, "javascript")) {
                type_string = "text/javascript";
            } else {
                // Unknown language type
                return .null;
            }
        }
    } else {
        // Use type attribute value, stripped of whitespace
        type_string = std.mem.trim(u8, type_attr, " \t\n\r\x0c");
    }

    // Step 9: If type string is a JavaScript MIME type essence match -> classic
    if (isJavaScriptMimeType(type_string)) {
        return .classic;
    }

    // Step 10: If type string is "module" (case-insensitive) -> module
    if (std.ascii.eqlIgnoreCase(type_string, "module")) {
        return .module;
    }

    // Step 11: If type string is "importmap" (case-insensitive) -> importmap
    if (std.ascii.eqlIgnoreCase(type_string, "importmap")) {
        return .importmap;
    }

    // Step 12: If type string is "speculationrules" (case-insensitive) -> speculationrules
    if (std.ascii.eqlIgnoreCase(type_string, "speculationrules")) {
        return .speculationrules;
    }

    // Step 13: Otherwise, no script is executed
    return .null;
}

/// Check if a MIME type is a JavaScript MIME type essence match
/// Spec: https://mimesniff.spec.whatwg.org/#javascript-mime-type
fn isJavaScriptMimeType(mime_type: []const u8) bool {
    // Lowercase the input into a stack buffer
    var buffer: [64]u8 = undefined;
    const len = @min(mime_type.len, 64);
    const lower = std.ascii.lowerString(buffer[0..len], mime_type[0..len]);

    // JavaScript MIME type essence matches
    const js_types = [_][]const u8{
        "application/ecmascript",
        "application/javascript",
        "application/x-ecmascript",
        "application/x-javascript",
        "text/ecmascript",
        "text/javascript",
        "text/javascript1.0",
        "text/javascript1.1",
        "text/javascript1.2",
        "text/javascript1.3",
        "text/javascript1.4",
        "text/javascript1.5",
        "text/jscript",
        "text/livescript",
        "text/x-ecmascript",
        "text/x-javascript",
    };

    for (js_types) |js_type| {
        if (std.mem.startsWith(u8, lower, js_type)) {
            // Check for exact match or parameters (;)
            if (lower.len == js_type.len or
                (lower.len > js_type.len and lower[js_type.len] == ';'))
            {
                return true;
            }
        }
    }

    return false;
}

/// DOM "connected": the element's shadow-including root is a document.
///
/// Spec: https://dom.spec.whatwg.org/#connected
/// Not "has a node document" - every node has one. Reading it that way let
/// "prepare the script element" step 7 go on for a script in a detached tree:
/// the HTML fragment parser prepared each script it converted into its
/// DocumentFragment, which set it running when the fragment was inserted.
fn isConnected(element: *runtime.Instance) bool {
    return interfaces.Node.get_isConnected(element) catch false;
}

/// Get the node's owner document
fn getNodeDocument(node: *runtime.Instance) ?*runtime.Instance {
    const internal_state = NodeImpl.getInternalState(node);
    if (internal_state) |internal| {
        return internal.owner_document;
    }
    return null;
}

/// The document's URL, for the realm `script_element` is in: an inline
/// classic script's resource name - the filename its errors report - and the
/// URL a string timer handler is compiled with.
///
/// `Document`'s `base_uri` field is written by nothing in the tree - it is
/// initialised to "" in `InternalState.init` and never assigned - and
/// `internal.url` may still read "about:blank". The URL the document was
/// actually fetched from lives on its realm (`runtime.Context.documentUrl`),
/// put there by `setDocumentUrl` during navigation. Reading `base_uri` alone
/// made every relative `src` on a dynamically-inserted script resolve to
/// itself, so the fetch went to a bare path with no origin and failed; an
/// absolute URL in the same position worked, which is what isolated it.
///
/// Not the document BASE URL: that honours `<base>` (`documentBaseUrlAlloc`).
fn documentUrl(document: ?*runtime.Instance, script_element: *runtime.Instance) []const u8 {
    if (document) |doc| {
        if (doc_state.getInternal(doc)) |internal| {
            if (internal.base_uri.len > 0) return internal.base_uri;
            if (internal.url.len > 0 and !std.mem.eql(u8, internal.url, "about:blank")) {
                return internal.url;
            }
        }
    }

    // The URL the element's realm records for its document.
    return script_element.ctx.documentUrl() orelse "";
}

/// The document base URL, as a copy owned by `allocator`, or null when it
/// cannot be copied.
///
/// Spec: https://html.spec.whatwg.org/multipage/urls-and-fetching.html#document-base-url
/// "1. If there is no base element that has an href attribute in the
///  Document, then return the Document's fallback base URL.
///  2. Otherwise, return the frozen base URL of the first base element in the
///  Document that has an href attribute, in tree order."
///
/// `Node.baseURI` is that algorithm. A script's `src` resolves against it
/// (prepare step 33.5), and so does everything an inline script's base URL
/// feeds: an inline module's imports, an import map's addresses. Resolving
/// against the document's own URL instead sent a frame's
/// `<base href="../"><script src="resources/x.js">` to the wrong directory
/// (module/dynamic-import/v8-code-cache.html).
///
/// An `about:` URL has no path to resolve against - an about:blank or
/// about:srcdoc document's fallback base URL is its creator's, which
/// `Node.baseURI` does not model - so for one of those it answers what
/// `documentUrl` does, as it did before.
fn documentBaseUrlAlloc(allocator: std.mem.Allocator, document: ?*runtime.Instance, script_element: *runtime.Instance) ?[]const u8 {
    if (document) |doc| {
        if (interfaces.Node.get_baseURI(doc)) |base| {
            defer doc.ctx.allocator.free(base);
            if (base.len > 0 and !std.ascii.startsWithIgnoreCase(base, "about:")) {
                return allocator.dupe(u8, base) catch null;
            }
        } else |_| {}
    }
    return allocator.dupe(u8, documentUrl(document, script_element)) catch null;
}

/// Parse `input` against `base` with the URL Standard's parser and return the
/// serialized result, or null on failure.
///
/// Spec: https://html.spec.whatwg.org/multipage/urls-and-fetching.html#encoding-parsing-a-url
/// For a UTF-8 document "encoding-parsing a URL" is the URL parser with the
/// document base URL, which is what `URL.parse(input, base)` runs.
///
/// Goes through the URL interface because html cannot reach the URL module's
/// parser directly (and the impls boundary rules out the impl). The temporary
/// URL object is never exposed to script, so nothing wraps it and nothing else
/// will free it - `runtime.Instance.deinit` releases its state and its slab
/// slot here.
///
/// The returned slice is owned by `context_instance.ctx.allocator`.
pub fn parseUrl(context_instance: *runtime.Instance, input: []const u8, base: []const u8) ?[]const u8 {
    const base_arg = if (base.len > 0)
        webidl.Opt(runtime.USVString).passed(base)
    else
        webidl.Opt(runtime.USVString).notPassed();
    const url_instance = (interfaces.URL.call_static_parse(context_instance, input, base_arg) catch
        return null) orelse return null;
    defer runtime.Instance.deinit(url_instance);
    return interfaces.URL.get_href(url_instance) catch null;
}

/// "Queue an element task on the DOM manipulation task source given el to fire
/// an event named error at el."
///
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#prepare-the-script-element
/// (steps 33.1, 33.3 and 33.6)
///
/// Queued, not fired, and the difference is observable: fetch-src/empty.html
/// asserts the event arrives after `appendChild` has returned. Before this the
/// three cases returned without firing anything at all, so a page waiting on
/// the element's error event waited out the harness timeout.
fn queueErrorEventTask(script_element: *runtime.Instance) void {
    const ctx = script_element.ctx;
    const loop = ctx.getOptionalEventLoop() orelse {
        // No event loop to queue on (a context built for tests): the event is
        // still owed, so fire it now rather than lose it.
        fireErrorEvent(ctx.allocator, script_element);
        return;
    };

    const task = ctx.allocator.create(QueuedElementEvent) catch {
        fireErrorEvent(ctx.allocator, script_element);
        return;
    };
    task.* = .{
        .element = script_element,
        .generation = runtime.SlabAllocator.generationOf(script_element),
        .allocator = ctx.allocator,
    };
    loop.queueTask(.{ .callback = &runQueuedErrorEvent, .context = task });
}

/// What a queued element task needs to find its element again.
///
/// The element is held as (address, slab generation), never as a bare
/// pointer: nothing keeps the element alive between queueing and running, and
/// the slab REUSES a freed Instance's address. A task that compared only the
/// address would fire at whatever element took the slot over.
const QueuedElementEvent = struct {
    element: *runtime.Instance,
    generation: u64,
    allocator: std.mem.Allocator,
};

fn runQueuedErrorEvent(data: ?*anyopaque) void {
    const task: *QueuedElementEvent = @ptrCast(@alignCast(data orelse return));
    defer task.allocator.destroy(task);

    // The element was collected and its slot reissued: nobody is left to hear it.
    if (runtime.SlabAllocator.generationOf(task.element) != task.generation) return;

    // An element task: it runs in the element's realm. An error means the
    // realm is gone, and nobody is left to hear the event.
    engine.runTaskInRealm(task.element.ctx, errorEventSteps, task) catch return;
}

fn errorEventSteps(data: ?*anyopaque) void {
    const task: *QueuedElementEvent = @ptrCast(@alignCast(data.?));
    fireErrorEvent(task.allocator, task.element);
}

/// The element's child text content.
///
/// Spec: https://dom.spec.whatwg.org/#concept-child-text-content
/// "The child text content of a node node is the concatenation of the data of
///  all the Text node children of node, in tree order."
///
/// CHILDREN, not descendants: "prepare the script element" step 5 reads it,
/// and a script element can have element children - an SVG script the parser
/// nests inside another (execution-timing/138-143), or anything script
/// appends. Their text is not the script's source; walking into them fed the
/// outer script the inner one's text and turned it into a SyntaxError.
/// A CDATASection is a Text node, so its data counts.
fn getChildTextContent(allocator: std.mem.Allocator, element: *runtime.Instance) ![]const u8 {
    var result = infra.List(u8).init(allocator);
    errdefer result.deinit();

    var child = NodeImpl.getFirstChild(element);
    while (child) |c| : (child = NodeImpl.getNextSibling(c)) {
        if (isTextNode(c)) try appendCharacterData(c, &result);
    }

    if (result.size() == 0) {
        result.deinit();
        return "";
    }

    return try result.toOwnedSlice();
}

/// Text or CDATASection: the nodes whose data is child text content.
fn isTextNode(node: *runtime.Instance) bool {
    const node_type = NodeImpl.getNodeType(node) orelse return false;
    return node_type == NodeImpl.NodeType.TEXT_NODE or
        node_type == NodeImpl.NodeType.CDATA_SECTION_NODE;
}

fn appendCharacterData(node: *runtime.Instance, result: *infra.List(u8)) !void {
    var data = CharacterData.get_data(node) catch return;
    defer data.deinit(result.allocator);
    try result.appendSlice(data.asSlice());
}

// =============================================================================
// External Script Loading
// =============================================================================

/// Result of fetching an external script. Every non-null slice is owned by
/// the allocator the fetch was given; `deinit` releases them all.
const ExternalScriptFetchResult = struct {
    body: ?[]const u8,
    content_type: ?[]const u8,
    status: u16,
    /// The response's URL - the last URL in its URL list, i.e. after
    /// redirects. Null when the response carried none.
    final_url: ?[]const u8,

    pub fn deinit(self: *ExternalScriptFetchResult, allocator: std.mem.Allocator) void {
        if (self.body) |b| allocator.free(b);
        if (self.content_type) |ct| allocator.free(ct);
        if (self.final_url) |u| allocator.free(u);
        self.body = null;
        self.content_type = null;
        self.final_url = null;
    }
};

/// Resolve a URL relative to a base URL
/// For now, this is a simple implementation that handles absolute URLs
/// and simple relative paths
fn resolveUrl(allocator: std.mem.Allocator, url: []const u8, base_url: []const u8) ![]const u8 {
    // If URL starts with a scheme, it's absolute
    // Check for "://" (http, https, etc.) or single-colon schemes (javascript:, data:, blob:, etc.)
    if (std.mem.indexOf(u8, url, "://") != null) {
        return url; // Return the original slice, don't allocate
    }

    // Check for single-colon schemes like javascript:, data:, blob:, mailto:, tel:, etc.
    // These are absolute URLs that should not be resolved relative to base
    if (std.mem.indexOf(u8, url, ":")) |colon_pos| {
        // Only treat as absolute if the scheme part contains only valid scheme characters (letters, digits, +, -, .)
        // and the colon is not at position 0
        if (colon_pos > 0) {
            const potential_scheme = url[0..colon_pos];
            var is_valid_scheme = true;
            for (potential_scheme) |c| {
                if (!std.ascii.isAlphanumeric(c) and c != '+' and c != '-' and c != '.') {
                    is_valid_scheme = false;
                    break;
                }
            }
            if (is_valid_scheme and std.ascii.isAlphabetic(potential_scheme[0])) {
                return url; // It's an absolute URL with a single-colon scheme
            }
        }
    }

    // If URL starts with //, it's protocol-relative
    if (std.mem.startsWith(u8, url, "//")) {
        // Extract scheme from base URL
        if (std.mem.indexOf(u8, base_url, "://")) |scheme_end| {
            const scheme = base_url[0..scheme_end];
            const result = try allocator.alloc(u8, scheme.len + 1 + url.len);
            @memcpy(result[0..scheme.len], scheme);
            result[scheme.len] = ':';
            @memcpy(result[scheme.len + 1 ..], url);
            return result;
        }
        // Fallback to https
        const result = try allocator.alloc(u8, 6 + url.len);
        @memcpy(result[0..6], "https:");
        @memcpy(result[6..], url);
        return result;
    }

    // Relative URL - resolve against base
    if (base_url.len == 0) {
        return url; // Can't resolve without base
    }

    // Find the base path (everything up to and including the last /)
    var base_path_end: usize = 0;
    if (std.mem.lastIndexOf(u8, base_url, "/")) |last_slash| {
        base_path_end = last_slash + 1;
    }

    // If URL starts with /, it's root-relative
    if (std.mem.startsWith(u8, url, "/")) {
        // Find the origin (scheme + authority)
        if (std.mem.indexOf(u8, base_url, "://")) |scheme_end| {
            const after_scheme = scheme_end + 3; // Skip "://"
            const origin_end = if (std.mem.indexOfPos(u8, base_url, after_scheme, "/")) |slash|
                slash
            else
                base_url.len;

            const result = try allocator.alloc(u8, origin_end + url.len);
            @memcpy(result[0..origin_end], base_url[0..origin_end]);
            @memcpy(result[origin_end..], url);
            return result;
        }
        return url;
    }

    // Regular relative URL - append to base path
    const result = try allocator.alloc(u8, base_path_end + url.len);
    @memcpy(result[0..base_path_end], base_url[0..base_path_end]);
    @memcpy(result[base_path_end..], url);
    return result;
}

/// URL parts for CSP checking
const UrlPartsForCSP = struct {
    scheme: []const u8,
    host: []const u8,
    port: ?u16,
    path: []const u8,
};

/// Parse a URL into components for CSP checking
/// This is a simplified URL parser for CSP purposes.
fn parseUrlForCSP(url: []const u8) UrlPartsForCSP {
    var result = UrlPartsForCSP{
        .scheme = "",
        .host = "",
        .port = null,
        .path = "/",
    };

    // Find scheme (before ://)
    if (std.mem.indexOf(u8, url, "://")) |scheme_end| {
        result.scheme = url[0..scheme_end];

        // Find host (after :// and before / or : or end)
        const after_scheme = url[scheme_end + 3 ..];

        // Find end of authority (first / or end of string)
        var authority_end = after_scheme.len;
        if (std.mem.indexOf(u8, after_scheme, "/")) |slash| {
            authority_end = slash;
            result.path = after_scheme[slash..];
        }

        const authority = after_scheme[0..authority_end];

        // Check for port (: in authority)
        if (std.mem.lastIndexOf(u8, authority, ":")) |colon| {
            result.host = authority[0..colon];
            const port_str = authority[colon + 1 ..];
            result.port = std.fmt.parseInt(u16, port_str, 10) catch null;
        } else {
            result.host = authority;
        }
    }

    return result;
}

/// Fetch an external script using the Fetch API
/// This is a synchronous fetch for parser-blocking scripts
///
/// `body` is null exactly when "fetch a classic script" would hand its
/// onComplete null: a network error or a status that is not an ok status. An
/// ok response with an EMPTY body is a script - one that does nothing - and it
/// still runs and still earns its element a load event, so it comes back as an
/// empty owned slice rather than null. Treating it as a failure made every
/// empty external script silently disappear.
///
/// Never fails: running out of memory while copying the response is reported
/// the way the spec reports any other failed fetch, with a null body.
fn fetchExternalScript(allocator: std.mem.Allocator, url: []const u8) ExternalScriptFetchResult {
    var result = ExternalScriptFetchResult{
        .body = null,
        .content_type = null,
        .status = 0,
        .final_url = null,
    };

    // Use the fetch module to retrieve the script. A transport failure comes
    // back IN-BAND as a network-error response (type error, status 0), which
    // the ok-status check below rejects - see AGENTS.md on in-band failures.
    const response = fetch.fetchSimple(allocator, url) catch |err| {
        log.debug("Fetch error for script {s}: {}", .{ url, err });
        return result;
    };
    defer response.deinit();

    result.status = response.status;

    // An ok status is 200-299 (Fetch §2.2.3).
    if (response.status < 200 or response.status >= 300) return result;

    if (response.header_list.getFirstValue("content-type")) |ct| {
        result.content_type = allocator.dupe(u8, ct) catch null;
    }
    if (response.url()) |response_url| {
        result.final_url = allocator.dupe(u8, response_url) catch null;
    }

    const bytes: []const u8 = if (response.body) |resp_body| resp_body.data.items else "";
    result.body = allocator.dupe(u8, bytes) catch {
        result.deinit(allocator);
        return .{ .body = null, .content_type = null, .status = response.status, .final_url = null };
    };
    return result;
}

// =============================================================================
// Import Map Support (HTML Standard §8.1.6)
// =============================================================================

/// Result of parsing an import map
const ImportMapParseResult = struct {
    /// Imports mapping: bare specifier -> resolved URL
    imports: std.StringHashMap([]const u8),

    /// Scopes mapping: scope prefix -> (specifier -> URL)
    scopes: std.StringHashMap(std.StringHashMap([]const u8)),

    /// Error message if parsing failed
    error_message: ?[]const u8,

    /// Allocator used for error message (for cleanup)
    allocator: ?std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) ImportMapParseResult {
        return .{
            .imports = std.StringHashMap([]const u8).init(alloc),
            .scopes = std.StringHashMap(std.StringHashMap([]const u8)).init(alloc),
            .error_message = null,
            .allocator = null,
        };
    }

    pub fn deinit(self: *ImportMapParseResult, alloc: std.mem.Allocator) void {
        // Free imports
        var imp_it = self.imports.iterator();
        while (imp_it.next()) |entry| {
            alloc.free(entry.key_ptr.*);
            alloc.free(entry.value_ptr.*);
        }
        self.imports.deinit();

        // Free scopes
        var scope_it = self.scopes.iterator();
        while (scope_it.next()) |entry| {
            alloc.free(entry.key_ptr.*);
            var nested_it = entry.value_ptr.iterator();
            while (nested_it.next()) |nested_entry| {
                alloc.free(nested_entry.key_ptr.*);
                alloc.free(nested_entry.value_ptr.*);
            }
            entry.value_ptr.deinit();
        }
        self.scopes.deinit();
    }
};

/// Parse an import map JSON
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#parse-an-import-map-string
fn parseImportMap(
    allocator: std.mem.Allocator,
    json_text: []const u8,
    base_url: []const u8,
) ImportMapParseResult {
    var result = ImportMapParseResult.init(allocator);

    // Parse JSON
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, json_text, .{}) catch {
        result.error_message = allocator.dupe(u8, "Invalid JSON in import map") catch null;
        result.allocator = allocator;
        return result;
    };
    defer parsed.deinit();

    const root = parsed.value;

    // Import map must be an object
    if (root != .object) {
        result.error_message = allocator.dupe(u8, "Import map must be a JSON object") catch null;
        result.allocator = allocator;
        return result;
    }

    const root_obj = root.object;

    // Process "imports" if present
    if (root_obj.get("imports")) |imports_value| {
        if (imports_value == .object) {
            var imp_it = imports_value.object.iterator();
            while (imp_it.next()) |entry| {
                const specifier = entry.key_ptr.*;
                if (entry.value_ptr.* == .string) {
                    const target = entry.value_ptr.string;

                    // Resolve target URL relative to base URL
                    const resolved = resolveUrl(allocator, target, base_url) catch continue;

                    // Store owned copies
                    const owned_specifier = allocator.dupe(u8, specifier) catch continue;
                    const owned_url = if (resolved.ptr != target.ptr)
                        resolved
                    else
                        allocator.dupe(u8, resolved) catch continue;

                    result.imports.put(owned_specifier, owned_url) catch {
                        allocator.free(owned_specifier);
                        if (resolved.ptr != target.ptr) allocator.free(resolved);
                        continue;
                    };
                }
            }
        }
    }

    // Process "scopes" if present
    if (root_obj.get("scopes")) |scopes_value| {
        if (scopes_value == .object) {
            var scope_it = scopes_value.object.iterator();
            while (scope_it.next()) |scope_entry| {
                const scope_prefix = scope_entry.key_ptr.*;
                if (scope_entry.value_ptr.* == .object) {
                    // Resolve scope prefix URL
                    const resolved_scope = resolveUrl(allocator, scope_prefix, base_url) catch continue;
                    const owned_scope = if (resolved_scope.ptr != scope_prefix.ptr)
                        resolved_scope
                    else
                        allocator.dupe(u8, resolved_scope) catch continue;

                    var scope_imports = std.StringHashMap([]const u8).init(allocator);

                    var inner_it = scope_entry.value_ptr.object.iterator();
                    while (inner_it.next()) |inner_entry| {
                        const specifier = inner_entry.key_ptr.*;
                        if (inner_entry.value_ptr.* == .string) {
                            const target = inner_entry.value_ptr.string;

                            // Resolve target URL relative to base URL
                            const resolved = resolveUrl(allocator, target, base_url) catch continue;

                            const owned_specifier = allocator.dupe(u8, specifier) catch continue;
                            const owned_url = if (resolved.ptr != target.ptr)
                                resolved
                            else
                                allocator.dupe(u8, resolved) catch continue;

                            scope_imports.put(owned_specifier, owned_url) catch {
                                allocator.free(owned_specifier);
                                if (resolved.ptr != target.ptr) allocator.free(resolved);
                                continue;
                            };
                        }
                    }

                    result.scopes.put(owned_scope, scope_imports) catch {
                        allocator.free(owned_scope);
                        // Free scope_imports contents
                        var cleanup_it = scope_imports.iterator();
                        while (cleanup_it.next()) |cleanup_entry| {
                            allocator.free(cleanup_entry.key_ptr.*);
                            allocator.free(cleanup_entry.value_ptr.*);
                        }
                        scope_imports.deinit();
                        continue;
                    };
                }
            }
        }
    }

    return result;
}

/// Register an import map with the document
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#register-an-import-map
fn registerImportMap(
    doc: *runtime.Instance,
    import_map: ImportMapParseResult,
) !void {
    // Register all top-level imports
    var imp_it = import_map.imports.iterator();
    while (imp_it.next()) |entry| {
        try doc_state.addImportMapping(doc, entry.key_ptr.*, entry.value_ptr.*);
    }

    // Register all scoped imports
    var scope_it = import_map.scopes.iterator();
    while (scope_it.next()) |scope_entry| {
        var inner_it = scope_entry.value_ptr.iterator();
        while (inner_it.next()) |inner_entry| {
            try doc_state.addScopedImportMapping(
                doc,
                scope_entry.key_ptr.*,
                inner_entry.key_ptr.*,
                inner_entry.value_ptr.*,
            );
        }
    }
}

// =============================================================================
// Speculation Rules Support (HTML Standard §7.6.1)
// =============================================================================

/// Speculation rule eagerness levels - re-export from doc_state
/// Spec: https://html.spec.whatwg.org/multipage/speculative-loading.html#speculation-rule-eagerness
pub const SpeculationEagerness = doc_state.SpeculationEagerness;

/// A single speculation rule
/// Spec: https://html.spec.whatwg.org/multipage/speculative-loading.html#speculation-rule
pub const SpeculationRule = struct {
    /// URLs to prefetch/prerender (for list-based rules)
    urls: infra.List([]const u8),

    /// Eagerness level
    eagerness: SpeculationEagerness,

    /// Referrer policy override (empty string means use default)
    referrer_policy: []const u8,

    /// Tags for this rule
    tags: infra.List([]const u8),

    /// Whether anonymous client IP is required for cross-origin
    requires_anonymous_client_ip: bool,

    pub fn init(allocator: std.mem.Allocator) SpeculationRule {
        return .{
            .urls = infra.List([]const u8).init(allocator),
            .eagerness = .immediate,
            .referrer_policy = "",
            .tags = infra.List([]const u8).init(allocator),
            .requires_anonymous_client_ip = false,
        };
    }

    pub fn deinit(self: *SpeculationRule, allocator: std.mem.Allocator) void {
        for (0..self.urls.len) |i| {
            if (self.urls.get(i)) |url| {
                allocator.free(url);
            }
        }
        self.urls.deinit();
        for (0..self.tags.len) |i| {
            if (self.tags.get(i)) |tag| {
                allocator.free(tag);
            }
        }
        self.tags.deinit();
        if (self.referrer_policy.len > 0) {
            allocator.free(self.referrer_policy);
        }
    }
};

/// Result of parsing speculation rules
const SpeculationRulesParseResult = struct {
    /// Prefetch rules
    prefetch_rules: infra.List(SpeculationRule),

    /// Prerender rules (treated same as prefetch for now)
    prerender_rules: infra.List(SpeculationRule),

    /// Top-level tag (optional)
    tag: ?[]const u8,

    /// Error message if parsing failed
    error_message: ?[]const u8,

    /// Allocator used for error message (for cleanup)
    allocator: ?std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) SpeculationRulesParseResult {
        return .{
            .prefetch_rules = infra.List(SpeculationRule).init(alloc),
            .prerender_rules = infra.List(SpeculationRule).init(alloc),
            .tag = null,
            .error_message = null,
            .allocator = null,
        };
    }

    pub fn deinit(self: *SpeculationRulesParseResult, alloc: std.mem.Allocator) void {
        for (0..self.prefetch_rules.len) |i| {
            if (self.prefetch_rules.get(i)) |*rule| {
                @constCast(rule).deinit(alloc);
            }
        }
        self.prefetch_rules.deinit();
        for (0..self.prerender_rules.len) |i| {
            if (self.prerender_rules.get(i)) |*rule| {
                @constCast(rule).deinit(alloc);
            }
        }
        self.prerender_rules.deinit();
        if (self.tag) |tag| {
            alloc.free(tag);
        }
    }
};

/// Parse speculation rules JSON
/// Spec: https://html.spec.whatwg.org/multipage/speculative-loading.html#parse-a-speculation-rule-set-string
fn parseSpeculationRules(
    allocator: std.mem.Allocator,
    json_text: []const u8,
    base_url: []const u8,
) SpeculationRulesParseResult {
    var result = SpeculationRulesParseResult.init(allocator);

    // Step 1: Parse JSON
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, json_text, .{}) catch {
        result.error_message = allocator.dupe(u8, "Invalid JSON in speculation rules") catch null;
        result.allocator = allocator;
        return result;
    };
    defer parsed.deinit();

    const root = parsed.value;

    // Step 2: Must be an object
    if (root != .object) {
        result.error_message = allocator.dupe(u8, "Speculation rules must be a JSON object") catch null;
        result.allocator = allocator;
        return result;
    }

    const root_obj = root.object;

    // Step 4-5: Get top-level tag if present
    if (root_obj.get("tag")) |tag_value| {
        if (tag_value == .string) {
            result.tag = allocator.dupe(u8, tag_value.string) catch null;
        }
    }

    // Step 7-8: Process "prefetch" and "prerender" arrays
    const rule_types = [_][]const u8{ "prefetch", "prerender" };

    for (rule_types) |rule_type| {
        if (root_obj.get(rule_type)) |rules_value| {
            if (rules_value == .array) {
                for (rules_value.array.items) |rule_value| {
                    const rule = parseSpeculationRule(allocator, rule_value, result.tag, base_url) orelse continue;
                    if (std.mem.eql(u8, rule_type, "prefetch")) {
                        result.prefetch_rules.append(rule) catch continue;
                    } else {
                        result.prerender_rules.append(rule) catch continue;
                    }
                }
            }
        }
    }

    return result;
}

/// Parse a single speculation rule
/// Spec: https://html.spec.whatwg.org/multipage/speculative-loading.html#parse-a-speculation-rule
fn parseSpeculationRule(
    allocator: std.mem.Allocator,
    input: std.json.Value,
    ruleset_tag: ?[]const u8,
    base_url: []const u8,
) ?SpeculationRule {
    // Step 1: Must be an object
    if (input != .object) {
        return null;
    }

    const obj = input.object;

    var rule = SpeculationRule.init(allocator);
    errdefer rule.deinit(allocator);

    // Step 3-7: Determine source (list or document)
    var source: ?[]const u8 = null;
    if (obj.get("source")) |source_value| {
        if (source_value == .string) {
            source = source_value.string;
        }
    }

    // Infer source if not provided
    if (source == null) {
        if (obj.get("urls") != null and obj.get("where") == null) {
            source = "list";
        } else if (obj.get("where") != null and obj.get("urls") == null) {
            source = "document";
        }
    }

    // Step 8-10: Parse URLs for list-based rules
    if (source != null and std.mem.eql(u8, source.?, "list")) {
        if (obj.get("urls")) |urls_value| {
            if (urls_value == .array) {
                for (urls_value.array.items) |url_value| {
                    if (url_value == .string) {
                        // Resolve URL relative to base
                        const resolved = resolveUrl(allocator, url_value.string, base_url) catch continue;
                        const owned_url = if (resolved.ptr != url_value.string.ptr)
                            resolved
                        else
                            allocator.dupe(u8, resolved) catch continue;

                        // Validate it's HTTP(S)
                        if (std.mem.startsWith(u8, owned_url, "http://") or
                            std.mem.startsWith(u8, owned_url, "https://"))
                        {
                            rule.urls.append(owned_url) catch {
                                allocator.free(owned_url);
                                continue;
                            };
                        } else {
                            allocator.free(owned_url);
                        }
                    }
                }
            }
        }
    }

    // Step 12-13: Parse eagerness
    if (obj.get("eagerness")) |eagerness_value| {
        if (eagerness_value == .string) {
            const eagerness_str = eagerness_value.string;
            if (std.mem.eql(u8, eagerness_str, "immediate")) {
                rule.eagerness = .immediate;
            } else if (std.mem.eql(u8, eagerness_str, "eager")) {
                rule.eagerness = .eager;
            } else if (std.mem.eql(u8, eagerness_str, "moderate")) {
                rule.eagerness = .moderate;
            } else if (std.mem.eql(u8, eagerness_str, "conservative")) {
                rule.eagerness = .conservative;
            } else {
                // Invalid eagerness
                return null;
            }
        }
    } else {
        // Default: immediate for list, conservative for document
        if (source != null and std.mem.eql(u8, source.?, "list")) {
            rule.eagerness = .immediate;
        } else {
            rule.eagerness = .conservative;
        }
    }

    // Step 14-15: Parse referrer policy
    if (obj.get("referrer_policy")) |rp_value| {
        if (rp_value == .string) {
            rule.referrer_policy = allocator.dupe(u8, rp_value.string) catch "";
        }
    }

    // Step 16-20: Parse tags
    if (ruleset_tag) |tag| {
        const owned_tag = allocator.dupe(u8, tag) catch null;
        if (owned_tag) |t| {
            rule.tags.append(t) catch {};
        }
    }
    if (obj.get("tag")) |tag_value| {
        if (tag_value == .string) {
            const owned_tag = allocator.dupe(u8, tag_value.string) catch null;
            if (owned_tag) |t| {
                rule.tags.append(t) catch {};
            }
        }
    }

    // Step 21-22: Parse requirements
    if (obj.get("requires")) |req_value| {
        if (req_value == .array) {
            for (req_value.array.items) |req| {
                if (req == .string) {
                    if (std.mem.eql(u8, req.string, "anonymous-client-ip-when-cross-origin")) {
                        rule.requires_anonymous_client_ip = true;
                    }
                }
            }
        }
    }

    return rule;
}

// toDocumentEagerness removed - SpeculationEagerness now comes directly from doc_state

/// Register speculation rules with the document
/// Spec: https://html.spec.whatwg.org/multipage/speculative-loading.html#consider-speculative-loads
fn registerSpeculationRules(
    doc: *runtime.Instance,
    rules: SpeculationRulesParseResult,
) !void {
    // For now, we just store the prefetch URLs in the document
    // A full implementation would:
    // 1. Add to document's speculation rule sets
    // 2. Consider speculative loads (queue microtask)
    // 3. Match against links in the document for document rules
    // 4. Actually initiate prefetch requests

    // Store prefetch URLs for potential use
    for (0..rules.prefetch_rules.len) |i| {
        const rule = rules.prefetch_rules.get(i) orelse continue;
        for (0..rule.urls.len) |j| {
            const url = rule.urls.get(j) orelse continue;
            // Add to document's prefetch hints
            // Convert local eagerness type to Document's eagerness type
            doc_state.addPrefetchHint(doc, url, rule.eagerness) catch continue;
        }
    }

    // Prerender rules are treated similarly (prefetch for now)
    for (0..rules.prerender_rules.len) |i| {
        const rule = rules.prerender_rules.get(i) orelse continue;
        for (0..rule.urls.len) |j| {
            const url = rule.urls.get(j) orelse continue;
            doc_state.addPrefetchHint(doc, url, rule.eagerness) catch continue;
        }
    }

    log.debug("Registered {d} prefetch rules and {d} prerender rules\n", .{
        rules.prefetch_rules.len,
        rules.prerender_rules.len,
    });
}

// =============================================================================
// Event Firing for Script Elements
// =============================================================================

// Event utilities for proper event creation and dispatch
const event_utils = @import("event_utils.zig");

/// Fire a load event on a script element
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#execute-the-script-element (step 8)
///
/// The load event is fired after successful script execution to indicate
/// the script has loaded and executed successfully.
pub fn fireLoadEvent(allocator: std.mem.Allocator, script_element: *runtime.Instance) void {
    // Fire a simple "load" event - not cancelable, doesn't bubble
    fireAtScriptElement(allocator, script_element, "load");
}

/// Fire an event at a script element through the REAL dispatch algorithm.
///
/// `event_utils.fireSimpleEvent` cannot be used here. Its `dispatchEvent` is a
/// stub that sets the dispatch flags and returns without invoking a single
/// listener - deliberately, because it is handed a context synthesised on the
/// CALLER'S STACK and only the absence of listeners keeps the event from
/// escaping into V8 (see the comment on `event_utils.fireEvent`). The
/// consequence for scripts is total: neither `script.onload = fn` nor
/// `script.addEventListener("load", fn)` ever ran, which is why so many files
/// under html/semantics/scripting-1/ waited out the full harness timeout
/// instead of failing.
///
/// A script element is never in that position - it has a real context, whose
/// entry outlives every Instance created in it - so it can go through
/// `EventTarget.dispatchEvent`, which walks the event path, invokes listeners
/// and calls the IDL event handler attribute.
///
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#execute-the-script-element
fn fireAtScriptElement(
    allocator: std.mem.Allocator,
    script_element: *runtime.Instance,
    event_type: []const u8,
) void {
    _ = allocator;
    // Callers include the parser - executeScriptsWhenParsingFinished runs a
    // deferred script and fires its load event from loadHTML, not from script
    // or a task - so the element's realm may not be current. Dispatch wraps
    // the event for its listeners in it (5 CRASHes in one worklist sweep, four
    // of them render-blocking files with a deferred script, when nothing
    // entered it). An error: the realm is gone, and nobody is left to hear the
    // event.
    var fire = ScriptElementEvent{ .element = script_element, .event_type = event_type };
    engine.runInRealm(script_element.ctx, fireAtScriptElementSteps, &fire) catch return;
}

const ScriptElementEvent = struct {
    element: *runtime.Instance,
    event_type: []const u8,
};

fn fireAtScriptElementSteps(data: ?*anyopaque) void {
    const fire: *const ScriptElementEvent = @ptrCast(@alignCast(data.?));
    const event = interfaces.Event.call_constructor(
        fire.element.ctx,
        runtime.DOMString.initInterned(fire.event_type),
        .{ .was_passed = true, .value = .{
            .bubbles = false,
            .cancelable = false,
            .composed = false,
        } },
    ) catch |err| {
        log.debug("Failed to create {s} event: {any}", .{ fire.event_type, err });
        return;
    };
    // Deliberately no `defer deinit`. A listener that runs can hand the event to
    // script, and the engine then holds a wrapper for it; freeing it here would
    // be a use-after-free the moment the handler kept a reference. Nor is it
    // freed with the context: nothing sweeps a context's Instances, and the
    // DebugAllocator reported one leak per external script. So the event is
    // released after dispatch unless something wrapped it.
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);

    // Fired by the user agent, so trusted (DOM 2.10): dispatchTrusted sets
    // isTrusted.
    _ = @import("dom").fire_event.dispatchTrusted(fire.element, event) catch |err| {
        log.debug("Failed to dispatch {s} event: {any}", .{ fire.event_type, err });
        return;
    };
}

/// Fire an error event on a script element
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#prepare-the-script-element
///
/// The error event is fired when:
/// - Script source cannot be loaded (network error, 404, etc.)
/// - Script type is not supported
/// - URL parsing fails
/// - CSP blocks the script
///
/// Note: This is different from reportScriptError which handles runtime errors.
/// This function handles load-time errors.
pub fn fireErrorEvent(allocator: std.mem.Allocator, script_element: *runtime.Instance) void {
    // Fire a simple "error" event - not cancelable by default for load errors
    fireAtScriptElement(allocator, script_element, "error");
}

/// Report a script execution error
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#report-an-exception
///
/// This is called when a script throws an exception during execution.
/// The error event is fired at the global object, not the script element.
///
/// Parameters:
/// - allocator: Memory allocator
/// - global: The global object (Window or WorkerGlobalScope)
/// - message: The error message
/// - filename: URL of the script where the error occurred
/// - lineno: Line number where the error occurred
/// - colno: Column number where the error occurred
/// - error_value: The JavaScript error object (may be null for muted errors)
/// - muted_errors: Whether this script has muted errors (cross-origin without CORS)
pub fn reportScriptError(
    allocator: std.mem.Allocator,
    global: *runtime.Instance,
    message: ?[]const u8,
    filename: ?[]const u8,
    lineno: ?u32,
    colno: ?u32,
    error_value: ?*const anyopaque,
    muted_errors: bool,
) void {
    _ = event_utils.reportException(
        allocator,
        null,
        global,
        error_value,
        message,
        filename,
        lineno,
        colno,
        muted_errors,
        false, // omit_error = false
    ) catch |err| {
        log.debug("Failed to report script error: {any}\n", .{err});
    };
}

// =============================================================================
// Tests
// =============================================================================

test "resolveUrl - absolute URLs" {
    const allocator = std.testing.allocator;

    // Absolute URLs should be returned as-is (same pointer)
    const abs_url = "https://example.com/script.js";
    const resolved = try resolveUrl(allocator, abs_url, "https://other.com/page.html");
    try std.testing.expectEqual(abs_url.ptr, resolved.ptr);
}

test "resolveUrl - protocol-relative URLs" {
    const allocator = std.testing.allocator;

    const result = try resolveUrl(allocator, "//cdn.example.com/script.js", "https://example.com/page.html");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("https://cdn.example.com/script.js", result);
}

test "resolveUrl - root-relative URLs" {
    const allocator = std.testing.allocator;

    const result = try resolveUrl(allocator, "/scripts/app.js", "https://example.com/path/to/page.html");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("https://example.com/scripts/app.js", result);
}

test "resolveUrl - relative URLs" {
    const allocator = std.testing.allocator;

    const result = try resolveUrl(allocator, "lib.js", "https://example.com/scripts/");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("https://example.com/scripts/lib.js", result);
}

test "isJavaScriptMimeType" {
    try std.testing.expect(isJavaScriptMimeType("text/javascript"));
    try std.testing.expect(isJavaScriptMimeType("TEXT/JAVASCRIPT"));
    try std.testing.expect(isJavaScriptMimeType("text/javascript; charset=utf-8"));
    try std.testing.expect(isJavaScriptMimeType("application/javascript"));
    try std.testing.expect(isJavaScriptMimeType("application/ecmascript"));

    try std.testing.expect(!isJavaScriptMimeType("text/plain"));
    try std.testing.expect(!isJavaScriptMimeType("application/json"));
    try std.testing.expect(!isJavaScriptMimeType(""));
}

// =============================================================================
// Import Map Tests
// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#import-maps
// =============================================================================

test "parseImportMap - basic bare specifier mapping" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "imports": {
        \\    "lodash": "https://cdn.example.com/lodash/v4.17.21/lodash.min.js",
        \\    "react": "https://cdn.example.com/react/v18.2.0/react.min.js"
        \\  }
        \\}
    ;

    var result = parseImportMap(allocator, json, "https://example.com/");
    defer result.deinit(allocator);

    try std.testing.expect(result.error_message == null);
    try std.testing.expectEqual(@as(usize, 2), result.imports.count());
    try std.testing.expectEqualStrings(
        "https://cdn.example.com/lodash/v4.17.21/lodash.min.js",
        result.imports.get("lodash").?,
    );
    try std.testing.expectEqualStrings(
        "https://cdn.example.com/react/v18.2.0/react.min.js",
        result.imports.get("react").?,
    );
}

test "parseImportMap - relative URL resolution" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "imports": {
        \\    "utils": "lib/utils.js",
        \\    "helpers": "/scripts/helpers.js"
        \\  }
        \\}
    ;

    var result = parseImportMap(allocator, json, "https://example.com/app/");
    defer result.deinit(allocator);

    try std.testing.expect(result.error_message == null);
    try std.testing.expectEqual(@as(usize, 2), result.imports.count());

    // Relative URL should be resolved against base URL
    try std.testing.expectEqualStrings(
        "https://example.com/app/lib/utils.js",
        result.imports.get("utils").?,
    );

    // Root-relative URL
    try std.testing.expectEqualStrings(
        "https://example.com/scripts/helpers.js",
        result.imports.get("helpers").?,
    );
}

test "parseImportMap - scoped imports" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "imports": {
        \\    "lodash": "https://cdn.example.com/lodash/v4.js"
        \\  },
        \\  "scopes": {
        \\    "/app/": {
        \\      "lodash": "https://cdn.example.com/lodash/v5.js"
        \\    }
        \\  }
        \\}
    ;

    var result = parseImportMap(allocator, json, "https://example.com/");
    defer result.deinit(allocator);

    try std.testing.expect(result.error_message == null);
    try std.testing.expectEqual(@as(usize, 1), result.imports.count());
    try std.testing.expectEqual(@as(usize, 1), result.scopes.count());

    // Top-level import
    try std.testing.expectEqualStrings(
        "https://cdn.example.com/lodash/v4.js",
        result.imports.get("lodash").?,
    );

    // Scoped import - different version for /app/ paths
    const app_scope = result.scopes.get("https://example.com/app/");
    try std.testing.expect(app_scope != null);
    try std.testing.expectEqualStrings(
        "https://cdn.example.com/lodash/v5.js",
        app_scope.?.get("lodash").?,
    );
}

test "parseImportMap - empty imports object" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "imports": {}
        \\}
    ;

    var result = parseImportMap(allocator, json, "https://example.com/");
    defer result.deinit(allocator);

    try std.testing.expect(result.error_message == null);
    try std.testing.expectEqual(@as(usize, 0), result.imports.count());
}

test "parseImportMap - invalid JSON" {
    const allocator = std.testing.allocator;

    const json = "{ invalid json }";

    const result = parseImportMap(allocator, json, "https://example.com/");
    defer {
        if (result.allocator) |alloc| {
            if (result.error_message) |msg| {
                alloc.free(msg);
            }
        }
    }

    try std.testing.expect(result.error_message != null);
    try std.testing.expectEqualStrings("Invalid JSON in import map", result.error_message.?);
}

test "parseImportMap - non-object root" {
    const allocator = std.testing.allocator;

    const json = "[\"array\", \"not\", \"object\"]";

    const result = parseImportMap(allocator, json, "https://example.com/");
    defer {
        if (result.allocator) |alloc| {
            if (result.error_message) |msg| {
                alloc.free(msg);
            }
        }
    }

    try std.testing.expect(result.error_message != null);
    try std.testing.expectEqualStrings("Import map must be a JSON object", result.error_message.?);
}

test "parseImportMap - package subpath imports" {
    const allocator = std.testing.allocator;

    // Common pattern: package name with trailing slash for subpath imports
    const json =
        \\{
        \\  "imports": {
        \\    "lodash/": "https://cdn.example.com/lodash/",
        \\    "lodash": "https://cdn.example.com/lodash/index.js"
        \\  }
        \\}
    ;

    var result = parseImportMap(allocator, json, "https://example.com/");
    defer result.deinit(allocator);

    try std.testing.expect(result.error_message == null);
    try std.testing.expectEqual(@as(usize, 2), result.imports.count());

    // Base import
    try std.testing.expectEqualStrings(
        "https://cdn.example.com/lodash/index.js",
        result.imports.get("lodash").?,
    );

    // Subpath prefix (trailing slash allows lodash/debounce -> cdn.example.com/lodash/debounce)
    try std.testing.expectEqualStrings(
        "https://cdn.example.com/lodash/",
        result.imports.get("lodash/").?,
    );
}

test "parseImportMap - multiple scopes" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "imports": {
        \\    "react": "https://cdn.example.com/react/v17.js"
        \\  },
        \\  "scopes": {
        \\    "/new-app/": {
        \\      "react": "https://cdn.example.com/react/v18.js"
        \\    },
        \\    "/legacy/": {
        \\      "react": "https://cdn.example.com/react/v16.js"
        \\    }
        \\  }
        \\}
    ;

    var result = parseImportMap(allocator, json, "https://example.com/");
    defer result.deinit(allocator);

    try std.testing.expect(result.error_message == null);
    try std.testing.expectEqual(@as(usize, 2), result.scopes.count());

    // New app gets React 18
    const new_app_scope = result.scopes.get("https://example.com/new-app/");
    try std.testing.expect(new_app_scope != null);
    try std.testing.expectEqualStrings(
        "https://cdn.example.com/react/v18.js",
        new_app_scope.?.get("react").?,
    );

    // Legacy app gets React 16
    const legacy_scope = result.scopes.get("https://example.com/legacy/");
    try std.testing.expect(legacy_scope != null);
    try std.testing.expectEqualStrings(
        "https://cdn.example.com/react/v16.js",
        legacy_scope.?.get("react").?,
    );
}

test "isUrlLikeSpecifier - URL-like specifiers" {
    // Absolute URLs with schemes
    try std.testing.expect(isUrlLikeSpecifier("https://example.com/module.js"));
    try std.testing.expect(isUrlLikeSpecifier("http://example.com/module.js"));

    // Root-relative
    try std.testing.expect(isUrlLikeSpecifier("/scripts/module.js"));

    // Relative
    try std.testing.expect(isUrlLikeSpecifier("./module.js"));
    try std.testing.expect(isUrlLikeSpecifier("../module.js"));
    try std.testing.expect(isUrlLikeSpecifier("./path/to/module.js"));

    // Bare specifiers (should NOT be URL-like)
    try std.testing.expect(!isUrlLikeSpecifier("lodash"));
    try std.testing.expect(!isUrlLikeSpecifier("react"));
    try std.testing.expect(!isUrlLikeSpecifier("@scoped/package"));
    try std.testing.expect(!isUrlLikeSpecifier("module-name"));
}

// =============================================================================
// Speculation Rules Tests
// Spec: https://html.spec.whatwg.org/multipage/speculative-loading.html
// =============================================================================

test "parseSpeculationRules - basic prefetch rule" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "prefetch": [
        \\    {
        \\      "source": "list",
        \\      "urls": ["https://example.com/page1", "https://example.com/page2"]
        \\    }
        \\  ]
        \\}
    ;

    const result = parseSpeculationRules(allocator, json, "https://example.com/");
    defer @constCast(&result).deinit(allocator);

    try std.testing.expect(result.error_message == null);
    try std.testing.expectEqual(@as(usize, 1), result.prefetch_rules.len);

    const rule = result.prefetch_rules.get(0).?;
    try std.testing.expectEqual(@as(usize, 2), rule.urls.len);
    try std.testing.expectEqualStrings("https://example.com/page1", rule.urls.get(0).?);
    try std.testing.expectEqualStrings("https://example.com/page2", rule.urls.get(1).?);
    try std.testing.expectEqual(SpeculationEagerness.immediate, rule.eagerness);
}

test "parseSpeculationRules - eagerness levels" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "prefetch": [
        \\    {
        \\      "urls": ["https://example.com/eager"],
        \\      "eagerness": "eager"
        \\    },
        \\    {
        \\      "urls": ["https://example.com/moderate"],
        \\      "eagerness": "moderate"
        \\    },
        \\    {
        \\      "urls": ["https://example.com/conservative"],
        \\      "eagerness": "conservative"
        \\    }
        \\  ]
        \\}
    ;

    var result = parseSpeculationRules(allocator, json, "https://example.com/");
    defer result.deinit(allocator);

    try std.testing.expect(result.error_message == null);
    try std.testing.expectEqual(@as(usize, 3), result.prefetch_rules.len);
    try std.testing.expectEqual(SpeculationEagerness.eager, result.prefetch_rules.get(0).?.eagerness);
    try std.testing.expectEqual(SpeculationEagerness.moderate, result.prefetch_rules.get(1).?.eagerness);
    try std.testing.expectEqual(SpeculationEagerness.conservative, result.prefetch_rules.get(2).?.eagerness);
}

test "parseSpeculationRules - with tag" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "tag": "navigation-hints",
        \\  "prefetch": [
        \\    {
        \\      "urls": ["https://example.com/page"],
        \\      "tag": "primary"
        \\    }
        \\  ]
        \\}
    ;

    var result = parseSpeculationRules(allocator, json, "https://example.com/");
    defer result.deinit(allocator);

    try std.testing.expect(result.error_message == null);
    try std.testing.expectEqual(@as(usize, 1), result.prefetch_rules.len);

    // Should have both ruleset tag and rule tag
    try std.testing.expectEqual(@as(usize, 2), result.prefetch_rules.get(0).?.tags.len);
}

test "parseSpeculationRules - invalid JSON" {
    const allocator = std.testing.allocator;

    const json = "{ invalid json }";

    const result = parseSpeculationRules(allocator, json, "https://example.com/");
    defer {
        if (result.allocator) |alloc| {
            if (result.error_message) |msg| {
                alloc.free(msg);
            }
        }
    }

    try std.testing.expect(result.error_message != null);
}

test "parseSpeculationRules - non-HTTP URLs filtered" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "prefetch": [
        \\    {
        \\      "urls": ["https://example.com/valid", "javascript:alert(1)", "data:text/html,test"]
        \\    }
        \\  ]
        \\}
    ;

    var result = parseSpeculationRules(allocator, json, "https://example.com/");
    defer result.deinit(allocator);

    try std.testing.expect(result.error_message == null);
    try std.testing.expectEqual(@as(usize, 1), result.prefetch_rules.len);
    // Only the HTTPS URL should be kept
    try std.testing.expectEqual(@as(usize, 1), result.prefetch_rules.get(0).?.urls.len);
}
