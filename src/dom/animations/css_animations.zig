//! CSS Animations made from style: CSS Animations 1 section 2 (the model,
//! the animation-name matching) and section 3 (@keyframes), CSS Animations 2
//! section 2 (the script overrides), 2.1 (the owning element), 2.2 (composite
//! order), 3.2 (processing keyframes) and 4.5 (animation-play-state).
//!
//! The style engine runs `styleChangeEvent` for an element (or one of its
//! pseudo-elements) at each of its style change events (the same events as
//! CSS transitions, tmp/plans/anim1b2-design.md section 1), BEFORE the
//! transition steps: Blink runs CSSAnimations::CalculateAnimationUpdate
//! before CalculateTransitionUpdate, and skips both at an animation-only
//! recalc. No before-change style is needed: the first resolution of an
//! element makes its animations (tmp/plans/anim1b3-design.md section 1).
//!
//! A CSSAnimation is a platform object (the CSSAnimation interface, made
//! through its generated file, never its impl) with a KeyframeEffect whose
//! keyframes come from the @keyframes rule the style engine found for the
//! name: values kept as declared text (var() included) and computed through
//! the cascade at each sample like every keyframe (the lesson "compute
//! animation keyframes through the cascade"); the generated 0%/100%
//! keyframes hold no value (IMPLICIT: the effect stack samples the
//! underlying value there, Blink's neutral keyframes, and getKeyframes()
//! fills in the base computed value: Blink CssKeyframeEffectModel::
//! GetComputedKeyframes, Gecko CSSAnimationKeyframeEffect::GetKeyframes).
//!
//! Ownership (the lesson "a browser's strong hold comes with the step that
//! ends it"; Blink's CSSAnimations::running_animations_ hold each Animation
//! as a Member while animation-name names it):
//!   - the element's ElementStyle owns `ElementAnimations` (inside the one
//!     pointer it shares with the transitions): BORROWED, generation-checked
//!     links to its CSSAnimations, in animation-name order per pseudo. No
//!     engine handle: the element's teardown frees it with no engine call.
//!   - a listed CSSAnimation keeps itself alive (`CssAnimation.listed`, read
//!     by Animation.settle) - finished ones too, since animation-name still
//!     names them and a collected one would restart - and leaves the list at
//!     a cancel from style (the name dropped, its rule gone, the element not
//!     rendered, the sweep after its removal); the window's end releases
//!     every animation's keep (Registry.windowDestroyed, endPage).
//!
//! Spec: https://drafts.csswg.org/css-animations-1/#animations
//! Spec: https://drafts.csswg.org/css-animations-2/#keyframes
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const css = @import("css");
const model = @import("model.zig");
const hooks = @import("hooks.zig");
const registry_mod = @import("registry.zig");
const css_events = @import("css_events.zig");
const keyframes_mod = @import("keyframes.zig");
const easing_mod = @import("easing.zig");
const options_mod = @import("options.zig");
const element_style = @import("../style/element_style.zig");
const style_rules = @import("../style/rules.zig");
const instance_bridge = @import("../instance_bridge.zig");

const Allocator = std.mem.Allocator;
const Value = css.style_values.Value;
const Longhand = css.properties.Longhand;
const ComputedStyle = css.computed_style.ComputedStyle;
const ListItem = css.animation_values.Item;
const Rule = style_rules.Rule;

// ============================================================================
// The animation's own state, and the element's list
// ============================================================================

/// What script overrode (CSS Animations 2 section 2): a later change to the
/// matching animation-* property or @keyframes rule is not reflected. WebKit
/// CSSAnimation::m_overriddenProperties; Blink's ignore_css_* flags.
pub const Overrides = packed struct {
    /// setKeyframes() succeeded.
    keyframes: bool = false,
    /// updateTiming() set the member.
    duration: bool = false,
    iterations: bool = false,
    direction: bool = false,
    delay: bool = false,
    fill: bool = false,
    /// play(), pause(), cancel(), or reverse() / the startTime setter changed
    /// the play state to or from paused.
    play_state: bool = false,
    /// The effect was set to null or another effect: only animation-name,
    /// animation-play-state and animation-timeline are reflected.
    effect: bool = false,
};

/// A CSS animation's own state (CSS Animations 2 6.1). OWNED by its
/// css_events.State.
pub const CssAnimation = struct {
    /// The bare pseudo-element name ("before"), OWNED; null for the element.
    pseudo: ?[]u8,
    /// Its position in the computed animation-name list (CSS Animations 2
    /// 2.2: the composite order among one owning element's animations).
    index: usize,
    /// A member of its owning element's list: it keeps itself alive
    /// (Animation.settle) until it leaves the list.
    listed: bool = true,
    /// The @keyframes rule its keyframes were built from - its address,
    /// compared only, never dereferenced - and the style engine generation
    /// they were built at: a moved generation (any sheet change, CSSOM
    /// keyframe edits included) rebuilds them. Blink compares the rule's
    /// version (StyleRuleKeyframes::Version) the same way.
    rule: usize = 0,
    built_generation: u64 = 0,
    /// The animation-timing-function and animation-composition items its
    /// keyframes defaulted to (CSS Animations 2 3.2 step 1).
    default_easing: []u8 = &.{},
    default_composite: keyframes_mod.CompositeOrAuto = .replace,
    /// The animation-play-state it last resolved to (4.5 "newly paused").
    paused: bool = false,
    overrides: Overrides = .{},
    /// It lost its owning element: it takes a new place in the global
    /// animation list the first time it leaves idle (CSS Animations 2 2.2;
    /// Gecko Animation::mNeedsNewAnimationIndexWhenRun).
    needs_new_sequence: bool = false,

    pub fn destroy(self: *CssAnimation, allocator: Allocator) void {
        if (self.pseudo) |p| allocator.free(p);
        allocator.free(self.default_easing);
        allocator.destroy(self);
    }
};

/// An element's CSS animations, for it and its pseudo-elements. OWNED by
/// its ElementStyle (element_style.StyleAnimations).
pub const ElementAnimations = struct {
    /// Borrowed, generation-checked links, each kept alive by itself while
    /// it is listed.
    list: std.ArrayListUnmanaged(model.Link) = .empty,
    /// The element left the document since (its removing steps): the next
    /// sweep or style change event cancels its animations.
    removed: bool = false,

    pub fn deinit(self: *ElementAnimations, allocator: Allocator) void {
        self.list.deinit(allocator);
    }

    fn remove(self: *ElementAnimations, instance: *runtime.Instance) void {
        var i: usize = 0;
        while (i < self.list.items.len) {
            const link = self.list.items[i];
            if (link.instance == instance or link.get() == null) {
                _ = self.list.orderedRemove(i);
            } else i += 1;
        }
    }
};

fn samePseudo(a: ?[]const u8, b: ?[]const u8) bool {
    const x = a orelse return b == null;
    const y = b orelse return false;
    return std.mem.eql(u8, x, y);
}

/// The CSS animation state of `animation`, when it is a CSS animation made
/// from style.
pub fn stateOf(animation: *const model.Animation) ?*CssAnimation {
    const state = animation.css orelse return null;
    return state.css_animation;
}

/// Whether `animation` is listed by its owning element (Animation.settle
/// keeps it alive then).
pub fn isListedMember(animation: *const model.Animation) bool {
    const state = stateOf(animation) orelse return false;
    return state.listed;
}

fn owningElement(animation: *const model.Animation) ?*runtime.Instance {
    const state = animation.css orelse return null;
    const link = state.owning_element orelse return null;
    return link.get();
}

fn setOf(element: *runtime.Instance) ?*ElementAnimations {
    const state = element_style.existingOf(element) orelse return null;
    const both = state.animations orelse return null;
    return &both.css_animations;
}

fn ensureSet(element: *runtime.Instance) Allocator.Error!*ElementAnimations {
    const state = element_style.of(element) orelse return error.OutOfMemory;
    const both = try state.ensureAnimations();
    return &both.css_animations;
}

/// `animation` leaves its owning element's list.
fn leaveList(animation: *model.Animation) void {
    const state = stateOf(animation) orelse return;
    if (!state.listed) return;
    state.listed = false;
    if (owningElement(animation)) |element| if (setOf(element)) |set| set.remove(animation.instance);
}

// ============================================================================
// The coordinated animation-* lists of the after-change style
// ============================================================================

/// The after-change style's animation-* values, coordinated with
/// animation-name (CSS Values 4 A "coordinating list-valued properties": the
/// other lists repeat or are truncated to its length).
const Lists = struct {
    style: *const ComputedStyle,

    fn item(self: Lists, l: Longhand, index: usize) ?ListItem {
        const v = self.style.get(l);
        return switch (v) {
            .animation_list => |list| if (list.items.items.len == 0) null else list.items.items[index % list.items.items.len],
            .keyword => |k| .{ .keyword = k },
            .number => |n| .{ .number = if (l == .animation_delay or l == .animation_duration) .{ .literal = .{ .value = n, .unit = .s } } else css.numeric_values.Number.scalar(n) },
            else => null,
        };
    }

    fn keyword(self: Lists, l: Longhand, index: usize) ?css.style_values.Keyword {
        const it = self.item(l, index) orelse return null;
        return if (it == .keyword) it.keyword else null;
    }

    /// A time item in milliseconds; null for one that is not a resolved time.
    fn ms(it: ?ListItem) ?f64 {
        const i = it orelse return null;
        if (i != .number) return null;
        const n = switch (i.number) {
            .literal => |literal| literal,
            .calculation => return null,
        };
        return switch (n.unit) {
            .s => n.value * 1000,
            .ms => n.value,
            else => null,
        };
    }

    /// CSS Animations 2 4.1: `auto` is 0s for a time-driven animation.
    fn duration(self: Lists, index: usize) f64 {
        return @max(ms(self.item(.animation_duration, index)) orelse 0, 0);
    }

    fn delay(self: Lists, index: usize) f64 {
        return ms(self.item(.animation_delay, index)) orelse 0;
    }

    fn iterations(self: Lists, index: usize) f64 {
        const it = self.item(.animation_iteration_count, index) orelse return 1;
        switch (it) {
            .keyword => |k| return if (k == .infinite) std.math.inf(f64) else 1,
            .number => |n| return switch (n) {
                .literal => |literal| @max(literal.value, 0),
                .calculation => 1,
            },
            else => return 1,
        }
    }

    fn direction(self: Lists, index: usize) @import("timing.zig").Direction {
        return switch (self.keyword(.animation_direction, index) orelse .normal) {
            .reverse => .reverse,
            .alternate => .alternate,
            .alternate_reverse => .alternate_reverse,
            else => .normal,
        };
    }

    fn fill(self: Lists, index: usize) @import("timing.zig").FillMode {
        return switch (self.keyword(.animation_fill_mode, index) orelse .none) {
            .forwards => .forwards,
            .backwards => .backwards,
            .both => .both,
            else => .none,
        };
    }

    fn paused(self: Lists, index: usize) bool {
        return self.keyword(.animation_play_state, index) == .paused;
    }

    fn composite(self: Lists, index: usize) keyframes_mod.CompositeOrAuto {
        return switch (self.keyword(.animation_composition, index) orelse .replace) {
            .add => .add,
            .accumulate => .accumulate,
            else => .replace,
        };
    }

    /// animation-timeline (CSS Animations 2 4.11): `auto` is the default
    /// document timeline; `none` no timeline. A named, scroll() or view()
    /// timeline is scroll-driven, which Crane does not run (geometry): no
    /// timeline, stated.
    fn usesDocumentTimeline(self: Lists, index: usize) bool {
        const it = self.item(.animation_timeline, index) orelse return true;
        return it == .keyword and it.keyword == .auto;
    }

    /// The animation-timing-function item, serialized (OWNED).
    fn easingText(self: Lists, allocator: Allocator, index: usize) Allocator.Error![]u8 {
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(allocator);
        if (self.item(.animation_timing_function, index)) |it| {
            try it.serialize(.animation_timing_function, &out, allocator);
        } else try out.appendSlice(allocator, "ease");
        return out.toOwnedSlice(allocator);
    }
};

// ============================================================================
// The style change event
// ============================================================================

/// Finds the @keyframes rule an animation-name item refers to: the style
/// engine's lookup (CSS Animations 1 section 3, the declaring tree first:
/// CSS Scoping tree-scoped references).
pub const Keyframes = struct {
    context: *anyopaque,
    find: *const fn (context: *anyopaque, declaring_scope: u64, name: []const u8) ?*Rule,
};

/// What a style change event is given about one element (or pseudo-element).
pub const Event = struct {
    /// The after-change style: the new base style (animation-* are not
    /// animatable, so the base style's are the computed ones).
    after: *const ComputedStyle,
    /// The element is being rendered now, judged on its base style
    /// (CSS Animations 2 2.1: "when ignoring the Transitions and Animations
    /// cascade origins").
    rendered: bool,
    keyframes: Keyframes,
    /// The style engine's generation now (the keyframes' version).
    generation: u64,
};

/// CSS Animations 1 section 2 / CSS Animations 2 2.1 and 3.2 for (element,
/// pseudo) at one of its style change events. Returns whether an animation
/// was made, canceled or changed (the element's effects moved).
pub fn styleChangeEvent(element: *runtime.Instance, pseudo: ?[]const u8, event: Event) bool {
    // The no-animations path: one read of animation-name, one null check.
    const names = event.after.get(.animation_name);
    const existing = setOf(element);
    const listed = if (existing) |set| set.list.items.len != 0 else false;
    if (names != .animation_list and !listed) return false;
    const realm = element.ctx;
    if (!realm.hasEngine()) return false;
    if (registry_mod.of(realm) == null) return false;
    var changed = false;
    if (existing) |set| if (set.removed) {
        // The element left the document since: its animations end.
        changed = cancelAll(set, null, true) or changed;
        set.removed = false;
    };
    // CSS Animations 2 2.1: "If the display property of an element is set
    // to none and its display value would compute to none when ignoring the
    // Transitions and Animations cascade origins, then terminate running
    // animations with this owning element." A ::before/::after that
    // generates no box (content none or normal) has none to run either, as
    // Blink only animates an existing PseudoElement.
    if (!event.rendered or !generated(event.after, pseudo)) {
        if (setOf(element)) |set| changed = cancelAll(set, pseudo, false) or changed;
        return changed;
    }
    var run: Run = .{ .allocator = realm.allocator, .element = element, .pseudo = pseudo, .event = event, .lists = .{ .style = event.after } };
    run.update() catch {};
    return changed or run.changed;
}

fn generated(style: *const ComputedStyle, pseudo: ?[]const u8) bool {
    const p = pseudo orelse return true;
    if (!std.mem.eql(u8, p, "before") and !std.mem.eql(u8, p, "after")) return true;
    return style.get(.content) == .content;
}

/// One style change event's update of (element, pseudo)'s animations.
const Run = struct {
    allocator: Allocator,
    element: *runtime.Instance,
    pseudo: ?[]const u8,
    event: Event,
    lists: Lists,
    changed: bool = false,

    const Wanted = struct { index: usize, name: []const u8, rule: *Rule };

    fn update(self: *Run) Allocator.Error!void {
        const allocator = self.allocator;
        // The animations the after-change style asks for, in order: a name
        // with no @keyframes rule makes none (CSS Animations 2 3.2 step 2.1:
        // "no animation is generated, and any existing animation matching
        // name is canceled"), and `none` none.
        var wanted: std.ArrayListUnmanaged(Wanted) = .empty;
        defer wanted.deinit(allocator);
        const names = self.event.after.get(.animation_name);
        if (names == .animation_list) {
            const list = names.animation_list;
            for (list.items.items, 0..) |it, index| {
                if (it != .name) continue;
                const rule = self.event.keyframes.find(self.event.keyframes.context, list.tree_scope.serial, it.name) orelse continue;
                try wanted.append(allocator, .{ .index = index, .name = it.name, .rule = rule });
            }
        }
        // The existing animations of (element, pseudo), in list order.
        var old: std.ArrayListUnmanaged(*model.Animation) = .empty;
        defer old.deinit(allocator);
        if (setOf(self.element)) |set| for (set.list.items) |link| {
            const instance = link.get() orelse continue;
            const animation = hooks.animationOf(instance) orelse continue;
            const state = stateOf(animation) orelse continue;
            if (!state.listed or !samePseudo(state.pseudo, self.pseudo)) continue;
            try old.append(allocator, animation);
        };
        const matched = try allocator.alloc(bool, old.items.len);
        defer allocator.free(matched);
        @memset(matched, false);
        const result = try allocator.alloc(?*model.Animation, wanted.items.len);
        defer allocator.free(result);
        @memset(result, null);
        // CSS Animations 1 section 2: "iterating over the new list of
        // animations from last to first, and, for each animation, finding the
        // *last* matching animation in the list of existing animations. ...
        // The matching animation is removed from the existing list of
        // animations such that it will not match twice." Gecko
        // nsAnimationManager BuildAnimations (PopExistingAnimation) does this;
        // Blink matches a name's n-th occurrence, which differs only for
        // duplicated names.
        var j = wanted.items.len;
        while (j > 0) {
            j -= 1;
            var k = old.items.len;
            while (k > 0) {
                k -= 1;
                if (matched[k]) continue;
                if (!std.mem.eql(u8, css_events.nameOf(old.items[k]), wanted.items[j].name)) continue;
                matched[k] = true;
                result[j] = old.items[k];
                break;
            }
        }
        // "If a match is found, the existing animation is updated using the
        // animation properties corresponding to its position in the new list
        // of animations, whilst maintaining its current playback time ... If a
        // match is not found, a new animation is created."
        for (wanted.items, result) |w, *slot| {
            if (slot.*) |animation| {
                if (try self.updateExisting(animation, w)) self.changed = true;
            } else {
                slot.* = try self.make(w);
                if (slot.* != null) self.changed = true;
            }
        }
        // The existing animations nothing matched end.
        for (old.items, matched) |animation, was_matched| {
            if (was_matched) continue;
            cancelFromStyle(animation);
            self.changed = true;
        }
        // The list: the other pseudo-elements' animations, then these in
        // animation-name order.
        const set = try ensureSet(self.element);
        var i: usize = 0;
        while (i < set.list.items.len) {
            const instance = set.list.items[i].get() orelse {
                _ = set.list.orderedRemove(i);
                continue;
            };
            const animation = hooks.animationOf(instance);
            const state = if (animation) |a| stateOf(a) else null;
            if (state == null or samePseudo(state.?.pseudo, self.pseudo)) {
                _ = set.list.orderedRemove(i);
                continue;
            }
            i += 1;
        }
        try set.list.ensureUnusedCapacity(allocator, result.len);
        for (result) |slot| if (slot) |animation| set.list.appendAssumeCapacity(model.Link.to(animation.instance));
    }

    /// An existing animation, updated in place (CSS Animations 1 section 2:
    /// "Changes to the values of animation properties while the animation is
    /// running apply as if the animation had those values from when it
    /// began"), except what script overrode (CSS Animations 2 section 2).
    fn updateExisting(self: *Run, animation: *model.Animation, w: Wanted) Allocator.Error!bool {
        const state = stateOf(animation).?;
        const index = w.index;
        var changed = state.index != index;
        state.index = index;
        // A canceled (idle) animation stays as script left it: "it should
        // be possible to cancel an animation from script such that all
        // future changes to style are ignored" (css-animations
        // CSSAnimation-canceling.tentative); its name and position still
        // follow.
        const effect: ?*model.Effect = if (state.overrides.effect) null else animation.effectModel();
        if (effect) |e| {
            var timing_changed = false;
            const t = &e.timing;
            if (!state.overrides.duration) {
                const d = self.lists.duration(index);
                if (t.duration == null or t.duration.? != d) {
                    t.duration = d;
                    timing_changed = true;
                }
            }
            if (!state.overrides.iterations) {
                const n = self.lists.iterations(index);
                if (t.iterations != n) {
                    t.iterations = n;
                    timing_changed = true;
                }
            }
            if (!state.overrides.direction) {
                const d = self.lists.direction(index);
                if (t.direction != d) {
                    t.direction = d;
                    timing_changed = true;
                }
            }
            if (!state.overrides.delay) {
                const d = self.lists.delay(index);
                if (t.delay != d) {
                    t.delay = d;
                    timing_changed = true;
                }
            }
            if (!state.overrides.fill) {
                const f = self.lists.fill(index);
                if (t.fill != f) {
                    t.fill = f;
                    timing_changed = true;
                }
            }
            if (timing_changed) {
                animation.updateFinishedState(false, false);
                changed = true;
            }
            // The keyframes follow the rule, its edits and the defaults it
            // was built with - until setKeyframes().
            if (!state.overrides.keyframes) {
                const easing_text = try self.lists.easingText(self.allocator, index);
                defer self.allocator.free(easing_text);
                const composite = self.lists.composite(index);
                if (state.rule != @intFromPtr(w.rule) or state.built_generation != self.event.generation or
                    !std.mem.eql(u8, state.default_easing, easing_text) or state.default_composite != composite)
                {
                    var list = try buildKeyframes(self.allocator, w.rule, easing_text, composite);
                    errdefer list.deinit(self.allocator);
                    const owned_easing = try self.allocator.dupe(u8, easing_text);
                    e.keyframes.deinit(self.allocator);
                    e.keyframes = list;
                    e.composite = compositeOf(composite);
                    self.allocator.free(state.default_easing);
                    state.default_easing = owned_easing;
                    state.default_composite = composite;
                    state.rule = @intFromPtr(w.rule);
                    state.built_generation = self.event.generation;
                    changed = true;
                }
            }
        }
        // CSS Animations 2 4.11: the timeline.
        const document = (interfaces.Node.get_ownerDocument(self.element) catch null) orelse return changed;
        const wanted_timeline: ?*runtime.Instance = if (self.lists.usesDocumentTimeline(index)) (registry_mod.defaultTimeline(document) catch null) else null;
        const current_timeline: ?*runtime.Instance = if (animation.timeline) |link| link.get() else null;
        if (current_timeline != wanted_timeline) {
            animation.setTimeline(wanted_timeline);
            changed = true;
        }
        // 4.5: "If at any time ... the resolved value of animation-play-state
        // corresponding to an animation is newly running, ... play an
        // animation ... with the auto-rewind flag set to false"; "newly
        // paused, ... pause an animation" - unless script overrode it.
        const paused = self.lists.paused(index);
        if (paused != state.paused) {
            state.paused = paused;
            if (!state.overrides.play_state) {
                playOrPause(animation, paused);
                changed = true;
            }
        }
        if (changed) animation.settle();
        return changed;
    }

    /// Make, associate and play (or pause) a CSSAnimation for `w`.
    fn make(self: *Run, w: Wanted) Allocator.Error!?*model.Animation {
        const allocator = self.allocator;
        const element = self.element;
        const realm = element.ctx;
        const index = w.index;
        const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return null;
        const timeline: ?*runtime.Instance = if (self.lists.usesDocumentTimeline(index)) (registry_mod.defaultTimeline(document) catch return null) else null;
        const easing_text = try self.lists.easingText(allocator, index);
        var easing_owned = true;
        defer if (easing_owned) allocator.free(easing_text);
        const composite = self.lists.composite(index);
        var list = try buildKeyframes(allocator, w.rule, easing_text, composite);
        var list_owned = true;
        defer if (list_owned) list.deinit(allocator);

        // The effect: target, timing (CSS Animations 2 4.x: the effect's
        // easing is linear, animation-timing-function goes on the
        // keyframes), keyframes, composite (4.10).
        const effect_instance = interfaces.KeyframeEffect.init(allocator, realm) catch return null;
        const effect_generation = runtime.SlabAllocator.generationOf(effect_instance);
        var effect_wrapped = false;
        defer if (!effect_wrapped) effect_instance.releaseIfUnwrapped(effect_generation);
        const effect = hooks.effectOf(effect_instance) orelse return null;
        effect.keyframe_effect = true;
        effect.setTarget(element);
        if (self.pseudo) |p| effect.pseudo = try std.mem.concat(allocator, u8, &.{ "::", p });
        effect.timing.deinit(allocator);
        effect.timing = .{
            .duration = self.lists.duration(index),
            .iterations = self.lists.iterations(index),
            .direction = self.lists.direction(index),
            .delay = self.lists.delay(index),
            .fill = self.lists.fill(index),
        };
        effect.composite = compositeOf(composite);
        effect.keyframes.deinit(allocator);
        effect.keyframes = list;
        list_owned = false;

        // The animation, wrapped at once: its lifetime is its wrapper's, as
        // for every platform object script has not seen yet.
        const instance = interfaces.CSSAnimation.init(allocator, realm) catch return null;
        const owned = engine.retainValue(realm, .{ .instance = instance }) catch {
            instance.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(instance));
            return null;
        };
        defer owned.release();
        const animation = hooks.animationOf(instance) orelse return null;
        @import("root.zig").constructAnimation(instance, effect_instance, .{ .value = timeline }) catch return null;
        effect_wrapped = true;
        var selector_buffer: std.ArrayList(u8) = .empty;
        defer selector_buffer.deinit(allocator);
        if (self.pseudo) |p| {
            try selector_buffer.appendSlice(allocator, "::");
            try selector_buffer.appendSlice(allocator, p);
        }
        try css_events.attach(animation, .animation, element, selector_buffer.items, w.name);
        const set = try ensureSet(element);
        try set.list.ensureUnusedCapacity(allocator, 1);
        const state = try allocator.create(CssAnimation);
        errdefer allocator.destroy(state);
        const owned_pseudo: ?[]u8 = if (self.pseudo) |p| try allocator.dupe(u8, p) else null;
        state.* = .{
            .pseudo = owned_pseudo,
            .index = index,
            .rule = @intFromPtr(w.rule),
            .built_generation = self.event.generation,
            .default_easing = easing_text,
            .default_composite = composite,
            .paused = self.lists.paused(index),
        };
        easing_owned = false;
        // From here nothing fails: the css_events state owns it.
        animation.css.?.css_animation = state;
        set.list.appendAssumeCapacity(model.Link.to(instance));
        // 4.5, "including when the animation is first generated".
        playOrPause(animation, state.paused);
        return animation;
    }
};

/// CSS Animations 2 4.5: "play an animation ... with the auto-rewind flag
/// set to false", or "pause an animation".
fn playOrPause(animation: *model.Animation, paused: bool) void {
    if (paused) {
        animation.pause() catch {};
    } else {
        animation.play(false) catch {};
    }
}

fn compositeOf(composite: keyframes_mod.CompositeOrAuto) model.Composite {
    return switch (composite) {
        .add => .add,
        .accumulate => .accumulate,
        else => .replace,
    };
}

/// Cancel every listed animation of (element, pseudo) - every pseudo too
/// when `every` - and say whether there was one.
fn cancelAll(set: *ElementAnimations, pseudo: ?[]const u8, every: bool) bool {
    var any = false;
    var i: usize = set.list.items.len;
    while (i > 0) {
        i -= 1;
        if (i >= set.list.items.len) continue;
        const instance = set.list.items[i].get() orelse {
            _ = set.list.orderedRemove(i);
            continue;
        };
        const animation = hooks.animationOf(instance) orelse continue;
        const state = stateOf(animation) orelse continue;
        if (!every and !samePseudo(state.pseudo, pseudo)) continue;
        cancelFromStyle(animation);
        any = true;
    }
    return any;
}

/// Cancel a CSS animation from style and disassociate it from its owning
/// element (CSS Animations 2 2.1). Its animationcancel is queued first, at
/// the owning element it had, with its position then (2.2 last paragraph);
/// Gecko CSSAnimation::CancelFromStyle, Blink ClearOwningElement + cancel -
/// css_transitions.cancelFromStyle's order.
pub fn cancelFromStyle(animation: *model.Animation) void {
    leaveList(animation);
    animation.cancel();
    css_events.update(animation);
    css_events.detach(animation);
    if (stateOf(animation)) |state| state.needs_new_sequence = true;
    animation.settle();
}

/// Animation.settle, for a CSS animation: one that lost its owning element
/// is appended to the global animation list the first time it leaves idle
/// (CSS Animations 2 2.2: "these animations are appended to the global
/// animation list at the first moment when they transition out of the idle
/// play state after being disassociated from their owning element").
pub fn settled(animation: *model.Animation) void {
    const state = stateOf(animation) orelse return;
    if (!state.needs_new_sequence or css_events.hasOwningElement(animation)) return;
    if (animation.playState() == .idle) return;
    state.needs_new_sequence = false;
    registry_mod.takeSequence(animation);
}

// ============================================================================
// Keyframes (CSS Animations 2 3.2)
// ============================================================================

/// One group of keyframe blocks: those sharing a selector offset, a last
/// declared animation-timing-function and a last declared
/// animation-composition (3.2 step 2.2).
const Group = struct {
    offset: f64,
    /// The timing function's text, OWNED.
    easing: []u8,
    composite: keyframes_mod.CompositeOrAuto,
    properties: std.ArrayListUnmanaged(keyframes_mod.Property) = .empty,

    fn deinit(self: *Group, allocator: Allocator) void {
        allocator.free(self.easing);
        for (self.properties.items) |p| {
            allocator.free(p.name);
            allocator.free(p.value);
        }
        self.properties.deinit(allocator);
    }

    /// "the last declaration among all its <keyframe-block> declarations
    /// takes precedence".
    fn put(self: *Group, allocator: Allocator, name: []const u8, value: []const u8) Allocator.Error!void {
        for (self.properties.items) |*p| if (std.mem.eql(u8, p.name, name)) {
            const copy = try allocator.dupe(u8, value);
            allocator.free(p.value);
            p.value = copy;
            return;
        };
        const owned_name = try allocator.dupe(u8, name);
        errdefer allocator.free(owned_name);
        const owned_value = try allocator.dupe(u8, value);
        errdefer allocator.free(owned_value);
        try self.properties.append(allocator, .{ .name = owned_name, .value = owned_value });
    }

    /// Whether the group sets `name`: the property itself, a longhand
    /// through a shorthand waiting for var() substitution, or - for a
    /// shorthand `name` - any of its longhands.
    fn sets(self: *const Group, name: []const u8) bool {
        const wanted = css.properties.lookup(name);
        for (self.properties.items) |p| {
            if (p.value.len == 0) continue;
            if (std.mem.eql(u8, p.name, name)) return true;
            if (css.properties.lookup(p.name)) |property| if (property == .shorthand) {
                for (property.shorthand.longhands()) |l| if (std.mem.eql(u8, l.name(), name)) return true;
            };
            if (wanted) |w| if (w == .shorthand) {
                for (w.shorthand.longhands()) |l| if (std.mem.eql(u8, l.name(), p.name)) return true;
            };
        }
        return false;
    }
};

/// One declaration of a keyframe block as a keyframe property: the
/// declared value's text (CSS Animations 2 3.2 step 2.3.2 "the set of
/// declared values"), var() kept. A shorthand waiting for var()
/// substitution stays one shorthand declaration (its longhands have no
/// text of their own), as Blink keeps a CSSPendingSubstitutionValue.
const Declared = struct { name: []const u8, value: []const u8 };

fn eachDeclared(allocator: Allocator, block: *const css.declarations.DeclarationBlock, out: *std.ArrayListUnmanaged(Declared), texts: *std.ArrayListUnmanaged([]u8)) Allocator.Error!void {
    var shorthands_seen: std.ArrayListUnmanaged(usize) = .empty;
    defer shorthands_seen.deinit(allocator);
    for (block.entries.items) |*entry| switch (entry.*) {
        .typed => |d| {
            const l = d.longhand;
            if (l == .animation_timing_function or l == .animation_composition) continue;
            // "except those that are 'not animatable', which must be
            // ignored" (3.2 step 2.3.1).
            if (css.interpolation.animationType(l) == .not_animatable) continue;
            if (d.value == .value and d.value.value == .pending) {
                const pending = d.value.value.pending;
                if (pending.property) |property| if (property == .shorthand) {
                    const address = @intFromPtr(pending);
                    const seen = for (shorthands_seen.items) |earlier| {
                        if (earlier == address) break true;
                    } else false;
                    if (!seen) {
                        try shorthands_seen.append(allocator, address);
                        try out.append(allocator, .{ .name = property.shorthand.name(), .value = pending.text });
                    }
                    continue;
                };
            }
            var text: std.ArrayList(u8) = .empty;
            errdefer text.deinit(allocator);
            try css.properties.serializeAssigned(l, d.value, &text, allocator);
            const owned = try text.toOwnedSlice(allocator);
            errdefer allocator.free(owned);
            try texts.append(allocator, owned);
            try out.append(allocator, .{ .name = l.name(), .value = owned });
        },
        .custom => |c| {
            var text: std.ArrayList(u8) = .empty;
            errdefer text.deinit(allocator);
            try c.value.serialize(&text, allocator);
            const owned = try text.toOwnedSlice(allocator);
            errdefer allocator.free(owned);
            try texts.append(allocator, owned);
            try out.append(allocator, .{ .name = c.name.bytes, .value = owned });
        },
        // A property Crane does not support: nothing to animate.
        .unparsed => {},
    };
}

/// The block's last declared animation-timing-function, as text (OWNED),
/// and animation-composition.
fn blockTiming(allocator: Allocator, block: *const css.declarations.DeclarationBlock) Allocator.Error!struct { easing: ?[]u8, composite: keyframes_mod.CompositeOrAuto } {
    var easing: ?[]u8 = null;
    errdefer if (easing) |e| allocator.free(e);
    var composite: keyframes_mod.CompositeOrAuto = .auto;
    for (block.entries.items) |*entry| {
        if (entry.* != .typed) continue;
        const d = entry.typed;
        switch (d.longhand) {
            .animation_timing_function => {
                var text: std.ArrayList(u8) = .empty;
                errdefer text.deinit(allocator);
                try css.properties.serializeAssigned(.animation_timing_function, d.value, &text, allocator);
                if (easing) |old| allocator.free(old);
                easing = try text.toOwnedSlice(allocator);
            },
            .animation_composition => {
                var text: std.ArrayList(u8) = .empty;
                defer text.deinit(allocator);
                try css.properties.serializeAssigned(.animation_composition, d.value, &text, allocator);
                if (std.mem.eql(u8, text.items, "add")) {
                    composite = .add;
                } else if (std.mem.eql(u8, text.items, "accumulate")) {
                    composite = .accumulate;
                } else if (std.mem.eql(u8, text.items, "replace")) composite = .replace;
            },
            else => {},
        }
    }
    return .{ .easing = easing, .composite = composite };
}

/// CSS Animations 2 3.2 "processing keyframes" for the @keyframes rule
/// `rule`, with the animation's `default_easing` (animation-timing-function,
/// serialized) and `default_composite` (animation-composition). OWNED.
pub fn buildKeyframes(allocator: Allocator, rule: *const Rule, default_easing: []const u8, default_composite: keyframes_mod.CompositeOrAuto) Allocator.Error!keyframes_mod.List {
    var groups: std.ArrayListUnmanaged(Group) = .empty;
    defer {
        for (groups.items) |*g| g.deinit(allocator);
        groups.deinit(allocator);
    }
    var animated: std.ArrayListUnmanaged([]const u8) = .empty;
    defer animated.deinit(allocator);
    var declared: std.ArrayListUnmanaged(Declared) = .empty;
    defer declared.deinit(allocator);
    var texts: std.ArrayListUnmanaged([]u8) = .empty;
    defer {
        for (texts.items) |t| allocator.free(t);
        texts.deinit(allocator);
    }
    // 2. Collect declared keyframes.
    if (rule.data == .keyframes) for (rule.data.keyframes.children.items) |child| {
        if (child.data != .keyframe) continue;
        const keyframe = &child.data.keyframe;
        const timing = try blockTiming(allocator, &keyframe.block);
        defer if (timing.easing) |e| allocator.free(e);
        const easing = timing.easing orelse default_easing;
        declared.clearRetainingCapacity();
        try eachDeclared(allocator, &keyframe.block, &declared, &texts);
        for (keyframe.selectors.items) |selector| {
            // A <timeline-range-name> offset places a keyframe on a
            // scroll-driven timeline's range: none in a time-driven
            // animation (stated, with scroll-driven timelines).
            if (selector.range != null) continue;
            const offset = selector.percentage / 100;
            // 2.2: the group of the same offset, timing function and
            // composite, in the order of its earliest block.
            const group = for (groups.items) |*g| {
                if (g.offset == offset and g.composite == timing.composite and std.mem.eql(u8, g.easing, easing)) break g;
            } else blk: {
                const owned = try allocator.dupe(u8, easing);
                errdefer allocator.free(owned);
                try groups.append(allocator, .{ .offset = offset, .easing = owned, .composite = timing.composite });
                break :blk &groups.items[groups.items.len - 1];
            };
            // 2.3.1 / 2.3.3.
            for (declared.items) |d| {
                try group.put(allocator, d.name, d.value);
                for (animated.items) |name| {
                    if (std.mem.eql(u8, name, d.name)) break;
                } else try animated.append(allocator, d.name);
            }
        }
    };

    var list: keyframes_mod.List = .{};
    errdefer list.deinit(allocator);
    // An animation whose keyframes set no animatable property has none at
    // all: Chrome, Firefox and Safari return no keyframes for `from {} to
    // {}` or keyframes with only a timing function (css-animations
    // KeyframeEffect-getKeyframes.tentative "no frames for various kinds of
    // empty animations"). The animation still runs and fires its events.
    if (animated.items.len == 0) return list;

    // 3. The initial and final keyframes: each animated property no
    // keyframe at that end sets is IMPLICIT there (an empty value): the
    // effect stack samples the underlying value, getKeyframes() reports the
    // computed value. Both are found or made before the groups move.
    var initial = try generatedFrame(allocator, groups.items, animated.items, 0, default_easing, default_composite);
    defer if (initial) |*f| deinitFrame(allocator, f);
    var final = try generatedFrame(allocator, groups.items, animated.items, 1, default_easing, default_composite);
    defer if (final) |*f| deinitFrame(allocator, f);

    try list.frames.ensureTotalCapacity(allocator, groups.items.len + 2);
    for (groups.items) |*g| {
        var frame: keyframes_mod.Keyframe = .{ .offset = g.offset, .computed_offset = g.offset, .composite = g.composite };
        frame.easing = try parseEasing(allocator, g.easing, default_easing);
        // The values move to the keyframe.
        frame.properties = g.properties;
        g.properties = .empty;
        list.frames.appendAssumeCapacity(frame);
    }
    if (initial) |f| {
        list.frames.appendAssumeCapacity(f);
        initial = null;
    }
    if (final) |f| {
        list.frames.appendAssumeCapacity(f);
        final = null;
    }
    // 4. The computed order: a stable sort by offset, the groups in the
    // order of their earliest block. A generated keyframe sorts after the
    // declared ones at its offset: Gecko and Blink report a declared 0%
    // keyframe with its own timing function before the generated one
    // (KeyframeEffect-getKeyframes.tentative "implicit values and a
    // non-default timing function"), where the text says to prepend it.
    std.sort.block(keyframes_mod.Keyframe, list.frames.items, {}, struct {
        fn lessThan(_: void, a: keyframes_mod.Keyframe, b: keyframes_mod.Keyframe) bool {
            return a.computed_offset < b.computed_offset;
        }
    }.lessThan);
    return list;
}

fn deinitFrame(allocator: Allocator, frame: *keyframes_mod.Keyframe) void {
    frame.easing.deinit(allocator);
    for (frame.properties.items) |p| {
        allocator.free(p.name);
        allocator.free(p.value);
    }
    frame.properties.deinit(allocator);
}

/// The generated keyframe at `offset` (0 or 1): "find or create" one with
/// the default timing function and composite; implicit values for the
/// animated properties no keyframe at that end sets. Returns the keyframe
/// when it was CREATED (OWNED); null when none was needed or a declared one
/// took the values.
fn generatedFrame(allocator: Allocator, groups: []Group, animated: []const []const u8, offset: f64, default_easing: []const u8, default_composite: keyframes_mod.CompositeOrAuto) Allocator.Error!?keyframes_mod.Keyframe {
    var missing: std.ArrayListUnmanaged([]const u8) = .empty;
    defer missing.deinit(allocator);
    for (animated) |name| {
        const set_there = for (groups) |*g| {
            if (g.offset == offset and g.sets(name)) break true;
        } else false;
        if (!set_there) try missing.append(allocator, name);
    }
    if (missing.items.len == 0) return null;
    // "Find" it: a declared keyframe at this end with the default timing
    // function and no composite of its own.
    for (groups) |*g| {
        if (g.offset != offset or g.composite != .auto or !std.mem.eql(u8, g.easing, default_easing)) continue;
        for (missing.items) |name| try g.put(allocator, name, "");
        return null;
    }
    // "Create" it.
    var frame: keyframes_mod.Keyframe = .{ .offset = offset, .computed_offset = offset, .composite = default_composite };
    errdefer deinitFrame(allocator, &frame);
    frame.easing = try parseEasing(allocator, default_easing, "ease");
    for (missing.items) |name| {
        const owned_name = try allocator.dupe(u8, name);
        errdefer allocator.free(owned_name);
        const owned_value = try allocator.dupe(u8, "");
        errdefer allocator.free(owned_value);
        try frame.properties.append(allocator, .{ .name = owned_name, .value = owned_value });
    }
    return frame;
}

/// A keyframe's easing from its timing function text; the default's when
/// it does not parse (a var() in it).
fn parseEasing(allocator: Allocator, text: []const u8, fallback: []const u8) Allocator.Error!easing_mod.Easing {
    if (try easing_mod.parse(allocator, text)) |parsed| return parsed;
    if (try easing_mod.parse(allocator, fallback)) |parsed| return parsed;
    return .{};
}

/// Whether `property` is an implicit value of a generated keyframe.
pub fn isImplicit(property: keyframes_mod.Property) bool {
    return property.value.len == 0;
}

/// getKeyframes() on the effect of a CSS animation: the implicit values
/// filled in with the target's current base computed value (Blink
/// CssKeyframeEffectModel::GetComputedKeyframes, Gecko
/// CSSAnimationKeyframeEffect::GetKeyframes). Null when the effect has no
/// implicit value (the caller reports its keyframes as they are). OWNED.
pub fn keyframesForScript(effect: *const model.Effect) Allocator.Error!?keyframes_mod.List {
    var has_implicit = false;
    outer: for (effect.keyframes.frames.items) |frame| for (frame.properties.items) |p| {
        if (isImplicit(p)) {
            has_implicit = true;
            break :outer;
        }
    };
    if (!has_implicit) return null;
    const allocator = effect.allocator;
    var list = try effect.keyframes.clone(allocator);
    errdefer list.deinit(allocator);
    const target = effect.targetElement();
    const bare: ?[]const u8 = if (effect.pseudo) |p| std.mem.trimStart(u8, p, ":") else null;
    const base = if (target) |t| baseStyle(t, bare) else null;
    for (list.frames.items) |*frame| {
        var i: usize = 0;
        while (i < frame.properties.items.len) {
            const p = &frame.properties.items[i];
            if (!isImplicit(p.*)) {
                i += 1;
                continue;
            }
            var text: std.ArrayList(u8) = .empty;
            defer text.deinit(allocator);
            if (base) |style| try serializeComputed(allocator, style, p.name, &text);
            if (text.items.len == 0) {
                const removed = frame.properties.orderedRemove(i);
                allocator.free(removed.name);
                allocator.free(removed.value);
                continue;
            }
            const owned = try text.toOwnedSlice(allocator);
            allocator.free(p.value);
            p.value = owned;
            i += 1;
        }
    }
    return list;
}

/// The base style of (element, pseudo): its style without the animation
/// and transition origins, resolved now. Borrowed until the next read.
fn baseStyle(element: *runtime.Instance, pseudo: ?[]const u8) ?*const ComputedStyle {
    const style_engine = @import("../style/root.zig").engine;
    const style = (style_engine.computedStyle(element, pseudo) catch null) orelse return null;
    const state = element_style.existingOf(element) orelse return style;
    const cached = if (pseudo) |p| (if (state.pseudoCached(p)) |c| c.cached else return style) else (state.cached orelse return style);
    return cached.base orelse cached.style;
}

fn serializeComputed(allocator: Allocator, style: *const ComputedStyle, name: []const u8, out: *std.ArrayList(u8)) Allocator.Error!void {
    if (std.mem.startsWith(u8, name, "--")) {
        if (style.customValue(name)) |text| try out.appendSlice(allocator, std.mem.trim(u8, text.bytes, " \t\n"));
        return;
    }
    const property = css.properties.lookup(name) orelse return;
    switch (property) {
        .longhand => |l| try css.properties.serializeValue(l, style.get(style.physical(l)), out, allocator),
        .shorthand => {},
    }
}

// ============================================================================
// Script overrides (CSS Animations 2 section 2) and pending style (6.2)
// ============================================================================

/// setKeyframes() succeeded on `effect`.
pub fn keyframesReplaced(effect: *model.Effect) void {
    const animation = effect.animationModel() orelse return;
    const state = stateOf(animation) orelse return;
    state.overrides.keyframes = true;
}

/// updateTiming() succeeded on `effect` with `input`: "for each property
/// included in the timing parameter, any subsequent change to a
/// corresponding animation property will not be reflected".
pub fn timingUpdated(effect: *model.Effect, input: options_mod.OptionalTiming) void {
    const animation = effect.animationModel() orelse return;
    const state = stateOf(animation) orelse return;
    if (input.duration != null) state.overrides.duration = true;
    if (input.iterations != null) state.overrides.iterations = true;
    if (input.direction != null) state.overrides.direction = true;
    if (input.delay != null) state.overrides.delay = true;
    if (input.fill != null) state.overrides.fill = true;
}

/// play(), pause() or cancel() from script succeeded: animation-play-state
/// no longer plays or pauses it (a cancel too: "it should be possible to
/// cancel an animation from script such that all future changes to style
/// are ignored", css-animations CSSAnimation-canceling.tentative).
pub fn playStateOverridden(animation: *model.Animation) void {
    const state = stateOf(animation) orelse return;
    state.overrides.play_state = true;
}

/// reverse() or the startTime setter succeeded: an override only when the
/// play state changed to or from paused.
pub fn playStateMaybeOverridden(animation: *model.Animation, before: model.PlayState) void {
    const after = animation.playState();
    if ((before == .paused) != (after == .paused)) playStateOverridden(animation);
}

/// The effect setter succeeded: another effect than the one style made.
pub fn effectReplaced(animation: *model.Animation) void {
    const state = stateOf(animation) orelse return;
    state.overrides.effect = true;
}

/// CSS Animations 2 6.2 / CSS Transitions 2 6.2 "requirements on pending
/// style changes": before playState, pending, play(), pause() or reverse()
/// of a CSS animation or transition answers or acts, its owning element's
/// pending style changes are processed (Gecko CSSAnimation::
/// PlayStateFromJS / PendingFromJS / PlayFromJS; Blink CSSAnimation::
/// playState and FlushStyles).
pub fn flushPendingStyle(animation: *model.Animation) void {
    const state = animation.css orelse return;
    const link = state.owning_element orelse return;
    const element = link.get() orelse return;
    const style_engine = @import("../style/root.zig").engine;
    const bare: ?[]const u8 = if (state.pseudo.len != 0) std.mem.trimStart(u8, state.pseudo, ":") else null;
    _ = style_engine.computedStyle(element, bare) catch {};
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return;
    sweep(document);
    @import("css_transitions.zig").sweep(document);
}

// ============================================================================
// Removal, and the sweep
// ============================================================================

/// DOM removing steps for `state`'s element (css_transitions.removingSteps
/// calls it): only a MARK - its listed animations are canceled at the next
/// sweep (step 11 of the frame the removal asks for, or a getAnimations()
/// flush). Returns whether it has any (the caller asks for that frame).
pub fn markRemoved(set: *ElementAnimations) bool {
    if (set.list.items.len == 0) return false;
    set.removed = true;
    return true;
}

/// The CSS animations `document` times whose owning element left the
/// document since they were made are canceled (Blink cancels them at
/// detach; web-animations cancel-event-on-element-removal waits for the
/// `cancel` event). HTML update the rendering steps 11 and 16, and the
/// getAnimations() flush.
pub fn sweep(document: *runtime.Instance) void {
    const registry = registry_mod.of(document.ctx) orelse return;
    var i: usize = 0;
    while (i < registry.animations.items.len) : (i += 1) {
        const instance = registry.animations.items[i].get() orelse continue;
        const animation = hooks.animationOf(instance) orelse continue;
        if (!isListedMember(animation)) continue;
        if (animation.documentForTiming() != document) continue;
        const element = owningElement(animation) orelse {
            leaveList(animation);
            animation.settle();
            continue;
        };
        const set = setOf(element) orelse continue;
        const connected = interfaces.Node.get_isConnected(element) catch false;
        if (!set.removed and connected) continue;
        _ = cancelAll(set, null, true);
        set.removed = false;
    }
}

// ============================================================================
// Composite order (CSS Animations 2 2.2)
// ============================================================================

/// Whether CSS animation `a` sorts before CSS animation `b`, both with an
/// owning element; null when 2.2 does not decide.
pub fn compositeLessThan(a: *const model.Animation, b: *const model.Animation) ?bool {
    const ea = owningElement(a) orelse return null;
    const eb = owningElement(b) orelse return null;
    const sa = stateOf(a);
    const sb = stateOf(b);
    const pa: ?[]const u8 = if (sa) |s| s.pseudo else null;
    const pb: ?[]const u8 = if (sb) |s| s.pseudo else null;
    // 1. Different owning elements: tree order, pseudo-elements after
    // their element and before its children.
    if (ea != eb) return treeOrderLessThan(ea, eb);
    if (!samePseudo(pa, pb)) return pseudoLessThan(pa, pb);
    // 2. The position in animation-name.
    const ia = if (sa) |s| s.index else 0;
    const ib = if (sb) |s| s.index else 0;
    if (ia != ib) return ia < ib;
    return null;
}

/// Tree order of two elements (DOM compareDocumentPosition).
pub fn treeOrderLessThan(a: *runtime.Instance, b: *runtime.Instance) ?bool {
    const position = interfaces.Node.call_compareDocumentPosition(a, b) catch return null;
    // DOCUMENT_POSITION_PRECEDING (2): b precedes a.
    return position & 2 == 0;
}

/// The pseudo-element order of CSS Animations 2 2.2 and CSS Transitions 2
/// 4.1: element, ::marker, ::before, the others by code points, ::after.
pub fn pseudoRank(pseudo: ?[]const u8) u8 {
    const p = pseudo orelse return 0;
    if (std.mem.eql(u8, p, "marker")) return 1;
    if (std.mem.eql(u8, p, "before")) return 2;
    if (std.mem.eql(u8, p, "after")) return 4;
    return 3;
}

fn pseudoLessThan(a: ?[]const u8, b: ?[]const u8) bool {
    const ra = pseudoRank(a);
    const rb = pseudoRank(b);
    if (ra != rb) return ra < rb;
    return std.mem.order(u8, a orelse "", b orelse "") == .lt;
}

test "pseudo-element order: element, marker, before, others, after" {
    try std.testing.expect(pseudoLessThan(null, "marker"));
    try std.testing.expect(pseudoLessThan("marker", "before"));
    try std.testing.expect(pseudoLessThan("before", "backdrop"));
    try std.testing.expect(pseudoLessThan("backdrop", "selection"));
    try std.testing.expect(pseudoLessThan("selection", "after"));
}
