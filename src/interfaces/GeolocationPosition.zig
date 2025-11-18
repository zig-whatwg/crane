//! Generated from: geolocation.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GeolocationPositionImpl = @import("../impls/GeolocationPosition.zig");

pub const GeolocationPosition = struct {
    pub const Meta = struct {
        pub const name = "GeolocationPosition";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            coords: GeolocationCoordinates = undefined,
            timestamp: EpochTimeStamp = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GeolocationPosition, .{
        .deinit_fn = &deinit_wrapper,

        .get_coords = &get_coords,
        .get_timestamp = &get_timestamp,

        .call_toJSON = &call_toJSON,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        GeolocationPositionImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GeolocationPositionImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_coords(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GeolocationPositionImpl.get_coords(state);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GeolocationPositionImpl.get_timestamp(state);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GeolocationPositionImpl.call_toJSON(state);
    }

};
