//! CSS Transitions made from style: CSS Transitions 1 section 3 ("starting of
//! transitions") and section 5 ("completion of transitions"), with CSS
//! Transitions 2's owning element, cancel, transition generation and
//! composite order (sections 3, 3.2, 4.1).
//!
//! The style engine runs `styleChangeEvent` for an element (or one of its
//! pseudo-elements) at each of its style change events: a resolution whose
//! style inputs moved (tmp/plans/anim1b2-design.md section 1). It hands over
//! the before-change style - the element's previous base style, the cascade
//! without the animation and transition origins (Blink
//! CSSAnimations::CalculateBeforeChangeStyle) - and the after-change style,
//! the new base style (Blink CalculateAfterChangeStyle). This file runs the
//! section 3 steps for each property and starts and cancels CSSTransitions.
//!
//! A CSSTransition is a platform object (the CSSTransition interface, made
//! through its generated file, never its impl) with a KeyframeEffect of two
//! linear keyframes and the timing {duration, delay, fill backwards, easing =
//! transition-timing-function}: Blink MaybeApplyPendingUpdate (TransitionKeyframes,
//! ConvertToTiming) and Gecko DoCreateTransition (TimingParams with the
//! timing function, FillMode Backwards) agree, and so do the WPT
//! expectations (css/css-transitions/KeyframeEffect-getKeyframes.tentative.html,
//! AnimationEffect-getComputedTiming.tentative.html).
//!
//! Ownership (the lesson "a browser's strong hold comes with the step that
//! ends it"; Blink's TransitionMap holds a RunningTransition's Animation as a
//! Member until the next style update takes it out):
//!   - the element's ElementStyle owns `ElementTransitions`: its running
//!     transitions as BORROWED, generation-checked links, and its completed
//!     transitions as values. No engine handle: the element's teardown frees
//!     it with no engine call.
//!   - a running transition keeps itself alive while it is a member of that
//!     running set (`Transition.running`, read by Animation.settle) - and
//!     leaves the set at completion (step 11), at a cancel from style, when an
//!     idle or finished member meets the element's next style change event,
//!     and at the sweep after its element left the document; the window's end
//!     releases every animation's keep (Registry.windowDestroyed, endPage).
//!
//! Spec: https://drafts.csswg.org/css-transitions-1/#starting
//! Spec: https://drafts.csswg.org/css-transitions-2/#transition-composite-order
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
const effect_stack = @import("effect_stack.zig");
const element_style = @import("../style/element_style.zig");
const instance_bridge = @import("../instance_bridge.zig");
const NodeBase = @import("../node_base.zig").NodeBase;

const Allocator = std.mem.Allocator;
const Value = css.style_values.Value;
const Longhand = css.properties.Longhand;
const ComputedStyle = css.computed_style.ComputedStyle;
const Text = css.custom_properties.Text;
const ListItem = css.animation_values.Item;

// ============================================================================
// Values
// ============================================================================

/// A transitioning property: a physical longhand, or a custom property.
pub const Property = union(enum) {
    longhand: Longhand,
    /// The custom property's name, OWNED.
    custom: []u8,

    fn eql(a: Property, b: Property) bool {
        return switch (a) {
            .longhand => |l| b == .longhand and b.longhand == l,
            .custom => |n| b == .custom and std.mem.eql(u8, b.custom, n),
        };
    }

    fn matches(self: Property, wanted: PropertyRef) bool {
        return switch (self) {
            .longhand => |l| wanted == .longhand and wanted.longhand == l,
            .custom => |n| wanted == .custom and std.mem.eql(u8, wanted.custom, n),
        };
    }

    /// CSS Transitions 2 6.1 "the expanded transition property name".
    pub fn name(self: Property) []const u8 {
        return switch (self) {
            .longhand => |l| l.name(),
            .custom => |n| n,
        };
    }

    fn deinit(self: Property, allocator: Allocator) void {
        if (self == .custom) allocator.free(self.custom);
    }
};

/// A property named without ownership, for lookups.
const PropertyRef = union(enum) {
    longhand: Longhand,
    custom: []const u8,

    fn own(self: PropertyRef, allocator: Allocator) Allocator.Error!Property {
        return switch (self) {
            .longhand => |l| .{ .longhand = l },
            .custom => |n| .{ .custom = try allocator.dupe(u8, n) },
        };
    }
};

/// A computed value of a transitioning property: a longhand's Value, or a
/// custom property's token text (null: the guaranteed-invalid value). One
/// reference held by its owner.
pub const TransitionValue = union(enum) {
    value: Value,
    custom: ?*Text,

    fn retained(self: TransitionValue) TransitionValue {
        switch (self) {
            .value => |v| v.retain(),
            .custom => |t| if (t) |text| text.retain(),
        }
        return self;
    }

    fn release(self: TransitionValue) void {
        switch (self) {
            .value => |v| v.release(),
            .custom => |t| if (t) |text| text.release(),
        }
    }

    fn eql(a: TransitionValue, b: TransitionValue) bool {
        return switch (a) {
            .value => |v| b == .value and v.eql(b.value),
            .custom => |t| b == .custom and textEql(t, b.custom),
        };
    }
};

fn textEql(a: ?*Text, b: ?*Text) bool {
    const x = a orelse return b == null;
    const y = b orelse return false;
    return std.mem.eql(u8, std.mem.trim(u8, x.bytes, " \t\n"), std.mem.trim(u8, y.bytes, " \t\n"));
}

/// `property`'s computed value in `style`. Borrowed.
fn valueIn(style: *const ComputedStyle, property: PropertyRef) TransitionValue {
    return switch (property) {
        .longhand => |l| .{ .value = style.get(l) },
        .custom => |n| .{ .custom = style.customValue(n) },
    };
}

// ============================================================================
// The transition's own state, and the element's sets
// ============================================================================

/// A CSS transition's own values (CSS Transitions 1 section 3; CSS
/// Transitions 2 3.1: "associated with the transition itself and not ... its
/// animation effect"). OWNED by its css_events.State.
pub const Transition = struct {
    property: Property,
    /// The bare pseudo-element name ("before"), OWNED; null for the element.
    pseudo: ?[]u8,
    start: TransitionValue,
    end: TransitionValue,
    reversing_adjusted_start: TransitionValue,
    reversing_shortening_factor: f64 = 1,
    /// CSS Transitions 2 3.2 the transition generation.
    generation: u64,
    /// A member of its owning element's running set: it keeps itself alive
    /// (Animation.settle) until it leaves the set.
    running: bool = true,
    /// The effect whose keyframes are this transition's own start and end
    /// values (until script replaces them: setKeyframes, a new effect).
    own_effect: ?model.Link = null,

    pub fn destroy(self: *Transition, allocator: Allocator) void {
        self.property.deinit(allocator);
        if (self.pseudo) |p| allocator.free(p);
        self.start.release();
        self.end.release();
        self.reversing_adjusted_start.release();
        allocator.destroy(self);
    }
};

/// A completed transition (CSS Transitions 1 section 3): its property and
/// end value.
const Completed = struct {
    /// The bare pseudo-element name, OWNED; null for the element.
    pseudo: ?[]u8,
    property: Property,
    end: TransitionValue,

    fn deinit(self: Completed, allocator: Allocator) void {
        if (self.pseudo) |p| allocator.free(p);
        self.property.deinit(allocator);
        self.end.release();
    }
};

/// An element's set of running transitions and set of completed transitions,
/// for it and its pseudo-elements. OWNED by its ElementStyle (inside
/// element_style.StyleAnimations).
pub const ElementTransitions = struct {
    /// The running transitions: borrowed, generation-checked links to their
    /// CSSTransitions, each kept alive by itself while it is a member.
    running: std.ArrayListUnmanaged(model.Link) = .empty,
    completed: std.ArrayListUnmanaged(Completed) = .empty,
    /// The element left the document since its transitions started (its
    /// removing steps): the next sweep cancels them.
    removed: bool = false,

    pub fn deinit(self: *ElementTransitions, allocator: Allocator) void {
        self.running.deinit(allocator);
        for (self.completed.items) |c| c.deinit(allocator);
        self.completed.deinit(allocator);
    }

    fn clearCompleted(self: *ElementTransitions, allocator: Allocator, pseudo: ?[]const u8, all: bool) void {
        var i: usize = 0;
        while (i < self.completed.items.len) {
            if (all or samePseudo(self.completed.items[i].pseudo, pseudo)) {
                self.completed.orderedRemove(i).deinit(allocator);
            } else i += 1;
        }
    }

    fn completedFor(self: *ElementTransitions, pseudo: ?[]const u8, property: PropertyRef) ?usize {
        for (self.completed.items, 0..) |c, i| {
            if (samePseudo(c.pseudo, pseudo) and c.property.matches(property)) return i;
        }
        return null;
    }

    fn removeRunning(self: *ElementTransitions, instance: *runtime.Instance) void {
        var i: usize = 0;
        while (i < self.running.items.len) {
            const link = self.running.items[i];
            if (link.instance == instance or link.get() == null) {
                _ = self.running.orderedRemove(i);
            } else i += 1;
        }
    }
};

fn samePseudo(a: ?[]const u8, b: ?[]const u8) bool {
    const x = a orelse return b == null;
    const y = b orelse return false;
    return std.mem.eql(u8, x, y);
}

/// The transition state of `animation`, when it is a CSS transition made
/// from style.
pub fn transitionOf(animation: *const model.Animation) ?*Transition {
    const state = animation.css orelse return null;
    return state.transition;
}

/// A custom property transition's start and end values, while `effect` is
/// its effect with the keyframes it was made with (effect_stack uses them in
/// place of the keyframes' text, keeping their attr() taint).
pub fn ownCustomValues(animation: *const model.Animation, effect: *const model.Effect) ?struct { name: []const u8, start: ?*Text, end: ?*Text } {
    const transition = transitionOf(animation) orelse return null;
    if (transition.property != .custom) return null;
    const own = transition.own_effect orelse return null;
    if (own.get() != effect.instance) return null;
    return .{ .name = transition.property.custom, .start = transition.start.custom, .end = transition.end.custom };
}

/// A longhand transition's start and end values, while `effect` is its
/// effect with the keyframes it was made with: effect_stack uses these
/// computed values in place of the keyframes' serialized text, which keeps
/// only six significant digits (CSS Transitions 1 3: the transition runs
/// from the start value to the end value - Blink's TransitionKeyframes hold
/// the computed values themselves).
pub fn ownLonghandValues(animation: *const model.Animation, effect: *const model.Effect) ?struct { longhand: Longhand, start: Value, end: Value } {
    const transition = transitionOf(animation) orelse return null;
    if (transition.property != .longhand) return null;
    const own = transition.own_effect orelse return null;
    if (own.get() != effect.instance) return null;
    if (transition.start != .value or transition.end != .value) return null;
    return .{ .longhand = transition.property.longhand, .start = transition.start.value, .end = transition.end.value };
}

/// Script replaced `effect`'s keyframes (setKeyframes): a transition that
/// owned them no longer does.
pub fn keyframesReplaced(effect: *model.Effect) void {
    const animation = effect.animationModel() orelse return;
    const transition = transitionOf(animation) orelse return;
    transition.own_effect = null;
}

/// Whether `animation` is a member of its owning element's running set
/// (Animation.settle keeps it alive then).
pub fn isRunningMember(animation: *const model.Animation) bool {
    const transition = transitionOf(animation) orelse return false;
    return transition.running;
}

fn owningElement(animation: *const model.Animation) ?*runtime.Instance {
    const state = animation.css orelse return null;
    const link = state.owning_element orelse return null;
    return link.get();
}

fn setOf(element: *runtime.Instance) ?*ElementTransitions {
    const state = element_style.existingOf(element) orelse return null;
    const both = state.animations orelse return null;
    return &both.transitions;
}

fn ensureSet(element: *runtime.Instance) Allocator.Error!*ElementTransitions {
    const state = element_style.of(element) orelse return error.OutOfMemory;
    const both = try state.ensureAnimations();
    return &both.transitions;
}

/// The running transition of (element, pseudo) for `property`.
fn runningFor(set: *ElementTransitions, pseudo: ?[]const u8, property: PropertyRef) ?*model.Animation {
    for (set.running.items) |link| {
        const instance = link.get() orelse continue;
        const animation = hooks.animationOf(instance) orelse continue;
        const transition = transitionOf(animation) orelse continue;
        if (samePseudo(transition.pseudo, pseudo) and transition.property.matches(property)) return animation;
    }
    return null;
}

/// `animation` leaves its owning element's running set.
fn leaveRunningSet(animation: *model.Animation) void {
    const transition = transitionOf(animation) orelse return;
    if (!transition.running) return;
    transition.running = false;
    if (owningElement(animation)) |element| if (setOf(element)) |set| set.removeRunning(animation.instance);
}

// ============================================================================
// The transition-* lists of the after-change style
// ============================================================================

/// The after-change style's transition-* values, matched per CSS Transitions
/// 1 section 2 ("the rules on matching lists": transition-property's length
/// decides, the other lists repeat).
const Lists = struct {
    properties: Value,
    durations: Value,
    delays: Value,
    timings: Value,
    behaviors: Value,

    fn of(style: *const ComputedStyle) Lists {
        return .{
            .properties = style.get(.transition_property),
            .durations = style.get(.transition_duration),
            .delays = style.get(.transition_delay),
            .timings = style.get(.transition_timing_function),
            .behaviors = style.get(.transition_behavior),
        };
    }

    fn count(v: Value) usize {
        return if (v == .animation_list) v.animation_list.items.items.len else 1;
    }

    fn item(l: Longhand, v: Value, index: usize) ?ListItem {
        return switch (v) {
            .animation_list => |list| if (list.items.items.len == 0) null else list.items.items[index % list.items.items.len],
            .keyword => |k| .{ .keyword = k },
            .number => |n| .{ .number = if (l == .transition_duration or l == .transition_delay) .{ .literal = .{ .value = n, .unit = .s } } else css.numeric_values.Number.scalar(n) },
            else => null,
        };
    }

    fn propertyCount(self: Lists) usize {
        return count(self.properties);
    }

    fn propertyItem(self: Lists, index: usize) ?ListItem {
        return item(.transition_property, self.properties, index);
    }

    /// A time item in milliseconds (0 for one that did not compute to a time).
    fn ms(it: ?ListItem) f64 {
        const i = it orelse return 0;
        if (i != .number) return 0;
        const n = switch (i.number) {
            .literal => |literal| literal,
            .calculation => return 0,
        };
        return switch (n.unit) {
            .s => n.value * 1000,
            .ms => n.value,
            else => 0,
        };
    }

    fn duration(self: Lists, index: usize) f64 {
        return @max(ms(item(.transition_duration, self.durations, index)), 0);
    }

    fn delay(self: Lists, index: usize) f64 {
        return ms(item(.transition_delay, self.delays, index));
    }

    fn allowDiscrete(self: Lists, index: usize) bool {
        const it = item(.transition_behavior, self.behaviors, index) orelse return false;
        return it == .keyword and it.keyword == .allow_discrete;
    }

    /// Whether any entry has a combined duration above 0s: the only way a
    /// transition can start (section 3 step 1).
    fn mayStart(self: Lists) bool {
        if (self.properties == .keyword and self.properties.keyword == .none) return false;
        for (0..self.propertyCount()) |i| {
            if (self.duration(i) + self.delay(i) > 0) return true;
        }
        return false;
    }

    /// "The matching transition-property value": the LAST item that names
    /// `property` (itself, a shorthand of it, or `all`); null for none.
    fn matching(self: Lists, style: *const ComputedStyle, property: PropertyRef) ?usize {
        var found: ?usize = null;
        for (0..self.propertyCount()) |i| {
            const it = self.propertyItem(i) orelse continue;
            switch (it) {
                .keyword => |k| if (k == .all) {
                    found = i;
                },
                .name => |n| if (nameCovers(style, n, property)) {
                    found = i;
                },
                else => {},
            }
        }
        return found;
    }
};

/// Whether the transition-property identifier `name` names `property`
/// (CSS Transitions 1 2.1: a shorthand stands for its longhands; a logical
/// longhand for the physical one this element maps it to).
fn nameCovers(style: *const ComputedStyle, name: []const u8, property: PropertyRef) bool {
    if (std.mem.startsWith(u8, name, "--")) return property == .custom and std.mem.eql(u8, name, property.custom);
    if (property != .longhand) return false;
    const found = css.properties.lookup(name) orelse return false;
    switch (found) {
        .longhand => |l| return style.physical(l) == property.longhand,
        .shorthand => |s| for (s.longhands()) |l| {
            if (style.physical(l) == property.longhand) return true;
        },
    }
    return false;
}

// ============================================================================
// Transitionable, and a running transition's current value
// ============================================================================

/// CSS Transitions 1 section 3 "transitionable": the pair's animation type is
/// neither not animatable nor discrete. With `transition-behavior:
/// allow-discrete` (CSS Transitions 2 2.5) a discrete pair is transitionable
/// too.
fn transitionable(allocator: Allocator, style: *const ComputedStyle, property: PropertyRef, a: TransitionValue, b: TransitionValue, allow_discrete: bool) bool {
    switch (property) {
        .longhand => |l| {
            if (css.interpolation.animationType(l) == .not_animatable) return false;
            if (allow_discrete) return true;
            return css.interpolation.transitionable(allocator, l, a.value, b.value) catch false;
        },
        .custom => |n| {
            if (allow_discrete) return true;
            return effect_stack.customSmooth(allocator, style, n, a.custom, b.custom) catch false;
        },
    }
}

/// The current value of the property in the running transition `animation`
/// (CSS Transitions 1 section 4): its start and end values interpolated at
/// its transformed progress now, range-checked as the value the element
/// shows (CSS Values 4 3.1: the final result is clamped - an easing that
/// overshoots, or a color between bytes, is not a value the element has).
/// OWNED.
fn currentValue(allocator: Allocator, style: *const ComputedStyle, animation: *model.Animation, transition: *const Transition) Allocator.Error!TransitionValue {
    const p = progressOf(animation);
    switch (transition.property) {
        .longhand => |l| return .{ .value = css.interpolation.clampFinal(l, try css.interpolation.interpolate(allocator, l, transition.start.value, transition.end.value, p)) },
        .custom => |n| return .{ .custom = try effect_stack.customInterpolate(allocator, style, n, transition.start.custom, transition.end.custom, p) },
    }
}

/// The output of `animation`'s timing function now (its effect's transformed
/// progress): 0 in its delay, 1 once its effect has no progress left.
fn progressOf(animation: *model.Animation) f64 {
    const effect = animation.effectModel() orelse return 1;
    const computed = effect.computed();
    if (computed.progress) |p| return p;
    return if (computed.phase == .before) 0 else 1;
}

// ============================================================================
// The style change event (section 3)
// ============================================================================

/// What a style change event is given about one element (or pseudo-element).
pub const Event = struct {
    /// The before-change style; null when there is none (never resolved,
    /// or not rendered at its previous style change event).
    before: ?*const ComputedStyle,
    /// The after-change style: the new base style.
    after: *const ComputedStyle,
    /// The element is being rendered now.
    rendered: bool,
    /// CSS Transitions 2 3.2: the current transition generation for the
    /// style change event this is part of, taken at its first transition.
    generation: *?u64,
};

/// CSS Transitions 1 section 3 for (element, pseudo) at one of its style
/// change events. Returns whether a transition started or was canceled (the
/// element's effects changed).
pub fn styleChangeEvent(element: *runtime.Instance, pseudo: ?[]const u8, event: Event) bool {
    const realm = element.ctx;
    if (!realm.hasEngine()) return false;
    const allocator = realm.allocator;
    var changed = false;
    const existing = setOf(element);
    if (existing) |set| {
        // The element left the document since (its removing steps): "If an
        // element is no longer in the document, implementations must cancel
        // any running transitions on it and remove transitions on it from
        // the completed transitions."
        if (set.removed) {
            changed = cancelAll(element, set, null, true) or changed;
            set.removed = false;
        }
        // CSS Transitions 2 section 3: the same for an element no longer
        // being rendered.
        if (!event.rendered) {
            changed = cancelAll(element, set, pseudo, false) or changed;
            set.clearCompleted(allocator, pseudo, false);
            return changed;
        }
    }
    // "If an element is not in the document during that style change event
    // or was not in the document during the previous style change event,
    // then transitions are not started for that element in that style change
    // event."
    const before = event.before orelse return changed;
    if (!event.rendered) return changed;
    const lists = Lists.of(event.after);
    // Nothing to start, nothing running or completed: no property can move.
    if (existing == null and !lists.mayStart()) return changed;
    if (existing) |set| if (set.running.items.len == 0 and set.completed.items.len == 0 and !lists.mayStart()) return changed;

    var run: Run = .{ .allocator = allocator, .element = element, .pseudo = pseudo, .event = event, .before = before, .lists = lists };
    run.each() catch {};
    return changed or run.changed;
}

/// One style change event's walk over the properties.
const Run = struct {
    allocator: Allocator,
    element: *runtime.Instance,
    pseudo: ?[]const u8,
    event: Event,
    before: *const ComputedStyle,
    lists: Lists,
    changed: bool = false,

    /// Every property the event must look at: those a transition-property
    /// item matches (all animatable physical longhands and custom properties
    /// for `all`), and those with a running or completed transition.
    fn each(self: *Run) Allocator.Error!void {
        var seen: std.EnumSet(Longhand) = .empty;
        var customs: std.ArrayListUnmanaged([]const u8) = .empty;
        defer customs.deinit(self.allocator);
        var any_all = false;
        for (0..self.lists.propertyCount()) |i| {
            const it = self.lists.propertyItem(i) orelse continue;
            switch (it) {
                .keyword => |k| if (k == .all) {
                    any_all = true;
                },
                .name => |n| try self.addName(n, &seen, &customs),
                else => {},
            }
        }
        if (any_all) {
            for (std.enums.values(Longhand)) |l| {
                if (css.interpolation.animationType(l) == .not_animatable) continue;
                if (self.event.after.physical(l) != l) continue;
                seen.insert(l);
            }
            for ([_]*const ComputedStyle{ self.before, self.event.after }) |style| {
                const names = try style.customNames(self.allocator);
                defer self.allocator.free(names);
                for (names) |n| try addCustom(self.allocator, &customs, n);
            }
        }
        if (setOf(self.element)) |set| {
            for (set.running.items) |link| {
                const instance = link.get() orelse continue;
                const animation = hooks.animationOf(instance) orelse continue;
                const transition = transitionOf(animation) orelse continue;
                if (!samePseudo(transition.pseudo, self.pseudo)) continue;
                switch (transition.property) {
                    .longhand => |l| seen.insert(l),
                    .custom => |n| try addCustom(self.allocator, &customs, n),
                }
            }
            for (set.completed.items) |c| {
                if (!samePseudo(c.pseudo, self.pseudo)) continue;
                switch (c.property) {
                    .longhand => |l| seen.insert(l),
                    .custom => |n| try addCustom(self.allocator, &customs, n),
                }
            }
        }
        // The longhands, then the custom properties (the composite order
        // sorts one generation's transitions by name, CSS Transitions 2 4.1).
        var it = seen.iterator();
        while (it.next()) |l| try self.property(.{ .longhand = l });
        // The names borrow the styles' and transitions' storage, which the
        // properties' steps may free (a cancel): own them first.
        var owned: std.ArrayListUnmanaged([]u8) = .empty;
        defer {
            for (owned.items) |n| self.allocator.free(n);
            owned.deinit(self.allocator);
        }
        for (customs.items) |n| try owned.append(self.allocator, try self.allocator.dupe(u8, n));
        for (owned.items) |n| try self.property(.{ .custom = n });
    }

    fn addName(self: *Run, name: []const u8, seen: *std.EnumSet(Longhand), customs: *std.ArrayListUnmanaged([]const u8)) Allocator.Error!void {
        if (std.mem.startsWith(u8, name, "--")) return addCustom(self.allocator, customs, name);
        // "If one of the identifiers listed is not a recognized property
        // name, the implementation must still start transitions on the
        // animatable properties in the list."
        const found = css.properties.lookup(name) orelse return;
        switch (found) {
            .longhand => |l| seen.insert(self.event.after.physical(l)),
            .shorthand => |s| for (s.longhands()) |l| seen.insert(self.event.after.physical(l)),
        }
    }

    fn addCustom(allocator: Allocator, customs: *std.ArrayListUnmanaged([]const u8), name: []const u8) Allocator.Error!void {
        for (customs.items) |n| if (std.mem.eql(u8, n, name)) return;
        try customs.append(allocator, name);
    }

    /// CSS Transitions 1 section 3, "for each element and property", steps
    /// 1-4.
    fn property(self: *Run, p: PropertyRef) Allocator.Error!void {
        const allocator = self.allocator;
        const after_style = self.event.after;
        if (p == .longhand and css.interpolation.animationType(p.longhand) == .not_animatable) return;
        // A property an animation in effect on the element drives starts and
        // cancels no transition (effect_stack.animatesProperty).
        if (effect_stack.animatesProperty(self.element, self.pseudo, after_style, if (p == .longhand) p.longhand else null, if (p == .custom) p.custom else null)) return;
        const after = valueIn(after_style, p);
        const before = valueIn(self.before, p);
        const match = self.lists.matching(after_style, p);
        const allow_discrete = if (match) |m| self.lists.allowDiscrete(m) else false;
        const combined: f64 = if (match) |m| self.lists.duration(m) + self.lists.delay(m) else 0;

        var running = if (setOf(self.element)) |set| runningFor(set, self.pseudo, p) else null;
        // A running transition that finished completes now if step 11 has not
        // moved it yet (section 5); one script canceled (idle) starts nothing
        // while its end value is the after-change value, and otherwise leaves
        // the set (Blink CalculateTransitionUpdateForPropertyHandle, and its
        // Inactive() entries finished at the end of the update).
        if (running) |animation| {
            const transition = transitionOf(animation).?;
            switch (animation.playState()) {
                .finished => {
                    complete(animation);
                    running = null;
                },
                .idle => {
                    if (transition.end.eql(after)) return;
                    leaveRunningSet(animation);
                    css_events.detach(animation);
                    animation.settle();
                    self.changed = true;
                    running = null;
                },
                else => {},
            }
        }
        const completed: ?usize = if (setOf(self.element)) |set| set.completedFor(self.pseudo, p) else null;

        // 1.
        if (running == null and !before.eql(after) and
            transitionable(allocator, after_style, p, before, after, allow_discrete) and
            (completed == null or !setOf(self.element).?.completed.items[completed.?].end.eql(after)) and
            match != null and combined > 0)
        {
            // "remove the completed transition (if present) from the set of
            // completed transitions and start a transition whose start time
            // is the time of the style change event plus the matching
            // transition delay, end time is the start time plus the matching
            // transition duration, start value is the value of the
            // transitioning property in the before-change style, end value
            // is the value of the transitioning property in the after-change
            // style, reversing-adjusted start value is the same as the start
            // value, and reversing shortening factor is 1."
            if (completed) |index| setOf(self.element).?.completed.orderedRemove(index).deinit(allocator);
            try self.start(p, before, after, before, 1, self.lists.duration(match.?), self.lists.delay(match.?), match.?);
            return;
        }
        // 2.
        if (completed) |index| {
            const set = setOf(self.element).?;
            if (!set.completed.items[index].end.eql(after)) set.completed.orderedRemove(index).deinit(allocator);
        }
        // 3.
        if (match == null) {
            if (running) |animation| self.cancel(animation);
            if (setOf(self.element)) |set| if (set.completedFor(self.pseudo, p)) |index| set.completed.orderedRemove(index).deinit(allocator);
            return;
        }
        // 4.
        const animation = running orelse return;
        const transition = transitionOf(animation).?;
        if (transition.end.eql(after)) return;
        const current = try currentValue(allocator, after_style, animation, transition);
        defer current.release();
        // 4.1.
        if (current.eql(after) or !transitionable(allocator, after_style, p, current, after, allow_discrete)) {
            self.cancel(animation);
            return;
        }
        // 4.2.
        if (combined <= 0) {
            self.cancel(animation);
            return;
        }
        const duration = self.lists.duration(match.?);
        const delay = self.lists.delay(match.?);
        // 4.3.
        if (transition.reversing_adjusted_start.eql(after)) {
            // "the absolute value, clamped to the range [0, 1], of the sum
            // of: the output of the timing function of the old transition at
            // the time of the style change event, times the reversing
            // shortening factor of the old transition; 1 minus the reversing
            // shortening factor of the old transition."
            const old_factor = transition.reversing_shortening_factor;
            const factor = std.math.clamp(@abs(progressOf(animation) * old_factor + (1 - old_factor)), 0, 1);
            // The old end value is the new reversing-adjusted start value:
            // keep a reference across the cancel.
            const adjusted = transition.end.retained();
            defer adjusted.release();
            self.cancel(animation);
            // start time: "the time of the style change event plus: if the
            // matching transition delay is nonnegative, the matching
            // transition delay, or if the matching transition delay is
            // negative, the product of the new transition's reversing
            // shortening factor and the matching transition delay"; end
            // time: "the start time plus the product of the matching
            // transition duration and the new transition's reversing
            // shortening factor".
            try self.start(p, current, after, adjusted, factor, duration * factor, if (delay >= 0) delay else factor * delay, match.?);
            return;
        }
        // 4.4.
        self.cancel(animation);
        try self.start(p, current, after, current, 1, duration, delay, match.?);
    }

    fn cancel(self: *Run, animation: *model.Animation) void {
        cancelFromStyle(animation);
        self.changed = true;
    }

    /// Start a transition of `p` on (element, pseudo).
    fn start(self: *Run, p: PropertyRef, from: TransitionValue, to: TransitionValue, adjusted: TransitionValue, factor: f64, duration: f64, delay: f64, index: usize) Allocator.Error!void {
        const generation = self.event.generation.* orelse blk: {
            const registry = registry_mod.of(self.element.ctx) orelse return;
            registry.transition_generation += 1;
            self.event.generation.* = registry.transition_generation;
            break :blk registry.transition_generation;
        };
        const timing_item = Lists.item(.transition_timing_function, self.lists.timings, index);
        if (try make(self.allocator, self.element, self.pseudo, p, from, to, adjusted, factor, duration, delay, timing_item, generation)) self.changed = true;
    }
};

/// Cancel every running transition of (element, pseudo) - every pseudo too
/// when `every` - and say whether there was one.
fn cancelAll(element: *runtime.Instance, set: *ElementTransitions, pseudo: ?[]const u8, every: bool) bool {
    var any = false;
    var i: usize = set.running.items.len;
    while (i > 0) {
        i -= 1;
        if (i >= set.running.items.len) continue;
        const instance = set.running.items[i].get() orelse {
            _ = set.running.orderedRemove(i);
            continue;
        };
        const animation = hooks.animationOf(instance) orelse continue;
        const transition = transitionOf(animation) orelse continue;
        if (!every and !samePseudo(transition.pseudo, pseudo)) continue;
        cancelFromStyle(animation);
        any = true;
    }
    if (every) {
        const allocator = element_style.existingOf(element).?.allocator;
        set.clearCompleted(allocator, null, true);
    }
    return any;
}

/// "Cancel" a transition (CSS Transitions 1 section 3; CSS Transitions 2
/// section 3: "it must disassociate the transition from its owning element
/// and run the procedure to cancel an animation on the transition"). Its
/// transitioncancel is queued first, at the owning element it had (CSS
/// Transitions 2 4.1: events use "the owning element and transition
/// generation that were set immediately prior to canceling"); Gecko
/// CSSTransition::CancelFromStyle, Blink ClearOwningElement + cancel.
pub fn cancelFromStyle(animation: *model.Animation) void {
    leaveRunningSet(animation);
    animation.cancel();
    css_events.update(animation);
    css_events.detach(animation);
    animation.settle();
}

/// Section 5: a running transition that finished completes: it moves from
/// the running transitions to the completed ones (its events follow, from
/// the same "update animations and send events").
pub fn complete(animation: *model.Animation) void {
    const transition = transitionOf(animation) orelse return;
    if (!transition.running) return;
    const element = owningElement(animation) orelse {
        leaveRunningSet(animation);
        return;
    };
    const set = setOf(element) orelse return;
    const allocator = element_style.existingOf(element).?.allocator;
    leaveRunningSet(animation);
    const pseudo: ?[]u8 = if (transition.pseudo) |p| allocator.dupe(u8, p) catch return else null;
    const property: Property = switch (transition.property) {
        .longhand => |l| .{ .longhand = l },
        .custom => |n| .{ .custom = allocator.dupe(u8, n) catch {
            if (pseudo) |p| allocator.free(p);
            return;
        } },
    };
    set.completed.append(allocator, .{ .pseudo = pseudo, .property = property, .end = transition.end.retained() }) catch {
        if (pseudo) |p| allocator.free(p);
        property.deinit(allocator);
        transition.end.release();
    };
}

/// HTML update the rendering step 11, for `animation` before its CSS events:
/// a running transition that finished completes (section 5).
pub fn completeIfFinished(animation: *model.Animation) void {
    if (!isRunningMember(animation)) return;
    if (animation.playState() == .finished) complete(animation);
}

// ============================================================================
// Making a CSSTransition
// ============================================================================

/// Make, associate and play a CSSTransition of `property` on (element,
/// pseudo) from `from` to `to`. Returns whether one was made.
fn make(
    allocator: Allocator,
    element: *runtime.Instance,
    pseudo: ?[]const u8,
    property: PropertyRef,
    from: TransitionValue,
    to: TransitionValue,
    adjusted: TransitionValue,
    factor: f64,
    duration: f64,
    delay: f64,
    timing_item: ?ListItem,
    generation: u64,
) Allocator.Error!bool {
    const realm = element.ctx;
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return false;
    // The two keyframes' values, serialized computed values.
    var from_text: std.ArrayList(u8) = .empty;
    defer from_text.deinit(allocator);
    var to_text: std.ArrayList(u8) = .empty;
    defer to_text.deinit(allocator);
    if (!try serialize(allocator, property, from, &from_text) or !try serialize(allocator, property, to, &to_text)) return false;
    var name_buffer: std.ArrayList(u8) = .empty;
    defer name_buffer.deinit(allocator);
    const property_name = switch (property) {
        .longhand => |l| l.name(),
        .custom => |n| n,
    };

    const timeline = registry_mod.defaultTimeline(document) catch return false;
    // The effect: target, timing, keyframes.
    const effect_instance = interfaces.KeyframeEffect.init(allocator, realm) catch return false;
    const effect_generation = runtime.SlabAllocator.generationOf(effect_instance);
    // Until the animation traces it (its wrapper made), the effect is ours to
    // free on every early return.
    var effect_wrapped = false;
    defer if (!effect_wrapped) effect_instance.releaseIfUnwrapped(effect_generation);
    const effect = hooks.effectOf(effect_instance) orelse return false;
    effect.keyframe_effect = true;
    effect.setTarget(element);
    if (pseudo) |p| effect.pseudo = try std.mem.concat(allocator, u8, &.{ "::", p });
    effect.timing.deinit(allocator);
    effect.timing = .{ .duration = duration, .delay = delay, .fill = .backwards, .iterations = 1 };
    if (timing_item) |it| if (it == .easing) {
        var text: std.ArrayList(u8) = .empty;
        defer text.deinit(allocator);
        try it.easing.serialize(&text, allocator);
        if (try easing_mod.parse(allocator, text.items)) |parsed| effect.timing.easing = parsed;
    };
    try appendFrame(allocator, &effect.keyframes, 0, property_name, from_text.items);
    try appendFrame(allocator, &effect.keyframes, 1, property_name, to_text.items);

    // The transition, wrapped at once: its lifetime is its wrapper's, as for
    // every platform object script has not seen yet.
    const instance = interfaces.CSSTransition.init(allocator, realm) catch return false;
    const owned = engine.retainValue(realm, .{ .instance = instance }) catch {
        instance.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(instance));
        return false;
    };
    defer owned.release();
    const animation = hooks.animationOf(instance) orelse return false;
    @import("root.zig").constructAnimation(instance, effect_instance, .{ .value = timeline }) catch return false;
    effect_wrapped = true;
    const pseudo_selector: []const u8 = if (pseudo) |p| blk: {
        try name_buffer.appendSlice(allocator, "::");
        try name_buffer.appendSlice(allocator, p);
        break :blk name_buffer.items;
    } else "";
    try css_events.attach(animation, .transition, element, pseudo_selector, property_name);
    const owned_property = try property.own(allocator);
    errdefer owned_property.deinit(allocator);
    const owned_pseudo: ?[]u8 = if (pseudo) |p| try allocator.dupe(u8, p) else null;
    errdefer if (owned_pseudo) |p| allocator.free(p);
    const set = try ensureSet(element);
    try set.running.ensureUnusedCapacity(allocator, 1);
    const transition = try allocator.create(Transition);
    transition.* = .{
        .property = owned_property,
        .pseudo = owned_pseudo,
        .start = from.retained(),
        .end = to.retained(),
        .reversing_adjusted_start = adjusted.retained(),
        .reversing_shortening_factor = factor,
        .generation = generation,
        .own_effect = model.Link.to(effect_instance),
    };
    // From here nothing fails: the state owns the transition's values.
    animation.css.?.transition = transition;
    set.running.appendAssumeCapacity(model.Link.to(instance));
    animation.play(true) catch {};
    return true;
}

fn appendFrame(allocator: Allocator, list: *keyframes_mod.List, offset: f64, name: []const u8, value: []const u8) Allocator.Error!void {
    var frame: keyframes_mod.Keyframe = .{ .offset = offset, .computed_offset = offset };
    errdefer frame.properties.deinit(allocator);
    const owned_name = try allocator.dupe(u8, name);
    errdefer allocator.free(owned_name);
    const owned_value = try allocator.dupe(u8, value);
    errdefer allocator.free(owned_value);
    try frame.properties.append(allocator, .{ .name = owned_name, .value = owned_value });
    try list.frames.append(allocator, frame);
}

/// A transition value as CSS text; false when it has none (a custom
/// property's guaranteed-invalid value).
fn serialize(allocator: Allocator, property: PropertyRef, value: TransitionValue, out: *std.ArrayList(u8)) Allocator.Error!bool {
    switch (property) {
        .longhand => |l| {
            try css.properties.serializeValue(l, value.value, out, allocator);
            return true;
        },
        .custom => {
            const text = value.custom orelse return false;
            try out.appendSlice(allocator, text.bytes);
            return true;
        },
    }
}

// ============================================================================
// Removal, and the sweep
// ============================================================================

/// DOM removing steps, for each removed node (registered by the Animation
/// interface's owner at process start). They only MARK - no engine call
/// inside the removal algorithm: the element's cached styles stop being
/// before-change styles, its completed transitions go, and its running
/// transitions and CSS animations are canceled at the next sweep (step 11
/// of the frame the removal asks for, or a getAnimations() flush).
pub fn removingSteps(node: *NodeBase, old_parent: ?*NodeBase) void {
    _ = old_parent;
    if (node.node_type != NodeBase.ELEMENT_NODE) return;
    const element: *runtime.Instance = @ptrCast(@alignCast(instance_bridge.getInstance(node) orelse return));
    const state = element_style.existingOf(element) orelse return;
    state.markRemoved();
    const both = state.animations orelse return;
    // Its CSS animations are canceled at the same sweep
    // (css_animations.sweep).
    var ask = @import("css_animations.zig").markRemoved(&both.css_animations);
    const set = &both.transitions;
    set.clearCompleted(state.allocator, null, true);
    if (set.running.items.len != 0) {
        set.removed = true;
        ask = true;
    }
    if (!ask) return;
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return;
    registry_mod.requestFrameFor(document);
}

/// The CSS transitions `document` times whose owning element left the
/// document since they started are canceled ("If an element is no longer in
/// the document, implementations must cancel any running transitions on
/// it"). HTML update the rendering steps 11 and 16, and the getAnimations()
/// flush.
pub fn sweep(document: *runtime.Instance) void {
    const registry = registry_mod.of(document.ctx) orelse return;
    var i: usize = 0;
    while (i < registry.animations.items.len) : (i += 1) {
        const instance = registry.animations.items[i].get() orelse continue;
        const animation = hooks.animationOf(instance) orelse continue;
        if (!isRunningMember(animation)) continue;
        if (animation.documentForTiming() != document) continue;
        const element = owningElement(animation) orelse {
            leaveRunningSet(animation);
            animation.settle();
            continue;
        };
        const set = setOf(element) orelse continue;
        const connected = interfaces.Node.get_isConnected(element) catch false;
        if (!set.removed and connected) continue;
        _ = cancelAll(element, set, null, true);
        set.removed = false;
    }
}

// ============================================================================
// Composite order (CSS Transitions 2 4.1)
// ============================================================================

/// Whether CSS transition `a` sorts before CSS transition `b` in composite
/// order; null when CSS Transitions 2 4.1 does not decide (the caller falls
/// back to the global animation list).
pub fn compositeLessThan(a: *const model.Animation, b: *const model.Animation) ?bool {
    const ea = owningElement(a);
    const eb = owningElement(b);
    // 1. Neither has an owning element: the global animation list.
    if (ea == null and eb == null) return null;
    // 2. Only one has: it sorts first.
    if (ea == null) return false;
    if (eb == null) return true;
    const ta = transitionOf(a);
    const tb = transitionOf(b);
    const pa: ?[]const u8 = if (ta) |t| t.pseudo else null;
    const pb: ?[]const u8 = if (tb) |t| t.pseudo else null;
    // 3. Different owning elements: tree order, a pseudo-element after its
    // element (::marker, ::before, the others by code points, ::after) and
    // before the element's children.
    if (ea.? != eb.?) {
        const position = interfaces.Node.call_compareDocumentPosition(ea.?, eb.?) catch return null;
        // DOCUMENT_POSITION_PRECEDING (2): b precedes a.
        return position & 2 == 0;
    }
    if (!samePseudo(pa, pb)) return pseudoRank(pa) < pseudoRank(pb) or (pseudoRank(pa) == pseudoRank(pb) and std.mem.order(u8, pa orelse "", pb orelse "") == .lt);
    // 4. Different transition generations: ascending.
    const ga = if (ta) |t| t.generation else 0;
    const gb = if (tb) |t| t.generation else 0;
    if (ga != gb) return ga < gb;
    // 5. The expanded transition property names, by code points.
    return std.mem.order(u8, css_events.nameOf(a), css_events.nameOf(b)) == .lt;
}

fn pseudoRank(pseudo: ?[]const u8) u8 {
    const p = pseudo orelse return 0;
    if (std.mem.eql(u8, p, "marker")) return 1;
    if (std.mem.eql(u8, p, "before")) return 2;
    if (std.mem.eql(u8, p, "after")) return 4;
    return 3;
}

test "Lists repeat their shorter lists and match the last item" {
    // Pure parts only: the item repetition (CSS Transitions 1 section 2).
    try std.testing.expectEqual(@as(f64, 2000), Lists.ms(.{ .number = .{ .literal = .{ .value = 2, .unit = .s } } }));
    try std.testing.expectEqual(@as(f64, 250), Lists.ms(.{ .number = .{ .literal = .{ .value = 250, .unit = .ms } } }));
    try std.testing.expectEqual(@as(f64, 0), Lists.ms(null));
    try std.testing.expectEqual(@as(u8, 2), pseudoRank("before"));
    try std.testing.expect(pseudoRank("marker") < pseudoRank("before"));
    try std.testing.expect(pseudoRank("before") < pseudoRank("selection"));
    try std.testing.expect(pseudoRank("selection") < pseudoRank("after"));
}
