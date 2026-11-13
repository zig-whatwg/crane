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
const dom = @import("dom");
const attribute_values = dom.attribute_values;
const DOMTokenList = interfaces.DOMTokenList;

pub const State = DOMTokenList.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
    SyntaxError,
    InvalidCharacterError,
};

/// Internal state for DOMTokenList implementation.
///
/// The token set is not stored: DOM's attribute change steps set it to the
/// associated attribute's value, parsed, whenever the attribute changes, so
/// it is always the current value's ordered set - which the value's record
/// keeps, split once per distinct value (dom.attribute_values.ClassNames,
/// lane nd2 batch 3; Blink's DOMTokenList reads the same SpaceSplitString
/// its element's class names are). A read takes the attribute's value id
/// and reads its token list; a change serializes the new set and sets the
/// attribute, whose change steps are the only update.
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// Associated element (for attribute updates)
    element: ?*runtime.Instance = null,

    /// Associated attribute name (e.g., "class")
    attr_name: ?runtime.DOMString = null,

    /// Supported tokens (for supports() method)
    supported_tokens: ?[]const []const u8 = null,

    /// A list not associated with an element (Element's getters set a
    /// list's value before associating it): its value, a counted record of
    /// its Browser's attribute values, whose tokens are its set.
    own_value: attribute_values.ValueId = .empty,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *InternalState, scope: *runtime.BrowserScope) void {
        if (self.attr_name) |*attr| {
            attr.deinit(self.allocator);
        }
        attribute_values.release(scope, self.own_value);
        self.own_value = .empty;
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
    dom.token_lists.install(.{ .associate = &associateWithAttribute });
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
    const internal = try runtime.arenaOf(instance).create(InternalState);
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
/// steps with the attribute's current value - need nothing here: every read
/// takes the attribute's current value's tokens (`TokenSet`), and every
/// change sets the attribute.
fn associateWithAttribute(list: *runtime.Instance, element: *runtime.Instance, local_name: []const u8) anyerror!void {
    const internal = getInternal(list) orelse return error.InvalidState;
    const name = try runtime.DOMString.initDupe(internal.allocator, local_name);
    setElement(list, element, name);
    // HTML 2.5.8: the blocking attribute's supported tokens are the possible
    // blocking tokens. DOM validation ASCII-lowercases its input.
    if (std.mem.eql(u8, local_name, "blocking") and
        (element.stateAs(interfaces.HTMLScriptElement.State) != null or
            element.stateAs(interfaces.HTMLLinkElement.State) != null or
            element.stateAs(interfaces.HTMLStyleElement.State) != null))
    {
        internal.supported_tokens = &.{"render"};
    } else if (std.mem.eql(u8, local_name, "rel") and element.stateAs(interfaces.HTMLLinkElement.State) != null) {
        // HTML link types this engine fetches. Other supported rel tokens
        // are a separate link-type feature, not implied by token syntax.
        internal.supported_tokens = &.{ "stylesheet", "preload", "modulepreload", "prefetch" };
    }
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(runtime.BrowserScope.ofInstance(instance));

        // Return the block itself, not just what it points to.
        // `internal.deinit()` releases the strings and lists the state
        // OWNS; without this the state struct stays allocated for the
        // life of the process - measured at 208 bytes per discarded
        // element across the impls still doing it this way.
        runtime.arenaOf(instance).destroy(InternalState, internal);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Getter for length
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-length
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return 0;
    var set: TokenSet = .{};
    try set.read(internal, instance);
    return @intCast(set.ids.len);
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
        var set: TokenSet = .{};
        try set.read(internal, instance);
        var buffer: [256]u8 = undefined;
        var scratch: std.heap.BufferFirstAllocator = .init(&buffer, allocator);
        var tokens = try set.slices(scratch.allocator());
        defer tokens.deinit(scratch.allocator());
        const text = try serialize(allocator, tokens.items);
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
/// value this way before `setElement`) takes the value as its own.
pub fn set_value(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return;
    const element = internal.element orelse return setOwnValue(internal, instance, value.asSlice());
    try interfaces.Element.call_setAttributeNS(element, null, internal.attr_name.?, .{ .domstring = value });
}

/// Operation: item(index)
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-item
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return null;
    var set: TokenSet = .{};
    try set.read(internal, instance);
    // Step 1: "If index is equal to or greater than this's token set's size,
    // then return null."
    if (index >= set.ids.len) return null;
    // Step 2: "Return this's token set[index]" - a copy: the caller frees
    // what it is handed, and the token stays its record's.
    return try runtime.DOMString.initDupe(instance.ctx.allocator, set.bytesAt(index));
}

/// Operation: contains(token)
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-contains
pub fn call_contains(instance: *runtime.Instance, token: runtime.DOMString) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    var set: TokenSet = .{};
    try set.read(internal, instance);
    return set.indexOf(token.asSlice()) != null;
}

/// Operation: add(tokens...)
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-add
pub fn call_add(instance: *runtime.Instance, tokens: []const runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return;
    // Step 1: every token is validated before any is added.
    for (tokens) |token| try validateToken(token.asSlice());
    var edit: Edit = undefined;
    try edit.begin(internal, instance);
    defer edit.end();
    // Step 2: append each to the set.
    for (tokens) |token| try edit.append(token.asSlice());
    // Step 3.
    try edit.runUpdateSteps();
}

/// Operation: remove(tokens...)
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-remove
pub fn call_remove(instance: *runtime.Instance, tokens: []const runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return;
    // Step 1: every token is validated before any is removed.
    for (tokens) |token| try validateToken(token.asSlice());
    var edit: Edit = undefined;
    try edit.begin(internal, instance);
    defer edit.end();
    // Step 2: remove each from the set.
    for (tokens) |token| edit.remove(token.asSlice());
    // Step 3.
    try edit.runUpdateSteps();
}

/// Operation: toggle(token, force?)
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-toggle
pub fn call_toggle(instance: *runtime.Instance, token: runtime.DOMString, force: webidl.Opt(bool)) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    // Steps 1-2, whatever the set holds.
    try validateToken(token.asSlice());
    var edit: Edit = undefined;
    try edit.begin(internal, instance);
    defer edit.end();
    // Step 3.
    if (edit.indexOf(token.asSlice()) != null) {
        // 3.1: "If force is either not given or is false, then remove token,
        // run the update steps and return false."
        if (!force.was_passed or !force.value) {
            edit.remove(token.asSlice());
            try edit.runUpdateSteps();
            return false;
        }
        // 3.2 - with no update steps, for web compatibility.
        return true;
    }
    // Step 4.
    if (!force.was_passed or force.value) {
        try edit.append(token.asSlice());
        try edit.runUpdateSteps();
        return true;
    }
    // Step 5.
    return false;
}

/// Operation: replace(token, newToken)
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-replace
pub fn call_replace(instance: *runtime.Instance, token: runtime.DOMString, newToken: runtime.DOMString) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    const old = token.asSlice();
    const new = newToken.asSlice();
    // Steps 1-2.
    if (old.len == 0 or new.len == 0) return error.SyntaxError;
    try validateToken(old);
    try validateToken(new);
    var edit: Edit = undefined;
    try edit.begin(internal, instance);
    defer edit.end();
    // Step 3.
    const at_old = edit.indexOf(old) orelse return false;
    // Step 4: Infra "replace" in an ordered set - the first of token and
    // newToken becomes newToken, and every other instance of either goes.
    const first = @min(at_old, edit.indexOf(new) orelse std.math.maxInt(usize));
    edit.tokens.items[first] = new;
    var i: usize = first + 1;
    while (i < edit.tokens.items.len) {
        const t = edit.tokens.items[i];
        if (std.mem.eql(u8, t, old) or std.mem.eql(u8, t, new)) {
            _ = edit.tokens.orderedRemove(i);
        } else i += 1;
    }
    // Step 5.
    try edit.runUpdateSteps();
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
    return error.TypeError;
}

// ============================================================================
// Internal helper functions
// ============================================================================

/// The token set as it is now: the ordered set parser over the associated
/// attribute's value - DOM's attribute change steps: "If localName is set's
/// attribute name, namespace is null, and value is null, then empty token
/// set. Otherwise, if localName is set's attribute name and namespace is
/// null, then set set's token set to value, parsed" - read from the value
/// record's token list (lane nd2 batch 3), or from the list's own value
/// while it has no element. Borrowed: valid until the attribute (or the own
/// value) next changes - read it all before setting the attribute.
const TokenSet = struct {
    table: ?*attribute_values.Table = null,
    ids: []const attribute_values.ValueId = &.{},
    /// A one-token value is its own token.
    one: [1]attribute_values.ValueId = undefined,

    /// Read in place: `ids` may point into this TokenSet.
    fn read(self: *TokenSet, internal: *InternalState, instance: *runtime.Instance) !void {
        self.* = .{};
        var value: attribute_values.ValueId = internal.own_value;
        var scope: *runtime.BrowserScope = undefined;
        if (internal.element) |element| {
            const data = dom.element_data.of(element) orelse return;
            const name = (internal.attr_name orelse return).asSlice();
            // The class attribute through its header index (lane nd2 N3).
            value = if (std.mem.eql(u8, name, "class")) data.classId() else (data.findValueId(null, name) orelse .empty);
            scope = data.scope;
        } else {
            scope = runtime.BrowserScope.ofInstance(instance);
        }
        if (value == .empty) return;
        const table = attribute_values.classTable(scope) orelse return;
        self.table = table;
        if (value.isOneToken()) {
            self.one[0] = value;
            self.ids = &self.one;
        } else {
            self.ids = (try table.classNames(value)).tokens();
        }
    }

    fn bytesAt(self: *const TokenSet, index: usize) []const u8 {
        return self.table.?.bytesOf(self.ids[index]);
    }

    fn indexOf(self: *const TokenSet, token: []const u8) ?usize {
        for (0..self.ids.len) |i| {
            if (std.mem.eql(u8, self.bytesAt(i), token)) return i;
        }
        return null;
    }

    /// The tokens' bytes, in order, borrowed from their records.
    fn slices(self: *const TokenSet, allocator: std.mem.Allocator) !std.ArrayListUnmanaged([]const u8) {
        var list: std.ArrayListUnmanaged([]const u8) = .empty;
        errdefer list.deinit(allocator);
        try list.ensureTotalCapacity(allocator, self.ids.len);
        for (0..self.ids.len) |i| list.appendAssumeCapacity(self.bytesAt(i));
        return list;
    }
};

/// A change to the token set: its tokens' bytes, borrowed from their records
/// (which nothing frees before `runUpdateSteps` sets the attribute), edited
/// as Infra's ordered set, then serialized into the attribute.
const Edit = struct {
    internal: *InternalState,
    instance: *runtime.Instance,
    buffer: [16 * @sizeOf([]const u8)]u8,
    scratch: std.heap.BufferFirstAllocator,
    tokens: std.ArrayListUnmanaged([]const u8),

    /// In place: `scratch` points into `buffer`.
    fn begin(self: *Edit, internal: *InternalState, instance: *runtime.Instance) !void {
        self.internal = internal;
        self.instance = instance;
        self.scratch = .init(&self.buffer, internal.allocator);
        var set: TokenSet = .{};
        try set.read(internal, instance);
        self.tokens = try set.slices(self.scratch.allocator());
    }

    fn end(self: *Edit) void {
        self.tokens.deinit(self.scratch.allocator());
    }

    fn indexOf(self: *const Edit, token: []const u8) ?usize {
        for (self.tokens.items, 0..) |t, i| {
            if (std.mem.eql(u8, t, token)) return i;
        }
        return null;
    }

    /// Infra "append" to an ordered set: nothing if it is already there.
    /// The token is the caller's, alive for the call.
    fn append(self: *Edit, token: []const u8) !void {
        if (self.indexOf(token) != null) return;
        try self.tokens.append(self.scratch.allocator(), token);
    }

    fn remove(self: *Edit, token: []const u8) void {
        const i = self.indexOf(token) orelse return;
        _ = self.tokens.orderedRemove(i);
    }

    /// The update steps.
    /// Spec: https://dom.spec.whatwg.org/#concept-dtl-update
    fn runUpdateSteps(self: *Edit) !void {
        const internal = self.internal;
        var buffer: [256]u8 = undefined;
        var scratch: std.heap.BufferFirstAllocator = .init(&buffer, internal.allocator);
        // Step 2's serializer, first: the tokens are borrowed from the
        // value's records, which setting the attribute may free.
        const text = try serialize(scratch.allocator(), self.tokens.items);
        defer scratch.allocator().free(text);
        const element = internal.element orelse return setOwnValue(internal, self.instance, text);
        const name = internal.attr_name orelse return;
        // Step 1: "If get an attribute by namespace and local name given
        // null, set's attribute name, and set's element returns null and
        // set's token set is empty, then return." - remove() on an element
        // with no class attribute does not create one.
        if (self.tokens.items.len == 0) {
            if (!try interfaces.Element.call_hasAttributeNS(element, null, name)) return;
        }
        // Step 2: "Set an attribute value given set's element, set's
        // attribute name, and the result of running the ordered set
        // serializer for set's token set."
        try interfaces.Element.call_setAttributeNS(element, null, name, .{ .domstring = runtime.DOMString.initInterned(text) });
    }
};

/// A list with no element takes `value` as its own (its set is `value`,
/// parsed).
fn setOwnValue(internal: *InternalState, instance: *runtime.Instance, value: []const u8) !void {
    const scope = runtime.BrowserScope.ofInstance(instance);
    const id = try attribute_values.intern(scope, value);
    attribute_values.release(scope, internal.own_value);
    internal.own_value = id;
}

/// Infra's ASCII whitespace.
const ascii_whitespace = " \t\n\r\x0c";

/// Steps 1-2 of add, remove, toggle and replace for one token.
fn validateToken(token: []const u8) !void {
    if (token.len == 0) return error.SyntaxError;
    if (std.mem.indexOfAny(u8, token, ascii_whitespace) != null) return error.InvalidCharacterError;
}

/// The ordered set serializer: the tokens joined by single spaces.
fn serialize(allocator: std.mem.Allocator, tokens: []const []const u8) ![]u8 {
    var len: usize = 0;
    for (tokens, 0..) |token, i| len += token.len + @intFromBool(i > 0);
    const out = try allocator.alloc(u8, len);
    var at: usize = 0;
    for (tokens, 0..) |token, i| {
        if (i > 0) {
            out[at] = ' ';
            at += 1;
        }
        @memcpy(out[at..][0..token.len], token);
        at += token.len;
    }
    return out;
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
    // The set is the element's attribute's from now on.
    if (element != null) {
        attribute_values.release(runtime.BrowserScope.ofInstance(instance), internal.own_value);
        internal.own_value = .empty;
    }
}
