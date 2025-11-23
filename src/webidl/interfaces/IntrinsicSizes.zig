//! Generated from: css-layout-api.idl
//! Generated at: 2025-11-23T01:22:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IntrinsicSizesImpl = @import("impls").IntrinsicSizes;

pub const IntrinsicSizes = struct {
    pub const Meta = struct {
        pub const name = "IntrinsicSizes";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "LayoutWorklet" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .LayoutWorklet = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "minContentSize", "get_minContentSize", null },
            .{ "maxContentSize", "get_maxContentSize", null },
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
            .{ "minContentSize", "get_minContentSize", null },
            .{ "maxContentSize", "get_maxContentSize", null },
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
            minContentSize: f64 = undefined,
            maxContentSize: f64 = undefined,
        },
    );

    const delegates = .{

        .get_maxContentSize = &get_maxContentSize,
        .get_minContentSize = &get_minContentSize,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return IntrinsicSizesImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IntrinsicSizesImpl.deinit(instance);
    }

    pub fn get_minContentSize(instance: *runtime.Instance) anyerror!f64 {
        return try IntrinsicSizesImpl.get_minContentSize(instance);
    }

    pub fn get_maxContentSize(instance: *runtime.Instance) anyerror!f64 {
        return try IntrinsicSizesImpl.get_maxContentSize(instance);
    }

};
