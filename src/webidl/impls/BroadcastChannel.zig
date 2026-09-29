//! Implementation for BroadcastChannel interface
//!
//! HTML §9.5 - Broadcasting to other browsing contexts
//! Spec: https://html.spec.whatwg.org/multipage/web-messaging.html#broadcasting-to-other-browsing-contexts
//!
//! A named channel: a message posted to one BroadcastChannel is delivered to
//! every other one of the same name whose relevant settings object has the
//! same storage key - in any window, frame or worker - as a `message` event
//! in a task of the receiver's global.
//!
//! Every global a page makes - its windows, its frames' and its workers' -
//! runs on the page's thread, so the channels live in one per-thread list,
//! in creation order: what postMessage's destinations are drawn from, and
//! the order they are sorted in (step 8).
//!
//! Stated, not modelled:
//! - "Obtain a storage key for non-storage purposes" is the settings
//!   object's origin, serialized. An opaque origin serializes to "null" and
//!   equals only itself; with no identity for one reachable here, a channel
//!   in an opaque origin reaches only channels of its own global - so an
//!   opaque-origin document and the workers it made do not share one.
//! - The strong reference from the global while a channel that is not closed
//!   has `message` or `messageerror` listeners: a channel is held from its
//!   construction until close() or its realm's end, listeners or not (Blink
//!   reads listeners at GC time, in HasPendingActivity; nothing here tells a
//!   channel when one is added).

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
const EventTargetImpl = @import("EventTarget.zig");
const BroadcastChannel = interfaces.BroadcastChannel;

pub const State = BroadcastChannel.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
};

/// "A BroadcastChannel object has a channel name and a closed flag."
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The channel name. Owned.
    name: []u8 = &.{},
    closed: bool = false,
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// A live channel: its address, and the generation of its block, which tells
/// a freed channel from one reusing the block.
const Entry = struct {
    instance: *runtime.Instance,
    generation: u64,

    fn live(self: Entry) ?*runtime.Instance {
        if (runtime.SlabAllocator.generationOf(self.instance) != self.generation) return null;
        return self.instance;
    }
};

/// Every BroadcastChannel on this thread that is not closed, in creation
/// order.
threadlocal var channels: std.ArrayListUnmanaged(Entry) = .empty;

fn register(instance: *runtime.Instance) !void {
    try channels.append(std.heap.page_allocator, .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) });
}

fn unregister(instance: *runtime.Instance) void {
    for (channels.items, 0..) |entry, i| {
        if (entry.instance == instance) {
            _ = channels.orderedRemove(i);
            return;
        }
    }
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // A BroadcastChannel is an EventTarget: `message` is fired at it.
    const instance = try EventTargetImpl.init(allocator, StateType, vtable, ctx);
    errdefer EventTargetImpl.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    unregister(instance);
    engine.releasePlatformObject(instance);
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.allocator.free(internal.name);
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    EventTargetImpl.deinit(instance);
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor: "1. Set this's channel name to name. 2. Set this's closed
/// flag to false."
pub fn call_constructor(ctx: runtime.Context, name: runtime.DOMString) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &BroadcastChannel.vtable, ctx);
    errdefer deinit(instance);
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.name = try internal.allocator.dupe(u8, name.asSlice());
    try register(instance);
    // Held while it can hear a message (the file comment says how far).
    engine.keepPlatformObjectAlive(instance);
    return instance;
}

/// "The name getter steps are to return this's channel name."
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return runtime.DOMString.initDupe(instance.ctx.allocator, internal.name);
}

// Event handlers: onmessage and onmessageerror, in EventTarget's event
// handler map.

pub fn get_onmessage(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "message");
}

pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "messageerror");
}

pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "message", value);
}

pub fn set_onmessageerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "messageerror", value);
}

/// "The close() method steps are to set this's closed flag to true." A
/// closed channel is never a destination again, and nothing holds it.
pub fn call_close(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return;
    internal.closed = true;
    unregister(instance);
    engine.releasePlatformObject(instance);
}

/// The postMessage(message) method steps.
pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // "1. If this is not eligible for messaging, then return."
    if (!eligibleForMessaging(instance)) return;
    // "2. If this's closed flag is true, then throw an "InvalidStateError"
    // DOMException."
    if (internal.closed) return error.InvalidStateError;
    // "3. Let serialized be StructuredSerialize(message). Rethrow any
    // exceptions."
    const allocator = instance.ctx.allocator;
    var serialized = try engine.structuredSerializeWithTransfer(instance.ctx, message, &.{}, &nothingTransferable, null, allocator);
    defer serialized.deinit(allocator);
    // "4. Let sourceOrigin be this's relevant settings object's origin."
    // "5. Let sourceStorageKey be the result of running obtain a storage key
    // for non-storage purposes with this's relevant settings object."
    const source_global = relevantGlobal(instance) orelse return;
    const source_origin = originOf(source_global) orelse return;
    defer source_global.ctx.allocator.free(source_origin);
    // "6. Let destinations be a list of BroadcastChannel objects that match
    // the following criteria: They are eligible for messaging. [Their storage
    // key] equals sourceStorageKey. Their channel name is this's channel
    // name. 7. Remove source from destinations. 8. Sort destinations [by
    // creation order]." The list is in creation order; queueing the tasks
    // runs no script, so it does not change while it is walked.
    for (channels.items) |entry| {
        const destination = entry.live() orelse continue;
        if (destination == instance) continue;
        const other = getInternal(destination) orelse continue;
        if (other.closed or !std.mem.eql(u8, other.name, internal.name)) continue;
        if (!eligibleForMessaging(destination)) continue;
        if (!sameStorageKey(source_global, source_origin, destination)) continue;
        // "9. For each destination in destinations, queue a global task on
        // the DOM manipulation task source given destination's relevant
        // global object."
        queueDelivery(destination, serialized.serialized, source_origin);
    }
}

/// Nothing is transferred: the transfer list is empty, so this is never
/// asked.
fn nothingTransferable(data: ?*anyopaque, instance: *runtime.Instance) runtime.TransferableState {
    _ = data;
    _ = instance;
    return .not_transferable;
}

/// The relevant global object of `instance`, from its relevant realm.
fn relevantGlobal(instance: *runtime.Instance) ?*runtime.Instance {
    const record = instance.ctx.getRealm() orelse return null;
    return @ptrCast(@alignCast(record.global_object orelse return null));
}

/// `global`'s settings object's origin, serialized; null when no kind of
/// global answers for it. Owned, `global.ctx.allocator`.
fn originOf(global: *runtime.Instance) ?[]const u8 {
    const settings = dom.global_settings.of(global) orelse return null;
    return settings.origin(global) catch null;
}

/// Whether `destination`'s storage key equals the source's (`source_global`,
/// whose origin serializes to `source_origin`). An opaque origin ("null")
/// equals only itself: approximated as the same global (see the file
/// comment).
fn sameStorageKey(source_global: *runtime.Instance, source_origin: []const u8, destination: *runtime.Instance) bool {
    const global = relevantGlobal(destination) orelse return false;
    if (std.mem.eql(u8, source_origin, "null")) return global == source_global;
    const origin = originOf(global) orelse return false;
    defer global.ctx.allocator.free(origin);
    return std.mem.eql(u8, origin, source_origin);
}

/// "A BroadcastChannel object is said to be eligible for messaging when its
/// relevant global object is either: a Window object whose associated
/// Document is fully active, or a WorkerGlobalScope object whose closing
/// flag is false and is not suspendable." No worker here is suspendable.
fn eligibleForMessaging(instance: *runtime.Instance) bool {
    const global = relevantGlobal(instance) orelse return false;
    if (global.stateAs(interfaces.Window.State) != null) {
        // Fully active: still its Window's document, and still with a
        // browsing context ("destroy" sets it to null). Not `closed`: a
        // window that is closing is still fully active until it is
        // destroyed, and its beforeunload and unload handlers still post.
        const document = interfaces.Window.get_document(global) catch return false;
        const view = (interfaces.Document.get_defaultView(document) catch null) orelse return false;
        return view == global;
    }
    return !workerClosing(global);
}

/// A WorkerGlobalScope's closing flag, which the worker host keeps (close()
/// and "terminate a worker" set its phase). A global no worker host runs
/// has no flag to read, and counts as not closing.
fn workerClosing(global: *runtime.Instance) bool {
    return @import("html").worker_host.scopeClosing(global.ctx) orelse false;
}

/// One destination's task: step 9's steps, in its realm.
const Delivery = struct {
    channel: *runtime.Instance,
    generation: u64,
    allocator: std.mem.Allocator,
    /// StructuredSerialize(message)'s bytes. Owned.
    serialized: []u8,
    /// sourceOrigin, serialized. Owned.
    origin: []u8,

    fn target(self: *const Delivery) ?*runtime.Instance {
        if (runtime.SlabAllocator.generationOf(self.channel) != self.generation) return null;
        return self.channel;
    }

    fn destroy(self: *Delivery) void {
        self.allocator.free(self.serialized);
        self.allocator.free(self.origin);
        self.allocator.destroy(self);
    }

    /// The task, from the destination global's event loop.
    fn run(data: ?*anyopaque) void {
        const self: *Delivery = @ptrCast(@alignCast(data orelse return));
        defer self.destroy();
        const channel = self.target() orelse return;
        engine.runTaskInRealm(channel.ctx, steps, self) catch {};
    }

    fn steps(data: ?*anyopaque) void {
        const self: *Delivery = @ptrCast(@alignCast(data orelse return));
        const channel = self.target() orelse return;
        const internal = getInternal(channel) orelse return;
        // "1. If destination's closed flag is true, then abort these steps."
        if (internal.closed) return;
        // The event loop runs no task whose document is not fully active,
        // nor one of a worker whose closing flag is set.
        if (!eligibleForMessaging(channel)) return;
        // "2. Let targetRealm be destination's relevant realm. 3. Let data be
        // StructuredDeserialize(serialized, targetRealm). If this throws an
        // exception, catch it, fire an event named messageerror at
        // destination, using MessageEvent, with the origin attribute
        // initialized to the serialization of sourceOrigin, and then abort
        // these steps."
        const value = engine.structuredDeserializeWithTransfer(channel.ctx, self.serialized, &.{}) catch {
            fire(channel, "messageerror", null, self.origin);
            return;
        };
        defer value.release();
        // "4. Fire an event named message at destination, using
        // MessageEvent, with the data attribute initialized to data and the
        // origin attribute initialized to the serialization of
        // sourceOrigin."
        fire(channel, "message", value.borrow(), self.origin);
    }
};

/// Queue step 9's task for `destination` on its global's event loop.
fn queueDelivery(destination: *runtime.Instance, serialized: []const u8, origin: []const u8) void {
    const timer = destination.ctx.getOptionalTimer() orelse return;
    const allocator = destination.ctx.allocator;
    const task = allocator.create(Delivery) catch return;
    const bytes = allocator.dupe(u8, serialized) catch {
        allocator.destroy(task);
        return;
    };
    const origin_copy = allocator.dupe(u8, origin) catch {
        allocator.free(bytes);
        allocator.destroy(task);
        return;
    };
    task.* = .{
        .channel = destination,
        .generation = runtime.SlabAllocator.generationOf(destination),
        .allocator = allocator,
        .serialized = bytes,
        .origin = origin_copy,
    };
    if (timer.setTimeout(0, Delivery.run, task) == 0) task.destroy();
}

/// Fire a MessageEvent named `event_type` at `channel`, with `data` (null for
/// messageerror) and `origin`. `data` is borrowed: the event keeps its own.
fn fire(channel: *runtime.Instance, event_type: []const u8, data: ?runtime.JSValue, origin: []const u8) void {
    const init_dict = dictionaries.MessageEventInit{
        .base = .{},
        .data = data,
        .origin = origin,
    };
    const event = interfaces.MessageEvent.call_constructor(
        channel.ctx,
        runtime.DOMString.initInterned(event_type),
        webidl.Opt(dictionaries.MessageEventInit).passed(init_dict),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    // Fired by the user agent: trusted.
    _ = EventTargetImpl.dispatchTrusted(channel, event) catch {};
    event.releaseIfUnwrapped(generation);
}
