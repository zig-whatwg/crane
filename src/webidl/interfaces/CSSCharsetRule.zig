//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-23T19:17:31Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSCharsetRuleImpl = @import("impls").CSSCharsetRule;
const CSSRule = @import("interfaces").CSSRule;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const DOMString = @import("typedefs").DOMString;

pub const CSSCharsetRule = struct {
    pub const Meta = struct {
        pub const name = "CSSCharsetRule";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSRule;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "encoding", "get_encoding", "set_encoding" },
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
            .{ "encoding", "get_encoding", "set_encoding" },
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
            encoding: runtime.DOMString = undefined,
            _internal: ?*CSSCharsetRuleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_encoding = &get_encoding,

        .set_encoding = &set_encoding,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSCharsetRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSCharsetRuleImpl.deinit(instance);
    }

    pub fn get_encoding(instance: *runtime.Instance) anyerror!DOMString {
        return try CSSCharsetRuleImpl.get_encoding(instance);
    }

    pub fn set_encoding(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSSCharsetRuleImpl.set_encoding(instance, value);
    }

};
