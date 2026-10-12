//! Generated from: OVR_multiview2.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const OVR_multiview2Impl = @import("impls").OVR_multiview2;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GLenum = @import("typedefs").GLenum;
const GLint = @import("typedefs").GLint;
const GLsizei = @import("typedefs").GLsizei;
const WebGLTexture = @import("interfaces").WebGLTexture;

pub const OVR_multiview2 = struct {
    pub const Meta = struct {
        pub const name = "OVR_multiview2";
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
            .{ "framebufferTextureMultiviewOVR", "call_framebufferTextureMultiviewOVR", 6 },
        };

        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "FRAMEBUFFER_ATTACHMENT_TEXTURE_NUM_VIEWS_OVR", "get_FRAMEBUFFER_ATTACHMENT_TEXTURE_NUM_VIEWS_OVR" },
            .{ "FRAMEBUFFER_ATTACHMENT_TEXTURE_BASE_VIEW_INDEX_OVR", "get_FRAMEBUFFER_ATTACHMENT_TEXTURE_BASE_VIEW_INDEX_OVR" },
            .{ "MAX_VIEWS_OVR", "get_MAX_VIEWS_OVR" },
            .{ "FRAMEBUFFER_INCOMPLETE_VIEW_TARGETS_OVR", "get_FRAMEBUFFER_INCOMPLETE_VIEW_TARGETS_OVR" },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "framebufferTextureMultiviewOVR",
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
            _internal: ?*OVR_multiview2Impl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum FRAMEBUFFER_ATTACHMENT_TEXTURE_NUM_VIEWS_OVR = 38448;
    pub fn get_FRAMEBUFFER_ATTACHMENT_TEXTURE_NUM_VIEWS_OVR() GLenum {
        return 38448;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_ATTACHMENT_TEXTURE_BASE_VIEW_INDEX_OVR = 38450;
    pub fn get_FRAMEBUFFER_ATTACHMENT_TEXTURE_BASE_VIEW_INDEX_OVR() GLenum {
        return 38450;
    }

    /// WebIDL constant: const GLenum MAX_VIEWS_OVR = 38449;
    pub fn get_MAX_VIEWS_OVR() GLenum {
        return 38449;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_INCOMPLETE_VIEW_TARGETS_OVR = 38451;
    pub fn get_FRAMEBUFFER_INCOMPLETE_VIEW_TARGETS_OVR() GLenum {
        return 38451;
    }

    const delegates = .{
        .get_FRAMEBUFFER_ATTACHMENT_TEXTURE_BASE_VIEW_INDEX_OVR = &get_FRAMEBUFFER_ATTACHMENT_TEXTURE_BASE_VIEW_INDEX_OVR,
        .get_FRAMEBUFFER_ATTACHMENT_TEXTURE_NUM_VIEWS_OVR = &get_FRAMEBUFFER_ATTACHMENT_TEXTURE_NUM_VIEWS_OVR,
        .get_FRAMEBUFFER_INCOMPLETE_VIEW_TARGETS_OVR = &get_FRAMEBUFFER_INCOMPLETE_VIEW_TARGETS_OVR,
        .get_MAX_VIEWS_OVR = &get_MAX_VIEWS_OVR,

        .call_framebufferTextureMultiviewOVR = &call_framebufferTextureMultiviewOVR,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("OVR_multiview2 has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(OVR_multiview2Impl, "init") and @hasDecl(OVR_multiview2Impl, "initOwn")) @compileError("OVR_multiview2Impl defines both init and initOwn");
        if (comptime @hasDecl(OVR_multiview2Impl, "init")) return OVR_multiview2Impl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(OVR_multiview2Impl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try OVR_multiview2Impl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(OVR_multiview2Impl, "init")) return false;
        if (comptime @hasDecl(OVR_multiview2Impl, "construction_args")) {
            inline for (OVR_multiview2Impl.construction_args) |arg| {
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
        if (comptime @hasDecl(OVR_multiview2Impl, "deinit") and @hasDecl(OVR_multiview2Impl, "deinitOwn")) @compileError("OVR_multiview2Impl defines both deinit and deinitOwn");
        if (comptime @hasDecl(OVR_multiview2Impl, "deinit")) return OVR_multiview2Impl.deinit(instance);
        if (comptime @hasDecl(OVR_multiview2Impl, "deinitOwn")) OVR_multiview2Impl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "OVR_multiview2")) {
            if (comptime @hasDecl(impls.OVR_multiview2, "installHooks")) impls.OVR_multiview2.installHooks();
        }
    }

    pub fn call_framebufferTextureMultiviewOVR(instance: *runtime.Instance, target: GLenum, attachment: GLenum, texture: ?*runtime.Instance, level: GLint, baseViewIndex: GLint, numViews: GLsizei) anyerror!void {
        return try OVR_multiview2Impl.call_framebufferTextureMultiviewOVR(instance, target, attachment, texture, level, baseViewIndex, numViews);
    }
};
