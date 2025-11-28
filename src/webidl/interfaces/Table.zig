//! Generated from: wasm-js-api.idl
//! Generated at: 2025-11-28T19:11:19Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TableImpl = @import("impls").Table;
const mixins = @import("mixins");
const AddressValue = @import("typedefs").AddressValue;
const TableDescriptor = @import("dictionaries").TableDescriptor;

pub const Table = struct {
    pub const Meta = struct {
        pub const name = "Table";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "length", "get_length", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "grow", "call_grow", 1 },
            .{ "get", "call_get", 1 },
            .{ "set", "call_set", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "grow",
            "get",
            "set",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "length", "get_length", null },
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
            length: AddressValue = undefined,
            _internal: ?*TableImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_length = &get_length,

        .call_get = &call_get,
        .call_grow = &call_grow,
        .call_set = &call_set,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TableImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TableImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, descriptor: TableDescriptor, value: webidl.Opt(*const anyopaque)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TableImpl.call_constructor(allocator, ctx, descriptor, value);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!AddressValue {
        return try TableImpl.get_length(instance);
    }

    pub fn call_get(instance: *runtime.Instance, index: AddressValue) anyerror!*const anyopaque {
        
        return try TableImpl.call_get(instance, index);
    }

    pub fn call_grow(instance: *runtime.Instance, delta: AddressValue, value: webidl.Opt(*const anyopaque)) anyerror!AddressValue {
        
        return try TableImpl.call_grow(instance, delta, value);
    }

    pub fn call_set(instance: *runtime.Instance, index: AddressValue, value: webidl.Opt(*const anyopaque)) anyerror!void {
        
        return try TableImpl.call_set(instance, index, value);
    }

};
