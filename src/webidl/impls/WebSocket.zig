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

// A socket keeps its own wrapper alive until it has closed.
const same_object = @import("same_object.zig");

// EventTarget is an ancestor: its impl owns the event listener list, the
// event handlers in it, and trusted dispatch.
const EventTargetImpl = @import("EventTarget.zig");

const log = std.log.scoped(.websocket);

/// The receive scratch: how much of a frame libcurl hands over per call.
///
/// Not a limit on a message's size. The connection assembles each message
/// across as many chunks - and frames - as it arrives in; this only sets how
/// many calls that takes.
const RECV_BUFFER_SIZE: usize = 64 * 1024;

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
    // which aborts the process. `pumpInScope` opens it.
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
///
/// If no isolate can be found, the pump does NOTHING rather than proceed
/// unscoped, and reports itself live so the next turn can try again. A socket
/// that never pumps times out; one that pumps unscoped takes the process down
/// and every remaining test file with it.
///
/// ## A worker socket
///
/// A worker realm has no event loop of its own: its tasks run as timers on the
/// page's loop, so a worker socket's pump turn starts with the PAGE's isolate
/// entered. Three things make it a turn of the worker instead:
///
/// 1. ENTER the socket's isolate (`v8_Isolate_Enter`). A HandleScope on the
///    worker's isolate is not enough, and neither is entering the worker's
///    context: everything below - `JsScope`, the event wrappers, the listener
///    calls, `binaryPayload` - asks `v8_Isolate_GetCurrent()`, and
///    until the isolate is entered that answers with the page's. Handles made
///    there, under a scope opened on the worker's isolate, are the "Cannot
///    create a handle without a HandleScope" abort that kept worker sockets
///    unpumped until now. AbortSignal.timeout()'s task hit the same wall
///    (AGENTS.md, "A task fired into a worker from outside must end the
///    worker's turn").
/// 2. A `JsScope` on the socket's own realm: a HandleScope plus its context.
/// 3. END the worker's turn (`finishTaskIn`), with the isolate still entered:
///    a microtask checkpoint, then whatever the worker posted to the page. The
///    harness in a worker reports its results by message, so a close event
///    that ran `test.done()` and stopped there would still read as a timeout.
///
/// Every step is a no-op for a window socket: its isolate is already the
/// current one, and `finishTaskIn` finds no worker with that isolate.
///
/// A worker realm that ends frees every Instance in its wrapper cache, and
/// `InternalState.deinit` cancels the token on the way, so no turn is ever
/// pumped into a disposed isolate.
fn pumpInScope(instance: *runtime.Instance) bool {
    const ffi = v8_engine.ffi;

    const internal = getInternal(instance) orelse return false;
    const isolate = internal.isolate orelse ffi.v8_Isolate_GetCurrent() orelse return true;

    // 1. The socket's isolate, entered for the whole turn.
    const entered = ffi.v8_Isolate_GetCurrent() != isolate;
    if (entered) ffi.v8_Isolate_Enter(isolate);
    defer if (entered) ffi.v8_Isolate_Exit(isolate);

    // 2. A scope and the socket's realm. `pump` may run script that frees the
    //    WebSocket, so nothing after it reads `instance` - the scope carries
    //    its own context and isolate.
    const live = blk: {
        const scope = v8_engine.JsScope.init(instance.ctx) orelse break :blk true;
        defer scope.deinit();
        break :blk pump(instance);
    };

    // 3. The end of the turn, for a worker; nothing for a window.
    @import("html").worker_v8_context.finishTaskIn(isolate);
    return live;
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

    /// The isolate the socket was made in: the page's, or a worker's. The pump
    /// enters it for each turn (see `pumpInScope`).
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
    /// life. Not a stack array: `pump` runs as a timer callback, and a 64 KB
    /// frame there is a stack overflow waiting for the right call depth.
    recv_buffer: ?[]u8 = null,

    /// What `bufferedAmount` returns (WebSockets § 3.1): the application data
    /// send() queued that had not been transmitted "as of the last time the
    /// event loop reached step 1", plus whatever send() queued since - "this
    /// thus includes any text sent during the execution of the current task".
    ///
    /// So send() adds to it, and only a pump turn - a task, so the event loop
    /// has been through step 1 since - brings it back to what the connection
    /// still holds. Reading the connection directly instead reported 0 straight
    /// after a send() the socket took at once, which `Send-data.any.js` and
    /// every test like it assert against.
    buffered_amount: u64 = 0,

    /// The socket's own wrapper, held from construction until the close event
    /// has fired.
    ///
    /// WebSockets § 7: a WebSocket whose connection is not yet closed must not
    /// be collected while it has listeners for the events still to come - and
    /// a socket is routinely held by nothing but its listeners
    /// (`new WebSocket(url).onmessage = f`). Blink holds it for as long as its
    /// channel exists (WebSocket::HasPendingActivity); this is that, through
    /// the same Pin XMLHttpRequest holds across a fetch. Released in the close
    /// task, and in deinit, which is how a realm's teardown gets past it.
    keep_alive: same_object.Pin = .{},

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .connection = null,
            .url_string = "",
            .binary_type = ._blob_,
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

        self.keep_alive.release();

        if (self.connection) |conn| {
            conn.deinit();
            self.connection = null;
        }
        if (self.requested_protocols) |protos| {
            for (protos) |p| self.allocator.free(p);
            self.allocator.free(protos);
            self.requested_protocols = null;
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

    /// `bufferedAmount`. See the field.
    pub fn getBufferedAmount(self: *const InternalState) u64 {
        return self.buffered_amount;
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
///
/// Through EventTarget's init, which registers the EventTarget state - the
/// event listener list and the event handler map - that every WebSocket event
/// is dispatched through. Made with `runtime.Instance.init` instead, a socket
/// had that state only once `addEventListener` created it lazily, so
/// `ws.onerror = f` on a fresh socket threw InvalidStateError.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return EventTargetImpl.init(allocator, StateType, vtable, ctx);
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

    // And the EventTarget state: listeners, handlers and the registry entry.
    // The registry is keyed by address, so an entry left behind is inherited
    // by whatever the slab puts at this address next - listeners and all.
    EventTargetImpl.deinit(instance);
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
/// One turn is one task, so each thing it fires is fired from a task, as
/// WebSockets § 4 queues them: the connection established (`open`), a message
/// received (`message`), the connection closed (`error` if it was failed,
/// then `close`).
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

    // 1. Establish the WebSocket connection (constructor step 12, "in
    //    parallel"). Begun on the first turn rather than in the constructor so
    //    that `new WebSocket(url)` returns CONNECTING; after that, advanced a
    //    step per turn so that script keeps running while it is in flight.
    if (!internal.connect_attempted and !connection.closed) {
        internal.connect_attempted = true;
        const origin = clientOrigin(instance.ctx);
        defer if (origin) |o| instance.ctx.allocator.free(o);
        connection.startConnect(.{
            .protocols = internal.requested_protocols,
            .origin = origin,
        }) catch |err| {
            log.debug("handshake to {s} failed to start: {s}", .{ internal.url_string, @errorName(err) });
        };
    }
    if (connection.state == .CONNECTING and !connection.closed) {
        const established = connection.pollConnect() catch |err| blk: {
            // "Fail the WebSocket connection" - which `closed` and `failed`
            // now say; the close task below fires `error` and then `close`.
            log.debug("handshake to {s} failed: {s}", .{ internal.url_string, @errorName(err) });
            break :blk false;
        };
        if (established) {
            // § 4, "the WebSocket connection is established": ready state
            // OPEN, protocol and extensions, then `open`.
            syncState(instance);
            fireSimpleEvent(instance, "open");

            // The open listener ran script. It may have closed the socket, and
            // it may have dropped it entirely.
            const after_open = getInternal(instance) orelse return false;
            if (after_open.pump_done) return false;
        }
    }

    // 2. The network takes what send() and close() queued.
    connection.flush();

    // 3. The event loop has reached step 1 since the last turn: bufferedAmount
    //    is what the connection still holds.
    internal.buffered_amount = connection.bufferedAmount();

    // 4. Receive. `connection.receive` reports "nothing yet" as null, and
    //    handles a Close frame or a lost transport itself, so the loop ends on
    //    a quiet socket or a closed one.
    const buffer = internal.recvBuffer() orelse return false;
    while (!connection.closed and (connection.state == .OPEN or connection.state == .CLOSING)) {
        const message = connection.receive(buffer) catch |err| {
            log.warn("receive on {s} failed: {s}", .{ internal.url_string, @errorName(err) });
            connection.fail();
            break;
        } orelse break;

        // § 4, "a WebSocket message has been received", step 1: if the ready
        // state is not OPEN, return. A message that arrives after close() is
        // dropped.
        if (connection.state != .OPEN) continue;

        fireMessageEvent(instance, internal, message.data, message.is_text);

        // Dispatch runs script, which may have closed or dropped the socket.
        const after_message = getInternal(instance) orelse return false;
        if (after_message.pump_done) return false;
    }

    // 5. The WebSocket connection is closed: the close task.
    if (connection.closed) {
        finishClose(instance, internal);
        return false;
    }

    return true;
}

/// The task WebSockets § 4 queues when "the WebSocket connection is closed":
///
/// 1. Change the ready state to CLOSED.
/// 2. If the user agent was required to fail the WebSocket connection, fire
///    `error`.
/// 3. Fire `close`, with wasClean, the connection close code and the
///    connection close reason.
///
/// Runs once. The close event's values are read before `error` fires: an
/// error listener runs script, and script may drop the WebSocket and its
/// connection with it.
fn finishClose(instance: *runtime.Instance, internal: *InternalState) void {
    if (internal.pump_done) return;
    internal.pump_done = true;

    const connection = internal.connection orelse return;
    var reason_buffer: [@import("websocket").connection.max_close_payload]u8 = undefined;
    const reason = connection.close_reason orelse "";
    const n = @min(reason.len, reason_buffer.len);
    @memcpy(reason_buffer[0..n], reason[0..n]);
    const outcome: CloseOutcome = .{
        .was_clean = connection.close_was_clean,
        .code = connection.close_code orelse 1006,
        .reason = reason_buffer[0..n],
    };
    const failed = connection.failed;

    // 1.
    connection.state = .CLOSED;
    syncState(instance);

    // 2.
    if (failed) {
        fireSimpleEvent(instance, "error");
        // Script ran: the WebSocket may be gone. Nothing below reads it but
        // through `instance`, which the dispatch paths look up afresh.
        if (getInternal(instance) == null) return;
    }

    // 3.
    fireCloseEvent(instance, outcome);

    // Nothing more will fire: the socket's lifetime is its wrapper's again.
    if (getInternal(instance)) |live| live.keep_alive.release();
}

const CloseOutcome = struct {
    was_clean: bool,
    code: u16,
    reason: []const u8,
};

/// The client's origin, serialized, for the handshake's `Origin` header:
/// this's relevant settings object's origin (Fetch appends a request Origin
/// header to every request whose mode is "websocket"). Read through the
/// realm's global, which is a Window or a WorkerGlobalScope and so answers
/// WindowOrWorkerGlobalScope's `origin`. Owned by `ctx.allocator`.
fn clientOrigin(ctx: runtime.Context) ?[]const u8 {
    const ffi = v8_engine.ffi;
    const engine_ctx = ctx.engine_ctx orelse return null;
    const v8_context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const global = ffi.v8_Context_Global(v8_context) orelse return null;
    defer ffi.v8_Object_Dispose(global);
    const raw = ffi.v8_Object_GetAlignedPointerFromInternalField(global, 0) orelse return null;
    const global_instance: *runtime.Instance = @ptrCast(@alignCast(raw));
    const origin = @import("mixins").WindowOrWorkerGlobalScope.get_origin(global_instance) catch return null;
    // "null" is an opaque origin, and a header saying so is still the one to send.
    return origin;
}

// =============================================================================
// Event dispatch
//
// One place a listener can be: the event listener list, which holds both the
// `addEventListener` listeners and the event handlers (`ws.onopen = f`), in
// the order they were activated (HTML § 8.1.8.1). So trusted dispatch alone
// reaches every one, `ws.dispatchEvent(e)` reaches `ws.onerror` too, and each
// runs with the WebSocket as `this`.
// =============================================================================

fn fireSimpleEvent(instance: *runtime.Instance, name: []const u8) void {
    const ctx = instance.ctx;
    const type_string = runtime.DOMString.initInterned(name);

    const event = interfaces.Event.call_constructor(
        ctx,
        type_string,
        webidl.Opt(dictionaries.EventInit).notPassed(),
    ) catch return;

    deliver(instance, event, type_string, .plain);
}

fn fireCloseEvent(instance: *runtime.Instance, outcome: CloseOutcome) void {
    const ctx = instance.ctx;
    const type_string = runtime.DOMString.initInterned("close");

    const init_dict = dictionaries.CloseEventInit{
        .base = .{},
        .wasClean = outcome.was_clean,
        .code = outcome.code,
        .reason = outcome.reason,
    };

    const event = interfaces.CloseEvent.call_constructor(
        ctx,
        type_string,
        webidl.Opt(dictionaries.CloseEventInit).passed(init_dict),
    ) catch return;

    deliver(instance, event, type_string, .close);
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

    deliver(instance, event, type_string, .message);
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

/// Fire `event` at the WebSocket, then release it if nothing kept it.
fn deliver(
    target: *runtime.Instance,
    event: *runtime.Instance,
    type_string: runtime.DOMString,
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

    // Fired by the user agent, so trusted (DOM 2.10). EventTarget is an
    // ancestor, so its impl.
    _ = EventTargetImpl.dispatchTrusted(target, event) catch |err| {
        log.debug("dispatch of {s} failed: {s}", .{ type_string.asSlice(), @errorName(err) });
    };

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

/// Constructor implementation
/// Spec: https://websockets.spec.whatwg.org/#dom-websocket-websocket
///
/// The WebSocket(url, protocols) constructor steps are:
/// 1. Let baseURL be this's relevant settings object's API base URL.
/// 2. Let urlRecord be the result of applying the URL parser to url with baseURL.
/// 3. If urlRecord is failure, throw a "SyntaxError" DOMException.
/// 4. If urlRecord's scheme is "http", set it to "ws".
/// 5. Otherwise, if urlRecord's scheme is "https", set it to "wss".
/// 6. If urlRecord's scheme is not "ws" or "wss", throw a "SyntaxError" DOMException.
/// 7. If urlRecord's fragment is non-null, throw a "SyntaxError" DOMException.
/// 8. If protocols is a string, set protocols to a sequence consisting of just that string.
/// 9. If any of the values in protocols occur more than once or contain illegal values,
///    throw a "SyntaxError" DOMException.
/// 10. Set this's url to urlRecord.
/// 11. Let client be this's relevant settings object.
/// 12. Run this step in parallel: Establish a WebSocket connection given urlRecord,
///     protocols, and client.
pub fn call_constructor(ctx: runtime.Context, url: runtime.USVString, protocols: webidl.Opt(runtime.JSValue)) !*runtime.Instance {
    // Steps 1-2. Parse url against this's relevant settings object's API base
    // URL. With no base, which is what this passed, every relative url - "",
    // "test", "?" - failed step 3 instead of resolving against the page.
    //
    // A prefix test (`startsWith("ws://")`, which this was before the parser)
    // is not equivalent either: `ws://web platform.test:80/echo` is a
    // SyntaxError because a space cannot appear in a host.
    var base_record: ?@import("url_record").URLRecord = null;
    defer if (base_record) |*b| b.deinit();
    if (apiBaseURL(ctx)) |base| {
        defer ctx.allocator.free(base);
        base_record = api_parser.parseURL(ctx.allocator, base, null) catch null;
    }

    var record = api_parser.parseURL(
        ctx.allocator,
        url,
        if (base_record) |*b| b else null,
    ) catch {
        // Step 3. Parse failure is a "SyntaxError" DOMException.
        return error.SyntaxError;
    };
    defer record.deinit();

    // Steps 4-5. "http" becomes "ws" and "https" becomes "wss".
    const scheme = record.scheme();
    const ws_scheme: []const u8 = if (std.mem.eql(u8, scheme, "http"))
        "ws"
    else if (std.mem.eql(u8, scheme, "https"))
        "wss"
    else
        scheme;

    // Step 6. The scheme must now be "ws" or "wss".
    if (!std.mem.eql(u8, ws_scheme, "ws") and !std.mem.eql(u8, ws_scheme, "wss")) {
        return error.SyntaxError;
    }

    // Step 7. A non-null fragment is a "SyntaxError" DOMException - including
    // an EMPTY one, so `ws://host/#` is just as invalid as `ws://host/#x`.
    if (record.has_fragment) {
        return error.SyntaxError;
    }

    // Step 10. This's url is urlRecord, and the `url` getter serializes it.
    // Serialized once, here: nothing changes a WebSocket's url afterwards.
    // Swapping the scheme on the serialization is exact, because each pair
    // shares its default port (80 for http and ws, 443 for https and wss), so
    // the parser elided the same port either way and nothing but the scheme
    // differs.
    const serialized = try @import("url_serializer").serialize(ctx.allocator, &record, false);
    defer ctx.allocator.free(serialized);
    const url_string = try std.mem.concat(ctx.allocator, u8, &.{ ws_scheme, serialized[scheme.len..] });
    var url_owned = true;
    defer if (url_owned) ctx.allocator.free(url_string);

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
    const connection = try WebSocketConnection.init(ctx.allocator, url_string);
    internal.connection = connection;

    // The serialized url, owned by the internal state from here on.
    internal.url_string = url_string;
    url_owned = false;
    state.own.url = internal.url_string;

    // Initialize state from connection
    state.own.readyState = connection.getReadyState();
    state.own.bufferedAmount = 0;
    state.own.extensions = runtime.DOMString.initEmpty();
    state.own.protocol = runtime.DOMString.initEmpty();
    state.own.binaryType = ._blob_;
    internal.binary_type = ._blob_;

    // Steps 8-9. protocols is a string or a sequence of strings. Each must be a
    // valid HTTP token, and no value may repeat (ASCII case-insensitively) -
    // otherwise throw a "SyntaxError" DOMException.
    internal.requested_protocols = try parseProtocols(ctx.allocator, protocols);

    // Step 12. "Run this step in parallel: establish a WebSocket connection."
    //
    // Deferred to the pump's first turn rather than done here. Connecting
    // inline would block the constructor on a network handshake and, worse,
    // leave readyState at OPEN before the caller had a chance to see
    // CONNECTING - which several tests in `websockets/` assert directly.
    //
    // A worker realm is pumped the same way: its timer is the page's, and
    // `pumpInScope` enters the worker's isolate for each turn.
    const timer = ctx.getOptionalTimer() orelse {
        // No timer means no event loop, so nothing could ever deliver an event.
        // Leave the socket in CONNECTING rather than pretending otherwise.
        log.warn("no timer interface in this realm; WebSocket to {s} cannot be pumped", .{url});
        return instance;
    };
    const token = try PollToken.create(instance, timer);
    internal.poll = token;
    token.arm();

    internal.keep_alive.hold(instance);

    return instance;
}

/// This's relevant settings object's API base URL, owned by `ctx.allocator`.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#api-base-url
///
/// A window's is its document's base URL, read through the Document's
/// `baseURI`; a worker's is its script URL, which the context entry records
/// (html/worker_v8_context.zig). The same lookup `Request`'s constructor makes.
fn apiBaseURL(ctx: runtime.Context) ?[]u8 {
    if (ctx.getEngineContextAs(v8_engine.ffi.Context)) |v8_context| {
        if (v8_engine.context_manager.getWindowForContext(v8_context)) |window| {
            const document = interfaces.Window.get_document(window) catch null;
            if (document) |d| {
                const base = interfaces.Node.get_baseURI(d) catch null;
                if (base) |b| {
                    if (b.len > 0) return @constCast(b);
                    d.ctx.allocator.free(b);
                }
            }
        }
        if (v8_engine.context_manager.getDocumentUrl(v8_context)) |document_url| {
            if (document_url.len > 0) return ctx.allocator.dupe(u8, document_url) catch null;
        }
    }
    return null;
}

/// Steps 8-9 of the constructor: validate and copy the requested subprotocols.
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

    // Step 9. Any value that is not a token, or that repeats, is a SyntaxError.
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

    // WebIDL § 3.2.24, union conversion: anything that is not an object is
    // converted to the union's DOMString. The binding has already done that for
    // a string - it arrives here as `.string`, never as a handle - and this used
    // to return on any non-handle, so `new WebSocket(url, "/echo")` sent no
    // protocol at all instead of throwing the SyntaxError step 9 requires.
    switch (value) {
        .string => |s| return list.append(allocator, try allocator.dupe(u8, s.data)),
        .boolean => |b| return list.append(allocator, try allocator.dupe(u8, if (b) "true" else "false")),
        .null => return list.append(allocator, try allocator.dupe(u8, "null")),
        .number => |n| return list.append(allocator, try numberToString(allocator, n)),
        .handle => {},
        // `undefined` is the omitted argument's default: the empty sequence.
        .undefined, .instance => return,
    }
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

/// ECMAScript's Number::toString, for a number passed as a protocol.
///
/// Exact for NaN, the infinities and every integer below 10^21 (which is what
/// an integer argument is); other values take the shortest round-trip form,
/// which differs from ECMAScript's only in exponent notation. Any of these that
/// is not an HTTP token is rejected by step 9 either way.
fn numberToString(allocator: std.mem.Allocator, n: f64) ![]const u8 {
    if (std.math.isNan(n)) return allocator.dupe(u8, "NaN");
    if (std.math.isInf(n)) return allocator.dupe(u8, if (n > 0) "Infinity" else "-Infinity");
    if (n == @trunc(n) and @abs(n) < 1e21) {
        return std.fmt.allocPrint(allocator, "{d}", .{@as(i128, @intFromFloat(n))});
    }
    return std.fmt.allocPrint(allocator, "{d}", .{n});
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

/// Getter for onopen (HTML § 8.1.8.1, the event handler IDL attribute).
pub fn get_onopen(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "open");
}

/// Getter for onerror (HTML § 8.1.8.1, the event handler IDL attribute).
pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "error");
}

/// Getter for onclose (HTML § 8.1.8.1, the event handler IDL attribute).
pub fn get_onclose(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "close");
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

/// Getter for onmessage (HTML § 8.1.8.1, the event handler IDL attribute).
pub fn get_onmessage(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "message");
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

/// Setter for onopen: the handler joins the event listener list, where
/// dispatch finds it in the order it was activated.
pub fn set_onopen(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "open", value);
}

/// Setter for onerror: the handler joins the event listener list, where
/// dispatch finds it in the order it was activated.
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "error", value);
}

/// Setter for onclose: the handler joins the event listener list, where
/// dispatch finds it in the order it was activated.
pub fn set_onclose(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "close", value);
}

/// Setter for onmessage: the handler joins the event listener list, where
/// dispatch finds it in the order it was activated.
pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "message", value);
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
    // already-closing socket.
    if (internal.pump_done) return;

    // Step 3's other cases: fail a connection not yet established, or start
    // the closing handshake. Either way the ready state is now CLOSING.
    //
    // What the close event reports is NOT decided here. It is the connection
    // close code and reason (RFC 6455 § 7.1.5, 7.1.6) - those of the Close
    // frame the peer sends back - or 1006 and "" for a failed connection,
    // whatever close() asked for.
    const close_code: ?u16 = if (code.was_passed) code.value else null;
    try connection.close(close_code, reason_str);
    syncState(instance);

    // The close event is fired from the pump, never from here: script called
    // close() and must see readyState CLOSING return first.
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

    // Steps 3-4. Send if the connection is established and its closing
    // handshake has not started; otherwise the data is discarded, silently.
    // Not an error - CLOSING and CLOSED are both normal states to call send in.
    // The connection decides which, and queues what it sends behind what is
    // already waiting.
    connection.send(if (payload.is_text) .text else .binary, payload.bytes) catch |err| {
        log.warn("send on {s} failed: {s}", .{ internal.url_string, @errorName(err) });
    };

    // Step 5. "Increase this's bufferedAmount by the byte length of data" -
    // sent or discarded, it counts until a later task finds it transmitted.
    internal.buffered_amount += payload.bytes.len;
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
