//! Generated from: webgpu.idl
//! Generated at: 2025-11-28T18:57:56Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUAdapterImpl = @import("impls").GPUAdapter;
const mixins = @import("mixins");
const GPUDeviceDescriptor = @import("dictionaries").GPUDeviceDescriptor;
const GPUSupportedLimits = @import("interfaces").GPUSupportedLimits;
const GPUSupportedFeatures = @import("interfaces").GPUSupportedFeatures;
const GPUAdapterInfo = @import("interfaces").GPUAdapterInfo;
const GPUDevice = @import("interfaces").GPUDevice;

pub const GPUAdapter = struct {
    pub const Meta = struct {
        pub const name = "GPUAdapter";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
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
            .{ "features", "get_features", null },
            .{ "limits", "get_limits", null },
            .{ "info", "get_info", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "requestDevice", "call_requestDevice", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "requestDevice",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "features", "get_features", null },
            .{ "limits", "get_limits", null },
            .{ "info", "get_info", null },
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
            features: *runtime.Instance = undefined,
            limits: *runtime.Instance = undefined,
            info: *runtime.Instance = undefined,
            cached_features: ?*runtime.Instance = null,
            cached_limits: ?*runtime.Instance = null,
            cached_info: ?*runtime.Instance = null,
            _internal: ?*GPUAdapterImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_features = &get_features,
        .get_info = &get_info,
        .get_limits = &get_limits,

        .call_requestDevice = &call_requestDevice,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GPUAdapterImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUAdapterImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_features(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_features) |cached| {
            return cached;
        }
        const value = try GPUAdapterImpl.get_features(instance);
        state.own.cached_features = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_limits(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_limits) |cached| {
            return cached;
        }
        const value = try GPUAdapterImpl.get_limits(instance);
        state.own.cached_limits = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_info(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_info) |cached| {
            return cached;
        }
        const value = try GPUAdapterImpl.get_info(instance);
        state.own.cached_info = value;
        return value;
    }

    pub fn call_requestDevice(instance: *runtime.Instance, descriptor: webidl.Opt(GPUDeviceDescriptor)) anyerror!*const anyopaque {
        
        return try GPUAdapterImpl.call_requestDevice(instance, descriptor);
    }

};
