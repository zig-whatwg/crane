//! Generated from: webvtt.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const VTTCueImpl = @import("impls").VTTCue;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const TextTrackCue = @import("interfaces").TextTrackCue;
const VTTRegion = @import("interfaces").VTTRegion;
const DocumentFragment = @import("interfaces").DocumentFragment;
const PositionAlignSetting = @import("enums").PositionAlignSetting;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const LineAlignSetting = @import("enums").LineAlignSetting;
const EventHandler = @import("typedefs").EventHandler;
const AlignSetting = @import("enums").AlignSetting;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const TextTrack = @import("interfaces").TextTrack;
const EventListener = @import("interfaces").EventListener;
const DirectionSetting = @import("enums").DirectionSetting;
const LineAndPositionSetting = @import("typedefs").LineAndPositionSetting;
const DOMString = @import("typedefs").DOMString;

pub const VTTCue = struct {
    pub const Meta = struct {
        pub const name = "VTTCue";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = TextTrackCue.State;
        pub const ParentInterface = TextTrackCue;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "region", "get_region", "set_region" },
            .{ "vertical", "get_vertical", "set_vertical" },
            .{ "snapToLines", "get_snapToLines", "set_snapToLines" },
            .{ "line", "get_line", "set_line" },
            .{ "lineAlign", "get_lineAlign", "set_lineAlign" },
            .{ "position", "get_position", "set_position" },
            .{ "positionAlign", "get_positionAlign", "set_positionAlign" },
            .{ "size", "get_size", "set_size" },
            .{ "align", "get_align", "set_align" },
            .{ "text", "get_text", "set_text" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getCueAsHTML", "call_getCueAsHTML", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getCueAsHTML",
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
            .{ "region", "get_region", "set_region" },
            .{ "vertical", "get_vertical", "set_vertical" },
            .{ "snapToLines", "get_snapToLines", "set_snapToLines" },
            .{ "line", "get_line", "set_line" },
            .{ "lineAlign", "get_lineAlign", "set_lineAlign" },
            .{ "position", "get_position", "set_position" },
            .{ "positionAlign", "get_positionAlign", "set_positionAlign" },
            .{ "size", "get_size", "set_size" },
            .{ "align", "get_align", "set_align" },
            .{ "text", "get_text", "set_text" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            region: ?*runtime.Instance = null,
            vertical: enums.DirectionSetting = undefined,
            snapToLines: bool = undefined,
            line: typedefs.LineAndPositionSetting = undefined,
            lineAlign: enums.LineAlignSetting = undefined,
            position: typedefs.LineAndPositionSetting = undefined,
            positionAlign: enums.PositionAlignSetting = undefined,
            size: f64 = undefined,
            @"align": enums.AlignSetting = undefined,
            text: runtime.DOMString = undefined,
            _internal: ?*VTTCueImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_align = &get_align,
        .get_line = &get_line,
        .get_lineAlign = &get_lineAlign,
        .get_position = &get_position,
        .get_positionAlign = &get_positionAlign,
        .get_region = &get_region,
        .get_size = &get_size,
        .get_snapToLines = &get_snapToLines,
        .get_text = &get_text,
        .get_vertical = &get_vertical,

        .set_align = &set_align,
        .set_line = &set_line,
        .set_lineAlign = &set_lineAlign,
        .set_position = &set_position,
        .set_positionAlign = &set_positionAlign,
        .set_region = &set_region,
        .set_size = &set_size,
        .set_snapToLines = &set_snapToLines,
        .set_text = &set_text,
        .set_vertical = &set_vertical,

        .call_getCueAsHTML = &call_getCueAsHTML,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("VTTCue has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(VTTCueImpl, "init") and @hasDecl(VTTCueImpl, "initOwn")) @compileError("VTTCueImpl defines both init and initOwn");
        if (comptime @hasDecl(VTTCueImpl, "init")) return VTTCueImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(VTTCueImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try VTTCueImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(VTTCueImpl, "init")) return false;
        if (comptime @hasDecl(VTTCueImpl, "construction_args")) {
            inline for (VTTCueImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(VTTCueImpl, "deinit") and @hasDecl(VTTCueImpl, "deinitOwn")) @compileError("VTTCueImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(VTTCueImpl, "deinit")) return VTTCueImpl.deinit(instance);
        if (comptime @hasDecl(VTTCueImpl, "deinitOwn")) VTTCueImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "VTTCue")) {
            if (comptime @hasDecl(impls.VTTCue, "installHooks")) impls.VTTCue.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, startTime: f64, endTime: f64, text: runtime.DOMString) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try VTTCueImpl.call_constructor(ctx, startTime, endTime, text);
    }

    pub fn get_region(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try VTTCueImpl.get_region(instance);
    }

    pub fn set_region(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
        try VTTCueImpl.set_region(instance, value);
    }

    pub fn get_vertical(instance: *runtime.Instance) anyerror!DirectionSetting {
        return try VTTCueImpl.get_vertical(instance);
    }

    pub fn set_vertical(instance: *runtime.Instance, value: DirectionSetting) anyerror!void {
        try VTTCueImpl.set_vertical(instance, value);
    }

    pub fn get_snapToLines(instance: *runtime.Instance) anyerror!bool {
        return try VTTCueImpl.get_snapToLines(instance);
    }

    pub fn set_snapToLines(instance: *runtime.Instance, value: bool) anyerror!void {
        try VTTCueImpl.set_snapToLines(instance, value);
    }

    pub fn get_line(instance: *runtime.Instance) anyerror!LineAndPositionSetting {
        return try VTTCueImpl.get_line(instance);
    }

    pub fn set_line(instance: *runtime.Instance, value: LineAndPositionSetting) anyerror!void {
        try VTTCueImpl.set_line(instance, value);
    }

    pub fn get_lineAlign(instance: *runtime.Instance) anyerror!LineAlignSetting {
        return try VTTCueImpl.get_lineAlign(instance);
    }

    pub fn set_lineAlign(instance: *runtime.Instance, value: LineAlignSetting) anyerror!void {
        try VTTCueImpl.set_lineAlign(instance, value);
    }

    pub fn get_position(instance: *runtime.Instance) anyerror!LineAndPositionSetting {
        return try VTTCueImpl.get_position(instance);
    }

    pub fn set_position(instance: *runtime.Instance, value: LineAndPositionSetting) anyerror!void {
        try VTTCueImpl.set_position(instance, value);
    }

    pub fn get_positionAlign(instance: *runtime.Instance) anyerror!PositionAlignSetting {
        return try VTTCueImpl.get_positionAlign(instance);
    }

    pub fn set_positionAlign(instance: *runtime.Instance, value: PositionAlignSetting) anyerror!void {
        try VTTCueImpl.set_positionAlign(instance, value);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!f64 {
        return try VTTCueImpl.get_size(instance);
    }

    pub fn set_size(instance: *runtime.Instance, value: f64) anyerror!void {
        try VTTCueImpl.set_size(instance, value);
    }

    pub fn get_align(instance: *runtime.Instance) anyerror!AlignSetting {
        return try VTTCueImpl.get_align(instance);
    }

    pub fn set_align(instance: *runtime.Instance, value: AlignSetting) anyerror!void {
        try VTTCueImpl.set_align(instance, value);
    }

    pub fn get_text(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try VTTCueImpl.get_text(instance);
    }

    pub fn set_text(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        try VTTCueImpl.set_text(instance, value);
    }

    pub fn call_getCueAsHTML(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try VTTCueImpl.call_getCueAsHTML(instance);
    }

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "set_size", 0b1 },
    };
};
