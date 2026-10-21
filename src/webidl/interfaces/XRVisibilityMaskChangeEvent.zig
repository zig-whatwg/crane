//! Generated from: webxr.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRVisibilityMaskChangeEventImpl = @import("impls").XRVisibilityMaskChangeEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Event = @import("interfaces").Event;
const EventTarget = @import("interfaces").EventTarget;
const XRSession = @import("interfaces").XRSession;
const XRVisibilityMaskChangeEventInit = @import("dictionaries").XRVisibilityMaskChangeEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const XREye = @import("enums").XREye;
const DOMString = @import("typedefs").DOMString;

pub const XRVisibilityMaskChangeEvent = struct {
    pub const Meta = struct {
        pub const name = "XRVisibilityMaskChangeEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "session", "get_session", null },
            .{ "eye", "get_eye", null },
            .{ "index", "get_index", null },
            .{ "vertices", "get_vertices", null },
            .{ "indices", "get_indices", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "session", "get_session", null },
            .{ "eye", "get_eye", null },
            .{ "index", "get_index", null },
            .{ "vertices", "get_vertices", null },
            .{ "indices", "get_indices", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            session: *runtime.Instance = undefined,
            eye: enums.XREye = undefined,
            index: u32 = undefined,
            vertices: runtime.Float32Array = undefined,
            indices: runtime.Uint32Array = undefined,
            cached_session: ?*runtime.Instance = null,
            cached_vertices: ?runtime.JSValue = null,
            cached_indices: ?runtime.JSValue = null,
            _internal: ?*XRVisibilityMaskChangeEventImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_eye = &get_eye,
        .get_index = &get_index,
        .get_indices = &get_indices,
        .get_session = &get_session,
        .get_vertices = &get_vertices,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Make a new instance: the construction chain, this interface's State
    /// and vtable.
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return initChain(allocator, State, &vtable, ctx, .{});
    }

    /// Make a new instance with construction arguments: facts given at
    /// construction, as a C++ constructor's parameters. Each field of `args`
    /// must be taken by an impl on the chain (its `construction_args`).
    pub fn initWith(allocator: std.mem.Allocator, ctx: runtime.Context, args: anytype) !*runtime.Instance {
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("XRVisibilityMaskChangeEvent has no construction argument '" ++ field.name ++ "'");
        }
        return initChain(allocator, State, &vtable, ctx, args);
    }

    /// The construction chain for a descendant's State and vtable, for an
    /// impl that still chains by hand.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return initChain(allocator, StateType, vtable_ptr, ctx, .{});
    }

    /// The construction chain: the parent interface's, then the impl's own
    /// steps (`initOwn`), whose failure unwinds the parent's part and frees
    /// the slot. An impl that still defines `init` chains by hand.
    pub inline fn initChain(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
        args: anytype,
    ) !*runtime.Instance {
        if (comptime @hasDecl(XRVisibilityMaskChangeEventImpl, "init") and @hasDecl(XRVisibilityMaskChangeEventImpl, "initOwn")) @compileError("XRVisibilityMaskChangeEventImpl defines both init and initOwn");
        if (comptime @hasDecl(XRVisibilityMaskChangeEventImpl, "init")) return XRVisibilityMaskChangeEventImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(XRVisibilityMaskChangeEventImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try XRVisibilityMaskChangeEventImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XRVisibilityMaskChangeEventImpl, "init")) return false;
        if (comptime @hasDecl(XRVisibilityMaskChangeEventImpl, "construction_args")) {
            inline for (XRVisibilityMaskChangeEventImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return Meta.ParentInterface.takesConstructionArg(name);
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(XRVisibilityMaskChangeEventImpl, "deinit") and @hasDecl(XRVisibilityMaskChangeEventImpl, "deinitOwn")) @compileError("XRVisibilityMaskChangeEventImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(XRVisibilityMaskChangeEventImpl, "deinit")) return XRVisibilityMaskChangeEventImpl.deinit(instance);
        if (comptime @hasDecl(XRVisibilityMaskChangeEventImpl, "deinitOwn")) XRVisibilityMaskChangeEventImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XRVisibilityMaskChangeEvent")) {
            if (comptime @hasDecl(impls.XRVisibilityMaskChangeEvent, "installHooks")) impls.XRVisibilityMaskChangeEvent.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 2;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: XRVisibilityMaskChangeEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try XRVisibilityMaskChangeEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    /// Extended attributes: [SameObject]
    pub fn get_session(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_session) |cached| {
            return cached;
        }
        const value = try XRVisibilityMaskChangeEventImpl.get_session(instance);
        state.own.cached_session = value;
        @import("dom").same_object_cache.made(instance, value, "session");
        return value;
    }

    pub fn get_eye(instance: *runtime.Instance) anyerror!XREye {
        return try XRVisibilityMaskChangeEventImpl.get_eye(instance);
    }

    pub fn get_index(instance: *runtime.Instance) anyerror!u32 {
        return try XRVisibilityMaskChangeEventImpl.get_index(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_vertices(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try XRVisibilityMaskChangeEventImpl.get_vertices(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_indices(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try XRVisibilityMaskChangeEventImpl.get_indices(instance);
    }
};
