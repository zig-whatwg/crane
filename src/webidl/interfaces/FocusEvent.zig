//! Generated from: uievents.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FocusEventImpl = @import("impls").FocusEvent;
const mixins = @import("mixins");
const UIEvent = @import("interfaces").UIEvent;
const UIEventInit = @import("dictionaries").UIEventInit;
const Window = @import("interfaces").Window;
const EventTarget = @import("interfaces").EventTarget;
const InputDeviceCapabilities = @import("interfaces").InputDeviceCapabilities;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;
const FocusEventInit = @import("dictionaries").FocusEventInit;

pub const FocusEvent = struct {
    pub const Meta = struct {
        pub const name = "FocusEvent";
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
            .{ "relatedTarget", "get_relatedTarget", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
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
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "relatedTarget", "get_relatedTarget", null },
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
            relatedTarget: ?*runtime.Instance = null,
            _internal: ?*FocusEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_relatedTarget = &get_relatedTarget,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FocusEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FocusEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: webidl.Opt(FocusEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try FocusEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict.value);
    }

    pub fn get_relatedTarget(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try FocusEventImpl.get_relatedTarget(instance);
    }

};
