//! Generated from: webxr-depth-sensing.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRDepthInformationImpl = @import("impls").XRDepthInformation;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XRViewGeometry = @import("mixins").XRViewGeometry;
const XRRigidTransform = @import("interfaces").XRRigidTransform;

pub const XRDepthInformation = struct {
    pub const Meta = struct {
        pub const name = "XRDepthInformation";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{
            XRViewGeometry,
        };
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "normDepthBufferFromNormView", "get_normDepthBufferFromNormView", null },
            .{ "rawValueToMeters", "get_rawValueToMeters", null },
            .{ "projectionMatrix", "get_projectionMatrix", null },
            .{ "transform", "get_transform", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "normDepthBufferFromNormView", "get_normDepthBufferFromNormView", null },
            .{ "rawValueToMeters", "get_rawValueToMeters", null },
            .{ "projectionMatrix", "get_projectionMatrix", null },
            .{ "transform", "get_transform", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// [SecureContext] members - their own, their partial interface's or
        /// their mixin's: hidden in a realm that is not a secure context
        /// (WebIDL 3.3.13).
        pub const secure_context_members = .{
            "projectionMatrix",
            "transform",
        };
        /// Member-level [Exposed] overrides; unlisted members inherit the interface.
        pub const exposed_members = .{
            .{ "projectionMatrix", .{"Window"} },
            .{ "transform", .{"Window"} },
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            width: u32 = undefined,
            height: u32 = undefined,
            normDepthBufferFromNormView: *runtime.Instance = undefined,
            rawValueToMeters: f32 = undefined,
            projectionMatrix: runtime.Float32Array = undefined,
            transform: *runtime.Instance = undefined,
            cached_normDepthBufferFromNormView: ?*runtime.Instance = null,
            cached_transform: ?*runtime.Instance = null,
            _internal: ?*XRDepthInformationImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_height = &get_height,
        .get_normDepthBufferFromNormView = &get_normDepthBufferFromNormView,
        .get_projectionMatrix = &get_projectionMatrix,
        .get_rawValueToMeters = &get_rawValueToMeters,
        .get_transform = &get_transform,
        .get_width = &get_width,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("XRDepthInformation has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(XRDepthInformationImpl, "init") and @hasDecl(XRDepthInformationImpl, "initOwn")) @compileError("XRDepthInformationImpl defines both init and initOwn");
        if (comptime @hasDecl(XRDepthInformationImpl, "init")) return XRDepthInformationImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(XRDepthInformationImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try XRDepthInformationImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XRDepthInformationImpl, "init")) return false;
        if (comptime @hasDecl(XRDepthInformationImpl, "construction_args")) {
            inline for (XRDepthInformationImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XRDepthInformationImpl, "deinit") and @hasDecl(XRDepthInformationImpl, "deinitOwn")) @compileError("XRDepthInformationImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(XRDepthInformationImpl, "deinit")) return XRDepthInformationImpl.deinit(instance);
        if (comptime @hasDecl(XRDepthInformationImpl, "deinitOwn")) XRDepthInformationImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XRDepthInformation")) {
            if (comptime @hasDecl(impls.XRDepthInformation, "installHooks")) impls.XRDepthInformation.installHooks();
        }
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!u32 {
        return try XRDepthInformationImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!u32 {
        return try XRDepthInformationImpl.get_height(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_normDepthBufferFromNormView(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_normDepthBufferFromNormView) |cached| {
            return cached;
        }
        const value = try XRDepthInformationImpl.get_normDepthBufferFromNormView(instance);
        state.own.cached_normDepthBufferFromNormView = value;
        @import("dom").same_object_cache.made(instance, value, "normDepthBufferFromNormView");
        return value;
    }

    pub fn get_rawValueToMeters(instance: *runtime.Instance) anyerror!f32 {
        return try XRDepthInformationImpl.get_rawValueToMeters(instance);
    }

    /// Extended attributes: [SecureContext], [Exposed=Window]
    pub const get_projectionMatrix = mixins.XRViewGeometry.get_projectionMatrix;

    /// Extended attributes: [SameObject], [SecureContext], [Exposed=Window]
    pub fn get_transform(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_transform) |cached| {
            return cached;
        }
        const value = try mixins.XRViewGeometry.get_transform(instance);
        state.own.cached_transform = value;
        @import("dom").same_object_cache.made(instance, value, "transform");
        return value;
    }
};
