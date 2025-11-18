//! Generated from: uievents.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const KeyboardEventImpl = @import("../impls/KeyboardEvent.zig");
const UIEvent = @import("UIEvent.zig");

pub const KeyboardEvent = struct {
    pub const Meta = struct {
        pub const name = "KeyboardEvent";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *UIEvent;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Properties that cannot be shadowed or deleted (configurable: false)
        pub const legacy_unforgeable_properties = .{
            "isTrusted",
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            key: runtime.DOMString = undefined,
            code: runtime.DOMString = undefined,
            location: u32 = undefined,
            ctrlKey: bool = undefined,
            shiftKey: bool = undefined,
            altKey: bool = undefined,
            metaKey: bool = undefined,
            repeat: bool = undefined,
            isComposing: bool = undefined,
            charCode: u32 = undefined,
            keyCode: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned long DOM_KEY_LOCATION_STANDARD = 0;
    pub fn get_DOM_KEY_LOCATION_STANDARD() u32 {
        return 0;
    }

    /// WebIDL constant: const unsigned long DOM_KEY_LOCATION_LEFT = 1;
    pub fn get_DOM_KEY_LOCATION_LEFT() u32 {
        return 1;
    }

    /// WebIDL constant: const unsigned long DOM_KEY_LOCATION_RIGHT = 2;
    pub fn get_DOM_KEY_LOCATION_RIGHT() u32 {
        return 2;
    }

    /// WebIDL constant: const unsigned long DOM_KEY_LOCATION_NUMPAD = 3;
    pub fn get_DOM_KEY_LOCATION_NUMPAD() u32 {
        return 3;
    }

    pub const vtable = runtime.buildVTable(KeyboardEvent, .{
        .deinit_fn = &deinit_wrapper,

        .get_AT_TARGET = &UIEvent.get_AT_TARGET,
        .get_BUBBLING_PHASE = &UIEvent.get_BUBBLING_PHASE,
        .get_CAPTURING_PHASE = &UIEvent.get_CAPTURING_PHASE,
        .get_DOM_KEY_LOCATION_LEFT = &get_DOM_KEY_LOCATION_LEFT,
        .get_DOM_KEY_LOCATION_NUMPAD = &get_DOM_KEY_LOCATION_NUMPAD,
        .get_DOM_KEY_LOCATION_RIGHT = &get_DOM_KEY_LOCATION_RIGHT,
        .get_DOM_KEY_LOCATION_STANDARD = &get_DOM_KEY_LOCATION_STANDARD,
        .get_NONE = &UIEvent.get_NONE,
        .get_altKey = &get_altKey,
        .get_bubbles = &get_bubbles,
        .get_cancelBubble = &get_cancelBubble,
        .get_cancelable = &get_cancelable,
        .get_charCode = &get_charCode,
        .get_code = &get_code,
        .get_composed = &get_composed,
        .get_ctrlKey = &get_ctrlKey,
        .get_currentTarget = &get_currentTarget,
        .get_defaultPrevented = &get_defaultPrevented,
        .get_detail = &get_detail,
        .get_eventPhase = &get_eventPhase,
        .get_isComposing = &get_isComposing,
        .get_isTrusted = &get_isTrusted,
        .get_key = &get_key,
        .get_keyCode = &get_keyCode,
        .get_location = &get_location,
        .get_metaKey = &get_metaKey,
        .get_repeat = &get_repeat,
        .get_returnValue = &get_returnValue,
        .get_shiftKey = &get_shiftKey,
        .get_sourceCapabilities = &get_sourceCapabilities,
        .get_srcElement = &get_srcElement,
        .get_target = &get_target,
        .get_timeStamp = &get_timeStamp,
        .get_type = &get_type,
        .get_view = &get_view,
        .get_which = &get_which,

        .set_cancelBubble = &set_cancelBubble,
        .set_returnValue = &set_returnValue,

        .call_composedPath = &call_composedPath,
        .call_getModifierState = &call_getModifierState,
        .call_initEvent = &call_initEvent,
        .call_initKeyboardEvent = &call_initKeyboardEvent,
        .call_initUIEvent = &call_initUIEvent,
        .call_preventDefault = &call_preventDefault,
        .call_stopImmediatePropagation = &call_stopImmediatePropagation,
        .call_stopPropagation = &call_stopPropagation,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        KeyboardEventImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        KeyboardEventImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, type_: runtime.DOMString, eventInitDict: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try KeyboardEventImpl.constructor(state, type_, eventInitDict);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_type(state);
    }

    pub fn get_target(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_target(state);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_srcElement(state);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_currentTarget(state);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_eventPhase(state);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_cancelBubble(state);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        KeyboardEventImpl.set_cancelBubble(state, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_bubbles(state);
    }

    pub fn get_cancelable(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_cancelable(state);
    }

    pub fn get_returnValue(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_returnValue(state);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        KeyboardEventImpl.set_returnValue(state, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_defaultPrevented(state);
    }

    pub fn get_composed(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_composed(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_isTrusted(state);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_timeStamp(state);
    }

    pub fn get_view(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_view(state);
    }

    pub fn get_detail(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_detail(state);
    }

    pub fn get_which(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_which(state);
    }

    pub fn get_sourceCapabilities(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_sourceCapabilities(state);
    }

    pub fn get_key(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_key(state);
    }

    pub fn get_code(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_code(state);
    }

    pub fn get_location(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_location(state);
    }

    pub fn get_ctrlKey(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_ctrlKey(state);
    }

    pub fn get_shiftKey(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_shiftKey(state);
    }

    pub fn get_altKey(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_altKey(state);
    }

    pub fn get_metaKey(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_metaKey(state);
    }

    pub fn get_repeat(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_repeat(state);
    }

    pub fn get_isComposing(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_isComposing(state);
    }

    pub fn get_charCode(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_charCode(state);
    }

    pub fn get_keyCode(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return KeyboardEventImpl.get_keyCode(state);
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyboardEventImpl.call_stopImmediatePropagation(state);
    }

    pub fn call_initEvent(instance: *runtime.Instance, type_: runtime.DOMString, bubbles: bool, cancelable: bool) anyopaque {
        const state = instance.getState(State);
        
        return KeyboardEventImpl.call_initEvent(state, type_, bubbles, cancelable);
    }

    pub fn call_getModifierState(instance: *runtime.Instance, keyArg: runtime.DOMString) bool {
        const state = instance.getState(State);
        
        return KeyboardEventImpl.call_getModifierState(state, keyArg);
    }

    pub fn call_initKeyboardEvent(instance: *runtime.Instance, typeArg: runtime.DOMString, bubblesArg: bool, cancelableArg: bool, viewArg: anyopaque, keyArg: runtime.DOMString, locationArg: u32, ctrlKey: bool, altKey: bool, shiftKey: bool, metaKey: bool) anyopaque {
        const state = instance.getState(State);
        
        return KeyboardEventImpl.call_initKeyboardEvent(state, typeArg, bubblesArg, cancelableArg, viewArg, keyArg, locationArg, ctrlKey, altKey, shiftKey, metaKey);
    }

    pub fn call_initUIEvent(instance: *runtime.Instance, typeArg: runtime.DOMString, bubblesArg: bool, cancelableArg: bool, viewArg: anyopaque, detailArg: i32) anyopaque {
        const state = instance.getState(State);
        
        return KeyboardEventImpl.call_initUIEvent(state, typeArg, bubblesArg, cancelableArg, viewArg, detailArg);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyboardEventImpl.call_composedPath(state);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyboardEventImpl.call_stopPropagation(state);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyboardEventImpl.call_preventDefault(state);
    }

};
