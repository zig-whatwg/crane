//! Generated from: credential-management.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CredentialsContainerImpl = @import("../impls/CredentialsContainer.zig");

pub const CredentialsContainer = struct {
    pub const Meta = struct {
        pub const name = "CredentialsContainer";
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

    pub const vtable = runtime.buildVTable(CredentialsContainer, .{
        .deinit_fn = &deinit_wrapper,

        .call_create = &call_create,
        .call_get = &call_get,
        .call_preventSilentAccess = &call_preventSilentAccess,
        .call_store = &call_store,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CredentialsContainerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CredentialsContainerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_store(instance: *runtime.Instance, credential: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CredentialsContainerImpl.call_store(state, credential);
    }

    pub fn call_get(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CredentialsContainerImpl.call_get(state, options);
    }

    pub fn call_preventSilentAccess(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CredentialsContainerImpl.call_preventSilentAccess(state);
    }

    pub fn call_create(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CredentialsContainerImpl.call_create(state, options);
    }

};
