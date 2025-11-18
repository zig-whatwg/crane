//! Generated from: input-device-capabilities.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const InputDeviceCapabilitiesImpl = @import("impls").InputDeviceCapabilities;
const InputDeviceCapabilitiesInit = @import("dictionaries").InputDeviceCapabilitiesInit;

pub const InputDeviceCapabilities = struct {
    pub const Meta = struct {
        pub const name = "InputDeviceCapabilities";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            firesTouchEvents: bool = undefined,
            pointerMovementScrolls: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(InputDeviceCapabilities, .{
        .deinit_fn = &deinit_wrapper,

        .get_firesTouchEvents = &get_firesTouchEvents,
        .get_pointerMovementScrolls = &get_pointerMovementScrolls,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        InputDeviceCapabilitiesImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        InputDeviceCapabilitiesImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, deviceInitDict: InputDeviceCapabilitiesInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try InputDeviceCapabilitiesImpl.constructor(instance, deviceInitDict);
        
        return instance;
    }

    pub fn get_firesTouchEvents(instance: *runtime.Instance) anyerror!bool {
        return try InputDeviceCapabilitiesImpl.get_firesTouchEvents(instance);
    }

    pub fn get_pointerMovementScrolls(instance: *runtime.Instance) anyerror!bool {
        return try InputDeviceCapabilitiesImpl.get_pointerMovementScrolls(instance);
    }

};
