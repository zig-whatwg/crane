//! Generated from: geolocation.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GeolocationImpl = @import("../impls/Geolocation.zig");

pub const Geolocation = struct {
    pub const Meta = struct {
        pub const name = "Geolocation";
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
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Geolocation, .{
        .deinit_fn = &deinit_wrapper,

        .call_clearWatch = &call_clearWatch,
        .call_getCurrentPosition = &call_getCurrentPosition,
        .call_watchPosition = &call_watchPosition,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        GeolocationImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GeolocationImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_getCurrentPosition(instance: *runtime.Instance, successCallback: anyopaque, errorCallback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GeolocationImpl.call_getCurrentPosition(state, successCallback, errorCallback, options);
    }

    pub fn call_clearWatch(instance: *runtime.Instance, watchId: i32) anyopaque {
        const state = instance.getState(State);
        
        return GeolocationImpl.call_clearWatch(state, watchId);
    }

    pub fn call_watchPosition(instance: *runtime.Instance, successCallback: anyopaque, errorCallback: anyopaque, options: anyopaque) i32 {
        const state = instance.getState(State);
        
        return GeolocationImpl.call_watchPosition(state, successCallback, errorCallback, options);
    }

};
