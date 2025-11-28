//! Generated from: css-fonts.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSFontPaletteValuesRuleImpl = @import("impls").CSSFontPaletteValuesRule;
const mixins = @import("mixins");
const CSSRule = @import("interfaces").CSSRule;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const DOMString = @import("typedefs").DOMString;

pub const CSSFontPaletteValuesRule = struct {
    pub const Meta = struct {
        pub const name = "CSSFontPaletteValuesRule";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "fontFamily", "get_fontFamily", null },
            .{ "basePalette", "get_basePalette", null },
            .{ "overrideColors", "get_overrideColors", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            .{ "fontFamily", "get_fontFamily", null },
            .{ "basePalette", "get_basePalette", null },
            .{ "overrideColors", "get_overrideColors", null },
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
            fontFamily: CSSOMString = undefined,
            basePalette: CSSOMString = undefined,
            overrideColors: CSSOMString = undefined,
            _internal: ?*CSSFontPaletteValuesRuleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_basePalette = &get_basePalette,
        .get_fontFamily = &get_fontFamily,
        .get_name = &get_name,
        .get_overrideColors = &get_overrideColors,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSFontPaletteValuesRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSFontPaletteValuesRuleImpl.deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontPaletteValuesRuleImpl.get_name(instance);
    }

    pub fn get_fontFamily(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontPaletteValuesRuleImpl.get_fontFamily(instance);
    }

    pub fn get_basePalette(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontPaletteValuesRuleImpl.get_basePalette(instance);
    }

    pub fn get_overrideColors(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontPaletteValuesRuleImpl.get_overrideColors(instance);
    }

};
