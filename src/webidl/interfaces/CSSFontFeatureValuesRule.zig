//! Generated from: css-fonts.idl
//! Generated at: 2025-11-23T19:17:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSFontFeatureValuesRuleImpl = @import("impls").CSSFontFeatureValuesRule;
const CSSRule = @import("interfaces").CSSRule;
const CSSFontFeatureValuesMap = @import("interfaces").CSSFontFeatureValuesMap;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const DOMString = @import("typedefs").DOMString;

pub const CSSFontFeatureValuesRule = struct {
    pub const Meta = struct {
        pub const name = "CSSFontFeatureValuesRule";
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
            .{ "fontFamily", "get_fontFamily", "set_fontFamily" },
            .{ "annotation", "get_annotation", null },
            .{ "ornaments", "get_ornaments", null },
            .{ "stylistic", "get_stylistic", null },
            .{ "swash", "get_swash", null },
            .{ "characterVariant", "get_characterVariant", null },
            .{ "styleset", "get_styleset", null },
            .{ "historicalForms", "get_historicalForms", null },
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
            .{ "fontFamily", "get_fontFamily", "set_fontFamily" },
            .{ "annotation", "get_annotation", null },
            .{ "ornaments", "get_ornaments", null },
            .{ "stylistic", "get_stylistic", null },
            .{ "swash", "get_swash", null },
            .{ "characterVariant", "get_characterVariant", null },
            .{ "styleset", "get_styleset", null },
            .{ "historicalForms", "get_historicalForms", null },
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
            fontFamily: CSSOMString = undefined,
            annotation: CSSFontFeatureValuesMap = undefined,
            ornaments: CSSFontFeatureValuesMap = undefined,
            stylistic: CSSFontFeatureValuesMap = undefined,
            swash: CSSFontFeatureValuesMap = undefined,
            characterVariant: CSSFontFeatureValuesMap = undefined,
            styleset: CSSFontFeatureValuesMap = undefined,
            historicalForms: CSSFontFeatureValuesMap = undefined,
            _internal: ?*CSSFontFeatureValuesRuleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_annotation = &get_annotation,
        .get_characterVariant = &get_characterVariant,
        .get_fontFamily = &get_fontFamily,
        .get_historicalForms = &get_historicalForms,
        .get_ornaments = &get_ornaments,
        .get_styleset = &get_styleset,
        .get_stylistic = &get_stylistic,
        .get_swash = &get_swash,

        .set_fontFamily = &set_fontFamily,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSFontFeatureValuesRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSFontFeatureValuesRuleImpl.deinit(instance);
    }

    pub fn get_fontFamily(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFeatureValuesRuleImpl.get_fontFamily(instance);
    }

    pub fn set_fontFamily(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFeatureValuesRuleImpl.set_fontFamily(instance, value);
    }

    pub fn get_annotation(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSFontFeatureValuesRuleImpl.get_annotation(instance);
    }

    pub fn get_ornaments(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSFontFeatureValuesRuleImpl.get_ornaments(instance);
    }

    pub fn get_stylistic(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSFontFeatureValuesRuleImpl.get_stylistic(instance);
    }

    pub fn get_swash(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSFontFeatureValuesRuleImpl.get_swash(instance);
    }

    pub fn get_characterVariant(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSFontFeatureValuesRuleImpl.get_characterVariant(instance);
    }

    pub fn get_styleset(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSFontFeatureValuesRuleImpl.get_styleset(instance);
    }

    pub fn get_historicalForms(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSFontFeatureValuesRuleImpl.get_historicalForms(instance);
    }

};
