//! Web Animations: the timing model, its objects' models, and "update
//! animations and send events" (HTML update the rendering step 11).
//!
//! Lane rendering2 (2026-10-29): the timing model and its API, and the CSS
//! animation and transition events on it. Applying animated values to
//! style (the effect stack, interpolation, commitStyles) and making CSS
//! animations and transitions from style are later pieces
//! (tmp/plans/rendering2-design.md).
//!
//! Spec: https://drafts.csswg.org/web-animations-1/
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const css = @import("css");

pub const timing = @import("timing.zig");
pub const easing = @import("easing.zig");
pub const model = @import("model.zig");
pub const registry = @import("registry.zig");
pub const keyframes = @import("keyframes.zig");
pub const effect_values = @import("effect_values.zig");
pub const effect_stack = @import("effect_stack.zig");
pub const options = @import("options.zig");
pub const hooks = @import("hooks.zig");
pub const promise = @import("promise.zig");
pub const css_events = @import("css_events.zig");

pub const Registry = registry.Registry;
pub const updateAnimationsAndSendEvents = registry.updateAnimationsAndSendEvents;
pub const defaultTimeline = registry.defaultTimeline;

const Allocator = std.mem.Allocator;
const JSValue = runtime.JSValue;

// ============================================================================
// Constructors (6.3, 6.4, 6.6)
// ============================================================================

/// The Animation constructor's steps (6.4) for the new `animation`: its
/// timeline - `timeline`, or with none given the default document timeline
/// of the current global object's document - then its effect.
pub fn constructAnimation(animation_instance: *runtime.Instance, effect: ?*runtime.Instance, timeline: options.EffectOptions.TimelineMember) !void {
    const animation = hooks.animationOf(animation_instance) orelse return error.InvalidStateError;
    registry.register(animation);
    // 2.
    const new_timeline = switch (timeline) {
        .value => |value| value,
        .missing => blk: {
            const document = registry.documentOfRealm(engine.currentRealm() orelse animation_instance.ctx) orelse
                registry.documentOfRealm(animation_instance.ctx) orelse break :blk null;
            break :blk try registry.defaultTimeline(document);
        },
    };
    animation.setTimeline(new_timeline);
    // 3.
    animation.setEffect(effect);
}

/// The KeyframeEffect(target, keyframes, options) constructor's steps (6.6)
/// for the new `effect_instance`. `options` was converted first, as the
/// binding converts arguments before the steps.
pub fn constructKeyframeEffect(effect_instance: *runtime.Instance, target: ?*runtime.Instance, keyframe_input: ?JSValue, converted: *const options.EffectOptions) !void {
    const effect = hooks.effectOf(effect_instance) orelse return error.InvalidStateError;
    effect.keyframe_effect = true;
    // 2.
    effect.setTarget(target);
    // 3.
    effect.pseudo = try options.parsePseudoElement(effect.allocator, converted.pseudo_element);
    // 4-5.
    try options.updateTiming(effect, converted.timing);
    // 6.
    effect.composite = converted.composite;
    // 7.
    try setKeyframes(effect, keyframe_input);
}

/// setKeyframes(): the processed keyframes replace the effect's, unless
/// processing throws.
pub fn setKeyframes(effect: *model.Effect, keyframe_input: ?JSValue) !void {
    var list = try keyframes.process(effect.instance.ctx, effect.allocator, keyframe_input);
    errdefer list.deinit(effect.allocator);
    effect.keyframes.deinit(effect.allocator);
    effect.keyframes = list;
    if (effect.animationModel()) |animation| animation.settle();
}

/// KeyframeEffect(source): a copy of `source`'s target, keyframes,
/// composite operation and specified timing.
pub fn copyKeyframeEffect(effect_instance: *runtime.Instance, source_instance: *runtime.Instance) !void {
    const effect = hooks.effectOf(effect_instance) orelse return error.InvalidStateError;
    const source = hooks.effectOf(source_instance) orelse return error.TypeError;
    effect.keyframe_effect = true;
    effect.setTarget(source.targetElement());
    if (source.pseudo) |pseudo| effect.pseudo = try effect.allocator.dupe(u8, pseudo);
    effect.composite = source.composite;
    effect.timing.deinit(effect.allocator);
    effect.timing = try source.timing.clone(effect.allocator);
    effect.keyframes.deinit(effect.allocator);
    effect.keyframes = try source.keyframes.clone(effect.allocator);
}

// ============================================================================
// Animatable (6.8)
// ============================================================================

/// Element.animate(keyframes, options) (6.8).
pub fn animate(target: *runtime.Instance, keyframe_input: ?JSValue, options_value: ?JSValue) !*runtime.Instance {
    const realm = target.ctx;
    const allocator = realm.allocator;
    var converted = try options.effectOptions(engine.currentRealm() orelse realm, options_value, allocator, true);
    defer converted.deinit(allocator);
    // 2. A KeyframeEffect in target's relevant realm.
    const effect = try interfaces.KeyframeEffect.init(allocator, realm);
    errdefer effect.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(effect));
    try constructKeyframeEffect(effect, target, keyframe_input, &converted);
    // 3. The timeline member, or the default document timeline of target's
    // node document.
    const timeline: options.EffectOptions.TimelineMember = switch (converted.timeline) {
        .value => |value| .{ .value = value },
        .missing => blk: {
            const document = (interfaces.Node.get_ownerDocument(target) catch null) orelse break :blk .{ .value = null };
            break :blk .{ .value = try registry.defaultTimeline(document) };
        },
    };
    // 4.
    const animation_instance = try interfaces.Animation.init(allocator, realm);
    errdefer animation_instance.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(animation_instance));
    try constructAnimation(animation_instance, effect, timeline);
    const animation = hooks.animationOf(animation_instance) orelse return error.InvalidStateError;
    // 5.
    if (converted.id) |id| {
        animation.id = try allocator.dupe(u8, id);
    }
    // 6.
    try animation.play(true);
    // 7.
    return animation_instance;
}

/// Element.getAnimations(options) (6.8).
pub fn elementAnimations(element: *runtime.Instance, subtree: bool, pseudo_element: ?[]const u8) !JSValue {
    const allocator = element.ctx.allocator;
    // 2. Pseudo-element parsing.
    const pseudo = try options.parsePseudoElement(allocator, pseudo_element);
    defer if (pseudo) |p| allocator.free(p);
    const Match = struct {
        element: *runtime.Instance,
        pseudo: ?[]const u8,
        subtree: bool,
        fn matches(self: @This(), effect: *const model.Effect) bool {
            const target = effect.targetElement() orelse return false;
            const target_pseudo = effect.pseudo;
            if (self.pseudo) |wanted| {
                // 3. The pseudo-element of `element` is the target.
                if (target != self.element) return false;
                return target_pseudo != null and std.mem.eql(u8, target_pseudo.?, wanted);
            }
            if (!self.subtree) return target == self.element and target_pseudo == null;
            // "an inclusive descendant ... or a pseudo-element of such a
            // descendant".
            return target == self.element or isDescendant(target, self.element);
        }
    };
    const result = try registry.relevantAnimations(element.ctx, Match{ .element = element, .pseudo = pseudo, .subtree = subtree }, Match.matches);
    return result.take();
}

/// Document.getAnimations() / ShadowRoot.getAnimations() (6.10): the
/// relevant animations for the subtree of `root` - targets that are its
/// descendants (or their pseudo-elements).
pub fn rootAnimations(root: *runtime.Instance) !JSValue {
    const Match = struct {
        root: *runtime.Instance,
        fn matches(self: @This(), effect: *const model.Effect) bool {
            const target = effect.targetElement() orelse return false;
            return isDescendant(target, self.root);
        }
    };
    const result = try registry.relevantAnimations(root.ctx, Match{ .root = root }, Match.matches);
    return result.take();
}

/// Whether `node` is a descendant of `ancestor` (DOM, not shadow-including).
fn isDescendant(node: *runtime.Instance, ancestor: *runtime.Instance) bool {
    var current = interfaces.Node.get_parentNode(node) catch return false;
    while (current) |parent| {
        if (parent == ancestor) return true;
        current = interfaces.Node.get_parentNode(parent) catch return false;
    }
    return false;
}

test {
    // The pure parts' own tests (no engine: the dom test binary links none).
    _ = timing;
    _ = easing;
    _ = keyframes;
    _ = options;
}

// ============================================================================
// commitStyles (6.4)
// ============================================================================

const html_namespace = "http://www.w3.org/1999/xhtml";
const svg_namespace = "http://www.w3.org/2000/svg";
const mathml_namespace = "http://www.w3.org/1998/Math/MathML";

/// "Commit computed styles" (6.4) for `animation`: its effect values,
/// evaluated over the partial effect stack with the endpoint-inclusive
/// active interval, written into its target's style attribute through
/// CSSStyleDeclaration's setProperty (CSSOM "set a CSS declaration" and
/// "update style attribute for", with CEReactions as script sees them).
pub fn commitStyles(animation: *model.Animation) !void {
    // 1. The targets: Crane's effects are keyframe effects with one target.
    const effect = animation.effectModel() orelse return;
    const target = effect.targetElement() orelse return;
    // 2.1. A pseudo-element, or an element with no style attribute.
    if (effect.pseudo != null) return error.NoModificationAllowedError;
    var namespace = (interfaces.Element.get_namespaceURI(target) catch null) orelse return error.NoModificationAllowedError;
    const kind: enum { html, svg, mathml, other } = blk: {
        defer namespace.deinit(target.ctx.allocator);
        const ns = namespace.asSlice();
        if (std.mem.eql(u8, ns, html_namespace)) break :blk .html;
        if (std.mem.eql(u8, ns, svg_namespace)) break :blk .svg;
        if (std.mem.eql(u8, ns, mathml_namespace)) break :blk .mathml;
        break :blk .other;
    };
    if (kind == .other) return error.NoModificationAllowedError;
    // 2.2. "If, after applying any pending style changes, target is not being
    // rendered": a display:contents element counts as rendered here (the
    // spec's note).
    const style_engine = @import("../style/root.zig").engine;
    if (!try style_engine.isBeingRenderedOrDelegating(target)) return error.InvalidStateError;
    // 4-5.4. The partial stack's effect values for the targeted properties.
    const loop_registry = registry.of(target.ctx) orelse return;
    var commit: effect_stack.Commit = .{ .allocator = target.ctx.allocator, .animation = animation, .target = target };
    defer commit.deinit();
    loop_registry.commit = &commit;
    registry.valuesChanged(target.ctx);
    const read = style_engine.computedStyle(target, null);
    loop_registry.commit = null;
    registry.valuesChanged(target.ctx);
    _ = try read;
    if (commit.values.count() == 0) return;
    // 3, 5.5-5.6.
    const declaration = switch (kind) {
        .html => try interfaces.HTMLElement.get_style(target),
        .svg => try interfaces.SVGElement.get_style(target),
        .mathml, .other => try interfaces.MathMLElement.get_style(target),
    };
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(target.ctx.allocator);
    for (commit.values.keys(), commit.values.values()) |l, v| {
        text.clearRetainingCapacity();
        try css.properties.serializeValue(l, v, &text, target.ctx.allocator);
        try interfaces.CSSStyleDeclaration.call_setProperty(declaration, runtime.DOMString.initInterned(l.name()), runtime.DOMString.initInterned(text.items), webidl.Opt(runtime.DOMString).notPassed());
    }
}
