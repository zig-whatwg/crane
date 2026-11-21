//! Implementation for SVGSVGElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const dom = @import("dom");
const SVGSVGElement = interfaces.SVGSVGElement;
const smil = dom.smil.document_animations;

pub const State = SVGSVGElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// What an svg element keeps: the timeline of the SVG document fragment it
/// is the outermost svg element of (SVG Animations 2 4.1), made the first
/// time an animation or a timeline method needs it - most svg elements
/// never do.
pub const InternalState = smil.Timeline;

/// The state's two exits (dom.orphan_states): this element's deinit, and the
/// sweep at its Browser's end for an orphan no deinit reaches.
const States = dom.orphan_states.Swept(.svg_svg_element, InternalState);

/// dom.smil.document_animations: `svg`'s timeline, made when `create` is
/// set.
fn timelineOf(svg: *runtime.Instance, create: bool) ?*smil.Timeline {
    const state = svg.stateAs(State) orelse return null;
    if (state.own._internal) |timeline| return timeline;
    if (!create) return null;
    const made = States.create(svg, smil.Timeline.init(svg.ctx.allocator)) catch return null;
    state.own._internal = made;
    return made;
}

/// dom.smil.document_animations: whether `element` is an svg element - the
/// brand check, one ancestry entry read.
fn isSvg(element: *runtime.Instance) bool {
    return element.stateAs(State) != null;
}

/// The timeline goes with the element: its animation elements are left on
/// none first, then what it owns.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.detach();
    state.own._internal = null;
    States.destroy(instance);
}

/// The hooks this type owns, installed once, at process start.
pub fn installHooks() void {
    States.installSweep();
    smil.installSvgElement(.{ .timeline_of = &timelineOf, .is_svg = &isSvg });
}

/// Getter for x
pub fn get_x(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for y
pub fn get_y(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for width
pub fn get_width(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for height
pub fn get_height(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for currentScale
pub fn get_currentScale(instance: *runtime.Instance) anyerror!f32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for currentTranslate
pub fn get_currentTranslate(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for currentScale
pub fn set_currentScale(instance: *runtime.Instance, value: f32) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: createSVGPoint
pub fn call_createSVGPoint(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: suspendRedraw
pub fn call_suspendRedraw(instance: *runtime.Instance, maxWaitMilliseconds: u32) anyerror!u32 {
    _ = instance;
    _ = maxWaitMilliseconds;
    return error.NotImplemented;
}

/// setCurrentTime(seconds) (SVG Animations 2 5.8): seek the timeline, or
/// record the time for one that has not begun; on the outermost svg element
/// only.
pub fn call_setCurrentTime(instance: *runtime.Instance, seconds: f32) anyerror!void {
    smil.setCurrentTime(instance, seconds);
}

/// Operation: createSVGLength
pub fn call_createSVGLength(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// animationsPaused() (5.8): whether the fragment's timeline was paused.
pub fn call_animationsPaused(instance: *runtime.Instance) anyerror!bool {
    return smil.animationsPaused(instance);
}

/// Operation: getIntersectionList
pub fn call_getIntersectionList(instance: *runtime.Instance, rect: *runtime.Instance, referenceElement: ?*runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    _ = rect;
    _ = referenceElement;
    return error.NotImplemented;
}

/// Operation: getElementById
pub fn call_getElementById(instance: *runtime.Instance, elementId: runtime.DOMString) anyerror!?*runtime.Instance {
    _ = instance;
    _ = elementId;
    return null;
}

/// Operation: unsuspendRedraw
pub fn call_unsuspendRedraw(instance: *runtime.Instance, suspendHandleID: u32) anyerror!void {
    _ = instance;
    _ = suspendHandleID;
    return error.NotImplemented;
}

/// Operation: getEnclosureList
pub fn call_getEnclosureList(instance: *runtime.Instance, rect: *runtime.Instance, referenceElement: ?*runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    _ = rect;
    _ = referenceElement;
    return error.NotImplemented;
}

/// pauseAnimations() (5.8): pause the fragment's timeline; on the
/// outermost svg element only.
pub fn call_pauseAnimations(instance: *runtime.Instance) anyerror!void {
    smil.pauseAnimations(instance);
}

/// Operation: createSVGAngle
pub fn call_createSVGAngle(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createSVGTransformFromMatrix
pub fn call_createSVGTransformFromMatrix(instance: *runtime.Instance, matrix: webidl.Opt(dictionaries.DOMMatrix2DInit)) anyerror!*runtime.Instance {
    _ = instance;
    _ = matrix;
    return error.NotImplemented;
}

/// Operation: forceRedraw
pub fn call_forceRedraw(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: unsuspendRedrawAll
pub fn call_unsuspendRedrawAll(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createSVGMatrix
pub fn call_createSVGMatrix(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// getCurrentTime() (5.8): 0 before the timeline began, else its time in
/// seconds.
pub fn call_getCurrentTime(instance: *runtime.Instance) anyerror!f32 {
    return smil.svgCurrentTime(instance);
}

/// Operation: checkIntersection
pub fn call_checkIntersection(instance: *runtime.Instance, element: *runtime.Instance, rect: *runtime.Instance) anyerror!bool {
    _ = instance;
    _ = element;
    _ = rect;
    return error.NotImplemented;
}

/// Operation: checkEnclosure
pub fn call_checkEnclosure(instance: *runtime.Instance, element: *runtime.Instance, rect: *runtime.Instance) anyerror!bool {
    _ = instance;
    _ = element;
    _ = rect;
    return error.NotImplemented;
}

/// unpauseAnimations() (5.8): unpause the fragment's timeline; on the
/// outermost svg element only.
pub fn call_unpauseAnimations(instance: *runtime.Instance) anyerror!void {
    smil.unpauseAnimations(instance);
}

/// Operation: createSVGRect
pub fn call_createSVGRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // SVG 2 §5.13.2: a new DOMRect whose x, y, width and height are all zero.
    return interfaces.DOMRect.call_constructor(instance.ctx, webidl.Opt(f64).passed(0), webidl.Opt(f64).passed(0), webidl.Opt(f64).passed(0), webidl.Opt(f64).passed(0));
}

/// Operation: createSVGTransform
pub fn call_createSVGTransform(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createSVGNumber
pub fn call_createSVGNumber(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: deselectAll
pub fn call_deselectAll(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}
