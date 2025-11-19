//! Generated from: digital-goods.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DigitalGoodsServiceImpl = @import("impls").DigitalGoodsService;
const DOMString = @import("typedefs").DOMString;

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
        return DigitalGoodsServiceImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DigitalGoodsServiceImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_consume(instance: *runtime.Instance, purchaseToken: DOMString) anyerror!anyopaque {
        
        return try DigitalGoodsServiceImpl.call_consume(instance, purchaseToken);
    }

    pub fn call_listPurchases(instance: *runtime.Instance) anyerror!anyopaque {
        return try DigitalGoodsServiceImpl.call_listPurchases(instance);
    }

    pub fn call_listPurchaseHistory(instance: *runtime.Instance) anyerror!anyopaque {
        return try DigitalGoodsServiceImpl.call_listPurchaseHistory(instance);
    }

    pub fn call_getDetails(instance: *runtime.Instance, itemIds: anyopaque) anyerror!anyopaque {
        
        return try DigitalGoodsServiceImpl.call_getDetails(instance, itemIds);
    }

};
