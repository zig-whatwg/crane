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
const HTMLIFrameElement = interfaces.HTMLIFrameElement;
const DOMTokenList = interfaces.DOMTokenList;
const DOMTokenListImpl = @import("DOMTokenList.zig");

// Import html_core for IFrameIntegration (interface-free module)
const html_core = @import("html_core");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const IFrameIntegration = html_core.IFrameIntegration;
const Origin = html_core.Origin;
const SandboxFlags = html_core.SandboxFlags;

// V8 imports for cross-realm support (Phase 3)
const v8 = @import("v8");
const context_manager = v8.context_manager;

// HTML parser for data: URL content
const html_parser = @import("html").parser;
const webidl = @import("webidl");
const EventTarget = interfaces.EventTarget;
const Event = interfaces.Event;

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

        // Clean up sandbox_token_list DOMTokenList if it was created
        // This is a lazily-created [SameObject] instance that owns resources
        if (self.sandbox_token_list) |token_list| {
            DOMTokenList.deinit(token_list);
            self.sandbox_token_list = null;
        }

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
        context_manager.destroyChildContext(entry, integration.allocator);
    }
}

/// Document creation callback for iframe navigation
/// Called when navigateToSrcDoc or navigateToSrc needs to create a Document instance.
/// Parameters: (runtime_context, browsing_context) -> document_instance
fn createDocumentForIframe(runtime_ctx_ptr: ?*anyopaque, browsing_ctx_ptr: *html_core.BrowsingContext) ?*anyopaque {
    const runtime_ctx: runtime.Context = @ptrCast(@alignCast(runtime_ctx_ptr orelse return null));
    const allocator = runtime_ctx.allocator;

    // Create a Document instance using the WebIDL interface
    const document_instance = interfaces.Document.init(allocator, runtime_ctx) catch return null;

    // Get the active window for this browsing context to associate with the document
    if (browsing_ctx_ptr.getActiveWindow()) |window_ptr| {
        // Set the document on the browsing context
        browsing_ctx_ptr.setActiveDocument(document_instance, window_ptr);

        // Also set the document on the Window
        const WindowImpl = @import("Window.zig");
        const window_instance: *runtime.Instance = @ptrCast(@alignCast(window_ptr));
        WindowImpl.setDocument(window_instance, document_instance);
    }

    return document_instance;
}

/// Getter for contentWindow
/// Returns the WindowProxy for the nested browsing context, or null if none.
///
/// Per HTML Standard §4.8.5, the contentWindow getter returns the WindowProxy
/// for the nested browsing context. This WindowProxy provides access to the
/// Window object in the iframe's realm.
///
/// Phase 4 (Window-as-V8-Global): The Window instance IS bound to the V8 global
/// object, enabling proper cross-realm access:
/// - `iframe.contentWindow.DOMRectReadOnly` returns the constructor
/// - `iframe.contentWindow === iframe.contentWindow.window` is true
/// - Cross-realm toJSON tests pass (result objects use the method's realm)
pub fn get_contentWindow(instance: *runtime.Instance) anyerror!?typedefs.WindowProxy {
    const internal = getInternal(instance) orelse return null;

    // Ensure the realm and V8 context are created (lazy initialization)
    // This creates a child V8 context with all interface bindings
    if (!internal.integration.hasRealmContext()) {
        // Get the current V8 isolate and context
        const isolate = v8.ffi.v8_Isolate_GetCurrent() orelse {
            // Fall back to WindowProxy if no V8 isolate
            if (internal.integration.getContentWindow()) |proxy| {
                return @ptrCast(proxy);
            }
            return null;
        };

        const parent_v8_ctx = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
            // Fall back to WindowProxy if no current context
            if (internal.integration.getContentWindow()) |proxy| {
                return @ptrCast(proxy);
            }
            return null;
        };

        // CRITICAL: Ensure the iframe's browsing context exists BEFORE creating the V8 context.
        // The browsing context is created by IFrameIntegration.onInsertedIntoDocument() when the
        // iframe is inserted into the DOM. However, that function may not have been called yet
        // (e.g., if insertion steps callbacks aren't set up). We lazily create it here.
        //
        // Get the parent Window's browsing context to use as the parent for the child BC.
        const parent_window = context_manager.getWindowForContext(parent_v8_ctx) orelse {
            if (internal.integration.getContentWindow()) |proxy| {
                return @ptrCast(proxy);
            }
            return null;
        };

        const WindowImpl = @import("Window.zig");
        const parent_window_internal = WindowImpl.getInternal(parent_window) orelse {
            if (internal.integration.getContentWindow()) |proxy| {
                return @ptrCast(proxy);
            }
            return null;
        };

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

        // Store the realm context in the integration for cleanup on removal
        internal.integration.setRealmContext(
            @ptrCast(entry.v8_ctx),
            @ptrCast(entry.realm),
            @ptrCast(entry),
            @ptrCast(&entry.runtime_ctx),
            createDocumentForIframe,
            iframeContextCleanup,
        );
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
pub fn get_contentDocument(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;

    // 1. If no content navigable (browsing context), return null
    const browsing_ctx = internal.integration.browsing_context orelse return null;

    // 2. Get the active document from the browsing context
    // BrowsingContext stores it as *anyopaque to avoid module conflicts,
    // so we cast it back to *runtime.Instance here.
    const document_ptr = browsing_ctx.getActiveDocument() orelse return null;
    const document: *runtime.Instance = @ptrCast(@alignCast(document_ptr));

    // 3. Get accessor origin - for WPT tests and same-origin scenarios,
    //    we use the container document's origin as the accessor origin.
    //    In a full implementation, this would come from the incumbent settings object.
    //    Since we're in the same execution context (WPT tests are same-origin),
    //    we use the container origin which is already stored in the integration.
    const accessor_origin = internal.integration.container_origin;

    // 4. Check same origin-domain access
    if (!internal.integration.isContentDocumentAccessible(accessor_origin)) {
        return null;
    }

    // 5. Return the document
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

    // Handle data: URLs with script execution
    if (std.mem.startsWith(u8, value, "data:")) {
        loadDataUrl(instance, internal, value) catch |err| {
            std.debug.print("[set_src] Failed to load data: URL: {}\n", .{err});
        };
        std.debug.print("[set_src] loadDataUrl completed\n", .{});
        return;
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
// Data URL Loading with Script Execution
// ============================================================================

/// Load a data: URL with proper script execution
/// Debug function to print tree structure
fn debugPrintTreeNode(node: *html_parser.TreeNode, depth: usize) void {
    var indent: [64]u8 = undefined;
    const indent_len = @min(depth * 2, 62);
    for (0..indent_len) |i| {
        indent[i] = ' ';
    }
    const indent_slice = indent[0..indent_len];

    switch (node.node_type) {
        .document => std.debug.print("{s}#document\n", .{indent_slice}),
        .element => {
            if (node.local_name) |name| {
                std.debug.print("{s}<{s}>\n", .{ indent_slice, name });
            }
        },
        .text => {
            const text = node.text_content.toSlice();
            if (text.len > 30) {
                std.debug.print("{s}#text: {s}...\n", .{ indent_slice, text[0..30] });
            } else {
                std.debug.print("{s}#text: {s}\n", .{ indent_slice, text });
            }
        },
        else => {},
    }

    var child = node.first_child;
    while (child) |c| {
        debugPrintTreeNode(c, depth + 1);
        child = c.next_sibling;
    }
}

/// Per HTML Standard §4.8.5, navigating an iframe to a data: URL should:
/// 1. Parse the data URL to extract content
/// 2. Create a new document in the iframe's browsing context
/// 3. Parse the HTML content
/// 4. Execute any scripts in the content
/// 5. Fire the 'load' event on the iframe
fn loadDataUrl(iframe: *runtime.Instance, internal: *InternalState, data_url: []const u8) !void {
    std.debug.print("[loadDataUrl] Starting to load data URL\n", .{});
    const allocator = internal.allocator;

    // Parse the data URL
    const content = try parseDataUrl(allocator, data_url);
    defer if (content.needs_free) allocator.free(content.data);
    std.debug.print("[loadDataUrl] Parsed data URL, mime={s}, data_len={d}\n", .{ content.mime_type, content.data.len });

    // Only process text/html content
    if (!std.mem.startsWith(u8, content.mime_type, "text/html")) {
        // Non-HTML content - delegate to integration
        internal.integration.setSrc(data_url) catch {};
        return;
    }

    // Ensure the iframe has a V8 context (creates browsing context if needed)
    const content_window = try get_contentWindow(iframe);
    if (content_window == null) {
        std.debug.print("[loadDataUrl] Failed to get contentWindow\n", .{});
        return;
    }

    // Get the V8 context for the iframe from the integration
    const engine_ctx = internal.integration.getEngineContext() orelse {
        std.debug.print("[loadDataUrl] No engine context for iframe\n", .{});
        return;
    };
    const child_v8_context: *v8.ffi.Context = @ptrCast(@alignCast(engine_ctx));

    const isolate = v8.ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;

    // Get the iframe's contentDocument to populate with parsed content
    // Note: We bypass get_contentDocument's same-origin check since this is internal
    // data: URL loading, not cross-origin JavaScript access
    const browsing_ctx = internal.integration.browsing_context orelse {
        std.debug.print("[loadDataUrl] No browsing context\n", .{});
        return;
    };
    const content_document: *runtime.Instance = @ptrCast(@alignCast(browsing_ctx.getActiveDocument() orelse {
        std.debug.print("[loadDataUrl] No active document in browsing context\n", .{});
        return;
    }));

    // Set the document's URL to the data: URL (including fragment)
    // This is needed for :target pseudo-class matching
    const DocumentImpl = @import("Document.zig");
    DocumentImpl.setUrl(content_document, data_url) catch |err| {
        std.debug.print("[loadDataUrl] Failed to set document URL: {}\n", .{err});
    };

    // Parse HTML content using the tokenizer and tree builder
    var tokenizer = html_parser.Tokenizer.init(allocator, content.data);
    defer tokenizer.deinit();

    var tree_builder = try html_parser.TreeBuilder.init(allocator, &tokenizer);
    defer tree_builder.deinit();

    // Run the tree building algorithm - processes all tokens
    try tree_builder.parse();

    // Convert parsed tree to DOM nodes and add to contentDocument
    const parsed_doc = tree_builder.document;

    // Get the runtime context from the iframe's context
    const ctx = context_manager.get(child_v8_context) orelse {
        std.debug.print("[loadDataUrl] Failed to get runtime context\n", .{});
        return;
    };

    // Convert the parsed tree to real DOM nodes and populate the contentDocument
    try populateDocumentFromTree(content_document, parsed_doc, ctx, isolate, child_v8_context, allocator);
    std.debug.print("[loadDataUrl] DOM populated\n", .{});

    // Run microtasks
    v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);

    // Fire 'load' event on the iframe's window and iframe element
    try fireLoadEventOnIframe(iframe, internal);
}

/// Populate a Document with content from a parsed TreeNode tree
/// This converts the TreeNode structure to real DOM nodes and adds them to the document,
/// executing scripts as they are encountered.
fn populateDocumentFromTree(
    document: *runtime.Instance,
    parsed_tree: *html_parser.TreeNode,
    ctx: runtime.Context,
    isolate: *v8.ffi.Isolate,
    v8_ctx: *v8.ffi.Context,
    allocator: std.mem.Allocator,
) !void {
    const DocumentImpl = @import("Document.zig");
    const NodeImpl = @import("Node.zig");
    const ElementImpl = @import("Element.zig");

    // Clear existing children from document
    while (try interfaces.Node.get_firstChild(document)) |first_child| {
        _ = try interfaces.Node.call_removeChild(document, first_child);
    }

    // Get document_element from parsed tree (should be <html>)
    var html_node = parsed_tree.first_child;
    while (html_node) |node| {
        if (node.node_type == .element) {
            if (node.local_name) |name| {
                if (std.mem.eql(u8, name, "html")) {
                    break;
                }
            }
        }
        html_node = node.next_sibling;
    }

    if (html_node == null) {
        std.debug.print("[populateDocumentFromTree] No <html> element found\n", .{});
        return;
    }

    // Create <html> element
    const html_element = try interfaces.HTMLHtmlElement.init(allocator, ctx);
    try ElementImpl.setLocalName(html_element, "html");
    try NodeImpl.setOwnerDocument(html_element, document);
    _ = try interfaces.Node.call_appendChild(document, html_element);

    // Set as document element
    if (DocumentImpl.getInternal(document)) |doc_internal| {
        doc_internal.document_element = html_element;
    }

    // Process children of <html> (head and body)
    var head_node: ?*html_parser.TreeNode = null;
    var body_node: ?*html_parser.TreeNode = null;

    var child = html_node.?.first_child;
    while (child) |c| {
        if (c.node_type == .element) {
            if (c.local_name) |name| {
                if (std.mem.eql(u8, name, "head")) {
                    head_node = c;
                } else if (std.mem.eql(u8, name, "body")) {
                    body_node = c;
                }
            }
        }
        child = c.next_sibling;
    }

    // Create <head> if found
    if (head_node) |hn| {
        const head_element = try interfaces.HTMLHeadElement.init(allocator, ctx);
        try ElementImpl.setLocalName(head_element, "head");
        try NodeImpl.setOwnerDocument(head_element, document);
        _ = try interfaces.Node.call_appendChild(html_element, head_element);

        // Process head children (style, etc.)
        try convertChildrenToDOM(hn, head_element, document, ctx, isolate, v8_ctx, allocator);
    }

    // Create <body>
    const body_element = try interfaces.HTMLBodyElement.init(allocator, ctx);
    try ElementImpl.setLocalName(body_element, "body");
    try NodeImpl.setOwnerDocument(body_element, document);
    _ = try interfaces.Node.call_appendChild(html_element, body_element);

    // Process body children
    if (body_node) |bn| {
        try convertChildrenToDOM(bn, body_element, document, ctx, isolate, v8_ctx, allocator);
    }
}

/// Convert TreeNode children to DOM nodes and append to parent
fn convertChildrenToDOM(
    tree_node: *html_parser.TreeNode,
    parent: *runtime.Instance,
    document: *runtime.Instance,
    ctx: runtime.Context,
    isolate: *v8.ffi.Isolate,
    v8_ctx: *v8.ffi.Context,
    allocator: std.mem.Allocator,
) !void {
    const NodeImpl = @import("Node.zig");
    const ElementImpl = @import("Element.zig");

    var child = tree_node.first_child;
    while (child) |c| {
        switch (c.node_type) {
            .element => {
                if (c.local_name) |name| {
                    std.debug.print("[convertChildrenToDOM] Element: {s}, has_children={}\n", .{ name, c.first_child != null });
                    // Check if it's a script element
                    if (std.mem.eql(u8, name, "script")) {
                        // Execute script immediately
                        try executeScriptInIframe(c, isolate, v8_ctx, allocator);
                    } else {
                        // Create the element
                        const element = try createElementForTag(name, allocator, ctx);
                        try ElementImpl.setLocalName(element, name);
                        try NodeImpl.setOwnerDocument(element, document);

                        // Copy id attribute if present
                        const attrs = c.attributes.toSlice();
                        for (attrs) |attr| {
                            if (std.mem.eql(u8, attr.name, "id")) {
                                _ = try interfaces.Element.call_setAttribute(
                                    element,
                                    runtime.DOMString.initInterned("id"),
                                    runtime.DOMString.initOwned(attr.value),
                                );
                                break;
                            }
                        }

                        // Recursively process children
                        try convertChildrenToDOM(c, element, document, ctx, isolate, v8_ctx, allocator);

                        _ = try interfaces.Node.call_appendChild(parent, element);
                    }
                }
            },
            .text => {
                const text_content = c.text_content.toSlice();
                std.debug.print("[convertChildrenToDOM] Text node: len={d}, content={s}\n", .{ text_content.len, if (text_content.len > 50) text_content[0..50] else text_content });
                if (text_content.len > 0) {
                    // Skip whitespace-only text nodes
                    var has_content = false;
                    for (text_content) |ch| {
                        if (ch != ' ' and ch != '\t' and ch != '\n' and ch != '\r') {
                            has_content = true;
                            break;
                        }
                    }
                    if (has_content) {
                        const text_node = try interfaces.Text.init(allocator, ctx);
                        try NodeImpl.setOwnerDocument(text_node, document);
                        // Set text content via CharacterData
                        const CharacterDataImpl = @import("CharacterData.zig");
                        try CharacterDataImpl.setData(text_node, text_content);

                        _ = try interfaces.Node.call_appendChild(parent, text_node);
                        // Verify the node was actually added
                        const first_child = try interfaces.Node.get_firstChild(parent);
                        std.debug.print("[convertChildrenToDOM] Added text node to DOM, parent now has firstChild={}\n", .{first_child != null});
                    }
                }
            },
            else => {},
        }
        child = c.next_sibling;
    }
}

/// Create an appropriate element instance for a given tag name
fn createElementForTag(tag_name: []const u8, allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
    // Map common tags to their specific interfaces
    if (std.mem.eql(u8, tag_name, "p")) {
        return try interfaces.HTMLParagraphElement.init(allocator, ctx);
    } else if (std.mem.eql(u8, tag_name, "div")) {
        return try interfaces.HTMLDivElement.init(allocator, ctx);
    } else if (std.mem.eql(u8, tag_name, "span")) {
        return try interfaces.HTMLSpanElement.init(allocator, ctx);
    } else if (std.mem.eql(u8, tag_name, "style")) {
        return try interfaces.HTMLStyleElement.init(allocator, ctx);
    } else if (std.mem.eql(u8, tag_name, "a")) {
        return try interfaces.HTMLAnchorElement.init(allocator, ctx);
    } else {
        // Default to generic HTMLElement
        return try interfaces.HTMLElement.init(allocator, ctx);
    }
}

/// Parse a data: URL and extract the content
const DataUrlContent = struct {
    data: []const u8,
    mime_type: []const u8,
    needs_free: bool,
};

fn parseDataUrl(allocator: std.mem.Allocator, url: []const u8) !DataUrlContent {
    // data:[<mediatype>][;base64],<data>
    // Note: Fragment (#foo) must be stripped from data before parsing
    // Per URL spec, fragment is not part of the data content
    const data_start = std.mem.indexOf(u8, url, ":") orelse return error.InvalidUrl;
    const rest = url[data_start + 1 ..];

    // Find comma separating metadata from data
    const comma_pos = std.mem.indexOf(u8, rest, ",") orelse return error.InvalidUrl;
    const metadata = rest[0..comma_pos];
    var encoded_data = rest[comma_pos + 1 ..];

    // Strip fragment identifier from data - fragment is NOT part of the data content
    // e.g., data:text/html,<p>Hello</p>#foo should only parse "<p>Hello</p>"
    if (std.mem.indexOf(u8, encoded_data, "#")) |fragment_pos| {
        encoded_data = encoded_data[0..fragment_pos];
    }

    // Parse metadata
    var mime_type: []const u8 = "text/plain";
    var is_base64 = false;

    if (metadata.len > 0) {
        if (std.mem.endsWith(u8, metadata, ";base64")) {
            is_base64 = true;
            const mime_part = metadata[0 .. metadata.len - 7];
            if (mime_part.len > 0) {
                mime_type = mime_part;
            }
        } else {
            mime_type = metadata;
        }
    }

    // Decode data
    if (is_base64) {
        const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(encoded_data) catch {
            return error.ParseError;
        };
        const decoded = try allocator.alloc(u8, decoded_len);
        errdefer allocator.free(decoded);

        _ = std.base64.standard.Decoder.decode(decoded, encoded_data) catch {
            allocator.free(decoded);
            return error.ParseError;
        };
        return .{ .data = decoded, .mime_type = mime_type, .needs_free = true };
    } else {
        // URL decode
        const decoded = try percentDecode(allocator, encoded_data);
        return .{ .data = decoded, .mime_type = mime_type, .needs_free = true };
    }
}

/// Percent-decode a string
fn percentDecode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result: std.ArrayList(u8) = .{};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        if (input[i] == '%' and i + 2 < input.len) {
            const hex = input[i + 1 .. i + 3];
            const byte = std.fmt.parseInt(u8, hex, 16) catch {
                try result.append(allocator, input[i]);
                i += 1;
                continue;
            };
            try result.append(allocator, byte);
            i += 3;
        } else {
            try result.append(allocator, input[i]);
            i += 1;
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Execute scripts in an iframe's parsed document tree
fn executeScriptsInIframe(
    node: *html_parser.TreeNode,
    isolate: *v8.ffi.Isolate,
    context: *v8.ffi.Context,
    allocator: std.mem.Allocator,
) !void {
    // Check if this is a script element
    if (node.node_type == .element) {
        if (node.local_name) |name| {
            std.debug.print("[executeScriptsInIframe] Found element: {s}\n", .{name});
            if (std.mem.eql(u8, name, "script")) {
                std.debug.print("[executeScriptsInIframe] Found script element!\n", .{});
                try executeScriptInIframe(node, isolate, context, allocator);
            }
        }
    }

    // Recurse to children
    var child = node.first_child;
    while (child) |c| {
        try executeScriptsInIframe(c, isolate, context, allocator);
        child = c.next_sibling;
    }
}

/// Execute a single script element in the iframe's V8 context
fn executeScriptInIframe(
    script_node: *html_parser.TreeNode,
    isolate: *v8.ffi.Isolate,
    context: *v8.ffi.Context,
    allocator: std.mem.Allocator,
) !void {
    // Get script content from child text nodes
    var script_content: std.ArrayList(u8) = .{};
    defer script_content.deinit(allocator);

    var child = script_node.first_child;
    while (child) |c| {
        if (c.node_type == .text) {
            const text = c.text_content.toSlice();
            try script_content.appendSlice(allocator, text);
        }
        child = c.next_sibling;
    }

    if (script_content.items.len == 0) {
        std.debug.print("[executeScriptInIframe] Empty script content\n", .{});
        return;
    }

    std.debug.print("[executeScriptInIframe] Executing script ({d} chars)\n", .{script_content.items.len});

    // Create handle scope for this script
    const handle_scope = v8.ffi.v8_HandleScope_New(isolate) orelse return;
    defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

    // Execute the script in the iframe's context
    // First, we need to enter the context
    v8.ffi.v8_Context_Enter(context);
    defer v8.ffi.v8_Context_Exit(context);

    // Execute the script
    const source_str = v8.ffi.v8_String_NewFromUtf8(
        isolate,
        script_content.items.ptr,
        @intCast(script_content.items.len),
    ) orelse {
        std.debug.print("[executeScriptInIframe] Failed to create source string\n", .{});
        return;
    };

    const compiled = v8.ffi.v8_Script_Compile(context, source_str) orelse {
        std.debug.print("[executeScriptInIframe] Failed to compile script\n", .{});
        return;
    };
    const result = v8.ffi.v8_Script_Run(context, compiled);
    if (result == null) {
        std.debug.print("[executeScriptInIframe] Script execution returned null\n", .{});
    } else {
        std.debug.print("[executeScriptInIframe] Script executed successfully\n", .{});
    }

    // Run microtasks
    v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);
    std.debug.print("[executeScriptInIframe] Microtasks checkpointed\n", .{});
}

/// Fire 'load' event on the iframe's window and iframe element
/// Per HTML spec, the 'load' event should fire on:
/// 1. The Window inside the iframe (when the document finishes loading)
/// 2. Then on the iframe element
fn fireLoadEventOnIframe(iframe: *runtime.Instance, internal: *InternalState) !void {
    std.debug.print("[fireLoadEventOnIframe] Starting to fire load events\n", .{});

    // First, fire 'load' on the iframe's contentWindow
    if (internal.integration.getEngineContext()) |engine_ctx| {
        const v8_ctx: *v8.ffi.Context = @ptrCast(@alignCast(engine_ctx));
        if (context_manager.getWindowForContext(v8_ctx)) |window_instance| {
            std.debug.print("[fireLoadEventOnIframe] Found window instance, firing load event\n", .{});

            const window_ctx = window_instance.ctx;
            const event_type = runtime.DOMString.initInterned("load");
            const event_init = dictionaries.EventInit{
                .bubbles = false,
                .cancelable = false,
                .composed = false,
            };

            const window_event = try Event.call_constructor(
                window_ctx,
                event_type,
                webidl.Opt(dictionaries.EventInit).passed(event_init),
            );
            defer Event.deinit(window_event);

            // Dispatch load event on the window
            _ = try EventTarget.call_dispatchEvent(window_instance, window_event);
            std.debug.print("[fireLoadEventOnIframe] Load event dispatched on window\n", .{});
        } else {
            std.debug.print("[fireLoadEventOnIframe] No window instance found\n", .{});
        }
    } else {
        std.debug.print("[fireLoadEventOnIframe] No engine context\n", .{});
    }

    // Then fire 'load' on the iframe element itself
    const iframe_ctx = iframe.ctx;
    const iframe_event_type = runtime.DOMString.initInterned("load");
    const iframe_event_init = dictionaries.EventInit{
        .bubbles = false,
        .cancelable = false,
        .composed = false,
    };

    const iframe_event = try Event.call_constructor(
        iframe_ctx,
        iframe_event_type,
        webidl.Opt(dictionaries.EventInit).passed(iframe_event_init),
    );
    defer Event.deinit(iframe_event);

    _ = try EventTarget.call_dispatchEvent(iframe, iframe_event);
    std.debug.print("[fireLoadEventOnIframe] Load event dispatched on iframe element\n", .{});
}
