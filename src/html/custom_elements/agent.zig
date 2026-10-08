//! An agent's reaction state, including the roots held until reactions finish.
//! Records outlive cancelled elements: a stale element-queue slot never
//! dereferences an element after its realm has ended or its address is reused.
const std = @import("std");
const infra = @import("infra");
const Reactions = @import("reactions.zig").Reactions;

pub fn AgentState(comptime Element: type, comptime Realm: type, comptime Payload: type, comptime Root: type, comptime Returns: type, comptime realmIsLive: fn (Realm) bool) type {
    return struct {
        const Self = @This();
        pub const ActiveConstructor = struct {
            constructor: ?Root,
            registry: ?Element,
            registry_root: ?Root,
            realm: Realm,

            fn release(self: *@This()) void {
                if (self.constructor) |root| root.release();
                if (self.registry_root) |root| root.release();
                self.constructor = null;
                self.registry_root = null;
                self.registry = null;
            }
        };
        const Record = struct {
            element: Element,
            realm: Realm,
            root: ?Root,
            cancelled: bool = false,
            next: ?*Record = null,

            fn release(self: *Record) void {
                const root = self.root orelse return;
                self.root = null;
                root.release();
            }
        };

        allocator: std.mem.Allocator,
        queues: Reactions(*Record, Payload),
        elements: std.AutoHashMap(Element, *Record),
        records: ?*Record = null,
        invoking: usize = 0,
        definition_count: usize = 0,
        form_definition_count: usize = 0,
        active_constructors: infra.List(ActiveConstructor),
        returns: Returns,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .queues = Reactions(*Record, Payload).init(allocator),
                .elements = std.AutoHashMap(Element, *Record).init(allocator),
                .active_constructors = infra.List(ActiveConstructor).init(allocator),
                .returns = Returns.init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.releasePending();
            self.queues.deinit();
            self.elements.deinit();
            self.active_constructors.deinit();
            self.returns.deinit();
            self.* = undefined;
        }

        /// Browser calls this before destroying the engine agent. The storage
        /// remains valid until AgentHost.deinit; queued microtasks only borrow
        /// that storage. Drop handles even if their realms have already ended.
        pub fn releasePending(self: *Self) void {
            std.debug.assert(self.invoking == 0 and self.queues.depth == 0);
            self.queues.deinit();
            self.queues = Reactions(*Record, Payload).init(self.allocator);
            self.releaseRecords();
            for (self.active_constructors.toSliceMut()) |*entry| entry.release();
            self.active_constructors.clear();
            self.returns.releaseAll();
        }

        pub fn begin(self: *Self) void {
            self.queues.begin();
        }

        pub fn hasCurrentQueue(self: *const Self) bool {
            return self.queues.hasCurrentQueue();
        }

        /// Takes payload only on success. acquire returns an owned root and
        /// must not run script. One root suffices for every queued occurrence
        /// of the same element, including recursively invoked reaction queues.
        pub fn enqueue(self: *Self, context: anytype, element: Element, realm: Realm, payload: Payload, comptime acquire: anytype) !bool {
            if (self.elements.get(element)) |record| return self.queues.enqueue(record, payload);
            const record = try self.allocator.create(Record);
            errdefer self.allocator.destroy(record);
            record.* = .{ .element = element, .realm = realm, .root = try acquire(context, element) };
            errdefer record.release();
            try self.elements.put(element, record);
            errdefer _ = self.elements.remove(element);
            const schedule = try self.queues.enqueue(record, payload);
            record.next = self.records;
            self.records = record;
            return schedule;
        }

        pub fn end(self: *Self, context: anytype, comptime invoke: anytype) void {
            self.invoking += 1;
            defer {
                self.invoking -= 1;
                self.collectQuiescent();
            }
            const Dispatch = Dispatcher(@TypeOf(context), invoke);
            var dispatch = Dispatch{ .context = context };
            self.queues.end(&dispatch, Dispatch.invoke);
        }

        pub fn invokeBackup(self: *Self, context: anytype, comptime invoke: anytype) void {
            self.invoking += 1;
            defer {
                self.invoking -= 1;
                self.collectQuiescent();
            }
            const Dispatch = Dispatcher(@TypeOf(context), invoke);
            var dispatch = Dispatch{ .context = context };
            self.queues.invokeBackup(&dispatch, Dispatch.invoke);
        }

        pub fn cancelBackup(self: *Self) void {
            self.queues.cancelBackup();
            self.collectQuiescent();
        }

        /// Pop without script when the engine cannot suspend an exception.
        /// Roots stay live until the transferred backup work runs or is dropped.
        pub fn deferCurrent(self: *Self) !bool {
            defer self.collectQuiescent();
            return self.queues.deferCurrent();
        }

        /// Upgrade step 10's failure path clears the element's reaction queue.
        pub fn clearElement(self: *Self, element: Element) void {
            const record = self.elements.get(element) orelse return;
            self.queues.clearElement(record);
        }

        /// Native error cleanup can destroy an element in a live realm. Its
        /// address may immediately be reissued; stale queue slots keep this
        /// cancelled identity, never the replacement's record.
        pub fn cancelElement(self: *Self, element: Element) void {
            const entry = self.elements.fetchRemove(element) orelse return;
            const record = entry.value;
            record.cancelled = true;
            self.queues.clearElement(record);
            record.release();
            self.collectQuiescent();
        }

        /// Called before the realm's instances or engine roots are destroyed.
        /// A scheduled backup microtask borrows this agent state, so it remains
        /// safe to run afterwards; cancelled records contain no callable work.
        pub fn clearRealm(self: *Self, realm: Realm) void {
            self.returns.clearRealm(realm);
            // Keep the scope slots until their callers pop them, including a
            // caller whose script destroys its own realm during construction.
            for (self.active_constructors.toSliceMut()) |*entry| {
                if (entry.realm == realm) entry.release();
            }
            var current = self.records;
            while (current) |record| : (current = record.next) {
                if (record.cancelled or record.realm != realm) continue;
                record.cancelled = true;
                _ = self.elements.remove(record.element);
                self.queues.clearElement(record);
                record.release();
            }
            self.collectQuiescent();
        }

        /// A stack of map overrides implements save/set/restore even when the
        /// same constructor recursively constructs another element.
        pub fn pushConstructor(self: *Self, entry: ActiveConstructor) !void {
            try self.active_constructors.append(entry);
        }

        pub fn popConstructor(self: *Self) void {
            var entry = self.active_constructors.remove(self.active_constructors.len - 1) catch unreachable;
            entry.release();
        }

        fn Dispatcher(comptime Context: type, comptime callback: anytype) type {
            return struct {
                context: Context,
                fn invoke(self: *@This(), record: *Record, payload: *Payload) void {
                    // A missed unloading hook must never expose a freed
                    // Instance. Its owned handles still need their release.
                    if (!record.cancelled and realmIsLive(record.realm)) callback(self.context, record.element, payload);
                }
            };
        }

        fn collectQuiescent(self: *Self) void {
            if (self.invoking != 0 or self.queues.depth != 0 or self.queues.processing_backup) return;
            self.releaseRecords();
        }

        fn releaseRecords(self: *Self) void {
            // Every `elements` entry has its record on `records` (enqueue puts
            // both), so no records means an empty map - and clearing an empty
            // map still memsets all of its metadata once it has ever grown
            // (std.HashMap.clearRetainingCapacity): after one define() upgraded
            // 100,000 elements, every later outermost [CEReactions] call paid
            // that memset - appendChild and setAttribute ran 15-25% slower
            // (CE-S2, measured with crane/lf1-scratch-ce-reactions-timing).
            if (self.records == null) return;
            var current = self.records;
            self.records = null;
            self.elements.clearRetainingCapacity();
            while (current) |record| {
                current = record.next;
                record.release();
                self.allocator.destroy(record);
            }
        }
    };
}
