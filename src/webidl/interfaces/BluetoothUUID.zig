//! Generated from: web-bluetooth.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BluetoothUUIDImpl = @import("impls").BluetoothUUID;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const UUID = @import("typedefs").UUID;
const DOMString = @import("typedefs").DOMString;

pub const BluetoothUUID = struct {
    pub const Meta = struct {
        pub const name = "BluetoothUUID";
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
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "getService", "call_static_getService", 1 },
            .{ "getCharacteristic", "call_static_getCharacteristic", 1 },
            .{ "getDescriptor", "call_static_getDescriptor", 1 },
            .{ "canonicalUUID", "call_static_canonicalUUID", 1 },
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*BluetoothUUIDImpl.InternalState = null,
        },
    );

    const delegates = .{

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BluetoothUUIDImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return BluetoothUUIDImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothUUIDImpl.deinit(instance);
    }

    pub fn call_static_getService(instance: *runtime.Instance, name: runtime.JSValue) anyerror!UUID {
        
        return try BluetoothUUIDImpl.call_static_getService(instance, name);
    }

    pub fn call_static_canonicalUUID(instance: *runtime.Instance, alias: u32) anyerror!UUID {
        // [EnforceRange] on alias
        if (!runtime.isInRange(u32, alias)) return error.TypeError;
        
        return try BluetoothUUIDImpl.call_static_canonicalUUID(instance, alias);
    }

    pub fn call_static_getCharacteristic(instance: *runtime.Instance, name: runtime.JSValue) anyerror!UUID {
        
        return try BluetoothUUIDImpl.call_static_getCharacteristic(instance, name);
    }

    pub fn call_static_getDescriptor(instance: *runtime.Instance, name: runtime.JSValue) anyerror!UUID {
        
        return try BluetoothUUIDImpl.call_static_getDescriptor(instance, name);
    }

};
