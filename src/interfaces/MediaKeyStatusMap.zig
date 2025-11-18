//! Generated from: encrypted-media.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaKeyStatusMapImpl = @import("../impls/MediaKeyStatusMap.zig");

pub const MediaKeyStatusMap = struct {
    pub const Meta = struct {
        pub const name = "MediaKeyStatusMap";
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
            size: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MediaKeyStatusMap, .{
        .deinit_fn = &deinit_wrapper,

        .get_size = &get_size,

        .call_get = &call_get,
        .call_has = &call_has,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        MediaKeyStatusMapImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MediaKeyStatusMapImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_size(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return MediaKeyStatusMapImpl.get_size(state);
    }

    pub fn call_has(instance: *runtime.Instance, keyId: anyopaque) bool {
        const state = instance.getState(State);
        
        return MediaKeyStatusMapImpl.call_has(state, keyId);
    }

    pub fn call_get(instance: *runtime.Instance, keyId: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaKeyStatusMapImpl.call_get(state, keyId);
    }

};
