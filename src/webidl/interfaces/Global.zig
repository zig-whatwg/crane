//! Generated from: wasm-js-api.idl
//! Generated at: 2025-11-23T19:47:43Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GlobalImpl = @import("impls").Global;
const GlobalDescriptor = @import("dictionaries").GlobalDescriptor;

pub const Global = struct {
    pub const Meta = struct {
        pub const name = "Global";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "LegacyNamespace", .value = .{ .identifier = "WebAssembly" } },
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "value", "get_value", "set_value" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "valueOf", "call_valueOf", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "valueOf",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "value", "get_value", "set_value" },
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
            value: *const anyopaque = undefined,
            _internal: ?*GlobalImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_value = &get_value,

        .set_value = &set_value,

        .call_valueOf = &call_valueOf,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GlobalImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GlobalImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, descriptor: GlobalDescriptor, v: *const anyopaque) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try GlobalImpl.call_constructor(allocator, ctx, descriptor, v);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try GlobalImpl.get_value(instance);
    }

    pub fn set_value(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
        try GlobalImpl.set_value(instance, value);
    }

    pub fn call_valueOf(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try GlobalImpl.call_valueOf(instance);
    }

};
