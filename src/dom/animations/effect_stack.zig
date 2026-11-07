//! The effect stack of an element (Web Animations 1 5.4): which keyframe
//! effects apply to it, in composite order; their computed keyframes (5.3.3);
//! the effect value of each target property (5.3.4, effect_values.zig) folded
//! onto the underlying value (5.4.3-5.4.4); and the composited values as the
//! declarations the cascade's animation origin receives (5.4.5).
//!
//! Pulled, like the rest of style (src/dom/style/engine.zig): nothing here
//! runs per frame. The style engine asks when it resolves an element's
//! style and that element's key moved (`component`):
//! - `component(element, pseudo)` is 0 for an element no effect targets,
//!   and the registry's values revision while effects target it - so a
//!   frame moves only the animated elements' keys (their descendants follow
//!   through the parent's style serial), never the whole document's.
//! - `animatedBlock` evaluates the stack over the element's base style.
//!
//! Computed keyframe values come from THE cascade: the caller's `Cascader`
//! cascades a keyframe's declaration block (keyframes.declarationBlock) above
//! every origin on this element, and each declared longhand's computed value
//! is read back - "compute a property value" (5.3.2) with exactly the
//! declarations' own var(), em, inherit, revert and logical mapping.
//!
//! Engines (designs only): Blink EffectStack::ActiveInterpolations and
//! StyleCascade::ApplyAnimations (core/animation, core/css/resolver); WebKit
//! KeyframeEffectStack and KeyframeEffect::setAnimatedPropertiesInStyle.
//!
//! Spec: https://drafts.csswg.org/web-animations-1/#combining-effects
const std = @import("std");
const runtime = @import("runtime");
const css = @import("css");
const model = @import("model.zig");
const hooks = @import("hooks.zig");
const registry_mod = @import("registry.zig");
const keyframes_mod = @import("keyframes.zig");
const effect_values = @import("effect_values.zig");

const Allocator = std.mem.Allocator;
const Value = css.style_values.Value;
const Longhand = css.properties.Longhand;
const ComputedStyle = css.computed_style.ComputedStyle;
const DeclarationBlock = css.declarations.DeclarationBlock;
const interpolation = css.interpolation;

/// The caller's cascade of the element being resolved.
pub const Cascader = struct {
    context: *anyopaque,
    /// The element's style with `block` cascaded above every origin (the
    /// transition origin's level): the computed keyframe values. OWNED.
    /// `under`, when given, is cascaded at the animation origin (the first
    /// round's composited values).
    cascadeAbove: *const fn (context: *anyopaque, under: ?*const DeclarationBlock, block: *const DeclarationBlock) Allocator.Error!*ComputedStyle,
};

// ============================================================================
// The target index (per values revision)
// ============================================================================

/// The effects that apply to each target, rebuilt the first time a style
/// read asks after the values revision moved. OWNED by the Registry.
pub const TargetIndex = struct {
    revision: u64 = 0,
    /// Effects as generation-checked links: an effect collected since the
    /// index was built is skipped, never read.
    map: std.AutoHashMapUnmanaged(Key, std.ArrayListUnmanaged(model.Link)) = .empty,
    /// Targets leave `map` as their animations end (`finish`): the
    /// tombstones they leave are bounded before each insert
    /// (src/infra/tombstones.zig).
    guard: @import("infra").tombstones.TombstoneGuard = .{},
    /// Every target's address (storage kept like the lists'), for a style
    /// read of an element no effect targets: while there are at most
    /// `scan_max`, a scan answers before the map hashes a key (every
    /// lineage entry of every read asks).
    addresses: std.ArrayListUnmanaged(usize) = .empty,

    pub const Key = struct { address: usize, generation: u64 };

    const scan_max = 8;

    pub fn deinit(self: *TargetIndex, allocator: Allocator) void {
        var it = self.map.valueIterator();
        while (it.next()) |list| list.deinit(allocator);
        self.map.deinit(allocator);
        self.addresses.deinit(allocator);
        self.* = .{};
    }

    /// A rebuild starts: every target's list empties and KEEPS its storage,
    /// so the frames of a running animation rebuild the index without
    /// allocating. A list freed and allocated again every frame shifted
    /// which buckets of its size class the WPT runner's DebugAllocator kept
    /// mapped (it never reuses a freed slot and unmaps a bucket with its
    /// last live slot), and the short-lived allocations of every style read
    /// of an UNANIMATED element then mapped and unmapped pages: about one
    /// extra page fault per getComputedStyle read beside one running
    /// animation (crane/r3-cost-one-spinner.html, +31%;
    /// tests/dom/r3_target_index_test.zig).
    pub fn begin(self: *TargetIndex) void {
        self.revision = 0;
        self.addresses.clearRetainingCapacity();
        var it = self.map.valueIterator();
        while (it.next()) |list| list.clearRetainingCapacity();
    }

    /// `link` applies to the target `key` names.
    pub fn add(self: *TargetIndex, allocator: Allocator, key: Key, link: model.Link) Allocator.Error!void {
        self.guard.beforeInsert(&self.map);
        const entry = try self.map.getOrPut(allocator, key);
        if (!entry.found_existing) entry.value_ptr.* = .empty;
        try entry.value_ptr.append(allocator, link);
    }

    /// The rebuild ends: each target's effects in composite order, and a
    /// target no effect applies to any more leaves with its storage.
    pub fn finish(self: *TargetIndex, allocator: Allocator, context: anytype, comptime lessThan: fn (@TypeOf(context), model.Link, model.Link) bool) Allocator.Error!void {
        var it = self.map.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.items.len != 0) {
                std.mem.sort(model.Link, entry.value_ptr.items, context, lessThan);
                try self.addresses.append(allocator, entry.key_ptr.address);
                continue;
            }
            entry.value_ptr.deinit(allocator);
            // Removal leaves a tombstone and never rehashes: the iterator
            // goes on over the same slots.
            self.map.removeByPtr(entry.key_ptr);
            self.guard.noteRemoval(&self.map);
        }
    }

    /// The effects that apply to `key`'s target, in composite order; null
    /// when none does.
    pub fn effectsOf(self: *const TargetIndex, key: Key) ?[]const model.Link {
        if (self.map.count() == 0) return null;
        if (self.addresses.items.len <= scan_max) {
            for (self.addresses.items) |address| {
                if (address == key.address) break;
            } else return null;
        }
        const list = self.map.getPtr(key) orelse return null;
        if (list.items.len == 0) return null;
        return list.items;
    }
};

/// 5.4.2: the effects in the stack - keyframe effects of animations whose
/// replace state is not removed, with a target, in effect.
fn applies(registry: *registry_mod.Registry, animation: *model.Animation, effect: *model.Effect) bool {
    if (registry.commit) |commit| {
        // 6.4 "commit computed styles" steps 5.1-5.3: the partial stack - up
        // to and including the committing animation, which counts even when
        // removed - with the endpoint-inclusive active interval.
        if (animation != commit.animation and registry_mod.compositeOrderLessThan({}, commit.animation, animation)) return false;
        if (animation.replace_state == .removed and animation != commit.animation) return false;
        if (!effect.keyframe_effect) return false;
        if (effect.targetElement() == null) return false;
        return effect.computedWith(true).active_time != null;
    }
    if (animation.replace_state == .removed) return false;
    if (!effect.keyframe_effect) return false;
    if (effect.targetElement() == null) return false;
    return effect.isInEffect();
}

fn linkLessThan(_: void, a: model.Link, b: model.Link) bool {
    const ea = hooks.effectOf(a.instance).?;
    const eb = hooks.effectOf(b.instance).?;
    return registry_mod.compositeOrderLessThan({}, ea.animationModel().?, eb.animationModel().?);
}

/// The index for the registry's current revision.
fn current(registry: *registry_mod.Registry) ?*TargetIndex {
    const index = &registry.targets;
    if (index.revision == registry.values_revision) return index;
    index.begin();
    for (registry.animations.items) |link| {
        const instance = link.get() orelse continue;
        const animation = hooks.animationOf(instance) orelse continue;
        const effect = animation.effectModel() orelse continue;
        if (!applies(registry, animation, effect)) continue;
        const target = effect.targetElement().?;
        index.add(registry.allocator, keyOf(target), model.Link.to(effect.instance)) catch return null;
    }
    index.finish(registry.allocator, {}, linkLessThan) catch return null;
    index.revision = registry.values_revision;
    return index;
}

fn liveEffect(link: model.Link) ?*model.Effect {
    const instance = link.get() orelse return null;
    const effect = hooks.effectOf(instance) orelse return null;
    if (effect.animationModel() == null) return null;
    return effect;
}

fn samePseudo(effect: *const model.Effect, pseudo: ?[]const u8) bool {
    const own = effect.pseudo orelse return pseudo == null;
    const wanted = pseudo orelse return false;
    // The effect's pseudo is "::before"-style; the style engine's is bare.
    const bare = std.mem.trimStart(u8, own, ":");
    return std.ascii.eqlIgnoreCase(bare, wanted);
}

fn effectsOf(element: *runtime.Instance) ?[]const model.Link {
    const registry = registry_mod.of(element.ctx) orelse return null;
    if (registry.animations.items.len == 0) return null;
    const index = current(registry) orelse return null;
    return index.effectsOf(keyOf(element));
}

/// A serial for a style the engine just resolved for `element`
/// (element_style.Cached.serial): its children compare it with the one they
/// were resolved under, so an animated parent resolved alone makes them
/// resolve again. Unique per event loop; 0 where no loop runs (a unit
/// test's), which keeps the serial check inert there. Kept on the Registry
/// so the StyleEngine embedded in Document's state does not grow.
pub fn nextStyleSerial(element: *runtime.Instance) u64 {
    const registry = registry_mod.of(element.ctx) orelse return 0;
    registry.style_serial +%= 1;
    if (registry.style_serial == 0) registry.style_serial = 1;
    return registry.style_serial;
}

/// The style-key component of (element, pseudo): 0 when no effect applies
/// to it, else the values revision (which moves on every change that can
/// move an effect value).
pub fn component(element: *runtime.Instance, pseudo: ?[]const u8) u64 {
    return reader(element).component(element, pseudo);
}

/// One style read's view of the effect stack (StyleEngine.computedStyle):
/// the registry, the index for the current revision and its revision,
/// found once for the read's whole lineage - every ancestor of every read
/// asks `component`, and nearly all of them are targeted by nothing.
pub const Reader = struct {
    index: ?*const TargetIndex = null,
    revision: u64 = 0,

    /// `component` (above) of `element`, which is in the same event loop
    /// as the element the reader was made for.
    pub fn component(self: Reader, element: *runtime.Instance, pseudo: ?[]const u8) u64 {
        const index = self.index orelse return 0;
        const effects = index.effectsOf(keyOf(element)) orelse return 0;
        for (effects) |link| {
            const effect = liveEffect(link) orelse continue;
            if (samePseudo(effect, pseudo)) return self.revision;
        }
        return 0;
    }
};

/// The reader for a style read of `element` (and its flat-tree ancestors).
pub fn reader(element: *runtime.Instance) Reader {
    const registry = registry_mod.of(element.ctx) orelse return .{};
    if (registry.animations.items.len == 0) return .{};
    const index = current(registry) orelse return .{};
    if (index.map.count() == 0) return .{};
    return .{ .index = index, .revision = registry.values_revision };
}

fn keyOf(element: *runtime.Instance) TargetIndex.Key {
    return .{ .address = @intFromPtr(element), .generation = runtime.SlabAllocator.generationOf(element) };
}

// ============================================================================
// commitStyles (6.4 "commit computed styles")
// ============================================================================

/// While armed on the Registry, a style read of `target` evaluates the
/// partial effect stack of `animation` and copies the effect values of the
/// properties `animation` targets.
pub const Commit = struct {
    allocator: Allocator,
    animation: *model.Animation,
    target: *runtime.Instance,
    /// The longhands `animation`'s effects set on `target` (step 4).
    targeted: std.AutoArrayHashMapUnmanaged(Longhand, void) = .empty,
    /// Their effect values (step 5.4), range-checked. OWNED.
    values: std.AutoArrayHashMapUnmanaged(Longhand, Value) = .empty,
    /// The custom properties `animation`'s effects set on `target` (step 4:
    /// "every property", custom properties included), each with its effect
    /// value once captured (`frame` unused). OWNED.
    customs: Customs = .empty,
    captured: bool = false,

    pub fn deinit(self: *Commit) void {
        for (self.values.values()) |v| v.release();
        self.values.deinit(self.allocator);
        self.targeted.deinit(self.allocator);
        releaseCustoms(self.allocator, &self.customs);
    }

    /// Custom property `name` is one `animation`'s effects target.
    fn targetCustom(self: *Commit, name: *css.custom_properties.Text) Allocator.Error!void {
        if (customIndex(&self.customs, name.bytes) != null) return;
        try self.customs.ensureUnusedCapacity(self.allocator, 1);
        name.retain();
        self.customs.appendAssumeCapacity(.{ .frame = 0, .name = name, .value = null });
    }

    fn capture(self: *Commit, composited: *const Composited, composited_customs: *const Customs) Allocator.Error!void {
        for (self.customs.items) |*custom| {
            const i = customIndex(composited_customs, custom.name.bytes) orelse continue;
            const value = composited_customs.items[i].value;
            if (value) |v| v.retain();
            if (custom.value) |old| old.release();
            custom.value = value;
        }
        self.captured = true;
        for (self.targeted.keys()) |l| {
            const v = composited.get(l) orelse continue;
            v.retain();
            const final = interpolation.clampFinal(l, v);
            const slot = self.values.getOrPut(self.allocator, l) catch |err| {
                final.release();
                return err;
            };
            if (slot.found_existing) slot.value_ptr.release();
            slot.value_ptr.* = final;
        }
    }
};

// ============================================================================
// Evaluating the stack
// ============================================================================

/// css.interpolation for one longhand, as effect_values' ops.
const ValueOps = struct {
    allocator: Allocator,
    longhand: Longhand,

    pub fn interpolate(self: ValueOps, a: Value, b: Value, p: f64) Allocator.Error!Value {
        return interpolation.interpolate(self.allocator, self.longhand, a, b, p);
    }
    pub fn add(self: ValueOps, a: Value, b: Value) Allocator.Error!Value {
        return interpolation.add(self.allocator, self.longhand, a, b);
    }
    pub fn accumulate(self: ValueOps, a: Value, b: Value) Allocator.Error!Value {
        return interpolation.accumulate(self.allocator, self.longhand, a, b);
    }
    pub fn retain(_: ValueOps, v: Value) Value {
        v.retain();
        return v;
    }
    pub fn release(_: ValueOps, v: Value) void {
        v.release();
    }
};

const PK = effect_values.PropertyKeyframe(Value);

/// One computed keyframe value of one longhand.
const ComputedValue = struct { frame: usize, longhand: Longhand, value: Value };

/// The composited values so far: physical longhand -> OWNED value.
const Composited = std.AutoArrayHashMapUnmanaged(Longhand, Value);

fn releaseAll(allocator: Allocator, composited: *Composited) void {
    for (composited.values()) |v| v.release();
    composited.deinit(allocator);
}

/// Which of the stack's effects a block composites (CSS Transitions 2 4.2):
/// CSS transitions with an owning element apply at the transitions level of
/// the cascade, every other effect at the animations level.
pub const Level = enum { animations, transitions };

fn levelOf(effect: *const model.Effect) Level {
    const animation = effect.animationModel() orelse return .animations;
    if (animation.class == .css_transition and @import("css_events.zig").hasOwningElement(animation)) return .transitions;
    return .animations;
}

/// The animated values of (element, pseudo) over `base` (its style without
/// animations), as declarations for the cascade level `level`: typed entries
/// of computed values, range-checked (Values 4 3.1). Null when no effect of
/// that level applies. OWNED.
pub fn animatedBlock(allocator: Allocator, element: *runtime.Instance, pseudo: ?[]const u8, base: *const ComputedStyle, cascader: Cascader, level: Level) Allocator.Error!?DeclarationBlock {
    const effects = effectsOf(element) orelse return null;
    // 5.3.2: "the computed values of dependencies held by value must be
    // calculated first". Two rounds, as Blink's StyleCascade applies its
    // high-priority interpolations first: the properties other values
    // depend on (font-size for em, line-height for lh, color for
    // currentcolor) are composited first, and the second round's keyframes
    // compute with those animated values in place.
    var early: Composited = .empty;
    defer releaseAll(allocator, &early);
    // Custom properties composite in the first round too: the later
    // longhands' keyframes substitute their animated values with var().
    var customs: Customs = .empty;
    defer releaseCustoms(allocator, &customs);
    var any = false;
    for (effects) |link| {
        const effect = liveEffect(link) orelse continue;
        if (!samePseudo(effect, pseudo) or levelOf(effect) != level) continue;
        any = true;
        try applyEffect(allocator, effect, base, cascader, null, .early, &early, &customs);
    }
    if (!any) return null;
    var early_block = try blockOf(allocator, &early, &customs);
    defer if (early_block) |*b| b.deinit();
    var composited: Composited = .empty;
    defer releaseAll(allocator, &composited);
    for (effects) |link| {
        const effect = liveEffect(link) orelse continue;
        if (!samePseudo(effect, pseudo) or levelOf(effect) != level) continue;
        try applyEffect(allocator, effect, base, cascader, if (early_block) |*b| b else null, .late, &composited, &customs);
    }
    for (early.keys(), early.values()) |l, *v| {
        try composited.put(allocator, l, v.*);
        v.* = .{ .keyword = .none }; // moved
    }
    // CSS Transitions 1 section 4: a transition's value enters the cascade
    // "if and only if that property is not currently undergoing a CSS
    // Animation on the same element" (Blink drops those transition
    // interpolations, kCSSTransitionBlockedByAnimation).
    if (level == .transitions) dropUnderCssAnimations(allocator, effects, pseudo, base, &composited, &customs);
    if (registry_mod.of(element.ctx)) |registry| if (registry.commit) |commit| {
        if (commit.target == element and pseudo == null) try commit.capture(&composited, &customs);
    };
    return try blockOf(allocator, &composited, &customs);
}

/// Whether an owned CSS animation in effect on (the element, `pseudo`) has
/// the longhand `l` or the custom property `custom` among its target
/// properties.
fn cssAnimationDrives(effects: []const model.Link, pseudo: ?[]const u8, base: *const ComputedStyle, l: ?Longhand, custom: ?[]const u8) bool {
    for (effects) |link| {
        const effect = liveEffect(link) orelse continue;
        if (!samePseudo(effect, pseudo)) continue;
        const animation = effect.animationModel() orelse continue;
        if (animation.class != .css_animation or !@import("css_events.zig").hasOwningElement(animation)) continue;
        for (effect.keyframes.frames.items) |frame| for (frame.properties.items) |property| {
            if (propertyNames(base, property.name, l, custom)) return true;
        };
    }
    return false;
}

/// Whether the keyframe property `name` sets `l` (a physical longhand, on
/// the element whose style is `style`) or is the custom property `custom`.
fn propertyNames(style: *const ComputedStyle, name: []const u8, l: ?Longhand, custom: ?[]const u8) bool {
    if (custom) |c| return std.mem.eql(u8, name, c);
    const wanted = l orelse return false;
    const found = css.properties.lookup(name) orelse return false;
    switch (found) {
        .longhand => |x| return style.physical(x) == wanted,
        .shorthand => |sh| for (sh.longhands()) |x| {
            if (style.physical(x) == wanted) return true;
        },
    }
    return false;
}

fn dropUnderCssAnimations(allocator: Allocator, effects: []const model.Link, pseudo: ?[]const u8, base: *const ComputedStyle, composited: *Composited, customs: *Customs) void {
    var i: usize = 0;
    while (i < composited.count()) {
        const l = composited.keys()[i];
        if (cssAnimationDrives(effects, pseudo, base, l, null)) {
            composited.values()[i].release();
            composited.swapRemoveAt(i);
        } else i += 1;
    }
    var j: usize = 0;
    while (j < customs.items.len) {
        const c = customs.items[j];
        if (cssAnimationDrives(effects, pseudo, base, null, c.name.bytes)) {
            c.name.release();
            if (c.value) |v| v.release();
            _ = customs.orderedRemove(j);
        } else j += 1;
    }
    _ = allocator;
}

/// Whether keyframe `frame` holds an IMPLICIT value (a CSS animation's
/// generated keyframe, css_animations) for the longhand `l` or the custom
/// property `custom`: the effect samples the underlying value there.
fn implicitIn(frame: *const keyframes_mod.Keyframe, base: *const ComputedStyle, l: ?Longhand, custom: ?[]const u8) bool {
    for (frame.properties.items) |property| {
        if (property.value.len != 0) continue;
        if (propertyNames(base, property.name, l, custom)) return true;
    }
    return false;
}

/// The composited values as typed declarations, range-checked (Values 4
/// 3.1), and the composited custom properties as custom declarations; null
/// when there are none. The block takes references of its own.
fn blockOf(allocator: Allocator, composited: *Composited, customs: *const Customs) Allocator.Error!?DeclarationBlock {
    if (composited.count() == 0 and customs.items.len == 0) return null;
    var block = DeclarationBlock.init(allocator);
    errdefer block.deinit();
    try block.entries.ensureTotalCapacity(allocator, composited.count() + customs.items.len);
    for (customs.items) |custom| {
        // A guaranteed-invalid effect value (an endpoint's) is the initial
        // value, as the custom property's own invalid value computes.
        const value: css.custom_properties.Specified = if (custom.value) |text| .{ .text = text } else .{ .css_wide = .initial };
        _ = block.setValidatedCustom(custom.name.bytes, value) catch |err| switch (err) {
            error.Invalid => unreachable, // a custom property name, in a style block
            error.OutOfMemory => return error.OutOfMemory,
        };
    }
    for (composited.keys(), composited.values()) |l, *v| {
        v.retain();
        const final = interpolation.clampFinal(l, v.*);
        block.entries.appendAssumeCapacity(.{ .typed = .{ .longhand = l, .value = .{ .value = final }, .important = false } });
    }
    return block;
}

const Round = enum { early, late };

/// The longhands the first round composites (see animatedBlock).
fn isEarly(l: Longhand) bool {
    return switch (l) {
        .font_size, .line_height, .color => true,
        else => false,
    };
}

fn roundDeclares(block: *const DeclarationBlock, round: Round) bool {
    for (block.entries.items) |*entry| {
        // Custom properties composite in the first round (see applyEffect).
        if (entry.* == .custom and round == .early) return true;
        if (entry.* != .typed) continue;
        // Logical longhands are never early.
        if (isEarly(entry.typed.longhand) == (round == .early)) return true;
    }
    return false;
}

/// One effect of the stack (5.4.3): each target property's effect value over
/// the underlying value so far, which it replaces.
fn applyEffect(allocator: Allocator, effect: *model.Effect, base: *const ComputedStyle, cascader: Cascader, under: ?*const DeclarationBlock, round: Round, composited: *Composited, composited_customs: *Customs) Allocator.Error!void {
    const registry = registry_mod.of(effect.instance.ctx);
    const commit = if (registry) |r| r.commit else null;
    const timing = effect.computedWith(commit != null);
    if (timing.progress == null) return;
    // 5.3.3: the computed keyframes.
    var computed_values: std.ArrayListUnmanaged(ComputedValue) = .empty;
    defer {
        for (computed_values.items) |c| c.value.release();
        computed_values.deinit(allocator);
    }
    var computed_customs: Customs = .empty;
    defer releaseCustoms(allocator, &computed_customs);
    for (effect.keyframes.frames.items, 0..) |*frame, frame_index| {
        if (frame.properties.items.len == 0) continue;
        var block = try keyframes_mod.declarationBlock(allocator, frame);
        defer block.deinit();
        if (block.entries.items.len == 0) continue;
        if (!roundDeclares(&block, round)) continue;
        const style = try cascader.cascadeAbove(cascader.context, under, &block);
        defer style.destroy();
        for (block.entries.items) |*entry| {
            if (entry.* == .custom) {
                // Custom properties composite in the first round: a value the
                // later longhands substitute with var() is a dependency held
                // by value (5.3.2), as Blink's StyleCascade applies custom
                // property interpolations before every other.
                if (round != .early) continue;
                const name = entry.custom.name;
                const value = style.customValue(name.bytes);
                try computed_customs.ensureUnusedCapacity(allocator, 1);
                name.retain();
                if (value) |v| v.retain();
                computed_customs.appendAssumeCapacity(.{ .frame = frame_index, .name = name, .value = value });
                continue;
            }
            if (entry.* != .typed) continue;
            const l = style.physical(entry.typed.longhand);
            if (interpolation.animationType(l) == .not_animatable) continue;
            if (isEarly(l) != (round == .early)) continue;
            const v = style.get(l);
            v.retain();
            computed_values.append(allocator, .{ .frame = frame_index, .longhand = l, .value = v }) catch |err| {
                v.release();
                return err;
            };
        }
    }
    // A CSS transition's keyframes are its start and end values themselves,
    // not their serialized text (css_transitions.ownLonghandValues).
    if (effect.animationModel()) |animation| {
        if (@import("css_transitions.zig").ownLonghandValues(animation, effect)) |own| {
            for (computed_values.items) |*c| {
                if (c.longhand != base.physical(own.longhand)) continue;
                const value = if (c.frame == 0) own.start else own.end;
                value.retain();
                c.value.release();
                c.value = value;
            }
        }
    }
    // Each target property in turn (5.3.4).
    var keyframe_list: std.ArrayListUnmanaged(PK) = .empty;
    defer keyframe_list.deinit(allocator);
    var done: std.AutoHashMapUnmanaged(Longhand, void) = .empty;
    defer done.deinit(allocator);
    for (computed_values.items) |seed| {
        if (done.contains(seed.longhand)) continue;
        try done.put(allocator, seed.longhand, {});
        keyframe_list.clearRetainingCapacity();
        const underlying = composited.get(seed.longhand) orelse base.get(seed.longhand);
        // The keyframes in order; a CSS animation's generated keyframe
        // holding an implicit value samples the underlying value with its
        // own easing (CSS Animations 2 3.2 step 3; Blink's neutral
        // keyframes).
        for (effect.keyframes.frames.items, 0..) |*frame, frame_index| {
            const declared = for (computed_values.items) |c| {
                if (c.longhand == seed.longhand and c.frame == frame_index) break true;
            } else false;
            if (!declared and implicitIn(frame, base, seed.longhand, null)) {
                try keyframe_list.append(allocator, .{
                    .offset = frame.computed_offset,
                    .easing = if (frame.easing.value != null) &frame.easing else null,
                    .composite = .replace,
                    .value = underlying,
                });
                continue;
            }
            for (computed_values.items) |c| {
                if (c.longhand != seed.longhand or c.frame != frame_index) continue;
                try keyframe_list.append(allocator, .{
                    .offset = frame.computed_offset,
                    .easing = if (frame.easing.value != null) &frame.easing else null,
                    .composite = switch (frame.composite) {
                        .auto => null,
                        .replace => .replace,
                        .add => .add,
                        .accumulate => .accumulate,
                    },
                    .value = c.value,
                });
            }
        }
        const ops: ValueOps = .{ .allocator = allocator, .longhand = seed.longhand };
        const result = try effect_values.effectValue(Value, ops, keyframe_list.items, .{
            .progress = timing.progress,
            .current_iteration = timing.current_iteration orelse 0,
            .before_flag = timing.before_flag,
        }, .{
            .composite = switch (effect.composite) {
                .replace => .replace,
                .add => .add,
                .accumulate => .accumulate,
            },
            .iteration_accumulate = effect.iteration_accumulate,
        }, underlying) orelse continue;
        const slot = composited.getOrPut(allocator, seed.longhand) catch |err| {
            result.release();
            return err;
        };
        if (slot.found_existing) slot.value_ptr.release();
        slot.value_ptr.* = result;
        if (commit) |c| if (effect.animationModel() == c.animation) try c.targeted.put(c.allocator, seed.longhand, {});
    }
    // A CSS transition's custom property keyframes are its start and end
    // values themselves, as Blink's TransitionKeyframes hold their values:
    // the computed text with its attr() taint (CSS Values 5 8.7.2), which
    // the keyframe's serialized text alone would lose
    // (css/css-variables/transition-with-attribute-taint.html).
    if (round == .early) if (effect.animationModel()) |animation| {
        if (@import("css_transitions.zig").ownCustomValues(animation, effect)) |own| {
            for (computed_customs.items) |*c| {
                if (!std.mem.eql(u8, c.name.bytes, own.name)) continue;
                const value = if (c.frame == 0) own.start else own.end;
                if (value) |v| v.retain();
                if (c.value) |old| old.release();
                c.value = value;
            }
        }
    };
    // Each target custom property in turn (5.3.4), combined by its
    // registered syntax (CSS Properties and Values API 1 2.5), or discretely
    // when it has none.
    var custom_keyframes: std.ArrayListUnmanaged(effect_values.PropertyKeyframe(CustomValue)) = .empty;
    defer custom_keyframes.deinit(allocator);
    for (computed_customs.items, 0..) |seed, seed_index| {
        const seen = for (computed_customs.items[0..seed_index]) |earlier| {
            if (std.mem.eql(u8, earlier.name.bytes, seed.name.bytes)) break true;
        } else false;
        if (seen) continue;
        custom_keyframes.clearRetainingCapacity();
        const existing = customIndex(composited_customs, seed.name.bytes);
        const underlying: CustomValue = if (existing) |i| composited_customs.items[i].value else base.customValue(seed.name.bytes);
        for (effect.keyframes.frames.items, 0..) |*frame, frame_index| {
            const declared = for (computed_customs.items) |c| {
                if (c.frame == frame_index and std.mem.eql(u8, c.name.bytes, seed.name.bytes)) break true;
            } else false;
            if (!declared and implicitIn(frame, base, null, seed.name.bytes)) {
                try custom_keyframes.append(allocator, .{
                    .offset = frame.computed_offset,
                    .easing = if (frame.easing.value != null) &frame.easing else null,
                    .composite = .replace,
                    .value = underlying,
                });
                continue;
            }
            for (computed_customs.items) |c| {
                if (c.frame != frame_index or !std.mem.eql(u8, c.name.bytes, seed.name.bytes)) continue;
                try custom_keyframes.append(allocator, .{
                    .offset = frame.computed_offset,
                    .easing = if (frame.easing.value != null) &frame.easing else null,
                    .composite = switch (frame.composite) {
                        .auto => null,
                        .replace => .replace,
                        .add => .add,
                        .accumulate => .accumulate,
                    },
                    .value = c.value,
                });
            }
        }
        const ops: CustomOps = .{ .allocator = allocator, .syntax = registeredSyntax(base, seed.name.bytes) };
        const result = try effect_values.effectValue(CustomValue, ops, custom_keyframes.items, .{
            .progress = timing.progress,
            .current_iteration = timing.current_iteration orelse 0,
            .before_flag = timing.before_flag,
        }, .{
            .composite = switch (effect.composite) {
                .replace => .replace,
                .add => .add,
                .accumulate => .accumulate,
            },
            .iteration_accumulate = effect.iteration_accumulate,
        }, underlying) orelse continue;
        if (existing) |i| {
            ops.release(composited_customs.items[i].value);
            composited_customs.items[i].value = result;
        } else {
            composited_customs.ensureUnusedCapacity(allocator, 1) catch |err| {
                ops.release(result);
                return err;
            };
            seed.name.retain();
            composited_customs.appendAssumeCapacity(.{ .frame = 0, .name = seed.name, .value = result });
        }
        if (commit) |c| if (effect.animationModel() == c.animation) try c.targetCustom(seed.name);
    }
}

/// A custom property's computed value in the stack: its token text (one
/// reference per holder), or null for the guaranteed-invalid value.
const CustomValue = ?*css.custom_properties.Text;

/// One custom property's value: a computed keyframe's (`frame`), or a
/// composited one. Holds a reference on `name` and on `value`.
const CustomEntry = struct { frame: usize, name: *css.custom_properties.Text, value: CustomValue };

/// The custom properties composited so far, in first-composited order.
const Customs = std.ArrayListUnmanaged(CustomEntry);

fn releaseCustoms(allocator: Allocator, customs: *Customs) void {
    for (customs.items) |c| {
        c.name.release();
        if (c.value) |v| v.release();
    }
    customs.deinit(allocator);
}

fn customIndex(customs: *const Customs, name: []const u8) ?usize {
    for (customs.items, 0..) |c, i| if (std.mem.eql(u8, c.name.bytes, name)) return i;
    return null;
}

/// Whether an animation that is not an owned CSS transition, in effect on
/// (element, pseudo), has `longhand` (a physical longhand) or the custom
/// property `custom` among its target properties: such a property starts no
/// transition (Gecko nsTransitionManager skips a property an effect set
/// animates, HasEffectiveAnimationOfProperty; Blink
/// CanCalculateTransitionUpdateForProperty; Chrome, Firefox and Safari pass
/// web-animations/interfaces/Animation/style-change-events.html, whose
/// covering animation keeps every probe transition from starting).
pub fn animatesProperty(element: *runtime.Instance, pseudo: ?[]const u8, style: *const ComputedStyle, longhand: ?Longhand, custom: ?[]const u8) bool {
    const effects = effectsOf(element) orelse return false;
    for (effects) |link| {
        const effect = liveEffect(link) orelse continue;
        if (!samePseudo(effect, pseudo) or levelOf(effect) != .animations) continue;
        for (effect.keyframes.frames.items) |frame| for (frame.properties.items) |property| {
            if (custom) |name| {
                if (std.mem.eql(u8, property.name, name)) return true;
                continue;
            }
            const wanted = longhand orelse continue;
            const found = css.properties.lookup(property.name) orelse continue;
            switch (found) {
                .longhand => |l| if (style.physical(l) == wanted) return true,
                .shorthand => |sh| for (sh.longhands()) |l| {
                    if (style.physical(l) == wanted) return true;
                },
            }
        };
    }
    return false;
}

/// CSS Transitions 1 "transitionable" for custom property `name` in
/// `style`: its registered syntax combines the pair smoothly (an
/// unregistered or universal one is discrete).
pub fn customSmooth(allocator: Allocator, style: *const ComputedStyle, name: []const u8, a: CustomValue, b: CustomValue) Allocator.Error!bool {
    const ops: CustomOps = .{ .allocator = allocator, .syntax = registeredSyntax(style, name) };
    const value = (try ops.combine(a, b, 0.5, .interpolate)) orelse return false;
    ops.release(value);
    return true;
}

/// Custom property `name`'s values `a` and `b` interpolated at `p` by its
/// registered syntax, discretely without one. OWNED.
pub fn customInterpolate(allocator: Allocator, style: *const ComputedStyle, name: []const u8, a: CustomValue, b: CustomValue, p: f64) Allocator.Error!CustomValue {
    const ops: CustomOps = .{ .allocator = allocator, .syntax = registeredSyntax(style, name) };
    return ops.interpolate(a, b, p);
}

/// The registered syntax of custom property `name` in `style`'s
/// registrations; null for an unregistered property or the universal
/// syntax, which animate discretely.
fn registeredSyntax(style: *const ComputedStyle, name: []const u8) ?*const css.syntax_definitions.Definition {
    const snapshot = style.registered orelse return null;
    const registration = snapshot.find(name) orelse return null;
    if (registration.syntax.universal) return null;
    return &registration.syntax;
}

/// effect_values' ops for a custom property: by its registered syntax
/// (css.interpolation.combineSyntax over the parsed computed values), else
/// discrete and not additive (Web Animations 1 5.2: an unregistered custom
/// property's animation type is discrete).
const CustomOps = struct {
    allocator: Allocator,
    syntax: ?*const css.syntax_definitions.Definition,

    pub fn interpolate(self: CustomOps, a: CustomValue, b: CustomValue, p: f64) Allocator.Error!CustomValue {
        // "p = 0 produces V_A and p = 1 produces V_B" (Values 4 3).
        if (p == 0) return self.retain(a);
        if (p == 1) return self.retain(b);
        if (try self.combine(a, b, p, .interpolate)) |v| return v;
        return self.retain(if (p < 0.5) a else b);
    }
    pub fn add(self: CustomOps, underlying: CustomValue, value: CustomValue) Allocator.Error!CustomValue {
        if (try self.combine(underlying, value, 1, .add)) |v| return v;
        return self.retain(value);
    }
    pub fn accumulate(self: CustomOps, underlying: CustomValue, value: CustomValue) Allocator.Error!CustomValue {
        if (try self.combine(underlying, value, 1, .accumulate)) |v| return v;
        return self.retain(value);
    }
    pub fn retain(_: CustomOps, v: CustomValue) CustomValue {
        if (v) |text| text.retain();
        return v;
    }
    pub fn release(_: CustomOps, v: CustomValue) void {
        if (v) |text| text.release();
    }

    /// The combination as computed text, or null when the syntax has no
    /// smooth combination for the pair.
    fn combine(self: CustomOps, a: CustomValue, b: CustomValue, p: f64, op: interpolation.SyntaxOp) Allocator.Error!CustomValue {
        const definition = self.syntax orelse return null;
        const ta = a orelse return null;
        const tb = b orelse return null;
        const options: css.properties.ParseOptions = .{ .allocator = self.allocator };
        var va = (try css.syntax_values.parse(definition, options, ta.bytes)) orelse return null;
        defer va.deinit();
        var vb = (try css.syntax_values.parse(definition, options, tb.bytes)) orelse return null;
        defer vb.deinit();
        var result = (try interpolation.combineSyntax(self.allocator, &va, &vb, p, op)) orelse return null;
        defer result.deinit();
        var text: std.ArrayList(u8) = .empty;
        defer text.deinit(self.allocator);
        try result.serialize(&text, self.allocator);
        return try css.custom_properties.Text.create(self.allocator, text.items);
    }
};
