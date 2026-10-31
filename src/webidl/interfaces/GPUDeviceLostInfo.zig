//! Generated from: webgpu.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUDeviceLostInfoImpl = @import("impls").GPUDeviceLostInfo;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GPUDeviceLostReason = @import("enums").GPUDeviceLostReason;
const DOMString = @import("typedefs").DOMString;

pub const GPUDeviceLostInfo = struct {
    pub const Meta = struct {
        pub const name = "GPUDeviceLostInfo";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "reason", "get_reason", null },
            .{ "message", "get_message", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "reason", "get_reason", null },
            .{ "message", "get_message", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            reason: enums.GPUDeviceLostReason = undefined,
            message: runtime.DOMString = undefined,
            _internal: ?*GPUDeviceLostInfoImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_message = &get_message,
        .get_reason = &get_reason,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("GPUDeviceLostInfo has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(GPUDeviceLostInfoImpl, "init") and @hasDecl(GPUDeviceLostInfoImpl, "initOwn")) @compileError("GPUDeviceLostInfoImpl defines both init and initOwn");
        if (comptime @hasDecl(GPUDeviceLostInfoImpl, "init")) return GPUDeviceLostInfoImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(GPUDeviceLostInfoImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try GPUDeviceLostInfoImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(GPUDeviceLostInfoImpl, "init")) return false;
        if (comptime @hasDecl(GPUDeviceLostInfoImpl, "construction_args")) {
            inline for (GPUDeviceLostInfoImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(GPUDeviceLostInfoImpl, "deinit") and @hasDecl(GPUDeviceLostInfoImpl, "deinitOwn")) @compileError("GPUDeviceLostInfoImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(GPUDeviceLostInfoImpl, "deinit")) return GPUDeviceLostInfoImpl.deinit(instance);
        if (comptime @hasDecl(GPUDeviceLostInfoImpl, "deinitOwn")) GPUDeviceLostInfoImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "GPUDeviceLostInfo")) {
            if (comptime @hasDecl(impls.GPUDeviceLostInfo, "installHooks")) impls.GPUDeviceLostInfo.installHooks();
        }
    }

    pub fn get_reason(instance: *runtime.Instance) anyerror!GPUDeviceLostReason {
        return try GPUDeviceLostInfoImpl.get_reason(instance);
    }

    pub fn get_message(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try GPUDeviceLostInfoImpl.get_message(instance);
    }
};
