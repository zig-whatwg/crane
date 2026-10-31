//! Generated from: OES_draw_buffers_indexed.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const OES_draw_buffers_indexedImpl = @import("impls").OES_draw_buffers_indexed;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GLenum = @import("typedefs").GLenum;
const GLboolean = @import("typedefs").GLboolean;
const GLuint = @import("typedefs").GLuint;

pub const OES_draw_buffers_indexed = struct {
    pub const Meta = struct {
        pub const name = "OES_draw_buffers_indexed";
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
            .{ "enableiOES", "call_enableiOES", 2 },
            .{ "disableiOES", "call_disableiOES", 2 },
            .{ "blendEquationiOES", "call_blendEquationiOES", 2 },
            .{ "blendEquationSeparateiOES", "call_blendEquationSeparateiOES", 3 },
            .{ "blendFunciOES", "call_blendFunciOES", 3 },
            .{ "blendFuncSeparateiOES", "call_blendFuncSeparateiOES", 5 },
            .{ "colorMaskiOES", "call_colorMaskiOES", 5 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "enableiOES",
            "disableiOES",
            "blendEquationiOES",
            "blendEquationSeparateiOES",
            "blendFunciOES",
            "blendFuncSeparateiOES",
            "colorMaskiOES",
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
            _internal: ?*OES_draw_buffers_indexedImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_blendEquationSeparateiOES = &call_blendEquationSeparateiOES,
        .call_blendEquationiOES = &call_blendEquationiOES,
        .call_blendFuncSeparateiOES = &call_blendFuncSeparateiOES,
        .call_blendFunciOES = &call_blendFunciOES,
        .call_colorMaskiOES = &call_colorMaskiOES,
        .call_disableiOES = &call_disableiOES,
        .call_enableiOES = &call_enableiOES,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("OES_draw_buffers_indexed has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(OES_draw_buffers_indexedImpl, "init") and @hasDecl(OES_draw_buffers_indexedImpl, "initOwn")) @compileError("OES_draw_buffers_indexedImpl defines both init and initOwn");
        if (comptime @hasDecl(OES_draw_buffers_indexedImpl, "init")) return OES_draw_buffers_indexedImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(OES_draw_buffers_indexedImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try OES_draw_buffers_indexedImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(OES_draw_buffers_indexedImpl, "init")) return false;
        if (comptime @hasDecl(OES_draw_buffers_indexedImpl, "construction_args")) {
            inline for (OES_draw_buffers_indexedImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(OES_draw_buffers_indexedImpl, "deinit") and @hasDecl(OES_draw_buffers_indexedImpl, "deinitOwn")) @compileError("OES_draw_buffers_indexedImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(OES_draw_buffers_indexedImpl, "deinit")) return OES_draw_buffers_indexedImpl.deinit(instance);
        if (comptime @hasDecl(OES_draw_buffers_indexedImpl, "deinitOwn")) OES_draw_buffers_indexedImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "OES_draw_buffers_indexed")) {
            if (comptime @hasDecl(impls.OES_draw_buffers_indexed, "installHooks")) impls.OES_draw_buffers_indexed.installHooks();
        }
    }

    pub fn call_blendFunciOES(instance: *runtime.Instance, buf: GLuint, src: GLenum, dst: GLenum) anyerror!void {
        return try OES_draw_buffers_indexedImpl.call_blendFunciOES(instance, buf, src, dst);
    }

    pub fn call_enableiOES(instance: *runtime.Instance, target: GLenum, index: GLuint) anyerror!void {
        return try OES_draw_buffers_indexedImpl.call_enableiOES(instance, target, index);
    }

    pub fn call_blendEquationSeparateiOES(instance: *runtime.Instance, buf: GLuint, modeRGB: GLenum, modeAlpha: GLenum) anyerror!void {
        return try OES_draw_buffers_indexedImpl.call_blendEquationSeparateiOES(instance, buf, modeRGB, modeAlpha);
    }

    pub fn call_blendFuncSeparateiOES(instance: *runtime.Instance, buf: GLuint, srcRGB: GLenum, dstRGB: GLenum, srcAlpha: GLenum, dstAlpha: GLenum) anyerror!void {
        return try OES_draw_buffers_indexedImpl.call_blendFuncSeparateiOES(instance, buf, srcRGB, dstRGB, srcAlpha, dstAlpha);
    }

    pub fn call_blendEquationiOES(instance: *runtime.Instance, buf: GLuint, mode: GLenum) anyerror!void {
        return try OES_draw_buffers_indexedImpl.call_blendEquationiOES(instance, buf, mode);
    }

    pub fn call_colorMaskiOES(instance: *runtime.Instance, buf: GLuint, r: GLboolean, g: GLboolean, b: GLboolean, a: GLboolean) anyerror!void {
        return try OES_draw_buffers_indexedImpl.call_colorMaskiOES(instance, buf, r, g, b, a);
    }

    pub fn call_disableiOES(instance: *runtime.Instance, target: GLenum, index: GLuint) anyerror!void {
        return try OES_draw_buffers_indexedImpl.call_disableiOES(instance, target, index);
    }
};
