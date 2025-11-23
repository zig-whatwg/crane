//! Generated from: webgpu.idl
//! Generated at: 2025-11-23T19:57:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUCanvasContextImpl = @import("impls").GPUCanvasContext;
const HTMLCanvasElement = @import("interfaces").HTMLCanvasElement;
const OffscreenCanvas = @import("interfaces").OffscreenCanvas;
const GPUCanvasConfiguration = @import("dictionaries").GPUCanvasConfiguration;
const GPUTexture = @import("interfaces").GPUTexture;

pub const GPUCanvasContext = struct {
    pub const Meta = struct {
        pub const name = "GPUCanvasContext";
        pub const is_mixin = false;
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
            .{ "canvas", "get_canvas", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "configure", "call_configure", 1 },
            .{ "unconfigure", "call_unconfigure", 0 },
            .{ "getConfiguration", "call_getConfiguration", 0 },
            .{ "getCurrentTexture", "call_getCurrentTexture", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "configure",
            "unconfigure",
            "getConfiguration",
            "getCurrentTexture",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "canvas", "get_canvas", null },
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
            canvas: union(enum) {
                HTMLCanvasElement: HTMLCanvasElement,
                OffscreenCanvas: OffscreenCanvas,
            } = undefined,
            _internal: ?*GPUCanvasContextImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_canvas = &get_canvas,

        .call_configure = &call_configure,
        .call_getConfiguration = &call_getConfiguration,
        .call_getCurrentTexture = &call_getCurrentTexture,
        .call_unconfigure = &call_unconfigure,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GPUCanvasContextImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUCanvasContextImpl.deinit(instance);
    }

    pub fn get_canvas(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try GPUCanvasContextImpl.get_canvas(instance);
    }

    pub fn call_unconfigure(instance: *runtime.Instance) anyerror!void {
        return try GPUCanvasContextImpl.call_unconfigure(instance);
    }

    pub fn call_configure(instance: *runtime.Instance, configuration: GPUCanvasConfiguration) anyerror!void {
        
        return try GPUCanvasContextImpl.call_configure(instance, configuration);
    }

    pub fn call_getConfiguration(instance: *runtime.Instance) anyerror!GPUCanvasConfiguration {
        return try GPUCanvasContextImpl.call_getConfiguration(instance);
    }

    pub fn call_getCurrentTexture(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try GPUCanvasContextImpl.call_getCurrentTexture(instance);
    }

};
