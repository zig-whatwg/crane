//! Implementation for MessagePort interface
//!
//! Spec: HTML Standard § 9.4.3 Message ports
//! https://html.spec.whatwg.org/multipage/web-messaging.html#message-ports
//!
//! A MessagePort is one end of a channel. The channel's ends are the streams
//! layer's internal ports (`streams_internal.MessagePort`): each holds the
//! port message queue for its end - serialized messages, in order - and its
//! entanglement. A MessagePort object wraps one end; transferring the port
//! ships that end, queue and entanglement included, to a new MessagePort in
//! the receiving realm (the transfer and transfer-receiving steps), so the
//! channel keeps working across realms and agents.
//!
//! Every message goes the spec's way, whether the other end is in this realm,
//! another window's or a worker's: StructuredSerializeWithTransfer at the
//! sender, a task on the receiving end's port message queue, and there
//! StructuredDeserializeWithTransfer into the receiver's realm and a `message`
//! event fired at the port. Both halves go through the Engine table.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const MessagePort = interfaces.MessagePort;

// A MessagePort is an EventTarget, and reaches its state through its impl.
const EventTargetImpl = @import("EventTarget.zig");

// The channel ends.
const message_port = @import("streams_internal");
const InternalMessagePort = message_port.MessagePort;

/// The hook other types transfer ports through (no IDL member runs the
/// transfer steps).
const message_ports = @import("dom").message_ports;

pub const State = MessagePort.State;

pub const ImplError = error{
    NotImplemented,
    PortClosed,
    NotEntangled,
    OutOfMemory,
};

/// Internal state for MessagePort implementation
pub const InternalState = struct {
    /// This port's end of its channel: its port message queue and its
    /// entanglement.
    internal_port: *InternalMessagePort,

    /// Allocator used for this state
    allocator: std.mem.Allocator,

    /// Whether this object owns `internal_port`. A transfer hands the end to
    /// the port the receiving realm makes of it.
    owns_port: bool = true,

    /// HTML: "has been shipped".
    has_been_shipped: bool = false,

    /// [[Detached]]: set by close(), and by the transfer steps.
    detached: bool = false,

    /// What `internal_port` calls when a message is queued on it, while this
    /// object is the end's owner. Freed with this state.
    receiver: ?*Receiver = null,

    /// The tasks queued for this port and not yet run - a message's
    /// delivery, its peer's `close` - which "destroy a document" removes
    /// unrun (`dropTasks`). A task takes itself off when it runs. The list
    /// (not the tasks: a queued one frees itself when it runs, finding its
    /// port gone) is allocated with `allocator`.
    armed: std.ArrayListUnmanaged(*PortTask) = .empty,

    pub fn deinit(self: *InternalState) void {
        self.armed.deinit(self.allocator);
        self.disconnect();
        // Only deinit the port if we own it: a transferred port's end belongs
        // to the port the receiving realm made of it.
        if (self.owns_port) self.internal_port.deinit();
    }

    /// Stop hearing about messages queued on the end.
    fn disconnect(self: *InternalState) void {
        const receiver = self.receiver orelse return;
        if (self.internal_port.callback_user_data == @as(?*anyopaque, @ptrCast(receiver))) {
            self.internal_port.callback_user_data = null;
            self.internal_port.on_serialized_message = null;
        }
        self.allocator.destroy(receiver);
        self.receiver = null;
    }

    /// A task of this port's ran: it is no longer queued.
    fn forgetTask(self: *InternalState, task: *PortTask) void {
        for (self.armed.items, 0..) |armed, i| {
            if (armed != task) continue;
            _ = self.armed.swapRemove(i);
            return;
        }
    }

    /// HTML "destroy a document" step 6.2: "Remove any tasks whose document is
    /// document from any task queue (without running those tasks)" - this
    /// port's. Each is freed once its timer has let it go; one its timer no
    /// longer knows may still run, and then finds itself off the list and its
    /// port's document gone, and frees itself.
    fn dropTasks(self: *InternalState) void {
        for (self.armed.items) |task| {
            if (task.timer.clearTimeout(task.id)) task.allocator.destroy(task);
        }
        self.armed.clearRetainingCapacity();
    }

    /// HTML's MessagePort transfer steps (value = this port): set its "has
    /// been shipped" flag, and hand over its end - which carries the port
    /// message queue ([[PortMessageQueue]]) and the entanglement
    /// ([[RemotePort]]) - as the data holder. The port is detached; it no
    /// longer hears its end's messages, and the end is no longer its to free.
    pub fn transfer(self: *InternalState) *InternalMessagePort {
        self.has_been_shipped = true;
        self.detached = true;
        self.disconnect();
        self.owns_port = false;
        return self.internal_port;
    }
};

/// The link from an end back to the MessagePort that owns it, held as
/// (address, slab generation): a collected port's slot can be reissued.
const Receiver = struct {
    instance: *runtime.Instance,
    generation: u64,

    fn get(self: Receiver) ?*runtime.Instance {
        if (runtime.SlabAllocator.generationOf(self.instance) != self.generation) return null;
        return self.instance;
    }
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const internal_port = try InternalMessagePort.init(allocator);
    errdefer internal_port.deinit();
    return initWithInternal(allocator, StateType, vtable, ctx, internal_port);
}

/// A MessagePort for an existing end: MessageChannel's two, and a transferred
/// port's in the receiving realm - HTML's transfer-receiving steps, which
/// give the new port the end's queue and entanglement. The new port owns the
/// end and hears its messages from now on.
pub fn initWithInternal(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    internal_port: *InternalMessagePort,
) !*runtime.Instance {
    // A MessagePort is an EventTarget: `message` is fired at it and heard.
    const instance = try EventTargetImpl.init(allocator, StateType, vtable, ctx);
    errdefer EventTargetImpl.deinit(instance);

    // Nobody can hold a port to transfer before one exists.
    message_ports.install(.{ .transferable_state = transferableState, .ship = ship, .receive = receive, .discard = discard });

    const internal_state = try allocator.create(InternalState);
    errdefer allocator.destroy(internal_state);
    internal_state.* = .{
        .internal_port = internal_port,
        .allocator = allocator,
    };
    instance.getState(StateType).own._internal = internal_state;

    try connect(instance, internal_state);
    // A queue that was enabled before the end was shipped (the sender's
    // start()) is not the receiver's: HTML's transfer-receiving steps leave
    // it disabled until this port's start() or onmessage.
    internal_port.queue_enabled = false;
    live_ports.append(std.heap.page_allocator, instance) catch {};
    // Its document's destruction disentangles it (`disentangleIn`).
    @import("dom").unloading_cleanup.install(&disentangleIn);
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
/// `realm`, whose document is destroyed. A disentangled port has no pending
/// activity left, so the hold that kept it - and through it its realm -
/// while its channel lived goes (Blink: MessagePort::ContextDestroyed
/// closes the port). Installed into the unloading document cleanup steps
/// (dom.unloading_cleanup), which "destroy a document" runs right after
/// these (step 6); a document Crane unloads is always destroyed - it keeps
/// no back/forward cache - so they run at the same moment either way, and a
/// worker's ports go when it ends.
pub fn disentangleIn(realm: runtime.Context) void {
    // Backwards: disentangling queues the peer's close event, frees nothing
    // here, but stay safe if it did.
    var i = live_ports.items.len;
    while (i > 0) {
        i -= 1;
        if (i >= live_ports.items.len) continue;
        const port = live_ports.items[i];
        if (port.ctx != realm) continue;
        disentangle(port);
    }
    // "Destroy a document" step 6.2 removes the document's tasks from their
    // queues unrun: the ports' tasks queued on this realm's event loop - with
    // the close events the loop above queued for peers in this realm. Never
    // left to the loop's own end: Browser.deinit ends the workers first, so a
    // worker's ports queue `close` for their peers on the page's loop, which
    // does not run again, and the loop's end dropped each task unfreed (leaks
    // lane, 2026-10-02: 6 per sharedworker-import file run alone).
    for (live_ports.items) |port| {
        if (port.ctx != realm) continue;
        const internal = getInternal(port) orelse continue;
        internal.dropTasks();
    }
}

/// HTML "disentangle" (9.4.4), initiated by `instance`: the two ports are
/// disentangled and the other one hears `close`.
fn disentangle(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    // A shipped port is not entangled: its end is another port's now.
    if (!internal.owns_port) return;
    // 1. otherPort, if this is entangled.
    const other = internal.internal_port.entangled_port;
    // 3. Disentangle the two ports (and close this end).
    internal.internal_port.close();
    syncPendingActivity(instance);
    // 4. Fire an event named close at otherPort - from a task of its own
    // realm, which may be another agent's.
    if (other) |end| scheduleClose(end);
}

/// Make `instance` the owner that hears messages queued on its end.
fn connect(instance: *runtime.Instance, internal: *InternalState) !void {
    const receiver = try internal.allocator.create(Receiver);
    receiver.* = .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    internal.receiver = receiver;
    internal.internal_port.callback_user_data = receiver;
    internal.internal_port.on_serialized_message = messageQueued;
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
    EventTargetImpl.deinit(instance);
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Get internal MessagePort (for streams integration)
pub fn getInternalPort(instance: *runtime.Instance) ?*InternalMessagePort {
    const internal = getInternal(instance) orelse return null;
    return internal.internal_port;
}

// ============================================================================
// Event handlers (HTML § 9.4.3: onmessage, onmessageerror, onclose). Their
// values live in EventTarget's event handler map, where a `message` event
// fired at this port finds them.
// ============================================================================

pub fn get_onclose(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "close");
}

pub fn get_onmessage(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "message");
}

pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "messageerror");
}

pub fn set_onclose(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "close", value);
}

/// "The first time a MessagePort object's onmessage IDL attribute is set, the
/// port's port message queue must be enabled, as if the start() method had
/// been called."
pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "message", value);
    enableQueue(instance);
}

pub fn set_onmessageerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "messageerror", value);
}

/// Operation: start
/// "The start() method steps are to enable this's port message queue, if it
/// is not already enabled."
pub fn call_start(instance: *runtime.Instance) anyerror!void {
    enableQueue(instance);
}

/// Enable the port message queue: its tasks may run now, so the first is
/// scheduled.
fn enableQueue(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    // A shipped port's end is another port's now.
    if (!internal.owns_port) return;
    if (internal.internal_port.queue_enabled) return;
    internal.internal_port.enableQueue();
    syncPendingActivity(instance);
    scheduleDelivery(instance);
}

/// Blink's MessagePort::HasPendingActivity(): a port whose message queue is
/// enabled and which is entangled must outlive whatever script holds of it.
/// HTML (9.4.6, ports and garbage collection): entangled ports act as if each
/// holds the other strongly - "a message port can be received, given an
/// event listener, and then forgotten, and so long as that event listener
/// could receive a message, the channel will be maintained". A port nobody
/// references that has been started - `channel.port2.onmessage = f` and no
/// other reference - was collected before its message arrived. Kept through
/// the Engine table's pending-activity hold, taken and released here as the
/// port's state changes: started, closed, shipped, or its peer closed.
fn syncPendingActivity(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    const port = internal.internal_port;
    const active = internal.owns_port and !internal.detached and port.queue_enabled and port.entangled_port != null;
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
    const end = internal.transfer();
    // Detached: no pending activity is left on this object.
    syncPendingActivity(instance);
    return @ptrCast(end);
}

/// Free an end no port took: disentangled from its other end (whose port
/// then has nothing to post to), its queue freed.
fn discard(end: *anyopaque) void {
    const port: *InternalMessagePort = @ptrCast(@alignCast(end));
    port.deinit();
}

/// The transfer-receiving steps: a new MessagePort of `realm` on `end`.
fn receive(realm: runtime.Context, end: *anyopaque) anyerror!*runtime.Instance {
    const port = try initWithInternal(realm.allocator, State, &MessagePort.vtable, realm, @ptrCast(@alignCast(end)));
    getInternal(port).?.has_been_shipped = true;
    return port;
}

/// The message port post message steps, given this, the entangled port (if
/// any), message and options["transfer"].
fn postMessageSteps(source: *runtime.Instance, message: runtime.JSValue, transfer: []const runtime.JSValue) anyerror!void {
    const internal = getInternal(source) orelse return;
    const allocator = source.ctx.allocator;

    // 1. targetPort: the end this one is entangled with, if any. A detached
    // port (closed, or shipped - its end is another port's) has none.
    const target = if (internal.detached or !internal.owns_port) null else internal.internal_port.entangled_port;

    // Steps 2 and 5: StructuredSerializeWithTransfer(message, transfer) -
    // which throws a DataCloneError when transfer contains sourcePort
    // (`transferableFrom`), and ships every port in transfer.
    var result = try engine.structuredSerializeWithTransfer(source.ctx, message, transfer, transferableFrom, source, allocator);
    defer result.deinit(allocator);
    var ends: std.ArrayListUnmanaged(*InternalMessagePort) = .empty;
    defer ends.deinit(allocator);
    // Step 3-4: doomed when targetPort is in transfer: its end is shipped
    // with the message posted to it, and the channel is lost.
    var doomed = false;
    for (result.platform_objects) |port| {
        const port_internal = getInternal(port) orelse continue;
        const end = port_internal.transfer();
        if (target != null and end == target.?) doomed = true;
        try ends.append(allocator, end);
    }

    // 6. If targetPort is null, or if doomed is true, then return.
    if (target == null or doomed) return;

    // 7. Add a task to targetPort's port message queue: the message waits on
    // the entangled end, in order, until that end's port enables its queue.
    const record = try frame(allocator, &result, ends.items);
    defer allocator.free(record);
    internal.internal_port.postSerializedMessage(record) catch |err| switch (err) {
        error.PortClosed, error.NotEntangled => return,
        else => return err,
    };
}

// ============================================================================
// The port message queue's task
// ============================================================================

/// A task queued for a port: the owner, held as (address, generation), and
/// where it is queued - the port's realm's timer and the id there - for
/// "destroy a document" to remove it unrun (`InternalState.dropTasks`).
const PortTask = struct {
    instance: *runtime.Instance,
    generation: u64,
    allocator: std.mem.Allocator,
    timer: runtime.TimerInterface,
    id: runtime.TimerId = 0,

    fn target(self: *const PortTask) ?*runtime.Instance {
        if (runtime.SlabAllocator.generationOf(self.instance) != self.generation) return null;
        return self.instance;
    }
};

/// `on_serialized_message`: a message was added to this end's queue.
fn messageQueued(end: *InternalMessagePort) void {
    const receiver: *Receiver = @ptrCast(@alignCast(end.callback_user_data orelse return));
    const instance = receiver.get() orelse return;
    scheduleDelivery(instance);
}

/// Arm one task on the owner's event loop to deliver the next message, while
/// the queue is enabled and holds one.
fn scheduleDelivery(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    if (!internal.owns_port) return;
    if (!internal.internal_port.queue_enabled or !internal.internal_port.hasSerializedMessages()) return;
    armTask(instance, deliverNext);
}

fn armTask(instance: *runtime.Instance, comptime run: fn (?*anyopaque) void) void {
    const internal = getInternal(instance) orelse return;
    const timer = instance.ctx.getOptionalTimer() orelse return;
    const task = instance.ctx.allocator.create(PortTask) catch return;
    task.* = .{
        .instance = instance,
        .generation = runtime.SlabAllocator.generationOf(instance),
        .allocator = instance.ctx.allocator,
        .timer = timer,
    };
    // Recorded with its port before it is queued: nothing can fail between
    // queuing it and the record.
    internal.armed.append(internal.allocator, task) catch {
        task.allocator.destroy(task);
        return;
    };
    task.id = timer.setTimeout(0, run, task);
    if (task.id == 0) {
        internal.forgetTask(task);
        task.allocator.destroy(task);
    }
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
fn deliverNext(data: ?*anyopaque) void {
    const task: *PortTask = @ptrCast(@alignCast(data orelse return));
    defer task.allocator.destroy(task);
    const instance = task.target() orelse return;
    const internal = getInternal(instance) orelse return;
    internal.forgetTask(task);
    if (!internal.owns_port or !internal.internal_port.queue_enabled) return;
    if (!internal.internal_port.hasSerializedMessages()) return;

    var delivery = Delivery{ .port = instance };
    engine.runTaskInRealm(instance.ctx, Delivery.steps, &delivery) catch {};

    // One message per task: the next gets its own - once this one ran.
    if (delivery.ran and task.target() != null) scheduleDelivery(instance);
}

const Delivery = struct {
    port: *runtime.Instance,
    ran: bool = false,

    fn steps(data: ?*anyopaque) void {
        const self: *Delivery = @ptrCast(@alignCast(data orelse return));
        // The event loop runs no task whose document is not fully active;
        // the message stays queued. Asked in the realm: the question reads
        // its global.
        if (!documentIsFullyActive(self.port)) return;
        const internal = getInternal(self.port) orelse return;
        const message = internal.internal_port.popSerializedMessage() orelse return;
        defer message.deinit();
        self.ran = true;
        deliver(self.port, message.data);
    }
};

/// Step 7 of the message port post message steps, in the receiving port's
/// realm: deserialize, make the transferred ports, fire `message`.
fn deliver(port: *runtime.Instance, record_bytes: []const u8) void {
    const ctx = port.ctx;
    const allocator = ctx.allocator;
    const record = unframe(allocator, record_bytes) catch {
        fire(port, "messageerror", runtime.JSValue.jsUndefined, &.{});
        return;
    };
    defer record.deinit(allocator);

    // 7.3-7.4: StructuredDeserializeWithTransfer(serializeWithTransferResult,
    // targetRealm). The transferred ports first (their transfer-receiving
    // steps): new MessagePorts of targetRealm on the shipped ends.
    var ports: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer ports.deinit(allocator);
    for (record.ends) |end| {
        const received = receive(ctx, @ptrCast(end)) catch continue;
        ports.append(allocator, received) catch continue;
    }

    // On an exception, fire `messageerror` at messageEventTarget.
    const clone = engine.structuredDeserializeWithTransfer(ctx, record.serialized, record.array_buffers) catch {
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
    _ = EventTargetImpl.dispatchTrusted(port, event) catch {};
    event.releaseIfUnwrapped(generation);
}

/// Disentangle step 4, for the other end's port, from a task of its realm.
fn scheduleClose(end: *InternalMessagePort) void {
    const receiver: *Receiver = @ptrCast(@alignCast(end.callback_user_data orelse return));
    const instance = receiver.get() orelse return;
    armTask(instance, fireClose);
}

fn fireClose(data: ?*anyopaque) void {
    const task: *PortTask = @ptrCast(@alignCast(data orelse return));
    defer task.allocator.destroy(task);
    const instance = task.target() orelse return;
    if (getInternal(instance)) |internal| internal.forgetTask(task);
    engine.runTaskInRealm(instance.ctx, fireCloseSteps, instance) catch {};
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
    _ = EventTargetImpl.dispatchTrusted(port, event) catch {};
    event.releaseIfUnwrapped(generation);
}

// ============================================================================
// The queued record
// ============================================================================

/// A queued message as its end holds it: the serialization, the transferred
/// ArrayBuffers' contents, and the shipped ends of the transferred ports.
/// Laid out in one buffer, since an end queues bytes:
///   u32 serialized length, the bytes; u32 buffer count, each a u64 length
///   and its bytes; u32 port count, each the end's address as a u64.
/// Within one process only - the ends are addresses.
const Record = struct {
    serialized: []const u8,
    array_buffers: []const []const u8,
    ends: []const *InternalMessagePort,

    fn deinit(self: Record, allocator: std.mem.Allocator) void {
        allocator.free(self.array_buffers);
        allocator.free(self.ends);
    }
};

fn frame(allocator: std.mem.Allocator, result: *const runtime.SerializedWithTransfer, ends: []const *InternalMessagePort) ![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    try appendInt(allocator, &out, u32, @intCast(result.serialized.len));
    try out.appendSlice(allocator, result.serialized);
    try appendInt(allocator, &out, u32, @intCast(result.array_buffers.len));
    for (result.array_buffers) |contents| {
        try appendInt(allocator, &out, u64, contents.len);
        try out.appendSlice(allocator, contents);
    }
    try appendInt(allocator, &out, u32, @intCast(ends.len));
    for (ends) |end| try appendInt(allocator, &out, u64, @intFromPtr(end));
    return out.toOwnedSlice(allocator);
}

fn appendInt(allocator: std.mem.Allocator, out: *std.ArrayListUnmanaged(u8), comptime T: type, value: T) !void {
    var bytes: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}

/// The record `bytes` holds. Its slices point into `bytes`; the two lists are
/// allocated (`Record.deinit`).
fn unframe(allocator: std.mem.Allocator, bytes: []const u8) !Record {
    var reader = Reader{ .bytes = bytes };
    const serialized = try reader.slice(try reader.int(u32));
    const buffer_count = try reader.int(u32);
    const buffers = try allocator.alloc([]const u8, buffer_count);
    errdefer allocator.free(buffers);
    for (buffers) |*buffer| buffer.* = try reader.slice(@intCast(try reader.int(u64)));
    const end_count = try reader.int(u32);
    const ends = try allocator.alloc(*InternalMessagePort, end_count);
    errdefer allocator.free(ends);
    for (ends) |*end| end.* = @ptrFromInt(@as(usize, @intCast(try reader.int(u64))));
    return .{ .serialized = serialized, .array_buffers = buffers, .ends = ends };
}

const Reader = struct {
    bytes: []const u8,
    at: usize = 0,

    fn int(self: *Reader, comptime T: type) !T {
        const data = try self.slice(@sizeOf(T));
        return std.mem.readInt(T, data[0..@sizeOf(T)], .little);
    }

    fn slice(self: *Reader, len: usize) ![]const u8 {
        if (self.bytes.len - self.at < len) return error.Truncated;
        defer self.at += len;
        return self.bytes[self.at..][0..len];
    }
};

test "a queued record round-trips" {
    const allocator = std.testing.allocator;
    var buffers = [_][]u8{ @constCast("abc"), @constCast("") };
    const result = runtime.SerializedWithTransfer{
        .serialized = @constCast("serialized"),
        .array_buffers = &buffers,
        .platform_objects = &.{},
    };
    const fake: *InternalMessagePort = @ptrFromInt(0x1000);
    const bytes = try frame(allocator, &result, &.{fake});
    defer allocator.free(bytes);
    const record = try unframe(allocator, bytes);
    defer record.deinit(allocator);
    try std.testing.expectEqualStrings("serialized", record.serialized);
    try std.testing.expectEqual(@as(usize, 2), record.array_buffers.len);
    try std.testing.expectEqualStrings("abc", record.array_buffers[0]);
    try std.testing.expectEqual(@as(usize, 0), record.array_buffers[1].len);
    try std.testing.expectEqual(fake, record.ends[0]);
    try std.testing.expectError(error.Truncated, unframe(allocator, bytes[0 .. bytes.len - 1]));
}
