//! Generated from: geolocation.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GeolocationPositionImpl = @import("impls").GeolocationPosition;
const EpochTimeStamp = @import("typedefs").EpochTimeStamp;
const GeolocationCoordinates = @import("interfaces").GeolocationCoordinates;

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
        
        // Initialize the instance (Impl receives full instance)
        GeolocationPositionImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GeolocationPositionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_coords(instance: *runtime.Instance) anyerror!GeolocationCoordinates {
        return try GeolocationPositionImpl.get_coords(instance);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyerror!EpochTimeStamp {
        return try GeolocationPositionImpl.get_timestamp(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!anyopaque {
        return try GeolocationPositionImpl.call_toJSON(instance);
    }

};
