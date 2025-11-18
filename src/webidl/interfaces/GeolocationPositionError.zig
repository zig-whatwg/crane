//! Generated from: geolocation.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GeolocationPositionErrorImpl = @import("impls").GeolocationPositionError;

pub const GeolocationPositionError = struct {
    pub const Meta = struct {
        pub const name = "GeolocationPositionError";
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
            code: u16 = undefined,
            message: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short PERMISSION_DENIED = 1;
    pub fn get_PERMISSION_DENIED() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short POSITION_UNAVAILABLE = 2;
    pub fn get_POSITION_UNAVAILABLE() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short TIMEOUT = 3;
    pub fn get_TIMEOUT() u16 {
        return 3;
    }

    pub const vtable = runtime.buildVTable(GeolocationPositionError, .{
        .deinit_fn = &deinit_wrapper,

        .get_PERMISSION_DENIED = &get_PERMISSION_DENIED,
        .get_POSITION_UNAVAILABLE = &get_POSITION_UNAVAILABLE,
        .get_TIMEOUT = &get_TIMEOUT,
        .get_code = &get_code,
        .get_message = &get_message,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        GeolocationPositionErrorImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GeolocationPositionErrorImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_code(instance: *runtime.Instance) anyerror!u16 {
        return try GeolocationPositionErrorImpl.get_code(instance);
    }

    pub fn get_message(instance: *runtime.Instance) anyerror!DOMString {
        return try GeolocationPositionErrorImpl.get_message(instance);
    }

};
