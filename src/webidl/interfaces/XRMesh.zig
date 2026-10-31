//! Generated from: real-world-meshing.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRMeshImpl = @import("impls").XRMesh;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const DOMString = @import("typedefs").DOMString;
const XRSpace = @import("interfaces").XRSpace;

pub const XRMesh = struct {
    pub const Meta = struct {
        pub const name = "XRMesh";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "meshSpace", "get_meshSpace", null },
            .{ "vertices", "get_vertices", null },
            .{ "indices", "get_indices", null },
            .{ "lastChangedTime", "get_lastChangedTime", null },
            .{ "semanticLabel", "get_semanticLabel", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "meshSpace", "get_meshSpace", null },
            .{ "vertices", "get_vertices", null },
            .{ "indices", "get_indices", null },
            .{ "lastChangedTime", "get_lastChangedTime", null },
            .{ "semanticLabel", "get_semanticLabel", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            meshSpace: *runtime.Instance = undefined,
            vertices: runtime.Float32Array = undefined,
            indices: runtime.Uint32Array = undefined,
            lastChangedTime: typedefs.DOMHighResTimeStamp = undefined,
            semanticLabel: ?runtime.DOMString = null,
            cached_meshSpace: ?*runtime.Instance = null,
            _internal: ?*XRMeshImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_indices = &get_indices,
        .get_lastChangedTime = &get_lastChangedTime,
        .get_meshSpace = &get_meshSpace,
        .get_semanticLabel = &get_semanticLabel,
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
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("XRMesh has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(XRMeshImpl, "init") and @hasDecl(XRMeshImpl, "initOwn")) @compileError("XRMeshImpl defines both init and initOwn");
        if (comptime @hasDecl(XRMeshImpl, "init")) return XRMeshImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(XRMeshImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try XRMeshImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XRMeshImpl, "init")) return false;
        if (comptime @hasDecl(XRMeshImpl, "construction_args")) {
            inline for (XRMeshImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return false;
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(XRMeshImpl, "deinit") and @hasDecl(XRMeshImpl, "deinitOwn")) @compileError("XRMeshImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(XRMeshImpl, "deinit")) return XRMeshImpl.deinit(instance);
        if (comptime @hasDecl(XRMeshImpl, "deinitOwn")) XRMeshImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XRMesh")) {
            if (comptime @hasDecl(impls.XRMesh, "installHooks")) impls.XRMesh.installHooks();
        }
    }

    /// Extended attributes: [SameObject]
    pub fn get_meshSpace(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_meshSpace) |cached| {
            return cached;
        }
        const value = try XRMeshImpl.get_meshSpace(instance);
        state.own.cached_meshSpace = value;
        @import("dom").same_object_cache.made(instance, value, "meshSpace");
        return value;
    }

    pub fn get_vertices(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try XRMeshImpl.get_vertices(instance);
    }

    pub fn get_indices(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try XRMeshImpl.get_indices(instance);
    }

    pub fn get_lastChangedTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try XRMeshImpl.get_lastChangedTime(instance);
    }

    pub fn get_semanticLabel(instance: *runtime.Instance) anyerror!?runtime.DOMString {
        return try XRMeshImpl.get_semanticLabel(instance);
    }
};
