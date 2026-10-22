//! Implementation for ProcessingInstruction interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-processinginstruction
//! WHATWG DOM Standard §4.13
//!
//! ProcessingInstruction nodes represent processing instructions in XML.
//! They extend CharacterData and have an associated target.
//! Node type is PROCESSING_INSTRUCTION_NODE (7).
//!
//! Migrated from: webidl/src/dom/ProcessingInstruction.zig

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const ProcessingInstruction = interfaces.ProcessingInstruction;
const dom = @import("dom");
const engine = @import("engine");
const Attributes = dom.pi_attributes.Attributes;
const style_sheet_loading = @import("html").style_sheet_loading;

const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;

pub const State = ProcessingInstruction.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

/// Internal state for ProcessingInstruction implementation
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The target of this processing instruction (e.g., "xml-stylesheet")
    target: []const u8,
    // The logical map starts empty/stale. Allocate and parse only on API use:
    // parsing a page containing PIs alone must not allocate attribute maps.
    attributes: ?*Attributes = null,
    attributes_stale: bool = true,
    attributes_already_updated: bool = false,
    sheet: ?*dom.style.SheetRecord = null,
    sheet_document: ?*runtime.Instance = null,
    sheet_document_generation: u64 = 0,
    load: u64 = 0,
    in_prolog: bool = false,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .target = "",
        };
    }

    pub fn deinit(self: *InternalState, instance: *runtime.Instance) void {
        style_sheet_loading.elementGone(instance);
        self.load = 0;
        removeSheet(instance, self);
        if (self.target.len > 0) self.allocator.free(self.target);
        self.target = "";
        if (self.attributes) |attributes| {
            attributes.deinit();
            self.allocator.destroy(attributes);
            self.attributes = null;
        }
    }
};

/// The ProcessingInstructions alive, for the final teardown's sweep.
///
/// A PI still alive when the browser ends is never deinit'd one by one:
/// the teardown sweeps free the node registries wholesale (dom.teardown_sweeps), and its
/// target - the PI's own, outside those registries - then leaked (17 over
/// dom/ranges/Range-surroundContents.html, the PIs in subtrees nothing tore
/// down). So the PI keeps its own list, taken on init and given up on deinit,
/// and installs a sweep (dom.teardown_sweeps) that frees what is left in it.
/// Keyed by address: the entry goes in the PI's deinit, before the slab can
/// reissue the address.
threadlocal var live: ?std.AutoHashMap(*runtime.Instance, void) = null;
threadlocal var live_guard: @import("webidl").utils.tombstones.TombstoneGuard = .{};

fn trackLive(instance: *runtime.Instance) void {
    if (live == null) live = .init(std.heap.c_allocator);
    const map = &live.?;
    live_guard.beforeInsert(map);
    map.put(instance, {}) catch {};
}

fn untrackLive(instance: *runtime.Instance) void {
    const map = if (live) |*m| m else return;
    if (map.remove(instance)) live_guard.noteRemoval(map);
}

/// dom.teardown_sweeps: free the state of every PI of `scope`'s Browser
/// still alive (the thread's set holds only its Browser's: a Browser's PIs
/// are made on its window thread).
fn sweepLive(scope: *runtime.BrowserScope) void {
    const map = if (live) |*m| m else return;
    var it = map.keyIterator();
    while (it.next()) |instance| {
        if (runtime.BrowserScope.ofInstance(instance.*) != scope) continue;
        if (getInternal(instance.*)) |internal| {
            internal.deinit(instance.*);
            internal.target = "";
        }
    }
    map.deinit();
    live = null;
    live_guard.reset();
}

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    dom.teardown_sweeps.install(.element_types, &sweepLive);
    dom.character_data.installProcessingInstruction(.{ .data_changed = &dataChanged });
    dom.style.hooks.install(.{ .pi_sheet_of = &sheetOf, .pi_sheet_arrived = &sheetArrived });
    dom.mutation.registerChildrenChangedCallback(&documentChildrenChanged) catch {};
    dom.mutation.registerRemovingStepsCallback(&removingSteps) catch {};
}

/// Replace-data step 12. Consume the already-updated argument before step 13
/// can run children-changed steps and reenter script with a different change.
fn dataChanged(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    defer updateStyleSheet(instance);
    if (internal.attributes_already_updated) {
        internal.attributes_already_updated = false;
        return;
    }
    // DOM initialize step 5 / update-attributes-from-data steps 1-4, delayed
    // until an attribute member observes the map. Blink likewise uses
    // ProcessingInstruction::ProcessAttributesIfNeeded (core/dom/processing_instruction.cc).
    internal.attributes_stale = true;
}

pub const construction_args = .{"target"};

/// ProcessingInstruction's own construction steps: the generated chain runs CharacterData's first.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    // Initialize ProcessingInstruction internal state
    const state = instance.getState(State);
    const internal = try runtime.arenaOf(instance).create(InternalState);
    errdefer runtime.arenaOf(instance).destroy(InternalState, internal);
    internal.* = InternalState.init(allocator);
    if (@hasField(@TypeOf(args), "target")) {
        internal.target = try allocator.dupe(u8, args.target);
    }
    state.own._internal = internal;
    trackLive(instance);
}

/// ProcessingInstruction's own teardown: the generated chain runs CharacterData's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    untrackLive(instance);
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(instance);

        // Return the block itself, not just what it points to.
        // `internal.deinit()` releases the strings and lists the state
        // OWNS; without this the state struct stays allocated for the
        // life of the process - measured at 208 bytes per discarded
        // element across the impls still doing it this way.
        runtime.arenaOf(instance).destroy(InternalState, internal);
        state.own._internal = null;
    }
}

// =============================================================================
// Getters - DOM §4.13
// =============================================================================

/// Getter for target
/// DOM §4.13 - Returns this's target.
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_target(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.target);
}

/// Getter for sheet (from LinkStyle mixin - CSSOM)
/// Returns the associated stylesheet, if any
pub fn get_sheet(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const record = sheetOf(instance) orelse return null;
    return try dom.style.objects.sheetObject(record, instance.ctx);
}

/// CSSOM 6.3.4: the prolog is the Document's children before its element.
/// Reconsider membership when a document child moves, including when an
/// element moves past an existing PI. Ordinary element mutations return here.
fn documentChildrenChanged(parent: *dom.NodeBase, _: dom.mutation.ChildrenChange) void {
    if (parent.node_type != dom.NodeBase.DOCUMENT_NODE) return;
    var in_prolog = true;
    for (parent.child_nodes.items()) |child| {
        if (child.node_type == dom.NodeBase.ELEMENT_NODE) in_prolog = false;
        if (child.node_type != dom.NodeBase.PROCESSING_INSTRUCTION_NODE) continue;
        const raw = dom.instance_bridge.getInstance(child) orelse continue;
        const instance: *runtime.Instance = @ptrCast(@alignCast(raw));
        const internal = getInternal(instance) orelse continue;
        if (internal.in_prolog == in_prolog) continue;
        internal.in_prolog = in_prolog;
        updateStyleSheet(instance);
    }
}

fn removingSteps(node: *dom.NodeBase, _: ?*dom.NodeBase) void {
    if (node.node_type != dom.NodeBase.PROCESSING_INSTRUCTION_NODE) return;
    const raw = dom.instance_bridge.getInstance(node) orelse return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(raw));
    const internal = getInternal(instance) orelse return;
    internal.in_prolog = false;
    updateStyleSheet(instance);
}

/// CSSOM 6.3.4 steps 1-14. The existing stylesheet loader owns fetching,
/// imports, cancellation, load-event delay and the owner's execution hold.
fn updateStyleSheet(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    const previous_load = internal.load;
    internal.load = 0;
    defer if (previous_load != 0) style_sheet_loading.cancel(previous_load);
    removeSheet(instance, internal);
    if (!internal.in_prolog or !std.mem.eql(u8, internal.target, "xml-stylesheet")) return;
    const document = (interfaces.Node.get_ownerDocument(instance) catch null) orelse return;
    if ((interfaces.Document.get_defaultView(document) catch null) == null) return;
    // CSSOM reads the serialized PI data using XML Stylesheet's grammar.
    // DOM's attribute map can retain names set through its more permissive
    // IDL API, so it is not a substitute for this strict parse.
    var attributes = Attributes.init(internal.allocator);
    defer attributes.deinit();
    attributes.parse(dom.character_data.dataOf(instance) orelse "") catch return;
    const href = attributes.get("href") orelse return;
    const title = attributes.get("title") orelse "";
    if (std.mem.eql(u8, attributes.get("alternate") orelse "", "yes") and title.len == 0) return;
    if (attributes.get("type")) |mime| if (mime.len != 0 and !std.ascii.eqlIgnoreCase(mime, "text/css")) return;
    // XML's stack-local parser cannot suspend yet. The load is asynchronous
    // and delays load, but enters no parser-blocking set until the XML
    // parser gains its document-load continuation (streamnav).
    internal.load = style_sheet_loading.startLink(instance, .{ .href = href }, false) orelse 0;
}

fn sheetOf(instance: *runtime.Instance) ?*dom.style.SheetRecord {
    return (getInternal(instance) orelse return null).sheet;
}

fn sheetArrived(instance: *runtime.Instance, text: []const u8, url: []const u8, origin_clean: bool) void {
    const internal = getInternal(instance) orelse return;
    if (!internal.in_prolog or !std.mem.eql(u8, internal.target, "xml-stylesheet")) return;
    var attributes = Attributes.init(internal.allocator);
    defer attributes.deinit();
    attributes.parse(dom.character_data.dataOf(instance) orelse "") catch return;
    const document = (interfaces.Node.get_ownerDocument(instance) catch null) orelse return;
    removeSheet(instance, internal);
    const record = dom.style.SheetRecord.create(instance.ctx.allocator, text, .{
        .owner_node = instance,
        .title = attributes.get("title") orelse "",
        .alternate = std.mem.eql(u8, attributes.get("alternate") orelse "", "yes"),
        .media = attributes.get("media") orelse "",
        .location = url,
        .base_url = url,
        .origin_clean = origin_clean,
        .mode = .{ .quirks = dom.document_internals.getMode(document) == .quirks },
    }) catch return;
    internal.sheet = record;
    internal.sheet_document = document;
    internal.sheet_document_generation = runtime.SlabAllocator.generationOf(document);
    if (dom.style.engine.engineOf(document)) |style_engine| style_engine.addOwner(instance) catch {};
}

fn removeSheet(instance: *runtime.Instance, internal: *InternalState) void {
    const record = internal.sheet orelse return;
    internal.sheet = null;
    if (internal.sheet_document) |document| {
        if (runtime.SlabAllocator.generationOf(document) == internal.sheet_document_generation) {
            if (dom.style.engine.engineOf(document)) |style_engine| style_engine.removeOwner(instance);
        }
    }
    internal.sheet_document = null;
    record.detach();
    dom.style.objects.ownerReleased(instance);
    record.unref();
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Get the target string directly (for cloning)
pub fn getTarget(instance: *runtime.Instance) ?[]const u8 {
    const internal = getInternal(instance) orelse return null;
    return internal.target;
}

/// Create a ProcessingInstruction with the given target and data
pub fn createProcessingInstruction(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    target: []const u8,
    data: []const u8,
) !*runtime.Instance {
    // Parser/clone inputs are already node data; validation belongs to the
    // script entry points, not to the generated construction chain.
    return ProcessingInstruction.initWith(allocator, ctx, .{ .target = target, .data = data });
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
/// Note: Use ctx.allocator for all allocations to ensure consistency with deinit
pub fn call_constructor(ctx: runtime.Context, target: runtime.DOMString, data: webidl.Opt(runtime.DOMString)) !*runtime.Instance {
    // Rule 2: newer spec, browsers lagging. whatwg/dom 729983ac2a was
    // co-authored by implementers; Mozilla #1369 and WebKit #628 support the
    // feature family, though no browser ships its constructor yet.
    // Initialization steps 1-2: XML Name, and no ?> in initial data.
    const value = if (data.was_passed) data.value.asSlice() else "";
    if (!dom.pi_attributes.isXmlName(target.asSlice()) or std.mem.indexOf(u8, value, "?>") != null)
        return error.InvalidCharacterError;
    const realm = ctx.realm orelse return error.InvalidStateError;
    const global: *runtime.Instance = @ptrCast(@alignCast(realm.global_object orelse return error.InvalidStateError));
    const document = try interfaces.Window.get_document(global);
    const instance = try ProcessingInstruction.initWith(ctx.allocator, ctx, .{ .target = target.asSlice(), .data = value });
    errdefer ProcessingInstruction.deinit(instance);
    // Constructor step 1; initialization steps 3-5 are the target/data
    // construction arguments and the initially stale, lazily parsed map.
    try dom.node_document.set(instance, document);
    return instance;
}

/// Rule 2: newer spec, one shipping browser. Chrome ships the attributes
/// added by whatwg/dom 729983ac2a (WPT 60815); Firefox/Safari still lag.
/// DOM update-attributes-from-data steps 1-4, evaluated lazily, as Blink's
/// ProcessingInstruction::ProcessAttributesIfNeeded does. Invalid syntax
/// clears the whole map; allocation failure is propagated, never cached.
fn ensureAttributes(instance: *runtime.Instance) !*Attributes {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.attributes == null) {
        const attributes = try internal.allocator.create(Attributes);
        attributes.* = Attributes.init(internal.allocator);
        internal.attributes = attributes;
    }
    const attributes = internal.attributes.?;
    if (internal.attributes_stale) {
        // Steps 1-2: clear, then parse the current CharacterData bytes.
        attributes.parse(dom.character_data.dataOf(instance) orelse "") catch |err| switch (err) {
            // Step 3: a parsing error leaves the cleared map empty.
            error.InvalidPseudoAttributes => {},
            error.OutOfMemory => return error.OutOfMemory,
        };
        // Step 4: parse inserted the ordered pseudo-attributes into the map.
        internal.attributes_stale = false;
    }
    return attributes;
}

fn updateDataFromAttributes(instance: *runtime.Instance, attributes: *Attributes) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Steps 1-2: ordered serialization, including U+003E -> &gt; (the
    // whatwg/dom b76da7af5f erratum, not the earlier U+003D typo).
    const data = try attributes.serialize();
    defer internal.allocator.free(data);
    // Step 3: replace all data with piAttributesAlreadyUpdated = true.
    // The callback consumes this before children-changed steps run script.
    // Reparsing would lose relaxed DOM attribute names XML Name rejects.
    const length = try interfaces.CharacterData.get_length(instance);
    internal.attributes_already_updated = true;
    defer internal.attributes_already_updated = false;
    try interfaces.CharacterData.call_replaceData(instance, 0, length, runtime.DOMString.initInterned(data));
}

pub fn call_hasAttributes(instance: *runtime.Instance) anyerror!bool {
    return (try ensureAttributes(instance)).entries.size() != 0;
}

pub fn call_toggleAttribute(instance: *runtime.Instance, name: runtime.DOMString, force: webidl.Opt(bool)) anyerror!bool {
    // Step 1: validate the DOM local name (not XML's Name production).
    if (!dom.names.isValidAttributeLocalName(name.asSlice())) return error.InvalidCharacterError;
    // Steps 2-3: add an absent name unless force is explicitly false.
    const attributes = try ensureAttributes(instance);
    if (attributes.get(name.asSlice()) == null) {
        if (force.was_passed and !force.value) return false;
        try attributes.set(name.asSlice(), "");
        try updateDataFromAttributes(instance, attributes);
        return true;
    }
    // Steps 4-5: remove a present name unless force is explicitly true.
    if (force.was_passed and force.value) return true;
    attributes.remove(name.asSlice());
    try updateDataFromAttributes(instance, attributes);
    return false;
}

pub fn call_hasAttribute(instance: *runtime.Instance, name: runtime.DOMString) anyerror!bool {
    return (try ensureAttributes(instance)).get(name.asSlice()) != null;
}

pub fn call_getAttribute(instance: *runtime.Instance, name: runtime.DOMString) anyerror!?runtime.DOMString {
    const value = (try ensureAttributes(instance)).get(name.asSlice()) orelse return null;
    return try runtime.DOMString.initDupe(instance.ctx.allocator, value);
}

pub fn call_getAttributeNames(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const attributes = try ensureAttributes(instance);
    const values = try instance.ctx.allocator.alloc(runtime.JSValue, attributes.entries.size());
    defer instance.ctx.allocator.free(values);
    for (attributes.entries.items(), values) |entry, *value| value.* = runtime.JSValue.fromStringRef(entry.name);
    return (try engine.createSequenceOfValues(engine.currentRealm() orelse instance.ctx, values)).take();
}

/// Operation: removeAttribute
pub fn call_removeAttribute(instance: *runtime.Instance, name: runtime.DOMString) anyerror!void {
    // Steps 1-2: remove the map entry, then serialize even if absent.
    // Current DOM requires this unconditionally; Blink still skips the
    // absent-name case (covered separately by the native regression).
    const attributes = try ensureAttributes(instance);
    attributes.remove(name.asSlice());
    try updateDataFromAttributes(instance, attributes);
}

/// Operation: setAttribute
pub fn call_setAttribute(instance: *runtime.Instance, name: runtime.DOMString, value: runtime.DOMString) anyerror!void {
    // Steps 1-3: validate, set the ordered map entry, update data.
    if (!dom.names.isValidAttributeLocalName(name.asSlice())) return error.InvalidCharacterError;
    const attributes = try ensureAttributes(instance);
    try attributes.set(name.asSlice(), value.asSlice());
    try updateDataFromAttributes(instance, attributes);
}
