//! Generated from: webxr-depth-sensing.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRWebGLDepthInformationImpl = @import("impls").XRWebGLDepthInformation;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XRDepthInformation = @import("interfaces").XRDepthInformation;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const XRTextureType = @import("enums").XRTextureType;
const WebGLTexture = @import("interfaces").WebGLTexture;

pub const XRWebGLDepthInformation = struct {
    pub const Meta = struct {
        pub const name = "XRWebGLDepthInformation";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = XRDepthInformation.State;
        pub const ParentInterface = XRDepthInformation;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "texture", "get_texture", null },
            .{ "textureType", "get_textureType", null },
            .{ "imageIndex", "get_imageIndex", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "texture", "get_texture", null },
            .{ "textureType", "get_textureType", null },
            .{ "imageIndex", "get_imageIndex", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            texture: *runtime.Instance = undefined,
            textureType: enums.XRTextureType = undefined,
            imageIndex: ?u32 = null,
            cached_texture: ?*runtime.Instance = null,
            _internal: ?*XRWebGLDepthInformationImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_imageIndex = &get_imageIndex,
        .get_texture = &get_texture,
        .get_textureType = &get_textureType,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("XRWebGLDepthInformation has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(XRWebGLDepthInformationImpl, "init") and @hasDecl(XRWebGLDepthInformationImpl, "initOwn")) @compileError("XRWebGLDepthInformationImpl defines both init and initOwn");
        if (comptime @hasDecl(XRWebGLDepthInformationImpl, "init")) return XRWebGLDepthInformationImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(XRWebGLDepthInformationImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try XRWebGLDepthInformationImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XRWebGLDepthInformationImpl, "init")) return false;
        if (comptime @hasDecl(XRWebGLDepthInformationImpl, "construction_args")) {
            inline for (XRWebGLDepthInformationImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XRWebGLDepthInformationImpl, "deinit") and @hasDecl(XRWebGLDepthInformationImpl, "deinitOwn")) @compileError("XRWebGLDepthInformationImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(XRWebGLDepthInformationImpl, "deinit")) return XRWebGLDepthInformationImpl.deinit(instance);
        if (comptime @hasDecl(XRWebGLDepthInformationImpl, "deinitOwn")) XRWebGLDepthInformationImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XRWebGLDepthInformation")) {
            if (comptime @hasDecl(impls.XRWebGLDepthInformation, "installHooks")) impls.XRWebGLDepthInformation.installHooks();
        }
    }

    /// Extended attributes: [SameObject]
    pub fn get_texture(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_texture) |cached| {
            return cached;
        }
        const value = try XRWebGLDepthInformationImpl.get_texture(instance);
        state.own.cached_texture = value;
        @import("dom").same_object_cache.made(instance, value, "texture");
        return value;
    }

    pub fn get_textureType(instance: *runtime.Instance) anyerror!XRTextureType {
        return try XRWebGLDepthInformationImpl.get_textureType(instance);
    }

    pub fn get_imageIndex(instance: *runtime.Instance) anyerror!?u32 {
        return try XRWebGLDepthInformationImpl.get_imageIndex(instance);
    }
};
