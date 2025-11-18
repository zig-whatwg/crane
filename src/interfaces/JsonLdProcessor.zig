//! Generated from: json-ld-api.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const JsonLdProcessorImpl = @import("../impls/JsonLdProcessor.zig");

pub const JsonLdProcessor = struct {
    pub const Meta = struct {
        pub const name = "JsonLdProcessor";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "JsonLd" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .JsonLd = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(JsonLdProcessor, .{
        .deinit_fn = &deinit_wrapper,

        .call_compact = &call_compact,
        .call_expand = &call_expand,
        .call_flatten = &call_flatten,
        .call_frame = &call_frame,
        .call_fromRdf = &call_fromRdf,
        .call_toRdf = &call_toRdf,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        JsonLdProcessorImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        JsonLdProcessorImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try JsonLdProcessorImpl.constructor(state);
        
        return instance;
    }

    pub fn call_toRdf(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return JsonLdProcessorImpl.call_toRdf(state, input, options);
    }

    pub fn call_flatten(instance: *runtime.Instance, input: anyopaque, context: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return JsonLdProcessorImpl.call_flatten(state, input, context, options);
    }

    pub fn call_fromRdf(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return JsonLdProcessorImpl.call_fromRdf(state, input, options);
    }

    pub fn call_expand(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return JsonLdProcessorImpl.call_expand(state, input, options);
    }

    pub fn call_compact(instance: *runtime.Instance, input: anyopaque, context: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return JsonLdProcessorImpl.call_compact(state, input, context, options);
    }

    pub fn call_frame(instance: *runtime.Instance, input: anyopaque, frame: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return JsonLdProcessorImpl.call_frame(state, input, frame, options);
    }

};
