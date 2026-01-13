//! Generated from: pointerevents.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PointerEventImpl = @import("impls").PointerEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const MouseEvent = @import("MouseEvent.zig").MouseEvent;
const UIEventInit = @import("dictionaries").UIEventInit;
const Window = @import("Window.zig").Window;
const PointerEventInit = @import("dictionaries").PointerEventInit;
const EventTarget = @import("EventTarget.zig").EventTarget;
const InputDeviceCapabilities = @import("InputDeviceCapabilities.zig").InputDeviceCapabilities;
const MouseEventInit = @import("dictionaries").MouseEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const PointerEvent = struct {
    pub const Meta = struct {
        pub const name = "PointerEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = MouseEvent.State;
        pub const ParentInterface = MouseEvent;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "pointerId", "get_pointerId", null },
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "pressure", "get_pressure", null },
            .{ "tangentialPressure", "get_tangentialPressure", null },
            .{ "tiltX", "get_tiltX", null },
            .{ "tiltY", "get_tiltY", null },
            .{ "twist", "get_twist", null },
            .{ "altitudeAngle", "get_altitudeAngle", null },
            .{ "azimuthAngle", "get_azimuthAngle", null },
            .{ "pointerType", "get_pointerType", null },
            .{ "isPrimary", "get_isPrimary", null },
            .{ "persistentDeviceId", "get_persistentDeviceId", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getCoalescedEvents", "call_getCoalescedEvents", 0 },
            .{ "getPredictedEvents", "call_getPredictedEvents", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getCoalescedEvents",
            "getPredictedEvents",
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
            .{ "pointerId", "get_pointerId", null },
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "pressure", "get_pressure", null },
            .{ "tangentialPressure", "get_tangentialPressure", null },
            .{ "tiltX", "get_tiltX", null },
            .{ "tiltY", "get_tiltY", null },
            .{ "twist", "get_twist", null },
            .{ "altitudeAngle", "get_altitudeAngle", null },
            .{ "azimuthAngle", "get_azimuthAngle", null },
            .{ "pointerType", "get_pointerType", null },
            .{ "isPrimary", "get_isPrimary", null },
            .{ "persistentDeviceId", "get_persistentDeviceId", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            pointerId: i32 = undefined,
            width: f64 = undefined,
            height: f64 = undefined,
            pressure: f32 = undefined,
            tangentialPressure: f32 = undefined,
            tiltX: i32 = undefined,
            tiltY: i32 = undefined,
            twist: i32 = undefined,
            altitudeAngle: f64 = undefined,
            azimuthAngle: f64 = undefined,
            pointerType: typedefs.DOMString = undefined,
            isPrimary: bool = undefined,
            persistentDeviceId: i32 = undefined,
            _internal: ?*PointerEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_altitudeAngle = &get_altitudeAngle,
        .get_azimuthAngle = &get_azimuthAngle,
        .get_height = &get_height,
        .get_isPrimary = &get_isPrimary,
        .get_persistentDeviceId = &get_persistentDeviceId,
        .get_pointerId = &get_pointerId,
        .get_pointerType = &get_pointerType,
        .get_pressure = &get_pressure,
        .get_tangentialPressure = &get_tangentialPressure,
        .get_tiltX = &get_tiltX,
        .get_tiltY = &get_tiltY,
        .get_twist = &get_twist,
        .get_width = &get_width,

        .call_getCoalescedEvents = &call_getCoalescedEvents,
        .call_getPredictedEvents = &call_getPredictedEvents,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PointerEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return PointerEventImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PointerEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": DOMString, eventInitDict: webidl.Opt(PointerEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PointerEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    pub fn get_pointerId(instance: *runtime.Instance) anyerror!i32 {
        return try PointerEventImpl.get_pointerId(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!f64 {
        return try PointerEventImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!f64 {
        return try PointerEventImpl.get_height(instance);
    }

    pub fn get_pressure(instance: *runtime.Instance) anyerror!f32 {
        return try PointerEventImpl.get_pressure(instance);
    }

    pub fn get_tangentialPressure(instance: *runtime.Instance) anyerror!f32 {
        return try PointerEventImpl.get_tangentialPressure(instance);
    }

    pub fn get_tiltX(instance: *runtime.Instance) anyerror!i32 {
        return try PointerEventImpl.get_tiltX(instance);
    }

    pub fn get_tiltY(instance: *runtime.Instance) anyerror!i32 {
        return try PointerEventImpl.get_tiltY(instance);
    }

    pub fn get_twist(instance: *runtime.Instance) anyerror!i32 {
        return try PointerEventImpl.get_twist(instance);
    }

    pub fn get_altitudeAngle(instance: *runtime.Instance) anyerror!f64 {
        return try PointerEventImpl.get_altitudeAngle(instance);
    }

    pub fn get_azimuthAngle(instance: *runtime.Instance) anyerror!f64 {
        return try PointerEventImpl.get_azimuthAngle(instance);
    }

    pub fn get_pointerType(instance: *runtime.Instance) anyerror!DOMString {
        return try PointerEventImpl.get_pointerType(instance);
    }

    pub fn get_isPrimary(instance: *runtime.Instance) anyerror!bool {
        return try PointerEventImpl.get_isPrimary(instance);
    }

    pub fn get_persistentDeviceId(instance: *runtime.Instance) anyerror!i32 {
        return try PointerEventImpl.get_persistentDeviceId(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_getCoalescedEvents(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PointerEventImpl.call_getCoalescedEvents(instance);
    }

    pub fn call_getPredictedEvents(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PointerEventImpl.call_getPredictedEvents(instance);
    }

};
