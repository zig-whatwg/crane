//! Generated from: digital-goods.idl
//! Generated at: 2025-11-23T20:06:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DigitalGoodsServiceImpl = @import("impls").DigitalGoodsService;
const DOMString = @import("typedefs").DOMString;

pub const DigitalGoodsService = struct {
    pub const Meta = struct {
        pub const name = "DigitalGoodsService";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "getDetails", "call_getDetails", 1 },
            .{ "listPurchases", "call_listPurchases", 0 },
            .{ "listPurchaseHistory", "call_listPurchaseHistory", 0 },
            .{ "consume", "call_consume", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getDetails",
            "listPurchases",
            "listPurchaseHistory",
            "consume",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

        .call_consume = &call_consume,
        .call_getDetails = &call_getDetails,
        .call_listPurchaseHistory = &call_listPurchaseHistory,
        .call_listPurchases = &call_listPurchases,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DigitalGoodsServiceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DigitalGoodsServiceImpl.deinit(instance);
    }

    pub fn call_consume(instance: *runtime.Instance, purchaseToken: DOMString) anyerror!*const anyopaque {
        
        return try DigitalGoodsServiceImpl.call_consume(instance, purchaseToken);
    }

    pub fn call_listPurchases(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try DigitalGoodsServiceImpl.call_listPurchases(instance);
    }

    pub fn call_listPurchaseHistory(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try DigitalGoodsServiceImpl.call_listPurchaseHistory(instance);
    }

    pub fn call_getDetails(instance: *runtime.Instance, itemIds: *const anyopaque) anyerror!*const anyopaque {
        
        return try DigitalGoodsServiceImpl.call_getDetails(instance, itemIds);
    }

};
