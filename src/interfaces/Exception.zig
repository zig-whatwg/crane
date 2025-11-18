//! Generated from: wasm-js-api.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ExceptionImpl = @import("../impls/Exception.zig");

pub const Exception = struct {
    pub const Meta = struct {
        pub const name = "Exception";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "LegacyNamespace", .value = .{ .identifier = "WebAssembly" } },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "Worklet" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .Worklet = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            stack: (DOMString or undefined) = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Exception, .{
        .deinit_fn = &deinit_wrapper,

        .get_stack = &get_stack,

        .call_getArg = &call_getArg,
        .call_is = &call_is,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ExceptionImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ExceptionImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, exceptionTag: anyopaque, payload: anyopaque, options: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try ExceptionImpl.constructor(state, exceptionTag, payload, options);
        
        return instance;
    }

    pub fn get_stack(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ExceptionImpl.get_stack(state);
    }

    pub fn call_is(instance: *runtime.Instance, exceptionTag: anyopaque) bool {
        const state = instance.getState(State);
        
        return ExceptionImpl.call_is(state, exceptionTag);
    }

    pub fn call_getArg(instance: *runtime.Instance, index: u32) anyopaque {
        const state = instance.getState(State);
        // [EnforceRange] on index
        if (index > std.math.maxInt(u53)) return error.TypeError;
        
        return ExceptionImpl.call_getArg(state, index);
    }

};
