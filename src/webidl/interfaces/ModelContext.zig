//! Generated from: webmcp.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ModelContextImpl = @import("impls").ModelContext;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ModelContextGetToolOptions = @import("dictionaries").ModelContextGetToolOptions;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const RegisteredTool = @import("dictionaries").RegisteredTool;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const ModelContextRegisterToolOptions = @import("dictionaries").ModelContextRegisterToolOptions;
const EventListener = @import("interfaces").EventListener;
const ModelContextTool = @import("dictionaries").ModelContextTool;
const ModelContextExecuteToolOptions = @import("dictionaries").ModelContextExecuteToolOptions;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const ModelContext = struct {
    pub const Meta = struct {
        pub const name = "ModelContext";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "ontoolchange", "get_ontoolchange", "set_ontoolchange" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "registerTool", "call_registerTool", 1 },
            .{ "getTools", "call_getTools", 0 },
            .{ "executeTool", "call_executeTool", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "registerTool",
            "getTools",
            "executeTool",
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
            .{ "ontoolchange", "get_ontoolchange", "set_ontoolchange" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            ontoolchange: typedefs.EventHandler = undefined,
            _internal: ?*ModelContextImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_ontoolchange = &get_ontoolchange,

        .set_ontoolchange = &set_ontoolchange,

        .call_executeTool = &call_executeTool,
        .call_getTools = &call_getTools,
        .call_registerTool = &call_registerTool,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("ModelContext has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(ModelContextImpl, "init") and @hasDecl(ModelContextImpl, "initOwn")) @compileError("ModelContextImpl defines both init and initOwn");
        if (comptime @hasDecl(ModelContextImpl, "init")) return ModelContextImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(ModelContextImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try ModelContextImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ModelContextImpl, "init")) return false;
        if (comptime @hasDecl(ModelContextImpl, "construction_args")) {
            inline for (ModelContextImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ModelContextImpl, "deinit") and @hasDecl(ModelContextImpl, "deinitOwn")) @compileError("ModelContextImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ModelContextImpl, "deinit")) return ModelContextImpl.deinit(instance);
        if (comptime @hasDecl(ModelContextImpl, "deinitOwn")) ModelContextImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ModelContext")) {
            if (comptime @hasDecl(impls.ModelContext, "installHooks")) impls.ModelContext.installHooks();
        }
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_ontoolchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(ModelContextImpl, "get_ontoolchange")) return try ModelContextImpl.get_ontoolchange(instance);
        return event_handlers.value(EventHandler, instance, "ontoolchange");
    }

    pub fn set_ontoolchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(ModelContextImpl, "set_ontoolchange")) return try ModelContextImpl.set_ontoolchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ontoolchange", value);
    }

    pub fn call_getTools(instance: *runtime.Instance, options: webidl.Opt(ModelContextGetToolOptions)) anyerror!runtime.JSValue {
        return try ModelContextImpl.call_getTools(instance, options);
    }

    pub fn call_registerTool(instance: *runtime.Instance, tool: ModelContextTool, options: webidl.Opt(ModelContextRegisterToolOptions)) anyerror!runtime.JSValue {
        return try ModelContextImpl.call_registerTool(instance, tool, options);
    }

    pub fn call_executeTool(instance: *runtime.Instance, tool: RegisteredTool, inputObject: webidl.Opt(runtime.JSValue), options: webidl.Opt(ModelContextExecuteToolOptions)) anyerror!runtime.JSValue {
        return try ModelContextImpl.call_executeTool(instance, tool, inputObject, options);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{"set_ontoolchange"};

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_getTools",
        "call_registerTool",
        "call_executeTool",
    };
};
