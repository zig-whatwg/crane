//! Implementation for XMLHttpRequest interface
//!
//! WHATWG XHR Standard: https://xhr.spec.whatwg.org/
//!
//! This module connects the WebIDL interface to the XHR algorithm implementations.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
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
const response_algo = xhr.response;
const XHREventType = xhr.XHREventType;
const EventTargetKind = xhr.EventTargetKind;
const ProgressEventData = xhr.ProgressEventData;

const log = std.log.scoped(.xhr);
const clock = @import("clock");
const fetch_mod = @import("fetch");

const same_object = @import("same_object.zig");
const fetch_body = @import("fetch_body.zig");
const blob_bytes = @import("dom").blob_bytes;
const global_settings = @import("dom").global_settings;
const document_fetches = @import("dom").document_fetches;
const infra = @import("infra");
const encoding = @import("encoding");

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

    /// The asynchronous send()'s fetch, from send() until its task has run.
    pending_fetch: ?*PendingFetch,

    /// Keeps `this.upload` alive for as long as this XHR's wrapper - an edge
    /// (same_object.Traced), as Blink's XMLHttpRequest::Trace visits
    /// `upload_`. The upload object carries the upload event handlers, which
    /// script sets on it and then never touches again; an XHR whose fetch is
    /// pending keeps its own wrapper (`keep_alive`), and with it this edge.
    upload_edge: same_object.Traced,

    /// This's response object is an object - the ArrayBuffer, Blob or JSON
    /// value `response` made - kept so every later read returns that same
    /// object: by an edge from the XHR's wrapper (`response_slot`,
    /// engine.traceValue), never a root. (Null and failure are
    /// xhr_state.response_object's.) Held as a root (an engine.Owned), a JSON
    /// response of a frame's XHR kept the frame's realm for as long as the
    /// XHR's instance lived, whatever script held.
    has_response_value: bool = false,

    pub fn initState(allocator: std.mem.Allocator) InternalState {
        return .{
            .xhr_state = XMLHttpRequestState.init(allocator),
            .allocator = allocator,
            .pending_fetch = null,
            .upload_edge = .{ .slot = .{ .name = "upload" } },
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

    /// Set this's response object to null (open() step 11). `owner`: the
    /// XHR this state is.
    fn releaseResponseValue(self: *InternalState, owner: *runtime.Instance) void {
        if (!self.has_response_value) return;
        self.has_response_value = false;
        engine.forgetTracedChild(owner, response_slot);
    }

    /// `owner`: the XHR this state is, whose edge to its upload object goes.
    pub fn deinitState(self: *InternalState, owner: *runtime.Instance) void {
        // The upload object's lifetime is the wrapper cache's from here.
        self.upload_edge.release(owner);
        self.releaseResponseValue(owner);
        // Before anything else: a fetch in flight, or its queued task, would
        // otherwise reach an instance that is going away.
        self.cancelFetch();
        self.xhr_state.deinit();
    }
};

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // "Abort a document" reaches a send()'s fetches through `live_pending`.
    document_fetches.install(&abortFetchesIn);
}

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
        internal.deinitState(instance);
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
    internal.upload_edge.hold(instance, upload);

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

    // Step 4: If this's response object is non-null, then return it - the
    // same object every time. This XHR keeps holding it; the binding gets a
    // hold of its own.
    const internal = getInternal(instance);
    if (internal.has_response_value) {
        if (engine.tracedValue(instance, response_slot)) |value| return value.take();
    }
    // What the steps below set this's response object to: OWNED until kept.
    var made: engine.Owned = undefined;

    switch (xhr_state.response_type) {
        // Step 8: the JSON response.
        .json => {
            // 8.2. If this's response's body is null, then return null. A
            //      null body received no bytes, which 8.3's parse rejects -
            //      the same null, without asking a response this XHR may
            //      already have let go of its body.
            // 8.3. Let jsonObject be the result of running parse JSON from
            //      bytes on this's received bytes. If that threw an
            //      exception, then return null.
            var parse: JsonParse = .{ .realm = instance.ctx, .bytes = xhr_state.received_bytes.items };
            const thrown = engine.completionOf(instance.ctx, JsonParse.steps, &parse) catch return .{ .null = {} };
            if (thrown) |exception| {
                exception.release();
                return .{ .null = {} };
            }
            // 8.4. Set this's response object to jsonObject.
            made = parse.value orelse return .{ .null = {} };
        },
        // Step 5: the ArrayBuffer response. "Set this's response object to a
        // new ArrayBuffer object representing this's received bytes. If this
        // throws an exception, then set this's response object to failure and
        // return null."
        .arraybuffer => {
            made = engine.createArrayBuffer(instance.ctx, xhr_state.received_bytes.items) catch {
                xhr_state.response_object = .failure;
                return .{ .null = {} };
            };
        },
        // Step 6: "set this's response object to a new Blob object
        // representing this's received bytes with type set to the result of
        // get a final MIME type for this."
        .blob => {
            const mime_type = try response_algo.finalMimeTypeBytes(allocator, xhr_state);
            defer allocator.free(mime_type);
            const blob = try blob_bytes.create(instance.ctx, xhr_state.received_bytes.items, mime_type);
            made = engine.retainValue(instance.ctx, .{ .instance = blob }) catch |err| {
                blob.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(blob));
                return err;
            };
        },
        // Step 7: the document response, which needs the HTML/XML parser.
        .document => return .{ .null = {} },
        .empty, .text => unreachable, // handled by step 1
    }

    // This's response object is kept by the XHR's wrapper from here.
    engine.traceValue(instance, made.value, response_slot);
    internal.has_response_value = true;
    // Step 9: Return this's response object (the hold made above, now the
    // binding's own).
    return made.take();
}

/// Where an XHR keeps its response object (Blink: XMLHttpRequest's
/// response_array_buffer_, response_blob_ and json are Members it traces).
const response_slot: engine.TracedSlot = .{ .name = "response" };

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

    // Text response steps 2-3: the label - the final encoding's, or an XML
    // response's declared one.
    const allocator = instance.ctx.allocator;
    const label = try response_algo.textResponseEncodingLabel(allocator, xhr_state);
    defer if (label) |l| allocator.free(l);
    // 4. If charset is null, then set charset to UTF-8 (as for a label that
    //    names no encoding: "get a final encoding" steps 6-7).
    const charset = if (label) |l| encoding.getEncoding(l) orelse &encoding.encoding.UTF_8 else &encoding.encoding.UTF_8;
    // 5. Return the result of running decode on xhr's received bytes using
    //    charset - a BOM overrides it. OWNED, as UTF-8: the interface layer
    //    frees what a USVString getter returns.
    const code_units = encoding.hooks.decode(allocator, xhr_state.received_bytes.items, charset) catch return error.OutOfMemory;
    defer allocator.free(code_units);
    // A decoder's output is scalar values: no surrogate is unpaired.
    return std.unicode.utf16LeToUtf8Alloc(allocator, code_units) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => unreachable,
    };
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
    // settings object". Borrowed from the realm - not ours to free.
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
    const internal = getInternal(instance);
    internal.cancelFetch();
    // Step 11: "Set this's response object to null" - the object half of it;
    // open_algo reset the rest.
    internal.releaseResponseValue(instance);

    // Step 12: If this's state is not opened, set it to opened and fire an
    // event named readystatechange at this.
    if (!was_opened) fireReadyStateChangeEvent(instance);
}

/// Record this XHR's relevant settings object - its realm's global
/// object's - in `state` as send()'s request's client. A realm with no such
/// global leaves the request's origin and referrer "client".
fn setClient(instance: *runtime.Instance, state: *XMLHttpRequestState) !void {
    const record = instance.ctx.getRealm() orelse return;
    const raw = record.global_object orelse return;
    const global: *runtime.Instance = @ptrCast(@alignCast(raw));
    var client = try global_settings.requestClient(global);
    defer client.deinit();
    try state.setClient(client.request);
}

/// "Parse JSON from bytes", as a completion: the response getter returns
/// null for the exception it throws rather than letting it propagate.
const JsonParse = struct {
    realm: runtime.Context,
    bytes: []const u8,
    /// OWNED, once parsed.
    value: ?engine.Owned = null,

    fn steps(data: ?*anyopaque) engine.Error!void {
        const self: *JsonParse = @ptrCast(@alignCast(data.?));
        self.value = try engine.parseJsonToValue(self.realm, self.bytes);
    }
};

/// Is the current global object a Window?
///
/// open() step 9 and the `timeout` and `responseType` setters restrict
/// synchronous requests in a Window only - a worker may block. The current
/// global object is the current realm's, and names its own interface.
fn currentGlobalIsWindow() bool {
    const current = engine.currentRealm() orelse return false;
    const record = current.getRealm() orelse return false;
    const raw = record.global_object orelse return false;
    const global: *runtime.Instance = @ptrCast(@alignCast(raw));
    return std.mem.eql(u8, global.vtable.name, "Window");
}

/// This's relevant settings object's API base URL.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#api-base-url
///
/// The realm's document URL: a Window's navigation records its document's
/// URL there, and a worker its script URL, which is a worker's API base URL.
/// (Not the Document's or the Location's: in a WPT [window] run those were
/// measured as '' and 'about:blank'.)
///
/// Returns a BORROWED slice owned by the realm, so the caller must not free
/// it.
fn relevantBaseURL(instance: *runtime.Instance) ?[]const u8 {
    const url = instance.ctx.documentUrl() orelse return null;
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

    // Every listener, the event handlers among them. The user agent fires
    // these, so they are trusted (DOM "fire an event": isTrusted true);
    // dispatchEvent() is script's, and resets it. The target - this XHR or
    // its upload object - is an EventTarget, this impl's ancestor.
    _ = EventTargetImpl.dispatchTrusted(target, event) catch |err| {
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
    // Wrapped => the engine owns it from here.
    if (engine.hasWrapper(event)) return;

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
/// With no event loop - a bare realm, a unit test's - it waits inline, which
/// is better than dropping the request.
pub fn call_send(instance: *runtime.Instance, body: webidl.Opt(?runtime.JSValue)) anyerror!void {
    const xhr_state = getXHRState(instance);
    const internal = getInternal(instance);

    // The argument, converted to (Document or XMLHttpRequestBodyInit)? as
    // the binding would before the method's steps run - its ToString can run
    // script - and, but for a Document, extracted. Owned for the life of the
    // request: an asynchronous request's fetch - a redirect re-sends it -
    // runs long after, and a handler that runs during this send() can send
    // again, with a body of its own.
    const allocator = internal.allocator;
    var send_body = try SendBody.convert(instance, body, allocator);
    defer if (send_body) |*b| b.deinit();

    installEventSink(instance);
    // The request's client is this's relevant settings object: its origin
    // is the request's (Fetch "fetch" step 13), and its cookie jar the one
    // the request's cookies come from and go to.
    setClient(instance, xhr_state) catch return error.OutOfMemory;

    // Steps 1-3, and 7-10, inline and synchronously observable. Step 3 (GET
    // and HEAD) gives back null.
    const owned_body: ?[]u8 = if (send_body) |*b| b.takeBytes() else null;
    var body_taken = false;
    defer if (!body_taken) if (owned_body) |b| allocator.free(b);
    const effective_body = try send_algo.sendPrologue(xhr_state, owned_body);

    // Step 4: the request body's Content-Type, in this's author request
    // headers.
    if (effective_body != null) if (send_body) |*b| try b.setContentType(xhr_state);

    // Step 5: If one or more event listeners are registered on this's upload
    // object, then set this's upload listener flag.
    xhr_state.upload_listener_flag = uploadHasListeners(instance);

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

    // A realm with no event loop to run the fetch's task on - a bare realm, a
    // unit test's - waits for it here, which is better than dropping the
    // request. (Every window and worker realm has one: a worker's own.)
    if (instance.ctx.getOptionalEventLoop() == null) {
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
        .body = if (effective_body != null) owned_body else null,
        .started_ms = clock.monotonicMillis(),
    };
    pending.fetch = fetch_mod.algorithms.AsyncFetch.startStreaming(
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
    // "Abort a document" reaches it through `live_pending`.
    live_pending.append(std.heap.c_allocator, pending) catch {};

    // Step 11.11: If this's timeout is not 0, end the fetch once it has run
    // that long.
    pending.armTimeout(xhr_state.timeout);
}

/// Every PendingFetch on this thread not yet freed, for `abortFetchesIn`.
threadlocal var live_pending: std.ArrayListUnmanaged(*PendingFetch) = .empty;

/// HTML "abort a document" step 2, for this interface: the request of every
/// XMLHttpRequest whose relevant realm is `realm` - a document of it is being
/// destroyed ("destroy a document" step 2) - is canceled, "discarding any
/// tasks queued for them, and discarding any further data received from the
/// network for them". No request error steps run and no event fires - "destroy
/// a document" step 7 removes the document's queued tasks without running
/// them - and the object keeps its state (XHR defines no steps of its own for
/// a document that stops being fully active). Its fetch is terminated
/// (Fetch "terminate", as a fetch group's termination does), and a response
/// already in hand is dropped with its task. Installed into
/// dom.document_fetches; HTMLIFrameElement's removing steps call it for every
/// document "destroy a child navigable" destroys.
///
/// xhr/open-url-multi-window-4.htm expects `error` and `loadend` instead,
/// after an XHR proposal (whatwg/xhr#3) that was never adopted; Edge, like
/// this, fires nothing (wpt.fyi: TIMEOUT).
fn abortFetchesIn(realm: runtime.Context) void {
    // Backwards: a cancel may free its entry, which swapRemove replaces with
    // one already visited.
    var i = live_pending.items.len;
    while (i > 0) {
        i -= 1;
        if (i >= live_pending.items.len) continue;
        const pending = live_pending.items[i];
        if (pending.cancelled or pending.instance.ctx != realm) continue;
        const internal = getInternal(pending.instance);
        if (internal.pending_fetch == pending) internal.cancelFetch() else pending.cancel();
    }
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
    /// A task of this request is on the stack (`run`, `timedOut`): it frees
    /// this when it returns. Script it runs can end the request - abort(),
    /// open(), or removing the frame whose document owns it
    /// (`abortFetchesIn`) - and `cancel` must not free it under the task.
    running: bool = false,
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
    /// loop - a window's, or a worker's own. (send() takes this path only for
    /// a realm that has one.)
    fn queueTask(self: *PendingFetch) void {
        if (self.task_queued or self.cancelled) return;
        const loop = self.instance.ctx.getOptionalEventLoop() orelse return;
        self.task_queued = true;
        loop.queueTask(.{ .callback = run, .context = self, .drop = drop });
    }

    /// The task: send() steps 11.9 onwards - the response's headers once,
    /// then whatever of its body has arrived.
    fn run(context: ?*anyopaque) void {
        const self: *PendingFetch = @ptrCast(@alignCast(context.?));
        self.task_queued = false;
        if (self.cancelled) return self.maybeFree();
        // A task runs from the event loop, not from script: it enters the
        // realm itself (a worker's, whose agent is not the page's) and ends
        // as a task there does.
        self.running = true;
        engine.runTaskInRealm(self.instance.ctx, taskSteps, self) catch {};
        self.running = false;
        self.maybeFree();
    }

    /// The task's steps, in the XHR's realm.
    fn taskSteps(context: ?*anyopaque) void {
        const self: *PendingFetch = @ptrCast(@alignCast(context.?));
        const state = getXHRState(self.instance);
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
            f.terminateWith(.{ .kind = .aborted });
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

    /// How long a timeout waits, at most, for a response that has started
    /// arriving (`async_fetch.catchUp`).
    const catch_up_budget_ms = 20;

    /// Step 11.11's timer: the fetch has run for this's timeout. Set the
    /// timed out flag and terminate the fetch; its processResponse would then
    /// run the timeout steps, which this does instead.
    fn timedOut(context: ?*anyopaque) void {
        const self: *PendingFetch = @ptrCast(@alignCast(context.?));
        self.timeout_id = 0;
        // The response may be in and unread: a long task can hold the loop
        // past the deadline with it waiting in the socket. The fetch and the
        // timer race in parallel, and the fetch finished first, so give the
        // network its step before calling it a timeout - and, INTERIM, while
        // the response is arriving, the reads a network thread would have
        // made during the long task (async_fetch.catchUp, bounded, inert).
        // (Only while the realm lives: a sweep inside the pump would end this
        // very call.)
        if (alive(self)) {
            _ = fetch_mod.algorithms.async_fetch.pump();
            fetch_mod.algorithms.async_fetch.catchUp(&self.fetch, catch_up_budget_ms);
        }
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
            f.terminateWith(.{ .kind = .network });
            self.fetch_holds = false;
        }
        defer self.maybeFree();
        // The timer's task: in the XHR's realm, ended as a task there is.
        self.running = true;
        defer self.running = false;
        engine.runTaskInRealm(instance.ctx, timeoutSteps, instance) catch {};
    }

    /// The timeout steps, in the XHR's realm.
    fn timeoutSteps(context: ?*anyopaque) void {
        const instance: *runtime.Instance = @ptrCast(@alignCast(context.?));
        var processor = xhr.response.ResponseProcessor.init(getXHRState(instance));
        processor.handleTimeout();
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
        if (self.fetch_holds or self.task_queued or self.running) return;
        if (!self.cancelled and !self.complete) return;
        for (live_pending.items, 0..) |p, i| {
            if (p != self) continue;
            _ = live_pending.swapRemove(i);
            break;
        }
        // Its capacity goes with its last entry: a worker thread that ends leaves none of it.
        if (live_pending.items.len == 0) live_pending.clearAndFree(std.heap.c_allocator);
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

/// send()'s `body`: the argument converted to (Document or
/// XMLHttpRequestBodyInit)? (WebIDL 3.2.24) and, but for a Document, safely
/// extracted (Fetch): the request body's bytes and bodyWithType's type.
const SendBody = struct {
    allocator: std.mem.Allocator,
    kind: Kind,
    /// The request body, owned until taken.
    bytes: ?[]u8,
    /// extractedContentType, owned, or null.
    content_type: ?[]u8 = null,

    const Kind = enum { usvstring, other };

    fn deinit(self: *SendBody) void {
        if (self.bytes) |b| self.allocator.free(b);
        if (self.content_type) |t| self.allocator.free(t);
    }

    /// The request body, which is the caller's from here.
    fn takeBytes(self: *SendBody) []u8 {
        const b = self.bytes.?;
        self.bytes = null;
        return b;
    }

    /// Null for a null (or undefined) body, and - for now - a Document.
    fn convert(instance: *runtime.Instance, argument: webidl.Opt(?runtime.JSValue), allocator: std.mem.Allocator) !?SendBody {
        if (!argument.wasPassed()) return null;
        const value = argument.value orelse return null;
        const realm = instance.ctx;
        switch (value) {
            .undefined, .null => return null,
            // A string primitive, as the binding converted it: WTF-8, a lone
            // surrogate in its three-byte form. USVString makes each one
            // U+FFFD.
            .string => |text| {
                const bytes = try allocator.dupe(u8, text.data);
                infra.string.replaceLoneSurrogatesWtf8(bytes);
                return try usvString(allocator, bytes);
            },
            .boolean, .number => return try usvString(allocator, try engine.convertToUSVString(realm, value, allocator)),
            .handle, .instance => {},
        }
        switch (engine.typeOf(realm, value)) {
            .undefined, .null => return null,
            else => {},
        }
        // A platform object of one of the union's interfaces is that member.
        // Any other falls through to the string it converts to.
        if (engine.convertToPlatformObject(realm, value)) |object| {
            // TODO: a Document's request body is the document serialized,
            // converted and UTF-8 encoded (step 4.2), and its Content-Type
            // text/html or application/xml (4.6); until its serializer is
            // reachable here, it sends no body, as before.
            if (object.stateAs(interfaces.Document.State) != null) return null;
            if (object.stateAs(interfaces.Blob.State) != null) return try extracted(allocator, .{ .blob = object });
            if (object.stateAs(interfaces.FormData.State) != null) return try extracted(allocator, .{ .form_data = object });
            if (object.stateAs(interfaces.URLSearchParams.State) != null) return try extracted(allocator, .{ .urlsearch_params = object });
        }
        // BufferSource: a copy of the bytes held by it; no type.
        if (try engine.getCopyOfBufferSourceBytes(realm, value, allocator)) |bytes| {
            return .{ .allocator = allocator, .kind = .other, .bytes = bytes };
        }
        // USVString: ToString, then each lone surrogate U+FFFD.
        return try usvString(allocator, try engine.convertToUSVString(realm, value, allocator));
    }

    /// A USVString body: its UTF-8 encoding, and text/plain;charset=UTF-8.
    /// Takes `text`.
    fn usvString(allocator: std.mem.Allocator, text: []u8) !SendBody {
        errdefer allocator.free(text);
        return .{
            .allocator = allocator,
            .kind = .usvstring,
            .bytes = text,
            .content_type = try allocator.dupe(u8, "text/plain;charset=UTF-8"),
        };
    }

    /// Fetch "safely extract" a Blob, FormData or URLSearchParams body.
    fn extracted(allocator: std.mem.Allocator, object: typedefs.XMLHttpRequestBodyInit) !SendBody {
        var result = fetch_body.extract(allocator, .{ .xmlhttp_request_body_init = object }, false) catch |err| return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            error.TypeError => error.TypeError,
        };
        defer result.deinit();
        const body = result.body orelse return error.TypeError;
        var self: SendBody = .{ .allocator = allocator, .kind = .other, .bytes = try allocator.dupe(u8, body.getBytes()) };
        self.content_type = result.content_type;
        result.content_type = null;
        return self;
    }

    /// send() steps 4.4-4.6: the Content-Type of this body, in `state`'s
    /// author request headers.
    fn setContentType(self: *const SendBody, state: *XMLHttpRequestState) !void {
        const kind: send_algo.BodyKind = switch (self.kind) {
            .usvstring => .usvstring,
            .other => .other,
        };
        try send_algo.setRequestContentType(self.allocator, state, kind, self.content_type);
    }
};

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
