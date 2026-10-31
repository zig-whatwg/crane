//! Generated from: webxrlayers.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRMediaBindingImpl = @import("impls").XRMediaBinding;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const HTMLVideoElement = @import("interfaces").HTMLVideoElement;
const XRMediaCylinderLayerInit = @import("dictionaries").XRMediaCylinderLayerInit;
const XREquirectLayer = @import("interfaces").XREquirectLayer;
const XRMediaQuadLayerInit = @import("dictionaries").XRMediaQuadLayerInit;
const XRCylinderLayer = @import("interfaces").XRCylinderLayer;
const XRSession = @import("interfaces").XRSession;
const XRQuadLayer = @import("interfaces").XRQuadLayer;
const XRMediaEquirectLayerInit = @import("dictionaries").XRMediaEquirectLayerInit;

pub const XRMediaBinding = struct {
    pub const Meta = struct {
        pub const name = "XRMediaBinding";
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
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "createQuadLayer", "call_createQuadLayer", 1 },
            .{ "createCylinderLayer", "call_createCylinderLayer", 1 },
            .{ "createEquirectLayer", "call_createEquirectLayer", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createQuadLayer",
            "createCylinderLayer",
            "createEquirectLayer",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*XRMediaBindingImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_createCylinderLayer = &call_createCylinderLayer,
        .call_createEquirectLayer = &call_createEquirectLayer,
        .call_createQuadLayer = &call_createQuadLayer,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("XRMediaBinding has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(XRMediaBindingImpl, "init") and @hasDecl(XRMediaBindingImpl, "initOwn")) @compileError("XRMediaBindingImpl defines both init and initOwn");
        if (comptime @hasDecl(XRMediaBindingImpl, "init")) return XRMediaBindingImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(XRMediaBindingImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try XRMediaBindingImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XRMediaBindingImpl, "init")) return false;
        if (comptime @hasDecl(XRMediaBindingImpl, "construction_args")) {
            inline for (XRMediaBindingImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XRMediaBindingImpl, "deinit") and @hasDecl(XRMediaBindingImpl, "deinitOwn")) @compileError("XRMediaBindingImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(XRMediaBindingImpl, "deinit")) return XRMediaBindingImpl.deinit(instance);
        if (comptime @hasDecl(XRMediaBindingImpl, "deinitOwn")) XRMediaBindingImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XRMediaBinding")) {
            if (comptime @hasDecl(impls.XRMediaBinding, "installHooks")) impls.XRMediaBinding.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, session: *runtime.Instance) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try XRMediaBindingImpl.call_constructor(ctx, session);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "", 0, "XRSession" },
    };

    pub fn call_createQuadLayer(instance: *runtime.Instance, video: *runtime.Instance, init_data: webidl.Opt(XRMediaQuadLayerInit)) anyerror!*runtime.Instance {
        return try XRMediaBindingImpl.call_createQuadLayer(instance, video, init_data);
    }

    pub fn call_createCylinderLayer(instance: *runtime.Instance, video: *runtime.Instance, init_data: webidl.Opt(XRMediaCylinderLayerInit)) anyerror!*runtime.Instance {
        return try XRMediaBindingImpl.call_createCylinderLayer(instance, video, init_data);
    }

    pub fn call_createEquirectLayer(instance: *runtime.Instance, video: *runtime.Instance, init_data: webidl.Opt(XRMediaEquirectLayerInit)) anyerror!*runtime.Instance {
        return try XRMediaBindingImpl.call_createEquirectLayer(instance, video, init_data);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_createQuadLayer", 0, "HTMLVideoElement" },
        .{ "call_createCylinderLayer", 0, "HTMLVideoElement" },
        .{ "call_createEquirectLayer", 0, "HTMLVideoElement" },
    };
};
