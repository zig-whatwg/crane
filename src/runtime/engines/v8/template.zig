//! V8 FunctionTemplate Generation for WebIDL
//!
//! Generates V8 FunctionTemplate for each WebIDL interface:
//! - Constructor function
//! - Prototype properties (attributes via setAccessor)
//! - Prototype methods (operations via FunctionTemplate)
//! - Inheritance support (via V8 inherit())
//!
//! Based on patterns from zig-js-runtime (Lightpanda headless browser).
//!
//! ## Architecture
//!
//! Each WebIDL interface generates:
//! ```
//! FunctionTemplate (Constructor)
//!   ├─ InstanceTemplate (holds internal fields)
//!   └─ PrototypeTemplate (holds properties/methods)
//!       ├─ Accessor: attribute1 (getter/setter)
//!       ├─ Accessor: attribute2 (getter/setter)
//!       ├─ Method: operation1
//!       └─ Method: operation2
//! ```
//!
//! ## Inheritance
//!
//! WebIDL inheritance maps to V8 prototype chain:
//! ```
//! interface Element : Node {
//!   attribute DOMString id;
//! };
//!
//! ElementTemplate.inherit(NodeTemplate)
//! → Element.prototype.__proto__ === Node.prototype
//! ```
//!
//! ## Usage
//!
//! ```zig
//! const template_gen = @import("runtime").v8_template;
//!
//! // Create template for Element interface
//! var builder = template_gen.TemplateBuilder.init(allocator, ctx);
//! defer builder.deinit();
//!
//! try builder.setName("Element");
//! try builder.setConstructor(elementConstructor);
//! try builder.addAttribute("id", idGetter, idSetter);
//! try builder.addAttribute("tagName", tagNameGetter, null);
//! try builder.addMethod("getAttribute", getAttributeMethod);
//! try builder.setInheritance("Node");
//!
//! const template = try builder.build();
//! ```

const std = @import("std");
const V8Context = @import("context.zig").V8Context;
const callbacks = @import("callbacks/root.zig");

/// Attribute descriptor
///
/// Describes a WebIDL attribute mapped to V8 accessor.
/// In real V8: v8::ObjectTemplate::SetAccessor()
pub const AttributeDescriptor = struct {
    name: []const u8,
    getter: ?callbacks.GetterCallback,
    setter: ?callbacks.SetterCallback,

    /// Check if attribute is read-only
    pub fn isReadOnly(self: AttributeDescriptor) bool {
        return self.setter == null;
    }
};

/// Method descriptor
///
/// Describes a WebIDL operation mapped to V8 FunctionTemplate.
/// In real V8: v8::FunctionTemplate::New() added to PrototypeTemplate
pub const MethodDescriptor = struct {
    name: []const u8,
    callback: callbacks.MethodCallback,
};

/// FunctionTemplate builder
///
/// Builds V8 FunctionTemplate for a WebIDL interface.
/// In real V8, this would use:
/// - v8::FunctionTemplate::New() for constructor
/// - v8::ObjectTemplate::SetAccessor() for attributes
/// - v8::FunctionTemplate::PrototypeTemplate() for methods
/// - v8::FunctionTemplate::Inherit() for inheritance
pub const TemplateBuilder = struct {
    allocator: std.mem.Allocator,
    v8_ctx: *V8Context,

    interface_name: ?[]const u8,
    constructor: ?callbacks.ConstructorCallback,
    attributes: std.ArrayList(AttributeDescriptor),
    methods: std.ArrayList(MethodDescriptor),
    parent_interface: ?[]const u8,

    /// Initialize template builder
    pub fn init(allocator: std.mem.Allocator, v8_ctx: *V8Context) TemplateBuilder {
        return .{
            .allocator = allocator,
            .v8_ctx = v8_ctx,
            .interface_name = null,
            .constructor = null,
            .attributes = std.ArrayList(AttributeDescriptor).init(allocator),
            .methods = std.ArrayList(MethodDescriptor).init(allocator),
            .parent_interface = null,
        };
    }

    /// Deinitialize builder
    pub fn deinit(self: *TemplateBuilder) void {
        self.methods.deinit();
        self.attributes.deinit();
    }

    /// Set interface name
    pub fn setName(self: *TemplateBuilder, name: []const u8) !void {
        self.interface_name = name;
    }

    /// Set constructor callback
    pub fn setConstructor(self: *TemplateBuilder, ctor: callbacks.ConstructorCallback) !void {
        self.constructor = ctor;
    }

    /// Add attribute (property with getter/setter)
    pub fn addAttribute(
        self: *TemplateBuilder,
        name: []const u8,
        getter: ?callbacks.GetterCallback,
        setter: ?callbacks.SetterCallback,
    ) !void {
        try self.attributes.append(.{
            .name = name,
            .getter = getter,
            .setter = setter,
        });
    }

    /// Add method (operation)
    pub fn addMethod(
        self: *TemplateBuilder,
        name: []const u8,
        method: callbacks.MethodCallback,
    ) !void {
        try self.methods.append(.{
            .name = name,
            .callback = method,
        });
    }

    /// Set parent interface for inheritance
    pub fn setInheritance(self: *TemplateBuilder, parent_name: []const u8) !void {
        self.parent_interface = parent_name;
    }

    /// Build FunctionTemplate
    ///
    /// Creates V8 FunctionTemplate with:
    /// - Constructor callback
    /// - Prototype attributes (setAccessor)
    /// - Prototype methods (FunctionTemplate)
    /// - Inheritance chain
    ///
    /// In real V8, this would:
    /// ```c++
    /// auto tpl = v8::FunctionTemplate::New(isolate, constructor);
    /// tpl->SetClassName(v8::String::NewFromUtf8(isolate, name));
    ///
    /// auto proto = tpl->PrototypeTemplate();
    /// proto->SetAccessor(name, getter, setter);
    /// proto->Set(method_name, v8::FunctionTemplate::New(isolate, method));
    ///
    /// if (parent) tpl->Inherit(parent);
    /// ```
    pub fn build(self: *TemplateBuilder) !Template {
        const name = self.interface_name orelse return error.NoInterfaceName;
        const ctor = self.constructor orelse return error.NoConstructor;

        // In real V8 integration, create FunctionTemplate here
        // For now, use mock template handle
        const template_handle = @intFromPtr(self.v8_ctx); // Mock

        // Cache template
        try self.v8_ctx.cacheTemplate(name, template_handle);

        // Build template descriptor
        return .{
            .name = name,
            .handle = template_handle,
            .constructor = ctor,
            .attributes = try self.attributes.toOwnedSlice(),
            .methods = try self.methods.toOwnedSlice(),
            .parent_interface = self.parent_interface,
        };
    }
};

/// FunctionTemplate descriptor
///
/// Represents a complete V8 FunctionTemplate for a WebIDL interface.
/// In real V8, this would hold v8::Local<v8::FunctionTemplate> handle.
pub const Template = struct {
    name: []const u8,
    handle: usize, // In real V8: v8::Local<v8::FunctionTemplate> handle
    constructor: callbacks.ConstructorCallback,
    attributes: []AttributeDescriptor,
    methods: []MethodDescriptor,
    parent_interface: ?[]const u8,

    /// Get attribute descriptor by name
    pub fn getAttribute(self: Template, name: []const u8) ?AttributeDescriptor {
        for (self.attributes) |attr| {
            if (std.mem.eql(u8, attr.name, name)) {
                return attr;
            }
        }
        return null;
    }

    /// Get method descriptor by name
    pub fn getMethod(self: Template, name: []const u8) ?MethodDescriptor {
        for (self.methods) |method| {
            if (std.mem.eql(u8, method.name, name)) {
                return method;
            }
        }
        return null;
    }

    /// Check if interface has inheritance
    pub fn hasInheritance(self: Template) bool {
        return self.parent_interface != null;
    }
};

/// Template registry
///
/// Manages all FunctionTemplates for WebIDL interfaces.
/// Handles inheritance relationships and template lookup.
pub const TemplateRegistry = struct {
    allocator: std.mem.Allocator,
    templates: std.StringHashMap(Template),

    /// Initialize registry
    pub fn init(allocator: std.mem.Allocator) TemplateRegistry {
        return .{
            .allocator = allocator,
            .templates = std.StringHashMap(Template).init(allocator),
        };
    }

    /// Deinitialize registry
    pub fn deinit(self: *TemplateRegistry) void {
        // Free template slices
        var iter = self.templates.valueIterator();
        while (iter.next()) |template| {
            self.allocator.free(template.attributes);
            self.allocator.free(template.methods);
        }
        self.templates.deinit();
    }

    /// Register template
    pub fn register(self: *TemplateRegistry, template: Template) !void {
        // Duplicate name since StringHashMap doesn't own keys
        const name_copy = try self.allocator.dupe(u8, template.name);
        try self.templates.put(name_copy, template);
    }

    /// Get template by interface name
    pub fn get(self: *const TemplateRegistry, name: []const u8) ?Template {
        return self.templates.get(name);
    }

    /// Check if interface is registered
    pub fn has(self: *const TemplateRegistry, name: []const u8) bool {
        return self.templates.contains(name);
    }

    /// Get all interfaces that inherit from parent
    pub fn getChildren(
        self: *const TemplateRegistry,
        allocator: std.mem.Allocator,
        parent_name: []const u8,
    ) ![][]const u8 {
        var children = std.ArrayList([]const u8).init(allocator);

        var iter = self.templates.iterator();
        while (iter.next()) |entry| {
            const template = entry.value_ptr.*;
            if (template.parent_interface) |parent| {
                if (std.mem.eql(u8, parent, parent_name)) {
                    try children.append(template.name);
                }
            }
        }

        return children.toOwnedSlice();
    }

    /// Get inheritance chain for interface
    ///
    /// Returns array: [Interface, Parent, Grandparent, ...]
    pub fn getInheritanceChain(
        self: *const TemplateRegistry,
        allocator: std.mem.Allocator,
        interface_name: []const u8,
    ) ![][]const u8 {
        var chain = std.ArrayList([]const u8).init(allocator);

        var current = interface_name;
        while (true) {
            try chain.append(current);

            const template = self.get(current) orelse break;
            const parent = template.parent_interface orelse break;

            current = parent;
        }

        return chain.toOwnedSlice();
    }
};

// Unit tests

const testing = std.testing;

fn mockGetter(instance: *@import("../../instance.zig").Instance) !usize {
    _ = instance;
    return 0x1234;
}

fn mockSetter(instance: *@import("../../instance.zig").Instance, value: usize) !void {
    _ = instance;
    _ = value;
}

fn mockMethod(instance: *@import("../../instance.zig").Instance, args: []const usize) !?usize {
    _ = instance;
    _ = args;
    return 0x5678;
}

fn mockInit(allocator: std.mem.Allocator, ctx: ?*anyopaque) !*@import("../../instance.zig").Instance {
    _ = ctx;
    const inst = try allocator.create(@import("../../instance.zig").Instance);
    inst.* = .{ .vtable = undefined, .state = null, .ctx = null };
    return inst;
}

test "TemplateBuilder builds template with attributes and methods" {
    const ctx = try V8Context.init(testing.allocator);
    defer ctx.deinit();

    var builder = TemplateBuilder.init(testing.allocator, ctx);
    defer builder.deinit();

    try builder.setName("Element");
    try builder.setConstructor(.{
        .interface_name = "Element",
        .init_fn = mockInit,
    });

    try builder.addAttribute("id", .{
        .property_name = "id",
        .getter_fn = mockGetter,
    }, .{
        .property_name = "id",
        .setter_fn = mockSetter,
    });

    try builder.addAttribute("tagName", .{
        .property_name = "tagName",
        .getter_fn = mockGetter,
    }, null);

    try builder.addMethod("getAttribute", .{
        .method_name = "getAttribute",
        .method_fn = mockMethod,
    });

    const template = try builder.build();

    try testing.expectEqualStrings("Element", template.name);
    try testing.expectEqual(@as(usize, 2), template.attributes.len);
    try testing.expectEqual(@as(usize, 1), template.methods.len);

    // Free template slices
    testing.allocator.free(template.attributes);
    testing.allocator.free(template.methods);
}

test "Template getAttribute returns correct descriptor" {
    const ctx = try V8Context.init(testing.allocator);
    defer ctx.deinit();

    var builder = TemplateBuilder.init(testing.allocator, ctx);
    defer builder.deinit();

    try builder.setName("Element");
    try builder.setConstructor(.{
        .interface_name = "Element",
        .init_fn = mockInit,
    });

    try builder.addAttribute("id", .{
        .property_name = "id",
        .getter_fn = mockGetter,
    }, null);

    const template = try builder.build();
    defer testing.allocator.free(template.attributes);
    defer testing.allocator.free(template.methods);

    const attr = template.getAttribute("id");
    try testing.expect(attr != null);
    try testing.expectEqualStrings("id", attr.?.name);
    try testing.expect(attr.?.isReadOnly());
}

test "Template getMethod returns correct descriptor" {
    const ctx = try V8Context.init(testing.allocator);
    defer ctx.deinit();

    var builder = TemplateBuilder.init(testing.allocator, ctx);
    defer builder.deinit();

    try builder.setName("Element");
    try builder.setConstructor(.{
        .interface_name = "Element",
        .init_fn = mockInit,
    });

    try builder.addMethod("getAttribute", .{
        .method_name = "getAttribute",
        .method_fn = mockMethod,
    });

    const template = try builder.build();
    defer testing.allocator.free(template.attributes);
    defer testing.allocator.free(template.methods);

    const method = template.getMethod("getAttribute");
    try testing.expect(method != null);
    try testing.expectEqualStrings("getAttribute", method.?.name);
}

test "TemplateRegistry register and get" {
    const ctx = try V8Context.init(testing.allocator);
    defer ctx.deinit();

    var registry = TemplateRegistry.init(testing.allocator);
    defer registry.deinit();

    var builder = TemplateBuilder.init(testing.allocator, ctx);
    defer builder.deinit();

    try builder.setName("Element");
    try builder.setConstructor(.{
        .interface_name = "Element",
        .init_fn = mockInit,
    });

    const template = try builder.build();
    try registry.register(template);

    const retrieved = registry.get("Element");
    try testing.expect(retrieved != null);
    try testing.expectEqualStrings("Element", retrieved.?.name);
}

test "TemplateRegistry getChildren returns interfaces that inherit" {
    const ctx = try V8Context.init(testing.allocator);
    defer ctx.deinit();

    var registry = TemplateRegistry.init(testing.allocator);
    defer registry.deinit();

    // Create Node (parent)
    {
        var builder = TemplateBuilder.init(testing.allocator, ctx);
        defer builder.deinit();

        try builder.setName("Node");
        try builder.setConstructor(.{
            .interface_name = "Node",
            .init_fn = mockInit,
        });

        const template = try builder.build();
        try registry.register(template);
    }

    // Create Element (child of Node)
    {
        var builder = TemplateBuilder.init(testing.allocator, ctx);
        defer builder.deinit();

        try builder.setName("Element");
        try builder.setConstructor(.{
            .interface_name = "Element",
            .init_fn = mockInit,
        });
        try builder.setInheritance("Node");

        const template = try builder.build();
        try registry.register(template);
    }

    // Create Document (child of Node)
    {
        var builder = TemplateBuilder.init(testing.allocator, ctx);
        defer builder.deinit();

        try builder.setName("Document");
        try builder.setConstructor(.{
            .interface_name = "Document",
            .init_fn = mockInit,
        });
        try builder.setInheritance("Node");

        const template = try builder.build();
        try registry.register(template);
    }

    const children = try registry.getChildren(testing.allocator, "Node");
    defer testing.allocator.free(children);

    try testing.expectEqual(@as(usize, 2), children.len);
}

test "TemplateRegistry getInheritanceChain returns full chain" {
    const ctx = try V8Context.init(testing.allocator);
    defer ctx.deinit();

    var registry = TemplateRegistry.init(testing.allocator);
    defer registry.deinit();

    // Create EventTarget (root)
    {
        var builder = TemplateBuilder.init(testing.allocator, ctx);
        defer builder.deinit();

        try builder.setName("EventTarget");
        try builder.setConstructor(.{
            .interface_name = "EventTarget",
            .init_fn = mockInit,
        });

        const template = try builder.build();
        try registry.register(template);
    }

    // Create Node (child of EventTarget)
    {
        var builder = TemplateBuilder.init(testing.allocator, ctx);
        defer builder.deinit();

        try builder.setName("Node");
        try builder.setConstructor(.{
            .interface_name = "Node",
            .init_fn = mockInit,
        });
        try builder.setInheritance("EventTarget");

        const template = try builder.build();
        try registry.register(template);
    }

    // Create Element (child of Node)
    {
        var builder = TemplateBuilder.init(testing.allocator, ctx);
        defer builder.deinit();

        try builder.setName("Element");
        try builder.setConstructor(.{
            .interface_name = "Element",
            .init_fn = mockInit,
        });
        try builder.setInheritance("Node");

        const template = try builder.build();
        try registry.register(template);
    }

    const chain = try registry.getInheritanceChain(testing.allocator, "Element");
    defer testing.allocator.free(chain);

    try testing.expectEqual(@as(usize, 3), chain.len);
    try testing.expectEqualStrings("Element", chain[0]);
    try testing.expectEqualStrings("Node", chain[1]);
    try testing.expectEqualStrings("EventTarget", chain[2]);
}
