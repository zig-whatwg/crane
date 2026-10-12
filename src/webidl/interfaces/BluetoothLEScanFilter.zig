//! Generated from: web-bluetooth-scanning.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BluetoothLEScanFilterImpl = @import("impls").BluetoothLEScanFilter;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const BluetoothManufacturerDataFilter = @import("interfaces").BluetoothManufacturerDataFilter;
const BluetoothLEScanFilterInit = @import("dictionaries").BluetoothLEScanFilterInit;
const UUID = @import("typedefs").UUID;
const DOMString = @import("typedefs").DOMString;
const BluetoothServiceDataFilter = @import("interfaces").BluetoothServiceDataFilter;

pub const BluetoothLEScanFilter = struct {
    pub const Meta = struct {
        pub const name = "BluetoothLEScanFilter";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "namePrefix", "get_namePrefix", null },
            .{ "services", "get_services", null },
            .{ "manufacturerData", "get_manufacturerData", null },
            .{ "serviceData", "get_serviceData", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "name", "get_name", null },
            .{ "namePrefix", "get_namePrefix", null },
            .{ "services", "get_services", null },
            .{ "manufacturerData", "get_manufacturerData", null },
            .{ "serviceData", "get_serviceData", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            name: ?typedefs.DOMString = null,
            namePrefix: ?typedefs.DOMString = null,
            services: runtime.JSValue = undefined,
            manufacturerData: *runtime.Instance = undefined,
            serviceData: *runtime.Instance = undefined,
            _internal: ?*BluetoothLEScanFilterImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_manufacturerData = &get_manufacturerData,
        .get_name = &get_name,
        .get_namePrefix = &get_namePrefix,
        .get_serviceData = &get_serviceData,
        .get_services = &get_services,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("BluetoothLEScanFilter has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(BluetoothLEScanFilterImpl, "init") and @hasDecl(BluetoothLEScanFilterImpl, "initOwn")) @compileError("BluetoothLEScanFilterImpl defines both init and initOwn");
        if (comptime @hasDecl(BluetoothLEScanFilterImpl, "init")) return BluetoothLEScanFilterImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(BluetoothLEScanFilterImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try BluetoothLEScanFilterImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(BluetoothLEScanFilterImpl, "init")) return false;
        if (comptime @hasDecl(BluetoothLEScanFilterImpl, "construction_args")) {
            inline for (BluetoothLEScanFilterImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(BluetoothLEScanFilterImpl, "deinit") and @hasDecl(BluetoothLEScanFilterImpl, "deinitOwn")) @compileError("BluetoothLEScanFilterImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(BluetoothLEScanFilterImpl, "deinit")) return BluetoothLEScanFilterImpl.deinit(instance);
        if (comptime @hasDecl(BluetoothLEScanFilterImpl, "deinitOwn")) BluetoothLEScanFilterImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "BluetoothLEScanFilter")) {
            if (comptime @hasDecl(impls.BluetoothLEScanFilter, "installHooks")) impls.BluetoothLEScanFilter.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, init_data: webidl.Opt(BluetoothLEScanFilterInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try BluetoothLEScanFilterImpl.call_constructor(ctx, init_data);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!?DOMString {
        return try BluetoothLEScanFilterImpl.get_name(instance);
    }

    pub fn get_namePrefix(instance: *runtime.Instance) anyerror!?DOMString {
        return try BluetoothLEScanFilterImpl.get_namePrefix(instance);
    }

    pub fn get_services(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try BluetoothLEScanFilterImpl.get_services(instance);
    }

    pub fn get_manufacturerData(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BluetoothLEScanFilterImpl.get_manufacturerData(instance);
    }

    pub fn get_serviceData(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BluetoothLEScanFilterImpl.get_serviceData(instance);
    }
};
