//! Generated from: css-layout-api.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ChildBreakTokenImpl = @import("impls").ChildBreakToken;
const mixins = @import("mixins");
const BreakType = @import("enums").BreakType;
const LayoutChild = @import("interfaces").LayoutChild;

pub const ChildBreakToken = struct {
    pub const Meta = struct {
        pub const name = "ChildBreakToken";
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
            .{ "breakType", "get_breakType", null },
            .{ "child", "get_child", null },
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
            .{ "breakType", "get_breakType", null },
            .{ "child", "get_child", null },
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
            breakType: BreakType = undefined,
            child: *runtime.Instance = undefined,
            _internal: ?*ChildBreakTokenImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_breakType = &get_breakType,
        .get_child = &get_child,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ChildBreakTokenImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ChildBreakTokenImpl.deinit(instance);
    }

    pub fn get_breakType(instance: *runtime.Instance) anyerror!BreakType {
        return try ChildBreakTokenImpl.get_breakType(instance);
    }

    pub fn get_child(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ChildBreakTokenImpl.get_child(instance);
    }

};
