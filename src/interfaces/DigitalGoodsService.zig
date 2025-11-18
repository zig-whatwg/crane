//! Generated from: digital-goods.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DigitalGoodsServiceImpl = @import("../impls/DigitalGoodsService.zig");

pub const DigitalGoodsService = struct {
    pub const Meta = struct {
        pub const name = "DigitalGoodsService";
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

    pub const vtable = runtime.buildVTable(DigitalGoodsService, .{
        .deinit_fn = &deinit_wrapper,

        .call_consume = &call_consume,
        .call_getDetails = &call_getDetails,
        .call_listPurchaseHistory = &call_listPurchaseHistory,
        .call_listPurchases = &call_listPurchases,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        DigitalGoodsServiceImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        DigitalGoodsServiceImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_consume(instance: *runtime.Instance, purchaseToken: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return DigitalGoodsServiceImpl.call_consume(state, purchaseToken);
    }

    pub fn call_listPurchases(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DigitalGoodsServiceImpl.call_listPurchases(state);
    }

    pub fn call_listPurchaseHistory(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DigitalGoodsServiceImpl.call_listPurchaseHistory(state);
    }

    pub fn call_getDetails(instance: *runtime.Instance, itemIds: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return DigitalGoodsServiceImpl.call_getDetails(state, itemIds);
    }

};
