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
pub fn set_src(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    // Free old value
    if (internal.src_attr) |old| {
        internal.allocator.free(old);
    }

    // Store new value - USVString is []const u8
    internal.src_attr = try internal.allocator.dupe(u8, value);

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
