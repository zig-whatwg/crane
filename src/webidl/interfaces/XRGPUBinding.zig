//! Generated from: webxr-webgpu-binding.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRGPUBindingImpl = @import("impls").XRGPUBinding;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XREquirectLayer = @import("interfaces").XREquirectLayer;
const XRCubeLayer = @import("interfaces").XRCubeLayer;
const XRGPUSubImage = @import("interfaces").XRGPUSubImage;
const XRGPUQuadLayerInit = @import("dictionaries").XRGPUQuadLayerInit;
const XRFrame = @import("interfaces").XRFrame;
const XRCylinderLayer = @import("interfaces").XRCylinderLayer;
const XRGPUCylinderLayerInit = @import("dictionaries").XRGPUCylinderLayerInit;
const XRView = @import("interfaces").XRView;
const GPUTextureFormat = @import("enums").GPUTextureFormat;
const XRSession = @import("interfaces").XRSession;
const XRGPUProjectionLayerInit = @import("dictionaries").XRGPUProjectionLayerInit;
const XRQuadLayer = @import("interfaces").XRQuadLayer;
const XRGPUEquirectLayerInit = @import("dictionaries").XRGPUEquirectLayerInit;
const XRCompositionLayer = @import("interfaces").XRCompositionLayer;
const GPUDevice = @import("interfaces").GPUDevice;
const XRProjectionLayer = @import("interfaces").XRProjectionLayer;
const XREye = @import("enums").XREye;
const XRGPUCubeLayerInit = @import("dictionaries").XRGPUCubeLayerInit;
const XRGPUDepthInformation = @import("interfaces").XRGPUDepthInformation;

pub const XRGPUBinding = struct {
    pub const Meta = struct {
        pub const name = "XRGPUBinding";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{"Window"} } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "nativeProjectionScaleFactor", "get_nativeProjectionScaleFactor", null },
            .{ "usesDepthValues", "get_usesDepthValues", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "createProjectionLayer", "call_createProjectionLayer", 0 },
            .{ "createQuadLayer", "call_createQuadLayer", 0 },
            .{ "createCylinderLayer", "call_createCylinderLayer", 0 },
            .{ "createEquirectLayer", "call_createEquirectLayer", 0 },
            .{ "createCubeLayer", "call_createCubeLayer", 0 },
            .{ "getSubImage", "call_getSubImage", 2 },
            .{ "getViewSubImage", "call_getViewSubImage", 2 },
            .{ "getPreferredColorFormat", "call_getPreferredColorFormat", 0 },
            .{ "getDepthInformation", "call_getDepthInformation", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createProjectionLayer",
            "createQuadLayer",
            "createCylinderLayer",
            "createEquirectLayer",
            "createCubeLayer",
            "getSubImage",
            "getViewSubImage",
            "getPreferredColorFormat",
            "getDepthInformation",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "nativeProjectionScaleFactor", "get_nativeProjectionScaleFactor", null },
            .{ "usesDepthValues", "get_usesDepthValues", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            nativeProjectionScaleFactor: f64 = undefined,
            usesDepthValues: bool = undefined,
            _internal: ?*XRGPUBindingImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_nativeProjectionScaleFactor = &get_nativeProjectionScaleFactor,
        .get_usesDepthValues = &get_usesDepthValues,

        .call_createCubeLayer = &call_createCubeLayer,
        .call_createCylinderLayer = &call_createCylinderLayer,
        .call_createEquirectLayer = &call_createEquirectLayer,
        .call_createProjectionLayer = &call_createProjectionLayer,
        .call_createQuadLayer = &call_createQuadLayer,
        .call_getDepthInformation = &call_getDepthInformation,
        .call_getPreferredColorFormat = &call_getPreferredColorFormat,
        .call_getSubImage = &call_getSubImage,
        .call_getViewSubImage = &call_getViewSubImage,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("XRGPUBinding has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(XRGPUBindingImpl, "init") and @hasDecl(XRGPUBindingImpl, "initOwn")) @compileError("XRGPUBindingImpl defines both init and initOwn");
        if (comptime @hasDecl(XRGPUBindingImpl, "init")) return XRGPUBindingImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(XRGPUBindingImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try XRGPUBindingImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XRGPUBindingImpl, "init")) return false;
        if (comptime @hasDecl(XRGPUBindingImpl, "construction_args")) {
            inline for (XRGPUBindingImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XRGPUBindingImpl, "deinit") and @hasDecl(XRGPUBindingImpl, "deinitOwn")) @compileError("XRGPUBindingImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(XRGPUBindingImpl, "deinit")) return XRGPUBindingImpl.deinit(instance);
        if (comptime @hasDecl(XRGPUBindingImpl, "deinitOwn")) XRGPUBindingImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XRGPUBinding")) {
            if (comptime @hasDecl(impls.XRGPUBinding, "installHooks")) impls.XRGPUBinding.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 2;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, session: *runtime.Instance, device: *runtime.Instance) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try XRGPUBindingImpl.call_constructor(ctx, session, device);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "", 0, "XRSession" },
        .{ "", 1, "GPUDevice" },
    };

    pub fn get_nativeProjectionScaleFactor(instance: *runtime.Instance) anyerror!f64 {
        return try XRGPUBindingImpl.get_nativeProjectionScaleFactor(instance);
    }

    pub fn get_usesDepthValues(instance: *runtime.Instance) anyerror!bool {
        return try XRGPUBindingImpl.get_usesDepthValues(instance);
    }

    pub fn call_createCylinderLayer(instance: *runtime.Instance, init_data: webidl.Opt(XRGPUCylinderLayerInit)) anyerror!*runtime.Instance {
        return try XRGPUBindingImpl.call_createCylinderLayer(instance, init_data);
    }

    pub fn call_createCubeLayer(instance: *runtime.Instance, init_data: webidl.Opt(XRGPUCubeLayerInit)) anyerror!*runtime.Instance {
        return try XRGPUBindingImpl.call_createCubeLayer(instance, init_data);
    }

    pub fn call_getSubImage(instance: *runtime.Instance, layer: *runtime.Instance, frame: *runtime.Instance, eye: webidl.Opt(XREye)) anyerror!*runtime.Instance {
        return try XRGPUBindingImpl.call_getSubImage(instance, layer, frame, eye);
    }

    pub fn call_getViewSubImage(instance: *runtime.Instance, layer: *runtime.Instance, view: *runtime.Instance) anyerror!*runtime.Instance {
        return try XRGPUBindingImpl.call_getViewSubImage(instance, layer, view);
    }

    pub fn call_getPreferredColorFormat(instance: *runtime.Instance) anyerror!GPUTextureFormat {
        return try XRGPUBindingImpl.call_getPreferredColorFormat(instance);
    }

    pub fn call_createQuadLayer(instance: *runtime.Instance, init_data: webidl.Opt(XRGPUQuadLayerInit)) anyerror!*runtime.Instance {
        return try XRGPUBindingImpl.call_createQuadLayer(instance, init_data);
    }

    pub fn call_getDepthInformation(instance: *runtime.Instance, view: *runtime.Instance) anyerror!?*runtime.Instance {
        return try XRGPUBindingImpl.call_getDepthInformation(instance, view);
    }

    pub fn call_createProjectionLayer(instance: *runtime.Instance, init_data: webidl.Opt(XRGPUProjectionLayerInit)) anyerror!*runtime.Instance {
        return try XRGPUBindingImpl.call_createProjectionLayer(instance, init_data);
    }

    pub fn call_createEquirectLayer(instance: *runtime.Instance, init_data: webidl.Opt(XRGPUEquirectLayerInit)) anyerror!*runtime.Instance {
        return try XRGPUBindingImpl.call_createEquirectLayer(instance, init_data);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_getSubImage", 0, "XRCompositionLayer" },
        .{ "call_getSubImage", 1, "XRFrame" },
        .{ "call_getViewSubImage", 0, "XRProjectionLayer" },
        .{ "call_getViewSubImage", 1, "XRView" },
        .{ "call_getDepthInformation", 0, "XRView" },
    };
};
