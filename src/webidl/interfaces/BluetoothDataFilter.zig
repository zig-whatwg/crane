//! Generated from: web-bluetooth-scanning.idl
//! Generated at: 2025-11-25T20:02:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothDataFilterImpl = @import("impls").BluetoothDataFilter;
const BluetoothDataFilterInit = @import("dictionaries").BluetoothDataFilterInit;

pub const BluetoothDataFilter = struct {
    pub const Meta = struct {
        pub const name = "BluetoothDataFilter";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "dataPrefix", "get_dataPrefix", null },
            .{ "mask", "get_mask", null },
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
            .{ "dataPrefix", "get_dataPrefix", null },
            .{ "mask", "get_mask", null },
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
            dataPrefix: runtime.ArrayBuffer = undefined,
            mask: runtime.ArrayBuffer = undefined,
            _internal: ?*BluetoothDataFilterImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_dataPrefix = &get_dataPrefix,
        .get_mask = &get_mask,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BluetoothDataFilterImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothDataFilterImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, init_data: BluetoothDataFilterInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try BluetoothDataFilterImpl.call_constructor(allocator, ctx, init_data);
    }

    pub fn get_dataPrefix(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try BluetoothDataFilterImpl.get_dataPrefix(instance);
    }

    pub fn get_mask(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try BluetoothDataFilterImpl.get_mask(instance);
    }

};
