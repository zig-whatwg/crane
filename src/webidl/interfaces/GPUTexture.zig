//! Generated from: webgpu.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUTextureImpl = @import("impls").GPUTexture;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GPUObjectBase = @import("mixins").GPUObjectBase;
const GPUTextureView = @import("interfaces").GPUTextureView;
const GPUTextureDimension = @import("enums").GPUTextureDimension;
const GPUSize32Out = @import("typedefs").GPUSize32Out;
const GPUFlagsConstant = @import("typedefs").GPUFlagsConstant;
const GPUTextureFormat = @import("enums").GPUTextureFormat;
const GPUTextureViewDimension = @import("enums").GPUTextureViewDimension;
const USVString = @import("typedefs").USVString;
const GPUTextureViewDescriptor = @import("dictionaries").GPUTextureViewDescriptor;
const GPUIntegerCoordinateOut = @import("typedefs").GPUIntegerCoordinateOut;

pub const GPUTexture = struct {
    pub const Meta = struct {
        pub const name = "GPUTexture";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{
            GPUObjectBase,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "depthOrArrayLayers", "get_depthOrArrayLayers", null },
            .{ "mipLevelCount", "get_mipLevelCount", null },
            .{ "sampleCount", "get_sampleCount", null },
            .{ "dimension", "get_dimension", null },
            .{ "format", "get_format", null },
            .{ "usage", "get_usage", null },
            .{ "textureBindingViewDimension", "get_textureBindingViewDimension", null },
            .{ "label", "get_label", "set_label" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "createView", "call_createView", 0 },
            .{ "destroy", "call_destroy", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createView",
            "destroy",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "depthOrArrayLayers", "get_depthOrArrayLayers", null },
            .{ "mipLevelCount", "get_mipLevelCount", null },
            .{ "sampleCount", "get_sampleCount", null },
            .{ "dimension", "get_dimension", null },
            .{ "format", "get_format", null },
            .{ "usage", "get_usage", null },
            .{ "textureBindingViewDimension", "get_textureBindingViewDimension", null },
            .{ "label", "get_label", "set_label" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            width: typedefs.GPUIntegerCoordinateOut = undefined,
            height: typedefs.GPUIntegerCoordinateOut = undefined,
            depthOrArrayLayers: typedefs.GPUIntegerCoordinateOut = undefined,
            mipLevelCount: typedefs.GPUIntegerCoordinateOut = undefined,
            sampleCount: typedefs.GPUSize32Out = undefined,
            dimension: enums.GPUTextureDimension = undefined,
            format: enums.GPUTextureFormat = undefined,
            usage: typedefs.GPUFlagsConstant = undefined,
            textureBindingViewDimension: union(enum) {
                GPUTextureViewDimension: GPUTextureViewDimension,
                undefined: void,
            } = undefined,
            label: runtime.USVString = undefined,
            _internal: ?*GPUTextureImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_depthOrArrayLayers = &get_depthOrArrayLayers,
        .get_dimension = &get_dimension,
        .get_format = &get_format,
        .get_height = &get_height,
        .get_label = &get_label,
        .get_mipLevelCount = &get_mipLevelCount,
        .get_sampleCount = &get_sampleCount,
        .get_textureBindingViewDimension = &get_textureBindingViewDimension,
        .get_usage = &get_usage,
        .get_width = &get_width,

        .set_label = &set_label,

        .call_createView = &call_createView,
        .call_destroy = &call_destroy,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("GPUTexture has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(GPUTextureImpl, "init") and @hasDecl(GPUTextureImpl, "initOwn")) @compileError("GPUTextureImpl defines both init and initOwn");
        if (comptime @hasDecl(GPUTextureImpl, "init")) return GPUTextureImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(GPUTextureImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try GPUTextureImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(GPUTextureImpl, "init")) return false;
        if (comptime @hasDecl(GPUTextureImpl, "construction_args")) {
            inline for (GPUTextureImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(GPUTextureImpl, "deinit") and @hasDecl(GPUTextureImpl, "deinitOwn")) @compileError("GPUTextureImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(GPUTextureImpl, "deinit")) return GPUTextureImpl.deinit(instance);
        if (comptime @hasDecl(GPUTextureImpl, "deinitOwn")) GPUTextureImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "GPUTexture")) {
            if (comptime @hasDecl(impls.GPUTexture, "installHooks")) impls.GPUTexture.installHooks();
        }
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!GPUIntegerCoordinateOut {
        return try GPUTextureImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!GPUIntegerCoordinateOut {
        return try GPUTextureImpl.get_height(instance);
    }

    pub fn get_depthOrArrayLayers(instance: *runtime.Instance) anyerror!GPUIntegerCoordinateOut {
        return try GPUTextureImpl.get_depthOrArrayLayers(instance);
    }

    pub fn get_mipLevelCount(instance: *runtime.Instance) anyerror!GPUIntegerCoordinateOut {
        return try GPUTextureImpl.get_mipLevelCount(instance);
    }

    pub fn get_sampleCount(instance: *runtime.Instance) anyerror!GPUSize32Out {
        return try GPUTextureImpl.get_sampleCount(instance);
    }

    pub fn get_dimension(instance: *runtime.Instance) anyerror!GPUTextureDimension {
        return try GPUTextureImpl.get_dimension(instance);
    }

    pub fn get_format(instance: *runtime.Instance) anyerror!GPUTextureFormat {
        return try GPUTextureImpl.get_format(instance);
    }

    pub fn get_usage(instance: *runtime.Instance) anyerror!GPUFlagsConstant {
        return try GPUTextureImpl.get_usage(instance);
    }

    pub fn get_textureBindingViewDimension(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try GPUTextureImpl.get_textureBindingViewDimension(instance);
    }

    pub const get_label = mixins.GPUObjectBase.get_label;
    pub const set_label = mixins.GPUObjectBase.set_label;

    pub fn call_createView(instance: *runtime.Instance, descriptor: webidl.Opt(GPUTextureViewDescriptor)) anyerror!*runtime.Instance {
        return try GPUTextureImpl.call_createView(instance, descriptor);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try GPUTextureImpl.call_destroy(instance);
    }
};
