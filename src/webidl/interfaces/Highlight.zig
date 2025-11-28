//! Generated from: css-highlight-api.idl
//! Generated at: 2025-11-28T19:51:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HighlightImpl = @import("impls").Highlight;
const mixins = @import("mixins");
const HighlightType = @import("enums").HighlightType;
const AbstractRange = @import("interfaces").AbstractRange;

pub const Highlight = struct {
    pub const Meta = struct {
        pub const name = "Highlight";
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
            .{ "priority", "get_priority", "set_priority" },
            .{ "type", "get_type", "set_type" },
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
            .{ "priority", "get_priority", "set_priority" },
            .{ "type", "get_type", "set_type" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            priority: i32 = undefined,
            @"type": HighlightType = undefined,
            _internal: ?*HighlightImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    const delegates = .{

        .get_priority = &get_priority,
        .get_type = &get_type,

        .set_priority = &set_priority,
        .set_type = &set_type,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HighlightImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HighlightImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, initialRanges: []const *runtime.Instance) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HighlightImpl.call_constructor(allocator, ctx, initialRanges);
    }

    pub fn get_priority(instance: *runtime.Instance) anyerror!i32 {
        return try HighlightImpl.get_priority(instance);
    }

    pub fn set_priority(instance: *runtime.Instance, value: i32) anyerror!void {
        try HighlightImpl.set_priority(instance, value);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!HighlightType {
        return try HighlightImpl.get_type(instance);
    }

    pub fn set_type(instance: *runtime.Instance, value: HighlightType) anyerror!void {
        try HighlightImpl.set_type(instance, value);
    }

};
