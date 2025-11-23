//! Generated from: webgpu.idl
//! Generated at: 2025-11-23T14:26:30Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUAdapterInfoImpl = @import("impls").GPUAdapterInfo;
const DOMString = @import("typedefs").DOMString;

pub const GPUAdapterInfo = struct {
    pub const Meta = struct {
        pub const name = "GPUAdapterInfo";
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
            .{ "vendor", "get_vendor", null },
            .{ "architecture", "get_architecture", null },
            .{ "device", "get_device", null },
            .{ "description", "get_description", null },
            .{ "subgroupMinSize", "get_subgroupMinSize", null },
            .{ "subgroupMaxSize", "get_subgroupMaxSize", null },
            .{ "isFallbackAdapter", "get_isFallbackAdapter", null },
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
            .{ "vendor", "get_vendor", null },
            .{ "architecture", "get_architecture", null },
            .{ "device", "get_device", null },
            .{ "description", "get_description", null },
            .{ "subgroupMinSize", "get_subgroupMinSize", null },
            .{ "subgroupMaxSize", "get_subgroupMaxSize", null },
            .{ "isFallbackAdapter", "get_isFallbackAdapter", null },
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
            vendor: runtime.DOMString = undefined,
            architecture: runtime.DOMString = undefined,
            device: runtime.DOMString = undefined,
            description: runtime.DOMString = undefined,
            subgroupMinSize: u32 = undefined,
            subgroupMaxSize: u32 = undefined,
            isFallbackAdapter: bool = undefined,
            _internal: ?*GPUAdapterInfoImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_architecture = &get_architecture,
        .get_description = &get_description,
        .get_device = &get_device,
        .get_isFallbackAdapter = &get_isFallbackAdapter,
        .get_subgroupMaxSize = &get_subgroupMaxSize,
        .get_subgroupMinSize = &get_subgroupMinSize,
        .get_vendor = &get_vendor,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GPUAdapterInfoImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUAdapterInfoImpl.deinit(instance);
    }

    pub fn get_vendor(instance: *runtime.Instance) anyerror!DOMString {
        return try GPUAdapterInfoImpl.get_vendor(instance);
    }

    pub fn get_architecture(instance: *runtime.Instance) anyerror!DOMString {
        return try GPUAdapterInfoImpl.get_architecture(instance);
    }

    pub fn get_device(instance: *runtime.Instance) anyerror!DOMString {
        return try GPUAdapterInfoImpl.get_device(instance);
    }

    pub fn get_description(instance: *runtime.Instance) anyerror!DOMString {
        return try GPUAdapterInfoImpl.get_description(instance);
    }

    pub fn get_subgroupMinSize(instance: *runtime.Instance) anyerror!u32 {
        return try GPUAdapterInfoImpl.get_subgroupMinSize(instance);
    }

    pub fn get_subgroupMaxSize(instance: *runtime.Instance) anyerror!u32 {
        return try GPUAdapterInfoImpl.get_subgroupMaxSize(instance);
    }

    pub fn get_isFallbackAdapter(instance: *runtime.Instance) anyerror!bool {
        return try GPUAdapterInfoImpl.get_isFallbackAdapter(instance);
    }

};
