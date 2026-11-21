//! Implementation for Location interface
//!
//! Implements the Location interface per HTML Standard §7.1.3.
//! Spec: https://html.spec.whatwg.org/multipage/history.html#the-location-interface
//!
//! ## Overview
//!
//! The Location interface represents the URL of the document and provides
//! methods to manipulate it. Setting URL components triggers navigation.
//!
//! ## Security Model
//!
//! The Location interface has special security requirements:
//! - Cross-origin access is restricted (throws SecurityError)
//! - Only certain properties are accessible cross-origin (href setter, replace)
//!
//! ## Navigation
//!
//! Setting URL components or calling navigation methods triggers:
//! - assign(): Normal navigation (adds to session history)
//! - replace(): Replace navigation (replaces current entry)
//! - reload(): Reloads the current document

const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.location);
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");

// URL modules
const url_record = @import("url_record");
const url_serializer = @import("url_serializer");
const host_serializer = @import("host_serializer");
const origin = @import("origin");
const basic_parser = @import("basic_parser");
const ParserState = @import("parser_state").ParserState;
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;

/// Special schemes default ports
/// Per WHATWG URL spec: https://url.spec.whatwg.org/#special-scheme
fn getDefaultPort(scheme: []const u8) ?u16 {
    if (std.mem.eql(u8, scheme, "http") or std.mem.eql(u8, scheme, "ws")) {
        return 80;
    } else if (std.mem.eql(u8, scheme, "https") or std.mem.eql(u8, scheme, "wss")) {
        return 443;
    } else if (std.mem.eql(u8, scheme, "ftp")) {
        return 21;
    }
    return null;
}

const Location = interfaces.Location;

pub const State = Location.State;

pub const ImplError = error{
    NotImplemented,
    SecurityError,
    InvalidStateError,
    SyntaxError,
    OutOfMemory,
};

const html_core = @import("html_core");
const navigate_steps = html_core.navigation.navigate_steps;
const joint_history = html_core.navigation.joint_history;
const dom = @import("dom");
const origin_domain = @import("html").origin_domain;

/// What "Location-object navigate" asks of the navigable's engine.
const NavigateRequest = dom.window_globals.NavigateRequest;

/// Navigation callback type for Location.assign/replace/href setter
/// (dom.window_globals.NavigateCallback): the navigable's "navigate".
const NavigateCallback = dom.window_globals.NavigateCallback;

/// Internal state for Location implementation
/// Contains private data not exposed via WebIDL attributes.
pub const InternalState = struct {
    /// Allocator for this location's resources
    allocator: Allocator,

    /// The associated window (owner)
    window: ?*runtime.Instance = null,

    /// The document's URL as a parsed URLRecord
    /// This is owned by the Document, Location just references it
    url: ?*url_record.URLRecord = null,

    /// The relevant Document's ancestor origins list (HTML 7.2.4
    /// ancestorOrigins getter step 4), made the first time it is asked for:
    /// the document's ancestor chain cannot change while it is active. Kept
    /// for `ancestor_origins_document` only; another document gets its own.
    ancestor_origins: ?*runtime.Instance = null,
    /// The document `ancestor_origins` was made for.
    ancestor_origins_document: ?@import("dom").same_object.Link = null,
    /// Keeps the list's wrapper and its script properties alive with ours.
    ancestor_origins_edge: @import("dom").same_object.Traced = .{ .slot = .{ .name = "Location.ancestorOrigins" } },
    /// The Location's "empty DOMStringList" (HTML 7.2.4), returned whenever
    /// there is no relevant Document: one list for the Location's life.
    empty_ancestor_origins: ?*runtime.Instance = null,
    empty_ancestor_origins_edge: @import("dom").same_object.Traced = .{ .slot = .{ .name = "Location.emptyAncestorOrigins" } },

    /// Cached href for comparison
    cached_href: ?[]const u8 = null,
    /// The document URL string `url` was last parsed from, so a document whose
    /// URL has not changed costs one comparison per access, not a parse.
    url_source: ?[]const u8 = null,

    /// Navigation callback for triggering actual navigation.
    /// Set by the context that creates this Location (e.g., HTMLIFrameElement for iframes).
    /// When set, call_assign/call_replace use this to perform navigation.
    navigate_callback: ?NavigateCallback = null,

    /// Opaque context pointer passed to navigate_callback.
    /// For iframe contexts, this is the IFrameIntegration*.
    navigate_context: ?*anyopaque = null,

    pub fn deinit(self: *InternalState) void {
        if (self.cached_href) |href| {
            self.allocator.free(href);
        }
        if (self.url_source) |src| self.allocator.free(src);
        // Free the URL if we own it (allocated in init)
        if (self.url) |url| {
            url.deinit();
            self.allocator.destroy(url);
        }
    }
};

/// Helper to get internal state from instance
/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// Helper to get URL from internal state
/// HTML §7.10.1: "A Location object's url is its relevant Document's URL,
/// if this Location object's relevant Document is non-null, and about:blank
/// otherwise" - with no relevant Document, its Window's Document's URL, as
/// the browsers do (urlDocumentWithoutRelevantDocument). The record parsed at
/// construction (about:blank) is the fallback when there is neither;
/// otherwise the document's URL wins, including changes made by
/// history.pushState.
fn getURL(instance: *runtime.Instance) ?*url_record.URLRecord {
    const internal = getInternal(instance) orelse return null;
    refreshFromDocument(internal);
    return internal.url;
}

/// The Document whose URL a Location with NO relevant Document reports: its
/// Window's associated Document, when it has one. HTML says about:blank
/// ("url ... about:blank otherwise"): a Window whose navigable navigated away,
/// or whose frame was removed, has a destroyed Document, and "destroy a
/// Document" step 6 set that Document's browsing context - so the Window's -
/// to null. The browsers read the Window's Document instead (golden rule 2,
/// the majority; the integrator's ruling, 2026-11-11): probe
/// tmp/probes/v8up-oldwin3/ (v3 and v4: Chrome 157.0, Firefox 159.0,
/// Safari 27.0), a Location kept from a frame's first document, read after
/// the frame navigated - href, toString, origin, protocol, host, pathname,
/// search: Chrome and Safari the OLD document's URL, Firefox the new one; and
/// a removed frame's Location: Chrome and Safari its document's URL, Firefox
/// "". Blink's Location::Url reads its DOMWindow's document. Only the URL
/// changes: the href setter, assign, replace, reload and the component
/// setters still begin "if this's relevant Document is null, then return" -
/// in Chrome and Safari none of them navigates the frame from such a
/// Location (Firefox's do: its old Location follows the docshell), and
/// ancestorOrigins is the empty list in all three.
fn urlDocumentWithoutRelevantDocument(internal: *InternalState) ?*runtime.Instance {
    const window = internal.window orelse return null;
    if (window.stateAs(interfaces.Window.State) == null) return null;
    return interfaces.Window.get_document(window) catch null;
}

/// HTML's relevant Document: the relevant Window's browsing context's
/// active document, or null after that context is discarded. Reading the
/// native record also works for href/replace's cross-origin callers.
fn relevantDocument(internal: *InternalState) ?*runtime.Instance {
    const window = internal.window orelse return null;
    const context = dom.browser_state.browsingContextOf(window) orelse return null;
    if (context.is_closed) return null;
    return @ptrCast(@alignCast(context.active_document orelse return null));
}

/// HTML §7.2.4, the step the Location members begin with: "If this's
/// relevant Document is non-null and its origin is not same origin-domain
/// with the entry settings object's origin, then throw a "SecurityError"
/// DOMException." A Location has a relevant Document while it has a window
/// (whose browsing context's active document it is).
fn checkSameOriginDomain(internal: *InternalState) !void {
    if (relevantDocument(internal) == null) return;
    const window = internal.window orelse return;
    if (!origin_domain.entryIsSameOriginDomainWith(window)) return error.SecurityError;
}

/// The same check for a getter, which starts from `instance`.
fn checkGetter(instance: *runtime.Instance) !void {
    const internal = getInternal(instance) orelse return;
    try checkSameOriginDomain(internal);
}

/// Re-parse `internal.url` when the relevant document's URL string differs
/// from the one it was parsed from. Every failure leaves the previous record
/// in place: an unreadable document URL is not a reason to report a wrong one.
fn refreshFromDocument(internal: *InternalState) void {
    const document = relevantDocument(internal) orelse urlDocumentWithoutRelevantDocument(internal);
    // The interface getter clones into the DOCUMENT's context allocator, so
    // that is what frees it (AGENTS.md, "Interface getters clone").
    const doc_url = if (document) |doc| interfaces.Document.get_URL(doc) catch return else "about:blank";
    defer if (document) |doc| doc.ctx.allocator.free(doc_url);
    if (doc_url.len == 0) return;
    if (internal.url_source) |src| {
        if (std.mem.eql(u8, src, doc_url)) return;
    }

    const parsed = internal.allocator.create(url_record.URLRecord) catch return;
    parsed.* = basic_parser.parse(internal.allocator, doc_url, null) catch {
        internal.allocator.destroy(parsed);
        return;
    };
    const source = internal.allocator.dupe(u8, doc_url) catch {
        parsed.deinit();
        internal.allocator.destroy(parsed);
        return;
    };

    if (internal.url) |old| {
        old.deinit();
        internal.allocator.destroy(old);
    }
    internal.url = parsed;
    if (internal.url_source) |src| internal.allocator.free(src);
    internal.url_source = source;
    if (internal.cached_href) |href| {
        internal.allocator.free(href);
        internal.cached_href = null;
    }
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // A Location's Window, navigable and URL, which the code that makes a
    // navigable's Window wires (HTMLIFrameElement) and the engine adapter's
    // wrapper cache reads: steps no IDL member names.
    dom.window_globals.installLocation(.{
        .window = &windowOf,
        .set_window = &setWindow,
        .set_navigable = &setNavigateCallback,
        .set_url = &setURLFromString,
    });
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    std.log.debug("[Location.init] Created instance {*}", .{instance});
    // Should anything below fail (out of memory), the instance's teardown
    // (`deinit`) frees whatever its internal state holds by then, and its
    // slot goes back. With no errdefer, a failed URL parse left the internal
    // state and the URL record allocated for good: a navigation's new
    // Window makes its Location (Window.get_location under attachRealm), and
    // tests/html/iframe_policy_container_oom_test.zig found 10 such blocks
    // live after Browser.deinit (lane v8up b3h).
    const state = instance.getState(StateType);
    state.own._internal = null;
    errdefer runtime.Instance.deinit(instance);

    // Initialize internal state. The Window is the relevant global object -
    // the realm record's, when the realm is a Window's (a Location made after
    // its Window, as Window.get_location makes one); setWindow says it
    // otherwise.
    const internal = try allocator.create(InternalState);
    internal.* = .{
        .allocator = allocator,
        .window = relevantWindow(ctx),
    };
    state.own._internal = internal;

    // Initialize with default URL (about:blank)
    // Per spec, Location's URL should be the document's URL
    // For WPT tests, we initialize to a default URL that can be updated later
    const parsed_url = try allocator.create(url_record.URLRecord);
    errdefer allocator.destroy(parsed_url);
    parsed_url.* = try basic_parser.parse(allocator, "about:blank", null);
    internal.url = parsed_url;

    std.log.debug("[Location.init] Instance {*} initialized with URL {*}", .{ instance, parsed_url });
    return instance;
}

/// `realm`'s global object, when it is a Window.
fn relevantWindow(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    if (global.stateAs(interfaces.Window.State) == null) return null;
    return global;
}

/// Update the Location's URL from a URL string
/// Called when navigating or when setting document URL
/// (dom.window_globals.setLocationUrl).
fn setURLFromString(instance: *runtime.Instance, url_string: []const u8) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const allocator = internal.allocator;

    const parsed_url = try allocator.create(url_record.URLRecord);
    errdefer allocator.destroy(parsed_url);
    parsed_url.* = try basic_parser.parse(allocator, url_string, null);
    errdefer parsed_url.deinit();
    // The string the record was parsed from, which `refreshFromDocument`
    // compares the document's URL with. Left behind, a later document URL
    // equal to the stale source - a traversal back over a fragment
    // navigation - was taken for "unchanged", and the record kept the
    // fragment.
    const source = try allocator.dupe(u8, url_string);

    if (internal.url) |old_url| {
        old_url.deinit();
        allocator.destroy(old_url);
    }
    internal.url = parsed_url;
    if (internal.url_source) |src| allocator.free(src);
    internal.url_source = source;
    if (internal.cached_href) |href| {
        allocator.free(href);
        internal.cached_href = null;
    }
}

/// The Window this Location belongs to, or null: made for none, or not a
/// Location (dom.window_globals.locationWindow). The wrapper cache keeps a
/// window's Location's wrapper with the window.
fn windowOf(instance: *runtime.Instance) ?*runtime.Instance {
    if (instance.stateAs(State) == null) return null;
    const internal = getInternal(instance) orelse return null;
    return internal.window;
}

/// Set the associated Window for this Location.
/// Called by Window/context initialization to establish the bi-directional link.
/// This enables Location.assign() to access the browsing context for navigation
/// (dom.window_globals.setLocationWindow).
fn setWindow(instance: *runtime.Instance, window: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    internal.window = window;
}

/// Set the navigation callback for this Location.
/// Called by iframe setup to enable programmatic navigation via location.href/assign/replace.
/// Parameters:
/// - callback: Function to call for navigation, or null to disable
/// - context: Opaque pointer passed to callback (e.g., IFrameIntegration*)
/// (dom.window_globals.setLocationNavigable).
fn setNavigateCallback(
    instance: *runtime.Instance,
    callback: ?NavigateCallback,
    context: ?*anyopaque,
) void {
    const internal = getInternal(instance) orelse return;
    internal.navigate_callback = callback;
    internal.navigate_context = context;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Location cleanup can be called from multiple paths:
    // 1. engine.destroyWindowRealm → Window.deinit → Location.deinit (normal cleanup)
    // 2. DOM tree traversal during nested iframe cleanup (may pre-mark)
    //
    // The lifecycle tracking prevents concurrent cleanup races, but we MUST
    // still clean up internal state if it exists. The state pointer being
    // non-null is the definitive check for whether cleanup is needed.
    const instance_lifecycle = @import("runtime").instance_lifecycle;

    // Try to mark cleanup started. If it returns false, another path already marked it,
    // but we still need to check and clean up internal state if present.
    const is_first = instance_lifecycle.markCleanupStarted(instance);

    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.ancestor_origins_edge.release(instance);
        internal.empty_ancestor_origins_edge.release(instance);
        internal.deinit();
        internal.allocator.destroy(internal);
        // Clear the pointer to prevent double-free on subsequent calls
        state.own._internal = null;
    }

    // Only clear lifecycle entry if we were the first to mark cleanup started.
    // This ensures the slab allocator address reuse works correctly.
    if (is_first) {
        instance_lifecycle.markCleanupComplete(instance);
    }
}

// =============================================================================
// URL Component Getters
// =============================================================================

/// Getter for href
/// Per spec §7.1.3: Returns the URL serialization of this Location's URL.
/// Returns DOMString with owned memory that caller must free.
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
    // Step 1: the same-origin-domain check (checkSameOriginDomain).
    try checkGetter(instance);
    const url = getURL(instance) orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    // Serialize the URL (exclude fragment = false)
    const serialized = try url_serializer.serialize(allocator, url, false);

    return serialized;
}

/// Getter for origin
/// Per spec §7.1.3: Returns the serialization of this Location's origin.
/// Returns DOMString with owned memory that caller must free.
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    // Step 1: the same-origin-domain check (checkSameOriginDomain).
    try checkGetter(instance);
    const url = getURL(instance) orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    // Get origin from URL
    const url_origin = try origin.getOrigin(allocator, url);
    defer url_origin.deinit(allocator);

    // Serialize the origin
    const serialized = try url_origin.serialize(allocator);

    return serialized;
}

/// Getter for protocol
/// Per spec §7.1.3: Returns the scheme of this Location's URL, followed by ":".
/// Returns DOMString with owned memory that caller must free.
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
    // Step 1: the same-origin-domain check (checkSameOriginDomain).
    try checkGetter(instance);
    const url = getURL(instance) orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    const scheme = url.scheme();

    // Allocate scheme + ":"
    const result = try allocator.alloc(u8, scheme.len + 1);
    @memcpy(result[0..scheme.len], scheme);
    result[scheme.len] = ':';

    return result;
}

/// Getter for host
/// Per spec §7.1.3: Returns this Location's URL host and port (if different from default).
/// Returns DOMString with owned memory that caller must free.
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_host(instance: *runtime.Instance) anyerror!runtime.USVString {
    // Step 1: the same-origin-domain check (checkSameOriginDomain).
    try checkGetter(instance);
    const url = getURL(instance) orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    // If no host, return empty string
    if (url.host == null) {
        return "";
    }

    // Serialize host
    const host_str = try host_serializer.serializeHost(allocator, url.host.?);
    defer allocator.free(host_str);

    // If no port or default port, return just host
    if (url.port == null) {
        const buffer = try allocator.dupe(u8, host_str);
        return buffer;
    }

    // Check if port is default for scheme
    const scheme = url.scheme();
    const default_port = getDefaultPort(scheme);
    if (default_port != null and url.port.? == default_port.?) {
        const buffer = try allocator.dupe(u8, host_str);
        return buffer;
    }

    // Return host:port
    const result = try std.fmt.allocPrint(allocator, "{s}:{d}", .{ host_str, url.port.? });

    return result;
}

/// Getter for hostname
/// Per spec §7.1.3: Returns this Location's URL host, serialized.
/// Returns DOMString with owned memory that caller must free.
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_hostname(instance: *runtime.Instance) anyerror!runtime.USVString {
    // Step 1: the same-origin-domain check (checkSameOriginDomain).
    try checkGetter(instance);
    const url = getURL(instance) orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    // If no host, return empty string
    if (url.host == null) {
        return "";
    }

    // Serialize host
    const host_str = try host_serializer.serializeHost(allocator, url.host.?);

    return host_str;
}

/// Getter for port
/// Per spec §7.1.3: Returns this Location's URL port, serialized.
/// Returns DOMString with owned memory that caller must free.
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_port(instance: *runtime.Instance) anyerror!runtime.USVString {
    // Step 1: the same-origin-domain check (checkSameOriginDomain).
    try checkGetter(instance);
    const url = getURL(instance) orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    // If no port, return empty string
    if (url.port == null) {
        return "";
    }

    // Serialize port
    const result = try std.fmt.allocPrint(allocator, "{d}", .{url.port.?});

    return result;
}

/// Getter for pathname
/// Per spec §7.1.3: Returns the URL path serialized.
/// Returns DOMString with owned memory that caller must free.
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_pathname(instance: *runtime.Instance) anyerror!runtime.USVString {
    // Step 1: the same-origin-domain check (checkSameOriginDomain).
    try checkGetter(instance);
    const url = getURL(instance) orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    // Use the path component from URL
    switch (url.path) {
        .opaque_path => |op| {
            const buffer = try allocator.dupe(u8, op);
            return buffer;
        },
        .segments => |segs| {
            // Build path string with "/" separators
            var result = std.ArrayListUnmanaged(u8).empty;
            errdefer result.deinit(allocator);

            var i: usize = 0;
            while (i < segs.len) : (i += 1) {
                try result.append(allocator, '/');
                if (segs.get(i)) |segment| {
                    try result.appendSlice(allocator, segment);
                }
            }

            // If empty segments, return "/"
            if (result.items.len == 0) {
                try result.append(allocator, '/');
            }

            const buffer = try result.toOwnedSlice(allocator);
            return buffer;
        },
    }
}

/// Getter for search
/// Per spec §7.1.3: Returns this Location's URL query (includes "?").
/// Returns DOMString with owned memory that caller must free.
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_search(instance: *runtime.Instance) anyerror!runtime.USVString {
    // Step 1: the same-origin-domain check (checkSameOriginDomain).
    try checkGetter(instance);
    const url = getURL(instance) orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    // If no query, return empty string
    const query = url.query() orelse {
        return "";
    };
    // HTML search getter step 2: null AND the empty query return "".
    if (query.len == 0) return "";

    // Return "?" + query
    const result = try allocator.alloc(u8, query.len + 1);
    result[0] = '?';
    @memcpy(result[1..], query);

    return result;
}

/// Getter for hash
/// Per spec §7.1.3: Returns this Location's URL fragment (includes "#").
/// Returns DOMString with owned memory that caller must free.
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_hash(instance: *runtime.Instance) anyerror!runtime.USVString {
    // Step 1: the same-origin-domain check (checkSameOriginDomain).
    try checkGetter(instance);
    const url = getURL(instance) orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    // If no fragment, return empty string
    const fragment = url.fragment() orelse {
        return "";
    };
    // HTML hash getter step 2: null AND the empty fragment return "".
    if (fragment.len == 0) return "";

    // Return "#" + fragment
    const result = try allocator.alloc(u8, fragment.len + 1);
    result[0] = '#';
    @memcpy(result[1..], fragment);

    return result;
}

/// HTML 7.2.4 ancestorOrigins getter steps 1-4. Not [SameObject] (HTML
/// dropped it; webref bfbec43f44): the getter returns the relevant
/// Document's list, or the Location's empty list when there is none.
/// Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-location-ancestororigins
pub fn get_ancestorOrigins(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: no relevant Document - a detached or superseded Window's
    // Location - returns this's empty DOMStringList, the same one each time.
    // It precedes the access check.
    const context = if (internal.window) |window| dom.browser_state.browsingContextOf(window) else null;
    const document: *runtime.Instance = relevant: {
        if (context) |current| {
            if (current.active_document) |raw_document| {
                const active: *runtime.Instance = @ptrCast(@alignCast(raw_document));
                if (dom.document_activity.fullyActive(active, runtime.SlabAllocator.generationOf(active))) break :relevant active;
            }
        }
        if (internal.empty_ancestor_origins) |list| return list;
        const list = try dom.string_lists.create(instance.ctx, &.{});
        internal.empty_ancestor_origins_edge.hold(instance, list);
        internal.empty_ancestor_origins = list;
        return list;
    };

    try checkGetter(instance); // Step 2: same origin-domain.

    // Steps 3-4: the relevant Document's ancestor origins list, made once
    // for that document.
    if (internal.ancestor_origins) |list| {
        if (internal.ancestor_origins_document) |made_for| {
            if (made_for.instance == document and made_for.isLive()) return list;
        }
    }

    // HTML 3.1.3: the document's internal ancestor origin objects list,
    // masked by each frame's iframe element referrer policy
    // (whatwg/html#11560, 2026-03-11; Firefox 157 ships it, 16/16 in
    // location-ancestor-origins.sub.html at wpt.fyi cc74d2669f, where Chrome
    // and Safari are 9/16). Golden rule 2 as refined 2026-10-17: a newer spec
    // one browser ships wins (gr2audit A19).
    var origins: std.ArrayList(?dom.origin_record.Origin) = .empty;
    defer origins.deinit(internal.allocator);
    try internalAncestorOrigins(internal.allocator, context.?, &origins);
    var strings: std.ArrayList([]const u8) = .empty;
    defer strings.deinit(internal.allocator);
    // Ancestor origins list creation step 4: each origin's serialization; a
    // masked entry is a new opaque origin, "null".
    for (origins.items) |entry| try strings.append(internal.allocator, if (entry) |o| o.serialized else "null");

    // Ancestor origins list creation steps 3-5: a DOMStringList that owns
    // copies of the serializations. A traced edge preserves script state
    // when only the Location still refers to the list; a list made for an
    // earlier document stays readable for script that holds it.
    const list = try dom.string_lists.create(instance.ctx, strings.items);
    internal.ancestor_origins_edge.hold(instance, list);
    internal.ancestor_origins = list;
    internal.ancestor_origins_document = @import("dom").same_object.Link.to(document);
    return list;
}

/// `document`'s origin as a security check reads it: its record, with the
/// serialization resolved. Borrowed for the computation that asks.
fn documentOriginOf(document: *runtime.Instance) !dom.origin_record.Origin {
    const record = (try dom.document_origin.shareable(document)) orelse return error.InvalidStateError;
    return .{ .serialized = record.serialized orelse "null", .record = record };
}

/// HTML 3.1.3 "internal ancestor origin objects list creation steps" for the
/// active document of `context`, into `out` (null: a new opaque origin, a
/// masked entry). The spec runs them as each document is created, from its
/// parent document's list; a document's container chain and the policy it
/// was created with (BrowsingContext.ancestor_origins_policy) cannot change
/// while it is fully active, so running them now, top-down over the chain,
/// gives the same list. The origins are borrowed from the chain's active
/// documents for the caller's synchronous use.
/// Spec: https://html.spec.whatwg.org/multipage/document-sequences.html#internal-ancestor-origin-objects-list-creation-steps
fn internalAncestorOrigins(allocator: Allocator, context: *html_core.BrowsingContext, out: *std.ArrayList(?dom.origin_record.Origin)) !void {
    // The chain, innermost first: context, its parent, ..., the top.
    var chain: std.ArrayList(*html_core.BrowsingContext) = .empty;
    defer chain.deinit(allocator);
    var at: ?*html_core.BrowsingContext = context;
    while (at) |c| : (at = c.parent) try chain.append(allocator, c);

    // The top-level document's list is empty (step 3); each child's is made
    // from its parent document's (step 5).
    var parent_list: std.ArrayList(?dom.origin_record.Origin) = .empty;
    defer parent_list.deinit(allocator);
    var index = chain.items.len - 1;
    while (index > 0) {
        index -= 1;
        const child = chain.items[index];
        const parent = chain.items[index + 1];
        const raw_document = child.active_document orelse return error.InvalidStateError;
        const raw_parent_document = parent.active_document orelse return error.InvalidStateError;
        const document_origin = try documentOriginOf(@ptrCast(@alignCast(raw_document)));
        // Steps 2 and 4: parentDoc, the container document.
        const parent_origin = try documentOriginOf(@ptrCast(@alignCast(raw_parent_document)));

        // Step 1: output.
        var output: std.ArrayList(?dom.origin_record.Origin) = .empty;
        errdefer output.deinit(allocator);
        // Steps 7-9: masked by "no-referrer", or by "same-origin" when the
        // parent document is of another origin.
        var masked = switch (child.ancestor_origins_policy) {
            .no_referrer => true,
            .same_origin => !dom.origin_record.sameOrigin(parent_origin, document_origin),
            else => false,
        };
        // Steps 10-11: a new opaque origin, or parentDoc's origin.
        try output.append(allocator, if (masked) null else parent_origin);
        // Step 12: parentDoc's own list (step 5).
        for (parent_list.items) |ancestor_origin| {
            // 12.1. A masked run hides the origins equal to parentDoc's.
            if (masked) {
                if (ancestor_origin) |o| {
                    if (dom.origin_record.sameOrigin(o, parent_origin)) {
                        try output.append(allocator, null);
                        continue;
                    }
                }
            }
            // 12.2.
            try output.append(allocator, ancestor_origin);
            masked = false;
        }
        parent_list.deinit(allocator);
        parent_list = output;
    }
    // Step 13: the innermost document's list.
    try out.appendSlice(allocator, parent_list.items);
}

// =============================================================================
// URL Component Setters
// =============================================================================

/// Setter for href
/// HTML §7.2.4: "1. If this's relevant Document is null, then return.
/// 2. Let url be the result of encoding-parsing a URL given the given value,
/// relative to the entry settings object. 3. If url is failure, then throw a
/// "SyntaxError" DOMException. 4. Location-object navigate this to url."
/// Intentionally no security check.
pub fn set_href(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (relevantDocument(internal) == null) return;
    const url = try parseRelativeToEntry(instance, internal, value);
    defer internal.allocator.free(url);
    return locationObjectNavigate(internal, url, .auto);
}

/// "Let copyURL be a copy of this's url": a record the URL-component setters
/// change and navigate to; the caller deinits it. Null with no URL.
fn copyOfURL(instance: *runtime.Instance, allocator: Allocator) !?url_record.URLRecord {
    const url = getURL(instance) orelse return null;
    const serialized = try url_serializer.serialize(allocator, url, false);
    defer allocator.free(serialized);
    return basic_parser.parse(allocator, serialized, null) catch null;
}

/// Basic URL parse `input` with `copy` as url and `state` as state override.
/// A failure leaves `copy` as it was, which is all a setter asks of it,
/// except the protocol setter, which throws (`error.SyntaxError`).
fn parseInto(allocator: Allocator, copy: *url_record.URLRecord, input: []const u8, state: ParserState) !void {
    if (basic_parser.parseWithStateOverride(allocator, input, null, state, copy)) |_| {} else |err| {
        if (err == error.OutOfMemory) return error.OutOfMemory;
        return error.SyntaxError;
    }
}

/// The URL-component setters' last step: "Location-object navigate this to
/// copyURL."
fn navigateToCopy(internal: *InternalState, copy: *url_record.URLRecord) !void {
    const serialized = try url_serializer.serialize(internal.allocator, copy, false);
    defer internal.allocator.free(serialized);
    return locationObjectNavigate(internal, serialized, .auto);
}

/// Setter for protocol
/// HTML §7.2.4: "1. If this's relevant Document is null, then return. ...
/// 3. Let copyURL be a copy of this's url. 4. Let possibleFailure be the
/// result of basic URL parsing the given value, followed by ":", with
/// copyURL as url and scheme start state as state override. 5. If
/// possibleFailure is failure, then throw a "SyntaxError" DOMException. 6. If
/// copyURL's scheme is not an HTTP(S) scheme, then terminate these steps. 7.
/// Location-object navigate this to copyURL."
pub fn set_protocol(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (relevantDocument(internal) == null) return;
    try checkSameOriginDomain(internal);
    const allocator = internal.allocator;
    var copy = (try copyOfURL(instance, allocator)) orelse return;
    defer copy.deinit();
    const input = try std.fmt.allocPrint(allocator, "{s}:", .{value});
    defer allocator.free(input);
    try parseInto(allocator, &copy, input, ParserState.scheme_start);
    const scheme = copy.scheme();
    if (!std.mem.eql(u8, scheme, "http") and !std.mem.eql(u8, scheme, "https")) return;
    return navigateToCopy(internal, &copy);
}

/// Setter for host
/// HTML §7.2.4: "3. Let copyURL be a copy of this's url. 4. If copyURL has an
/// opaque path, then return. 5. Basic URL parse the given value, with copyURL
/// as url and host state as state override. 6. Location-object navigate this
/// to copyURL."
pub fn set_host(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    return setComponent(instance, value, ParserState.host);
}

/// Setter for hostname: as host, with the hostname state as state override.
pub fn set_hostname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    return setComponent(instance, value, ParserState.hostname);
}

/// The host and hostname setters' steps.
fn setComponent(instance: *runtime.Instance, value: []const u8, state: ParserState) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (relevantDocument(internal) == null) return;
    try checkSameOriginDomain(internal);
    const allocator = internal.allocator;
    var copy = (try copyOfURL(instance, allocator)) orelse return;
    defer copy.deinit();
    if (copy.hasOpaquePath()) return;
    parseInto(allocator, &copy, value, state) catch |err| if (err == error.OutOfMemory) return err;
    return navigateToCopy(internal, &copy);
}

/// Setter for port
/// HTML §7.2.4: "3. Let copyURL be a copy of this's url. 4. If copyURL cannot
/// have a username/password/port, then return. 5. If the given value is the
/// empty string, then set copyURL's port to null. 6. Otherwise, basic URL
/// parse the given value, with copyURL as url and port state as state
/// override. 7. Location-object navigate this to copyURL."
pub fn set_port(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (relevantDocument(internal) == null) return;
    try checkSameOriginDomain(internal);
    const allocator = internal.allocator;
    var copy = (try copyOfURL(instance, allocator)) orelse return;
    defer copy.deinit();
    if (copy.cannotHaveUsernamePasswordPort()) return;
    if (value.len == 0) {
        copy.port = null;
    } else {
        parseInto(allocator, &copy, value, ParserState.port) catch |err| if (err == error.OutOfMemory) return err;
    }
    return navigateToCopy(internal, &copy);
}

/// Setter for pathname
/// HTML §7.2.4: "3. Let copyURL be a copy of this's url. 4. If copyURL has an
/// opaque path, then return. 5. Set copyURL's path to the empty list. 6.
/// Basic URL parse the given value, with copyURL as url and path start state
/// as state override. 7. Location-object navigate this to copyURL."
pub fn set_pathname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (relevantDocument(internal) == null) return;
    try checkSameOriginDomain(internal);
    const allocator = internal.allocator;
    var copy = (try copyOfURL(instance, allocator)) orelse return;
    defer copy.deinit();
    if (copy.hasOpaquePath()) return;
    switch (copy.path) {
        .segments => |*segments| {
            for (segments.toSlice()) |segment| copy.allocator.free(segment);
            segments.clear();
        },
        .opaque_path => {},
    }
    parseInto(allocator, &copy, value, ParserState.path_start) catch |err| if (err == error.OutOfMemory) return err;
    return navigateToCopy(internal, &copy);
}

/// Setter for search
/// HTML §7.2.4: copy this's url; set its query to null for the empty string,
/// otherwise basic-URL-parse the value without a leading "?" with the query
/// state as state override and the relevant Document's encoding;
/// Location-object navigate to it. The fragment is kept.
pub fn set_search(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const document = relevantDocument(internal) orelse return;
    try checkSameOriginDomain(internal);
    const allocator = internal.allocator;
    // Steps 3-4: copy this's URL; the empty value makes its query null.
    var copy = (try copyOfURL(instance, allocator)) orelse return;
    defer copy.deinit();
    if (value.len == 0) {
        try copy.setQuery(null);
    } else {
        // Steps 5.1-5.3: remove one '?'; the query-state override initializes
        // the query to empty, then encodes with the relevant Document's
        // encoding. The entry Document can have a different encoding.
        const input = if (value[0] == '?') value[1..] else value;
        const sniffing = html_core.parser.encoding_sniffing;
        const name = dom.document_internals.getEncoding(document) orelse "UTF-8";
        const encoding = sniffing.lookup(name) orelse sniffing.utf_8;
        _ = try basic_parser.parseWithEncodingAndStateOverride(allocator, input, &copy, .query, encoding);
    }
    return navigateToCopy(internal, &copy); // Step 6.
}

/// Setter for hash
/// HTML §7.2.4, the hash setter steps.
pub fn set_hash(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Step 1: "If this's relevant Document is null, then return."
    if (relevantDocument(internal) == null) return;
    // Step 2: the same-origin-domain check.
    try checkSameOriginDomain(internal);
    // Step 3: "Let copyURL be a copy of this's url."
    const url = getURL(instance) orelse return;
    const allocator = internal.allocator;
    var copy = (try copyOfURL(instance, allocator)) orelse return;
    defer copy.deinit();
    // Step 4: the original URL remains unchanged while the copy is parsed.
    const this_fragment = url.fragment() orelse "";
    // Step 5: "Let input be the given value with a single leading "#"
    // removed, if any."
    const input = if (value.len > 0 and value[0] == '#') value[1..] else value;
    // Steps 6-7: state override starts with an empty fragment and preserves
    // spaces at either end. Full-URL parsing would strip those spaces.
    try parseInto(allocator, &copy, input, .fragment);
    // Step 8: "If copyURL's fragment is thisURLFragment, then return."
    if (std.mem.eql(u8, copy.fragment() orelse "", this_fragment)) return;
    // Step 9: "Location-object navigate this to copyURL."
    return navigateToCopy(internal, &copy);
}

/// `url` encoding-parsed relative to the entry settings object - the
/// document of the script that is running - and serialized; owned. Failure
/// is a "SyntaxError". With no script running, the Location's own URL is the
/// base.
fn parseRelativeToEntry(instance: *runtime.Instance, internal: *InternalState, url: []const u8) ![]u8 {
    const allocator = internal.allocator;
    if (entryDocument()) |document| {
        // HTML encoding-parse a URL: entry document base and encoding.
        // The helper's result belongs to that document's allocator, whereas
        // our callers free with the Location's. Copy across that boundary.
        const serialized = (try dom.encoding_parse.encodingParseAndSerialize(document, url)) orelse return error.SyntaxError;
        defer document.ctx.allocator.free(serialized);
        return allocator.dupe(u8, serialized);
    }
    var parsed = basic_parser.parse(allocator, url, getURL(instance)) catch return error.SyntaxError;
    defer parsed.deinit();
    return @constCast(try url_serializer.serialize(allocator, &parsed, false));
}

/// The entry global object's associated Document: the document of the
/// window whose realm is the entry realm (engine.entryRealm). Null when no
/// script is running, or the entry global is no Window.
fn entryDocument() ?*runtime.Instance {
    const realm = engine.entryRealm() orelse return null;
    const record = realm.getRealm() orelse return null;
    const window: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    if (window.stateAs(interfaces.Window.State) == null) return null;
    return interfaces.Window.get_document(window) catch null;
}

/// The incumbent global object's associated Document: the document of the
/// window whose realm is the incumbent realm (engine.incumbentRealm). Null
/// when no script is running, or the incumbent global is no Window.
fn incumbentDocument() ?*runtime.Instance {
    const realm = engine.incumbentRealm() orelse return null;
    const record = realm.getRealm() orelse return null;
    const window: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    if (window.stateAs(interfaces.Window.State) == null) return null;
    return interfaces.Window.get_document(window) catch null;
}

/// HTML "Location-object navigate" this Location's navigable to `url`
/// (serialized), with `behavior`. Steps 1-2 and 4 are the navigable's
/// engine's (the navigate callback); step 3 is too, since it reads the
/// navigable's own record of its document.
///
/// Step 1: "Let navigable be location's relevant global object's navigable."
/// A Location whose Window no navigable shows has no navigate callback (every
/// navigable gives its Window's Location one: HTMLIFrameElement's
/// giveLocationNavigateCallback), and there is nothing to navigate. (Lane
/// life1 removed this file's own copy of "navigate" for that case - a path no
/// browser has.)
fn locationObjectNavigate(internal: *InternalState, url: []const u8, behavior: navigate_steps.HistoryBehavior) !void {
    // Step 2: "Let sourceDocument be the incumbent global object's associated
    // Document" - whose URL the request's referrer is
    // (multiple-globals/context-for-location*).
    const source = incumbentDocument();
    const callback = internal.navigate_callback orelse return;
    if (!callback(internal.navigate_context, url, .{ .history_behavior = behavior, .source_document = if (source) |d| @ptrCast(d) else null })) {
        return error.SecurityError;
    }
}

// =============================================================================
// Navigation Methods
// =============================================================================

/// Operation: assign
/// HTML §7.2.4: "1. If this's relevant Document is null, then return. ...
/// 3. Let urlRecord be the result of encoding-parsing a URL given url,
/// relative to the entry settings object. 4. If urlRecord is failure, then
/// throw a "SyntaxError" DOMException. 5. Location-object navigate this to
/// urlRecord."
pub fn call_assign(instance: *runtime.Instance, url: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (relevantDocument(internal) == null) return;
    try checkSameOriginDomain(internal);
    const resolved = try parseRelativeToEntry(instance, internal, url);
    defer internal.allocator.free(resolved);
    return locationObjectNavigate(internal, resolved, .auto);
}

/// Operation: replace
/// HTML §7.2.4: as assign(), with no security check, and Location-object
/// navigate given "replace".
pub fn call_replace(instance: *runtime.Instance, url: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (relevantDocument(internal) == null) return;
    const resolved = try parseRelativeToEntry(instance, internal, url);
    defer internal.allocator.free(resolved);
    return locationObjectNavigate(internal, resolved, .replace);
}

/// Operation: reload
/// HTML §7.2.4: "1. Let document be this's relevant Document. 2. If
/// document is null, then return. 3. If document's origin is not same
/// origin-domain with the entry settings object's origin, then throw a
/// "SecurityError" DOMException. 4. Reload document's node navigable."
pub fn call_reload(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Steps 1-2.
    if (relevantDocument(internal) == null) return;
    const window = internal.window orelse return;
    // Step 3.
    try checkSameOriginDomain(internal);
    // Step 4: "reload" - the reload navigate event, then the reload history
    // step, both History's (dom.history_traversal). A window that has not
    // made its History yet makes it, which installs the hook.
    if (!dom.history_traversal.isInstalled()) _ = interfaces.Window.get_history(window) catch {};
    dom.history_traversal.reload(window);
}
