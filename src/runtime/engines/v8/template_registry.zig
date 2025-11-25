//! V8 Template Registry
//!
//! Runtime registry for V8 FunctionTemplates, enabling dynamic wrapping
//! of Zig instances into properly typed V8 objects.
//!
//! ## Problem Solved
//!
//! When a Zig method returns `*runtime.Instance` (e.g., Document.createElement
//! returning an Element), we need to wrap it in a V8 object with the correct
//! prototype chain. This requires:
//!
//! 1. Looking up the interface name from the instance
//! 2. Finding the FunctionTemplate for that interface
//! 3. Creating a new V8 object with that template
//! 4. Storing the Zig instance in the object's internal fields
//!
//! ## Usage
//!
//! During interface registration (V8Interface.registerGlobal):
//! ```zig
//! template_registry.register(interface_name, template, isolate);
//! ```
//!
//! When wrapping an instance for return to JavaScript:
//! ```zig
//! const v8_obj = try template_registry.wrapInstanceAsV8Object(
//!     instance,
//!     "Element",
//!     isolate,
//!     context,
//! );
//! ```

const std = @import("std");
const v8 = @import("ffi.zig");
const runtime = @import("runtime");
const wrapper_type_info = @import("wrapper_type_info.zig");
const dom_type_info = @import("dom_type_info.zig");

/// Maximum number of interface templates that can be registered
const MAX_TEMPLATES = 2048; // Need to support all WebIDL interfaces (~1100)

/// Entry in the template registry
const TemplateEntry = struct {
    name: []const u8,
    template: *v8.FunctionTemplate,
    isolate: *v8.Isolate,
};

/// Global template registry
/// Maps interface names to their FunctionTemplates
var templates: [MAX_TEMPLATES]?TemplateEntry = [_]?TemplateEntry{null} ** MAX_TEMPLATES;
var template_count: usize = 0;
var initialized: bool = false;

/// Initialize the registry (called automatically on first use)
fn ensureInitialized() void {
    if (!initialized) {
        initialized = true;
    }
}

/// Register a FunctionTemplate for an interface
///
/// Called by V8Interface.registerGlobal after creating the template.
/// This allows later wrapping of instances via wrapInstanceAsV8Object.
pub fn register(
    interface_name: []const u8,
    template: *v8.FunctionTemplate,
    isolate: *v8.Isolate,
) void {
    ensureInitialized();

    // Check if already registered (avoid duplicates on re-registration)
    for (&templates) |*entry| {
        if (entry.*) |*e| {
            if (std.mem.eql(u8, e.name, interface_name)) {
                // Update existing entry
                e.template = template;
                e.isolate = isolate;
                return;
            }
        }
    }

    // Add new entry
    if (template_count < MAX_TEMPLATES) {
        templates[template_count] = .{
            .name = interface_name,
            .template = template,
            .isolate = isolate,
        };
        template_count += 1;
    }
}

/// Get a registered FunctionTemplate by interface name
pub fn getTemplate(interface_name: []const u8) ?*v8.FunctionTemplate {
    ensureInitialized();

    // Only iterate over registered templates, not the full array
    for (templates[0..template_count]) |entry| {
        if (entry) |e| {
            if (std.mem.eql(u8, e.name, interface_name)) {
                return e.template;
            }
        }
    }
    return null;
}

/// Wrap a Zig runtime.Instance into a V8 Object with the correct prototype
///
/// This is the key function for returning interface instances from methods.
/// It creates a V8 object with the correct FunctionTemplate (prototype chain)
/// and stores the Zig instance pointer in the internal fields.
///
/// **Now with wrapper identity caching!** Returns the same V8 wrapper for the
/// same Zig instance, solving the querySelector identity problem.
///
/// ## Parameters
/// - instance: The Zig instance to wrap
/// - interface_name: Name of the interface (e.g., "Element", "Document")
/// - isolate: V8 isolate
/// - context: V8 context
///
/// ## Returns
/// A V8 Object wrapping the instance (cached if already wrapped, new if first time)
pub fn wrapInstanceAsV8Object(
    instance: *runtime.Instance,
    interface_name: []const u8,
    isolate: *v8.Isolate,
    context: *v8.Context,
) !*v8.Object {
    // ========================================
    // CACHE LOOKUP: Check if we already have a wrapper for this instance
    // ========================================
    const ctx_mgr = @import("context_manager.zig");
    if (ctx_mgr.get(context)) |runtime_ctx| {
        if (runtime_ctx.getV8WrapperCacheStorage()) |cache_storage| {
            const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
            const cache: *WrapperCache = @ptrCast(@alignCast(cache_storage));

            // Cache hit? Return existing wrapper (same V8 object)
            if (cache.get(instance)) |cached_wrapper| {
                return cached_wrapper;
            }
        }
    }

    // ========================================
    // CACHE MISS: Create new wrapper
    // ========================================

    // Look up the FunctionTemplate for this interface
    const template = getTemplate(interface_name) orelse {
        // Template not registered - this shouldn't happen for core interfaces
        // but can happen for interfaces not yet implemented
        return error.TemplateNotRegistered;
    };

    // Get the InstanceTemplate from the FunctionTemplate
    const instance_template = v8.v8_FunctionTemplate_InstanceTemplate(template);

    // Create a new V8 object from the template
    // This creates an object with the correct prototype chain and internal fields
    const v8_object = v8.v8_ObjectTemplate_NewInstance(instance_template, context);

    // Store the Zig instance in internal field 0
    v8.v8_Object_SetAlignedPointerInInternalField(
        v8_object,
        0,
        @ptrCast(instance),
    );

    // Store WrapperTypeInfo in internal field 1 (for type-safe unwrapping)
    if (dom_type_info.getTypeInfoByName(interface_name)) |type_info| {
        v8.v8_Object_SetAlignedPointerInInternalField(
            v8_object,
            1,
            @ptrCast(@constCast(type_info)),
        );
    }

    // ========================================
    // CACHE THE WRAPPER: Store for future lookups
    // ========================================
    if (ctx_mgr.get(context)) |runtime_ctx| {
        if (runtime_ctx.getV8WrapperCacheStorage()) |cache_storage| {
            const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
            const cache: *WrapperCache = @ptrCast(@alignCast(cache_storage));

            // Cache the wrapper (log but don't fail if caching fails)
            cache.set(instance, v8_object, isolate) catch |err| {
                std.log.warn("Failed to cache V8 wrapper: {s}", .{@errorName(err)});
            };
        }
    }

    return v8_object;
}

/// Get the interface name from an Instance
///
/// This looks at the instance's vtable to determine which interface it belongs to.
/// Compares vtable addresses against known vtables to identify the interface.
pub fn getInstanceInterfaceName(instance: *runtime.Instance) []const u8 {
    // Import generated interfaces to get their vtables
    const interfaces = @import("interfaces");

    // Get the instance's vtable address
    const inst_vtable = instance.vtable;

    // Compare against known vtable addresses
    // NOTE: This compares pointer addresses, which works because vtables are comptime constants

    // Check NodeList first (most common for querySelectorAll)
    if (inst_vtable == &interfaces.NodeList.vtable) {
        return "NodeList";
    }

    // Check Element and subclasses
    if (inst_vtable == &interfaces.Element.vtable) {
        return "Element";
    }

    if (inst_vtable == &interfaces.HTMLElement.vtable) {
        return "HTMLElement";
    }

    // Check Document
    if (inst_vtable == &interfaces.Document.vtable) {
        return "Document";
    }

    // Check other common types
    if (inst_vtable == &interfaces.Text.vtable) {
        return "Text";
    }

    if (inst_vtable == &interfaces.Comment.vtable) {
        return "Comment";
    }

    if (inst_vtable == &interfaces.DocumentFragment.vtable) {
        return "DocumentFragment";
    }

    if (inst_vtable == &interfaces.Attr.vtable) {
        return "Attr";
    }

    if (inst_vtable == &interfaces.CharacterData.vtable) {
        return "CharacterData";
    }

    if (inst_vtable == &interfaces.ProcessingInstruction.vtable) {
        return "ProcessingInstruction";
    }

    if (inst_vtable == &interfaces.CDATASection.vtable) {
        return "CDATASection";
    }

    if (inst_vtable == &interfaces.DocumentType.vtable) {
        return "DocumentType";
    }

    // Default to "Element" for unknown types (backwards compat)
    return "Element";
}

// ============================================================================
// Tests
// ============================================================================

test "template_registry basic operations" {
    // This test would require V8 initialization, so we just test the registry logic
    ensureInitialized();

    // Verify initial state
    const template = getTemplate("NonExistent");
    try std.testing.expectEqual(@as(?*v8.FunctionTemplate, null), template);
}
