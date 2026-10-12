//! Generated from: webusb.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const USBInterfaceImpl = @import("impls").USBInterface;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const USBConfiguration = @import("interfaces").USBConfiguration;
const USBAlternateInterface = @import("interfaces").USBAlternateInterface;

pub const USBInterface = struct {
    pub const Meta = struct {
        pub const name = "USBInterface";
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
            .{ "interfaceNumber", "get_interfaceNumber", null },
            .{ "alternate", "get_alternate", null },
            .{ "alternates", "get_alternates", null },
            .{ "claimed", "get_claimed", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "interfaceNumber", "get_interfaceNumber", null },
            .{ "alternate", "get_alternate", null },
            .{ "alternates", "get_alternates", null },
            .{ "claimed", "get_claimed", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            interfaceNumber: u8 = undefined,
            alternate: *runtime.Instance = undefined,
            alternates: runtime.JSValue = undefined,
            claimed: bool = undefined,
            _internal: ?*USBInterfaceImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_alternate = &get_alternate,
        .get_alternates = &get_alternates,
        .get_claimed = &get_claimed,
        .get_interfaceNumber = &get_interfaceNumber,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("USBInterface has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(USBInterfaceImpl, "init") and @hasDecl(USBInterfaceImpl, "initOwn")) @compileError("USBInterfaceImpl defines both init and initOwn");
        if (comptime @hasDecl(USBInterfaceImpl, "init")) return USBInterfaceImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(USBInterfaceImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try USBInterfaceImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(USBInterfaceImpl, "init")) return false;
        if (comptime @hasDecl(USBInterfaceImpl, "construction_args")) {
            inline for (USBInterfaceImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(USBInterfaceImpl, "deinit") and @hasDecl(USBInterfaceImpl, "deinitOwn")) @compileError("USBInterfaceImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(USBInterfaceImpl, "deinit")) return USBInterfaceImpl.deinit(instance);
        if (comptime @hasDecl(USBInterfaceImpl, "deinitOwn")) USBInterfaceImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "USBInterface")) {
            if (comptime @hasDecl(impls.USBInterface, "installHooks")) impls.USBInterface.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, configuration: *runtime.Instance, interfaceNumber: u8) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try USBInterfaceImpl.call_constructor(ctx, configuration, interfaceNumber);
    }

    pub fn get_interfaceNumber(instance: *runtime.Instance) anyerror!u8 {
        return try USBInterfaceImpl.get_interfaceNumber(instance);
    }

    pub fn get_alternate(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try USBInterfaceImpl.get_alternate(instance);
    }

    pub fn get_alternates(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try USBInterfaceImpl.get_alternates(instance);
    }

    pub fn get_claimed(instance: *runtime.Instance) anyerror!bool {
        return try USBInterfaceImpl.get_claimed(instance);
    }
};
