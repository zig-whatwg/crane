//! Generated from: media-source.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SourceBufferListImpl = @import("impls").SourceBufferList;
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
const SourceBuffer = @import("interfaces").SourceBuffer;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const SourceBufferList = struct {
    pub const Meta = struct {
        pub const name = "SourceBufferList";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "length", "get_length", null },
            .{ "onaddsourcebuffer", "get_onaddsourcebuffer", "set_onaddsourcebuffer" },
            .{ "onremovesourcebuffer", "get_onremovesourcebuffer", "set_onremovesourcebuffer" },
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
            .{ "length", "get_length", null },
            .{ "onaddsourcebuffer", "get_onaddsourcebuffer", "set_onaddsourcebuffer" },
            .{ "onremovesourcebuffer", "get_onremovesourcebuffer", "set_onremovesourcebuffer" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// WebIDL 2.5.6 special operations, own or inherited (the derived-most):
        /// the function that runs each. The binding installs indexed and named
        /// property handlers from this table (webidl.SpecialOperations).
        pub const special_operations: webidl.SpecialOperations = .{
            .indexed_getter = .{ .function = "call_getter", .implemented = @hasDecl(SourceBufferListImpl, "call_getter") },
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: u32 = undefined,
            onaddsourcebuffer: typedefs.EventHandler = undefined,
            onremovesourcebuffer: typedefs.EventHandler = undefined,
            _internal: ?*SourceBufferListImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_length = &get_length,
        .get_onaddsourcebuffer = &get_onaddsourcebuffer,
        .get_onremovesourcebuffer = &get_onremovesourcebuffer,

        .set_onaddsourcebuffer = &set_onaddsourcebuffer,
        .set_onremovesourcebuffer = &set_onremovesourcebuffer,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("SourceBufferList has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SourceBufferListImpl, "init") and @hasDecl(SourceBufferListImpl, "initOwn")) @compileError("SourceBufferListImpl defines both init and initOwn");
        if (comptime @hasDecl(SourceBufferListImpl, "init")) return SourceBufferListImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(SourceBufferListImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try SourceBufferListImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SourceBufferListImpl, "init")) return false;
        if (comptime @hasDecl(SourceBufferListImpl, "construction_args")) {
            inline for (SourceBufferListImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SourceBufferListImpl, "deinit") and @hasDecl(SourceBufferListImpl, "deinitOwn")) @compileError("SourceBufferListImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SourceBufferListImpl, "deinit")) return SourceBufferListImpl.deinit(instance);
        if (comptime @hasDecl(SourceBufferListImpl, "deinitOwn")) SourceBufferListImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SourceBufferList")) {
            if (comptime @hasDecl(impls.SourceBufferList, "installHooks")) impls.SourceBufferList.installHooks();
        }
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try SourceBufferListImpl.get_length(instance);
    }

    pub fn get_onaddsourcebuffer(instance: *runtime.Instance) anyerror!EventHandler {
        return try SourceBufferListImpl.get_onaddsourcebuffer(instance);
    }

    pub fn set_onaddsourcebuffer(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SourceBufferListImpl.set_onaddsourcebuffer(instance, value);
    }

    pub fn get_onremovesourcebuffer(instance: *runtime.Instance) anyerror!EventHandler {
        return try SourceBufferListImpl.get_onremovesourcebuffer(instance);
    }

    pub fn set_onremovesourcebuffer(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SourceBufferListImpl.set_onremovesourcebuffer(instance, value);
    }

    pub fn call_getter(instance: *runtime.Instance, index: u32) anyerror!*runtime.Instance {
        if (comptime @hasDecl(SourceBufferListImpl, "call_getter")) {
            return try SourceBufferListImpl.call_getter(instance, index);
        } else {
            return error.NotImplemented;
        }
    }
};
