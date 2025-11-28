//! Generated from: webgpu.idl
//! Generated at: 2025-11-28T18:57:55Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUPipelineBaseImpl = @import("impls").GPUPipelineBase;
const mixins = @import("mixins");
const GPUBindGroupLayout = @import("interfaces").GPUBindGroupLayout;

pub const GPUPipelineBase = struct {
    pub const Meta = struct {
        pub const name = "GPUPipelineBase";
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
            .{ "getBindGroupLayout", "call_getBindGroupLayout", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getBindGroupLayout",
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
            _internal: ?*GPUPipelineBaseImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_getBindGroupLayout = &call_getBindGroupLayout,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GPUPipelineBaseImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUPipelineBaseImpl.deinit(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getBindGroupLayout(instance: *runtime.Instance, index: u32) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try GPUPipelineBaseImpl.call_getBindGroupLayout(instance, index);
    }

};
