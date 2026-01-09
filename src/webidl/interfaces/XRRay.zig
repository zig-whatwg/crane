//! Generated from: webxr-hit-test.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRRayImpl = @import("impls").XRRay;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMPointInit = @import("dictionaries").DOMPointInit;
const XRRigidTransform = @import("XRRigidTransform.zig").XRRigidTransform;
const XRRayDirectionInit = @import("dictionaries").XRRayDirectionInit;
const DOMPointReadOnly = @import("DOMPointReadOnly.zig").DOMPointReadOnly;

pub const XRRay = struct {
    pub const Meta = struct {
        pub const name = "XRRay";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "origin", "get_origin", null },
            .{ "direction", "get_direction", null },
            .{ "matrix", "get_matrix", null },
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
            .{ "origin", "get_origin", null },
            .{ "direction", "get_direction", null },
            .{ "matrix", "get_matrix", null },
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
            origin: *runtime.Instance = undefined,
            direction: *runtime.Instance = undefined,
            matrix: runtime.Float32Array = undefined,
            cached_origin: ?*runtime.Instance = null,
            cached_direction: ?*runtime.Instance = null,
            cached_matrix: ?runtime.JSValue = null,
            _internal: ?*XRRayImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_direction = &get_direction,
        .get_matrix = &get_matrix,
        .get_origin = &get_origin,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRRayImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return XRRayImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRRayImpl.deinit(instance);
    }

    /// Arguments for constructor (WebIDL overloading)
    pub const ConstructorArgs = union(enum) {
        /// constructor(origin, direction)
        DOMPointInit_XRRayDirectionInit: struct {
            origin: webidl.Opt(DOMPointInit),
            direction: webidl.Opt(XRRayDirectionInit),
        },
        /// constructor(transform)
        XRRigidTransform: XRRigidTransform,
    };

    /// WebIDL constructor (overloaded)
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, args: ConstructorArgs) !*runtime.Instance {
        // Pass args union directly to impl
        return try XRRayImpl.call_constructor(ctx, args);
    }

    /// Extended attributes: [SameObject]
    pub fn get_origin(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_origin) |cached| {
            return cached;
        }
        const value = try XRRayImpl.get_origin(instance);
        state.own.cached_origin = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_direction(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_direction) |cached| {
            return cached;
        }
        const value = try XRRayImpl.get_direction(instance);
        state.own.cached_direction = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_matrix(instance: *runtime.Instance) anyerror!runtime.JSValue {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_matrix) |cached| {
            return cached;
        }
        const value = try XRRayImpl.get_matrix(instance);
        state.own.cached_matrix = value;
        return value;
    }

};
