//! Generated from: wasm-js-api.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebAssemblyImpl = @import("impls").WebAssembly;
const Tag = @import("interfaces").Tag;
const BufferSource = @import("typedefs").BufferSource;
const Promise<Instance> = @import("interfaces").Promise<Instance>;
const Promise<WebAssemblyInstantiatedSource> = @import("interfaces").Promise<WebAssemblyInstantiatedSource>;
const Promise<Module> = @import("interfaces").Promise<Module>;
const Promise<Response> = @import("interfaces").Promise<Response>;
const WebAssemblyCompileOptions = @import("dictionaries").WebAssemblyCompileOptions;
const Module = @import("interfaces").Module;

pub const WebAssembly = struct {
    pub const Meta = struct {
        pub const name = "WebAssembly";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            JSTag: Tag = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WebAssembly, .{
        .deinit_fn = &deinit_wrapper,

        .get_JSTag = &get_JSTag,

        .call_compile = &call_compile,
        .call_compileStreaming = &call_compileStreaming,
        .call_instantiate = &call_instantiate,
        .call_instantiateStreaming = &call_instantiateStreaming,
        .call_validate = &call_validate,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WebAssemblyImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebAssemblyImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_JSTag(instance: *runtime.Instance) anyerror!Tag {
        return try WebAssemblyImpl.get_JSTag(instance);
    }

    pub fn call_compile(instance: *runtime.Instance, bytes: BufferSource, options: WebAssemblyCompileOptions) anyerror!anyopaque {
        
        return try WebAssemblyImpl.call_compile(instance, bytes, options);
    }

    /// Arguments for instantiate (WebIDL overloading)
    pub const InstantiateArgs = union(enum) {
        /// instantiate(bytes, importObject, options)
        BufferSource_object_WebAssemblyCompileOptions: struct {
            bytes: BufferSource,
            importObject: anyopaque,
            options: WebAssemblyCompileOptions,
        },
        /// instantiate(moduleObject, importObject)
        Module_object: struct {
            moduleObject: Module,
            importObject: anyopaque,
        },
    };

    pub fn call_instantiate(instance: *runtime.Instance, args: InstantiateArgs) anyerror!anyopaque {
        switch (args) {
            .BufferSource_object_WebAssemblyCompileOptions => |a| return try WebAssemblyImpl.BufferSource_object_WebAssemblyCompileOptions(instance, a.bytes, a.importObject, a.options),
            .Module_object => |a| return try WebAssemblyImpl.Module_object(instance, a.moduleObject, a.importObject),
        }
    }

    pub fn call_validate(instance: *runtime.Instance, bytes: BufferSource, options: WebAssemblyCompileOptions) anyerror!bool {
        
        return try WebAssemblyImpl.call_validate(instance, bytes, options);
    }

    pub fn call_compileStreaming(instance: *runtime.Instance, source: anyopaque, options: WebAssemblyCompileOptions) anyerror!anyopaque {
        
        return try WebAssemblyImpl.call_compileStreaming(instance, source, options);
    }

    pub fn call_instantiateStreaming(instance: *runtime.Instance, source: anyopaque, importObject: anyopaque, options: WebAssemblyCompileOptions) anyerror!anyopaque {
        
        return try WebAssemblyImpl.call_instantiateStreaming(instance, source, importObject, options);
    }

};
