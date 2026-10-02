//! Implementation for DOMTokenList interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-domtokenlist
//! WHATWG DOM Standard §7.1
//!
//! A DOMTokenList represents a set of space-separated tokens. It's used for
//! Element.classList to manage CSS classes.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const infra = @import("infra");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const DOMTokenList = interfaces.DOMTokenList;

pub const State = DOMTokenList.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
    SyntaxError,
    InvalidCharacterError,
};

/// Internal state for DOMTokenList implementation
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The list of tokens
    tokens: infra.List(runtime.DOMString),

    /// Associated element (for attribute updates)
    element: ?*runtime.Instance = null,

    /// Associated attribute name (e.g., "class")
    attr_name: ?runtime.DOMString = null,

    /// Supported tokens (for supports() method)
    supported_tokens: ?[]const []const u8 = null,

    /// The associated attribute's value the token set was last parsed from
    /// (null: the attribute was absent), owned. Meaningful only while
    /// `synced` is true - see `followAttribute`.
    synced_value: ?[]u8 = null,
    synced: bool = false,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .tokens = infra.List(runtime.DOMString).init(allocator),
        };
    }

    pub fn deinit(self: *InternalState) void {
        // Free owned DOMStrings
        const slice = self.tokens.toSliceMut();
        for (slice) |*token| {
            token.deinit(self.allocator);
        }
        self.tokens.deinit();
        if (self.attr_name) |*attr| {
            attr.deinit(self.allocator);
        }
        if (self.synced_value) |v| self.allocator.free(v);
    }
};

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // Code outside this impl associates a list through dom.token_lists.
    @import("dom").token_lists.install(.{ .associate = &associateWithAttribute });
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

    // Initialize internal state
    const state = instance.getState(StateType);
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    state.own._internal = internal;

    // Initialize length to 0
    state.own.length = 0;
    state.own.value = runtime.DOMString.initEmpty();

    return instance;
}

/// `dom.token_lists`' association: make `list` - just created, empty -
/// `element`'s token list for its `local_name` attribute (null namespace), as
/// a reflected DOMTokenList attribute's getter returns it (HTML 2.6.1). DOM's
/// "when a DOMTokenList object is created" steps - run the attribute change
/// steps with the attribute's current value - happen on the list's first
/// read (`followAttribute`); from then on the list updates the attribute.
fn associateWithAttribute(list: *runtime.Instance, element: *runtime.Instance, local_name: []const u8) anyerror!void {
    const internal = getInternal(list) orelse return error.InvalidState;
    const name = try runtime.DOMString.initDupe(internal.allocator, local_name);
    setElement(list, element, name);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();

        // Return the block itself, not just what it points to.
        // `internal.deinit()` releases the strings and lists the state
        // OWNS; without this the state struct stays allocated for the
        // life of the process - measured at 208 bytes per discarded
        // element across the impls still doing it this way.
        const Arena = @import("runtime").ArenaAllocator;
        if (Arena.tryGet() catch null) |arena| arena.destroy(InternalState, internal);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Getter for length
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-length
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return 0;
    try followAttribute(internal);
    return @intCast(internal.tokens.size());
}

/// Getter for value: the serialize steps, "get an attribute value given the
/// element and the attribute name" - the attribute verbatim, "" when absent,
/// not the token set re-serialized (`class="a  b"` reads back "a  b").
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-value
pub fn get_value(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    const allocator = instance.ctx.allocator;
    const element = internal.element orelse {
        // Not associated (never, once created through an element): the set
        // itself is all there is.
        const text = try serialize(internal, allocator);
        return if (text.len == 0) runtime.DOMString.initEmpty() else runtime.DOMString.initOwned(text);
    };
    var value = try interfaces.Element.call_getAttributeNS(element, null, internal.attr_name.?) orelse
        return runtime.DOMString.initEmpty();
    defer value.deinit(element.ctx.allocator);
    return runtime.DOMString.initDupe(allocator, value.asSlice());
}

/// Setter for value: "set an attribute value for the associated element
/// using associated attribute's local name and the given value" - verbatim;
/// the token set follows through the attribute change steps.
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-value
///
/// A list not associated yet (Element's classList and part set their initial
/// value this way before `setElement`) takes the value as its token set.
pub fn set_value(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return;
    const element = internal.element orelse return parseInto(internal, value.asSlice());
    try interfaces.Element.call_setAttributeNS(element, null, internal.attr_name.?, value);
}

/// Operation: item(index)
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-item
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return null;
    try followAttribute(internal);
    // Step 1: "If index is equal to or greater than this's token set's size,
    // then return null."
    if (index >= internal.tokens.size()) return null;
    // Step 2: "Return this's token set[index]" - a copy: the caller frees
    // what it is handed, and the token stays the set's.
    return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.tokens.toSlice()[index].asSlice());
}

/// Operation: contains(token)
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-contains
pub fn call_contains(instance: *runtime.Instance, token: runtime.DOMString) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    try followAttribute(internal);
    return indexOf(internal, token.asSlice()) != null;
}

/// Operation: add(tokens...)
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-add
pub fn call_add(instance: *runtime.Instance, tokens: []const runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return;
    try followAttribute(internal);
    // Step 1: every token is validated before any is added.
    for (tokens) |token| try validateToken(token.asSlice());
    // Step 2: append each to the set.
    for (tokens) |token| try appendToken(internal, token.asSlice());
    // Step 3.
    try runUpdateSteps(internal);
}

/// Operation: remove(tokens...)
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-remove
pub fn call_remove(instance: *runtime.Instance, tokens: []const runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return;
    try followAttribute(internal);
    // Step 1: every token is validated before any is removed.
    for (tokens) |token| try validateToken(token.asSlice());
    // Step 2: remove each from the set.
    for (tokens) |token| removeToken(internal, token.asSlice());
    // Step 3.
    try runUpdateSteps(internal);
}

/// Operation: toggle(token, force?)
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-toggle
pub fn call_toggle(instance: *runtime.Instance, token: runtime.DOMString, force: webidl.Opt(bool)) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    try followAttribute(internal);
    // Steps 1-2, whatever the set holds.
    try validateToken(token.asSlice());
    // Step 3.
    if (indexOf(internal, token.asSlice()) != null) {
        // 3.1: "If force is either not given or is false, then remove token,
        // run the update steps and return false."
        if (!force.was_passed or !force.value) {
            removeToken(internal, token.asSlice());
            try runUpdateSteps(internal);
            return false;
        }
        // 3.2 - with no update steps, for web compatibility.
        return true;
    }
    // Step 4.
    if (!force.was_passed or force.value) {
        try appendToken(internal, token.asSlice());
        try runUpdateSteps(internal);
        return true;
    }
    // Step 5.
    return false;
}

/// Operation: replace(token, newToken)
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-replace
pub fn call_replace(instance: *runtime.Instance, token: runtime.DOMString, newToken: runtime.DOMString) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    try followAttribute(internal);
    const old = token.asSlice();
    const new = newToken.asSlice();
    // Steps 1-2.
    if (old.len == 0 or new.len == 0) return error.SyntaxError;
    try validateToken(old);
    try validateToken(new);
    // Step 3.
    if (indexOf(internal, old) == null) return false;
    // Step 4: Infra "replace" in an ordered set - the first of token and
    // newToken becomes newToken, and every other instance of either goes.
    const first = @min(indexOf(internal, old) orelse std.math.maxInt(usize), indexOf(internal, new) orelse std.math.maxInt(usize));
    const slice = internal.tokens.toSliceMut();
    if (!std.mem.eql(u8, slice[first].asSlice(), new)) {
        const replacement = try runtime.DOMString.initDupe(internal.allocator, new);
        slice[first].deinit(internal.allocator);
        slice[first] = replacement;
    }
    var i: usize = first + 1;
    while (i < internal.tokens.size()) {
        const t = internal.tokens.toSlice()[i].asSlice();
        if (std.mem.eql(u8, t, old) or std.mem.eql(u8, t, new)) {
            var removed = try internal.tokens.remove(i);
            removed.deinit(internal.allocator);
        } else i += 1;
    }
    // Step 5.
    try runUpdateSteps(internal);
    // Step 6.
    return true;
}

/// Operation: supports(token)
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-supports
pub fn call_supports(instance: *runtime.Instance, token: runtime.DOMString) anyerror!bool {
    const internal = getInternal(instance) orelse return false;

    // Check if supported tokens are defined
    if (internal.supported_tokens) |supported| {
        const token_slice = token.asSlice();
        for (supported) |s| {
            if (std.ascii.eqlIgnoreCase(s, token_slice)) {
                return true;
            }
        }
        return false;
    }

    // No supported tokens defined - throw TypeError
    return error.NotImplemented;
}

/// Operation: forEach(callback)
/// Spec: https://webidl.spec.whatwg.org/#es-forEach
pub fn call_forEach(instance: *runtime.Instance, callback: runtime.JSValue) anyerror!void {
    const internal = getInternal(instance) orelse return;
    _ = callback;

    // forEach requires JS callback invocation
    const tokens = internal.tokens.toSlice();
    for (tokens) |_| {
        // TODO: Invoke callback(token, index, this) via V8
    }
}

// ============================================================================
// Internal helper functions
// ============================================================================

/// The token set follows the associated attribute: DOM's attribute change
/// steps for a DOMTokenList - "If localName is set's attribute name,
/// namespace is null, and value is null, then empty token set. Otherwise, if
/// localName is set's attribute name and namespace is null, then set set's
/// token set to value, parsed" - run LAZILY, when the set is next read,
/// rather than on every attribute change.
///
/// Observably the same: the token set is visible only through this list, and
/// it always equals the parse of the value it was last synced to, because
/// every change the list makes to the set runs the update steps, which write
/// the attribute (and record that value here). So comparing the attribute's
/// current value with the last one parsed says exactly whether the change
/// steps would have run. Eager steps would need the list registered against
/// its element - any element in any namespace, for classList and part - and
/// a list routinely outlives its element (script keeps `el.classList` and
/// drops `el`), which is the recycled-address hazard of a registry keyed on
/// the element (docs/lessons/architecture-a-stale-weak-callback-s-registry-remove-evicts.md).
fn followAttribute(internal: *InternalState) !void {
    const element = internal.element orelse return;
    const name = internal.attr_name orelse return;
    var current = try interfaces.Element.call_getAttributeNS(element, null, name);
    defer if (current) |*c| c.deinit(element.ctx.allocator);
    const value: ?[]const u8 = if (current) |c| c.asSlice() else null;
    if (internal.synced and optionalEql(internal.synced_value, value)) return;
    // Step 1 (null empties the set) and step 2 (a value is parsed).
    try parseInto(internal, value orelse "");
    try recordSynced(internal, value);
}

fn optionalEql(a: ?[]const u8, b: ?[]const u8) bool {
    if (a == null or b == null) return a == null and b == null;
    return std.mem.eql(u8, a.?, b.?);
}

fn recordSynced(internal: *InternalState, value: ?[]const u8) !void {
    const copy: ?[]u8 = if (value) |v| try internal.allocator.dupe(u8, v) else null;
    if (internal.synced_value) |old| internal.allocator.free(old);
    internal.synced_value = copy;
    internal.synced = true;
}

/// The token set becomes `value`, run through Infra's ordered set parser:
/// split on ASCII whitespace, each token once, in first-seen order.
fn parseInto(internal: *InternalState, value: []const u8) !void {
    for (internal.tokens.toSliceMut()) |*token| token.deinit(internal.allocator);
    internal.tokens.clear();
    var it = std.mem.tokenizeAny(u8, value, ascii_whitespace);
    while (it.next()) |token| try appendToken(internal, token);
}

/// Infra's ASCII whitespace.
const ascii_whitespace = " \t\n\r\x0c";

/// Steps 1-2 of add, remove, toggle and replace for one token.
fn validateToken(token: []const u8) !void {
    if (token.len == 0) return error.SyntaxError;
    if (std.mem.indexOfAny(u8, token, ascii_whitespace) != null) return error.InvalidCharacterError;
}

fn indexOf(internal: *InternalState, token: []const u8) ?usize {
    for (internal.tokens.toSlice(), 0..) |t, i| {
        if (std.mem.eql(u8, t.asSlice(), token)) return i;
    }
    return null;
}

/// Infra "append" to an ordered set: nothing if it is already there.
fn appendToken(internal: *InternalState, token: []const u8) !void {
    if (indexOf(internal, token) != null) return;
    const owned = try runtime.DOMString.initDupe(internal.allocator, token);
    errdefer {
        var o = owned;
        o.deinit(internal.allocator);
    }
    try internal.tokens.append(owned);
}

fn removeToken(internal: *InternalState, token: []const u8) void {
    const i = indexOf(internal, token) orelse return;
    var removed = internal.tokens.remove(i) catch return;
    removed.deinit(internal.allocator);
}

/// The ordered set serializer: the tokens joined by single spaces.
fn serialize(internal: *InternalState, allocator: std.mem.Allocator) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    for (internal.tokens.toSlice(), 0..) |token, i| {
        if (i > 0) try out.append(allocator, ' ');
        try out.appendSlice(allocator, token.asSlice());
    }
    return out.toOwnedSlice(allocator);
}

/// The update steps.
/// Spec: https://dom.spec.whatwg.org/#concept-dtl-update
fn runUpdateSteps(internal: *InternalState) !void {
    const element = internal.element orelse return;
    const name = internal.attr_name orelse return;
    // Step 1: "If get an attribute by namespace and local name given null,
    // set's attribute name, and set's element returns null and set's token
    // set is empty, then return." - remove() on an element with no class
    // attribute does not create one.
    if (internal.tokens.size() == 0) {
        if (!try interfaces.Element.call_hasAttributeNS(element, null, name)) return;
    }
    // Step 2: "Set an attribute value given set's element, set's attribute
    // name, and the result of running the ordered set serializer for set's
    // token set."
    const text = try serialize(internal, internal.allocator);
    defer internal.allocator.free(text);
    try interfaces.Element.call_setAttributeNS(element, null, name, runtime.DOMString.initInterned(text));
    // The change steps parse that value back into this same set; record it
    // rather than re-parse it on the next read.
    try recordSynced(internal, text);
}

/// Set supported tokens for supports() method
pub fn setSupportedTokens(instance: *runtime.Instance, tokens: []const []const u8) void {
    const internal = getInternal(instance) orelse return;
    internal.supported_tokens = tokens;
}

/// Set the associated element and attribute
pub fn setElement(instance: *runtime.Instance, element: ?*runtime.Instance, attr_name: ?runtime.DOMString) void {
    const internal = getInternal(instance) orelse return;
    internal.element = element;
    internal.attr_name = attr_name;
    // The set follows this element's attribute from its next read on.
    internal.synced = false;
}
