//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TextTrackImpl = @import("impls").TextTrack;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const TextTrackKind = @import("enums").TextTrackKind;
const Observable = @import("interfaces").Observable;
const TextTrackMode = @import("enums").TextTrackMode;
const Event = @import("interfaces").Event;
const TextTrackCueList = @import("interfaces").TextTrackCueList;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const SourceBuffer = @import("interfaces").SourceBuffer;
const EventListener = @import("interfaces").EventListener;
const TextTrackCue = @import("interfaces").TextTrackCue;
const EventHandler = @import("typedefs").EventHandler;

pub const TextTrack = struct {
    pub const Meta = struct {
        pub const name = "TextTrack";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "kind", "get_kind", null },
            .{ "label", "get_label", null },
            .{ "language", "get_language", null },
            .{ "id", "get_id", null },
            .{ "inBandMetadataTrackDispatchType", "get_inBandMetadataTrackDispatchType", null },
            .{ "mode", "get_mode", "set_mode" },
            .{ "cues", "get_cues", null },
            .{ "activeCues", "get_activeCues", null },
            .{ "oncuechange", "get_oncuechange", "set_oncuechange" },
            .{ "sourceBuffer", "get_sourceBuffer", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "addCue", "call_addCue", 1 },
            .{ "removeCue", "call_removeCue", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "addCue",
            "removeCue",
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
            .{ "kind", "get_kind", null },
            .{ "label", "get_label", null },
            .{ "language", "get_language", null },
            .{ "id", "get_id", null },
            .{ "inBandMetadataTrackDispatchType", "get_inBandMetadataTrackDispatchType", null },
            .{ "mode", "get_mode", "set_mode" },
            .{ "cues", "get_cues", null },
            .{ "activeCues", "get_activeCues", null },
            .{ "oncuechange", "get_oncuechange", "set_oncuechange" },
            .{ "sourceBuffer", "get_sourceBuffer", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
        /// Member-level [Exposed] overrides; unlisted members inherit the interface.
        pub const exposed_members = .{
            .{ "sourceBuffer", .{"Window"} },
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            kind: enums.TextTrackKind = undefined,
            label: runtime.DOMString = undefined,
            language: runtime.DOMString = undefined,
            id: runtime.DOMString = undefined,
            inBandMetadataTrackDispatchType: runtime.DOMString = undefined,
            mode: enums.TextTrackMode = undefined,
            cues: ?*runtime.Instance = null,
            activeCues: ?*runtime.Instance = null,
            oncuechange: typedefs.EventHandler = undefined,
            sourceBuffer: ?*runtime.Instance = null,
            _internal: ?*TextTrackImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_activeCues = &get_activeCues,
        .get_cues = &get_cues,
        .get_id = &get_id,
        .get_inBandMetadataTrackDispatchType = &get_inBandMetadataTrackDispatchType,
        .get_kind = &get_kind,
        .get_label = &get_label,
        .get_language = &get_language,
        .get_mode = &get_mode,
        .get_oncuechange = &get_oncuechange,
        .get_sourceBuffer = &get_sourceBuffer,

        .set_mode = &set_mode,
        .set_oncuechange = &set_oncuechange,

        .call_addCue = &call_addCue,
        .call_removeCue = &call_removeCue,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("TextTrack has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(TextTrackImpl, "init") and @hasDecl(TextTrackImpl, "initOwn")) @compileError("TextTrackImpl defines both init and initOwn");
        if (comptime @hasDecl(TextTrackImpl, "init")) return TextTrackImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(TextTrackImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try TextTrackImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(TextTrackImpl, "init")) return false;
        if (comptime @hasDecl(TextTrackImpl, "construction_args")) {
            inline for (TextTrackImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(TextTrackImpl, "deinit") and @hasDecl(TextTrackImpl, "deinitOwn")) @compileError("TextTrackImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(TextTrackImpl, "deinit")) return TextTrackImpl.deinit(instance);
        if (comptime @hasDecl(TextTrackImpl, "deinitOwn")) TextTrackImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "TextTrack")) {
            if (comptime @hasDecl(impls.TextTrack, "installHooks")) impls.TextTrack.installHooks();
        }
    }

    pub fn get_kind(instance: *runtime.Instance) anyerror!TextTrackKind {
        return try TextTrackImpl.get_kind(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try TextTrackImpl.get_label(instance);
    }

    pub fn get_language(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try TextTrackImpl.get_language(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try TextTrackImpl.get_id(instance);
    }

    pub fn get_inBandMetadataTrackDispatchType(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try TextTrackImpl.get_inBandMetadataTrackDispatchType(instance);
    }

    pub fn get_mode(instance: *runtime.Instance) anyerror!TextTrackMode {
        return try TextTrackImpl.get_mode(instance);
    }

    pub fn set_mode(instance: *runtime.Instance, value: TextTrackMode) anyerror!void {
        try TextTrackImpl.set_mode(instance, value);
    }

    pub fn get_cues(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try TextTrackImpl.get_cues(instance);
    }

    pub fn get_activeCues(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try TextTrackImpl.get_activeCues(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_oncuechange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(TextTrackImpl, "get_oncuechange")) return try TextTrackImpl.get_oncuechange(instance);
        return event_handlers.value(EventHandler, instance, "oncuechange");
    }

    pub fn set_oncuechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(TextTrackImpl, "set_oncuechange")) return try TextTrackImpl.set_oncuechange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oncuechange", value);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_sourceBuffer(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try TextTrackImpl.get_sourceBuffer(instance);
    }

    pub fn call_addCue(instance: *runtime.Instance, cue: *runtime.Instance) anyerror!void {
        return try TextTrackImpl.call_addCue(instance, cue);
    }

    pub fn call_removeCue(instance: *runtime.Instance, cue: *runtime.Instance) anyerror!void {
        return try TextTrackImpl.call_removeCue(instance, cue);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{"set_oncuechange"};

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_addCue", 0, "TextTrackCue" },
        .{ "call_removeCue", 0, "TextTrackCue" },
    };
};
