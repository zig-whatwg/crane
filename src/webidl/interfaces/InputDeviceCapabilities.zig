//! Generated from: input-device-capabilities.idl
//! Generated at: 2025-11-24T18:47:08Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const InputDeviceCapabilitiesImpl = @import("impls").InputDeviceCapabilities;
const InputDeviceCapabilitiesInit = @import("dictionaries").InputDeviceCapabilitiesInit;

pub const InputDeviceCapabilities = struct {
    pub const Meta = struct {
        pub const name = "InputDeviceCapabilities";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "firesTouchEvents", "get_firesTouchEvents", null },
            .{ "pointerMovementScrolls", "get_pointerMovementScrolls", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "firesTouchEvents", "get_firesTouchEvents", null },
            .{ "pointerMovementScrolls", "get_pointerMovementScrolls", null },
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
            firesTouchEvents: bool = undefined,
            pointerMovementScrolls: bool = undefined,
            _internal: ?*InputDeviceCapabilitiesImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_firesTouchEvents = &get_firesTouchEvents,
        .get_pointerMovementScrolls = &get_pointerMovementScrolls,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return InputDeviceCapabilitiesImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        InputDeviceCapabilitiesImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, deviceInitDict: InputDeviceCapabilitiesInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try InputDeviceCapabilitiesImpl.call_constructor(allocator, ctx, deviceInitDict);
    }

    pub fn get_firesTouchEvents(instance: *runtime.Instance) anyerror!bool {
        return try InputDeviceCapabilitiesImpl.get_firesTouchEvents(instance);
    }

    pub fn get_pointerMovementScrolls(instance: *runtime.Instance) anyerror!bool {
        return try InputDeviceCapabilitiesImpl.get_pointerMovementScrolls(instance);
    }

};
