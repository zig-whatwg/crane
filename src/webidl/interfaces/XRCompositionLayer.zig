//! Generated from: webxrlayers.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRCompositionLayerImpl = @import("impls").XRCompositionLayer;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XRLayer = @import("interfaces").XRLayer;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const XRLayerLayout = @import("enums").XRLayerLayout;
const XRLayerQuality = @import("enums").XRLayerQuality;
const Observable = @import("interfaces").Observable;

pub const XRCompositionLayer = struct {
    pub const Meta = struct {
        pub const name = "XRCompositionLayer";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = XRLayer.State;
        pub const ParentInterface = XRLayer;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "layout", "get_layout", null },
            .{ "blendTextureSourceAlpha", "get_blendTextureSourceAlpha", "set_blendTextureSourceAlpha" },
            .{ "forceMonoPresentation", "get_forceMonoPresentation", "set_forceMonoPresentation" },
            .{ "opacity", "get_opacity", "set_opacity" },
            .{ "mipLevels", "get_mipLevels", null },
            .{ "quality", "get_quality", "set_quality" },
            .{ "needsRedraw", "get_needsRedraw", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "destroy", "call_destroy", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "destroy",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "layout", "get_layout", null },
            .{ "blendTextureSourceAlpha", "get_blendTextureSourceAlpha", "set_blendTextureSourceAlpha" },
            .{ "forceMonoPresentation", "get_forceMonoPresentation", "set_forceMonoPresentation" },
            .{ "opacity", "get_opacity", "set_opacity" },
            .{ "mipLevels", "get_mipLevels", null },
            .{ "quality", "get_quality", "set_quality" },
            .{ "needsRedraw", "get_needsRedraw", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            layout: enums.XRLayerLayout = undefined,
            blendTextureSourceAlpha: bool = undefined,
            forceMonoPresentation: bool = undefined,
            opacity: f32 = undefined,
            mipLevels: u32 = undefined,
            quality: enums.XRLayerQuality = undefined,
            needsRedraw: bool = undefined,
            _internal: ?*XRCompositionLayerImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_blendTextureSourceAlpha = &get_blendTextureSourceAlpha,
        .get_forceMonoPresentation = &get_forceMonoPresentation,
        .get_layout = &get_layout,
        .get_mipLevels = &get_mipLevels,
        .get_needsRedraw = &get_needsRedraw,
        .get_opacity = &get_opacity,
        .get_quality = &get_quality,

        .set_blendTextureSourceAlpha = &set_blendTextureSourceAlpha,
        .set_forceMonoPresentation = &set_forceMonoPresentation,
        .set_opacity = &set_opacity,
        .set_quality = &set_quality,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("XRCompositionLayer has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(XRCompositionLayerImpl, "init") and @hasDecl(XRCompositionLayerImpl, "initOwn")) @compileError("XRCompositionLayerImpl defines both init and initOwn");
        if (comptime @hasDecl(XRCompositionLayerImpl, "init")) return XRCompositionLayerImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(XRCompositionLayerImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try XRCompositionLayerImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XRCompositionLayerImpl, "init")) return false;
        if (comptime @hasDecl(XRCompositionLayerImpl, "construction_args")) {
            inline for (XRCompositionLayerImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XRCompositionLayerImpl, "deinit") and @hasDecl(XRCompositionLayerImpl, "deinitOwn")) @compileError("XRCompositionLayerImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(XRCompositionLayerImpl, "deinit")) return XRCompositionLayerImpl.deinit(instance);
        if (comptime @hasDecl(XRCompositionLayerImpl, "deinitOwn")) XRCompositionLayerImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XRCompositionLayer")) {
            if (comptime @hasDecl(impls.XRCompositionLayer, "installHooks")) impls.XRCompositionLayer.installHooks();
        }
    }

    pub fn get_layout(instance: *runtime.Instance) anyerror!XRLayerLayout {
        return try XRCompositionLayerImpl.get_layout(instance);
    }

    pub fn get_blendTextureSourceAlpha(instance: *runtime.Instance) anyerror!bool {
        return try XRCompositionLayerImpl.get_blendTextureSourceAlpha(instance);
    }

    pub fn set_blendTextureSourceAlpha(instance: *runtime.Instance, value: bool) anyerror!void {
        try XRCompositionLayerImpl.set_blendTextureSourceAlpha(instance, value);
    }

    pub fn get_forceMonoPresentation(instance: *runtime.Instance) anyerror!bool {
        return try XRCompositionLayerImpl.get_forceMonoPresentation(instance);
    }

    pub fn set_forceMonoPresentation(instance: *runtime.Instance, value: bool) anyerror!void {
        try XRCompositionLayerImpl.set_forceMonoPresentation(instance, value);
    }

    pub fn get_opacity(instance: *runtime.Instance) anyerror!f32 {
        return try XRCompositionLayerImpl.get_opacity(instance);
    }

    pub fn set_opacity(instance: *runtime.Instance, value: f32) anyerror!void {
        try XRCompositionLayerImpl.set_opacity(instance, value);
    }

    pub fn get_mipLevels(instance: *runtime.Instance) anyerror!u32 {
        return try XRCompositionLayerImpl.get_mipLevels(instance);
    }

    pub fn get_quality(instance: *runtime.Instance) anyerror!XRLayerQuality {
        return try XRCompositionLayerImpl.get_quality(instance);
    }

    pub fn set_quality(instance: *runtime.Instance, value: XRLayerQuality) anyerror!void {
        try XRCompositionLayerImpl.set_quality(instance, value);
    }

    pub fn get_needsRedraw(instance: *runtime.Instance) anyerror!bool {
        return try XRCompositionLayerImpl.get_needsRedraw(instance);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try XRCompositionLayerImpl.call_destroy(instance);
    }

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "set_opacity", 0b1 },
    };
};
