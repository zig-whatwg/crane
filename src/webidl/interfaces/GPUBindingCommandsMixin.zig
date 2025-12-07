//! Generated from: webgpu.idl
//! Generated at: 2025-12-07T20:02:44Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const GPUBindingCommandsMixinImpl = @import("impls").GPUBindingCommandsMixin;
const mixins = @import("mixins");
const GPUIndex32 = @import("typedefs").GPUIndex32;
const GPUSize64 = @import("typedefs").GPUSize64;
const GPUBindGroup = @import("interfaces").GPUBindGroup;
const GPUBufferDynamicOffset = @import("typedefs").GPUBufferDynamicOffset;
const GPUSize32 = @import("typedefs").GPUSize32;

pub const GPUBindingCommandsMixin = struct {
    pub const Meta = struct {
        pub const name = "GPUBindingCommandsMixin";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setBindGroup", "call_setBindGroup", 2 },
            .{ "setBindGroup", "call_setBindGroup", 5 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setBindGroup",
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

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUBindingCommandsMixinImpl.deinit(instance);
    }

    pub fn call_setBindGroup(instance: *runtime.Instance, index: GPUIndex32, bindGroup: ?*runtime.Instance, dynamicOffsets: webidl.Opt(*const anyopaque)) anyerror!void {
        
        return try GPUBindingCommandsMixinImpl.call_setBindGroup(instance, index, bindGroup, dynamicOffsets);
    }

};
