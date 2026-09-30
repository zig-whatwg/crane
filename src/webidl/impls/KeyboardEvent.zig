//! Implementation for KeyboardEvent interface
//!
//! Spec: https://w3c.github.io/uievents/#interface-keyboardevent
//!
//! ```idl
//! [Exposed=Window]
//! interface KeyboardEvent : UIEvent {
//!   constructor(DOMString type, optional KeyboardEventInit eventInitDict = {});
//!   const unsigned long DOM_KEY_LOCATION_STANDARD = 0x00; ...
//!   readonly attribute DOMString key;
//!   readonly attribute DOMString code;
//!   readonly attribute unsigned long location;
//!   readonly attribute boolean ctrlKey, shiftKey, altKey, metaKey;
//!   readonly attribute boolean repeat;
//!   readonly attribute boolean isComposing;
//!   boolean getModifierState(DOMString keyArg);
//! };
//! dictionary KeyboardEventInit : EventModifierInit {
//!   DOMString key = ""; DOMString code = ""; unsigned long location = 0;
//!   boolean repeat = false; boolean isComposing = false;
//!   unsigned long charCode = 0; unsigned long keyCode = 0;  // legacy
//! };
//! ```

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const event_construction = @import("dom").event_construction;
const KeyboardEvent = interfaces.KeyboardEvent;

pub const State = KeyboardEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// The modifier keys getModifierState names, in the order of UI Events'
/// "Modifier Keys" table, with the EventModifierInit member that
/// initializes each.
const Modifier = enum(u4) {
    Alt,
    AltGraph,
    CapsLock,
    Control,
    Fn,
    FnLock,
    Hyper,
    Meta,
    NumLock,
    ScrollLock,
    Shift,
    Super,
    Symbol,
    SymbolLock,
};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// Owned.
    key: []u8 = &.{},
    /// Owned.
    code: []u8 = &.{},
    location: u32 = 0,
    repeat: bool = false,
    is_composing: bool = false,
    char_code: u32 = 0,
    key_code: u32 = 0,
    /// Every modifier the event was initialized with, by `Modifier`.
    modifiers: std.EnumSet(Modifier) = .{},

    fn setKey(self: *InternalState, value: []const u8) !void {
        const copy = try self.allocator.dupe(u8, value);
        self.allocator.free(self.key);
        self.key = copy;
    }

    fn setCode(self: *InternalState, value: []const u8) !void {
        const copy = try self.allocator.dupe(u8, value);
        self.allocator.free(self.code);
        self.code = copy;
    }
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// Initialize instance: the UIEvent part, then KeyboardEvent's own state.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try interfaces.UIEvent.initWithState(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance: its own state, then the UIEvent part.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.allocator.free(internal.key);
        internal.allocator.free(internal.code);
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    interfaces.UIEvent.deinit(instance);
}

/// Constructor: inner event creation steps, the UIEventInit members, then
/// EventModifierInit's and KeyboardEventInit's.
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.KeyboardEventInit)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &KeyboardEvent.vtable, ctx);
    errdefer deinit(instance);
    const dict: dictionaries.KeyboardEventInit = if (eventInitDict.was_passed) eventInitDict.value else .{ .base = .{ .base = .{ .base = .{} } } };
    const modifier_init = dict.base;
    try event_construction.innerEventCreationSteps(instance, @"type", event_construction.eventInitFrom(modifier_init.base.base));
    event_construction.initializeUIEvent(instance, event_construction.uiEventInitFrom(modifier_init.base));

    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try internal.setKey(if (dict.key) |k| k.asSlice() else "");
    try internal.setCode(if (dict.code) |c| c.asSlice() else "");
    internal.location = dict.location orelse 0;
    internal.repeat = dict.repeat orelse false;
    internal.is_composing = dict.isComposing orelse false;
    internal.char_code = dict.charCode orelse 0;
    internal.key_code = dict.keyCode orelse 0;
    internal.modifiers = modifiersOf(modifier_init);
    return instance;
}

/// The modifiers an EventModifierInit sets: ctrlKey is "Control", and each
/// modifierX member is "X".
fn modifiersOf(init_dict: dictionaries.EventModifierInit) std.EnumSet(Modifier) {
    var set: std.EnumSet(Modifier) = .{};
    if (init_dict.ctrlKey orelse false) set.insert(.Control);
    if (init_dict.shiftKey orelse false) set.insert(.Shift);
    if (init_dict.altKey orelse false) set.insert(.Alt);
    if (init_dict.metaKey orelse false) set.insert(.Meta);
    if (init_dict.modifierAltGraph orelse false) set.insert(.AltGraph);
    if (init_dict.modifierCapsLock orelse false) set.insert(.CapsLock);
    if (init_dict.modifierFn orelse false) set.insert(.Fn);
    if (init_dict.modifierFnLock orelse false) set.insert(.FnLock);
    if (init_dict.modifierHyper orelse false) set.insert(.Hyper);
    if (init_dict.modifierNumLock orelse false) set.insert(.NumLock);
    if (init_dict.modifierScrollLock orelse false) set.insert(.ScrollLock);
    if (init_dict.modifierSuper orelse false) set.insert(.Super);
    if (init_dict.modifierSymbol orelse false) set.insert(.Symbol);
    if (init_dict.modifierSymbolLock orelse false) set.insert(.SymbolLock);
    return set;
}

fn hasModifier(instance: *runtime.Instance, modifier: Modifier) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.modifiers.contains(modifier);
}

/// Getter for key. A copy: the binding frees what a string getter returns.
pub fn get_key(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    return runtime.DOMString.initDupe(instance.ctx.allocator, internal.key);
}

/// Getter for code. A copy, as key's.
pub fn get_code(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    return runtime.DOMString.initDupe(instance.ctx.allocator, internal.code);
}

/// Getter for location
pub fn get_location(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return 0;
    return internal.location;
}

/// Getter for ctrlKey
pub fn get_ctrlKey(instance: *runtime.Instance) anyerror!bool {
    return hasModifier(instance, .Control);
}

/// Getter for shiftKey
pub fn get_shiftKey(instance: *runtime.Instance) anyerror!bool {
    return hasModifier(instance, .Shift);
}

/// Getter for altKey
pub fn get_altKey(instance: *runtime.Instance) anyerror!bool {
    return hasModifier(instance, .Alt);
}

/// Getter for metaKey
pub fn get_metaKey(instance: *runtime.Instance) anyerror!bool {
    return hasModifier(instance, .Meta);
}

/// Getter for repeat
pub fn get_repeat(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    return internal.repeat;
}

/// Getter for isComposing
pub fn get_isComposing(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    return internal.is_composing;
}

/// Getter for charCode (legacy): the value it was initialized to.
pub fn get_charCode(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return 0;
    return internal.char_code;
}

/// Getter for keyCode (legacy): the value it was initialized to.
pub fn get_keyCode(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return 0;
    return internal.key_code;
}

/// Operation: getModifierState
/// Spec: https://w3c.github.io/uievents/#dom-keyboardevent-getmodifierstate
///
/// "Returns true if it is a modifier key and the modifier is activated" -
/// keyArg is one of the modifier key values, compared case-sensitively.
pub fn call_getModifierState(instance: *runtime.Instance, keyArg: runtime.DOMString) anyerror!bool {
    const modifier = std.meta.stringToEnum(Modifier, keyArg.asSlice()) orelse return false;
    return hasModifier(instance, modifier);
}

/// Operation: initKeyboardEvent (legacy)
/// Spec: https://w3c.github.io/uievents/#dom-keyboardevent-initkeyboardevent
///
/// "If this's dispatch flag is set, return; initialize this with typeArg,
/// bubblesArg and cancelableArg; set view, key, location and the four
/// modifier attributes from the arguments."
pub fn call_initKeyboardEvent(instance: *runtime.Instance, typeArg: runtime.DOMString, bubblesArg: webidl.Opt(bool), cancelableArg: webidl.Opt(bool), viewArg: webidl.Opt(?*runtime.Instance), keyArg: webidl.Opt(runtime.DOMString), locationArg: webidl.Opt(u32), ctrlKey: webidl.Opt(bool), altKey: webidl.Opt(bool), shiftKey: webidl.Opt(bool), metaKey: webidl.Opt(bool)) anyerror!void {
    if (event_construction.dispatchFlag(instance)) return;
    try interfaces.UIEvent.call_initUIEvent(instance, typeArg, bubblesArg, cancelableArg, viewArg, webidl.Opt(i32).notPassed());
    const internal = getInternal(instance) orelse return;
    try internal.setKey(if (keyArg.was_passed) keyArg.value.asSlice() else "");
    internal.location = locationArg.getOrDefault(0);
    var set: std.EnumSet(Modifier) = .{};
    if (ctrlKey.getOrDefault(false)) set.insert(.Control);
    if (altKey.getOrDefault(false)) set.insert(.Alt);
    if (shiftKey.getOrDefault(false)) set.insert(.Shift);
    if (metaKey.getOrDefault(false)) set.insert(.Meta);
    internal.modifiers = set;
}
