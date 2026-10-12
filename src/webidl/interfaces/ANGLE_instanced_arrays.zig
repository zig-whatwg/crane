//! Generated from: ANGLE_instanced_arrays.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ANGLE_instanced_arraysImpl = @import("impls").ANGLE_instanced_arrays;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GLenum = @import("typedefs").GLenum;
const GLint = @import("typedefs").GLint;
const GLintptr = @import("typedefs").GLintptr;
const GLsizei = @import("typedefs").GLsizei;
const GLuint = @import("typedefs").GLuint;

pub const ANGLE_instanced_arrays = struct {
    pub const Meta = struct {
        pub const name = "ANGLE_instanced_arrays";
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
            .{ "drawArraysInstancedANGLE", "call_drawArraysInstancedANGLE", 4 },
            .{ "drawElementsInstancedANGLE", "call_drawElementsInstancedANGLE", 5 },
            .{ "vertexAttribDivisorANGLE", "call_vertexAttribDivisorANGLE", 2 },
        };

        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "VERTEX_ATTRIB_ARRAY_DIVISOR_ANGLE", "get_VERTEX_ATTRIB_ARRAY_DIVISOR_ANGLE" },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "drawArraysInstancedANGLE",
            "drawElementsInstancedANGLE",
            "vertexAttribDivisorANGLE",
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
            _internal: ?*ANGLE_instanced_arraysImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum VERTEX_ATTRIB_ARRAY_DIVISOR_ANGLE = 35070;
    pub fn get_VERTEX_ATTRIB_ARRAY_DIVISOR_ANGLE() GLenum {
        return 35070;
    }

    const delegates = .{
        .get_VERTEX_ATTRIB_ARRAY_DIVISOR_ANGLE = &get_VERTEX_ATTRIB_ARRAY_DIVISOR_ANGLE,

        .call_drawArraysInstancedANGLE = &call_drawArraysInstancedANGLE,
        .call_drawElementsInstancedANGLE = &call_drawElementsInstancedANGLE,
        .call_vertexAttribDivisorANGLE = &call_vertexAttribDivisorANGLE,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("ANGLE_instanced_arrays has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(ANGLE_instanced_arraysImpl, "init") and @hasDecl(ANGLE_instanced_arraysImpl, "initOwn")) @compileError("ANGLE_instanced_arraysImpl defines both init and initOwn");
        if (comptime @hasDecl(ANGLE_instanced_arraysImpl, "init")) return ANGLE_instanced_arraysImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(ANGLE_instanced_arraysImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try ANGLE_instanced_arraysImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ANGLE_instanced_arraysImpl, "init")) return false;
        if (comptime @hasDecl(ANGLE_instanced_arraysImpl, "construction_args")) {
            inline for (ANGLE_instanced_arraysImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ANGLE_instanced_arraysImpl, "deinit") and @hasDecl(ANGLE_instanced_arraysImpl, "deinitOwn")) @compileError("ANGLE_instanced_arraysImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ANGLE_instanced_arraysImpl, "deinit")) return ANGLE_instanced_arraysImpl.deinit(instance);
        if (comptime @hasDecl(ANGLE_instanced_arraysImpl, "deinitOwn")) ANGLE_instanced_arraysImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ANGLE_instanced_arrays")) {
            if (comptime @hasDecl(impls.ANGLE_instanced_arrays, "installHooks")) impls.ANGLE_instanced_arrays.installHooks();
        }
    }

    pub fn call_drawArraysInstancedANGLE(instance: *runtime.Instance, mode: GLenum, first: GLint, count: GLsizei, primcount: GLsizei) anyerror!void {
        return try ANGLE_instanced_arraysImpl.call_drawArraysInstancedANGLE(instance, mode, first, count, primcount);
    }

    pub fn call_drawElementsInstancedANGLE(instance: *runtime.Instance, mode: GLenum, count: GLsizei, @"type": GLenum, offset: GLintptr, primcount: GLsizei) anyerror!void {
        return try ANGLE_instanced_arraysImpl.call_drawElementsInstancedANGLE(instance, mode, count, @"type", offset, primcount);
    }

    pub fn call_vertexAttribDivisorANGLE(instance: *runtime.Instance, index: GLuint, divisor: GLuint) anyerror!void {
        return try ANGLE_instanced_arraysImpl.call_vertexAttribDivisorANGLE(instance, index, divisor);
    }
};
