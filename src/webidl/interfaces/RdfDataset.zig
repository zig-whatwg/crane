//! Generated from: json-ld-api.idl
//! Generated at: 2025-11-28T03:24:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RdfDatasetImpl = @import("impls").RdfDataset;
const RdfGraph = @import("interfaces").RdfGraph;
const USVString = @import("interfaces").USVString;

pub const RdfDataset = struct {
    pub const Meta = struct {
        pub const name = "RdfDataset";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "defaultGraph", "get_defaultGraph", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "add", "call_add", 2 },
            .{ "forEach", "call_forEach", 1 },
            .{ "forEach", "call_forEach", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "add",
            "forEach",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "defaultGraph", "get_defaultGraph", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
        
        /// Iterable declaration (for Symbol.iterator support)
        pub const iterable = .{
            .value_type = "runtime.USVString",
            .key_type = "RdfGraph",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            defaultGraph: *runtime.Instance = undefined,
            _internal: ?*RdfDatasetImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_defaultGraph = &get_defaultGraph,

        .call_add = &call_add,
        .call_forEach = &call_forEach,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RdfDatasetImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RdfDatasetImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try RdfDatasetImpl.call_constructor(allocator, ctx);
    }

    pub fn get_defaultGraph(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RdfDatasetImpl.get_defaultGraph(instance);
    }

    pub fn call_add(instance: *runtime.Instance, graphName: runtime.USVString, graph: *runtime.Instance) anyerror!void {
        
        return try RdfDatasetImpl.call_add(instance, graphName, graph);
    }

    pub fn call_forEach(instance: *runtime.Instance, callback: *const anyopaque) anyerror!void {
        
        return try RdfDatasetImpl.call_forEach(instance, callback);
    }

};
