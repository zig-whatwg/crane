//! Implementation for DOMImplementation interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-domimplementation
//! WHATWG DOM Standard §4.5
//!
//! Factory interface for creating documents and document types.
//! Accessed via document.implementation getter.
//!
//! Migrated from: webidl/src/dom/DOMImplementation.zig

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const DOMImplementation = interfaces.DOMImplementation;

// Import related impls for factory methods
const DocumentImpl = @import("Document.zig");
const DocumentTypeImpl = @import("DocumentType.zig");
const ElementImpl = @import("Element.zig");
const TextImpl = @import("Text.zig");

pub const State = DOMImplementation.State;

pub const ImplError = error{
    NotImplemented,
    InvalidCharacterError,
    OutOfMemory,
};

/// Internal state for DOMImplementation
/// Spec: DOMImplementation is associated with a Document
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// Associated document (the document that owns this implementation object)
    /// DOMImplementation is created via document.implementation getter
    document: ?*runtime.Instance,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .document = null,
        };
    }

    pub fn deinit(self: *InternalState) void {
        // No cleanup needed - document owns this DOMImplementation
        _ = self;
    }
};

/// Helper to access internal state from instance
fn getInternal(instance: *runtime.Instance) *InternalState {
    const state = instance.getState(State);
    return @ptrCast(@alignCast(state.own._internal));
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Initialize internal state
    const internal = try allocator.create(InternalState);
    internal.* = InternalState.init(allocator);

    // Store internal state in instance
    const state = instance.getState(State);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal_ptr| {
        const internal: *InternalState = @ptrCast(@alignCast(internal_ptr));
        internal.deinit();
        internal.allocator.destroy(internal);
    }
    runtime.Instance.deinit(instance);
}

/// createDocumentType(name, publicId, systemId)
/// DOM §4.5 - Creates a DocumentType node
///
/// Spec algorithm:
/// 1. If name is not a valid doctype name, then throw an "InvalidCharacterError" DOMException.
/// 2. Return a new doctype, with name as its name, publicId as its public ID, and systemId
///    as its system ID, and with its node document set to the associated document of this.
pub fn call_createDocumentType(instance: *runtime.Instance, name: runtime.DOMString, publicId: runtime.DOMString, systemId: runtime.DOMString) ImplError!*runtime.Instance {
    const internal = getInternal(instance);
    const allocator = internal.allocator;

    // Step 1: Validate doctype name
    const name_slice = if (name) |s| s.data else "";
    if (!isValidDoctypeName(name_slice)) {
        return error.InvalidCharacterError;
    }

    // Step 2: Create and return new doctype
    const ctx = instance.context;
    const doctype = DocumentTypeImpl.init(
        allocator,
        interfaces.DocumentType.State,
        &interfaces.DocumentType.vtable,
        ctx,
    ) catch return error.OutOfMemory;

    // Initialize doctype with name, publicId, systemId
    // TODO: Set doctype properties via DocumentTypeImpl
    // For now, the doctype is created but needs DocumentType implementation to be complete

    // Set node document to the associated document
    // TODO: Set owner_document once we bridge Node properties
    _ = publicId;
    _ = systemId;

    return doctype;
}

/// createDocument(namespace, qualifiedName, doctype)
/// DOM §4.5 - Creates an XMLDocument
///
/// Spec algorithm:
/// 1. Let document be a new XMLDocument.
/// 2. Let element be null.
/// 3. If qualifiedName is not the empty string, then set element to the result of running
///    the internal createElementNS steps, given document, namespace, qualifiedName, and an
///    empty dictionary.
/// 4. If doctype is non-null, append doctype to document.
/// 5. If element is non-null, append element to document.
/// 6. document's origin is this's associated document's origin.
/// 7. document's content type is determined by namespace:
///    - HTML namespace: "application/xhtml+xml"
///    - SVG namespace: "image/svg+xml"
///    - Any other namespace: "application/xml"
/// 8. Return document.
pub fn call_createDocument(instance: *runtime.Instance, namespace: runtime.DOMString, qualifiedName: runtime.DOMString, doctype: ?*runtime.Instance) ImplError!*runtime.Instance {
    const internal = getInternal(instance);
    const allocator = internal.allocator;
    const ctx = instance.context;

    // Step 1: Create new XMLDocument
    const document = DocumentImpl.init(
        allocator,
        interfaces.Document.State,
        &interfaces.Document.vtable,
        ctx,
    ) catch return error.OutOfMemory;

    // Set document type to XML
    // TODO: Set doc_type = .xml via DocumentImpl

    // Step 3: If qualifiedName is not empty, create element
    const qname_slice = if (qualifiedName) |s| s.data else "";
    if (qname_slice.len > 0) {
        // TODO: Create element via document.createElementNS
        // For now, skip element creation - needs Document.createElementNS
        _ = namespace;
    }

    // Step 4: If doctype is non-null, append to document
    if (doctype) |_| {
        // TODO: Append doctype to document via mutation algorithms
    }

    // Step 5: If element is non-null, append to document
    // (handled in step 3 TODO)

    // Step 6: Set document's origin
    // TODO: Copy origin from associated document

    // Step 7: Set content type based on namespace
    // TODO: Set content type via DocumentImpl

    // Step 8: Return document
    return document;
}

/// createHTMLDocument(title)
/// DOM §4.5 - Creates an HTML document
///
/// Spec algorithm:
/// 1. Let doc be a new document that is an HTML document.
/// 2. Set doc's content type to "text/html".
/// 3. Append a new doctype, with "html" as its name and with its node document set to doc, to doc.
/// 4. Append the result of creating an element given doc, "html", and the HTML namespace, to doc.
/// 5. Append the result of creating an element given doc, "head", and the HTML namespace, to the html element created earlier.
/// 6. If title is given:
///    1. Append the result of creating an element given doc, "title", and the HTML namespace, to the head element created earlier.
///    2. Append a new Text node, with its data set to title (which could be the empty string) and its node document set to doc, to the title element created earlier.
/// 7. Append the result of creating an element given doc, "body", and the HTML namespace, to the html element created earlier.
/// 8. doc's origin is this's associated document's origin.
/// 9. Return doc.
pub fn call_createHTMLDocument(instance: *runtime.Instance, title: runtime.DOMString) ImplError!*runtime.Instance {
    const internal = getInternal(instance);
    const allocator = internal.allocator;
    const ctx = instance.context;

    // Step 1: Create new HTML document
    const doc = DocumentImpl.init(
        allocator,
        interfaces.Document.State,
        &interfaces.Document.vtable,
        ctx,
    ) catch return error.OutOfMemory;

    // Step 2: Set content type to "text/html"
    // TODO: Set content_type via DocumentImpl

    // Step 3: Create and append doctype with name "html"
    // TODO: Create doctype and append via mutation algorithms

    // Step 4: Create and append html element
    // TODO: Create <html> element in HTML namespace

    // Step 5: Create and append head element to html
    // TODO: Create <head> element

    // Step 6: If title is given, create title element with text
    if (title) |_| {
        // TODO: Create <title> element with text content
    }

    // Step 7: Create and append body element to html
    // TODO: Create <body> element

    // Step 8: Set doc's origin from associated document
    // TODO: Copy origin

    // Step 9: Return doc
    return doc;
}

/// hasFeature()
/// DOM §4.5 - Legacy method that always returns true
///
/// Spec: hasFeature() originally would report whether the user agent claimed to support
/// a given DOM feature, but experience proved it was not nearly as reliable or granular
/// as simply checking whether the desired objects, attributes, or methods existed.
/// As such, it is no longer to be used, but continues to exist (and simply returns true)
/// so that old pages don't stop working.
pub fn call_hasFeature(instance: *runtime.Instance) bool {
    _ = instance;
    return true;
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Validates a doctype name per DOM spec
///
/// A string is a valid doctype name if it does not contain:
/// - ASCII whitespace (U+0009 TAB, U+000A LF, U+000C FF, U+000D CR, U+0020 SPACE)
/// - U+0000 NULL
/// - U+003E (>)
///
/// The empty string is a valid doctype name.
fn isValidDoctypeName(name: []const u8) bool {
    for (name) |c| {
        // Check for ASCII whitespace
        if (c == 0x09 or c == 0x0A or c == 0x0C or c == 0x0D or c == 0x20) {
            return false;
        }
        // Check for NULL
        if (c == 0x00) {
            return false;
        }
        // Check for >
        if (c == 0x3E) {
            return false;
        }
    }
    return true;
}
