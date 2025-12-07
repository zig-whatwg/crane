//! Generated from: css-counter-styles.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSCounterStyleRuleImpl = @import("impls").CSSCounterStyleRule;
const mixins = @import("mixins");
const CSSRule = @import("interfaces").CSSRule;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const DOMString = @import("typedefs").DOMString;

pub const CSSCounterStyleRule = struct {
    pub const Meta = struct {
        pub const name = "CSSCounterStyleRule";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSRule.State;
        pub const ParentInterface = CSSRule;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", "set_name" },
            .{ "system", "get_system", "set_system" },
            .{ "symbols", "get_symbols", "set_symbols" },
            .{ "additiveSymbols", "get_additiveSymbols", "set_additiveSymbols" },
            .{ "negative", "get_negative", "set_negative" },
            .{ "prefix", "get_prefix", "set_prefix" },
            .{ "suffix", "get_suffix", "set_suffix" },
            .{ "range", "get_range", "set_range" },
            .{ "pad", "get_pad", "set_pad" },
            .{ "speakAs", "get_speakAs", "set_speakAs" },
            .{ "fallback", "get_fallback", "set_fallback" },
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
            .{ "name", "get_name", "set_name" },
            .{ "system", "get_system", "set_system" },
            .{ "symbols", "get_symbols", "set_symbols" },
            .{ "additiveSymbols", "get_additiveSymbols", "set_additiveSymbols" },
            .{ "negative", "get_negative", "set_negative" },
            .{ "suffix", "get_suffix", "set_suffix" },
            .{ "range", "get_range", "set_range" },
            .{ "pad", "get_pad", "set_pad" },
            .{ "speakAs", "get_speakAs", "set_speakAs" },
            .{ "fallback", "get_fallback", "set_fallback" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
            .{ "prefix", "get_prefix", "set_prefix" },
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            name: CSSOMString = undefined,
            system: CSSOMString = undefined,
            symbols: CSSOMString = undefined,
            additiveSymbols: CSSOMString = undefined,
            negative: CSSOMString = undefined,
            prefix: CSSOMString = undefined,
            suffix: CSSOMString = undefined,
            range: CSSOMString = undefined,
            pad: CSSOMString = undefined,
            speakAs: CSSOMString = undefined,
            fallback: CSSOMString = undefined,
            _internal: ?*CSSCounterStyleRuleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_additiveSymbols = &get_additiveSymbols,
        .get_fallback = &get_fallback,
        .get_name = &get_name,
        .get_negative = &get_negative,
        .get_pad = &get_pad,
        .get_prefix = &get_prefix,
        .get_range = &get_range,
        .get_speakAs = &get_speakAs,
        .get_suffix = &get_suffix,
        .get_symbols = &get_symbols,
        .get_system = &get_system,

        .set_additiveSymbols = &set_additiveSymbols,
        .set_fallback = &set_fallback,
        .set_name = &set_name,
        .set_negative = &set_negative,
        .set_pad = &set_pad,
        .set_prefix = &set_prefix,
        .set_range = &set_range,
        .set_speakAs = &set_speakAs,
        .set_suffix = &set_suffix,
        .set_symbols = &set_symbols,
        .set_system = &set_system,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSCounterStyleRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSCounterStyleRuleImpl.deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSCounterStyleRuleImpl.get_name(instance);
    }

    pub fn set_name(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSCounterStyleRuleImpl.set_name(instance, value);
    }

    pub fn get_system(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSCounterStyleRuleImpl.get_system(instance);
    }

    pub fn set_system(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSCounterStyleRuleImpl.set_system(instance, value);
    }

    pub fn get_symbols(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSCounterStyleRuleImpl.get_symbols(instance);
    }

    pub fn set_symbols(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSCounterStyleRuleImpl.set_symbols(instance, value);
    }

    pub fn get_additiveSymbols(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSCounterStyleRuleImpl.get_additiveSymbols(instance);
    }

    pub fn set_additiveSymbols(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSCounterStyleRuleImpl.set_additiveSymbols(instance, value);
    }

    pub fn get_negative(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSCounterStyleRuleImpl.get_negative(instance);
    }

    pub fn set_negative(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSCounterStyleRuleImpl.set_negative(instance, value);
    }

    pub fn get_prefix(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSCounterStyleRuleImpl.get_prefix(instance);
    }

    pub fn set_prefix(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSCounterStyleRuleImpl.set_prefix(instance, value);
    }

    pub fn get_suffix(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSCounterStyleRuleImpl.get_suffix(instance);
    }

    pub fn set_suffix(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSCounterStyleRuleImpl.set_suffix(instance, value);
    }

    pub fn get_range(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSCounterStyleRuleImpl.get_range(instance);
    }

    pub fn set_range(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSCounterStyleRuleImpl.set_range(instance, value);
    }

    pub fn get_pad(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSCounterStyleRuleImpl.get_pad(instance);
    }

    pub fn set_pad(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSCounterStyleRuleImpl.set_pad(instance, value);
    }

    pub fn get_speakAs(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSCounterStyleRuleImpl.get_speakAs(instance);
    }

    pub fn set_speakAs(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSCounterStyleRuleImpl.set_speakAs(instance, value);
    }

    pub fn get_fallback(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSCounterStyleRuleImpl.get_fallback(instance);
    }

    pub fn set_fallback(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSCounterStyleRuleImpl.set_fallback(instance, value);
    }

};
