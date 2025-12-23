//! Generated from: geometry.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DOMQuadImpl = @import("impls").DOMQuad;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMPoint = @import("interfaces").DOMPoint;
const DOMRect = @import("interfaces").DOMRect;
const DOMRectInit = @import("dictionaries").DOMRectInit;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const DOMPointInit = @import("dictionaries").DOMPointInit;

pub const DOMQuad = struct {
    pub const Meta = struct {
        pub const name = "DOMQuad";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getBounds", "call_getBounds", 0 },
            .{ "toJSON", "call_toJSON", 0 },
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "fromRect", "call_static_fromRect", 0 },
            .{ "fromQuad", "call_static_fromQuad", 0 },
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

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for DOMQuad
    /// Generated from [Default] toJSON extended attribute
    pub const DOMQuadToJSON = struct {
        p1: *runtime.Instance,
        p2: *runtime.Instance,
        p3: *runtime.Instance,
        p4: *runtime.Instance,
    };

    const delegates = .{

        .get_p1 = &get_p1,
        .get_p2 = &get_p2,
        .get_p3 = &get_p3,
        .get_p4 = &get_p4,

        .call_getBounds = &call_getBounds,
        .call_toJSON = &call_toJSON,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DOMQuadImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return DOMQuadImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DOMQuadImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, p1: webidl.Opt(DOMPointInit), p2: webidl.Opt(DOMPointInit), p3: webidl.Opt(DOMPointInit), p4: webidl.Opt(DOMPointInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try DOMQuadImpl.call_constructor(ctx, p1, p2, p3, p4);
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

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!DOMQuadToJSON {
        return try DOMQuadImpl.call_toJSON(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_static_fromRect(instance: *runtime.Instance, other: webidl.Opt(DOMRectInit)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMQuadImpl.call_static_fromRect(instance, other);
    }

    /// Extended attributes: [NewObject]
    pub fn call_static_fromQuad(instance: *runtime.Instance, other: webidl.Opt(DOMQuadInit)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMQuadImpl.call_static_fromQuad(instance, other);
    }

};
