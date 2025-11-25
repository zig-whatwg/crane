//! Generated from: css-layout-api.idl
//! Generated at: 2025-11-25T20:02:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BreakTokenImpl = @import("impls").BreakToken;
const ChildBreakToken = @import("interfaces").ChildBreakToken;

pub const BreakToken = struct {
    pub const Meta = struct {
        pub const name = "BreakToken";
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
            .{ "childBreakTokens", "get_childBreakTokens", null },
            .{ "data", "get_data", null },
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
            .{ "childBreakTokens", "get_childBreakTokens", null },
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
            childBreakTokens: runtime.FrozenArray(ChildBreakToken) = undefined,
            data: *const anyopaque = undefined,
            _internal: ?*BreakTokenImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_childBreakTokens = &get_childBreakTokens,
        .get_data = &get_data,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BreakTokenImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BreakTokenImpl.deinit(instance);
    }

    pub fn get_childBreakTokens(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try BreakTokenImpl.get_childBreakTokens(instance);
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try BreakTokenImpl.get_data(instance);
    }

};
