//! Generated from: WEBGL_provoking_vertex.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WEBGL_provoking_vertexImpl = @import("impls").WEBGL_provoking_vertex;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GLenum = @import("typedefs").GLenum;

pub const WEBGL_provoking_vertex = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_provoking_vertex";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "LegacyNoInterfaceObject" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "provokingVertexWEBGL", "call_provokingVertexWEBGL", 1 },
        };

        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "FIRST_VERTEX_CONVENTION_WEBGL", "get_FIRST_VERTEX_CONVENTION_WEBGL" },
            .{ "LAST_VERTEX_CONVENTION_WEBGL", "get_LAST_VERTEX_CONVENTION_WEBGL" },
            .{ "PROVOKING_VERTEX_WEBGL", "get_PROVOKING_VERTEX_WEBGL" },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "provokingVertexWEBGL",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*WEBGL_provoking_vertexImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum FIRST_VERTEX_CONVENTION_WEBGL = 36429;
    pub fn get_FIRST_VERTEX_CONVENTION_WEBGL() GLenum {
        return 36429;
    }

    /// WebIDL constant: const GLenum LAST_VERTEX_CONVENTION_WEBGL = 36430;
    pub fn get_LAST_VERTEX_CONVENTION_WEBGL() GLenum {
        return 36430;
    }

    /// WebIDL constant: const GLenum PROVOKING_VERTEX_WEBGL = 36431;
    pub fn get_PROVOKING_VERTEX_WEBGL() GLenum {
        return 36431;
    }

    const delegates = .{
        .get_FIRST_VERTEX_CONVENTION_WEBGL = &get_FIRST_VERTEX_CONVENTION_WEBGL,
        .get_LAST_VERTEX_CONVENTION_WEBGL = &get_LAST_VERTEX_CONVENTION_WEBGL,
        .get_PROVOKING_VERTEX_WEBGL = &get_PROVOKING_VERTEX_WEBGL,

        .call_provokingVertexWEBGL = &call_provokingVertexWEBGL,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("WEBGL_provoking_vertex has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(WEBGL_provoking_vertexImpl, "init") and @hasDecl(WEBGL_provoking_vertexImpl, "initOwn")) @compileError("WEBGL_provoking_vertexImpl defines both init and initOwn");
        if (comptime @hasDecl(WEBGL_provoking_vertexImpl, "init")) return WEBGL_provoking_vertexImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(WEBGL_provoking_vertexImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try WEBGL_provoking_vertexImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(WEBGL_provoking_vertexImpl, "init")) return false;
        if (comptime @hasDecl(WEBGL_provoking_vertexImpl, "construction_args")) {
            inline for (WEBGL_provoking_vertexImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(WEBGL_provoking_vertexImpl, "deinit") and @hasDecl(WEBGL_provoking_vertexImpl, "deinitOwn")) @compileError("WEBGL_provoking_vertexImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(WEBGL_provoking_vertexImpl, "deinit")) return WEBGL_provoking_vertexImpl.deinit(instance);
        if (comptime @hasDecl(WEBGL_provoking_vertexImpl, "deinitOwn")) WEBGL_provoking_vertexImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "WEBGL_provoking_vertex")) {
            if (comptime @hasDecl(impls.WEBGL_provoking_vertex, "installHooks")) impls.WEBGL_provoking_vertex.installHooks();
        }
    }

    pub fn call_provokingVertexWEBGL(instance: *runtime.Instance, provokeMode: GLenum) anyerror!void {
        return try WEBGL_provoking_vertexImpl.call_provokingVertexWEBGL(instance, provokeMode);
    }
};
