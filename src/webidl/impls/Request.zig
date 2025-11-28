//! Implementation for Request interface
//!
//! Wraps Fetch internal InternalRequest to provide WebIDL interface.
//! Spec: https://fetch.spec.whatwg.org/#request-class
//!
//! NOTE: This is Option A (minimal but compiling) - constructors/body methods are stubbed.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");

// Import Fetch internal structures
const fetch = @import("fetch");
const InternalRequest = fetch.internal.InternalRequest;

const Request = interfaces.Request;

pub const State = Request.State;

pub const ImplError = error{
    OutOfMemory,
    TypeError,
    InvalidState,
};

/// Internal state wraps Fetch InternalRequest
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    request: *InternalRequest,
};

/// Initialize instance
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Create internal state
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    // Create internal request with default URL
    const request = try InternalRequest.init(allocator, "");
    errdefer request.deinit();

    internal.* = .{
        .allocator = allocator,
        .request = request,
    };

    // Store in instance
    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        const allocator = internal.allocator;
        internal.request.deinit();
        allocator.destroy(internal);
    }
    runtime.Instance.deinit(instance);
}

/// Constructor - STUB: Does not parse input/init properly (Option A)
pub fn call_constructor(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    input: typedefs.RequestInfo,
    init_data: dictionaries.RequestInit,
) !*runtime.Instance {
    const instance = try init(allocator, State, &Request.vtable, ctx);
    errdefer deinit(instance);

    // TODO (Option B): Parse input (URL string or Request object)
    // TODO (Option B): Parse all init_data fields (method, headers, body, mode, etc.)
    _ = input;
    _ = init_data;

    return instance;
}

// === Property Getters ===

/// Get method
pub fn get_method(instance: *runtime.Instance) ImplError![]const u8 {
    const state = instance.getState(State);
    const internal = state.own._internal.?;
    return internal.request.method;
}

/// Get URL
pub fn get_url(instance: *runtime.Instance) ImplError![]const u8 {
    const state = instance.getState(State);
    const internal = state.own._internal.?;
    // Use accessor method - returns first URL in url_list
    return internal.request.getUrl();
}

/// Get headers - STUB: Returns field without caching (Option A)
pub fn get_headers(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    // TODO (Option B): Create and cache Headers instance wrapping internal.request.header_list
    return state.own.headers;
}

/// Get destination
pub fn get_destination(instance: *runtime.Instance) ImplError!enums.RequestDestination {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Map internal destination to WebIDL enum
    return switch (internal.request.destination) {
        .empty => .__,
        .audio => ._audio_,
        .audioworklet => ._audioworklet_,
        .document => ._document_,
        .embed => ._embed_,
        .font => ._font_,
        .frame => ._frame_,
        .iframe => ._iframe_,
        .image => ._image_,
        .json => ._json_,
        .manifest => ._manifest_,
        .object => ._object_,
        .paintworklet => ._paintworklet_,
        .report => ._report_,
        .script => ._script_,
        .serviceworker => ._script_, // serviceworker not in WebIDL enum
        .sharedworker => ._sharedworker_,
        .style => ._style_,
        .track => ._track_,
        .video => ._video_,
        .webidentity => .__, // webidentity not in WebIDL enum
        .worker => ._worker_,
        .xslt => ._xslt_,
    };
}

/// Get referrer
pub fn get_referrer(instance: *runtime.Instance) ImplError![]const u8 {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return switch (internal.request.referrer) {
        .no_referrer => "",
        .client => "about:client",
        .url => |url| url,
    };
}

/// Get referrerPolicy
pub fn get_referrerPolicy(instance: *runtime.Instance) ImplError!enums.ReferrerPolicy {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return switch (internal.request.referrer_policy) {
        .empty => .__,
        .no_referrer => ._no_referrer_,
        .no_referrer_when_downgrade => ._no_referrer_when_downgrade_,
        .same_origin => ._same_origin_,
        .origin => ._origin_,
        .strict_origin => ._strict_origin_,
        .origin_when_cross_origin => ._origin_when_cross_origin_,
        .strict_origin_when_cross_origin => ._strict_origin_when_cross_origin_,
        .unsafe_url => ._unsafe_url_,
    };
}

/// Get mode
pub fn get_mode(instance: *runtime.Instance) ImplError!enums.RequestMode {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return switch (internal.request.mode) {
        .same_origin => ._same_origin_,
        .cors => ._cors_,
        .no_cors => ._no_cors_,
        .navigate => ._navigate_,
        .websocket => ._navigate_, // websocket not in WebIDL enum, use navigate
    };
}

/// Get credentials
pub fn get_credentials(instance: *runtime.Instance) ImplError!enums.RequestCredentials {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return switch (internal.request.credentials_mode) {
        .omit => ._omit_,
        .same_origin => ._same_origin_,
        .include => ._include_,
    };
}

/// Get cache
pub fn get_cache(instance: *runtime.Instance) ImplError!enums.RequestCache {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return switch (internal.request.cache_mode) {
        .default => ._default_,
        .no_store => ._no_store_,
        .reload => ._reload_,
        .no_cache => ._no_cache_,
        .force_cache => ._force_cache_,
        .only_if_cached => ._only_if_cached_,
    };
}

/// Get redirect
pub fn get_redirect(instance: *runtime.Instance) ImplError!enums.RequestRedirect {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return switch (internal.request.redirect_mode) {
        .follow => ._follow_,
        .@"error" => ._error_,
        .manual => ._manual_,
    };
}

/// Get integrity
pub fn get_integrity(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // integrity_metadata is []const u8, convert to DOMString
    if (internal.request.integrity_metadata.len == 0) {
        return runtime.DOMString.initEmpty();
    }
    return runtime.DOMString.initInterned(internal.request.integrity_metadata);
}

/// Get keepalive
pub fn get_keepalive(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return internal.request.keepalive;
}

/// Get isReloadNavigation
pub fn get_isReloadNavigation(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return internal.request.reload_navigation;
}

/// Get isHistoryNavigation
pub fn get_isHistoryNavigation(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return internal.request.history_navigation;
}

/// Get signal - Return from state field
pub fn get_signal(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    return state.own.signal;
}

/// Get duplex
pub fn get_duplex(instance: *runtime.Instance) ImplError!enums.RequestDuplex {
    _ = instance;
    // TODO (Option B): Track duplex mode in InternalRequest
    return ._half_;
}

/// Get targetAddressSpace
pub fn get_targetAddressSpace(instance: *runtime.Instance) ImplError!enums.IPAddressSpace {
    _ = instance;
    // TODO (Option B): Implement target address space from InternalRequest
    return ._public_; // Default to public
}

// === Body Mixin Properties ===

/// Get body
pub fn get_body(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    const state = instance.getState(State);
    return state.own.body;
}

/// Get bodyUsed
pub fn get_bodyUsed(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    return state.own.bodyUsed;
}

// === Methods - STUBS (Option A) ===

/// clone() - STUB
pub fn call_clone(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    // TODO (Option B): Clone InternalRequest, tee body stream
    return error.InvalidState;
}

/// arrayBuffer() - STUB
pub fn call_arrayBuffer(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    // TODO (Option B): Delegate to Body mixin
    return error.InvalidState;
}

/// blob() - STUB
pub fn call_blob(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    // TODO (Option B): Delegate to Body mixin
    return error.InvalidState;
}

/// bytes() - STUB
pub fn call_bytes(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    // TODO (Option B): Delegate to Body mixin
    return error.InvalidState;
}

/// formData() - STUB
pub fn call_formData(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    // TODO (Option B): Delegate to Body mixin
    return error.InvalidState;
}

/// json() - STUB
pub fn call_json(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    // TODO (Option B): Delegate to Body mixin
    return error.InvalidState;
}

/// text() - STUB
pub fn call_text(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    // TODO (Option B): Delegate to Body mixin
    return error.InvalidState;
}
