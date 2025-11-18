//! Generated from: encrypted-media.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaKeysImpl = @import("../impls/MediaKeys.zig");

pub const MediaKeys = struct {
    pub const Meta = struct {
        pub const name = "MediaKeys";
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
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MediaKeys, .{
        .deinit_fn = &deinit_wrapper,

        .call_createSession = &call_createSession,
        .call_getStatusForPolicy = &call_getStatusForPolicy,
        .call_setServerCertificate = &call_setServerCertificate,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        MediaKeysImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MediaKeysImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_setServerCertificate(instance: *runtime.Instance, serverCertificate: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaKeysImpl.call_setServerCertificate(state, serverCertificate);
    }

    pub fn call_createSession(instance: *runtime.Instance, sessionType: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaKeysImpl.call_createSession(state, sessionType);
    }

    pub fn call_getStatusForPolicy(instance: *runtime.Instance, policy: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaKeysImpl.call_getStatusForPolicy(state, policy);
    }

};
