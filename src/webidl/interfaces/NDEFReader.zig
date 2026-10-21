//! Generated from: web-nfc.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NDEFReaderImpl = @import("impls").NDEFReader;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const NDEFMessageSource = @import("typedefs").NDEFMessageSource;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const EventHandler = @import("typedefs").EventHandler;
const NDEFMakeReadOnlyOptions = @import("dictionaries").NDEFMakeReadOnlyOptions;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const NDEFScanOptions = @import("dictionaries").NDEFScanOptions;
const DOMString = @import("typedefs").DOMString;
const NDEFWriteOptions = @import("dictionaries").NDEFWriteOptions;

pub const NDEFReader = struct {
    pub const Meta = struct {
        pub const name = "NDEFReader";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onreading", "get_onreading", "set_onreading" },
            .{ "onreadingerror", "get_onreadingerror", "set_onreadingerror" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "scan", "call_scan", 0 },
            .{ "write", "call_write", 1 },
            .{ "makeReadOnly", "call_makeReadOnly", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "scan",
            "write",
            "makeReadOnly",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "onreading", "get_onreading", "set_onreading" },
            .{ "onreadingerror", "get_onreadingerror", "set_onreadingerror" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onreading: typedefs.EventHandler = undefined,
            onreadingerror: typedefs.EventHandler = undefined,
            _internal: ?*NDEFReaderImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onreading = &get_onreading,
        .get_onreadingerror = &get_onreadingerror,

        .set_onreading = &set_onreading,
        .set_onreadingerror = &set_onreadingerror,

        .call_makeReadOnly = &call_makeReadOnly,
        .call_scan = &call_scan,
        .call_write = &call_write,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("NDEFReader has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(NDEFReaderImpl, "init") and @hasDecl(NDEFReaderImpl, "initOwn")) @compileError("NDEFReaderImpl defines both init and initOwn");
        if (comptime @hasDecl(NDEFReaderImpl, "init")) return NDEFReaderImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(NDEFReaderImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try NDEFReaderImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(NDEFReaderImpl, "init")) return false;
        if (comptime @hasDecl(NDEFReaderImpl, "construction_args")) {
            inline for (NDEFReaderImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return Meta.ParentInterface.takesConstructionArg(name);
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(NDEFReaderImpl, "deinit") and @hasDecl(NDEFReaderImpl, "deinitOwn")) @compileError("NDEFReaderImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(NDEFReaderImpl, "deinit")) return NDEFReaderImpl.deinit(instance);
        if (comptime @hasDecl(NDEFReaderImpl, "deinitOwn")) NDEFReaderImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "NDEFReader")) {
            if (comptime @hasDecl(impls.NDEFReader, "installHooks")) impls.NDEFReader.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try NDEFReaderImpl.call_constructor(ctx);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onreading(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(NDEFReaderImpl, "get_onreading")) return try NDEFReaderImpl.get_onreading(instance);
        return event_handlers.value(EventHandler, instance, "onreading");
    }

    pub fn set_onreading(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(NDEFReaderImpl, "set_onreading")) return try NDEFReaderImpl.set_onreading(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onreading", value);
    }

    pub fn get_onreadingerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(NDEFReaderImpl, "get_onreadingerror")) return try NDEFReaderImpl.get_onreadingerror(instance);
        return event_handlers.value(EventHandler, instance, "onreadingerror");
    }

    pub fn set_onreadingerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(NDEFReaderImpl, "set_onreadingerror")) return try NDEFReaderImpl.set_onreadingerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onreadingerror", value);
    }

    pub fn call_write(instance: *runtime.Instance, message: NDEFMessageSource, options: webidl.Opt(NDEFWriteOptions)) anyerror!runtime.JSValue {
        return try NDEFReaderImpl.call_write(instance, message, options);
    }

    pub fn call_scan(instance: *runtime.Instance, options: webidl.Opt(NDEFScanOptions)) anyerror!runtime.JSValue {
        return try NDEFReaderImpl.call_scan(instance, options);
    }

    pub fn call_makeReadOnly(instance: *runtime.Instance, options: webidl.Opt(NDEFMakeReadOnlyOptions)) anyerror!runtime.JSValue {
        return try NDEFReaderImpl.call_makeReadOnly(instance, options);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_onreading", "set_onreadingerror" };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_write",
        "call_scan",
        "call_makeReadOnly",
    };
};
