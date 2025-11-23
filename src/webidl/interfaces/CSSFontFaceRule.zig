//! Generated from: css-fonts-5.idl
//! Generated at: 2025-11-23T01:18:35Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSFontFaceRuleImpl = @import("impls").CSSFontFaceRule;
const CSSRule = @import("interfaces").CSSRule;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("interfaces").CSSOMString;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const CSSFontFaceDescriptors = @import("interfaces").CSSFontFaceDescriptors;
const DOMString = @import("typedefs").DOMString;

pub const CSSFontFaceRule = struct {
    pub const Meta = struct {
        pub const name = "CSSFontFaceRule";
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
            .{ "style", "get_style", null },
            .{ "style", "get_style", null },
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
            .{ "style", "get_style", null },
            .{ "style", "get_style", null },
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
            style: CSSFontFaceDescriptors = undefined,
            cached_style: ?CSSFontFaceDescriptors = null,
        },
    );

    const delegates = .{

        .get_style = &get_style,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSFontFaceRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSFontFaceRuleImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject], [PutForwards=cssText]
    pub fn get_style(instance: *runtime.Instance) anyerror!CSSFontFaceDescriptors {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_style) |cached| {
            return cached;
        }
        const value = try CSSFontFaceRuleImpl.get_style(instance);
        state.own.cached_style = value;
        return value;
    }

};
