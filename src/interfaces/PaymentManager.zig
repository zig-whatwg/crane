//! Generated from: payment-handler.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PaymentManagerImpl = @import("../impls/PaymentManager.zig");

pub const PaymentManager = struct {
    pub const Meta = struct {
        pub const name = "PaymentManager";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            userHint: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PaymentManager, .{
        .deinit_fn = &deinit_wrapper,

        .get_userHint = &get_userHint,

        .set_userHint = &set_userHint,

        .call_enableDelegations = &call_enableDelegations,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        PaymentManagerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PaymentManagerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_userHint(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PaymentManagerImpl.get_userHint(state);
    }

    pub fn set_userHint(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        PaymentManagerImpl.set_userHint(state, value);
    }

    pub fn call_enableDelegations(instance: *runtime.Instance, delegations: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PaymentManagerImpl.call_enableDelegations(state, delegations);
    }

};
