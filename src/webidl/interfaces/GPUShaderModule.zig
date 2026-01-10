//! Generated from: webgpu.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUShaderModuleImpl = @import("impls").GPUShaderModule;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GPUObjectBase = @import("mixins").GPUObjectBase;
const GPUCompilationInfo = @import("GPUCompilationInfo.zig").GPUCompilationInfo;
const USVString = @import("typedefs").USVString;

pub const GPUShaderModule = struct {
    pub const Meta = struct {
        pub const name = "GPUShaderModule";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{
            GPUObjectBase,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "label", "get_label", "set_label" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getCompilationInfo", "call_getCompilationInfo", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getCompilationInfo",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "label", "get_label", "set_label" },
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
            label: runtime.USVString = undefined,
            _internal: ?*GPUShaderModuleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_label = &get_label,

        .set_label = &set_label,

        .call_getCompilationInfo = &call_getCompilationInfo,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GPUShaderModuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return GPUShaderModuleImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUShaderModuleImpl.deinit(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try GPUShaderModuleImpl.get_label(instance);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try GPUShaderModuleImpl.set_label(instance, value);
    }

    pub fn call_getCompilationInfo(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try GPUShaderModuleImpl.call_getCompilationInfo(instance);
    }

};
