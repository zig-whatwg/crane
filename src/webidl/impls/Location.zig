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
pub const NavigateRequest = html_core.window.iframe_integration.NavigateRequest;

/// Navigation callback type for Location.assign/replace/href setter.
/// Parameters: (context_ptr, url, request) -> whether a navigable took it.
/// The context_ptr is an opaque pointer to implementation-specific data
/// (e.g., IFrameIntegration* for iframe contexts). The engine behind it runs
/// "Location-object navigate" step 3 - a relevant document that is not
/// completely loaded makes the navigation a replace - and step 4, "navigate".
pub const NavigateCallback = *const fn (ctx: ?*anyopaque, url: []const u8, request: NavigateRequest) bool;

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

    /// Cached ancestor origins (lazily created DOMStringList)
    ancestor_origins: ?*runtime.Instance = null,

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
/// otherwise." The record parsed at construction (about:blank) is the
/// fallback for a Location with no window yet; with a window, the document's
/// URL wins - it is what navigation set, and `history.pushState` changes it.
fn getURL(instance: *runtime.Instance) ?*url_record.URLRecord {
    const internal = getInternal(instance) orelse return null;
    refreshFromDocument(internal);
    return internal.url;
}

/// HTML §7.2.4, the step the Location members begin with: "If this's
/// relevant Document is non-null and its origin is not same origin-domain
/// with the entry settings object's origin, then throw a "SecurityError"
/// DOMException." A Location has a relevant Document while it has a window
/// (whose browsing context's active document it is).
fn checkSameOriginDomain(internal: *InternalState) !void {
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
    const window = internal.window orelse return;
    const document = interfaces.Window.get_document(window) catch return;
    // The interface getter clones into the DOCUMENT's context allocator, so
    // that is what frees it (AGENTS.md, "Interface getters clone").
    const doc_url = interfaces.Document.get_URL(document) catch return;
    defer document.ctx.allocator.free(doc_url);
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
    // The hyperlinks and forms that choose the top-level page navigate it
    // here.
    @import("dom").top_level_navigation.install(.{ .navigate = &topLevelNavigateHook });
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

    // Initialize internal state. The Window is the relevant global object -
    // the realm record's, when the realm is a Window's (a Location made after
    // its Window, as Window.get_location makes one); setWindow says it
    // otherwise.
    const internal = try allocator.create(InternalState);
    internal.* = .{
        .allocator = allocator,
        .window = relevantWindow(ctx),
    };

    // Initialize with default URL (about:blank)
    // Per spec, Location's URL should be the document's URL
    // For WPT tests, we initialize to a default URL that can be updated later
    const parsed_url = try allocator.create(url_record.URLRecord);
    parsed_url.* = try basic_parser.parse(allocator, "about:blank", null);
    internal.url = parsed_url;

    // Store internal state in the instance
    const state = instance.getState(StateType);
    state.own._internal = internal;

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
pub fn setURLFromString(instance: *runtime.Instance, url_string: []const u8) !void {
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

/// Get internal state (exposed for Window impl to set URL)
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return getInternal(instance);
}

/// Set the associated Window for this Location.
/// Called by Window/context initialization to establish the bi-directional link.
/// This enables Location.assign() to access the browsing context for navigation.
pub fn setWindow(instance: *runtime.Instance, window: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    internal.window = window;
}

/// Set the navigation callback for this Location.
/// Called by iframe setup to enable programmatic navigation via location.href/assign/replace.
/// Parameters:
/// - callback: Function to call for navigation, or null to disable
/// - context: Opaque pointer passed to callback (e.g., IFrameIntegration*)
pub fn setNavigateCallback(
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

    // Return "#" + fragment
    const result = try allocator.alloc(u8, fragment.len + 1);
    result[0] = '#';
    @memcpy(result[1..], fragment);

    return result;
}

/// Getter for ancestorOrigins
/// Per spec §7.1.3: Returns a DOMStringList of ancestor browsing context origins.
pub fn get_ancestorOrigins(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // Step 2: the same-origin-domain check (step 1, the empty list for a
    // null relevant Document, is part of what is not implemented below).
    try checkGetter(instance);
    // TODO: Implement DOMStringList creation
    // This requires:
    // 1. Walking up the browsing context tree
    // 2. Collecting origins from each ancestor
    // 3. Creating a DOMStringList with those origins
    return error.NotImplemented;
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
    if (internal.window == null) return;
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
    if (internal.window == null) return;
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
    if (internal.window == null) return;
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
    if (internal.window == null) return;
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
    if (internal.window == null) return;
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
/// state as state override; Location-object navigate to it. The fragment is
/// kept. Deviation, stated (encoding-parse-utf8): the query is
/// percent-encoded as UTF-8, not in the relevant document's encoding -
/// queued.
pub fn set_search(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.window == null) return;
    try checkSameOriginDomain(internal);
    const url = getURL(instance) orelse return;
    const allocator = internal.allocator;
    const current = try url_serializer.serialize(allocator, url, false);
    defer allocator.free(current);
    const without_fragment = navigate_steps.withoutFragment(current);
    const query_start = std.mem.indexOfScalar(u8, without_fragment, '?') orelse without_fragment.len;
    const input = if (value.len > 0 and value[0] == '?') value[1..] else value;
    const fragment = navigate_steps.fragmentOf(current);
    const candidate = try std.fmt.allocPrint(allocator, "{s}{s}{s}{s}{s}", .{
        without_fragment[0..query_start],
        if (value.len == 0) "" else "?",
        if (value.len == 0) "" else input,
        if (fragment != null) "#" else "",
        fragment orelse "",
    });
    defer allocator.free(candidate);
    const copy_url = try reparse(allocator, candidate);
    defer allocator.free(copy_url);
    return locationObjectNavigate(internal, copy_url, .auto);
}

/// Setter for hash
/// HTML §7.2.4, the hash setter steps.
pub fn set_hash(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Step 1: "If this's relevant Document is null, then return."
    if (internal.window == null) return;
    // Step 2: the same-origin-domain check.
    try checkSameOriginDomain(internal);
    // Step 3: "Let copyURL be a copy of this's url."
    const url = getURL(instance) orelse return;
    const allocator = internal.allocator;
    const current = try url_serializer.serialize(allocator, url, false);
    defer allocator.free(current);
    // Step 4: "Let thisURLFragment be copyURL's fragment if it is non-null;
    // otherwise the empty string."
    const this_fragment = navigate_steps.fragmentOf(current) orelse "";
    // Step 5: "Let input be the given value with a single leading "#"
    // removed, if any."
    const input = if (value.len > 0 and value[0] == '#') value[1..] else value;
    // Steps 6-7: set copyURL's fragment to the empty string and basic URL
    // parse input with the fragment state as state override - the same as
    // parsing copyURL with "#" and input appended.
    const candidate = try std.fmt.allocPrint(allocator, "{s}#{s}", .{ navigate_steps.withoutFragment(current), input });
    defer allocator.free(candidate);
    const copy_url = try reparse(allocator, candidate);
    defer allocator.free(copy_url);
    // Step 8: "If copyURL's fragment is thisURLFragment, then return."
    if (std.mem.eql(u8, navigate_steps.fragmentOf(copy_url) orelse "", this_fragment)) return;
    // Step 9: "Location-object navigate this to copyURL."
    return locationObjectNavigate(internal, copy_url, .auto);
}

/// HTML "navigate" for the top-level page, whose Location has no navigable
/// engine behind it: `window`'s navigable, to `url` (serialized, absolute).
/// This engine cannot replace the page's document, so what it runs is:
/// history handling (steps 12-13), a fragment navigation (step 14, "navigate
/// to a fragment"), and the navigate event before anything else (step 21) -
/// a navigation it lets through that would make a new document ends there,
/// error.NotImplemented.
///
/// Not modelled, stated: source snapshot params and sandboxing (1-7), the
/// ongoing navigation (19). A javascript: URL (20) runs in a task, and its
/// String result - a new document - is dropped.
fn topLevelNavigate(window: *runtime.Instance, url: []const u8, params: dom.top_level_navigation.Params) !void {
    const document = interfaces.Window.get_document(window) catch return;
    // Step 9: "If navigable's active document's unload counter is greater
    // than 0 ... return."
    if (dom.document_lifecycle.isUnloading(document)) return;
    // Step 12: "If navigable's allowed to perform a navigation or history
    // update returns blocked, then ... return."
    if (html_core.window.BrowsingContext.ofWindow(@ptrCast(window))) |navigable| {
        if (!navigable.allowedToNavigateOrUpdateHistory()) return;
    }
    const allocator = window.ctx.allocator;
    const document_url = interfaces.Document.get_URL(document) catch return;
    defer document.ctx.allocator.free(document_url);
    // Steps 12-13: history handling.
    const handling = navigate_steps.resolveHistoryHandling(switch (params.history_behavior) {
        .auto => .auto,
        .push => .push,
        .replace => .replace,
    }, url, .{
        .url = document_url,
        .is_initial_about_blank = dom.document_lifecycle.isInitialAboutBlank(document),
    }, sameOriginSource(params.source_document, document_url, allocator));

    // Step 14: a fragment navigation - never one with a document resource,
    // a form's POST resource.
    if (navigate_steps.isFragmentNavigation(url, document_url, params.form_data != null)) {
        return topLevelFragmentNavigation(window, url, document_url, handling, params);
    }
    // Step 20: "If url's scheme is "javascript", then queue a global task on
    // the navigation and traversal task source given navigable's active
    // window to navigate to a javascript: URL", and return.
    if (navigate_steps.isJavascript(url)) return queueJavascriptNavigation(window, url, params.source_document, params.csp_navigation_type);
    // Step 21: the navigate event, for a navigation from a same-origin
    // source to a fetch scheme, when the active document is not the initial
    // about:blank.
    if (sameOriginSource(params.source_document, document_url, allocator) and
        !dom.document_lifecycle.isInitialAboutBlank(document) and
        navigate_steps.isFetchScheme(url))
    {
        const continue_navigation = dom.navigation_api.firePushReplaceReload(window, .{
            .navigation_type = if (handling == .push) .push else .replace,
            .destination_url = url,
            .is_same_document = false,
            .user_involvement = params.user_involvement,
            .source_element = params.source_element,
            .navigation_api_state = params.navigation_api_state orelse .undefined,
            // Step 20's entryListForFiring.
            .form_data = params.form_data,
        });
        // Canceled, or intercepted - which made it same-document.
        if (!continue_navigation) return;
    }
    // A document that is not itself a file: document navigating to a file:
    // URL goes nowhere - all three browsers refuse to load local resources
    // for web content, and the navigation API sees the navigation aborted
    // (navigation-methods/return-value/navigate-file-url.html). Fetch leaves
    // file: URLs to the user agent.
    if (std.mem.eql(u8, navigate_steps.schemeOf(url), "file") and !std.mem.eql(u8, navigate_steps.schemeOf(document_url), "file")) {
        dom.navigation_api.informAboutAbortingNavigation(window);
        return;
    }
    // A new document for the top-level page: not this engine's to make.
    return error.NotImplemented;
}

/// HTML "navigate to a javascript: URL" for the top-level page, queued by
/// "navigate" step 20: what it needs when it runs - the URL, the initiator
/// origin snapshot (the source document's origin, serialized), the
/// initiator policy container (a clone of the source document's, taken now:
/// step 4's request carries it), and the source window - the request's
/// client, whose default policy the pre-navigation check runs.
const JavascriptNavigation = struct {
    allocator: Allocator,
    window: *runtime.Instance,
    generation: u64,
    url: []u8,
    initiator_origin: ?[]u8,
    initiator_policy_container: ?dom.policy_containers.PolicyContainer = null,
    source_window: ?*runtime.Instance = null,
    source_generation: u64 = 0,
    /// "Navigate"'s cspNavigationType, which step 5 asks CSP 4.2.4 with.
    csp_navigation_type: @import("csp").navigation_check.NavigationType = .other,

    fn destroy(self: *JavascriptNavigation) void {
        self.allocator.free(self.url);
        if (self.initiator_origin) |o| self.allocator.free(o);
        if (self.initiator_policy_container) |*container| container.deinit();
        self.allocator.destroy(self);
    }

    /// The source window, while it is still the one recorded and its realm
    /// runs.
    fn liveSourceWindow(self: *const JavascriptNavigation) ?*runtime.Instance {
        const source = self.source_window orelse return null;
        if (runtime.SlabAllocator.generationOf(source) != self.source_generation) return null;
        if (!source.ctx.hasEngine()) return null;
        return source;
    }

    fn run(context: ?*anyopaque) void {
        const self: *JavascriptNavigation = @ptrCast(@alignCast(context.?));
        defer self.destroy();
        if (runtime.SlabAllocator.generationOf(self.window) != self.generation) return;
        if (!self.window.ctx.hasEngine()) return;
        engine.runTaskInRealm(self.window.ctx, steps, self) catch |err| log.debug("javascript: URL not run: {s}", .{@errorName(err)});
    }

    fn drop(context: ?*anyopaque) void {
        const self: *JavascriptNavigation = @ptrCast(@alignCast(context.?));
        self.destroy();
    }

    fn steps(data: ?*anyopaque) void {
        const self: *JavascriptNavigation = @ptrCast(@alignCast(data.?));
        navigateToJavascriptUrl(self);
    }
};

fn queueJavascriptNavigation(window: *runtime.Instance, url: []const u8, source: ?*runtime.Instance, csp_navigation_type: @import("csp").navigation_check.NavigationType) !void {
    const allocator = window.ctx.allocator;
    const task = try allocator.create(JavascriptNavigation);
    errdefer allocator.destroy(task);
    const owned_url = try allocator.dupe(u8, url);
    errdefer allocator.free(owned_url);
    // Navigate step 4's initiatorOriginSnapshot: the source document's
    // origin, the page's own when there is none.
    const source_window: ?*runtime.Instance = if (source) |doc| (interfaces.Document.get_defaultView(doc) catch null) else window;
    const initiator: ?[]u8 = if (source_window) |w| blk: {
        const serialized = interfaces.Window.get_origin(w) catch break :blk null;
        defer w.ctx.allocator.free(serialized);
        break :blk try allocator.dupe(u8, serialized);
    } else null;
    // Navigate step 4's source snapshot params' source policy container: a
    // clone of the source document's (the page's own with no source), which
    // "navigate to a javascript: URL" step 4's request carries.
    const container_document: ?*runtime.Instance = source orelse (interfaces.Window.get_document(window) catch null);
    var initiator_container: ?dom.policy_containers.PolicyContainer = null;
    if (container_document) |doc| {
        if (dom.policy_containers.of(doc)) |container| initiator_container = try container.clone(allocator);
    }
    errdefer if (initiator_container) |*container| container.deinit();
    task.* = .{
        .allocator = allocator,
        .window = window,
        .generation = runtime.SlabAllocator.generationOf(window),
        .url = owned_url,
        .initiator_origin = initiator,
        .initiator_policy_container = initiator_container,
        .source_window = source_window,
        .source_generation = if (source_window) |w| runtime.SlabAllocator.generationOf(w) else 0,
        .csp_navigation_type = csp_navigation_type,
    };
    const loop = window.ctx.getOptionalEventLoop() orelse return JavascriptNavigation.run(task);
    loop.queueTask(.{ .callback = JavascriptNavigation.run, .context = task, .drop = JavascriptNavigation.drop });
}

/// "Navigate to a javascript: URL", in the page's realm. Not modelled,
/// stated: step 2 (the page's navigable keeps no ongoing navigation); and
/// steps 8-17 - a String result would be the page's new document, which
/// this engine cannot make for the top-level page: the result is dropped.
fn navigateToJavascriptUrl(task: *JavascriptNavigation) void {
    const window = task.window;
    // Step 3: "If initiatorOrigin is not same origin-domain with
    // targetNavigable's active document's origin, then return."
    const initiator = task.initiator_origin orelse return;
    const target = interfaces.Window.get_origin(window) catch return;
    defer window.ctx.allocator.free(target);
    if (std.mem.eql(u8, initiator, "null") or !std.mem.eql(u8, initiator, target)) return;
    // Steps 4-5: "Let request be a new request whose URL is url and whose
    // policy container is initiatorPolicyContainer. If the result of should
    // navigation request of type be blocked by Content Security Policy?
    // given request and cspNavigationType is "Blocked", then return." The
    // request's client is the source window, where violations go: a source
    // window that is gone has no default policy, so a javascript: URL under
    // enforced Trusted Types is then Blocked.
    var url: []const u8 = task.url;
    var rewritten: ?[]u8 = null;
    defer if (rewritten) |u| task.allocator.free(u);
    if (task.initiator_policy_container) |*container| {
        const check = dom.csp_violations.shouldJavascriptNavigationBeBlocked(task.allocator, &container.csp_list, task.liveSourceWindow(), null, task.url, task.csp_navigation_type, &isValidUrl) catch return;
        switch (check) {
            .allowed => {},
            .rewritten => |u| {
                rewritten = u;
                url = u;
            },
            .blocked => return,
        }
    }
    // Not in the spec, stated (whatwg/html#4651;
    // dom.csp_violations.shouldTargetBlockJavascriptUrl): Chrome and Firefox
    // check the target's CSP too, after the initiator's, and WPT's
    // to-javascript-parent-initiated-child-csp.html asserts it - skipped when
    // the page is the initiator, whose list step 5 just checked.
    if (task.liveSourceWindow() != window and dom.csp_violations.shouldTargetBlockJavascriptUrl(window, url)) return;
    // Step 6: "Let newDocument be the result of evaluating a javascript: URL".
    const result = evaluateJavascriptUrl(window, url, task.allocator) orelse return;
    task.allocator.free(result);
    log.debug("a javascript: URL's String result would replace the top-level page; it cannot be", .{});
}

/// Whether the URL parser parses `url` (the pre-navigation check's step 6).
fn isValidUrl(allocator: Allocator, url: []const u8) bool {
    var parsed = basic_parser.parse(allocator, url, null) catch return false;
    parsed.deinit();
    return true;
}

/// HTML "evaluate a javascript: URL" in `window`'s realm: the script's
/// String completion value (owned by `allocator`), or null - for any other
/// value, and for a script that throws, which is reported.
fn evaluateJavascriptUrl(window: *runtime.Instance, url: []const u8, allocator: Allocator) ?[]u8 {
    const realm = window.ctx;
    // Steps 1-3: "Let encodedScriptSource be the result of removing the
    // leading "javascript:" from urlString"; "let scriptSource be the UTF-8
    // decoding of the percent-decoding of encodedScriptSource".
    const source = @import("percent_encoding").percentDecode(allocator, url["javascript:".len..]) catch return null;
    defer allocator.free(source);
    // Steps 4-8: create a classic script and run it.
    const completion = engine.evaluateClassicScript(realm, .{ .utf8 = source }, "", null, .{ .report = reportJavascriptUrlException, .host = realm }) catch return null;
    defer completion.release();
    // Step 9: only a String is a result.
    if (engine.typeOf(realm, completion.value) != .string) return null;
    return engine.convertToDOMString(realm, completion.value, allocator) catch null;
}

/// What a javascript: URL's script throws is reported at its window.
fn reportJavascriptUrlException(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
    const fallback: runtime.Context = @ptrCast(@alignCast(host orelse return));
    const realm = info.realm orelse fallback;
    const record = realm.getRealm() orelse return;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return));
    const extracted: runtime.ErrorInfo = .{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = if (info.error_value == .undefined) null else info.error_value,
    };
    _ = @import("html").report_exception.reportErrorInfo(global, &extracted, .{});
}

/// dom.top_level_navigation: the page's hyperlinks and forms.
fn topLevelNavigateHook(window: *runtime.Instance, url: []const u8, params: dom.top_level_navigation.Params) void {
    topLevelNavigate(window, url, params) catch |err| {
        log.debug("the top-level page cannot navigate to {s}: {s}", .{ url, @errorName(err) });
    };
}

/// Whether `source` - navigate's sourceDocument - is same origin with the
/// active document at `document_url` (step 12.1, step 21). By URL, as the
/// navigable containers compare it; no source is the page itself.
fn sameOriginSource(source: ?*runtime.Instance, document_url: []const u8, allocator: Allocator) bool {
    const doc = source orelse return true;
    const source_url = interfaces.Document.get_URL(doc) catch return true;
    defer doc.ctx.allocator.free(source_url);
    _ = allocator;
    return std.mem.eql(u8, originPrefix(source_url), originPrefix(document_url));
}

/// "scheme://host[:port]" of a serialized URL, or the whole URL for one
/// without an authority (whose origin is opaque or inherited: compared as is).
fn originPrefix(url: []const u8) []const u8 {
    const scheme = navigate_steps.schemeOf(url);
    if (!std.mem.startsWith(u8, url[scheme.len..], "://")) return url;
    const end = std.mem.indexOfAnyPos(u8, url, scheme.len + 3, "/?#") orelse url.len;
    return url[0..end];
}

/// HTML "navigate to a fragment" (§7.4.2.3.3) for the top-level page: the
/// navigate event first; then the document's URL changes now, the new entry
/// is pushed or replaced, the navigation API's entries follow, and
/// hashchange is queued if the fragment changed. Scrolling is not modelled
/// (no layout), stated.
fn topLevelFragmentNavigation(
    window: *runtime.Instance,
    url: []const u8,
    old_url: []const u8,
    handling: navigate_steps.HistoryHandling,
    params: dom.top_level_navigation.Params,
) !void {
    const allocator = window.ctx.allocator;
    const bc = html_core.window.BrowsingContext.ofWindow(@ptrCast(window));
    // Steps 2-3: "Let destinationNavigationAPIState be navigable's active
    // session history entry's navigation API state. If navigationAPIState is
    // not null, then set destinationNavigationAPIState to navigationAPIState."
    var destination_state: joint_history.SerializedState = .undefined;
    defer destination_state.deinit(allocator);
    if (params.navigation_api_state) |state| {
        destination_state = try state.clone(allocator);
    } else if (bc) |b| {
        if (b.ensureHistoryEntries(&@import("history_documents.zig").infoOf)) |history| {
            if (history.currentEntry(b.id)) |entry| destination_state = try entry.api_state.clone(allocator);
        } else |_| {}
    }
    // Steps 4-5: "Let continue be the result of firing a push/replace/reload
    // navigate event ... If continue is false, then return."
    if (!dom.navigation_api.firePushReplaceReload(window, .{
        .navigation_type = if (handling == .push) .push else .replace,
        .destination_url = url,
        .is_same_document = true,
        .user_involvement = params.user_involvement,
        .source_element = params.source_element,
        .navigation_api_state = destination_state,
    })) return;

    // Steps 6-13 and 17: the new entry on the same document, pushed or
    // replacing the current one in the traversable's history, with the
    // destination's navigation API state and a null classic history API
    // state.
    if (html_core.window.BrowsingContext.ofWindow(@ptrCast(window))) |b| {
        if (b.ensureHistoryEntries(&@import("history_documents.zig").infoOf)) |history| {
            const api_state = destination_state.clone(allocator) catch null;
            history.commitSameDocument(b.id, url, .null, if (handling == .push) .push else .replace, api_state) catch {};
        } else |_| {}
    }

    // Step 12: "Set navigable's active document's URL to url." A document
    // with a window reads its URL from its realm's record.
    try window.ctx.setDocumentUrl(url);

    // Step 15, "update document for history step application" 6.4.2:
    // "Update the navigation API entries for a same-document navigation
    // given navigation, historyEntry, and historyHandling."
    if (html_core.window.BrowsingContext.ofWindow(@ptrCast(window)) != null) {
        dom.navigation_api.sameDocumentNavigation(window, if (handling == .push) .push else .replace);
    }

    // 6.4.3: "Fire an event named popstate at document's relevant global
    // object, using PopStateEvent, with the state attribute initialized to
    // document's history object's state" - null: 6.3 restored it from the
    // new entry, whose classic history API state is never carried over.
    firePopStateNull(window);

    // 6.4.5: hashchange, if the fragment changed.
    const old_fragment = navigate_steps.fragmentOf(old_url);
    const new_fragment = navigate_steps.fragmentOf(url);
    const same = if (old_fragment) |a| (if (new_fragment) |b| std.mem.eql(u8, a, b) else false) else new_fragment == null;
    if (!same) queueHashChange(allocator, window, old_url, url);
}

/// "Update document for history step application" step 6.4.3 for a
/// fragment navigation's entry: popstate at `window`, its state null.
fn firePopStateNull(window: *runtime.Instance) void {
    const event = interfaces.PopStateEvent.call_constructor(
        window.ctx,
        runtime.DOMString.initInterned("popstate"),
        webidl.Opt(dictionaries.PopStateEventInit).passed(.{ .base = .{}, .state = runtime.JSValue.jsNull }),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = dom.fire_event.dispatchTrusted(window, event) catch {};
    event.releaseIfUnwrapped(generation);
}

/// BrowsingContext.ensureHistoryEntries's `url_of`.
/// A queued hashchange at a window, held with its slab generation.
const HashChange = struct {
    window: *runtime.Instance,
    generation: u64,
    old_url: []u8,
    new_url: []u8,
    allocator: Allocator,

    fn destroy(self: *HashChange) void {
        self.allocator.free(self.old_url);
        self.allocator.free(self.new_url);
        self.allocator.destroy(self);
    }
};

/// "Queue a global task on the DOM manipulation task source given
/// document's relevant global object to fire an event named hashchange".
fn queueHashChange(allocator: Allocator, window: *runtime.Instance, old_url: []const u8, new_url: []const u8) void {
    const task = allocator.create(HashChange) catch return;
    const old_copy = allocator.dupe(u8, old_url) catch {
        allocator.destroy(task);
        return;
    };
    const new_copy = allocator.dupe(u8, new_url) catch {
        allocator.free(old_copy);
        allocator.destroy(task);
        return;
    };
    task.* = .{
        .window = window,
        .generation = runtime.SlabAllocator.generationOf(window),
        .old_url = old_copy,
        .new_url = new_copy,
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
    engine.runTaskInRealm(task.window.ctx, fireHashChange, task) catch |err| {
        log.debug("hashchange not fired: {}", .{err});
    };
}

/// Fire "hashchange" at the task's window, in its realm.
fn fireHashChange(data: ?*anyopaque) void {
    const task: *HashChange = @ptrCast(@alignCast(data orelse return));
    const event = interfaces.HashChangeEvent.call_constructor(
        task.window.ctx,
        runtime.DOMString.initInterned("hashchange"),
        webidl.Opt(dictionaries.HashChangeEventInit).passed(.{ .base = .{}, .oldURL = task.old_url, .newURL = task.new_url }),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = @import("dom").fire_event.dispatchTrusted(task.window, event) catch {};
    event.releaseIfUnwrapped(generation);
}

/// `url` through the basic URL parser and serializer; owned.
fn reparse(allocator: Allocator, url: []const u8) ![]u8 {
    var parsed = basic_parser.parse(allocator, url, null) catch return error.SyntaxError;
    defer parsed.deinit();
    return @constCast(try url_serializer.serialize(allocator, &parsed, false));
}

/// `url` encoding-parsed relative to the entry settings object - the
/// document of the script that is running - and serialized; owned. Failure
/// is a "SyntaxError". With no script running, the Location's own URL is the
/// base.
/// Deviation, stated (encoding-parse-utf8): the query is encoded as UTF-8, not with the document's encoding - queued.
fn parseRelativeToEntry(instance: *runtime.Instance, internal: *InternalState, url: []const u8) ![]u8 {
    const allocator = internal.allocator;
    if (entryDocument()) |document| {
        const base = interfaces.Node.get_baseURI(document) catch "";
        defer if (base.len > 0) document.ctx.allocator.free(base);
        if (base.len > 0) {
            var base_record = basic_parser.parse(allocator, base, null) catch null;
            defer if (base_record) |*b| b.deinit();
            if (base_record) |*b| {
                var parsed = basic_parser.parse(allocator, url, b) catch return error.SyntaxError;
                defer parsed.deinit();
                return @constCast(try url_serializer.serialize(allocator, &parsed, false));
            }
        }
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
fn locationObjectNavigate(internal: *InternalState, url: []const u8, behavior: navigate_steps.HistoryBehavior) !void {
    // Step 2: "Let sourceDocument be the incumbent global object's associated
    // Document" - whose URL the request's referrer is
    // (multiple-globals/context-for-location*).
    const source = incumbentDocument();
    const callback = internal.navigate_callback orelse {
        // The top-level page, "navigate"d as far as this engine can.
        const window = internal.window orelse return;
        const document = interfaces.Window.get_document(window) catch return;
        // Step 3: "If location's relevant Document is not yet completely
        // loaded, and the incumbent global object does not have transient
        // activation, then set historyHandling to "replace"."
        const replace = !dom.document_lifecycle.isCompletelyLoaded(document) and
            !@import("html").user_activation.incumbentHasTransientActivation();
        const handling: dom.top_level_navigation.HistoryBehavior = if (replace) .replace else switch (behavior) {
            .auto => .auto,
            .push => .push,
            .replace => .replace,
        };
        return topLevelNavigate(window, url, .{ .history_behavior = handling, .source_document = source });
    };
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
    if (internal.window == null) return;
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
    if (internal.window == null) return;
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
    const window = internal.window orelse return;
    // Step 3.
    try checkSameOriginDomain(internal);
    // Step 4: "reload" - the reload navigate event, then the reload history
    // step, both History's (dom.history_traversal). A window that has not
    // made its History yet makes it, which installs the hook.
    if (!dom.history_traversal.isInstalled()) _ = interfaces.Window.get_history(window) catch {};
    dom.history_traversal.reload(window);
}
