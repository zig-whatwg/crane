//! Generated from: wasm-js-api.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebAssemblyImpl = @import("../impls/WebAssembly.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        WebAssemblyImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WebAssemblyImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_JSTag(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebAssemblyImpl.get_JSTag(state);
    }

    pub fn call_compile(instance: *runtime.Instance, bytes: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebAssemblyImpl.call_compile(state, bytes, options);
    }

    /// Arguments for instantiate (WebIDL overloading)
    pub const InstantiateArgs = union(enum) {
        /// instantiate(bytes, importObject, options)
        BufferSource_object_WebAssemblyCompileOptions: struct {
            bytes: anyopaque,
            importObject: anyopaque,
            options: anyopaque,
        },
        /// instantiate(moduleObject, importObject)
        Module_object: struct {
            moduleObject: anyopaque,
            importObject: anyopaque,
        },
    };

    pub fn call_instantiate(instance: *runtime.Instance, args: InstantiateArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .BufferSource_object_WebAssemblyCompileOptions => |a| return WebAssemblyImpl.BufferSource_object_WebAssemblyCompileOptions(state, a.bytes, a.importObject, a.options),
            .Module_object => |a| return WebAssemblyImpl.Module_object(state, a.moduleObject, a.importObject),
        }
    }

    pub fn call_validate(instance: *runtime.Instance, bytes: anyopaque, options: anyopaque) bool {
        const state = instance.getState(State);
        
        return WebAssemblyImpl.call_validate(state, bytes, options);
    }

    pub fn call_compileStreaming(instance: *runtime.Instance, source: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebAssemblyImpl.call_compileStreaming(state, source, options);
    }

    pub fn call_instantiateStreaming(instance: *runtime.Instance, source: anyopaque, importObject: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebAssemblyImpl.call_instantiateStreaming(state, source, importObject, options);
    }

};
