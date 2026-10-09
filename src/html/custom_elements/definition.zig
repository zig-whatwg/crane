//! HTML §4.13.3: the definition shared by the registry, elements and upgrades.
//! Parameters keep the declaration usable through html_core without adding
//! an engine dependency to that module's engine-free users.
const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Definition(comptime runtime: type, comptime engine: type) type {
    return struct {
        const Self = @This();
        name: []const u8,
        local_name: []const u8,
        /// OWNED WebIDL callback, including the context of its conversion.
        constructor: engine.CallbackFunction,
        observed_attributes: []const []const u8,
        lifecycle_callbacks: LifecycleCallbacks,
        form_associated: bool,
        disable_internals: bool,
        disable_shadow: bool,
        construction_stack: std.ArrayListUnmanaged(ConstructionStackEntry) = .empty,
        allocator: Allocator,
        references: usize = 1,
        /// The registry this definition is in; set with `setRegistry`, read
        /// with `liveRegistry`.
        registry: ?*runtime.Instance = null,
        registry_generation: u64 = 0,
        /// The registry's realm (a runtime.Context; opaque so this type stays
        /// usable with a runtime that has none, as engine-free tests do).
        registry_realm: ?*anyopaque = null,
        agent_definition_count: ?*usize = null,
        agent_form_definition_count: ?*usize = null,

        pub const ConstructionStackEntry = union(enum) {
            element: *runtime.Instance,
            already_constructed: void,
        };

        pub const LifecycleCallbacks = struct {
            connectedCallback: ?engine.CallbackFunction = null,
            disconnectedCallback: ?engine.CallbackFunction = null,
            adoptedCallback: ?engine.CallbackFunction = null,
            connectedMoveCallback: ?engine.CallbackFunction = null,
            attributeChangedCallback: ?engine.CallbackFunction = null,
            formAssociatedCallback: ?engine.CallbackFunction = null,
            formResetCallback: ?engine.CallbackFunction = null,
            formDisabledCallback: ?engine.CallbackFunction = null,
            formStateRestoreCallback: ?engine.CallbackFunction = null,

            pub fn deinit(self: *LifecycleCallbacks, allocator: Allocator) void {
                _ = allocator;
                inline for (std.meta.fields(LifecycleCallbacks)) |field| {
                    if (@field(self, field.name)) |callback| callback.release();
                    @field(self, field.name) = null;
                }
            }
        };

        /// Takes constructor on success; other exits leave it with the caller.
        pub fn init(allocator: Allocator, name: []const u8, local_name: []const u8, constructor: engine.CallbackFunction) !*Self {
            const definition = try allocator.create(Self);
            errdefer allocator.destroy(definition);
            const owned_name = try allocator.dupe(u8, name);
            errdefer allocator.free(owned_name);
            definition.* = .{
                .name = owned_name,
                .local_name = try allocator.dupe(u8, local_name),
                .constructor = constructor,
                .observed_attributes = &.{},
                .lifecycle_callbacks = .{},
                .form_associated = false,
                .disable_internals = false,
                .disable_shadow = false,
                .allocator = allocator,
            };
            return definition;
        }

        /// Record the registry this definition was added to (HTML define()
        /// step 16), with its slab generation and realm (PR-N1).
        ///
        /// What keeps the registry alive is tracing, never this pointer: the
        /// Window holds its global registry, and a scoped registry is held by
        /// the traced edges of the nodes associated with it (and of a
        /// document it was initialized on - dom.custom_elements
        /// RegistryAssociation). The generation is a safety net for teardown
        /// order only: a definition that outlives its registry - an element
        /// or a queued upgrade retains it - reads none (`liveRegistry`), and
        /// the constructor that needs it fails with InvalidStateError rather
        /// than touching the slot. A check failing here must never be how a
        /// live page loses an upgrade; if one does, the registry's keeper
        /// went missing, and that is the bug.
        pub fn setRegistry(self: *Self, registry: *runtime.Instance) void {
            self.registry = registry;
            self.registry_generation = runtime.SlabAllocator.generationOf(registry);
            self.registry_realm = registry.ctx;
        }

        /// The registry while it is still the one recorded: its slot not
        /// freed or reissued, not torn down, its realm not ended (a context
        /// that never had an engine has no realm to end). Never dereferences
        /// a registry that is gone.
        pub fn liveRegistry(self: *const Self) ?*runtime.Instance {
            const registry = self.registry orelse return null;
            if (runtime.SlabAllocator.generationOf(registry) != self.registry_generation) return null;
            if (runtime.instance_lifecycle.isCleanedUp(registry)) return null;
            if (self.registry_realm) |opaque_realm| {
                const realm: runtime.Context = @ptrCast(@alignCast(opaque_realm));
                if (!realm.hasEngine() and realm.agent != null) return null;
            }
            return registry;
        }

        pub fn retain(self: *Self) *Self {
            self.references += 1;
            return self;
        }

        /// HTMLConstructor steps 9, 12–13 and 15. The adapter has completed
        /// prototype access before this non-script step (HostHooks contract).
        /// An upgrade owns the entry until it pops it, including on failure.
        pub fn takeConstructionElement(self: *Self) error{TypeError}!?*runtime.Instance {
            if (self.construction_stack.items.len == 0) return null;
            const entry = &self.construction_stack.items[self.construction_stack.items.len - 1];
            const element = switch (entry.*) {
                .already_constructed => return error.TypeError,
                .element => |element| element,
            };
            entry.* = .already_constructed;
            return element;
        }

        /// Registry, element and upgrade reactions each release their own hold.
        pub fn deinit(self: *Self) void {
            std.debug.assert(self.references != 0);
            self.references -= 1;
            if (self.references != 0) return;
            if (self.agent_definition_count) |count| count.* -= 1;
            if (self.agent_form_definition_count) |count| count.* -= 1;
            self.allocator.free(self.name);
            self.allocator.free(self.local_name);
            for (self.observed_attributes) |attribute| self.allocator.free(attribute);
            if (self.observed_attributes.len != 0) self.allocator.free(self.observed_attributes);
            self.construction_stack.deinit(self.allocator);
            self.lifecycle_callbacks.deinit(self.allocator);
            self.constructor.release();
            self.allocator.destroy(self);
        }
    };
}
