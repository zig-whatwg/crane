//! Generated from: css-fonts.idl
//! Generated at: 2025-11-29T05:01:35Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSFontFeatureValuesMapImpl = @import("impls").CSSFontFeatureValuesMap;
const mixins = @import("mixins");
const sequence = @import("interfaces").sequence;
const CSSOMString = @import("typedefs").CSSOMString;

pub const CSSFontFeatureValuesMap = struct {
    pub const Meta = struct {
        pub const name = "CSSFontFeatureValuesMap";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "set", "call_set", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "set",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
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
            _internal: ?*CSSFontFeatureValuesMapImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    const delegates = .{

        .call_set = &call_set,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSFontFeatureValuesMapImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSFontFeatureValuesMapImpl.deinit(instance);
    }

    pub fn call_set(instance: *runtime.Instance, featureValueName: CSSOMString, values: *const anyopaque) anyerror!void {
        
        return try CSSFontFeatureValuesMapImpl.call_set(instance, featureValueName, values);
    }

};
