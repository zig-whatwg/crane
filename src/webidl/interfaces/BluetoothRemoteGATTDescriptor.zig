//! Generated from: web-bluetooth.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BluetoothRemoteGATTDescriptorImpl = @import("impls").BluetoothRemoteGATTDescriptor;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const BluetoothRemoteGATTCharacteristic = @import("interfaces").BluetoothRemoteGATTCharacteristic;
const UUID = @import("typedefs").UUID;
const BufferSource = @import("typedefs").BufferSource;

pub const BluetoothRemoteGATTDescriptor = struct {
    pub const Meta = struct {
        pub const name = "BluetoothRemoteGATTDescriptor";
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
            .{ "characteristic", "get_characteristic", null },
            .{ "uuid", "get_uuid", null },
            .{ "value", "get_value", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "readValue", "call_readValue", 0 },
            .{ "writeValue", "call_writeValue", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "readValue",
            "writeValue",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "characteristic", "get_characteristic", null },
            .{ "uuid", "get_uuid", null },
            .{ "value", "get_value", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            characteristic: *runtime.Instance = undefined,
            uuid: typedefs.UUID = undefined,
            value: ?runtime.DataView = null,
            cached_characteristic: ?*runtime.Instance = null,
            _internal: ?*BluetoothRemoteGATTDescriptorImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_characteristic = &get_characteristic,
        .get_uuid = &get_uuid,
        .get_value = &get_value,

        .call_readValue = &call_readValue,
        .call_writeValue = &call_writeValue,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("BluetoothRemoteGATTDescriptor has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(BluetoothRemoteGATTDescriptorImpl, "init") and @hasDecl(BluetoothRemoteGATTDescriptorImpl, "initOwn")) @compileError("BluetoothRemoteGATTDescriptorImpl defines both init and initOwn");
        if (comptime @hasDecl(BluetoothRemoteGATTDescriptorImpl, "init")) return BluetoothRemoteGATTDescriptorImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(BluetoothRemoteGATTDescriptorImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try BluetoothRemoteGATTDescriptorImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(BluetoothRemoteGATTDescriptorImpl, "init")) return false;
        if (comptime @hasDecl(BluetoothRemoteGATTDescriptorImpl, "construction_args")) {
            inline for (BluetoothRemoteGATTDescriptorImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(BluetoothRemoteGATTDescriptorImpl, "deinit") and @hasDecl(BluetoothRemoteGATTDescriptorImpl, "deinitOwn")) @compileError("BluetoothRemoteGATTDescriptorImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(BluetoothRemoteGATTDescriptorImpl, "deinit")) return BluetoothRemoteGATTDescriptorImpl.deinit(instance);
        if (comptime @hasDecl(BluetoothRemoteGATTDescriptorImpl, "deinitOwn")) BluetoothRemoteGATTDescriptorImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "BluetoothRemoteGATTDescriptor")) {
            if (comptime @hasDecl(impls.BluetoothRemoteGATTDescriptor, "installHooks")) impls.BluetoothRemoteGATTDescriptor.installHooks();
        }
    }

    /// Extended attributes: [SameObject]
    pub fn get_characteristic(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_characteristic) |cached| {
            return cached;
        }
        const value = try BluetoothRemoteGATTDescriptorImpl.get_characteristic(instance);
        state.own.cached_characteristic = value;
        @import("dom").same_object_cache.made(instance, value, "characteristic");
        return value;
    }

    pub fn get_uuid(instance: *runtime.Instance) anyerror!UUID {
        return try BluetoothRemoteGATTDescriptorImpl.get_uuid(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try BluetoothRemoteGATTDescriptorImpl.get_value(instance);
    }

    pub fn call_writeValue(instance: *runtime.Instance, value: BufferSource) anyerror!runtime.JSValue {
        return try BluetoothRemoteGATTDescriptorImpl.call_writeValue(instance, value);
    }

    pub fn call_readValue(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try BluetoothRemoteGATTDescriptorImpl.call_readValue(instance);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_writeValue",
        "call_readValue",
    };
};
