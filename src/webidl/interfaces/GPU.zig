//! Generated from: webgpu.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUImpl = @import("impls").GPU;
const mixins = @import("mixins");
const GPUAdapter = @import("interfaces").GPUAdapter;
const WGSLLanguageFeatures = @import("interfaces").WGSLLanguageFeatures;
const GPURequestAdapterOptions = @import("dictionaries").GPURequestAdapterOptions;
const GPUTextureFormat = @import("enums").GPUTextureFormat;

pub const GPU = struct {
    pub const Meta = struct {
        pub const name = "GPU";
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
            .{ "wgslLanguageFeatures", "get_wgslLanguageFeatures", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "requestAdapter", "call_requestAdapter", 0 },
            .{ "getPreferredCanvasFormat", "call_getPreferredCanvasFormat", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "requestAdapter",
            "getPreferredCanvasFormat",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "wgslLanguageFeatures", "get_wgslLanguageFeatures", null },
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
            wgslLanguageFeatures: *runtime.Instance = undefined,
            cached_wgslLanguageFeatures: ?*runtime.Instance = null,
            _internal: ?*GPUImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_wgslLanguageFeatures = &get_wgslLanguageFeatures,

        .call_getPreferredCanvasFormat = &call_getPreferredCanvasFormat,
        .call_requestAdapter = &call_requestAdapter,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GPUImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_wgslLanguageFeatures(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_wgslLanguageFeatures) |cached| {
            return cached;
        }
        const value = try GPUImpl.get_wgslLanguageFeatures(instance);
        state.own.cached_wgslLanguageFeatures = value;
        return value;
    }

    pub fn call_requestAdapter(instance: *runtime.Instance, options: webidl.Opt(GPURequestAdapterOptions)) anyerror!*const anyopaque {
        
        return try GPUImpl.call_requestAdapter(instance, options);
    }

    pub fn call_getPreferredCanvasFormat(instance: *runtime.Instance) anyerror!GPUTextureFormat {
        return try GPUImpl.call_getPreferredCanvasFormat(instance);
    }

};
