//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const OriginImpl = @import("impls").Origin;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const Origin = struct {
    pub const Meta = struct {
        pub const name = "Origin";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "opaque", "get_opaque", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "isSameOrigin", "call_isSameOrigin", 1 },
            .{ "isSameSite", "call_isSameSite", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "isSameOrigin",
            "isSameSite",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "opaque", "get_opaque", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "from", "call_static_from", 1 },
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            @"opaque": bool = undefined,
            _internal: ?*OriginImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_opaque = &get_opaque,

        .call_isSameOrigin = &call_isSameOrigin,
        .call_isSameSite = &call_isSameSite,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return OriginImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return OriginImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        OriginImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try OriginImpl.call_constructor(ctx);
    }

    pub fn get_opaque(instance: *runtime.Instance) anyerror!bool {
        return try OriginImpl.get_opaque(instance);
    }

    pub fn call_isSameOrigin(instance: *runtime.Instance, other: *runtime.Instance) anyerror!bool {
        
        return try OriginImpl.call_isSameOrigin(instance, other);
    }

    pub fn call_static_from(instance: *runtime.Instance, value: runtime.JSValue) anyerror!*runtime.Instance {
        
        return try OriginImpl.call_static_from(instance, value);
    }

    pub fn call_isSameSite(instance: *runtime.Instance, other: *runtime.Instance) anyerror!bool {
        
        return try OriginImpl.call_isSameSite(instance, other);
    }

};
