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
const scripted_parser = html_module.scripted_parser;
const document_internals = dom_module.document_internals;

// ============================================================================
// Iframe Src Loading Hook (for WPT runner integration)
// ============================================================================
//
// This hook allows the WPT runner to intercept iframe src loading for relative
// and HTTP URLs. The WPT runner can:
// 1. Resolve relative URLs against the test directory
// 2. Fetch content from the WPT file system
// 3. Parse the HTML and set up the document
// 4. Fire the load event on the iframe
//
// The hook returns true if it handled the load, false otherwise.

/// Type for the iframe src load hook
/// Parameters: (iframe_instance, src_url) -> handled
pub const IframeSrcLoadHook = *const fn (*runtime.Instance, []const u8) bool;

/// Thread-local hook for iframe src loading
/// Set by the WPT runner to intercept iframe navigations
threadlocal var iframe_src_load_hook: ?IframeSrcLoadHook = null;

/// Set the iframe src load hook
/// Call with null to clear the hook
pub fn setIframeSrcLoadHook(hook: ?IframeSrcLoadHook) void {
    iframe_src_load_hook = hook;
}

/// Get the current iframe src load hook
pub fn getIframeSrcLoadHook() ?IframeSrcLoadHook {
    return iframe_src_load_hook;
}

// ============================================================================
// Post-Connection Steps for Iframe Load Event
// ============================================================================
//
// Per HTML Standard §4.8.5, when an iframe element is inserted into a document:
// 1. Create a nested browsing context
// 2. Navigate to initial content (about:blank if no src/srcdoc)
// 3. Fire the load event on the iframe element
//
// This callback is registered with the DOM mutation system to handle the
// post-connection steps for iframe elements.

/// Fire the iframe load event if this is an about:blank iframe, or trigger
/// navigation for iframes with src/srcdoc that were set before connection.
///
/// Called from Node.call_appendChild after an iframe is inserted into the document.
/// This function is called with the CORRECT runtime.Instance that JavaScript holds,
/// ensuring event handlers stored on that instance are found.
///
/// Per HTML spec §4.8.5, the load event fires synchronously after:
/// 1. The iframe is connected to a document
/// 2. The about:blank document is created (for iframes without src/srcdoc)
///
/// For iframes with src/srcdoc, we need to trigger navigation here because
/// the srcdoc/src attributes may have been set before the iframe was connected,
/// and at that time the browsing context didn't exist.
pub fn fireIframeLoadEventIfNeeded(instance: *runtime.Instance) void {
    // Get the internal state to check if we need to fire the load event
    // Note: We'll re-fetch this after get_contentWindow since that operation
    // can trigger memory allocations that could invalidate pointers.
    if (getInternal(instance) == null) return;

    // Ensure the browsing context exists (via contentWindow access)
    // This creates the BC and sets up parse_html_callback
    // CRITICAL: This can trigger context creation, memory allocation, and potentially
    // arena resets. We MUST re-fetch internal state after this call.
    _ = get_contentWindow(instance) catch return;

    // Re-fetch internal state after get_contentWindow.
    // get_contentWindow does extensive work (context creation, Window instantiation,
    // browsing context setup) that can invalidate previously captured pointers.
    const internal = getInternal(instance) orelse return;

    // Check for srcdoc content in the element's attribute list.
    // This is critical for nested iframes created by HTML parsing, where the
    // srcdoc attribute is set via Element.setAttribute rather than the IDL setter.
    // The IDL setter (set_srcdoc) updates internal.srcdoc_attr, but HTML parsing
    // only updates the element's attribute list.
    const ElementImpl = @import("Element.zig");
    const srcdoc_attr_name = runtime.DOMString.initInterned("srcdoc");
    const srcdoc_value = ElementImpl.call_getAttribute(instance, srcdoc_attr_name) catch null;

    if (srcdoc_value) |srcdoc_str| {
        const srcdoc = srcdoc_str.asSlice();
        if (srcdoc.len > 0) {
            // Now that BC and callbacks are set up, trigger navigation
            internal.integration.setSrcdoc(srcdoc) catch {};
            // Fire load event after srcdoc navigation completes
            fireLoadEventOnIframe(instance);
            return;
        }
    }

    // Also check internal state (for iframes where srcdoc was set via JavaScript)
    if (internal.srcdoc_attr) |srcdoc| {
        // Now that BC and callbacks are set up, trigger navigation
        internal.integration.setSrcdoc(srcdoc) catch {};
        // Fire load event after srcdoc navigation completes
        fireLoadEventOnIframe(instance);
        return;
    }

    // If we have src, trigger navigation
    // (src navigation is typically handled by the WPT runner hook)
    if (internal.src_attr != null) {
        return;
    }

    // For about:blank iframes (no src/srcdoc), the load event was already
    // fired when get_contentWindow created the initial document.
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

    /// Cached attribute values for reflection
    src_attr: ?[]const u8 = null,
    srcdoc_attr: ?[]const u8 = null,
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

        state.* = .{
            .integration = integration,
            .allocator = allocator,
        };

        return state;
    }

    pub fn deinit(self: *InternalState) void {
        // Clean up integration
        self.integration.deinit();

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
    ensureInsertionStepsRegistered();

    // Chain to parent class (HTMLElement)
    const HTMLElementImpl = @import("HTMLElement.zig");
    const instance = try HTMLElementImpl.init(allocator, StateType, vtable, ctx);
    errdefer HTMLElementImpl.deinit(instance);

    // Initialize internal state
    const state = instance.getState(StateType);
    state.own._internal = try InternalState.init(allocator);

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
    if (!runtime.instance_lifecycle.markCleanupStarted(instance)) {
        return; // Already being cleaned up, skip
    }

    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
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
    const runtime_ctx: runtime.Context = @ptrCast(@alignCast(runtime_ctx_ptr orelse {
        return null;
    }));
    const allocator = runtime_ctx.allocator;

    // Get window BEFORE parsing for nested iframe support
    const window_instance: ?*runtime.Instance = if (browsing_ctx_ptr.getActiveWindow()) |window_ptr|
        @ptrCast(@alignCast(window_ptr))
    else
        null;

    // Use the scripted parser which:
    // 1. Creates a Document FIRST
    // 2. Uses DomTreeAdapter to convert TreeNodes to DOM nodes incrementally
    // 3. Scripts can access DOM nodes during parsing via querySelector etc.
    //
    // CRITICAL: Check sandbox flags to determine if scripting is enabled.
    // Per HTML spec §4.8.5, when an iframe has the sandbox attribute:
    // - If empty (sandbox=""), ALL restrictions apply including script blocking
    // - If sandbox="allow-scripts", scripts are allowed to execute
    // The BrowsingContext.allowsScripts() method encapsulates this check.
    const scripting_enabled = browsing_ctx_ptr.allowsScripts();

    const document_instance = scripted_parser.parseHTMLWithScripting(
        allocator,
        runtime_ctx,
        html_content,
        .{ .scripting_enabled = scripting_enabled, .window = window_instance },
    ) catch {
        // Fall back to empty document on parse error
        return createDocumentForIframe(runtime_ctx_ptr, browsing_ctx_ptr);
    };

    // Set document type to HTML
    document_internals.setDocumentType(document_instance, .html) catch {};

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
    const DocumentImpl = @import("Document.zig");
    DocumentImpl.setBoundV8Wrapper(document_instance, v8_wrapper);

    // Get the active window for this browsing context to associate with the document
    if (browsing_ctx_ptr.getActiveWindow()) |window_ptr| {
        // Set the document on the browsing context
        browsing_ctx_ptr.setActiveDocument(document_instance, window_ptr);

        // Also set the document on the Window
        const WindowImpl = @import("Window.zig");
        const window_inst: *runtime.Instance = @ptrCast(@alignCast(window_ptr));
        WindowImpl.setDocument(window_inst, document_instance);
        // Set the defaultView on the document (bidirectional Document <-> Window link)
        // Note: This is also set by the parser via options.window, but we keep it here
        // for consistency and in case of parse errors that fall back to createDocumentForIframe
        DocumentImpl.setDefaultView(document_instance, window_inst);
    }

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

    // Update Location's URL
    const LocationImpl = @import("Location.zig");
    LocationImpl.setURLFromString(location, url) catch {};
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
    defer Event.deinit(event);

    // Dispatch the event on the iframe element
    // HTMLIFrameElement inherits from HTMLElement -> Element -> Node -> EventTarget
    _ = interfaces.EventTarget.call_dispatchEvent(instance, event) catch return;
}

/// Getter for contentWindow
/// Returns the WindowProxy for the nested browsing context, or null if none.
///
/// Per HTML Standard §4.8.5, the contentWindow getter returns the WindowProxy
/// for the nested browsing context. This WindowProxy provides access to the
/// Window object in the iframe's realm.
///
/// IMPORTANT: Per spec, contentWindow returns null if the iframe is not connected
/// (not inserted into the document). The content navigable is only created when
/// the iframe element is inserted into the DOM via the "post-connection steps".
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
    // The content navigable is only created during "post-connection steps"
    // when the iframe is inserted into the DOM.
    const NodeImpl = @import("Node.zig");
    const is_connected = NodeImpl.get_isConnected(instance) catch false;
    if (!is_connected) {
        return null;
    }

    // Ensure the realm and V8 context are created (lazy initialization)
    // This creates a child V8 context with all interface bindings
    if (!internal.integration.hasRealmContext()) {
        // Get the current V8 isolate
        const isolate = v8.ffi.v8_Isolate_GetCurrent() orelse {
            // Fall back to WindowProxy if no V8 isolate
            if (internal.integration.getContentWindow()) |proxy| {
                return @ptrCast(proxy);
            }
            return null;
        };

        // Get the current V8 context (used for context creation later)
        const current_v8_ctx = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
            // Fall back to WindowProxy if no current context
            if (internal.integration.getContentWindow()) |proxy| {
                return @ptrCast(proxy);
            }
            return null;
        };

        // CRITICAL: Find the correct parent window.
        // For nested iframes (inside another iframe's srcdoc), we need to find the parent
        // through the DOM tree, not through v8_Isolate_GetCurrentContext().
        //
        // The correct parent is the window of the iframe's ownerDocument.
        // For a nested iframe in outer iframe's srcdoc:
        // - instance.ownerDocument = outer iframe's document
        // - outer iframe's document.defaultView = outer iframe's window
        // - outer iframe's window.browsing_context = correct parent BC
        const DocumentImpl = @import("Document.zig");

        // Try to get parent through ownerDocument.defaultView (correct for nested iframes)
        const parent_window: *runtime.Instance = blk: {
            // Get this iframe's ownerDocument (NodeImpl already imported above)
            if (NodeImpl.getOwnerDocument(instance)) |owner_doc| {
                // Get the document's defaultView (the window that contains this document)
                if (DocumentImpl.get_defaultView(owner_doc) catch null) |default_view| {
                    break :blk default_view;
                }
            }
            // Fall back to window from current V8 context (for top-level iframes)
            break :blk context_manager.getWindowForContext(current_v8_ctx) orelse {
                if (internal.integration.getContentWindow()) |proxy| {
                    return @ptrCast(proxy);
                }
                return null;
            };
        };
        const WindowImpl = @import("Window.zig");

        // Use current V8 context for child context creation
        const parent_v8_ctx = current_v8_ctx;

        const parent_window_internal = WindowImpl.getInternal(parent_window) orelse {
            if (internal.integration.getContentWindow()) |proxy| {
                return @ptrCast(proxy);
            }
            return null;
        };

        // Set the container_origin from the parent window's origin.
        // This is required for same-origin checks in contentDocument.
        // Per spec, the container origin is the origin of the parent document.
        // The Window stores its origin as a string (e.g., "http://localhost:8000"),
        // so we need to parse it into an Origin struct.
        const parent_origin_str = parent_window_internal.origin;
        const parent_origin = parseOriginFromString(parent_origin_str);
        internal.integration.container_origin = parent_origin;

        // Ensure the iframe's browsing context exists (lazy creation)
        const existing_bc = internal.integration.ensureBrowsingContext(
            @ptrCast(parent_window_internal.browsing_context),
        ) orelse {
            if (internal.integration.getContentWindow()) |proxy| {
                return @ptrCast(proxy);
            }
            return null;
        };

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
            .existing_browsing_context = @ptrCast(existing_bc),
        }, internal.allocator) catch {
            // Fall back to WindowProxy if context creation fails
            if (internal.integration.getContentWindow()) |proxy| {
                return @ptrCast(proxy);
            }
            return null;
        };

        // CRITICAL: Set the Window's origin from the parent for srcdoc/about:blank iframes.
        // Per HTML spec, srcdoc iframes inherit their origin from the container document.
        // The Window's origin defaults to "null" (opaque), which breaks same-origin checks.
        // We must set it to the parent's origin so contentDocument is accessible.
        if (entry.window_instance) |window_inst| {
            const WinImpl = @import("Window.zig");
            WinImpl.setOrigin(window_inst, parent_origin_str) catch {};
        }

        // Store the realm context in the integration for cleanup on removal
        internal.integration.setRealmContext(
            @ptrCast(entry.v8_ctx),
            @ptrCast(entry.realm),
            @ptrCast(entry),
            @ptrCast(&entry.runtime_ctx),
            createDocumentForIframe,
            iframeContextCleanup,
            parseHtmlForIframe,
        );

        // Set script execution callbacks (for script execution in iframe documents)
        internal.integration.execute_script_callback = &executeIframeScript;
        internal.integration.update_location_callback = &updateIframeLocation;

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
            WinImpl.replaceBrowsingContext(window_instance, @ptrCast(existing_bc));
        }

        // Create the initial about:blank Document for the iframe.
        // Per HTML spec §7.5.1, every browsing context has an active document.
        // For about:blank, the document is created immediately when the browsing
        // context is created, not through navigation.
        // We call the createDocumentForIframe callback directly to create and
        // associate the Document with the browsing context.
        _ = createDocumentForIframe(@ptrCast(&entry.runtime_ctx), existing_bc);

        // Fire the load event on the iframe element ONLY if no srcdoc/src navigation is pending.
        // Per HTML spec §4.8.5, the "iframe load event steps" fire a load event
        // at the iframe element after the document is completely loaded.
        // For about:blank documents (no srcdoc/src), this happens synchronously.
        // If srcdoc or src is set, the load event will be fired after navigation completes.
        //
        // CRITICAL: Also check the element's attribute list for srcdoc, not just internal state.
        // For nested iframes created by HTML parsing, the srcdoc attribute is in the element's
        // attribute list but not in internal.srcdoc_attr (because Element.setAttribute doesn't
        // call the IDL setter).
        const has_srcdoc_attr = blk: {
            const ElementImpl = @import("Element.zig");
            const srcdoc_attr_name = runtime.DOMString.initInterned("srcdoc");
            const srcdoc_value = ElementImpl.call_getAttribute(instance, srcdoc_attr_name) catch null;
            if (srcdoc_value) |sv| {
                break :blk sv.asSlice().len > 0;
            }
            break :blk false;
        };
        const has_src_attr = blk: {
            const ElementImpl = @import("Element.zig");
            const src_attr_name = runtime.DOMString.initInterned("src");
            const src_value = ElementImpl.call_getAttribute(instance, src_attr_name) catch null;
            if (src_value) |sv| {
                break :blk sv.asSlice().len > 0;
            }
            break :blk false;
        };
        if (internal.srcdoc_attr == null and internal.src_attr == null and !has_srcdoc_attr and !has_src_attr) {
            fireLoadEventOnIframe(instance);
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
/// Returns a newly allocated copy of the src attribute.
/// The V8 interface layer will free the returned string after converting to V8.
pub fn get_src(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return "";

    if (internal.src_attr) |src| {
        // Must dupe - V8 interface layer frees getter results
        return try internal.allocator.dupe(u8, src);
    }
    return "";
}

/// Setter for src
/// Setting src triggers navigation to the new URL.
///
/// Per HTML Standard §4.8.5, setting src navigates the iframe to the given URL.
/// For WPT tests, we check if an external hook is registered to handle relative
/// and HTTP URLs. This allows the WPT runner to load content from its file system.
pub fn set_src(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    // Free old value
    if (internal.src_attr) |old| {
        internal.allocator.free(old);
    }

    // Store new value - USVString is []const u8
    internal.src_attr = try internal.allocator.dupe(u8, value);

    // Ensure the V8 context exists before navigation.
    // Per HTML spec, when src is set, the iframe should navigate to the URL.
    // Scripts in the navigated document need a V8 context to execute.
    // Accessing contentWindow lazily creates the V8 context if needed.
    _ = try get_contentWindow(instance);

    // Check if an external hook is registered to handle this URL
    // The hook handles relative URLs and HTTP URLs for WPT tests
    if (iframe_src_load_hook) |hook| {
        // Check if this URL needs external handling (relative or HTTP)
        const needs_external = !std.mem.startsWith(u8, value, "about:") and
            !std.mem.startsWith(u8, value, "data:") and
            !std.mem.startsWith(u8, value, "file://") and
            !std.mem.startsWith(u8, value, "javascript:");

        if (needs_external) {
            // Try the external hook first
            if (hook(instance, value)) {
                // Hook handled the load - don't call integration.setSrc
                return;
            }
        }
    }

    // Trigger navigation via integration
    // Navigation errors are typically silent for iframe src
    internal.integration.setSrc(value) catch {};
}

/// Getter for srcdoc
pub fn get_srcdoc(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initInterned("");

    if (internal.srcdoc_attr) |srcdoc| {
        return runtime.DOMString.initInterned(srcdoc);
    }
    return runtime.DOMString.initInterned("");
}

/// Setter for srcdoc
/// Setting srcdoc loads inline HTML content.
pub fn set_srcdoc(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    // Free old value
    if (internal.srcdoc_attr) |old| {
        internal.allocator.free(old);
    }

    // Store new value - DOMString.asSlice() gets the underlying []const u8
    const str = value.asSlice();
    internal.srcdoc_attr = try internal.allocator.dupe(u8, str);

    // CRITICAL: Read and apply the sandbox attribute BEFORE creating the browsing context.
    // Per HTML spec §4.8.5, the sandbox attribute affects script execution in the iframe.
    // When setAttribute('sandbox', '') is called, it sets the attribute on the Element,
    // but the IFrameIntegration needs to be notified to set sandbox flags on the
    // BrowsingContext. Without this, scripts will execute even in sandboxed iframes.
    const ElementImpl = @import("Element.zig");
    const sandbox_attr_name = runtime.DOMString.initInterned("sandbox");
    if (ElementImpl.call_hasAttribute(instance, sandbox_attr_name) catch false) {
        // Sandbox attribute exists (even if empty string)
        const sandbox_value = ElementImpl.call_getAttribute(instance, sandbox_attr_name) catch null;
        const sandbox_str = if (sandbox_value) |sv| sv.asSlice() else "";
        // Apply sandbox flags to the integration
        internal.integration.setSandbox(sandbox_str) catch {};
    }

    // Ensure the V8 context exists before navigation.
    // Scripts in srcdoc content need a V8 context to execute.
    _ = try get_contentWindow(instance);

    // Trigger navigation via integration
    // Navigation errors are typically silent
    internal.integration.setSrcdoc(str) catch {};
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
    internal.integration.onRemovedFromDocument();
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
var insertion_steps_registered: bool = false;

/// Ensure the iframe removing steps callback is registered.
/// This is called lazily during iframe creation to ensure the callback is set up.
pub fn ensureRemovingStepsRegistered() void {
    if (removing_steps_registered) return;
    registerIframeRemovingSteps() catch return;
    removing_steps_registered = true;
}

// ============================================================================
// Insertion Steps Callback for Iframe Browsing Context Creation
// ============================================================================

/// Insertion steps callback for iframe elements.
/// This callback is registered with the DOM mutation system and is called whenever
/// a node is inserted into the document. If the node is an iframe element, this
/// function triggers browsing context creation if not already created.
///
/// Per HTML spec §4.8.5, when an iframe is inserted into a document that has
/// a browsing context:
/// 1. Create a nested browsing context for the element
/// 2. Process the iframe attributes (src, srcdoc, etc.)
///
/// This is critical for window.frames[name] to work - the browsing context must
/// exist and have its name set before JavaScript can access it via the frames collection.
fn iframeInsertionStepsCallback(node: *NodeBase) void {
    // Only process ELEMENT_NODE (nodeType == 1)
    if (node.node_type != 1) return;

    // Check if this is an iframe element by looking at the node_name.
    // For HTML elements, node_name is the uppercase tag name (e.g., "IFRAME").
    // We also check for lowercase "iframe" for robustness.
    if (!std.ascii.eqlIgnoreCase(node.node_name, "iframe")) return;

    // Get the runtime.Instance from the NodeBase using the instance bridge
    const instance_ptr = instance_bridge.getInstance(node) orelse return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_ptr));

    // Get the iframe's internal state
    const internal = getInternal(instance) orelse return;

    // If the browsing context already exists, we're done
    // (this handles re-insertion of an iframe that was previously in the document)
    if (internal.integration.browsing_context != null) {
        return;
    }

    // Trigger lazy creation of the browsing context by accessing contentWindow.
    // This will:
    // 1. Create the child V8 context
    // 2. Create the browsing context and add it to the parent's children list
    // 3. Set the target_name on the browsing context (if name attribute is set)
    // 4. Create the initial about:blank document
    //
    // After this, window.frames[name] will work because the browsing context
    // is in the parent's children list with its name set.
    _ = get_contentWindow(instance) catch return;

    // If the iframe has a name set, ensure it's propagated to the browsing context.
    // This handles the case where name was set before insertion.
    if (internal.name_attr) |name| {
        internal.integration.setName(name) catch {};
        // Also set on the browsing context directly
        if (internal.integration.browsing_context) |bc| {
            bc.setTargetName(name) catch {};
        }

        // Register the named property on the parent window's global object
        // This is needed because V8's named property interceptors don't work after snapshot restore.
        // By setting window[name] = contentWindow, we enable window.frames['name'] to work.
        registerNamedPropertyOnParentGlobal(instance, name);
    }
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

    // Get the parent's global object
    const global = v8.ffi.v8_Context_Global(parent_v8_ctx) orelse return;

    // Get the child Window instance and its V8 context from its realm
    const child_window_ptr = child_bc.active_window orelse return;
    const child_window: *runtime.Instance = @ptrCast(@alignCast(child_window_ptr));
    const child_ctx_data = child_window.ctx;
    const child_realm = child_ctx_data.realm orelse return;

    const child_v8_ctx_ptr = child_realm.getV8Context() orelse return;
    const child_v8_ctx: *v8.ffi.Context = @ptrCast(@alignCast(child_v8_ctx_ptr));

    // Get the child window's V8 wrapper (the global object of the child context)
    const child_global = v8.ffi.v8_Context_Global(child_v8_ctx) orelse return;

    // Create the property name string
    const name_str = v8.ffi.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse return;

    // Set the property: window[name] = child's global (contentWindow)
    _ = v8.ffi.v8_Object_Set(global, parent_v8_ctx, @ptrCast(name_str), @ptrCast(child_global));
}

/// Register the iframe insertion steps callback with the DOM mutation system.
/// This should be called during application initialization.
pub fn registerIframeInsertionSteps() !void {
    try dom_module.mutation.registerInsertionStepsCallback(&iframeInsertionStepsCallback);
}

/// Ensure the iframe insertion steps callback is registered.
/// This is called lazily during iframe creation to ensure the callback is set up.
pub fn ensureInsertionStepsRegistered() void {
    if (insertion_steps_registered) return;
    registerIframeInsertionSteps() catch return;
    insertion_steps_registered = true;
}
