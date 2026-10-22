//! Generated from: touch-events.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TouchImpl = @import("impls").Touch;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const TouchInit = @import("dictionaries").TouchInit;
const EventTarget = @import("interfaces").EventTarget;
const TouchType = @import("enums").TouchType;

pub const Touch = struct {
    pub const Meta = struct {
        pub const name = "Touch";
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
        pub const properties = .{
            .{ "identifier", "get_identifier", null },
            .{ "target", "get_target", null },
            .{ "screenX", "get_screenX", null },
            .{ "screenY", "get_screenY", null },
            .{ "clientX", "get_clientX", null },
            .{ "clientY", "get_clientY", null },
            .{ "pageX", "get_pageX", null },
            .{ "pageY", "get_pageY", null },
            .{ "radiusX", "get_radiusX", null },
            .{ "radiusY", "get_radiusY", null },
            .{ "rotationAngle", "get_rotationAngle", null },
            .{ "force", "get_force", null },
            .{ "altitudeAngle", "get_altitudeAngle", null },
            .{ "azimuthAngle", "get_azimuthAngle", null },
            .{ "touchType", "get_touchType", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "identifier", "get_identifier", null },
            .{ "target", "get_target", null },
            .{ "screenX", "get_screenX", null },
            .{ "screenY", "get_screenY", null },
            .{ "clientX", "get_clientX", null },
            .{ "clientY", "get_clientY", null },
            .{ "pageX", "get_pageX", null },
            .{ "pageY", "get_pageY", null },
            .{ "radiusX", "get_radiusX", null },
            .{ "radiusY", "get_radiusY", null },
            .{ "rotationAngle", "get_rotationAngle", null },
            .{ "force", "get_force", null },
            .{ "altitudeAngle", "get_altitudeAngle", null },
            .{ "azimuthAngle", "get_azimuthAngle", null },
            .{ "touchType", "get_touchType", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            identifier: i32 = undefined,
            target: *runtime.Instance = undefined,
            screenX: f64 = undefined,
            screenY: f64 = undefined,
            clientX: f64 = undefined,
            clientY: f64 = undefined,
            pageX: f64 = undefined,
            pageY: f64 = undefined,
            radiusX: f32 = undefined,
            radiusY: f32 = undefined,
            rotationAngle: f32 = undefined,
            force: f32 = undefined,
            altitudeAngle: f32 = undefined,
            azimuthAngle: f32 = undefined,
            touchType: enums.TouchType = undefined,
            _internal: ?*TouchImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_altitudeAngle = &get_altitudeAngle,
        .get_azimuthAngle = &get_azimuthAngle,
        .get_clientX = &get_clientX,
        .get_clientY = &get_clientY,
        .get_force = &get_force,
        .get_identifier = &get_identifier,
        .get_pageX = &get_pageX,
        .get_pageY = &get_pageY,
        .get_radiusX = &get_radiusX,
        .get_radiusY = &get_radiusY,
        .get_rotationAngle = &get_rotationAngle,
        .get_screenX = &get_screenX,
        .get_screenY = &get_screenY,
        .get_target = &get_target,
        .get_touchType = &get_touchType,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("Touch has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(TouchImpl, "init") and @hasDecl(TouchImpl, "initOwn")) @compileError("TouchImpl defines both init and initOwn");
        if (comptime @hasDecl(TouchImpl, "init")) return TouchImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(TouchImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try TouchImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(TouchImpl, "init")) return false;
        if (comptime @hasDecl(TouchImpl, "construction_args")) {
            inline for (TouchImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(TouchImpl, "deinit") and @hasDecl(TouchImpl, "deinitOwn")) @compileError("TouchImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(TouchImpl, "deinit")) return TouchImpl.deinit(instance);
        if (comptime @hasDecl(TouchImpl, "deinitOwn")) TouchImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Touch")) {
            if (comptime @hasDecl(impls.Touch, "installHooks")) impls.Touch.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, touchInitDict: TouchInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TouchImpl.call_constructor(ctx, touchInitDict);
    }

    pub fn get_identifier(instance: *runtime.Instance) anyerror!i32 {
        return try TouchImpl.get_identifier(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try TouchImpl.get_target(instance);
    }

    pub fn get_screenX(instance: *runtime.Instance) anyerror!f64 {
        return try TouchImpl.get_screenX(instance);
    }

    pub fn get_screenY(instance: *runtime.Instance) anyerror!f64 {
        return try TouchImpl.get_screenY(instance);
    }

    pub fn get_clientX(instance: *runtime.Instance) anyerror!f64 {
        return try TouchImpl.get_clientX(instance);
    }

    pub fn get_clientY(instance: *runtime.Instance) anyerror!f64 {
        return try TouchImpl.get_clientY(instance);
    }

    pub fn get_pageX(instance: *runtime.Instance) anyerror!f64 {
        return try TouchImpl.get_pageX(instance);
    }

    pub fn get_pageY(instance: *runtime.Instance) anyerror!f64 {
        return try TouchImpl.get_pageY(instance);
    }

    pub fn get_radiusX(instance: *runtime.Instance) anyerror!f32 {
        return try TouchImpl.get_radiusX(instance);
    }

    pub fn get_radiusY(instance: *runtime.Instance) anyerror!f32 {
        return try TouchImpl.get_radiusY(instance);
    }

    pub fn get_rotationAngle(instance: *runtime.Instance) anyerror!f32 {
        return try TouchImpl.get_rotationAngle(instance);
    }

    pub fn get_force(instance: *runtime.Instance) anyerror!f32 {
        return try TouchImpl.get_force(instance);
    }

    pub fn get_altitudeAngle(instance: *runtime.Instance) anyerror!f32 {
        return try TouchImpl.get_altitudeAngle(instance);
    }

    pub fn get_azimuthAngle(instance: *runtime.Instance) anyerror!f32 {
        return try TouchImpl.get_azimuthAngle(instance);
    }

    pub fn get_touchType(instance: *runtime.Instance) anyerror!TouchType {
        return try TouchImpl.get_touchType(instance);
    }
};
