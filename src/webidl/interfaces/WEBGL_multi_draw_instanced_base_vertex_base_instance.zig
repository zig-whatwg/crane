//! Generated from: WEBGL_multi_draw_instanced_base_vertex_base_instance.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl = @import("impls").WEBGL_multi_draw_instanced_base_vertex_base_instance;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GLenum = @import("typedefs").GLenum;
const GLsizei = @import("typedefs").GLsizei;
const GLint = @import("typedefs").GLint;
const GLuint = @import("typedefs").GLuint;

pub const WEBGL_multi_draw_instanced_base_vertex_base_instance = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_multi_draw_instanced_base_vertex_base_instance";
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
            .{ "multiDrawArraysInstancedBaseInstanceWEBGL", "call_multiDrawArraysInstancedBaseInstanceWEBGL", 10 },
            .{ "multiDrawElementsInstancedBaseVertexBaseInstanceWEBGL", "call_multiDrawElementsInstancedBaseVertexBaseInstanceWEBGL", 13 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "multiDrawArraysInstancedBaseInstanceWEBGL",
            "multiDrawElementsInstancedBaseVertexBaseInstanceWEBGL",
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
            _internal: ?*WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_multiDrawArraysInstancedBaseInstanceWEBGL = &call_multiDrawArraysInstancedBaseInstanceWEBGL,
        .call_multiDrawElementsInstancedBaseVertexBaseInstanceWEBGL = &call_multiDrawElementsInstancedBaseVertexBaseInstanceWEBGL,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("WEBGL_multi_draw_instanced_base_vertex_base_instance has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl, "init") and @hasDecl(WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl, "initOwn")) @compileError("WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl defines both init and initOwn");
        if (comptime @hasDecl(WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl, "init")) return WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl, "init")) return false;
        if (comptime @hasDecl(WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl, "construction_args")) {
            inline for (WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl, "deinit") and @hasDecl(WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl, "deinitOwn")) @compileError("WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl, "deinit")) return WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl.deinit(instance);
        if (comptime @hasDecl(WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl, "deinitOwn")) WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "WEBGL_multi_draw_instanced_base_vertex_base_instance")) {
            if (comptime @hasDecl(impls.WEBGL_multi_draw_instanced_base_vertex_base_instance, "installHooks")) impls.WEBGL_multi_draw_instanced_base_vertex_base_instance.installHooks();
        }
    }

    pub fn call_multiDrawArraysInstancedBaseInstanceWEBGL(instance: *runtime.Instance, mode: GLenum, firstsList: runtime.JSValue, firstsOffset: u64, countsList: runtime.JSValue, countsOffset: u64, instanceCountsList: runtime.JSValue, instanceCountsOffset: u64, baseInstancesList: runtime.JSValue, baseInstancesOffset: u64, drawcount: GLsizei) anyerror!void {
        return try WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl.call_multiDrawArraysInstancedBaseInstanceWEBGL(instance, mode, firstsList, firstsOffset, countsList, countsOffset, instanceCountsList, instanceCountsOffset, baseInstancesList, baseInstancesOffset, drawcount);
    }

    pub fn call_multiDrawElementsInstancedBaseVertexBaseInstanceWEBGL(instance: *runtime.Instance, mode: GLenum, countsList: runtime.JSValue, countsOffset: u64, @"type": GLenum, offsetsList: runtime.JSValue, offsetsOffset: u64, instanceCountsList: runtime.JSValue, instanceCountsOffset: u64, baseVerticesList: runtime.JSValue, baseVerticesOffset: u64, baseInstancesList: runtime.JSValue, baseInstancesOffset: u64, drawcount: GLsizei) anyerror!void {
        return try WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl.call_multiDrawElementsInstancedBaseVertexBaseInstanceWEBGL(instance, mode, countsList, countsOffset, @"type", offsetsList, offsetsOffset, instanceCountsList, instanceCountsOffset, baseVerticesList, baseVerticesOffset, baseInstancesList, baseInstancesOffset, drawcount);
    }
};
