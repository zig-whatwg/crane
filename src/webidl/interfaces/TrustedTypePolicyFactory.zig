//! Generated from: trusted-types.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TrustedTypePolicyFactoryImpl = @import("impls").TrustedTypePolicyFactory;
const TrustedTypePolicyOptions = @import("dictionaries").TrustedTypePolicyOptions;
const TrustedHTML = @import("interfaces").TrustedHTML;
const TrustedScript = @import("interfaces").TrustedScript;
const TrustedTypePolicy = @import("interfaces").TrustedTypePolicy;
const DOMString = @import("typedefs").DOMString;

pub const TrustedTypePolicyFactory = struct {
    pub const Meta = struct {
        pub const name = "TrustedTypePolicyFactory";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            emptyHTML: TrustedHTML = undefined,
            emptyScript: TrustedScript = undefined,
            defaultPolicy: ?TrustedTypePolicy = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(TrustedTypePolicyFactory, .{
        .deinit_fn = &deinit_wrapper,

        .get_defaultPolicy = &get_defaultPolicy,
        .get_emptyHTML = &get_emptyHTML,
        .get_emptyScript = &get_emptyScript,

        .call_createPolicy = &call_createPolicy,
        .call_getAttributeType = &call_getAttributeType,
        .call_getPropertyType = &call_getPropertyType,
        .call_isHTML = &call_isHTML,
        .call_isScript = &call_isScript,
        .call_isScriptURL = &call_isScriptURL,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return TrustedTypePolicyFactoryImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TrustedTypePolicyFactoryImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_emptyHTML(instance: *runtime.Instance) anyerror!TrustedHTML {
        return try TrustedTypePolicyFactoryImpl.get_emptyHTML(instance);
    }

    pub fn get_emptyScript(instance: *runtime.Instance) anyerror!TrustedScript {
        return try TrustedTypePolicyFactoryImpl.get_emptyScript(instance);
    }

    pub fn get_defaultPolicy(instance: *runtime.Instance) anyerror!TrustedTypePolicy {
        return try TrustedTypePolicyFactoryImpl.get_defaultPolicy(instance);
    }

    pub fn call_createPolicy(instance: *runtime.Instance, policyName: DOMString, policyOptions: TrustedTypePolicyOptions) anyerror!TrustedTypePolicy {
        
        return try TrustedTypePolicyFactoryImpl.call_createPolicy(instance, policyName, policyOptions);
    }

    pub fn call_isScript(instance: *runtime.Instance, value: anyopaque) anyerror!bool {
        
        return try TrustedTypePolicyFactoryImpl.call_isScript(instance, value);
    }

    pub fn call_isScriptURL(instance: *runtime.Instance, value: anyopaque) anyerror!bool {
        
        return try TrustedTypePolicyFactoryImpl.call_isScriptURL(instance, value);
    }

    pub fn call_getPropertyType(instance: *runtime.Instance, tagName: DOMString, property: DOMString, elementNs: DOMString) anyerror!DOMString {
        
        return try TrustedTypePolicyFactoryImpl.call_getPropertyType(instance, tagName, property, elementNs);
    }

    pub fn call_isHTML(instance: *runtime.Instance, value: anyopaque) anyerror!bool {
        
        return try TrustedTypePolicyFactoryImpl.call_isHTML(instance, value);
    }

    pub fn call_getAttributeType(instance: *runtime.Instance, tagName: DOMString, attribute: DOMString, elementNs: DOMString, attrNs: DOMString) anyerror!DOMString {
        
        return try TrustedTypePolicyFactoryImpl.call_getAttributeType(instance, tagName, attribute, elementNs, attrNs);
    }

};
