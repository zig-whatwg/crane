//! Mutation Observer Algorithms (WHATWG DOM Standard §7)
//!
//! Spec: https://dom.spec.whatwg.org/#mutation-observers
//!
//! This module implements the mutation observation algorithms:
//! - Queue a mutation record
//! - Queue a tree mutation record
//! - Queue a mutation observer microtask
//! - Notify mutation observers
//!
//! These algorithms are called by DOM mutation operations to notify observers
//! of changes to the tree.

const std = @import("std");
const infra = @import("infra");
const Allocator = std.mem.Allocator;

// Import DOM types from interfaces (via root.zig re-exports)
const interfaces = @import("interfaces");
const Node = interfaces.Node;
const NodeList = interfaces.NodeList;
const MutationObserver = interfaces.MutationObserver;
const MutationRecord = interfaces.MutationRecord;

// Import dictionary from dictionaries module
const dictionaries = @import("dictionaries");
const MutationObserverInit = dictionaries.MutationObserverInit;
const engine = @import("engine");
const observer_registrations = @import("observer_registrations.zig");
const AgentHost = @import("html_core").agent_host.AgentHost;

const log = std.log.scoped(.mutation_observer);

/// DOM 4.3: "Each similar-origin window agent has a mutation observer
/// microtask queued (a boolean) ... pending mutation observers (a set of zero
/// or more MutationObserver objects) ... signal slots (a set of slots)". The
/// agent's: each agent's host keeps one (html AgentHost.mutation_observers),
/// found from a realm of it (`agentOf`). It was one per THREAD: with two
/// agents on a thread, one agent's queued microtask kept the other from
/// queueing its own, the other's notify ran this agent's observers, and one
/// Browser's page end dropped every agent's pending observers
/// (tests/html/gs3_agent_state_one_thread_test.zig).
pub const MutationObserverAgent = struct {
    /// Whether a mutation observer microtask has been queued
    microtask_queued: bool = false,

    /// Set of mutation observers with pending records
    /// Stores *runtime.Instance pointers to MutationObserver instances
    pending_observers: infra.List(*runtime.Instance),

    /// DOM 4.3: the agent's "mutation observer counter (a number), which is
    /// initially 0" - the next MutationObserver's creation index
    /// (`takeCreationIndex`), by which "notify mutation observers" step 2
    /// orders the pending observers.
    observer_counter: u64 = 0,

    /// DOM 4.2.2.5: the agent's signal slots, an ordered set of slots. Each
    /// slot in it has pending activity (engine.keepPlatformObjectAlive) until
    /// its slotchange event has been fired - Blink keeps the list as traced
    /// Members - and the generation tells a slot its realm's end freed anyway.
    signal_slots: std.ArrayListUnmanaged(SignalSlot) = .empty,
    /// Membership of `signal_slots` - slot -> its generation - so that
    /// appending to the set stays constant time however many slots one task
    /// signals (a page building a thousand components signals thousands
    /// before its first microtask checkpoint).
    signal_slot_set: infra.address_map.AddressHashMapUnmanaged(*runtime.Instance, u64) = .empty,

    allocator: Allocator,

    pub fn init(allocator: Allocator) MutationObserverAgent {
        return .{
            .microtask_queued = false,
            .pending_observers = infra.List(*runtime.Instance).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MutationObserverAgent) void {
        self.pending_observers.deinit();
        for (self.signal_slots.items) |*entry| entry.ref.release(entry.slot);
        self.signal_slots.deinit(self.allocator);
        self.signal_slot_set.deinit(self.allocator);
    }

    /// The agent's host ends, after the agent and its DOM: the storage goes,
    /// and whatever is still listed - which its page's end (`resetAgent`) and
    /// each object's teardown (`forgetObserver`, `forgetSlot`) left - is
    /// not touched: its nodes are gone with the agent's DOM.
    pub fn deinitAfterAgent(self: *MutationObserverAgent) void {
        self.pending_observers.deinit();
        self.signal_slots.deinit(self.allocator);
        self.signal_slot_set.deinit(self.allocator);
    }

    /// Whether `slot` is in the signal slots.
    fn isSignaled(self: *const MutationObserverAgent, slot: *runtime.Instance) bool {
        const generation = self.signal_slot_set.get(slot) orelse return false;
        return generation == runtime.SlabAllocator.generationOf(slot);
    }
};

/// A slot in the agent's signal slots, with its slab generation when it
/// entered, and the counted reference the set holds it by until its
/// slotchange is fired (refcount step 7's missed holder, lane refcount8: the
/// zombie audit's full sweep found the slotchange taking on a slot whose tree
/// the counts had called garbage). WebKit keeps the signal slot list as
/// GCReachableRefs: a counted reference beside the pending-activity keep. A
/// chainless node_holds.CountedRef: the list's items move.
pub const SignalSlot = struct {
    slot: *runtime.Instance,
    generation: u64,
    ref: @import("node_holds.zig").CountedRef = .{},
};

/// The mutation observer state of the agent `realm` belongs to - the
/// surrounding agent, for an object of the realm - kept on its host (html
/// AgentHost.mutation_observers). Null for a realm with no agent, or an agent
/// with no host (an engine-less DOM test's, a bare test agent's): records
/// still reach their observers' record queues there (takeRecords), and no
/// notify is queued.
pub fn agentOf(realm: runtime.Context) ?*MutationObserverAgent {
    const agent = realm.agent orelse return null;
    const host: *AgentHost = @ptrCast(@alignCast(engine.agentHost(agent) orelse return null));
    return &host.mutation_observers;
}

/// `new MutationObserver(callback)` steps 2-3: "Set this's creation index to
/// this's relevant agent's mutation observer counter. Increase this's
/// relevant agent's mutation observer counter by 1." `realm` is the new
/// observer's relevant realm. An agent with no host keeps no state and no
/// notify runs there, so its observers' index is 0.
pub fn takeCreationIndex(realm: runtime.Context) u64 {
    const agent = agentOf(realm) orelse return 0;
    const index = agent.observer_counter;
    agent.observer_counter += 1;
    return index;
}

/// A MutationObserver is going away: take it off the surrounding agent's
/// pending mutation observers, so the notify microtask cannot reach it.
pub fn forgetObserver(observer: *runtime.Instance) void {
    const agent = agentOf(observer.ctx) orelse return;
    var i: usize = 0;
    while (i < agent.pending_observers.len) {
        if (agent.pending_observers.get(i) == observer) {
            _ = agent.pending_observers.remove(i) catch break;
            continue;
        }
        i += 1;
    }
}

/// DOM "signal a slot change", for `slot` (an HTMLSlotElement).
///
/// Spec: https://dom.spec.whatwg.org/#signal-a-slot-change
pub fn signalSlotChange(slot: *runtime.Instance) void {
    const agent = agentOf(slot.ctx) orelse return;
    // Step 1: "Append slot to slot's relevant agent's signal slots." A set:
    // a slot already in it keeps its place.
    if (!agent.isSignaled(slot)) {
        const generation = runtime.SlabAllocator.generationOf(slot);
        agent.signal_slots.ensureUnusedCapacity(agent.allocator, 1) catch return;
        agent.signal_slot_set.put(agent.allocator, slot, generation) catch return;
        var entry: SignalSlot = .{ .slot = slot, .generation = generation };
        entry.ref.take(slot, @import("instance_bridge.zig").getNodeBase(@ptrCast(slot)));
        agent.signal_slots.appendAssumeCapacity(entry);
        // Until its slotchange is fired, the slot stays alive whatever script
        // holds - the event is pending activity.
        engine.keepPlatformObjectAlive(slot);
    }
    // Step 2: "Queue a mutation observer microtask."
    queueMutationObserverMicrotask(agent, slot.ctx) catch |err| {
        std.log.scoped(.mutation_observer).warn("slotchange microtask not queued: {}", .{err});
    };
}

/// `slot` is being torn down: take it out of the signal slots, so that
/// notify cannot reach it, and end the pending activity signaling began.
pub fn forgetSlot(slot: *runtime.Instance) void {
    const agent = agentOf(slot.ctx) orelse return;
    if (!agent.isSignaled(slot)) return;
    _ = agent.signal_slot_set.remove(slot);
    for (agent.signal_slots.items, 0..) |entry, i| {
        if (entry.slot == slot) {
            var removed = agent.signal_slots.orderedRemove(i);
            removed.ref.release(slot);
            break;
        }
    }
    engine.releasePlatformObject(slot);
}

/// DOM "notify mutation observers" step 7, for one slot of signalSet: "fire
/// an event named slotchange, with its bubbles attribute set to true, at
/// slot."
fn fireSlotChange(slot: *runtime.Instance) void {
    // Only script listens for slotchange; with no engine behind the realm (a
    // DOM unit test's context) there is no listener, and an event made there
    // would have no owner to free it (Instance.releaseIfUnwrapped).
    if (!slot.ctx.hasEngine()) return;
    const webidl = @import("webidl");
    const event = interfaces.Event.call_constructor(
        slot.ctx,
        runtime.DOMString.initInterned("slotchange"),
        webidl.Opt(dictionaries.EventInit).passed(.{ .bubbles = true, .cancelable = false, .composed = false }),
    ) catch return;
    // Not `defer deinit`: a listener can keep the event, and its wrapper
    // then owns it.
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);
    _ = @import("fire_event.zig").dispatchTrusted(slot, event) catch {};
}

/// The page of `realm`'s agent ends (browser Context.deinit, a Browser's page
/// - every window of its agent): the agent's pending mutation observers and
/// signal slots go, while their nodes are still alive, and the microtask
/// queued flag with them - this agent's only, never another's.
pub fn resetAgent(realm: runtime.Context) void {
    const agent = agentOf(realm) orelse return;
    const allocator = agent.allocator;
    // The counter is the agent's, not the page's: an observer that outlives
    // the page still sorts before every observer made after it.
    const counter = agent.observer_counter;
    agent.deinit();
    agent.* = MutationObserverAgent.init(allocator);
    agent.observer_counter = counter;
}

/// DOM §7.3 - Queue a mutation record
///
/// Queue a mutation record of type for target with name, namespace, oldValue,
/// addedNodes, removedNodes, previousSibling, and nextSibling.
///
/// Spec: https://dom.spec.whatwg.org/#queueing-a-mutation-record
pub fn queueMutationRecord(
    allocator: Allocator,
    mutation_type: []const u8,
    target: *Node,
    name: ?[]const u8,
    namespace: ?[]const u8,
    old_value: ?[]const u8,
    added_nodes: *NodeList,
    removed_nodes: *NodeList,
    previous_sibling: ?*Node,
    next_sibling: ?*Node,
) !void {
    // Step 1: Let interestedObservers be an empty map
    var interested_observers = std.AutoHashMap(*MutationObserver, ?[]const u8).init(allocator);
    defer interested_observers.deinit();

    // Step 2: Let nodes be the inclusive ancestors of target
    const tree_helpers = @import("tree_helpers.zig");
    var nodes = try tree_helpers.getInclusiveAncestors(allocator, target);
    defer nodes.deinit();

    // Step 3: For each node in nodes, and then for each registered of node's registered observer list
    for (nodes.items()) |node| {
        var entries = node.registeredObservers();
        while (entries.next()) |registered| {
            const options = registered.options;

            // Step 3.2: If none of the following are true, then:
            var should_skip = false;

            // - node is not target and options["subtree"] is false
            if (node != target and !options.subtree) {
                should_skip = true;
            }

            // - type is "attributes" and options["attributes"] either does not exist or is false
            if (std.mem.eql(u8, mutation_type, "attributes")) {
                if (options.attributes == null or !options.attributes.?) {
                    should_skip = true;
                }
                // - type is "attributes", options["attributeFilter"] exists, and
                //   options["attributeFilter"] does not contain name or namespace is non-null
                if (options.attributeFilter) |filter| {
                    if (namespace != null) {
                        should_skip = true;
                    } else if (name) |attr_name| {
                        var found = false;
                        for (filter) |filter_name| {
                            if (std.mem.eql(u8, filter_name, attr_name)) {
                                found = true;
                                break;
                            }
                        }
                        if (!found) should_skip = true;
                    }
                }
            }

            // - type is "characterData" and options["characterData"] either does not exist or is false
            if (std.mem.eql(u8, mutation_type, "characterData")) {
                if (options.characterData == null or !options.characterData.?) {
                    should_skip = true;
                }
            }

            // - type is "childList" and options["childList"] is false
            if (std.mem.eql(u8, mutation_type, "childList")) {
                if (!options.childList) {
                    should_skip = true;
                }
            }

            if (should_skip) continue;

            // Step 3.2.1: Let mo be registered's observer
            // Cast from opaque type to concrete MutationObserver struct
            const mo: *MutationObserver = @ptrCast(@alignCast(registered.observer));

            // Step 3.2.2: If interestedObservers[mo] does not exist, then set interestedObservers[mo] to null
            if (!interested_observers.contains(mo)) {
                try interested_observers.put(mo, null);
            }

            // Step 3.2.3: If either type is "attributes" and options["attributeOldValue"] is true,
            // or type is "characterData" and options["characterDataOldValue"] is true,
            // then set interestedObservers[mo] to oldValue
            if (std.mem.eql(u8, mutation_type, "attributes") and (options.attributeOldValue orelse false)) {
                try interested_observers.put(mo, old_value);
            } else if (std.mem.eql(u8, mutation_type, "characterData") and (options.characterDataOldValue orelse false)) {
                try interested_observers.put(mo, old_value);
            }
        }
    }

    // Step 4: For each observer → mappedOldValue of interestedObservers
    var it = interested_observers.iterator();
    while (it.next()) |entry| {
        const observer = entry.key_ptr.*;
        const mapped_old_value = entry.value_ptr.*;

        // Step 4.1: Let record be a new MutationRecord object with...
        const record = try MutationRecord.init(
            allocator,
            mutation_type,
            target,
            added_nodes,
            removed_nodes,
            previous_sibling,
            next_sibling,
            name,
            namespace,
            mapped_old_value,
        );

        // Step 4.2: Enqueue record to observer's record queue
        try observer.enqueueRecord(record);
    }

    // Steps 4.3 and 5 - the surrounding agent's pending mutation observers,
    // and its microtask - are skipped: a legacy `*Node` carries no realm to
    // name the surrounding agent by, so the records wait in their observers'
    // queues (takeRecords). (Nothing reaches this function: its only caller,
    // attribute_algorithms.handleAttributeChanges, is reached only from the
    // unused dom_token_list.zig.)
}

/// DOM §7.3 - Queue a tree mutation record
///
/// Queue a tree mutation record for target with addedNodes, removedNodes,
/// previousSibling, and nextSibling.
///
/// Spec: https://dom.spec.whatwg.org/#queue-a-tree-mutation-record
///
/// The added and removed nodes come as the tree's own nodes, and no NodeList
/// is made for them here: each record holds them and makes its addedNodes
/// and removedNodes when script first reads one (MutationRecord.create).
/// The spec's two lists are the same objects in every observer's record; a
/// record's lists are its own here, made from the same nodes in the same
/// order (Blink shares the whole record instead).
pub fn queueTreeMutationRecord(
    allocator: Allocator,
    target: *runtime.Instance,
    added_nodes: []const *NodeBase,
    removed_nodes: []const *NodeBase,
    previous_sibling: ?*runtime.Instance,
    next_sibling: ?*runtime.Instance,
) !void {
    // Step 1: Assert: either addedNodes or removedNodes is not empty
    std.debug.assert(added_nodes.len > 0 or removed_nodes.len > 0);

    // The nodes as platform objects: a node with no instance (built below
    // the WebIDL layer) is not script-visible and is left out, as it was.
    var fixed: [16]*runtime.Instance = undefined;
    const total = added_nodes.len + removed_nodes.len;
    const instances = if (total <= fixed.len) fixed[0..total] else try allocator.alloc(*runtime.Instance, total);
    defer if (total > fixed.len) allocator.free(instances);
    const added_count = collectInstances(added_nodes, instances);
    const removed_count = collectInstances(removed_nodes, instances[added_count..]);

    // Step 2: Queue a mutation record of "childList" for target with null, null, null,
    // addedNodes, removedNodes, previousSibling, and nextSibling
    try queueMutationRecordInternal(
        allocator,
        .child_list,
        target,
        null, // name
        null, // namespace
        null, // oldValue
        instances[0..added_count],
        instances[added_count .. added_count + removed_count],
        previous_sibling,
        next_sibling,
    );
}

/// The platform objects of `nodes`, in order, into `out`; how many.
fn collectInstances(nodes: []const *NodeBase, out: []*runtime.Instance) usize {
    var count: usize = 0;
    for (nodes) |node| {
        const object = @import("instance_bridge.zig").getInstance(node) orelse continue;
        out[count] = @ptrCast(@alignCast(object));
        count += 1;
    }
    return count;
}

const runtime = @import("runtime");
const NodeBase = @import("node_base.zig").NodeBase;
const RegisteredObserverOptions = @import("registered_observer.zig").RegisteredObserver.Options;

/// The three record types "queue a mutation record" takes.
pub const MutationType = enum {
    attributes,
    character_data,
    child_list,

    /// The string MutationRecord.type reports.
    pub fn name(self: MutationType) []const u8 {
        return switch (self) {
            .attributes => "attributes",
            .character_data => "characterData",
            .child_list => "childList",
        };
    }
};

/// "Queue a mutation record" step 3.1: whether `options`, registered on a
/// node that is (or is not) the target, wants a record of this type. The
/// spec lists the conditions under which the observer is skipped; this is
/// their negation.
fn wantsRecord(
    options: RegisteredObserverOptions,
    node_is_target: bool,
    mutation_type: MutationType,
    name: ?[]const u8,
    namespace: ?[]const u8,
) bool {
    // "node is not target and options["subtree"] is false"
    if (!node_is_target and !options.subtree) return false;
    switch (mutation_type) {
        .attributes => {
            // "type is "attributes" and options["attributes"] either does not
            // exist or is false"
            if (!options.attributes) return false;
            // "type is "attributes", options["attributeFilter"] exists, and
            // options["attributeFilter"] does not contain name or namespace
            // is non-null"
            if (options.attribute_filter) |filter| {
                if (namespace != null) return false;
                const attr_name = name orelse return false;
                for (filter) |filtered| {
                    if (std.mem.eql(u8, filtered, attr_name)) break;
                } else return false;
            }
            return true;
        },
        // "type is "characterData" and options["characterData"] either does
        // not exist or is false"
        .character_data => return options.character_data,
        // "type is "childList" and options["childList"] is false"
        .child_list => return options.child_list,
    }
}

/// Would "queue a mutation record" of this type for `target` find any
/// interested observer? The same walk as its steps 2 and 3, asked before a
/// record or its node lists exist - the question Blink's
/// MutationObserverInterestGroup answers first - so that a mutation nobody
/// observes costs one walk up the ancestors and allocates nothing.
pub fn hasInterestedObservers(target: *NodeBase, mutation_type: MutationType, name: ?[]const u8, namespace: ?[]const u8) bool {
    var current: ?*NodeBase = target;
    var visited: usize = 0;
    while (current) |node| : (current = node.parent_node) {
        var entries = node.registeredObservers();
        while (entries.next()) |registered| {
            if (wantsRecord(registered.options, node == target, mutation_type, name, namespace)) return true;
        }
        // A deep target: before climbing further, ask whether any
        // MutationObserver was ever made in its agent. If none was, no node
        // has a registered observer and the rest of the ancestry has nothing
        // to find - where the walk visited every ancestor on every mutation
        // of a deep tree (lane crash1 batch 3: O(nodes x depth) to build
        // one). The agent's mutation observer counter (DOM 4.3) only grows,
        // like Blink's and WebKit's per-document observer-type flags, which
        // their MutationObserverInterestGroup::CreateIfNeeded /
        // createIfNeeded ask before walking (Document::
        // HasMutationObserversOfType / hasMutationObserversOfType). Asked
        // only past `walk_before_asking` ancestors: finding the agent takes
        // the engine's agent-registry lock (engine.agentHost), which costs
        // what a walk of about 33 ancestors does (measured below).
        visited += 1;
        if (visited == walk_before_asking and !anyObserverMade(target)) return false;
    }
    return false;
}

/// How many ancestors a walk for registered observers visits before it asks
/// the agent whether any observer exists (`anyObserverMade`). Measured (lane
/// crash1 batch 3, server1 x86-64, ReleaseSafe, a Browser's page, medians of
/// 5 x 2,000,000 calls): `anyObserverMade` - engine.agentHost's registry lock
/// and lookup - 127 ns; walking 64 ancestors' registered observer lists 245
/// ns, 3.8 ns an ancestor. So the lookup is worth about 33 ancestors: a tree
/// up to 32 deep pays only its walk, a deeper one 32 ancestors and one
/// lookup, where it paid its whole depth.
pub const walk_before_asking = 32;

/// Whether a MutationObserver was ever made in the agent `node`'s realm
/// belongs to - true when that cannot be told (no instance, no agent: an
/// engine-less realm keeps no agent state), so that the walk goes on. False
/// means no node of the agent has a registered observer, transient or not.
pub fn anyObserverMade(node: *NodeBase) bool {
    const object = node.ownerInstance() orelse return true;
    const instance: *runtime.Instance = @ptrCast(@alignCast(object));
    const agent = agentOf(instance.ctx) orelse return true;
    return agent.observer_counter != 0;
}

/// DOM "handle attribute changes" step 1: "Queue a mutation record of
/// "attributes" for element with attribute's local name, attribute's
/// namespace, oldValue, « », « », null, and null."
///
/// The strings are copied into each record; the caller's may be freed as soon
/// as this returns.
pub fn queueAttributeMutationRecord(
    element: *runtime.Instance,
    local_name: []const u8,
    namespace: ?[]const u8,
    old_value: ?[]const u8,
) !void {
    try queueRecordWithoutNodes(.attributes, element, local_name, namespace, old_value);
}

/// DOM "replace data" step 4: "Queue a mutation record of "characterData" for
/// node with null, null, node's data, « », « », null, and null."
///
/// `old_data` is copied into each record; it may change once this returns.
pub fn queueCharacterDataMutationRecord(node: *runtime.Instance, old_data: []const u8) !void {
    try queueRecordWithoutNodes(.character_data, node, null, null, old_data);
}

/// A record whose added and removed nodes are « » and whose siblings are
/// null - every "attributes" and "characterData" record. Nothing is built
/// unless an observer wants it, and its two empty NodeLists not until script
/// reads one (MutationRecord.get_addedNodes; Blink's RecordWithEmptyNodeLists
/// makes them lazily too): two lists per observed attribute change were
/// made and, unread, never freed.
fn queueRecordWithoutNodes(
    mutation_type: MutationType,
    target: *runtime.Instance,
    name: ?[]const u8,
    namespace: ?[]const u8,
    old_value: ?[]const u8,
) !void {
    const instance_bridge = @import("instance_bridge.zig");
    const base = instance_bridge.getNodeBase(@ptrCast(target)) orelse return;
    if (!hasInterestedObservers(base, mutation_type, name, namespace)) return;

    try queueMutationRecordInternal(target.ctx.allocator, mutation_type, target, name, namespace, old_value, &.{}, &.{}, null, null);
}

/// Internal version of queueMutationRecord that uses runtime.Instance
/// This avoids the architectural mismatch with the old interface-based signatures
///
/// Spec: https://dom.spec.whatwg.org/#queueing-a-mutation-record
fn queueMutationRecordInternal(
    allocator: Allocator,
    mutation_type: MutationType,
    target: *runtime.Instance,
    name: ?[]const u8,
    namespace: ?[]const u8,
    old_value: ?[]const u8,
    added_nodes: []const *runtime.Instance,
    removed_nodes: []const *runtime.Instance,
    previous_sibling: ?*runtime.Instance,
    next_sibling: ?*runtime.Instance,
) !void {
    const instance_bridge = @import("instance_bridge.zig");
    const handles = @import("handles.zig");

    // Get target's NodeBase for accessing registered observers
    const target_nodebase = instance_bridge.getNodeBase(@ptrCast(target)) orelse {
        // Target is not a registered node - can't dispatch mutations
        std.log.debug("[MutationObserver] queueMutationRecordInternal: target has no NodeBase", .{});
        return;
    };

    // Step 1: "Let interestedObservers be an empty map." An ORDERED map:
    // the order observers enter it is the order they join the surrounding
    // agent's pending mutation observers (step 4.3). It lives for this call
    // only, so it is on the stack while it fits - a few observers, the
    // common case - and on `allocator` past that: a per-record allocation
    // and free cost a bucket's mmap and munmap under the WPT runner's
    // DebugAllocator once nothing longer-lived shares their size class (lane
    // wr1 b6: crane/ed-mo-parse-page.html ran 2.25x slower; docs/lessons/
    // debugging-a-per-call-allocation-in-a-lonely-size-class-maps-a-page.md;
    // tests/v8/wr6_record_queue_alloc_test.zig).
    const Interested = struct { observer: *runtime.Instance, mapped_old_value: ?[]const u8 };
    const interested_on_stack = 16;
    var interested_buffer: [interested_on_stack * @sizeOf(Interested)]u8 align(@alignOf(Interested)) = undefined;
    var interested_memory: std.heap.BufferFirstAllocator = .init(&interested_buffer, allocator);
    const interested_allocator = interested_memory.allocator();
    var interested_observers: std.ArrayListUnmanaged(Interested) = .empty;
    defer interested_observers.deinit(interested_allocator);

    // Step 2: Let nodes be the inclusive ancestors of target
    // Walk from target up to root
    var current: ?*NodeBase = target_nodebase;
    while (current) |node| : (current = node.parent_node) {
        // Step 3: For each node in nodes, for each registered of node's registered observer list
        var entries = node.registeredObservers();
        while (entries.next()) |registered| {
            const options = registered.options;

            // Step 3.1: skip an observer that does not want this record.
            if (!wantsRecord(options, node == target_nodebase, mutation_type, name, namespace)) continue;

            // Step 3.2.1: Let mo be registered's observer
            const observer_ptr = handles.mutationObserverToAnyopaque(registered.observer) orelse {
                std.log.debug("[MutationObserver] WARNING: mutationObserverToAnyopaque returned null!", .{});
                continue;
            };
            const mo: *runtime.Instance = @ptrCast(@alignCast(observer_ptr));
            std.log.debug("[MutationObserver] Observer instance: {*}", .{mo});

            // Step 3.2.2: "If interestedObservers[mo] does not exist, then
            // set interestedObservers[mo] to null."
            const slot = for (interested_observers.items) |*item| {
                if (item.observer == mo) break item;
            } else blk: {
                try interested_observers.append(interested_allocator, .{ .observer = mo, .mapped_old_value = null });
                break :blk &interested_observers.items[interested_observers.items.len - 1];
            };

            // Step 3.2.3: "If either type is "attributes" and
            // options["attributeOldValue"] is true, or type is
            // "characterData" and options["characterDataOldValue"] is true,
            // then set interestedObservers[mo] to oldValue."
            if ((mutation_type == .attributes and options.attribute_old_value) or
                (mutation_type == .character_data and options.character_data_old_value))
            {
                slot.mapped_old_value = old_value;
            }
        }
    }

    // Step 4: For each observer → mappedOldValue of interestedObservers
    for (interested_observers.items) |entry| {
        const observer = entry.observer;
        const mapped_old_value = entry.mapped_old_value;

        // Step 4.1: "Let record be a new MutationRecord object with its type
        // set to type, target set to target, attributeName set to name,
        // attributeNamespace set to namespace, oldValue set to
        // mappedOldValue, addedNodes set to addedNodes, removedNodes set to
        // removedNodes, previousSibling set to previousSibling, and
        // nextSibling set to nextSibling." Those are its construction
        // arguments; it holds every node it names from here.
        const ctx = target.ctx;
        const record = try MutationRecord.initWith(allocator, ctx, .{ .record = .{
            .mutation_type = mutation_type.name(),
            .target = target,
            .added_nodes = added_nodes,
            .removed_nodes = removed_nodes,
            .previous_sibling = previous_sibling,
            .next_sibling = next_sibling,
            .attribute_name = name,
            .attribute_namespace = namespace,
            .old_value = mapped_old_value,
        } });

        // Step 4.2: Enqueue record to observer's record queue - and its
        // target to the observer's pending targets (WebKit
        // MutationObserver::enqueueMutationRecord, `m_pendingTargets.add`).
        std.log.debug("[MutationObserver] Enqueueing record to observer", .{});
        const queue = observer_registrations.recordQueueOf(observer) orelse {
            runtime.Instance.deinit(record);
            continue;
        };
        queue.enqueue(record, target, target_nodebase) catch {
            // If enqueueing fails, clean up the record
            std.log.debug("[MutationObserver] Failed to enqueue record!", .{});
            runtime.Instance.deinit(record);
            continue;
        };
        std.log.debug("[MutationObserver] Record enqueued successfully", .{});

        // Step 4.3: Append observer to the surrounding agent's pending mutation
        // observers - target's relevant realm's agent's. An agent with no host
        // keeps no state: the record waits in the observer's queue.
        const agent = agentOf(target.ctx) orelse continue;
        var already_pending = false;
        for (agent.pending_observers.items()) |pending| {
            if (pending == observer) {
                already_pending = true;
                break;
            }
        }
        if (!already_pending) {
            try agent.pending_observers.append(observer);
            std.log.debug("[MutationObserver] Added observer to pending_observers, total: {}", .{agent.pending_observers.len});
        } else {
            std.log.debug("[MutationObserver] Observer already pending", .{});
        }
    }

    // Step 5: Queue a mutation observer microtask, in the agent of target's
    // relevant realm - the surrounding agent.
    const agent = agentOf(target.ctx) orelse return;
    std.log.debug("[MutationObserver] queueMutationRecordInternal complete, pending_observers: {}", .{agent.pending_observers.len});
    try queueMutationObserverMicrotask(agent, target.ctx);
}

/// DOM §7.1 - Queue a mutation observer microtask
///
/// Queue a microtask to notify mutation observers.
///
/// Spec: https://dom.spec.whatwg.org/#queue-a-mutation-observer-compound-microtask
///
/// `agent` is the surrounding agent's state, and `realm` a realm of it.
fn queueMutationObserverMicrotask(agent: *MutationObserverAgent, realm: runtime.Context) !void {

    // Step 1: If the surrounding agent's mutation observer microtask queued is true, then return
    if (agent.microtask_queued) return;

    // Step 2: Set the surrounding agent's mutation observer microtask queued to true
    agent.microtask_queued = true;

    // Step 3: Queue a microtask to notify mutation observers
    queueNotifyMicrotask(agent, realm) catch {
        // If queueing fails, fall back to synchronous execution
        log.warn("the notify microtask could not be queued; notifying now", .{});
        try notifyMutationObservers(agent);
    };
}

/// The microtask's steps: notify mutation observers, for the agent whose
/// state its data is (BORROWED: the agent's host outlives every microtask of
/// the agent). It owns no data: the agent's state holds what it needs, so a
/// microtask the agent's queue discards (a terminated checkpoint) leaves
/// nothing behind. It used to carry a context holding the allocator, which
/// leaked whenever the microtask never ran (lane leaks1,
/// tests/v8/microtask_dropped_end_test.zig). It stays an agent microtask, not
/// a realm one (engine.queueRealmMicrotask): it notifies every pending
/// observer of the agent, whichever realm queued it, so the end of that
/// realm must not drop it.
fn mutationMicrotask(data: ?*anyopaque) void {
    const agent: *MutationObserverAgent = @ptrCast(@alignCast(data orelse return));

    // Out of memory before any observer was notified: the observers stay
    // pending, and the next mutation's microtask notifies them.
    notifyMutationObservers(agent) catch |err| {
        log.warn("notify mutation observers failed: {s}", .{@errorName(err)});
    };
}

/// DOM "queue a mutation observer microtask", step 3: queue a microtask to
/// notify mutation observers, in the agent of `realm` - the surrounding
/// agent, which the caller names by a realm of it.
///
/// Spec: https://dom.spec.whatwg.org/#queue-a-mutation-observer-compound-microtask
fn queueNotifyMicrotask(state: *MutationObserverAgent, realm: runtime.Context) !void {
    const queued: engine.Error!void = if (realm.agent) |agent| engine.queueMicrotask(agent, mutationMicrotask, state) else error.NotSupported;
    queued catch |err| {
        switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            // No engine behind the realm (unit tests of the DOM alone), so
            // no microtask queue: notify now.
            else => try notifyMutationObservers(state),
        }
    };
}

/// "Notify mutation observers" step 2's order: `a` before `b` when its
/// creation index is lower. Creation indexes in one agent are unique.
fn createdBefore(a: *runtime.Instance, b: *runtime.Instance) bool {
    return observer_registrations.creationIndexOf(a) < observer_registrations.creationIndexOf(b);
}

/// DOM §7.1 - Notify mutation observers
///
/// Invoke callbacks for all pending mutation observers.
///
/// Spec: https://dom.spec.whatwg.org/#notify-mutation-observers
pub fn notifyMutationObservers(agent: *MutationObserverAgent) !void {
    std.log.debug("[MutationObserver] notifyMutationObservers called", .{});
    const allocator = agent.allocator;

    // Step 1: Set the surrounding agent's mutation observer microtask queued to false
    agent.microtask_queued = false;

    // Step 2: "Let notifyList be the result of sorting the surrounding
    // agent's pending mutation observers in ascending order, with a being
    // less than b if a's creation index is less than b's creation index."
    // (whatwg/dom#1507, 2026-10-09: the order the observers were created in,
    // as Blink's DeliverMutations - std::sort by ObserverLessThan, priority_
    // - and WebKit's notifyMutationObservers - std::ranges::sort by
    // m_priority - already did; not the order they became pending.) Every
    // observer listed is alive: its teardown takes it off the list
    // (`forgetObserver`).
    var notify_set = infra.List(*runtime.Instance).init(allocator);
    defer notify_set.deinit();
    try notify_set.appendSlice(agent.pending_observers.items());
    notify_set.sort(createdBefore);

    // Each observer's slab generation now: a callback earlier in the loop can
    // run script, and script can let a later observer go - its teardown takes
    // it off the pending list, but not off this clone.
    const generations = try allocator.alloc(u64, notify_set.len);
    defer allocator.free(generations);
    for (notify_set.items(), 0..) |mo, i| generations[i] = runtime.SlabAllocator.generationOf(mo);

    std.log.debug("[MutationObserver] notifySet has {} observers", .{notify_set.len});

    // Step 3: Empty the surrounding agent's pending mutation observers
    agent.pending_observers.clear();

    // Step 4: "Let signalSet be a clone of the surrounding agent's signal
    // slots."
    // Step 5: "Empty the surrounding agent's signal slots."
    var signal_set = agent.signal_slots;
    agent.signal_slots = .empty;
    // Freed, not kept: the agent outlives every page, and nothing else
    // would ever return the memory.
    agent.signal_slot_set.clearAndFree(agent.allocator);
    const signal_allocator = agent.allocator;
    defer signal_set.deinit(signal_allocator);

    // Step 6: For each mo of notifySet
    for (notify_set.items(), 0..) |mo_instance, mo_index| {
        if (runtime.SlabAllocator.generationOf(mo_instance) != generations[mo_index]) continue;

        // Step 6.1: "Let records be a clone of mo's record queue." Step 6.2:
        // "Empty mo's record queue." Together a move: the queue's list is
        // taken whole, which allocates nothing. (A clone appended `catch
        // continue`: out of memory, a record left the queue without
        // reaching the clone, and was neither delivered nor freed.) The
        // pending targets go with them, and are let go when this iteration
        // ends - after the callback returned, as WebKit's deliver keeps its
        // swapped-out `pendingTargets` until it returns.
        const queue = observer_registrations.recordQueueOf(mo_instance);
        var taken: observer_registrations.RecordQueue.Taken = if (queue) |q| q.take() else .{ .allocator = allocator };
        defer taken.deinit();
        const records = &taken.records;

        std.log.debug("[MutationObserver] Processing observer {*}, records.len={}", .{ mo_instance, records.items.len });

        // Step 6.3: "For each node of mo's node list, remove all transient
        // registered observers whose observer is mo from node's registered
        // observer list."
        observer_registrations.removeTransients(mo_instance);

        // Step 6.4: If records is not empty, then invoke mo's callback with « records, mo »
        if (records.items.len > 0) {
            std.log.debug("[MutationObserver] Invoking callback with {} records", .{records.items.len});
            // The records are TAKEN on every path, failure included
            // (observer_registrations.Implementation.invoke_callback):
            // wrapped, they are the wrapper cache's; not, the observer frees
            // them. So a failure frees nothing here - this catch used to
            // free them all again, a double free whenever wrapping or the
            // call failed (lane leaks6).
            observer_registrations.invokeCallback(mo_instance, records.items) catch |err| {
                log.warn("invoking an observer's callback failed: {s}", .{@errorName(err)});
            };
        }
    }

    // Step 7: "For each slot of signalSet: fire an event named slotchange,
    // with its bubbles attribute set to true, at slot."
    for (signal_set.items) |*entry| {
        // The set's counted reference ends after the slot's slotchange (or
        // is forgotten, for a slot freed meanwhile).
        defer entry.ref.release(entry.slot);
        // A slot its realm's end freed meanwhile (generation), is skipped.
        if (runtime.SlabAllocator.generationOf(entry.slot) != entry.generation) continue;
        fireSlotChange(entry.slot);
        // Its pending activity ends with its event. The keep is counted, one
        // per membership of the signal slots: a listener that signaled the
        // slot again put it back in the (emptied) set with a keep of its own,
        // which forgetSlot or the next notify ends - so this membership's
        // ends here either way. (forgetSlot releases only a slot in the set,
        // and step 5 took every slot here out of it: the two never end the
        // same keep.)
        if (runtime.SlabAllocator.generationOf(entry.slot) != entry.generation) continue;
        engine.releasePlatformObject(entry.slot);
    }
}

// Tests
