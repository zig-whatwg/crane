//! Implementation for XMLHttpRequest interface
//!
//! WHATWG XHR Standard: https://xhr.spec.whatwg.org/
//!
//! This module connects the WebIDL interface to the XHR algorithm implementations.

const std = @import("std");
const runtime = @import("runtime");
const v8_engine = @import("v8");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const XMLHttpRequest = interfaces.XMLHttpRequest;

// XHR algorithm implementations
const xhr = @import("xhr");
const XMLHttpRequestState = xhr.XMLHttpRequestState;
const ReadyState = xhr.ReadyState;
const ResponseType = xhr.state_machine.ResponseType;

// XHR Algorithms
const open_algo = xhr.open;
const headers_algo = xhr.headers;

// Import pointer_tag for V8 pointer untagging (via v8 module)
const pointer_tag = @import("v8").pointer_tag;

pub const State = XMLHttpRequest.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    SyntaxError,
    SecurityError,
    InvalidAccessError,
    OutOfMemory,
};

/// Internal state for implementation-specific data
/// Contains the XMLHttpRequestState from the XHR module
pub const InternalState = struct {
    xhr_state: XMLHttpRequestState,
    allocator: std.mem.Allocator,

    /// Event handler stored as V8 Global handle.
    ///
    /// This MUST be a Global handle (not raw pointer) because:
    /// 1. The JavaScript callback needs to survive past the setter's HandleScope
    /// 2. Local handles become invalid when the HandleScope that created them is destroyed
    /// 3. Without Global handles, invoking the handler would crash due to dangling pointers
    ///
    /// See: src/runtime/engines/v8/global_handles.zig for Global handle management.
    onreadystatechange: v8_engine.OptionalGlobalHandle,

    /// V8 isolate for creating/disposing Global handles
    isolate: ?*v8_engine.ffi.Isolate,

    pub fn initState(allocator: std.mem.Allocator) InternalState {
        return .{
            .xhr_state = XMLHttpRequestState.init(allocator),
            .allocator = allocator,
            .onreadystatechange = null,
            .isolate = null,
        };
    }

    pub fn deinitState(self: *InternalState) void {
        // Dispose V8 Global handle to prevent memory leaks
        v8_engine.disposeOptionalGlobalHandle(&self.onreadystatechange);
        self.xhr_state.deinit();
    }
};

/// Initialize instance (creates the instance)
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

    internal.* = InternalState.initState(allocator);

    // Store in instance
    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinitState();
        internal.allocator.destroy(internal);
    }
    // NOTE: Do NOT call runtime.Instance.deinit here - GC layer handles it
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
///
/// Spec: "The new XMLHttpRequest() constructor steps are:
/// 1. Set this's upload object to a new XMLHttpRequestUpload object."
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &XMLHttpRequest.vtable, ctx);
    errdefer deinit(instance);

    // Store V8 isolate for Global handle management
    const internal = getInternal(instance);
    internal.isolate = ctx.getEngineContextAs(v8_engine.ffi.Isolate);

    // Step 1: Set upload object (TODO: when XMLHttpRequestUpload is implemented)
    // For now, the XHR state is initialized in init()

    return instance;
}

/// Helper to get XHR state from instance
fn getXHRState(instance: *runtime.Instance) *XMLHttpRequestState {
    const state = instance.getState(State);
    const internal = state.own._internal.?;
    return &internal.xhr_state;
}

/// Helper to get internal state from instance
fn getInternal(instance: *runtime.Instance) *InternalState {
    const state = instance.getState(State);
    return state.own._internal.?;
}

/// Getter for onreadystatechange
///
/// Spec: "The onreadystatechange attribute is an event handler IDL attribute."
/// Returns the event handler by retrieving a Local handle from the Global handle.
pub fn get_onreadystatechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const internal = getInternal(instance);
    const isolate = internal.isolate orelse return null;
    if (internal.onreadystatechange) |global| {
        // Use GlobalHandle's get() method to retrieve Local handle
        return @ptrCast(@alignCast(global.get(isolate)));
    }
    return null;
}

/// Getter for readyState
///
/// Spec: "The readyState getter steps are to return the value from the table..."
pub fn get_readyState(instance: *runtime.Instance) anyerror!u16 {
    const xhr_state = getXHRState(instance);
    return @intFromEnum(xhr_state.ready_state);
}

/// Getter for timeout
///
/// Spec: "The timeout getter steps are to return this's timeout."
pub fn get_timeout(instance: *runtime.Instance) anyerror!u32 {
    const xhr_state = getXHRState(instance);
    return xhr_state.timeout;
}

/// Getter for withCredentials
///
/// Spec: "The withCredentials getter steps are to return this's cross-origin credentials."
pub fn get_withCredentials(instance: *runtime.Instance) anyerror!bool {
    const xhr_state = getXHRState(instance);
    return xhr_state.cross_origin_credentials;
}

/// Getter for upload
///
/// Spec: "The upload getter steps are to return this's upload object."
/// Note: The upload object is lazily created and cached via [SameObject] in the interface.
pub fn get_upload(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance);

    // Create XMLHttpRequestUpload instance
    // The caching is handled by [SameObject] in the interface layer (cached_upload)
    const XMLHttpRequestUpload = interfaces.XMLHttpRequestUpload;
    const upload = try XMLHttpRequestUpload.init(internal.allocator, instance.ctx);

    return upload;
}

/// Getter for responseURL
///
/// Spec: "The responseURL getter steps are to return the empty string if this's
/// response's URL is null; otherwise its serialization with the exclude fragment flag set."
pub fn get_responseURL(instance: *runtime.Instance) anyerror!runtime.USVString {
    const xhr_state = getXHRState(instance);

    // Get URL from response
    if (xhr_state.response) |response| {
        if (response.url()) |url| {
            // TODO: Serialize URL with exclude fragment flag
            // For now, return the URL as-is
            return url;
        }
    }

    return "";
}

/// Getter for status
///
/// Spec: "The status getter steps are to return this's response's status."
pub fn get_status(instance: *runtime.Instance) anyerror!u16 {
    const xhr_state = getXHRState(instance);

    if (xhr_state.response) |response| {
        return response.status;
    }

    // Network error has status 0
    return 0;
}

/// Getter for statusText
///
/// Spec: "The statusText getter steps are to return this's response's status message."
pub fn get_statusText(instance: *runtime.Instance) anyerror!runtime.ByteString {
    const xhr_state = getXHRState(instance);

    if (xhr_state.response) |response| {
        return response.status_message;
    }

    return "";
}

/// Getter for responseType
///
/// Spec: "The responseType getter steps are to return this's response type."
pub fn get_responseType(instance: *runtime.Instance) anyerror!enums.XMLHttpRequestResponseType {
    const xhr_state = getXHRState(instance);

    return switch (xhr_state.response_type) {
        .empty => .__,
        .text => ._text_,
        .arraybuffer => ._arraybuffer_,
        .blob => ._blob_,
        .document => ._document_,
        .json => ._json_,
    };
}

/// Getter for response
/// TODO: Implement full response object handling
pub fn get_response(instance: *runtime.Instance) anyerror!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for responseText
///
/// Spec: "The responseText getter steps are:
/// 1. If this's response type is not the empty string or 'text', throw InvalidStateError
/// 2. If this's state is not loading or done, return the empty string
/// 3. Return the result of getting a text response for this."
pub fn get_responseText(instance: *runtime.Instance) anyerror!runtime.USVString {
    const xhr_state = getXHRState(instance);

    // Step 1: Check response type
    if (xhr_state.response_type != .empty and xhr_state.response_type != .text) {
        return error.InvalidStateError;
    }

    // Step 2: Check state
    if (xhr_state.ready_state != .LOADING and xhr_state.ready_state != .DONE) {
        return "";
    }

    // Step 3: Return text response
    // TODO: Implement proper text decoding with encoding detection
    return xhr_state.received_bytes.items;
}

/// Getter for responseXML
/// Returns null (Document response not implemented)
pub fn get_responseXML(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Setter for onreadystatechange
///
/// Spec: "The onreadystatechange attribute is an event handler IDL attribute."
/// Creates a Global handle from the passed value so it survives past the setter's HandleScope.
pub fn set_onreadystatechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const internal = getInternal(instance);
    const isolate = internal.isolate orelse return;

    // Dispose old Global handle first to prevent memory leaks
    v8_engine.disposeOptionalGlobalHandle(&internal.onreadystatechange);

    // Create new Global handle from the Local handle (value)
    if (value) |handler| {
        internal.onreadystatechange = v8_engine.createOptionalGlobalHandle(isolate, @ptrCast(@constCast(handler)));
    } else {
        internal.onreadystatechange = null;
    }
}

/// Setter for timeout
///
/// Spec: "The timeout setter steps are:
/// 1. If the current global object is a Window object and this's synchronous flag is set,
///    throw InvalidAccessError
/// 2. Set this's timeout to the given value."
pub fn set_timeout(instance: *runtime.Instance, value: u32) anyerror!void {
    const xhr_state = getXHRState(instance);

    // Step 1: Check sync mode in Window context (TODO: check global object type)
    // For now, skip this check since we don't have Window detection

    // Step 2: Set timeout
    xhr_state.timeout = value;
}

/// Setter for withCredentials
///
/// Spec: "The withCredentials setter steps are:
/// 1. If this's state is not unsent or opened, throw InvalidStateError
/// 2. If this's send() flag is set, throw InvalidStateError
/// 3. Set this's cross-origin credentials to the given value."
pub fn set_withCredentials(instance: *runtime.Instance, value: bool) anyerror!void {
    const xhr_state = getXHRState(instance);

    // Step 1: Check state
    if (xhr_state.ready_state != .UNSENT and xhr_state.ready_state != .OPENED) {
        return error.InvalidStateError;
    }

    // Step 2: Check send flag
    if (xhr_state.send_flag) {
        return error.InvalidStateError;
    }

    // Step 3: Set cross-origin credentials
    xhr_state.cross_origin_credentials = value;
}

/// Setter for responseType
///
/// Spec: "The responseType setter steps are:
/// 1. If current global object is not Window and value is 'document', return
/// 2. If this's state is loading or done, throw InvalidStateError
/// 3. If current global object is Window and synchronous flag is set, throw InvalidAccessError
/// 4. Set this's response type to the given value."
pub fn set_responseType(instance: *runtime.Instance, value: enums.XMLHttpRequestResponseType) anyerror!void {
    const xhr_state = getXHRState(instance);

    // Step 1: Skip document in non-Window context (TODO: check global object type)
    // For now, allow all types

    // Step 2: Check state
    if (xhr_state.ready_state == .LOADING or xhr_state.ready_state == .DONE) {
        return error.InvalidStateError;
    }

    // Step 3: Check sync mode in Window context (TODO)

    // Step 4: Set response type
    xhr_state.response_type = switch (value) {
        .__ => .empty,
        ._text_ => .text,
        ._arraybuffer_ => .arraybuffer,
        ._blob_ => .blob,
        ._document_ => .document,
        ._json_ => .json,
    };
}

/// Operation: setPrivateToken
/// Private Token API (not part of core XHR spec)
pub fn call_setPrivateToken(instance: *runtime.Instance, privateToken: dictionaries.PrivateToken) anyerror!void {
    _ = instance;
    _ = privateToken;
    return error.NotImplemented;
}

/// Operation: setAttributionReporting
/// Attribution Reporting API (not part of core XHR spec)
pub fn call_setAttributionReporting(instance: *runtime.Instance, options: dictionaries.AttributionReportingRequestOptions) anyerror!void {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: open
///
/// Spec: https://xhr.spec.whatwg.org/#the-open()-method
/// Step 15: "Set this's state to opened"
/// Step 16: "Fire an event named readystatechange at this."
pub fn call_open(instance: *runtime.Instance, method: runtime.ByteString, url: runtime.USVString) anyerror!void {
    const xhr_state = getXHRState(instance);

    // Call the open algorithm
    open_algo.open(
        xhr_state,
        method,
        url,
        true, // async = true (default)
        null, // username
        null, // password
    ) catch |err| {
        return switch (err) {
            open_algo.OpenError.SecurityError => error.SecurityError,
            open_algo.OpenError.InvalidURL => error.SyntaxError,
            open_algo.OpenError.InvalidMethod => error.SyntaxError,
            open_algo.OpenError.InvalidState => error.InvalidStateError,
            open_algo.OpenError.OutOfMemory => error.OutOfMemory,
        };
    };

    // Step 16: Fire readystatechange event
    // Per spec, after state changes to OPENED, fire readystatechange event
    fireReadyStateChangeEvent(instance);
}

/// Fire the readystatechange event by invoking the onreadystatechange handler
/// Per WHATWG XHR spec, this is fired whenever the readyState attribute changes
fn fireReadyStateChangeEvent(instance: *runtime.Instance) void {
    const internal = getInternal(instance);
    const isolate = internal.isolate orelse return;

    // Get the onreadystatechange handler from Global handle
    if (internal.onreadystatechange) |global| {
        // Retrieve Local handle from Global handle
        const local_value = global.get(isolate) orelse return;

        // Get V8 context from the instance's runtime context
        const v8_context: *v8_engine.ffi.Context = instance.ctx.getEngineContextAs(v8_engine.ffi.Context) orelse return;

        // Check if it's a function and invoke it
        if (v8_engine.ffi.v8_Value_IsFunction(@ptrCast(local_value))) {
            const function: *v8_engine.ffi.Function = @ptrCast(local_value);
            // Call the callback with no arguments
            // The readystatechange event doesn't pass an event object in typical XHR usage
            // Use undefined as the receiver (this) since XHR events don't need a specific this binding
            const undefined_recv = v8_engine.ffi.v8_Undefined(isolate);
            var empty_args: [0]*v8_engine.ffi.Value = .{};
            _ = v8_engine.ffi.v8_Function_Call(function, v8_context, @ptrCast(undefined_recv), 0, &empty_args);
        }
    }
}

/// Operation: abort
///
/// Spec: https://xhr.spec.whatwg.org/#the-abort()-method
pub fn call_abort(instance: *runtime.Instance) anyerror!void {
    const xhr_state = getXHRState(instance);

    // Step 1: Abort this's fetch controller (TODO: implement FetchController.abort())

    // Step 2: If state is opened with send flag set, headers received, or loading
    if ((xhr_state.ready_state == .OPENED and xhr_state.send_flag) or
        xhr_state.ready_state == .HEADERS_RECEIVED or
        xhr_state.ready_state == .LOADING)
    {
        // Run request error steps for abort
        xhr_state.ready_state = .DONE;
        xhr_state.send_flag = false;
        // Set response to network error
        if (xhr_state.response) |r| r.deinit();
        xhr_state.response = null;
        // Fire readystatechange and abort events (TODO)

        // Step 3: If state is done, set to unsent and response to network error
        // (This is part of the same conditional block per spec)
        xhr_state.ready_state = .UNSENT;
    } else if (xhr_state.ready_state == .OPENED) {
        // If OPENED but send flag not set, just reset to UNSENT
        xhr_state.ready_state = .UNSENT;
        if (xhr_state.response) |r| r.deinit();
        xhr_state.response = null;
    }
}

/// Operation: send
///
/// Spec: https://xhr.spec.whatwg.org/#the-send()-method
/// TODO: Implement full send() with Fetch integration
pub fn call_send(instance: *runtime.Instance, body: webidl.Opt(?*const anyopaque)) anyerror!void {
    const xhr_state = getXHRState(instance);
    _ = body;

    // Step 1: Check state
    if (xhr_state.ready_state != .OPENED) {
        return error.InvalidStateError;
    }

    // Step 2: Check send flag
    if (xhr_state.send_flag) {
        return error.InvalidStateError;
    }

    // TODO: Implement full send() with Fetch integration
    // For now, just set the send flag
    xhr_state.send_flag = true;
}

/// Operation: setRequestHeader
///
/// Spec: https://xhr.spec.whatwg.org/#the-setrequestheader()-method
pub fn call_setRequestHeader(instance: *runtime.Instance, name: runtime.ByteString, value: runtime.ByteString) anyerror!void {
    const xhr_state = getXHRState(instance);

    headers_algo.setRequestHeader(
        xhr_state,
        name,
        value,
    ) catch |err| {
        return switch (err) {
            headers_algo.HeaderError.InvalidStateError => error.InvalidStateError,
            headers_algo.HeaderError.SyntaxError => error.SyntaxError,
            headers_algo.HeaderError.OutOfMemory => error.OutOfMemory,
        };
    };
}

/// Operation: getResponseHeader
///
/// Spec: https://xhr.spec.whatwg.org/#the-getresponseheader()-method
pub fn call_getResponseHeader(instance: *runtime.Instance, name: runtime.ByteString) anyerror!?runtime.ByteString {
    const xhr_state = getXHRState(instance);
    const internal = getInternal(instance);

    return try headers_algo.getResponseHeader(
        internal.allocator,
        xhr_state,
        name,
    );
}

/// Operation: overrideMimeType
///
/// Spec: https://xhr.spec.whatwg.org/#the-overridemimetype()-method
pub fn call_overrideMimeType(instance: *runtime.Instance, mime: runtime.DOMString) anyerror!void {
    const xhr_state = getXHRState(instance);

    headers_algo.overrideMimeType(
        xhr_state,
        mime.asSlice(),
    ) catch |err| {
        return switch (err) {
            headers_algo.HeaderError.InvalidStateError => error.InvalidStateError,
            headers_algo.HeaderError.SyntaxError => error.SyntaxError,
            headers_algo.HeaderError.OutOfMemory => error.OutOfMemory,
        };
    };
}

/// Operation: getAllResponseHeaders
///
/// Spec: https://xhr.spec.whatwg.org/#the-getallresponseheaders()-method
pub fn call_getAllResponseHeaders(instance: *runtime.Instance) anyerror!runtime.ByteString {
    const xhr_state = getXHRState(instance);
    const internal = getInternal(instance);

    return try headers_algo.getAllResponseHeaders(internal.allocator, xhr_state);
}
