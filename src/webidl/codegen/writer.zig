//! WebIDL Code Writer
//!
//! This module provides functions for writing generated Zig code from WebIDL definitions.

const std = @import("std");
const types = @import("types.zig");
const overload = @import("overload.zig");
const property_classifier = @import("property_classifier.zig");
const ir = @import("ir.zig");

/// Check if a union type is a (TrustedType or DOMString/USVString) pattern
/// These unions are used for Trusted Types API integration but since TrustedTypes
/// are not yet implemented, we treat them as plain DOMString/USVString.
///
/// Matches patterns like:
/// - (TrustedType or DOMString)
/// - (TrustedHTML or DOMString)
/// - (TrustedScript or DOMString)
/// - (TrustedScriptURL or USVString)
fn isTrustedTypeOrStringUnion(union_types: []const types.IDLType) bool {
    if (union_types.len != 2) return false;

    var has_trusted_type = false;
    var has_string = false;

    for (union_types) |ut| {
        const t = ut.type;
        // Check for TrustedTypes (not yet implemented, treat as string)
        if (std.mem.eql(u8, t, "TrustedType")) has_trusted_type = true;
        if (std.mem.eql(u8, t, "TrustedHTML")) has_trusted_type = true;
        if (std.mem.eql(u8, t, "TrustedScript")) has_trusted_type = true;
        if (std.mem.eql(u8, t, "TrustedScriptURL")) has_trusted_type = true;
        // Check for string types
        if (std.mem.eql(u8, t, "DOMString")) has_string = true;
        if (std.mem.eql(u8, t, "USVString")) has_string = true;
    }

    return has_trusted_type and has_string;
}

/// Check if a union type is the (Node or DOMString) pattern used by DOM mutation methods
/// This pattern is used by ParentNode.prepend/append/replaceChildren and ChildNode.before/after/replaceWith
fn isNodeOrDOMStringUnion(union_types: []const types.IDLType) bool {
    if (union_types.len != 2) return false;

    var has_node = false;
    var has_string = false;

    for (union_types) |ut| {
        const t = ut.type;
        if (std.mem.eql(u8, t, "Node")) has_node = true;
        if (std.mem.eql(u8, t, "DOMString")) has_string = true;
        // Also handle TrustedScript variant used in some specs
        if (std.mem.eql(u8, t, "TrustedScript")) has_string = true;
    }

    return has_node and has_string;
}

/// Write a file header comment with source information and timestamp
///
/// Example output:
/// ```zig
/// //! Generated from: dom.json
/// //! Specification: https://dom.spec.whatwg.org/
/// //!
/// //! This file is AUTO-GENERATED. Do not edit manually.
/// ```
pub fn writeHeader(
    writer: anytype,
    source_file: []const u8,
    spec_url: ?[]const u8,
) !void {
    // Write header comment
    try writer.print("//! Generated from: {s}\n", .{source_file});

    if (spec_url) |url| {
        try writer.print("//! Specification: {s}\n", .{url});
    }

    try writer.writeAll("//!\n");
    try writer.writeAll("//! This file is AUTO-GENERATED. Do not edit manually.\n");
    try writer.writeAll("\n");
}

/// Write import statements for a generated interface file
///
/// Example output:
/// ```zig
/// const std = @import("std");
/// const runtime = @import("runtime");
/// const ElementImpl = @import("impls").Element;
/// const Node = @import("interfaces").Node;
/// const GLenum = @import("typedefs").GLenum;
/// const CustomEventInit = @import("dictionaries").CustomEventInit;
/// ```
pub fn writeImports(
    writer: anytype,
    interface_name: []const u8,
    base_type: ?[]const u8,
    mixins: []const []const u8,
    referenced_interfaces: []const []const u8,
    type_registry: ?*const @import("ir.zig").TypeRegistry,
) !void {
    try writer.writeAll("const std = @import(\"std\");\n");
    try writer.writeAll("const runtime = @import(\"runtime\");\n");
    try writer.writeAll("const webidl = @import(\"webidl\");\n");
    // NOTE: v8 import removed - use runtime.JSValue instead of v8.JSValue

    // Import implementation from "impls" module
    try writer.print("const {s}Impl = @import(\"impls\").{s};\n", .{ interface_name, interface_name });

    // Import mixins module (for ParentNode.NodeOrString and other mixin types)
    try writer.writeAll("const mixins = @import(\"mixins\");\n");

    // Import type category modules for State struct field types
    // These are needed because State uses fully-qualified type paths (e.g., typedefs.DOMString)
    try writer.writeAll("const typedefs = @import(\"typedefs\");\n");
    try writer.writeAll("const enums = @import(\"enums\");\n");
    try writer.writeAll("const dictionaries = @import(\"dictionaries\");\n");

    // Track which types we've already imported to avoid duplicates
    var imported = std.StringHashMap(void).init(std.heap.page_allocator);
    defer imported.deinit();

    // JavaScript built-in types (provided by V8, available from runtime)
    const js_builtins = [_][]const u8{
        "ArrayBuffer",
        "SharedArrayBuffer",
        "DataView",
        "Int8Array",
        "Int16Array",
        "Int32Array",
        "Uint8Array",
        "Uint8ClampedArray",
        "Uint16Array",
        "Uint32Array",
        "Float32Array",
        "Float64Array",
        "BigInt64Array",
        "BigUint64Array",
    };

    // WebIDL primitives that should NOT be imported
    // These are mapped to Zig types directly (u32, i32, bool, etc.)
    // NOTE: DOMString, USVString, ByteString are typedefs and SHOULD be imported
    const primitive_types = [_][]const u8{
        // WebIDL primitives (with and without spaces - parser may collapse them)
        "void",
        "undefined",
        "boolean",
        "byte",
        "octet",
        "short",
        "long",
        "float",
        "double",
        "any",
        "object",
        "symbol",
        // Compound primitives without spaces (parser may collapse spaces)
        "unsignedshort",
        "unsignedlong",
        "longlong",
        "unsignedlonglong",
        "unrestrictedfloat",
        "unrestricteddouble",
    };

    // Helper to check if a type is a JS built-in
    const isJsBuiltin = struct {
        fn call(type_name: []const u8) bool {
            for (js_builtins) |builtin| {
                if (std.mem.eql(u8, type_name, builtin)) return true;
            }
            return false;
        }
    }.call;

    // Helper to check if a type is a WebIDL primitive or string type
    const isPrimitiveOrString = struct {
        fn call(type_name: []const u8) bool {
            for (primitive_types) |prim| {
                if (std.mem.eql(u8, type_name, prim)) return true;
            }
            return false;
        }
    }.call;

    // Helper to get the import module for a type name
    // Returns null if the type should be skipped (not in registry and not a known type)
    const getImportModule = struct {
        fn call(type_name: []const u8, reg: ?*const @import("ir.zig").TypeRegistry) ?[]const u8 {
            // Special case: DOMString, USVString, ByteString are registered as primitives
            // but they have typedef files that re-export runtime types.
            // These should be imported from typedefs when used in signatures.
            if (std.mem.eql(u8, type_name, "DOMString") or
                std.mem.eql(u8, type_name, "USVString") or
                std.mem.eql(u8, type_name, "ByteString"))
            {
                return "typedefs";
            }

            if (reg) |r| {
                if (r.lookup(type_name)) |kind| {
                    return switch (kind) {
                        .interface => "interfaces",
                        .callback_interface => "interfaces", // Callback interfaces are still interfaces
                        .typedef => "typedefs",
                        .dictionary => "dictionaries",
                        .enum_type => "enums",
                        .callback => "callbacks",
                        .namespace => "namespaces",
                        .mixin => "mixins",
                        .primitive => null, // Skip primitives - they're Zig native types
                    };
                }
            }
            // Type not in registry - return null only if registry was provided
            // If no registry, we can't determine the module
            return null;
        }
    }.call;

    // Helper to get import module with fallback for tests (when registry is null)
    // Base types and mixins default to "interfaces" when no registry is provided
    const getImportModuleWithFallback = struct {
        fn call(type_name: []const u8, reg: ?*const @import("ir.zig").TypeRegistry, default_module: []const u8) ?[]const u8 {
            if (getImportModule(type_name, reg)) |module| {
                return module;
            }
            // If no registry provided, use the default module
            if (reg == null) {
                return default_module;
            }
            return null;
        }
    }.call;

    // Import base type if present
    if (base_type) |base| {
        if (getImportModuleWithFallback(base, type_registry, "interfaces")) |module| {
            // Use direct peer imports for interface types to avoid fat-module dependency
            if (std.mem.eql(u8, module, "interfaces")) {
                try writer.print("const {s} = @import(\"{s}.zig\").{s};\n", .{ base, base, base });
            } else {
                try writer.print("const {s} = @import(\"{s}\").{s};\n", .{ base, module, base });
            }
            try imported.put(base, {});
        }
    }

    // Import mixin types
    for (mixins) |mixin| {
        if (!imported.contains(mixin)) {
            if (getImportModuleWithFallback(mixin, type_registry, "mixins")) |module| {
                // Mixins use "mixins" module, not direct peer imports
                try writer.print("const {s} = @import(\"{s}\").{s};\n", .{ mixin, module, mixin });
                try imported.put(mixin, {});
            }
        }
    }

    // Import all other referenced types
    for (referenced_interfaces) |ref| {
        // Skip if already imported (base type or mixin) or if it's the interface itself
        if (!imported.contains(ref) and !std.mem.eql(u8, ref, interface_name)) {
            // Skip malformed type names that contain generic syntax (e.g., "sequence<T>")
            // These indicate a parser bug where generic types weren't properly decomposed
            if (std.mem.indexOfScalar(u8, ref, '<')) |_| {
                continue; // Skip this import - it's invalid Zig syntax
            }

            // Skip primitive types with spaces (invalid Zig identifiers)
            // e.g., "unsigned short", "unsigned long", "unrestricted double"
            if (std.mem.indexOfScalar(u8, ref, ' ')) |_| {
                continue; // Skip this import - it's a primitive type
            }

            // Skip union type syntax (e.g., "(DOMString or long)")
            // These start with '(' and indicate union types
            if (std.mem.startsWith(u8, ref, "(")) {
                continue; // Skip this import - it's a union type
            }

            // Skip namespace syntax (e.g., "stylesheets::MediaList")
            // These contain '::' which is invalid in Zig
            if (std.mem.indexOf(u8, ref, "::")) |_| {
                continue; // Skip this import - it's namespace syntax
            }

            // Skip JavaScript built-in types (ArrayBuffer, TypedArrays, etc.)
            // These are available from runtime module, not interfaces
            if (isJsBuiltin(ref)) {
                continue; // Skip - available from runtime
            }

            // Skip WebIDL primitive and string types (mapped to Zig native types)
            // e.g., "unsignedlong", "DOMString", "USVString", etc.
            if (isPrimitiveOrString(ref)) {
                continue; // Skip - these are Zig native types or runtime types
            }

            // Try to get the import module - skip if type is not registered
            if (getImportModuleWithFallback(ref, type_registry, "interfaces")) |module| {
                // Use direct peer imports for interface types to avoid fat-module dependency
                if (std.mem.eql(u8, module, "interfaces")) {
                    try writer.print("const {s} = @import(\"{s}.zig\").{s};\n", .{ ref, ref, ref });
                } else {
                    try writer.print("const {s} = @import(\"{s}\").{s};\n", .{ ref, module, ref });
                }
                try imported.put(ref, {});
            }
            // If module is null, the type is not in the registry - skip it silently
            // This handles missing interfaces like AbstractView, CSSMarginDescriptors
        }
    }

    try writer.writeAll("\n");
}

/// Write the interface struct declaration
///
/// Example output:
/// ```zig
/// pub const EventTarget = struct {
///     // ...
/// };
/// ```
pub fn writeInterfaceStruct(
    writer: anytype,
    interface_name: []const u8,
) !void {
    try writer.print("pub const {s} = struct {{\n", .{interface_name});
}

/// Write struct closing brace
pub fn writeStructEnd(writer: anytype) !void {
    try writer.writeAll("};\n");
}

/// Write metadata struct
///
/// Example output:
/// ```zig
/// pub const Meta = struct {
///     pub const name = "EventTarget";
///     pub const spec_url = "https://dom.spec.whatwg.org/#interface-eventtarget";
///     pub const BaseType = ?*anyopaque;
///     pub const MixinTypes = .{};
///     pub const extended_attributes = .{
///         .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
///     };
/// };
/// ```
pub fn writeMetadata(
    writer: anytype,
    interface_name: []const u8,
    spec_url: ?[]const u8,
    base_type: ?[]const u8,
    base_is_interface: bool,
    mixins: []const []const u8,
    extended_attrs: []const types.ExtendedAttribute,
    attributes: []const types.Attribute,
    all_operations: []const types.Operation,
    own_operations: []const types.Operation,
    constants: []const types.Constant,
    has_constructor: bool,
    is_mixin: bool,
    is_callback: bool,
    iterable: ?types.Iterable,
    own_attributes: []const types.Attribute,
    async_iterable: ?types.AsyncIterable,
) !void {
    _ = attributes; // Unused - we now use own_attributes for properties/lazy_properties

    try writer.writeAll("    pub const Meta = struct {\n");
    try writer.print("        pub const name = \"{s}\";\n", .{interface_name});
    try writer.print("        pub const is_mixin = {};\n", .{is_mixin});
    try writer.print("        pub const is_callback_interface = {};\n", .{is_callback});

    if (spec_url) |url| {
        try writer.print("        pub const spec_url = \"{s}\";\n", .{url});
    } else {
        try writer.writeAll("        pub const spec_url: ?[]const u8 = null;\n");
    }

    if (base_type) |base| {
        if (base_is_interface) {
            // Use Parent.State so FlattenedState embeds the parent's state struct,
            // enabling proper inheritance of internal state (_internal field accessible
            // via state.base.own._internal from subclasses)
            try writer.print("        pub const BaseType = {s}.State;\n", .{base});
            // Also provide ParentInterface for V8 prototype chain setup
            try writer.print("        pub const ParentInterface = {s};\n", .{base});
        } else {
            // For non-interface base types (dictionaries, etc.), use pointer
            try writer.print("        pub const BaseType = *{s};\n", .{base});
        }
    } else {
        // Root interfaces have no base type - use null so FlattenedState produces void
        try writer.writeAll("        pub const BaseType = null;\n");
    }

    if (mixins.len > 0) {
        try writer.writeAll("        pub const MixinTypes = &.{\n");
        for (mixins) |mixin| {
            try writer.print("            {s},\n", .{mixin});
        }
        try writer.writeAll("        };\n");
    } else {
        try writer.writeAll("        pub const MixinTypes = &.{};\n");
    }

    // Write extended attributes
    if (extended_attrs.len > 0) {
        try writer.writeAll("        pub const extended_attributes = .{\n");
        for (extended_attrs) |attr| {
            try writer.print("            .{{ .name = \"{s}\"", .{attr.name});
            if (attr.rhs) |rhs| {
                try writer.writeAll(", .value = ");
                try writeExtendedAttributeValue(writer, rhs);
            }
            try writer.writeAll(" },\n");
        }
        try writer.writeAll("        };\n");
    } else {
        try writer.writeAll("        pub const extended_attributes = .{};\n");
    }

    // Extract [Exposed] context information
    var exposed_attr: ?types.ExtendedAttribute = null;
    for (extended_attrs) |attr| {
        if (std.mem.eql(u8, attr.name, "Exposed")) {
            exposed_attr = attr;
            break;
        }
    }

    if (exposed_attr) |exposed| {
        try writer.writeAll("        \n");
        try writer.writeAll("        /// Global contexts where this interface is exposed\n");
        if (exposed.rhs) |rhs| {
            switch (rhs) {
                .identifier => |id| {
                    if (std.mem.eql(u8, id, "*")) {
                        try writer.writeAll("        pub const exposed_in_all_contexts = true;\n");
                    } else {
                        try writer.print("        pub const exposed_in = .{{ .{s} = true }};\n", .{id});
                    }
                },
                .identifierList => |list| {
                    try writer.writeAll("        pub const exposed_in = .{\n");
                    for (list) |id| {
                        try writer.print("            .{s} = true,\n", .{id});
                    }
                    try writer.writeAll("        };\n");
                },
                else => {},
            }
        }
    }

    // Generate property hints for V8 bindings (avoids comptime reflection loops) - ONLY own properties
    try writer.writeAll("        \n");
    try writer.writeAll("        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties\n");
    try writer.writeAll("        pub const properties = .{\n");
    {
        const extattr_mod = @import("extattr.zig");
        for (own_attributes) |attr| {
            // Write JS property name (original with hyphens)
            try writer.print("            .{{ \"{s}\", \"get_", .{attr.name});
            // Write sanitized getter name (hyphens -> underscores)
            try writeSanitizedName(writer, attr.name);
            // Check if this needs a setter: non-readonly OR [Replaceable] OR [PutForwards] OR [LegacyLenientSetter]
            const is_replaceable = extattr_mod.isReplaceable(attr.extAttrs);
            const has_put_forwards = extattr_mod.getPutForwards(attr.extAttrs) != null;
            const is_legacy_lenient_setter = extattr_mod.isLegacyLenientSetter(attr.extAttrs);
            if (!attr.readonly or is_replaceable or has_put_forwards or is_legacy_lenient_setter) {
                try writer.writeAll("\", \"set_");
                try writeSanitizedName(writer, attr.name);
                try writer.writeAll("\" },\n");
            } else {
                try writer.writeAll("\", null },\n");
            }
        }
    }
    try writer.writeAll("        };\n");

    // Generate [PutForwards] metadata for attributes with setter forwarding
    // Per WebIDL spec §4.3.10: [PutForwards=X] means setting the attribute
    // actually sets property X on the current value of the attribute
    {
        const extattr_mod = @import("extattr.zig");
        var has_put_forwards = false;

        // Check if any attributes have [PutForwards]
        for (own_attributes) |attr| {
            if (extattr_mod.getPutForwards(attr.extAttrs)) |_| {
                has_put_forwards = true;
                break;
            }
        }

        if (has_put_forwards) {
            try writer.writeAll("        \n");
            try writer.writeAll("        /// [PutForwards] attributes: setting the attribute forwards to a property on the value\n");
            try writer.writeAll("        /// Format: { \"attrName\", \"forwardedProperty\" }\n");
            try writer.writeAll("        pub const put_forwards_attributes = .{\n");
            for (own_attributes) |attr| {
                if (extattr_mod.getPutForwards(attr.extAttrs)) |forwarded| {
                    try writer.print("            .{{ \"{s}\", \"{s}\" }},\n", .{ attr.name, forwarded });
                }
            }
            try writer.writeAll("        };\n");
        }
    }

    // Generate [LegacyLenientThis] metadata for attributes that should NOT throw on invalid this
    // Per WebIDL §4.3.10: [LegacyLenientThis] attributes return undefined (getter) or
    // silently return (setter) when called with invalid `this` values instead of throwing.
    {
        const extattr_mod = @import("extattr.zig");
        var has_lenient_this = false;

        // Check if any attributes have [LegacyLenientThis]
        for (own_attributes) |attr| {
            if (extattr_mod.isLegacyLenientThis(attr.extAttrs)) {
                has_lenient_this = true;
                break;
            }
        }

        if (has_lenient_this) {
            try writer.writeAll("        \n");
            try writer.writeAll("        /// [LegacyLenientThis] attributes: do NOT throw TypeError on invalid this\n");
            try writer.writeAll("        /// Getters return undefined, setters silently return\n");
            try writer.writeAll("        pub const lenient_this_attributes = .{\n");
            for (own_attributes) |attr| {
                if (extattr_mod.isLegacyLenientThis(attr.extAttrs)) {
                    try writer.print("            \"{s}\",\n", .{attr.name});
                }
            }
            try writer.writeAll("        };\n");
        }
    }

    // Generate [LegacyLenientSetter] metadata for readonly attributes with no-op setters
    // Per WebIDL §4.3.10: [LegacyLenientSetter] readonly attributes have setters that
    // silently do nothing - the setter steps are to return.
    {
        const extattr_mod = @import("extattr.zig");
        var has_lenient_setter = false;

        // Check if any attributes have [LegacyLenientSetter]
        for (own_attributes) |attr| {
            if (extattr_mod.isLegacyLenientSetter(attr.extAttrs)) {
                has_lenient_setter = true;
                break;
            }
        }

        if (has_lenient_setter) {
            try writer.writeAll("        \n");
            try writer.writeAll("        /// [LegacyLenientSetter] attributes: readonly with no-op setters\n");
            try writer.writeAll("        /// Setters silently do nothing (don't throw, don't modify)\n");
            try writer.writeAll("        pub const lenient_setter_attributes = .{\n");
            for (own_attributes) |attr| {
                if (extattr_mod.isLegacyLenientSetter(attr.extAttrs)) {
                    try writer.print("            \"{s}\",\n", .{attr.name});
                }
            }
            try writer.writeAll("        };\n");
        }
    }

    // Generate method hints - ONLY for own operations (not inherited)
    // Separate static methods from instance methods
    try writer.writeAll("        \n");
    try writer.writeAll("        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods\n");
    try writer.writeAll("        pub const methods = .{\n");
    for (own_operations) |op| {
        if (op.name) |name| {
            // Skip static methods - they go in static_methods
            if (op.static) continue;

            // Include regular operations AND named special operations (like getter item())
            // Named special operations should be exposed as methods per WebIDL spec
            const should_include = op.special == null or
                op.special.? == .getter or
                op.special.? == .setter;

            if (should_include) {
                // Count required (non-optional) parameters for arity
                var arity: usize = 0;
                for (op.arguments) |arg| {
                    if (!arg.optional) {
                        arity += 1;
                    }
                }

                try writer.print("            .{{ \"{s}\", \"call_", .{name});
                try writeSanitizedName(writer, name);
                try writer.print("\", {d} }},\n", .{arity});
            }
        }
    }

    // Add forEach method for iterable interfaces (per WebIDL spec)
    if (iterable != null) {
        try writer.writeAll("            .{ \"forEach\", \"call_forEach\", 1 },\n");
    }

    // Add toString method for stringifier interfaces (per WebIDL spec)
    // Bare stringifier declarations generate a toString() method that calls serialize
    // Stringifier attribute declarations generate a toString() method that returns the attribute
    var has_stringifier = false;
    for (own_operations) |op| {
        if (op.special) |special| {
            if (special == .stringifier and op.name == null) {
                try writer.writeAll("            .{ \"toString\", \"serialize\", 0 },\n");
                has_stringifier = true;
                break;
            }
        }
    }
    // Check for stringifier attribute (e.g., stringifier attribute USVString href)
    if (!has_stringifier) {
        for (own_attributes) |attr| {
            for (attr.extAttrs) |ext_attr| {
                if (std.mem.eql(u8, ext_attr.name, "Stringifier")) {
                    // toString() returns the stringifier attribute's getter
                    try writer.print("            .{{ \"toString\", \"get_{s}\", 0 }},\n", .{attr.name});
                    has_stringifier = true;
                    break;
                }
            }
            if (has_stringifier) break;
        }
    }

    try writer.writeAll("        };\n");

    // Generate static methods hints
    var has_static_methods = false;
    for (own_operations) |op| {
        if (op.static and op.name != null) {
            has_static_methods = true;
            break;
        }
    }

    if (has_static_methods) {
        try writer.writeAll("        \n");
        try writer.writeAll("        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)\n");
        try writer.writeAll("        pub const static_methods = .{\n");
        for (own_operations) |op| {
            if (op.static) {
                if (op.name) |name| {
                    // Count required (non-optional) parameters for arity
                    var arity: usize = 0;
                    for (op.arguments) |arg| {
                        if (!arg.optional) {
                            arity += 1;
                        }
                    }

                    // Static methods always use call_static_<name> convention
                    // This avoids collision with instance methods of the same name
                    try writer.print("            .{{ \"{s}\", \"call_static_", .{name});
                    try writeSanitizedName(writer, name);
                    try writer.print("\", {d} }},\n", .{arity});
                }
            }
        }
        try writer.writeAll("        };\n");
    }

    // Generate constants metadata for V8 bindings
    // Filter out _skipped constants (these are placeholders for unsupported types)
    var has_real_constants = false;
    for (constants) |constant| {
        if (!std.mem.eql(u8, constant.name, "_skipped")) {
            has_real_constants = true;
            break;
        }
    }

    if (has_real_constants) {
        try writer.writeAll("        \n");
        try writer.writeAll("        /// Constants binding hints for V8Interface (JS name, getter fn name)\n");
        try writer.writeAll("        pub const constants = .{\n");
        for (constants) |constant| {
            if (!std.mem.eql(u8, constant.name, "_skipped")) {
                try writer.print("            .{{ \"{s}\", \"get_{s}\" }},\n", .{ constant.name, constant.name });
            }
        }
        try writer.writeAll("        };\n");
    }

    // Generate method override tracking for prototype chain optimization
    try writer.writeAll("        \n");
    try writer.writeAll("        /// Methods defined/overridden by this interface\n");
    try writer.writeAll("        pub const own_methods = .{\n");
    for (own_operations) |op| {
        if (op.name) |name| {
            // Include regular operations AND named special operations
            const should_include = op.special == null or
                op.special.? == .getter or
                op.special.? == .setter;

            if (should_include) {
                try writer.print("            \"{s}\",\n", .{name});
            }
        }
    }

    // Add toString for stringifier interfaces (both bare stringifier and stringifier attribute)
    var has_tostring = false;
    for (own_operations) |op| {
        if (op.special) |special| {
            if (special == .stringifier and op.name == null) {
                try writer.writeAll("            \"toString\",\n");
                has_tostring = true;
                break;
            }
        }
    }
    // Check for stringifier attribute
    if (!has_tostring) {
        for (own_attributes) |attr| {
            for (attr.extAttrs) |ext_attr| {
                if (std.mem.eql(u8, ext_attr.name, "Stringifier")) {
                    try writer.writeAll("            \"toString\",\n");
                    has_tostring = true;
                    break;
                }
            }
            if (has_tostring) break;
        }
    }

    try writer.writeAll("        };\n");

    try writer.writeAll("        \n");
    try writer.writeAll("        /// Methods inherited from parent/mixins (rely on V8 prototype chain)\n");
    try writer.writeAll("        pub const inherited_methods = .{\n");
    // Inherited methods = all_operations - own_operations
    for (all_operations) |all_op| {
        if (all_op.name) |all_name| {
            const should_include = all_op.special == null or
                all_op.special.? == .getter or
                all_op.special.? == .setter;

            if (should_include) {
                // Check if this method is NOT in own_operations
                var is_own = false;
                for (own_operations) |own_op| {
                    if (own_op.name) |own_name| {
                        if (std.mem.eql(u8, all_name, own_name)) {
                            is_own = true;
                            break;
                        }
                    }
                }
                if (!is_own) {
                    try writer.print("            \"{s}\",\n", .{all_name});
                }
            }
        }
    }
    try writer.writeAll("        };\n");

    // Generate property classification for lazy loading optimization - ONLY own properties
    // Split properties into eager (frequently accessed) and lazy (rarely accessed)
    try writer.writeAll("        \n");
    try writer.writeAll("        /// Properties to define eagerly (frequently accessed) - ONLY own properties\n");
    try writer.writeAll("        pub const eager_properties = .{\n");
    {
        const extattr_mod_eager = @import("extattr.zig");
        for (own_attributes) |attr| {
            // Classify based on property name and extended attributes
            // For now, just use empty slice for ext attrs - classifier checks attr names internally
            const classification = property_classifier.classifyProperty(attr.name, &.{});
            if (classification == .eager) {
                try writer.print("            .{{ \"{s}\", \"get_", .{attr.name});
                try writeSanitizedName(writer, attr.name);
                // Check if this needs a setter: non-readonly OR [Replaceable] OR [PutForwards] OR [LegacyLenientSetter]
                const is_replaceable_eager = extattr_mod_eager.isReplaceable(attr.extAttrs);
                const has_put_forwards_eager = extattr_mod_eager.getPutForwards(attr.extAttrs) != null;
                const is_legacy_lenient_setter_eager = extattr_mod_eager.isLegacyLenientSetter(attr.extAttrs);
                if (!attr.readonly or is_replaceable_eager or has_put_forwards_eager or is_legacy_lenient_setter_eager) {
                    try writer.writeAll("\", \"set_");
                    try writeSanitizedName(writer, attr.name);
                    try writer.writeAll("\" },\n");
                } else {
                    try writer.writeAll("\", null },\n");
                }
            }
        }
    }
    try writer.writeAll("        };\n");

    try writer.writeAll("        \n");
    try writer.writeAll("        /// Properties to define lazily (rarely accessed) - ONLY own properties\n");
    try writer.writeAll("        pub const lazy_properties = .{\n");
    {
        const extattr_mod_lazy = @import("extattr.zig");
        for (own_attributes) |attr| {
            // Classify based on property name and extended attributes
            const classification = property_classifier.classifyProperty(attr.name, &.{});
            if (classification == .lazy) {
                try writer.print("            .{{ \"{s}\", \"get_", .{attr.name});
                try writeSanitizedName(writer, attr.name);
                // Check if this needs a setter: non-readonly OR [Replaceable] OR [PutForwards] OR [LegacyLenientSetter]
                const is_replaceable_lazy = extattr_mod_lazy.isReplaceable(attr.extAttrs);
                const has_put_forwards_lazy = extattr_mod_lazy.getPutForwards(attr.extAttrs) != null;
                const is_legacy_lenient_setter_lazy = extattr_mod_lazy.isLegacyLenientSetter(attr.extAttrs);
                if (!attr.readonly or is_replaceable_lazy or has_put_forwards_lazy or is_legacy_lenient_setter_lazy) {
                    try writer.writeAll("\", \"set_");
                    try writeSanitizedName(writer, attr.name);
                    try writer.writeAll("\" },\n");
                } else {
                    try writer.writeAll("\", null },\n");
                }
            }
        }
    }
    try writer.writeAll("        };\n");

    // Generate constructor hint
    try writer.writeAll("        \n");
    try writer.print("        pub const has_constructor = {};\n", .{has_constructor});

    // Generate iterable metadata if present
    if (iterable) |iter| {
        try writer.writeAll("        \n");
        try writer.writeAll("        /// Iterable declaration (for Symbol.iterator support)\n");
        try writer.writeAll("        pub const iterable = .{\n");

        // Value type (always present)
        try writer.writeAll("            .value_type = \"");
        try writeIDLType(writer, iter.keyType);
        try writer.writeAll("\",\n");

        // Key type (only for pair iterables)
        if (iter.valueType) |val_type| {
            try writer.writeAll("            .key_type = \"");
            try writeIDLType(writer, val_type);
            try writer.writeAll("\",\n");
        } else {
            try writer.writeAll("            .key_type = null,\n");
        }

        try writer.writeAll("        };\n");
    }

    // Generate async_iterable metadata if present
    if (async_iterable) |async_iter| {
        try writer.writeAll("        \n");
        try writer.writeAll("        /// Async iterable declaration (for Symbol.asyncIterator support)\n");
        try writer.writeAll("        pub const async_iterable = .{\n");

        // Value type (always present)
        try writer.writeAll("            .value_type = \"");
        try writeIDLType(writer, async_iter.keyType);
        try writer.writeAll("\",\n");

        // Key type (only for pair async iterables)
        if (async_iter.valueType) |val_type| {
            try writer.writeAll("            .key_type = \"");
            try writeIDLType(writer, val_type);
            try writer.writeAll("\",\n");
        } else {
            try writer.writeAll("            .key_type = null,\n");
        }

        // Options type (if arguments present)
        if (async_iter.arguments.len > 0) {
            // For ReadableStream: async_iterable<any>(optional ReadableStreamIteratorOptions options = {});
            // Extract the type from the first argument
            const first_arg = async_iter.arguments[0];
            try writer.writeAll("            .options_type = \"");
            try writeIDLType(writer, first_arg.idlType);
            try writer.writeAll("\",\n");
        } else {
            try writer.writeAll("            .options_type = null,\n");
        }

        try writer.writeAll("        };\n");
    }

    // Generate unscopables list for [Unscopable] extended attribute
    // Check attributes and operations for [Unscopable] and collect their names
    const extattr = @import("extattr.zig");
    var has_unscopables = false;

    // Check own_attributes for [Unscopable]
    for (own_attributes) |attr| {
        if (extattr.isUnscopable(attr.extAttrs)) {
            has_unscopables = true;
            break;
        }
    }

    // Check own_operations for [Unscopable]
    if (!has_unscopables) {
        for (own_operations) |op| {
            if (extattr.isUnscopable(op.extAttrs)) {
                has_unscopables = true;
                break;
            }
        }
    }

    if (has_unscopables) {
        try writer.writeAll("        \n");
        try writer.writeAll("        /// Members marked with [Unscopable] extended attribute\n");
        try writer.writeAll("        pub const unscopables = .{\n");

        // Output unscopable attribute names
        for (own_attributes) |attr| {
            if (extattr.isUnscopable(attr.extAttrs)) {
                try writer.print("            \"{s}\",\n", .{attr.name});
            }
        }

        // Output unscopable operation names
        for (own_operations) |op| {
            if (op.name) |name| {
                if (extattr.isUnscopable(op.extAttrs)) {
                    try writer.print("            \"{s}\",\n", .{name});
                }
            }
        }

        try writer.writeAll("        };\n");
    }

    try writer.writeAll("    };\n\n");
}

/// Write extended attribute value (RHS)
fn writeExtendedAttributeValue(writer: anytype, rhs: types.ExtAttrRHS) !void {
    switch (rhs) {
        .identifier => |id| {
            try writer.print(".{{ .identifier = \"{s}\" }}", .{id});
        },
        .identifierList => |list| {
            try writer.writeAll(".{ .identifier_list = &.{ ");
            for (list, 0..) |id, i| {
                if (i > 0) try writer.writeAll(", ");
                try writer.print("\"{s}\"", .{id});
            }
            try writer.writeAll(" } }");
        },
        .string => |s| {
            try writer.print(".{{ .string = \"{s}\" }}", .{s});
        },
        .integer => |n| {
            try writer.print(".{{ .integer = {d} }}", .{n});
        },
    }
}

/// Write a sanitized name (hyphens replaced with underscores for Zig identifiers)
fn writeSanitizedName(writer: anytype, name: []const u8) !void {
    for (name) |c| {
        if (c == '-') {
            try writer.writeByte('_');
        } else {
            try writer.writeByte(c);
        }
    }
}

/// Parse a union type string like "(Type1 or Type2 or Type3)" into member types
/// Returns a slice of type name strings (caller must free)
fn parseUnionTypeString(allocator: std.mem.Allocator, union_str: []const u8) ![][]const u8 {
    // Strip leading '(' and trailing ')'
    if (!std.mem.startsWith(u8, union_str, "(") or !std.mem.endsWith(u8, union_str, ")")) {
        // Not a union type string
        return &[_][]const u8{};
    }

    const inner = union_str[1 .. union_str.len - 1];

    // Split by " or "
    var members = std.ArrayList([]const u8).empty;
    defer members.deinit(allocator);

    var it = std.mem.splitSequence(u8, inner, " or ");
    while (it.next()) |member| {
        const trimmed = std.mem.trim(u8, member, " \t");
        if (trimmed.len > 0) {
            try members.append(allocator, try allocator.dupe(u8, trimmed));
        }
    }

    return members.toOwnedSlice(allocator);
}

/// Write a WebIDL union type as a Zig tagged union (from type name strings)
fn writeUnionTypeFromStrings(writer: anytype, member_types: [][]const u8) !void {
    try writer.writeAll("union(enum) {\n");

    for (member_types) |type_name| {
        // Check if nullable (ends with ?)
        var base_type = type_name;
        var is_nullable = false;

        if (type_name.len > 0 and type_name[type_name.len - 1] == '?') {
            base_type = type_name[0 .. type_name.len - 1];
            is_nullable = true;
        }

        // Generate variant name from type name
        const variant_name = try sanitizeVariantName(base_type);

        try writer.writeAll("                ");
        try writer.print("{s}: ", .{variant_name});

        // Add nullable prefix if needed
        if (is_nullable) {
            try writer.writeAll("?");
        }

        // Write the member type
        try writeZigType(writer, base_type);
        try writer.writeAll(",\n");
    }

    try writer.writeAll("            }");
}

/// Write a WebIDL union type as a Zig tagged union
///
/// Generates: union(enum) { TypeName: Type, ... }
/// Each member type becomes a variant with a sanitized name
fn writeUnionType(writer: anytype, union_types: []const types.IDLType) !void {
    try writer.writeAll("union(enum) {\n");

    for (union_types) |member_type| {
        // Get the base type name (strip nullable marker)
        var type_name = member_type.type;
        var is_nullable = member_type.nullable;

        // Strip trailing '?' if present
        if (type_name.len > 0 and type_name[type_name.len - 1] == '?') {
            type_name = type_name[0 .. type_name.len - 1];
            is_nullable = true;
        }

        // Generate variant name from type name
        // Use the type name as variant name (sanitized for Zig)
        const variant_name = try sanitizeVariantName(type_name);

        try writer.writeAll("                ");
        try writer.print("{s}: ", .{variant_name});

        // Add nullable prefix if needed
        if (is_nullable) {
            try writer.writeAll("?");
        }

        // Write the member type
        try writeZigType(writer, type_name);
        try writer.writeAll(",\n");
    }

    try writer.writeAll("            }");
}

/// Sanitize a type name for use as a union variant name
/// Converts "DOMString" → "DOMString", "unsigned long" → "unsigned_long", etc.
/// Escapes Zig keywords like "undefined" → "@\"undefined\""
fn sanitizeVariantName(type_name: []const u8) ![]const u8 {
    // Escape Zig keywords
    if (std.mem.eql(u8, type_name, "undefined")) {
        return "@\"undefined\"";
    }

    // For primitive types with spaces, replace spaces with underscores
    // For interface types, use as-is
    if (std.mem.indexOfScalar(u8, type_name, ' ')) |_| {
        // Has spaces - create sanitized version
        const allocator = std.heap.page_allocator;
        var result = try allocator.alloc(u8, type_name.len);
        for (type_name, 0..) |c, i| {
            result[i] = if (c == ' ') '_' else c;
        }
        return result;
    }
    return type_name;
}

/// Write a Zig type from a structured IDLType
///
/// This function correctly handles all WebIDL type constructs by inspecting
/// the structured IDLType representation from the parser, rather than trying
/// to parse type strings.
///
/// Handles:
/// - Primitives: boolean → bool, long → i32, double → f64, etc.
/// - Strings: DOMString → runtime.DOMString, etc.
/// - Interfaces: Node, Element, etc. (preserved as-is)
/// - Sequences: sequence<T> → runtime.sequence(T)
/// - FrozenArray: FrozenArray<T> → runtime.FrozenArray(T)
/// - ObservableArray: ObservableArray<T> → runtime.ObservableArray(T)
/// - Promise: Promise<T> → runtime.Promise(T)
/// - Record: record<K,V> → runtime.record(K, V)
/// - Union types: (A or B) → union(enum) { A: A, B: B }
/// - Nullable types: T? → ?T
///
/// This is the canonical way to generate Zig types from WebIDL.
fn writeIDLType(writer: anytype, idl_type: types.IDLType) !void {
    // Handle sequence<T> - check both structured and generic forms
    if (idl_type.sequence) |inner| {
        // Structured form: sequence pointer to inner IDLType
        try writer.writeAll("runtime.sequence(");
        try writeIDLType(writer, inner.*);
        try writer.writeAll(")");
        return;
    } else if (std.mem.eql(u8, idl_type.type, "sequence")) {
        // Generic form: type="sequence", generic="T"
        if (idl_type.generic) |generic_param| {
            try writer.writeAll("runtime.sequence(");
            // Recursively handle the generic parameter - might contain nested generics
            // Use writeZigType to handle "FrozenArray<T>" syntax
            try writeZigType(writer, generic_param);
            try writer.writeAll(")");
            return;
        }
        // Malformed: sequence without parameter - shouldn't happen
        try writer.writeAll("runtime.JSValue /* malformed sequence */");
        return;
    }

    // Handle Promise<T>
    if (std.mem.eql(u8, idl_type.type, "Promise")) {
        if (idl_type.generic) |generic_param| {
            try writer.writeAll("runtime.Promise(");
            // Recursively handle the generic parameter
            try writeZigType(writer, generic_param);
            try writer.writeAll(")");
            return;
        }
        // Malformed: Promise without parameter
        try writer.writeAll("runtime.JSValue /* malformed Promise */");
        return;
    }

    // Handle FrozenArray<T>
    if (std.mem.eql(u8, idl_type.type, "FrozenArray")) {
        if (idl_type.generic) |generic_param| {
            try writer.writeAll("runtime.FrozenArray(");
            // Recursively handle the generic parameter
            try writeZigType(writer, generic_param);
            try writer.writeAll(")");
            return;
        }
        // Malformed: FrozenArray without parameter
        try writer.writeAll("runtime.JSValue /* malformed FrozenArray */");
        return;
    }

    // Handle ObservableArray<T>
    if (std.mem.eql(u8, idl_type.type, "ObservableArray")) {
        if (idl_type.generic) |generic_param| {
            try writer.writeAll("runtime.ObservableArray(");
            // Recursively handle the generic parameter
            try writeZigType(writer, generic_param);
            try writer.writeAll(")");
            return;
        }
        // Malformed: ObservableArray without parameter
        try writer.writeAll("runtime.JSValue /* malformed ObservableArray */");
        return;
    }

    // Handle record<K, V>
    if (idl_type.record) |rec| {
        // Structured form: record with key/value pointers
        try writer.writeAll("runtime.record(");
        try writeIDLType(writer, rec.key.*);
        try writer.writeAll(", ");
        try writeIDLType(writer, rec.value.*);
        try writer.writeAll(")");
        return;
    } else if (std.mem.eql(u8, idl_type.type, "record")) {
        // Generic form would have comma-separated generics
        // This is complex - fall back to string handler
        if (idl_type.generic) |_| {
            // Reconstruct the string form
            const full_type = try std.fmt.allocPrint(std.heap.page_allocator, "{s}<{s}>", .{ idl_type.type, idl_type.generic.? });
            defer std.heap.page_allocator.free(full_type);
            try writeZigType(writer, full_type);
            return;
        }
    }

    // Handle union types
    if (idl_type.unionTypes) |union_types| {
        // Check for (TrustedType or DOMString/USVString) pattern
        // TrustedTypes are not yet implemented, so we treat these as plain strings
        if (isTrustedTypeOrStringUnion(union_types)) {
            try writer.writeAll("DOMString");
            return;
        }
        // Check for (Node or DOMString) pattern used by DOM mutation methods
        if (isNodeOrDOMStringUnion(union_types)) {
            try writer.writeAll("mixins.ParentNode.NodeOrString");
            return;
        }
        // Other union types use runtime.JSValue for type safety
        // The JSValue tagged union preserves type information at runtime
        // and allows proper JavaScript value handling
        try writer.writeAll("runtime.JSValue");
        return;
    }

    // Check if type string has parameterized syntax (e.g., "FrozenArray<T>")
    // This handles cases where parser stored string form
    if (std.mem.indexOfScalar(u8, idl_type.type, '<')) |_| {
        // Delegate to string-based handler
        try writeZigType(writer, idl_type.type);
        return;
    }

    // Base type - use simple mapping
    const zig_type = idlTypeToZig(idl_type.type);
    try writer.writeAll(zig_type);
}

/// Map WebIDL type to Zig type (string-based, deprecated)
///
/// Converts WebIDL type names to their Zig equivalents.
/// Preserves exact casing from WebIDL for interface types.
/// Returns either a primitive type or the interface name as-is.
/// Write a Zig type to the writer, handling parameterized generic types
///
/// NOTE: This function is deprecated in favor of writeIDLType() which works
/// with structured IDLType. This is kept for backward compatibility with
/// code that needs to handle pre-concatenated type strings.
fn writeZigType(writer: anytype, idl_type_name: []const u8) !void {
    // Check if this is a parameterized generic type (e.g., FrozenArray<DOMString>)
    if (std.mem.indexOfScalar(u8, idl_type_name, '<')) |open_bracket| {
        const wrapper_type = idl_type_name[0..open_bracket];

        // Find the closing bracket
        if (std.mem.lastIndexOfScalar(u8, idl_type_name, '>')) |close_bracket| {
            const inner_type = idl_type_name[open_bracket + 1 .. close_bracket];

            // Map WebIDL parameterized types to Zig types
            if (std.mem.eql(u8, wrapper_type, "FrozenArray")) {
                // FrozenArray<T> -> runtime.FrozenArray(T)
                try writer.writeAll("runtime.FrozenArray(");
                try writeZigType(writer, inner_type);
                try writer.writeAll(")");
                return;
            } else if (std.mem.eql(u8, wrapper_type, "sequence")) {
                // sequence<T> -> runtime.sequence(T)
                try writer.writeAll("runtime.sequence(");
                try writeZigType(writer, inner_type);
                try writer.writeAll(")");
                return;
            } else if (std.mem.eql(u8, wrapper_type, "ObservableArray")) {
                // ObservableArray<T> -> runtime.ObservableArray(T)
                try writer.writeAll("runtime.ObservableArray(");
                try writeZigType(writer, inner_type);
                try writer.writeAll(")");
                return;
            } else if (std.mem.eql(u8, wrapper_type, "Promise")) {
                // Promise<T> -> runtime.Promise(T)
                try writer.writeAll("runtime.Promise(");
                try writeZigType(writer, inner_type);
                try writer.writeAll(")");
                return;
            } else if (std.mem.eql(u8, wrapper_type, "record")) {
                // record<K,V> -> runtime.record(K, V)
                // Note: Per WebIDL spec, "Records must not be used as the type of an
                // attribute or constant." So this should never appear in State structs.
                // This handles the case of malformed IDL or future spec changes.
                // Records are used in: operation params, return types, and dictionary members.

                // Parse out K and V from "K, V"
                if (std.mem.indexOfScalar(u8, inner_type, ',')) |comma_pos| {
                    const key_type = std.mem.trim(u8, inner_type[0..comma_pos], " \t");
                    const value_type = std.mem.trim(u8, inner_type[comma_pos + 1 ..], " \t");

                    try writer.writeAll("runtime.record(");
                    try writeZigType(writer, key_type);
                    try writer.writeAll(", ");
                    try writeZigType(writer, value_type);
                    try writer.writeAll(")");
                    return;
                }

                // Malformed record type, fall back to runtime.JSValue for type safety
                try writer.writeAll("runtime.JSValue");
                return;
            }
        }

        // Unknown or malformed parameterized type - use runtime.JSValue for type safety
        try writer.writeAll("runtime.JSValue");
        return;
    }

    // Non-parameterized type - use the simple mapping
    const zig_type = idlTypeToZig(idl_type_name);
    try writer.writeAll(zig_type);
}

fn idlTypeToZig(idl_type_name: []const u8) []const u8 {
    // Map primitive types - both with spaces and collapsed forms
    // The parser sometimes produces collapsed forms like "unsignedlong" instead of "unsigned long"
    if (std.mem.eql(u8, idl_type_name, "boolean")) {
        return "bool";
    } else if (std.mem.eql(u8, idl_type_name, "byte")) {
        return "i8";
    } else if (std.mem.eql(u8, idl_type_name, "octet")) {
        return "u8";
    } else if (std.mem.eql(u8, idl_type_name, "short")) {
        return "i16";
    } else if (std.mem.eql(u8, idl_type_name, "unsigned short") or std.mem.eql(u8, idl_type_name, "unsignedshort")) {
        return "u16";
    } else if (std.mem.eql(u8, idl_type_name, "long")) {
        return "i32";
    } else if (std.mem.eql(u8, idl_type_name, "unsigned long") or std.mem.eql(u8, idl_type_name, "unsignedlong")) {
        return "u32";
    } else if (std.mem.eql(u8, idl_type_name, "long long") or std.mem.eql(u8, idl_type_name, "longlong")) {
        return "i64";
    } else if (std.mem.eql(u8, idl_type_name, "unsigned long long") or std.mem.eql(u8, idl_type_name, "unsignedlonglong")) {
        return "u64";
    } else if (std.mem.eql(u8, idl_type_name, "float")) {
        return "f32";
    } else if (std.mem.eql(u8, idl_type_name, "unrestricted float") or std.mem.eql(u8, idl_type_name, "unrestrictedfloat")) {
        return "f32";
    } else if (std.mem.eql(u8, idl_type_name, "double")) {
        return "f64";
    } else if (std.mem.eql(u8, idl_type_name, "unrestricted double") or std.mem.eql(u8, idl_type_name, "unrestricteddouble")) {
        return "f64";
    } else if (std.mem.eql(u8, idl_type_name, "DOMString")) {
        return "runtime.DOMString";
    } else if (std.mem.eql(u8, idl_type_name, "ByteString")) {
        return "runtime.ByteString";
    } else if (std.mem.eql(u8, idl_type_name, "USVString")) {
        return "runtime.USVString";
    } else if (std.mem.eql(u8, idl_type_name, "object")) {
        return "runtime.JSValue";
    } else if (std.mem.eql(u8, idl_type_name, "any")) {
        return "runtime.JSValue";
    } else if (std.mem.eql(u8, idl_type_name, "void")) {
        return "void";
    } else if (std.mem.eql(u8, idl_type_name, "undefined")) {
        return "void";
        // JavaScript built-in types (provided by V8, not WebIDL interfaces)
    } else if (std.mem.eql(u8, idl_type_name, "ArrayBuffer")) {
        return "runtime.ArrayBuffer";
    } else if (std.mem.eql(u8, idl_type_name, "SharedArrayBuffer")) {
        return "runtime.SharedArrayBuffer";
    } else if (std.mem.eql(u8, idl_type_name, "DataView")) {
        return "runtime.DataView";
    } else if (std.mem.eql(u8, idl_type_name, "Int8Array")) {
        return "runtime.Int8Array";
    } else if (std.mem.eql(u8, idl_type_name, "Int16Array")) {
        return "runtime.Int16Array";
    } else if (std.mem.eql(u8, idl_type_name, "Int32Array")) {
        return "runtime.Int32Array";
    } else if (std.mem.eql(u8, idl_type_name, "Uint8Array")) {
        return "runtime.Uint8Array";
    } else if (std.mem.eql(u8, idl_type_name, "Uint8ClampedArray")) {
        return "runtime.Uint8ClampedArray";
    } else if (std.mem.eql(u8, idl_type_name, "Uint16Array")) {
        return "runtime.Uint16Array";
    } else if (std.mem.eql(u8, idl_type_name, "Uint32Array")) {
        return "runtime.Uint32Array";
    } else if (std.mem.eql(u8, idl_type_name, "Float32Array")) {
        return "runtime.Float32Array";
    } else if (std.mem.eql(u8, idl_type_name, "Float64Array")) {
        return "runtime.Float64Array";
    } else if (std.mem.eql(u8, idl_type_name, "BigInt64Array")) {
        return "runtime.BigInt64Array";
    } else if (std.mem.eql(u8, idl_type_name, "BigUint64Array")) {
        return "runtime.BigUint64Array";
        // FrozenArray<T> - immutable array type in WebIDL
        // For toJSON, these serialize as JavaScript arrays
    } else if (std.mem.eql(u8, idl_type_name, "FrozenArray")) {
        return "runtime.JSValue";
        // sequence<T> - also maps to array
    } else if (std.mem.eql(u8, idl_type_name, "sequence")) {
        return "runtime.JSValue";
    } else {
        // Interface types - preserve exact casing from WebIDL
        // These will be forward references (e.g., Node, Element, etc.)
        // Note: Parameterized types are handled by writeZigType()
        return idl_type_name;
    }
}

/// Write State struct with fields from attributes
///
/// Generates a struct with fields for each attribute, using:
/// - Exact attribute names from WebIDL (preserving casing)
/// - Mapped Zig types for the attribute types
/// - Optional types (?) for nullable attributes
///
/// Example output:
/// ```zig
/// pub const State = struct {
///     namespaceURI: ?runtime.DOMString = null,
///     prefix: ?runtime.DOMString = null,
///     localName: runtime.DOMString,
///     tagName: runtime.DOMString,
///     id: runtime.DOMString = runtime.DOMString.initEmpty(),
/// };
/// ```
pub fn writeStateStruct(
    writer: anytype,
    attributes: []const types.Attribute,
) !void {
    try writer.writeAll("    pub const State = struct {");

    // Check if we have any non-static attributes
    var has_fields = false;
    for (attributes) |attr| {
        if (!attr.static) {
            has_fields = true;
            break;
        }
    }

    if (!has_fields) {
        // Empty struct for interfaces with no own instance attributes
        try writer.writeAll(" };\n\n");
        return;
    }

    try writer.writeAll("\n");

    // Write a field for each attribute
    for (attributes) |attr| {
        // Skip static attributes - they're not stored in instance state
        if (attr.static) continue;

        // Check if type name ends with '?' (parser includes it in type string)
        var type_name = attr.idlType.type;
        var is_nullable = attr.idlType.nullable;

        // WORKAROUND: Parser includes '?' in type name, strip it
        if (type_name.len > 0 and type_name[type_name.len - 1] == '?') {
            type_name = type_name[0 .. type_name.len - 1];
            is_nullable = true;
        }

        const zig_type = idlTypeToZig(type_name);

        // Preserve exact casing from WebIDL for field name
        const field_name = attr.name;

        // Write field with proper escaping if needed
        try writer.writeAll("        ");
        try writeEscapedIdentifier(writer, field_name);

        // Add nullability if the IDL type is nullable
        if (is_nullable) {
            // Nullable: ?T with null default
            try writer.print(": ?{s} = null,\n", .{zig_type});
        } else {
            // Non-nullable: use undefined default (impl will initialize properly)
            try writer.print(": {s} = undefined,\n", .{zig_type});
        }
    }

    try writer.writeAll("    };\n\n");
}

/// Write consolidated State declaration
///
/// Generates State as a FlattenedState with the own-fields struct inlined.
/// This eliminates the need for separate State/FullState declarations.
///
/// Example output:
/// ```zig
/// pub const State = runtime.FlattenedState(
///     Meta.BaseType,
///     Meta.MixinTypes,
///     struct {
///         id: runtime.DOMString = undefined,
///         className: runtime.DOMString = undefined,
///     },
/// );
/// ```
pub fn writeGeneratedState(
    writer: anytype,
    attributes: []const types.Attribute,
    impl_name: []const u8,
    type_registry: ?*const @import("ir.zig").TypeRegistry,
) !void {
    // Check if we have any non-static attributes
    var has_fields = false;
    for (attributes) |attr| {
        if (!attr.static) {
            has_fields = true;
            break;
        }
    }

    // Start the FlattenedState declaration with correct parameter order:
    // FlattenedState(BaseType: ?type, MixinTypes: []const type, OwnFields: type)
    try writer.writeAll("    pub const State = runtime.FlattenedState(\n");
    try writer.writeAll("        Meta.BaseType,\n");
    try writer.writeAll("        Meta.MixinTypes,\n");

    // Write the own-fields struct inline as third parameter
    // Always generate a struct with _internal field for impl-specific state,
    // even if there are no WebIDL attributes
    try writer.writeAll("        struct {\n");

    if (has_fields) {

        // Write a field for each attribute
        for (attributes) |attr| {
            // Skip static attributes - they're not stored in instance state
            if (attr.static) continue;

            // Check if type name ends with '?' (parser includes it in type string)
            var type_name = attr.idlType.type;
            var is_nullable = attr.idlType.nullable;

            // WORKAROUND: Parser includes '?' in type name, strip it
            if (type_name.len > 0 and type_name[type_name.len - 1] == '?') {
                type_name = type_name[0 .. type_name.len - 1];
                is_nullable = true;
            }

            // Preserve exact casing from WebIDL for field name
            const field_name = attr.name;

            // Write the field with proper type handling and escaping
            try writer.writeAll("            ");
            try writeEscapedIdentifier(writer, field_name);
            try writer.writeAll(": ");

            // Add nullability prefix if needed
            if (is_nullable) {
                try writer.writeAll("?");
            }

            // Check for union types - generate tagged union
            // Union types have unionTypes field set OR type string starts with '('
            if (attr.idlType.unionTypes) |union_types| {
                // Generate inline tagged union: union(enum) { variant_name: Type, ... }
                try writeUnionType(writer, union_types);
            } else if (std.mem.startsWith(u8, type_name, "(")) {
                // Parser didn't populate unionTypes but type string has union syntax
                // Parse the union from the string: "(Type1 or Type2 or Type3)"
                const allocator = std.heap.page_allocator;
                const union_members = try parseUnionTypeString(allocator, type_name);
                defer allocator.free(union_members);

                try writeUnionTypeFromStrings(writer, union_members);
            } else {
                // Check the type kind in the registry
                const type_kind = if (type_registry) |reg| reg.lookup(attr.idlType.type) else null;

                if (type_kind) |kind| {
                    switch (kind) {
                        .callback_interface => {
                            // Callback interface types use ?*runtime.CallbackWrapper
                            try writer.writeAll("?*runtime.CallbackWrapper");
                        },
                        .interface, .mixin => {
                            // Interface/mixin types use *runtime.Instance
                            try writer.writeAll("*runtime.Instance");
                        },
                        .enum_type => {
                            // Enum types must be prefixed with enums module
                            try writer.writeAll("enums.");
                            try writer.writeAll(attr.idlType.type);
                        },
                        .dictionary => {
                            // Dictionary types are prefixed with dictionaries module
                            try writer.writeAll("dictionaries.");
                            try writer.writeAll(attr.idlType.type);
                        },
                        .typedef => {
                            // Typedef types are prefixed with typedefs module
                            try writer.writeAll("typedefs.");
                            try writer.writeAll(attr.idlType.type);
                        },
                        .callback => {
                            // Callback types use runtime.JSValue (function values)
                            try writer.writeAll("runtime.JSValue");
                        },
                        .namespace => {
                            // Namespace types shouldn't appear in State, use JSValue as fallback
                            try writer.writeAll("runtime.JSValue");
                        },
                        .primitive => {
                            // Primitive types get mapped via idlTypeToZig
                            const zig_type = idlTypeToZig(attr.idlType.type);
                            try writer.writeAll(zig_type);
                        },
                    }
                } else {
                    // Type not found in registry - check if it's a primitive
                    const zig_type = idlTypeToZig(attr.idlType.type);
                    if (std.mem.eql(u8, zig_type, attr.idlType.type)) {
                        // idlTypeToZig returned the type unchanged - it's not a known primitive
                        // Use runtime.JSValue for missing/unknown types
                        try writer.writeAll("runtime.JSValue");
                    } else {
                        // It's a mapped primitive type
                        try writer.writeAll(zig_type);
                    }
                }
            }

            // Add default value
            if (is_nullable) {
                try writer.writeAll(" = null,\n");
            } else {
                try writer.writeAll(" = undefined,\n");
            }
        }

        // Add cached fields for [SameObject] attributes
        const allocator = std.heap.page_allocator;
        for (attributes) |attr| {
            // Skip static attributes
            if (attr.static) continue;

            // Check if this attribute has [SameObject]
            const has_same_object = hasExtendedAttribute(attr.extAttrs, "SameObject");
            if (!has_same_object) continue;

            // Sanitize attribute name for field name (convert hyphens to underscores)
            const sanitized_name = try sanitizeFunctionName(allocator, attr.name);
            const name_was_sanitized = !std.mem.eql(u8, sanitized_name, attr.name);
            defer if (name_was_sanitized) allocator.free(sanitized_name);

            // Write cached field (always optional)
            // Build the full cached field name first, then escape if needed
            const cached_field_name = try std.fmt.allocPrint(allocator, "cached_{s}", .{sanitized_name});
            defer allocator.free(cached_field_name);

            try writer.writeAll("            ");
            try writeEscapedIdentifier(writer, cached_field_name);
            try writer.writeAll(": ?");

            // Write the type - must match getter return type exactly
            const cached_type_name = attr.idlType.type;

            // Check for union types - these always return runtime.JSValue from getters
            // because union types are mapped to anyopaque which becomes JSValue
            if (attr.idlType.unionTypes != null or std.mem.startsWith(u8, cached_type_name, "(")) {
                // Union types: getter returns runtime.JSValue, so cache must store JSValue
                try writer.writeAll("runtime.JSValue");
            } else {
                // Regular type - use same type mapping as getter to ensure consistency
                // This is critical: cached field type MUST match getter return type
                const type_kind = if (type_registry) |reg| reg.lookup(attr.idlType.type) else null;
                const is_interface_type = type_kind != null and type_kind.? == .interface;
                const is_callback_interface_type = type_kind != null and type_kind.? == .callback_interface;

                if (is_callback_interface_type) {
                    // Callback interface types use ?*runtime.CallbackWrapper
                    try writer.writeAll("?*runtime.CallbackWrapper");
                } else if (is_interface_type) {
                    // Interface types use *runtime.Instance
                    try writer.writeAll("*runtime.Instance");
                } else {
                    // Non-interface types - use mapWebIDLTypeWithRegistry to match getter
                    // This ensures cached value type matches what the getter returns
                    var return_type = if (type_registry) |reg|
                        mapWebIDLTypeWithRegistry(attr.idlType, reg).type_name
                    else
                        mapWebIDLType(attr.idlType);

                    // Convert bare anyopaque to JSValue (same as getter does)
                    if (std.mem.eql(u8, return_type, "anyopaque")) {
                        return_type = "runtime.JSValue";
                    }

                    try writer.writeAll(return_type);
                }
            }

            try writer.writeAll(" = null,\n");
        }
    }

    // Add _internal field for impl-specific state
    // This allows implementations to store custom state (like URLRecord)
    // while keeping the codegen automated
    // Always added, even for interfaces with no WebIDL attributes
    try writer.print("            _internal: ?*{s}.InternalState = null,\n", .{impl_name});

    try writer.writeAll("        },\n");

    // Complete the FlattenedState call
    try writer.writeAll("    );\n\n");
}

/// Write state type alias (references impl file)
///
/// For interfaces with manual impl files, we use the impl's State definition
/// and flatten it with inheritance/mixins.
///
/// Example output:
/// ```zig
/// pub const State = runtime.FlattenedState(Meta.BaseType, Meta.MixinTypes, EventTargetImpl.State);
/// ```
pub fn writeStateTypeAlias(
    writer: anytype,
    impl_name: []const u8,
) !void {
    try writer.print("    pub const State = runtime.FlattenedState(Meta.BaseType, Meta.MixinTypes, {s}.State);\n\n", .{impl_name});
}

/// Write constant getter functions
///
/// WebIDL constants become static getter functions that return const values.
///
/// Example output:
/// ```zig
/// /// WebIDL constant: const unsigned short ELEMENT_NODE = 1;
/// pub fn get_ELEMENT_NODE() u16 {
///     return 1;
/// }
/// ```
pub fn writeConstants(
    writer: anytype,
    constants: []const types.Constant,
) !void {
    if (constants.len == 0) return;

    try writer.writeAll("    // ========================================\n");
    try writer.writeAll("    // Constants (static getters)\n");
    try writer.writeAll("    // ========================================\n\n");

    for (constants) |constant| {
        const zig_type = idlTypeToZig(constant.idlType.type);

        // Skip void constants (these are placeholders and have no meaningful value)
        if (std.mem.eql(u8, zig_type, "void")) {
            continue;
        }

        // Write comment with WebIDL declaration
        try writer.writeAll("    /// WebIDL constant: const ");
        try writer.print("{s} {s} = ", .{ constant.idlType.type, constant.name });

        // Write value in comment
        switch (constant.value) {
            .integer => |val| try writer.print("{d}", .{val}),
            .float => |val| try writer.print("{d}", .{val}),
            .boolean => |val| try writer.print("{}", .{val}),
            .string => |val| try writer.print("\"{s}\"", .{val}),
            .infinity => |inf| {
                if (inf == .positive) {
                    try writer.writeAll("Infinity");
                } else {
                    try writer.writeAll("-Infinity");
                }
            },
            .nan => try writer.writeAll("NaN"),
            .null => try writer.writeAll("null"),
            .emptySequence => try writer.writeAll("[]"),
            .emptyDictionary => try writer.writeAll("{}"),
        }
        try writer.writeAll(";\n");

        // Write static getter function
        try writer.print("    pub fn get_{s}() {s} {{\n", .{ constant.name, zig_type });
        try writer.writeAll("        return ");

        // Write constant value
        switch (constant.value) {
            .integer => |val| try writer.print("{d}", .{val}),
            .float => |val| try writer.print("{d}", .{val}),
            .boolean => |val| try writer.print("{}", .{val}),
            .string => |val| try writer.print("\"{s}\"", .{val}),
            .infinity => |inf| {
                if (inf == .positive) {
                    try writer.writeAll("std.math.inf(");
                    try writer.print("{s}", .{zig_type});
                    try writer.writeAll(")");
                } else {
                    try writer.writeAll("-std.math.inf(");
                    try writer.print("{s}", .{zig_type});
                    try writer.writeAll(")");
                }
            },
            .nan => {
                try writer.writeAll("std.math.nan(");
                try writer.print("{s}", .{zig_type});
                try writer.writeAll(")");
            },
            .null => try writer.writeAll("null"),
            .emptySequence => try writer.writeAll("&.{}"), // Empty slice literal
            .emptyDictionary => try writer.writeAll(".{}"), // Empty struct literal
        }

        try writer.writeAll(";\n");
        try writer.writeAll("    }\n\n");
    }
}

/// Write ToJSON struct for an interface with [Default] toJSON
///
/// Per WebIDL spec, [Default] toJSON() returns an object with all exposed
/// regular (non-static) attributes from the interface and its inherited interfaces.
///
/// For interface-typed attributes (like DOMQuad.p1 which is DOMPoint), the ToJSON
/// struct uses `*runtime.Instance` pointers. These get converted to proper V8 objects
/// with correct prototype chains by the toV8Value conversion layer.
///
/// Example output for DOMRectReadOnly:
/// ```zig
/// /// ToJSON result struct for DOMRectReadOnly
/// /// Generated from [Default] toJSON extended attribute
/// pub const DOMRectReadOnlyToJSON = struct {
///     x: f64,
///     y: f64,
///     width: f64,
///     height: f64,
///     top: f64,
///     right: f64,
///     bottom: f64,
///     left: f64,
/// };
/// ```
///
/// Example output for DOMQuad (with interface-typed attributes):
/// ```zig
/// pub const DOMQuadToJSON = struct {
///     p1: *runtime.Instance,  // DOMPoint
///     p2: *runtime.Instance,  // DOMPoint
///     p3: *runtime.Instance,  // DOMPoint
///     p4: *runtime.Instance,  // DOMPoint
/// };
/// ```
pub fn writeToJSONStruct(
    writer: anytype,
    interface_name: []const u8,
    attrs: []const ir.ToJSONAttribute,
    ir_data: *const ir.IR,
) !void {
    if (attrs.len == 0) return;

    try writer.writeAll("    // ========================================\n");
    try writer.writeAll("    // ToJSON Struct ([Default] toJSON result)\n");
    try writer.writeAll("    // ========================================\n\n");

    try writer.print("    /// ToJSON result struct for {s}\n", .{interface_name});
    try writer.writeAll("    /// Generated from [Default] toJSON extended attribute\n");
    try writer.print("    pub const {s}ToJSON = struct {{\n", .{interface_name});

    for (attrs) |attr| {
        const zig_type = idlTypeToZigForToJSON(attr.idl_type.type, ir_data);
        try writer.print("        {s}: {s},\n", .{ attr.name, zig_type });
    }

    try writer.writeAll("    };\n\n");
}

/// Convert IDL type to Zig type for ToJSON struct fields
///
/// This is similar to idlTypeToZig but handles interface types specially:
/// interface-typed attributes become `*runtime.Instance` pointers, which
/// allows the V8 conversion layer to wrap them with proper prototypes.
fn idlTypeToZigForToJSON(idl_type_name: []const u8, ir_data: *const ir.IR) []const u8 {
    // First check if it's a known primitive/built-in type
    const primitive_result = idlTypeToZig(idl_type_name);

    // If idlTypeToZig returned the type name unchanged, it's likely an interface type
    // Check if it exists in our IR's interface map
    if (std.mem.eql(u8, primitive_result, idl_type_name)) {
        // It's not a known primitive - check if it's an interface
        if (ir_data.interfaces.contains(idl_type_name)) {
            // Interface-typed attributes in toJSON become runtime Instance pointers
            // The V8 toV8Value function will convert these to proper JS objects
            return "*runtime.Instance";
        }
    }

    return primitive_result;
}

/// Write VTable constant
///
/// Example output:
/// ```zig
/// pub const vtable = runtime.buildVTable(.{
///     .deinit = &deinit,
///     .get_ELEMENT_NODE = &Node.get_ELEMENT_NODE,
///     .get_id = &get_id,
///     .get_title = &get_title,
///
///     .set_id = &set_id,
///     .set_title = &set_title,
///
///     .call_addEventListener = &call_addEventListener,
///     .call_remove = &call_remove,
/// });
/// ```
pub fn writeVTable(
    writer: anytype,
    all_constants: []const types.Constant,
    own_constants: []const types.Constant,
    own_attributes: []const types.Attribute,
    own_operations: []const types.Operation,
    interface_name: []const u8,
) !void {
    const allocator = std.heap.page_allocator;

    // Generate delegates struct first, then create vtable from it
    try writer.writeAll("    const delegates = .{\n");
    // Note: deinit is now passed as second parameter at the end

    // Collect all getters (attributes + constants) with their references
    var getters = std.ArrayList(VTableEntry).empty;
    defer getters.deinit(allocator);

    // Add attribute getters - ONLY for own attributes (not inherited)
    for (own_attributes) |attr| {
        const sanitized_name = try sanitizeFunctionName(allocator, attr.name);
        const name_was_sanitized = !std.mem.eql(u8, sanitized_name, attr.name);

        // Store sanitized name - keep allocated if sanitized, duplicate if not
        const stored_name = if (name_was_sanitized)
            sanitized_name
        else
            try allocator.dupe(u8, sanitized_name);

        try getters.append(allocator, .{
            .name = stored_name,
            .reference = try std.fmt.allocPrint(allocator, "&get_{s}", .{stored_name}),
            .is_allocated = true,
        });
    }

    // Add constant getters - constants are exposed as readonly properties on instances
    for (own_constants) |constant| {
        const zig_type = idlTypeToZig(constant.idlType.type);

        // Skip void constants (these are placeholders and have no getter)
        if (std.mem.eql(u8, zig_type, "void")) {
            continue;
        }

        const sanitized_name = try sanitizeFunctionName(allocator, constant.name);
        const name_was_sanitized = !std.mem.eql(u8, sanitized_name, constant.name);

        const stored_name = if (name_was_sanitized)
            sanitized_name
        else
            try allocator.dupe(u8, sanitized_name);

        try getters.append(allocator, .{
            .name = stored_name,
            .reference = try std.fmt.allocPrint(allocator, "&get_{s}", .{stored_name}),
            .is_allocated = true,
        });
    }

    _ = all_constants; // Suppress unused warning (own_constants is used above)

    // Sort getters alphabetically by name
    std.mem.sort(VTableEntry, getters.items, {}, vtableEntryLessThan);

    // Deduplicate getters (keep first occurrence, free duplicates)
    try deduplicateVTableEntries(allocator, &getters);

    // Collect setters - ONLY for own attributes (not inherited)
    // Include non-readonly attributes AND [Replaceable] OR [PutForwards] OR [LegacyLenientSetter] readonly attributes
    const extattr_mod = @import("extattr.zig");
    var setters = std.ArrayList(VTableEntry).empty;
    defer setters.deinit(allocator);

    for (own_attributes) |attr| {
        // Generate setter for non-readonly OR [Replaceable] OR [PutForwards] OR [LegacyLenientSetter] readonly attributes
        const is_replaceable = extattr_mod.isReplaceable(attr.extAttrs);
        const has_put_forwards = extattr_mod.getPutForwards(attr.extAttrs) != null;
        const is_legacy_lenient_setter = extattr_mod.isLegacyLenientSetter(attr.extAttrs);
        if (!attr.readonly or is_replaceable or has_put_forwards or is_legacy_lenient_setter) {
            const sanitized_name = try sanitizeFunctionName(allocator, attr.name);
            const name_was_sanitized = !std.mem.eql(u8, sanitized_name, attr.name);

            // Store sanitized name - keep allocated if sanitized, duplicate if not
            const stored_name = if (name_was_sanitized)
                sanitized_name
            else
                try allocator.dupe(u8, sanitized_name);

            try setters.append(allocator, .{
                .name = stored_name,
                .reference = try std.fmt.allocPrint(allocator, "&set_{s}", .{stored_name}),
                .is_allocated = true,
            });
        }
    }

    // Sort setters alphabetically by name
    std.mem.sort(VTableEntry, setters.items, {}, vtableEntryLessThan);

    // Deduplicate setters (keep first occurrence, free duplicates)
    try deduplicateVTableEntries(allocator, &setters);

    // Group operations by name to handle overloads - ONLY for own operations (not inherited)
    const overload_sets = try overload.groupOperationsByName(allocator, own_operations);
    defer overload.freeOverloadSets(allocator, overload_sets);

    // Collect operations (one vtable entry per operation name, regardless of overloads)
    var calls = std.ArrayList(VTableEntry).empty;
    defer calls.deinit(allocator);

    for (overload_sets) |set| {
        // Each overload set has one operation name
        if (set.operations.len > 0) {
            // Skip static operations - they are bound to the constructor, not vtable
            if (set.operations[0].static) continue;

            if (set.operations[0].name) |name| {
                const sanitized_name = try sanitizeFunctionName(allocator, name);
                const name_was_sanitized = !std.mem.eql(u8, sanitized_name, name);

                // Store sanitized name - keep allocated if sanitized, duplicate if not
                const stored_name = if (name_was_sanitized)
                    sanitized_name
                else
                    try allocator.dupe(u8, sanitized_name);

                try calls.append(allocator, .{
                    .name = stored_name,
                    .reference = try std.fmt.allocPrint(allocator, "&call_{s}", .{stored_name}),
                    .is_allocated = true,
                });
            }
        }
    }

    // Sort operations alphabetically by name
    std.mem.sort(VTableEntry, calls.items, {}, vtableEntryLessThan);

    // Deduplicate operations (keep first occurrence, free duplicates)
    try deduplicateVTableEntries(allocator, &calls);

    // Emit getters (blank line before)
    if (getters.items.len > 0) {
        try writer.writeAll("\n");
        for (getters.items) |entry| {
            try writer.print("        .get_{s} = {s},\n", .{ entry.name, entry.reference });
            if (entry.is_allocated) {
                allocator.free(entry.name);
                allocator.free(entry.reference);
            }
        }
    }

    // Emit setters (blank line before)
    if (setters.items.len > 0) {
        try writer.writeAll("\n");
        for (setters.items) |entry| {
            try writer.print("        .set_{s} = {s},\n", .{ entry.name, entry.reference });
            if (entry.is_allocated) {
                allocator.free(entry.name);
                allocator.free(entry.reference);
            }
        }
    }

    // Emit operations (blank line before, but no blank line after - it's the last group)
    if (calls.items.len > 0) {
        try writer.writeAll("\n");
        for (calls.items) |entry| {
            try writer.print("        .call_{s} = {s},\n", .{ entry.name, entry.reference });
            if (entry.is_allocated) {
                allocator.free(entry.name);
                allocator.free(entry.reference);
            }
        }
    }

    // Add CSS property named handlers for CSSStyleDeclaration and related interfaces
    // These enable named property access for CSS properties (style.color, style.backgroundColor)
    if (isCSSDeclarationInterface(interface_name)) {
        try writer.writeAll("\n        .call_namedItem = &call_namedItem,\n");
        try writer.writeAll("        .call_setNamedItem = &call_setNamedItem,\n");
    }

    // Add deinit for cleanup when V8 GC collects the wrapper object
    try writer.writeAll("\n        .deinit = &deinit,\n");

    try writer.writeAll("    };\n");
    // buildVTable auto-extracts .deinit from delegates struct
    try writer.writeAll("    pub const vtable = runtime.buildVTable(&delegates);\n\n");
}

/// VTable entry for sorting
const VTableEntry = struct {
    name: []const u8,
    reference: []const u8,
    is_allocated: bool,
};

/// Compare VTable entries for alphabetical sorting
fn vtableEntryLessThan(_: void, a: VTableEntry, b: VTableEntry) bool {
    return std.mem.lessThan(u8, a.name, b.name);
}

/// Deduplicate VTable entries by name (keep first, remove subsequent duplicates)
/// Assumes the list is already sorted by name
fn deduplicateVTableEntries(allocator: std.mem.Allocator, entries: *std.ArrayList(VTableEntry)) !void {
    if (entries.items.len <= 1) return;

    var write_idx: usize = 0;
    var read_idx: usize = 1;

    while (read_idx < entries.items.len) {
        // If current name differs from previous, keep it
        if (!std.mem.eql(u8, entries.items[read_idx].name, entries.items[write_idx].name)) {
            write_idx += 1;
            entries.items[write_idx] = entries.items[read_idx];
        } else {
            // Duplicate - free both name and reference if allocated
            if (entries.items[read_idx].is_allocated) {
                allocator.free(entries.items[read_idx].name);
                allocator.free(entries.items[read_idx].reference);
            }
        }
        read_idx += 1;
    }

    // Truncate the list to remove duplicates
    try entries.resize(allocator, write_idx + 1);
}

/// Check if a constant is in the list (by name comparison)
fn isConstantInList(needle: types.Constant, haystack: []const types.Constant) bool {
    for (haystack) |item| {
        if (std.mem.eql(u8, needle.name, item.name)) {
            return true;
        }
    }
    return false;
}

/// Write lifecycle functions
///
/// Example output:
/// ```zig
/// pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
///     const instance = try runtime.SlabAllocator.get().alloc(&vtable);
///     errdefer runtime.SlabAllocator.get().free(instance);
///
///     const state = try runtime.ArenaAllocator.get().create(State);
///     instance.state = state;
///
///     // Initialize the state (Impl receives full hierarchy)
///     ImplType.init(state);
///
///     return instance;
/// }
///
/// pub fn deinit(instance: *runtime.Instance) void {
///     const state = instance.getState(State);
///     ImplType.deinit(state);
/// }
/// ```
pub fn writeLifecycleFunctions(
    writer: anytype,
    impl_name: []const u8,
) !void {
    // init() - delegates to Impl.init() which delegates to Instance.init()
    try writer.writeAll("    /// Initialize a new instance\n");
    try writer.writeAll("    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {\n");
    try writer.print("        return {s}.init(allocator, State, &vtable, ctx);\n", .{impl_name});
    try writer.writeAll("    }\n\n");

    // initWithState() - for subclasses to call with their own StateType and vtable
    try writer.writeAll("    /// Initialize with custom state type (for subclasses)\n");
    try writer.writeAll("    /// Subclasses call this to properly initialize the base class state.\n");
    try writer.writeAll("    pub fn initWithState(\n");
    try writer.writeAll("        allocator: std.mem.Allocator,\n");
    try writer.writeAll("        comptime StateType: type,\n");
    try writer.writeAll("        vtable_ptr: *const runtime.VTable,\n");
    try writer.writeAll("        ctx: runtime.Context,\n");
    try writer.writeAll("    ) !*runtime.Instance {\n");
    try writer.print("        return {s}.init(allocator, StateType, vtable_ptr, ctx);\n", .{impl_name});
    try writer.writeAll("    }\n\n");

    // deinit() - delegates to Impl.deinit()
    try writer.writeAll("    /// Clean up instance resources\n");
    try writer.print("    pub fn deinit(instance: *runtime.Instance) void {{\n", .{});
    try writer.print("        {s}.deinit(instance);\n", .{impl_name});
    try writer.writeAll("    }\n\n");
}

/// Write WebIDL constructor function
///
/// Example output:
/// ```zig
/// pub fn call_constructor(allocator: std.mem.Allocator, type_param: runtime.DOMString) !*runtime.Instance {
///     const instance = try init(allocator);
///     errdefer deinit(instance);
///
///     const state = instance.getState(State);
///     try EventImpl.construct(state, type_param);
///
///     return instance;
/// }
/// ```
pub fn writeConstructor(
    writer: anytype,
    impl_name: []const u8,
    constructor: types.Constructor,
    type_registry: ?*const @import("ir.zig").TypeRegistry,
) !void {
    try writer.writeAll("    /// WebIDL constructor\n");
    try writer.writeAll("    /// Note: Uses ctx.allocator internally for all allocations to ensure\n");
    try writer.writeAll("    /// consistency with deinit which uses instance.ctx.allocator\n");
    try writer.writeAll("    pub fn call_constructor(ctx: runtime.Context");

    // Write constructor parameters
    for (constructor.arguments) |arg| {
        try writer.writeAll(", ");
        try writeEscapedInterfaceParamName(writer, arg.name, arg.idlType);
        try writer.writeAll(": ");

        // Handle optional parameters: optional T becomes Opt(T)
        if (arg.optional) {
            try writer.writeAll("webidl.Opt(");
        }

        // Handle variadic parameters: T... becomes []const T
        if (arg.variadic) {
            try writer.writeAll("[]const ");
        }

        // Check for union types FIRST (before anyopaque fallback)
        if (arg.idlType.unionTypes) |union_types| {
            if (isNodeOrDOMStringUnion(union_types)) {
                // Handle nullable union types
                if (arg.idlType.nullable and !arg.variadic) {
                    try writer.writeAll("?");
                }
                try writer.writeAll("mixins.ParentNode.NodeOrString");

                // Close optional wrapper if needed
                if (arg.optional) {
                    try writer.writeAll(")");
                }
                continue; // Skip rest of type processing
            }
        }

        const type_mapping = if (type_registry) |reg|
            mapWebIDLTypeWithRegistry(arg.idlType, reg)
        else
            TypeMapping{ .type_name = mapWebIDLType(arg.idlType), .needs_import = false };

        var arg_type = type_mapping.type_name;

        // Check if this is an interface type - if so, use *runtime.Instance
        // Callback interfaces use ?*runtime.CallbackWrapper
        const type_kind = if (type_registry) |reg| reg.lookup(arg.idlType.type) else null;
        const is_interface = type_kind != null and type_kind.? == .interface;
        const is_callback_interface = type_kind != null and type_kind.? == .callback_interface;

        // If we got anyopaque (union type or unknown), use JSValue for type safety
        if (std.mem.eql(u8, arg_type, "anyopaque")) {
            arg_type = "runtime.JSValue";
        }

        // For callback interface types, use ?*runtime.CallbackWrapper
        // For regular interface types, use *runtime.Instance directly
        // Handle nullable parameters: T? becomes ?T (but not for variadic - slice handles null)
        if (is_callback_interface) {
            if (arg.idlType.nullable and !arg.variadic) {
                try writer.writeAll("?");
            }
            try writer.writeAll("?*runtime.CallbackWrapper");
        } else if (is_interface) {
            if (arg.idlType.nullable and !arg.variadic) {
                try writer.writeAll("?");
            }
            try writer.writeAll("*runtime.Instance");
        } else {
            if (arg.idlType.nullable and !arg.variadic) {
                try writer.writeAll("?");
            }
            try writer.print("{s}", .{arg_type});
        }

        // Close optional wrapper if needed
        if (arg.optional) {
            try writer.writeAll(")");
        }
    }

    try writer.writeAll(") !*runtime.Instance {\n");
    try writer.writeAll("        // Directly return result from impl.call_constructor\n");
    try writer.print("        return try {s}.call_constructor(ctx", .{impl_name});

    // Pass arguments to impl constructor
    // Note: webidl.Opt() parameters are passed directly (not unwrapped)
    // The impl is responsible for checking .wasPassed() and handling defaults
    for (constructor.arguments) |arg| {
        try writer.writeAll(", ");
        try writeEscapedInterfaceParamName(writer, arg.name, arg.idlType);
    }

    try writer.writeAll(");\n");
    try writer.writeAll("    }\n\n");
}

/// Write overloaded constructor with tagged union dispatch
///
/// Example output:
/// ```zig
/// pub const ConstructorArgs = union(enum) {
///     no_params: void,
///     angle: CSSNumericValue,
///     x_y_z_angle: struct { x: CSSNumberish, y: CSSNumberish, z: CSSNumberish, angle: CSSNumericValue },
/// };
///
/// pub fn call_constructor(allocator: std.mem.Allocator, args: ConstructorArgs) !*runtime.Instance {
///     switch (args) {
///         .no_params => ...,
///         .angle => |angle_val| ...,
///         .x_y_z_angle => |a| ...,
///     }
/// }
/// ```
pub fn writeOverloadedConstructor(
    writer: anytype,
    impl_name: []const u8,
    set: overload.ConstructorSet,
    type_registry: ?*const @import("ir.zig").TypeRegistry,
) !void {
    const allocator = std.heap.page_allocator;

    // Generate ConstructorArgs union type
    try writer.writeAll("    /// Arguments for constructor (WebIDL overloading)\n");
    try writer.writeAll("    pub const ConstructorArgs = union(enum) {\n");

    // Generate variant for each overload
    for (set.constructors) |ctor| {
        const variant_name = try overload.generateConstructorVariantName(allocator, ctor);
        defer allocator.free(variant_name);

        if (ctor.arguments.len == 0) {
            try writer.writeAll("        /// constructor()\n");
            try writer.print("        {s}: void,\n", .{variant_name});
        } else if (ctor.arguments.len == 1) {
            // Build type with optional, variadic, nullable, and union handling
            var buffer: [512]u8 = undefined;
            var fbs = std.io.fixedBufferStream(&buffer);
            const arg = ctor.arguments[0];

            // Optional: optional T -> webidl.Opt(T)
            if (arg.optional) {
                try fbs.writer().writeAll("webidl.Opt(");
            }

            // Variadic: T... -> []const T
            if (arg.variadic) {
                try fbs.writer().writeAll("[]const ");
            }

            // Check for union types FIRST
            if (arg.idlType.unionTypes) |union_types| {
                if (isNodeOrDOMStringUnion(union_types)) {
                    if (arg.idlType.nullable and !arg.variadic) {
                        try fbs.writer().writeByte('?');
                    }
                    try fbs.writer().writeAll("mixins.ParentNode.NodeOrString");
                    if (arg.optional) {
                        try fbs.writer().writeByte(')');
                    }
                    try writer.print("        /// constructor({s})\n", .{arg.name});
                    try writer.print("        {s}: {s},\n", .{ variant_name, fbs.getWritten() });
                    continue;
                }
            }

            // Nullable: T? -> ?T (but not for variadic)
            if (arg.idlType.nullable and !arg.variadic) {
                try fbs.writer().writeByte('?');
            }

            var base_type = if (type_registry) |reg|
                mapWebIDLTypeWithRegistry(arg.idlType, reg).type_name
            else
                mapWebIDLType(arg.idlType);
            if (std.mem.eql(u8, base_type, "anyopaque")) {
                base_type = "runtime.JSValue";
            }
            try fbs.writer().writeAll(base_type);

            // Close optional wrapper
            if (arg.optional) {
                try fbs.writer().writeByte(')');
            }

            try writer.print("        /// constructor({s})\n", .{arg.name});
            try writer.print("        {s}: {s},\n", .{ variant_name, fbs.getWritten() });
        } else {
            try writer.writeAll("        /// constructor(");
            for (ctor.arguments, 0..) |arg, i| {
                if (i > 0) try writer.writeAll(", ");
                try writer.print("{s}", .{arg.name});
            }
            try writer.writeAll(")\n");

            try writer.print("        {s}: struct {{\n", .{variant_name});
            for (ctor.arguments) |arg| {
                // Build type with optional, variadic, nullable, and union handling
                var buffer: [512]u8 = undefined;
                var fbs = std.io.fixedBufferStream(&buffer);

                // Optional: optional T -> webidl.Opt(T)
                if (arg.optional) {
                    try fbs.writer().writeAll("webidl.Opt(");
                }

                // Variadic: T... -> []const T
                if (arg.variadic) {
                    try fbs.writer().writeAll("[]const ");
                }

                // Check for union types FIRST
                var is_union = false;
                if (arg.idlType.unionTypes) |union_types| {
                    if (isNodeOrDOMStringUnion(union_types)) {
                        if (arg.idlType.nullable and !arg.variadic) {
                            try fbs.writer().writeByte('?');
                        }
                        try fbs.writer().writeAll("mixins.ParentNode.NodeOrString");
                        if (arg.optional) {
                            try fbs.writer().writeByte(')');
                        }
                        is_union = true;
                    }
                }

                if (!is_union) {
                    // Nullable: T? -> ?T (but not for variadic)
                    if (arg.idlType.nullable and !arg.variadic) {
                        try fbs.writer().writeByte('?');
                    }

                    var base_type = if (type_registry) |reg|
                        mapWebIDLTypeWithRegistry(arg.idlType, reg).type_name
                    else
                        mapWebIDLType(arg.idlType);
                    if (std.mem.eql(u8, base_type, "anyopaque")) {
                        base_type = "runtime.JSValue";
                    }
                    try fbs.writer().writeAll(base_type);

                    // Close optional wrapper
                    if (arg.optional) {
                        try fbs.writer().writeByte(')');
                    }
                }

                // Escape Zig keywords using @"..." syntax
                if (isKeyword(arg.name)) {
                    try writer.print("            @\"{s}\": {s},\n", .{ arg.name, fbs.getWritten() });
                } else {
                    try writer.print("            {s}: {s},\n", .{ arg.name, fbs.getWritten() });
                }
            }
            try writer.writeAll("        },\n");
        }
    }

    try writer.writeAll("    };\n\n");

    // Generate dispatch function
    try writer.writeAll("    /// WebIDL constructor (overloaded)\n");
    try writer.writeAll("    /// Note: Uses ctx.allocator internally for all allocations to ensure\n");
    try writer.writeAll("    /// consistency with deinit which uses instance.ctx.allocator\n");
    try writer.writeAll("    pub fn call_constructor(ctx: runtime.Context, args: ConstructorArgs) !*runtime.Instance {\n");
    try writer.writeAll("        // Pass args union directly to impl\n");
    try writer.print("        return try {s}.call_constructor(ctx, args);\n", .{impl_name});
    try writer.writeAll("    }\n\n");
}

/// Write delegate functions for attributes and operations
///
/// Example output:
/// ```zig
/// pub fn get_eventPhase(instance: *runtime.Instance) u16 {
///     const state = instance.getState(State);
///     return EventTargetImpl.get_eventPhase(state);
/// }
///
/// pub fn set_id(instance: *runtime.Instance, value: runtime.DOMString) void {
///     const state = instance.getState(State);
///     EventTargetImpl.set_id(state, value);
/// }
/// ```
/// Check if extended attributes contain a specific attribute by name
fn hasExtendedAttribute(ext_attrs: []const types.ExtendedAttribute, name: []const u8) bool {
    for (ext_attrs) |attr| {
        if (std.mem.eql(u8, attr.name, name)) return true;
    }
    return false;
}

/// Write extended attributes as doc comments
fn writeExtendedAttributesComment(writer: anytype, ext_attrs: []const types.ExtendedAttribute) !void {
    if (ext_attrs.len == 0) return;

    try writer.writeAll("    /// Extended attributes: ");
    for (ext_attrs, 0..) |attr, i| {
        if (i > 0) try writer.writeAll(", ");
        try writer.print("[{s}", .{attr.name});
        if (attr.rhs) |rhs| {
            switch (rhs) {
                .identifier => |id| try writer.print("={s}", .{id}),
                .identifierList => |list| {
                    try writer.writeAll("=(");
                    for (list, 0..) |id, j| {
                        if (j > 0) try writer.writeAll(",");
                        try writer.print("{s}", .{id});
                    }
                    try writer.writeAll(")");
                },
                .string => |s| try writer.print("=\"{s}\"", .{s}),
                .integer => |n| try writer.print("={d}", .{n}),
            }
        }
        try writer.writeAll("]");
    }
    try writer.writeAll("\n");
}

/// Write a single non-overloaded operation
fn writeSingleOperation(
    writer: anytype,
    impl_name: []const u8,
    op: types.Operation,
    type_registry: ?*const @import("ir.zig").TypeRegistry,
    _: bool, // has_static_collision - no longer used
) !void {
    const allocator = std.heap.page_allocator;
    const name = op.name orelse if (op.special) |special| @tagName(special) else return; // Skip unnamed operations without special type

    // Static methods always use call_static_<name> convention
    // Instance methods use call_<name> convention
    const is_static = op.static;

    // Check for [Default] toJSON - returns {InterfaceName}ToJSON struct
    const is_default_to_json = std.mem.eql(u8, name, "toJSON") and types.hasDefaultExtAttr(op);

    // Derive interface name from impl_name (strip "Impl" suffix)
    const interface_name = if (std.mem.endsWith(u8, impl_name, "Impl"))
        impl_name[0 .. impl_name.len - 4]
    else
        impl_name;

    // For [Default] toJSON, allocate the struct type name
    var to_json_type_buf: ?[]u8 = null;
    defer if (to_json_type_buf) |buf| allocator.free(buf);

    var return_type: []const u8 = undefined;

    if (is_default_to_json) {
        // Return the ToJSON struct type for [Default] toJSON operations
        to_json_type_buf = try std.fmt.allocPrint(allocator, "{s}ToJSON", .{interface_name});
        return_type = to_json_type_buf.?;
    } else {
        // Check if return type is an interface - if so, use *runtime.Instance
        // Callback interfaces use ?*runtime.CallbackWrapper
        const return_type_kind = if (type_registry) |reg| reg.lookup(op.idlType.type) else null;
        const is_interface_return = return_type_kind != null and return_type_kind.? == .interface;
        const is_callback_interface_return = return_type_kind != null and return_type_kind.? == .callback_interface;

        return_type = if (is_callback_interface_return)
            "?*runtime.CallbackWrapper"
        else if (is_interface_return)
            "*runtime.Instance"
        else if (type_registry) |reg|
            mapWebIDLTypeWithRegistry(op.idlType, reg).type_name
        else
            mapWebIDLType(op.idlType);

        // Convert bare anyopaque to JSValue (for sequences, promises, union types, etc.)
        // These are truly unknown/dynamic types that need runtime handling
        if (std.mem.eql(u8, return_type, "anyopaque")) {
            return_type = "runtime.JSValue";
        }
    }

    // Check if return type is nullable (WebIDL T? type)
    const is_nullable_return = op.idlType.nullable;

    const has_ce_reactions = hasExtendedAttribute(op.extAttrs, "CEReactions");
    const has_new_object = hasExtendedAttribute(op.extAttrs, "NewObject");

    // Write extended attributes as comment
    try writeExtendedAttributesComment(writer, op.extAttrs);

    // Generate function name: call_static_<name> for static, call_<name> for instance
    if (is_static) {
        try writer.print("    pub fn call_static_{s}(instance: *runtime.Instance", .{name});
    } else {
        try writer.print("    pub fn call_{s}(instance: *runtime.Instance", .{name});
    }

    // Write parameters
    for (op.arguments) |arg| {
        try writer.writeAll(", ");
        try writeEscapedInterfaceParamName(writer, arg.name, arg.idlType);
        try writer.writeAll(": ");

        // Handle optional parameters: optional T becomes Opt(T)
        if (arg.optional) {
            try writer.writeAll("webidl.Opt(");
        }

        // Handle variadic parameters: T... becomes []const T
        if (arg.variadic) {
            try writer.writeAll("[]const ");
        }

        // Check for union types FIRST (before anyopaque fallback)
        // This handles both variadic and non-variadic union parameters
        if (arg.idlType.unionTypes) |union_types| {
            if (isNodeOrDOMStringUnion(union_types)) {
                // Use tagged union for (Node or DOMString) pattern
                // Handle nullable: (Node or DOMString)? is unusual but possible
                if (arg.idlType.nullable and !arg.variadic) {
                    try writer.writeAll("?");
                }
                try writer.writeAll("mixins.ParentNode.NodeOrString");

                // Close optional wrapper if needed
                if (arg.optional) {
                    try writer.writeAll(")");
                }
                continue; // Skip rest of type processing
            }
            // TODO: Handle other union types (TrustedType or DOMString, etc.)
        }

        // Check if parameter type is an interface - if so, use *runtime.Instance
        // Callback interfaces use ?*runtime.CallbackWrapper through EngineInterface
        const type_kind = if (type_registry) |reg| reg.lookup(arg.idlType.type) else null;
        const is_interface_param = type_kind != null and type_kind.? == .interface;
        const is_callback_interface_param = type_kind != null and type_kind.? == .callback_interface;

        var arg_type = if (is_callback_interface_param)
            "?*runtime.CallbackWrapper"
        else if (is_interface_param)
            "*runtime.Instance"
        else if (type_registry) |reg|
            mapWebIDLTypeWithRegistry(arg.idlType, reg).type_name
        else
            mapWebIDLType(arg.idlType);

        // Convert bare anyopaque to JSValue (for unknown types, sequences, promises, etc.)
        // These are truly dynamic types that need runtime handling
        if (std.mem.eql(u8, arg_type, "anyopaque")) {
            arg_type = "runtime.JSValue";
        }

        // Handle nullable parameters: T? becomes ?T (but not for variadic - slice handles null)
        if (arg.idlType.nullable and !arg.variadic) {
            try writer.print("?{s}", .{arg_type});
        } else {
            try writer.print("{s}", .{arg_type});
        }

        // Close optional wrapper if needed
        if (arg.optional) {
            try writer.writeAll(")");
        }
    }

    // For nullable return types, return ?T instead of T (allows returning null instead of error)
    if (is_nullable_return) {
        try writer.print(") anyerror!?{s} {{\n", .{return_type});
    } else {
        try writer.print(") anyerror!{s} {{\n", .{return_type});
    }

    if (has_ce_reactions) {
        try writer.writeAll("        // [CEReactions] - Trigger Custom Element lifecycle callbacks\n");
        try writer.writeAll("        runtime.CEReactions.begin();\n");
        try writer.writeAll("        defer runtime.CEReactions.end();\n");
        try writer.writeAll("        \n");
    }

    if (has_new_object) {
        try writer.writeAll("        // [NewObject] - Caller owns the returned object\n");
    }

    // Validate/clamp arguments
    for (op.arguments) |arg| {
        const has_enforce_range = hasExtendedAttribute(arg.extAttrs, "EnforceRange");
        const has_clamp = hasExtendedAttribute(arg.extAttrs, "Clamp");

        if (has_enforce_range) {
            try writer.writeAll("        // [EnforceRange] on ");
            try writeEscapedInterfaceParamName(writer, arg.name, arg.idlType);
            try writer.writeAll("\n        if (!runtime.isInRange(");
            try writeZigType(writer, arg.idlType.type);
            try writer.writeAll(", ");
            try writeEscapedInterfaceParamName(writer, arg.name, arg.idlType);
            try writer.writeAll(")) return error.TypeError;\n");
        } else if (has_clamp) {
            try writer.writeAll("        // [Clamp] on ");
            try writeEscapedInterfaceParamName(writer, arg.name, arg.idlType);
            if (arg.optional) {
                // For optional params with [Clamp]: clamp if passed, otherwise pass notPassed()
                try writer.print("\n        const clamped_{s} = if (", .{arg.name});
                try writeEscapedInterfaceParamName(writer, arg.name, arg.idlType);
                try writer.writeAll(".wasPassed()) webidl.Opt(");
                try writeZigType(writer, arg.idlType.type);
                try writer.writeAll(").passed(runtime.clamp(");
                try writeZigType(writer, arg.idlType.type);
                try writer.writeAll(", ");
                try writeEscapedInterfaceParamName(writer, arg.name, arg.idlType);
                try writer.writeAll(".value)) else webidl.Opt(");
                try writeZigType(writer, arg.idlType.type);
                try writer.writeAll(").notPassed();\n");
            } else {
                try writer.print("\n        const clamped_{s} = runtime.clamp(", .{arg.name});
                try writeZigType(writer, arg.idlType.type);
                try writer.writeAll(", ");
                try writeEscapedInterfaceParamName(writer, arg.name, arg.idlType);
                try writer.writeAll(");\n");
            }
        }
    }

    if (op.arguments.len > 0) {
        try writer.writeAll("        \n");
    }

    // Call impl with matching convention: call_static_<name> for static, call_<name> for instance
    if (is_static) {
        try writer.print("        return try {s}.call_static_{s}(instance", .{ impl_name, name });
    } else {
        try writer.print("        return try {s}.call_{s}(instance", .{ impl_name, name });
    }

    // Pass arguments
    // Note: webidl.Opt() parameters are passed directly (not unwrapped)
    // The impl is responsible for checking .wasPassed() and handling defaults
    for (op.arguments) |arg| {
        const has_clamp = hasExtendedAttribute(arg.extAttrs, "Clamp");

        if (has_clamp) {
            try writer.print(", clamped_{s}", .{arg.name});
        } else {
            try writer.writeAll(", ");
            try writeEscapedInterfaceParamName(writer, arg.name, arg.idlType);
        }
    }

    try writer.writeAll(");\n");
    try writer.writeAll("    }\n\n");
}

/// Write an overloaded operation with tagged union dispatch
fn writeOverloadedOperation(
    writer: anytype,
    impl_name: []const u8,
    set: overload.OverloadSet,
    type_registry: ?*const @import("ir.zig").TypeRegistry,
) !void {
    const allocator = std.heap.page_allocator;
    const name = set.name;

    // Determine the common return type (should be same for all overloads)
    const return_type = if (type_registry) |reg|
        mapWebIDLTypeWithRegistry(set.operations[0].idlType, reg).type_name
    else
        mapWebIDLType(set.operations[0].idlType);

    // Check if return type is nullable (WebIDL T? type)
    const is_nullable_return = set.operations[0].idlType.nullable;

    // Generate Args union type
    try writer.print("    /// Arguments for {s} (WebIDL overloading)\n", .{name});
    const cap_name = try capitalize(allocator, name);
    defer allocator.free(cap_name);
    try writer.print("    pub const {s}Args = union(enum) {{\n", .{cap_name});

    // Generate variant for each overload
    for (set.operations) |op| {
        const variant_name = try overload.generateVariantName(allocator, op);
        defer allocator.free(variant_name);

        if (op.arguments.len == 0) {
            try writer.print("        /// {s}()\n", .{name});
            try writer.print("        {s}: void,\n", .{variant_name});
        } else if (op.arguments.len == 1) {
            // Build type with optional, variadic, nullable, and union handling
            var buffer: [512]u8 = undefined;
            var fbs = std.io.fixedBufferStream(&buffer);
            const arg = op.arguments[0];

            // Optional: optional T -> webidl.Opt(T)
            if (arg.optional) {
                try fbs.writer().writeAll("webidl.Opt(");
            }

            // Variadic: T... -> []const T
            if (arg.variadic) {
                try fbs.writer().writeAll("[]const ");
            }

            // Check for union types FIRST
            if (arg.idlType.unionTypes) |union_types| {
                if (isNodeOrDOMStringUnion(union_types)) {
                    if (arg.idlType.nullable and !arg.variadic) {
                        try fbs.writer().writeByte('?');
                    }
                    try fbs.writer().writeAll("mixins.ParentNode.NodeOrString");
                    if (arg.optional) {
                        try fbs.writer().writeByte(')');
                    }
                    try writer.print("        /// {s}({s})\n", .{ name, arg.name });
                    try writer.print("        {s}: {s},\n", .{ variant_name, fbs.getWritten() });
                    continue;
                }
            }

            // Nullable: T? -> ?T (but not for variadic)
            if (arg.idlType.nullable and !arg.variadic) {
                try fbs.writer().writeByte('?');
            }

            const base_type = if (type_registry) |reg|
                mapWebIDLTypeWithRegistry(arg.idlType, reg).type_name
            else
                mapWebIDLType(arg.idlType);
            try fbs.writer().writeAll(base_type);

            // Close optional wrapper
            if (arg.optional) {
                try fbs.writer().writeByte(')');
            }

            try writer.print("        /// {s}({s})\n", .{ name, arg.name });
            try writer.print("        {s}: {s},\n", .{ variant_name, fbs.getWritten() });
        } else {
            try writer.print("        /// {s}(", .{name});
            for (op.arguments, 0..) |arg, i| {
                if (i > 0) try writer.writeAll(", ");
                try writer.print("{s}", .{arg.name});
            }
            try writer.writeAll(")\n");

            try writer.print("        {s}: struct {{\n", .{variant_name});
            for (op.arguments) |arg| {
                // Build type with optional, variadic, nullable, and union handling
                var buffer: [512]u8 = undefined;
                var fbs = std.io.fixedBufferStream(&buffer);

                // Optional: optional T -> webidl.Opt(T)
                if (arg.optional) {
                    try fbs.writer().writeAll("webidl.Opt(");
                }

                // Variadic: T... -> []const T
                if (arg.variadic) {
                    try fbs.writer().writeAll("[]const ");
                }

                // Check for union types FIRST
                var is_union = false;
                if (arg.idlType.unionTypes) |union_types| {
                    if (isNodeOrDOMStringUnion(union_types)) {
                        if (arg.idlType.nullable and !arg.variadic) {
                            try fbs.writer().writeByte('?');
                        }
                        try fbs.writer().writeAll("mixins.ParentNode.NodeOrString");
                        if (arg.optional) {
                            try fbs.writer().writeByte(')');
                        }
                        is_union = true;
                    }
                }

                if (!is_union) {
                    // Nullable: T? -> ?T (but not for variadic)
                    if (arg.idlType.nullable and !arg.variadic) {
                        try fbs.writer().writeByte('?');
                    }

                    const base_type = if (type_registry) |reg|
                        mapWebIDLTypeWithRegistry(arg.idlType, reg).type_name
                    else
                        mapWebIDLType(arg.idlType);
                    try fbs.writer().writeAll(base_type);

                    // Close optional wrapper
                    if (arg.optional) {
                        try fbs.writer().writeByte(')');
                    }
                }

                // Escape Zig keywords using @"..." syntax
                if (isKeyword(arg.name)) {
                    try writer.print("            @\"{s}\": {s},\n", .{ arg.name, fbs.getWritten() });
                } else {
                    try writer.print("            {s}: {s},\n", .{ arg.name, fbs.getWritten() });
                }
            }
            try writer.writeAll("        },\n");
        }
    }

    try writer.writeAll("    };\n\n");

    // Generate dispatch function
    const cap_name2 = try capitalize(allocator, name);
    defer allocator.free(cap_name2);
    // For nullable return types, return ?T instead of T
    if (is_nullable_return) {
        try writer.print("    pub fn call_{s}(instance: *runtime.Instance, args: {s}Args) anyerror!?{s} {{\n", .{ name, cap_name2, return_type });
    } else {
        try writer.print("    pub fn call_{s}(instance: *runtime.Instance, args: {s}Args) anyerror!{s} {{\n", .{ name, cap_name2, return_type });
    }
    try writer.print("        switch (args) {{\n", .{});

    // Generate case for each variant
    for (set.operations) |op| {
        const variant_name = try overload.generateVariantName(allocator, op);
        defer allocator.free(variant_name);

        if (op.arguments.len == 0) {
            try writer.print("            .{s} => return try {s}.{s}(instance),\n", .{ variant_name, impl_name, variant_name });
        } else if (op.arguments.len == 1) {
            try writer.print("            .{s} => |arg| return try {s}.{s}(instance, arg),\n", .{ variant_name, impl_name, variant_name });
        } else {
            try writer.print("            .{s} => |a| return try {s}.{s}(instance", .{ variant_name, impl_name, variant_name });
            for (op.arguments) |arg| {
                // Use @"..." syntax for keywords
                if (isKeyword(arg.name)) {
                    try writer.print(", a.@\"{s}\"", .{arg.name});
                } else {
                    try writer.print(", a.{s}", .{arg.name});
                }
            }
            try writer.writeAll("),\n");
        }
    }

    try writer.writeAll("        }\n");
    try writer.writeAll("    }\n\n");
}

/// Capitalize first letter of a string
fn capitalize(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
    if (s.len == 0) return try allocator.dupe(u8, s);

    var result = try allocator.alloc(u8, s.len);
    result[0] = std.ascii.toUpper(s[0]);
    @memcpy(result[1..], s[1..]);
    return result;
}

pub fn writeDelegateFunctions(
    writer: anytype,
    impl_name: []const u8,
    type_registry: ?*const @import("ir.zig").TypeRegistry,
    own_attributes: []const types.Attribute,
    own_operations: []const types.Operation,
) !void {
    const allocator = std.heap.page_allocator;

    // Write attribute getters - ONLY for own attributes (not inherited)
    for (own_attributes) |attr| {
        // Check if this is an interface type - if so, use *runtime.Instance
        // Callback interfaces use ?*runtime.CallbackWrapper
        const attr_type_kind = if (type_registry) |reg| reg.lookup(attr.idlType.type) else null;
        const is_interface_type = attr_type_kind != null and attr_type_kind.? == .interface;
        const is_callback_interface_type = attr_type_kind != null and attr_type_kind.? == .callback_interface;

        var return_type = if (is_callback_interface_type)
            "?*runtime.CallbackWrapper"
        else if (is_interface_type)
            "*runtime.Instance"
        else if (type_registry) |reg|
            mapWebIDLTypeWithRegistry(attr.idlType, reg).type_name
        else
            mapWebIDLType(attr.idlType);

        // Convert bare anyopaque to JSValue (for unresolved types)
        if (std.mem.eql(u8, return_type, "anyopaque")) {
            return_type = "runtime.JSValue";
        }

        // Check if this attribute is nullable (WebIDL T? type)
        const is_nullable = attr.idlType.nullable;

        const has_same_object = hasExtendedAttribute(attr.extAttrs, "SameObject");

        // Sanitize attribute name for function names (convert hyphens to underscores)
        const sanitized_name = try sanitizeFunctionName(allocator, attr.name);
        const name_was_sanitized = !std.mem.eql(u8, sanitized_name, attr.name);
        defer if (name_was_sanitized) allocator.free(sanitized_name);

        // Write extended attributes as comment
        try writeExtendedAttributesComment(writer, attr.extAttrs);

        // For nullable types, return ?T instead of T (allows returning null instead of error)
        if (is_nullable) {
            try writer.print("    pub fn get_{s}(instance: *runtime.Instance) anyerror!?{s} {{\n", .{ sanitized_name, return_type });
        } else {
            try writer.print("    pub fn get_{s}(instance: *runtime.Instance) anyerror!{s} {{\n", .{ sanitized_name, return_type });
        }

        // Use caching for [SameObject] attributes (all attributes here are own)
        // NOTE: Static attributes cannot use instance caching - they don't have instance state
        if (has_same_object and !attr.static) {
            // [SameObject] - Cache the result and return same instance every time
            try writer.writeAll("        const state = instance.getState(State);\n");
            try writer.print("        // [SameObject] - Return cached instance\n", .{});
            try writer.print("        if (state.own.cached_{s}) |cached| {{\n", .{sanitized_name});
            try writer.writeAll("            return cached;\n");
            try writer.writeAll("        }\n");
            try writer.print("        const value = try {s}.get_{s}(instance);\n", .{ impl_name, sanitized_name });
            try writer.print("        state.own.cached_{s} = value;\n", .{sanitized_name});
            try writer.writeAll("        return value;\n");
        } else {
            // Static attributes or non-[SameObject] - delegate directly to impl
            try writer.print("        return try {s}.get_{s}(instance);\n", .{ impl_name, sanitized_name });
        }

        try writer.writeAll("    }\n\n");

        // Check for [PutForwards], [Replaceable], and [LegacyLenientSetter] extended attributes
        // Per WebIDL §4.3.10: [PutForwards=X] creates a setter that forwards to property X
        // on the current value of the attribute, even if the attribute is readonly
        // Per WebIDL §4.3.10: [Replaceable] creates a setter that uses [[DefineOwnProperty]]
        // to create an own property on the object, shadowing the inherited getter
        // Per WebIDL §4.3.10: [LegacyLenientSetter] readonly attributes have setters that
        // silently do nothing (no-op) - the setter steps are to return.
        const extattr_mod = @import("extattr.zig");
        const put_forwards = extattr_mod.getPutForwards(attr.extAttrs);
        const is_replaceable = extattr_mod.isReplaceable(attr.extAttrs);
        const is_legacy_lenient_setter = extattr_mod.isLegacyLenientSetter(attr.extAttrs);

        // Write setter: [PutForwards] > [Replaceable] > regular non-readonly
        if (put_forwards) |forwarded_property| {
            // [PutForwards] setter - forwards assignment to property on the attribute's value
            const has_ce_reactions = hasExtendedAttribute(attr.extAttrs, "CEReactions");

            try writeExtendedAttributesComment(writer, attr.extAttrs);

            // The setter takes a string value (per WebIDL spec, the forwarded property is typically a DOMString)
            try writer.print("    pub fn set_{s}(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {{\n", .{sanitized_name});

            if (has_ce_reactions) {
                try writer.writeAll("        // [CEReactions] - Trigger Custom Element lifecycle callbacks\n");
                try writer.writeAll("        runtime.CEReactions.begin();\n");
                try writer.writeAll("        defer runtime.CEReactions.end();\n");
                try writer.writeAll("        \n");
            }

            try writer.writeAll("        // [PutForwards] - Get target object and set the forwarded property\n");
            try writer.print("        // Per WebIDL spec: setting '{s}' forwards to '{s}' on the attribute's value\n", .{ attr.name, forwarded_property });
            // Only handle nullable unwrap if the attribute type is nullable
            if (is_nullable) {
                try writer.print("        const target_opt = try get_{s}(instance);\n", .{sanitized_name});
                try writer.writeAll("        // Per WebIDL spec: if the target is null, throw TypeError\n");
                try writer.writeAll("        const target = target_opt orelse return error.TypeError;\n");
            } else {
                try writer.print("        const target = try get_{s}(instance);\n", .{sanitized_name});
            }
            try writer.writeAll("        \n");
            try writer.writeAll("        // Use JavaScript [[Set]] semantics to set the forwarded property\n");
            try writer.writeAll("        // This respects prototype chain and user-defined setters\n");
            // Check if the getter returns JSValue vs *Instance
            // If the return type contains "JSValue", use setPropertyOnJSValue; otherwise use setPropertyOnInstance
            const is_jsvalue_return = std.mem.indexOf(u8, return_type, "JSValue") != null;
            if (is_jsvalue_return) {
                try writer.writeAll("        // Note: target is a JSValue (from [SameObject] caching), not *Instance\n");
                try writer.print("        try runtime.setPropertyOnJSValue(target, instance, \"{s}\", value);\n", .{forwarded_property});
            } else {
                try writer.writeAll("        // Note: target is a *Instance, use setPropertyOnInstance\n");
                try writer.print("        try runtime.setPropertyOnInstance(target, \"{s}\", value);\n", .{forwarded_property});
            }
            try writer.writeAll("    }\n\n");
        } else if (is_replaceable) {
            // [Replaceable] setter - creates an own property on the object
            // Per WebIDL §4.3.10: The setter steps are to perform ? [[DefineOwnProperty]]
            // on this with the attribute's identifier as the property name and
            // PropertyDescriptor{[[Value]]: V, [[Writable]]: true, [[Enumerable]]: true, [[Configurable]]: true}.
            try writeExtendedAttributesComment(writer, attr.extAttrs);

            // [Replaceable] setter takes runtime.JSValue to accept any JavaScript value
            try writer.print("    pub fn set_{s}(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {{\n", .{sanitized_name});
            try writer.writeAll("        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]\n");
            try writer.writeAll("        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,\n");
            try writer.writeAll("        //                                     [[Enumerable]]: true, [[Configurable]]: true}\n");
            try writer.print("        try runtime.defineOwnProperty(instance, \"{s}\", value);\n", .{attr.name});
            try writer.writeAll("    }\n\n");
        } else if (is_legacy_lenient_setter) {
            // [LegacyLenientSetter] setter - silently does nothing (no-op)
            // Per WebIDL §4.3.10: If the attribute is declared with the [LegacyLenientSetter]
            // extended attribute, then the setter steps are to return.
            // This is used for readonly attributes that should not throw when assigned to.
            try writeExtendedAttributesComment(writer, attr.extAttrs);

            // [LegacyLenientSetter] setter takes runtime.JSValue to accept any value
            // but ignores it completely
            try writer.print("    pub fn set_{s}(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {{\n", .{sanitized_name});
            try writer.writeAll("        // [LegacyLenientSetter] - Silently do nothing (no-op setter)\n");
            try writer.writeAll("        // Per WebIDL §4.3.10: The setter steps are to return.\n");
            try writer.writeAll("        _ = instance;\n");
            try writer.writeAll("        _ = value;\n");
            try writer.writeAll("    }\n\n");
        } else if (!attr.readonly) {
            // Regular setter for non-readonly attributes (no [PutForwards])
            const has_ce_reactions = hasExtendedAttribute(attr.extAttrs, "CEReactions");

            // Extended attributes apply to setter too
            try writeExtendedAttributesComment(writer, attr.extAttrs);

            // For nullable types, the setter parameter must also be nullable
            // Per WebIDL spec: undefined/null JS values convert to null for nullable types
            if (is_nullable) {
                try writer.print("    pub fn set_{s}(instance: *runtime.Instance, value: ?{s}) anyerror!void {{\n", .{ sanitized_name, return_type });
            } else {
                try writer.print("    pub fn set_{s}(instance: *runtime.Instance, value: {s}) anyerror!void {{\n", .{ sanitized_name, return_type });
            }

            if (has_ce_reactions) {
                // [CEReactions] - Wrap in Custom Element reactions
                try writer.writeAll("        // [CEReactions] - Trigger Custom Element lifecycle callbacks\n");
                try writer.writeAll("        runtime.CEReactions.begin();\n");
                try writer.writeAll("        defer runtime.CEReactions.end();\n");
                try writer.writeAll("        \n");
            }

            if (has_same_object) {
                // If [SameObject], invalidate cache on set (all attributes here are own)
                try writer.writeAll("        const state = instance.getState(State);\n");
                try writer.print("        state.own.cached_{s} = null; // Invalidate [SameObject] cache\n", .{sanitized_name});
            }

            try writer.print("        try {s}.set_{s}(instance, value);\n", .{ impl_name, sanitized_name });
            try writer.writeAll("    }\n\n");
        }
    }

    // Group operations by name to detect overloads - ONLY for own operations (not inherited)
    const overload_sets = try overload.groupOperationsByName(allocator, own_operations);
    defer overload.freeOverloadSets(allocator, overload_sets);

    // Write operation delegates (with overload support) - ONLY for own operations
    for (overload_sets) |set| {
        if (set.isOverloaded()) {
            // Multiple overloads - generate tagged union and dispatch function
            try writeOverloadedOperation(writer, impl_name, set, type_registry);
        } else {
            // Single operation - generate normal function
            const op = set.operations[0];
            // Static methods use call_static_<name>, instance methods use call_<name>
            // No collision detection needed - convention handles it
            try writeSingleOperation(writer, impl_name, op, type_registry, false);
        }
    }

    // Write serialize delegate for stringifier interfaces
    // Per WebIDL spec, bare stringifier declarations generate a toString() method
    // that returns the result of the stringification behavior
    for (own_operations) |op| {
        if (op.special) |special| {
            if (special == .stringifier and op.name == null) {
                try writer.writeAll("    /// Stringifier delegate - toString() implementation\n");
                try writer.writeAll("    /// Per WebIDL spec: https://webidl.spec.whatwg.org/#es-stringifier\n");
                try writer.print("    pub fn serialize(instance: *runtime.Instance) anyerror!runtime.USVString {{\n", .{});
                try writer.print("        return try {s}.serialize(instance);\n", .{impl_name});
                try writer.writeAll("    }\n\n");
                break;
            }
        }
    }
}

/// Write the getEntriesForIterable function for pair iterable interfaces
///
/// This function is used by V8Interface to get entries for iteration.
/// It delegates to the Impl's getEntriesInternal function.
///
/// Example output:
/// ```zig
/// /// Get entries for pair iterable support (used by V8 for iteration)
/// pub fn getEntriesForIterable(instance: *runtime.Instance) ?[]const @import("fetch").internal.header_list.Header {
///     return HeadersImpl.getEntriesInternal(instance);
/// }
/// ```
pub fn writeIterableSupport(
    writer: anytype,
    impl_name: []const u8,
    iterable: types.Iterable,
) !void {
    // Only generate for pair iterables (have both key and value types)
    if (iterable.valueType == null) {
        // Value-only iterable - different pattern needed
        return;
    }

    // For pair iterables, generate getEntriesForIterable that delegates to Impl.getEntriesInternal
    try writer.writeAll("    /// Get entries for pair iterable support (used by V8 for iteration)\n");
    try writer.writeAll("    /// Returns slice of entries with .name and .value fields\n");
    try writer.print("    pub fn getEntriesForIterable(instance: *runtime.Instance) ?[]const {s}.IterableEntry {{\n", .{impl_name});
    try writer.print("        return {s}.getEntriesInternal(instance);\n", .{impl_name});
    try writer.writeAll("    }\n\n");
}

/// Write getSupportedPropertyNames delegate for named property support
///
/// This function is used by V8Interface to enumerate named properties for
/// legacy platform objects (e.g., NamedNodeMap, HTMLCollection, DOMStringMap).
/// It delegates to the Impl's getSupportedPropertyNames function.
///
/// Example output:
/// ```zig
/// /// Get supported property names for named property enumeration (Reflect.ownKeys, etc.)
/// pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
///     return NamedNodeMapImpl.getSupportedPropertyNames(instance, allocator);
/// }
/// ```
pub fn writeNamedPropertySupport(
    writer: anytype,
    impl_name: []const u8,
) !void {
    try writer.writeAll("    /// Get supported property names for named property enumeration (Reflect.ownKeys, etc.)\n");
    try writer.writeAll("    /// Per WebIDL spec §3.9.3, returns names in list order for proper enumeration\n");
    try writer.writeAll("    pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {\n");
    try writer.print("        return {s}.getSupportedPropertyNames(instance, allocator);\n", .{impl_name});
    try writer.writeAll("    }\n\n");
}

/// Write CSS property named handlers for CSSStyleDeclaration and CSSStyleProperties
///
/// Per CSS OM spec §6.6.1, CSSStyleDeclaration supports named property access for
/// CSS properties (e.g., style.color, style.backgroundColor). This is NOT defined
/// in WebIDL but is browser-specific behavior that we need to support.
///
/// Generates:
/// - call_namedItem: Gets CSS property value by name (camelCase or kebab-case)
/// - call_setNamedItem: Sets CSS property value by name
/// - getSupportedPropertyNames: Returns list of set property names
pub fn writeCSSPropertyNamedHandlers(
    writer: anytype,
    impl_name: []const u8,
) !void {
    // call_namedItem - Named property getter for CSS properties
    try writer.writeAll("    /// Named property getter for CSS property access\n");
    try writer.writeAll("    /// Maps style.color, style.backgroundColor to getPropertyValue()\n");
    try writer.writeAll("    /// Per CSS OM spec §6.6.1\n");
    try writer.writeAll("    pub fn call_namedItem(instance: *runtime.Instance, name: runtime.DOMString) anyerror!?runtime.DOMString {\n");
    try writer.print("        return {s}.call_namedItem(instance, name);\n", .{impl_name});
    try writer.writeAll("    }\n\n");

    // call_setNamedItem - Named property setter for CSS properties
    try writer.writeAll("    /// Named property setter for CSS property access\n");
    try writer.writeAll("    /// Maps style.color = \"red\" to setProperty()\n");
    try writer.writeAll("    /// Per CSS OM spec §6.6.1\n");
    try writer.writeAll("    pub fn call_setNamedItem(instance: *runtime.Instance, name: runtime.DOMString, value: runtime.DOMString) anyerror!void {\n");
    try writer.print("        return {s}.call_setNamedItem(instance, name, value);\n", .{impl_name});
    try writer.writeAll("    }\n\n");

    // getSupportedPropertyNames - For enumeration
    try writer.writeAll("    /// Get supported property names for CSS property enumeration\n");
    try writer.writeAll("    /// Returns CSS property names that have been set on this declaration\n");
    try writer.writeAll("    pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {\n");
    try writer.print("        return {s}.getSupportedPropertyNames(instance, allocator);\n", .{impl_name});
    try writer.writeAll("    }\n\n");
}

/// Check if an interface should have CSS property named handlers
/// These interfaces need special handling for CSS property access (style.color, etc.)
pub fn isCSSDeclarationInterface(name: []const u8) bool {
    return std.mem.eql(u8, name, "CSSStyleDeclaration") or
        std.mem.eql(u8, name, "CSSStyleProperties") or
        std.mem.eql(u8, name, "CSSPageDescriptors") or
        std.mem.eql(u8, name, "CSSMarginDescriptors");
}

/// Check if an interface has a named property getter operation
/// A named property getter is: getter <type> <name>(<DOMString param>)
/// Examples:
///   getter Element? namedItem(DOMString name);
///   getter Attr? getNamedItem(DOMString qualifiedName);
pub fn hasNamedPropertyGetter(operations: []const types.Operation) bool {
    for (operations) |op| {
        // Must be a getter special operation
        if (op.special) |special| {
            if (special == .getter) {
                // Must have a DOMString parameter (named property getter, not indexed)
                // Indexed getters have unsigned long parameter
                if (op.arguments.len > 0) {
                    const first_arg_type = op.arguments[0].idlType.type;
                    if (std.mem.eql(u8, first_arg_type, "DOMString") or
                        std.mem.eql(u8, first_arg_type, "USVString"))
                    {
                        return true;
                    }
                }
            }
        }
    }
    return false;
}

/// Escape Zig reserved keywords by appending underscore
fn escapeKeyword(name: []const u8) []const u8 {
    // List of Zig reserved keywords that might appear as WebIDL parameter names
    const keywords = [_][]const u8{
        "type", // Most common (addEventListener)
        "error", // Common in error handling
        "defer",
        "return",
        "var",
        "const",
        "fn",
        "struct",
        "enum",
        "union",
        "opaque",
        "try",
        "catch",
        "async",
        "await",
        "suspend",
        "resume",
        "export",
        "extern",
        "pub",
        "inline",
        "comptime",
        "callconv",
        "test",
        "and",
        "or",
        "switch",
        "if",
        "else",
        "while",
        "for",
        "break",
        "continue",
        "unreachable",
        "anytype",
        "anyframe",
        "anyerror",
        "anyopaque", // Not a keyword but avoid conflicts
    };

    for (keywords) |keyword| {
        if (std.mem.eql(u8, name, keyword)) {
            // For Zig keywords, we append underscore
            // This is a common pattern: type -> type_
            return name; // Will be appended with _ at call site
        }
    }

    return name;
}

/// Check if a name is a Zig reserved keyword
fn isKeyword(name: []const u8) bool {
    const keywords = [_][]const u8{
        "type",     "error",       "defer",   "return",   "var",      "const",     "fn",       "struct",
        "enum",     "union",       "opaque",  "try",      "catch",    "async",     "await",    "suspend",
        "resume",   "export",      "extern",  "pub",      "inline",   "comptime",  "callconv", "test",
        "and",      "or",          "switch",  "if",       "else",     "while",     "for",      "break",
        "continue", "unreachable", "anytype", "anyframe", "anyerror", "anyopaque", "align",
    };

    for (keywords) |keyword| {
        if (std.mem.eql(u8, name, keyword)) {
            return true;
        }
    }

    return false;
}

/// Check if an identifier needs escaping in Zig
/// Returns true for keywords or identifiers with hyphens
fn needsEscaping(name: []const u8) bool {
    if (isKeyword(name)) return true;

    // Check for hyphen (invalid in Zig identifiers)
    if (std.mem.indexOfScalar(u8, name, '-')) |_| {
        return true;
    }

    return false;
}

/// Write an identifier, escaping it with @"..." if needed
/// Used for struct fields, which can be escaped
fn writeEscapedIdentifier(writer: anytype, name: []const u8) !void {
    if (needsEscaping(name)) {
        try writer.print("@\"{s}\"", .{name});
    } else {
        try writer.print("{s}", .{name});
    }
}

/// Sanitize a name for use in a function name (cannot use @"..." for functions)
/// Converts hyphens to underscores
fn sanitizeFunctionName(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    // Check if name contains hyphens
    if (std.mem.indexOfScalar(u8, name, '-')) |_| {
        // Replace hyphens with underscores
        var result = try allocator.alloc(u8, name.len);
        for (name, 0..) |c, i| {
            result[i] = if (c == '-') '_' else c;
        }
        return result;
    }
    // No hyphens, return as-is (no allocation needed)
    return name;
}

/// Check if a name conflicts with interface-reserved function names (init, deinit)
/// These are functions generated in every interface file
fn isInterfaceReservedName(name: []const u8) bool {
    const reserved = [_][]const u8{
        "init", // Instance allocation function
        "deinit", // Instance deallocation function
    };

    for (reserved) |r| {
        if (std.mem.eql(u8, name, r)) {
            return true;
        }
    }

    return false;
}

/// Check if parameter name shadows a type name from its IDL type
/// Example: parameter "RestrictionTarget" with type "RestrictionTarget?" shadows the type
fn parameterShadowsType(param_name: []const u8, idl_type: types.IDLType) bool {
    // Strip trailing '?' from type name if present (nullable types)
    var type_name = idl_type.type;
    if (type_name.len > 0 and type_name[type_name.len - 1] == '?') {
        type_name = type_name[0 .. type_name.len - 1];
    }

    // Check if parameter name matches the base type name
    if (std.mem.eql(u8, param_name, type_name)) {
        return true;
    }

    // Check union types
    if (idl_type.unionTypes) |union_types| {
        for (union_types) |union_type| {
            if (parameterShadowsType(param_name, union_type)) {
                return true;
            }
        }
    }

    return false;
}

/// Write escaped parameter name for interface constructors
/// Renames reserved names to avoid shadowing: init → init_data
/// Renames type-shadowing names: RestrictionTarget → restrictiontarget_param
fn writeEscapedInterfaceParamName(writer: anytype, name: []const u8, idl_type: types.IDLType) !void {
    if (isInterfaceReservedName(name)) {
        try writer.print("{s}_data", .{name});
    } else if (parameterShadowsType(name, idl_type)) {
        // Just append _param suffix, preserve original case
        try writer.print("{s}_param", .{name});
    } else if (isKeyword(name)) {
        try writer.print("@\"{s}\"", .{name});
    } else {
        try writer.print("{s}", .{name});
    }
}

/// Result of type mapping with import information
pub const TypeMapping = struct {
    /// The Zig type name to use in generated code
    type_name: []const u8,
    /// Whether this type needs to be imported
    needs_import: bool,
    /// Which module to import from (if needs_import is true)
    import_module: ?[]const u8 = null,
};

/// Map WebIDL type to Zig type with TypeRegistry support
///
/// This is the new type mapper that uses TypeRegistry to resolve custom types.
/// Falls back to mapWebIDLType for primitives and unknown types.
fn mapWebIDLTypeWithRegistry(idl_type: types.IDLType, type_registry: *const @import("ir.zig").TypeRegistry) TypeMapping {
    // Handle union types first (before registry lookup, since unions have special .type values)
    if (idl_type.unionTypes) |union_types| {
        // Check for (Node or DOMString) pattern used by DOM mutation methods
        if (isNodeOrDOMStringUnion(union_types)) {
            return .{
                .type_name = "mixins.ParentNode.NodeOrString",
                .needs_import = false, // Already using mixins prefix
            };
        }
        // Check for (TrustedType or DOMString/USVString) pattern
        // TrustedTypes are not yet implemented, so treat as plain string
        if (isTrustedTypeOrStringUnion(union_types)) {
            return .{
                .type_name = "DOMString",
                .needs_import = false,
            };
        }
        // Other union types fall back to runtime.JSValue for type safety
        return .{
            .type_name = "runtime.JSValue",
            .needs_import = false,
        };
    }

    // Check if it's a registered custom type first
    if (type_registry.lookup(idl_type.type)) |kind| {
        const import_module = switch (kind) {
            .interface => "interfaces",
            .callback_interface => "interfaces", // Callback interfaces are still in interfaces/
            .typedef => "typedefs",
            .dictionary => "dictionaries",
            .enum_type => "enums",
            .callback => "callbacks",
            .namespace => "namespaces",
            .mixin => "mixins",
            .primitive => null, // Primitives don't need imports
        };

        // For primitives that are in the registry, use the mapped Zig type
        if (kind == .primitive) {
            return .{
                .type_name = mapWebIDLType(idl_type),
                .needs_import = false,
            };
        }

        // Custom types use their WebIDL name and need imports
        return .{
            .type_name = idl_type.type,
            .needs_import = true,
            .import_module = import_module,
        };
    }

    // Not in registry - use legacy mapper
    const legacy_type = mapWebIDLType(idl_type);
    return .{
        .type_name = legacy_type,
        .needs_import = false,
    };
}

/// Map WebIDL type to Zig type (legacy version)
/// Map WebIDL types to Zig types
///
/// Maps WebIDL type names to their Zig equivalents:
/// - void/undefined -> void (no return value)
/// - boolean -> bool
/// - numeric types -> i8, u8, i16, u16, i32, u32, i64, u64, f32, f64
/// - string types -> runtime.DOMString, runtime.ByteString, runtime.USVString
/// - unknown types -> runtime.JSValue
fn mapWebIDLType(idl_type: types.IDLType) []const u8 {
    // Handle union types first
    if (idl_type.unionTypes) |union_types| {
        // Check for (TrustedType or DOMString/USVString) pattern
        // TrustedTypes are not yet implemented, so treat as plain string
        if (isTrustedTypeOrStringUnion(union_types)) {
            return "DOMString";
        }
        // Other union types fall back to runtime.JSValue for type safety
        return "runtime.JSValue";
    }

    // WebIDL "undefined" is the modern replacement for "void"
    // Both represent operations that return no meaningful value
    // In Zig, both map to the `void` type
    const base_type = if (std.mem.eql(u8, idl_type.type, "void"))
        "void"
    else if (std.mem.eql(u8, idl_type.type, "undefined"))
        "void" // WebIDL undefined (return type) -> Zig void
    else if (std.mem.eql(u8, idl_type.type, "boolean"))
        "bool"
    else if (std.mem.eql(u8, idl_type.type, "byte"))
        "i8"
    else if (std.mem.eql(u8, idl_type.type, "octet"))
        "u8"
    else if (std.mem.eql(u8, idl_type.type, "short"))
        "i16"
    else if (std.mem.eql(u8, idl_type.type, "unsigned short"))
        "u16"
    else if (std.mem.eql(u8, idl_type.type, "long"))
        "i32"
    else if (std.mem.eql(u8, idl_type.type, "unsigned long"))
        "u32"
    else if (std.mem.eql(u8, idl_type.type, "long long"))
        "i64"
    else if (std.mem.eql(u8, idl_type.type, "unsigned long long"))
        "u64"
    else if (std.mem.eql(u8, idl_type.type, "float"))
        "f32"
    else if (std.mem.eql(u8, idl_type.type, "unrestricted float"))
        "f32"
    else if (std.mem.eql(u8, idl_type.type, "double"))
        "f64"
    else if (std.mem.eql(u8, idl_type.type, "unrestricted double"))
        "f64"
    else if (std.mem.eql(u8, idl_type.type, "DOMString"))
        "runtime.DOMString"
    else if (std.mem.eql(u8, idl_type.type, "ByteString"))
        "runtime.ByteString"
    else if (std.mem.eql(u8, idl_type.type, "USVString"))
        "runtime.USVString"
    else if (std.mem.eql(u8, idl_type.type, "any"))
        "runtime.JSValue"
    else if (std.mem.eql(u8, idl_type.type, "object"))
        "runtime.JSValue"
    else
        "runtime.JSValue"; // Unknown types use JSValue for type safety

    // For now, ignore nullable - we'll improve this later
    _ = idl_type.nullable;

    return base_type;
}

// Unit tests
const testing = std.testing;

test "mapWebIDLType maps undefined to void" {
    const undefined_type = types.IDLType{ .type = "undefined" };
    const result = mapWebIDLType(undefined_type);
    try testing.expectEqualStrings("void", result);
}

test "mapWebIDLType maps void to void" {
    const void_type = types.IDLType{ .type = "void" };
    const result = mapWebIDLType(void_type);
    try testing.expectEqualStrings("void", result);
}

test "mapWebIDLType maps primitives correctly" {
    try testing.expectEqualStrings("bool", mapWebIDLType(.{ .type = "boolean" }));
    try testing.expectEqualStrings("i8", mapWebIDLType(.{ .type = "byte" }));
    try testing.expectEqualStrings("u8", mapWebIDLType(.{ .type = "octet" }));
    try testing.expectEqualStrings("i32", mapWebIDLType(.{ .type = "long" }));
    try testing.expectEqualStrings("u32", mapWebIDLType(.{ .type = "unsigned long" }));
    try testing.expectEqualStrings("f64", mapWebIDLType(.{ .type = "double" }));
}

test "mapWebIDLType maps string types to runtime types" {
    try testing.expectEqualStrings("runtime.DOMString", mapWebIDLType(.{ .type = "DOMString" }));
    try testing.expectEqualStrings("runtime.ByteString", mapWebIDLType(.{ .type = "ByteString" }));
    try testing.expectEqualStrings("runtime.USVString", mapWebIDLType(.{ .type = "USVString" }));
}

test "writeHeader writes basic header" {
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);

    try writeHeader(writer.any(), "test.json", null);

    const output = buffer.items;

    // Should contain source file
    try testing.expect(std.mem.indexOf(u8, output, "Generated from: test.json") != null);

    // Should contain auto-generated warning
    try testing.expect(std.mem.indexOf(u8, output, "AUTO-GENERATED") != null);

    // Should NOT contain timestamp (removed to avoid unnecessary git diffs)
    try testing.expect(std.mem.indexOf(u8, output, "Generated at:") == null);
}

test "writeHeader includes spec URL" {
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);

    try writeHeader(writer.any(), "dom.json", "https://dom.spec.whatwg.org/");

    const output = buffer.items;

    // Should contain spec URL
    try testing.expect(std.mem.indexOf(u8, output, "Specification: https://dom.spec.whatwg.org/") != null);
}

test "writeHeader does not include timestamp" {
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);

    try writeHeader(writer.any(), "test.json", null);

    const output = buffer.items;

    // Timestamp should NOT be present (removed to avoid unnecessary git diffs)
    try testing.expect(std.mem.indexOf(u8, output, "Generated at:") == null);
    // Should still have the AUTO-GENERATED notice
    try testing.expect(std.mem.indexOf(u8, output, "AUTO-GENERATED") != null);
}

test "writeImports writes standard imports" {
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);

    try writeImports(writer.any(), "TestInterface", null, &.{}, &.{}, null);

    const output = buffer.items;

    // Should import std
    try testing.expect(std.mem.indexOf(u8, output, "const std = @import(\"std\");") != null);
    // Should import runtime
    try testing.expect(std.mem.indexOf(u8, output, "const runtime = @import(\"runtime\");") != null);
    // Should import impl from "impls" module
    try testing.expect(std.mem.indexOf(u8, output, "const TestInterfaceImpl = @import(\"impls\").TestInterface;") != null);
}

test "writeImports includes base type" {
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);

    try writeImports(writer.any(), "Node", "EventTarget", &.{}, &.{}, null);

    const output = buffer.items;

    // Should import impl from "impls" module
    try testing.expect(std.mem.indexOf(u8, output, "const NodeImpl = @import(\"impls\").Node;") != null);
    // Should import base type as direct peer import (breaks circular dependency)
    try testing.expect(std.mem.indexOf(u8, output, "const EventTarget = @import(\"EventTarget.zig\").EventTarget;") != null);
}

test "writeImports includes mixins" {
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);

    const mixins = [_][]const u8{ "ParentNode", "ChildNode" };
    try writeImports(writer.any(), "Element", null, &mixins, &.{}, null);

    const output = buffer.items;

    // Should import impl from "impls" module
    try testing.expect(std.mem.indexOf(u8, output, "const ElementImpl = @import(\"impls\").Element;") != null);
    // Should import both mixins from "mixins" module
    try testing.expect(std.mem.indexOf(u8, output, "const ParentNode = @import(\"mixins\").ParentNode;") != null);
    try testing.expect(std.mem.indexOf(u8, output, "const ChildNode = @import(\"mixins\").ChildNode;") != null);
}

test "writeImports includes both base and mixins" {
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);

    const mixins = [_][]const u8{"ParentNode"};
    try writeImports(writer.any(), "Element", "EventTarget", &mixins, &.{}, null);

    const output = buffer.items;

    // Should have all imports
    try testing.expect(std.mem.indexOf(u8, output, "const std") != null);
    try testing.expect(std.mem.indexOf(u8, output, "const runtime") != null);
    try testing.expect(std.mem.indexOf(u8, output, "const ElementImpl = @import(\"impls\").Element;") != null);
    try testing.expect(std.mem.indexOf(u8, output, "const EventTarget") != null);
    try testing.expect(std.mem.indexOf(u8, output, "const ParentNode") != null);
}

test "writeImports includes referenced interfaces" {
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);

    const refs = [_][]const u8{ "Node", "Document" };
    try writeImports(writer.any(), "AbstractRange", null, &.{}, &refs, null);

    const output = buffer.items;

    // Should import referenced interfaces as direct peer imports (breaks circular dependency)
    try testing.expect(std.mem.indexOf(u8, output, "const Node = @import(\"Node.zig\").Node;") != null);
    try testing.expect(std.mem.indexOf(u8, output, "const Document = @import(\"Document.zig\").Document;") != null);
}

test "writeImports avoids duplicate imports" {
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);

    const mixins = [_][]const u8{"ParentNode"};
    const refs = [_][]const u8{ "EventTarget", "ParentNode", "Node" }; // Duplicates base and mixin
    try writeImports(writer.any(), "Element", "EventTarget", &mixins, &refs, null);

    const output = buffer.items;

    // Count occurrences of each import
    var count_eventtarget: usize = 0;
    var count_parentnode: usize = 0;
    var pos: usize = 0;

    while (std.mem.indexOf(u8, output[pos..], "const EventTarget")) |idx| {
        count_eventtarget += 1;
        pos += idx + 1;
    }

    pos = 0;
    while (std.mem.indexOf(u8, output[pos..], "const ParentNode")) |idx| {
        count_parentnode += 1;
        pos += idx + 1;
    }

    // Should only import each once
    try testing.expectEqual(@as(usize, 1), count_eventtarget);
    try testing.expectEqual(@as(usize, 1), count_parentnode);

    // Node should be imported (not duplicate)
    try testing.expect(std.mem.indexOf(u8, output, "const Node = @import(\"interfaces\").Node;") != null);
}

test "writeInterfaceStruct generates struct declaration" {
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);

    try writeInterfaceStruct(writer.any(), "TestInterface");

    const output = buffer.items;
    try testing.expect(std.mem.indexOf(u8, output, "pub const TestInterface = struct {") != null);
}

test "writeMetadata generates Meta struct" {
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);

    try writeMetadata(writer.any(), "Node", "https://dom.spec.whatwg.org/#interface-node", "EventTarget", true, &.{}, &.{}, &.{}, &.{}, &.{}, &.{}, false, false, false, null, &.{}, null);

    const output = buffer.items;
    try testing.expect(std.mem.indexOf(u8, output, "pub const Meta = struct {") != null);
    try testing.expect(std.mem.indexOf(u8, output, "pub const name = \"Node\";") != null);
    try testing.expect(std.mem.indexOf(u8, output, "pub const BaseType = EventTarget.State;") != null);
}

test "writeMetadata handles no base type" {
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);

    try writeMetadata(writer.any(), "EventTarget", null, null, false, &.{}, &.{}, &.{}, &.{}, &.{}, &.{}, false, false, false, null, &.{}, null);

    const output = buffer.items;
    try testing.expect(std.mem.indexOf(u8, output, "pub const BaseType = null;") != null);
}

test "writeMetadata includes mixins" {
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);

    const mixins = [_][]const u8{"ParentNode"};
    try writeMetadata(writer.any(), "Node", null, null, false, &mixins, &.{}, &.{}, &.{}, &.{}, &.{}, false, false, false, null, &.{}, null);

    const output = buffer.items;
    try testing.expect(std.mem.indexOf(u8, output, "pub const MixinTypes = &.{") != null);
    try testing.expect(std.mem.indexOf(u8, output, "ParentNode,") != null);
}

test "writeMetadata includes extended attributes" {
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);

    const ext_attrs = [_]types.ExtendedAttribute{
        .{ .name = "Exposed", .rhs = .{ .identifier = "Window" } },
        .{ .name = "LegacyUnforgeable", .rhs = null },
    };
    try writeMetadata(writer.any(), "Event", null, null, false, &.{}, &ext_attrs, &.{}, &.{}, &.{}, &.{}, false, false, false, null, &.{}, null);

    const output = buffer.items;
    try testing.expect(std.mem.indexOf(u8, output, "pub const extended_attributes = .{") != null);
    try testing.expect(std.mem.indexOf(u8, output, ".name = \"Exposed\"") != null);
    try testing.expect(std.mem.indexOf(u8, output, ".identifier = \"Window\"") != null);
    try testing.expect(std.mem.indexOf(u8, output, ".name = \"LegacyUnforgeable\"") != null);
}

test "writeMetadata includes legacy unforgeable properties" {
    // LegacyUnforgeable attributes appear in the properties list like any other attribute
    // The LegacyUnforgeable extended attribute appears in extended_attributes
    // This test verifies that attributes with LegacyUnforgeable are included in properties

    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);

    var ext_attrs = [_]types.ExtendedAttribute{
        .{ .name = "LegacyUnforgeable", .rhs = null },
    };

    var attrs = [_]types.Attribute{
        .{
            .name = "isTrusted",
            .idlType = .{ .type = "boolean" },
            .readonly = true,
            .extAttrs = &ext_attrs,
        },
    };

    try writeMetadata(writer.any(), "Event", null, null, false, &.{}, &.{}, &attrs, &.{}, &.{}, &.{}, false, false, false, null, &attrs, null);

    const output = buffer.items;

    // LegacyUnforgeable attributes should appear in the properties list
    try testing.expect(std.mem.indexOf(u8, output, "pub const properties = .{") != null);
    try testing.expect(std.mem.indexOf(u8, output, "\"isTrusted\"") != null);
    try testing.expect(std.mem.indexOf(u8, output, "\"get_isTrusted\"") != null);
}

test "writeStateTypeAlias generates type alias" {
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);

    try writeStateTypeAlias(writer.any(), "NodeImpl");

    const output = buffer.items;
    // Check that parameters are in correct order: BaseType, MixinTypes, OwnFields
    try testing.expect(std.mem.indexOf(u8, output, "pub const State = runtime.FlattenedState(Meta.BaseType, Meta.MixinTypes, NodeImpl.State)") != null);
}

test "writeVTable generates vtable constant" {
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);

    const attrs: []const types.Attribute = &.{};
    const ops: []const types.Operation = &.{};
    const all_consts: []const types.Constant = &.{};
    const own_consts: []const types.Constant = &.{};
    try writeVTable(writer.any(), all_consts, own_consts, attrs, ops, "TestInterface");

    const output = buffer.items;
    try testing.expect(std.mem.indexOf(u8, output, "const delegates = .{") != null);
    try testing.expect(std.mem.indexOf(u8, output, ".deinit = &deinit,") != null);
    try testing.expect(std.mem.indexOf(u8, output, "pub const vtable = runtime.buildVTable(&delegates);") != null);
}

test "writeLifecycleFunctions generates init and deinit" {
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);

    try writeLifecycleFunctions(writer.any(), "NodeImpl");

    const output = buffer.items;
    try testing.expect(std.mem.indexOf(u8, output, "pub fn init(") != null);
    try testing.expect(std.mem.indexOf(u8, output, "pub fn deinit(") != null);
    // init() should delegate to Impl.init() with State and vtable
    try testing.expect(std.mem.indexOf(u8, output, "NodeImpl.init(allocator, State, &vtable, ctx)") != null);
}

test "writeDelegateFunctions generates attribute getters" {
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);

    const attrs = [_]types.Attribute{
        .{
            .name = "nodeType",
            .idlType = .{ .type = "unsigned short" },
            .readonly = true,
        },
    };

    try writeDelegateFunctions(writer.any(), "NodeImpl", null, &attrs, &.{});

    const output = buffer.items;
    try testing.expect(std.mem.indexOf(u8, output, "pub fn get_nodeType(") != null);
    try testing.expect(std.mem.indexOf(u8, output, "u16") != null);
}

test "writeDelegateFunctions generates setters for non-readonly attributes" {
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);

    const attrs = [_]types.Attribute{
        .{
            .name = "textContent",
            .idlType = .{ .type = "DOMString" },
            .readonly = false,
        },
    };

    try writeDelegateFunctions(writer.any(), "NodeImpl", null, &attrs, &.{});

    const output = buffer.items;
    try testing.expect(std.mem.indexOf(u8, output, "pub fn get_textContent(") != null);
    try testing.expect(std.mem.indexOf(u8, output, "pub fn set_textContent(") != null);
}

test "writeDelegateFunctions generates operation delegates" {
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);

    const args = [_]types.Argument{
        .{
            .name = "node",
            .idlType = .{ .type = "Node" },
        },
    };

    const ops = [_]types.Operation{
        .{
            .name = "appendChild",
            .idlType = .{ .type = "Node" },
            .arguments = @constCast(&args),
        },
    };

    try writeDelegateFunctions(writer.any(), "NodeImpl", null, &.{}, &ops);

    const output = buffer.items;
    try testing.expect(std.mem.indexOf(u8, output, "pub fn call_appendChild(") != null);
    // Without type registry, unknown types map to runtime.JSValue
    try testing.expect(std.mem.indexOf(u8, output, "node: runtime.JSValue") != null);
}

test "mapWebIDLType maps primitive types" {
    try testing.expectEqualStrings("void", mapWebIDLType(.{ .type = "void" }));
    try testing.expectEqualStrings("void", mapWebIDLType(.{ .type = "undefined" })); // undefined -> void
    try testing.expectEqualStrings("bool", mapWebIDLType(.{ .type = "boolean" }));
    try testing.expectEqualStrings("u16", mapWebIDLType(.{ .type = "unsigned short" }));
    try testing.expectEqualStrings("i32", mapWebIDLType(.{ .type = "long" }));
    try testing.expectEqualStrings("runtime.DOMString", mapWebIDLType(.{ .type = "DOMString" }));
}

test "writeConstructor generates constructor function" {
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);

    var args_list = std.ArrayList(types.Argument).empty;
    defer args_list.deinit(testing.allocator);
    try args_list.append(testing.allocator, .{
        .name = "type",
        .idlType = .{ .type = "DOMString" },
    });

    const ctor = types.Constructor{
        .arguments = args_list.items,
    };

    try writeConstructor(writer.any(), "EventImpl", ctor, null);

    const output = buffer.items;
    // Note: allocator parameter was removed - constructors now use ctx.allocator
    try testing.expect(std.mem.indexOf(u8, output, "pub fn call_constructor(ctx: runtime.Context") != null);
    try testing.expect(std.mem.indexOf(u8, output, "@\"type\": runtime.DOMString") != null);
    try testing.expect(std.mem.indexOf(u8, output, "return try EventImpl.call_constructor(ctx") != null);
}

test "writeConstructor handles no-argument constructor" {
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);

    const ctor = types.Constructor{
        .arguments = &.{},
    };

    try writeConstructor(writer.any(), "EventTargetImpl", ctor, null);

    const output = buffer.items;
    // Note: allocator parameter was removed - constructors now use ctx.allocator
    try testing.expect(std.mem.indexOf(u8, output, "pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance") != null);
    try testing.expect(std.mem.indexOf(u8, output, "return try EventTargetImpl.call_constructor(ctx)") != null);
}
