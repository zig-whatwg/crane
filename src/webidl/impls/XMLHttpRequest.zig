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
const send_algo = xhr.send;
const XHREventType = xhr.XHREventType;
const EventTargetKind = xhr.EventTargetKind;
const ProgressEventData = xhr.ProgressEventData;

const log = std.log.scoped(.xhr);
const clock = @import("clock");
const fetch_mod = @import("fetch");

const same_object = @import("same_object.zig");

/// An XMLHttpRequest is an XMLHttpRequestEventTarget, which is an EventTarget:
/// its event handlers, `onreadystatechange` among them, live in EventTarget's
/// event handler map, and its events are dispatched there.
const XMLHttpRequestEventTargetImpl = @import("XMLHttpRequestEventTarget.zig");
const EventTargetImpl = @import("EventTarget.zig");

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

    /// V8 isolate for creating/disposing Global handles
    isolate: ?*v8_engine.ffi.Isolate,

    /// The asynchronous send()'s fetch, from send() until its task has run.
    pending_fetch: ?*PendingFetch,

    /// Keeps `this.upload` alive for as long as this XHR - see
    /// `same_object.zig`. The upload object carries the upload event handlers,
    /// which script sets on it and then never touches again.
    upload_pin: same_object.Pin,

    pub fn initState(allocator: std.mem.Allocator) InternalState {
        return .{
            .xhr_state = XMLHttpRequestState.init(allocator),
            .allocator = allocator,
            .isolate = null,
            .pending_fetch = null,
            .upload_pin = .{},
        };
    }

    /// End the asynchronous send()'s fetch, if there is one: "terminate"
    /// (open(), a later send(), the XHR going) or "abort" (abort()) this's
    /// fetch controller. Its transfer is cancelled and nothing it received
    /// reaches the XHR.
    fn cancelFetch(self: *InternalState) void {
        const pending = self.pending_fetch orelse return;
        self.pending_fetch = null;
        pending.cancel();
    }

    pub fn deinitState(self: *InternalState) void {
        // The upload object's lifetime is the wrapper cache's from here.
        self.upload_pin.release();
        // Before anything else: a fetch in flight, or its queued task, would
        // otherwise reach an instance that is going away.
        self.cancelFetch();
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
    const instance = try XMLHttpRequestEventTargetImpl.init(allocator, StateType, vtable, ctx);
    errdefer XMLHttpRequestEventTargetImpl.deinit(instance);

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
        state.own._internal = null;
    }
    // The event handlers and listeners go with EventTarget's state.
    XMLHttpRequestEventTargetImpl.deinit(instance);
    // NOTE: Do NOT call runtime.Instance.deinit here - GC layer handles it
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
///
/// Spec: "The new XMLHttpRequest() constructor steps are:
/// 1. Set this's upload object to a new XMLHttpRequestUpload object."
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &XMLHttpRequest.vtable, ctx);
    errdefer deinit(instance);

    // The isolate this XHR's script runs in.
    //
    // NOT `ctx.getEngineContextAs(Isolate)`: `engine_ctx` is a
    // `Global<Context>*`, and that call just reinterprets it, so `internal
    // .isolate` used to be the CONTEXT wearing an Isolate's type. Every use of
    // it - `global.get(isolate)`, `v8_Undefined(isolate)` - was reading a
    // Context as an Isolate.
    const internal = getInternal(instance);
    internal.isolate = v8_engine.ffi.v8_Isolate_GetCurrent();

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
pub fn get_onreadystatechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "readystatechange");
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

    // `cached_upload` is a pointer V8 cannot see. Without this, a collection
    // between `xhr.upload.onloadend = f` and `send()` freed the upload object
    // and `send()` fired `upload.loadstart` into the slab
    // (xhr/send-timeout-events.htm, SEGV in v8_Value_IsFunction).
    internal.upload_pin.hold(upload);

    return upload;
}

/// Getter for responseURL
///
/// Spec: "The responseURL getter steps are to return the empty string if this's
/// response's URL is null; otherwise its serialization with the exclude fragment flag set."
pub fn get_responseURL(instance: *runtime.Instance) anyerror!runtime.USVString {
    const xhr_state = getXHRState(instance);

    // OWNERSHIP: a getter returning USVString/ByteString/DOMString has its
    // result FREED by the interface layer (see the `needs_cleanup` defer in
    // `engines/v8/interface.zig`). Returning a borrowed slice - which this and
    // `statusText` and `responseText` all did - hands the response's own
    // storage to `allocator.free`. It only never fired because `call_send`
    // never produced a response to read.
    if (xhr_state.response) |response| {
        if (response.url()) |url| {
            // TODO: Serialize URL with the exclude fragment flag set.
            return try instance.ctx.allocator.dupe(u8, url);
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
        if (response.status_message.len == 0) return "";
        // Owned: see the note on `get_responseURL`.
        return try instance.ctx.allocator.dupe(u8, response.status_message);
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
///
/// Spec: https://xhr.spec.whatwg.org/#the-response-attribute
///
/// This returned `error.NotImplemented`, so `xhr.response` THREW for every
/// response type - including the default empty one, where the spec says to
/// return the text response.
pub fn get_response(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const xhr_state = getXHRState(instance);
    const allocator = instance.ctx.allocator;

    // Step 1: If this's response type is the empty string or "text", then
    // return the empty string if the state is not loading or done, otherwise
    // the text response.
    if (xhr_state.response_type == .empty or xhr_state.response_type == .text) {
        const text = try get_responseText(instance);
        return .{ .string = .{ .data = text, .owned = text.len > 0 } };
    }

    // Step 2: If this's state is not done, then return null.
    if (xhr_state.ready_state != .DONE) return .{ .null = {} };

    // Step 3: If this's response object is failure, then return null.
    if (xhr_state.response_object == .failure) return .{ .null = {} };

    switch (xhr_state.response_type) {
        // Step 8: the JSON response. `parse JSON from bytes`; a parse failure
        // returns null rather than throwing.
        .json => {
            if (xhr_state.received_bytes.items.len == 0) return .{ .null = {} };
            const engine = instance.ctx.getEngine() orelse return .{ .null = {} };
            const engine_ctx = instance.ctx.getEngineContext() orelse return .{ .null = {} };
            const parse = engine.parseJson orelse return .{ .null = {} };
            const parsed = parse(engine_ctx, xhr_state.received_bytes.items) catch return .{ .null = {} };
            return .{ .handle = .{ .ptr = parsed, .needs_disposal = true, .handle_scope = .global } };
        },
        // Step 5: the ArrayBuffer response. "Set this's response object to a
        // new ArrayBuffer object representing this's received bytes. If this
        // throws an exception, then set this's response object to failure and
        // return null."
        .arraybuffer => {
            const engine = instance.ctx.getEngine() orelse return .{ .null = {} };
            const engine_ctx = instance.ctx.getEngineContext() orelse return .{ .null = {} };
            const create = engine.createArrayBuffer orelse return .{ .null = {} };
            const buffer = create(engine_ctx, xhr_state.received_bytes.items) catch {
                // The spec's "if this throws" branch: remember the failure, so
                // a second read returns null at step 3 rather than retrying an
                // allocation that has already failed once.
                xhr_state.response_object = .failure;
                return .{ .null = {} };
            };
            return .{ .handle = .{ .ptr = buffer, .needs_disposal = true, .handle_scope = .global } };
        },
        // Step 6: the Blob response.
        //
        // TODO: needs a Blob instance carrying the received bytes with its type
        // set to the final MIME type. Returning the bytes as a string would be
        // a worse answer than null, because script could not tell it apart from
        // a text response.
        .blob => {
            _ = allocator;
            log.debug("blob response type is not implemented", .{});
            return .{ .null = {} };
        },
        // Step 7: the document response, which needs the HTML/XML parser.
        .document => return .{ .null = {} },
        .empty, .text => unreachable, // handled by step 1
    }
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

    // Step 3: Return the result of getting a text response for this.
    //
    // Text response step 1: if this's response's body is null, return the empty
    // string. A network error has a null body.
    if (xhr_state.isNetworkError()) return "";

    if (xhr_state.received_bytes.items.len == 0) return "";

    // OWNED, not borrowed: the interface layer frees what a USVString getter
    // returns, and `received_bytes.items` belongs to an ArrayList.
    //
    // TODO: decode using the final charset rather than assuming UTF-8.
    return try instance.ctx.allocator.dupe(u8, xhr_state.received_bytes.items);
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
pub fn set_onreadystatechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "readystatechange", value);
}

/// Setter for timeout
///
/// Spec: "The timeout setter steps are:
/// 1. If the current global object is a Window object and this's synchronous flag is set,
///    throw InvalidAccessError
/// 2. Set this's timeout to the given value."
pub fn set_timeout(instance: *runtime.Instance, value: u32) anyerror!void {
    const xhr_state = getXHRState(instance);

    // Step 1: If the current global object is a Window object and this's
    // synchronous flag is set, then throw an "InvalidAccessError".
    if (xhr_state.synchronous_flag and currentGlobalIsWindow()) return error.InvalidAccessError;

    // Step 2: Set timeout
    xhr_state.timeout = value;

    // "This implies that the timeout attribute can be set while fetching is
    // in progress" - and it still counts from when fetching began.
    if (getInternal(instance).pending_fetch) |pending| pending.armTimeout(value);
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

    // Step 1: If the current global object is not a Window object and the
    // given value is "document", then return.
    if (value == ._document_ and !currentGlobalIsWindow()) return;

    // Step 2: Check state
    if (xhr_state.ready_state == .LOADING or xhr_state.ready_state == .DONE) {
        return error.InvalidStateError;
    }

    // Step 3: If the current global object is a Window object and this's
    // synchronous flag is set, then throw an "InvalidAccessError".
    if (xhr_state.synchronous_flag and currentGlobalIsWindow()) return error.InvalidAccessError;

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

/// Operation: open(method, url)
///
/// Spec: https://xhr.spec.whatwg.org/#the-open()-method
pub fn call_open(instance: *runtime.Instance, method: runtime.ByteString, url: runtime.USVString) anyerror!void {
    // Step 7: "If the async argument is omitted, set async to true, and set
    // username and password to null."
    return openSteps(instance, method, url, true, null, null);
}

/// Operation: open(method, url, async, username, password)
///
/// Spec: https://xhr.spec.whatwg.org/#the-open()-method
///
/// The overload with `async`, and the only way to make a SYNCHRONOUS request:
/// `open("GET", url, false)`. Until the binding resolved overloads, only the
/// two-argument open() was bound, the third argument was dropped, and every
/// XMLHttpRequest ran asynchronously - so the ~80 xhr/ files that open
/// synchronously read `status` and `responseText` right after send() and got
/// 0 and "".
///
/// Note step 7's converse: `open(m, url, undefined)` IS this overload -
/// argument count, not value, selects it - so `async` is then false.
pub fn call_open__1(
    instance: *runtime.Instance,
    method: runtime.ByteString,
    url: runtime.USVString,
    is_async: bool,
    username: webidl.Opt(?runtime.USVString),
    password: webidl.Opt(?runtime.USVString),
) anyerror!void {
    // `optional USVString? username = null`: omitted, undefined and null are
    // all null.
    const user: ?[]const u8 = if (username.wasPassed()) username.value else null;
    const pass: ?[]const u8 = if (password.wasPassed()) password.value else null;
    return openSteps(instance, method, url, is_async, user, pass);
}

fn openSteps(
    instance: *runtime.Instance,
    method: []const u8,
    url: []const u8,
    is_async: bool,
    username: ?[]const u8,
    password: ?[]const u8,
) anyerror!void {
    const xhr_state = getXHRState(instance);

    // Steps 5-6: "encoding-parsing a URL url, relative to this's relevant
    // settings object". Borrowed from the context entry - not ours to free.
    const base_url = relevantBaseURL(instance);

    // Step 12 fires readystatechange only "if this's state is not opened" -
    // a second open() on an opened request changes nothing observable there.
    // Step 11 does not touch the state, so asking now is asking then.
    const was_opened = xhr_state.ready_state == .OPENED;

    // Steps 2-11.
    open_algo.open(
        xhr_state,
        method,
        url,
        is_async,
        username,
        password,
        base_url,
        currentGlobalIsWindow(),
    ) catch |err| {
        return switch (err) {
            open_algo.OpenError.SecurityError => error.SecurityError,
            open_algo.OpenError.InvalidURL => error.SyntaxError,
            open_algo.OpenError.InvalidMethod => error.SyntaxError,
            open_algo.OpenError.InvalidState => error.InvalidStateError,
            open_algo.OpenError.InvalidAccess => error.InvalidAccessError,
            open_algo.OpenError.OutOfMemory => error.OutOfMemory,
        };
    };

    // Step 10 (with 11, which open_algo ran): Terminate this's fetch
    // controller. Nothing observable happens between the two.
    getInternal(instance).cancelFetch();

    // Step 12: If this's state is not opened, set it to opened and fire an
    // event named readystatechange at this.
    if (!was_opened) fireReadyStateChangeEvent(instance);
}

/// Is the current global object a Window?
///
/// open() step 9 and the `timeout` and `responseType` setters restrict
/// synchronous requests in a Window only - a worker may block. The current
/// global object is the running realm's; its Instance sits in internal field
/// 0 of the context's global, and names its own interface.
fn currentGlobalIsWindow() bool {
    const ffi = v8_engine.ffi;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return false;
    const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse return false;
    defer ffi.v8_Context_Dispose(context);
    const global = ffi.v8_Context_Global(context) orelse return false;
    defer ffi.v8_Object_Dispose(global);
    const raw = ffi.v8_Object_GetAlignedPointerFromInternalField(global, 0) orelse return false;
    const global_instance: *runtime.Instance = @ptrCast(@alignCast(raw));
    return std.mem.eql(u8, global_instance.vtable.name, "Window");
}

/// This's relevant settings object's API base URL.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#api-base-url
///
/// ## Where the page URL actually lives
///
/// NOT on the Document and NOT on the Location. Both were measured in a WPT
/// [window] run:
///
///     document.URL   = ''
///     location.href  = 'about:blank'
///
/// `Context.loadHTML` records the URL in three places -
/// `context_manager.setDocumentUrl`, `Context.url`, and the Window's origin -
/// and `Context.setUrl`'s own comment says it does not reach Location
/// ("Direct impl access would require Location.setHref which isn't currently
/// exposed"). Nothing sets `Document`'s URL outside `DOMParser`, which reads it
/// from the realm and so inherits the same emptiness.
///
/// The one place that IS populated is `context_manager`, whose comment says
/// exactly what it is for: "Set the document URL in context_manager for fetch
/// relative URL resolution". A worker context has no entry, which is correct -
/// a worker's base URL is its script URL, which is a separate lookup.
///
/// Returns a BORROWED slice owned by the context entry, so the caller must not
/// free it.
fn relevantBaseURL(instance: *runtime.Instance) ?[]const u8 {
    const v8_context = instance.ctx.getEngineContextAs(v8_engine.ffi.Context) orelse return null;
    const url = v8_engine.context_manager.getDocumentUrl(v8_context) orelse return null;
    if (url.len == 0) return null;
    return url;
}

// =============================================================================
// Events
//
// Spec: https://xhr.spec.whatwg.org/#events
//
// `src/xhr/` cannot reach JavaScript - it has no `runtime` import and no V8
// link. It fires events through an `EventSink`, a two-field vtable, and this is
// the implementation of it: dispatch at the XHR or its upload object. The
// event listener list holds both kinds of listener - `addEventListener`'s and
// the event handlers' (`xhr.onload = f`), in activation order - so dispatch
// alone reaches every one.
// =============================================================================

/// Install the sink so the algorithms in `src/xhr/` can fire at this object.
fn installEventSink(instance: *runtime.Instance) void {
    const xhr_state = getXHRState(instance);
    xhr_state.event_sink = .{ .ctx = @ptrCast(instance), .fire = &fireFromAlgorithms };
}

/// `EventSink.fire`. `ctx` is the XMLHttpRequest instance.
fn fireFromAlgorithms(
    ctx: *anyopaque,
    target: EventTargetKind,
    event_type: XHREventType,
    progress: ?ProgressEventData,
) void {
    const instance: *runtime.Instance = @ptrCast(@alignCast(ctx));

    const target_instance = switch (target) {
        .xhr => instance,
        // An upload event fires at this's upload object. If script has never
        // read `xhr.upload` there is no upload object, so there is nothing
        // listening and nothing to create one for.
        .upload => uploadObjectIfCreated(instance) orelse return,
    };

    fireAt(target_instance, event_type, progress);
}

/// This's upload object, but only if it already exists.
///
/// `[SameObject]` caching lives in the generated interface (`cached_upload`),
/// so reading the field is how to ask "has anyone touched `xhr.upload`?"
/// without creating one.
fn uploadObjectIfCreated(instance: *runtime.Instance) ?*runtime.Instance {
    const state = instance.getState(State);
    return state.own.cached_upload;
}

/// Build the event object and dispatch it at `target`.
///
/// The event instance is released when - and only when - nothing wrapped it.
/// See `releaseEventIfUnwrapped`.
fn fireAt(
    target: *runtime.Instance,
    event_type: XHREventType,
    progress: ?ProgressEventData,
) void {
    const ctx = target.ctx;
    const name = event_type.name();
    const type_string = runtime.DOMString.initInterned(name);

    // ProgressEvent for the seven progress types, plain Event for
    // readystatechange. Both are non-bubbling and non-cancelable.
    const event: *runtime.Instance = blk: {
        if (progress) |p| {
            const init_dict = dictionaries.ProgressEventInit{
                .base = .{},
                .lengthComputable = p.lengthComputable,
                .loaded = @floatFromInt(p.loaded),
                .total = @floatFromInt(p.total),
            };
            break :blk interfaces.ProgressEvent.call_constructor(
                ctx,
                type_string,
                webidl.Opt(dictionaries.ProgressEventInit).passed(init_dict),
            ) catch return;
        }
        break :blk interfaces.Event.call_constructor(
            ctx,
            type_string,
            webidl.Opt(dictionaries.EventInit).notPassed(),
        ) catch return;
    };

    // `dispatchEvent` throws unless the event's INITIALIZED flag is set, and
    // neither constructor sets it - `document.createEvent("Event")` hands back
    // an uninitialized event on purpose. `initEvent` sets it, and also gives
    // the event an owned copy of its type string, which is what dispatch
    // matches listeners on.
    interfaces.Event.call_initEvent(
        event,
        type_string,
        webidl.Opt(bool).passed(false),
        webidl.Opt(bool).passed(false),
    ) catch return;

    // Every listener, the event handlers among them.
    _ = interfaces.EventTarget.call_dispatchEvent(target, event) catch |err| {
        log.debug("dispatch of {s} failed: {s}", .{ name, @errorName(err) });
    };

    releaseEventIfUnwrapped(event, progress != null);
}

/// Free an event nobody ever saw.
///
/// `ProgressEvent.call_constructor` allocates its `InternalState` with
/// `ctx.allocator.create` and the instance created here has no owner, so every
/// event fired leaked one - `DebugAllocator` named it through
/// `XMLHttpRequest.fireAt`, and a request fires six.
///
/// Freeing it unconditionally is NOT safe: a listener may have kept the event
/// (`let saved; xhr.onload = e => saved = e`), in which case V8 holds a wrapper
/// around an Instance this would return to the slab. AGENTS.md: prove the
/// callee does not retain it, or do not dispose.
///
/// The WRAPPER CACHE is that proof. Every path that hands the event to V8 -
/// `wrapInstanceAsV8Object`, from both `invokeIdlHandler` and EventTarget's
/// listener invocation - puts it in the cache, and the weak callback there
/// owns it from that moment. So an event absent from the cache after dispatch
/// has never been seen by V8, nothing can be holding it, and freeing it is
/// provably safe. An event that IS cached is left entirely alone.
///
/// That covers the common case outright: `progress` and `readystatechange` fire
/// on every request whether or not anything is listening.
///
/// `Window.zig` does the same thing for MessageEvent, but removes from the
/// cache first and frees regardless - which is the version this deliberately
/// does not copy.
fn releaseEventIfUnwrapped(event: *runtime.Instance, is_progress_event: bool) void {
    const cache_storage = event.ctx.getV8WrapperCacheStorage() orelse return;
    const cache: *v8_engine.WrapperCache = @ptrCast(@alignCast(cache_storage));

    // Wrapped => V8 owns it from here.
    if (cache.get(event) != null) return;

    if (is_progress_event) {
        interfaces.ProgressEvent.deinit(event);
    } else {
        interfaces.Event.deinit(event);
    }
}

/// Fire readystatechange at this XHR.
fn fireReadyStateChangeEvent(instance: *runtime.Instance) void {
    fireAt(instance, .readystatechange, null);
}

/// Operation: abort
///
/// Spec: https://xhr.spec.whatwg.org/#the-abort()-method
///
/// The whole algorithm lives in `xhr.abort`; this only has to make sure the
/// events it fires can reach script.
pub fn call_abort(instance: *runtime.Instance) anyerror!void {
    const xhr_state = getXHRState(instance);
    installEventSink(instance);
    // Step 1: Abort this's fetch controller.
    getInternal(instance).cancelFetch();
    xhr.abort.abort(xhr_state);
}

/// Operation: send
///
/// Spec: https://xhr.spec.whatwg.org/#the-send()-method
///
/// ## Sync waits; async fetches in parallel
///
/// Steps 1-10, which script can observe immediately (a second `send()` must
/// throw), and 11.1-11.6 (`loadstart`) run inline. A synchronous request then
/// waits for its response (step 12), as sync means. An asynchronous one hands
/// req to the event loop (`fetch.algorithms.AsyncFetch`) and returns; a task
/// runs steps 11.9 onwards once the response is in (`PendingFetch`). So
/// handlers assigned after `send()` see every event, the loop keeps turning
/// while the response is on its way, requests complete in the order the
/// server answers them, and `timeout` and `abort()` end one still in flight.
///
/// The fetch used to run inside that task, blocked in curl, so none of the
/// last three held.
///
/// With no event loop and no timer - a bare realm, or a unit test - it waits
/// inline, which is better than dropping the request.
pub fn call_send(instance: *runtime.Instance, body: webidl.Opt(?runtime.JSValue)) anyerror!void {
    const xhr_state = getXHRState(instance);
    const internal = getInternal(instance);

    // Step 5: If one or more event listeners are registered on this's upload
    // object, then set this's upload listener flag.
    xhr_state.upload_listener_flag = uploadHasListeners(instance);

    // Own the body for the life of the request: the conversion layer frees
    // its copy when this returns, and an asynchronous request's fetch - a
    // redirect re-sends it - runs long after. The body is THIS send()'s: a
    // handler that runs during it can send again, with a body of its own.
    const allocator = internal.allocator;
    const owned_body: ?[]u8 = if (extractBodyBytes(instance, body)) |bytes|
        allocator.dupe(u8, bytes) catch return error.OutOfMemory
    else
        null;
    var body_taken = false;
    defer if (!body_taken) if (owned_body) |b| allocator.free(b);

    installEventSink(instance);

    // Steps 1-10, inline and synchronously observable.
    const effective_body = try send_algo.sendPrologue(xhr_state, owned_body);

    // Step 12: a sync request blocks here, which is what sync MEANS.
    if (xhr_state.synchronous_flag) {
        send_algo.sendDispatch(xhr_state, effective_body) catch |err| {
            return switch (err) {
                error.TimeoutError => error.TimeoutError,
                error.NetworkError => error.NetworkError,
                else => err,
            };
        };
        return;
    }

    // Steps 11.1-11.6 are SYNCHRONOUS: `loadstart` is a step of `send()`, not
    // of the fetch, and must fire before `send()` returns. Deferring it with
    // the rest of step 11 put it after whatever the caller did next, so
    // `xhr.send(); xhr.abort();` emitted `readystatechange(4)` first and
    // `loadstart` never.
    if (!send_algo.sendStart(xhr_state, effective_body)) return;

    // A realm with no event loop and no timer to run the fetch's task on - a
    // bare realm, or a unit test - waits for it here, which is better than
    // dropping the request.
    if (instance.ctx.getOptionalEventLoop() == null and instance.ctx.getOptionalTimer() == null) {
        send_algo.sendDispatch(xhr_state, effective_body) catch |err| {
            log.debug("inline send failed: {s}", .{@errorName(err)});
        };
        return;
    }

    // Steps 11.7-11.10: fetch req in parallel, on the event loop. Step 3 may
    // have discarded the body (GET, HEAD); then none is sent.
    internal.cancelFetch();
    const request = try send_algo.createRequest(allocator, xhr_state, effective_body);
    const pending = allocator.create(PendingFetch) catch {
        request.deinit();
        return error.OutOfMemory;
    };
    pending.* = .{
        .allocator = allocator,
        .instance = instance,
        .isolate = internal.isolate orelse v8_engine.ffi.v8_Isolate_GetCurrent() orelse {
            allocator.destroy(pending);
            request.deinit();
            return error.InvalidStateError;
        },
        .body = if (effective_body != null) owned_body else null,
        .started_ms = clock.monotonicMillis(),
    };
    pending.fetch = fetch_mod.algorithms.AsyncFetch.start(
        allocator,
        request,
        .{},
        fetch_mod.network.scheduler.threadScheduler(),
        pending.client(),
    ) catch |err| {
        // The fetch owned the request, and freed it.
        allocator.destroy(pending);
        return err;
    };
    // The request's body is these bytes, borrowed; the pending fetch keeps
    // them for as long as the fetch can read them.
    if (pending.body != null) body_taken = true;
    internal.pending_fetch = pending;
    pending.keep_alive.hold(instance);

    // Step 11.11: If this's timeout is not 0, end the fetch once it has run
    // that long.
    pending.armTimeout(xhr_state.timeout);
}

/// One asynchronous send()'s fetch, from `send()` until its body has been
/// read to its end.
///
/// The response comes at its headers (the headers-received steps run in a
/// task), and its body after, through the response's pipe: each time the
/// pipe has news, a task feeds what arrived to step 11.9.13's
/// processBodyChunk, and its end to processEndOfBody. Nothing is read until
/// a task runs, so events fire only at the top of a task.
///
/// Two things hold it, each letting go once: the fetch, until it is over
/// (`finished`), gone (`gone`) or ended here; and a queued task, until it
/// runs (or its `drop`). The XMLHttpRequest's `pending_fetch` points at it
/// while it is the XHR's current request; `cancel` (abort(), open(), a later
/// send(), deinit) ends that - the fetch is terminated and nothing more
/// reaches the XHR.
///
/// The instance is read only while nothing has cancelled this: the XHR's
/// `deinitState` cancels it before the instance can go, and the slab
/// recycles addresses, so a bare `*Instance` held across turns would
/// otherwise run into whatever took its place.
const PendingFetch = struct {
    allocator: std.mem.Allocator,
    instance: *runtime.Instance,
    /// The XMLHttpRequest's isolate - a worker's is not the page's, and the
    /// task can run from the page's loop.
    isolate: *v8_engine.ffi.Isolate,
    fetch: ?*fetch_mod.algorithms.AsyncFetch = null,
    /// The fetch's outcome, from `done` until a task processes it.
    outcome: ?(fetch_mod.algorithms.FetchError!fetch_mod.algorithms.FetchResult) = null,
    /// The response's body, while it is being read: borrowed from the
    /// response, which the XHR state owns - `cancel` lets go of it before
    /// anything can replace that response.
    pipe: ?*fetch_mod.internal.BodyPipe = null,
    /// Step 11.9's processor, kept from the headers to the body's end: it
    /// carries the progress throttle.
    processor: ?xhr.response.ResponseProcessor = null,
    /// The request body, owned: req's body borrows it, and a redirect
    /// re-sends it, so it lives as long as this does.
    body: ?[]u8 = null,
    /// No longer the XHR's request: touch nothing but this.
    cancelled: bool = false,
    /// The response has been processed and its body read to the end.
    complete: bool = false,
    fetch_holds: bool = true,
    task_queued: bool = false,
    /// When the fetch began, which is what `timeout` counts from.
    started_ms: i64,
    /// The XMLHttpRequest's wrapper, held strongly while this exists. XHR
    /// §3.2: an XMLHttpRequest whose request is outstanding "must not be
    /// garbage collected" - its events are still to come, and script need not
    /// hold it to hear them (`xhr.onloadend = () => t.done()` closes over
    /// nothing). Without this a collection mid-fetch deinitialised it, which
    /// cancels the fetch, and no event ever fired. Blink's
    /// XMLHttpRequest::HasPendingActivity is the same rule.
    keep_alive: same_object.Pin = .{},
    /// The pending timeout, until the body has ended.
    timeout_timer: ?runtime.TimerInterface = null,
    timeout_id: runtime.TimerId = 0,

    fn client(self: *PendingFetch) fetch_mod.algorithms.AsyncFetch.Client {
        return .{ .context = self, .done = done, .alive = alive, .gone = gone, .finished = finished };
    }

    /// Whether the XHR's realm is still there. A page that ends retires its
    /// context and empties its `engine_ctx`.
    fn alive(context: *anyopaque) bool {
        const self: *PendingFetch = @ptrCast(@alignCast(context));
        return self.instance.ctx.engine_ctx != null;
    }

    /// The realm went away with the fetch in flight; the fetch is over.
    fn gone(context: *anyopaque) void {
        const self: *PendingFetch = @ptrCast(@alignCast(context));
        self.fetch = null;
        self.fetch_holds = false;
        if (!self.cancelled) {
            self.cancelled = true;
            self.releasePipe();
            self.detach();
        }
        self.maybeFree();
    }

    /// The fetch is over: its body has ended (and said so through the pipe),
    /// or nobody was left to read it.
    fn finished(context: *anyopaque) void {
        const self: *PendingFetch = @ptrCast(@alignCast(context));
        self.fetch = null;
        self.fetch_holds = false;
        self.maybeFree();
    }

    /// req's fetch has its response - its headers; its body still arriving.
    fn done(context: *anyopaque, outcome: fetch_mod.algorithms.FetchError!fetch_mod.algorithms.FetchResult) void {
        const self: *PendingFetch = @ptrCast(@alignCast(context));
        self.outcome = outcome;
        self.queueTask();
    }

    /// The body's pipe has news.
    fn notify(context: *anyopaque) void {
        const self: *PendingFetch = @ptrCast(@alignCast(context));
        self.queueTask();
    }

    /// Queue the task that acts on what has arrived, on the realm's event
    /// loop - or, in a worker, whose realm has none and runs its tasks as
    /// timers on the page's, as a timer.
    fn queueTask(self: *PendingFetch) void {
        if (self.task_queued or self.cancelled) return;
        const ctx = self.instance.ctx;
        if (ctx.getOptionalEventLoop()) |loop| {
            self.task_queued = true;
            loop.queueTask(.{ .callback = run, .context = self, .drop = drop });
            return;
        }
        if (ctx.getOptionalTimer()) |timer| {
            if (timer.setTimeout(0, run, self) != 0) {
                self.task_queued = true;
                return;
            }
        }
    }

    /// The task: send() steps 11.9 onwards - the response's headers once,
    /// then whatever of its body has arrived.
    fn run(context: ?*anyopaque) void {
        const self: *PendingFetch = @ptrCast(@alignCast(context.?));
        self.task_queued = false;
        if (self.cancelled) return self.maybeFree();
        const instance = self.instance;

        // A task runs from the event loop, not from script: it enters the
        // realm itself - and in a worker, the worker's isolate.
        const isolate = self.isolate;
        const entered = v8_engine.ffi.v8_Isolate_GetCurrent() != isolate;
        if (entered) v8_engine.ffi.v8_Isolate_Enter(isolate);
        defer if (entered) v8_engine.ffi.v8_Isolate_Exit(isolate);
        {
            const scope = v8_engine.JsScope.init(instance.ctx) orelse return self.maybeFree();
            defer scope.deinit();
            const state = getXHRState(instance);
            if (self.outcome) |outcome| {
                self.outcome = null;
                self.processor = xhr.response.ResponseProcessor.init(state);
                const pipe = send_algo.sendAsyncFinish(state, self.body, outcome, &self.processor.?) catch |err| blk: {
                    log.debug("async send failed: {s}", .{@errorName(err)});
                    break :blk null;
                };
                // A listener may have ended this request (abort(), open()).
                if (!self.cancelled) {
                    if (pipe) |p| {
                        self.pipe = p;
                        p.consumer = .{ .context = self, .notify = notify };
                    } else self.finishRequest();
                }
            }
            if (!self.cancelled) self.readBody(state);
        }
        self.maybeFree();
        // In a worker, the task's end is the worker's to run.
        @import("html").worker_v8_context.finishTaskIn(isolate);
    }

    /// Feed the body that has arrived to processBodyChunk, and its end to
    /// processEndOfBody - stopping the moment a listener ends the request.
    fn readBody(self: *PendingFetch, state: *XMLHttpRequestState) void {
        const pipe = self.pipe orelse return;
        if (pipe.hasBytes()) {
            const bytes = pipe.take() catch return;
            defer self.allocator.free(bytes);
            send_algo.sendAsyncBodyChunk(state, &self.processor.?, bytes) catch |err| {
                log.debug("body chunk failed: {s}", .{@errorName(err)});
            };
            if (self.cancelled) return;
        }
        const p = self.pipe orelse return;
        switch (p.state) {
            .open => {},
            .closed => {
                if (p.hasBytes()) return self.queueTask();
                self.releasePipe();
                self.finishRequest();
                send_algo.sendAsyncEndOfBody(state, &self.processor.?);
            },
            .errored => {
                self.releasePipe();
                self.finishRequest();
                send_algo.sendAsyncBodyFailed(state, &self.processor.?);
            },
        }
    }

    /// The response has been read: this is no longer the XHR's request in
    /// flight, and its timeout is over.
    fn finishRequest(self: *PendingFetch) void {
        self.complete = true;
        self.disarmTimeout();
        self.detach();
    }

    /// A task that will never run: its loop is going.
    fn drop(context: ?*anyopaque) void {
        const self: *PendingFetch = @ptrCast(@alignCast(context.?));
        self.task_queued = false;
        if (!self.cancelled) {
            self.cancelled = true;
            self.releasePipe();
            self.detach();
        }
        self.maybeFree();
    }

    /// This is no longer the XHR's request (abort(), open(), a later send(),
    /// deinit): the fetch is terminated, and nothing more reaches the XHR.
    fn cancel(self: *PendingFetch) void {
        self.cancelled = true;
        self.releasePipe();
        self.disarmTimeout();
        if (self.fetch) |f| {
            self.fetch = null;
            f.terminate(.{ .kind = .aborted });
            self.fetch_holds = false;
        }
        self.maybeFree();
    }

    /// Stop listening to the body; the pipe itself is the response's.
    fn releasePipe(self: *PendingFetch) void {
        const pipe = self.pipe orelse return;
        self.pipe = null;
        pipe.consumer = null;
    }

    /// Step 11.11's timer: the fetch has run for this's timeout. Set the
    /// timed out flag and terminate the fetch; its processResponse would then
    /// run the timeout steps, which this does instead.
    fn timedOut(context: ?*anyopaque) void {
        const self: *PendingFetch = @ptrCast(@alignCast(context.?));
        self.timeout_id = 0;
        // The response may be in and unread: a long task can hold the loop
        // past the deadline with it waiting in the socket. The fetch and the
        // timer race in parallel, and the fetch finished first, so give the
        // network its step before calling it a timeout. (Only while the realm
        // lives: a sweep inside the pump would end this very call.)
        if (alive(self)) _ = fetch_mod.algorithms.async_fetch.pump();
        if (self.cancelled or self.complete) return;
        // A response in, and its body not yet all read: in time only if the
        // body has arrived.
        if (self.pipe) |pipe| {
            if (pipe.state == .closed) return;
        } else if (self.outcome != null and self.fetch == null) return;

        const instance = self.instance;
        self.cancelled = true;
        self.releasePipe();
        self.detach();
        if (self.fetch) |f| {
            self.fetch = null;
            f.terminate(.{ .kind = .network });
            self.fetch_holds = false;
        }
        const isolate = self.isolate;
        defer self.maybeFree();

        const entered = v8_engine.ffi.v8_Isolate_GetCurrent() != isolate;
        if (entered) v8_engine.ffi.v8_Isolate_Enter(isolate);
        defer if (entered) v8_engine.ffi.v8_Isolate_Exit(isolate);
        {
            const scope = v8_engine.JsScope.init(instance.ctx) orelse return;
            defer scope.deinit();
            var processor = xhr.response.ResponseProcessor.init(getXHRState(instance));
            processor.handleTimeout();
        }
        @import("html").worker_v8_context.finishTaskIn(isolate);
    }

    /// Arm the timeout for a fetch that began at `started_ms`, `timeout_ms`
    /// after it began - at once if that is already past. 0 is no timeout.
    fn armTimeout(self: *PendingFetch, timeout_ms: u32) void {
        self.disarmTimeout();
        if (timeout_ms == 0 or self.cancelled or self.complete) return;
        const timer = self.instance.ctx.getOptionalTimer() orelse return;
        const elapsed = clock.monotonicMillis() - self.started_ms;
        const remaining: u64 = @intCast(@max(0, @as(i64, timeout_ms) - elapsed));
        const id = timer.setTimeout(remaining, timedOut, self);
        if (id == 0) return;
        self.timeout_timer = timer;
        self.timeout_id = id;
    }

    fn disarmTimeout(self: *PendingFetch) void {
        if (self.timeout_id == 0) return;
        if (self.timeout_timer) |timer| _ = timer.clearTimeout(self.timeout_id);
        self.timeout_id = 0;
    }

    /// Unhook from the XMLHttpRequest, which is still there.
    fn detach(self: *PendingFetch) void {
        const internal = getInternal(self.instance);
        if (internal.pending_fetch == self) internal.pending_fetch = null;
    }

    /// Free once nothing holds this: the fetch has let go, no task is
    /// queued, and there is nothing more to read.
    fn maybeFree(self: *PendingFetch) void {
        if (self.fetch_holds or self.task_queued) return;
        if (!self.cancelled and !self.complete) return;
        self.releasePipe();
        self.keep_alive.release();
        self.disarmTimeout();
        if (self.outcome) |outcome| freeOutcome(outcome);
        if (self.body) |b| self.allocator.free(b);
        self.allocator.destroy(self);
    }

    fn freeOutcome(outcome: fetch_mod.algorithms.FetchError!fetch_mod.algorithms.FetchResult) void {
        var result = outcome catch return;
        result.deinit();
    }
};

/// Step 5: "If one or more event listeners are registered on this's upload
/// object, then set this's upload listener flag." An event handler's listener
/// is one of them, so `xhr.upload.onprogress = f` and
/// `xhr.upload.addEventListener("progress", f)` both count - the second used
/// not to, when the handlers lived outside the listener list.
fn uploadHasListeners(instance: *runtime.Instance) bool {
    const upload = uploadObjectIfCreated(instance) orelse return false;
    // Every listener, whether `addEventListener` or an event handler added it.
    for (EventTargetImpl.getEventListenersForType(upload, "")) |listener| {
        if (!listener.removed) return true;
    }
    return false;
}

/// The bytes of the `body` argument.
///
/// Spec step 4 covers Document, Blob, BufferSource, FormData, URLSearchParams
/// and USVString. Only the string form is handled here; the rest need the body
/// extraction algorithm, and returning null for them sends no body rather than
/// sending the wrong one.
fn extractBodyBytes(instance: *runtime.Instance, body: webidl.Opt(?runtime.JSValue)) ?[]const u8 {
    if (!body.wasPassed()) return null;
    const value = body.value orelse return null;

    return switch (value) {
        .undefined, .null => null,
        .string => |sv| if (sv.data.len > 0) sv.data else null,
        .handle => |h| blk: {
            // A JS string arrives as a handle when it was not converted up
            // front. Anything else is a body type we cannot extract yet.
            const engine = instance.ctx.getEngine() orelse break :blk null;
            const engine_ctx = instance.ctx.getEngineContext() orelse break :blk null;
            const is_string = engine.isString orelse break :blk null;
            if (!is_string(h.ptr)) {
                log.debug("send() body is a type whose extraction is not implemented", .{});
                break :blk null;
            }
            const extract = engine.extractString orelse break :blk null;
            break :blk extract(engine_ctx, h.ptr, instance.ctx.allocator) catch null;
        },
        else => null,
    };
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
