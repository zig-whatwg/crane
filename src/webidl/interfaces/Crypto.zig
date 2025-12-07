//! Generated from: webcrypto.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CryptoImpl = @import("impls").Crypto;
const mixins = @import("mixins");
const ArrayBufferView = @import("typedefs").ArrayBufferView;
const SubtleCrypto = @import("interfaces").SubtleCrypto;
const DOMString = @import("typedefs").DOMString;

pub const Crypto = struct {
    pub const Meta = struct {
        pub const name = "Crypto";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "subtle", "get_subtle", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getRandomValues", "call_getRandomValues", 1 },
            .{ "randomUUID", "call_randomUUID", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getRandomValues",
            "randomUUID",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "subtle", "get_subtle", null },
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
            subtle: *runtime.Instance = undefined,
            _internal: ?*CryptoImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_subtle = &get_subtle,

        .call_getRandomValues = &call_getRandomValues,
        .call_randomUUID = &call_randomUUID,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CryptoImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CryptoImpl.deinit(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_subtle(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CryptoImpl.get_subtle(instance);
    }

    pub fn call_getRandomValues(instance: *runtime.Instance, array: ArrayBufferView) anyerror!ArrayBufferView {
        
        return try CryptoImpl.call_getRandomValues(instance, array);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_randomUUID(instance: *runtime.Instance) anyerror!DOMString {
        return try CryptoImpl.call_randomUUID(instance);
    }

};
