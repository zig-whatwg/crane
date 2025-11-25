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
/// ## Parameters
/// - instance: The Zig instance to wrap
/// - interface_name: Name of the interface (e.g., "Element", "Document")
/// - isolate: V8 isolate
/// - context: V8 context
///
/// ## Returns
/// A V8 Object wrapping the instance, or error if template not found
pub fn wrapInstanceAsV8Object(
    instance: *runtime.Instance,
    interface_name: []const u8,
    isolate: *v8.Isolate,
    context: *v8.Context,
) !*v8.Object {
    _ = isolate; // May be needed for future error handling

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

    return v8_object;
}

/// Get the interface name from an Instance
///
/// This looks at the instance's vtable to determine which interface it belongs to.
/// Currently uses a heuristic based on vtable address matching.
/// TODO: Store interface name directly in Instance or VTable
pub fn getInstanceInterfaceName(instance: *runtime.Instance) []const u8 {
    // For now, we need to determine the interface from the vtable
    // This is a temporary solution - ideally the vtable or instance would store the name

    // Check against known vtable addresses
    // This will be populated by codegen in the future

    // Default to "Element" for now (most common case for createElement)
    // The proper fix is to store the interface name in the instance or vtable
    _ = instance;
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
