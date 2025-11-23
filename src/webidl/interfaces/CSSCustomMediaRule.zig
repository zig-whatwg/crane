//! Generated from: mediaqueries-5.idl
//! Generated at: 2025-11-23T01:22:15Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSCustomMediaRuleImpl = @import("impls").CSSCustomMediaRule;
const CSSRule = @import("interfaces").CSSRule;
const CustomMediaQuery = @import("typedefs").CustomMediaQuery;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("interfaces").CSSOMString;
const DOMString = @import("typedefs").DOMString;

pub const CSSCustomMediaRule = struct {
    pub const Meta = struct {
        pub const name = "CSSCustomMediaRule";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSRule;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "query", "get_query", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "name", "get_name", null },
            .{ "query", "get_query", null },
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
            query: CustomMediaQuery = undefined,
        },
    );

    const delegates = .{

        .get_name = &get_name,
        .get_query = &get_query,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSCustomMediaRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSCustomMediaRuleImpl.deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try CSSCustomMediaRuleImpl.get_name(instance);
    }

    pub fn get_query(instance: *runtime.Instance) anyerror!CustomMediaQuery {
        return try CSSCustomMediaRuleImpl.get_query(instance);
    }

};
