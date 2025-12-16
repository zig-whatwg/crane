//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const StorageImpl = @import("impls").Storage;
const mixins = @import("mixins");
const DOMString = @import("typedefs").DOMString;

pub const Storage = struct {
    pub const Meta = struct {
        pub const name = "Storage";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "length", "get_length", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "key", "call_key", 1 },
            .{ "getItem", "call_getItem", 1 },
            .{ "setItem", "call_setItem", 2 },
            .{ "clear", "call_clear", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "key",
            "getItem",
            "setItem",
            "clear",
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
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: u32 = undefined,
            _internal: ?*StorageImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_length = &get_length,

        .call_clear = &call_clear,
        .call_getItem = &call_getItem,
        .call_key = &call_key,
        .call_removeItem = &call_removeItem,
        .call_setItem = &call_setItem,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return StorageImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return StorageImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        StorageImpl.deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try StorageImpl.get_length(instance);
    }

    pub fn call_getItem(instance: *runtime.Instance, key: DOMString) anyerror!?DOMString {
        
        return try StorageImpl.call_getItem(instance, key);
    }

    pub fn call_removeItem(instance: *runtime.Instance, key: DOMString) anyerror!void {
        
        return try StorageImpl.call_removeItem(instance, key);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try StorageImpl.call_clear(instance);
    }

    pub fn call_setItem(instance: *runtime.Instance, key: DOMString, value: DOMString) anyerror!void {
        
        return try StorageImpl.call_setItem(instance, key, value);
    }

    pub fn call_key(instance: *runtime.Instance, index: u32) anyerror!?DOMString {
        
        return try StorageImpl.call_key(instance, index);
    }

    /// Get supported property names for named property enumeration (Reflect.ownKeys, etc.)
    /// Per WebIDL spec §3.9.3, returns names in list order for proper enumeration
    pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
        return StorageImpl.getSupportedPropertyNames(instance, allocator);
    }

};
