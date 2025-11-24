//! Generated from: css-mixins.idl
//! Generated at: 2025-11-24T18:47:07Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSFunctionRuleImpl = @import("impls").CSSFunctionRule;
const CSSGroupingRule = @import("interfaces").CSSGroupingRule;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const FunctionParameter = @import("dictionaries").FunctionParameter;
const CSSRule = @import("interfaces").CSSRule;
const CSSRuleList = @import("interfaces").CSSRuleList;
const DOMString = @import("typedefs").DOMString;

pub const CSSFunctionRule = struct {
    pub const Meta = struct {
        pub const name = "CSSFunctionRule";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSGroupingRule;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "returnType", "get_returnType", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "getParameters", "call_getParameters", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getParameters",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "insertRule",
            "deleteRule",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "name", "get_name", null },
            .{ "returnType", "get_returnType", null },
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
            name: CSSOMString = undefined,
            returnType: CSSOMString = undefined,
            _internal: ?*CSSFunctionRuleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_name = &get_name,
        .get_returnType = &get_returnType,

        .call_getParameters = &call_getParameters,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSFunctionRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSFunctionRuleImpl.deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFunctionRuleImpl.get_name(instance);
    }

    pub fn get_returnType(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFunctionRuleImpl.get_returnType(instance);
    }

    pub fn call_getParameters(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try CSSFunctionRuleImpl.call_getParameters(instance);
    }

};
