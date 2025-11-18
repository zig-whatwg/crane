//! Generated from: payment-handler.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PaymentManagerImpl = @import("impls").PaymentManager;
const Promise<undefined> = @import("interfaces").Promise<undefined>;

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
        
        // Initialize the instance (Impl receives full instance)
        PaymentManagerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PaymentManagerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_userHint(instance: *runtime.Instance) anyerror!DOMString {
        return try PaymentManagerImpl.get_userHint(instance);
    }

    pub fn set_userHint(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try PaymentManagerImpl.set_userHint(instance, value);
    }

    pub fn call_enableDelegations(instance: *runtime.Instance, delegations: anyopaque) anyerror!anyopaque {
        
        return try PaymentManagerImpl.call_enableDelegations(instance, delegations);
    }

};
