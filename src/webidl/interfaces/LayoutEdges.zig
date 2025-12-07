//! Generated from: css-layout-api.idl
//! Generated at: 2025-12-07T19:33:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const LayoutEdgesImpl = @import("impls").LayoutEdges;
const mixins = @import("mixins");

pub const LayoutEdges = struct {
    pub const Meta = struct {
        pub const name = "LayoutEdges";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "inlineStart", "get_inlineStart", null },
            .{ "inlineEnd", "get_inlineEnd", null },
            .{ "blockStart", "get_blockStart", null },
            .{ "blockEnd", "get_blockEnd", null },
            .{ "inline", "get_inline", null },
            .{ "block", "get_block", null },
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
            .{ "inlineStart", "get_inlineStart", null },
            .{ "inlineEnd", "get_inlineEnd", null },
            .{ "blockStart", "get_blockStart", null },
            .{ "blockEnd", "get_blockEnd", null },
            .{ "inline", "get_inline", null },
            .{ "block", "get_block", null },
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
            inlineStart: f64 = undefined,
            inlineEnd: f64 = undefined,
            blockStart: f64 = undefined,
            blockEnd: f64 = undefined,
            @"inline": f64 = undefined,
            block: f64 = undefined,
            _internal: ?*LayoutEdgesImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_block = &get_block,
        .get_blockEnd = &get_blockEnd,
        .get_blockStart = &get_blockStart,
        .get_inline = &get_inline,
        .get_inlineEnd = &get_inlineEnd,
        .get_inlineStart = &get_inlineStart,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return LayoutEdgesImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LayoutEdgesImpl.deinit(instance);
    }

    pub fn get_inlineStart(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutEdgesImpl.get_inlineStart(instance);
    }

    pub fn get_inlineEnd(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutEdgesImpl.get_inlineEnd(instance);
    }

    pub fn get_blockStart(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutEdgesImpl.get_blockStart(instance);
    }

    pub fn get_blockEnd(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutEdgesImpl.get_blockEnd(instance);
    }

    pub fn get_inline(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutEdgesImpl.get_inline(instance);
    }

    pub fn get_block(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutEdgesImpl.get_block(instance);
    }

};
