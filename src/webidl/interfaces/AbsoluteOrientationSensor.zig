//! Generated from: orientation-sensor.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AbsoluteOrientationSensorImpl = @import("impls").AbsoluteOrientationSensor;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const OrientationSensor = @import("interfaces").OrientationSensor;
const DOMString = @import("typedefs").DOMString;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("interfaces").Event;
const RotationMatrixType = @import("typedefs").RotationMatrixType;
const EventListenerOptionsOrBoolean = @import("typedefs").EventListenerOptionsOrBoolean;
const EventListener = @import("interfaces").EventListener;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const OrientationSensorOptions = @import("dictionaries").OrientationSensorOptions;
const AddEventListenerOptionsOrBoolean = @import("typedefs").AddEventListenerOptionsOrBoolean;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const AbsoluteOrientationSensor = struct {
    pub const Meta = struct {
        pub const name = "AbsoluteOrientationSensor";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = OrientationSensor.State;
        pub const ParentInterface = OrientationSensor;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "start",
            "stop",
            "populateMatrix",
        };

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
            _internal: ?*AbsoluteOrientationSensorImpl.InternalState = null,
        },
    );

    const delegates = .{
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
            if (comptime !takesConstructionArg(field_name)) @compileError("AbsoluteOrientationSensor has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(AbsoluteOrientationSensorImpl, "init") and @hasDecl(AbsoluteOrientationSensorImpl, "initOwn")) @compileError("AbsoluteOrientationSensorImpl defines both init and initOwn");
        if (comptime @hasDecl(AbsoluteOrientationSensorImpl, "init")) return AbsoluteOrientationSensorImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(AbsoluteOrientationSensorImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try AbsoluteOrientationSensorImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(AbsoluteOrientationSensorImpl, "init")) return false;
        if (comptime @hasDecl(AbsoluteOrientationSensorImpl, "construction_args")) {
            inline for (AbsoluteOrientationSensorImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(AbsoluteOrientationSensorImpl, "deinit") and @hasDecl(AbsoluteOrientationSensorImpl, "deinitOwn")) @compileError("AbsoluteOrientationSensorImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(AbsoluteOrientationSensorImpl, "deinit")) return AbsoluteOrientationSensorImpl.deinit(instance);
        if (comptime @hasDecl(AbsoluteOrientationSensorImpl, "deinitOwn")) AbsoluteOrientationSensorImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "AbsoluteOrientationSensor")) {
            if (comptime @hasDecl(impls.AbsoluteOrientationSensor, "installHooks")) impls.AbsoluteOrientationSensor.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, sensorOptions: webidl.Opt(OrientationSensorOptions)) !*runtime.Instance {
        if (comptime @FieldType(std.meta.ArgsTuple(@TypeOf(AbsoluteOrientationSensorImpl.call_constructor)), "0") == *runtime.Instance) {
            // WebIDL 3.7.1 step 1.8: internally create a new object implementing
            // the interface. Until it is returned, the construction is its only
            // owner: a failed step frees it whole.
            const instance = try init(ctx.allocator, ctx);
            errdefer runtime.gc.releaseFailedConstruction(instance);
            // Step 1.9: perform the constructor steps with object as this.
            try AbsoluteOrientationSensorImpl.call_constructor(instance, sensorOptions);
            return instance;
        } else {
            // A factory: the impl makes the object, and frees it whole when a
            // step fails (tools/lint_constructors.zig).
            return try AbsoluteOrientationSensorImpl.call_constructor(ctx, sensorOptions);
        }
    }
};
