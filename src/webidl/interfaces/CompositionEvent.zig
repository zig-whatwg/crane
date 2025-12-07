//! Generated from: uievents.idl
//! Generated at: 2025-12-07T20:02:44Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const CompositionEventImpl = @import("impls").CompositionEvent;
const mixins = @import("mixins");
const UIEvent = @import("interfaces").UIEvent;
const UIEventInit = @import("dictionaries").UIEventInit;
const Window = @import("interfaces").Window;
const CompositionEventInit = @import("dictionaries").CompositionEventInit;
const EventTarget = @import("interfaces").EventTarget;
const WindowProxy = @import("typedefs").WindowProxy;
const InputDeviceCapabilities = @import("interfaces").InputDeviceCapabilities;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const CompositionEvent = struct {
    pub const Meta = struct {
        pub const name = "CompositionEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = UIEvent.State;
        pub const ParentInterface = UIEvent;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "data", "get_data", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "initCompositionEvent", "call_initCompositionEvent", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "initCompositionEvent",
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
            data: runtime.USVString = undefined,
            _internal: ?*CompositionEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_data = &get_data,

        .call_initCompositionEvent = &call_initCompositionEvent,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CompositionEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CompositionEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: webidl.Opt(CompositionEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CompositionEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try CompositionEventImpl.get_data(instance);
    }

    pub fn call_initCompositionEvent(instance: *runtime.Instance, typeArg: DOMString, bubblesArg: webidl.Opt(bool), cancelableArg: webidl.Opt(bool), viewArg: webidl.Opt(?WindowProxy), dataArg: webidl.Opt(DOMString)) anyerror!void {
        
        return try CompositionEventImpl.call_initCompositionEvent(instance, typeArg, bubblesArg, cancelableArg, viewArg, dataArg);
    }

};
