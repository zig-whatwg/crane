//! Generated from: touch-events.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TouchEventImpl = @import("impls").TouchEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const UIEvent = @import("UIEvent.zig").UIEvent;
const UIEventInit = @import("dictionaries").UIEventInit;
const Window = @import("Window.zig").Window;
const TouchEventInit = @import("dictionaries").TouchEventInit;
const EventTarget = @import("EventTarget.zig").EventTarget;
const TouchList = @import("TouchList.zig").TouchList;
const InputDeviceCapabilities = @import("InputDeviceCapabilities.zig").InputDeviceCapabilities;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const TouchEvent = struct {
    pub const Meta = struct {
        pub const name = "TouchEvent";
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
            .{ "touches", "get_touches", null },
            .{ "targetTouches", "get_targetTouches", null },
            .{ "changedTouches", "get_changedTouches", null },
            .{ "altKey", "get_altKey", null },
            .{ "metaKey", "get_metaKey", null },
            .{ "ctrlKey", "get_ctrlKey", null },
            .{ "shiftKey", "get_shiftKey", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getModifierState", "call_getModifierState", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getModifierState",
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
            .{ "touches", "get_touches", null },
            .{ "targetTouches", "get_targetTouches", null },
            .{ "changedTouches", "get_changedTouches", null },
            .{ "altKey", "get_altKey", null },
            .{ "metaKey", "get_metaKey", null },
            .{ "ctrlKey", "get_ctrlKey", null },
            .{ "shiftKey", "get_shiftKey", null },
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
            touches: *runtime.Instance = undefined,
            targetTouches: *runtime.Instance = undefined,
            changedTouches: *runtime.Instance = undefined,
            altKey: bool = undefined,
            metaKey: bool = undefined,
            ctrlKey: bool = undefined,
            shiftKey: bool = undefined,
            _internal: ?*TouchEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_altKey = &get_altKey,
        .get_changedTouches = &get_changedTouches,
        .get_ctrlKey = &get_ctrlKey,
        .get_metaKey = &get_metaKey,
        .get_shiftKey = &get_shiftKey,
        .get_targetTouches = &get_targetTouches,
        .get_touches = &get_touches,

        .call_getModifierState = &call_getModifierState,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TouchEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return TouchEventImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TouchEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": DOMString, eventInitDict: webidl.Opt(TouchEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TouchEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    pub fn get_touches(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try TouchEventImpl.get_touches(instance);
    }

    pub fn get_targetTouches(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try TouchEventImpl.get_targetTouches(instance);
    }

    pub fn get_changedTouches(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try TouchEventImpl.get_changedTouches(instance);
    }

    pub fn get_altKey(instance: *runtime.Instance) anyerror!bool {
        return try TouchEventImpl.get_altKey(instance);
    }

    pub fn get_metaKey(instance: *runtime.Instance) anyerror!bool {
        return try TouchEventImpl.get_metaKey(instance);
    }

    pub fn get_ctrlKey(instance: *runtime.Instance) anyerror!bool {
        return try TouchEventImpl.get_ctrlKey(instance);
    }

    pub fn get_shiftKey(instance: *runtime.Instance) anyerror!bool {
        return try TouchEventImpl.get_shiftKey(instance);
    }

    pub fn call_getModifierState(instance: *runtime.Instance, keyArg: DOMString) anyerror!bool {
        
        return try TouchEventImpl.call_getModifierState(instance, keyArg);
    }

    /// Get supported property names for named property enumeration (Reflect.ownKeys, etc.)
    /// Per WebIDL spec §3.9.3, returns names in list order for proper enumeration
    pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
        return TouchEventImpl.getSupportedPropertyNames(instance, allocator);
    }

};
