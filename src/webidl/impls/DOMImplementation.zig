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
const webidl = @import("webidl");
const DOMImplementation = interfaces.DOMImplementation;

// Import DOM internals for document state access (Golden Rule #12 compliant)
const dom = @import("dom");
const document_internals = dom.document_internals;

// Import related impls for factory methods (Golden Rule #13 - to be migrated)
const DocumentTypeImpl = @import("DocumentType.zig");
const ElementImpl = @import("Element.zig");
const NodeImpl = @import("Node.zig");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;

pub const State = DOMImplementation.State;

pub const ImplError = error{
    NotImplemented,
    InvalidCharacterError,
    NamespaceError,
    OutOfMemory,
};

/// HTML namespace constant
const HTML_NAMESPACE = "http://www.w3.org/1999/xhtml";
/// SVG namespace constant
const SVG_NAMESPACE = "http://www.w3.org/2000/svg";

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
/// Get internal state from instance using shared accessor (pointer cast variant)
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) *InternalState {
    return Accessor.getCast(instance);
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
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
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
        // Note: Internal state memory is managed by arena allocator - do NOT destroy
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Set the associated document for this DOMImplementation
pub fn setDocument(instance: *runtime.Instance, document: *runtime.Instance) void {
    const internal = getInternal(instance);
    internal.document = document;
}

// ============================================================================
// createDocumentType(name, publicId, systemId)
// ============================================================================

/// createDocumentType(name, publicId, systemId)
/// DOM §4.5 - Creates a DocumentType node
/// Spec: https://dom.spec.whatwg.org/#dom-domimplementation-createdocumenttype
///
/// Spec algorithm:
/// 1. If name is not a valid doctype name, then throw an "InvalidCharacterError" DOMException.
/// 2. Return a new doctype, with name as its name, publicId as its public ID, and systemId
///    as its system ID, and with its node document set to the associated document of this.
pub fn call_createDocumentType(instance: *runtime.Instance, name: runtime.DOMString, publicId: runtime.DOMString, systemId: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance);
    const allocator = internal.allocator;
    const ctx = instance.ctx;

    // Step 1: Validate doctype name
    const name_slice = name.asSlice();
    if (!isValidDoctypeName(name_slice)) {
        return error.InvalidCharacterError;
    }

    const public_id_slice = publicId.asSlice();
    const system_id_slice = systemId.asSlice();

    // Step 2: Create and return new doctype using helper
    const doctype = try DocumentTypeImpl.createDocumentType(
        allocator,
        ctx,
        name_slice,
        public_id_slice,
        system_id_slice,
    );
    errdefer interfaces.DocumentType.deinit(doctype);

    // Set node document to the associated document
    if (internal.document) |doc| {
        try NodeImpl.setOwnerDocument(doctype, doc);
    }

    return doctype;
}

// ============================================================================
// createDocument(namespace, qualifiedName, doctype)
// ============================================================================

/// createDocument(namespace, qualifiedName, doctype)
/// DOM §4.5 - Creates an XMLDocument
/// Spec: https://dom.spec.whatwg.org/#dom-domimplementation-createdocument
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
pub fn call_createDocument(instance: *runtime.Instance, namespace: ?runtime.DOMString, qualifiedName: runtime.DOMString, doctype: webidl.Opt(?*runtime.Instance)) anyerror!*runtime.Instance {
    const internal = getInternal(instance);
    const allocator = internal.allocator;
    const ctx = instance.ctx;

    // Step 1: Create new XMLDocument (use interface per Golden Rule #13)
    const document = try interfaces.Document.init(
        allocator,
        ctx,
    );
    errdefer interfaces.Document.deinit(document);

    // Set document type to XML
    try document_internals.setDocumentType(document, .xml);

    // Step 2-3: If qualifiedName is not empty, create element
    const qname_slice = qualifiedName.asSlice();
    var element: ?*runtime.Instance = null;

    if (qname_slice.len > 0) {
        const ns_slice = if (namespace) |ns| ns.asSlice() else "";

        // Validate namespace and qualified name per WebIDL
        try validateNamespace(ns_slice, qname_slice);

        // Create element via createElementNS
        element = try createElementNS(allocator, ctx, document, ns_slice, qname_slice);
    }

    // Step 4: If doctype is non-null, append doctype to document
    if (doctype.was_passed) {
        if (doctype.value) |dt| {
            try NodeImpl.setOwnerDocument(dt, document);
            // Use interface instead of impl (per Golden Rule #13)
            _ = try interfaces.Node.call_appendChild(document, dt);
        }
    }

    // Step 5: If element is non-null, append element to document
    if (element) |elem| {
        // Use interface instead of impl (per Golden Rule #13)
        _ = try interfaces.Node.call_appendChild(document, elem);
    }

    // Step 6: Set document's origin from associated document
    if (internal.document) |assoc_doc| {
        try document_internals.copyOrigin(document, assoc_doc);
    }

    // Step 7: Set content type based on namespace
    const ns_slice_final = if (namespace) |ns| ns.asSlice() else "";
    const content_type = if (ns_slice_final.len > 0) blk: {
        if (std.mem.eql(u8, ns_slice_final, HTML_NAMESPACE)) {
            break :blk "application/xhtml+xml";
        } else if (std.mem.eql(u8, ns_slice_final, SVG_NAMESPACE)) {
            break :blk "image/svg+xml";
        } else {
            break :blk "application/xml";
        }
    } else "application/xml";

    try document_internals.setContentType(document, content_type);

    // Step 8: Return document
    return document;
}

// ============================================================================
// createHTMLDocument(title)
// ============================================================================

/// createHTMLDocument(title)
/// DOM §4.5 - Creates an HTML document
/// Spec: https://dom.spec.whatwg.org/#dom-domimplementation-createhtmldocument
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
pub fn call_createHTMLDocument(instance: *runtime.Instance, title: webidl.Opt(runtime.DOMString)) anyerror!*runtime.Instance {
    const internal = getInternal(instance);
    const allocator = internal.allocator;
    const ctx = instance.ctx;

    // Step 1: Create new HTML document (use interface per Golden Rule #13)
    const doc = try interfaces.Document.init(
        allocator,
        ctx,
    );
    errdefer interfaces.Document.deinit(doc);

    // Set document type to HTML
    try document_internals.setDocumentType(doc, .html);

    // Step 2: Set content type to "text/html"
    try document_internals.setContentType(doc, "text/html");

    // Step 3: Create and append doctype with name "html"
    const doctype = try DocumentTypeImpl.createDocumentType(allocator, ctx, "html", "", "");
    errdefer interfaces.DocumentType.deinit(doctype);
    try NodeImpl.setOwnerDocument(doctype, doc);
    // Use interface instead of impl (per Golden Rule #13)
    _ = try interfaces.Node.call_appendChild(doc, doctype);

    // Step 4: Create and append <html> element
    const html = try createElementNS(allocator, ctx, doc, HTML_NAMESPACE, "html");
    errdefer interfaces.Element.deinit(html);
    // Use interface instead of impl (per Golden Rule #13)
    _ = try interfaces.Node.call_appendChild(doc, html);

    // Step 5: Create and append <head> element to html
    const head = try createElementNS(allocator, ctx, doc, HTML_NAMESPACE, "head");
    errdefer interfaces.Element.deinit(head);
    // Use interface instead of impl (per Golden Rule #13)
    _ = try interfaces.Node.call_appendChild(html, head);

    // Step 6: If title is given (non-null/non-empty check)
    if (title.was_passed) {
        const title_val = title.value;
        const title_slice = title_val.asSlice();
        // Per spec, we create <title> element with whatever data is given (even empty)
        if (title_slice.len > 0 or true) { // Always create if title param passed
            // Step 6.1: Create and append <title> element to head
            const title_elem = try createElementNS(allocator, ctx, doc, HTML_NAMESPACE, "title");
            errdefer interfaces.Element.deinit(title_elem);
            // Use interface instead of impl (per Golden Rule #13)
            _ = try interfaces.Node.call_appendChild(head, title_elem);

            // Step 6.2: Create Text node with title data and append to title element (use interface per Golden Rule #13)
            const text_node = try interfaces.Text.call_constructor(ctx, webidl.Opt(runtime.DOMString).passed(title_val));
            errdefer interfaces.Text.deinit(text_node);
            try NodeImpl.setOwnerDocument(text_node, doc);
            // Use interface instead of impl (per Golden Rule #13)
            _ = try interfaces.Node.call_appendChild(title_elem, text_node);
        }
    }

    // Step 7: Create and append <body> element to html
    const body = try createElementNS(allocator, ctx, doc, HTML_NAMESPACE, "body");
    errdefer interfaces.Element.deinit(body);
    // Use interface instead of impl (per Golden Rule #13)
    _ = try interfaces.Node.call_appendChild(html, body);

    // Step 8: Set doc's origin from associated document
    if (internal.document) |assoc_doc| {
        try document_internals.copyOrigin(doc, assoc_doc);
    }

    // Step 9: Return doc
    return doc;
}

// ============================================================================
// hasFeature()
// ============================================================================

/// hasFeature()
/// DOM §4.5 - Legacy method that always returns true
/// Spec: https://dom.spec.whatwg.org/#dom-domimplementation-hasfeature
///
/// Spec: hasFeature() originally would report whether the user agent claimed to support
/// a given DOM feature, but experience proved it was not nearly as reliable or granular
/// as simply checking whether the desired objects, attributes, or methods existed.
/// As such, it is no longer to be used, but continues to exist (and simply returns true)
/// so that old pages don't stop working.
pub fn call_hasFeature(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return true;
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Validates a doctype name per DOM spec
/// Spec: https://dom.spec.whatwg.org/#dom-domimplementation-createdocumenttype
///
/// A string is a valid doctype name if it matches the Name production
/// per XML spec. Simplified validation:
/// - Must not be empty
/// - Must not contain ASCII whitespace, NULL, or '>'
fn isValidDoctypeName(name: []const u8) bool {
    if (name.len == 0) return false;

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

/// Validate namespace and qualified name
/// Spec: https://dom.spec.whatwg.org/#validate-and-extract
fn validateNamespace(namespace: []const u8, qualified_name: []const u8) ImplError!void {
    // If qualifiedName is empty string, namespace must also be empty or null
    if (qualified_name.len == 0 and namespace.len > 0) {
        return error.NamespaceError;
    }

    // Check for invalid characters in qualified name
    for (qualified_name) |c| {
        if (c == 0x00) return error.InvalidCharacterError;
    }

    // Parse prefix and local name
    var prefix: ?[]const u8 = null;
    var local_name: []const u8 = qualified_name;

    if (std.mem.indexOfScalar(u8, qualified_name, ':')) |colon_pos| {
        prefix = qualified_name[0..colon_pos];
        local_name = qualified_name[colon_pos + 1 ..];

        // If prefix is non-null and namespace is empty, throw NamespaceError
        if (namespace.len == 0) {
            return error.NamespaceError;
        }
    }

    // If prefix is "xml" and namespace is not XML namespace, throw NamespaceError
    if (prefix) |p| {
        if (std.mem.eql(u8, p, "xml") and !std.mem.eql(u8, namespace, "http://www.w3.org/XML/1998/namespace")) {
            return error.NamespaceError;
        }
    }

    // Local name must not be empty if we have a prefix
    if (prefix != null and local_name.len == 0) {
        return error.InvalidCharacterError;
    }
}

/// Create an element with namespace
/// Used by createDocument and createHTMLDocument
fn createElementNS(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    document: *runtime.Instance,
    namespace: []const u8,
    qualified_name: []const u8,
) !*runtime.Instance {
    // Create element via Element interface (per Golden Rule #13)
    const element = try interfaces.Element.init(
        allocator,
        ctx,
    );
    errdefer interfaces.Element.deinit(element);

    // Set node type to ELEMENT_NODE
    try NodeImpl.setNodeType(element, NodeImpl.NodeType.ELEMENT_NODE);

    // Parse prefix and local name
    var prefix: ?[]const u8 = null;
    var local_name: []const u8 = qualified_name;

    if (std.mem.indexOfScalar(u8, qualified_name, ':')) |colon_pos| {
        prefix = qualified_name[0..colon_pos];
        local_name = qualified_name[colon_pos + 1 ..];
    }

    // Set element properties
    try ElementImpl.setLocalName(element, local_name);
    if (namespace.len > 0) {
        try ElementImpl.setNamespaceURI(element, namespace);
    }
    if (prefix) |p| {
        try ElementImpl.setPrefix(element, p);
    }

    // Set owner document
    try NodeImpl.setOwnerDocument(element, document);

    return element;
}
