//! Generated from: webgpu.idl
//! Generated at: 2025-11-23T16:59:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorGPUImpl = @import("impls").NavigatorGPU;
const GPU = @import("interfaces").GPU;

pub const NavigatorGPU = struct {
    pub const Meta = struct {
        pub const name = "NavigatorGPU";
        pub const is_mixin = true;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "gpu", "get_gpu", null },
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
            .{ "gpu", "get_gpu", null },
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
            gpu: GPU = undefined,
            cached_gpu: ?GPU = null,
            _internal: ?*NavigatorGPUImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_gpu = &get_gpu,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NavigatorGPUImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorGPUImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_gpu(instance: *runtime.Instance) anyerror!GPU {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_gpu) |cached| {
            return cached;
        }
        const value = try NavigatorGPUImpl.get_gpu(instance);
        state.own.cached_gpu = value;
        return value;
    }

};
