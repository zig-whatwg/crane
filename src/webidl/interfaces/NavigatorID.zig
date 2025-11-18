//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorIDImpl = @import("impls").NavigatorID;

pub const NavigatorID = struct {
    pub const Meta = struct {
        pub const name = "NavigatorID";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            appCodeName: runtime.DOMString = undefined,
            appName: runtime.DOMString = undefined,
            appVersion: runtime.DOMString = undefined,
            platform: runtime.DOMString = undefined,
            product: runtime.DOMString = undefined,
            productSub: runtime.DOMString = undefined,
            userAgent: runtime.DOMString = undefined,
            vendor: runtime.DOMString = undefined,
            vendorSub: runtime.DOMString = undefined,
            oscpu: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NavigatorID, .{
        .deinit_fn = &deinit_wrapper,

        .get_appCodeName = &get_appCodeName,
        .get_appName = &get_appName,
        .get_appVersion = &get_appVersion,
        .get_oscpu = &get_oscpu,
        .get_platform = &get_platform,
        .get_product = &get_product,
        .get_productSub = &get_productSub,
        .get_userAgent = &get_userAgent,
        .get_vendor = &get_vendor,
        .get_vendorSub = &get_vendorSub,

        .call_taintEnabled = &call_taintEnabled,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        NavigatorIDImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorIDImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_appCodeName(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorIDImpl.get_appCodeName(instance);
    }

    pub fn get_appName(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorIDImpl.get_appName(instance);
    }

    pub fn get_appVersion(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorIDImpl.get_appVersion(instance);
    }

    pub fn get_platform(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorIDImpl.get_platform(instance);
    }

    pub fn get_product(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorIDImpl.get_product(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_productSub(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorIDImpl.get_productSub(instance);
    }

    pub fn get_userAgent(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorIDImpl.get_userAgent(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_vendor(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorIDImpl.get_vendor(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_vendorSub(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorIDImpl.get_vendorSub(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_oscpu(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorIDImpl.get_oscpu(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_taintEnabled(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorIDImpl.call_taintEnabled(instance);
    }

};
