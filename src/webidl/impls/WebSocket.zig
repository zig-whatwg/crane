//! Implementation for WebSocket interface
//!
//! The WebSocket interface enables bidirectional communication with a server
//! over a WebSocket connection.
//!
//! Spec: https://websockets.spec.whatwg.org/#the-websocket-interface
//!
//! ## Connection States
//!
//! - CONNECTING (0): Connection not yet established
//! - OPEN (1): Connection established, communication possible
//! - CLOSING (2): Close handshake in progress
//! - CLOSED (3): Connection closed or could not be opened
//!
//! ## Events
//!
//! - open: Fired when connection is established
//! - message: Fired when data is received
//! - error: Fired when error occurs
//! - close: Fired when connection is closed

const std = @import("std");
const runtime = @import("runtime");
const v8_engine = @import("v8");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const WebSocket = interfaces.WebSocket;

// Import the WebSocket connection module
const websocket = @import("websocket");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const WebSocketConnection = websocket.WebSocketConnection;

// The constructor applies the URL parser, per steps 2-5.
const api_parser = @import("api_parser");

const log = std.log.scoped(.websocket);

/// Largest single frame `pump` will hand to script.
///
/// `Send-65K-data.any.js` round-trips 65536 bytes, so anything smaller turns
/// that test into a silent truncation rather than a failure.
const RECV_BUFFER_SIZE: usize = 128 * 1024;

/// How often the connection is drained, in milliseconds.
///
/// The pump runs as a self-rearming one-shot on the SAME TimerManager that
/// backs `setTimeout`, which is what makes it work at all: `V8EventLoop
/// .hasPendingWork` returns true while any timer is live, so the browser's
/// `runEventLoopBlocking` will not break out of its loop with a socket still
/// open, and `runOnceBlocking` caps its `pollBlocking` wait at the next timer
/// deadline, so it cannot sleep through an arriving frame either. Registering
/// an I/O source with the V8 event loop instead would need both of those
/// behaviours rebuilt.
const POLL_INTERVAL_MS: u64 = 1;

pub const State = WebSocket.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    SyntaxError,
    InvalidAccessError,
};

/// The pump's half of the WebSocket, owned independently of the instance.
///
/// The timer callback cannot be handed `*InternalState`: that block comes from
/// the process-wide `ArenaAllocator` and `deinit` returns it to a size-classed
/// free list, from which the next same-sized request takes it (AGENTS.md,
/// "InstanceRegistry.createIn destabilises the DOM"). A timer still holding it
/// would then write into a different object's state. The same applies to
/// `*runtime.Instance`, whose address the slab recycles.
///
/// So the token is its own allocation from the page allocator, and it is the
/// ONLY thing the timer points at. Ownership follows one rule:
///
///   armed == true   the scheduled timer owns it; the callback frees it
///   armed == false  the impl owns it; `detach` frees it
///
/// `detach` therefore never calls `clearTimeout`. Cancelling is a single bool
/// store on a block nothing else can reach, which keeps teardown free of the
/// added work that costs this codebase crashes (AGENTS.md, "The teardown race
/// taxes every change"). A cancelled token costs one more tick, then goes.
const PollToken = struct {
    /// The WebSocket this pumps. Read ONLY while `cancelled` is false - after
    /// `detach` the instance may already be back in the slab.
    instance: *runtime.Instance,
    /// Set by `detach`. Once true the callback touches nothing but the token.
    cancelled: bool = false,
    /// True exactly while a timer is scheduled against this token.
    armed: bool = false,
    /// True while `pumpCallback` is on the stack. `detach` must not free the
    /// token under its own caller, and dispatching an event runs script, which
    /// can drop the last reference to the WebSocket and take deinit with it.
    in_callback: bool = false,
    /// The realm's timer interface, captured at construction.
    timer: runtime.TimerInterface,

    fn allocator() std.mem.Allocator {
        return std.heap.page_allocator;
    }

    fn create(instance: *runtime.Instance, timer: runtime.TimerInterface) !*PollToken {
        const self = try allocator().create(PollToken);
        self.* = .{ .instance = instance, .timer = timer };
        return self;
    }

    /// Schedule the next pump. No-op if one is already scheduled.
    fn arm(self: *PollToken) void {
        if (self.armed or self.cancelled) return;
        self.armed = true;
        _ = self.timer.setTimeout(POLL_INTERVAL_MS, pumpCallback, @ptrCast(self));
    }

    /// Give up the instance. Frees the token unless someone else still owns it.
    fn detach(self: *PollToken) void {
        self.cancelled = true;
        if (!self.armed and !self.in_callback) allocator().destroy(self);
    }
};

/// Timer callback. Runs one pump, then re-arms while the socket is live.
fn pumpCallback(user_data: ?*anyopaque) void {
    const token: *PollToken = @ptrCast(@alignCast(user_data orelse return));
    token.armed = false;

    // The instance is gone; the token is ours to release.
    if (token.cancelled) {
        PollToken.allocator().destroy(token);
        return;
    }

    // A timer callback runs with NO HandleScope on the stack, and everything
    // the pump does downstream of an event - wrapping the event object,
    // invoking a listener - asks V8 for a Local. Without a scope that is not a
    // failed call, it is:
    //
    //     Fatal error in v8::HandleScope::CreateHandle()
    //     Cannot create a handle without a HandleScope
    //
    // which aborts the process. `invokeIdlHandler` opens its own scope, but by
    // then the event has already been constructed and dispatched.
    token.in_callback = true;
    const still_live = pumpInScope(token.instance);
    token.in_callback = false;

    // `pump` dispatches events, which run script. If that collected the
    // WebSocket, `detach` has already run and left the free to us - so this is
    // the first read of the token that is safe to make afterwards.
    if (token.cancelled) {
        PollToken.allocator().destroy(token);
        return;
    }

    // A socket that reached CLOSED and fired its close event has nothing left
    // to poll for. Stopping is what lets `hasPendingWork` go false and the
    // event loop go idle - a pump that re-armed forever would hold every test
    // open for its full timeout.
    if (!still_live) return;
    token.arm();
}

/// Run one pump turn with a HandleScope on the stack.
///
/// A timer callback is entered from the event loop, not from V8, so there is no
/// scope. Everything downstream of an event - wrapping the event object,
/// invoking a listener - asks V8 for a Local, and without a scope that is not a
/// failed call but an abort:
///
///     # Fatal error in v8::HandleScope::CreateHandle()
///     # Cannot create a handle without a HandleScope
///
/// which the journal records as one CRASH with no subtests and no clue.
/// `invokeIdlHandler` opens its own scope, but the event has been constructed
/// and dispatched long before that.
///
/// If no isolate can be found, the pump does NOTHING rather than proceed
/// unscoped, and reports itself live so the next turn can try again. A socket
/// that never pumps times out; one that pumps unscoped takes the process down
/// and every remaining test file with it.
fn pumpInScope(instance: *runtime.Instance) bool {
    const ffi = v8_engine.ffi;

    // The SOCKET's isolate, not the entered one. A worker's timers run on the
    // parent's TimerManager, so a pump turn for a worker socket is entered with
    // the parent's isolate current while every handle the turn creates belongs
    // to the worker's. A scope opened on the wrong isolate is no scope at all,
    // and the abort looks identical to having opened none.
    const internal = getInternal(instance) orelse return false;
    const isolate = internal.isolate orelse ffi.v8_Isolate_GetCurrent() orelse return true;

    const scope = ffi.v8_HandleScope_New(isolate) orelse return true;
    defer ffi.v8_HandleScope_Dispose(scope);

    // ENTER the socket's realm as well. A scope alone is not enough: V8 creates
    // handles in whichever context is entered on this isolate, and a turn
    // entered from the event loop has none - or, for a worker socket whose
    // timers run on the parent's TimerManager, has the PARENT's. Dispatching
    // into the wrong realm is the same abort as dispatching into no realm.
    //
    // The window case worked without this only because the browser leaves the
    // page's context entered, which is exactly the kind of accident that makes
    // a worker the first thing to break.
    const engine_ctx = instance.ctx.engine_ctx orelse return pump(instance);
    const v8_context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    ffi.v8_Context_Enter(v8_context);
    defer ffi.v8_Context_Exit(v8_context);

    return pump(instance);
}

/// Internal state for WebSocket implementation
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The underlying WebSocket connection
    connection: ?*WebSocketConnection,

    /// The WebSocket URL (stored separately for ownership)
    url_string: []const u8,

    /// Binary type preference
    binary_type: enums.BinaryType,

    /// Event handlers stored as V8 Global handles.
    ///
    /// These MUST be Global handles (not raw pointers) because:
    /// 1. The JavaScript callback objects need to survive past the setter's HandleScope
    /// 2. Local handles become invalid when the HandleScope that created them is destroyed
    /// 3. Without Global handles, invoking event handlers would crash due to dangling pointers
    ///
    /// See: src/runtime/engines/v8/global_handles.zig for Global handle management.
    onopen: v8_engine.OptionalGlobalHandle,
    onerror: v8_engine.OptionalGlobalHandle,
    onclose: v8_engine.OptionalGlobalHandle,
    onmessage: v8_engine.OptionalGlobalHandle,

    /// V8 isolate for creating/disposing Global handles
    isolate: ?*v8_engine.ffi.Isolate,

    /// The pump's token, while one exists. See `PollToken`.
    poll: ?*PollToken = null,

    /// Subprotocols requested by the constructor, owned here.
    requested_protocols: ?[][]const u8 = null,

    /// Whether the handshake has been attempted. The pump connects on its first
    /// turn rather than in the constructor, so that `new WebSocket(url)` returns
    /// with readyState CONNECTING the way every caller expects.
    connect_attempted: bool = false,

    /// Set once the close event has fired. Guards against firing it twice and
    /// tells the pump to stop re-arming.
    pump_done: bool = false,

    /// Receive scratch, allocated on first use and reused for the socket's
    /// life. Not a stack array: `pump` runs as a timer callback, and a 128 KB
    /// frame there is a stack overflow waiting for the right call depth.
    recv_buffer: ?[]u8 = null,

    /// Set once the close outcome is decided, by close() or by the protocol.
    close_reported: bool = false,

    /// Close code and reason to report, captured when the close is decided.
    reported_code: u16 = 1006,
    reported_reason: ?[]const u8 = null,
    reported_clean: bool = false,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .connection = null,
            .url_string = "",
            .binary_type = ._blob_,
            .onopen = null,
            .onerror = null,
            .onclose = null,
            .onmessage = null,
            .isolate = null,
        };
    }

    pub fn deinit(self: *InternalState) void {
        // Release the pump FIRST. Everything below frees memory the pump reads,
        // and the token is the only handle it has on any of it.
        if (self.poll) |token| {
            token.detach();
            self.poll = null;
        }

        // Dispose V8 Global handles to prevent memory leaks
        v8_engine.disposeOptionalGlobalHandle(&self.onopen);
        v8_engine.disposeOptionalGlobalHandle(&self.onerror);
        v8_engine.disposeOptionalGlobalHandle(&self.onclose);
        v8_engine.disposeOptionalGlobalHandle(&self.onmessage);

        if (self.connection) |conn| {
            conn.deinit();
            self.connection = null;
        }
        if (self.requested_protocols) |protos| {
            for (protos) |p| self.allocator.free(p);
            self.allocator.free(protos);
            self.requested_protocols = null;
        }
        if (self.reported_reason) |r| {
            self.allocator.free(r);
            self.reported_reason = null;
        }
        if (self.recv_buffer) |b| {
            self.allocator.free(b);
            self.recv_buffer = null;
        }
        if (self.url_string.len > 0) {
            self.allocator.free(self.url_string);
        }
    }

    /// The receive scratch buffer, allocated on first use.
    pub fn recvBuffer(self: *InternalState) ?[]u8 {
        if (self.recv_buffer) |b| return b;
        const b = self.allocator.alloc(u8, RECV_BUFFER_SIZE) catch return null;
        self.recv_buffer = b;
        return b;
    }

    /// Get the current ready state from the connection
    pub fn getReadyState(self: *const InternalState) u16 {
        if (self.connection) |conn| {
            return conn.getReadyState();
        }
        return 3; // CLOSED if no connection
    }

    /// Get the buffered amount from the connection
    pub fn getBufferedAmount(self: *const InternalState) u64 {
        if (self.connection) |conn| {
            return conn.buffered_amount;
        }
        return 0;
    }

    /// Get the negotiated protocol from the connection
    pub fn getProtocol(self: *const InternalState) ?[]const u8 {
        if (self.connection) |conn| {
            return conn.protocol;
        }
        return null;
    }

    /// Get the extensions from the connection
    pub fn getExtensions(self: *const InternalState) ?[]const u8 {
        if (self.connection) |conn| {
            return conn.extensions;
        }
        return null;
    }
};

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();

        // Return the block itself, not just what it points to.
        // `internal.deinit()` releases the strings and lists the state
        // OWNS; without this the state struct stays allocated for the
        // life of the process - measured at 208 bytes per discarded
        // element across the impls still doing it this way.
        const Arena = @import("runtime").ArenaAllocator;
        if (Arena.tryGet() catch null) |arena| arena.destroy(InternalState, internal);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

// =============================================================================
// The pump
//
// Spec: https://websockets.spec.whatwg.org/#feedback-from-the-protocol
//
// `src/websocket/` is a synchronous, non-blocking API over libcurl - connect,
// receive, close - with no way to reach JavaScript. This is the half that turns
// it into the event-driven interface the spec describes, one event-loop turn at
// a time.
// =============================================================================

/// Drain one turn's worth of protocol activity and fire what it produced.
///
/// Returns false when there is nothing left to poll for, so the caller stops
/// re-arming. Every `return false` below is also a point past which `internal`
/// may no longer exist: dispatching an event runs script, and script can drop
/// the last reference to the WebSocket. Nothing here touches `internal` after a
/// dispatch without fetching it again.
fn pump(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    if (internal.pump_done) return false;
    const connection = internal.connection orelse return false;

    // 0. close() before the handshake even started. `connection.close` fails
    //    the connection outright in that case, so there is nothing to connect
    //    to any more - only the close event is still owed.
    if (connection.state == .CLOSED) {
        captureCloseFromConnection(internal, connection);
        finishClose(instance, internal);
        return false;
    }

    // 1. Establish the WebSocket connection. Deferred off the constructor so
    //    that readyState is observably CONNECTING first.
    if (!internal.connect_attempted) {
        internal.connect_attempted = true;

        connection.connect(internal.requested_protocols) catch |err| {
            // "Fail the WebSocket connection": an error event, then a close
            // event with wasClean false and code 1006. Both are required - a
            // test waiting only on close must still see it.
            log.warn("handshake to {s} failed: {s}", .{ internal.url_string, @errorName(err) });
            internal.close_reported = true;
            internal.reported_code = 1006;
            internal.reported_clean = false;
            fireSimpleEvent(instance, "error", .@"error");
            if (getInternal(instance)) |live| finishClose(instance, live);
            return false;
        };

        syncState(instance);
        fireSimpleEvent(instance, "open", .open);

        // The open listener ran script. It may have closed the socket, and it
        // may have dropped it entirely.
        const after_open = getInternal(instance) orelse return false;
        if (after_open.pump_done) return false;
        if (connection.state == .CLOSED) {
            captureCloseFromConnection(after_open, connection);
            finishClose(instance, after_open);
            return false;
        }
    }

    // 2. Receive. `connection.receive` reports "nothing yet" as null and folds
    //    an arriving close frame into its own state, so the loop ends either on
    //    a quiet socket or on a closed one.
    const buffer = internal.recvBuffer() orelse return false;
    while (connection.state == .OPEN or connection.state == .CLOSING) {
        const message = connection.receive(buffer) catch |err| {
            // A transport error after the handshake is an abnormal closure.
            // Not a fired error event: the spec fires error only when the
            // connection could not be established or was closed uncleanly, and
            // the close event below carries that.
            log.warn("receive on {s} failed: {s}", .{ internal.url_string, @errorName(err) });
            internal.close_reported = true;
            internal.reported_code = 1006;
            internal.reported_clean = false;
            finishClose(instance, internal);
            return false;
        } orelse break;

        fireMessageEvent(instance, internal, message.data, message.is_text);

        // Dispatch runs script, which may have closed or dropped the socket.
        const after_message = getInternal(instance) orelse return false;
        if (after_message.pump_done) return false;
    }

    // 3. The closing handshake completed, either because the server sent a
    //    close frame or because ours was acknowledged.
    if (connection.state == .CLOSED) {
        captureCloseFromConnection(internal, connection);
        finishClose(instance, internal);
        return false;
    }

    return true;
}

/// Copy the connection's close outcome into the state the close event reads.
///
/// Skipped once `close()` has already decided: the values script asked for are
/// what the event must report, and the connection only ever holds what the peer
/// echoed back.
fn captureCloseFromConnection(internal: *InternalState, connection: *WebSocketConnection) void {
    if (internal.close_reported) return;
    internal.close_reported = true;

    internal.reported_code = connection.close_code orelse 1005;
    internal.reported_clean = connection.wasClean();
    if (internal.reported_reason == null) {
        if (connection.close_reason) |reason| {
            internal.reported_reason = internal.allocator.dupe(u8, reason) catch null;
        }
    }
}

/// Fire the close event, once, and retire the pump.
fn finishClose(instance: *runtime.Instance, internal: *InternalState) void {
    if (internal.pump_done) return;
    internal.pump_done = true;

    if (internal.connection) |conn| conn.state = .CLOSED;
    syncState(instance);

    fireCloseEvent(instance, internal);
}

// =============================================================================
// Event dispatch
//
// Two places a listener can be, and both have to be tried - the same split
// XMLHttpRequest.zig documents at length:
//
//   1. the event listener list, via `EventTarget.dispatchEvent`;
//   2. the event handler IDL attribute (`ws.onopen = f`), which Crane keeps in
//      this impl's own InternalState as a V8 Global rather than as a listener,
//      so `EventTarget.invokeIdlEventHandler` cannot see it.
// =============================================================================

/// Which handler attribute an event type maps to.
const HandlerKind = enum { open, @"error", close, message };

fn fireSimpleEvent(instance: *runtime.Instance, name: []const u8, kind: HandlerKind) void {
    const ctx = instance.ctx;
    const type_string = runtime.DOMString.initInterned(name);

    const event = interfaces.Event.call_constructor(
        ctx,
        type_string,
        webidl.Opt(dictionaries.EventInit).notPassed(),
    ) catch return;

    deliver(instance, event, type_string, kind, .plain);
}

fn fireCloseEvent(instance: *runtime.Instance, internal: *InternalState) void {
    const ctx = instance.ctx;
    const type_string = runtime.DOMString.initInterned("close");

    const init_dict = dictionaries.CloseEventInit{
        .base = .{},
        .wasClean = internal.reported_clean,
        .code = internal.reported_code,
        .reason = internal.reported_reason orelse "",
    };

    const event = interfaces.CloseEvent.call_constructor(
        ctx,
        type_string,
        webidl.Opt(dictionaries.CloseEventInit).passed(init_dict),
    ) catch return;

    deliver(instance, event, type_string, .close, .close);
}

fn fireMessageEvent(
    instance: *runtime.Instance,
    internal: *InternalState,
    data: []const u8,
    is_text: bool,
) void {
    const ctx = instance.ctx;
    const type_string = runtime.DOMString.initInterned("message");

    // The payload is a view into the pump's reusable receive buffer, which the
    // next frame overwrites, so the JSValue has to own its bytes before the
    // event outlives this call. `MessageEvent.call_constructor` clones the
    // dictionary's data, so an OWNED string here would be cloned and then
    // leaked; a ref is cloned into an owned copy, which is what is wanted.
    const payload: runtime.JSValue = blk: {
        if (is_text) break :blk runtime.JSValue.fromStringRef(data);
        break :blk binaryPayload(instance, internal, data) orelse return;
    };

    const init_dict = dictionaries.MessageEventInit{
        .base = .{},
        .data = payload,
        .origin = originOf(internal.url_string),
    };

    const event = interfaces.MessageEvent.call_constructor(
        ctx,
        type_string,
        webidl.Opt(dictionaries.MessageEventInit).passed(init_dict),
    ) catch return;

    deliver(instance, event, type_string, .message, .message);
}

/// A binary frame as `binaryType` says to present it.
fn binaryPayload(
    instance: *runtime.Instance,
    internal: *InternalState,
    data: []const u8,
) ?runtime.JSValue {
    switch (internal.binary_type) {
        ._arraybuffer_ => {
            const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return null;
            const engine_ctx = instance.ctx.engine_ctx orelse return null;
            const v8_context: *v8_engine.ffi.Context = @ptrCast(@alignCast(engine_ctx));

            // v8_ArrayBuffer_NewWithData COPIES into a buffer V8 owns, so the
            // stack payload does not have to outlive the call.
            const value = v8_engine.ffi.v8_ArrayBuffer_NewWithData(
                isolate,
                v8_context,
                @ptrCast(@constCast(data.ptr)),
                data.len,
            ) orelse return null;
            return runtime.JSValue.fromGlobalHandle(@ptrCast(value));
        },
        ._blob_ => {
            // Built through Blob's own constructor rather than by reaching into
            // its impl: `new Blob([arrayBuffer])`, assembled here. The Blob
            // copies the bytes into its BlobData, so the pump's stack buffer
            // does not have to outlive this call.
            const v8 = v8_engine.ffi;
            const isolate = v8.v8_Isolate_GetCurrent() orelse return null;
            const engine_ctx = instance.ctx.engine_ctx orelse return null;
            const v8_context: *v8.Context = @ptrCast(@alignCast(engine_ctx));

            const buffer = v8.v8_ArrayBuffer_NewWithData(
                isolate,
                v8_context,
                @ptrCast(@constCast(data.ptr)),
                data.len,
            ) orelse return null;
            defer v8.v8_Value_Dispose(buffer);

            // Both of these allocate a Global the caller owns, and the Blob
            // copies out of them rather than retaining them.
            const parts = v8.v8_Array_New(isolate, 1);
            defer v8.v8_Value_Dispose(@ptrCast(parts));
            if (!v8.v8_Array_Set(parts, v8_context, 0, buffer)) return null;

            const blob = interfaces.Blob.call_constructor(
                instance.ctx,
                webidl.Opt(runtime.JSValue).passed(runtime.JSValue.fromHandleNonOwning(@ptrCast(parts))),
                webidl.Opt(dictionaries.BlobPropertyBag).notPassed(),
            ) catch return null;
            return runtime.JSValue.fromInstance(blob);
        },
    }
}

/// The origin a MessageEvent from this socket reports: the URL's scheme, host
/// and port with the ws/wss scheme mapped to http/https, per the spec's
/// "origin" for a WebSocket message.
fn originOf(url: []const u8) []const u8 {
    const sep = std.mem.indexOf(u8, url, "://") orelse return "";
    const rest = url[sep + 3 ..];
    const end = std.mem.indexOfAny(u8, rest, "/?#") orelse rest.len;
    return url[0 .. sep + 3 + end];
}

const EventShape = enum { plain, close, message };

/// Deliver an event to both kinds of listener, then release it if nothing kept it.
fn deliver(
    target: *runtime.Instance,
    event: *runtime.Instance,
    type_string: runtime.DOMString,
    kind: HandlerKind,
    shape: EventShape,
) void {
    // `dispatchEvent` throws unless the event's INITIALIZED flag is set, and no
    // constructor sets it. `initEvent` does, and gives the event an owned copy
    // of the type string that dispatch matches listeners on.
    interfaces.Event.call_initEvent(
        event,
        type_string,
        webidl.Opt(bool).passed(false),
        webidl.Opt(bool).passed(false),
    ) catch return;

    _ = interfaces.EventTarget.call_dispatchEvent(target, event) catch |err| {
        log.debug("dispatch of {s} failed: {s}", .{ type_string.asSlice(), @errorName(err) });
    };

    invokeIdlHandler(target, event, kind);
    releaseEventIfUnwrapped(event, shape);
}

/// Free an event nobody ever saw.
///
/// The wrapper cache is the proof: every path that hands an event to V8 puts it
/// there and the weak callback owns it from that moment, so an event absent
/// from the cache after dispatch has provably never been seen and freeing it is
/// safe. One that IS cached is left entirely alone. Same reasoning, and the
/// same hazard, as `XMLHttpRequest.releaseEventIfUnwrapped`.
fn releaseEventIfUnwrapped(event: *runtime.Instance, shape: EventShape) void {
    const cache_storage = event.ctx.getV8WrapperCacheStorage() orelse return;
    const cache: *v8_engine.WrapperCache = @ptrCast(@alignCast(cache_storage));
    if (cache.get(event) != null) return;

    switch (shape) {
        .plain => interfaces.Event.deinit(event),
        .close => interfaces.CloseEvent.deinit(event),
        .message => interfaces.MessageEvent.deinit(event),
    }
}

/// Call `ws.onopen = f` and friends with the event.
///
/// The handler is stored as a V8 Global and must be passed through AS a Global:
/// `v8_Value_IsFunction` takes a `Global<Value>*` and calls `Get` on it, so a
/// Local reinterpreted as one is read at the wrong offset and crashes. This is
/// the mistake `XMLHttpRequest.invokeIdlHandler` records having made.
fn invokeIdlHandler(target: *runtime.Instance, event: *runtime.Instance, kind: HandlerKind) void {
    const internal = getInternal(target) orelse return;
    const handle = switch (kind) {
        .open => internal.onopen,
        .@"error" => internal.onerror,
        .close => internal.onclose,
        .message => internal.onmessage,
    } orelse return;

    const callback_global: *v8_engine.ffi.Value = @ptrCast(handle.ptr);

    const engine_ctx = target.ctx.engine_ctx orelse return;
    const v8_context: *v8_engine.ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const v8_isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return;

    // A Local handle is only valid inside a HandleScope, and wrapping the event
    // creates several.
    const handle_scope = v8_engine.ffi.v8_HandleScope_New(v8_isolate) orelse return;
    defer v8_engine.ffi.v8_HandleScope_Dispose(handle_scope);

    if (!v8_engine.ffi.v8_Value_IsFunction(callback_global)) return;

    // Wrap with the event's ACTUAL interface, so an onmessage handler sees
    // `.data` rather than a bare Event.
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

/// Constructor implementation
/// Spec: https://websockets.spec.whatwg.org/#dom-websocket-websocket
///
/// The WebSocket(url, protocols) constructor steps are:
/// 1. Let baseURL be this's relevant settings object's API base URL.
/// 2. Let urlRecord be the result of applying the URL parser to url with baseURL.
/// 3. If urlRecord is failure, throw a "SyntaxError" DOMException.
/// 4. If urlRecord's scheme is not "ws" or "wss", throw a "SyntaxError" DOMException.
/// 5. If urlRecord's fragment is non-null, throw a "SyntaxError" DOMException.
/// 6. If protocols is a string, set protocols to a sequence consisting of just that string.
/// 7. If any of the values in protocols occur more than once or contain illegal values,
///    throw a "SyntaxError" DOMException.
/// 8. Set this's url to urlRecord.
/// 9. Let client be this's relevant settings object.
/// 10. Run this step in parallel: Establish a WebSocket connection given urlRecord, protocols...
pub fn call_constructor(ctx: runtime.Context, url: runtime.USVString, protocols: webidl.Opt(runtime.JSValue)) !*runtime.Instance {
    // Steps 2-5. Parse the URL, then check its scheme and fragment.
    //
    // This used to be `startsWith("ws://")` plus a search for '#', which reads
    // as equivalent and is not: it accepts everything the URL parser rejects
    // for reasons that are not in the prefix. `ws://web platform.test:80/echo`
    // is a SyntaxError because a space cannot appear in a host, and a prefix
    // test cannot see that.
    var record = api_parser.parseURL(ctx.allocator, url, null) catch {
        // Step 3. Parse failure is a "SyntaxError" DOMException.
        return error.SyntaxError;
    };
    defer record.deinit();

    // Step 4. The scheme must be "ws" or "wss".
    const scheme = record.scheme();
    if (!std.mem.eql(u8, scheme, "ws") and !std.mem.eql(u8, scheme, "wss")) {
        return error.SyntaxError;
    }

    // Step 5. A non-null fragment is a "SyntaxError" DOMException - including
    // an EMPTY one, so `ws://host/#` is just as invalid as `ws://host/#x`.
    if (record.has_fragment) {
        return error.SyntaxError;
    }

    // Create instance
    const instance = try init(ctx.allocator, State, &WebSocket.vtable, ctx);
    errdefer deinit(instance);

    // Get state
    const state = instance.getState(State);

    // Create internal state
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(ctx.allocator);

    // Store the V8 isolate for Global handle management.
    //
    // NOT `ctx.getEngineContextAs(Isolate)`, which is what this used to be:
    // `engine_ctx` holds the V8 *Context*, and that cast just relabels it. The
    // four `get_on*` accessors have been passing a Context to
    // `GlobalHandle.get(isolate)` ever since, and went unnoticed only because
    // nothing ever fired an event to read a handler back with.
    internal.isolate = v8_engine.ffi.v8_Isolate_GetCurrent();

    state.own._internal = internal;

    // Create the WebSocket connection (starts in CONNECTING state)
    const connection = try WebSocketConnection.init(ctx.allocator, url);
    internal.connection = connection;

    // Store URL (copy for ownership)
    internal.url_string = try ctx.allocator.dupe(u8, url);
    state.own.url = internal.url_string;

    // Initialize state from connection
    state.own.readyState = connection.getReadyState();
    state.own.bufferedAmount = 0;
    state.own.extensions = runtime.DOMString.initEmpty();
    state.own.protocol = runtime.DOMString.initEmpty();
    state.own.binaryType = ._blob_;
    internal.binary_type = ._blob_;

    // Initialize event handlers to null
    state.own.onopen = null;
    state.own.onerror = null;
    state.own.onclose = null;
    state.own.onmessage = null;

    // Steps 6-7. protocols is a string or a sequence of strings. Each must be a
    // valid HTTP token, and no value may repeat (ASCII case-insensitively) -
    // otherwise throw a "SyntaxError" DOMException.
    internal.requested_protocols = try parseProtocols(ctx.allocator, protocols);

    // Step 10. "Run this step in parallel: establish a WebSocket connection."
    //
    // Deferred to the pump's first turn rather than done here. Connecting
    // inline would block the constructor on a network handshake and, worse,
    // leave readyState at OPEN before the caller had a chance to see
    // CONNECTING - which several tests in `websockets/` assert directly.
    // TODO(websockets): pump worker realms.
    //
    // A worker's timers are scheduled on the PARENT's TimerManager
    // (`Worker.zig` hands `ctx.timer` to `WorkerV8Context.setTimerInterface`),
    // so a pump turn for a worker socket is entered from the parent's event
    // loop with the parent's realm current. Creating the event objects there
    // aborts the process outright:
    //
    //     # Fatal error in v8::HandleScope::CreateHandle()
    //     # Cannot create a handle without a HandleScope
    //
    // Measured, not assumed: `websockets/Create-invalid-urls.any.js`, whose
    // sockets all throw in the constructor so no pump is ever armed, runs
    // clean in both realms (OK, 12/16), while every file that constructs a
    // live socket took the whole process down on its worker run. A
    // HandleScope on the entered isolate, one on the socket's own isolate,
    // and `Context::Enter` on the socket's context were each tried and each
    // still aborted, so the gap is in how a worker realm is entered from the
    // parent's loop - worker infrastructure, not this impl.
    //
    // Until that is fixed a worker socket stays in CONNECTING and its tests
    // time out. That is the behaviour they already had, and a timeout is a
    // result; an abort takes every remaining file in the shard with it.
    // `ctx.isWorker()` is NOT the test - it reports false for the realm a WPT
    // `.any.worker.js` runs in, because nothing sets that context's realm_info.
    // Asking the global object whether it has `window` is the same distinction
    // WPT's own `GLOBAL.isWindow()` draws, and it is answered here, inside a
    // constructor call, where a HandleScope certainly exists.
    if (!realmIsWindow(ctx)) {
        log.warn("WebSocket in a non-window realm is not pumped yet: {s}", .{url});
        return instance;
    }

    const timer = ctx.getOptionalTimer() orelse {
        // No timer means no event loop, so nothing could ever deliver an event.
        // Leave the socket in CONNECTING rather than pretending otherwise.
        log.warn("no timer interface in this realm; WebSocket to {s} cannot be pumped", .{url});
        return instance;
    };
    const token = try PollToken.create(instance, timer);
    internal.poll = token;
    token.arm();

    return instance;
}

/// Does this realm have a `window` on its global?
///
/// A Window global does; a WorkerGlobalScope does not. Called from the
/// constructor, so a HandleScope is already on the stack.
fn realmIsWindow(ctx: runtime.Context) bool {
    const ffi = v8_engine.ffi;
    const engine_ctx = ctx.engine_ctx orelse return false;
    const v8_context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));

    // `v8_Context_Global` hands back a Global the caller owns.
    const global = ffi.v8_Context_Global(v8_context) orelse return false;
    defer ffi.v8_Value_Dispose(@ptrCast(global));

    return ffi.v8_Object_Has(v8_context, global, "window");
}

/// Steps 6-7 of the constructor: validate and copy the requested subprotocols.
///
/// Returns null when none were given, which is distinct from an empty list -
/// `CreateWebSocket(false, false)` must send no Sec-WebSocket-Protocol header
/// at all.
fn parseProtocols(
    allocator: std.mem.Allocator,
    protocols: webidl.Opt(runtime.JSValue),
) !?[][]const u8 {
    if (!protocols.was_passed) return null;

    var list: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (list.items) |p| allocator.free(p);
        list.deinit(allocator);
    }

    try collectProtocolStrings(allocator, &list, protocols.value);

    if (list.items.len == 0) {
        list.deinit(allocator);
        return null;
    }

    // Step 7. Any value that is not a token, or that repeats, is a SyntaxError.
    for (list.items, 0..) |value, i| {
        if (!isHttpToken(value)) return error.SyntaxError;
        for (list.items[0..i]) |earlier| {
            if (std.ascii.eqlIgnoreCase(earlier, value)) return error.SyntaxError;
        }
    }

    return try list.toOwnedSlice(allocator);
}

/// Pull the strings out of the protocols argument.
///
/// `protocols` is `(DOMString or sequence<DOMString>)`, and reaches an impl as
/// an unconverted JSValue, so both shapes are read straight off the V8 value.
fn collectProtocolStrings(
    allocator: std.mem.Allocator,
    list: *std.ArrayList([]const u8),
    value: runtime.JSValue,
) !void {
    const v8 = v8_engine.ffi;

    if (value != .handle) return;
    const v8_value: *v8.Value = @ptrCast(@alignCast(value.handle.ptr));

    const isolate = v8.v8_Isolate_GetCurrent() orelse return;

    if (v8.v8_Value_IsString(v8_value)) {
        // A bare string is a sequence of just that string.
        if (try v8StringToOwned(allocator, v8_value)) |s| try list.append(allocator, s);
        return;
    }

    if (!v8.v8_Value_IsArray(v8_value)) return;

    const v8_array: *v8.Array = @ptrCast(v8_value);
    const length = v8.v8_Array_Length(v8_array);
    if (length == 0) return;

    // `v8_Isolate_GetCurrentContext` allocates a Global the caller owns.
    const v8_context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(v8_context);

    var i: u32 = 0;
    while (i < length) : (i += 1) {
        const element = v8.v8_Array_Get(v8_context, v8_array, i) orelse continue;
        defer v8.v8_Value_Dispose(element);
        if (try v8StringToOwned(allocator, element)) |s| try list.append(allocator, s);
    }
}

/// A V8 string as an owned UTF-8 slice, or null if it is not a string.
fn v8StringToOwned(allocator: std.mem.Allocator, value: *v8_engine.ffi.Value) !?[]const u8 {
    const v8 = v8_engine.ffi;
    if (!v8.v8_Value_IsString(value)) return null;

    const str: *v8.String = @ptrCast(value);
    const utf8_len = v8.v8_String_Utf8Length(str);
    if (utf8_len <= 0) return try allocator.dupe(u8, "");

    const buffer = try allocator.alloc(u8, @intCast(utf8_len));
    errdefer allocator.free(buffer);
    _ = v8.v8_String_WriteUtf8(str, buffer.ptr, utf8_len);
    return buffer;
}

/// An HTTP token, per RFC 9110 § 5.6.2. Empty is not a token.
fn isHttpToken(value: []const u8) bool {
    if (value.len == 0) return false;
    for (value) |c| {
        const ok = switch (c) {
            '!', '#', '$', '%', '&', '\'', '*', '+', '-', '.', '^', '_', '`', '|', '~' => true,
            '0'...'9', 'a'...'z', 'A'...'Z' => true,
            else => false,
        };
        if (!ok) return false;
    }
    return true;
}

/// Getter for url
/// Spec: https://websockets.spec.whatwg.org/#dom-websocket-url
///
/// The url attribute must return this's url, serialized.
pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    return state.own.url;
}

/// Getter for readyState
/// Spec: https://websockets.spec.whatwg.org/#dom-websocket-readystate
///
/// The readyState attribute represents the state of the connection.
pub fn get_readyState(instance: *runtime.Instance) anyerror!u16 {
    const internal = getInternal(instance) orelse return 3; // CLOSED
    return internal.getReadyState();
}

/// Getter for bufferedAmount
/// Spec: https://websockets.spec.whatwg.org/#dom-websocket-bufferedamount
///
/// The bufferedAmount attribute must return the number of bytes of application data
/// (UTF-8 text and binary data) that have been queued using send() but not yet been
/// transmitted to the network.
pub fn get_bufferedAmount(instance: *runtime.Instance) anyerror!u64 {
    const internal = getInternal(instance) orelse return 0;
    return internal.getBufferedAmount();
}

/// Getter for onopen
/// Returns the event handler by retrieving a Local handle from the Global handle.
pub fn get_onopen(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const internal = getInternal(instance) orelse return null;
    const isolate = internal.isolate orelse return null;
    if (internal.onopen) |global| {
        // Use GlobalHandle's get() method to retrieve Local handle
        return @ptrCast(@alignCast(global.get(isolate)));
    }
    return null;
}

/// Getter for onerror
/// Returns the event handler by retrieving a Local handle from the Global handle.
pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const internal = getInternal(instance) orelse return null;
    const isolate = internal.isolate orelse return null;
    if (internal.onerror) |global| {
        // Use GlobalHandle's get() method to retrieve Local handle
        return @ptrCast(@alignCast(global.get(isolate)));
    }
    return null;
}

/// Getter for onclose
/// Returns the event handler by retrieving a Local handle from the Global handle.
pub fn get_onclose(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const internal = getInternal(instance) orelse return null;
    const isolate = internal.isolate orelse return null;
    if (internal.onclose) |global| {
        // Use GlobalHandle's get() method to retrieve Local handle
        return @ptrCast(@alignCast(global.get(isolate)));
    }
    return null;
}

/// Getter for extensions
/// Spec: https://websockets.spec.whatwg.org/#dom-websocket-extensions
///
/// The extensions attribute must initially return the empty string.
/// After the WebSocket connection is established, its value might change.
pub fn get_extensions(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    if (internal.getExtensions()) |ext| {
        return runtime.DOMString.initInterned(ext);
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for protocol
/// Spec: https://websockets.spec.whatwg.org/#dom-websocket-protocol
///
/// The protocol attribute must initially return the empty string.
/// After the WebSocket connection is established, its value might change.
pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    if (internal.getProtocol()) |proto| {
        return runtime.DOMString.initInterned(proto);
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for onmessage
/// Returns the event handler by retrieving a Local handle from the Global handle.
pub fn get_onmessage(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const internal = getInternal(instance) orelse return null;
    const isolate = internal.isolate orelse return null;
    if (internal.onmessage) |global| {
        // Use GlobalHandle's get() method to retrieve Local handle
        return @ptrCast(@alignCast(global.get(isolate)));
    }
    return null;
}

/// Getter for binaryType
/// Spec: https://websockets.spec.whatwg.org/#dom-websocket-binarytype
///
/// The binaryType IDL attribute, on getting, must return the IDL value
/// corresponding to the binaryType attribute of the WebSocket object.
pub fn get_binaryType(instance: *runtime.Instance) anyerror!enums.BinaryType {
    const internal = getInternal(instance) orelse return ._blob_;
    return internal.binary_type;
}

/// Extract GlobalHandle from a tagged callback pointer (from V8 conversion).
/// The V8 conversions layer creates Global handles and tags the pointers.
fn extractEventHandler(handler: ?*const anyopaque) v8_engine.OptionalGlobalHandle {
    if (handler) |ptr| {
        const untagged = v8_engine.pointer_tag.untagPointer(ptr);
        if (untagged.tag == .global_handle or untagged.tag == .untagged) {
            return v8_engine.GlobalHandle{ .ptr = @ptrCast(@alignCast(untagged.ptr)) };
        }
    }
    return null;
}

/// Setter for onopen
/// Extracts GlobalHandle from the tagged pointer passed from V8.
pub fn set_onopen(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const internal = getInternal(instance) orelse return;

    // Dispose old Global handle first to prevent memory leaks
    v8_engine.disposeOptionalGlobalHandle(&internal.onopen);

    // Extract Global handle from tagged pointer (V8 conversion already created the Global)
    internal.onopen = extractEventHandler(@ptrCast(value));
}

/// Setter for onerror
/// Extracts GlobalHandle from the tagged pointer passed from V8.
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const internal = getInternal(instance) orelse return;

    // Dispose old Global handle first to prevent memory leaks
    v8_engine.disposeOptionalGlobalHandle(&internal.onerror);

    // Extract Global handle from tagged pointer (V8 conversion already created the Global)
    internal.onerror = extractEventHandler(@ptrCast(value));
}

/// Setter for onclose
/// Extracts GlobalHandle from the tagged pointer passed from V8.
pub fn set_onclose(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const internal = getInternal(instance) orelse return;

    // Dispose old Global handle first to prevent memory leaks
    v8_engine.disposeOptionalGlobalHandle(&internal.onclose);

    // Extract Global handle from tagged pointer (V8 conversion already created the Global)
    internal.onclose = extractEventHandler(@ptrCast(value));
}

/// Setter for onmessage
/// Extracts GlobalHandle from the tagged pointer passed from V8.
pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const internal = getInternal(instance) orelse return;

    // Dispose old Global handle first to prevent memory leaks
    v8_engine.disposeOptionalGlobalHandle(&internal.onmessage);

    // Extract Global handle from tagged pointer (V8 conversion already created the Global)
    internal.onmessage = extractEventHandler(@ptrCast(value));
}

/// Setter for binaryType
/// Spec: https://websockets.spec.whatwg.org/#dom-websocket-binarytype
///
/// The binaryType IDL attribute, on setting, must set the binaryType attribute
/// of the WebSocket object to the new value.
pub fn set_binaryType(instance: *runtime.Instance, value: enums.BinaryType) anyerror!void {
    const internal = getInternal(instance) orelse return;
    internal.binary_type = value;
    const state = instance.getState(State);
    state.own.binaryType = value;
}

/// Operation: close
/// Spec: https://websockets.spec.whatwg.org/#dom-websocket-close
///
/// The close(code, reason) method steps are:
/// 1. If code is present but not 1000 or 3000-4999, throw an "InvalidAccessError" DOMException.
/// 2. If reason is present and UTF-8 encoded is longer than 123 bytes, throw a "SyntaxError" DOMException.
/// 3. Run the first matching steps from the following list:
///    - If this's ready state is CLOSING or CLOSED: Do nothing.
///    - If the WebSocket connection is not yet established: Fail the WebSocket connection.
///    - If the WebSocket closing handshake has not yet been started: Start the WebSocket closing handshake.
///    - Otherwise: The WebSocket closing handshake is started.
pub fn call_close(instance: *runtime.Instance, code: webidl.Opt(u16), reason: webidl.Opt(runtime.USVString)) anyerror!void {
    const internal = getInternal(instance) orelse return;

    // Validate code if present
    if (code.was_passed) {
        const c = code.value;
        // Code must be either 1000 or in range 3000-4999
        if (c != 1000 and (c < 3000 or c > 4999)) {
            return error.InvalidAccessError;
        }
    }

    // Validate reason length if present
    const reason_str: ?[]const u8 = if (reason.was_passed) blk: {
        if (reason.value.len > 123) {
            return error.SyntaxError;
        }
        break :blk reason.value;
    } else null;

    // Get the connection
    const connection = internal.connection orelse return;

    // Step 3, first case: "If this's ready state is CLOSING or CLOSED, do
    // nothing." Validation above still runs - a bad code throws even on an
    // already-closing socket - but nothing below may re-decide the close
    // outcome, or a second close(3000) would rewrite the code the first one
    // committed to.
    if (internal.pump_done) return;
    if (connection.state == .CLOSING or connection.state == .CLOSED) return;

    // Remember what the close event should report. `close(1000, "reason")`
    // must come back as code 1000 with that reason and wasClean true, so the
    // values are captured HERE - by the time the handshake completes the
    // connection has only what the peer echoed.
    const close_code: ?u16 = if (code.was_passed) code.value else null;
    if (reason_str) |r| {
        if (internal.reported_reason) |old| internal.allocator.free(old);
        internal.reported_reason = internal.allocator.dupe(u8, r) catch null;
    }

    const was_connecting = connection.state == .CONNECTING;

    try connection.close(close_code, reason_str);

    internal.close_reported = true;
    if (was_connecting) {
        // "If the connection is not yet established, fail the WebSocket
        // connection" - which is never clean, and reports 1006 whatever code
        // was asked for.
        internal.reported_code = 1006;
        internal.reported_clean = false;
    } else {
        internal.reported_code = close_code orelse 1005;
        internal.reported_clean = true;
    }

    // Update the state
    const state = instance.getState(State);
    state.own.readyState = connection.getReadyState();

    // The close event is fired from the pump, never from here: script called
    // close() and must see readyState CLOSING (or CLOSED) return first.
    if (internal.poll) |token| token.arm();
}

/// Operation: send
/// Spec: https://websockets.spec.whatwg.org/#dom-websocket-send
///
/// The send(data) method steps are:
/// 1. If this's ready state is CONNECTING, throw an "InvalidStateError" DOMException.
/// 2. Run the appropriate set of steps from the following list:
///    - If data is a string: Let data be the result of converting data to a sequence of Unicode scalar values.
///    - If data is a Blob: Let data be the raw data represented by data.
///    - If data is an ArrayBuffer: Let data be the data stored in data.
///    - If data is an ArrayBufferView: Let data be the data stored in the buffer described by data.
/// 3. If the WebSocket connection is established and this's ready state is OPEN,
///    then send data using the WebSocket.
/// 4. Otherwise, discard data.
/// 5. Increase this's bufferedAmount by the byte length of data.
pub fn call_send(instance: *runtime.Instance, data: runtime.JSValue) anyerror!void {
    const internal = getInternal(instance) orelse return;
    const connection = internal.connection orelse return;

    // Step 1. CONNECTING is an "InvalidStateError" DOMException - the one case
    // where send reports a problem to script at all.
    if (internal.getReadyState() == 0) {
        return error.InvalidStateError;
    }

    // Step 2. Read the payload out of the argument. `send` accepts
    // (USVString or Blob or ArrayBuffer or ArrayBufferView); anything else has
    // already been rejected by the binding layer.
    var scratch: ?[]u8 = null;
    defer if (scratch) |s| internal.allocator.free(s);

    const payload = try payloadOf(internal, data, &scratch);

    // Steps 3-4. Send if the connection is established and OPEN; otherwise the
    // data is DISCARDED, silently. Not an error - CLOSING and CLOSED are both
    // normal states to call send in.
    if (internal.getReadyState() != 1) {
        // Step 5 still applies: bufferedAmount counts data that was queued and
        // not transmitted.
        connection.buffered_amount += payload.bytes.len;
        syncState(instance);
        return;
    }

    if (payload.is_text) {
        connection.sendText(payload.bytes) catch |err| {
            log.warn("send text on {s} failed: {s}", .{ internal.url_string, @errorName(err) });
            return;
        };
    } else {
        connection.sendBinary(payload.bytes) catch |err| {
            log.warn("send binary on {s} failed: {s}", .{ internal.url_string, @errorName(err) });
            return;
        };
    }

    syncState(instance);
}

const Payload = struct {
    bytes: []const u8,
    is_text: bool,
};

/// The bytes a `send` argument stands for, and whether they are a text frame.
///
/// `scratch` receives an allocation only when one was needed; everything else
/// is a view into V8's own backing store, valid for this call only - which is
/// all `curl_ws_send` needs, since it copies.
fn payloadOf(
    internal: *InternalState,
    data: runtime.JSValue,
    scratch: *?[]u8,
) !Payload {
    const v8 = v8_engine.ffi;

    // A string that the binding layer already converted for us.
    if (data == .string) return .{ .bytes = data.string.data, .is_text = true };

    if (data != .handle) return .{ .bytes = "", .is_text = true };
    const value: *v8.Value = @ptrCast(@alignCast(data.handle.ptr));

    if (v8.v8_Value_IsString(value)) {
        const str: *v8.String = @ptrCast(value);
        const utf8_len = v8.v8_String_Utf8Length(str);
        if (utf8_len <= 0) return .{ .bytes = "", .is_text = true };
        const buffer = try internal.allocator.alloc(u8, @intCast(utf8_len));
        scratch.* = buffer;
        _ = v8.v8_String_WriteUtf8(str, buffer.ptr, utf8_len);
        return .{ .bytes = buffer, .is_text = true };
    }

    if (v8.v8_Value_IsArrayBuffer(value)) {
        const ab: *v8.ArrayBuffer = @ptrCast(value);
        const len = v8.v8_ArrayBuffer_ByteLength(ab);
        if (len == 0) return .{ .bytes = "", .is_text = false };
        const ptr = v8.v8_ArrayBuffer_Data(ab) orelse return .{ .bytes = "", .is_text = false };
        const bytes: [*]const u8 = @ptrCast(ptr);
        return .{ .bytes = bytes[0..len], .is_text = false };
    }

    if (v8.v8_Value_IsArrayBufferView(value)) {
        // A view sends the bytes it describes, NOT its whole buffer - which is
        // the entire point of `Send-binary-arraybufferview-*-offset-length`.
        const ab = v8.v8_TypedArray_Buffer(value) orelse return .{ .bytes = "", .is_text = false };
        const offset = v8.v8_TypedArray_ByteOffset(value);
        const len = v8.v8_TypedArray_ByteLength(value);
        if (len == 0) return .{ .bytes = "", .is_text = false };
        const ptr = v8.v8_ArrayBuffer_Data(ab) orelse return .{ .bytes = "", .is_text = false };
        const bytes: [*]const u8 = @ptrCast(ptr);
        return .{ .bytes = bytes[offset..][0..len], .is_text = false };
    }

    // TODO(websockets): send(Blob). The bytes live in `impls/Blob.zig`'s
    // BlobData, and `interfaces.Blob` exposes no synchronous accessor for them
    // - only `arrayBuffer()`, `text()` and `bytes()`, which all return
    // promises. Reading them directly would be a new impls-boundary call, which
    // AGENTS.md lists as non-negotiable; doing it properly needs a delegate on
    // Blob's (generated) interface plus the spec's asynchronous "queue the
    // data" step. Until then a Blob counts toward bufferedAmount and is not
    // transmitted, so `Send-binary-blob.any.js` reports a failure rather than
    // hiding one.
    return .{ .bytes = "", .is_text = false };
}

// =============================================================================
// Helper functions for connection management
// =============================================================================

/// Synchronize the WebIDL state with the underlying connection state.
/// Call this after any operation that might change connection state.
pub fn syncState(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    const state = instance.getState(State);

    // Sync readyState
    state.own.readyState = internal.getReadyState();

    // Sync bufferedAmount
    state.own.bufferedAmount = internal.getBufferedAmount();

    // Sync protocol
    if (internal.getProtocol()) |proto| {
        state.own.protocol = runtime.DOMString.initInterned(proto);
    }

    // Sync extensions
    if (internal.getExtensions()) |ext| {
        state.own.extensions = runtime.DOMString.initInterned(ext);
    }
}

/// Get the underlying connection for direct access (for event loop integration)
pub fn getConnection(instance: *runtime.Instance) ?*WebSocketConnection {
    const internal = getInternal(instance) orelse return null;
    return internal.connection;
}
