//! Generated from: json-ld-api.idl
//! Generated at: 2025-11-23T19:47:43Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const JsonLdProcessorImpl = @import("impls").JsonLdProcessor;
const RdfDataset = @import("interfaces").RdfDataset;
const JsonLdOptions = @import("dictionaries").JsonLdOptions;
const JsonLdInput = @import("typedefs").JsonLdInput;
const JsonLdRecord = @import("typedefs").JsonLdRecord;
const JsonLdContext = @import("typedefs").JsonLdContext;

pub const JsonLdProcessor = struct {
    pub const Meta = struct {
        pub const name = "JsonLdProcessor";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "JsonLd" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .JsonLd = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "compact", "call_compact", 1 },
            .{ "expand", "call_expand", 1 },
            .{ "flatten", "call_flatten", 1 },
            .{ "fromRdf", "call_fromRdf", 1 },
            .{ "toRdf", "call_toRdf", 1 },
            .{ "frame", "call_frame", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "compact",
            "expand",
            "flatten",
            "fromRdf",
            "toRdf",
            "frame",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

        .call_compact = &call_compact,
        .call_expand = &call_expand,
        .call_flatten = &call_flatten,
        .call_frame = &call_frame,
        .call_fromRdf = &call_fromRdf,
        .call_toRdf = &call_toRdf,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return JsonLdProcessorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        JsonLdProcessorImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try JsonLdProcessorImpl.call_constructor(allocator, ctx);
    }

    pub fn call_toRdf(instance: *runtime.Instance, input: JsonLdInput, options: JsonLdOptions) anyerror!*const anyopaque {
        
        return try JsonLdProcessorImpl.call_toRdf(instance, input, options);
    }

    pub fn call_flatten(instance: *runtime.Instance, input: JsonLdInput, context: JsonLdContext, options: JsonLdOptions) anyerror!*const anyopaque {
        
        return try JsonLdProcessorImpl.call_flatten(instance, input, context, options);
    }

    pub fn call_fromRdf(instance: *runtime.Instance, input: *runtime.Instance, options: JsonLdOptions) anyerror!*const anyopaque {
        
        return try JsonLdProcessorImpl.call_fromRdf(instance, input, options);
    }

    pub fn call_expand(instance: *runtime.Instance, input: JsonLdInput, options: JsonLdOptions) anyerror!*const anyopaque {
        
        return try JsonLdProcessorImpl.call_expand(instance, input, options);
    }

    pub fn call_compact(instance: *runtime.Instance, input: JsonLdInput, context: JsonLdContext, options: JsonLdOptions) anyerror!*const anyopaque {
        
        return try JsonLdProcessorImpl.call_compact(instance, input, context, options);
    }

    pub fn call_frame(instance: *runtime.Instance, input: JsonLdInput, frame: JsonLdInput, options: JsonLdOptions) anyerror!*const anyopaque {
        
        return try JsonLdProcessorImpl.call_frame(instance, input, frame, options);
    }

};
