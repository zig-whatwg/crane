//! Generated from: webusb.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const USBEndpointImpl = @import("impls").USBEndpoint;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const USBEndpointType = @import("enums").USBEndpointType;
const USBDirection = @import("enums").USBDirection;
const USBAlternateInterface = @import("interfaces").USBAlternateInterface;

pub const USBEndpoint = struct {
    pub const Meta = struct {
        pub const name = "USBEndpoint";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Worker", "Window" } } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Worker = true,
            .Window = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "endpointNumber", "get_endpointNumber", null },
            .{ "direction", "get_direction", null },
            .{ "type", "get_type", null },
            .{ "packetSize", "get_packetSize", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "endpointNumber", "get_endpointNumber", null },
            .{ "direction", "get_direction", null },
            .{ "type", "get_type", null },
            .{ "packetSize", "get_packetSize", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            endpointNumber: u8 = undefined,
            direction: enums.USBDirection = undefined,
            type: enums.USBEndpointType = undefined,
            packetSize: u32 = undefined,
            _internal: ?*USBEndpointImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_direction = &get_direction,
        .get_endpointNumber = &get_endpointNumber,
        .get_packetSize = &get_packetSize,
        .get_type = &get_type,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("USBEndpoint has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(USBEndpointImpl, "init") and @hasDecl(USBEndpointImpl, "initOwn")) @compileError("USBEndpointImpl defines both init and initOwn");
        if (comptime @hasDecl(USBEndpointImpl, "init")) return USBEndpointImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(USBEndpointImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try USBEndpointImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(USBEndpointImpl, "init")) return false;
        if (comptime @hasDecl(USBEndpointImpl, "construction_args")) {
            inline for (USBEndpointImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(USBEndpointImpl, "deinit") and @hasDecl(USBEndpointImpl, "deinitOwn")) @compileError("USBEndpointImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(USBEndpointImpl, "deinit")) return USBEndpointImpl.deinit(instance);
        if (comptime @hasDecl(USBEndpointImpl, "deinitOwn")) USBEndpointImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "USBEndpoint")) {
            if (comptime @hasDecl(impls.USBEndpoint, "installHooks")) impls.USBEndpoint.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, alternate: *runtime.Instance, endpointNumber: u8, direction: USBDirection) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try USBEndpointImpl.call_constructor(ctx, alternate, endpointNumber, direction);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "", 0, "USBAlternateInterface" },
    };

    pub fn get_endpointNumber(instance: *runtime.Instance) anyerror!u8 {
        return try USBEndpointImpl.get_endpointNumber(instance);
    }

    pub fn get_direction(instance: *runtime.Instance) anyerror!USBDirection {
        return try USBEndpointImpl.get_direction(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!USBEndpointType {
        return try USBEndpointImpl.get_type(instance);
    }

    pub fn get_packetSize(instance: *runtime.Instance) anyerror!u32 {
        return try USBEndpointImpl.get_packetSize(instance);
    }
};
