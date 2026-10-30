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

    pub const Key = struct { address: usize, generation: u64 };

    pub fn deinit(self: *TargetIndex, allocator: Allocator) void {
        var it = self.map.valueIterator();
        while (it.next()) |list| list.deinit(allocator);
        self.map.deinit(allocator);
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
    pub fn finish(self: *TargetIndex, allocator: Allocator, context: anytype, comptime lessThan: fn (@TypeOf(context), model.Link, model.Link) bool) void {
        var it = self.map.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.items.len != 0) {
                std.mem.sort(model.Link, entry.value_ptr.items, context, lessThan);
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
        const key: TargetIndex.Key = .{ .address = @intFromPtr(target), .generation = runtime.SlabAllocator.generationOf(target) };
        index.add(registry.allocator, key, model.Link.to(effect.instance)) catch return null;
    }
    index.finish(registry.allocator, {}, linkLessThan);
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
    return index.effectsOf(.{ .address = @intFromPtr(element), .generation = runtime.SlabAllocator.generationOf(element) });
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
    const effects = effectsOf(element) orelse return 0;
    for (effects) |link| {
        const effect = liveEffect(link) orelse continue;
        if (samePseudo(effect, pseudo)) return registry_mod.of(element.ctx).?.values_revision;
    }
    return 0;
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
    captured: bool = false,

    pub fn deinit(self: *Commit) void {
        for (self.values.values()) |v| v.release();
        self.values.deinit(self.allocator);
        self.targeted.deinit(self.allocator);
    }

    fn capture(self: *Commit, composited: *const Composited) Allocator.Error!void {
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

/// The animated values of (element, pseudo) over `base` (its style without
/// animations), as declarations for the animation origin: typed entries of
/// computed values, range-checked (Values 4 3.1). Null when no effect
/// applies. OWNED.
pub fn animatedBlock(allocator: Allocator, element: *runtime.Instance, pseudo: ?[]const u8, base: *const ComputedStyle, cascader: Cascader) Allocator.Error!?DeclarationBlock {
    const effects = effectsOf(element) orelse return null;
    // 5.3.2: "the computed values of dependencies held by value must be
    // calculated first". Two rounds, as Blink's StyleCascade applies its
    // high-priority interpolations first: the properties other values
    // depend on (font-size for em, line-height for lh, color for
    // currentcolor) are composited first, and the second round's keyframes
    // compute with those animated values in place.
    var early: Composited = .empty;
    defer releaseAll(allocator, &early);
    var any = false;
    for (effects) |link| {
        const effect = liveEffect(link) orelse continue;
        if (!samePseudo(effect, pseudo)) continue;
        any = true;
        try applyEffect(allocator, effect, base, cascader, null, .early, &early);
    }
    if (!any) return null;
    var early_block = try blockOf(allocator, &early);
    defer if (early_block) |*b| b.deinit();
    var composited: Composited = .empty;
    defer releaseAll(allocator, &composited);
    for (effects) |link| {
        const effect = liveEffect(link) orelse continue;
        if (!samePseudo(effect, pseudo)) continue;
        try applyEffect(allocator, effect, base, cascader, if (early_block) |*b| b else null, .late, &composited);
    }
    for (early.keys(), early.values()) |l, *v| {
        try composited.put(allocator, l, v.*);
        v.* = .{ .keyword = .none }; // moved
    }
    if (registry_mod.of(element.ctx)) |registry| if (registry.commit) |commit| {
        if (commit.target == element and pseudo == null) try commit.capture(&composited);
    };
    return try blockOf(allocator, &composited);
}

/// The composited values as typed declarations, range-checked (Values 4
/// 3.1); null when there are none. The values move into the block.
fn blockOf(allocator: Allocator, composited: *Composited) Allocator.Error!?DeclarationBlock {
    if (composited.count() == 0) return null;
    var block = DeclarationBlock.init(allocator);
    errdefer block.deinit();
    try block.entries.ensureTotalCapacity(allocator, composited.count());
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
        if (entry.* != .typed) continue;
        // Logical longhands are never early.
        if (isEarly(entry.typed.longhand) == (round == .early)) return true;
    }
    return false;
}

/// One effect of the stack (5.4.3): each target property's effect value over
/// the underlying value so far, which it replaces.
fn applyEffect(allocator: Allocator, effect: *model.Effect, base: *const ComputedStyle, cascader: Cascader, under: ?*const DeclarationBlock, round: Round, composited: *Composited) Allocator.Error!void {
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
    for (effect.keyframes.frames.items, 0..) |*frame, frame_index| {
        if (frame.properties.items.len == 0) continue;
        var block = try keyframes_mod.declarationBlock(allocator, frame);
        defer block.deinit();
        if (block.entries.items.len == 0) continue;
        if (!roundDeclares(&block, round)) continue;
        const style = try cascader.cascadeAbove(cascader.context, under, &block);
        defer style.destroy();
        for (block.entries.items) |*entry| {
            // TODO(rendering3): custom properties animate discretely (5.2.1);
            // they need custom entries in the animation block.
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
    // Each target property in turn (5.3.4).
    var keyframe_list: std.ArrayListUnmanaged(PK) = .empty;
    defer keyframe_list.deinit(allocator);
    var done: std.AutoHashMapUnmanaged(Longhand, void) = .empty;
    defer done.deinit(allocator);
    for (computed_values.items) |seed| {
        if (done.contains(seed.longhand)) continue;
        try done.put(allocator, seed.longhand, {});
        keyframe_list.clearRetainingCapacity();
        for (computed_values.items) |c| {
            if (c.longhand != seed.longhand) continue;
            const frame = &effect.keyframes.frames.items[c.frame];
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
        const underlying = composited.get(seed.longhand) orelse base.get(seed.longhand);
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
}
