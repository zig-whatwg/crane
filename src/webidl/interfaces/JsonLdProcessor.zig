//! Generated from: json-ld-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const JsonLdProcessorImpl = @import("impls").JsonLdProcessor;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const RdfDataset = @import("RdfDataset.zig").RdfDataset;
const JsonLdOptions = @import("dictionaries").JsonLdOptions;
const JsonLdInput = @import("typedefs").JsonLdInput;
const JsonLdRecord = @import("typedefs").JsonLdRecord;
const JsonLdContext = @import("typedefs").JsonLdContext;

pub const JsonLdProcessor = struct {
    pub const Meta = struct {
        pub const name = "JsonLdProcessor";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "JsonLd" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .JsonLd = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "compact", "call_static_compact", 1 },
            .{ "expand", "call_static_expand", 1 },
            .{ "flatten", "call_static_flatten", 1 },
            .{ "fromRdf", "call_static_fromRdf", 1 },
            .{ "toRdf", "call_static_toRdf", 1 },
            .{ "frame", "call_static_frame", 2 },
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*JsonLdProcessorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return JsonLdProcessorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return JsonLdProcessorImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        JsonLdProcessorImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try JsonLdProcessorImpl.call_constructor(ctx);
    }

    pub fn call_static_compact(instance: *runtime.Instance, input: JsonLdInput, context: webidl.Opt(JsonLdContext), options: webidl.Opt(JsonLdOptions)) anyerror!runtime.JSValue {
        
        return try JsonLdProcessorImpl.call_static_compact(instance, input, context, options);
    }

    pub fn call_static_fromRdf(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(JsonLdOptions)) anyerror!runtime.JSValue {
        
        return try JsonLdProcessorImpl.call_static_fromRdf(instance, input, options);
    }

    pub fn call_static_toRdf(instance: *runtime.Instance, input: JsonLdInput, options: webidl.Opt(JsonLdOptions)) anyerror!runtime.JSValue {
        
        return try JsonLdProcessorImpl.call_static_toRdf(instance, input, options);
    }

    pub fn call_static_expand(instance: *runtime.Instance, input: JsonLdInput, options: webidl.Opt(JsonLdOptions)) anyerror!runtime.JSValue {
        
        return try JsonLdProcessorImpl.call_static_expand(instance, input, options);
    }

    pub fn call_static_frame(instance: *runtime.Instance, input: JsonLdInput, frame: JsonLdInput, options: webidl.Opt(JsonLdOptions)) anyerror!runtime.JSValue {
        
        return try JsonLdProcessorImpl.call_static_frame(instance, input, frame, options);
    }

    pub fn call_static_flatten(instance: *runtime.Instance, input: JsonLdInput, context: webidl.Opt(JsonLdContext), options: webidl.Opt(JsonLdOptions)) anyerror!runtime.JSValue {
        
        return try JsonLdProcessorImpl.call_static_flatten(instance, input, context, options);
    }

};
