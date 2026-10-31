//! Generated from: clipboard-apis.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ClipboardImpl = @import("impls").Clipboard;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ClipboardUnsanitizedFormats = @import("dictionaries").ClipboardUnsanitizedFormats;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const ClipboardItems = @import("typedefs").ClipboardItems;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("interfaces").Observable;

pub const Clipboard = struct {
    pub const Meta = struct {
        pub const name = "Clipboard";
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
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "read", "call_read", 0 },
            .{ "readText", "call_readText", 0 },
            .{ "write", "call_write", 1 },
            .{ "writeText", "call_writeText", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "read",
            "readText",
            "write",
            "writeText",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*ClipboardImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_read = &call_read,
        .call_readText = &call_readText,
        .call_write = &call_write,
        .call_writeText = &call_writeText,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("Clipboard has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(ClipboardImpl, "init") and @hasDecl(ClipboardImpl, "initOwn")) @compileError("ClipboardImpl defines both init and initOwn");
        if (comptime @hasDecl(ClipboardImpl, "init")) return ClipboardImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(ClipboardImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try ClipboardImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ClipboardImpl, "init")) return false;
        if (comptime @hasDecl(ClipboardImpl, "construction_args")) {
            inline for (ClipboardImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ClipboardImpl, "deinit") and @hasDecl(ClipboardImpl, "deinitOwn")) @compileError("ClipboardImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ClipboardImpl, "deinit")) return ClipboardImpl.deinit(instance);
        if (comptime @hasDecl(ClipboardImpl, "deinitOwn")) ClipboardImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Clipboard")) {
            if (comptime @hasDecl(impls.Clipboard, "installHooks")) impls.Clipboard.installHooks();
        }
    }

    pub fn call_readText(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ClipboardImpl.call_readText(instance);
    }

    pub fn call_read(instance: *runtime.Instance, formats: webidl.Opt(ClipboardUnsanitizedFormats)) anyerror!runtime.JSValue {
        return try ClipboardImpl.call_read(instance, formats);
    }

    pub fn call_write(instance: *runtime.Instance, data: ClipboardItems) anyerror!runtime.JSValue {
        return try ClipboardImpl.call_write(instance, data);
    }

    pub fn call_writeText(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.JSValue {
        return try ClipboardImpl.call_writeText(instance, data);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_write", 0, "ClipboardItem" },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_readText",
        "call_read",
        "call_write",
        "call_writeText",
    };
};
