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
        registry: ?*runtime.Instance = null,
        agent_definition_count: ?*usize = null,

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

        pub fn retain(self: *Self) *Self {
            self.references += 1;
            return self;
        }

        /// Registry, element and upgrade reactions each release their own hold.
        pub fn deinit(self: *Self) void {
            std.debug.assert(self.references != 0);
            self.references -= 1;
            if (self.references != 0) return;
            if (self.agent_definition_count) |count| count.* -= 1;
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
