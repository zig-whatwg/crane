//! Generated from: webgpu.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUAdapterInfoImpl = @import("impls").GPUAdapterInfo;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const GPUAdapterInfo = struct {
    pub const Meta = struct {
        pub const name = "GPUAdapterInfo";
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
            .{ "vendor", "get_vendor", null },
            .{ "architecture", "get_architecture", null },
            .{ "device", "get_device", null },
            .{ "description", "get_description", null },
            .{ "subgroupMinSize", "get_subgroupMinSize", null },
            .{ "subgroupMaxSize", "get_subgroupMaxSize", null },
            .{ "isFallbackAdapter", "get_isFallbackAdapter", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "vendor", "get_vendor", null },
            .{ "architecture", "get_architecture", null },
            .{ "device", "get_device", null },
            .{ "description", "get_description", null },
            .{ "subgroupMinSize", "get_subgroupMinSize", null },
            .{ "subgroupMaxSize", "get_subgroupMaxSize", null },
            .{ "isFallbackAdapter", "get_isFallbackAdapter", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            vendor: runtime.DOMString = undefined,
            architecture: runtime.DOMString = undefined,
            device: runtime.DOMString = undefined,
            description: runtime.DOMString = undefined,
            subgroupMinSize: u32 = undefined,
            subgroupMaxSize: u32 = undefined,
            isFallbackAdapter: bool = undefined,
            _internal: ?*GPUAdapterInfoImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_architecture = &get_architecture,
        .get_description = &get_description,
        .get_device = &get_device,
        .get_isFallbackAdapter = &get_isFallbackAdapter,
        .get_subgroupMaxSize = &get_subgroupMaxSize,
        .get_subgroupMinSize = &get_subgroupMinSize,
        .get_vendor = &get_vendor,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("GPUAdapterInfo has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(GPUAdapterInfoImpl, "init") and @hasDecl(GPUAdapterInfoImpl, "initOwn")) @compileError("GPUAdapterInfoImpl defines both init and initOwn");
        if (comptime @hasDecl(GPUAdapterInfoImpl, "init")) return GPUAdapterInfoImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(GPUAdapterInfoImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try GPUAdapterInfoImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(GPUAdapterInfoImpl, "init")) return false;
        if (comptime @hasDecl(GPUAdapterInfoImpl, "construction_args")) {
            inline for (GPUAdapterInfoImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(GPUAdapterInfoImpl, "deinit") and @hasDecl(GPUAdapterInfoImpl, "deinitOwn")) @compileError("GPUAdapterInfoImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(GPUAdapterInfoImpl, "deinit")) return GPUAdapterInfoImpl.deinit(instance);
        if (comptime @hasDecl(GPUAdapterInfoImpl, "deinitOwn")) GPUAdapterInfoImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "GPUAdapterInfo")) {
            if (comptime @hasDecl(impls.GPUAdapterInfo, "installHooks")) impls.GPUAdapterInfo.installHooks();
        }
    }

    pub fn get_vendor(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try GPUAdapterInfoImpl.get_vendor(instance);
    }

    pub fn get_architecture(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try GPUAdapterInfoImpl.get_architecture(instance);
    }

    pub fn get_device(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try GPUAdapterInfoImpl.get_device(instance);
    }

    pub fn get_description(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try GPUAdapterInfoImpl.get_description(instance);
    }

    pub fn get_subgroupMinSize(instance: *runtime.Instance) anyerror!u32 {
        return try GPUAdapterInfoImpl.get_subgroupMinSize(instance);
    }

    pub fn get_subgroupMaxSize(instance: *runtime.Instance) anyerror!u32 {
        return try GPUAdapterInfoImpl.get_subgroupMaxSize(instance);
    }

    pub fn get_isFallbackAdapter(instance: *runtime.Instance) anyerror!bool {
        return try GPUAdapterInfoImpl.get_isFallbackAdapter(instance);
    }
};
