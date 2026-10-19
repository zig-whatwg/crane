//! Implementation for ExtendableCookieChangeEvent interface
//!
//! WHATWG Cookie Store Standard 5.2:
//! https://cookiestore.spec.whatwg.org/#extendablecookiechangeevent
//!
//! The `cookiechange` functional event a service worker's global gets when a
//! cookie change matches its registration's cookie change subscription list
//! (Cookie Store "process cookie changes" step 2.5): an ExtendableEvent (its
//! extended lifetime is ExtendableEvent's construction argument) with the
//! changed and deleted lists. The service worker's thread
//! (src/service_worker/run.zig) makes it with `cookie_changes`, the lists
//! prepared when the change was processed; script constructs one with a
//! dictionary.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const cookie_values = @import("cookie_values.zig");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const cookiestore = @import("cookiestore");
const dom = @import("dom");
const service_worker = @import("service_worker");
const ExtendableCookieChangeEvent = interfaces.ExtendableCookieChangeEvent;
const CookieListItem = cookiestore.CookieListItem;

pub const State = ExtendableCookieChangeEvent.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    OutOfMemory,
};

/// What the user agent's event is made with
/// (service_worker.CookieChangeLists), BORROWED: the event copies the lists.
pub const construction_args = .{"cookie_changes"};

/// Internal state for ExtendableCookieChangeEvent implementation
/// Same as CookieChangeEvent but extends ExtendableEvent
pub const InternalState = struct {
    /// Changed cookies (FrozenArray<CookieListItem>)
    changed: std.ArrayListUnmanaged(CookieListItem),

    /// Deleted cookies (FrozenArray<CookieListItem>)
    deleted: std.ArrayListUnmanaged(CookieListItem),

    /// The attributes' values: `[SameObject] FrozenArray<CookieListItem>`,
    /// each made on its first read and returned on every read after - one
    /// frozen array per attribute for the event's life, kept by an edge from
    /// the event's wrapper (`changed_slot`, `deleted_slot`; engine.traceValue),
    /// never a root.
    has_changed_array: bool = false,
    has_deleted_array: bool = false,

    /// Allocator for internal allocations
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*InternalState {
        const internal = try allocator.create(InternalState);
        internal.* = InternalState{
            .changed = .empty,
            .deleted = .empty,
            .allocator = allocator,
        };
        return internal;
    }

    /// The attributes' arrays are let go - where the event ends, its
    /// instance deinit; the Zig state (`deinit`) holds no engine value. An
    /// event the collector freed lost them with its wrapper; one freed before
    /// script saw it lets go of the arrays waiting for its wrapper.
    fn releaseArrays(self: *InternalState, event: *runtime.Instance) void {
        if (self.has_changed_array) engine.forgetTracedChild(event, changed_slot);
        if (self.has_deleted_array) engine.forgetTracedChild(event, deleted_slot);
        self.has_changed_array = false;
        self.has_deleted_array = false;
    }

    pub fn deinit(self: *InternalState) void {
        for (self.changed.items) |*item| {
            item.deinit();
        }
        self.changed.deinit(self.allocator);

        for (self.deleted.items) |*item| {
            item.deinit();
        }
        self.deleted.deinit(self.allocator);

        self.allocator.destroy(self);
    }
};

/// ExtendableCookieChangeEvent's own construction steps: the generated chain
/// runs ExtendableEvent's (and Event's) first.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    const internal = try InternalState.init(allocator);
    instance.getState(State).own._internal = internal;
    if (!@hasField(@TypeOf(args), "cookie_changes")) return;
    const lists: *const service_worker.CookieChangeLists = args.cookie_changes;
    for (lists.changed) |item| try appendCopy(&internal.changed, allocator, item);
    for (lists.deleted) |item| try appendCopy(&internal.deleted, allocator, item);
}

fn appendCopy(list: *std.ArrayListUnmanaged(CookieListItem), allocator: std.mem.Allocator, item: CookieListItem) !void {
    var copy = try item.clone(allocator);
    errdefer copy.deinit();
    try list.append(allocator, copy);
}

/// ExtendableCookieChangeEvent's own teardown: the generated chain runs
/// ExtendableEvent's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.releaseArrays(instance);
        internal.deinit();
        state.own._internal = null;
    }
}

/// Helper to get internal state
fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// The constructor (5.2): Event's inner event creation steps with the
/// dictionary's EventInit, then changed and deleted - "the value they were
/// initialized to": an item with no `value` member keeps none.
/// https://cookiestore.spec.whatwg.org/#dom-extendablecookiechangeevent-extendablecookiechangeevent
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.ExtendableCookieChangeEventInit)) !*runtime.Instance {
    const instance = try ExtendableCookieChangeEvent.init(ctx.allocator, ctx);
    errdefer ExtendableCookieChangeEvent.deinit(instance);
    const given: dictionaries.ExtendableCookieChangeEventInit = if (eventInitDict.was_passed) eventInitDict.value else .{ .base = .{ .base = .{} } };
    try dom.event_construction.innerEventCreationSteps(instance, @"type", dom.event_construction.eventInitFrom(given.base.base));
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    if (given.changed) |changed_list| for (changed_list) |dict_item| try appendItem(&internal.changed, ctx.allocator, dict_item);
    if (given.deleted) |deleted_list| for (deleted_list) |dict_item| try appendItem(&internal.deleted, ctx.allocator, dict_item);
    return instance;
}

fn appendItem(list: *std.ArrayListUnmanaged(CookieListItem), allocator: std.mem.Allocator, dict_item: dictionaries.CookieListItem) !void {
    var item = try CookieListItem.init(allocator, dict_item.name orelse "", dict_item.value orelse "");
    item.has_value = dict_item.value != null;
    errdefer item.deinit();
    try list.append(allocator, item);
}

// ============================================================================
// FrozenArray<CookieListItem> attributes
//
// `changed` and `deleted` are `[SameObject] FrozenArray<CookieListItem>`: the
// attribute returns the same frozen array on every read. Each is made on its
// first read - in the event's relevant realm - kept by an edge from the
// event's wrapper, and returned as a hold of the binding's own. The getters built a fresh, unfrozen array per read and handed it
// back as non-owning, which leaked the array's handle on every read.
// ============================================================================

/// The array `slot` holds, made from `items` on the first call.
fn frozenAttribute(instance: *runtime.Instance, internal: *InternalState, slot: engine.TracedSlot, made: *bool, items: []const CookieListItem) !runtime.JSValue {
    // The event keeps its array ([SameObject]); the binding gets a hold of
    // its own.
    if (made.*) {
        if (engine.tracedValue(instance, slot)) |array| return array.take();
    }
    const array = try cookie_values.frozenList(instance.ctx, items, internal.allocator);
    engine.traceValue(instance, array.value, slot);
    made.* = true;
    return array.take();
}

const changed_slot: engine.TracedSlot = .{ .name = "changed" };
const deleted_slot: engine.TracedSlot = .{ .name = "deleted" };

/// Getter for changed
/// https://cookiestore.spec.whatwg.org/#dom-extendablecookiechangeevent-changed
pub fn get_changed(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    return frozenAttribute(instance, internal, changed_slot, &internal.has_changed_array, internal.changed.items);
}

/// Getter for deleted
/// https://cookiestore.spec.whatwg.org/#dom-extendablecookiechangeevent-deleted
pub fn get_deleted(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    return frozenAttribute(instance, internal, deleted_slot, &internal.has_deleted_array, internal.deleted.items);
}
