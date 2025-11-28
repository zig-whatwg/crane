//! Generated from: wasm-js-api.idl
//! Generated at: 2025-11-28T22:33:19Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MemoryImpl = @import("impls").Memory;
const mixins = @import("mixins");
const MemoryDescriptor = @import("dictionaries").MemoryDescriptor;
const AddressValue = @import("typedefs").AddressValue;

pub const Memory = struct {
    pub const Meta = struct {
        pub const name = "Memory";
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
            .{ "buffer", "get_buffer", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "grow", "call_grow", 1 },
            .{ "toFixedLengthBuffer", "call_toFixedLengthBuffer", 0 },
            .{ "toResizableBuffer", "call_toResizableBuffer", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "grow",
            "toFixedLengthBuffer",
            "toResizableBuffer",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "buffer", "get_buffer", null },
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
            buffer: runtime.ArrayBuffer = undefined,
            _internal: ?*MemoryImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_buffer = &get_buffer,

        .call_grow = &call_grow,
        .call_toFixedLengthBuffer = &call_toFixedLengthBuffer,
        .call_toResizableBuffer = &call_toResizableBuffer,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MemoryImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MemoryImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, descriptor: MemoryDescriptor) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MemoryImpl.call_constructor(allocator, ctx, descriptor);
    }

    pub fn get_buffer(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try MemoryImpl.get_buffer(instance);
    }

    pub fn call_grow(instance: *runtime.Instance, delta: AddressValue) anyerror!AddressValue {
        
        return try MemoryImpl.call_grow(instance, delta);
    }

    pub fn call_toFixedLengthBuffer(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try MemoryImpl.call_toFixedLengthBuffer(instance);
    }

    pub fn call_toResizableBuffer(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try MemoryImpl.call_toResizableBuffer(instance);
    }

};
