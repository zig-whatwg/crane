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

/// The parent interface's generated State. `xhr.onload` and friends are
/// declared on XMLHttpRequestEventTarget, so the fields live here for BOTH an
/// XMLHttpRequest and an XMLHttpRequestUpload; `instance.getState` of this type
/// reaches them on either, because `FlattenedState` puts `base` first.
///
/// This reads the generated INTERFACE's State, not the sibling impl - the same
/// thing every impl does when it touches `state.base.own.*`.
const EventTargetState = interfaces.XMLHttpRequestEventTarget.State;

comptime {
    // The aliasing above is load-bearing and silent if it ever stops holding:
    // a wrong offset would read some other field as a function pointer and
    // call it. Pin it here rather than discover it in a crash.
    std.debug.assert(@offsetOf(XMLHttpRequest.State, "base") == 0);
    std.debug.assert(@offsetOf(interfaces.XMLHttpRequestUpload.State, "base") == 0);
    std.debug.assert(@offsetOf(EventTargetState, "base") == 0);
}

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

    /// The request body, owned for the lifetime of one send().
    ///
    /// An async send() hands the bytes to an event-loop TASK, which runs after
    /// `call_send` has returned and the WebIDL conversion layer has freed its
    /// copy of the argument. Borrowing it would be a use-after-free by the time
    /// the request goes out.
    pending_body: ?[]u8,

    pub fn initState(allocator: std.mem.Allocator) InternalState {
        return .{
            .xhr_state = XMLHttpRequestState.init(allocator),
            .allocator = allocator,
            .onreadystatechange = null,
            .isolate = null,
            .pending_body = null,
        };
    }

    fn releasePendingBody(self: *InternalState) void {
        if (self.pending_body) |b| {
            self.allocator.free(b);
            self.pending_body = null;
        }
    }

    pub fn deinitState(self: *InternalState) void {
        // Dispose V8 Global handle to prevent memory leaks
        v8_engine.disposeOptionalGlobalHandle(&self.onreadystatechange);
        self.releasePendingBody();
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
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &XMLHttpRequest.vtable, ctx);
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
        // Steps 5 and 6: ArrayBuffer and Blob.
        //
        // TODO: both need a real object - `createArrayBuffer` for the first and
        // a Blob instance for the second. Returning the bytes as a string would
        // be a worse answer than null, because script would not be able to tell
        // it apart from a text response.
        .arraybuffer, .blob => {
            _ = allocator;
            log.debug("response type {s} is not implemented", .{@tagName(xhr_state.response_type)});
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
/// Creates a Global handle from the passed value so it survives past the setter's HandleScope.
pub fn set_onreadystatechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const internal = getInternal(instance);

    // Dispose old Global handle first to prevent memory leaks
    v8_engine.disposeOptionalGlobalHandle(&internal.onreadystatechange);

    // Extract Global handle from tagged pointer (V8 conversion already created the Global)
    if (value) |handler| {
        const untagged = v8_engine.pointer_tag.untagPointer(@ptrCast(handler));
        if (untagged.tag == .global_handle or untagged.tag == .untagged) {
            internal.onreadystatechange = v8_engine.GlobalHandle{ .ptr = @ptrCast(@alignCast(untagged.ptr)) };
        } else {
            internal.onreadystatechange = null;
        }
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
    const internal = getInternal(instance);

    // Steps 5-6: "encoding-parsing a URL url, relative to this's relevant
    // settings object". The base URL is the relevant global object's associated
    // Document's URL.
    const base_url = relevantBaseURL(instance);
    defer if (base_url) |b| internal.allocator.free(b);

    // Call the open algorithm
    open_algo.open(
        xhr_state,
        method,
        url,
        true, // async = true (default)
        null, // username
        null, // password
        base_url,
    ) catch |err| {
        return switch (err) {
            open_algo.OpenError.SecurityError => error.SecurityError,
            open_algo.OpenError.InvalidURL => error.SyntaxError,
            open_algo.OpenError.InvalidMethod => error.SyntaxError,
            open_algo.OpenError.InvalidState => error.InvalidStateError,
            open_algo.OpenError.OutOfMemory => error.OutOfMemory,
        };
    };

    // Step 12: Fire an event named readystatechange at this.
    fireReadyStateChangeEvent(instance);
}

/// This's relevant settings object's API base URL: the relevant global object's
/// associated Document's URL.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#api-base-url
///
/// Returns an owned string, or null when there is no Document to ask - a bare
/// realm, or a worker, where a relative URL then legitimately fails to parse.
/// Same shape as `DOMParser.call_parseFromString`, and it goes through
/// `interfaces`, never another impl.
fn relevantBaseURL(instance: *runtime.Instance) ?[]const u8 {
    const realm = instance.ctx.realm orelse return null;
    const window_ptr = realm.global_object orelse return null;
    const window_instance: *runtime.Instance = @ptrCast(@alignCast(window_ptr));

    const doc = interfaces.Window.get_document(window_instance) catch return null;
    return interfaces.Document.get_URL(doc) catch null;
}

// =============================================================================
// Events
//
// Spec: https://xhr.spec.whatwg.org/#events
//
// `src/xhr/` cannot reach JavaScript - it has no `runtime` import and no V8
// link. It fires events through an `EventSink`, a two-field vtable, and this is
// the implementation of it. Each event goes to both places a listener can be:
//
//   1. the event listener list, via `EventTarget.dispatchEvent` - this is what
//      `xhr.addEventListener("load", f)` registers into;
//   2. the event handler IDL attribute (`xhr.onload = f`), which Crane keeps in
//      a separate field rather than as a listener.
//
// `EventTarget.invokeIdlEventHandler` does (2) for HTMLElement and Window only,
// by looking in those two impls' own maps, so an XHR handler is invisible to
// it. Hence the second half here.
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

    fireAt(target_instance, instance, event_type, progress);
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

/// Build the event object and deliver it to both kinds of listener.
fn fireAt(
    target: *runtime.Instance,
    xhr_instance: *runtime.Instance,
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

    // (1) the event listener list.
    _ = interfaces.EventTarget.call_dispatchEvent(target, event) catch |err| {
        log.debug("dispatch of {s} failed: {s}", .{ name, @errorName(err) });
    };

    // (2) the event handler IDL attribute.
    invokeIdlHandler(target, xhr_instance, event, event_type);
}

/// The raw, still-tagged handler pointer for `event_type` on `target`.
///
/// `readystatechange` is XMLHttpRequest's own attribute and is stored as a
/// Global handle on the impl's internal state; the other seven come from
/// XMLHttpRequestEventTarget and are stored in the generated State as
/// `typedefs.EventHandler` - a `*const fn` that is really a TAGGED V8 Global
/// handle pointer, because that is what the conversion layer produces for a
/// callback function.
fn rawIdlHandler(
    target: *runtime.Instance,
    xhr_instance: *runtime.Instance,
    event_type: XHREventType,
) ?*anyopaque {
    if (event_type == .readystatechange) {
        // Only the XHR itself has onreadystatechange.
        if (target != xhr_instance) return null;
        const internal = getInternal(xhr_instance);
        const global = internal.onreadystatechange orelse return null;
        return @ptrCast(global.ptr);
    }

    const state = target.getState(EventTargetState);
    const handler: typedefs.EventHandler = switch (event_type) {
        .loadstart => state.own.onloadstart,
        .progress => state.own.onprogress,
        .abort => state.own.onabort,
        .@"error" => state.own.onerror,
        .load => state.own.onload,
        .timeout => state.own.ontimeout,
        .loadend => state.own.onloadend,
        .readystatechange => unreachable,
    };

    // Read the bits WITHOUT materialising the pointer. The stored address has
    // tag bits in its low two bits, so it is deliberately misaligned, and
    // @ptrCast/@alignCast on it panics with "incorrect alignment" in a safe
    // build. A byte copy has no alignment check. Same approach as
    // `MessagePort.zig` and `HTMLElement.getEventHandler`.
    const bytes = @as(*const [@sizeOf(typedefs.EventHandler)]u8, @ptrCast(&handler)).*;
    const addr: usize = @bitCast(bytes);
    if (addr == 0) return null;
    return @ptrFromInt(addr & ~@as(usize, 0x3) | (addr & 0x3));
}

/// Call `xhr.onload = f` and friends with the event.
///
/// The previous version of this - `fireReadyStateChangeEvent` - crashed:
///
///     panic: load of misaligned address ...
///     v8_Value_IsFunction -> PersistentBase<Value>::Get(isolate)
///
/// It did `global.get(isolate)` to get a LOCAL and passed that to
/// `v8_Value_IsFunction`, which takes a `Global<Value>*` and calls `Get` on it.
/// A Local reinterpreted as a Global is read at the wrong offset. Pass the
/// Global straight through, as `EventTarget.invokeIdlEventHandler` does.
fn invokeIdlHandler(
    target: *runtime.Instance,
    xhr_instance: *runtime.Instance,
    event: *runtime.Instance,
    event_type: XHREventType,
) void {
    const raw = rawIdlHandler(target, xhr_instance, event_type) orelse return;

    const untagged = pointer_tag.untagPointer(raw);
    if (untagged.tag != .global_handle and untagged.tag != .untagged) return;

    const callback_global: *v8_engine.ffi.Value = @ptrCast(@alignCast(untagged.ptr));

    const engine_ctx = target.ctx.engine_ctx orelse return;
    const v8_context: *v8_engine.ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const v8_isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return;

    // A Local handle is only valid inside a HandleScope, and wrapping the event
    // creates several.
    const handle_scope = v8_engine.ffi.v8_HandleScope_New(v8_isolate) orelse return;
    defer v8_engine.ffi.v8_HandleScope_Dispose(handle_scope);

    if (!v8_engine.ffi.v8_Value_IsFunction(callback_global)) return;

    // Wrap with the event's ACTUAL interface, so a ProgressEvent handler sees
    // `.loaded` and `.total` rather than a bare Event.
    const interface_name = v8_engine.template_registry.getInstanceInterfaceName(event);
    const event_global = v8_engine.template_registry.wrapInstanceAsV8Object(
        event,
        interface_name,
        v8_isolate,
        v8_context,
    ) catch return;

    const undefined_recv = v8_engine.ffi.v8_Undefined(v8_isolate);
    var args: [1]*v8_engine.ffi.Value = .{@ptrCast(event_global)};

    const result = v8_engine.ffi.v8_Function_Call_Safe(
        callback_global,
        v8_context,
        @ptrCast(undefined_recv),
        1,
        @ptrCast(&args),
    );
    v8_engine.ffi.v8_FreeFunctionCallResult(result);
}

/// Fire readystatechange at this XHR.
fn fireReadyStateChangeEvent(instance: *runtime.Instance) void {
    fireAt(instance, instance, .readystatechange, null);
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
    xhr.abort.abort(xhr_state);
}

/// Operation: send
///
/// Spec: https://xhr.spec.whatwg.org/#the-send()-method
///
/// ## Async is a task, not a thread
///
/// `fetch.algorithms.fetch` blocks. Running it inline for an async request
/// would fire `loadstart` .. `loadend` BEFORE `send()` returned, so
///
///     xhr.send();
///     xhr.onload = () => { ... };   // assigned after send(), as tests do
///
/// would miss every event. So steps 1-10, which script can observe immediately
/// (a second `send()` must throw), run inline, and step 11 - loadstart, the
/// fetch and everything downstream - runs from an event-loop TASK.
///
/// That gets ordering right for the common case and is still wrong in one
/// respect: the task occupies the loop for the duration of the transfer, so two
/// concurrent XHRs complete in the order they were sent rather than the order
/// the server answers. Fixing that needs an incremental fetch backend, not a
/// change here.
///
/// With no event loop - a bare realm, or a unit test - it falls back to running
/// inline, which is better than dropping the request.
pub fn call_send(instance: *runtime.Instance, body: webidl.Opt(?runtime.JSValue)) anyerror!void {
    const xhr_state = getXHRState(instance);
    const internal = getInternal(instance);

    // Step 5: If one or more event listeners are registered on this's upload
    // object, then set this's upload listener flag.
    xhr_state.upload_listener_flag = uploadHasListeners(instance);

    // Own the body for the life of the request: an async send() reads it from a
    // task, long after the conversion layer has freed its copy.
    internal.releasePendingBody();
    if (extractBodyBytes(instance, body)) |bytes| {
        internal.pending_body = internal.allocator.dupe(u8, bytes) catch return error.OutOfMemory;
    }

    installEventSink(instance);

    // Steps 1-10, inline and synchronously observable.
    const effective_body = send_algo.sendPrologue(xhr_state, internal.pending_body) catch |err| {
        internal.releasePendingBody();
        return err;
    };

    // Step 12: a sync request blocks here, which is what sync MEANS.
    if (xhr_state.synchronous_flag) {
        defer internal.releasePendingBody();
        send_algo.sendDispatch(xhr_state, effective_body) catch |err| {
            return switch (err) {
                error.TimeoutError => error.TimeoutError,
                error.NetworkError => error.NetworkError,
                else => err,
            };
        };
        return;
    }

    // Step 11, from a task.
    const event_loop = instance.ctx.getOptionalEventLoop() orelse {
        defer internal.releasePendingBody();
        send_algo.sendDispatch(xhr_state, effective_body) catch |err| {
            log.debug("inline send failed: {s}", .{@errorName(err)});
        };
        return;
    };

    const task = internal.allocator.create(SendTask) catch return error.OutOfMemory;
    task.* = .{ .instance = instance, .allocator = internal.allocator };
    event_loop.queueTask(.{ .callback = &runSendTask, .context = @ptrCast(task) });
}

/// Context for the deferred step 11.
///
/// It holds only the INSTANCE, never the body slice: the body lives in
/// `InternalState.pending_body`, so `open()` or `abort()` between queueing and
/// running cannot leave this task pointing at freed bytes.
const SendTask = struct {
    instance: *runtime.Instance,
    allocator: std.mem.Allocator,
};

fn runSendTask(context: ?*anyopaque) void {
    const task: *SendTask = @ptrCast(@alignCast(context orelse return));
    const instance = task.instance;
    const allocator = task.allocator;
    defer allocator.destroy(task);

    const xhr_state = getXHRState(instance);
    const internal = getInternal(instance);
    defer internal.releasePendingBody();

    // Step 11.6, hoisted: between `send()` returning and this task running,
    // script has had a turn. `abort()` unsets the send() flag and `open()`
    // resets the state, and either means this request is no longer wanted.
    if (!xhr_state.send_flag or xhr_state.ready_state != .OPENED) return;

    send_algo.sendDispatch(xhr_state, internal.pending_body) catch |err| {
        log.debug("async send failed: {s}", .{@errorName(err)});
    };
}

/// Step 5: "If one or more event listeners are registered on this's upload
/// object, then set this's upload listener flag."
///
/// KNOWN GAP: this sees the event handler IDL attributes
/// (`xhr.upload.onprogress = f`) but NOT `xhr.upload.addEventListener(...)`,
/// because the event listener list lives in EventTarget's private registry and
/// no interface exposes "does this target have listeners". The flag only
/// affects whether upload progress events fire and whether a CORS preflight is
/// forced, so the failure mode is missing upload events, not wrong ones.
fn uploadHasListeners(instance: *runtime.Instance) bool {
    const upload = uploadObjectIfCreated(instance) orelse return false;
    const state = upload.getState(EventTargetState);
    inline for (.{
        state.own.onloadstart,
        state.own.onprogress,
        state.own.onabort,
        state.own.onerror,
        state.own.onload,
        state.own.ontimeout,
        state.own.onloadend,
    }) |handler| {
        const bytes = @as(*const [@sizeOf(typedefs.EventHandler)]u8, @ptrCast(&handler)).*;
        const addr: usize = @bitCast(bytes);
        if (addr != 0) return true;
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
