//! Implementation for MessagePort interface
//!
//! Spec: HTML Standard § 9.4.3 Message ports
//! https://html.spec.whatwg.org/multipage/web-messaging.html#message-ports
//!
//! A MessagePort is one end of a channel. The channel - both ends' port
//! message queues and their entanglement - is a `dom.port_channels.Channel`,
//! which may have its two ends on two threads: a port transferred to a
//! worker lives in the worker's realm, on the worker's thread. A MessagePort
//! object owns one END of a channel and receives what arrives there, from
//! tasks posted to its realm's event loop (`ContextData.task_sink`);
//! transferring the port ships the end, queue and entanglement included, to a
//! new MessagePort in the receiving realm (the transfer and transfer-receiving
//! steps), so the channel keeps working across realms, agents and threads.
//!
//! Every message goes the spec's way, whether the other end is in this realm,
//! another window's or a worker's: StructuredSerializeWithTransfer at the
//! sender, a task on the receiving end's port message queue, and there
//! StructuredDeserializeWithTransfer into the receiver's realm and a `message`
//! event fired at the port. Both halves go through the engine protocol. The
//! transfer list's platform objects - ports, streams - are transferred and
//! received by the one shared step every carrier runs (dom.transferables).
//!
//! A stream's cross-realm transform (Streams 8.2) listens and posts on ports
//! of its own, which script never sees (`hidden`): their messages go the same
//! way, and at the receiving port run the transform's native message and
//! messageerror steps instead of firing events - WebKit's
//! MessagePort::setMessageHandler, Blink's native listeners.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const dom = @import("dom");
const MessagePort = interfaces.MessagePort;

// The channel ends, which cross threads.
const port_channels = dom.port_channels;
const End = port_channels.End;
const PortMessage = port_channels.PortMessage;

/// The hook other types transfer ports through (no IDL member runs the
/// transfer steps).
const message_ports = dom.message_ports;

pub const State = MessagePort.State;

pub const ImplError = error{
    NotImplemented,
    PortClosed,
    NotEntangled,
    OutOfMemory,
};

/// Internal state for MessagePort implementation
pub const InternalState = struct {
    /// This port's end of its channel - its port message queue and its
    /// entanglement - while this port has it: null once it is shipped (the
    /// transfer steps hand it to the port the receiving realm makes of it).
    end: ?*End,

    /// Allocator used for this state
    allocator: std.mem.Allocator,

    /// HTML: "has been shipped".
    has_been_shipped: bool = false,

    /// The port's one pending-activity keep is held (while it is enabled
    /// and entangled): the keep is counted, so `syncPendingActivity` keeps
    /// once and releases once.
    kept_alive: bool = false,

    /// [[Detached]]: set by close(), and by the transfer steps.
    detached: bool = false,

    /// A task that enables the end again once the port's page is fully
    /// active waits in its realm's loop (`EnableWhenActive`).
    enable_queued: bool = false,

    /// A port a cross-realm transform made (Streams 8.2, dom.message_ports
    /// `hidden`): what reaches it runs these native steps instead of firing
    /// `message` or `messageerror` - script never holds the port, so no
    /// listener could hear them. Told when the port goes (`released`).
    native: ?message_ports.NativeReceiver = null,

    pub fn deinit(self: *InternalState) void {
        // The port goes, and its end with it: disentangled (its peer hears
        // `close`), its queue dropped.
        if (self.end) |end| end.discard();
        self.end = null;
        // Its cross-realm transform hears that the port is gone.
        if (self.native) |receiver| receiver.released(receiver.ctx);
        self.native = null;
    }

    /// HTML's MessagePort transfer steps (value = this port): set its "has
    /// been shipped" flag, and hand over its end - which carries the port
    /// message queue ([[PortMessageQueue]]) and the entanglement
    /// ([[RemotePort]]) - as the data holder. The port is detached; it no
    /// longer hears its end's messages, and the end is no longer its to free.
    pub fn transfer(self: *InternalState) ?*End {
        self.has_been_shipped = true;
        self.detached = true;
        const end = self.end orelse return null;
        end.unbind();
        self.end = null;
        return end;
    }
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    message_ports.install(.{
        .transferable_state = transferableState,
        .ship = ship,
        .receive = receive,
        .adopt = adopt,
        .discard = discard,
        .hidden = hidden,
        .post = postFromHidden,
        .disentangle = disentangle,
    });
    dom.unloading_cleanup.install(&disentangleIn);
}

/// Initialize instance: a port on no channel - entangled with nothing. (Every
/// port script sees comes from a MessageChannel, or a transfer: `adopt`,
/// `receive`.)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const channel = try port_channels.Channel.create(allocator);
    // The other end goes at once: this one is disentangled.
    channel.end(1).discard();
    errdefer channel.end(0).discard();
    return initWithEnd(allocator, StateType, vtable, ctx, channel.end(0));
}

/// A MessagePort for an existing end, which it takes: MessageChannel's two,
/// and a transferred port's in the receiving realm - HTML's transfer-receiving
/// steps, which give the new port the end's queue and entanglement. The new
/// port owns the end and hears its messages from now on, from tasks of its
/// realm's event loop; its queue starts disabled, whatever it was before the
/// end was shipped, until this port's start() or onmessage.
fn initWithEnd(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    end: *End,
) !*runtime.Instance {
    // A MessagePort is an EventTarget: `message` is fired at it and heard.
    const instance = try interfaces.EventTarget.initWithState(allocator, StateType, vtable, ctx);
    errdefer interfaces.EventTarget.deinit(instance);

    const internal_state = try allocator.create(InternalState);
    internal_state.* = .{
        .end = end,
        .allocator = allocator,
    };
    instance.getState(StateType).own._internal = internal_state;

    // The receiver: this port, on its realm's event loop. A realm with no
    // loop to post to (none made it) leaves the end unbound: its messages
    // wait, as for a port whose queue is not enabled.
    if (ctx.task_sink) |sink| end.bind(.{
        .sink = sink,
        .receiver = instance,
        .generation = runtime.SlabAllocator.generationOf(instance),
        .hooks = &port_hooks,
    });
    // Its document's destruction disentangles it (`disentangleIn`): its
    // realm keeps it on its list of ports.
    ctx.addObject(.message_ports, instance) catch {};
    return instance;
}

// Every MessagePort is on its realm's list of ports, from init to deinit
// (runtime.ContextData objects(.message_ports)): the ports "destroy a
// document" reaches (`disentangleIn`) - "MessagePorts whose relevant global
// object's associated Document is document", a realm's. It was one list per
// thread, every realm's ports in it, filtered by realm at each walk.

/// `instance` is gone from its realm's list. The list's memory goes with its
/// last port.
fn forgetPort(instance: *runtime.Instance) void {
    instance.ctx.forgetObject(.message_ports, instance);
}

/// HTML "destroy a document" steps 4-5: "Let ports be the list of
/// MessagePorts whose relevant global object's associated Document is
/// document. For each port in ports, disentangle port." - for the ports of
/// `realm`, whose document is destroyed. Each port's end is unbound too: a
/// task already queued for it then finds a later epoch and runs nothing -
/// HTML "destroy a document" step 6.2 removes the document's tasks from
/// their queues unrun - and the task itself is freed by whichever loop holds
/// it, when it runs or when that loop ends (a loop that never runs again
/// drops what it holds: runtime.TaskSink). A disentangled port has no
/// pending activity left, so the hold that kept it - and through it its
/// realm - while its channel lived goes (Blink: MessagePort::ContextDestroyed
/// closes the port). Installed into the unloading document cleanup steps
/// (dom.unloading_cleanup), which "destroy a document" runs right after these
/// (step 6); a document Crane unloads is always destroyed - it keeps no
/// back/forward cache - so they run at the same moment either way, and a
/// worker's ports go when it ends.
pub fn disentangleIn(realm: runtime.Context) void {
    // Backwards: disentangling posts a task to the peer and frees nothing
    // here, but stay safe if it did.
    const ports = realm.objects(.message_ports);
    var i = ports.items.len;
    while (i > 0) {
        i -= 1;
        if (i >= ports.items.len) continue;
        const port: *runtime.Instance = @ptrCast(@alignCast(ports.items[i]));
        disentangle(port);
        const internal = getInternal(port) orelse continue;
        if (internal.end) |end| end.unbind();
    }
}

/// HTML "disentangle" (9.4.4), initiated by `instance`: the two ports are
/// disentangled, and the other one is told so from a task of its own realm -
/// which may be another agent's, on another thread - so its pending activity
/// ends (no event: see `peerDisentangledSteps`).
fn disentangle(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    // A shipped port is not entangled: its end is another port's now.
    const end = internal.end orelse return;
    end.disentangle();
    syncPendingActivity(instance);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    forgetPort(instance);
    // Whatever pending-activity hold is left on it goes with it.
    releasePendingActivity(instance);
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    interfaces.EventTarget.deinit(instance);
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

// ============================================================================
// Event handlers (HTML § 9.4.3: onmessage, onmessageerror). Their
// values live in EventTarget's event handler map, where a `message` event
// fired at this port finds them.
// ============================================================================

/// "The first time a MessagePort object's onmessage IDL attribute is set, the
/// port's port message queue must be enabled, as if the start() method had
/// been called."
pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try dom.event_handlers.set(typedefs.EventHandler, instance, "message", value);
    enableQueue(instance);
}

/// Operation: start
/// "The start() method steps are to enable this's port message queue, if it
/// is not already enabled."
pub fn call_start(instance: *runtime.Instance) anyerror!void {
    enableQueue(instance);
}

/// Enable the port message queue: its tasks may run now, so the first is
/// posted to the port's loop.
fn enableQueue(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    // A shipped port's end is another port's now.
    const end = internal.end orelse return;
    end.enable();
    syncPendingActivity(instance);
}

/// Blink's MessagePort::HasPendingActivity(): a port whose message queue is
/// enabled and which is entangled must outlive whatever script holds of it.
/// HTML (9.4.6, ports and garbage collection): entangled ports act as if each
/// holds the other strongly - "a message port can be received, given an
/// event listener, and then forgotten, and so long as that event listener
/// could receive a message, the channel will be maintained". A port nobody
/// references that has been started - `channel.port2.onmessage = f` and no
/// other reference - was collected before its message arrived. Kept through
/// the engine's pending-activity hold, taken and released here as the port's
/// state changes: started, closed, shipped, or its peer closed - decided on
/// the port's thread from its end's state read under the channel's lock.
fn syncPendingActivity(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    const active = if (internal.end) |end| blk: {
        const state = end.state();
        break :blk !internal.detached and state.enabled and state.entangled;
    } else false;
    if (active) {
        if (!internal.kept_alive) engine.keepPlatformObjectAlive(instance);
        internal.kept_alive = true;
    } else releasePendingActivity(instance);
}

/// End the pending-activity hold on a port, if it is held (idempotent).
fn releasePendingActivity(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    if (!internal.kept_alive) return;
    internal.kept_alive = false;
    engine.releasePlatformObject(instance);
}

/// Operation: close
/// "1. Set this's [[Detached]] internal slot value to true.
///  2. If this is entangled, disentangle it."
pub fn call_close(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return;
    internal.detached = true;
    // 2. If this is entangled, disentangle it.
    disentangle(instance);
}

// ============================================================================
// Posting (HTML "message port post message steps")
// ============================================================================

/// Operation: postMessage(message, transfer)
/// "2. Let options be «[ "transfer" → transfer ]». 3. Run the message port
/// post message steps providing this, targetPort, message and options."
pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue, transfer: runtime.JSValue) anyerror!void {
    const allocator = instance.ctx.allocator;
    const objects = try engine.convertToSequenceOfObjects(instance.ctx, transfer, allocator);
    defer {
        for (objects) |object| object.release();
        allocator.free(objects);
    }
    const list = try allocator.alloc(runtime.JSValue, objects.len);
    defer allocator.free(list);
    for (objects, list) |object, *item| item.* = object.value;
    return postMessageSteps(instance, message, list);
}

/// Operation: postMessage(message, options)
pub fn call_postMessage__1(instance: *runtime.Instance, message: runtime.JSValue, options: webidl.Opt(dictionaries.StructuredSerializeOptions)) anyerror!void {
    const transfer: []const runtime.JSValue = if (options.wasPassed()) (options.getValue().transfer orelse &.{}) else &.{};
    return postMessageSteps(instance, message, transfer);
}

/// Whether a platform object in a transfer list from `source` (a MessagePort)
/// can be transferred: HTML 2.7.5 steps 2.1 and 5.2, and the message port post
/// message steps' step 2 ("If transfer contains sourcePort, then throw a
/// DataCloneError"). Any transferable platform object - a port, a stream -
/// answers through the one shared step (dom.transferables).
fn transferableFrom(source: ?*anyopaque, instance: *runtime.Instance) runtime.TransferableState {
    if (source) |s| {
        if (@as(*runtime.Instance, @ptrCast(@alignCast(s))) == instance) return .not_transferable;
    }
    return dom.transferables.transferableState(instance);
}

// ============================================================================
// The transfer steps, for other types (dom.message_ports)
// ============================================================================

/// Whether `instance` is a MessagePort that can be transferred.
fn transferableState(instance: *runtime.Instance) runtime.TransferableState {
    const internal = getInternal(instance) orelse return .not_transferable;
    if (internal.detached) return .detached;
    return .transferable;
}

/// The transfer steps for `instance`: its end.
fn ship(instance: *runtime.Instance) ?*anyopaque {
    const internal = getInternal(instance) orelse return null;
    const end = internal.transfer() orelse return null;
    // Detached: no pending activity is left on this object.
    syncPendingActivity(instance);
    return @ptrCast(end);
}

/// Free an end no port took: disentangled from its other end (whose port
/// hears `close`), its queue freed.
fn discard(end: *anyopaque) void {
    const channel_end: *End = @ptrCast(@alignCast(end));
    channel_end.discard();
}

/// The transfer-receiving steps: a new MessagePort of `realm` on `end`.
fn receive(realm: runtime.Context, end: *anyopaque) anyerror!*runtime.Instance {
    const port = try adopt(realm, end);
    getInternal(port).?.has_been_shipped = true;
    return port;
}

/// A new MessagePort of `realm` on `end`, a fresh channel's: MessageChannel's
/// ports, a SharedWorker's outside port.
fn adopt(realm: runtime.Context, end: *anyopaque) anyerror!*runtime.Instance {
    const channel_end: *End = @ptrCast(@alignCast(end));
    errdefer channel_end.discard();
    return initWithEnd(realm.allocator, State, &MessagePort.vtable, realm, channel_end);
}

/// A port for a cross-realm transform (Streams 8.2): a MessagePort of
/// `realm` on `end` - the transfer-receiving steps of a stream's [[port]],
/// or port1 of its transfer steps - whose message and messageerror handlers
/// are `receiver`'s native steps, with its port message queue enabled
/// (SetUpCrossRealmTransformReadable step 5, ...Writable step 6). Being
/// enabled and entangled, it is kept while its channel lives, as any started
/// port is (`syncPendingActivity`). `receiver.released` runs at its deinit.
fn hidden(realm: runtime.Context, end: *anyopaque, receiver: message_ports.NativeReceiver) anyerror!*runtime.Instance {
    const port = try adopt(realm, end);
    const internal = getInternal(port).?;
    internal.native = receiver;
    enableQueue(port);
    return port;
}

/// Streams PackAndPostMessage steps 4-6 from a cross-realm transform's
/// port: the message port post message steps with an empty transfer list.
fn postFromHidden(port: *runtime.Instance, message: runtime.JSValue) anyerror!void {
    return postMessageSteps(port, message, &.{});
}

/// The message port post message steps, given this, the entangled port (if
/// any), message and options["transfer"].
fn postMessageSteps(source: *runtime.Instance, message: runtime.JSValue, transfer: []const runtime.JSValue) anyerror!void {
    const internal = getInternal(source) orelse return;
    const allocator = source.ctx.allocator;

    // 1. targetPort: the end this one is entangled with, if any. A detached
    // port (closed, or shipped - its end is another port's) has none.
    const end: ?*End = if (internal.detached) null else internal.end;
    const has_target = if (end) |e| e.state().entangled else false;

    // Steps 2 and 5: StructuredSerializeWithTransfer(message, transfer) -
    // which throws a DataCloneError when transfer contains sourcePort
    // (`transferableFrom`) - and, step 5.5, the transfer steps of every
    // platform object in transfer, in order: one shared step for every
    // carrier (dom.transferables) - a port ships its end, a stream pipes to
    // a cross-realm transform and ships its other port's end.
    var result = try engine.structuredSerializeWithTransfer(source.ctx, message, transfer, transferableFrom, source, allocator);
    defer result.deinit(allocator);
    const holders = try dom.transferables.transferAll(source.ctx, result.platform_objects, allocator);
    var holders_taken = false;
    // Holders no message took are discarded.
    defer if (!holders_taken) {
        for (holders) |holder| holder.discard();
        allocator.free(holders);
    };
    // Step 3-4: doomed when targetPort is in transfer: its end is shipped
    // with the message posted to it, and the channel is lost.
    var doomed = false;
    if (end) |e| {
        for (holders) |holder| switch (holder) {
            .message_port => |shipped| if (e.isEntangledWith(shipped)) {
                doomed = true;
            },
            else => {},
        };
    }

    // 6. If targetPort is null, or if doomed is true, then return.
    if (!has_target or doomed) return;

    // 7. Add a task to targetPort's port message queue: the message waits on
    // the entangled end, in order, until that end's port enables its queue.
    const port_message = try PortMessage.create(allocator, &result, holders);
    holders_taken = true;
    end.?.post(port_message);
}

// ============================================================================
// The port message queue's task
// ============================================================================

/// What this port does with what reaches its end, on its realm's loop.
const port_hooks: port_channels.ReceiverHooks = .{
    .deliver = deliverHook,
    .closed = closedHook,
};

/// The port, if `receiver` is still the port its end was bound to: a
/// collected port's slot can be reissued.
fn liveReceiver(receiver: *anyopaque, generation: u64) ?*runtime.Instance {
    const port: *runtime.Instance = @ptrCast(@alignCast(receiver));
    if (runtime.SlabAllocator.generationOf(port) != generation) return null;
    return port;
}

/// HTML event loop processing model step 2: a task whose document is not
/// fully active is not run. A port's is its relevant global's document when
/// that is a Window - an iframe removed from its document leaves its realm's
/// ports with none that is (webmessaging/message-channels/detached-iframe:
/// a port kept alive for its pending activity must still hear nothing). A
/// worker's realm has no document. Document's `location` getter answers the
/// question exactly: null unless its document is fully active.
fn documentIsFullyActive(instance: *runtime.Instance) bool {
    // The relevant global object, from the relevant realm's record.
    const record = instance.ctx.getRealm() orelse return true;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return true));
    if (global.stateAs(interfaces.Window.State) == null) return true;
    if (interfaces.Window.get_closed(global) catch true) return false;
    const document = interfaces.Window.get_document(global) catch return false;
    const location = interfaces.Document.get_location(document) catch return false;
    return location != null;
}

/// One task of the port message queue: the message port post message steps'
/// step 7, as a task of the receiving port's realm. (A closing worker's port
/// hears nothing: HTML close() and "terminate a worker" discard every task
/// of the worker's event loop, and the worker's own loop - every worker runs
/// one on its own thread - runs no task once its closing flag is set:
/// webmessaging/message-channels/worker-post-after-close.)
fn deliverHook(receiver: *anyopaque, generation: u64, delivery: *port_channels.Delivery) void {
    const port = liveReceiver(receiver, generation) orelse return;
    var task = Delivery{ .port = port, .delivery = delivery };
    engine.runTaskInRealm(port.ctx, Delivery.steps, &task) catch {};
}

const Delivery = struct {
    port: *runtime.Instance,
    delivery: *port_channels.Delivery,

    fn steps(data: ?*anyopaque) void {
        const self: *Delivery = @ptrCast(@alignCast(data orelse return));
        // The event loop runs no task whose document is not fully active;
        // the message stays queued. Asked in the realm: the question reads
        // its global. A page the back/forward cache keeps is fully active
        // again when it is restored: the queue's task waits for that
        // (`EnableWhenActive`), as Firefox and Safari keep a cached page's
        // port messages, and Chrome re-posts them to the page's frozen task
        // queue (MessagePort::Accept, kBackForwardCachePostedMessage) - all
        // three deliver them once the page is shown. (Chrome evicts the page
        // instead for a message to a SharedWorker's port,
        // "sharedworker-message"; Firefox and Safari queue that too, the
        // majority.)
        if (!documentIsFullyActive(self.port)) {
            if (dom.document_activity.inactiveWindowOf(self.port) != null) EnableWhenActive.queue(self.port);
            return;
        }
        const message = self.delivery.next() orelse return;
        defer message.destroy();
        deliver(self.port, message);
    }
};

/// A port message queue that waits for its page to be fully active again:
/// a global task naming the port's Window enables the port's end once the
/// event loop runs it - at the page's restore - and port_channels.End.enable
/// notifies the port when messages wait. One at a time per port.
const EnableWhenActive = struct {
    port: *runtime.Instance,
    generation: u64,
    allocator: std.mem.Allocator,

    fn queue(port: *runtime.Instance) void {
        const internal = getInternal(port) orelse return;
        if (internal.enable_queued) return;
        const self = internal.allocator.create(EnableWhenActive) catch return;
        self.* = .{ .port = port, .generation = runtime.SlabAllocator.generationOf(port), .allocator = internal.allocator };
        if (!dom.document_activity.queuedUntilFullyActive(port, run, drop, self)) {
            internal.allocator.destroy(self);
            return;
        }
        internal.enable_queued = true;
    }

    fn run(data: ?*anyopaque) void {
        const self: *EnableWhenActive = @ptrCast(@alignCast(data.?));
        defer self.allocator.destroy(self);
        if (runtime.SlabAllocator.generationOf(self.port) != self.generation) return;
        const internal = getInternal(self.port) orelse return;
        internal.enable_queued = false;
        if (internal.end) |end| {
            if (end.state().enabled) end.enable();
        }
    }

    /// Never run: the page left the cache to be destroyed, or the loop
    /// ended.
    fn drop(data: ?*anyopaque) void {
        const self: *EnableWhenActive = @ptrCast(@alignCast(data.?));
        defer self.allocator.destroy(self);
        if (runtime.SlabAllocator.generationOf(self.port) != self.generation) return;
        const internal = getInternal(self.port) orelse return;
        internal.enable_queued = false;
    }
};

/// Step 7 of the message port post message steps, in the receiving port's
/// realm: deserialize, make the transferred objects, fire `message` - or,
/// at a cross-realm transform's port, run its native message steps.
fn deliver(port: *runtime.Instance, message: *PortMessage) void {
    const ctx = port.ctx;
    const allocator = ctx.allocator;
    const native = if (getInternal(port)) |internal| internal.native else null;

    // 7.3-7.4: StructuredDeserializeWithTransfer(serializeWithTransferResult,
    // targetRealm). The transferred objects first (their transfer-receiving
    // steps, step 3): made in targetRealm from their data holders - a port
    // on its shipped end, a stream on its [[port]] (dom.transferables). On
    // an exception - also when a transfer-receiving step failed (step 3.4.4
    // throws then: the value's references are by place in the transfer
    // list) - fire `messageerror` at messageEventTarget. The value refers to
    // the transferred objects it contained as the new ones (memory, step 3.5).
    const holders = message.takeHolders();
    defer message.allocator.free(holders);
    var received = dom.transferables.receiveAll(ctx, holders, allocator) catch {
        if (native) |receiver| return receiver.message_error(receiver.ctx);
        fire(port, "messageerror", runtime.JSValue.jsUndefined, &.{});
        return;
    };
    defer received.deinit();
    const clone = engine.structuredDeserializeWithOptions(ctx, message.serialized, .{ .array_buffers = message.array_buffers, .transferred = received.values, .shared_memory = message.shared_memory }) catch {
        if (native) |receiver| return receiver.message_error(receiver.ctx);
        fire(port, "messageerror", runtime.JSValue.jsUndefined, &.{});
        return;
    };
    defer clone.release();

    // A cross-realm transform's port: its message handler (Streams 8.2),
    // with the data of the message.
    if (native) |receiver| return receiver.message(receiver.ctx, clone.value);
    // 7.5-7.7: fire `message` at messageEventTarget, with data messageClone
    // and ports a frozen array of the transferred MessagePorts.
    fire(port, "message", clone.value, received.ports);
}

/// Fire a MessageEvent named `event_type` at `port`. `data` is borrowed: the
/// event keeps its own.
fn fire(port: *runtime.Instance, event_type: []const u8, data: runtime.JSValue, ports: []const *runtime.Instance) void {
    const init_dict = dictionaries.MessageEventInit{
        .base = .{},
        .data = data,
        .ports = ports,
    };
    const event = interfaces.MessageEvent.call_constructor(
        port.ctx,
        runtime.DOMString.initInterned(event_type),
        webidl.Opt(dictionaries.MessageEventInit).passed(init_dict),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    // Fired by the user agent: trusted (DOM 2.10).
    _ = dom.fire_event.dispatchTrusted(port, event) catch {};
    event.releaseIfUnwrapped(generation);
}

/// Its peer disentangled: the task of this port's realm that notes it.
fn closedHook(receiver: *anyopaque, generation: u64) void {
    const port = liveReceiver(receiver, generation) orelse return;
    engine.runTaskInRealm(port.ctx, peerDisentangledSteps, port) catch {};
}

/// The port is no longer entangled, so no longer active: its pending
/// activity ends. No event is fired: whatwg/html#13016 (2026-10) removed
/// MessagePort's `close` event and `onclose` - "no browser ships the close
/// events" - and Chrome, Firefox and Safari fire none
/// (webmessaging/message-channels/historical.any.js; the IDL member goes
/// through codegen's member_removals.zig). The port lifetime rules the
/// revert restored are not changed here: a port stays held exactly as
/// before, while its queue is enabled and it is entangled.
fn peerDisentangledSteps(data: ?*anyopaque) void {
    const port: *runtime.Instance = @ptrCast(@alignCast(data orelse return));
    syncPendingActivity(port);
}
