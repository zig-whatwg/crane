//! Generated from: web-bluetooth.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BluetoothCharacteristicPropertiesImpl = @import("impls").BluetoothCharacteristicProperties;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const BluetoothCharacteristicProperties = struct {
    pub const Meta = struct {
        pub const name = "BluetoothCharacteristicProperties";
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
            .{ "broadcast", "get_broadcast", null },
            .{ "read", "get_read", null },
            .{ "writeWithoutResponse", "get_writeWithoutResponse", null },
            .{ "write", "get_write", null },
            .{ "notify", "get_notify", null },
            .{ "indicate", "get_indicate", null },
            .{ "authenticatedSignedWrites", "get_authenticatedSignedWrites", null },
            .{ "reliableWrite", "get_reliableWrite", null },
            .{ "writableAuxiliaries", "get_writableAuxiliaries", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "broadcast", "get_broadcast", null },
            .{ "read", "get_read", null },
            .{ "writeWithoutResponse", "get_writeWithoutResponse", null },
            .{ "write", "get_write", null },
            .{ "notify", "get_notify", null },
            .{ "indicate", "get_indicate", null },
            .{ "authenticatedSignedWrites", "get_authenticatedSignedWrites", null },
            .{ "reliableWrite", "get_reliableWrite", null },
            .{ "writableAuxiliaries", "get_writableAuxiliaries", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            broadcast: bool = undefined,
            read: bool = undefined,
            writeWithoutResponse: bool = undefined,
            write: bool = undefined,
            notify: bool = undefined,
            indicate: bool = undefined,
            authenticatedSignedWrites: bool = undefined,
            reliableWrite: bool = undefined,
            writableAuxiliaries: bool = undefined,
            _internal: ?*BluetoothCharacteristicPropertiesImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_authenticatedSignedWrites = &get_authenticatedSignedWrites,
        .get_broadcast = &get_broadcast,
        .get_indicate = &get_indicate,
        .get_notify = &get_notify,
        .get_read = &get_read,
        .get_reliableWrite = &get_reliableWrite,
        .get_writableAuxiliaries = &get_writableAuxiliaries,
        .get_write = &get_write,
        .get_writeWithoutResponse = &get_writeWithoutResponse,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("BluetoothCharacteristicProperties has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(BluetoothCharacteristicPropertiesImpl, "init") and @hasDecl(BluetoothCharacteristicPropertiesImpl, "initOwn")) @compileError("BluetoothCharacteristicPropertiesImpl defines both init and initOwn");
        if (comptime @hasDecl(BluetoothCharacteristicPropertiesImpl, "init")) return BluetoothCharacteristicPropertiesImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(BluetoothCharacteristicPropertiesImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try BluetoothCharacteristicPropertiesImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(BluetoothCharacteristicPropertiesImpl, "init")) return false;
        if (comptime @hasDecl(BluetoothCharacteristicPropertiesImpl, "construction_args")) {
            inline for (BluetoothCharacteristicPropertiesImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(BluetoothCharacteristicPropertiesImpl, "deinit") and @hasDecl(BluetoothCharacteristicPropertiesImpl, "deinitOwn")) @compileError("BluetoothCharacteristicPropertiesImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(BluetoothCharacteristicPropertiesImpl, "deinit")) return BluetoothCharacteristicPropertiesImpl.deinit(instance);
        if (comptime @hasDecl(BluetoothCharacteristicPropertiesImpl, "deinitOwn")) BluetoothCharacteristicPropertiesImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "BluetoothCharacteristicProperties")) {
            if (comptime @hasDecl(impls.BluetoothCharacteristicProperties, "installHooks")) impls.BluetoothCharacteristicProperties.installHooks();
        }
    }

    pub fn get_broadcast(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothCharacteristicPropertiesImpl.get_broadcast(instance);
    }

    pub fn get_read(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothCharacteristicPropertiesImpl.get_read(instance);
    }

    pub fn get_writeWithoutResponse(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothCharacteristicPropertiesImpl.get_writeWithoutResponse(instance);
    }

    pub fn get_write(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothCharacteristicPropertiesImpl.get_write(instance);
    }

    pub fn get_notify(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothCharacteristicPropertiesImpl.get_notify(instance);
    }

    pub fn get_indicate(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothCharacteristicPropertiesImpl.get_indicate(instance);
    }

    pub fn get_authenticatedSignedWrites(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothCharacteristicPropertiesImpl.get_authenticatedSignedWrites(instance);
    }

    pub fn get_reliableWrite(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothCharacteristicPropertiesImpl.get_reliableWrite(instance);
    }

    pub fn get_writableAuxiliaries(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothCharacteristicPropertiesImpl.get_writableAuxiliaries(instance);
    }
};
