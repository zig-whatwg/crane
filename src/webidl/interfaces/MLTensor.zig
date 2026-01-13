//! Generated from: webnn.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MLTensorImpl = @import("impls").MLTensor;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const MLOperandDataType = @import("enums").MLOperandDataType;

pub const MLTensor = struct {
    pub const Meta = struct {
        pub const name = "MLTensor";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
            .{ "readable", "get_readable", null },
            .{ "writable", "get_writable", null },
            .{ "constant", "get_constant", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "destroy", "call_destroy", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "destroy",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "dataType", "get_dataType", null },
            .{ "shape", "get_shape", null },
            .{ "readable", "get_readable", null },
            .{ "writable", "get_writable", null },
            .{ "constant", "get_constant", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            dataType: enums.MLOperandDataType = undefined,
            shape: runtime.JSValue = undefined,
            readable: bool = undefined,
            writable: bool = undefined,
            constant: bool = undefined,
            _internal: ?*MLTensorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_constant = &get_constant,
        .get_dataType = &get_dataType,
        .get_readable = &get_readable,
        .get_shape = &get_shape,
        .get_writable = &get_writable,

        .call_destroy = &call_destroy,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MLTensorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return MLTensorImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MLTensorImpl.deinit(instance);
    }

    pub fn get_dataType(instance: *runtime.Instance) anyerror!MLOperandDataType {
        return try MLTensorImpl.get_dataType(instance);
    }

    pub fn get_shape(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try MLTensorImpl.get_shape(instance);
    }

    pub fn get_readable(instance: *runtime.Instance) anyerror!bool {
        return try MLTensorImpl.get_readable(instance);
    }

    pub fn get_writable(instance: *runtime.Instance) anyerror!bool {
        return try MLTensorImpl.get_writable(instance);
    }

    pub fn get_constant(instance: *runtime.Instance) anyerror!bool {
        return try MLTensorImpl.get_constant(instance);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try MLTensorImpl.call_destroy(instance);
    }

};
