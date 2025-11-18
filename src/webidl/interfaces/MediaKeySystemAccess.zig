//! Generated from: encrypted-media.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaKeySystemAccessImpl = @import("impls").MediaKeySystemAccess;
const MediaKeySystemConfiguration = @import("dictionaries").MediaKeySystemConfiguration;
const Promise<MediaKeys> = @import("interfaces").Promise<MediaKeys>;

pub const MediaKeySystemAccess = struct {
    pub const Meta = struct {
        pub const name = "MediaKeySystemAccess";
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
            keySystem: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MediaKeySystemAccess, .{
        .deinit_fn = &deinit_wrapper,

        .get_keySystem = &get_keySystem,

        .call_createMediaKeys = &call_createMediaKeys,
        .call_getConfiguration = &call_getConfiguration,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        MediaKeySystemAccessImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaKeySystemAccessImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_keySystem(instance: *runtime.Instance) anyerror!DOMString {
        return try MediaKeySystemAccessImpl.get_keySystem(instance);
    }

    pub fn call_getConfiguration(instance: *runtime.Instance) anyerror!MediaKeySystemConfiguration {
        return try MediaKeySystemAccessImpl.call_getConfiguration(instance);
    }

    pub fn call_createMediaKeys(instance: *runtime.Instance) anyerror!anyopaque {
        return try MediaKeySystemAccessImpl.call_createMediaKeys(instance);
    }

};
