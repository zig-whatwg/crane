//! Generated from: html.idl
//! Generated at: 2025-11-25T20:02:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorIDImpl = @import("impls").NavigatorID;
const DOMString = @import("typedefs").DOMString;

pub const NavigatorID = struct {
    pub const Meta = struct {
        pub const name = "NavigatorID";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "appCodeName", "get_appCodeName", null },
            .{ "appName", "get_appName", null },
            .{ "appVersion", "get_appVersion", null },
            .{ "platform", "get_platform", null },
            .{ "product", "get_product", null },
            .{ "productSub", "get_productSub", null },
            .{ "userAgent", "get_userAgent", null },
            .{ "vendor", "get_vendor", null },
            .{ "vendorSub", "get_vendorSub", null },
            .{ "oscpu", "get_oscpu", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "taintEnabled", "call_taintEnabled", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "taintEnabled",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "appCodeName", "get_appCodeName", null },
            .{ "appName", "get_appName", null },
            .{ "appVersion", "get_appVersion", null },
            .{ "platform", "get_platform", null },
            .{ "product", "get_product", null },
            .{ "productSub", "get_productSub", null },
            .{ "userAgent", "get_userAgent", null },
            .{ "vendor", "get_vendor", null },
            .{ "vendorSub", "get_vendorSub", null },
            .{ "oscpu", "get_oscpu", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
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
            _internal: ?*NavigatorIDImpl.InternalState = null,
        },
    );

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NavigatorIDImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorIDImpl.deinit(instance);
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
