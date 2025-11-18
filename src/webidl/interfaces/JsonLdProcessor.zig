//! Generated from: json-ld-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const JsonLdProcessorImpl = @import("impls").JsonLdProcessor;
const RdfDataset = @import("interfaces").RdfDataset;
const JsonLdOptions = @import("dictionaries").JsonLdOptions;
const Promise<JsonLdRecord> = @import("interfaces").Promise<JsonLdRecord>;
const JsonLdInput = @import("typedefs").JsonLdInput;
const Promise<sequence<JsonLdRecord>> = @import("interfaces").Promise<sequence<JsonLdRecord>>;
const JsonLdContext = @import("typedefs").JsonLdContext;
const Promise<RdfDataset> = @import("interfaces").Promise<RdfDataset>;

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
        
        // Initialize the instance (Impl receives full instance)
        JsonLdProcessorImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        JsonLdProcessorImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try JsonLdProcessorImpl.constructor(instance);
        
        return instance;
    }

    pub fn call_toRdf(instance: *runtime.Instance, input: JsonLdInput, options: JsonLdOptions) anyerror!anyopaque {
        
        return try JsonLdProcessorImpl.call_toRdf(instance, input, options);
    }

    pub fn call_flatten(instance: *runtime.Instance, input: JsonLdInput, context: JsonLdContext, options: JsonLdOptions) anyerror!anyopaque {
        
        return try JsonLdProcessorImpl.call_flatten(instance, input, context, options);
    }

    pub fn call_fromRdf(instance: *runtime.Instance, input: RdfDataset, options: JsonLdOptions) anyerror!anyopaque {
        
        return try JsonLdProcessorImpl.call_fromRdf(instance, input, options);
    }

    pub fn call_expand(instance: *runtime.Instance, input: JsonLdInput, options: JsonLdOptions) anyerror!anyopaque {
        
        return try JsonLdProcessorImpl.call_expand(instance, input, options);
    }

    pub fn call_compact(instance: *runtime.Instance, input: JsonLdInput, context: JsonLdContext, options: JsonLdOptions) anyerror!anyopaque {
        
        return try JsonLdProcessorImpl.call_compact(instance, input, context, options);
    }

    pub fn call_frame(instance: *runtime.Instance, input: JsonLdInput, frame: JsonLdInput, options: JsonLdOptions) anyerror!anyopaque {
        
        return try JsonLdProcessorImpl.call_frame(instance, input, frame, options);
    }

};
