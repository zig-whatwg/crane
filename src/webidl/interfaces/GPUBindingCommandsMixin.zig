//! Generated from: webgpu.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUBindingCommandsMixinImpl = @import("impls").GPUBindingCommandsMixin;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GPUIndex32 = @import("typedefs").GPUIndex32;
const GPUSize64 = @import("typedefs").GPUSize64;
const GPUBindGroup = @import("GPUBindGroup.zig").GPUBindGroup;
const GPUBufferDynamicOffset = @import("typedefs").GPUBufferDynamicOffset;
const GPUSize32 = @import("typedefs").GPUSize32;

pub const GPUBindingCommandsMixin = struct {
    pub const Meta = struct {
        pub const name = "GPUBindingCommandsMixin";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setBindGroup", "call_setBindGroup", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setBindGroup",
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
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*GPUBindingCommandsMixinImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_setBindGroup = &call_setBindGroup,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GPUBindingCommandsMixinImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return GPUBindingCommandsMixinImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUBindingCommandsMixinImpl.deinit(instance);
    }

    pub fn call_setBindGroup(instance: *runtime.Instance, index: GPUIndex32, bindGroup: ?*runtime.Instance, dynamicOffsets: webidl.Opt(runtime.JSValue)) anyerror!void {
        
        return try GPUBindingCommandsMixinImpl.call_setBindGroup(instance, index, bindGroup, dynamicOffsets);
    }

};
