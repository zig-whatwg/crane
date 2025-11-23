//! Generated from: mediacapture-streams.idl
//! Generated at: 2025-11-23T19:47:42Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const OverconstrainedErrorImpl = @import("impls").OverconstrainedError;
const DOMException = @import("interfaces").DOMException;
const DOMString = @import("typedefs").DOMString;

pub const OverconstrainedError = struct {
    pub const Meta = struct {
        pub const name = "OverconstrainedError";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *DOMException;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "constraint", "get_constraint", null },
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
            .{ "constraint", "get_constraint", null },
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
            constraint: runtime.DOMString = undefined,
            _internal: ?*OverconstrainedErrorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_constraint = &get_constraint,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return OverconstrainedErrorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        OverconstrainedErrorImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, constraint: DOMString, message: DOMString) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try OverconstrainedErrorImpl.call_constructor(allocator, ctx, constraint, message);
    }

    pub fn get_constraint(instance: *runtime.Instance) anyerror!DOMString {
        return try OverconstrainedErrorImpl.get_constraint(instance);
    }

};
