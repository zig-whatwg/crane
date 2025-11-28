//! Generated from: trusted-types.idl
//! Generated at: 2025-11-28T22:33:21Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TrustedTypePolicyFactoryImpl = @import("impls").TrustedTypePolicyFactory;
const mixins = @import("mixins");
const TrustedTypePolicyOptions = @import("dictionaries").TrustedTypePolicyOptions;
const TrustedHTML = @import("interfaces").TrustedHTML;
const TrustedScript = @import("interfaces").TrustedScript;
const TrustedTypePolicy = @import("interfaces").TrustedTypePolicy;
const DOMString = @import("typedefs").DOMString;

pub const TrustedTypePolicyFactory = struct {
    pub const Meta = struct {
        pub const name = "TrustedTypePolicyFactory";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "emptyHTML", "get_emptyHTML", null },
            .{ "emptyScript", "get_emptyScript", null },
            .{ "defaultPolicy", "get_defaultPolicy", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "createPolicy", "call_createPolicy", 1 },
            .{ "isHTML", "call_isHTML", 1 },
            .{ "isScript", "call_isScript", 1 },
            .{ "isScriptURL", "call_isScriptURL", 1 },
            .{ "getAttributeType", "call_getAttributeType", 2 },
            .{ "getPropertyType", "call_getPropertyType", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createPolicy",
            "isHTML",
            "isScript",
            "isScriptURL",
            "getAttributeType",
            "getPropertyType",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "emptyHTML", "get_emptyHTML", null },
            .{ "emptyScript", "get_emptyScript", null },
            .{ "defaultPolicy", "get_defaultPolicy", null },
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
            emptyHTML: *runtime.Instance = undefined,
            emptyScript: *runtime.Instance = undefined,
            defaultPolicy: ?*runtime.Instance = null,
            _internal: ?*TrustedTypePolicyFactoryImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_defaultPolicy = &get_defaultPolicy,
        .get_emptyHTML = &get_emptyHTML,
        .get_emptyScript = &get_emptyScript,

        .call_createPolicy = &call_createPolicy,
        .call_getAttributeType = &call_getAttributeType,
        .call_getPropertyType = &call_getPropertyType,
        .call_isHTML = &call_isHTML,
        .call_isScript = &call_isScript,
        .call_isScriptURL = &call_isScriptURL,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TrustedTypePolicyFactoryImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TrustedTypePolicyFactoryImpl.deinit(instance);
    }

    pub fn get_emptyHTML(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try TrustedTypePolicyFactoryImpl.get_emptyHTML(instance);
    }

    pub fn get_emptyScript(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try TrustedTypePolicyFactoryImpl.get_emptyScript(instance);
    }

    pub fn get_defaultPolicy(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try TrustedTypePolicyFactoryImpl.get_defaultPolicy(instance);
    }

    pub fn call_createPolicy(instance: *runtime.Instance, policyName: DOMString, policyOptions: webidl.Opt(TrustedTypePolicyOptions)) anyerror!*runtime.Instance {
        
        return try TrustedTypePolicyFactoryImpl.call_createPolicy(instance, policyName, policyOptions);
    }

    pub fn call_isScript(instance: *runtime.Instance, value: *const anyopaque) anyerror!bool {
        
        return try TrustedTypePolicyFactoryImpl.call_isScript(instance, value);
    }

    pub fn call_isScriptURL(instance: *runtime.Instance, value: *const anyopaque) anyerror!bool {
        
        return try TrustedTypePolicyFactoryImpl.call_isScriptURL(instance, value);
    }

    pub fn call_getPropertyType(instance: *runtime.Instance, tagName: DOMString, property: DOMString, elementNs: webidl.Opt(?DOMString)) anyerror!?DOMString {
        
        return try TrustedTypePolicyFactoryImpl.call_getPropertyType(instance, tagName, property, elementNs);
    }

    pub fn call_isHTML(instance: *runtime.Instance, value: *const anyopaque) anyerror!bool {
        
        return try TrustedTypePolicyFactoryImpl.call_isHTML(instance, value);
    }

    pub fn call_getAttributeType(instance: *runtime.Instance, tagName: DOMString, attribute: DOMString, elementNs: webidl.Opt(?DOMString), attrNs: webidl.Opt(?DOMString)) anyerror!?DOMString {
        
        return try TrustedTypePolicyFactoryImpl.call_getAttributeType(instance, tagName, attribute, elementNs, attrNs);
    }

};
