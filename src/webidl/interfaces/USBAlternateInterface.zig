//! Generated from: webusb.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const USBAlternateInterfaceImpl = @import("impls").USBAlternateInterface;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const USBInterface = @import("interfaces").USBInterface;
const USBEndpoint = @import("interfaces").USBEndpoint;
const DOMString = @import("typedefs").DOMString;

pub const USBAlternateInterface = struct {
    pub const Meta = struct {
        pub const name = "USBAlternateInterface";
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
            .{ "alternateSetting", "get_alternateSetting", null },
            .{ "interfaceClass", "get_interfaceClass", null },
            .{ "interfaceSubclass", "get_interfaceSubclass", null },
            .{ "interfaceProtocol", "get_interfaceProtocol", null },
            .{ "interfaceName", "get_interfaceName", null },
            .{ "endpoints", "get_endpoints", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "alternateSetting", "get_alternateSetting", null },
            .{ "interfaceClass", "get_interfaceClass", null },
            .{ "interfaceSubclass", "get_interfaceSubclass", null },
            .{ "interfaceProtocol", "get_interfaceProtocol", null },
            .{ "interfaceName", "get_interfaceName", null },
            .{ "endpoints", "get_endpoints", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            alternateSetting: u8 = undefined,
            interfaceClass: u8 = undefined,
            interfaceSubclass: u8 = undefined,
            interfaceProtocol: u8 = undefined,
            interfaceName: ?runtime.DOMString = null,
            endpoints: runtime.JSValue = undefined,
            _internal: ?*USBAlternateInterfaceImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_alternateSetting = &get_alternateSetting,
        .get_endpoints = &get_endpoints,
        .get_interfaceClass = &get_interfaceClass,
        .get_interfaceName = &get_interfaceName,
        .get_interfaceProtocol = &get_interfaceProtocol,
        .get_interfaceSubclass = &get_interfaceSubclass,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("USBAlternateInterface has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(USBAlternateInterfaceImpl, "init") and @hasDecl(USBAlternateInterfaceImpl, "initOwn")) @compileError("USBAlternateInterfaceImpl defines both init and initOwn");
        if (comptime @hasDecl(USBAlternateInterfaceImpl, "init")) return USBAlternateInterfaceImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(USBAlternateInterfaceImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try USBAlternateInterfaceImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(USBAlternateInterfaceImpl, "init")) return false;
        if (comptime @hasDecl(USBAlternateInterfaceImpl, "construction_args")) {
            inline for (USBAlternateInterfaceImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(USBAlternateInterfaceImpl, "deinit") and @hasDecl(USBAlternateInterfaceImpl, "deinitOwn")) @compileError("USBAlternateInterfaceImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(USBAlternateInterfaceImpl, "deinit")) return USBAlternateInterfaceImpl.deinit(instance);
        if (comptime @hasDecl(USBAlternateInterfaceImpl, "deinitOwn")) USBAlternateInterfaceImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "USBAlternateInterface")) {
            if (comptime @hasDecl(impls.USBAlternateInterface, "installHooks")) impls.USBAlternateInterface.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, deviceInterface: *runtime.Instance, alternateSetting: u8) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try USBAlternateInterfaceImpl.call_constructor(ctx, deviceInterface, alternateSetting);
    }

    pub fn get_alternateSetting(instance: *runtime.Instance) anyerror!u8 {
        return try USBAlternateInterfaceImpl.get_alternateSetting(instance);
    }

    pub fn get_interfaceClass(instance: *runtime.Instance) anyerror!u8 {
        return try USBAlternateInterfaceImpl.get_interfaceClass(instance);
    }

    pub fn get_interfaceSubclass(instance: *runtime.Instance) anyerror!u8 {
        return try USBAlternateInterfaceImpl.get_interfaceSubclass(instance);
    }

    pub fn get_interfaceProtocol(instance: *runtime.Instance) anyerror!u8 {
        return try USBAlternateInterfaceImpl.get_interfaceProtocol(instance);
    }

    pub fn get_interfaceName(instance: *runtime.Instance) anyerror!?runtime.DOMString {
        return try USBAlternateInterfaceImpl.get_interfaceName(instance);
    }

    pub fn get_endpoints(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try USBAlternateInterfaceImpl.get_endpoints(instance);
    }
};
