//! HTML custom element reactions; mutable queues belong to one AgentHost.
const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const ce = @import("dom").custom_elements;
const driver = @import("custom_elements/driver.zig");

pub const CustomElementDefinition = ce.Definition;
pub const Reaction = ce.Reaction;
pub const ReactionType = @import("html_core").custom_element_reaction.ReactionType;
pub const CallbackType = ce.CallbackType;
pub const AgentState = ce.AgentState;
pub const begin = driver.begin;
pub const end = driver.end;
pub const clearRealm = driver.clearRealm;
pub const clearElement = driver.clearElement;
pub const stateForRealm = driver.stateForRealm;
pub const enqueueCallback = driver.enqueueCallback;
pub const enqueueUpgrade = driver.enqueueUpgrade;
pub const callbackFromMutation = driver.callbackFromMutation;
pub const reportThrown = driver.reportThrown;
pub const pushConstructor = driver.pushConstructor;
pub const activeRegistry = driver.activeRegistry;
pub const hasDefinitions = driver.hasDefinitions;

/// Element reaction queue
/// Each custom element has its own queue of pending reactions
pub const ReactionQueue = struct {
    reactions: std.ArrayListUnmanaged(Reaction),
    allocator: Allocator,

    pub fn init(allocator: Allocator) ReactionQueue {
        return .{
            .reactions = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ReactionQueue) void {
        for (self.reactions.items) |*reaction| reaction.deinit();
        self.reactions.deinit(self.allocator);
    }

    pub fn enqueue(self: *ReactionQueue, reaction: Reaction) !void {
        try self.reactions.append(self.allocator, reaction);
    }

    pub fn dequeue(self: *ReactionQueue) ?Reaction {
        if (self.reactions.items.len == 0) return null;
        const item = self.reactions.orderedRemove(0);
        return item;
    }

    pub fn isEmpty(self: *const ReactionQueue) bool {
        return self.reactions.items.len == 0;
    }

    pub fn clear(self: *ReactionQueue) void {
        for (self.reactions.items) |*reaction| reaction.deinit();
        self.reactions.clearRetainingCapacity();
    }
};

/// Element queue for the custom element reactions stack
/// Uses ArrayListUnmanaged since these queues are stored inside another collection
/// Elements are WebIDL interface instances (Element or subclass)
pub const ElementQueue = std.ArrayListUnmanaged(*runtime.Instance);

/// Stack of element queues - also uses ArrayListUnmanaged
pub const ElementQueueStack = std.ArrayListUnmanaged(ElementQueue);

/// Custom element reactions stack
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#custom-element-reactions-stack
pub const ReactionsStack = struct {
    stack: ElementQueueStack,
    backup_queue: ElementQueue,
    processing_backup: bool = false,
    allocator: Allocator,

    pub fn init(allocator: Allocator) ReactionsStack {
        return .{
            .stack = .empty,
            .backup_queue = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ReactionsStack) void {
        for (self.stack.items) |*queue| {
            queue.deinit(self.allocator);
        }
        self.stack.deinit(self.allocator);
        self.backup_queue.deinit(self.allocator);
    }

    pub fn push(self: *ReactionsStack) !void {
        const queue: ElementQueue = .empty;
        try self.stack.append(self.allocator, queue);
    }

    pub fn pop(self: *ReactionsStack) ?ElementQueue {
        return self.stack.pop();
    }

    pub fn currentElementQueue(self: *ReactionsStack) ?*ElementQueue {
        if (self.stack.items.len == 0) return null;
        return &self.stack.items[self.stack.items.len - 1];
    }

    pub fn isEmpty(self: *const ReactionsStack) bool {
        return self.stack.items.len == 0;
    }
};

/// Explicit storage for clients of the elementary reaction-queue API.
/// It is never shared implicitly with another agent or another test.
pub const ElementReactionQueues = struct {
    allocator: Allocator,
    queues: std.AutoHashMap(*runtime.Instance, ReactionQueue),
    pub fn init(allocator: Allocator) ElementReactionQueues {
        return .{ .allocator = allocator, .queues = std.AutoHashMap(*runtime.Instance, ReactionQueue).init(allocator) };
    }
    pub fn deinit(self: *ElementReactionQueues) void {
        var iterator = self.queues.valueIterator();
        while (iterator.next()) |queue| queue.deinit();
        self.queues.deinit();
    }
};

pub fn getOrCreateReactionQueue(state: *ElementReactionQueues, element: *runtime.Instance) !*ReactionQueue {
    const entry = try state.queues.getOrPut(element);
    if (!entry.found_existing) entry.value_ptr.* = ReactionQueue.init(state.allocator);
    return entry.value_ptr;
}

pub fn removeReactionQueue(state: *ElementReactionQueues, element: *runtime.Instance) void {
    if (state.queues.fetchRemove(element)) |entry| {
        var queue = entry.value;
        queue.deinit();
    }
}

pub fn enqueueCustomElementUpgradeReaction(allocator: Allocator, element: *runtime.Instance, definition: *CustomElementDefinition) !void {
    _ = allocator;
    try enqueueUpgrade(element, definition);
}

pub fn enqueueConnectedCallback(allocator: Allocator, element: *runtime.Instance, definition: *CustomElementDefinition) !void {
    _ = allocator;
    try enqueueCallback(element, definition, .connected, .none);
}
