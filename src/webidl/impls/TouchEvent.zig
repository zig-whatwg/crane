//! Implementation for TouchEvent interface (Touch Events, "TouchEvent
//! Interface"): a UIEvent with three lists of Touch objects and the
//! modifier keys - immutable once made, by script's constructor or by the
//! user agent for a touch the input layer reports (html.user_input).
//!
//! The touches are kept the way Blink's TouchEvent keeps its lists
//! (traced): each Touch by an edge from the event's wrapper, slot
//! "<list>.<i>". The TouchList objects script reads are made on first read
//! and kept by an edge too (slots "touches", "targetTouches",
//! "changedTouches"), so each attribute answers the same object.
//!
//! The event's touch target list (DOM 2.2; Touch Events "Retargeting") is
//! its touches' unadjusted targets, in the order touches, targetTouches,
//! changedTouches; each touch is told where its target is listed
//! (dom.touch_points.adopt), and reads it there while the event is
//! dispatched.
//!
//! Spec: https://w3c.github.io/touch-events/#touchevent-interface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const dom = @import("dom");
const event_construction = dom.event_construction;
const KeptInstance = dom.custom_elements.KeptInstance;
const InternalStateAccessor = webidl.utils.InternalStateAccessor;
const TouchEvent = interfaces.TouchEvent;

pub const State = TouchEvent.State;

pub const ImplError = error{
    InvalidState,
    OutOfMemory,
};

const List = enum(u2) {
    touches,
    targetTouches,
    changedTouches,
};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// Each list's touches, each kept by the edge in slot "<list>.<i>".
    lists: [3][]KeptInstance = .{ &.{}, &.{}, &.{} },
    /// The TouchList objects made for script, each kept by the edge in slot
    /// "<list>".
    objects: [3]?KeptInstance = .{ null, null, null },
    alt_key: bool = false,
    ctrl_key: bool = false,
    meta_key: bool = false,
    shift_key: bool = false,
    /// UI Events getModifierState's other keys, from EventModifierInit.
    modifiers: Modifiers = .{},
};

const Modifiers = struct {
    alt_graph: bool = false,
    caps_lock: bool = false,
    fn_key: bool = false,
    fn_lock: bool = false,
    hyper: bool = false,
    num_lock: bool = false,
    scroll_lock: bool = false,
    super: bool = false,
    symbol: bool = false,
    symbol_lock: bool = false,
};

fn touchSlot(buffer: []u8, list: List, index: usize) engine.TracedSlot {
    return .{ .name = std.fmt.bufPrint(buffer, "{s}.{d}", .{ @tagName(list), index }) catch unreachable };
}

fn listSlot(list: List) engine.TracedSlot {
    return .{ .name = @tagName(list) };
}

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
    return interfaces.UIEvent.initWithState(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance: the event's own storage and the holds of an
/// unwrapped event (a collected one's edges went with its wrapper) - never a
/// Touch or a TouchList - then UIEvent's part.
pub fn deinit(instance: *runtime.Instance) void {
    if (instance.stateAs(State)) |state| if (state.own._internal) |internal| {
        state.own._internal = null;
        inline for (comptime std.enums.values(List)) |list| {
            const kept = internal.lists[@backingInt(list)];
            for (0..kept.len) |index| {
                var buffer: [40]u8 = undefined;
                engine.forgetTracedChild(instance, touchSlot(&buffer, list, index));
            }
            internal.allocator.free(kept);
            if (internal.objects[@backingInt(list)] != null) engine.forgetTracedChild(instance, listSlot(list));
        }
        internal.allocator.destroy(internal);
    };
    interfaces.UIEvent.deinit(instance);
}

/// Constructor: "constructor(DOMString type, optional TouchEventInit
/// eventInitDict = {})" - DOM's inner event creation steps, UIEventInit's
/// and EventModifierInit's members, and the three lists.
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.TouchEventInit)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &TouchEvent.vtable, ctx);
    errdefer deinit(instance);
    const event_init: dictionaries.TouchEventInit = if (eventInitDict.was_passed) eventInitDict.value else .{ .base = .{ .base = .{ .base = .{} } } };
    const modifier_init = event_init.base;
    const ui_init = modifier_init.base;
    try event_construction.innerEventCreationSteps(instance, @"type", event_construction.eventInitFrom(ui_init.base));
    event_construction.initializeUIEvent(instance, event_construction.uiEventInitFrom(ui_init));

    const state = instance.stateAs(State) orelse return error.InvalidState;
    const internal = try ctx.allocator.create(InternalState);
    internal.* = .{
        .allocator = ctx.allocator,
        .alt_key = modifier_init.altKey orelse false,
        .ctrl_key = modifier_init.ctrlKey orelse false,
        .meta_key = modifier_init.metaKey orelse false,
        .shift_key = modifier_init.shiftKey orelse false,
        .modifiers = .{
            .alt_graph = modifier_init.modifierAltGraph orelse false,
            .caps_lock = modifier_init.modifierCapsLock orelse false,
            .fn_key = modifier_init.modifierFn orelse false,
            .fn_lock = modifier_init.modifierFnLock orelse false,
            .hyper = modifier_init.modifierHyper orelse false,
            .num_lock = modifier_init.modifierNumLock orelse false,
            .scroll_lock = modifier_init.modifierScrollLock orelse false,
            .super = modifier_init.modifierSuper orelse false,
            .symbol = modifier_init.modifierSymbol orelse false,
            .symbol_lock = modifier_init.modifierSymbolLock orelse false,
        },
    };
    state.own._internal = internal;

    const sources = [3][]const *runtime.Instance{
        event_init.touches orelse &.{},
        event_init.targetTouches orelse &.{},
        event_init.changedTouches orelse &.{},
    };
    const event_state = dom.event_dispatch.of(instance);
    var listed: u32 = 0;
    inline for (comptime std.enums.values(List)) |list| {
        const source = sources[@backingInt(list)];
        const kept = try ctx.allocator.alloc(KeptInstance, source.len);
        for (source, kept) |touch, *k| k.* = KeptInstance.of(touch);
        internal.lists[@backingInt(list)] = kept;
        for (source, 0..) |touch, index| {
            var buffer: [40]u8 = undefined;
            engine.traceChild(instance, touch, touchSlot(&buffer, list, index));
            // The touch target list: each touch's unadjusted target, the
            // touch told the index of its first entry.
            const target = dom.touch_points.unadjustedTarget(touch) orelse continue;
            const state_ptr = event_state orelse continue;
            if (!alreadyListed(sources, @backingInt(list), index, touch)) dom.touch_points.adopt(touch, instance, listed);
            try state_ptr.touch_target_list.append(runtime.allocatorOf(instance), target);
            listed += 1;
        }
    }
    return instance;
}

/// Whether `touch` is in a list before list `list`'s `index`.
fn alreadyListed(sources: [3][]const *runtime.Instance, list: usize, index: usize, touch: *runtime.Instance) bool {
    for (0..list + 1) |l| {
        const end = if (l == list) index else sources[l].len;
        for (sources[l][0..end]) |other| if (other == touch) return true;
    }
    return false;
}

/// The TouchList for `list`, made on first read and kept.
fn listObject(instance: *runtime.Instance, list: List) !*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidState;
    const index = @backingInt(list);
    if (internal.objects[index]) |kept| if (kept.get()) |object| return object;
    const kept = internal.lists[index];
    var touches: std.ArrayList(*runtime.Instance) = .empty;
    defer touches.deinit(internal.allocator);
    for (kept) |k| if (k.get()) |touch| try touches.append(internal.allocator, touch);
    const object = try interfaces.TouchList.initWith(instance.ctx.allocator, instance.ctx, .{ .touches = @as([]const *runtime.Instance, touches.items) });
    engine.traceChild(instance, object, listSlot(list));
    internal.objects[index] = KeptInstance.of(object);
    return object;
}

/// Getter for touches
pub fn get_touches(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return listObject(instance, .touches);
}

/// Getter for targetTouches
pub fn get_targetTouches(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return listObject(instance, .targetTouches);
}

/// Getter for changedTouches
pub fn get_changedTouches(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return listObject(instance, .changedTouches);
}

/// Getter for altKey
pub fn get_altKey(instance: *runtime.Instance) anyerror!bool {
    return (getInternal(instance) orelse return false).alt_key;
}

/// Getter for metaKey
pub fn get_metaKey(instance: *runtime.Instance) anyerror!bool {
    return (getInternal(instance) orelse return false).meta_key;
}

/// Getter for ctrlKey
pub fn get_ctrlKey(instance: *runtime.Instance) anyerror!bool {
    return (getInternal(instance) orelse return false).ctrl_key;
}

/// Getter for shiftKey
pub fn get_shiftKey(instance: *runtime.Instance) anyerror!bool {
    return (getInternal(instance) orelse return false).shift_key;
}

/// Operation: getModifierState(keyArg) - "true if it is a modifier key and
/// the modifier is activated" (UI Events 7.3.1's key values).
pub fn call_getModifierState(instance: *runtime.Instance, keyArg: runtime.DOMString) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    const key = keyArg.asSlice();
    const m = internal.modifiers;
    const table = [_]struct { []const u8, bool }{
        .{ "Alt", internal.alt_key },     .{ "Control", internal.ctrl_key },
        .{ "Meta", internal.meta_key },   .{ "Shift", internal.shift_key },
        .{ "AltGraph", m.alt_graph },     .{ "CapsLock", m.caps_lock },
        .{ "Fn", m.fn_key },              .{ "FnLock", m.fn_lock },
        .{ "Hyper", m.hyper },            .{ "NumLock", m.num_lock },
        .{ "ScrollLock", m.scroll_lock }, .{ "Super", m.super },
        .{ "Symbol", m.symbol },          .{ "SymbolLock", m.symbol_lock },
    };
    for (table) |row| if (std.mem.eql(u8, key, row[0])) return row[1];
    return false;
}
