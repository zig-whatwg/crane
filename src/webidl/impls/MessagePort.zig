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
//! event fired at the port. Both halves go through the engine protocol.

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

    /// [[Detached]]: set by close(), and by the transfer steps.
    detached: bool = false,

    pub fn deinit(self: *InternalState) void {
        // The port goes, and its end with it: disentangled (its peer hears
        // `close`), its queue dropped.
        if (self.end) |end| end.discard();
        self.end = null;
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
    live_ports.append(std.heap.page_allocator, instance) catch {};
    // Its document's destruction disentangles it (`disentangleIn`).
    return instance;
}

/// Every MessagePort on this thread, from init to deinit: the ports "destroy
/// a document" reaches (`disentangleIn`).
threadlocal var live_ports: std.ArrayListUnmanaged(*runtime.Instance) = .empty;

fn forgetPort(instance: *runtime.Instance) void {
    for (live_ports.items, 0..) |port, i| {
        if (port != instance) continue;
        _ = live_ports.swapRemove(i);
        return;
    }
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
    // Backwards: disentangling posts the peer's close event and frees
    // nothing here, but stay safe if it did.
    var i = live_ports.items.len;
    while (i > 0) {
        i -= 1;
        if (i >= live_ports.items.len) continue;
        const port = live_ports.items[i];
        if (port.ctx != realm) continue;
        disentangle(port);
        const internal = getInternal(port) orelse continue;
        if (internal.end) |end| end.unbind();
    }
}

/// HTML "disentangle" (9.4.4), initiated by `instance`: the two ports are
/// disentangled and the other one hears `close`, from a task of its own realm
/// - which may be another agent's, on another thread.
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
// Event handlers (HTML § 9.4.3: onmessage, onmessageerror, onclose). Their
// values live in EventTarget's event handler map, where a `message` event
// fired at this port finds them.
// ============================================================================

pub fn get_onclose(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return dom.event_handlers.get(typedefs.EventHandler, instance, "close");
}

pub fn get_onmessage(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return dom.event_handlers.get(typedefs.EventHandler, instance, "message");
}

pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return dom.event_handlers.get(typedefs.EventHandler, instance, "messageerror");
}

pub fn set_onclose(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try dom.event_handlers.set(typedefs.EventHandler, instance, "close", value);
}

/// "The first time a MessagePort object's onmessage IDL attribute is set, the
/// port's port message queue must be enabled, as if the start() method had
/// been called."
pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try dom.event_handlers.set(typedefs.EventHandler, instance, "message", value);
    enableQueue(instance);
}

pub fn set_onmessageerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try dom.event_handlers.set(typedefs.EventHandler, instance, "messageerror", value);
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
        engine.keepPlatformObjectAlive(instance);
    } else releasePendingActivity(instance);
}

/// End the pending-activity hold on a port (idempotent).
fn releasePendingActivity(instance: *runtime.Instance) void {
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
/// DataCloneError").
fn transferableFrom(source: ?*anyopaque, instance: *runtime.Instance) runtime.TransferableState {
    if (source) |s| {
        if (@as(*runtime.Instance, @ptrCast(@alignCast(s))) == instance) return .not_transferable;
    }
    return transferableState(instance);
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
    // (`transferableFrom`), and ships every port in transfer.
    var result = try engine.structuredSerializeWithTransfer(source.ctx, message, transfer, transferableFrom, source, allocator);
    defer result.deinit(allocator);
    var ends: std.ArrayListUnmanaged(*End) = .empty;
    // Ends no message took go with the list.
    defer {
        for (ends.items) |shipped| shipped.discard();
        ends.deinit(allocator);
    }
    // Step 3-4: doomed when targetPort is in transfer: its end is shipped
    // with the message posted to it, and the channel is lost.
    var doomed = false;
    for (result.platform_objects) |port| {
        const port_internal = getInternal(port) orelse continue;
        const shipped = port_internal.transfer() orelse continue;
        syncPendingActivity(port);
        if (end) |e| {
            if (e.isEntangledWith(shipped)) doomed = true;
        }
        ends.append(allocator, shipped) catch |err| {
            shipped.discard();
            return err;
        };
    }

    // 6. If targetPort is null, or if doomed is true, then return.
    if (!has_target or doomed) return;

    // 7. Add a task to targetPort's port message queue: the message waits on
    // the entangled end, in order, until that end's port enables its queue.
    const owned_ends = try ends.toOwnedSlice(allocator);
    const port_message = PortMessage.create(allocator, &result, owned_ends) catch |err| {
        for (owned_ends) |shipped| shipped.discard();
        allocator.free(owned_ends);
        return err;
    };
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
/// step 7, as a task of the receiving port's realm.
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
        // its global.
        if (!documentIsFullyActive(self.port)) return;
        const message = self.delivery.next() orelse return;
        defer message.destroy();
        deliver(self.port, message);
    }
};

/// Step 7 of the message port post message steps, in the receiving port's
/// realm: deserialize, make the transferred ports, fire `message`.
fn deliver(port: *runtime.Instance, message: *PortMessage) void {
    const ctx = port.ctx;
    const allocator = ctx.allocator;

    // 7.3-7.4: StructuredDeserializeWithTransfer(serializeWithTransferResult,
    // targetRealm). The transferred ports first (their transfer-receiving
    // steps): new MessagePorts of targetRealm on the shipped ends.
    var ports: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer ports.deinit(allocator);
    const ends = message.takeEnds();
    defer message.allocator.free(ends);
    for (ends) |end| {
        const received = receive(ctx, @ptrCast(end)) catch continue;
        ports.append(allocator, received) catch continue;
    }

    // On an exception, fire `messageerror` at messageEventTarget.
    const clone = engine.structuredDeserializeWithTransfer(ctx, message.serialized, message.array_buffers) catch {
        fire(port, "messageerror", runtime.JSValue.jsUndefined, &.{});
        return;
    };
    defer clone.release();

    // 7.5-7.7: fire `message` at messageEventTarget, with data messageClone
    // and ports a frozen array of the transferred ports.
    fire(port, "message", clone.value, ports.items);
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

/// Disentangle step 4, for this port: its peer disentangled, and this is
/// the task of its realm that fires `close` at it.
fn closedHook(receiver: *anyopaque, generation: u64) void {
    const port = liveReceiver(receiver, generation) orelse return;
    engine.runTaskInRealm(port.ctx, fireCloseSteps, port) catch {};
}

fn fireCloseSteps(data: ?*anyopaque) void {
    const port: *runtime.Instance = @ptrCast(@alignCast(data orelse return));
    // Its peer closed: it is no longer entangled, so no longer active - but
    // the `close` event is dispatched first, while it is still held.
    defer syncPendingActivity(port);
    if (!documentIsFullyActive(port)) return;
    const event = interfaces.Event.call_constructor(
        port.ctx,
        runtime.DOMString.initInterned("close"),
        webidl.Opt(dictionaries.EventInit).notPassed(),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = dom.fire_event.dispatchTrusted(port, event) catch {};
    event.releaseIfUnwrapped(generation);
}
