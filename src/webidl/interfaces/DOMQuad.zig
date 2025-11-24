//! Generated from: geometry.idl
//! Generated at: 2025-11-24T18:47:07Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DOMQuadImpl = @import("impls").DOMQuad;
const DOMPoint = @import("interfaces").DOMPoint;
const DOMRect = @import("interfaces").DOMRect;
const DOMRectInit = @import("dictionaries").DOMRectInit;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const DOMPointInit = @import("dictionaries").DOMPointInit;

pub const DOMQuad = struct {
    pub const Meta = struct {
        pub const name = "DOMQuad";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "p1", "get_p1", null },
            .{ "p2", "get_p2", null },
            .{ "p3", "get_p3", null },
            .{ "p4", "get_p4", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "fromRect", "call_fromRect", 0 },
            .{ "fromQuad", "call_fromQuad", 0 },
            .{ "getBounds", "call_getBounds", 0 },
            .{ "toJSON", "call_toJSON", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "fromRect",
            "fromQuad",
            "getBounds",
            "toJSON",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "p1", "get_p1", null },
            .{ "p2", "get_p2", null },
            .{ "p3", "get_p3", null },
            .{ "p4", "get_p4", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            p1: *runtime.Instance = undefined,
            p2: *runtime.Instance = undefined,
            p3: *runtime.Instance = undefined,
            p4: *runtime.Instance = undefined,
            cached_p1: ?*runtime.Instance = null,
            cached_p2: ?*runtime.Instance = null,
            cached_p3: ?*runtime.Instance = null,
            cached_p4: ?*runtime.Instance = null,
            _internal: ?*DOMQuadImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_p1 = &get_p1,
        .get_p2 = &get_p2,
        .get_p3 = &get_p3,
        .get_p4 = &get_p4,

        .call_fromQuad = &call_fromQuad,
        .call_fromRect = &call_fromRect,
        .call_getBounds = &call_getBounds,
        .call_toJSON = &call_toJSON,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DOMQuadImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DOMQuadImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, p1: DOMPointInit, p2: DOMPointInit, p3: DOMPointInit, p4: DOMPointInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try DOMQuadImpl.call_constructor(allocator, ctx, p1, p2, p3, p4);
    }

    /// Extended attributes: [SameObject]
    pub fn get_p1(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_p1) |cached| {
            return cached;
        }
        const value = try DOMQuadImpl.get_p1(instance);
        state.own.cached_p1 = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_p2(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_p2) |cached| {
            return cached;
        }
        const value = try DOMQuadImpl.get_p2(instance);
        state.own.cached_p2 = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_p3(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_p3) |cached| {
            return cached;
        }
        const value = try DOMQuadImpl.get_p3(instance);
        state.own.cached_p3 = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_p4(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_p4) |cached| {
            return cached;
        }
        const value = try DOMQuadImpl.get_p4(instance);
        state.own.cached_p4 = value;
        return value;
    }

    /// Extended attributes: [NewObject]
    pub fn call_getBounds(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try DOMQuadImpl.call_getBounds(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fromQuad(instance: *runtime.Instance, other: DOMQuadInit) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMQuadImpl.call_fromQuad(instance, other);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fromRect(instance: *runtime.Instance, other: DOMRectInit) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMQuadImpl.call_fromRect(instance, other);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try DOMQuadImpl.call_toJSON(instance);
    }

};
