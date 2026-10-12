//! Generated from: webmidi.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MIDIAccessImpl = @import("impls").MIDIAccess;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const MIDIOutputMap = @import("interfaces").MIDIOutputMap;
const EventListener = @import("interfaces").EventListener;
const MIDIInputMap = @import("interfaces").MIDIInputMap;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const MIDIAccess = struct {
    pub const Meta = struct {
        pub const name = "MIDIAccess";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Transferable" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "inputs", "get_inputs", null },
            .{ "outputs", "get_outputs", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
            .{ "sysexEnabled", "get_sysexEnabled", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "inputs", "get_inputs", null },
            .{ "outputs", "get_outputs", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
            .{ "sysexEnabled", "get_sysexEnabled", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            inputs: *runtime.Instance = undefined,
            outputs: *runtime.Instance = undefined,
            onstatechange: typedefs.EventHandler = undefined,
            sysexEnabled: bool = undefined,
            _internal: ?*MIDIAccessImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_inputs = &get_inputs,
        .get_onstatechange = &get_onstatechange,
        .get_outputs = &get_outputs,
        .get_sysexEnabled = &get_sysexEnabled,

        .set_onstatechange = &set_onstatechange,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("MIDIAccess has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(MIDIAccessImpl, "init") and @hasDecl(MIDIAccessImpl, "initOwn")) @compileError("MIDIAccessImpl defines both init and initOwn");
        if (comptime @hasDecl(MIDIAccessImpl, "init")) return MIDIAccessImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(MIDIAccessImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try MIDIAccessImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MIDIAccessImpl, "init")) return false;
        if (comptime @hasDecl(MIDIAccessImpl, "construction_args")) {
            inline for (MIDIAccessImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(MIDIAccessImpl, "deinit") and @hasDecl(MIDIAccessImpl, "deinitOwn")) @compileError("MIDIAccessImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(MIDIAccessImpl, "deinit")) return MIDIAccessImpl.deinit(instance);
        if (comptime @hasDecl(MIDIAccessImpl, "deinitOwn")) MIDIAccessImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "MIDIAccess")) {
            if (comptime @hasDecl(impls.MIDIAccess, "installHooks")) impls.MIDIAccess.installHooks();
        }
    }

    pub fn get_inputs(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try MIDIAccessImpl.get_inputs(instance);
    }

    pub fn get_outputs(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try MIDIAccessImpl.get_outputs(instance);
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try MIDIAccessImpl.get_onstatechange(instance);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MIDIAccessImpl.set_onstatechange(instance, value);
    }

    pub fn get_sysexEnabled(instance: *runtime.Instance) anyerror!bool {
        return try MIDIAccessImpl.get_sysexEnabled(instance);
    }
};
