//! Generated from: wasm-js-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MemoryImpl = @import("impls").Memory;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const MemoryDescriptor = @import("dictionaries").MemoryDescriptor;
const AddressValue = @import("typedefs").AddressValue;

pub const Memory = struct {
    pub const Meta = struct {
        pub const name = "Memory";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "LegacyNamespace", .value = .{ .identifier = "WebAssembly" } },
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "buffer", "get_buffer", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "grow", "call_grow", 1 },
            .{ "toFixedLengthBuffer", "call_toFixedLengthBuffer", 0 },
            .{ "toResizableBuffer", "call_toResizableBuffer", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "grow",
            "toFixedLengthBuffer",
            "toResizableBuffer",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "buffer", "get_buffer", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            buffer: runtime.ArrayBuffer = undefined,
            _internal: ?*MemoryImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_buffer = &get_buffer,

        .call_grow = &call_grow,
        .call_toFixedLengthBuffer = &call_toFixedLengthBuffer,
        .call_toResizableBuffer = &call_toResizableBuffer,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("Memory has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(MemoryImpl, "init") and @hasDecl(MemoryImpl, "initOwn")) @compileError("MemoryImpl defines both init and initOwn");
        if (comptime @hasDecl(MemoryImpl, "init")) return MemoryImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(MemoryImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try MemoryImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MemoryImpl, "init")) return false;
        if (comptime @hasDecl(MemoryImpl, "construction_args")) {
            inline for (MemoryImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(MemoryImpl, "deinit") and @hasDecl(MemoryImpl, "deinitOwn")) @compileError("MemoryImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(MemoryImpl, "deinit")) return MemoryImpl.deinit(instance);
        if (comptime @hasDecl(MemoryImpl, "deinitOwn")) MemoryImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Memory")) {
            if (comptime @hasDecl(impls.Memory, "installHooks")) impls.Memory.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, descriptor: MemoryDescriptor) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MemoryImpl.call_constructor(ctx, descriptor);
    }

    pub fn get_buffer(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try MemoryImpl.get_buffer(instance);
    }

    pub fn call_toResizableBuffer(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try MemoryImpl.call_toResizableBuffer(instance);
    }

    pub fn call_grow(instance: *runtime.Instance, delta: AddressValue) anyerror!AddressValue {
        return try MemoryImpl.call_grow(instance, delta);
    }

    pub fn call_toFixedLengthBuffer(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try MemoryImpl.call_toFixedLengthBuffer(instance);
    }
};
