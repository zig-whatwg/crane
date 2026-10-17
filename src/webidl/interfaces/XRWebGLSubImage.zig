//! Generated from: webxrlayers.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRWebGLSubImageImpl = @import("impls").XRWebGLSubImage;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XRSubImage = @import("interfaces").XRSubImage;
const XRViewport = @import("interfaces").XRViewport;
const WebGLTexture = @import("interfaces").WebGLTexture;

pub const XRWebGLSubImage = struct {
    pub const Meta = struct {
        pub const name = "XRWebGLSubImage";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = XRSubImage.State;
        pub const ParentInterface = XRSubImage;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "colorTexture", "get_colorTexture", null },
            .{ "depthStencilTexture", "get_depthStencilTexture", null },
            .{ "motionVectorTexture", "get_motionVectorTexture", null },
            .{ "imageIndex", "get_imageIndex", null },
            .{ "colorTextureWidth", "get_colorTextureWidth", null },
            .{ "colorTextureHeight", "get_colorTextureHeight", null },
            .{ "depthStencilTextureWidth", "get_depthStencilTextureWidth", null },
            .{ "depthStencilTextureHeight", "get_depthStencilTextureHeight", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "colorTexture", "get_colorTexture", null },
            .{ "depthStencilTexture", "get_depthStencilTexture", null },
            .{ "motionVectorTexture", "get_motionVectorTexture", null },
            .{ "imageIndex", "get_imageIndex", null },
            .{ "colorTextureWidth", "get_colorTextureWidth", null },
            .{ "colorTextureHeight", "get_colorTextureHeight", null },
            .{ "depthStencilTextureWidth", "get_depthStencilTextureWidth", null },
            .{ "depthStencilTextureHeight", "get_depthStencilTextureHeight", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            colorTexture: *runtime.Instance = undefined,
            depthStencilTexture: ?*runtime.Instance = null,
            motionVectorTexture: ?*runtime.Instance = null,
            imageIndex: ?u32 = null,
            colorTextureWidth: u32 = undefined,
            colorTextureHeight: u32 = undefined,
            depthStencilTextureWidth: ?u32 = null,
            depthStencilTextureHeight: ?u32 = null,
            cached_colorTexture: ?*runtime.Instance = null,
            cached_depthStencilTexture: ?*runtime.Instance = null,
            cached_motionVectorTexture: ?*runtime.Instance = null,
            _internal: ?*XRWebGLSubImageImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_colorTexture = &get_colorTexture,
        .get_colorTextureHeight = &get_colorTextureHeight,
        .get_colorTextureWidth = &get_colorTextureWidth,
        .get_depthStencilTexture = &get_depthStencilTexture,
        .get_depthStencilTextureHeight = &get_depthStencilTextureHeight,
        .get_depthStencilTextureWidth = &get_depthStencilTextureWidth,
        .get_imageIndex = &get_imageIndex,
        .get_motionVectorTexture = &get_motionVectorTexture,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("XRWebGLSubImage has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(XRWebGLSubImageImpl, "init") and @hasDecl(XRWebGLSubImageImpl, "initOwn")) @compileError("XRWebGLSubImageImpl defines both init and initOwn");
        if (comptime @hasDecl(XRWebGLSubImageImpl, "init")) return XRWebGLSubImageImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(XRWebGLSubImageImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try XRWebGLSubImageImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XRWebGLSubImageImpl, "init")) return false;
        if (comptime @hasDecl(XRWebGLSubImageImpl, "construction_args")) {
            inline for (XRWebGLSubImageImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XRWebGLSubImageImpl, "deinit") and @hasDecl(XRWebGLSubImageImpl, "deinitOwn")) @compileError("XRWebGLSubImageImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(XRWebGLSubImageImpl, "deinit")) return XRWebGLSubImageImpl.deinit(instance);
        if (comptime @hasDecl(XRWebGLSubImageImpl, "deinitOwn")) XRWebGLSubImageImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XRWebGLSubImage")) {
            if (comptime @hasDecl(impls.XRWebGLSubImage, "installHooks")) impls.XRWebGLSubImage.installHooks();
        }
    }

    /// Extended attributes: [SameObject]
    pub fn get_colorTexture(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_colorTexture) |cached| {
            return cached;
        }
        const value = try XRWebGLSubImageImpl.get_colorTexture(instance);
        state.own.cached_colorTexture = value;
        @import("dom").same_object_cache.made(instance, value, "colorTexture");
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_depthStencilTexture(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_depthStencilTexture) |cached| {
            return cached;
        }
        const value = try XRWebGLSubImageImpl.get_depthStencilTexture(instance);
        state.own.cached_depthStencilTexture = value;
        if (value) |child| @import("dom").same_object_cache.made(instance, child, "depthStencilTexture");
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_motionVectorTexture(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_motionVectorTexture) |cached| {
            return cached;
        }
        const value = try XRWebGLSubImageImpl.get_motionVectorTexture(instance);
        state.own.cached_motionVectorTexture = value;
        if (value) |child| @import("dom").same_object_cache.made(instance, child, "motionVectorTexture");
        return value;
    }

    pub fn get_imageIndex(instance: *runtime.Instance) anyerror!?u32 {
        return try XRWebGLSubImageImpl.get_imageIndex(instance);
    }

    pub fn get_colorTextureWidth(instance: *runtime.Instance) anyerror!u32 {
        return try XRWebGLSubImageImpl.get_colorTextureWidth(instance);
    }

    pub fn get_colorTextureHeight(instance: *runtime.Instance) anyerror!u32 {
        return try XRWebGLSubImageImpl.get_colorTextureHeight(instance);
    }

    pub fn get_depthStencilTextureWidth(instance: *runtime.Instance) anyerror!?u32 {
        return try XRWebGLSubImageImpl.get_depthStencilTextureWidth(instance);
    }

    pub fn get_depthStencilTextureHeight(instance: *runtime.Instance) anyerror!?u32 {
        return try XRWebGLSubImageImpl.get_depthStencilTextureHeight(instance);
    }
};
