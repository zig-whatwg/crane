//! Generated from: is-input-pending.idl
//! Generated at: 2025-11-25T14:21:40Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SchedulingImpl = @import("impls").Scheduling;
const IsInputPendingOptions = @import("dictionaries").IsInputPendingOptions;

pub const Scheduling = struct {
    pub const Meta = struct {
        pub const name = "Scheduling";
        pub const is_mixin = false;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "isInputPending", "call_isInputPending", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "isInputPending",
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
            _internal: ?*SchedulingImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_isInputPending = &call_isInputPending,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SchedulingImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SchedulingImpl.deinit(instance);
    }

    pub fn call_isInputPending(instance: *runtime.Instance, isInputPendingOptions: IsInputPendingOptions) anyerror!bool {
        
        return try SchedulingImpl.call_isInputPending(instance, isInputPendingOptions);
    }

};
