//! Implementation for HTMLInputElement interface
//!
//! Spec: HTML § 4.10.5 The input element
//! https://html.spec.whatwg.org/multipage/input.html
//!
//! What is here is the element's state and what changes it:
//!
//!   * the type attribute's state and its value mode (§ 4.10.5.4 `value`),
//!     the type change steps and the value sanitization algorithms
//!   * checkedness, the radio button group, and the activation behaviour -
//!     a checkbox or radio button toggles (legacy-pre-activation) and fires
//!     input and change, a submit or image button submits its form owner, a
//!     reset button resets it
//!   * the text control selection APIs (§ 4.10.20), shared with textarea
//!     through form_associated.zig
//!   * stepUp() / stepDown() and valueAsNumber, over the types' string <->
//!     number conversions (§ 4.10.5.1.x) and the date and time microsyntaxes
//!     (§ 2.3.5)
//!
//! Stated deviations: no constraint validation (validity, checkValidity,
//! willValidate report a control is never barred only by its own state), no
//! files are ever selected, and there is no rendering, so an Image Button's
//! selected coordinate is (0, 0) and width and height read 0.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const HTMLInputElement = interfaces.HTMLInputElement;
const reflection = @import("reflection.zig");
const form_associated = @import("html").form_associated;
const dom = @import("dom");
const instance_bridge = dom.instance_bridge;
const NodeBase = dom.NodeBase;
const log = std.log.scoped(.forms);

/// `size` reflects, but not as its IDL says. html.idl (webref, and the live
/// spec) declares `[CEReactions, Reflect] attribute unsigned long size;`,
/// while 4.10.5.3.2's prose says "The size IDL attribute is limited to only
/// positive numbers and has a default value of 20" - which reflection-forms
/// and every engine follow. The generated reflection would implement the IDL
/// (default 0, no IndexSizeError), so this impl states the prose's modifiers.
const size_reflection: reflection.Spec = .{ .name = "size", .limit = .positive, .default = 20 };
const autofill = @import("html").autofill;

pub const State = HTMLInputElement.State;

pub const ImplError = error{
    NotImplemented,
};

// ============================================================================
// The type attribute's states (§ 4.10.5)
// ============================================================================

/// The type attribute's states, by keyword. "The missing value default and
/// the invalid value default are the Text state."
pub const InputType = enum {
    hidden,
    text,
    search,
    tel,
    url,
    email,
    password,
    date,
    month,
    week,
    time,
    @"datetime-local",
    number,
    range,
    color,
    checkbox,
    radio,
    file,
    submit,
    image,
    reset,
    button,

    pub fn keyword(self: InputType) []const u8 {
        return @tagName(self);
    }

    /// The state an attribute value maps to: its keyword ASCII
    /// case-insensitively, else Text.
    pub fn fromAttribute(value: ?[]const u8) InputType {
        const v = value orelse return .text;
        inline for (std.meta.fields(InputType)) |field| {
            if (std.ascii.eqlIgnoreCase(v, field.name)) return @enumFromInt(field.value);
        }
        return .text;
    }

    /// § 4.10.5.4 "The value IDL attribute ... in one of the following
    /// modes, which define its behavior".
    pub fn valueMode(self: InputType) ValueMode {
        return switch (self) {
            .hidden, .submit, .image, .reset, .button => .default,
            .checkbox, .radio => .default_on,
            .file => .filename,
            else => .value,
        };
    }

    /// Whether selectionStart, selectionEnd, selectionDirection,
    /// setRangeText() and setSelectionRange() apply: the Text, Search, URL,
    /// Telephone and Password states.
    pub fn selectionApplies(self: InputType) bool {
        return switch (self) {
            .text, .search, .url, .tel, .password => true,
            else => false,
        };
    }

    /// Whether select() applies: the text-entry states and the ones with a
    /// text field of their own.
    pub fn selectApplies(self: InputType) bool {
        return switch (self) {
            .text, .search, .url, .tel, .password, .email, .date, .month, .week, .time, .@"datetime-local", .number, .color, .file => true,
            else => false,
        };
    }

    /// Whether stepUp(), stepDown() and valueAsNumber apply.
    pub fn numeric(self: InputType) bool {
        return switch (self) {
            .date, .month, .week, .time, .@"datetime-local", .number, .range => true,
            else => false,
        };
    }
};

pub const ValueMode = enum { value, default, default_on, filename };

/// The element's type attribute's state.
pub fn typeOf(instance: *runtime.Instance) InputType {
    const value = attribute(instance, "type") orelse return .text;
    defer instance.ctx.allocator.free(value);
    return InputType.fromAttribute(value);
}

/// The value of a content attribute in no namespace, owned by the element's
/// allocator; null when absent.
fn attribute(instance: *runtime.Instance, comptime name: []const u8) ?[]u8 {
    return form_associated.attributeValue(instance.ctx.allocator, instance, name) catch null;
}

fn hasAttribute(instance: *runtime.Instance, comptime name: []const u8) bool {
    return form_associated.hasAttribute(instance, name);
}

fn setAttributeValue(instance: *runtime.Instance, comptime name: []const u8, value: []const u8) !void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned(name), .{ .domstring = runtime.DOMString.initInterned(value) });
}

// ============================================================================
// Internal state
// ============================================================================

const utils = @import("webidl").utils;
const Registry = utils.InstanceRegistry(InternalState);

/// https://html.spec.whatwg.org/multipage/input.html#concept-fe-value
///
/// `value` and `checked` are NOT reflections. Each is element state that starts
/// out tracking a content attribute and permanently detaches the moment anything
/// assigns to it - the "dirty value flag" and "dirty checkedness flag". So:
///
///     <input value="a">           .value -> "a"   (tracking the attribute)
///     el.setAttribute("value","b"); .value -> "b"   (still tracking)
///     el.value = "c";               .value -> "c"   (now dirty)
///     el.setAttribute("value","d"); .value -> "c"   (attribute no longer wins)
///
/// That last line is the one that matters for React: it sets .value directly,
/// and a later attribute write must not clobber what it set.
///
/// Dirtiness of the value is encoded as the optional being non-null: a clean
/// value is the value attribute, sanitized, computed when read - which is what
/// "set the value of the element to the value of the value content attribute
/// and run the value sanitization algorithm" leaves on every attribute change.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// Owned. Non-null means the dirty value flag is set; always sanitized.
    value: ?[]u8 = null,
    /// The element's checkedness, and its dirty checkedness flag. Set from
    /// the checked content attribute while not dirty.
    checkedness: bool = false,
    dirty_checkedness: bool = false,
    /// The indeterminate IDL attribute's state.
    indeterminate: bool = false,
    /// The selection or text entry cursor (§ 4.10.20).
    selection: form_associated.TextSelection = .{},
    /// Select event tasks still queued (form_associated.queueSelectEvent).
    pending_select_tasks: u32 = 0,
    /// What the legacy-pre-activation behaviour saved for the
    /// legacy-canceled-activation behaviour.
    saved_checkedness: bool = false,
    saved_indeterminate: bool = false,
    saved_checked_radio: ?SavedRadio = null,

    pub fn deinit(self: *InternalState) void {
        if (self.value) |v| self.allocator.free(v);
        self.value = null;
    }

    fn setValue(self: *InternalState, value: []const u8) !void {
        const copy = try self.allocator.dupe(u8, value);
        if (self.value) |old| self.allocator.free(old);
        self.value = copy;
    }

    fn clearValue(self: *InternalState) void {
        if (self.value) |old| self.allocator.free(old);
        self.value = null;
    }
};

/// A radio button remembered across a dispatch, by generation.
const SavedRadio = struct {
    element: *runtime.Instance,
    generation: u64,

    fn isLive(self: SavedRadio) bool {
        return runtime.SlabAllocator.generationOf(self.element) == self.generation;
    }
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // The steps other code runs on inputs.
    dom.attribute_change_steps.install("input", &attributeChangeSteps);
    dom.activation.install(.{
        .has = &hasActivationBehavior,
        .run = &runActivationBehavior,
        .legacy_pre_activation = &legacyPreActivation,
        .legacy_canceled_activation = &legacyCanceledActivation,
    });
    dom.form_controls.install(.{ .is = &isInput, .reset = &resetAlgorithm });
    dom.teardown_sweeps.install(&cleanupAllRemainingInternal);
    dom.mutation.registerInsertionStepsCallback(&insertionStepsCallback) catch |err| {
        log.warn("input insertion steps not registered: {}", .{err});
    };
}

/// Initialize instance (creates the instance)
/// Chains to parent class: HTMLElement -> Element -> Node -> EventTarget
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain to parent class (HTMLElement)
    const instance = try interfaces.HTMLElement.initWithState(allocator, StateType, vtable, ctx);
    errdefer interfaces.HTMLElement.deinit(instance);

    // createIn, not set: the registry then owns the block and returns it to the
    // arena on remove, rather than dropping it from the map and holding it to
    // process exit.
    const ArenaAllocator = runtime.ArenaAllocator;
    const internal = try Registry.createIn(instance, ArenaAllocator.get());
    internal.* = .{ .allocator = ctx.allocator };

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    if (Registry.get(instance)) |internal| internal.deinit();
    Registry.remove(instance);

    interfaces.HTMLElement.deinit(instance);
}

/// dom.teardown_sweeps: an input still alive when the browser ends is never
/// deinit'd one by one, and its dirty value is its own allocation.
pub fn cleanupAllRemainingInternal() void {
    Registry.deinitAllAndClear();
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &HTMLInputElement.vtable, ctx);
    errdefer deinit(instance);
    return instance;
}

fn isInput(instance: *runtime.Instance) bool {
    return form_associated.isInput(instance);
}

// ============================================================================
// Attribute change steps, insertion steps and the type change steps
// ============================================================================

/// dom.attribute_change_steps for input elements.
fn attributeChangeSteps(
    instance: *runtime.Instance,
    local_name: []const u8,
    old_value: ?[]const u8,
    value: ?[]const u8,
    namespace: ?[]const u8,
) void {
    if (namespace != null) return;
    const internal = getInternal(instance) orelse return;
    if (std.mem.eql(u8, local_name, "type")) {
        const previous = InputType.fromAttribute(old_value);
        const now = InputType.fromAttribute(value);
        if (previous != now) typeChangeSteps(instance, previous, now);
    } else if (std.mem.eql(u8, local_name, "checked")) {
        // "When the checked content attribute is added, if the control does
        // not have dirty checkedness, the user agent must set the checkedness
        // of the element to true; when the checked content attribute is
        // removed, if the control does not have dirty checkedness, the user
        // agent must set the checkedness of the element to false."
        if (internal.dirty_checkedness) return;
        if ((old_value == null) == (value == null)) return;
        setCheckedness(instance, value != null);
    } else if (std.mem.eql(u8, local_name, "name")) {
        // The radio button group rule: the name changed.
        if (internal.checkedness and typeOf(instance) == .radio) uncheckOthersInGroup(instance);
    }
}

/// § 4.10.5 "When an input element's type attribute changes state".
fn typeChangeSteps(instance: *runtime.Instance, previous: InputType, now: InputType) void {
    const internal = getInternal(instance) orelse return;
    const previous_mode = previous.valueMode();
    const new_mode = now.valueMode();
    if (previous_mode == .value and (new_mode == .default or new_mode == .default_on)) {
        // 1. "If the previous state ... put the value IDL attribute in the
        // value mode, and the element's value is not the empty string, and
        // the new state ... puts the value IDL attribute in either the
        // default mode or the default/on mode, then set the element's value
        // content attribute to the element's value."
        const current = valueIn(instance, previous) catch return;
        defer internal.allocator.free(current);
        if (current.len > 0) {
            // The attribute change steps this runs see the new type; the
            // value is no longer the element's own.
            setAttributeValue(instance, "value", current) catch |err| {
                log.warn("input value attribute not set on a type change: {}", .{err});
            };
        }
    } else if (previous_mode != .value and new_mode == .value) {
        // 2. "set the value of the element to the value of the value content
        // attribute, if there is one, or the empty string otherwise, and then
        // set the control's dirty value flag to false."
        internal.clearValue();
    } else if (previous_mode != .filename and new_mode == .filename) {
        // 3. "set the value of the element to the empty string" - a File
        // Upload control's value is its selected files'.
        internal.clearValue();
    }
    // 4. (rendering). 5. Signal a type change: the radio button group rule.
    if (now == .radio and internal.checkedness) uncheckOthersInGroup(instance);
    // 6. The value sanitization algorithm of the new state, on a dirty value
    // (a clean one is sanitized when read).
    if (internal.value) |dirty| {
        const sanitized = sanitize(internal.allocator, instance, now, dirty) catch return;
        defer internal.allocator.free(sanitized);
        internal.setValue(sanitized) catch {};
    }
    // 7-9. Newly selectable: the text entry cursor at the beginning, the
    // direction "none".
    if (!previous.selectionApplies() and now.selectionApplies()) {
        internal.selection = .{};
    }
}

/// The input element's insertion steps: "The element becomes connected" is
/// one of the phenomena after which a checked radio button unchecks the
/// others in its group. Called for every inserted node.
fn insertionStepsCallback(node: *NodeBase) void {
    if (node.node_type != 1) return;
    const instance_ptr = instance_bridge.getInstance(node) orelse return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_ptr));
    const internal = getInternal(instance) orelse return;
    if (!internal.checkedness or typeOf(instance) != .radio) return;
    if (!(interfaces.Node.get_isConnected(instance) catch false)) return;
    uncheckOthersInGroup(instance);
}

// ============================================================================
// Checkedness and the radio button group
// ============================================================================

/// Set the element's checkedness; a radio button that becomes checked
/// unchecks the others in its group.
fn setCheckedness(instance: *runtime.Instance, checked: bool) void {
    const internal = getInternal(instance) orelse return;
    internal.checkedness = checked;
    if (checked and typeOf(instance) == .radio) uncheckOthersInGroup(instance);
}

/// The radio button group's name: a name attribute that is not empty.
/// Owned by the element's allocator.
fn groupName(instance: *runtime.Instance) ?[]u8 {
    const name = attribute(instance, "name") orelse return null;
    if (name.len == 0) {
        instance.ctx.allocator.free(name);
        return null;
    }
    return name;
}

/// Whether `other` is in `instance`'s radio button group: a radio button in
/// the same tree, with the same form owner (or none for both) and the same
/// non-empty name.
fn inSameGroup(instance: *runtime.Instance, name: []const u8, owner: ?*runtime.Instance, other: *runtime.Instance) bool {
    if (other == instance or !form_associated.isInput(other)) return false;
    if (typeOf(other) != .radio) return false;
    const other_name = groupName(other) orelse return false;
    defer other.ctx.allocator.free(other_name);
    if (!std.mem.eql(u8, name, other_name)) return false;
    return form_associated.formOwner(other) == owner;
}

/// "The checkedness state of all the other elements in the same radio
/// button group must be set to false."
fn uncheckOthersInGroup(instance: *runtime.Instance) void {
    const name = groupName(instance) orelse return;
    defer instance.ctx.allocator.free(name);
    const owner = form_associated.formOwner(instance);
    const root = form_associated.rootOf(instance);
    var node: ?*runtime.Instance = root;
    while (node) |n| : (node = form_associated.nextInTree(n, root, false)) {
        if (!inSameGroup(instance, name, owner, n)) continue;
        if (getInternal(n)) |other| other.checkedness = false;
    }
}

/// The checked radio button in `instance`'s group other than itself, if any.
fn checkedInGroup(instance: *runtime.Instance) ?*runtime.Instance {
    const name = groupName(instance) orelse return null;
    defer instance.ctx.allocator.free(name);
    const owner = form_associated.formOwner(instance);
    const root = form_associated.rootOf(instance);
    var node: ?*runtime.Instance = root;
    while (node) |n| : (node = form_associated.nextInTree(n, root, false)) {
        if (!inSameGroup(instance, name, owner, n)) continue;
        if (getInternal(n)) |other| {
            if (other.checkedness) return n;
        }
    }
    return null;
}

// ============================================================================
// Activation behaviour (§ 4.10.5 and each state's input activation behavior)
// ============================================================================

fn hasActivationBehavior(target: *runtime.Instance) bool {
    return form_associated.isInput(target);
}

/// "The legacy-pre-activation behavior for input elements": a checkbox
/// toggles (and stops being indeterminate); a radio button remembers its
/// group's checked button and becomes checked.
fn legacyPreActivation(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    switch (typeOf(instance)) {
        .checkbox => {
            internal.saved_checkedness = internal.checkedness;
            internal.saved_indeterminate = internal.indeterminate;
            // A user's (or click()'s) change of checkedness is an
            // interaction that changes it: the dirty checkedness flag.
            internal.dirty_checkedness = true;
            setCheckedness(instance, !internal.checkedness);
            internal.indeterminate = false;
        },
        .radio => {
            internal.saved_checked_radio = if (checkedInGroup(instance)) |checked|
                .{ .element = checked, .generation = runtime.SlabAllocator.generationOf(checked) }
            else
                null;
            internal.saved_checkedness = internal.checkedness;
            internal.dirty_checkedness = true;
            setCheckedness(instance, true);
        },
        else => {},
    }
}

/// "The legacy-canceled-activation behavior for input elements": undo it.
fn legacyCanceledActivation(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    switch (typeOf(instance)) {
        .checkbox => {
            internal.checkedness = internal.saved_checkedness;
            internal.indeterminate = internal.saved_indeterminate;
        },
        .radio => {
            // The remembered button, if it is still in this element's group,
            // is checked again; otherwise this element is unchecked.
            const saved = internal.saved_checked_radio;
            internal.saved_checked_radio = null;
            if (saved) |radio| {
                if (radio.isLive()) {
                    if (groupName(instance)) |name| {
                        defer instance.ctx.allocator.free(name);
                        if (inSameGroup(instance, name, form_associated.formOwner(instance), radio.element)) {
                            setCheckedness(radio.element, true);
                            return;
                        }
                    }
                }
            }
            internal.checkedness = false;
        },
        else => {},
    }
}

/// "The activation behavior for input elements element, given event".
fn runActivationBehavior(instance: *runtime.Instance, event: *runtime.Instance) void {
    const input_type = typeOf(instance);
    // 1. Not mutable (disabled; readonly where it applies), and neither a
    // checkbox nor a radio button: nothing.
    if (!isMutable(instance, input_type) and input_type != .checkbox and input_type != .radio) return;
    // 2. The input activation behavior of the state.
    switch (input_type) {
        .checkbox, .radio => {
            // 1. If the element is not connected, then return.
            if (!(interfaces.Node.get_isConnected(instance) catch false)) return;
            // 2. Fire input, bubbling and composed. 3. Fire change, bubbling.
            fireEvent(instance, "input", .{ .bubbles = true, .composed = true }) catch |err| {
                log.warn("input event not fired: {}", .{err});
            };
            fireEvent(instance, "change", .{ .bubbles = true }) catch |err| {
                log.warn("change event not fired: {}", .{err});
            };
        },
        .submit, .image => {
            // 1. No form owner: nothing. 2. (Fully active.) 3. Submit the
            // form owner from the element, with userInvolvement set to
            // event's user navigation involvement. (Image: the selected
            // coordinate stays (0, 0).)
            const owner = form_associated.formOwner(instance) orelse return;
            dom.form_submission.submit(owner, instance, userInvolvement(event)) catch |err| {
                log.warn("form not submitted: {}", .{err});
            };
        },
        .reset => {
            // 1. No form owner: nothing. 2. (Fully active.) 3. Reset the form
            // owner.
            const owner = form_associated.formOwner(instance) orelse return;
            dom.form_submission.reset(owner) catch |err| {
                log.warn("form not reset: {}", .{err});
            };
        },
        // File Upload and Color show a picker: there is none to show.
        else => {},
    }
    // 3-4. The popover target attribute activation behavior is not
    // implemented.
}

/// DOM "fire an event" named `event_type` at the element: a trusted Event
/// made in its realm, dispatched through dom.fire_event.
fn fireEvent(instance: *runtime.Instance, comptime event_type: []const u8, init_dict: dictionaries.EventInit) !void {
    const event = try interfaces.Event.call_constructor(
        instance.ctx,
        runtime.DOMString.initInterned(event_type),
        webidl.Opt(dictionaries.EventInit).passed(init_dict),
    );
    // A listener can keep the event; only one nothing wrapped is freed here.
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);
    _ = try dom.fire_event.dispatchTrusted(instance, event);
}

/// An event's "user navigation involvement": "activation" when it is
/// trusted, "none" otherwise.
fn userInvolvement(event: *runtime.Instance) dom.form_submission.UserInvolvement {
    const trusted = interfaces.Event.get_isTrusted(event) catch false;
    return if (trusted) .activation else .none;
}

/// "Mutable": not disabled, and not readonly where readonly applies.
fn isMutable(instance: *runtime.Instance, input_type: InputType) bool {
    if (form_associated.isDisabled(instance)) return false;
    const readonly_applies = switch (input_type) {
        .text, .search, .url, .tel, .email, .password, .date, .month, .week, .time, .@"datetime-local", .number => true,
        else => false,
    };
    return !(readonly_applies and hasAttribute(instance, "readonly"));
}

/// dom.form_controls: "The reset algorithm for input elements is to set the
/// user validity, dirty value flag, and dirty checkedness flag back to
/// false, set the value of the element to the value of the value content
/// attribute, if there is one, or the empty string otherwise, set the
/// checkedness of the element to true if the element has a checked content
/// attribute and false if it does not, empty the list of selected files,
/// and then invoke the value sanitization algorithm, if the type
/// attribute's current state defines one."
fn resetAlgorithm(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    internal.clearValue();
    internal.dirty_checkedness = false;
    setCheckedness(instance, hasAttribute(instance, "checked"));
}

// ============================================================================
// The value (§ 4.10.5.4 `value`)
// ============================================================================

/// The element's value as the given state reads it, owned by the
/// element's allocator.
fn valueIn(instance: *runtime.Instance, input_type: InputType) ![]u8 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const allocator = internal.allocator;
    return switch (input_type.valueMode()) {
        // "value": the element's value - the dirty one, or the value
        // attribute sanitized.
        .value => if (internal.value) |v| allocator.dupe(u8, v) else blk: {
            const given = attribute(instance, "value");
            defer if (given) |g| instance.ctx.allocator.free(g);
            break :blk sanitize(allocator, instance, input_type, given orelse "");
        },
        // "default": the value attribute, or the empty string.
        .default => attribute(instance, "value") orelse allocator.dupe(u8, ""),
        // "default/on": the value attribute, or "on".
        .default_on => attribute(instance, "value") orelse allocator.dupe(u8, "on"),
        // "filename": no files are ever selected, so the empty string.
        .filename => allocator.dupe(u8, ""),
    };
}

/// The element's value in its current state; owned by the element's
/// allocator.
fn currentValue(instance: *runtime.Instance) ![]u8 {
    return valueIn(instance, typeOf(instance));
}

/// The relevant value's length, in UTF-16 code units, for the selection.
fn relevantValueLength(instance: *runtime.Instance) u32 {
    const internal = getInternal(instance) orelse return 0;
    const text = currentValue(instance) catch return 0;
    defer internal.allocator.free(text);
    return form_associated.utf16Length(text);
}

/// Getter for value
pub fn get_value(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const text = try currentValue(instance);
    if (text.len == 0) {
        getInternal(instance).?.allocator.free(text);
        return runtime.DOMString.initEmpty();
    }
    return runtime.DOMString.initOwned(text);
}

/// Setter for value, by mode.
pub fn set_value(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    const input_type = typeOf(instance);
    switch (input_type.valueMode()) {
        .value => {
            // 1. Let oldValue be the element's value.
            const old = try currentValue(instance);
            defer internal.allocator.free(old);
            // 2-4. Set the value to the new value, set the dirty value flag,
            // and invoke the value sanitization algorithm.
            const sanitized = try sanitize(internal.allocator, instance, input_type, value.asSlice());
            defer internal.allocator.free(sanitized);
            try internal.setValue(sanitized);
            // 5. "If the element's value (after applying the value
            // sanitization algorithm) is different from oldValue, and the
            // element has a text entry cursor position, move the text entry
            // cursor position to the end of the text control, unselecting any
            // selected text and resetting the selection direction to "none"."
            if (!std.mem.eql(u8, old, sanitized)) {
                const end = form_associated.utf16Length(sanitized);
                internal.selection = .{ .start = end, .end = end, .direction = .none };
            }
        },
        // "default" and "default/on": set the value content attribute.
        .default, .default_on => try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("value"), .{ .domstring = value }),
        // "filename": the empty string empties the list of selected files;
        // anything else throws.
        .filename => if (value.asSlice().len != 0) return error.InvalidStateError,
    }
}

// ============================================================================
// Value sanitization (§ 4.10.5.1.x "value sanitization algorithm")
// ============================================================================

fn isNewline(c: u8) bool {
    return c == '\n' or c == '\r';
}

/// Infra's ASCII whitespace: TAB, LF, FF, CR and SPACE.
fn isAsciiWhitespace(c: u8) bool {
    return c == '\t' or c == '\n' or c == 0x0C or c == '\r' or c == ' ';
}

fn stripNewlines(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    for (text) |c| {
        if (!isNewline(c)) try out.append(allocator, c);
    }
    return out.toOwnedSlice(allocator);
}

fn trimAsciiWhitespace(text: []const u8) []const u8 {
    return std.mem.trim(u8, text, "\t\n\x0C\r ");
}

/// The value sanitization algorithm of `input_type`, applied to `value`.
/// The result is owned by `allocator`.
fn sanitize(allocator: std.mem.Allocator, instance: *runtime.Instance, input_type: InputType, value: []const u8) ![]u8 {
    switch (input_type) {
        // "Strip newlines from the value."
        .text, .search, .tel, .password => return stripNewlines(allocator, value),
        // "Strip newlines from the value, then strip leading and trailing
        // ASCII whitespace from the value."
        .url => {
            const stripped = try stripNewlines(allocator, value);
            defer allocator.free(stripped);
            return allocator.dupe(u8, trimAsciiWhitespace(stripped));
        },
        .email => {
            const stripped = try stripNewlines(allocator, value);
            defer allocator.free(stripped);
            if (!hasAttribute(instance, "multiple")) return allocator.dupe(u8, trimAsciiWhitespace(stripped));
            // multiple: "split on commas, strip leading and trailing ASCII
            // whitespace from each resulting token, if any, and let the
            // element's values be the (possibly empty) resulting list of
            // (possibly empty) tokens, maintaining the original order" - and
            // the value is those values joined with ",".
            var out: std.ArrayListUnmanaged(u8) = .empty;
            errdefer out.deinit(allocator);
            var tokens = std.mem.splitScalar(u8, stripped, ',');
            var first = true;
            while (tokens.next()) |token| {
                if (!first) try out.append(allocator, ',');
                first = false;
                try out.appendSlice(allocator, trimAsciiWhitespace(token));
            }
            return out.toOwnedSlice(allocator);
        },
        // "If the value of the element is not a valid date string, then set
        // it to the empty string instead" - and likewise for the others.
        .date => return allocator.dupe(u8, if (parseDate(value) != null) value else ""),
        .month => return allocator.dupe(u8, if (parseMonth(value) != null) value else ""),
        .week => return allocator.dupe(u8, if (parseWeek(value) != null) value else ""),
        .time => return allocator.dupe(u8, if (parseTime(value) != null) value else ""),
        // "If the value of the element is a valid local date and time string,
        // then set it to a valid normalized local date and time string
        // representing the same date and time; otherwise, set it to the empty
        // string instead."
        .@"datetime-local" => {
            const parsed = parseLocalDateTime(value) orelse return allocator.dupe(u8, "");
            return formatLocalDateTime(allocator, parsed);
        },
        // "If the value of the element is not a valid floating-point number,
        // then set it to the empty string instead."
        .number => return allocator.dupe(u8, if (parseValidFloat(value) != null) value else ""),
        .range => return sanitizeRange(allocator, instance, value),
        // "If the value of the element is a valid simple color, then set it
        // to the value of the element converted to ASCII lowercase;
        // otherwise, set it to the string "#000000"."
        .color => {
            if (!isValidSimpleColor(value)) return allocator.dupe(u8, "#000000");
            const lowered = try allocator.dupe(u8, value);
            for (lowered) |*c| c.* = std.ascii.toLower(c.*);
            return lowered;
        },
        else => return allocator.dupe(u8, value),
    }
}

/// The Range state's sanitization: "If the value of the element is not a
/// valid floating-point number, then set it to the best representation, as
/// a floating-point number, of the default value" - then the state's
/// underflow, overflow and step mismatch rules, which set the value to the
/// minimum, the maximum, or the nearest allowed step (rounding up on a tie).
fn sanitizeRange(allocator: std.mem.Allocator, instance: *runtime.Instance, value: []const u8) ![]u8 {
    const minimum = numberAttribute(instance, .range, "min") orelse 0;
    const maximum_given = numberAttribute(instance, .range, "max") orelse 100;
    // "The default maximum is 100 ... if the maximum is less than the
    // minimum, the maximum is the minimum."
    const maximum = if (maximum_given < minimum) minimum else maximum_given;
    // "The default value is the minimum plus half the difference between the
    // minimum and the maximum, unless the maximum is less than the minimum,
    // in which case the default value is the minimum."
    const default_value = if (maximum_given < minimum) minimum else minimum + (maximum - minimum) / 2;
    var number = parseValidFloat(value) orelse default_value;
    if (number < minimum) number = minimum;
    if (number > maximum) number = maximum;
    if (allowedValueStep(instance, .range)) |step| {
        const base = stepBase(instance, .range);
        const steps = (number - base) / step;
        if (steps != @floor(steps)) {
            var snapped = base + @floor(steps + 0.5) * step;
            if (snapped > maximum) snapped = base + @floor((maximum - base) / step) * step;
            if (snapped < minimum) snapped = base + @ceil((minimum - base) / step) * step;
            number = snapped;
        }
    }
    return formatFloat(allocator, number);
}

fn isValidSimpleColor(value: []const u8) bool {
    if (value.len != 7 or value[0] != '#') return false;
    for (value[1..]) |c| {
        if (!std.ascii.isHex(c)) return false;
    }
    return true;
}

// ============================================================================
// Microsyntaxes (§ 2.3.4 numbers, § 2.3.5 dates and times)
// ============================================================================

/// "A string is a valid floating-point number if it consists of: optionally,
/// a U+002D HYPHEN-MINUS character (-); one or both of: a series of one or
/// more ASCII digits, then a U+002E FULL STOP character (.) and a series of
/// one or more ASCII digits; optionally, a U+0065 (e) or U+0045 (E),
/// optionally a U+002D (-) or U+002B (+), and a series of one or more ASCII
/// digits." Its value, when finite.
pub fn parseValidFloat(text: []const u8) ?f64 {
    var i: usize = 0;
    if (i < text.len and text[i] == '-') i += 1;
    const integer_start = i;
    while (i < text.len and std.ascii.isDigit(text[i])) i += 1;
    const has_integer = i > integer_start;
    var has_fraction = false;
    if (i < text.len and text[i] == '.') {
        i += 1;
        const fraction_start = i;
        while (i < text.len and std.ascii.isDigit(text[i])) i += 1;
        if (i == fraction_start) return null;
        has_fraction = true;
    }
    if (!has_integer and !has_fraction) return null;
    if (i < text.len and (text[i] == 'e' or text[i] == 'E')) {
        i += 1;
        if (i < text.len and (text[i] == '-' or text[i] == '+')) i += 1;
        const exponent_start = i;
        while (i < text.len and std.ascii.isDigit(text[i])) i += 1;
        if (i == exponent_start) return null;
    }
    if (i != text.len) return null;
    const number = std.fmt.parseFloat(f64, text) catch return null;
    if (!std.math.isFinite(number)) return null;
    return number;
}

/// "The best representation of the number n as a floating-point number":
/// JavaScript's Number::toString - "1e+21", not the 22 digits `{d}` prints.
fn formatFloat(allocator: std.mem.Allocator, number: f64) ![]u8 {
    var buffer: [32]u8 = undefined;
    return allocator.dupe(u8, reflection.numberToString(&buffer, number));
}

fn parseDigits(text: []const u8) ?u32 {
    if (text.len == 0) return null;
    var n: u32 = 0;
    for (text) |c| {
        if (!std.ascii.isDigit(c)) return null;
        n = std.math.mul(u32, n, 10) catch return null;
        n = std.math.add(u32, n, c - '0') catch return null;
    }
    return n;
}

fn isLeapYear(year: u32) bool {
    return (year % 400 == 0) or (year % 4 == 0 and year % 100 != 0);
}

fn daysInMonth(year: u32, month: u32) u32 {
    return switch (month) {
        1, 3, 5, 7, 8, 10, 12 => 31,
        4, 6, 9, 11 => 30,
        2 => if (isLeapYear(year)) 29 else 28,
        else => 0,
    };
}

const YearMonth = struct { year: u32, month: u32 };

/// "Parse a month component": four or more ASCII digits, a year greater
/// than zero; "-"; two digits, a month 1-12. Returns the rest.
fn parseMonthComponent(text: []const u8) ?struct { value: YearMonth, rest: []const u8 } {
    var i: usize = 0;
    while (i < text.len and std.ascii.isDigit(text[i])) i += 1;
    if (i < 4) return null;
    const year = parseDigits(text[0..i]) orelse return null;
    if (year == 0) return null;
    if (i >= text.len or text[i] != '-') return null;
    if (text.len < i + 3) return null;
    const month_text = text[i + 1 .. i + 3];
    if (!std.ascii.isDigit(month_text[0]) or !std.ascii.isDigit(month_text[1])) return null;
    const month = parseDigits(month_text) orelse return null;
    if (month < 1 or month > 12) return null;
    return .{ .value = .{ .year = year, .month = month }, .rest = text[i + 3 ..] };
}

/// A valid month string: a month component and nothing else.
pub fn parseMonth(text: []const u8) ?YearMonth {
    const parsed = parseMonthComponent(text) orelse return null;
    if (parsed.rest.len != 0) return null;
    return parsed.value;
}

pub const Date = struct { year: u32, month: u32, day: u32 };

fn parseDateComponent(text: []const u8) ?struct { value: Date, rest: []const u8 } {
    const month = parseMonthComponent(text) orelse return null;
    const rest = month.rest;
    if (rest.len < 3 or rest[0] != '-' or !std.ascii.isDigit(rest[1]) or !std.ascii.isDigit(rest[2])) return null;
    const day = parseDigits(rest[1..3]) orelse return null;
    if (day < 1 or day > daysInMonth(month.value.year, month.value.month)) return null;
    return .{ .value = .{ .year = month.value.year, .month = month.value.month, .day = day }, .rest = rest[3..] };
}

/// A valid date string.
pub fn parseDate(text: []const u8) ?Date {
    const parsed = parseDateComponent(text) orelse return null;
    if (parsed.rest.len != 0) return null;
    return parsed.value;
}

/// A time: hours, minutes and milliseconds of the minute.
pub const Time = struct { hour: u32, minute: u32, millisecond: u32 };

/// "Parse a time component": HH ":" MM, optionally ":" SS, optionally "."
/// and one to three digits (a longer fraction is not a valid time string).
fn parseTimeComponent(text: []const u8) ?struct { value: Time, rest: []const u8 } {
    if (text.len < 5 or text[2] != ':') return null;
    if (!std.ascii.isDigit(text[0]) or !std.ascii.isDigit(text[1]) or !std.ascii.isDigit(text[3]) or !std.ascii.isDigit(text[4])) return null;
    const hour = parseDigits(text[0..2]) orelse return null;
    const minute = parseDigits(text[3..5]) orelse return null;
    if (hour > 23 or minute > 59) return null;
    var rest = text[5..];
    var millisecond: u32 = 0;
    if (rest.len > 0 and rest[0] == ':') {
        if (rest.len < 3 or !std.ascii.isDigit(rest[1]) or !std.ascii.isDigit(rest[2])) return null;
        const second = parseDigits(rest[1..3]) orelse return null;
        if (second > 59) return null;
        millisecond = second * 1000;
        rest = rest[3..];
        if (rest.len > 0 and rest[0] == '.') {
            var i: usize = 1;
            while (i < rest.len and std.ascii.isDigit(rest[i])) i += 1;
            const digits = rest[1..i];
            if (digits.len == 0 or digits.len > 3) return null;
            var fraction = parseDigits(digits) orelse return null;
            var scale = digits.len;
            while (scale < 3) : (scale += 1) fraction *= 10;
            millisecond += fraction;
            rest = rest[i..];
        }
    }
    return .{ .value = .{ .hour = hour, .minute = minute, .millisecond = millisecond }, .rest = rest };
}

/// A valid time string.
pub fn parseTime(text: []const u8) ?Time {
    const parsed = parseTimeComponent(text) orelse return null;
    if (parsed.rest.len != 0) return null;
    return parsed.value;
}

pub const LocalDateTime = struct { date: Date, time: Time };

/// A valid local date and time string: a date, "T" or a space, a time.
pub fn parseLocalDateTime(text: []const u8) ?LocalDateTime {
    const date = parseDateComponent(text) orelse return null;
    const rest = date.rest;
    if (rest.len == 0 or (rest[0] != 'T' and rest[0] != ' ')) return null;
    const time = parseTime(rest[1..]) orelse return null;
    return .{ .date = date.value, .time = time };
}

const YearWeek = struct { year: u32, week: u32 };

/// The number of ISO weeks in `year`: 53 when 1 January is a Thursday, or a
/// Wednesday in a leap year.
fn weeksInYear(year: u32) u32 {
    const jan1 = weekdayOf(year, 1, 1); // 0 = Monday
    if (jan1 == 3 or (jan1 == 2 and isLeapYear(year))) return 53;
    return 52;
}

/// A valid week string: four or more digits (a year above zero), "-W", two
/// digits (a week 1 to the year's week count).
pub fn parseWeek(text: []const u8) ?YearWeek {
    var i: usize = 0;
    while (i < text.len and std.ascii.isDigit(text[i])) i += 1;
    if (i < 4) return null;
    const year = parseDigits(text[0..i]) orelse return null;
    if (year == 0) return null;
    const rest = text[i..];
    if (rest.len != 4 or rest[0] != '-' or rest[1] != 'W') return null;
    if (!std.ascii.isDigit(rest[2]) or !std.ascii.isDigit(rest[3])) return null;
    const week = parseDigits(rest[2..4]) orelse return null;
    if (week < 1 or week > weeksInYear(year)) return null;
    return .{ .year = year, .week = week };
}

/// Days from 1970-01-01 to the given proleptic Gregorian date.
fn daysFromCivil(year_given: u32, month: u32, day: u32) i64 {
    // Howard Hinnant's days_from_civil.
    const y: i64 = @as(i64, year_given) - @as(i64, if (month <= 2) 1 else 0);
    const era: i64 = @divFloor(y, 400);
    const yoe: i64 = y - era * 400;
    const m: i64 = month;
    const doy: i64 = @divFloor(153 * (if (m > 2) m - 3 else m + 9) + 2, 5) + @as(i64, day) - 1;
    const doe: i64 = yoe * 365 + @divFloor(yoe, 4) - @divFloor(yoe, 100) + doy;
    return era * 146097 + doe - 719468;
}

/// The date `days` after 1970-01-01.
fn civilFromDays(days: i64) Date {
    const z = days + 719468;
    const era = @divFloor(z, 146097);
    const doe = z - era * 146097;
    const yoe = @divFloor(doe - @divFloor(doe, 1460) + @divFloor(doe, 36524) - @divFloor(doe, 146096), 365);
    const doy = doe - (365 * yoe + @divFloor(yoe, 4) - @divFloor(yoe, 100));
    const mp = @divFloor(5 * doy + 2, 153);
    const d = doy - @divFloor(153 * mp + 2, 5) + 1;
    const m = if (mp < 10) mp + 3 else mp - 9;
    const y = yoe + era * 400 + @as(i64, if (m <= 2) 1 else 0);
    return .{ .year = @intCast(@max(y, 0)), .month = @intCast(m), .day = @intCast(d) };
}

/// Monday = 0 ... Sunday = 6.
fn weekdayOf(year: u32, month: u32, day: u32) u32 {
    const days = daysFromCivil(year, month, day);
    // 1970-01-01 was a Thursday (3).
    return @intCast(@mod(days + 3, 7));
}

const ms_per_day: f64 = 86_400_000;
const ms_per_week: f64 = 604_800_000;

/// "The algorithm to convert a string to a number" of `input_type`, or null
/// (an error).
fn stringToNumber(input_type: InputType, text: []const u8) ?f64 {
    return switch (input_type) {
        .number, .range => parseValidFloat(text),
        // Milliseconds from midnight 1970-01-01 UTC to midnight of the date.
        .date => blk: {
            const d = parseDate(text) orelse break :blk null;
            break :blk @as(f64, @floatFromInt(daysFromCivil(d.year, d.month, d.day))) * ms_per_day;
        },
        // Months from 1970-01.
        .month => blk: {
            const m = parseMonth(text) orelse break :blk null;
            break :blk (@as(f64, @floatFromInt(m.year)) - 1970) * 12 + @as(f64, @floatFromInt(m.month)) - 1;
        },
        // Milliseconds from midnight 1970-01-01 UTC to midnight on the
        // Monday of the week.
        .week => blk: {
            const w = parseWeek(text) orelse break :blk null;
            // The Monday of ISO week 1 is the Monday on or before 4 January.
            const jan4 = daysFromCivil(w.year, 1, 4);
            const monday = jan4 - @as(i64, weekdayOf(w.year, 1, 4));
            break :blk @as(f64, @floatFromInt(monday + (@as(i64, w.week) - 1) * 7)) * ms_per_day;
        },
        // Milliseconds from midnight.
        .time => blk: {
            const t = parseTime(text) orelse break :blk null;
            break :blk @as(f64, @floatFromInt(t.hour * 3_600_000 + t.minute * 60_000 + t.millisecond));
        },
        // Milliseconds from midnight 1970-01-01 to the date and time.
        .@"datetime-local" => blk: {
            const dt = parseLocalDateTime(text) orelse break :blk null;
            const day = @as(f64, @floatFromInt(daysFromCivil(dt.date.year, dt.date.month, dt.date.day))) * ms_per_day;
            break :blk day + @as(f64, @floatFromInt(dt.time.hour * 3_600_000 + dt.time.minute * 60_000 + dt.time.millisecond));
        },
        else => null,
    };
}

/// A time in its shortest valid form: HH:MM, then :SS if the seconds or
/// milliseconds are not zero, then .sss (trailing zeros dropped) if the
/// milliseconds are not.
fn appendTime(out: *std.ArrayListUnmanaged(u8), allocator: std.mem.Allocator, time: Time) !void {
    const seconds = time.millisecond / 1000;
    const millis = time.millisecond % 1000;
    try out.print(allocator, "{d:0>2}:{d:0>2}", .{ time.hour, time.minute });
    if (seconds == 0 and millis == 0) return;
    try out.print(allocator, ":{d:0>2}", .{seconds});
    if (millis == 0) return;
    var buffer: [3]u8 = undefined;
    _ = std.fmt.bufPrint(&buffer, "{d:0>3}", .{millis}) catch return;
    var len: usize = 3;
    while (len > 1 and buffer[len - 1] == '0') len -= 1;
    try out.append(allocator, '.');
    try out.appendSlice(allocator, buffer[0..len]);
}

fn appendDate(out: *std.ArrayListUnmanaged(u8), allocator: std.mem.Allocator, date: Date) !void {
    try out.print(allocator, "{d:0>4}-{d:0>2}-{d:0>2}", .{ date.year, date.month, date.day });
}

/// "A valid normalized local date and time string": the date, "T", and the
/// time in its shortest form.
fn formatLocalDateTime(allocator: std.mem.Allocator, value: LocalDateTime) ![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    try appendDate(&out, allocator, value.date);
    try out.append(allocator, 'T');
    try appendTime(&out, allocator, value.time);
    return out.toOwnedSlice(allocator);
}

/// The largest magnitude of an ECMAScript time value, in milliseconds either
/// side of the epoch (ECMA-262 21.4.1.1, "Time Values and Time Range").
const max_time_value: f64 = 8.64e15;

/// The last date that time range reaches, +275760-09-13.
const max_date: Date = .{ .year = 275760, .month = 9, .day = 13 };

/// Whether a valid date string can represent `date`: its year is "four or
/// more ASCII digits, representing year, where year > 0", and it lies within
/// the time range - HTML leaves the upper limit to the implementation, and
/// this is the one a Date (and Chromium's DateComponents) has.
fn dateRepresentable(date: Date) bool {
    if (date.year < 1) return false;
    if (date.year != max_date.year) return date.year < max_date.year;
    if (date.month != max_date.month) return date.month < max_date.month;
    return date.day <= max_date.day;
}

/// The date `number` milliseconds after 1970-01-01T00:00Z, and the
/// milliseconds into that day - or null when the number is outside the time
/// range or its date has no valid date string. Range-checked as a float first:
/// a number beyond the range of i64 is a safety panic in `@intFromFloat`
/// (input-valueasnumber.html sets 2.7343337071894478e26).
fn dateOfTimeValue(number: f64) ?struct { date: Date, day_ms: i64 } {
    if (!std.math.isFinite(number) or @abs(number) > max_time_value) return null;
    const total: i64 = @intFromFloat(@floor(number));
    const date = civilFromDays(@divFloor(total, 86_400_000));
    if (!dateRepresentable(date)) return null;
    return .{ .date = date, .day_ms = @mod(total, 86_400_000) };
}

/// A time of day from a millisecond count in [0, 86 400 000).
fn timeOfDay(ms: i64) Time {
    return .{
        .hour = @intCast(@divFloor(ms, 3_600_000)),
        .minute = @intCast(@divFloor(@mod(ms, 3_600_000), 60_000)),
        .millisecond = @intCast(@mod(ms, 60_000)),
    };
}

/// "The algorithm to convert a number to a string" of `input_type`. Where no
/// valid string represents the number (a date outside the representable
/// range) the answer is the empty string: the value sanitization algorithm
/// would make any invalid value that, and the valueAsNumber setter then sets
/// the value to it, as browsers do.
fn numberToString(allocator: std.mem.Allocator, input_type: InputType, number: f64) ![]u8 {
    switch (input_type) {
        .number, .range => return formatFloat(allocator, number),
        .date => {
            // "a valid date string that represents the date that, in UTC, is
            // current input milliseconds after midnight UTC on the morning of
            // 1970-01-01".
            const at = dateOfTimeValue(number) orelse return allocator.dupe(u8, "");
            var out: std.ArrayListUnmanaged(u8) = .empty;
            errdefer out.deinit(allocator);
            try appendDate(&out, allocator, at.date);
            return out.toOwnedSlice(allocator);
        },
        .month => {
            // "a valid month string that represents the month that has input
            // months between it and January 1970". Checked as a float, then
            // against the representable years.
            if (!std.math.isFinite(number)) return allocator.dupe(u8, "");
            const months_f = @floor(number);
            const max_months: f64 = @floatFromInt((@as(i64, max_date.year) - 1970) * 12 + max_date.month - 1);
            const min_months: f64 = @floatFromInt((1 - 1970) * 12);
            if (months_f < min_months or months_f > max_months) return allocator.dupe(u8, "");
            const months: i64 = @intFromFloat(months_f);
            const year = 1970 + @divFloor(months, 12);
            const month = @mod(months, 12) + 1;
            return std.fmt.allocPrint(allocator, "{d:0>4}-{d:0>2}", .{ @as(u64, @intCast(year)), @as(u64, @intCast(month)) });
        },
        .week => {
            // "a valid week string that represents the week that, in UTC, is
            // current input milliseconds after midnight UTC on the morning of
            // 1970-01-01".
            const at = dateOfTimeValue(number) orelse return allocator.dupe(u8, "");
            const days = daysFromCivil(at.date.year, at.date.month, at.date.day);
            // The ISO week of the date: the week of its Thursday.
            const weekday: i64 = @mod(days + 3, 7);
            const thursday = civilFromDays(days - weekday + 3);
            if (!dateRepresentable(thursday)) return allocator.dupe(u8, "");
            const jan4 = daysFromCivil(thursday.year, 1, 4);
            const week1_monday = jan4 - @as(i64, weekdayOf(thursday.year, 1, 4));
            const week = @divFloor(days - weekday - week1_monday, 7) + 1;
            return std.fmt.allocPrint(allocator, "{d:0>4}-W{d:0>2}", .{ thursday.year, @as(u64, @intCast(week)) });
        },
        .time => {
            // "a valid time string that represents the time that is input
            // milliseconds after midnight on a day with no time changes": only
            // the number modulo one day matters, however large. Reduced as a
            // float - exact for the integer floor(number) - so it fits a u32.
            if (!std.math.isFinite(number)) return allocator.dupe(u8, "");
            const ms: i64 = @intFromFloat(@mod(@floor(number), ms_per_day));
            var out: std.ArrayListUnmanaged(u8) = .empty;
            errdefer out.deinit(allocator);
            try appendTime(&out, allocator, timeOfDay(ms));
            return out.toOwnedSlice(allocator);
        },
        .@"datetime-local" => {
            // "a valid normalized local date and time string that represents
            // the date and time that is input milliseconds after midnight on
            // the morning of 1970-01-01".
            const at = dateOfTimeValue(number) orelse return allocator.dupe(u8, "");
            return formatLocalDateTime(allocator, .{ .date = at.date, .time = timeOfDay(at.day_ms) });
        },
        else => return allocator.dupe(u8, ""),
    }
}

/// An attribute parsed with the type's string-to-number algorithm, or null.
fn numberAttribute(instance: *runtime.Instance, input_type: InputType, comptime name: []const u8) ?f64 {
    const value = attribute(instance, name) orelse return null;
    defer instance.ctx.allocator.free(value);
    return stringToNumber(input_type, value);
}

/// "The element's minimum": the min attribute, or the Range state's
/// default minimum 0.
fn minimumOf(instance: *runtime.Instance, input_type: InputType) ?f64 {
    if (numberAttribute(instance, input_type, "min")) |m| return m;
    return if (input_type == .range) 0 else null;
}

/// "The element's maximum": the max attribute, or the Range state's default
/// maximum 100 (the minimum when that is greater).
fn maximumOf(instance: *runtime.Instance, input_type: InputType) ?f64 {
    if (numberAttribute(instance, input_type, "max")) |m| return m;
    if (input_type != .range) return null;
    const minimum = minimumOf(instance, input_type) orelse 0;
    return if (100 < minimum) minimum else 100;
}

/// Each state's default step and step scale factor.
fn stepDefaults(input_type: InputType) struct { step: f64, scale: f64 } {
    return switch (input_type) {
        .date => .{ .step = 1, .scale = ms_per_day },
        .month => .{ .step = 1, .scale = 1 },
        .week => .{ .step = 1, .scale = ms_per_week },
        .time, .@"datetime-local" => .{ .step = 60, .scale = 1000 },
        else => .{ .step = 1, .scale = 1 },
    };
}

/// § 4.10.5.3.8 "The allowed value step": the step attribute parsed as a
/// valid floating-point number greater than zero (else the default step),
/// times the step scale factor; null when step is "any".
fn allowedValueStep(instance: *runtime.Instance, input_type: InputType) ?f64 {
    const defaults = stepDefaults(input_type);
    const value = attribute(instance, "step") orelse return defaults.step * defaults.scale;
    defer instance.ctx.allocator.free(value);
    if (std.ascii.eqlIgnoreCase(value, "any")) return null;
    const parsed = parseValidFloat(value) orelse return defaults.step * defaults.scale;
    if (parsed <= 0) return defaults.step * defaults.scale;
    return parsed * defaults.scale;
}

/// "The step base": the min attribute's number, else the value attribute's,
/// else the state's default step base (the Week state's is −259,200,000,
/// the Monday of 1970-W01), else zero.
fn stepBase(instance: *runtime.Instance, input_type: InputType) f64 {
    if (numberAttribute(instance, input_type, "min")) |m| return m;
    if (numberAttribute(instance, input_type, "value")) |v| return v;
    if (input_type == .week) return -259_200_000;
    return 0;
}

fn isIntegral(value: f64) bool {
    return @abs(value - @round(value)) < 1e-9;
}

/// § 4.10.5.4 stepUp(n) / stepDown(n).
fn stepValue(instance: *runtime.Instance, n: i32, comptime up: bool) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const input_type = typeOf(instance);
    // 1. The method does not apply: InvalidStateError.
    if (!input_type.numeric()) return error.InvalidStateError;
    // 2. No allowed value step: InvalidStateError.
    const step = allowedValueStep(instance, input_type) orelse return error.InvalidStateError;
    const minimum = minimumOf(instance, input_type);
    const maximum = maximumOf(instance, input_type);
    const base = stepBase(instance, input_type);
    if (minimum != null and maximum != null) {
        // 3. A minimum greater than the maximum: nothing.
        if (minimum.? > maximum.?) return;
        // 4. No allowed value between them: nothing.
        const first = base + @ceil((minimum.? - base) / step) * step;
        if (first > maximum.?) return;
    }
    // 5. The value as a number, or zero.
    const current = try currentValue(instance);
    defer internal.allocator.free(current);
    var value = stringToNumber(input_type, current) orelse 0;
    // 6.
    const before = value;
    // 7. Off a step: to the nearest step below (stepDown) or above (stepUp).
    const steps = (value - base) / step;
    if (!isIntegral(steps)) {
        value = base + (if (up) @ceil(steps) else @floor(steps)) * step;
    } else {
        // 7.1-7.4: delta = step × n, negated for stepDown.
        const delta = step * @as(f64, @floatFromInt(n));
        value += if (up) delta else -delta;
    }
    // 8. Below the minimum: the smallest step at or above it.
    if (minimum) |min| {
        if (value < min) value = base + @ceil((min - base) / step) * step;
    }
    // 9. Above the maximum: the largest step at or below it.
    if (maximum) |max| {
        if (value > max) value = base + @floor((max - base) / step) * step;
    }
    // 10. Moving the wrong way: nothing.
    if ((!up and value > before) or (up and value < before)) return;
    // 11-12. Set the value to its string.
    const text = try numberToString(internal.allocator, input_type, value);
    defer internal.allocator.free(text);
    try set_value(instance, runtime.DOMString.initInterned(text));
}

/// Operation: stepUp
pub fn call_stepUp(instance: *runtime.Instance, n: webidl.Opt(i32)) anyerror!void {
    try stepValue(instance, n.getOrDefault(1), true);
}

/// Operation: stepDown
pub fn call_stepDown(instance: *runtime.Instance, n: webidl.Opt(i32)) anyerror!void {
    try stepValue(instance, n.getOrDefault(1), false);
}

/// Getter for valueAsNumber: the value converted by the state's
/// string-to-number algorithm, or NaN (also where it does not apply).
pub fn get_valueAsNumber(instance: *runtime.Instance) anyerror!f64 {
    const input_type = typeOf(instance);
    if (!input_type.numeric()) return std.math.nan(f64);
    const internal = getInternal(instance) orelse return std.math.nan(f64);
    const current = try currentValue(instance);
    defer internal.allocator.free(current);
    return stringToNumber(input_type, current) orelse std.math.nan(f64);
}

/// Setter for valueAsNumber: "1. If the given value is infinite, throw a
/// TypeError. 2. If the attribute does not apply, throw an
/// InvalidStateError. 3. If the given value is NaN, set the value to the
/// empty string. 4. Otherwise, set the value to the number converted to a
/// string."
pub fn set_valueAsNumber(instance: *runtime.Instance, value: f64) anyerror!void {
    if (std.math.isInf(value)) return error.TypeError;
    const input_type = typeOf(instance);
    if (!input_type.numeric()) return error.InvalidStateError;
    if (std.math.isNan(value)) return set_value(instance, runtime.DOMString.initEmpty());
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const text = try numberToString(internal.allocator, input_type, value);
    defer internal.allocator.free(text);
    try set_value(instance, runtime.DOMString.initInterned(text));
}

// ============================================================================
// Reflected and derived attributes
// ============================================================================

/// Getter for autocomplete
pub fn get_autocomplete(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#autofill
    //
    // Not a two-value enumeration. "on"/"off" are one branch; the other is an
    // ordered autofill token list, returned verbatim (lowercased) when it forms
    // a valid expansion and "" when it does not:
    //
    //     <input>                                -> ""
    //     <input autocomplete="on">              -> "on"
    //     <input autocomplete="shipping country">-> "shipping country"
    //     <input autocomplete="foobar">          -> ""
    //     <input autocomplete="home country">    -> ""  (country is not a
    //                                                    contact field)
    const value = attribute(instance, "autocomplete") orelse return runtime.DOMString.initEmpty();
    defer instance.ctx.allocator.free(value);
    inline for ([_][]const u8{ "on", "off" }) |candidate| {
        if (std.ascii.eqlIgnoreCase(value, candidate)) {
            return runtime.DOMString.initInterned(candidate);
        }
    }
    const expansion = autofill.parse(value) orelse return runtime.DOMString.initEmpty();
    var buf: [256]u8 = undefined;
    const serialized = autofill.serialize(expansion, &buf) orelse return runtime.DOMString.initEmpty();
    return runtime.DOMString.initDupe(instance.ctx.allocator, serialized) catch return error.OutOfMemory;
}

/// Getter for checked: the element's checkedness.
pub fn get_checked(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    return internal.checkedness;
}

/// Setter for checked: "set the element's checkedness to the new value and
/// set the element's dirty checkedness flag to true".
pub fn set_checked(instance: *runtime.Instance, value: bool) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    internal.dirty_checkedness = true;
    setCheckedness(instance, value);
}

/// Getter for indeterminate
pub fn get_indeterminate(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    return internal.indeterminate;
}

/// Setter for indeterminate
pub fn set_indeterminate(instance: *runtime.Instance, value: bool) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    internal.indeterminate = value;
}

/// Getter for colorSpace
pub fn get_colorSpace(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for form: the element's form owner.
pub fn get_form(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return form_associated.formOwner(instance);
}

/// Getter for files
pub fn get_files(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// A URL attribute with the document URL as its fallback: "on getting, when
/// the content attribute is missing or its value is the empty string, the
/// element's node document's URL must be returned instead."
fn urlAttributeOrDocumentUrl(instance: *runtime.Instance, comptime name: []const u8) anyerror!runtime.USVString {
    if (attribute(instance, name)) |value| {
        defer instance.ctx.allocator.free(value);
        if (value.len > 0) return reflection.get(runtime.USVString, instance, .{ .name = name, .url = true });
    }
    const document = (try interfaces.Node.get_ownerDocument(instance)) orelse return try instance.ctx.allocator.dupe(u8, "");
    return interfaces.Document.get_URL(document);
}

/// Getter for formAction
pub fn get_formAction(instance: *runtime.Instance) anyerror!runtime.USVString {
    return urlAttributeOrDocumentUrl(instance, "formaction");
}

/// An enumerated attribute limited to only known values with no missing
/// value default: its keyword, `invalid` for an unknown value, "" when
/// absent.
fn enumeratedNoMissingDefault(instance: *runtime.Instance, comptime name: []const u8, comptime known: []const []const u8, comptime invalid: []const u8) runtime.DOMString {
    const value = attribute(instance, name) orelse return runtime.DOMString.initEmpty();
    defer instance.ctx.allocator.free(value);
    inline for (known) |candidate| {
        if (std.ascii.eqlIgnoreCase(value, candidate)) return runtime.DOMString.initInterned(candidate);
    }
    return runtime.DOMString.initInterned(invalid);
}

/// Getter for formEnctype: formenctype, limited to only known values; its
/// invalid value default is application/x-www-form-urlencoded, and it has no
/// missing value default.
pub fn get_formEnctype(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return enumeratedNoMissingDefault(instance, "formenctype", &.{ "application/x-www-form-urlencoded", "multipart/form-data", "text/plain" }, "application/x-www-form-urlencoded");
}

/// Getter for formMethod: formmethod, limited to only known values; its
/// invalid value default is GET, and it has no missing value default.
pub fn get_formMethod(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return enumeratedNoMissingDefault(instance, "formmethod", &.{ "get", "post", "dialog" }, "get");
}

/// Setter for formEnctype
pub fn set_formEnctype(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("formenctype"), .{ .domstring = value });
}

/// Setter for formMethod
pub fn set_formMethod(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("formmethod"), .{ .domstring = value });
}

/// Getter for height: the rendered height of an image being rendered, else
/// its natural height, else 0 - nothing is rendered or decoded here.
pub fn get_height(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return 0;
}

/// Getter for width: as height.
pub fn get_width(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return 0;
}

/// Getter for list
pub fn get_list(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for size
pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
    return reflection.get(u32, instance, size_reflection);
}

/// Setter for size
pub fn set_size(instance: *runtime.Instance, value: u32) anyerror!void {
    return reflection.set(u32, instance, size_reflection, value);
}

/// Getter for type: reflects the type attribute, limited to only known
/// values - its state's keyword.
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned(typeOf(instance).keyword());
}

/// Setter for type
pub fn set_type(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // Setting writes the attribute VERBATIM; only the getter canonicalises.
    // `el.type = "NONSENSE"` leaves type="NONSENSE" in the markup while
    // `el.type` reads back "text". The type change steps run from the
    // attribute change.
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("type"), .{ .domstring = value });
}

/// Getter for valueAsDate
pub fn get_valueAsDate(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    return null;
}

/// Setter for valueAsDate
pub fn set_valueAsDate(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Getter for willValidate: a candidate for constraint validation - not
/// barred: not hidden, reset or button; not disabled; not readonly where
/// readonly applies; no datalist ancestor.
pub fn get_willValidate(instance: *runtime.Instance) anyerror!bool {
    const input_type = typeOf(instance);
    switch (input_type) {
        .hidden, .reset, .button => return false,
        else => {},
    }
    if (form_associated.isDisabled(instance)) return false;
    if (!isMutable(instance, input_type)) return false;
    var ancestor = form_associated.parentOf(instance);
    while (ancestor) |a| : (ancestor = form_associated.parentOf(a)) {
        if (form_associated.isElementNamed(a, "datalist")) return false;
    }
    return true;
}

/// Getter for validity
pub fn get_validity(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for validationMessage
pub fn get_validationMessage(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for labels: null in the Hidden state, else the element's labels.
pub fn get_labels(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    if (typeOf(instance) == .hidden) return null;
    return try form_associated.labelsNodeList(instance);
}

/// Getter for capture
pub fn get_capture(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for webkitdirectory
pub fn get_webkitdirectory(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for webkitEntries
pub fn get_webkitEntries(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for popoverTargetElement
pub fn get_popoverTargetElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for popoverTargetAction
pub fn get_popoverTargetAction(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for colorSpace
pub fn set_colorSpace(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for files
pub fn set_files(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for capture
pub fn set_capture(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for webkitdirectory
pub fn set_webkitdirectory(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for popoverTargetElement
pub fn set_popoverTargetElement(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for popoverTargetAction
pub fn set_popoverTargetAction(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: showPicker
pub fn call_showPicker(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setCustomValidity
pub fn call_setCustomValidity(instance: *runtime.Instance, @"error": runtime.DOMString) anyerror!void {
    _ = instance;
    _ = @"error";
    return error.NotImplemented;
}

/// Operation: checkValidity
pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: reportValidity
pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

// ============================================================================
// Text control selections (§ 4.10.20)
// ============================================================================

fn pendingSelectTasks(instance: *runtime.Instance) ?*u32 {
    const internal = getInternal(instance) orelse return null;
    return &internal.pending_select_tasks;
}

/// "Set the selection range", and on a change, queue the select event.
fn setSelectionRange(instance: *runtime.Instance, start: ?u32, end: ?u32, direction: ?[]const u8) void {
    const internal = getInternal(instance) orelse return;
    const length = relevantValueLength(instance);
    if (internal.selection.setRange(start, end, direction, length)) {
        form_associated.queueSelectEvent(instance, &pendingSelectTasks);
    }
}

/// The selection as it reads now.
fn currentSelection(instance: *runtime.Instance) form_associated.TextSelection {
    const internal = getInternal(instance) orelse return .{};
    return internal.selection.clamped(relevantValueLength(instance));
}

/// Getter for selectionStart: null where it does not apply.
pub fn get_selectionStart(instance: *runtime.Instance) anyerror!?u32 {
    if (!typeOf(instance).selectionApplies()) return null;
    return currentSelection(instance).start;
}

/// Getter for selectionEnd: null where it does not apply.
pub fn get_selectionEnd(instance: *runtime.Instance) anyerror!?u32 {
    if (!typeOf(instance).selectionApplies()) return null;
    return currentSelection(instance).end;
}

/// Getter for selectionDirection: null where it does not apply.
pub fn get_selectionDirection(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    if (!typeOf(instance).selectionApplies()) return null;
    return runtime.DOMString.initInterned(currentSelection(instance).direction.keyword());
}

/// Setter for selectionStart: "1. ... throw InvalidStateError where it does
/// not apply. 2. Let end be the value of this element's selectionEnd
/// attribute. 3. If end is less than the given value, set end to the given
/// value. 4. Set the selection range with the given value, end, and the
/// value of this element's selectionDirection attribute." A null start is 0.
pub fn set_selectionStart(instance: *runtime.Instance, value: ?u32) anyerror!void {
    if (!typeOf(instance).selectionApplies()) return error.InvalidStateError;
    const current = currentSelection(instance);
    const start = value orelse 0;
    const end = @max(current.end, start);
    setSelectionRange(instance, start, end, current.direction.keyword());
}

/// Setter for selectionEnd: "Set the selection range with the value of this
/// element's selectionStart attribute, the given value, and the value of
/// this element's selectionDirection attribute."
pub fn set_selectionEnd(instance: *runtime.Instance, value: ?u32) anyerror!void {
    if (!typeOf(instance).selectionApplies()) return error.InvalidStateError;
    const current = currentSelection(instance);
    setSelectionRange(instance, current.start, value, current.direction.keyword());
}

/// Setter for selectionDirection: "Set the selection range with the value of
/// this element's selectionStart attribute, the value of this element's
/// selectionEnd attribute, and the given value."
pub fn set_selectionDirection(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    if (!typeOf(instance).selectionApplies()) return error.InvalidStateError;
    const current = currentSelection(instance);
    setSelectionRange(instance, current.start, current.end, if (value) |v| v.asSlice() else null);
}

/// Operation: select - "1. If this element is an input element, and either
/// select() does not apply to this element or the corresponding control has
/// no selectable text, return. 2. Set the selection range with 0 and
/// infinity."
pub fn call_select(instance: *runtime.Instance) anyerror!void {
    const input_type = typeOf(instance);
    if (!input_type.selectApplies()) return;
    // Only the text-entry states have text to select here: the others are
    // pickers with no text of their own.
    if (!input_type.selectionApplies() and input_type != .email and input_type != .number) return;
    setSelectionRange(instance, 0, std.math.maxInt(u32), null);
}

/// Operation: setSelectionRange
pub fn call_setSelectionRange(instance: *runtime.Instance, start: u32, end: u32, direction: webidl.Opt(runtime.DOMString)) anyerror!void {
    if (!typeOf(instance).selectionApplies()) return error.InvalidStateError;
    setSelectionRange(instance, start, end, if (direction.was_passed) direction.value.asSlice() else null);
}

/// setRangeText() steps 1-14 for both overloads.
fn setRangeText(instance: *runtime.Instance, replacement: []const u8, range: ?[2]u32, mode: ?form_associated.SelectionMode) !void {
    // 1. Where it does not apply: InvalidStateError.
    if (!typeOf(instance).selectionApplies()) return error.InvalidStateError;
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const current = try currentValue(instance);
    defer internal.allocator.free(current);
    // 3-13.
    const result = try form_associated.setRangeText(internal.allocator, current, currentSelection(instance), replacement, range, mode);
    defer internal.allocator.free(result.value);
    // 2. Set the dirty value flag; 9-10 the relevant value changed.
    try internal.setValue(result.value);
    // 14. Set the selection range with selection start and selection end.
    setSelectionRange(instance, result.selection_start, result.selection_end, null);
}

/// Operation: setRangeText(replacement)
pub fn call_setRangeText(instance: *runtime.Instance, replacement: runtime.DOMString) anyerror!void {
    try setRangeText(instance, replacement.asSlice(), null, null);
}

/// Operation: setRangeText(replacement, start, end, selectionMode)
pub fn call_setRangeText__1(instance: *runtime.Instance, replacement: runtime.DOMString, start: u32, end: u32, selectionMode: webidl.Opt(enums.SelectionMode)) anyerror!void {
    try setRangeText(instance, replacement.asSlice(), .{ start, end }, selectionModeOf(selectionMode));
}

/// The SelectionMode argument of setRangeText(replacement, start, end,
/// selectionMode): "preserve" when not given.
fn selectionModeOf(mode: webidl.Opt(enums.SelectionMode)) form_associated.SelectionMode {
    if (!mode.was_passed) return .preserve;
    return switch (mode.value) {
        ._select_ => .select,
        ._start_ => .start,
        ._end_ => .end,
        ._preserve_ => .preserve,
    };
}
