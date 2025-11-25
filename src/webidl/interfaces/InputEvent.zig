//! Generated from: uievents.idl
//! Generated at: 2025-11-25T20:02:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const InputEventImpl = @import("impls").InputEvent;
const UIEvent = @import("interfaces").UIEvent;
const Window = @import("interfaces").Window;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const USVString = @import("interfaces").USVString;
const UIEventInit = @import("dictionaries").UIEventInit;
const InputEventInit = @import("dictionaries").InputEventInit;
const EventTarget = @import("interfaces").EventTarget;
const InputDeviceCapabilities = @import("interfaces").InputDeviceCapabilities;
const EventInit = @import("dictionaries").EventInit;
const DataTransfer = @import("interfaces").DataTransfer;
const DOMString = @import("typedefs").DOMString;
const StaticRange = @import("interfaces").StaticRange;

pub const InputEvent = struct {
    pub const Meta = struct {
        pub const name = "InputEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "data", "get_data", null },
            .{ "isComposing", "get_isComposing", null },
            .{ "inputType", "get_inputType", null },
            .{ "dataTransfer", "get_dataTransfer", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getTargetRanges", "call_getTargetRanges", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getTargetRanges",
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
            .{ "data", "get_data", null },
            .{ "isComposing", "get_isComposing", null },
            .{ "inputType", "get_inputType", null },
            .{ "dataTransfer", "get_dataTransfer", null },
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
            data: ?runtime.USVString = null,
            isComposing: bool = undefined,
            inputType: runtime.DOMString = undefined,
            dataTransfer: ?*runtime.Instance = null,
            _internal: ?*InputEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_data = &get_data,
        .get_dataTransfer = &get_dataTransfer,
        .get_inputType = &get_inputType,
        .get_isComposing = &get_isComposing,

        .call_getTargetRanges = &call_getTargetRanges,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return InputEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        InputEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: InputEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try InputEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!?runtime.USVString {
        return try InputEventImpl.get_data(instance);
    }

    pub fn get_isComposing(instance: *runtime.Instance) anyerror!bool {
        return try InputEventImpl.get_isComposing(instance);
    }

    pub fn get_inputType(instance: *runtime.Instance) anyerror!DOMString {
        return try InputEventImpl.get_inputType(instance);
    }

    pub fn get_dataTransfer(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try InputEventImpl.get_dataTransfer(instance);
    }

    pub fn call_getTargetRanges(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try InputEventImpl.call_getTargetRanges(instance);
    }

};
