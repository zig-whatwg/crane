//! HTML §4.13.6: agent-owned custom element reaction queues.
//!
//! Element is an identity key, kept alive by the caller while it has queued
//! work. Payload.deinit releases the data owned by one successful enqueue.
//! This module does not enter script, select an agent, or schedule microtasks.
const std = @import("std");
const infra = @import("infra");

pub fn Reactions(comptime Element: type, comptime Payload: type) type {
    return struct {
        const Self = @This();
        const ElementQueue = infra.List(Element);
        const Pending = struct {
            items: infra.List(Payload),
            next: usize = 0,

            fn deinit(self: *@This()) void {
                for (self.items.toSliceMut()[self.next..]) |*payload| payload.deinit();
                self.items.deinit();
            }
        };
        const Frame = struct { depth: usize, elements: ElementQueue };

        allocator: std.mem.Allocator,
        // Empty scopes have no queue allocation, including the scopes entered
        // before the agent's first custom element definition is registered.
        depth: usize = 0,
        frames: infra.List(Frame),
        pending: std.AutoHashMap(Element, Pending),
        backup: ElementQueue,
        processing_backup: bool = false,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .frames = infra.List(Frame).init(allocator),
                .pending = std.AutoHashMap(Element, Pending).init(allocator),
                .backup = ElementQueue.init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            var iterator = self.pending.valueIterator();
            while (iterator.next()) |pending| pending.deinit();
            self.pending.deinit();
            for (self.frames.toSliceMut()) |*frame| frame.elements.deinit();
            self.frames.deinit();
            self.backup.deinit();
            self.* = undefined;
        }

        /// [CEReactions] step 1: push an initially empty element queue.
        pub fn begin(self: *Self) void {
            self.depth += 1;
        }

        pub fn hasCurrentQueue(self: *const Self) bool {
            return self.depth != 0 and self.frames.len != 0 and self.frames.get(self.frames.len - 1).?.depth == self.depth;
        }

        /// [CEReactions] step 3: pop before invoking, even on abrupt completion.
        /// No pointer into the frames or pending map survives a script call.
        pub fn end(self: *Self, context: anytype, comptime invoke: anytype) void {
            std.debug.assert(self.depth != 0);
            const depth = self.depth;
            self.depth -= 1;
            if (self.frames.len == 0 or self.frames.get(self.frames.len - 1).?.depth != depth) return;
            var frame = self.frames.remove(self.frames.len - 1) catch unreachable;
            defer frame.elements.deinit();
            for (frame.elements.toSlice()) |element| self.invokeElement(element, context, invoke);
        }

        /// The engine cannot set aside the pending exception in this native
        /// call. Pop the scope without invoking script, and let a checkpoint
        /// invoke its elements after the exception has unwound. True asks the
        /// owner to schedule the backup microtask; payload ownership never moves.
        pub fn deferCurrent(self: *Self) !bool {
            std.debug.assert(self.depth != 0);
            const depth = self.depth;
            self.depth -= 1;
            if (self.frames.len == 0 or self.frames.get(self.frames.len - 1).?.depth != depth) return false;
            var frame = self.frames.remove(self.frames.len - 1) catch unreachable;
            defer frame.elements.deinit();
            if (self.backup.len == 0) {
                // Transfer the entire queue without allocating in the common
                // first-deferred-scope case, including its inline storage.
                self.backup.deinit();
                self.backup = frame.elements;
                frame.elements = ElementQueue.init(self.allocator);
            } else {
                self.backup.appendSlice(frame.elements.toSlice()) catch |err| {
                    // No frame now owns these slots. Dropping their payloads
                    // leaves any partially appended backup slots harmless.
                    for (frame.elements.toSlice()) |element| self.clearElement(element);
                    return err;
                };
            }
            if (self.processing_backup) return false;
            self.processing_backup = true;
            return true;
        }

        /// Enqueue a reaction, then enqueue the element on the appropriate queue.
        /// On error the caller still owns payload. A true result asks the owner
        /// to queue ONE backup-processing microtask (appropriate-queue step 1.4).
        pub fn enqueue(self: *Self, element: Element, payload: Payload) !bool {
            const entry = try self.pending.getOrPut(element);
            if (!entry.found_existing) entry.value_ptr.* = .{ .items = infra.List(Payload).init(self.allocator) };
            errdefer if (!entry.found_existing) {
                entry.value_ptr.deinit();
                _ = self.pending.remove(element);
            };
            try entry.value_ptr.items.append(payload);
            errdefer _ = entry.value_ptr.items.remove(entry.value_ptr.items.len - 1) catch unreachable;

            if (self.depth != 0) {
                // Appropriate-queue step 2. Materialise only a nonempty frame.
                const new_frame = self.frames.len == 0 or self.frames.get(self.frames.len - 1).?.depth != self.depth;
                if (new_frame) try self.frames.append(.{ .depth = self.depth, .elements = ElementQueue.init(self.allocator) });
                errdefer if (new_frame) {
                    var frame = self.frames.remove(self.frames.len - 1) catch unreachable;
                    frame.elements.deinit();
                };
                try self.frames.toSliceMut()[self.frames.len - 1].elements.append(element);
                return false;
            }

            // Appropriate-queue steps 1.1–1.3: the flag covers both a scheduled
            // microtask and its invocation, including reentrant enqueues.
            try self.backup.append(element);
            if (self.processing_backup) return false;
            self.processing_backup = true;
            return true;
        }

        /// Appropriate-queue step 1.4: invoke until the backup queue is empty,
        /// including elements appended by the callbacks being invoked.
        pub fn invokeBackup(self: *Self, context: anytype, comptime invoke: anytype) void {
            var index: usize = 0;
            while (index < self.backup.len) : (index += 1) {
                const element = self.backup.get(index).?;
                self.invokeElement(element, context, invoke);
            }
            self.backup.clear();
            self.processing_backup = false;
        }

        /// The owner could not schedule the microtask; no callback owns it.
        pub fn cancelBackup(self: *Self) void {
            for (self.backup.toSlice()) |element| self.clearElement(element);
            self.backup.clear();
            self.processing_backup = false;
        }

        /// Failed upgrade and owner teardown discard all this element's queued
        /// reactions. Its existing element-queue entries safely become no-ops.
        pub fn clearElement(self: *Self, element: Element) void {
            if (self.pending.fetchRemove(element)) |entry| {
                var pending = entry.value;
                pending.deinit();
            }
        }

        fn takeReaction(self: *Self, element: Element) ?Payload {
            const pending = self.pending.getPtr(element) orelse return null;
            const payload = pending.items.get(pending.next).?;
            pending.next += 1;
            if (pending.next == pending.items.len) {
                // All data in this list has moved to invocations. Remove the
                // entry before script can grow the map or enqueue this element.
                pending.items.deinit();
                _ = self.pending.remove(element);
            }
            return payload;
        }

        fn invokeElement(self: *Self, element: Element, context: anytype, comptime invoke: anytype) void {
            // Invoke custom element reactions steps 1.1–1.2: take the first
            // reaction, invoke it, and look up the queue again after script.
            while (self.takeReaction(element)) |reaction| {
                var payload = reaction;
                defer payload.deinit();
                invoke(context, element, &payload);
            }
        }
    };
}
