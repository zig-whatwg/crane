//! Generated from: webusb.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const USBIsochronousOutTransferPacketImpl = @import("impls").USBIsochronousOutTransferPacket;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const USBTransferStatus = @import("enums").USBTransferStatus;

pub const USBIsochronousOutTransferPacket = struct {
    pub const Meta = struct {
        pub const name = "USBIsochronousOutTransferPacket";
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
            .{ "bytesWritten", "get_bytesWritten", null },
            .{ "status", "get_status", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "bytesWritten", "get_bytesWritten", null },
            .{ "status", "get_status", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            bytesWritten: u32 = undefined,
            status: enums.USBTransferStatus = undefined,
            _internal: ?*USBIsochronousOutTransferPacketImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_bytesWritten = &get_bytesWritten,
        .get_status = &get_status,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("USBIsochronousOutTransferPacket has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(USBIsochronousOutTransferPacketImpl, "init") and @hasDecl(USBIsochronousOutTransferPacketImpl, "initOwn")) @compileError("USBIsochronousOutTransferPacketImpl defines both init and initOwn");
        if (comptime @hasDecl(USBIsochronousOutTransferPacketImpl, "init")) return USBIsochronousOutTransferPacketImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(USBIsochronousOutTransferPacketImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try USBIsochronousOutTransferPacketImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(USBIsochronousOutTransferPacketImpl, "init")) return false;
        if (comptime @hasDecl(USBIsochronousOutTransferPacketImpl, "construction_args")) {
            inline for (USBIsochronousOutTransferPacketImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(USBIsochronousOutTransferPacketImpl, "deinit") and @hasDecl(USBIsochronousOutTransferPacketImpl, "deinitOwn")) @compileError("USBIsochronousOutTransferPacketImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(USBIsochronousOutTransferPacketImpl, "deinit")) return USBIsochronousOutTransferPacketImpl.deinit(instance);
        if (comptime @hasDecl(USBIsochronousOutTransferPacketImpl, "deinitOwn")) USBIsochronousOutTransferPacketImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "USBIsochronousOutTransferPacket")) {
            if (comptime @hasDecl(impls.USBIsochronousOutTransferPacket, "installHooks")) impls.USBIsochronousOutTransferPacket.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, status: USBTransferStatus, bytesWritten: webidl.Opt(u32)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try USBIsochronousOutTransferPacketImpl.call_constructor(ctx, status, bytesWritten);
    }

    pub fn get_bytesWritten(instance: *runtime.Instance) anyerror!u32 {
        return try USBIsochronousOutTransferPacketImpl.get_bytesWritten(instance);
    }

    pub fn get_status(instance: *runtime.Instance) anyerror!USBTransferStatus {
        return try USBIsochronousOutTransferPacketImpl.get_status(instance);
    }
};
