//! IFrame Browsing Context Integration - HTML Standard §7.5
//!
//! This module handles the lifecycle management of browsing contexts for iframe elements.
//! When an iframe is inserted into the DOM, a nested browsing context is created.
//! When removed, the browsing context is destroyed.
//!
//! Spec: https://html.spec.whatwg.org/multipage/iframe-embed-object.html
//!
//! ## Key Algorithms
//!
//! - Create a nested browsing context (§7.1)
//! - Process the iframe attributes (src, srcdoc, sandbox)
//! - Navigate to the initial URL or create about:blank
//!
//! ## Architecture
//!
//! IFrameIntegration provides the glue between:
//! - HTMLIFrameElement (the DOM element)
//! - BrowsingContext (the environment for documents)
//! - WindowProxy (the cross-origin access control)

const std = @import("std");
const log = std.log.scoped(.iframe);
const Allocator = std.mem.Allocator;
const browsing_context = @import("browsing_context.zig");
const BrowsingContext = browsing_context.BrowsingContext;
const SandboxFlags = browsing_context.SandboxFlags;
const WindowProxy = @import("window_proxy.zig").WindowProxy;
const Origin = @import("window_proxy.zig").Origin;
const html_parser = @import("../parser/root.zig");
const encoding_sniffing = html_parser.encoding_sniffing;
// Navigation fetch and the "load a document" MIME routing. Both live in the
// navigation half of this same module, so an iframe navigates through exactly
// the machinery a top-level navigation uses.
const navigation_fetch = @import("../navigation/fetch_integration.zig");
const document_type = @import("../navigation/document_type.zig");
const navigate_steps = @import("../navigation/navigate_steps.zig");
const clock = @import("clock");
const infra = @import("infra");
const platform_host = @import("host");

/// Error types for iframe integration
pub const IFrameError = error{
    /// Failed to create browsing context
    ContextCreationFailed,
    /// Navigation failed
    NavigationFailed,
    /// Invalid src URL
    InvalidURL,
    /// Sandbox policy violation
    SandboxViolation,
    /// Out of memory
    OutOfMemory,
    /// Failed to read file
    FileReadError,
    /// Unsupported URL scheme
    UnsupportedScheme,
    /// Parse error during HTML parsing
    ParseError,
    /// The response's computed MIME type is one the HTML Standard hands off to
    /// external software (a download). Not a failure: no Document is committed
    /// and no load event is owed.
    ExternalHandoff,
    /// The response is one the navigation does not proceed with - a 204 or a
    /// 205 (HTML §7.4.5 "populate a history entry" step 12): the navigable
    /// keeps its current document and no load event is owed.
    NoDocument,
};

/// What a caller without engine access asks the engine's "navigate" for.
pub const NavigateRequest = struct {
    history_behavior: navigate_steps.HistoryBehavior = .auto,
    /// The navigation's "sourceDocument" (an engine document), or null.
    source_document: ?*anyopaque = null,
    /// Navigate's "referrerPolicy": "no-referrer" for window.open()'s
    /// noreferrer; the empty string defers to the policy container's.
    referrer_policy: @import("fetch").internal.ReferrerPolicy = .empty,
};

/// An engine context this integration made for a content navigable it no
/// longer has - the iframe was removed and inserted again, or a navigation's
/// new Window could not be made. Destroyed with the integration: script may
/// still be running in it, or hold its window, when the replacement is made.
/// (A realm a navigation replaced is the engine's to end:
/// `releaseCurrentRealm`.)
pub const RetiredRealm = struct {
    data: *anyopaque,
    /// The realm's own global object, when its global proxy went on to a new
    /// realm (an engine handle, owned): the context no longer reaches it.
    global: ?*anyopaque = null,
    destroy: *const fn (data: *anyopaque, global: ?*anyopaque, allocator: Allocator) void,
};

/// State of the iframe's nested browsing context
pub const IFrameState = enum {
    /// No browsing context yet (element not in document)
    uninitialized,
    /// Browsing context exists, navigating to about:blank
    creating_initial_document,
    /// Initial about:blank document loaded
    initial_document_ready,
    /// Navigating to src or srcdoc content
    navigating,
    /// Content loaded and ready
    ready,
    /// Browsing context discarded (element removed from document)
    discarded,
};

/// What a frame's HTML parse needs besides the bytes of a response it
/// decodes (HTML §13.2.3.2): the Content-Type the transport layer gave, and
/// whether the container document is same origin with the new document, so
/// that its encoding is the sniffing algorithm's step 6.
pub const ByteStream = struct {
    content_type: ?[]const u8,
    parent_same_origin: bool,
};

/// Result of fetching content from a URL
pub const FetchedContent = struct {
    /// The raw bytes fetched
    bytes: []u8,
    /// Content-Type header value (null if not available)
    content_type: ?[]u8,
    /// Allocator used for bytes (for cleanup)
    allocator: Allocator,

    pub fn deinit(self: *FetchedContent) void {
        self.allocator.free(self.bytes);
        if (self.content_type) |ct| {
            self.allocator.free(ct);
        }
    }
};

/// Percent-decode a string (simplified URL decoding)
/// Decodes %XX sequences to their byte values
fn percentDecode(allocator: Allocator, input: []const u8) ![]u8 {
    // Calculate output size (will be <= input size)
    var output_size: usize = 0;
    var i: usize = 0;
    while (i < input.len) {
        if (input[i] == '%' and i + 2 < input.len) {
            // Check if next two chars are hex digits
            if (std.fmt.parseInt(u8, input[i + 1 .. i + 3], 16)) |_| {
                output_size += 1;
                i += 3;
                continue;
            } else |_| {}
        }
        output_size += 1;
        i += 1;
    }

    const output = try allocator.alloc(u8, output_size);
    errdefer allocator.free(output);

    i = 0;
    var j: usize = 0;
    while (i < input.len) {
        if (input[i] == '%' and i + 2 < input.len) {
            if (std.fmt.parseInt(u8, input[i + 1 .. i + 3], 16)) |byte| {
                output[j] = byte;
                j += 1;
                i += 3;
                continue;
            } else |_| {}
        }
        output[j] = input[i];
        j += 1;
        i += 1;
    }

    return output;
}

/// Integration state for an iframe element
/// This struct manages the relationship between HTMLIFrameElement and BrowsingContext
pub const IFrameIntegration = struct {
    /// Allocator for this integration's resources
    allocator: Allocator,

    /// The nested browsing context (null until element is inserted)
    browsing_context: ?*BrowsingContext,

    /// The WindowProxy for accessing the nested window
    window_proxy: ?WindowProxy,

    /// Current state of the iframe
    state: IFrameState,

    /// The parent browsing context (container document's context)
    parent_context: ?*BrowsingContext,

    /// Cached src URL (null if no src attribute)
    src_url: ?[]const u8,

    /// The host bytes of the document origin the last navigation recorded on
    /// the WindowProxy. `Origin` BORROWS its host, and navigateToSrc used to
    /// hand it a slice of the URL it was called with - a buffer every caller
    /// frees once the call returns - so the frame's origin read freed memory
    /// and `iframe.contentDocument` came back null. Owned here instead.
    document_origin_host: ?[]u8 = null,

    /// Cached srcdoc content (null if no srcdoc attribute)
    srcdoc_content: ?[]const u8,

    /// MIME type essence of the document the last navigation committed
    /// (e.g. "text/css"). Null until one commits. Owned.
    loaded_content_type: ?[]u8,

    /// URL of the document the last navigation committed, after redirects.
    /// Null until one commits. Owned.
    loaded_url: ?[]u8,

    /// The iframe's name attribute
    name: []const u8,

    /// Origin of the container document (for same-origin checks)
    container_origin: Origin,

    /// Sandbox flags for this iframe (null if no sandbox attribute)
    sandbox_flags: ?SandboxFlags,

    /// Whether this iframe is sandboxed
    is_sandboxed: bool,

    // ========================================================================
    // Cross-Realm Support (Phase 3)
    // ========================================================================
    //
    // Engine-agnostic fields for cross-realm support.
    // V8-specific context creation is handled by the module with V8 access
    // (e.g., HTMLIFrameElement impl) using the setRealmContext method.

    /// Opaque pointer to the engine-specific context (e.g., V8 Context*)
    /// Set by modules with engine access (e.g., impls/HTMLIFrameElement.zig)
    engine_context: ?*anyopaque,

    /// Opaque pointer to the realm (e.g., runtime.Realm*)
    /// Contains intrinsics, global object, etc.
    realm: ?*anyopaque,

    /// Opaque pointer to cleanup data (e.g., ContextEntry* for cleanup)
    context_cleanup_data: ?*anyopaque,

    /// Opaque pointer to the runtime context (e.g., runtime.Context*)
    /// Used for creating Document instances during navigation
    runtime_context: ?*anyopaque,

    /// Callback to create a Document instance from the runtime context
    /// Parameters: (runtime_context, browsing_context) -> document_instance
    /// Set by modules with WebIDL interface access (e.g., impls/HTMLIFrameElement.zig)
    create_document_callback: ?*const fn (?*anyopaque, *BrowsingContext) ?*anyopaque,

    /// Callback to clean up the realm and context
    /// Set by the module that created the context
    cleanup_callback: ?*const fn (*IFrameIntegration) void,

    /// How a retired context's cleanup data is destroyed; see
    /// `retireRealmContext`. Set with the context.
    retired_realm_destroy: ?*const fn (data: *anyopaque, global: ?*anyopaque, allocator: Allocator) void = null,

    /// The realm an auxiliary navigable's first realm was made under - the
    /// opener's (a runtime.Context, opaque here) - for the realms later
    /// navigations make; an iframe's parent realm is its parent navigable's
    /// window's. Not owned.
    parent_realm: ?*anyopaque = null,

    /// Guard flag to prevent recursive cleanup during context teardown
    /// Set to true when cleanupRealmContext is entered
    cleanup_in_progress: bool,

    // ========================================================================
    // Script Execution Callbacks (Engine-Agnostic)
    // ========================================================================
    //
    // These callbacks are set by modules with V8 access (e.g., HTMLIFrameElement impl)
    // to allow script execution without directly importing v8 in this module.

    /// Callback to execute a script string in the iframe's realm
    /// Parameters: (runtime_context - the realm, script_source) -> void
    /// Set by modules with engine access
    execute_script_callback: ?*const fn (?*anyopaque, []const u8) void,

    /// Callback to update the Location URL in the iframe's window
    /// Parameters: (runtime_context - the realm, url) -> void
    /// Set by modules with engine access
    update_location_callback: ?*const fn (?*anyopaque, []const u8) void,

    /// Callback to parse HTML content into the iframe's document using DomTreeAdapter.
    /// This is needed for srcdoc and src navigation to properly populate the document
    /// with parsed content that JavaScript can access via DOM APIs.
    /// Parameters: (runtime_context, browsing_context, html_content) -> document_instance
    /// Set by modules with interface access (e.g., impls/HTMLIFrameElement.zig)
    parse_html_callback: ?*const fn (?*anyopaque, *BrowsingContext, []const u8, ?ByteStream) ?*anyopaque,

    /// Callback to fire the load event on the iframe element after navigation.
    /// Parameters: (iframe_instance) -> void
    /// Set by modules with interface access (e.g., impls/HTMLIFrameElement.zig)
    fire_load_callback: ?*const fn (?*anyopaque) void,

    /// Opaque pointer to the HTMLIFrameElement instance (for load event firing)
    iframe_element: ?*anyopaque,

    // ========================================================================
    // Navigation (HTML §7.4.2)
    // ========================================================================

    /// HTML "ongoing navigation" of the content navigable (§7.4.2.5): a new
    /// navigation replaces it, and an earlier one that finds it changed stops.
    ongoing_navigation: navigate_steps.OngoingNavigation = .none,

    /// HTML "is delaying load events": set by "navigate" step 15 and held
    /// until the container's load event steps have run for a navigation (or
    /// it ends without a document). While it is set the container delays its
    /// node document's load event (§4.8.5 "potentially delays the load
    /// event"). Held past "finalize a cross-document navigation" step 2,
    /// which clears the spec's flag, to the iframe load event: browsers fire
    /// the frame's load before the window's, and the new document's own load
    /// event is what gets it there.
    delaying_load: bool = false,

    /// Engine contexts of earlier content navigables; see `RetiredRealm`.
    retired_realms: std.ArrayListUnmanaged(RetiredRealm) = .empty,

    /// The engine's "navigate" for this navigable, set with its context, for
    /// callers that have no engine access (window.open()'s navigation).
    navigate_callback: ?*const fn (*IFrameIntegration, []const u8, NavigateRequest) void = null,

    /// Abandon the navigation in flight, if any: set by the engine that runs
    /// it, and called when the navigable goes.
    abandon_navigations_callback: ?*const fn (*IFrameIntegration) void = null,

    /// How many engine steps are running script with this integration in
    /// hand (a commit parsing the new document, a javascript: URL). Script
    /// can take the iframe away and a collection can deinit its element; the
    /// element then sets `deinit_pending` instead of freeing this, and the
    /// last step to finish does it.
    busy: u32 = 0,
    deinit_pending: bool = false,

    /// Told as the integration is deinited, by the engine that set it.
    deinit_callback: ?*const fn (*IFrameIntegration) void = null,

    /// HTML "create and initialize a Document object" steps 5-7, for a
    /// document of the given origin about to become the active document:
    /// keep the active window, or make a new realm and Window around the same
    /// WindowProxy. Set by the engine; false when no realm could be made.
    realm_for_document_callback: ?*const fn (*IFrameIntegration, Origin) bool = null,

    /// The origin (serialized) the navigable's Windows are created with - the
    /// creator's - or null for an opaque one. Owned.
    window_origin: ?[]u8 = null,

    /// The about base URL the next document this navigable makes is created
    /// with ("create and initialize a Document object"): set just before a
    /// commit that makes an about:blank or about:srcdoc document, taken by
    /// whatever creates the document, and cleared after the commit. Owned.
    next_about_base_url: ?[]u8 = null,

    /// The policy container the next document this navigable makes is
    /// created with ("create and initialize a Document object" step 9: the
    /// one "determine navigation params policy container" chose): set just
    /// before a commit, taken by whatever creates the document - before its
    /// parser applies a meta referrer or runs a script - and cleared after
    /// the commit. Owned until taken.
    next_policy_container: ?@import("fetch").internal.PolicyContainer = null,

    /// The referrer the next document this navigable makes is created with:
    /// for a fetched response, its request's referrer as main fetch left it
    /// ("create and initialize a Document object" step 14), and for a new
    /// browsing context's initial about:blank, its creator's URL ("create a
    /// new browsing context and document" step 19.1). Set just before the
    /// document is made - before its parser runs a script - and cleared
    /// after. Owned. Null: the empty string.
    next_referrer: ?[]u8 = null,

    /// The `Refresh` header of the response the next document this navigable
    /// makes is created from, isomorphic decoded ("create and initialize a
    /// Document object" step 17): run as the shared declarative refresh steps
    /// once the document exists, before its parser - so the header wins over
    /// a meta refresh. Set just before the commit and cleared after. Owned.
    next_refresh: ?[]u8 = null,

    /// Create a new IFrameIntegration (element not yet in document)
    pub fn init(allocator: Allocator) IFrameIntegration {
        return .{
            .allocator = allocator,
            .browsing_context = null,
            .window_proxy = null,
            .state = .uninitialized,
            .parent_context = null,
            .src_url = null,
            .srcdoc_content = null,
            .loaded_content_type = null,
            .loaded_url = null,
            .name = "",
            .container_origin = Origin.createOpaque(),
            .sandbox_flags = null,
            .is_sandboxed = false,
            // Cross-realm fields (engine-agnostic)
            .engine_context = null,
            .realm = null,
            .context_cleanup_data = null,
            .runtime_context = null,
            .create_document_callback = null,
            .cleanup_callback = null,
            .cleanup_in_progress = false,
            // Script execution callbacks
            .execute_script_callback = null,
            .update_location_callback = null,
            .parse_html_callback = null,
            .fire_load_callback = null,
            .iframe_element = null,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *IFrameIntegration) void {
        if (self.deinit_callback) |gone| gone(self);
        // A navigation in flight holds this integration; it ends first.
        if (self.abandon_navigations_callback) |abandon| abandon(self);
        self.ongoing_navigation = .none;

        // Clean up engine-specific context (Phase 3)
        self.cleanupRealmContext();
        for (self.retired_realms.items) |retired| retired.destroy(retired.data, retired.global, self.allocator);
        self.retired_realms.deinit(self.allocator);
        if (self.window_origin) |o| self.allocator.free(o);
        self.window_origin = null;
        self.setNextAboutBaseUrl(null);
        // A pending policy container is only ever set and cleared around one
        // commit, inside the same call; one still here (a commit that stopped
        // before a document took it) goes with the integration. Nothing else
        // needs to free it: removing the iframe ends its navigations, and
        // the integration's deinit follows.
        self.setNextPolicyContainer(null);

        // Destroy the browsing context if it exists
        // NOTE: BrowsingContext.deinit() already calls self.allocator.destroy(self)
        // so we only need to call deinit() here.
        if (self.browsing_context) |ctx| {
            log.debug("[IFrameIntegration.deinit] integration={*} -> BC {*}\n", .{ self, ctx });
            ctx.deinit();
        } else {
            log.debug("[IFrameIntegration.deinit] integration={*} -> BC null\n", .{self});
        }

        // Free allocated strings
        if (self.src_url) |url| {
            self.allocator.free(url);
        }
        if (self.document_origin_host) |host| {
            self.allocator.free(host);
        }
        if (self.srcdoc_content) |content| {
            self.allocator.free(content);
        }
        if (self.loaded_content_type) |ct| {
            self.allocator.free(ct);
        }
        if (self.loaded_url) |u| {
            self.allocator.free(u);
        }
        if (self.name.len > 0) {
            self.allocator.free(self.name);
        }
    }

    // ========================================================================
    // Realm and Context Management (Phase 3: Cross-Realm Support)
    // ========================================================================
    //
    // Engine-agnostic interface for realm/context management.
    // Actual V8-specific implementation is in HTMLIFrameElement impl.

    /// Set the realm context data (called from engine-specific code)
    ///
    /// This is called by modules with V8 access (e.g., HTMLIFrameElement impl)
    /// to associate engine-specific context data with this integration.
    ///
    /// Parameters:
    /// - context: Opaque pointer to engine context (e.g., V8 Context*)
    /// - realm_ptr: Opaque pointer to realm (e.e., runtime.Realm*)
    /// - cleanup_data: Opaque pointer to cleanup data (e.g., ContextEntry*)
    /// - runtime_ctx: Opaque pointer to runtime context (e.g., runtime.Context*)
    /// - cleanup_fn: Callback to clean up context when iframe is removed
    pub fn setRealmContext(
        self: *IFrameIntegration,
        context: ?*anyopaque,
        realm_ptr: ?*anyopaque,
        cleanup_data: ?*anyopaque,
        runtime_ctx: ?*anyopaque,
        create_doc_fn: ?*const fn (?*anyopaque, *BrowsingContext) ?*anyopaque,
        cleanup_fn: ?*const fn (*IFrameIntegration) void,
        parse_html_fn: ?*const fn (?*anyopaque, *BrowsingContext, []const u8, ?ByteStream) ?*anyopaque,
    ) void {
        self.engine_context = context;
        self.realm = realm_ptr;
        self.context_cleanup_data = cleanup_data;
        self.runtime_context = runtime_ctx;
        self.create_document_callback = create_doc_fn;
        self.cleanup_callback = cleanup_fn;
        self.parse_html_callback = parse_html_fn;
    }

    /// Clean up the realm and engine context
    fn cleanupRealmContext(self: *IFrameIntegration) void {
        // Guard against recursive cleanup during context teardown
        // This can happen when:
        // 1. context_manager.deinit() cleans up wrapper cache
        // 2. Wrapper cache cleanup triggers HTMLIFrameElement.deinit()
        // 3. HTMLIFrameElement.deinit() calls integration.deinit()
        // 4. integration.deinit() calls cleanupRealmContext()
        // 5. cleanupRealmContext() tries to end the realm
        //    which is already being torn down by context_manager.deinit()
        if (self.cleanup_in_progress) return;
        self.cleanup_in_progress = true;

        if (self.cleanup_callback) |callback| {
            callback(self);
        }
        self.engine_context = null;
        self.realm = null;
        self.context_cleanup_data = null;
        self.runtime_context = null;
        self.create_document_callback = null;
        self.cleanup_callback = null;
        self.parse_html_callback = null;
        // Note: cleanup_in_progress stays true to prevent any further cleanup attempts
    }

    /// Get the realm for this iframe (as opaque pointer)
    ///
    /// Returns the Realm associated with this iframe's browsing context.
    /// The caller is responsible for casting to the correct type.
    pub fn getRealmOpaque(self: *IFrameIntegration) ?*anyopaque {
        return self.realm;
    }

    /// Get the engine context (as opaque pointer)
    ///
    /// Returns the engine-specific context (e.g., V8 Context).
    /// The caller is responsible for casting to the correct type.
    pub fn getEngineContext(self: *IFrameIntegration) ?*anyopaque {
        return self.engine_context;
    }

    /// Check if this iframe has a realm context
    pub fn hasRealmContext(self: *const IFrameIntegration) bool {
        return self.realm != null;
    }

    /// Detach the current engine context without destroying it, so that a
    /// new content navigable can be made (the iframe was removed and is being
    /// inserted again). It is destroyed with the integration: script from it
    /// may be on the stack right now - a frame that moves its own container -
    /// and script elsewhere may hold its window.
    pub fn retireRealmContext(self: *IFrameIntegration) IFrameError!void {
        if (self.context_cleanup_data) |data| {
            const destroy = self.retired_realm_destroy orelse return IFrameError.ContextCreationFailed;
            self.retired_realms.append(self.allocator, .{ .data = data, .destroy = destroy }) catch return IFrameError.OutOfMemory;
        }
        self.engine_context = null;
        self.realm = null;
        self.context_cleanup_data = null;
        self.runtime_context = null;
        self.create_document_callback = null;
        self.cleanup_callback = null;
        self.parse_html_callback = null;
        self.execute_script_callback = null;
        self.update_location_callback = null;
        self.navigate_callback = null;
        self.ongoing_navigation = .none;
        self.window_proxy = null;
        self.state = .uninitialized;
    }

    /// The about base URL for the next document this navigable makes (a
    /// copy), or null for none.
    pub fn setNextAboutBaseUrl(self: *IFrameIntegration, url: ?[]const u8) void {
        const copy: ?[]u8 = if (url) |u| self.allocator.dupe(u8, u) catch null else null;
        if (self.next_about_base_url) |old| self.allocator.free(old);
        self.next_about_base_url = copy;
    }

    /// The referrer for the next document this navigable makes (a copy), or
    /// null for none - the empty string.
    pub fn setNextReferrer(self: *IFrameIntegration, referrer: ?[]const u8) void {
        const copy: ?[]u8 = if (referrer) |r| self.allocator.dupe(u8, r) catch null else null;
        if (self.next_referrer) |old| self.allocator.free(old);
        self.next_referrer = copy;
    }

    /// The isomorphic decoding of the next document's response's `Refresh`
    /// header value (a copy made here), or null for none.
    pub fn setNextRefresh(self: *IFrameIntegration, header_value: ?[]const u8) void {
        const copy: ?[]u8 = if (header_value) |v| infra.bytes.isomorphicDecodeToUtf8(self.allocator, v) catch null else null;
        if (self.next_refresh) |old| self.allocator.free(old);
        self.next_refresh = copy;
    }

    /// The policy container for the next document this navigable makes,
    /// taken (null: none - the document keeps a new one), releasing one
    /// still pending.
    pub fn setNextPolicyContainer(self: *IFrameIntegration, container: ?@import("fetch").internal.PolicyContainer) void {
        if (self.next_policy_container) |*old| old.deinit();
        self.next_policy_container = container;
    }

    /// The pending policy container, handed over: the integration keeps none.
    pub fn takeNextPolicyContainer(self: *IFrameIntegration) ?@import("fetch").internal.PolicyContainer {
        const container = self.next_policy_container;
        self.next_policy_container = null;
        return container;
    }

    /// Record the origin the navigable's Windows are created with.
    pub fn setWindowOrigin(self: *IFrameIntegration, origin: ?[]const u8) !void {
        const copy: ?[]u8 = if (origin) |o| try self.allocator.dupe(u8, o) else null;
        if (self.window_origin) |old| self.allocator.free(old);
        self.window_origin = copy;
    }

    /// Take the current engine context off the integration without
    /// destroying it - a navigation is replacing the navigable's Window - and
    /// hand it to the caller: its cleanup data, or null when there is none.
    /// The caller attaches the new context and ends the old one (the engine
    /// keeps a realm a navigation replaced for as long as script reaches
    /// anything of it - its document, a node, a function - and no longer:
    /// engine.WindowRealmEnd.global_detached). Kept here until the
    /// integration went, every replaced realm lived as long as its iframe.
    pub fn releaseCurrentRealm(self: *IFrameIntegration) ?*anyopaque {
        const data = self.context_cleanup_data orelse return null;
        self.engine_context = null;
        self.realm = null;
        self.context_cleanup_data = null;
        self.runtime_context = null;
        return data;
    }

    /// Keep a realm `releaseCurrentRealm` handed out until the integration
    /// goes (`retired_realms`): for a replacement that could not be made.
    pub fn keepRetiredRealm(self: *IFrameIntegration, data: *anyopaque) IFrameError!void {
        const destroy = self.retired_realm_destroy orelse return IFrameError.ContextCreationFailed;
        self.retired_realms.append(self.allocator, .{ .data = data, .destroy = destroy }) catch return IFrameError.OutOfMemory;
    }

    /// Make sure the realm the next document goes in is the right one: see
    /// `realm_for_document_callback`. Called before the document is
    /// committed, while the recorded document origin is still the active
    /// document's.
    pub fn realmForDocument(self: *IFrameIntegration, new_origin: Origin) IFrameError!void {
        const decide = self.realm_for_document_callback orelse return;
        if (!decide(self, new_origin)) return IFrameError.ContextCreationFailed;
    }

    /// HTML "navigate" this navigable to `url` (serialized, absolute), through
    /// the engine that owns it. Nothing happens without one.
    pub fn navigate(self: *IFrameIntegration, url: []const u8, request: NavigateRequest) void {
        const navigate_fn = self.navigate_callback orelse return;
        navigate_fn(self, url, request);
    }

    /// Called when iframe is inserted into a document
    /// Creates the nested browsing context per HTML §7.5.4
    pub fn onInsertedIntoDocument(
        self: *IFrameIntegration,
        parent_ctx: *BrowsingContext,
        container_origin: Origin,
    ) IFrameError!void {
        if (self.state != .uninitialized) {
            // Already initialized - this shouldn't happen but handle gracefully
            return;
        }

        self.parent_context = parent_ctx;
        self.container_origin = container_origin;

        // Create the nested browsing context
        const nested_ctx = BrowsingContext.initChild(self.allocator, parent_ctx) catch {
            return IFrameError.ContextCreationFailed;
        };

        log.debug("[IFrameIntegration.onInsertedIntoDocument] Created BC {*} for integration {*} (via onInsertedIntoDocument)\n", .{ nested_ctx, self });
        self.browsing_context = nested_ctx;

        // Set the target name if we have one
        if (self.name.len > 0) {
            nested_ctx.setTargetName(self.name) catch {
                return IFrameError.OutOfMemory;
            };
        }

        // Create the WindowProxy
        self.window_proxy = WindowProxy.init(self.allocator, nested_ctx);

        self.state = .creating_initial_document;

        // Navigate to initial content
        try self.navigateToInitialContent();
    }

    /// Lazily ensure the browsing context exists.
    /// This is called when contentWindow is accessed and the browsing context
    /// hasn't been created yet (e.g., if onInsertedIntoDocument wasn't called).
    ///
    /// Parameters:
    /// - parent_bc_opaque: Opaque pointer to the parent Window's browsing context
    ///                     (obtained from the parent Window's internal state)
    ///
    /// Returns: The browsing context (creating it if necessary), or null on error
    pub fn ensureBrowsingContext(self: *IFrameIntegration, parent_bc_opaque: *anyopaque) ?*BrowsingContext {
        // If we already have a browsing context, return it
        if (self.browsing_context) |bc| {
            return bc;
        }

        // Create the browsing context as a child of the parent
        const parent_bc: *BrowsingContext = @ptrCast(@alignCast(parent_bc_opaque));

        const nested_ctx = BrowsingContext.initChild(self.allocator, parent_bc) catch {
            return null;
        };

        log.debug("[IFrameIntegration.ensureBrowsingContext] Created BC {*} for integration {*} (via ensureBrowsingContext)\n", .{ nested_ctx, self });
        self.browsing_context = nested_ctx;
        self.parent_context = parent_bc;

        // Set the target name if we have one
        if (self.name.len > 0) {
            nested_ctx.setTargetName(self.name) catch {};
        }

        // CRITICAL: Apply sandbox flags to the newly created browsing context.
        // Per HTML spec §4.8.5, sandbox flags may have been set on the integration
        // before the browsing context was created (e.g., via setAttribute('sandbox', '')).
        // The browsing context must inherit these flags so that script execution
        // respects the sandbox restrictions.
        if (self.is_sandboxed) {
            if (self.sandbox_flags) |flags| {
                nested_ctx.setSandboxFlags(flags);
            }
        }

        // Create the WindowProxy
        self.window_proxy = WindowProxy.init(self.allocator, nested_ctx);

        // Set the document origin on the WindowProxy
        // For about:blank (no src), the iframe inherits the container's origin
        if (self.window_proxy) |*proxy| {
            proxy.setDocumentOrigin(self.container_origin);
        }

        // Update state
        if (self.state == .uninitialized) {
            self.state = .creating_initial_document;
        }

        return nested_ctx;
    }

    /// Called when iframe is removed from a document
    /// Per WHATWG HTML §7.3.1.6 "destroy a child navigable", the browsing context
    /// is destroyed synchronously when the iframe element is removed from the document.
    ///
    /// Architecture notes:
    /// - BrowsingContext is a Zig-only struct with no V8 references - safe to deinit synchronously
    /// - V8 context cleanup (cleanupRealmContext) is NOT done here - the child V8 context must
    ///   remain alive so V8's weak callbacks can properly handle wrapper cleanup when GC runs
    /// - The wrapper cache cleanup happens when the realm ends (engine.destroyWindowRealm)
    ///
    /// This follows the Chromium pattern of deterministic cleanup during element removal,
    /// not GC-driven cleanup. The BC must be destroyed here to prevent memory leaks caused
    /// by memory address reuse before GC runs.
    pub fn onRemovedFromDocument(self: *IFrameIntegration) void {
        // Guard against double-calls. Once discarded, we don't process again.
        if (self.state == .discarded) return;

        // "Destroy a child navigable": its navigation in flight ends with it,
        // and it no longer delays anything.
        if (self.abandon_navigations_callback) |abandon| abandon(self);
        self.ongoing_navigation = .none;
        self.delaying_load = false;

        // DO NOT call cleanupRealmContext() here!
        // The child V8 context must remain alive so V8's weak callbacks can
        // properly handle cleanup when GC runs. Destroying it now while JS
        // may still be executing causes use-after-free.

        if (self.browsing_context) |ctx| {
            // Per WHATWG spec §7.3.1.6 "destroy a child navigable": leave the
            // parent (window.frames.length reflects the removal immediately),
            // close, drop the children. Freed synchronously only if no Window
            // still points at it - script can hold iframe.contentWindow past
            // iframe.remove(), and that Window reads this struct - otherwise the
            // Window frees it at teardown (BrowsingContext.discard).
            log.debug("[IFrameIntegration.onRemovedFromDocument] integration={*} -> discarding BC {*}\n", .{ self, ctx });
            if (ctx.discard()) ctx.deinit();
            // Set to null to prevent double-free in IFrameIntegration.deinit()
            self.browsing_context = null;
        }
        // What the navigable kept goes with it: its target name and the
        // origin its Windows were created with. A navigable made when the
        // element is inserted again records its own (iframePostConnectionSteps
        // sets the name, attachRealm the origin); nothing reads them while
        // the element has none. Not left to deinit: an iframe that script
        // never wrapped, removed by innerHTML, is never deinit'd, and these
        // copies leaked with it (leaks lane, 2026-10-02: 25 + 25 in
        // custom-elements/form-associated/ElementInternals-setFormValue.html).
        if (self.window_origin) |origin| self.allocator.free(origin);
        self.window_origin = null;
        if (self.name.len > 0) self.allocator.free(self.name);
        self.name = "";
        // A destroyed navigable no longer lives: it leaves the engine's list
        // of live navigables now (`deinit_callback`, which deinit calls too;
        // leaving twice is a no-op), and a navigable made on re-insertion
        // joins again. Left to deinit, the integration of an iframe that is
        // never deinit'd stayed listed past its Browser, and the next
        // Browser's iframe insertion read the freed block (SIGSEGV in
        // integrationOfBrowsingContext, two Browsers in one process).
        if (self.deinit_callback) |gone| gone(self);
        self.state = .discarded;
    }

    /// Navigate to the initial content based on src/srcdoc attributes
    fn navigateToInitialContent(self: *IFrameIntegration) IFrameError!void {
        // Per spec: srcdoc takes precedence over src
        if (self.srcdoc_content) |content| {
            try self.navigateToSrcdoc(content);
            return;
        }

        if (self.src_url) |url| {
            try self.navigateToSrc(url);
            return;
        }

        // No src or srcdoc - navigate to about:blank
        try self.navigateToAboutBlank();
    }

    /// Navigate to about:blank
    fn navigateToAboutBlank(self: *IFrameIntegration) IFrameError!void {
        // Set the origin to inherit from container document
        // Per spec, about:blank inherits origin from container
        if (self.window_proxy) |*proxy| {
            proxy.setDocumentOrigin(self.container_origin);
        }

        self.state = .initial_document_ready;
        // In a full implementation, we would create the about:blank Document here
        // For now, we just mark the state
    }

    /// Navigate to srcdoc content
    /// Per HTML Standard §4.8.5.1 - srcdoc attribute processing
    ///
    /// srcdoc content is always treated as UTF-8 since it comes from the
    /// parent document's parsing (which normalizes to UTF-8).
    fn navigateToSrcdoc(self: *IFrameIntegration, content: []const u8) IFrameError!void {
        // Debug: trace what content is being parsed
        const time_ns = clock.wallNanos();
        const preview_len = @min(150, content.len);
        log.debug("[navigateToSrcdoc] time={d}ns content_len={d} content={s}...\n", .{ time_ns, content.len, content[0..preview_len] });

        // srcdoc documents inherit origin from container
        if (self.window_proxy) |*proxy| {
            proxy.setDocumentOrigin(self.container_origin);
        }

        self.state = .navigating;

        // Use the parse_html_callback if available - this uses DomTreeAdapter
        // to properly populate the document with parsed content that JavaScript
        // can access via DOM APIs like getElementById(), querySelector(), etc.
        if (self.parse_html_callback) |parse_html| {
            if (self.browsing_context) |ctx| {
                _ = parse_html(self.runtime_context, ctx, content, null);
            }

            // Update the iframe's Location URL to about:srcdoc
            // Per HTML spec, srcdoc documents have URL "about:srcdoc"
            self.updateLocationUrl("about:srcdoc");

            self.state = .ready;
            return;
        }

        // Fallback: Parse without DOM integration (scripts won't have access to parsed DOM)
        // This path is only used when parse_html_callback is not set.
        const tree_builder = html_parser.parseHTMLFromString(self.allocator, content) catch {
            self.state = .ready;
            return IFrameError.ParseError;
        };
        defer {
            tree_builder.deinit();
            self.allocator.destroy(tree_builder);
        }

        // Create a Document instance using the callback if available.
        // The callback handles creating the runtime.Instance and linking it
        // to the BrowsingContext and Window.
        if (self.create_document_callback) |create_doc| {
            if (self.browsing_context) |ctx| {
                _ = create_doc(self.runtime_context, ctx);
            }
        }

        // Update the iframe's Location URL to about:srcdoc
        // Per HTML spec, srcdoc documents have URL "about:srcdoc"
        self.updateLocationUrl("about:srcdoc");

        // Execute inline scripts in the parsed document
        // Per HTML Standard §4.12.1.1, scripts execute in document order
        self.executeScriptsInTree(tree_builder.document);

        self.state = .ready;
    }

    /// Navigate the iframe's content navigable to `url` - HTML Standard §7.4.6
    /// "load a document".
    ///
    /// `url` must already be absolute. Resolving the src attribute against the
    /// container document belongs to "process the iframe attributes" on the
    /// element, which is the only place that knows the container document; this
    /// function has no access to it and will not guess.
    ///
    /// Steps:
    /// 1. Fetch the resource through the navigation fetch
    ///    (`navigation/fetch_integration.zig`), which reaches the network via
    ///    the Fetch algorithm and libcurl.
    /// 2. Take the essence of the response's Content-Type - the "computed type".
    /// 3. Select a document class for that type and build the Document the spec
    ///    names for it.
    /// 4. Record the committed URL and content type so the element can apply
    ///    them to the Document and fire the load event.
    ///
    /// Returns `IFrameError.ExternalHandoff` when the computed type is one the
    /// spec hands to external software (a download). That is not a failure, but
    /// it is not a navigation either: no Document is committed and no load event
    /// is owed.
    pub fn navigateToSrc(self: *IFrameIntegration, url: []const u8) IFrameError!void {
        self.state = .navigating;

        // javascript: URLs are never fetched. Per HTML §7.4.2 the script runs in
        // the iframe's own realm; only a string result would replace the
        // document, which Crane does not yet implement.
        if (std.mem.startsWith(u8, url, "javascript:")) {
            const script = url["javascript:".len..];
            if (self.execute_script_callback) |exec| {
                exec(self.runtime_context, script);
            }
            self.updateLocationUrl(url);
            try self.recordCommit(url, "text/html");
            self.state = .ready;
            return;
        }

        var response = navigation_fetch.fetchNavigationResource(self.allocator, url, .{
            .destination = .iframe,
            .mode = .navigate,
            .redirect = .follow,
        }) catch |err| {
            self.state = .ready;
            return switch (err) {
                error.OutOfMemory => IFrameError.OutOfMemory,
                error.InvalidUrl => IFrameError.InvalidURL,
                error.SecurityError => IFrameError.SandboxViolation,
                else => IFrameError.NavigationFailed,
            };
        };
        defer response.deinit();

        // A network error is not a document, and neither is a 204/205. Leaving
        // the previous document in place is what the synchronous path has
        // always done.
        if (response.is_network_error or !navigation_fetch.shouldNavigationProceed(response.status)) {
            self.state = .ready;
            return IFrameError.NavigationFailed;
        }
        return self.commitResponse(url, &response);
    }

    /// Make the document `response` - the fetch of `url` - describes this
    /// navigable's active document: HTML §7.4.6 "load a document" by the
    /// response's computed type, with the URL, origin and content type the
    /// document is created with. The caller has unloaded the document it
    /// replaces.
    ///
    /// A network error commits an empty error document at `url` with an
    /// opaque origin - the spec's "display inline content" - so the frame
    /// still finishes loading and its container still hears load. A 204 or
    /// 205, and a type handed to external software, commit nothing:
    /// `IFrameError.NoDocument` / `IFrameError.ExternalHandoff`.
    pub fn commitResponse(self: *IFrameIntegration, url: []const u8, response: *const navigation_fetch.NavigationFetchResult) IFrameError!void {
        if (response.is_network_error) {
            if (self.window_proxy) |*proxy| proxy.setDocumentOrigin(Origin.createOpaque());
            self.updateLocationUrl(url);
            _ = try self.commitHtmlDocument("", null);
            try self.recordCommit(url, "text/html");
            self.state = .ready;
            return;
        }
        if (!navigation_fetch.shouldNavigationProceed(response.status)) return IFrameError.NoDocument;

        const body = response.body orelse "";

        // The computed type. A response with no Content-Type would be sniffed
        // per mimesniff; until Crane can reach that module from here, an absent
        // type is treated as HTML, which is what the rest of the engine assumes.
        const computed = document_type.essence(
            self.allocator,
            response.content_type orelse "text/html",
        ) catch return IFrameError.OutOfMemory;
        defer self.allocator.free(computed);

        const final_url = if (response.final_url.len > 0) response.final_url else url;
        const kind = document_type.classify(computed);
        switch (kind) {
            // "Otherwise, proceed onward" - the resource is handed off to
            // external software. The navigable keeps its current document.
            .multipart, .external => return IFrameError.ExternalHandoff,
            else => {},
        }

        self.state = .navigating;

        // The document origin follows the URL navigated to - an about: URL
        // inherits the container's - and is set as the document is created,
        // before any of its script runs.
        var new_origin = self.parseOriginFromURL(final_url);
        if (!new_origin.is_opaque and new_origin.host.len > 0) {
            const owned_host = self.allocator.dupe(u8, new_origin.host) catch return IFrameError.OutOfMemory;
            if (self.document_origin_host) |old| self.allocator.free(old);
            self.document_origin_host = owned_host;
            new_origin.host = owned_host;
        }
        if (self.window_proxy) |*proxy| {
            proxy.setDocumentOrigin(new_origin);
        }

        // HTML "create and initialize a Document object": the new document's
        // URL is the response URL from the moment it exists - before the parser
        // runs its scripts. Support pages read their parameters from
        // location.search while loading (`self[params.get("window")]
        // .postMessage(...)`); updating after the commit handed them the
        // previous URL, they threw, and the page waiting on them timed out.
        self.updateLocationUrl(final_url);

        switch (kind) {
            // "Load an HTML document": the parser decodes the response's
            // bytes with the encoding the sniffing algorithm determines from
            // them, the Content-Type and - same origin - the container
            // document's encoding.
            .html => _ = try self.commitHtmlDocument(body, .{
                .content_type = response.content_type,
                .parent_same_origin = new_origin.isSameOrigin(self.container_origin),
            }),
            .text => try self.commitTextDocument(body, response.content_type),
            .media => try self.commitMediaDocument(final_url, document_type.mediaHostElement(computed)),
            .xml => try self.commitXmlDocument(),
            .multipart, .external => unreachable,
        }

        try self.recordCommit(final_url, computed);
        self.state = .ready;
    }

    /// The origin of the document committing `response` - the fetch of `url`
    /// - would make: opaque for a network error, else the final URL's.
    pub fn responseOrigin(self: *IFrameIntegration, url: []const u8, response: *const navigation_fetch.NavigationFetchResult) Origin {
        if (response.is_network_error) return Origin.createOpaque();
        const final_url = if (response.final_url.len > 0) response.final_url else url;
        return self.parseOriginFromURL(final_url);
    }

    /// Whether committing `response` makes a document: a network error does
    /// (its error document), a 204 or 205 does not (HTML §7.4.5 "populate a
    /// history entry" step 12), and neither does a type handed to external
    /// software.
    pub fn responseMakesDocument(self: *IFrameIntegration, response: *const navigation_fetch.NavigationFetchResult) bool {
        if (response.is_network_error) return true;
        if (!navigation_fetch.shouldNavigationProceed(response.status)) return false;
        const computed = document_type.essence(self.allocator, response.content_type orelse "text/html") catch return true;
        defer self.allocator.free(computed);
        return switch (document_type.classify(computed)) {
            .multipart, .external => false,
            else => true,
        };
    }

    /// Set the active document's URL - the navigable's Location and the
    /// context's document URL - as a fragment navigation does (HTML
    /// §7.4.2.3.3 step 12).
    pub fn setDocumentUrl(self: *IFrameIntegration, url: []const u8) void {
        self.updateLocationUrl(url);
    }

    /// Commit a document made of `html` at `url`, whose origin is the
    /// container's: an `about:srcdoc` document, or the document a
    /// `javascript:` URL's string result makes.
    pub fn commitHtmlAt(self: *IFrameIntegration, url: []const u8, html: []const u8, origin: Origin) IFrameError!void {
        self.state = .navigating;
        if (self.window_proxy) |*proxy| proxy.setDocumentOrigin(origin);
        self.updateLocationUrl(url);
        _ = try self.commitHtmlDocument(html, null);
        try self.recordCommit(url, "text/html");
        self.state = .ready;
    }

    /// Remember what the last navigation committed, so `HTMLIFrameElement` can
    /// stamp the Document with its URL and content type.
    fn recordCommit(self: *IFrameIntegration, url: []const u8, content_type: []const u8) IFrameError!void {
        const new_url = self.allocator.dupe(u8, url) catch return IFrameError.OutOfMemory;
        errdefer self.allocator.free(new_url);
        const new_type = self.allocator.dupe(u8, content_type) catch return IFrameError.OutOfMemory;

        if (self.loaded_url) |old| self.allocator.free(old);
        if (self.loaded_content_type) |old| self.allocator.free(old);
        self.loaded_url = new_url;
        self.loaded_content_type = new_type;
    }

    /// The MIME type essence of the document the last navigation committed, or
    /// null if none has. Borrowed; valid until the next navigation.
    pub fn getLoadedContentType(self: *const IFrameIntegration) ?[]const u8 {
        return self.loaded_content_type;
    }

    /// The URL of the document the last navigation committed, after redirects.
    /// Borrowed; valid until the next navigation.
    pub fn getLoadedUrl(self: *const IFrameIntegration) ?[]const u8 {
        return self.loaded_url;
    }

    /// "Loading an HTML document": hand the bytes to the HTML parser. The
    /// document it made, when the parse callback returned one.
    fn commitHtmlDocument(self: *IFrameIntegration, content: []const u8, byte_stream: ?ByteStream) IFrameError!?*anyopaque {
        // The parse callback runs the scripted parser against the iframe's own
        // realm, so scripts in the loaded document see its DOM.
        if (self.parse_html_callback) |parse_html| {
            if (self.browsing_context) |ctx| {
                return parse_html(self.runtime_context, ctx, content, byte_stream);
            }
        }

        // Fallback for a navigable with no realm yet: parse into a detached
        // tree so at least the scripts run. Nothing can reach this DOM.
        const tree_builder = html_parser.parseHTMLFromString(self.allocator, content) catch {
            return IFrameError.ParseError;
        };
        defer {
            tree_builder.deinit();
            self.allocator.destroy(tree_builder);
        }

        if (self.create_document_callback) |create_doc| {
            if (self.browsing_context) |ctx| {
                _ = create_doc(self.runtime_context, ctx);
            }
        }

        self.executeScriptsInTree(tree_builder.document);
        return null;
    }

    /// "Loading a text document" - HTML Standard §7.5.4.
    ///
    /// The spec primes the HTML parser with a `pre` start tag and a single LF,
    /// then switches its tokenizer to the PLAINTEXT state, so the whole rest of
    /// the byte stream is the text of that one element. Crane's parser cannot be
    /// primed into PLAINTEXT from outside, so the equivalent markup is
    /// synthesised instead: escaping U+0026 and U+003C makes every remaining
    /// byte inert in exactly the way the PLAINTEXT state does, and the LF after
    /// the start tag is dropped by the parser's own "newline after pre" rule,
    /// which is why the spec emits it.
    ///
    /// The bytes are decoded first, by the type's rules: a BOM, the
    /// Content-Type's charset, else the default - the sniffing algorithm
    /// without the prescan, as text is not markup.
    fn commitTextDocument(self: *IFrameIntegration, bytes: []const u8, content_type: ?[]const u8) IFrameError!void {
        const sniffed = encoding_sniffing.sniff(bytes, .{
            .transport = if (content_type) |ct| encoding_sniffing.transportEncoding(self.allocator, ct) else null,
            .prescan = false,
        });
        const text = encoding_sniffing.decode(self.allocator, bytes, sniffed.encoding) catch return IFrameError.OutOfMemory;
        defer self.allocator.free(text);
        const markup = document_type.textDocumentMarkup(self.allocator, text) catch {
            return IFrameError.OutOfMemory;
        };
        defer self.allocator.free(markup);
        // Steps 2-3: "Set document's parser cannot change the mode flag to
        // true. Set document's mode to "no-quirks"." Here the mode is set
        // after the parse instead: the synthesised markup has no DOCTYPE, so
        // the parse picks quirks, but nothing in it runs script, so no one can
        // observe the mode before this - the same as the parser cannot change
        // the mode flag keeping no-quirks throughout.
        const document = try self.commitHtmlDocument(markup, null);
        if (document) |doc| {
            setNoQuirks(doc);
            @import("dom").document_internals.setEncoding(@ptrCast(@alignCast(doc)), encoding_sniffing.canonicalName(sniffed.encoding)) catch {};
        }
    }

    /// Set the document the parse made to no-quirks mode.
    fn setNoQuirks(document: *anyopaque) void {
        @import("dom").document_internals.setMode(@ptrCast(@alignCast(document)), .no_quirks) catch {};
    }

    /// "Loading a media document" - HTML Standard §7.5.6.
    ///
    /// The response body is not parsed at all. The document is an html/head/body
    /// skeleton whose body hosts one element - `img`, `video` or `audio` per the
    /// table in the spec - with its `src` set to the address of the resource.
    fn commitMediaDocument(
        self: *IFrameIntegration,
        address: []const u8,
        host_element: document_type.MediaHostElement,
    ) IFrameError!void {
        const markup = document_type.mediaDocumentMarkup(self.allocator, address, host_element) catch {
            return IFrameError.OutOfMemory;
        };
        defer self.allocator.free(markup);
        // Step 2: "Set document's mode to "no-quirks"." Nothing in the
        // synthesised markup runs script, so setting it after the parse, which
        // (with no DOCTYPE) chose quirks, is the mode ever seen.
        const document = try self.commitHtmlDocument(markup, null);
        if (document) |doc| setNoQuirks(doc);
    }

    /// "Loading an XML document" - HTML Standard §7.5.3.
    ///
    /// TODO: Crane has no XML parser (nothing in `src/` implements one), so the
    /// document is created empty. Its content type and URL are still correct,
    /// which is what `document.contentType` and `location` report; the tree is
    /// not. Replace the body of this function with a real XML parse once an XML
    /// parser exists.
    fn commitXmlDocument(self: *IFrameIntegration) IFrameError!void {
        if (self.create_document_callback) |create_doc| {
            if (self.browsing_context) |ctx| {
                _ = create_doc(self.runtime_context, ctx);
            }
        }
    }

    /// Fetch content from a file:// URL
    fn fetchFileContent(self: *IFrameIntegration, url: []const u8) !FetchedContent {
        // Extract file path from file:// URL
        var file_path: []const u8 = undefined;

        if (std.mem.startsWith(u8, url, "file:///")) {
            // file:///path/to/file -> /path/to/file
            file_path = url[7..];
        } else if (std.mem.startsWith(u8, url, "file://")) {
            // file://host/path (network path) - not supported
            return error.UnsupportedScheme;
        } else {
            return error.InvalidURL;
        }

        // Read the file
        const io = platform_host.io();
        const file = platform_host.cwd().openFile(io, file_path, .{}) catch {
            return error.FileReadError;
        };
        defer file.close(io);

        // Read up to 10MB (reasonable limit for iframe content)
        const max_size = 10 * 1024 * 1024;
        var file_reader = file.reader(io, &.{});
        const bytes = file_reader.interface.allocRemaining(self.allocator, .limited(max_size)) catch {
            return error.FileReadError;
        };

        // Try to read .headers file for Content-Type
        var content_type: ?[]u8 = null;
        const headers_path = std.fmt.allocPrint(self.allocator, "{s}.headers", .{file_path}) catch null;
        if (headers_path) |hp| {
            defer self.allocator.free(hp);
            content_type = self.readContentTypeFromHeadersFile(hp);
        }

        return FetchedContent{
            .bytes = bytes,
            .content_type = content_type,
            .allocator = self.allocator,
        };
    }

    /// Read Content-Type from a .headers file (WPT convention)
    /// Format: "Content-Type: text/html; charset=big5"
    fn readContentTypeFromHeadersFile(self: *IFrameIntegration, headers_path: []const u8) ?[]u8 {
        const io = platform_host.io();
        const file = platform_host.cwd().openFile(io, headers_path, .{}) catch return null;
        defer file.close(io);

        // Read headers file (usually small)
        var buf: [4096]u8 = undefined;
        const bytes_read = file.readPositional(io, &.{&buf}, 0) catch return null;
        const content = buf[0..bytes_read];

        // Parse Content-Type header
        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, &[_]u8{ ' ', '\t', '\r' });
            if (std.ascii.startsWithIgnoreCase(trimmed, "content-type:")) {
                const value = std.mem.trim(u8, trimmed["content-type:".len..], &[_]u8{ ' ', '\t' });
                return self.allocator.dupe(u8, value) catch null;
            }
        }

        return null;
    }

    /// Parse a data: URL and return the content
    /// Format: data:[<mediatype>][;base64],<data>
    fn parseDataUrl(self: *IFrameIntegration, url: []const u8) !FetchedContent {
        if (!std.mem.startsWith(u8, url, "data:")) {
            return error.InvalidURL;
        }

        const rest = url[5..]; // Skip "data:"

        // Find the comma separating metadata from data
        const comma_idx = std.mem.indexOf(u8, rest, ",") orelse return error.InvalidURL;

        const metadata = rest[0..comma_idx];
        const data = rest[comma_idx + 1 ..];

        // Check for base64 encoding
        const is_base64 = std.mem.endsWith(u8, metadata, ";base64");

        // Extract content type
        var content_type: ?[]u8 = null;
        const ct_end = if (is_base64) metadata.len - 7 else metadata.len;
        if (ct_end > 0) {
            content_type = try self.allocator.dupe(u8, metadata[0..ct_end]);
        }

        // Decode the data
        const bytes = if (is_base64) blk: {
            // Base64 decode
            const decoded_size = std.base64.standard.Decoder.calcSizeForSlice(data) catch return error.InvalidURL;
            const decoded = try self.allocator.alloc(u8, decoded_size);
            errdefer self.allocator.free(decoded);
            std.base64.standard.Decoder.decode(decoded, data) catch return error.InvalidURL;
            break :blk decoded;
        } else blk: {
            // Percent-decode (simplified: just unescape %XX sequences)
            const decoded = try percentDecode(self.allocator, data);
            break :blk decoded;
        };

        return FetchedContent{
            .bytes = bytes,
            .content_type = content_type,
            .allocator = self.allocator,
        };
    }

    /// Parse origin from URL (simplified)
    fn parseOriginFromURL(self: *IFrameIntegration, url: []const u8) Origin {
        // Simplified parsing - in real implementation, use full URL parser
        // URL "origin" for a blob: URL: its path's URL's origin when that is
        // http(s) - a blob URL is of the origin that made it. (The entry's
        // environment's origin, step 1, is the same for the URLs
        // URL.createObjectURL makes.)
        if (std.mem.startsWith(u8, url, "blob:http://") or std.mem.startsWith(u8, url, "blob:https://")) {
            return self.parseOriginFromURL(url["blob:".len..]);
        }
        // For data: (and any other blob:) URLs, return opaque origin
        if (std.mem.startsWith(u8, url, "data:") or
            std.mem.startsWith(u8, url, "blob:") or
            std.mem.startsWith(u8, url, "javascript:"))
        {
            return Origin.createOpaque();
        }

        // For about:blank and about:srcdoc, inherit container origin
        if (std.mem.startsWith(u8, url, "about:")) {
            return self.container_origin;
        }

        // For http(s) URLs, the origin is (scheme, host, port) from the
        // authority. This used to keep ":8000" inside the host and hard-code
        // the port as 80 or 443, so no http(s) frame on a non-default port was
        // ever same origin with its container, and `iframe.contentDocument`
        // answered null for every one of them.
        if (std.mem.startsWith(u8, url, "https://")) return authorityOrigin("https", url[8..], 443);
        if (std.mem.startsWith(u8, url, "http://")) return authorityOrigin("http", url[7..], 80);

        // Unknown scheme - opaque origin
        return Origin.createOpaque();
    }

    /// The tuple origin of an http(s) URL whose scheme and "//" are already
    /// stripped: the authority ends at the first '/', '?' or '#', userinfo
    /// (up to the last '@') is dropped, and an explicit port - after the last
    /// ':' that is not inside an IPv6 literal's brackets - overrides the
    /// scheme's default.
    fn authorityOrigin(scheme: []const u8, rest: []const u8, default_port: u16) Origin {
        const end = std.mem.indexOfAny(u8, rest, "/?#") orelse rest.len;
        var authority = rest[0..end];
        if (std.mem.lastIndexOfScalar(u8, authority, '@')) |at| authority = authority[at + 1 ..];
        const bracket_end = std.mem.lastIndexOfScalar(u8, authority, ']') orelse 0;
        if (std.mem.lastIndexOfScalar(u8, authority, ':')) |colon| {
            if (colon > bracket_end) {
                const port_text = authority[colon + 1 ..];
                const port = if (port_text.len == 0) default_port else std.fmt.parseInt(u16, port_text, 10) catch default_port;
                return Origin.init(scheme, authority[0..colon], port);
            }
        }
        return Origin.init(scheme, authority, default_port);
    }

    /// Set the src attribute value
    /// Per spec, setting src triggers navigation
    pub fn setSrc(self: *IFrameIntegration, url: []const u8) IFrameError!void {
        // Free old URL if any
        if (self.src_url) |old_url| {
            self.allocator.free(old_url);
        }

        // Copy new URL
        self.src_url = self.allocator.dupe(u8, url) catch {
            return IFrameError.OutOfMemory;
        };

        // If we have a browsing context, navigate
        if (self.browsing_context != null and self.state != .uninitialized and self.state != .discarded) {
            try self.navigateToSrc(url);
        }
    }

    /// Get the src attribute value
    pub fn getSrc(self: *const IFrameIntegration) ?[]const u8 {
        return self.src_url;
    }

    /// Set the srcdoc attribute value
    /// Per spec, srcdoc takes precedence over src
    pub fn setSrcdoc(self: *IFrameIntegration, content: []const u8) IFrameError!void {
        // Free old content if any
        if (self.srcdoc_content) |old_content| {
            self.allocator.free(old_content);
        }

        // Copy new content - CRITICAL: we must use this copy, not the original!
        // The original 'content' may be a slice into a DOMString that gets freed
        // after this function returns.
        self.srcdoc_content = self.allocator.dupe(u8, content) catch {
            return IFrameError.OutOfMemory;
        };

        // If we have a browsing context, navigate
        // IMPORTANT: Use self.srcdoc_content (the owned copy), NOT content (potentially dangling)
        if (self.browsing_context != null and self.state != .uninitialized and self.state != .discarded) {
            try self.navigateToSrcdoc(self.srcdoc_content.?);
        }
    }

    /// Get the srcdoc attribute value
    pub fn getSrcdoc(self: *const IFrameIntegration) ?[]const u8 {
        return self.srcdoc_content;
    }

    /// Set the name attribute value
    pub fn setName(self: *IFrameIntegration, name: []const u8) IFrameError!void {
        // Free old name if any
        if (self.name.len > 0) {
            self.allocator.free(self.name);
        }

        // Copy new name
        self.name = self.allocator.dupe(u8, name) catch {
            return IFrameError.OutOfMemory;
        };

        // Update browsing context target name if it exists
        if (self.browsing_context) |ctx| {
            ctx.setTargetName(name) catch {
                return IFrameError.OutOfMemory;
            };
        }
    }

    /// Get the name attribute value
    pub fn getName(self: *const IFrameIntegration) []const u8 {
        return self.name;
    }

    /// Get the contentWindow (WindowProxy)
    /// Returns null if no browsing context or discarded
    pub fn getContentWindow(self: *IFrameIntegration) ?*WindowProxy {
        if (self.state == .uninitialized or self.state == .discarded) {
            return null;
        }
        if (self.window_proxy) |*proxy| {
            return proxy;
        }
        return null;
    }

    /// Check if contentDocument should be accessible (same-origin check)
    pub fn isContentDocumentAccessible(self: *const IFrameIntegration, accessor_origin: Origin) bool {
        if (self.state == .uninitialized or self.state == .discarded) {
            return false;
        }
        if (self.window_proxy) |proxy| {
            return proxy.isSameOriginAccess(accessor_origin);
        }
        return false;
    }

    /// Get whether the iframe's browsing context is closed
    pub fn isClosed(self: *const IFrameIntegration) bool {
        if (self.browsing_context) |ctx| {
            return ctx.is_closed;
        }
        return self.state == .discarded;
    }

    // ========================================================================
    // Sandbox Attribute (§4.8.5.4)
    // ========================================================================

    /// Set sandbox flags from the sandbox attribute value
    /// Per HTML Standard §4.8.5.4
    /// Empty value means all restrictions apply.
    /// "allow-*" tokens lift specific restrictions.
    pub fn setSandbox(self: *IFrameIntegration, value: []const u8) IFrameError!void {
        const flags = SandboxFlags.parseAlloc(self.allocator, value) catch {
            return IFrameError.OutOfMemory;
        };
        self.sandbox_flags = flags;
        self.is_sandboxed = true;

        // Apply to browsing context if it exists
        if (self.browsing_context) |ctx| {
            ctx.setSandboxFlags(flags);
        }
    }

    /// Remove sandbox (clear the sandbox attribute)
    pub fn clearSandbox(self: *IFrameIntegration) void {
        self.sandbox_flags = null;
        self.is_sandboxed = false;

        // Clear from browsing context if it exists
        if (self.browsing_context) |ctx| {
            ctx.clearSandboxFlags();
        }
    }

    /// Get the current sandbox flags (null if not sandboxed)
    pub fn getSandboxFlags(self: *const IFrameIntegration) ?SandboxFlags {
        return self.sandbox_flags;
    }

    /// Check if this iframe is sandboxed
    pub fn isSandboxed(self: *const IFrameIntegration) bool {
        return self.is_sandboxed;
    }

    /// Check if scripts are allowed in this iframe
    pub fn allowsScripts(self: *const IFrameIntegration) bool {
        if (self.sandbox_flags) |flags| {
            return flags.allow_scripts;
        }
        return true; // Not sandboxed
    }

    /// Check if forms are allowed in this iframe
    pub fn allowsForms(self: *const IFrameIntegration) bool {
        if (self.sandbox_flags) |flags| {
            return flags.allow_forms;
        }
        return true;
    }

    /// Check if popups are allowed in this iframe
    pub fn allowsPopups(self: *const IFrameIntegration) bool {
        if (self.sandbox_flags) |flags| {
            return flags.allow_popups;
        }
        return true;
    }

    /// Check if top navigation is allowed in this iframe
    pub fn allowsTopNavigation(self: *const IFrameIntegration) bool {
        if (self.sandbox_flags) |flags| {
            return flags.allow_top_navigation;
        }
        return true;
    }

    // ============================================================================
    // Script Execution for Iframes
    // ============================================================================

    /// Execute inline scripts found in the parsed HTML tree.
    /// This function walks the tree to find <script> elements and executes their
    /// content in the iframe's context using the execute_script_callback.
    ///
    /// Per HTML Standard §4.12.1.1, scripts should execute in document order.
    /// For simplicity, we only execute inline scripts (no external src support here).
    pub fn executeScriptsInTree(self: *IFrameIntegration, document_node: *html_parser.TreeNode) void {
        // Need both the realm and the script execution callback
        const realm = self.runtime_context orelse return;
        const execute_callback = self.execute_script_callback orelse return;

        // Walk the tree and execute scripts
        self.executeScriptsRecursive(document_node, realm, execute_callback);
    }

    /// Recursively walk the tree and execute script elements
    fn executeScriptsRecursive(
        self: *IFrameIntegration,
        node: *html_parser.TreeNode,
        realm: *anyopaque,
        execute_callback: *const fn (?*anyopaque, []const u8) void,
    ) void {
        // Check if this is a script element
        if (node.node_type == .element) {
            if (node.local_name) |name| {
                if (std.mem.eql(u8, name, "script")) {
                    // Check if sandbox allows scripts
                    if (self.isSandboxed() and !self.allowsScripts()) {
                        // Sandbox blocks script execution
                        return;
                    }

                    // Get script text content from child text nodes
                    const script_text = self.getScriptTextContent(node);
                    if (script_text.len > 0) {
                        // Execute via callback (which has V8 access)
                        execute_callback(realm, script_text);
                    }
                }
            }
        }

        // Recurse to children (depth-first, document order)
        var child = node.first_child;
        while (child) |c| {
            self.executeScriptsRecursive(c, realm, execute_callback);
            child = c.next_sibling;
        }
    }

    /// Get the text content of a script element (from its child text nodes)
    fn getScriptTextContent(self: *IFrameIntegration, script_node: *html_parser.TreeNode) []const u8 {
        _ = self;

        // Script text is in child text nodes
        var child = script_node.first_child;
        while (child) |c| {
            if (c.node_type == .text) {
                // Return the text content (simplified - doesn't concatenate multiple text nodes)
                return c.text_content.toSlice();
            }
            child = c.next_sibling;
        }
        return "";
    }

    /// Update the iframe's Location URL to reflect the navigated URL.
    /// This is called during navigation so that `location.hash`, etc. work correctly.
    fn updateLocationUrl(self: *IFrameIntegration, url: []const u8) void {
        // Need both the realm and the location update callback
        const realm = self.runtime_context orelse return;
        const update_callback = self.update_location_callback orelse return;

        // Call the callback (which has impls access)
        update_callback(realm, url);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "IFrameIntegration - init creates uninitialized state" {
    const allocator = std.testing.allocator;

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    try std.testing.expectEqual(IFrameState.uninitialized, integration.state);
    try std.testing.expect(integration.browsing_context == null);
    try std.testing.expect(integration.window_proxy == null);
}

test "IFrameIntegration - a pending policy container is taken by the commit, or released with the integration" {
    const allocator = std.testing.allocator;
    const PolicyContainer = @import("fetch").internal.PolicyContainer;

    const parent_ctx = try BrowsingContext.initTopLevel(allocator);
    defer parent_ctx.deinit();

    // Set, then taken - what a commit does: the document owns it.
    {
        var integration = IFrameIntegration.init(allocator);
        defer integration.deinit();
        try integration.onInsertedIntoDocument(parent_ctx, Origin.createOpaque());
        integration.setNextPolicyContainer(try PolicyContainer.fromResponse(allocator, "no-referrer"));
        // A second set releases the first.
        integration.setNextPolicyContainer(try PolicyContainer.fromResponse(allocator, "origin"));
        var taken = integration.takeNextPolicyContainer() orelse return error.TestExpectedContainer;
        defer taken.deinit();
        try std.testing.expectEqual(@import("fetch").internal.ReferrerPolicy.origin, taken.referrer_policy);
        try std.testing.expect(integration.takeNextPolicyContainer() == null);
    }

    // Set, then the iframe is removed before any document took it: the
    // integration's deinit releases it.
    {
        var integration = IFrameIntegration.init(allocator);
        defer integration.deinit();
        try integration.onInsertedIntoDocument(parent_ctx, Origin.createOpaque());
        integration.setNextPolicyContainer(try PolicyContainer.fromResponse(allocator, "no-referrer"));
        integration.onRemovedFromDocument();
    }
}

test "IFrameIntegration - insertion creates browsing context" {
    const allocator = std.testing.allocator;

    const parent_ctx = try BrowsingContext.initTopLevel(allocator);
    defer parent_ctx.deinit();

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    const container_origin = Origin.init("https", "example.com", 443);

    try integration.onInsertedIntoDocument(parent_ctx, container_origin);

    // Should have created nested browsing context
    try std.testing.expect(integration.browsing_context != null);
    try std.testing.expect(integration.window_proxy != null);
    try std.testing.expect(integration.state != .uninitialized);

    // Should be child of parent
    if (integration.browsing_context) |ctx| {
        try std.testing.expect(ctx.parent == parent_ctx);
    }
}

test "IFrameIntegration - removal discards browsing context" {
    const allocator = std.testing.allocator;

    const parent_ctx = try BrowsingContext.initTopLevel(allocator);
    defer parent_ctx.deinit();

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    try integration.onInsertedIntoDocument(parent_ctx, Origin.createOpaque());

    integration.onRemovedFromDocument();

    try std.testing.expectEqual(IFrameState.discarded, integration.state);
    if (integration.browsing_context) |ctx| {
        try std.testing.expect(ctx.is_closed);
    }
}

test "IFrameIntegration - setSrc triggers navigation" {
    const allocator = std.testing.allocator;

    const parent_ctx = try BrowsingContext.initTopLevel(allocator);
    defer parent_ctx.deinit();

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    try integration.onInsertedIntoDocument(parent_ctx, Origin.init("https", "example.com", 443));

    try integration.setSrc("https://example.com/page");

    try std.testing.expect(integration.getSrc() != null);
    try std.testing.expectEqualStrings("https://example.com/page", integration.getSrc().?);
}

test "IFrameIntegration - setSrcdoc" {
    const allocator = std.testing.allocator;

    const parent_ctx = try BrowsingContext.initTopLevel(allocator);
    defer parent_ctx.deinit();

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    try integration.onInsertedIntoDocument(parent_ctx, Origin.init("https", "example.com", 443));

    try integration.setSrcdoc("<html><body>Hello</body></html>");

    try std.testing.expect(integration.getSrcdoc() != null);
}

test "IFrameIntegration - setName updates browsing context" {
    const allocator = std.testing.allocator;

    const parent_ctx = try BrowsingContext.initTopLevel(allocator);
    defer parent_ctx.deinit();

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    try integration.onInsertedIntoDocument(parent_ctx, Origin.createOpaque());

    try integration.setName("myframe");

    try std.testing.expectEqualStrings("myframe", integration.getName());
    if (integration.browsing_context) |ctx| {
        try std.testing.expectEqualStrings("myframe", ctx.target_name);
    }
}

test "IFrameIntegration - getContentWindow returns null when uninitialized" {
    const allocator = std.testing.allocator;

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    try std.testing.expect(integration.getContentWindow() == null);
}

test "IFrameIntegration - getContentWindow returns proxy when initialized" {
    const allocator = std.testing.allocator;

    const parent_ctx = try BrowsingContext.initTopLevel(allocator);
    defer parent_ctx.deinit();

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    try integration.onInsertedIntoDocument(parent_ctx, Origin.createOpaque());

    try std.testing.expect(integration.getContentWindow() != null);
}

test "IFrameIntegration - contentDocument access same-origin" {
    const allocator = std.testing.allocator;

    const parent_ctx = try BrowsingContext.initTopLevel(allocator);
    defer parent_ctx.deinit();

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    const origin = Origin.init("https", "example.com", 443);
    try integration.onInsertedIntoDocument(parent_ctx, origin);

    // Same origin should allow access
    try std.testing.expect(integration.isContentDocumentAccessible(origin));

    // Cross-origin should deny access
    const cross_origin = Origin.init("https", "other.com", 443);
    try std.testing.expect(!integration.isContentDocumentAccessible(cross_origin));
}

test "IFrameIntegration - parseOriginFromURL" {
    const allocator = std.testing.allocator;

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    // HTTPS URL
    const https_origin = integration.parseOriginFromURL("https://example.com/path");
    try std.testing.expectEqualStrings("https", https_origin.scheme);
    try std.testing.expectEqualStrings("example.com", https_origin.host);

    // HTTP URL
    const http_origin = integration.parseOriginFromURL("http://example.com/path");
    try std.testing.expectEqualStrings("http", http_origin.scheme);

    // data: URL returns opaque
    const data_origin = integration.parseOriginFromURL("data:text/html,<h1>Hi</h1>");
    try std.testing.expect(data_origin.is_opaque);

    // javascript: URL returns opaque
    const js_origin = integration.parseOriginFromURL("javascript:void(0)");
    try std.testing.expect(js_origin.is_opaque);
}

test "IFrameIntegration - about:blank inherits origin" {
    const allocator = std.testing.allocator;

    const parent_ctx = try BrowsingContext.initTopLevel(allocator);
    defer parent_ctx.deinit();

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    const container_origin = Origin.init("https", "example.com", 443);
    try integration.onInsertedIntoDocument(parent_ctx, container_origin);

    // about:blank should inherit container origin
    if (integration.window_proxy) |proxy| {
        try std.testing.expect(proxy.isSameOriginAccess(container_origin));
    }
}

// ============================================================================
// Sandbox Tests
// ============================================================================

test "IFrameIntegration - setSandbox with empty value blocks all" {
    const allocator = std.testing.allocator;

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    // Empty sandbox = all restrictions
    try integration.setSandbox("");

    try std.testing.expect(integration.isSandboxed());
    try std.testing.expect(!integration.allowsScripts());
    try std.testing.expect(!integration.allowsForms());
    try std.testing.expect(!integration.allowsPopups());
    try std.testing.expect(!integration.allowsTopNavigation());
}

test "IFrameIntegration - setSandbox with allow-scripts" {
    const allocator = std.testing.allocator;

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    try integration.setSandbox("allow-scripts");

    try std.testing.expect(integration.isSandboxed());
    try std.testing.expect(integration.allowsScripts());
    try std.testing.expect(!integration.allowsForms());
}

test "IFrameIntegration - setSandbox with multiple flags" {
    const allocator = std.testing.allocator;

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    try integration.setSandbox("allow-scripts allow-forms allow-same-origin");

    try std.testing.expect(integration.isSandboxed());
    try std.testing.expect(integration.allowsScripts());
    try std.testing.expect(integration.allowsForms());

    const flags = integration.getSandboxFlags().?;
    try std.testing.expect(flags.allow_same_origin);
}

test "IFrameIntegration - clearSandbox removes restrictions" {
    const allocator = std.testing.allocator;

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    try integration.setSandbox("allow-scripts");
    try std.testing.expect(integration.isSandboxed());

    integration.clearSandbox();
    try std.testing.expect(!integration.isSandboxed());
    try std.testing.expect(integration.allowsScripts()); // No sandbox = allow all
    try std.testing.expect(integration.allowsForms());
}

test "IFrameIntegration - sandbox applied to browsing context" {
    const allocator = std.testing.allocator;

    const parent_ctx = try BrowsingContext.initTopLevel(allocator);
    defer parent_ctx.deinit();

    var integration = IFrameIntegration.init(allocator);
    defer integration.deinit();

    // Set sandbox before insertion
    try integration.setSandbox("allow-scripts");

    // Insert into document
    try integration.onInsertedIntoDocument(parent_ctx, Origin.createOpaque());

    // Apply sandbox to browsing context
    if (integration.browsing_context) |ctx| {
        // The sandbox flags should be applied
        ctx.setSandboxFlags(integration.sandbox_flags.?);
        try std.testing.expect(ctx.is_sandboxed);
        try std.testing.expect(ctx.allowsScripts());
        try std.testing.expect(!ctx.allowsForms());
    }
}

// ============================================================================
// Percent Decode Tests (Phase 2)
// ============================================================================

test "percentDecode - no escapes" {
    const allocator = std.testing.allocator;
    const result = try percentDecode(allocator, "hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "percentDecode - simple escape" {
    const allocator = std.testing.allocator;
    const result = try percentDecode(allocator, "hello%20world");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello world", result);
}

test "percentDecode - multiple escapes" {
    const allocator = std.testing.allocator;
    const result = try percentDecode(allocator, "%3C%3E");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("<>", result);
}

test "IFrameIntegration - an http(s) URL's origin keeps its port and drops the rest" {
    var integration = IFrameIntegration.init(std.testing.allocator);
    defer integration.deinit();

    const cases = [_]struct { url: []const u8, scheme: []const u8, host: []const u8, port: u16 }{
        .{ .url = "http://web-platform.test:8000/a/b.py?x=1#f", .scheme = "http", .host = "web-platform.test", .port = 8000 },
        .{ .url = "http://web-platform.test/a", .scheme = "http", .host = "web-platform.test", .port = 80 },
        .{ .url = "https://www.web-platform.test:8443", .scheme = "https", .host = "www.web-platform.test", .port = 8443 },
        .{ .url = "https://user:pw@example.com:9/p", .scheme = "https", .host = "example.com", .port = 9 },
        .{ .url = "http://[::1]:8000/", .scheme = "http", .host = "[::1]", .port = 8000 },
        .{ .url = "http://[::1]/", .scheme = "http", .host = "[::1]", .port = 80 },
        .{ .url = "http://example.com?q", .scheme = "http", .host = "example.com", .port = 80 },
    };
    for (cases) |c| {
        const origin = integration.parseOriginFromURL(c.url);
        try std.testing.expect(origin.isSameOrigin(Origin.init(c.scheme, c.host, c.port)));
    }
}
