//! Generated from: webrtc-identity.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCIdentityProviderRegistrarImpl = @import("../impls/RTCIdentityProviderRegistrar.zig");

pub const RTCIdentityProviderRegistrar = struct {
    pub const Meta = struct {
        pub const name = "RTCIdentityProviderRegistrar";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "RTCIdentityProvider" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .RTCIdentityProvider = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RTCIdentityProviderRegistrar, .{
        .deinit_fn = &deinit_wrapper,

        .call_register = &call_register,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        RTCIdentityProviderRegistrarImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RTCIdentityProviderRegistrarImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_register(instance: *runtime.Instance, idp: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCIdentityProviderRegistrarImpl.call_register(state, idp);
    }

};
