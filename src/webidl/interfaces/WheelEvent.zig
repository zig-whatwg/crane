//! Generated from: uievents.idl
//! Generated at: 2025-11-28T19:11:18Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WheelEventImpl = @import("impls").WheelEvent;
const mixins = @import("mixins");
const MouseEvent = @import("interfaces").MouseEvent;
const UIEventInit = @import("dictionaries").UIEventInit;
const Window = @import("interfaces").Window;
const EventTarget = @import("interfaces").EventTarget;
const WheelEventInit = @import("dictionaries").WheelEventInit;
const InputDeviceCapabilities = @import("interfaces").InputDeviceCapabilities;
const MouseEventInit = @import("dictionaries").MouseEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const WheelEvent = struct {
    pub const Meta = struct {
        pub const name = "WheelEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *MouseEvent;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "deltaX", "get_deltaX", null },
            .{ "deltaY", "get_deltaY", null },
            .{ "deltaZ", "get_deltaZ", null },
            .{ "deltaMode", "get_deltaMode", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "DOM_DELTA_PIXEL", "get_DOM_DELTA_PIXEL" },
            .{ "DOM_DELTA_LINE", "get_DOM_DELTA_LINE" },
            .{ "DOM_DELTA_PAGE", "get_DOM_DELTA_PAGE" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
            "initUIEvent",
            "getModifierState",
            "initMouseEvent",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "deltaX", "get_deltaX", null },
            .{ "deltaY", "get_deltaY", null },
            .{ "deltaZ", "get_deltaZ", null },
            .{ "deltaMode", "get_deltaMode", null },
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
            deltaX: f64 = undefined,
            deltaY: f64 = undefined,
            deltaZ: f64 = undefined,
            deltaMode: u32 = undefined,
            _internal: ?*WheelEventImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned long DOM_DELTA_PIXEL = 0;
    pub fn get_DOM_DELTA_PIXEL() u32 {
        return 0;
    }

    /// WebIDL constant: const unsigned long DOM_DELTA_LINE = 1;
    pub fn get_DOM_DELTA_LINE() u32 {
        return 1;
    }

    /// WebIDL constant: const unsigned long DOM_DELTA_PAGE = 2;
    pub fn get_DOM_DELTA_PAGE() u32 {
        return 2;
    }

    const delegates = .{

        .get_DOM_DELTA_LINE = &get_DOM_DELTA_LINE,
        .get_DOM_DELTA_PAGE = &get_DOM_DELTA_PAGE,
        .get_DOM_DELTA_PIXEL = &get_DOM_DELTA_PIXEL,
        .get_deltaMode = &get_deltaMode,
        .get_deltaX = &get_deltaX,
        .get_deltaY = &get_deltaY,
        .get_deltaZ = &get_deltaZ,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WheelEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WheelEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: webidl.Opt(WheelEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try WheelEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_deltaX(instance: *runtime.Instance) anyerror!f64 {
        return try WheelEventImpl.get_deltaX(instance);
    }

    pub fn get_deltaY(instance: *runtime.Instance) anyerror!f64 {
        return try WheelEventImpl.get_deltaY(instance);
    }

    pub fn get_deltaZ(instance: *runtime.Instance) anyerror!f64 {
        return try WheelEventImpl.get_deltaZ(instance);
    }

    pub fn get_deltaMode(instance: *runtime.Instance) anyerror!u32 {
        return try WheelEventImpl.get_deltaMode(instance);
    }

};
