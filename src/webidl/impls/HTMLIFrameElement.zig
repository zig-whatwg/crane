//! Implementation for HTMLIFrameElement interface
//!
//! Implements the HTMLIFrameElement per HTML Standard §4.8.5.
//! Spec: https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element
//!
//! ## Key Features
//!
//! - contentWindow: Returns the WindowProxy for the nested browsing context
//! - contentDocument: Returns the nested document (same-origin only)
//! - src/srcdoc: URL or inline HTML content
//! - name: Browsing context name for targeting
//! - sandbox: DOMTokenList controlling iframe restrictions
//!
//! ## Architecture
//!
//! HTMLIFrameElement uses IFrameIntegration to manage the nested browsing context.
//! The integration handles lifecycle (insertion/removal) and navigation.

const std = @import("std");
const log = std.log.scoped(.html_iframe);
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const HTMLIFrameElement = interfaces.HTMLIFrameElement;
const DOMTokenList = interfaces.DOMTokenList;
const DOMTokenListImpl = @import("DOMTokenList.zig");

// Import html_core for IFrameIntegration (interface-free module)
const html_core = @import("html_core");
const InternalStateAccessor = webidl.utils.InternalStateAccessor;
const IFrameIntegration = html_core.IFrameIntegration;
const Origin = html_core.Origin;
const SandboxFlags = html_core.SandboxFlags;

// V8 imports for cross-realm support (Phase 3)
const v8 = @import("v8");
const context_manager = v8.context_manager;

// DOM imports for post-connection steps callback
const dom_module = @import("dom");
const instance_bridge = dom_module.instance_bridge;
const NodeBase = dom_module.NodeBase;

// HTML module for scripted parsing with DOM integration
const html_module = @import("html");
const clock = @import("clock");
const scripted_parser = html_module.scripted_parser;
const document_internals = dom_module.document_internals;

// ============================================================================
// Node.call_appendChild's iframe hook
// ============================================================================

/// Nothing: the iframe's post-connection steps (`iframePostConnectionSteps`)
/// create its content navigable and process its attributes for every
/// insertion - the parser's, and every DOM method's - which this hook,
/// called from Node.call_appendChild alone, never could: a parser-inserted
/// `<iframe src>` never loaded. Kept only because Node.zig still calls it.
pub fn fireIframeLoadEventIfNeeded(instance: *runtime.Instance) void {
    _ = instance;
}

pub const State = HTMLIFrameElement.State;

pub const ImplError = error{
    NotImplemented,
    OutOfMemory,
    InvalidState,
};

/// Internal state for HTMLIFrameElement
/// Tracks the nested browsing context and related state
pub const InternalState = struct {
    /// The iframe integration managing the browsing context lifecycle
    integration: *IFrameIntegration,

    /// Allocator for this instance
    allocator: std.mem.Allocator,

    /// DOMTokenList for the sandbox attribute (lazily created)
    sandbox_token_list: ?*runtime.Instance = null,

    /// Cached attribute values for reflection. `src` and `srcdoc` are not
    /// cached: they reflect their content attributes, which "process the
    /// iframe attributes" reads.
    name_attr: ?[]const u8 = null,
    allow_attr: ?[]const u8 = null,
    width_attr: ?[]const u8 = null,
    height_attr: ?[]const u8 = null,
    referrer_policy_attr: ?[]const u8 = null,
    loading_attr: ?[]const u8 = null,
    csp_attr: ?[]const u8 = null,
    align_attr: ?[]const u8 = null,
    scrolling_attr: ?[]const u8 = null,
    frame_border_attr: ?[]const u8 = null,
    long_desc_attr: ?[]const u8 = null,
    margin_height_attr: ?[]const u8 = null,
    margin_width_attr: ?[]const u8 = null,
    private_token_attr: ?[]const u8 = null,

    /// Boolean attributes
    allow_fullscreen: bool = false,
    browsing_topics: bool = false,
    credentialless: bool = false,
    ad_auction_headers: bool = false,
    shared_storage_writable: bool = false,

    pub fn init(allocator: std.mem.Allocator) !*InternalState {
        const ArenaAllocator = runtime.ArenaAllocator;
        const state = try ArenaAllocator.get().create(InternalState);

        const integration = try ArenaAllocator.get().create(IFrameIntegration);
        integration.* = IFrameIntegration.init(allocator);

        log.debug("[InternalState.init] Created integration={*} for state={*}", .{ integration, state });

        state.* = .{
            .integration = integration,
            .allocator = allocator,
        };

        return state;
    }

    pub fn deinit(self: *InternalState) void {
        // Clean up integration, then return ITS block too - `init` takes a second
        // arena allocation for it, and releasing only what it points to left the
        // struct held for the life of the process. A navigation step running
        // script with it in hand puts that off until it is done (see
        // `IFrameIntegration.busy`).
        if (self.integration.busy > 0) {
            self.integration.deinit_pending = true;
        } else {
            destroyIntegration(self.integration);
        }

        // NOTE: Do NOT call DOMTokenList.deinit() on sandbox_token_list here.
        // The [SameObject] DOMTokenList instances are managed by the V8 wrapper cache.
        // During context cleanup, the wrapper cache iterates all instances and calls
        // their deinit. If we also call deinit here, we get a double-free crash.
        // Just clear the pointer to avoid dangling references.
        self.sandbox_token_list = null;

        // Free cached strings
        inline for (@typeInfo(InternalState).@"struct".fields) |field| {
            if (field.type == ?[]const u8) {
                if (@field(self, field.name)) |str| {
                    self.allocator.free(str);
                }
            }
        }
    }
};

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

pub fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// Initialize instance (creates the instance)
/// Chains to parent class: HTMLElement -> Element -> Node -> EventTarget
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Ensure the iframe DOM mutation callbacks are registered.
    // These only register once and are no-ops on subsequent calls.
    ensureRemovingStepsRegistered();
    ensurePostConnectionStepsRegistered();
    dom_module.auxiliary_navigables.install(.{ .create = &createAuxiliaryNavigable });
    dom_module.content_navigables.install(.{
        .delays_load_event = &iframesDelayLoadEvent,
        .run_load_event_steps = &contentNavigableLoadEventSteps,
    });

    // Chain to parent class (HTMLElement)
    const HTMLElementImpl = @import("HTMLElement.zig");
    const instance = try HTMLElementImpl.init(allocator, StateType, vtable, ctx);
    errdefer HTMLElementImpl.deinit(instance);

    // Initialize internal state
    const state = instance.getState(StateType);
    state.own._internal = try InternalState.init(allocator);
    log.debug("[HTMLIFrameElement.init] instance={*} -> internal={*} -> integration={*}", .{ instance, state.own._internal.?, state.own._internal.?.integration });

    // Set Node's local name for iframe identification during DOM operations
    const NodeImpl = @import("Node.zig");
    try NodeImpl.setLocalName(instance, runtime.DOMString.initInterned("iframe"));

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Guard against double-deinit. This can happen when:
    // 1. Tree cleanup (Node.deinit → deinitNodeByType) deinits this iframe
    // 2. GC cleanup (onObjectFreed) also tries to deinit the same iframe
    // Only one path should proceed with cleanup.
    log.debug("[HTMLIFrameElement.deinit] Called for instance {*}", .{instance});
    if (!runtime.instance_lifecycle.markCleanupStarted(instance)) {
        log.debug("[HTMLIFrameElement.deinit] Already cleaning up, skipping", .{});
        return; // Already being cleaned up, skip
    }

    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        log.debug("[HTMLIFrameElement.deinit] instance={*} -> integration={*}", .{ instance, internal.integration });
        internal.deinit();
        // The state block too, and no pointer left to it: a second deinit
        // must find nothing to free.
        state.own._internal = null;
        const Arena = runtime.ArenaAllocator;
        if (Arena.tryGet() catch null) |arena| arena.destroy(InternalState, internal);
    } else {
        log.debug("[HTMLIFrameElement.deinit] instance={*} -> No internal state", .{instance});
    }
    // Chain to parent class cleanup
    const HTMLElementImpl = @import("HTMLElement.zig");
    HTMLElementImpl.deinit(instance);
}

/// Constructor implementation
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &HTMLIFrameElement.vtable, ctx);
    errdefer deinit(instance);
    return instance;
}

// ============================================================================
// Content Accessors (§4.8.5)
// ============================================================================

/// IFrameIntegration's `retired_realm_destroy`: a context retired when its
/// iframe was inserted again is destroyed with the integration.
fn destroyRetiredRealm(data: *anyopaque, allocator: std.mem.Allocator) void {
    const entry: *context_manager.ContextEntry = @ptrCast(@alignCast(data));
    context_manager.destroyChildContext(entry, allocator);
}

/// Cleanup callback for iframe context
/// Called when the iframe is removed from the document to clean up V8 resources
fn iframeContextCleanup(integration: *IFrameIntegration) void {
    if (integration.context_cleanup_data) |data| {
        const entry: *context_manager.ContextEntry = @ptrCast(@alignCast(data));
        // Clear the cleanup data BEFORE calling destroyChildContext to prevent
        // any re-entrant calls from trying to use this stale pointer.
        // destroyChildContext() has its own guards against double-cleanup.
        integration.context_cleanup_data = null;
        context_manager.destroyChildContext(entry, integration.allocator);
    }
}

/// Parse an origin string (e.g., "http://localhost:8000") into an Origin struct.
/// Returns an opaque origin for invalid or "null" strings.
fn parseOriginFromString(origin_str: []const u8) Origin {
    // "null" means opaque origin
    if (std.mem.eql(u8, origin_str, "null")) {
        return Origin.createOpaque();
    }

    // Parse "http://host:port" format
    if (std.mem.startsWith(u8, origin_str, "http://")) {
        const rest = origin_str[7..]; // Skip "http://"
        const host_port_end = std.mem.indexOf(u8, rest, "/") orelse rest.len;
        const host_port = rest[0..host_port_end];

        // Check for port
        if (std.mem.lastIndexOf(u8, host_port, ":")) |colon_idx| {
            const host = host_port[0..colon_idx];
            const port_str = host_port[colon_idx + 1 ..];
            const port = std.fmt.parseInt(u16, port_str, 10) catch 80;
            return Origin.init("http", host, port);
        }
        return Origin.init("http", host_port, 80);
    }

    // Parse "https://host:port" format
    if (std.mem.startsWith(u8, origin_str, "https://")) {
        const rest = origin_str[8..]; // Skip "https://"
        const host_port_end = std.mem.indexOf(u8, rest, "/") orelse rest.len;
        const host_port = rest[0..host_port_end];

        // Check for port
        if (std.mem.lastIndexOf(u8, host_port, ":")) |colon_idx| {
            const host = host_port[0..colon_idx];
            const port_str = host_port[colon_idx + 1 ..];
            const port = std.fmt.parseInt(u16, port_str, 10) catch 443;
            return Origin.init("https", host, port);
        }
        return Origin.init("https", host_port, 443);
    }

    // Unknown format - return opaque
    return Origin.createOpaque();
}

/// Document creation callback for iframe navigation
/// Called when navigateToSrcDoc or navigateToSrc needs to create a Document instance.
/// Parameters: (runtime_context, browsing_context) -> document_instance
fn createDocumentForIframe(runtime_ctx_ptr: ?*anyopaque, browsing_ctx_ptr: *html_core.BrowsingContext) ?*anyopaque {
    const runtime_ctx: runtime.Context = @ptrCast(@alignCast(runtime_ctx_ptr orelse {
        return null;
    }));
    const allocator = runtime_ctx.allocator;

    // Create a Document instance using the WebIDL interface
    const document_instance = interfaces.Document.init(allocator, runtime_ctx) catch {
        return null;
    };
    // HTML "create a new browsing context and document" step 15: the initial
    // about:blank document's type is "html" and its content type
    // "text/html". Set before the elements below are created, which it makes
    // HTML elements.
    document_internals.setDocumentType(document_instance, .html) catch {};
    document_internals.setContentType(document_instance, "text/html") catch {};

    // Per HTML spec, about:blank documents must have a basic HTML structure:
    // <html><head></head><body></body></html>
    // This is required because browsers always create these elements for any HTML document.
    const DocumentImpl = @import("Document.zig");
    const NodeImpl = @import("Node.zig");

    // Create html element (HTMLHtmlElement)
    const html_element = DocumentImpl.call_createElement(
        document_instance,
        runtime.DOMString.initInterned("html"),
        webidl.Opt(runtime.JSValue).notPassed(),
    ) catch {
        return document_instance; // Continue with empty document if element creation fails
    };

    // Create head element (HTMLHeadElement)
    const head_element = DocumentImpl.call_createElement(
        document_instance,
        runtime.DOMString.initInterned("head"),
        webidl.Opt(runtime.JSValue).notPassed(),
    ) catch {
        return document_instance;
    };

    // Create body element (HTMLBodyElement)
    const body_element = DocumentImpl.call_createElement(
        document_instance,
        runtime.DOMString.initInterned("body"),
        webidl.Opt(runtime.JSValue).notPassed(),
    ) catch {
        return document_instance;
    };

    // Append head to html
    _ = NodeImpl.call_appendChild(html_element, head_element) catch {
        return document_instance;
    };

    // Append body to html
    _ = NodeImpl.call_appendChild(html_element, body_element) catch {
        return document_instance;
    };

    // Append html to document
    _ = NodeImpl.call_appendChild(document_instance, html_element) catch {
        return document_instance;
    };

    // Set the document element (html) on the Document
    DocumentImpl.setDocumentElement(document_instance, html_element);

    // Create the V8 wrapper for the Document in the child context.
    // This is critical for cross-context access: when the parent context accesses
    // iframe.contentDocument, we return this pre-created wrapper instead of creating
    // a new one in the parent context. This avoids callback corruption issues where
    // the callbacks are registered for the wrong context.
    const child_v8_ctx: *v8.ffi.Context = @ptrCast(@alignCast(runtime_ctx.engine_ctx orelse {
        return null;
    }));

    // Get the current isolate
    const isolate = v8.ffi.v8_Isolate_GetCurrent() orelse {
        return null;
    };

    // Enter the child context to create the wrapper
    v8.ffi.v8_Context_Enter(child_v8_ctx);
    defer v8.ffi.v8_Context_Exit(child_v8_ctx);

    // Create the V8 wrapper in the child context using template_registry
    const v8_wrapper = v8.template_registry.wrapInstanceAsV8Object(
        document_instance,
        "Document",
        isolate,
        child_v8_ctx,
    ) catch {
        // Continue without wrapper - will create on demand (may have issues)
        return document_instance;
    };

    // Store the wrapper on the Document for cross-context access
    DocumentImpl.setBoundV8Wrapper(document_instance, v8_wrapper);

    // Get the active window for this browsing context to associate with the document
    if (browsing_ctx_ptr.getActiveWindow()) |window_ptr| {
        // Set the document on the browsing context
        browsing_ctx_ptr.setActiveDocument(document_instance, window_ptr);

        // Also set the document on the Window
        const WindowImpl = @import("Window.zig");
        const window_instance: *runtime.Instance = @ptrCast(@alignCast(window_ptr));
        WindowImpl.setDocument(window_instance, document_instance);
        // Set the defaultView on the document (bidirectional Document <-> Window link)
        DocumentImpl.setDefaultView(document_instance, window_instance);
    }

    return document_instance;
}

/// Parse HTML content into a Document for iframe navigation.
/// This uses DomTreeAdapter to properly populate the document with parsed content
/// that JavaScript can access via DOM APIs like getElementById(), querySelector(), etc.
/// Parameters: (runtime_context, browsing_context, html_content) -> document_instance
fn parseHtmlForIframe(runtime_ctx_ptr: ?*anyopaque, browsing_ctx_ptr: *html_core.BrowsingContext, html_content: []const u8) ?*anyopaque {
    const time_start = clock.monotonicNanos();
    log.debug("[parseHtmlForIframe] time={d}ns START content_len={d}", .{ time_start, html_content.len });

    const runtime_ctx: runtime.Context = @ptrCast(@alignCast(runtime_ctx_ptr orelse {
        return null;
    }));
    const allocator = runtime_ctx.allocator;

    // Get window BEFORE parsing for nested iframe support
    const window_instance: ?*runtime.Instance = if (browsing_ctx_ptr.getActiveWindow()) |window_ptr|
        @ptrCast(@alignCast(window_ptr))
    else
        null;

    // CRITICAL: Check sandbox flags to determine if scripting is enabled.
    // Per HTML spec §4.8.5, when an iframe has the sandbox attribute:
    // - If empty (sandbox=""), ALL restrictions apply including script blocking
    // - If sandbox="allow-scripts", scripts are allowed to execute
    // The BrowsingContext.allowsScripts() method encapsulates this check.
    const scripting_enabled = browsing_ctx_ptr.allowsScripts();

    // HTML "create and initialize a Document object" step 9: a new Document
    // whose type is "html" and content type "text/html" ("load an HTML
    // document"); step 10: the window's associated Document becomes it. Both
    // happen before the parser exists, so the page's own scripts - run BY the
    // parser - see the document they are in. Associating it only once
    // parsing finished left those scripts on the frame's initial about:blank
    // document: their getElementsByTagName, createElement and body were that
    // document's.
    const document_instance = interfaces.Document.init(allocator, runtime_ctx) catch return null;
    document_internals.setDocumentType(document_instance, .html) catch {};
    document_internals.setContentType(document_instance, "text/html") catch {};

    const DocumentImpl = @import("Document.zig");
    if (window_instance) |window_inst| {
        browsing_ctx_ptr.setActiveDocument(document_instance, window_inst);
        const WindowImpl = @import("Window.zig");
        WindowImpl.setDocument(window_inst, document_instance);
        DocumentImpl.setDefaultView(document_instance, window_inst);
    } else {
        log.debug("[parseHtmlForIframe] BC={*} WARNING: No active window, document {*} will NOT be linked!", .{ browsing_ctx_ptr, document_instance });
    }

    // The scripted parser builds the tree incrementally through the
    // DomTreeAdapter, so scripts can reach nodes already parsed.
    log.debug("[parseHtmlForIframe] time={d}ns calling parseHTMLWithScripting", .{clock.monotonicNanos()});
    _ = scripted_parser.parseHTMLWithScripting(
        allocator,
        runtime_ctx,
        html_content,
        .{ .scripting_enabled = scripting_enabled, .window = window_instance, .document = document_instance },
    ) catch |err| {
        // The document stays - with whatever was parsed - as the frame's
        // document: a parse that fails part-way is still the page loaded.
        log.warn("[parseHtmlForIframe] parsing stopped: {}", .{err});
    };
    log.debug("[parseHtmlForIframe] time={d}ns parseHTMLWithScripting DONE", .{clock.monotonicNanos()});

    // HTML "the end": readiness "interactive" now the parser has stopped,
    // then DOMContentLoaded, readiness "complete", load at the window and
    // pageshow as tasks - the last of which queues the iframe's own load
    // ("completely finish loading"), after everything the page posted.
    dom_module.document_lifecycle.parsingStopped(document_instance);
    // "The end" step 5: run the list of scripts that will execute when the
    // document has finished parsing - every `defer` script and every
    // parser-inserted module script. The frame's parse never did, so no
    // module script in a frame ever ran.
    if (scripting_enabled) {
        html_module.script_execution.executeScriptsWhenParsingFinished(allocator, document_instance);
    }
    dom_module.document_lifecycle.finishLoading(document_instance);

    // Create the V8 wrapper for the Document in the child context.
    // This is critical for cross-context access: when the parent context accesses
    // iframe.contentDocument, we return this pre-created wrapper instead of creating
    // a new one in the parent context.
    const child_v8_ctx: *v8.ffi.Context = @ptrCast(@alignCast(runtime_ctx.engine_ctx orelse {
        return document_instance;
    }));

    // Get the current isolate
    const isolate = v8.ffi.v8_Isolate_GetCurrent() orelse {
        return document_instance;
    };

    // Enter the child context to create the wrapper
    v8.ffi.v8_Context_Enter(child_v8_ctx);
    defer v8.ffi.v8_Context_Exit(child_v8_ctx);

    // Create the V8 wrapper in the child context using template_registry
    const v8_wrapper = v8.template_registry.wrapInstanceAsV8Object(
        document_instance,
        "Document",
        isolate,
        child_v8_ctx,
    ) catch {
        // Continue without wrapper - will create on demand (may have issues)
        return document_instance;
    };

    // Store the wrapper on the Document for cross-context access
    DocumentImpl.setBoundV8Wrapper(document_instance, v8_wrapper);

    return document_instance;
}

/// Script execution callback for iframes
/// Called by IFrameIntegration.executeScriptsInTree to execute scripts in the iframe's V8 context.
/// Parameters: (engine_context as v8.Context*, script_source) -> void
fn executeIframeScript(engine_ctx: ?*anyopaque, source: []const u8) void {
    const v8_ctx: *v8.ffi.Context = @ptrCast(@alignCast(engine_ctx orelse return));
    const isolate = v8.ffi.v8_Isolate_GetCurrent() orelse return;

    if (source.len == 0) return;

    // Enter the iframe's context for script execution
    v8.ffi.v8_Context_Enter(v8_ctx);
    defer v8.ffi.v8_Context_Exit(v8_ctx);

    // Create V8 string from source
    const source_str = v8.ffi.v8_String_NewFromUtf8(isolate, source.ptr, @intCast(source.len)) orelse return;
    defer v8.ffi.v8_String_Dispose(source_str);

    // Compile the script
    const compiled = v8.ffi.v8_Script_Compile(v8_ctx, source_str) orelse return;

    // Run the script
    _ = v8.ffi.v8_Script_Run(v8_ctx, compiled);

    // Run microtasks (for Promise resolution, etc.)
    v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);
}

/// HTML "shared attribute processing steps for iframe and frame elements",
/// steps 2-3: the `src` value encoding-parsed relative to the element's node
/// document; the empty string, or a value that does not parse, is
/// about:blank. Owned by the element's context allocator.
///
/// The raw attribute value used to go straight to the fetch, which cannot
/// fetch a relative URL, and the navigation failed silently - so an iframe
/// with `src="resources/x.html"` simply never loaded. That is most of WPT:
/// the 52 moving-between-documents files all waited on such a frame.
fn resolveSrc(instance: *runtime.Instance, src: []const u8) []const u8 {
    const allocator = instance.ctx.allocator;
    const blank = "about:blank";
    if (src.len == 0) return allocator.dupe(u8, blank) catch unreachable;
    const base = interfaces.Node.get_baseURI(instance) catch
        return allocator.dupe(u8, src) catch unreachable;
    defer allocator.free(base);
    const base_arg = if (base.len > 0)
        webidl.Opt(runtime.USVString).passed(base)
    else
        webidl.Opt(runtime.USVString).notPassed();
    const url = (interfaces.URL.call_static_parse(instance, src, base_arg) catch null) orelse
        return allocator.dupe(u8, blank) catch unreachable;
    defer runtime.Instance.deinit(url);
    return interfaces.URL.get_href(url) catch allocator.dupe(u8, blank) catch unreachable;
}

/// Location URL update callback for iframes
/// Called by IFrameIntegration.updateLocationUrl to set the iframe's Location URL.
/// Parameters: (engine_context as v8.Context*, url) -> void
fn updateIframeLocation(engine_ctx: ?*anyopaque, url: []const u8) void {
    const v8_ctx: *v8.ffi.Context = @ptrCast(@alignCast(engine_ctx orelse return));

    // Get Window from V8 context
    const window = context_manager.getWindowForContext(v8_ctx) orelse return;

    // Get Window's Location
    const WindowImpl = @import("Window.zig");
    const internal = WindowImpl.getInternal(window) orelse return;
    const location = internal.location orelse return;

    // Record it as the child context's document URL too - only top-level
    // pages and workers ever did, so `document.URL` inside an iframe was "".
    // Document.get_URL and, through it, Location read this.
    context_manager.setDocumentUrl(v8_ctx, url) catch {};

    // Update Location's URL
    const LocationImpl = @import("Location.zig");
    LocationImpl.setURLFromString(location, url) catch {};
}

// ============================================================================
// Navigating a content or auxiliary navigable (HTML §7.4.2 "navigate")
// ============================================================================
//
// Crane's navigable is an IFrameIntegration: an iframe's content navigable,
// or a window.open() popup, which has no container. "Navigate" runs its
// synchronous steps in the caller and everything the spec does "in parallel"
// as tasks on the navigable's event loop:
//
//   navigate()         steps 1-22: history handling, a fragment navigation
//                      (committed on the spot), the ongoing navigation, and
//                      a javascript: URL, which runs in a task of its own
//   runBeforeUnload    step 23.1: beforeunload at the active document
//   (the fetch)        step 23.9: about:, data: and file: answered at once,
//                      http(s) through the event loop's AsyncFetch
//   runCommit          "finalize a cross-document navigation" and the history
//                      step it applies: unload the active document and its
//                      descendants, then make the new document active and
//                      load it
//
// Every step finds its navigation by ID. One that finds another navigation
// ongoing - a later navigate() replaced it - or no record at all - its
// navigable went away - stops there. That is the spec's "ongoing navigation",
// and it is how a second navigation in the same task aborts the first.
//
// The design is Blink's (not its code): FrameLoader::StartNavigation commits
// a same-document navigation synchronously and hands everything else to the
// browser process to fetch; FrameLoader::CommitNavigation then detaches the
// old document - Document::DispatchUnloadEvents, pagehide, visibilitychange
// and unload in that order - before the new DocumentLoader commits.
//
// Deviation, stated: the new document keeps the navigable's Window. HTML
// "create and initialize a Document object" reuses the Window only for the
// initial about:blank document; otherwise it is a new realm. Until contexts
// can be recreated around the same global proxy, a navigated frame keeps its
// realm, and handlers on its window persist into the next document.

const navigate_steps = html_core.navigation.navigate_steps;
const navigation_fetch = html_core.navigation.fetch_integration;
const document_lifecycle = dom_module.document_lifecycle;
const fetch_mod = @import("fetch");

/// "Navigate"'s optional arguments that the callers here pass.
pub const NavigateOptions = struct {
    /// "sourceDocument": the document whose script (or element) navigates.
    source_document: ?*runtime.Instance = null,
    history_behavior: navigate_steps.HistoryBehavior = .auto,
    /// "documentResource" as a string: an iframe srcdoc document's markup.
    srcdoc: ?[]const u8 = null,
    initial_insertion: bool = false,
};

/// One navigation, from "navigate" step 19 until its document commits or it
/// is abandoned.
const Navigation = struct {
    id: u64,
    integration: *IFrameIntegration,
    allocator: std.mem.Allocator,
    url: []u8,
    srcdoc: ?[]u8 = null,
    history_handling: navigate_steps.HistoryHandling,
    initial_insertion: bool,
    /// The fetch in flight, until it answers.
    fetch: ?*fetch_mod.algorithms.AsyncFetch = null,
    /// What the fetch answered, until the commit takes it.
    response: ?navigation_fetch.NavigationFetchResult = null,

    fn destroy(self: *Navigation) void {
        // Terminating a fetch runs neither `done` nor `gone`.
        if (self.fetch) |f| f.terminate();
        if (self.response) |*r| r.deinit();
        if (self.srcdoc) |s| self.allocator.free(s);
        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }
};

/// Source of navigation IDs: never reused, never zero.
threadlocal var next_navigation_id: u64 = 1;

/// Every navigation in flight, by ID. A task holds only the ID, so a
/// navigation ended while its task waited is simply not found.
threadlocal var navigations: std.AutoHashMapUnmanaged(u64, *Navigation) = .empty;

fn navigationById(id: u64) ?*Navigation {
    return navigations.get(id);
}

/// End navigation `id`: aborted, superseded, or its navigable gone.
fn endNavigation(id: u64) void {
    const kv = navigations.fetchRemove(id) orelse return;
    kv.value.destroy();
}

/// HTML "set the ongoing navigation" (§7.4.2.5). The navigation it replaces
/// ends here - the spec lets it notice at its next step; ending it now also
/// cancels its fetch.
fn setOngoingNavigation(integration: *IFrameIntegration, value: navigate_steps.OngoingNavigation) void {
    // Step 1: "If navigable's ongoing navigation is equal to newValue, then return."
    if (integration.ongoing_navigation.eql(value)) return;
    // Step 2 (inform the navigation API) is not modelled.
    switch (integration.ongoing_navigation) {
        .id => |old| endNavigation(old),
        else => {},
    }
    // Step 3.
    integration.ongoing_navigation = value;
}

/// IFrameIntegration's abandon hook: the navigable is going, and so is its
/// navigation in flight.
fn abandonNavigationsOf(integration: *IFrameIntegration) void {
    setOngoingNavigation(integration, .none);
}

/// The navigable's active document, as its browsing context records it -
/// not `window.document`, which is script's getter and refuses a
/// cross-origin reader.
fn activeDocumentOf(integration: *IFrameIntegration) ?*runtime.Instance {
    const browsing_context = integration.browsing_context orelse return null;
    const document = browsing_context.getActiveDocument() orelse return null;
    return @ptrCast(@alignCast(document));
}

/// `document`'s URL, serialized and owned by `allocator`; "about:blank"
/// when there is no document to ask.
fn documentUrlOf(document: ?*runtime.Instance, allocator: std.mem.Allocator) ![]u8 {
    const doc = document orelse return allocator.dupe(u8, "about:blank");
    const url = interfaces.Document.get_URL(doc) catch return allocator.dupe(u8, "about:blank");
    defer doc.ctx.allocator.free(url);
    if (url.len == 0) return allocator.dupe(u8, "about:blank");
    return allocator.dupe(u8, url);
}

/// The origin of a serialized http(s) URL - "scheme://host[:port]" - or null
/// for any other scheme, whose origin is opaque or inherited.
fn tupleOriginOf(url: []const u8) ?[]const u8 {
    const scheme = navigate_steps.schemeOf(url);
    if (!std.mem.eql(u8, scheme, "http") and !std.mem.eql(u8, scheme, "https")) return null;
    const after = scheme.len + 3; // "://"
    if (url.len < after) return null;
    const end = std.mem.indexOfAnyPos(u8, url, after, "/?#") orelse url.len;
    return url[0..end];
}

/// Whether `source` - navigate's initiator - is same origin with `active`,
/// for step 12.1. Deviation, stated: compared by URL, so a document whose
/// origin is inherited (about:blank, srcdoc) or changed by document.domain
/// counts as same origin.
fn initiatorSameOrigin(source: ?*runtime.Instance, active_url: []const u8, allocator: std.mem.Allocator) bool {
    const doc = source orelse return true;
    const source_url = documentUrlOf(doc, allocator) catch return true;
    defer allocator.free(source_url);
    const a = tupleOriginOf(source_url) orelse return true;
    const b = tupleOriginOf(active_url) orelse return true;
    return std.mem.eql(u8, a, b);
}

/// HTML "navigate" `integration`'s navigable to `url` (serialized, absolute).
/// Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigate
///
/// Steps not modelled, stated: source snapshot params and sandboxed
/// navigation (1-7), the navigate event (21), deferred fetch quota (22),
/// WebDriver BiDi, and lazy loading (11).
pub fn navigate(integration: *IFrameIntegration, url: []const u8, options: NavigateOptions) void {
    // A navigable that is going, or never came: nothing to navigate.
    if (integration.state == .discarded) return;
    const browsing_context = integration.browsing_context orelse return;
    if (browsing_context.is_closed) return;
    const allocator = integration.allocator;
    const active = activeDocumentOf(integration);

    // Step 9: "If navigable's active document's unload counter is greater
    // than 0, then ... return."
    if (active) |doc| {
        if (document_lifecycle.isUnloading(doc)) return;
    }

    // Steps 12-13: history handling.
    const active_url = documentUrlOf(active, allocator) catch return;
    defer allocator.free(active_url);
    const history_handling = navigate_steps.resolveHistoryHandling(options.history_behavior, url, .{
        .url = active_url,
        .is_initial_about_blank = if (active) |doc| document_lifecycle.isInitialAboutBlank(doc) else false,
    }, initiatorSameOrigin(options.source_document, active_url, allocator));

    // Step 14: a fragment navigation commits now, in the same document.
    if (navigate_steps.isFragmentNavigation(url, active_url, options.srcdoc != null)) {
        navigateToFragment(integration, url, active_url);
        return;
    }

    // Step 15: "If navigable's parent is non-null, then set navigable's is
    // delaying load events to true." A popup has no parent.
    if (integration.iframe_element != null) integration.delaying_load = true;

    // Step 18: a navigable that is traversing ignores navigations. Nothing
    // traverses yet, so this never holds.
    if (integration.ongoing_navigation == .traversal) return;

    // Step 7's navigation ID, and step 19: set the ongoing navigation - which
    // ends any earlier one.
    const id = next_navigation_id;
    next_navigation_id += 1;
    setOngoingNavigation(integration, .{ .id = id });

    const record = allocator.create(Navigation) catch return;
    record.* = .{
        .id = id,
        .integration = integration,
        .allocator = allocator,
        .url = allocator.dupe(u8, url) catch {
            allocator.destroy(record);
            return;
        },
        .history_handling = history_handling,
        .initial_insertion = options.initial_insertion,
    };
    if (options.srcdoc) |html| {
        record.srcdoc = allocator.dupe(u8, html) catch {
            record.destroy();
            return;
        };
    }
    navigations.put(std.heap.page_allocator, id, record) catch {
        record.destroy();
        return;
    };

    // Step 20: a javascript: URL runs in a task, not the caller.
    if (navigate_steps.isJavascript(url)) {
        queueNavigationTask(integration, id, &runJavascriptNavigation);
        return;
    }
    // Step 23: "In parallel": beforeunload, then the fetch.
    queueNavigationTask(integration, id, &runBeforeUnload);
}

/// Queue `callback` for navigation `id` on the navigable's event loop - a
/// global task on the navigation and traversal task source. With no loop (a
/// context built for tests) it runs now.
fn queueNavigationTask(integration: *IFrameIntegration, id: u64, callback: *const fn (?*anyopaque) void) void {
    const context: ?*anyopaque = @ptrFromInt(id);
    const runtime_ctx: runtime.Context = @ptrCast(@alignCast(integration.runtime_context orelse return callback(context)));
    const loop = runtime_ctx.getOptionalEventLoop() orelse return callback(context);
    loop.queueTask(.{ .callback = callback, .context = context });
}

fn idOf(context: ?*anyopaque) u64 {
    return @intFromPtr(context);
}

/// Whether navigation `id` is still `integration`'s ongoing navigation.
fn isOngoing(integration: *IFrameIntegration, id: u64) bool {
    return integration.ongoing_navigation.eql(.{ .id = id });
}

/// The runtime context of `integration`'s content navigable, if it has one.
fn navigableContext(integration: *IFrameIntegration) ?runtime.Context {
    return @ptrCast(@alignCast(integration.runtime_context orelse return null));
}

/// Step 23.1: "checking if unloading is canceled" for the active document's
/// inclusive descendant navigables - beforeunload at each, parents first.
/// Step 23.2: canceled, or navigated again meanwhile, and this navigation
/// ends. Step 23.3 (abort the active document) is not modelled.
fn runBeforeUnload(context: ?*anyopaque) void {
    const id = idOf(context);
    const record = navigationById(id) orelse return;
    const integration = record.integration;
    if (!isOngoing(integration, id)) return endNavigation(id);

    if (activeDocumentOf(integration)) |document| {
        var canceled = false;
        var documents = collectInclusiveDescendantDocuments(document, integration.allocator);
        defer documents.deinit(integration.allocator);
        for (documents.items) |entry| {
            if (runtime.SlabAllocator.generationOf(entry.document) != entry.generation) continue;
            if (document_lifecycle.fireBeforeUnload(entry.document).canceled) canceled = true;
        }
        // The handlers ran script: a later navigation replaces this one -
        // and ends its record - and a navigable taken away ends it too.
        const again = navigationById(id) orelse return;
        if (canceled) {
            setOngoingNavigation(again.integration, .none);
            endLoadDelay(again.integration);
            return;
        }
    }
    startFetch(navigationById(id) orelse return);
}

/// Step 23.9: "attempt to populate the history entry's document" - its fetch.
/// about:blank, srcdoc, data: and file: are answered without the network and
/// committed by a task; http(s) goes to the network through the event loop.
fn startFetch(record: *Navigation) void {
    const allocator = record.allocator;
    const url = record.url;

    if (record.srcdoc) |html| {
        record.response = htmlResponse(allocator, "about:srcdoc", html) catch navigation_fetch.networkErrorResult(allocator, url) catch return endNavigation(record.id);
        return queueNavigationTask(record.integration, record.id, &runCommit);
    }
    if (navigate_steps.matchesAboutBlank(url)) {
        record.response = htmlResponse(allocator, url, "") catch navigation_fetch.networkErrorResult(allocator, url) catch return endNavigation(record.id);
        return queueNavigationTask(record.integration, record.id, &runCommit);
    }

    const scheme = navigate_steps.schemeOf(url);
    if (std.mem.eql(u8, scheme, "http") or std.mem.eql(u8, scheme, "https")) {
        const request = navigation_fetch.navigationRequest(allocator, url, .{
            .destination = if (record.integration.iframe_element != null) .iframe else .document,
            .mode = .navigate,
            .redirect = .follow,
        }) catch {
            record.response = navigation_fetch.networkErrorResult(allocator, url) catch return endNavigation(record.id);
            return queueNavigationTask(record.integration, record.id, &runCommit);
        };
        const client: fetch_mod.algorithms.AsyncFetch.Client = .{
            .context = @ptrFromInt(record.id),
            .done = &fetchDone,
            .alive = &fetchAlive,
            .gone = &fetchGone,
        };
        record.fetch = fetch_mod.algorithms.AsyncFetch.start(allocator, request, .{}, fetch_mod.network.scheduler.threadScheduler(), client) catch {
            // The fetch owned the request, and freed it.
            record.response = navigation_fetch.networkErrorResult(allocator, url) catch return endNavigation(record.id);
            return queueNavigationTask(record.integration, record.id, &runCommit);
        };
        return;
    }

    // Everything else this engine can load without the network.
    record.response = navigation_fetch.fetchNavigationResource(allocator, url, .{
        .destination = .iframe,
        .mode = .navigate,
        .redirect = .follow,
    }) catch navigation_fetch.networkErrorResult(allocator, url) catch return endNavigation(record.id);
    queueNavigationTask(record.integration, record.id, &runCommit);
}

/// A response made of `html`, as a fetch would have answered it.
fn htmlResponse(allocator: std.mem.Allocator, url: []const u8, html: []const u8) !navigation_fetch.NavigationFetchResult {
    var result = navigation_fetch.NavigationFetchResult.init(allocator);
    errdefer result.deinit();
    result.final_url = try allocator.dupe(u8, url);
    result.content_type = try allocator.dupe(u8, "text/html;charset=utf-8");
    result.body = try allocator.dupe(u8, html);
    result.status = 200;
    result.ok = true;
    result.is_network_error = false;
    return result;
}

/// Whether the navigation that started a fetch is still there to hear it:
/// its record, and the realm of its navigable. A page torn down with the
/// fetch in flight retires its contexts, and Fetch's "terminate a fetch
/// group" ends the fetch at the next sweep.
fn fetchAlive(context: *anyopaque) bool {
    const record = navigationById(@intFromPtr(context)) orelse return false;
    const ctx = navigableContext(record.integration) orelse return false;
    return ctx.engine_ctx != null;
}

/// The fetch was terminated because its navigation's realm went: the
/// navigation ends with it.
fn fetchGone(context: *anyopaque) void {
    const id = @intFromPtr(context);
    const record = navigationById(id) orelse return;
    record.fetch = null;
    endNavigation(id);
}

/// The navigation fetch answered (from the event loop's network step):
/// keep the response and queue the task that commits it.
fn fetchDone(context: *anyopaque, outcome: fetch_mod.algorithms.FetchError!fetch_mod.algorithms.FetchResult) void {
    const id = @intFromPtr(context);
    var result = outcome catch null;
    defer if (result) |*r| r.deinit();
    const record = navigationById(id) orelse return;
    record.fetch = null;
    record.response = if (result) |r|
        navigation_fetch.resultFromResponse(record.allocator, record.url, r.response, .{}) catch null
    else
        null;
    if (record.response == null) {
        record.response = navigation_fetch.networkErrorResult(record.allocator, record.url) catch return endNavigation(id);
    }
    queueNavigationTask(record.integration, id, &runCommit);
}

/// The task that ends a navigation with a response: HTML "finalize a
/// cross-document navigation" and the history step it applies. Unload the
/// active document and its descendants, then create the new document, make
/// it active, and load it.
fn runCommit(context: ?*anyopaque) void {
    const id = idOf(context);
    const kv = navigations.fetchRemove(id) orelse return;
    const record = kv.value;
    defer record.destroy();
    const integration = record.integration;
    if (!isOngoing(integration, id)) return;
    const response = if (record.response) |*r| r else return;

    // A 204, a 205 or a download commits no document: the navigable keeps
    // the one it has, and no load event is owed. Decided before anything is
    // unloaded.
    if (!integration.responseMakesDocument(response)) {
        integration.ongoing_navigation = .none;
        endLoadDelay(integration);
        return;
    }

    // Script runs below and may take the iframe away; the integration stays
    // until this is done with it - and is freed, if it has to be, only after
    // the realm scope below has been left.
    integration.busy += 1;
    defer finishBusy(integration);
    commitNavigation(integration, record, response);
}

/// `runCommit`'s work, inside the navigable's realm.
fn commitNavigation(integration: *IFrameIntegration, record: *Navigation, response: *navigation_fetch.NavigationFetchResult) void {
    const ctx = navigableContext(integration) orelse return endLoadDelay(integration);
    // The document's scripts and unload handlers run from the event loop,
    // not from script: the navigable's realm is entered here.
    const scope = v8.JsScope.init(ctx) orelse return endLoadDelay(integration);
    defer scope.deinit();

    // "Deactivate a document for a cross-document navigation" step 5.2: the
    // ongoing navigation is null - new navigations may start.
    integration.ongoing_navigation = .none;

    // Step 5.3: "Unload a document and its descendants".
    if (activeDocumentOf(integration)) |old| unloadDocumentAndDescendants(old, integration);
    if (integration.state == .discarded or integration.browsing_context == null) return;

    integration.commitResponse(record.url, response) catch |err| {
        log.debug("[navigation] commit of {s} failed: {s}", .{ record.url, @errorName(err) });
        endLoadDelay(integration);
        return;
    };
    loadEventStepsIfNothingWill(integration);
}

/// A document that never goes through the parser - an XML document, which
/// has no parser yet - has no "the end" to finish loading it, so nothing
/// would run its container's load event steps. Run them now.
fn loadEventStepsIfNothingWill(integration: *IFrameIntegration) void {
    const document = activeDocumentOf(integration) orelse return endLoadDelay(integration);
    const readiness = interfaces.Document.get_readyState(document) catch return;
    if (readiness != ._loading_) return;
    const element: *runtime.Instance = @ptrCast(@alignCast(integration.iframe_element orelse return endLoadDelay(integration)));
    runIframeLoadEventSteps(element);
}

/// "Unload a document and its descendants": its child navigables' documents
/// first, then `document`. Their navigations in flight end with them, and
/// their windows' timers stop ("unloading document cleanup steps" 4.2).
fn unloadDocumentAndDescendants(document: *runtime.Instance, integration: *IFrameIntegration) void {
    var documents = collectInclusiveDescendantDocuments(document, integration.allocator);
    defer documents.deinit(integration.allocator);
    // Children first: the list is parents-first, so walk it backwards.
    var i = documents.items.len;
    while (i > 0) {
        i -= 1;
        const entry = documents.items[i];
        if (runtime.SlabAllocator.generationOf(entry.document) != entry.generation) continue;
        if (entry.integration) |child| {
            if (child != integration) abandonNavigationsOf(child);
        }
        document_lifecycle.unload(entry.document);
    }
    if (integration.engine_context) |engine_ctx| {
        context_manager.cleanUpChildWindows(@ptrCast(@alignCast(engine_ctx)));
    }
}

const DocumentEntry = struct {
    document: *runtime.Instance,
    generation: u64,
    /// The navigable whose active document this is; null for the root.
    integration: ?*IFrameIntegration,
};

/// `document` and the active documents of its descendant navigables, parents
/// first - HTML "inclusive descendant navigables" by their active documents.
/// Each is held with its slab generation, since script runs between the
/// collection and the use.
fn collectInclusiveDescendantDocuments(document: *runtime.Instance, allocator: std.mem.Allocator) std.ArrayListUnmanaged(DocumentEntry) {
    var out: std.ArrayListUnmanaged(DocumentEntry) = .empty;
    out.append(allocator, .{ .document = document, .generation = runtime.SlabAllocator.generationOf(document), .integration = null }) catch return out;
    var index: usize = 0;
    while (index < out.items.len and out.items.len < 256) : (index += 1) {
        const parent = out.items[index].document;
        var iframes = iframesIn(parent, allocator);
        defer iframes.deinit(allocator);
        for (iframes.items) |iframe| {
            const internal = getInternal(iframe) orelse continue;
            const child = activeDocumentOf(internal.integration) orelse continue;
            out.append(allocator, .{
                .document = child,
                .generation = runtime.SlabAllocator.generationOf(child),
                .integration = internal.integration,
            }) catch break;
        }
    }
    return out;
}

/// The iframe elements in `document`, in tree order.
fn iframesIn(document: *runtime.Instance, allocator: std.mem.Allocator) std.ArrayListUnmanaged(*runtime.Instance) {
    var out: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    const NodeImpl = @import("Node.zig");
    const node_internal = NodeImpl.getInternalState(document) orelse return out;
    const root = node_internal.node_base orelse return out;
    collectIframes(root, &out, allocator, 0);
    return out;
}

fn collectIframes(node: *NodeBase, out: *std.ArrayListUnmanaged(*runtime.Instance), allocator: std.mem.Allocator, depth: usize) void {
    if (depth > 512) return;
    for (node.child_nodes.items()) |child| {
        if (child.node_type == 1 and std.ascii.eqlIgnoreCase(child.node_name, "iframe")) {
            if (instance_bridge.getInstance(child)) |ptr| {
                const instance: *runtime.Instance = @ptrCast(@alignCast(ptr));
                if (instance.stateAs(State) != null) out.append(allocator, instance) catch return;
            }
        }
        collectIframes(child, out, allocator, depth + 1);
    }
}

/// HTML "navigate to a fragment" (§7.4.2.3.3) - synchronous: the document's
/// URL changes now, and hashchange is queued if the fragment did.
///
/// Not modelled, stated: the navigate event (steps 1-5), the session history
/// entry and history object (6-11, 13, 16-17: item 3 of the navigation
/// work), and scrolling (15: no layout).
fn navigateToFragment(integration: *IFrameIntegration, url: []const u8, old_url: []const u8) void {
    // Step 12: "Set navigable's active document's URL to url."
    integration.setDocumentUrl(url);
    // Step 14, "update document for history step application" step 6.4.5:
    // "If oldURL's fragment is not equal to entry's URL's fragment, then
    // queue a global task ... to fire an event named hashchange".
    const old_fragment = navigate_steps.fragmentOf(old_url);
    const new_fragment = navigate_steps.fragmentOf(url);
    const same = if (old_fragment) |a| (if (new_fragment) |b| std.mem.eql(u8, a, b) else false) else new_fragment == null;
    if (!same) queueHashChange(integration, old_url, url);
}

/// A queued hashchange: the window it fires at, held with its slab
/// generation, and the two URLs, owned.
const HashChange = struct {
    window: *runtime.Instance,
    generation: u64,
    old_url: []u8,
    new_url: []u8,
    allocator: std.mem.Allocator,

    fn destroy(self: *HashChange) void {
        self.allocator.free(self.old_url);
        self.allocator.free(self.new_url);
        self.allocator.destroy(self);
    }
};

fn queueHashChange(integration: *IFrameIntegration, old_url: []const u8, new_url: []const u8) void {
    const browsing_context = integration.browsing_context orelse return;
    const window: *runtime.Instance = @ptrCast(@alignCast(browsing_context.getActiveWindow() orelse return));
    const allocator = integration.allocator;
    const task = allocator.create(HashChange) catch return;
    task.* = .{
        .window = window,
        .generation = runtime.SlabAllocator.generationOf(window),
        .old_url = allocator.dupe(u8, old_url) catch {
            allocator.destroy(task);
            return;
        },
        .new_url = allocator.dupe(u8, new_url) catch {
            allocator.free(task.old_url);
            allocator.destroy(task);
            return;
        },
        .allocator = allocator,
    };
    const loop = window.ctx.getOptionalEventLoop() orelse return runHashChange(task);
    loop.queueTask(.{ .callback = &runHashChange, .context = task, .drop = &dropHashChange });
}

fn dropHashChange(context: ?*anyopaque) void {
    const task: *HashChange = @ptrCast(@alignCast(context orelse return));
    task.destroy();
}

fn runHashChange(context: ?*anyopaque) void {
    const task: *HashChange = @ptrCast(@alignCast(context orelse return));
    defer task.destroy();
    if (runtime.SlabAllocator.generationOf(task.window) != task.generation) return;
    const scope = v8.JsScope.init(task.window.ctx) orelse return;
    defer scope.deinit();
    const event = interfaces.HashChangeEvent.call_constructor(
        task.window.ctx,
        runtime.DOMString.initInterned("hashchange"),
        webidl.Opt(dictionaries.HashChangeEventInit).passed(.{ .base = .{}, .oldURL = task.old_url, .newURL = task.new_url }),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = interfaces.EventTarget.call_dispatchEvent(task.window, event) catch {};
    event.releaseIfUnwrapped(generation);
}

/// HTML "navigate to a javascript: URL" (§7.4.2.3.2), as its task.
///
/// Steps 3-5 (the initiator's origin, CSP) are not modelled. The new
/// document's origin is the container's, not the initiator's - the same
/// when, as in every case this engine reaches, the page navigates its own
/// frame.
fn runJavascriptNavigation(context: ?*anyopaque) void {
    const id = idOf(context);
    const kv = navigations.fetchRemove(id) orelse return;
    const record = kv.value;
    defer record.destroy();
    const integration = record.integration;
    if (!isOngoing(integration, id)) return;
    // Step 2: "Set the ongoing navigation for targetNavigable to null."
    integration.ongoing_navigation = .none;

    integration.busy += 1;
    defer finishBusy(integration);
    javascriptNavigation(integration, record);
}

/// `runJavascriptNavigation`'s work, inside the navigable's realm.
fn javascriptNavigation(integration: *IFrameIntegration, record: *Navigation) void {
    const ctx = navigableContext(integration) orelse return endLoadDelay(integration);
    const scope = v8.JsScope.init(ctx) orelse return endLoadDelay(integration);
    defer scope.deinit();

    // Step 6: "evaluate a javascript: URL".
    const result = evaluateJavascriptUrl(integration, record.url);
    const html = result orelse {
        // Step 7: no new document. On initial insertion into an initial
        // about:blank document, the iframe load event steps still run.
        const initial = if (activeDocumentOf(integration)) |doc| document_lifecycle.isInitialAboutBlank(doc) else false;
        if (record.initial_insertion and initial) {
            if (integration.iframe_element) |element| return runIframeLoadEventSteps(@ptrCast(@alignCast(element)));
        }
        endLoadDelay(integration);
        return;
    };
    defer integration.allocator.free(html);
    if (integration.state == .discarded or integration.browsing_context == null) return;

    // Steps 9-12: the new document's URL is the active entry's URL - a
    // javascript: URL is never a document's URL.
    const active = activeDocumentOf(integration);
    const url = documentUrlOf(active, integration.allocator) catch return endLoadDelay(integration);
    defer integration.allocator.free(url);
    if (active) |old| unloadDocumentAndDescendants(old, integration);
    if (integration.state == .discarded or integration.browsing_context == null) return;
    // Step 17 ("load an HTML document" given the result as its body).
    integration.commitHtmlAt(url, html, integration.container_origin) catch return endLoadDelay(integration);
}

/// HTML "evaluate a javascript: URL" steps 1-10: the script is the URL after
/// "javascript:", percent-decoded, run as a classic script in the navigable's
/// realm. Its completion value, if it is a String, is the new document's
/// markup (owned); anything else - or a throw - is null.
fn evaluateJavascriptUrl(integration: *IFrameIntegration, url: []const u8) ?[]u8 {
    const allocator = integration.allocator;
    const v8_ctx: *v8.ffi.Context = @ptrCast(@alignCast(integration.engine_context orelse return null));
    const isolate = v8.ffi.v8_Isolate_GetCurrent() orelse return null;
    // Steps 1-3: strip the scheme, percent-decode.
    const encoded = url["javascript:".len..];
    const source = percentDecode(allocator, encoded) catch return null;
    defer allocator.free(source);

    const source_str = v8.ffi.v8_String_NewFromUtf8(isolate, source.ptr, @intCast(source.len)) orelse return null;
    defer v8.ffi.v8_String_Dispose(source_str);
    const script = v8.ffi.v8_Script_Compile(v8_ctx, source_str) orelse return null;
    defer v8.ffi.v8_Script_Dispose(script);
    // Step 7: run it. A throw is reported by the safe runner's TryCatch and
    // is not a String.
    const run = v8.ffi.v8_Script_Run_Safe(v8_ctx, script);
    defer v8.ffi.v8_FreeScriptRunResult(run);
    if (run.error_info != null) return null;
    const value = run.value orelse return null;
    // Step 9: only a String replaces the document.
    if (!v8.ffi.v8_Value_IsString(value)) return null;
    const string = v8.ffi.v8_Value_ToString(value, v8_ctx) orelse return null;
    defer v8.ffi.v8_String_Dispose(string);
    const length = v8.ffi.v8_String_Utf8Length(string);
    if (length < 0) return null;
    const buffer = allocator.alloc(u8, @as(usize, @intCast(length)) + 1) catch return null;
    defer allocator.free(buffer);
    const written = v8.helpers.writtenUtf8(buffer, v8.ffi.v8_String_WriteUtf8(string, buffer.ptr, @intCast(buffer.len))) orelse return null;
    return allocator.dupe(u8, written) catch null;
}

fn percentDecode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    var i: usize = 0;
    while (i < input.len) {
        if (input[i] == '%' and i + 2 < input.len) {
            if (std.fmt.parseInt(u8, input[i + 1 .. i + 3], 16)) |byte| {
                try out.append(allocator, byte);
                i += 3;
                continue;
            } else |_| {}
        }
        try out.append(allocator, input[i]);
        i += 1;
    }
    return out.toOwnedSlice(allocator);
}

/// The script behind `integration.busy` is done with the integration; if its
/// element was deinited meanwhile, the deinit it put off happens now.
fn finishBusy(integration: *IFrameIntegration) void {
    integration.busy -= 1;
    if (integration.busy == 0 and integration.deinit_pending) destroyIntegration(integration);
}

/// Deinit `integration` and return its block to the arena it came from.
fn destroyIntegration(integration: *IFrameIntegration) void {
    integration.deinit();
    const Arena = runtime.ArenaAllocator;
    if (Arena.tryGet() catch null) |arena| arena.destroy(IFrameIntegration, integration);
}

// ----------------------------------------------------------------------------
// Delaying the container document's load event (HTML §4.8.5)
// ----------------------------------------------------------------------------

/// The navigable stops delaying its container document's load event: its
/// navigation finished (the iframe load event steps ran) or ended without a
/// document. The container document may be waiting on it.
fn endLoadDelay(integration: *IFrameIntegration) void {
    if (!integration.delaying_load) return;
    integration.delaying_load = false;
    const element: *runtime.Instance = @ptrCast(@alignCast(integration.iframe_element orelse return));
    const NodeImpl = @import("Node.zig");
    const document = NodeImpl.getOwnerDocument(element) orelse return;
    document_lifecycle.loadDelayMayHaveEnded(document);
}

/// dom.content_navigables: whether an iframe in `document` delays its load
/// event - its content navigable is navigating, and has not yet run the
/// iframe load event steps for it.
fn iframesDelayLoadEvent(document: *runtime.Instance) bool {
    var iframes = iframesIn(document, std.heap.page_allocator);
    defer iframes.deinit(std.heap.page_allocator);
    for (iframes.items) |iframe| {
        const internal = getInternal(iframe) orelse continue;
        if (internal.integration.delaying_load) return true;
    }
    return false;
}

/// dom.content_navigables: `container`'s load event steps, when it is an
/// iframe.
fn contentNavigableLoadEventSteps(container: *runtime.Instance) bool {
    if (container.stateAs(State) == null) return false;
    runIframeLoadEventSteps(container);
    return true;
}

/// HTML "iframe load event steps" (§4.8.5): fire load at the element - and
/// with that, its navigation no longer delays its node document's load
/// event.
///
/// The delay ends before the event and the document hears of it after: a
/// load handler that navigates the frame again sets the delay again, and
/// "that will further delay the load event" (§4.8.5) - the document's load
/// waits for that navigation too, as it does in browsers.
fn runIframeLoadEventSteps(element: *runtime.Instance) void {
    const internal = getInternal(element) orelse return;
    const was_delaying = internal.integration.delaying_load;
    internal.integration.delaying_load = false;
    const generation = runtime.SlabAllocator.generationOf(element);
    // Steps 1-3 (mute iframe load) and 4 (resource timing) are not modelled.
    // Step 6: "Fire an event named load at element."
    fireLoadEventOnIframe(element);
    // The handlers may have taken the element away.
    if (!was_delaying or runtime.SlabAllocator.generationOf(element) != generation) return;
    const NodeImpl = @import("Node.zig");
    const document = NodeImpl.getOwnerDocument(element) orelse return;
    document_lifecycle.loadDelayMayHaveEnded(document);
}

// ----------------------------------------------------------------------------
// Entry points
// ----------------------------------------------------------------------------

/// IFrameIntegration's navigate hook - window.open()'s navigation of a
/// popup, and any caller without engine access.
fn navigateFromIntegration(integration: *IFrameIntegration, url: []const u8, request: html_core.window.iframe_integration.NavigateRequest) void {
    navigate(integration, url, .{
        .source_document = if (request.source_document) |d| @ptrCast(@alignCast(d)) else null,
        .history_behavior = request.history_behavior,
    });
}

/// Location's navigate callback: HTML "Location-object navigate" steps 3-4,
/// for a frame's or popup's Location. Step 3 - a relevant document that is
/// not completely loaded makes it a replace - is read here, from the
/// navigable's own record of its document.
fn navigateFromLocation(ctx: ?*anyopaque, url: []const u8, request: html_core.window.iframe_integration.NavigateRequest) bool {
    const integration: *IFrameIntegration = @ptrCast(@alignCast(ctx orelse return false));
    if (integration.browsing_context == null or integration.state == .discarded) return false;
    var behavior = request.history_behavior;
    if (activeDocumentOf(integration)) |document| {
        if (!document_lifecycle.isCompletelyLoaded(document)) behavior = .replace;
    }
    navigate(integration, url, .{
        .source_document = if (request.source_document) |d| @ptrCast(@alignCast(d)) else null,
        .history_behavior = behavior,
    });
    return true;
}

/// HTML "process the iframe attributes" (§4.8.5).
///
/// Lazy loading (steps 1.1-1.2 and 2.5-2.6) is not modelled: every frame
/// loads eagerly.
fn processIframeAttributes(element: *runtime.Instance, initial_insertion: bool) void {
    const internal = getInternal(element) orelse return;
    const ElementImpl = @import("Element.zig");
    // Step 1: "If element's srcdoc attribute is specified" - navigate to the
    // srcdoc resource.
    if (ElementImpl.call_getAttribute(element, runtime.DOMString.initInterned("srcdoc")) catch null) |srcdoc| {
        const markup = internal.allocator.dupe(u8, srcdoc.asSlice()) catch return;
        defer internal.allocator.free(markup);
        navigateIframeOrFrame(element, "about:srcdoc", markup, initial_insertion);
        return;
    }
    // Step 2.1: the shared attribute processing steps.
    const url = sharedAttributeProcessingSteps(element) orelse return;
    defer element.ctx.allocator.free(url);
    // Step 2.3: a URL that matches about:blank, on initial insertion, is not
    // navigated to: the frame keeps its initial about:blank document - whose
    // window never sees load or pageshow - and only the iframe load event
    // steps run.
    if (navigate_steps.matchesAboutBlank(url) and initial_insertion) {
        runIframeLoadEventSteps(element);
        return;
    }
    // Step 2.7: navigate.
    navigateIframeOrFrame(element, url, null, initial_insertion);
}

/// HTML "shared attribute processing steps for iframe and frame elements":
/// the src URL (owned by the element's context allocator), about:blank when
/// src is absent, empty or does not parse, or null when an inclusive
/// ancestor navigable already shows it (step 3: no infinite nesting).
/// Step 4 (URL and history update steps for about:blank?query) is not
/// modelled.
fn sharedAttributeProcessingSteps(element: *runtime.Instance) ?[]const u8 {
    const ElementImpl = @import("Element.zig");
    const src = ElementImpl.call_getAttribute(element, runtime.DOMString.initInterned("src")) catch null;
    const value: []const u8 = if (src) |s| s.asSlice() else "";
    const url = resolveSrc(element, value);
    if (ancestorShows(element, url)) {
        element.ctx.allocator.free(url);
        return null;
    }
    return url;
}

/// Step 3: whether a navigable among `element`'s node navigable and its
/// ancestors shows a document whose URL equals `url` without fragments.
fn ancestorShows(element: *runtime.Instance, url: []const u8) bool {
    if (navigate_steps.matchesAboutBlank(url)) return false;
    const NodeImpl = @import("Node.zig");
    var document = NodeImpl.getOwnerDocument(element);
    var depth: usize = 0;
    while (document) |doc| : (depth += 1) {
        if (depth > 32) return false;
        const doc_url = documentUrlOf(doc, element.ctx.allocator) catch return false;
        defer element.ctx.allocator.free(doc_url);
        if (navigate_steps.equalsExcludingFragments(doc_url, url)) return true;
        const window = (interfaces.Document.get_defaultView(doc) catch null) orelse return false;
        const container = dom_module.navigable_container.of(window) orelse return false;
        document = NodeImpl.getOwnerDocument(container);
    }
    return false;
}

/// HTML "navigate an iframe or frame" (§4.8.5).
fn navigateIframeOrFrame(element: *runtime.Instance, url: []const u8, srcdoc: ?[]const u8, initial_insertion: bool) void {
    const internal = getInternal(element) orelse return;
    const integration = internal.integration;
    // Step 1: "Let historyHandling be "auto"."
    var behavior: navigate_steps.HistoryBehavior = .auto;
    // Step 2: "If element's content navigable's active document is not
    // completely loaded, then set historyHandling to "replace"."
    if (activeDocumentOf(integration)) |document| {
        if (!document_lifecycle.isCompletelyLoaded(document)) behavior = .replace;
    }
    // Step 4: navigate, using element's node document.
    const NodeImpl = @import("Node.zig");
    navigate(integration, url, .{
        .source_document = NodeImpl.getOwnerDocument(element),
        .history_behavior = behavior,
        .srcdoc = srcdoc,
        .initial_insertion = initial_insertion,
    });
}

/// Fire a load event on the iframe element.
/// Per HTML spec §4.8.5, this is the "iframe load event steps" algorithm:
/// 1. Assert: element's content navigable is not null.
/// 2. Let childDocument be element's content navigable's active document.
/// 3. If childDocument has its mute iframe load flag set, then return.
/// 4. Fire an event named "load" at element.
///
/// For about:blank documents, the load event fires synchronously after
/// the document is created since there are no resources to fetch.
fn fireLoadEventOnIframe(instance: *runtime.Instance) void {
    const ctx = instance.ctx;

    // Create the Event instance via constructor (like JavaScript's new Event('load'))
    // Per HTML spec, load events on iframe elements do NOT bubble
    const Event = interfaces.Event;
    const event_type = runtime.DOMString.initInterned("load");

    // EventInit: bubbles=false, cancelable=false
    const event_init = dictionaries.EventInit{
        .bubbles = false,
        .cancelable = false,
        .composed = false,
    };

    const event = Event.call_constructor(ctx, event_type, webidl.Opt(dictionaries.EventInit).passed(event_init)) catch return;
    // Not `defer deinit`: a listener can keep the event -
    // `await new Promise(r => iframe.addEventListener("load", r))` resolves
    // with it - and its wrapper then owns it.
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);

    // Dispatch the event on the iframe element
    // HTMLIFrameElement inherits from HTMLElement -> Element -> Node -> EventTarget
    _ = interfaces.EventTarget.call_dispatchEvent(instance, event) catch return;
}

/// Getter for contentWindow
/// HTML "content window": the content navigable's active WindowProxy, or null
/// when the element has no content navigable.
///
/// The navigable is made by the element's post-connection steps. One that
/// never ran them - an element connected before any iframe existed to
/// register them - gets one here, without its attributes processed.
///
/// Phase 4 (Window-as-V8-Global): The Window instance IS bound to the V8 global
/// object, enabling proper cross-realm access:
/// - `iframe.contentWindow.DOMRectReadOnly` returns the constructor
/// - `iframe.contentWindow === iframe.contentWindow.window` is true
/// - Cross-realm toJSON tests pass (result objects use the method's realm)
pub fn get_contentWindow(instance: *runtime.Instance) anyerror!?typedefs.WindowProxy {
    const internal = getInternal(instance) orelse return null;

    // Per HTML spec: If the iframe is not connected (not in the document),
    // there is no content navigable, so contentWindow must return null.
    const NodeImpl = @import("Node.zig");
    const is_connected = NodeImpl.get_isConnected(instance) catch false;
    if (!is_connected) {
        return null;
    }
    if (internal.integration.state == .discarded) return null;

    if (!internal.integration.hasRealmContext()) {
        if (!createChildNavigable(instance)) {
            if (internal.integration.getContentWindow()) |proxy| return @ptrCast(proxy);
            return null;
        }
    }

    // Return the Window instance from the child context
    // The Window IS bound to the V8 global, so accessing properties on it
    // (like DOMRectReadOnly) works correctly for cross-realm scenarios.
    if (internal.integration.getEngineContext()) |engine_ctx| {
        const v8_ctx: *v8.ffi.Context = @ptrCast(@alignCast(engine_ctx));
        if (context_manager.getWindowForContext(v8_ctx)) |window| {
            // WindowProxy typedef is *runtime.Instance
            return window;
        }
    }

    // Fall back to old WindowProxy behavior if no Window instance available
    if (internal.integration.getContentWindow()) |proxy| {
        return @ptrCast(proxy);
    }
    return null;
}

/// HTML "create a new child navigable" for `instance`: a browsing context in
/// its node document's navigable, and a V8 context with a Window and the
/// initial about:blank document. False when the element's node document has
/// no browsing context - a document made by createHTMLDocument() or
/// DOMParser has no navigable to be the parent - or creation failed.
fn createChildNavigable(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    const isolate = v8.ffi.v8_Isolate_GetCurrent() orelse return false;
    const NodeImpl = @import("Node.zig");
    const DocumentImpl = @import("Document.zig");

    // The parent is the window of the element's node document - for a frame
    // nested in another frame's document, that frame's window.
    const owner_doc = NodeImpl.getOwnerDocument(instance) orelse return false;
    const parent_window: *runtime.Instance = (DocumentImpl.get_defaultView(owner_doc) catch null) orelse return false;
    const WindowImpl = @import("Window.zig");
    const parent_window_internal = WindowImpl.getInternal(parent_window) orelse return false;
    // The parent's context: createChildContext finds its entry by it and
    // copies its security token. A window whose realm was never recorded
    // falls back to the current context, which is what this always used.
    var owned_ctx: ?*v8.ffi.Context = null;
    defer if (owned_ctx) |c| v8.ffi.v8_Context_Dispose(c);
    const parent_v8_ctx: *v8.ffi.Context = blk: {
        if (parent_window.ctx.realm) |realm| {
            if (realm.getV8Context()) |c| break :blk @ptrCast(@alignCast(c));
        }
        owned_ctx = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return false;
        break :blk owned_ctx.?;
    };

    // The container document's origin, for same-origin checks on
    // contentDocument. The Window stores its origin as a string (e.g.,
    // "http://localhost:8000").
    const parent_origin_str = parent_window_internal.origin;
    const parent_origin = parseOriginFromString(parent_origin_str);
    internal.integration.container_origin = parent_origin;

    // The browsing context, a child of the container document's.
    const existing_bc = internal.integration.ensureBrowsingContext(
        @ptrCast(parent_window_internal.browsing_context),
    ) orelse return false;
    // This element is the new navigable's container.
    existing_bc.container = instance;

    // Sandboxed without allow-same-origin, the navigable's origin is opaque
    // - decided before the context exists, since V8's security token is set
    // as it is created.
    const use_opaque_origin = blk: {
        if (internal.integration.sandbox_flags) |flags| {
            break :blk !flags.allow_same_origin;
        }
        break :blk false;
    };

    // This element is the navigable's container: its load event steps run
    // once a navigation completes.
    internal.integration.iframe_element = @ptrCast(instance);

    // The navigable's context, Window and initial about:blank document.
    _ = attachNavigableContext(
        internal.integration,
        parent_v8_ctx,
        isolate,
        existing_bc,
        if (use_opaque_origin) null else parent_origin_str,
        internal.allocator,
    ) orelse return false;
    return true;
}

/// A navigable's V8 context, Window and initial about:blank document, wired to
/// `integration`: an iframe's content navigable, or window.open()'s auxiliary
/// one. The Window's origin is `origin`; null leaves it opaque. The context is
/// a child of `parent_v8_ctx`, whose teardown takes it down.
fn attachNavigableContext(
    integration: *IFrameIntegration,
    parent_v8_ctx: *v8.ffi.Context,
    isolate: *v8.ffi.Isolate,
    browsing_context: *html_core.BrowsingContext,
    origin: ?[]const u8,
    allocator: std.mem.Allocator,
) ?*context_manager.ContextEntry {
    // Create child V8 context with all interface bindings AND Window instance
    // The Window instance IS the V8 global, enabling cross-realm access
    //
    // Pass the iframe's browsing context so the Window uses it instead
    // of creating a new one. This is crucial for frames[index] to work:
    // - The browsing context was already added to the parent's children list
    // - The Window needs to use that same browsing context, not create a duplicate
    const entry = context_manager.createChildContext(.{
        .parent_context = parent_v8_ctx,
        .isolate = isolate,
        .context_type = .window,
        .inherit_event_loop = true,
        .existing_browsing_context = @ptrCast(browsing_context),
        .use_opaque_origin = origin == null,
    }, allocator) catch return null;

    // The Window's origin defaults to "null" (opaque), and stays so when
    // `origin` is null.
    if (entry.window_instance) |window_inst| {
        const WinImpl = @import("Window.zig");
        if (origin) |o| WinImpl.setOrigin(window_inst, o) catch {};
    }

    // Store the realm context in the integration for cleanup on removal
    integration.setRealmContext(
        @ptrCast(entry.v8_ctx),
        @ptrCast(entry.realm),
        @ptrCast(entry),
        @ptrCast(&entry.runtime_ctx),
        createDocumentForIframe,
        iframeContextCleanup,
        parseHtmlForIframe,
    );

    // Set script execution callbacks (for script execution in iframe documents)
    integration.execute_script_callback = &executeIframeScript;
    integration.update_location_callback = &updateIframeLocation;
    // Navigation: this engine's "navigate", the hook that ends a navigation
    // in flight when the navigable goes, and how a retired context ends.
    integration.navigate_callback = &navigateFromIntegration;
    integration.abandon_navigations_callback = &abandonNavigationsOf;
    integration.retired_realm_destroy = &destroyRetiredRealm;

    // Set up Location's navigate callback for programmatic navigation
    // (e.g., iframe.contentWindow.location = 'url' or location.assign())
    if (entry.window_instance) |window_instance| {
        const WinImpl = @import("Window.zig");
        if (WinImpl.getInternal(window_instance)) |window_internal| {
            if (window_internal.location) |location| {
                const LocationImpl = @import("Location.zig");
                // Set up bi-directional link: Location knows its Window
                LocationImpl.setWindow(location, window_instance);
                // Set up navigation callback with IFrameIntegration as context
                LocationImpl.setNavigateCallback(location, &navigateFromLocation, @ptrCast(integration));
            }
        }
    }

    // CRITICAL: Associate the iframe's browsing context with the Window.
    // createChildContext ignores existing_browsing_context (disabled for crash investigation),
    // so the Window was created with its own new browsing context. We need to:
    // 1. Replace the Window's browsing context with the iframe's browsing context
    // 2. Set this Window as the active window on the iframe's browsing context
    // This is required for contentDocument to work - createDocumentForIframe calls
    // browsing_ctx.getActiveWindow() which must return this Window.
    if (entry.window_instance) |window_instance| {
        // Use the already-imported WindowImpl from earlier in this function
        const WinImpl = @import("Window.zig");
        WinImpl.replaceBrowsingContext(window_instance, @ptrCast(browsing_context));
    }

    // Create the initial about:blank Document for the iframe.
    // Per HTML spec §7.5.1, every browsing context has an active document.
    // For about:blank, the document is created immediately when the browsing
    // context is created, not through navigation.
    // We call the createDocumentForIframe callback directly to create and
    // associate the Document with the browsing context.
    // HTML "create a new browsing context and document" step 15: this
    // document "is initial about:blank"; step 21 completely finishes loading
    // it.
    if (createDocumentForIframe(@ptrCast(&entry.runtime_ctx), browsing_context)) |document| {
        dom_module.document_lifecycle.markInitialAboutBlank(@ptrCast(@alignCast(document)));
    }

    return entry;
}

/// dom.auxiliary_navigables: window.open()'s new navigable - an auxiliary
/// browsing context opened by `opener_bc_ptr`, whose context, Window and
/// initial about:blank document are made exactly as an iframe's are, minus
/// the container. The integration is the caller's to deinit and destroy.
fn createAuxiliaryNavigable(
    allocator: std.mem.Allocator,
    opener_bc_ptr: *anyopaque,
    opener_origin: []const u8,
    is_popup: bool,
) ?dom_module.auxiliary_navigables.Created {
    const opener_bc: *html_core.BrowsingContext = @ptrCast(@alignCast(opener_bc_ptr));
    const isolate = v8.ffi.v8_Isolate_GetCurrent() orelse return null;
    // The opener is the entry global, whose script called open(): its
    // context is the new context's parent, so the page that keeps the popup
    // (Window.auxiliary_navigables) is the page that takes it down.
    const opener_v8_ctx = v8.ffi.v8_Isolate_GetEnteredOrMicrotaskContext(isolate) orelse return null;

    const integration = allocator.create(IFrameIntegration) catch return null;
    integration.* = IFrameIntegration.init(allocator);
    const browsing_context = html_core.BrowsingContext.initAuxiliary(allocator, opener_bc, is_popup) catch {
        integration.deinit();
        allocator.destroy(integration);
        return null;
    };
    // From here the integration owns the browsing context: its deinit frees it.
    integration.browsing_context = browsing_context;
    integration.container_origin = parseOriginFromString(opener_origin);
    integration.state = .creating_initial_document;

    const entry = attachNavigableContext(integration, opener_v8_ctx, isolate, browsing_context, opener_origin, allocator) orelse {
        integration.deinit();
        allocator.destroy(integration);
        return null;
    };
    const window = entry.window_instance orelse {
        integration.deinit();
        allocator.destroy(integration);
        return null;
    };
    return .{ .integration = @ptrCast(integration), .window = window };
}

/// Getter for contentDocument
/// Returns the nested document if same-origin, null otherwise.
/// Per HTML Standard §4.8.5: "The contentDocument getter steps are to return
/// this's content navigable's active document if this is same origin-domain;
/// otherwise null."
///
/// IMPORTANT: Per spec, contentDocument returns null if the iframe is not connected
/// (not inserted into the document). The content navigable is only created when
/// the iframe element is inserted into the DOM.
///
/// This getter delegates to contentWindow first to ensure the V8 context and
/// Document are lazily created if needed. Per spec, every browsing context
/// has an active document, so if the iframe is connected to the DOM, it should
/// have a Document.
pub fn get_contentDocument(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;

    // Per HTML spec: If the iframe is not connected (not in the document),
    // there is no content navigable, so contentDocument must return null.
    const NodeImpl = @import("Node.zig");
    const is_connected = NodeImpl.get_isConnected(instance) catch false;
    if (!is_connected) {
        return null;
    }

    // 1. Ensure the V8 context and Document exist by accessing contentWindow.
    //    Per spec, contentWindow triggers lazy creation of the browsing context,
    //    Window, and Document for a connected iframe. This is necessary because
    //    about:blank Documents are created when the context is initialized, not
    //    through navigation.
    _ = try get_contentWindow(instance);

    // 2. If no content navigable (browsing context), return null
    const browsing_ctx = internal.integration.browsing_context orelse return null;

    // 3. Get the active document from the browsing context
    // BrowsingContext stores it as *anyopaque to avoid module conflicts,
    // so we cast it back to *runtime.Instance here.
    const document_ptr = browsing_ctx.getActiveDocument() orelse return null;
    const document: *runtime.Instance = @ptrCast(@alignCast(document_ptr));

    // 4. Get accessor origin - for WPT tests and same-origin scenarios,
    //    we use the container document's origin as the accessor origin.
    //    In a full implementation, this would come from the incumbent settings object.
    //    Since we're in the same execution context (WPT tests are same-origin),
    //    we use the container origin which is already stored in the integration.
    const accessor_origin = internal.integration.container_origin;

    // 5. Check same origin-domain access
    const is_accessible = internal.integration.isContentDocumentAccessible(accessor_origin);
    if (!is_accessible) {
        return null;
    }

    // 6. Return the document
    return document;
}

// ============================================================================
// URL Attributes (§4.8.5)
// ============================================================================

/// Getter for src
/// HTML "reflect" for a USVString URL attribute: the content attribute,
/// encoding-parsed and serialized relative to the node document - or, when
/// that fails, the attribute's value as given; "" without one. Owned: the
/// binding frees what a getter returns.
pub fn get_src(instance: *runtime.Instance) anyerror!runtime.USVString {
    const ElementImpl = @import("Element.zig");
    const value = (try ElementImpl.call_getAttribute(instance, runtime.DOMString.initInterned("src"))) orelse return "";
    const raw = value.asSlice();
    if (raw.len == 0) return instance.ctx.allocator.dupe(u8, "");
    const base = interfaces.Node.get_baseURI(instance) catch return instance.ctx.allocator.dupe(u8, raw);
    defer instance.ctx.allocator.free(base);
    const base_arg = if (base.len > 0)
        webidl.Opt(runtime.USVString).passed(base)
    else
        webidl.Opt(runtime.USVString).notPassed();
    const url = (interfaces.URL.call_static_parse(instance, raw, base_arg) catch null) orelse
        return instance.ctx.allocator.dupe(u8, raw);
    defer runtime.Instance.deinit(url);
    return interfaces.URL.get_href(url);
}

/// Setter for src
/// HTML "reflect": set the src content attribute.
///
/// HTML §4.8.5: "whenever an iframe element with a non-null content navigable
/// but with no srcdoc attribute specified has its src attribute set, changed,
/// or removed, the user agent must process the iframe attributes." Element's
/// attribute change steps do not reach this element yet, so the setter does
/// it; `setAttribute("src", ...)` does not navigate.
pub fn set_src(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const ElementImpl = @import("Element.zig");
    try ElementImpl.call_setAttribute(instance, runtime.DOMString.initInterned("src"), runtime.DOMString.initInterned(value));
    if (!hasContentNavigable(instance)) return;
    if (try ElementImpl.call_hasAttribute(instance, runtime.DOMString.initInterned("srcdoc"))) return;
    processIframeAttributes(instance, false);
}

/// Getter for srcdoc
/// HTML "reflect": the srcdoc content attribute, or "". A copy - the binding
/// frees what a getter returns, and the attribute can change under it.
pub fn get_srcdoc(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const ElementImpl = @import("Element.zig");
    const value = (try ElementImpl.call_getAttribute(instance, runtime.DOMString.initInterned("srcdoc"))) orelse
        return runtime.DOMString.initInterned("");
    return runtime.DOMString.initDupe(instance.ctx.allocator, value.asSlice());
}

/// Setter for srcdoc
/// HTML "reflect": set the srcdoc content attribute - and, the attribute
/// change steps not reaching this element yet, process the iframe attributes
/// (§4.8.5: "whenever an iframe element with a non-null content navigable
/// has its srcdoc attribute set, changed, or removed").
pub fn set_srcdoc(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const ElementImpl = @import("Element.zig");
    try ElementImpl.call_setAttribute(instance, runtime.DOMString.initInterned("srcdoc"), value);
    if (!hasContentNavigable(instance)) return;
    processIframeAttributes(instance, false);
}

/// Whether the element has a content navigable: it is connected and its
/// post-connection steps made one.
fn hasContentNavigable(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    if (internal.integration.state == .discarded or internal.integration.state == .uninitialized) return false;
    if (internal.integration.browsing_context == null) return false;
    const NodeImpl = @import("Node.zig");
    return NodeImpl.get_isConnected(instance) catch false;
}

/// Getter for name
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initInterned("");

    if (internal.name_attr) |name| {
        return runtime.DOMString.initInterned(name);
    }
    return runtime.DOMString.initInterned("");
}

/// Setter for name
/// Sets the browsing context name for targeting.
pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    // Free old value
    if (internal.name_attr) |old| {
        internal.allocator.free(old);
    }

    // Store new value
    const str = value.asSlice();
    internal.name_attr = try internal.allocator.dupe(u8, str);

    // Update integration (propagates to iframe's browsing context)
    internal.integration.setName(str) catch {};

    // Also propagate to the Window's browsing context if contentWindow exists
    // This ensures iframe.contentWindow.name reflects the updated name
    if (internal.integration.getEngineContext()) |engine_ctx| {
        const v8_ctx: *v8.ffi.Context = @ptrCast(@alignCast(engine_ctx));
        if (context_manager.getWindowForContext(v8_ctx)) |window_instance| {
            const WindowImpl = @import("Window.zig");
            if (WindowImpl.getInternal(window_instance)) |window_internal| {
                window_internal.browsing_context.setTargetName(str) catch {};
            }
        }
    }
}

// ============================================================================
// Sandbox Attribute (§4.8.5)
// ============================================================================

/// Getter for sandbox
/// Returns a DOMTokenList for the sandbox attribute.
/// Per spec, this is a [SameObject] attribute - returns the same DOMTokenList each time.
pub fn get_sandbox(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidState;

    // Return cached token list if already created
    if (internal.sandbox_token_list) |token_list| {
        return token_list;
    }

    // Create a new DOMTokenList for the sandbox attribute
    const token_list = DOMTokenList.init(internal.allocator, instance.ctx) catch return error.OutOfMemory;
    errdefer DOMTokenList.deinit(token_list);

    // Set supported tokens for supports() method
    DOMTokenListImpl.setSupportedTokens(token_list, &SandboxFlags.SUPPORTED_TOKENS);

    // Associate with this element and attribute name
    DOMTokenListImpl.setElement(token_list, instance, runtime.DOMString.initInterned("sandbox"));

    // Initialize the token list from the element's current sandbox attribute value.
    // This is critical: the attribute may have been set via Element.setAttribute()
    // before the DOMTokenList was created. Per spec, the DOMTokenList should
    // reflect the current attribute value.
    const ElementImpl = @import("Element.zig");
    const sandbox_attr_name = runtime.DOMString.initInterned("sandbox");
    if (ElementImpl.call_getAttribute(instance, sandbox_attr_name) catch null) |attr_value| {
        const attr_slice = attr_value.asSlice();
        if (attr_slice.len > 0) {
            // Parse the attribute value and populate the token list
            DOMTokenListImpl.set_value(token_list, attr_value) catch {};
        }
    }

    // Cache for future calls (SameObject semantic)
    internal.sandbox_token_list = token_list;

    return token_list;
}

/// Internal: Update sandbox flags when DOMTokenList changes
/// Called when the sandbox attribute value changes.
pub fn updateSandboxFlags(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return;

    if (internal.sandbox_token_list) |token_list| {
        // Get the serialized value from DOMTokenList
        const value = try DOMTokenListImpl.get_value(token_list);
        const value_slice = value.asSlice();

        if (value_slice.len > 0) {
            // Apply sandbox with the token values
            try internal.integration.setSandbox(value_slice);
        } else {
            // Empty sandbox attribute = all restrictions
            try internal.integration.setSandbox("");
        }
    }
}

// ============================================================================
// Permissions Policy Attributes (§4.8.5)
// ============================================================================

/// Getter for allow
pub fn get_allow(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initInterned("");

    if (internal.allow_attr) |allow| {
        return runtime.DOMString.initInterned(allow);
    }
    return runtime.DOMString.initInterned("");
}

/// Setter for allow
pub fn set_allow(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    if (internal.allow_attr) |old| {
        internal.allocator.free(old);
    }
    internal.allow_attr = try internal.allocator.dupe(u8, value.asSlice());
}

/// Getter for allowFullscreen
pub fn get_allowFullscreen(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    return internal.allow_fullscreen;
}

/// Setter for allowFullscreen
pub fn set_allowFullscreen(instance: *runtime.Instance, value: bool) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    internal.allow_fullscreen = value;
}

// ============================================================================
// Dimension Attributes (§4.8.5)
// ============================================================================

/// Getter for width
pub fn get_width(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initInterned("");

    if (internal.width_attr) |width| {
        return runtime.DOMString.initInterned(width);
    }
    return runtime.DOMString.initInterned("");
}

/// Setter for width
pub fn set_width(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    if (internal.width_attr) |old| {
        internal.allocator.free(old);
    }
    internal.width_attr = try internal.allocator.dupe(u8, value.asSlice());
}

/// Getter for height
pub fn get_height(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initInterned("");

    if (internal.height_attr) |height| {
        return runtime.DOMString.initInterned(height);
    }
    return runtime.DOMString.initInterned("");
}

/// Setter for height
pub fn set_height(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    if (internal.height_attr) |old| {
        internal.allocator.free(old);
    }
    internal.height_attr = try internal.allocator.dupe(u8, value.asSlice());
}

// ============================================================================
// Loading and Security Attributes (§4.8.5)
// ============================================================================

/// Getter for referrerPolicy
pub fn get_referrerPolicy(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initInterned("");

    if (internal.referrer_policy_attr) |rp| {
        return runtime.DOMString.initInterned(rp);
    }
    return runtime.DOMString.initInterned("");
}

/// Setter for referrerPolicy
pub fn set_referrerPolicy(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    if (internal.referrer_policy_attr) |old| {
        internal.allocator.free(old);
    }
    internal.referrer_policy_attr = try internal.allocator.dupe(u8, value.asSlice());
}

/// Getter for loading
pub fn get_loading(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initInterned("eager");

    if (internal.loading_attr) |loading| {
        return runtime.DOMString.initInterned(loading);
    }
    return runtime.DOMString.initInterned("eager");
}

/// Setter for loading
pub fn set_loading(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    if (internal.loading_attr) |old| {
        internal.allocator.free(old);
    }
    internal.loading_attr = try internal.allocator.dupe(u8, value.asSlice());
}

/// Getter for browsingTopics
pub fn get_browsingTopics(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    return internal.browsing_topics;
}

/// Setter for browsingTopics
pub fn set_browsingTopics(instance: *runtime.Instance, value: bool) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    internal.browsing_topics = value;
}

/// Getter for csp
pub fn get_csp(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initInterned("");

    if (internal.csp_attr) |csp| {
        return runtime.DOMString.initInterned(csp);
    }
    return runtime.DOMString.initInterned("");
}

/// Setter for csp
pub fn set_csp(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    if (internal.csp_attr) |old| {
        internal.allocator.free(old);
    }
    internal.csp_attr = try internal.allocator.dupe(u8, value.asSlice());
}

/// Getter for credentialless
pub fn get_credentialless(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    return internal.credentialless;
}

/// Setter for credentialless
pub fn set_credentialless(instance: *runtime.Instance, value: bool) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    internal.credentialless = value;
}

/// Getter for adAuctionHeaders
pub fn get_adAuctionHeaders(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    return internal.ad_auction_headers;
}

/// Setter for adAuctionHeaders
pub fn set_adAuctionHeaders(instance: *runtime.Instance, value: bool) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    internal.ad_auction_headers = value;
}

// ============================================================================
// Legacy Attributes (§4.8.5)
// ============================================================================

/// Getter for align
pub fn get_align(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initInterned("");

    if (internal.align_attr) |align_val| {
        return runtime.DOMString.initInterned(align_val);
    }
    return runtime.DOMString.initInterned("");
}

/// Setter for align
pub fn set_align(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    if (internal.align_attr) |old| {
        internal.allocator.free(old);
    }
    internal.align_attr = try internal.allocator.dupe(u8, value.asSlice());
}

/// Getter for scrolling
pub fn get_scrolling(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initInterned("");

    if (internal.scrolling_attr) |scrolling| {
        return runtime.DOMString.initInterned(scrolling);
    }
    return runtime.DOMString.initInterned("");
}

/// Setter for scrolling
pub fn set_scrolling(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    if (internal.scrolling_attr) |old| {
        internal.allocator.free(old);
    }
    internal.scrolling_attr = try internal.allocator.dupe(u8, value.asSlice());
}

/// Getter for frameBorder
pub fn get_frameBorder(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initInterned("");

    if (internal.frame_border_attr) |fb| {
        return runtime.DOMString.initInterned(fb);
    }
    return runtime.DOMString.initInterned("");
}

/// Setter for frameBorder
pub fn set_frameBorder(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    if (internal.frame_border_attr) |old| {
        internal.allocator.free(old);
    }
    internal.frame_border_attr = try internal.allocator.dupe(u8, value.asSlice());
}

/// Getter for longDesc
/// Returns a newly allocated copy of the longDesc attribute.
/// The V8 interface layer will free the returned string after converting to V8.
pub fn get_longDesc(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return "";

    if (internal.long_desc_attr) |ld| {
        // Must dupe - V8 interface layer frees getter results
        return try internal.allocator.dupe(u8, ld);
    }
    return "";
}

/// Setter for longDesc
pub fn set_longDesc(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    if (internal.long_desc_attr) |old| {
        internal.allocator.free(old);
    }
    // USVString is []const u8
    internal.long_desc_attr = try internal.allocator.dupe(u8, value);
}

/// Getter for marginHeight
pub fn get_marginHeight(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initInterned("");

    if (internal.margin_height_attr) |mh| {
        return runtime.DOMString.initInterned(mh);
    }
    return runtime.DOMString.initInterned("");
}

/// Setter for marginHeight
pub fn set_marginHeight(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    if (internal.margin_height_attr) |old| {
        internal.allocator.free(old);
    }
    internal.margin_height_attr = try internal.allocator.dupe(u8, value.asSlice());
}

/// Getter for marginWidth
pub fn get_marginWidth(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initInterned("");

    if (internal.margin_width_attr) |mw| {
        return runtime.DOMString.initInterned(mw);
    }
    return runtime.DOMString.initInterned("");
}

/// Setter for marginWidth
pub fn set_marginWidth(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    if (internal.margin_width_attr) |old| {
        internal.allocator.free(old);
    }
    internal.margin_width_attr = try internal.allocator.dupe(u8, value.asSlice());
}

// ============================================================================
// Experimental Attributes
// ============================================================================

/// Getter for privateToken
pub fn get_privateToken(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initInterned("");

    if (internal.private_token_attr) |pt| {
        return runtime.DOMString.initInterned(pt);
    }
    return runtime.DOMString.initInterned("");
}

/// Setter for privateToken
pub fn set_privateToken(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    if (internal.private_token_attr) |old| {
        internal.allocator.free(old);
    }
    internal.private_token_attr = try internal.allocator.dupe(u8, value.asSlice());
}

/// Getter for permissionsPolicy
pub fn get_permissionsPolicy(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    // TODO: Implement PermissionsPolicy interface
    return error.NotImplemented;
}

/// Getter for sharedStorageWritable
pub fn get_sharedStorageWritable(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    return internal.shared_storage_writable;
}

/// Setter for sharedStorageWritable
pub fn set_sharedStorageWritable(instance: *runtime.Instance, value: bool) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    internal.shared_storage_writable = value;
}

// ============================================================================
// Operations (§4.8.5)
// ============================================================================

/// Operation: getSVGDocument
/// Returns the nested SVG document if applicable.
pub fn call_getSVGDocument(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    // TODO: Implement SVG document retrieval
    return null;
}

// ============================================================================
// Removing Steps Callback for Iframe Cleanup
// ============================================================================

/// Removing steps callback for iframe elements.
/// This callback is registered with the DOM mutation system and is called whenever
/// a node is removed from the document. If the node is an iframe element, this
/// function calls onRemovedFromDocument() on the iframe's integration to clean up
/// the nested browsing context.
///
/// Per HTML spec §4.8.5, when an iframe is removed from the document:
/// 1. The nested browsing context is discarded
/// 2. The browsing context is removed from its parent's children list
/// 3. window.frames.length should reflect the change immediately
fn iframeRemovingStepsCallback(node: *NodeBase, old_parent: ?*NodeBase) void {
    _ = old_parent;

    // Only process ELEMENT_NODE (nodeType == 1)
    if (node.node_type != 1) return;

    // Check if this is an iframe element by looking at the node_name.
    // For HTML elements, node_name is the uppercase tag name (e.g., "IFRAME").
    // We also check for lowercase "iframe" for robustness.
    if (!std.ascii.eqlIgnoreCase(node.node_name, "iframe")) return;

    // Get the runtime.Instance from the NodeBase using the instance bridge
    const instance_ptr = instance_bridge.getInstance(node) orelse return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_ptr));

    // Get the iframe's internal state and call onRemovedFromDocument
    const internal = getInternal(instance) orelse return;
    // "Destroy a child navigable" destroys the documents of the frame and of
    // every frame in it: their windows' timers and animation frames end here,
    // though the contexts live on while script holds the windows.
    if (internal.integration.state != .discarded) {
        if (internal.integration.engine_context) |engine_ctx| {
            context_manager.cleanUpChildWindows(@ptrCast(@alignCast(engine_ctx)));
        }
    }
    const was_delaying = internal.integration.delaying_load;
    internal.integration.onRemovedFromDocument();
    // The node document may have been waiting on this frame's navigation to
    // fire its load event. It has no content navigable now.
    if (was_delaying) {
        const NodeImpl = @import("Node.zig");
        if (NodeImpl.getOwnerDocument(instance)) |document| dom_module.document_lifecycle.loadDelayMayHaveEnded(document);
    }
}

/// Register the iframe removing steps callback with the DOM mutation system.
/// This should be called during application initialization.
///
/// The callback is idempotent - calling it multiple times just adds the callback
/// again, but since it's the same function pointer, the behavior is the same.
pub fn registerIframeRemovingSteps() !void {
    try dom_module.mutation.registerRemovingStepsCallback(&iframeRemovingStepsCallback);
}

/// Flag to track if the callbacks have been registered
var removing_steps_registered: bool = false;
var post_connection_steps_registered: bool = false;

/// Ensure the iframe removing steps callback is registered.
/// This is called lazily during iframe creation to ensure the callback is set up.
pub fn ensureRemovingStepsRegistered() void {
    if (removing_steps_registered) return;
    registerIframeRemovingSteps() catch return;
    removing_steps_registered = true;
}

// ============================================================================
// Post-connection steps (HTML §4.8.5)
// ============================================================================

/// The iframe HTML element post-connection steps, given `node`:
/// 1. create a new child navigable for it;
/// 2. parse its sandbox attribute, if it has one;
/// 3. process the iframe attributes, with initialInsertion true.
///
/// Every insertion reaches this - the parsers' as much as script's - once
/// the whole batch is in the tree, so a frame's load event and its scripts
/// never run in the middle of an insertion.
///
/// An element that was removed and is inserted again gets a NEW navigable
/// and a new initial about:blank document; its old context is retired, not
/// destroyed (see `IFrameIntegration.retireRealmContext`).
fn iframePostConnectionSteps(node: *NodeBase) void {
    if (node.node_type != 1) return;
    if (!std.ascii.eqlIgnoreCase(node.node_name, "iframe")) return;
    const instance_ptr = instance_bridge.getInstance(node) orelse return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_ptr));
    const internal = getInternal(instance) orelse return;
    const NodeImpl = @import("Node.zig");
    if (!(NodeImpl.get_isConnected(instance) catch false)) return;

    // Inserted again after a removal: the old navigable is gone.
    if (internal.integration.state == .discarded) {
        internal.integration.retireRealmContext() catch return;
    }

    // Step 2 comes first here: the sandboxing flags decide the new context's
    // security token as it is created.
    const ElementImpl = @import("Element.zig");
    if (ElementImpl.call_getAttribute(instance, runtime.DOMString.initInterned("sandbox")) catch null) |sandbox| {
        internal.integration.setSandbox(sandbox.asSlice()) catch {};
    }

    // Step 1: create a new child navigable.
    if (!internal.integration.hasRealmContext()) {
        if (!createChildNavigable(instance)) return;
    }

    // The navigable's target name is the element's name attribute, and the
    // parent's global reaches it by that name.
    const name: ?[]const u8 = blk: {
        if (internal.name_attr) |n| break :blk n;
        if (ElementImpl.call_getAttribute(instance, runtime.DOMString.initInterned("name")) catch null) |attr| break :blk attr.asSlice();
        break :blk null;
    };
    if (name) |n| {
        if (n.len > 0) {
            const owned = internal.allocator.dupe(u8, n) catch return;
            defer internal.allocator.free(owned);
            internal.integration.setName(owned) catch {};
            registerNamedPropertyOnParentGlobal(instance, owned);
        }
    }

    // Step 3.
    processIframeAttributes(instance, true);
}

/// Register a named property on the parent window's global object for iframe access.
/// This sets window[name] = iframe.contentWindow, enabling window.frames['name'] to work.
///
/// This is called when an iframe with a name is inserted into the document.
/// V8's named property interceptors don't survive snapshot restore, so we use this
/// direct property approach instead.
fn registerNamedPropertyOnParentGlobal(iframe_instance: *runtime.Instance, name: []const u8) void {
    // Get the iframe's internal state
    const internal = getInternal(iframe_instance) orelse return;

    // Get the child browsing context (contains the contentWindow)
    const child_bc = internal.integration.browsing_context orelse return;

    // Get the parent browsing context
    const parent_bc = child_bc.parent orelse return;

    // Get the parent's Window instance
    const parent_window_ptr = parent_bc.active_window orelse return;
    const parent_window: *runtime.Instance = @ptrCast(@alignCast(parent_window_ptr));

    // Get the V8 isolate and context from the parent window's realm
    // We use the realm because it stores the actual V8 context pointer,
    // unlike GetCurrentContext() which returns the currently-entered context
    // (which might be the child's context during iframe insertion).
    const ctx_data = parent_window.ctx;
    const realm = ctx_data.realm orelse return;

    const isolate_ptr = realm.getIsolate() orelse return;
    const isolate: *v8.ffi.Isolate = @ptrCast(@alignCast(isolate_ptr));

    const parent_v8_ctx_ptr = realm.getV8Context() orelse return;
    const parent_v8_ctx: *v8.ffi.Context = @ptrCast(@alignCast(parent_v8_ctx_ptr));

    // Get the parent's global object. Every handle below is owned, and one
    // to a global keeps its whole page alive: each is released here.
    const global = v8.ffi.v8_Context_Global(parent_v8_ctx) orelse return;
    defer v8.ffi.v8_Object_Dispose(global);

    // Get the child Window instance and its V8 context from its realm
    const child_window_ptr = child_bc.active_window orelse return;
    const child_window: *runtime.Instance = @ptrCast(@alignCast(child_window_ptr));
    const child_ctx_data = child_window.ctx;
    const child_realm = child_ctx_data.realm orelse return;

    const child_v8_ctx_ptr = child_realm.getV8Context() orelse return;
    const child_v8_ctx: *v8.ffi.Context = @ptrCast(@alignCast(child_v8_ctx_ptr));

    // Get the child window's V8 wrapper (the global object of the child context)
    const child_global = v8.ffi.v8_Context_Global(child_v8_ctx) orelse return;
    defer v8.ffi.v8_Object_Dispose(child_global);

    // Create the property name string
    const name_str = v8.ffi.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse return;
    defer v8.ffi.v8_String_Dispose(name_str);

    // Set the property: window[name] = child's global (contentWindow)
    _ = v8.ffi.v8_Object_Set(global, parent_v8_ctx, @ptrCast(name_str), @ptrCast(child_global));
}

/// Register the iframe post-connection steps with the DOM mutation system.
pub fn registerIframePostConnectionSteps() !void {
    try dom_module.mutation.registerPostConnectionStepsCallback(&iframePostConnectionSteps);
}

/// Ensure the iframe post-connection steps are registered - once, when the
/// first iframe element is made.
pub fn ensurePostConnectionStepsRegistered() void {
    if (post_connection_steps_registered) return;
    registerIframePostConnectionSteps() catch return;
    post_connection_steps_registered = true;
}
