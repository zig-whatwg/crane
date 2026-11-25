//! WebVTT 9.1: the VTTCue interface - a WebVTT cue (3.2-3.3), the text
//! track cue WebVTT files and script make. TextTrackCue (HTML 4.8.11.11.5)
//! holds what every text track cue has; this holds the WebVTT cue settings
//! and the cue text.
//!
//! A cue keeps the VTTRegion it is in: an edge from its wrapper
//! (engine.traceChild), as Blink's VTTCue traces region_ (vtt_cue.h). A cue
//! the WebVTT parser made has no wrapper until its list hands it to script;
//! until then it names its region by a link only (its track keeps the
//! regions its file made: TextTrack's keep_region), and `exposed` draws the
//! edge.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dom = @import("dom");
const html = @import("html");
const same_object = dom.same_object;
const VTTCue = interfaces.VTTCue;

pub const State = VTTCue.State;

const region_slot: engine.TracedSlot = .{ .name = "region" };

/// A WebVTT cue's settings and cue text (WebVTT 3.3), at the values the
/// VTTCue() constructor's steps 7-15 give them.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// WebVTT cue region (null: none), and whether its edge is drawn.
    region: ?same_object.Link = null,
    region_traced: bool = false,
    /// WebVTT cue writing direction: horizontal ("").
    vertical: enums.DirectionSetting = .__,
    /// WebVTT cue snap-to-lines flag.
    snap_to_lines: bool = true,
    /// WebVTT cue line: auto.
    line: typedefs.LineAndPositionSetting = .{ .auto_keyword = ._auto_ },
    /// WebVTT cue line alignment: start.
    line_align: enums.LineAlignSetting = ._start_,
    /// WebVTT cue position: auto.
    position: typedefs.LineAndPositionSetting = .{ .auto_keyword = ._auto_ },
    /// WebVTT cue position alignment: auto.
    position_align: enums.PositionAlignSetting = ._auto_,
    /// WebVTT cue size: 100.
    size: f64 = 100,
    /// WebVTT cue text alignment: center.
    text_align: enums.AlignSetting = ._center_,
    /// The cue text, raw.
    text: runtime.DOMString = .initEmpty(),
};

pub fn installHooks() void {
    dom.media_elements.installVTTCue(exposed);
}

/// The cue has a wrapper now: the edge to its region, if it has one.
fn exposed(cue: *runtime.Instance) void {
    const internal = (cue.stateAs(State) orelse return).own._internal orelse return;
    const link = internal.region orelse return;
    if (internal.region_traced or !link.isLive()) return;
    engine.traceChild(cue, link.instance, region_slot);
    internal.region_traced = true;
}

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(State).own._internal = internal;
}

/// The cue's own teardown: its region's edge goes by name only (the region
/// may be gone).
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        state.own._internal = null;
        if (internal.region_traced) engine.forgetTracedChild(instance, region_slot);
        internal.text.deinit(internal.allocator);
        internal.allocator.destroy(internal);
    }
}

fn internalOf(instance: *runtime.Instance) !*InternalState {
    return (instance.stateAs(State) orelse return error.InvalidStateError).own._internal orelse error.InvalidStateError;
}

/// The VTTCue(startTime, endTime, text) constructor.
pub fn call_constructor(cue: *runtime.Instance, startTime: f64, endTime: f64, text: runtime.DOMString) !void {
    // 1. A new WebVTT cue: `cue`, which the generated constructor made
    // (WebIDL 3.7.1 step 1.8) and frees whole when a step fails (lane ctor1).
    // 3. An end time of negative Infinity or NaN: TypeError.
    if (std.math.isNan(endTime) or endTime == -std.math.inf(f64)) return error.TypeError;
    // 5-15. its identifier "", pause-on-exit false, region null, writing
    // direction horizontal, snap-to-lines true, line auto, line alignment
    // start, position auto, position alignment auto, size 100, text
    // alignment center (InternalState's and TextTrackCue's initial values).
    const internal = internalOf(cue) catch unreachable;
    // 2-3. Its start and end times. Neither setter can fail on a cue in no
    // list.
    interfaces.TextTrackCue.set_startTime(cue, startTime) catch unreachable;
    interfaces.TextTrackCue.set_endTime(cue, endTime) catch unreachable;
    // 4. Its cue text (the WebVTT rules for extracting the chapter title
    // are the format's own).
    internal.text = try text.clone(internal.allocator);
    // 16. Return cue: the generated constructor does.
}

/// "The VTTRegion object representing the WebVTT cue region ... if any; or
/// null otherwise."
pub fn get_region(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const link = (try internalOf(instance)).region orelse return null;
    return if (link.isLive()) link.instance else null;
}

/// "On setting, the WebVTT cue region must be set to the new value."
pub fn set_region(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    const internal = try internalOf(instance);
    if (value) |region| {
        internal.region = same_object.Link.to(region);
        // A cue with no wrapper yet draws its edge when it gets one
        // (`exposed`).
        if (dom.media_elements.mayBeWrapped(instance)) {
            engine.traceChild(instance, region, region_slot);
            internal.region_traced = true;
        } else if (internal.region_traced) {
            engine.forgetTracedChild(instance, region_slot);
            internal.region_traced = false;
        }
    } else {
        internal.region = null;
        if (internal.region_traced) engine.forgetTracedChild(instance, region_slot);
        internal.region_traced = false;
    }
}

pub fn get_vertical(instance: *runtime.Instance) anyerror!enums.DirectionSetting {
    return (try internalOf(instance)).vertical;
}

pub fn set_vertical(instance: *runtime.Instance, value: enums.DirectionSetting) anyerror!void {
    (try internalOf(instance)).vertical = value;
}

pub fn get_snapToLines(instance: *runtime.Instance) anyerror!bool {
    return (try internalOf(instance)).snap_to_lines;
}

/// The API rejects no combination of snapToLines and line, so either can be
/// set first (9.1's note).
pub fn set_snapToLines(instance: *runtime.Instance, value: bool) anyerror!void {
    (try internalOf(instance)).snap_to_lines = value;
}

pub fn get_line(instance: *runtime.Instance) anyerror!typedefs.LineAndPositionSetting {
    return (try internalOf(instance)).line;
}

/// "On setting, the WebVTT cue line must be set to the new value; if the
/// new value is the string "auto", then it must be interpreted as the
/// special value auto."
pub fn set_line(instance: *runtime.Instance, value: typedefs.LineAndPositionSetting) anyerror!void {
    (try internalOf(instance)).line = value;
}

pub fn get_lineAlign(instance: *runtime.Instance) anyerror!enums.LineAlignSetting {
    return (try internalOf(instance)).line_align;
}

pub fn set_lineAlign(instance: *runtime.Instance, value: enums.LineAlignSetting) anyerror!void {
    (try internalOf(instance)).line_align = value;
}

pub fn get_position(instance: *runtime.Instance) anyerror!typedefs.LineAndPositionSetting {
    return (try internalOf(instance)).position;
}

/// "On setting, if the new value is negative or greater than 100, then an
/// IndexSizeError exception must be thrown. Otherwise, the WebVTT cue
/// position must be set to the new value" ("auto": the special value auto).
pub fn set_position(instance: *runtime.Instance, value: typedefs.LineAndPositionSetting) anyerror!void {
    const internal = try internalOf(instance);
    switch (value) {
        .double => |number| if (number < 0 or number > 100) return error.IndexSizeError,
        .auto_keyword => {},
    }
    internal.position = value;
}

pub fn get_positionAlign(instance: *runtime.Instance) anyerror!enums.PositionAlignSetting {
    return (try internalOf(instance)).position_align;
}

pub fn set_positionAlign(instance: *runtime.Instance, value: enums.PositionAlignSetting) anyerror!void {
    (try internalOf(instance)).position_align = value;
}

pub fn get_size(instance: *runtime.Instance) anyerror!f64 {
    return (try internalOf(instance)).size;
}

/// "On setting, if the new value is negative or greater than 100, then an
/// IndexSizeError exception must be thrown."
pub fn set_size(instance: *runtime.Instance, value: f64) anyerror!void {
    if (value < 0 or value > 100) return error.IndexSizeError;
    (try internalOf(instance)).size = value;
}

pub fn get_align(instance: *runtime.Instance) anyerror!enums.AlignSetting {
    return (try internalOf(instance)).text_align;
}

pub fn set_align(instance: *runtime.Instance, value: enums.AlignSetting) anyerror!void {
    (try internalOf(instance)).text_align = value;
}

/// "The raw cue text."
pub fn get_text(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return (try internalOf(instance)).text.clone(instance.ctx.allocator);
}

pub fn set_text(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = try internalOf(instance);
    const copy = try value.clone(internal.allocator);
    internal.text.deinit(internal.allocator);
    internal.text = copy;
}

/// "Convert the cue text to a DocumentFragment for the responsible document
/// specified by the entry settings object by applying the WebVTT cue text
/// DOM construction rules to the result of applying the WebVTT cue text
/// parsing rules to the cue text" - with no fallback language.
pub fn call_getCueAsHTML(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = try internalOf(instance);
    const document = entryDocument() orelse relevantDocument(instance) orelse return error.InvalidStateError;
    // Empty cue text: the parsing rules return an empty list, and the DOM
    // construction rules an empty fragment. Chrome, Firefox and Safari all
    // answer a fragment holding one empty Text node instead (Blink's
    // VTTParser::CreateDocumentFragmentFromCueText appends Text::Create(
    // document, "") for empty cue text), and
    // track-element/track-cue-empty.html expects it: wpt.fyi 1/1 in Chrome
    // 157 (run 4786307730243584), Firefox 160 (4877168468033536) and Safari
    // 27.2 (6479119966273536). No newer spec is involved: golden rule 2
    // takes the browsers' Text node.
    if (internal.text.asSlice().len == 0) return html.webvtt.emptyCueTextFragment(document);
    var tree = try html.webvtt.parseCueText(instance.ctx.allocator, internal.text.asSlice(), null);
    defer tree.deinit();
    return html.webvtt.cueTextFragment(document, tree.root);
}

/// The entry settings object's responsible document: the document of the
/// window whose realm is the entry realm (as Location.zig's entryDocument).
fn entryDocument() ?*runtime.Instance {
    const realm = engine.entryRealm() orelse return null;
    const record = realm.getRealm() orelse return null;
    const window: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    if (window.stateAs(interfaces.Window.State) == null) return null;
    return interfaces.Window.get_document(window) catch null;
}

/// With no script running (no entry realm), the cue's own realm's document.
fn relevantDocument(instance: *runtime.Instance) ?*runtime.Instance {
    const realm = instance.ctx.getRealm() orelse return null;
    const window: *runtime.Instance = @ptrCast(@alignCast(realm.global_object orelse return null));
    if (window.stateAs(interfaces.Window.State) == null) return null;
    return interfaces.Window.get_document(window) catch null;
}
