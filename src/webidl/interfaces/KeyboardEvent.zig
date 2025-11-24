//! Generated from: uievents.idl
//! Generated at: 2025-11-24T18:47:06Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const KeyboardEventImpl = @import("impls").KeyboardEvent;
const UIEvent = @import("interfaces").UIEvent;
const Window = @import("interfaces").Window;
const UIEventInit = @import("dictionaries").UIEventInit;
const EventTarget = @import("interfaces").EventTarget;
const InputDeviceCapabilities = @import("interfaces").InputDeviceCapabilities;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;
const KeyboardEventInit = @import("dictionaries").KeyboardEventInit;

pub const KeyboardEvent = struct {
    pub const Meta = struct {
        pub const name = "KeyboardEvent";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *UIEvent;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "key", "get_key", null },
            .{ "code", "get_code", null },
            .{ "location", "get_location", null },
            .{ "ctrlKey", "get_ctrlKey", null },
            .{ "shiftKey", "get_shiftKey", null },
            .{ "altKey", "get_altKey", null },
            .{ "metaKey", "get_metaKey", null },
            .{ "repeat", "get_repeat", null },
            .{ "isComposing", "get_isComposing", null },
            .{ "charCode", "get_charCode", null },
            .{ "keyCode", "get_keyCode", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "getModifierState", "call_getModifierState", 1 },
            .{ "initKeyboardEvent", "call_initKeyboardEvent", 1 },
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "DOM_KEY_LOCATION_STANDARD", "get_DOM_KEY_LOCATION_STANDARD" },
            .{ "DOM_KEY_LOCATION_LEFT", "get_DOM_KEY_LOCATION_LEFT" },
            .{ "DOM_KEY_LOCATION_RIGHT", "get_DOM_KEY_LOCATION_RIGHT" },
            .{ "DOM_KEY_LOCATION_NUMPAD", "get_DOM_KEY_LOCATION_NUMPAD" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getModifierState",
            "initKeyboardEvent",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
            "initUIEvent",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "key", "get_key", null },
            .{ "code", "get_code", null },
            .{ "location", "get_location", null },
            .{ "ctrlKey", "get_ctrlKey", null },
            .{ "shiftKey", "get_shiftKey", null },
            .{ "altKey", "get_altKey", null },
            .{ "metaKey", "get_metaKey", null },
            .{ "repeat", "get_repeat", null },
            .{ "isComposing", "get_isComposing", null },
            .{ "charCode", "get_charCode", null },
            .{ "keyCode", "get_keyCode", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
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
            _internal: ?*KeyboardEventImpl.InternalState = null,
        },
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

    const delegates = .{

        .get_DOM_KEY_LOCATION_LEFT = &get_DOM_KEY_LOCATION_LEFT,
        .get_DOM_KEY_LOCATION_NUMPAD = &get_DOM_KEY_LOCATION_NUMPAD,
        .get_DOM_KEY_LOCATION_RIGHT = &get_DOM_KEY_LOCATION_RIGHT,
        .get_DOM_KEY_LOCATION_STANDARD = &get_DOM_KEY_LOCATION_STANDARD,
        .get_altKey = &get_altKey,
        .get_charCode = &get_charCode,
        .get_code = &get_code,
        .get_ctrlKey = &get_ctrlKey,
        .get_isComposing = &get_isComposing,
        .get_key = &get_key,
        .get_keyCode = &get_keyCode,
        .get_location = &get_location,
        .get_metaKey = &get_metaKey,
        .get_repeat = &get_repeat,
        .get_shiftKey = &get_shiftKey,

        .call_getModifierState = &call_getModifierState,
        .call_initKeyboardEvent = &call_initKeyboardEvent,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return KeyboardEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        KeyboardEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: KeyboardEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try KeyboardEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_key(instance: *runtime.Instance) anyerror!DOMString {
        return try KeyboardEventImpl.get_key(instance);
    }

    pub fn get_code(instance: *runtime.Instance) anyerror!DOMString {
        return try KeyboardEventImpl.get_code(instance);
    }

    pub fn get_location(instance: *runtime.Instance) anyerror!u32 {
        return try KeyboardEventImpl.get_location(instance);
    }

    pub fn get_ctrlKey(instance: *runtime.Instance) anyerror!bool {
        return try KeyboardEventImpl.get_ctrlKey(instance);
    }

    pub fn get_shiftKey(instance: *runtime.Instance) anyerror!bool {
        return try KeyboardEventImpl.get_shiftKey(instance);
    }

    pub fn get_altKey(instance: *runtime.Instance) anyerror!bool {
        return try KeyboardEventImpl.get_altKey(instance);
    }

    pub fn get_metaKey(instance: *runtime.Instance) anyerror!bool {
        return try KeyboardEventImpl.get_metaKey(instance);
    }

    pub fn get_repeat(instance: *runtime.Instance) anyerror!bool {
        return try KeyboardEventImpl.get_repeat(instance);
    }

    pub fn get_isComposing(instance: *runtime.Instance) anyerror!bool {
        return try KeyboardEventImpl.get_isComposing(instance);
    }

    pub fn get_charCode(instance: *runtime.Instance) anyerror!u32 {
        return try KeyboardEventImpl.get_charCode(instance);
    }

    pub fn get_keyCode(instance: *runtime.Instance) anyerror!u32 {
        return try KeyboardEventImpl.get_keyCode(instance);
    }

    pub fn call_getModifierState(instance: *runtime.Instance, keyArg: DOMString) anyerror!bool {
        
        return try KeyboardEventImpl.call_getModifierState(instance, keyArg);
    }

    pub fn call_initKeyboardEvent(instance: *runtime.Instance, typeArg: DOMString, bubblesArg: bool, cancelableArg: bool, viewArg: *runtime.Instance, keyArg: DOMString, locationArg: u32, ctrlKey: bool, altKey: bool, shiftKey: bool, metaKey: bool) anyerror!void {
        
        return try KeyboardEventImpl.call_initKeyboardEvent(instance, typeArg, bubblesArg, cancelableArg, viewArg, keyArg, locationArg, ctrlKey, altKey, shiftKey, metaKey);
    }

};
