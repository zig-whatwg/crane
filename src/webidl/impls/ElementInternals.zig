//! Implementation for ElementInternals interface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const ce = @import("dom").custom_elements;
const form_associated = @import("html").form_associated;
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const ElementInternals = interfaces.ElementInternals;

pub const State = ElementInternals.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    target: ?*runtime.Instance = null,
    target_generation: u64 = 0,
    target_traced: bool = false,
    states: ?*runtime.Instance = null,
    states_generation: u64 = 0,
    states_traced: bool = false,
    validity_flags: ce.ValidityFlags = .{},
    validity: ?*runtime.Instance = null,
    validity_generation: u64 = 0,
    validity_traced: bool = false,
    validation_message: []const u8 = "",
    validation_anchor_traced: bool = false,
    submission: ControlValue = .none,
    form_state: ControlValue = .none,
    submission_traced: bool = false,
    form_state_traced: bool = false,
    form_owner: ?*runtime.Instance = null,
    form_owner_generation: u64 = 0,
    disabled: bool = false,
    labels: ?*runtime.Instance = null,
    labels_generation: u64 = 0,
    labels_traced: bool = false,
    aria_active_descendant: @import("dom").node_holds.MemberHold = .{},
    aria_elements: [aria_array_members.len]AriaElements = @splat(.{}),
};

/// A [SameObject] child kept beside the owner's traced edge to it: the
/// child while it is still the one made - its slot not freed or reissued,
/// not torn down. The edge is what keeps it; a child whose edge was lost
/// reads as gone and is made again, never a freed or reissued object
/// (PR-N1, the 2026-10-03 lesson).
fn liveChild(child: ?*runtime.Instance, generation: u64) ?*runtime.Instance {
    const value = child orelse return null;
    if (runtime.SlabAllocator.generationOf(value) != generation or runtime.instance_lifecycle.isCleanedUp(value)) return null;
    return value;
}

const ControlValue = union(enum) {
    none,
    string: []const u8,
    /// Kept by the internals' traced edge; checked on every read (CE2-M2).
    file: ce.KeptInstance,
    form_data: struct { instance: *runtime.Instance, native_owned: bool, generation: u64 },

    fn deinit(value: *ControlValue, allocator: std.mem.Allocator) void {
        switch (value.*) {
            .string => |text| allocator.free(text),
            .form_data => |data| if (data.native_owned) runtime.Instance.deinit(data.instance) else data.instance.releaseIfUnwrapped(data.generation),
            else => {},
        }
        value.* = .none;
    }
    /// The object this value keeps while it is live: a File whose edge was
    /// lost, or a FormData freed under it, reads as none.
    fn object(value: ControlValue) ?*runtime.Instance {
        return switch (value) {
            .file => |file| file.get(),
            .form_data => |data| if (runtime.SlabAllocator.generationOf(data.instance) == data.generation) data.instance else null,
            else => null,
        };
    }
};

fn getInternal(instance: *runtime.Instance) !*InternalState {
    return instance.getState(State).own._internal orelse error.InvalidStateError;
}

fn targetElement(instance: *runtime.Instance) !*runtime.Instance {
    const internal = try getInternal(instance);
    const target = internal.target orelse return error.InvalidStateError;
    if (runtime.SlabAllocator.generationOf(target) != internal.target_generation or runtime.instance_lifecycle.isCleanedUp(target)) return error.InvalidStateError;
    return target;
}

fn formAssociatedTarget(instance: *runtime.Instance) !*runtime.Instance {
    const target = try targetElement(instance);
    const data = ce.get(target) orelse return error.NotSupportedError;
    const definition = data.definition orelse return error.NotSupportedError;
    if (!definition.form_associated) return error.NotSupportedError;
    return target;
}

pub fn installHooks() void {
    ce.installInternals(.{ .set_target = &setTarget, .states = &statesIfCreated, .validity_flags = &validityFlags, .refresh_form = &refreshForm, .append_form_entries = &appendFormEntries, .validation_state = &form_associated.validationState, .disabled_state = &form_associated.customDisabledState });
    @import("dom").form_controls.install(.{ .is = &ce.isFormAssociated, .reset = &resetControl });
    // CE2-S1: the mutations that can change a form-associated custom
    // element's owner or disabled state reset just the elements they reach.
    const form_owner = @import("html").custom_elements.form_owner;
    ce.installForm(.{ .subtree_moved = &form_owner.subtreeMoved, .attribute_changed = &form_owner.attributeChanged });
}

fn resetControl(element: *runtime.Instance) void {
    // HTML 4.13.3 reset algorithm: one callback, no automatic value clearing.
    ce.enqueueCallback(element, .form_reset, .none);
}

fn refreshForm(instance: *runtime.Instance) void {
    const target = formAssociatedTarget(instance) catch return;
    const internal = getInternal(instance) catch return;
    const form = form_associated.formOwner(target);
    const generation = if (form) |owner| runtime.SlabAllocator.generationOf(owner) else 0;
    const data = ce.get(target) orelse return;
    const definition = data.definition orelse return;
    if (form != internal.form_owner or generation != internal.form_owner_generation) {
        internal.form_owner = form;
        internal.form_owner_generation = generation;
        @import("html").custom_elements.enqueueCallback(target, definition, .form_associated, .{ .form_associated = form }) catch {};
    }
    const disabled = form_associated.isDisabled(target);
    if (disabled != internal.disabled) {
        internal.disabled = disabled;
        @import("html").custom_elements.enqueueCallback(target, definition, .form_disabled, .{ .form_disabled = disabled }) catch {};
    }
    // The ID its form attribute names is now the one to watch (HTML
    // 4.10.18.3's ID-target resets), or none.
    @import("html").custom_elements.form_owner.observe(target);
}

fn statesIfCreated(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(instance) catch return null;
    return liveChild(internal.states, internal.states_generation);
}

fn validityFlags(instance: *runtime.Instance) ce.ValidityFlags {
    return (getInternal(instance) catch return .{}).validity_flags;
}

fn flagsAreValid(flags: ce.ValidityFlags) bool {
    inline for (std.meta.fields(ce.ValidityFlags)) |field| {
        if (@field(flags, field.name) orelse false) return false;
    }
    return true;
}

fn setTarget(instance: *runtime.Instance, target: *runtime.Instance) !void {
    const internal = try getInternal(instance);
    internal.target = target;
    internal.target_generation = runtime.SlabAllocator.generationOf(target);
    if (instance.ctx.hasEngine()) {
        engine.traceChild(instance, target, .{ .name = "targetElement" });
        internal.target_traced = true;
    }
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    if (internal.target_traced) engine.forgetTracedChild(instance, .{ .name = "targetElement" });
    if (internal.states_traced) engine.forgetTracedChild(instance, .{ .name = "states" });
    if (internal.validity_traced) engine.forgetTracedChild(instance, .{ .name = "validity" });
    if (internal.labels_traced) engine.forgetTracedChild(instance, .{ .name = "labels" });
    // In engine-free tests the owner is responsible for lazily created
    // children. With an engine, the traced wrapper graph owns their lifetime.
    if (!internal.states_traced) if (liveChild(internal.states, internal.states_generation)) |child| runtime.Instance.deinit(child);
    if (!internal.validity_traced) if (liveChild(internal.validity, internal.validity_generation)) |child| runtime.Instance.deinit(child);
    if (!internal.labels_traced) if (liveChild(internal.labels, internal.labels_generation)) |child| runtime.Instance.deinit(child);
    if (internal.validation_anchor_traced) engine.forgetTracedChild(instance, .{ .name = "validationAnchor" });
    internal.allocator.free(internal.validation_message);
    if (internal.submission_traced) engine.forgetTracedChild(instance, .{ .name = "submissionValue" });
    if (internal.form_state_traced) engine.forgetTracedChild(instance, .{ .name = "formState" });
    internal.submission.deinit(internal.allocator);
    internal.form_state.deinit(internal.allocator);
    internal.aria_active_descendant.release(instance, aria_single_slot);
    inline for (aria_array_members, 0..) |member, i| {
        internal.aria_elements[i].deinit(internal.allocator);
        engine.forgetTracedChild(instance, .{ .name = member ++ ":explicit" });
        engine.forgetTracedChild(instance, .{ .name = member ++ ":cached" });
    }
    // ARIA's generated string fields own the internal default values.
    inline for (std.meta.fields(@TypeOf(state.own))) |field| {
        if (comptime field.type == ?runtime.DOMString and
            (std.mem.eql(u8, field.name, "role") or std.mem.startsWith(u8, field.name, "aria")))
        {
            if (@field(state.own, field.name)) |*value| value.deinit(internal.allocator);
            @field(state.own, field.name) = null;
        }
    }
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

/// Getter for shadowRoot
pub fn get_shadowRoot(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    // HTML 4.13.7.2 steps 1–5 include closed roots that were made available.
    const shadow = ce.shadowRootOf(try targetElement(instance)) orelse return null;
    return if (ce.shadowAvailableToInternals(shadow)) shadow else null;
}

/// Getter for form
pub fn get_form(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = try formAssociatedTarget(instance);
    const internal = try getInternal(instance);
    const owner = internal.form_owner orelse return null;
    if (runtime.SlabAllocator.generationOf(owner) != internal.form_owner_generation or runtime.instance_lifecycle.isCleanedUp(owner)) return null;
    return owner;
}

/// Getter for willValidate
pub fn get_willValidate(instance: *runtime.Instance) anyerror!bool {
    const target = try formAssociatedTarget(instance);
    // HTML 4.10.21.1 and 4.13.3: disabled, readonly and datalist bar FACE.
    if (form_associated.isDisabled(target) or form_associated.hasAttribute(target, "readonly")) return false;
    var ancestor = form_associated.parentOf(target);
    while (ancestor) |node| : (ancestor = form_associated.parentOf(node)) {
        if (form_associated.isElementNamed(node, "datalist")) return false;
    }
    return true;
}

/// Getter for validity
pub fn get_validity(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = try formAssociatedTarget(instance);
    const internal = try getInternal(instance);
    if (liveChild(internal.validity, internal.validity_generation)) |validity| return validity;
    const validity = try interfaces.ValidityState.init(internal.allocator, instance.ctx);
    errdefer runtime.Instance.deinit(validity);
    try ce.setValidityInternals(validity, instance);
    if (instance.ctx.hasEngine()) {
        engine.traceChild(instance, validity, .{ .name = "validity" });
        internal.validity_traced = true;
    }
    internal.validity = validity;
    internal.validity_generation = runtime.SlabAllocator.generationOf(validity);
    return validity;
}

/// Getter for validationMessage
pub fn get_validationMessage(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = try formAssociatedTarget(instance);
    return runtime.DOMString.initDupe(instance.ctx.allocator, (try getInternal(instance)).validation_message);
}

/// Getter for labels
pub fn get_labels(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const target = try formAssociatedTarget(instance);
    const internal = try getInternal(instance);
    if (liveChild(internal.labels, internal.labels_generation)) |labels| return labels;
    const list = try interfaces.NodeList.init(internal.allocator, instance.ctx);
    errdefer runtime.Instance.deinit(list);
    try @import("dom").node_lists.labels(list, target);
    if (instance.ctx.hasEngine()) {
        engine.traceChild(instance, list, .{ .name = "labels" });
        internal.labels_traced = true;
    }
    internal.labels = list;
    internal.labels_generation = runtime.SlabAllocator.generationOf(list);
    return list;
}

/// Getter for states
pub fn get_states(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = try getInternal(instance);
    if (liveChild(internal.states, internal.states_generation)) |states| return states;
    // HTML 4.13.7.5: the target's initially empty set, with stable identity.
    const states = try interfaces.CustomStateSet.init(internal.allocator, instance.ctx);
    errdefer runtime.Instance.deinit(states);
    try ce.setCustomStatesTarget(states, try targetElement(instance));
    if (instance.ctx.hasEngine()) {
        engine.traceChild(instance, states, .{ .name = "states" });
        internal.states_traced = true;
    }
    internal.states = states;
    internal.states_generation = runtime.SlabAllocator.generationOf(states);
    return states;
}

// HTML 2.6.1's ElementInternals reflected target uses internal content
// attributes, never the target's public attribute list (4.13.7.4). The
// generated nullable string fields are that private map's fixed keys.
// WAI-ARIA 6.3.2/6.3.4: preserve case and invalid values; do not apply defaults.
fn getAriaString(instance: *runtime.Instance, comptime member: []const u8) !?runtime.DOMString {
    // Nullable DOMString getter steps 2 and 5: return the internal value.
    const value = @field(instance.getState(State).own, member) orelse return null;
    return try value.clone(instance.ctx.allocator);
}

fn setAriaString(instance: *runtime.Instance, comptime member: []const u8, value: ?runtime.DOMString) !void {
    const internal = try getInternal(instance);
    const stored = &@field(instance.getState(State).own, member);
    // Setter steps 1-2: null deletes the entry, otherwise store a copy.
    // Allocate before replacing so an OOM leaves the previous value intact.
    const replacement = if (value) |text| try text.clone(internal.allocator) else null;
    if (stored.*) |*old| old.deinit(internal.allocator);
    stored.* = replacement;
}

// An internals reference is an explicit default, not an ID lookup through the
// target's public content attributes. Blink and Gecko do not scope-filter these
// references, unlike HTML 2.6.1's general reflected-element algorithm:
// https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/html/custom/element_internals.cc
//   ElementInternals::GetElementAttribute/GetElementArrayAttribute
// https://github.com/mozilla/gecko-dev/blob/master/dom/html/ElementInternals.cpp
//   ElementInternals::GetAttrElement/GetAttrElements
const aria_array_members = .{
    "ariaControlsElements",     "ariaDescribedByElements", "ariaDetailsElements",
    "ariaErrorMessageElements", "ariaFlowToElements",      "ariaLabelledByElements",
    "ariaOwnsElements",
};
const aria_single_slot: engine.TracedSlot = .{ .name = "ariaActiveDescendantElement" };

// The traced frozen arrays keep the wrappers; these native entries are only
// generation-checked identities for HTML's cached-array content comparison.
// No borrowed JS handle is retained, and the two arrays have distinct slots.
const AriaElements = struct {
    explicit: ?[]ce.KeptInstance = null,
    cached: ?[]ce.KeptInstance = null,

    fn deinit(self: *AriaElements, allocator: std.mem.Allocator) void {
        if (self.explicit) |values| allocator.free(values);
        if (self.cached) |values| allocator.free(values);
        self.* = .{};
    }
};

fn ariaArrayIndex(comptime member: []const u8) usize {
    inline for (aria_array_members, 0..) |name, i| {
        if (comptime std.mem.eql(u8, name, member)) return i;
    }
    @compileError("Unknown ARIA element-reference array");
}

fn getAriaElements(instance: *runtime.Instance, comptime member: []const u8) !?runtime.JSValue {
    const internal = try getInternal(instance);
    const state = &internal.aria_elements[comptime ariaArrayIndex(member)];
    const slot: engine.TracedSlot = .{ .name = member ++ ":cached" };
    // HTML 2.6.1 getter step 1: the explicit list, or null for an unset value.
    const explicit = state.explicit orelse {
        if (state.cached) |previous| internal.allocator.free(previous);
        state.cached = null;
        engine.forgetTracedChild(instance, slot);
        return null;
    };
    var count: usize = 0;
    var unchanged = state.cached != null;
    for (explicit) |kept| {
        const node = kept.get() orelse continue;
        if (state.cached) |cached| {
            if (count >= cached.len or cached[count].get() != node) unchanged = false;
        }
        count += 1;
    }
    if (state.cached) |cached| unchanged = unchanged and cached.len == count;
    // Step 2: equal contents reuse the same frozen array object, even after
    // assigning a new iterable with the same elements.
    if (unchanged) if (engine.tracedValue(instance, slot)) |cached| return cached.take();

    const values = try internal.allocator.alloc(runtime.JSValue, count);
    defer internal.allocator.free(values);
    const cached = try internal.allocator.alloc(ce.KeptInstance, count);
    errdefer internal.allocator.free(cached);
    var index: usize = 0;
    for (explicit) |kept| {
        const node = kept.get() orelse continue;
        values[index] = .{ .instance = node };
        cached[index] = kept;
        index += 1;
    }
    // Steps 3-6: freeze the snapshot, replace the cached contents/object,
    // and transfer a separate owned result to the getter's caller.
    const realm = engine.currentRealm() orelse instance.ctx;
    const array = try engine.createFrozenArray(realm, values);
    engine.traceValue(instance, array.borrow(), slot);
    if (state.cached) |previous| internal.allocator.free(previous);
    state.cached = cached;
    return array.take();
}

fn setAriaElements(instance: *runtime.Instance, comptime member: []const u8, value: ?runtime.JSValue) !void {
    const internal = try getInternal(instance);
    const allocator = internal.allocator;
    const generation = runtime.SlabAllocator.generationOf(instance);
    const owner_realm = instance.ctx;
    const slot: engine.TracedSlot = .{ .name = member ++ ":explicit" };
    // HTML 2.6.1 setter step 1: clear the explicit value. Leave the cached
    // value until the next get, as required by the independent getter steps.
    const input = value orelse {
        const state = &internal.aria_elements[comptime ariaArrayIndex(member)];
        if (state.explicit) |previous| allocator.free(previous);
        state.explicit = null;
        engine.forgetTracedChild(instance, slot);
        return;
    };
    const realm = engine.currentRealm() orelse instance.ctx;
    if (engine.typeOf(realm, input) != .object) return error.TypeError;

    const Collect = struct {
        realm: runtime.Context,
        values: @import("infra").List(engine.Owned),
        nodes: @import("infra").List(ce.KeptInstance),

        fn item(data: ?*anyopaque, next: runtime.JSValue) engine.Error!void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            // WebIDL 3.2.21.1 step 3.3: convert each item to Element before
            // advancing the iterator. Retain it across any later script/GC.
            const node = engine.convertToPlatformObject(self.realm, next) orelse return error.TypeError;
            if (node.stateAs(interfaces.Element.State) == null) return error.TypeError;
            const owned = try engine.retainValue(node.ctx, .{ .instance = node });
            errdefer owned.release();
            try self.nodes.append(ce.KeptInstance.of(node));
            try self.values.append(owned);
        }
    };
    var collect: Collect = .{
        .realm = realm,
        .values = .init(allocator),
        .nodes = .init(allocator),
    };
    defer {
        for (collect.values.toSlice()) |owned| owned.release();
        collect.values.deinit();
        collect.nodes.deinit();
    }
    if (!try engine.iterate(realm, input, Collect.item, &collect)) return error.TypeError;
    if (runtime.SlabAllocator.generationOf(instance) != generation or
        runtime.instance_lifecycle.isCleanedUp(instance) or !owner_realm.hasEngine()) return error.InvalidStateError;
    const state = &(try getInternal(instance)).aria_elements[comptime ariaArrayIndex(member)];
    // Conversion can run script (including a reentrant setter). Only replace
    // the current member after conversion and every allocation have succeeded.
    const nodes = try allocator.dupe(ce.KeptInstance, collect.nodes.toSlice());
    errdefer allocator.free(nodes);
    const values = try allocator.alloc(runtime.JSValue, collect.values.len);
    defer allocator.free(values);
    for (collect.values.toSlice(), values) |owned, *out| out.* = owned.borrow();
    const array = try engine.createFrozenArray(realm, values);
    defer array.release();
    engine.traceValue(instance, array.borrow(), slot);
    if (state.explicit) |previous| allocator.free(previous);
    state.explicit = nodes;
}

/// Getter for role
pub fn get_role(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "role");
}

/// Getter for ariaActiveDescendantElement
pub fn get_ariaActiveDescendantElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return (try getInternal(instance)).aria_active_descendant.get();
}

/// Getter for ariaAtomic
pub fn get_ariaAtomic(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaAtomic");
}

/// Getter for ariaAutoComplete
pub fn get_ariaAutoComplete(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaAutoComplete");
}

/// Getter for ariaBrailleLabel
pub fn get_ariaBrailleLabel(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaBrailleLabel");
}

/// Getter for ariaBrailleRoleDescription
pub fn get_ariaBrailleRoleDescription(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaBrailleRoleDescription");
}

/// Getter for ariaBusy
pub fn get_ariaBusy(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaBusy");
}

/// Getter for ariaChecked
pub fn get_ariaChecked(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaChecked");
}

/// Getter for ariaColCount
pub fn get_ariaColCount(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaColCount");
}

/// Getter for ariaColIndex
pub fn get_ariaColIndex(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaColIndex");
}

/// Getter for ariaColIndexText
pub fn get_ariaColIndexText(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaColIndexText");
}

/// Getter for ariaColSpan
pub fn get_ariaColSpan(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaColSpan");
}

/// Getter for ariaControlsElements
pub fn get_ariaControlsElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    return getAriaElements(instance, "ariaControlsElements");
}

/// Getter for ariaCurrent
pub fn get_ariaCurrent(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaCurrent");
}

/// Getter for ariaDescribedByElements
pub fn get_ariaDescribedByElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    return getAriaElements(instance, "ariaDescribedByElements");
}

/// Getter for ariaDescription
pub fn get_ariaDescription(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaDescription");
}

/// Getter for ariaDetailsElements
pub fn get_ariaDetailsElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    return getAriaElements(instance, "ariaDetailsElements");
}

/// Getter for ariaDisabled
pub fn get_ariaDisabled(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaDisabled");
}

/// Getter for ariaErrorMessageElements
pub fn get_ariaErrorMessageElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    return getAriaElements(instance, "ariaErrorMessageElements");
}

/// Getter for ariaExpanded
pub fn get_ariaExpanded(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaExpanded");
}

/// Getter for ariaFlowToElements
pub fn get_ariaFlowToElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    return getAriaElements(instance, "ariaFlowToElements");
}

/// Getter for ariaHasPopup
pub fn get_ariaHasPopup(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaHasPopup");
}

/// Getter for ariaHidden
pub fn get_ariaHidden(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaHidden");
}

/// Getter for ariaInvalid
pub fn get_ariaInvalid(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaInvalid");
}

/// Getter for ariaKeyShortcuts
pub fn get_ariaKeyShortcuts(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaKeyShortcuts");
}

/// Getter for ariaLabel
pub fn get_ariaLabel(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaLabel");
}

/// Getter for ariaLabelledByElements
pub fn get_ariaLabelledByElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    return getAriaElements(instance, "ariaLabelledByElements");
}

/// Getter for ariaLevel
pub fn get_ariaLevel(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaLevel");
}

/// Getter for ariaLive
pub fn get_ariaLive(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaLive");
}

/// Getter for ariaModal
pub fn get_ariaModal(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaModal");
}

/// Getter for ariaMultiLine
pub fn get_ariaMultiLine(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaMultiLine");
}

/// Getter for ariaMultiSelectable
pub fn get_ariaMultiSelectable(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaMultiSelectable");
}

/// Getter for ariaOrientation
pub fn get_ariaOrientation(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaOrientation");
}

/// Getter for ariaOwnsElements
pub fn get_ariaOwnsElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    return getAriaElements(instance, "ariaOwnsElements");
}

/// Getter for ariaPlaceholder
pub fn get_ariaPlaceholder(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaPlaceholder");
}

/// Getter for ariaPosInSet
pub fn get_ariaPosInSet(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaPosInSet");
}

/// Getter for ariaPressed
pub fn get_ariaPressed(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaPressed");
}

/// Getter for ariaReadOnly
pub fn get_ariaReadOnly(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaReadOnly");
}

/// Getter for ariaRelevant
pub fn get_ariaRelevant(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaRelevant");
}

/// Getter for ariaRequired
pub fn get_ariaRequired(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaRequired");
}

/// Getter for ariaRoleDescription
pub fn get_ariaRoleDescription(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaRoleDescription");
}

/// Getter for ariaRowCount
pub fn get_ariaRowCount(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaRowCount");
}

/// Getter for ariaRowIndex
pub fn get_ariaRowIndex(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaRowIndex");
}

/// Getter for ariaRowIndexText
pub fn get_ariaRowIndexText(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaRowIndexText");
}

/// Getter for ariaRowSpan
pub fn get_ariaRowSpan(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaRowSpan");
}

/// Getter for ariaSelected
pub fn get_ariaSelected(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaSelected");
}

/// Getter for ariaSetSize
pub fn get_ariaSetSize(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaSetSize");
}

/// Getter for ariaSort
pub fn get_ariaSort(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaSort");
}

/// Getter for ariaValueMax
pub fn get_ariaValueMax(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaValueMax");
}

/// Getter for ariaValueMin
pub fn get_ariaValueMin(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaValueMin");
}

/// Getter for ariaValueNow
pub fn get_ariaValueNow(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaValueNow");
}

/// Getter for ariaValueText
pub fn get_ariaValueText(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return getAriaString(instance, "ariaValueText");
}

/// Setter for role
pub fn set_role(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "role", value);
}

/// Setter for ariaActiveDescendantElement
pub fn set_ariaActiveDescendantElement(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    if (value) |node| if (node.stateAs(interfaces.Element.State) == null) return error.TypeError;
    const held = &(try getInternal(instance)).aria_active_descendant;
    if (value != null and held.get() == value) return;
    // HTML 2.6.1 setter steps 1 and 3: clear or replace the explicit value.
    // The existing member hold supplies the counted node and traced edge.
    held.release(instance, aria_single_slot);
    if (value) |node| held.take(instance, node, aria_single_slot);
}

/// Setter for ariaAtomic
pub fn set_ariaAtomic(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaAtomic", value);
}

/// Setter for ariaAutoComplete
pub fn set_ariaAutoComplete(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaAutoComplete", value);
}

/// Setter for ariaBrailleLabel
pub fn set_ariaBrailleLabel(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaBrailleLabel", value);
}

/// Setter for ariaBrailleRoleDescription
pub fn set_ariaBrailleRoleDescription(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaBrailleRoleDescription", value);
}

/// Setter for ariaBusy
pub fn set_ariaBusy(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaBusy", value);
}

/// Setter for ariaChecked
pub fn set_ariaChecked(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaChecked", value);
}

/// Setter for ariaColCount
pub fn set_ariaColCount(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaColCount", value);
}

/// Setter for ariaColIndex
pub fn set_ariaColIndex(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaColIndex", value);
}

/// Setter for ariaColIndexText
pub fn set_ariaColIndexText(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaColIndexText", value);
}

/// Setter for ariaColSpan
pub fn set_ariaColSpan(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaColSpan", value);
}

/// Setter for ariaControlsElements
pub fn set_ariaControlsElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    try setAriaElements(instance, "ariaControlsElements", value);
}

/// Setter for ariaCurrent
pub fn set_ariaCurrent(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaCurrent", value);
}

/// Setter for ariaDescribedByElements
pub fn set_ariaDescribedByElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    try setAriaElements(instance, "ariaDescribedByElements", value);
}

/// Setter for ariaDescription
pub fn set_ariaDescription(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaDescription", value);
}

/// Setter for ariaDetailsElements
pub fn set_ariaDetailsElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    try setAriaElements(instance, "ariaDetailsElements", value);
}

/// Setter for ariaDisabled
pub fn set_ariaDisabled(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaDisabled", value);
}

/// Setter for ariaErrorMessageElements
pub fn set_ariaErrorMessageElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    try setAriaElements(instance, "ariaErrorMessageElements", value);
}

/// Setter for ariaExpanded
pub fn set_ariaExpanded(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaExpanded", value);
}

/// Setter for ariaFlowToElements
pub fn set_ariaFlowToElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    try setAriaElements(instance, "ariaFlowToElements", value);
}

/// Setter for ariaHasPopup
pub fn set_ariaHasPopup(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaHasPopup", value);
}

/// Setter for ariaHidden
pub fn set_ariaHidden(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaHidden", value);
}

/// Setter for ariaInvalid
pub fn set_ariaInvalid(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaInvalid", value);
}

/// Setter for ariaKeyShortcuts
pub fn set_ariaKeyShortcuts(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaKeyShortcuts", value);
}

/// Setter for ariaLabel
pub fn set_ariaLabel(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaLabel", value);
}

/// Setter for ariaLabelledByElements
pub fn set_ariaLabelledByElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    try setAriaElements(instance, "ariaLabelledByElements", value);
}

/// Setter for ariaLevel
pub fn set_ariaLevel(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaLevel", value);
}

/// Setter for ariaLive
pub fn set_ariaLive(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaLive", value);
}

/// Setter for ariaModal
pub fn set_ariaModal(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaModal", value);
}

/// Setter for ariaMultiLine
pub fn set_ariaMultiLine(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaMultiLine", value);
}

/// Setter for ariaMultiSelectable
pub fn set_ariaMultiSelectable(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaMultiSelectable", value);
}

/// Setter for ariaOrientation
pub fn set_ariaOrientation(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaOrientation", value);
}

/// Setter for ariaOwnsElements
pub fn set_ariaOwnsElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    try setAriaElements(instance, "ariaOwnsElements", value);
}

/// Setter for ariaPlaceholder
pub fn set_ariaPlaceholder(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaPlaceholder", value);
}

/// Setter for ariaPosInSet
pub fn set_ariaPosInSet(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaPosInSet", value);
}

/// Setter for ariaPressed
pub fn set_ariaPressed(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaPressed", value);
}

/// Setter for ariaReadOnly
pub fn set_ariaReadOnly(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaReadOnly", value);
}

/// Setter for ariaRelevant
pub fn set_ariaRelevant(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaRelevant", value);
}

/// Setter for ariaRequired
pub fn set_ariaRequired(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaRequired", value);
}

/// Setter for ariaRoleDescription
pub fn set_ariaRoleDescription(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaRoleDescription", value);
}

/// Setter for ariaRowCount
pub fn set_ariaRowCount(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaRowCount", value);
}

/// Setter for ariaRowIndex
pub fn set_ariaRowIndex(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaRowIndex", value);
}

/// Setter for ariaRowIndexText
pub fn set_ariaRowIndexText(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaRowIndexText", value);
}

/// Setter for ariaRowSpan
pub fn set_ariaRowSpan(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaRowSpan", value);
}

/// Setter for ariaSelected
pub fn set_ariaSelected(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaSelected", value);
}

/// Setter for ariaSetSize
pub fn set_ariaSetSize(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaSetSize", value);
}

/// Setter for ariaSort
pub fn set_ariaSort(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaSort", value);
}

/// Setter for ariaValueMax
pub fn set_ariaValueMax(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaValueMax", value);
}

/// Setter for ariaValueMin
pub fn set_ariaValueMin(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaValueMin", value);
}

/// Setter for ariaValueNow
pub fn set_ariaValueNow(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaValueNow", value);
}

/// Setter for ariaValueText
pub fn set_ariaValueText(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    try setAriaString(instance, "ariaValueText", value);
}

/// Operation: setValidity
pub fn call_setValidity(instance: *runtime.Instance, flags: webidl.Opt(dictionaries.ValidityStateFlags), message: webidl.Opt(runtime.DOMString), anchor: webidl.Opt(*runtime.Instance)) anyerror!void {
    // The generated pointer signature erases the IDL HTMLElement brand.
    if (anchor.was_passed and anchor.value.stateAs(interfaces.HTMLElement.State) == null) return error.TypeError;
    // HTML 4.13.7.3 steps 1–4: validate before changing the validity flags.
    const target = try formAssociatedTarget(instance);
    const internal = try getInternal(instance);
    const new_flags = flags.getOrDefault(.{});
    const valid = flagsAreValid(new_flags);
    const text = message.getOrDefault(runtime.DOMString.initEmpty()).asSlice();
    if (!valid and text.len == 0) return error.TypeError;
    // Steps 5–8: normalize CRLF/CR to LF and replace every flag and message.
    var normalized: std.ArrayList(u8) = .empty;
    defer normalized.deinit(internal.allocator);
    if (!valid) {
        var index: usize = 0;
        while (index < text.len) : (index += 1) {
            if (text[index] == '\r') {
                try normalized.append(internal.allocator, '\n');
                if (index + 1 < text.len and text[index + 1] == '\n') index += 1;
            } else try normalized.append(internal.allocator, text[index]);
        }
    }
    const owned_message = try normalized.toOwnedSlice(internal.allocator);
    internal.allocator.free(internal.validation_message);
    internal.validation_message = owned_message;
    internal.validity_flags = new_flags;
    // Steps 9–11: the anchor must be a shadow-including inclusive descendant.
    const selected_anchor = anchor.getOrDefault(target);
    var ancestor: ?*runtime.Instance = selected_anchor;
    while (ancestor) |node| {
        if (node == target) break;
        ancestor = form_associated.parentOf(node);
        if (ancestor == null and node.stateAs(interfaces.ShadowRoot.State) != null) ancestor = try interfaces.ShadowRoot.get_host(node);
    } else return error.NotFoundError;
    if (instance.ctx.hasEngine()) {
        engine.traceChild(instance, selected_anchor, .{ .name = "validationAnchor" });
        internal.validation_anchor_traced = true;
    }
}

/// Operation: checkValidity
pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
    const target = try formAssociatedTarget(instance);
    // HTML 4.10.21.3 check-validity steps 1–2.
    if (!(try get_willValidate(instance)) or flagsAreValid((try getInternal(instance)).validity_flags)) return true;
    const event = try interfaces.Event.call_constructor(instance.ctx, runtime.DOMString.initInterned("invalid"), .passed(.{ .cancelable = true }));
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);
    _ = try @import("dom").fire_event.dispatchTrusted(target, event);
    return false;
}

/// Operation: reportValidity
pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
    // Same observable result/event; the host supplies any validation UI.
    return call_checkValidity(instance);
}

/// Operation: setFormValue
pub fn call_setFormValue(instance: *runtime.Instance, value: ?typedefs.FileOrUSVStringOrFormData, state: webidl.Opt(?runtime.JSValue)) anyerror!void {
    const realm = instance.ctx;
    const allocator = realm.allocator;
    const had_engine = realm.hasEngine();
    // WebIDL operation steps 2.1.5–2.1.8: convert every argument before
    // running HTML's method steps. This conversion can run author script.
    const converted_state = if (state.was_passed) try convertStateValue(realm, state.value) else null;
    defer if (converted_state) |converted| {
        if (converted == .usvstring) allocator.free(converted.usvstring);
    };
    if (had_engine and !realm.hasEngine()) return error.InvalidStateError;
    _ = try formAssociatedTarget(instance);
    const internal = try getInternal(instance);
    var submission = try copyControlValue(instance, value);
    defer submission.releaseRoot();
    errdefer submission.value.deinit(allocator);
    // HTML 4.13.7.3 steps 3–6: FormData's entry list is cloned, and an
    // omitted state uses the same value while an explicit null stays null.
    var saved_state = try copyControlValue(instance, if (state.was_passed) converted_state else value);
    defer saved_state.releaseRoot();
    errdefer saved_state.value.deinit(allocator);
    setValueEdge(instance, submission.value, "submissionValue", &internal.submission_traced);
    setValueEdge(instance, saved_state.value, "formState", &internal.form_state_traced);
    internal.submission.deinit(internal.allocator);
    internal.form_state.deinit(internal.allocator);
    internal.submission = submission.value;
    internal.form_state = saved_state.value;
}

fn setValueEdge(instance: *runtime.Instance, value: ControlValue, comptime slot: []const u8, traced: *bool) void {
    if (instance.ctx.hasEngine()) {
        if (value.object()) |object| {
            engine.traceChild(instance, object, .{ .name = slot });
            traced.* = true;
            return;
        }
    }
    if (traced.*) engine.forgetTracedChild(instance, .{ .name = slot });
    traced.* = false;
}

/// A cloned list must survive allocations while its entries (and a second
/// state list) are copied, before the internals' traced edges are installed.
const PreparedValue = struct {
    value: ControlValue,
    root: ?engine.Owned = null,

    fn releaseRoot(self: PreparedValue) void {
        if (self.root) |root| root.release();
    }
};

fn copyControlValue(instance: *runtime.Instance, value: ?typedefs.FileOrUSVStringOrFormData) !PreparedValue {
    const supplied = value orelse return .{ .value = .none };
    var prepared: PreparedValue = .{ .value = switch (supplied) {
        .usvstring => |text| .{ .string = try instance.ctx.allocator.dupe(u8, text) },
        .file => |file| .{ .file = ce.KeptInstance.of(file) },
        .form_data => blk: {
            const clone = try interfaces.FormData.call_constructor(instance.ctx, .notPassed(), .notPassed());
            break :blk .{ .form_data = .{ .instance = clone, .native_owned = !instance.ctx.hasEngine(), .generation = runtime.SlabAllocator.generationOf(clone) } };
        },
    } };
    errdefer prepared.value.deinit(instance.ctx.allocator);
    if (instance.ctx.hasEngine()) {
        if (prepared.value.object()) |object| prepared.root = try engine.retainValue(object.ctx, .{ .instance = object });
    }
    errdefer prepared.releaseRoot();
    if (supplied == .form_data) try appendDataEntries(prepared.value.form_data.instance, supplied.form_data);
    return prepared;
}

fn convertStateValue(realm: runtime.Context, value: ?runtime.JSValue) !?typedefs.FileOrUSVStringOrFormData {
    const given = value orelse return null;
    switch (engine.typeOf(realm, given)) {
        .null, .undefined => return null,
        else => {},
    }
    if (engine.convertToPlatformObject(realm, given)) |object| {
        if (object.stateAs(interfaces.File.State) != null) return .{ .file = object };
        if (object.stateAs(interfaces.FormData.State) != null) return .{ .form_data = object };
    }
    return .{ .usvstring = try engine.convertToUSVString(realm, given, realm.allocator) };
}

fn appendDataEntries(destination: *runtime.Instance, source: *runtime.Instance) !void {
    const entries = interfaces.FormData.getEntriesForIterable(source) orelse return;
    for (entries) |entry| switch (entry.value) {
        .usvstring => |text| try interfaces.FormData.call_append(destination, entry.name, text),
        .file => |file| try interfaces.FormData.call_append__1(destination, entry.name, file, .notPassed()),
    };
}

fn appendFormEntries(instance: *runtime.Instance, form_data: *runtime.Instance) !void {
    const target = try formAssociatedTarget(instance);
    const internal = try getInternal(instance);
    // HTML 4.13.7.3 entry-construction step 1 precedes the name check.
    if (internal.submission == .form_data) return appendDataEntries(form_data, internal.submission.object() orelse return);
    const name = (try form_associated.attributeValue(internal.allocator, target, "name")) orelse return;
    defer internal.allocator.free(name);
    if (name.len == 0) return;
    switch (internal.submission) {
        .none => {},
        .string => |text| try interfaces.FormData.call_append(form_data, name, text),
        // A File that is gone is submitted as nothing, never as whatever
        // reissued its slot.
        .file => |file| if (file.get()) |live| try interfaces.FormData.call_append__1(form_data, name, live, .notPassed()),
        .form_data => unreachable,
    }
}
