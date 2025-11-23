//! Generated from: css-layout-api.idl
//! Generated at: 2025-11-23T01:22:15Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LayoutConstraintsImpl = @import("impls").LayoutConstraints;
const BlockFragmentationType = @import("enums").BlockFragmentationType;

pub const LayoutConstraints = struct {
    pub const Meta = struct {
        pub const name = "LayoutConstraints";
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
            .{ "availableInlineSize", "get_availableInlineSize", null },
            .{ "availableBlockSize", "get_availableBlockSize", null },
            .{ "fixedInlineSize", "get_fixedInlineSize", null },
            .{ "fixedBlockSize", "get_fixedBlockSize", null },
            .{ "percentageInlineSize", "get_percentageInlineSize", null },
            .{ "percentageBlockSize", "get_percentageBlockSize", null },
            .{ "blockFragmentationOffset", "get_blockFragmentationOffset", null },
            .{ "blockFragmentationType", "get_blockFragmentationType", null },
            .{ "data", "get_data", null },
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
            .{ "availableInlineSize", "get_availableInlineSize", null },
            .{ "availableBlockSize", "get_availableBlockSize", null },
            .{ "fixedInlineSize", "get_fixedInlineSize", null },
            .{ "fixedBlockSize", "get_fixedBlockSize", null },
            .{ "percentageInlineSize", "get_percentageInlineSize", null },
            .{ "percentageBlockSize", "get_percentageBlockSize", null },
            .{ "blockFragmentationOffset", "get_blockFragmentationOffset", null },
            .{ "blockFragmentationType", "get_blockFragmentationType", null },
            .{ "data", "get_data", null },
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
            availableInlineSize: f64 = undefined,
            availableBlockSize: f64 = undefined,
            fixedInlineSize: ?f64 = null,
            fixedBlockSize: ?f64 = null,
            percentageInlineSize: f64 = undefined,
            percentageBlockSize: f64 = undefined,
            blockFragmentationOffset: ?f64 = null,
            blockFragmentationType: BlockFragmentationType = undefined,
            data: *const anyopaque = undefined,
        },
    );

    const delegates = .{

        .get_availableBlockSize = &get_availableBlockSize,
        .get_availableInlineSize = &get_availableInlineSize,
        .get_blockFragmentationOffset = &get_blockFragmentationOffset,
        .get_blockFragmentationType = &get_blockFragmentationType,
        .get_data = &get_data,
        .get_fixedBlockSize = &get_fixedBlockSize,
        .get_fixedInlineSize = &get_fixedInlineSize,
        .get_percentageBlockSize = &get_percentageBlockSize,
        .get_percentageInlineSize = &get_percentageInlineSize,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return LayoutConstraintsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LayoutConstraintsImpl.deinit(instance);
    }

    pub fn get_availableInlineSize(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutConstraintsImpl.get_availableInlineSize(instance);
    }

    pub fn get_availableBlockSize(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutConstraintsImpl.get_availableBlockSize(instance);
    }

    pub fn get_fixedInlineSize(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutConstraintsImpl.get_fixedInlineSize(instance);
    }

    pub fn get_fixedBlockSize(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutConstraintsImpl.get_fixedBlockSize(instance);
    }

    pub fn get_percentageInlineSize(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutConstraintsImpl.get_percentageInlineSize(instance);
    }

    pub fn get_percentageBlockSize(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutConstraintsImpl.get_percentageBlockSize(instance);
    }

    pub fn get_blockFragmentationOffset(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutConstraintsImpl.get_blockFragmentationOffset(instance);
    }

    pub fn get_blockFragmentationType(instance: *runtime.Instance) anyerror!BlockFragmentationType {
        return try LayoutConstraintsImpl.get_blockFragmentationType(instance);
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try LayoutConstraintsImpl.get_data(instance);
    }

};
