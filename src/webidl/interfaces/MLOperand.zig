//! Generated from: webnn.idl
//! Generated at: 2025-11-23T20:06:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MLOperandImpl = @import("impls").MLOperand;
const unsignedlong = @import("interfaces").unsignedlong;
const MLOperandDataType = @import("enums").MLOperandDataType;

pub const MLOperand = struct {
    pub const Meta = struct {
        pub const name = "MLOperand";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "dataType", "get_dataType", null },
            .{ "shape", "get_shape", null },
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
            .{ "dataType", "get_dataType", null },
            .{ "shape", "get_shape", null },
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
            dataType: MLOperandDataType = undefined,
            shape: runtime.FrozenArray(unsignedlong) = undefined,
            _internal: ?*MLOperandImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_dataType = &get_dataType,
        .get_shape = &get_shape,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MLOperandImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MLOperandImpl.deinit(instance);
    }

    pub fn get_dataType(instance: *runtime.Instance) anyerror!MLOperandDataType {
        return try MLOperandImpl.get_dataType(instance);
    }

    pub fn get_shape(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try MLOperandImpl.get_shape(instance);
    }

};
