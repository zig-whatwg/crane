//! Generated from: encrypted-media.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaKeyStatusMapImpl = @import("impls").MediaKeyStatusMap;
const (MediaKeyStatus or undefined) = @import("interfaces").(MediaKeyStatus or undefined);
const MediaKeyStatus = @import("enums").MediaKeyStatus;
const BufferSource = @import("typedefs").BufferSource;

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
        
        // Initialize the instance (Impl receives full instance)
        MediaKeyStatusMapImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaKeyStatusMapImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
        return try MediaKeyStatusMapImpl.get_size(instance);
    }

    pub fn call_has(instance: *runtime.Instance, keyId: BufferSource) anyerror!bool {
        
        return try MediaKeyStatusMapImpl.call_has(instance, keyId);
    }

    pub fn call_get(instance: *runtime.Instance, keyId: BufferSource) anyerror!anyopaque {
        
        return try MediaKeyStatusMapImpl.call_get(instance, keyId);
    }

};
