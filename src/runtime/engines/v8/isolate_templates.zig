//! V8 Isolate-Local Template Storage
//!
//! An isolate's FunctionTemplates, kept in one of V8's embedder data slots -
//! the isolate's own, as Blink keeps its templates in V8PerIsolateData
//! (`isolate->GetData(gin::kEmbedderBlink)`). Nothing of another isolate
//! reaches them, and they go with their isolate (`cleanupTemplateStorage`,
//! before it is disposed).
//!
//! ## Slot Usage
//!
//! - Slot 0: IsolateAllocator (see isolate_allocator.zig)
//! - Slot 1: IsolateTemplates (this module)
//! - Slot 2: v8_wrapper.cpp's per-isolate data
//! - Slot 3: the innermost binding catch scope (v8_wrapper.cpp)
//!
//! ## One isolate's, on its thread
//!
//! Agents live on several threads (every Browser and every worker has its
//! own, docs/instances.md), and an isolate is used by one thread at a time:
//! its storage is read and written there, without a lock. The template
//! registry (template_registry.zig) was a process-wide table of every
//! isolate's templates under a mutex, and a process-wide generation counter
//! that EVERY agent's end bumped threw away every OTHER isolate's storage -
//! a worker's end on its own thread made the page's next iterator from a new
//! template, so its prototype was not the realm's (instances B2,
//! tests/v8/agent_templates_isolation_test.zig).

const std = @import("std");
const v8 = @import("ffi.zig");

/// Embedder data slot for template storage
/// V8 allows storing arbitrary data per-isolate using slot indices
/// Slot 0 is used by isolate_allocator.zig for allocator storage
// All four of V8's isolate data slots are taken: 0 isolate_allocator.zig, 1 this storage (which also carries the agent's deferred teardown queue for dom_algorithm.zig), 2 v8_wrapper.cpp kIsolateDataSlot, 3 v8_wrapper.cpp kBindingCatchScopeSlot - add a field here, never a slot.
pub const TEMPLATE_SLOT: c_int = 1;

/// Per-isolate template storage
pub const IsolateTemplates = struct {
    allocator: std.mem.Allocator,
    /// The binding's cache: the template it made for each interface
    /// (createTemplateCached), and each iterable interface's iterator
    /// prototype template ("<Interface> Iterator"). Disposed with the
    /// storage (`deinit`), each once: the ones objects are made from are
    /// also `registered`, and the rest - the iterator prototype templates,
    /// an interface made for a namespace object - are this map's alone.
    templates: std.StringHashMap(*v8.FunctionTemplate),
    /// The template registry (template_registry.register): the template each
    /// interface's objects of this isolate are made from, by interface name.
    /// The names are BORROWED (the generated interfaces' comptime names); the
    /// templates are disposed with the storage.
    registered: std.StringHashMapUnmanaged(*v8.FunctionTemplate) = .empty,
    /// The agent's deferred teardown queue (engine.AgentOptions.
    /// deferred_teardown), BORROWED from createAgent to the agent's end, for
    /// the "DOM algorithm active" depth every binding entry and callback
    /// invocation counts (dom_algorithm.zig): one load from the isolate, on
    /// the hottest path. Null for an isolate createAgent did not make.
    deferred_teardown: ?*@import("runtime").gc.DeferredTeardown = null,

    /// Initialize isolate-local template storage
    pub fn init(allocator: std.mem.Allocator) IsolateTemplates {
        return .{
            .allocator = allocator,
            .templates = std.StringHashMap(*v8.FunctionTemplate).init(allocator),
        };
    }

    /// Free the maps. `dispose`: every template either map holds too, each
    /// handle once - one in both maps is one handle.
    ///
    /// This disposed only the registered ones, so a template that was only
    /// in `templates` outlived its storage: every iterable interface's
    /// iterator prototype template (interface.zig, iteratorPrototypeTemplate)
    /// was one Global<FunctionTemplate> left behind per worker realm that
    /// iterated one - a worker realm ends its storage with it - and per
    /// agent for a Window (lane sw1-b2's leaks --atExit: 21 x 16 B from
    /// `V8Interface(Headers).returnNewIterator` on worker threads).
    pub fn deinit(self: *IsolateTemplates, dispose: bool) void {
        if (dispose) self.disposeAll();
        self.registered.deinit(self.allocator);
        self.templates.deinit();
    }

    /// Dispose every distinct template the two maps hold.
    fn disposeAll(self: *IsolateTemplates) void {
        var distinct: std.AutoHashMapUnmanaged(*v8.FunctionTemplate, void) = .empty;
        defer distinct.deinit(self.allocator);
        distinct.ensureTotalCapacity(self.allocator, self.registered.count() + self.templates.count()) catch {
            // Out of memory: the registered ones at least, as before.
            var registered = self.registered.valueIterator();
            while (registered.next()) |template| v8.v8_FunctionTemplate_Dispose(template.*);
            return;
        };
        var registered = self.registered.valueIterator();
        while (registered.next()) |template| distinct.putAssumeCapacity(template.*, {});
        var cached = self.templates.valueIterator();
        while (cached.next()) |template| distinct.putAssumeCapacity(template.*, {});
        var each = distinct.keyIterator();
        while (each.next()) |template| v8.v8_FunctionTemplate_Dispose(template.*);
    }

    /// Get a template by interface name
    pub fn get(self: *IsolateTemplates, name: []const u8) ?*v8.FunctionTemplate {
        return self.templates.get(name);
    }

    /// Store a template for an interface name
    pub fn put(self: *IsolateTemplates, name: []const u8, template: *v8.FunctionTemplate) !void {
        try self.templates.put(name, template);
    }

    /// Check if a template exists for an interface name
    pub fn contains(self: *IsolateTemplates, name: []const u8) bool {
        return self.templates.contains(name);
    }

    /// Get the number of stored templates
    pub fn count(self: *IsolateTemplates) usize {
        return self.templates.count();
    }

    /// Clear all templates (but keep the storage allocated)
    pub fn clear(self: *IsolateTemplates) void {
        self.templates.clearRetainingCapacity();
    }
};

/// The isolate's template storage, made with `allocator` if it has none.
pub fn getOrCreateTemplateStorage(
    isolate: *v8.Isolate,
    allocator: std.mem.Allocator,
) !*IsolateTemplates {
    if (getTemplateStorage(isolate)) |existing| return existing;

    const storage = try allocator.create(IsolateTemplates);
    storage.* = IsolateTemplates.init(allocator);
    v8.v8_Isolate_SetData(isolate, TEMPLATE_SLOT, storage);
    return storage;
}

/// The isolate's template storage, made if it has none: with the isolate's
/// allocator (isolate_allocator.zig), or - for an isolate without one, the
/// snapshot generator's or a test's own - the C allocator. Null when out of
/// memory. On the isolate's own thread.
pub fn storageFor(isolate: *v8.Isolate) ?*IsolateTemplates {
    if (getTemplateStorage(isolate)) |existing| return existing;
    const isolate_alloc = @import("isolate_allocator.zig");
    const allocator = isolate_alloc.getIsolateAllocator(isolate) orelse std.heap.c_allocator;
    return getOrCreateTemplateStorage(isolate, allocator) catch null;
}

/// Get template storage for an isolate (returns null if not initialized)
pub fn getTemplateStorage(isolate: *v8.Isolate) ?*IsolateTemplates {
    const data_ptr = v8.v8_Isolate_GetData(isolate, TEMPLATE_SLOT) orelse return null;
    return @ptrCast(@alignCast(data_ptr));
}

/// End the isolate's template storage: its registered templates disposed,
/// its maps and the storage freed, the slot cleared.
///
/// MUST be called BEFORE disposing the isolate, on its thread.
pub fn cleanupTemplateStorage(isolate: *v8.Isolate, _: std.mem.Allocator) void {
    endStorage(isolate, true);
}

/// `cleanupTemplateStorage` without disposing anything: for a test whose
/// templates are synthetic pointers.
pub fn forgetTemplateStorage(isolate: *v8.Isolate) void {
    endStorage(isolate, false);
}

fn endStorage(isolate: *v8.Isolate, dispose: bool) void {
    const storage = getTemplateStorage(isolate) orelse return;
    v8.v8_Isolate_SetData(isolate, TEMPLATE_SLOT, null);
    // The storage's own allocator: the isolate's, or the C allocator for an
    // isolate without one.
    const storage_allocator = storage.allocator;
    storage.deinit(dispose);
    storage_allocator.destroy(storage);
}
