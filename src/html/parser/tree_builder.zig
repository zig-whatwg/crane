//! HTML Tree Construction Algorithm
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#tree-construction
//! HTML Standard §13.2.6 "Tree construction"
//!
//! The tree construction stage takes tokens from the tokenizer and builds
//! the DOM tree. It uses an insertion mode state machine with 24 modes.
//!
//! Key data structures:
//! - Stack of open elements: Contains elements that have been opened but not closed
//! - List of active formatting elements: Handles mis-nested formatting tags
//! - Element pointers: head element pointer, form element pointer
//!
//! The tree builder maintains state about:
//! - Current insertion mode
//! - Original insertion mode (for text mode)
//! - Stack of template insertion modes
//! - Scripting flag, frameset-ok flag

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");

const Token = @import("tokens.zig").Token;
const TagToken = @import("tokens.zig").TagToken;
const DoctypeToken = @import("tokens.zig").DoctypeToken;
const CommentToken = @import("tokens.zig").CommentToken;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const State = @import("tokenizer_states.zig").State;
const ParseErrorCode = @import("parse_errors.zig").ParseErrorCode;
const ParseErrorCallback = @import("parse_errors.zig").ParseErrorCallback;
const document_write = @import("document_write.zig");
const InputStreamManager = document_write.InputStreamManager;
const encoding_sniffing = @import("encoding_sniffing.zig");

/// A parser driver's "change the encoding" (HTML §13.2.3.4), which the tree
/// builder runs for a meta element that declares `requested`.
pub const ChangeTheEncoding = struct {
    context: *anyopaque,
    change: *const fn (context: *anyopaque, requested: encoding_sniffing.Encoding) void,
};

/// The 24 insertion modes defined in HTML Standard §13.2.6.4
///
/// The insertion mode controls how tokens are processed and which
/// elements can be created.
pub const InsertionMode = enum {
    /// Initial mode - handles DOCTYPE and switches to before_html
    initial,
    /// Before <html> element
    before_html,
    /// Before <head> element
    before_head,
    /// Inside <head> element
    in_head,
    /// Inside <head><noscript>
    in_head_noscript,
    /// After </head> before <body>
    after_head,
    /// Main body content
    in_body,
    /// Handling text content (script, style, etc.)
    text,
    /// Inside <table> element
    in_table,
    /// Collecting text inside table
    in_table_text,
    /// Inside <caption> element
    in_caption,
    /// Inside <colgroup> element
    in_column_group,
    /// Inside <tbody>, <thead>, <tfoot>
    in_table_body,
    /// Inside <tr> element
    in_row,
    /// Inside <td> or <th>
    in_cell,
    /// Inside <select> element
    in_select,
    /// Inside <select> inside <table>
    in_select_in_table,
    /// Inside <template> element
    in_template,
    /// After </body>
    after_body,
    /// Inside <frameset> element
    in_frameset,
    /// After </frameset>
    after_frameset,
    /// After </html> (after body)
    after_after_body,
    /// After </html> (after frameset)
    after_after_frameset,
};

/// Quirks mode for the document.
///
/// HTML Standard: The document mode affects CSS layout and some DOM APIs.
pub const QuirksMode = enum {
    /// Standards mode (no quirks)
    no_quirks,
    /// Limited quirks mode (almost-standards)
    limited_quirks,
    /// Quirks mode (legacy compatibility)
    quirks,
};

/// An entry in the list of active formatting elements.
///
/// HTML Standard §13.2.4.3: The list contains elements in the formatting
/// category and markers.
pub const FormattingEntry = union(enum) {
    /// A marker (inserted when entering certain elements)
    marker,
    /// A formatting element with its associated token
    element: struct {
        /// The element node
        node: *TreeNode,
        /// Copy of the token that created this element
        token: TagToken,
    },
};

/// Categories of special elements that have specific parsing rules.
///
/// HTML Standard §13.2.4.2: Special elements have varying levels of
/// special parsing rules.
pub const ElementCategory = enum {
    /// Special elements (have specific parsing behavior)
    special,
    /// Formatting elements (go in active formatting list)
    formatting,
    /// Ordinary elements (generic handling)
    ordinary,
};

/// Namespaces used in the tree builder.
pub const Namespace = enum {
    /// HTML namespace (http://www.w3.org/1999/xhtml)
    html,
    /// MathML namespace (http://www.w3.org/1998/Math/MathML)
    mathml,
    /// SVG namespace (http://www.w3.org/2000/svg)
    svg,
};

/// The namespaces "adjust foreign attributes" gives an attribute. Every other
/// attribute the parser creates is in no namespace.
///
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html#adjust-foreign-attributes
pub const AttributeNamespace = enum {
    xlink,
    xml,
    xmlns,

    pub fn uri(self: AttributeNamespace) []const u8 {
        return switch (self) {
            .xlink => "http://www.w3.org/1999/xlink",
            .xml => "http://www.w3.org/XML/1998/namespace",
            .xmlns => "http://www.w3.org/2000/xmlns/",
        };
    }
};

/// A node in the DOM tree being constructed.
///
/// This is a simplified node representation for the parser.
/// The actual DOM nodes will be created using the webidl types.
pub const TreeNode = struct {
    /// Node type
    node_type: NodeType,
    /// Local name (for elements)
    local_name: ?[]const u8,
    /// Whether local_name is interned (static memory, don't free)
    local_name_interned: bool,
    /// Namespace (for elements)
    namespace: Namespace,
    /// Parent node
    parent: ?*TreeNode,
    /// First child
    first_child: ?*TreeNode,
    /// Last child
    last_child: ?*TreeNode,
    /// Previous sibling
    prev_sibling: ?*TreeNode,
    /// Next sibling
    next_sibling: ?*TreeNode,
    /// Temporary ownership of a detached parser subtree (adoption agency).
    detached_next: ?*TreeNode = null,
    /// The intended parent at creation, before the node is attached. The DOM
    /// adapter resolves foster locations against the live tree.
    creation_location: ?TreeBuilder.InsertionLocation = null,
    /// Attributes (for elements)
    attributes: infra.List(Attribute),
    /// Text content (for text/comment nodes)
    text_content: infra.List(u8),
    /// DOCTYPE name
    doctype_name: ?[]const u8,
    /// DOCTYPE public identifier
    doctype_public_id: ?[]const u8,
    /// DOCTYPE system identifier
    doctype_system_id: ?[]const u8,
    /// Force quirks flag (for DOCTYPE)
    force_quirks: bool,
    /// Allocator
    allocator: Allocator,

    pub const NodeType = enum {
        document,
        doctype,
        element,
        text,
        comment,
    };

    /// An attribute as "create an element for a token" appends it: a local
    /// name (owned), a value (owned), and - for the attributes in the
    /// "adjust foreign attributes" table - a namespace and a prefix (static).
    pub const Attribute = struct {
        name: []const u8,
        value: []const u8,
        namespace: ?AttributeNamespace,
        prefix: ?[]const u8 = null,
    };

    /// Create a new document node.
    pub fn initDocument(allocator: Allocator) !*TreeNode {
        const node = try allocator.create(TreeNode);
        node.* = TreeNode{
            .node_type = .document,
            .local_name = null,
            .local_name_interned = false,
            .namespace = .html,
            .parent = null,
            .first_child = null,
            .last_child = null,
            .prev_sibling = null,
            .next_sibling = null,
            .attributes = infra.List(Attribute).init(allocator),
            .text_content = infra.List(u8).init(allocator),
            .doctype_name = null,
            .doctype_public_id = null,
            .doctype_system_id = null,
            .force_quirks = false,
            .allocator = allocator,
        };
        return node;
    }

    /// Create a new element node.
    /// Uses tag name interning for common HTML elements to avoid allocation.
    pub fn initElement(allocator: Allocator, local_name: []const u8, namespace: Namespace) !*TreeNode {
        const node = try allocator.create(TreeNode);

        // Try to use interned tag name for HTML elements
        const tag_name_intern = @import("tag_name_intern.zig");
        const interned = if (namespace == .html) tag_name_intern.intern(local_name) else null;

        const name_ptr = interned orelse try allocator.dupe(u8, local_name);
        const is_interned = interned != null;

        node.* = TreeNode{
            .node_type = .element,
            .local_name = name_ptr,
            .local_name_interned = is_interned,
            .namespace = namespace,
            .parent = null,
            .first_child = null,
            .last_child = null,
            .prev_sibling = null,
            .next_sibling = null,
            .attributes = infra.List(Attribute).init(allocator),
            .text_content = infra.List(u8).init(allocator),
            .doctype_name = null,
            .doctype_public_id = null,
            .doctype_system_id = null,
            .force_quirks = false,
            .allocator = allocator,
        };
        return node;
    }

    /// Create a new text node.
    pub fn initText(allocator: Allocator) !*TreeNode {
        const node = try allocator.create(TreeNode);
        node.* = TreeNode{
            .node_type = .text,
            .local_name = null,
            .local_name_interned = false,
            .namespace = .html,
            .parent = null,
            .first_child = null,
            .last_child = null,
            .prev_sibling = null,
            .next_sibling = null,
            .attributes = infra.List(Attribute).init(allocator),
            .text_content = infra.List(u8).init(allocator),
            .doctype_name = null,
            .doctype_public_id = null,
            .doctype_system_id = null,
            .force_quirks = false,
            .allocator = allocator,
        };
        return node;
    }

    /// Create a new comment node.
    pub fn initComment(allocator: Allocator) !*TreeNode {
        const node = try allocator.create(TreeNode);
        node.* = TreeNode{
            .node_type = .comment,
            .local_name = null,
            .local_name_interned = false,
            .namespace = .html,
            .parent = null,
            .first_child = null,
            .last_child = null,
            .prev_sibling = null,
            .next_sibling = null,
            .attributes = infra.List(Attribute).init(allocator),
            .text_content = infra.List(u8).init(allocator),
            .doctype_name = null,
            .doctype_public_id = null,
            .doctype_system_id = null,
            .force_quirks = false,
            .allocator = allocator,
        };
        return node;
    }

    /// Create a new DOCTYPE node.
    pub fn initDoctype(allocator: Allocator, name: ?[]const u8, public_id: ?[]const u8, system_id: ?[]const u8, force_quirks: bool) !*TreeNode {
        const node = try allocator.create(TreeNode);
        node.* = TreeNode{
            .node_type = .doctype,
            .local_name = null,
            .local_name_interned = false,
            .namespace = .html,
            .parent = null,
            .first_child = null,
            .last_child = null,
            .prev_sibling = null,
            .next_sibling = null,
            .attributes = infra.List(Attribute).init(allocator),
            .text_content = infra.List(u8).init(allocator),
            .doctype_name = if (name) |n| try allocator.dupe(u8, n) else null,
            .doctype_public_id = if (public_id) |p| try allocator.dupe(u8, p) else null,
            .doctype_system_id = if (system_id) |s| try allocator.dupe(u8, s) else null,
            .force_quirks = force_quirks,
            .allocator = allocator,
        };
        return node;
    }

    /// Free resources.
    /// Note: This recursively frees all child nodes.
    pub fn deinit(self: *TreeNode) void {
        // First, recursively free all children
        var child = self.first_child;
        while (child) |c| {
            const next = c.next_sibling;
            c.deinit();
            child = next;
        }

        // Free local name (only if not interned - interned names are static)
        if (self.local_name) |name| {
            if (!self.local_name_interned) {
                self.allocator.free(name);
            }
        }
        // Free attributes
        const attrs = self.attributes.toSlice();
        for (attrs) |attr| {
            self.allocator.free(attr.name);
            self.allocator.free(attr.value);
        }
        self.attributes.deinit();
        // Free text content
        self.text_content.deinit();
        // Free DOCTYPE fields
        if (self.doctype_name) |n| self.allocator.free(n);
        if (self.doctype_public_id) |p| self.allocator.free(p);
        if (self.doctype_system_id) |s| self.allocator.free(s);
        // Free node itself
        self.allocator.destroy(self);
    }

    /// Append a child node.
    pub fn appendChild(self: *TreeNode, child: *TreeNode) void {
        child.remove();
        child.parent = self;
        child.prev_sibling = self.last_child;
        child.next_sibling = null;

        if (self.last_child) |last| {
            last.next_sibling = child;
        } else {
            self.first_child = child;
        }
        self.last_child = child;
    }

    pub fn remove(self: *TreeNode) void {
        const parent = self.parent orelse return;
        if (self.prev_sibling) |previous| previous.next_sibling = self.next_sibling else parent.first_child = self.next_sibling;
        if (self.next_sibling) |next| next.prev_sibling = self.prev_sibling else parent.last_child = self.prev_sibling;
        self.parent = null;
        self.prev_sibling = null;
        self.next_sibling = null;
    }

    pub fn insertBefore(self: *TreeNode, child: *TreeNode, before: ?*TreeNode) void {
        if (before == null) return self.appendChild(child);
        if (before == child) return;
        child.remove();
        const reference = before.?;
        child.parent = self;
        child.next_sibling = reference;
        child.prev_sibling = reference.prev_sibling;
        if (reference.prev_sibling) |previous| previous.next_sibling = child else self.first_child = child;
        reference.prev_sibling = child;
    }

    /// Add an attribute in no namespace.
    pub fn addAttribute(self: *TreeNode, name: []const u8, value: []const u8, namespace: ?AttributeNamespace) !void {
        return self.addNamespacedAttribute(name, value, namespace, null);
    }

    /// Add an attribute with a namespace and prefix (both static, from the
    /// "adjust foreign attributes" table), or none.
    pub fn addNamespacedAttribute(self: *TreeNode, name: []const u8, value: []const u8, namespace: ?AttributeNamespace, prefix: ?[]const u8) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);
        const value_copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(value_copy);

        try self.attributes.append(.{
            .name = name_copy,
            .value = value_copy,
            .namespace = namespace,
            .prefix = prefix,
        });
    }

    /// The value of the attribute in no namespace named `name`, if any.
    pub fn getAttribute(self: *const TreeNode, name: []const u8) ?[]const u8 {
        for (self.attributes.toSlice()) |attr| {
            if (attr.namespace == null and std.mem.eql(u8, attr.name, name)) return attr.value;
        }
        return null;
    }

    /// Append text to text content.
    pub fn appendText(self: *TreeNode, text: []const u8) !void {
        try self.text_content.appendSlice(text);
    }

    /// Append a single character to text content.
    pub fn appendChar(self: *TreeNode, char: u21) !void {
        var buf: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(char, &buf) catch {
            // Invalid codepoint, use replacement character
            try self.text_content.appendSlice(&[_]u8{ 0xEF, 0xBF, 0xBD });
            return;
        };
        try self.text_content.appendSlice(buf[0..len]);
    }

    /// Check if this element has a specific tag name.
    pub fn hasTagName(self: *const TreeNode, name: []const u8) bool {
        if (self.local_name) |local| {
            return std.mem.eql(u8, local, name);
        }
        return false;
    }

    /// Check if this is an element in the HTML namespace.
    pub fn isHtmlElement(self: *const TreeNode) bool {
        return self.node_type == .element and self.namespace == .html;
    }
};

/// HTML Tree Builder.
///
/// Implements the tree construction stage of the HTML parsing algorithm.
/// Takes tokens from the tokenizer and builds the DOM tree.
pub const TreeBuilder = struct {
    /// Memory allocator.
    allocator: Allocator,

    /// The tokenizer.
    tokenizer: *Tokenizer,

    /// The document being built.
    document: *TreeNode,

    /// Current insertion mode.
    insertion_mode: InsertionMode,

    /// Original insertion mode (for returning from text mode).
    original_insertion_mode: InsertionMode,

    /// Stack of open elements.
    /// HTML Standard §13.2.4.2: The stack grows downwards; the topmost
    /// node is the first one added.
    open_elements: infra.List(*TreeNode),

    /// List of active formatting elements.
    /// HTML Standard §13.2.4.3: Contains elements in formatting category
    /// and markers.
    active_formatting_elements: infra.List(FormattingEntry),

    /// Stack of template insertion modes.
    template_insertion_modes: infra.List(InsertionMode),

    /// Head element pointer.
    head_element: ?*TreeNode,

    /// Form element pointer.
    form_element: ?*TreeNode,

    /// Scripting flag.
    scripting_enabled: bool,

    /// Frameset-ok flag.
    frameset_ok: bool,

    /// Parser cannot change the mode flag.
    parser_cannot_change_mode: bool,

    /// Document quirks mode.
    quirks_mode: QuirksMode,

    /// Foster parenting flag.
    foster_parenting: bool,

    /// Error callback.
    error_callback: ?ParseErrorCallback,

    /// Error context.
    error_context: ?*anyopaque,

    /// Pending table character tokens for "in table text" mode.
    pending_table_char_tokens: infra.List(u21),

    /// Script nesting level.
    /// HTML Standard §13.2.6: Tracks nested script execution. When > 0,
    /// certain operations like document.open() are blocked.
    script_nesting_level: u32,

    /// Parser pause flag.
    /// HTML Standard: Set while waiting for scripts to load/execute.
    parser_pause_flag: bool,

    /// Callback for script execution.
    /// HTML Standard §13.2.6.4.7: When a script end tag is encountered,
    /// the script should be prepared and potentially executed.
    /// This callback is invoked with the script element node.
    script_execution_callback: ?*const fn (*TreeNode, ?*anyopaque) void,

    /// Script execution callback context.
    script_execution_context: ?*anyopaque,

    /// DOM adapter callbacks for incremental TreeNode to DOM conversion.
    /// When set, these callbacks are invoked as nodes are created and modified,
    /// enabling scripts to access DOM during parsing.
    ///
    /// Callback signatures:
    /// - on_node_created: fn(node: *TreeNode, context: ?*anyopaque) void
    /// - on_child_appended: fn(parent: *TreeNode, child: *TreeNode, context: ?*anyopaque) void
    /// - on_text_content_changed: fn(node: *TreeNode, context: ?*anyopaque) void
    dom_adapter_context: ?*anyopaque,
    dom_adapter_on_node_created: ?*const fn (*TreeNode, ?*anyopaque) void,
    dom_adapter_on_child_appended: ?*const fn (*TreeNode, *TreeNode, ?*anyopaque) void,
    dom_adapter_on_text_content_changed: ?*const fn (*TreeNode, ?*anyopaque) void,
    /// The text node the parser has been appending to without telling the DOM
    /// adapter yet - see `flushPendingText`.
    pending_text: ?*TreeNode = null,
    detached_nodes: ?*TreeNode = null,
    dom_adapter_on_inserted: ?*const fn (InsertionLocation, *TreeNode, ?*anyopaque) void = null,
    dom_adapter_on_removed: ?*const fn (*TreeNode, ?*anyopaque) void = null,
    dom_adapter_on_children_moved: ?*const fn (*TreeNode, *TreeNode, ?*anyopaque) void = null,
    /// An attribute was added to an element the adapter already made: a
    /// second <html> or <body> start tag's attributes, which "in body" adds
    /// to the existing element. Called with `dom_adapter_context`.
    dom_adapter_on_attribute_added: ?*const fn (*TreeNode, *const TreeNode.Attribute, ?*anyopaque) void = null,

    /// The fragment parsing algorithm's context element, as a tree node the
    /// caller owns: the adjusted current node while the stack of open elements
    /// holds only the root. Null for a document parse.
    fragment_context: ?*TreeNode = null,

    /// The document is an iframe srcdoc document - one whose URL matches
    /// about:srcdoc - which the "initial" insertion mode never puts in quirks
    /// or limited-quirks mode. Set by the parser's creator.
    iframe_srcdoc: bool = false,

    /// The parser set the document's mode (`quirks_mode`): the Document the
    /// DOM adapter builds takes it. Called with `dom_adapter_context`.
    dom_adapter_on_mode_set: ?*const fn (QuirksMode, ?*anyopaque) void = null,

    /// The parser's "change the encoding" (HTML §13.2.3.4), which a meta
    /// element runs while the confidence is tentative. Set by a driver
    /// decoding a byte stream, which holds the confidence and the input
    /// stream; null when the input was never bytes (document.write(),
    /// fragments, DOMParser), which have no encoding to change.
    change_the_encoding: ?ChangeTheEncoding = null,

    /// The "text" insertion mode popped an element other than a script off
    /// the stack of open elements - a style element's end tag, or EOF - its
    /// text already told to the adapter. HTML runs "update a style block"
    /// then. Called with `dom_adapter_context`.
    dom_adapter_on_element_popped: ?*const fn (*TreeNode, ?*anyopaque) void = null,

    /// An element left the stack of open elements - "popped off the stack
    /// of open elements of an HTML parser" - by any removal: its end tag, an
    /// implied end tag, a popUntil*, the adoption agency's removal of a node
    /// that is not the current node, or "stop parsing" popping everything at
    /// the end of the input. Its children are parsed (Blink's
    /// Element::FinishParsingChildren, which HTMLElementStack's PopCommon,
    /// RemoveNonTopCommon and PopAll call). Called with
    /// `dom_adapter_context`; see `finishedParsingChildren`.
    dom_adapter_on_children_finished: ?*const fn (*TreeNode, ?*anyopaque) void = null,

    /// Input stream manager for document.write() support.
    ///
    /// HTML Standard §13.2.3: When document.write() is called during parsing,
    /// the content is inserted into the input stream at the current insertion point.
    /// This field provides access to the InputStreamManager for such insertions.
    input_stream_manager: ?*InputStreamManager,

    /// Initialize a new tree builder with static input.
    pub fn init(allocator: Allocator, tokenizer: *Tokenizer) !TreeBuilder {
        const document = try TreeNode.initDocument(allocator);
        return TreeBuilder{
            .allocator = allocator,
            .tokenizer = tokenizer,
            .document = document,
            .insertion_mode = .initial,
            .original_insertion_mode = .initial,
            .open_elements = infra.List(*TreeNode).init(allocator),
            .active_formatting_elements = infra.List(FormattingEntry).init(allocator),
            .template_insertion_modes = infra.List(InsertionMode).init(allocator),
            .head_element = null,
            .form_element = null,
            .scripting_enabled = false,
            .frameset_ok = true,
            .parser_cannot_change_mode = false,
            .quirks_mode = .no_quirks,
            .foster_parenting = false,
            .error_callback = null,
            .error_context = null,
            .pending_table_char_tokens = infra.List(u21).init(allocator),
            .script_nesting_level = 0,
            .parser_pause_flag = false,
            .script_execution_callback = null,
            .script_execution_context = null,
            .dom_adapter_context = null,
            .dom_adapter_on_node_created = null,
            .dom_adapter_on_child_appended = null,
            .dom_adapter_on_text_content_changed = null,
            .input_stream_manager = tokenizer.getInputStreamManager(),
        };
    }

    /// Initialize a tree builder with an InputStreamManager for document.write() support.
    ///
    /// HTML Standard §13.2.3: This enables dynamic content insertion via document.write()
    /// during script execution. The input stream manager handles insertion points and
    /// pending insertions.
    pub fn initWithStreamManager(allocator: Allocator, tokenizer: *Tokenizer, stream_manager: *InputStreamManager) !TreeBuilder {
        const document = try TreeNode.initDocument(allocator);
        return TreeBuilder{
            .allocator = allocator,
            .tokenizer = tokenizer,
            .document = document,
            .insertion_mode = .initial,
            .original_insertion_mode = .initial,
            .open_elements = infra.List(*TreeNode).init(allocator),
            .active_formatting_elements = infra.List(FormattingEntry).init(allocator),
            .template_insertion_modes = infra.List(InsertionMode).init(allocator),
            .head_element = null,
            .form_element = null,
            .scripting_enabled = false,
            .frameset_ok = true,
            .parser_cannot_change_mode = false,
            .quirks_mode = .no_quirks,
            .foster_parenting = false,
            .error_callback = null,
            .error_context = null,
            .pending_table_char_tokens = infra.List(u21).init(allocator),
            .script_nesting_level = 0,
            .parser_pause_flag = false,
            .script_execution_callback = null,
            .script_execution_context = null,
            .dom_adapter_context = null,
            .dom_adapter_on_node_created = null,
            .dom_adapter_on_child_appended = null,
            .dom_adapter_on_text_content_changed = null,
            .input_stream_manager = stream_manager,
        };
    }

    /// Set script execution callback.
    /// The callback will be invoked when a script element's end tag is processed.
    pub fn setScriptExecutionCallback(
        self: *TreeBuilder,
        callback: *const fn (*TreeNode, ?*anyopaque) void,
        context: ?*anyopaque,
    ) void {
        self.script_execution_callback = callback;
        self.script_execution_context = context;
    }

    /// Set DOM adapter callbacks for incremental conversion.
    /// When set, these callbacks are invoked as nodes are created and modified during parsing.
    /// This enables scripts to access DOM nodes that were parsed before them.
    pub fn setDomAdapterCallbacks(
        self: *TreeBuilder,
        context: ?*anyopaque,
        on_node_created: ?*const fn (*TreeNode, ?*anyopaque) void,
        on_child_appended: ?*const fn (*TreeNode, *TreeNode, ?*anyopaque) void,
        on_text_content_changed: ?*const fn (*TreeNode, ?*anyopaque) void,
    ) void {
        self.dom_adapter_context = context;
        self.dom_adapter_on_node_created = on_node_created;
        self.dom_adapter_on_child_appended = on_child_appended;
        self.dom_adapter_on_text_content_changed = on_text_content_changed;
    }

    /// Set the adapter's mode callback (see `dom_adapter_on_mode_set`); it
    /// shares `dom_adapter_context`.
    pub fn setDomAdapterModeCallback(self: *TreeBuilder, on_mode_set: ?*const fn (QuirksMode, ?*anyopaque) void) void {
        self.dom_adapter_on_mode_set = on_mode_set;
    }

    /// Reparenting cannot be expressed as append notifications: scripts may
    /// have moved the table, and the furthest block may have new children.
    pub fn setDomAdapterTreeMutationCallbacks(
        self: *TreeBuilder,
        on_inserted: *const fn (InsertionLocation, *TreeNode, ?*anyopaque) void,
        on_removed: *const fn (*TreeNode, ?*anyopaque) void,
        on_children_moved: *const fn (*TreeNode, *TreeNode, ?*anyopaque) void,
    ) void {
        self.dom_adapter_on_inserted = on_inserted;
        self.dom_adapter_on_removed = on_removed;
        self.dom_adapter_on_children_moved = on_children_moved;
    }

    /// Set the adapter's element-popped callback (see
    /// `dom_adapter_on_element_popped`); it shares `dom_adapter_context`.
    pub fn setDomAdapterPoppedCallback(self: *TreeBuilder, on_popped: ?*const fn (*TreeNode, ?*anyopaque) void) void {
        self.dom_adapter_on_element_popped = on_popped;
    }

    /// Set the adapter's finished-parsing-children callback (see
    /// `dom_adapter_on_children_finished`); it shares `dom_adapter_context`.
    pub fn setDomAdapterFinishedCallback(self: *TreeBuilder, on_finished: ?*const fn (*TreeNode, ?*anyopaque) void) void {
        self.dom_adapter_on_children_finished = on_finished;
    }

    /// Set the adapter's attribute-added callback (see
    /// `dom_adapter_on_attribute_added`); it shares `dom_adapter_context`.
    pub fn setDomAdapterAttributeCallback(
        self: *TreeBuilder,
        on_attribute_added: ?*const fn (*TreeNode, *const TreeNode.Attribute, ?*anyopaque) void,
    ) void {
        self.dom_adapter_on_attribute_added = on_attribute_added;
    }

    /// Check if the parser is currently paused waiting for scripts.
    pub fn isPaused(self: *const TreeBuilder) bool {
        return self.parser_pause_flag;
    }

    /// Check if currently executing scripts (nesting level > 0).
    pub fn isExecutingScript(self: *const TreeBuilder) bool {
        return self.script_nesting_level > 0;
    }

    // =========================================================================
    // document.write() Support
    // =========================================================================

    /// Get the input stream manager for document.write() support.
    ///
    /// Returns null if the parser was not initialized with an InputStreamManager.
    pub fn getInputStreamManager(self: *TreeBuilder) ?*InputStreamManager {
        return self.input_stream_manager;
    }

    /// Free all resources.
    pub fn deinit(self: *TreeBuilder) void {
        // Free all nodes (document tree)
        self.freeTree(self.document);
        while (self.detached_nodes) |node| {
            self.detached_nodes = node.detached_next;
            node.deinit();
        }
        self.open_elements.deinit();
        while (self.active_formatting_elements.len > 0) self.removeFormattingAt(self.active_formatting_elements.len - 1);
        self.active_formatting_elements.deinit();
        self.template_insertion_modes.deinit();
        self.pending_table_char_tokens.deinit();
    }

    /// Free a tree of nodes.
    /// Note: TreeNode.deinit() recursively frees all child nodes,
    /// so we just need to call deinit on the root.
    fn freeTree(self: *TreeBuilder, node: *TreeNode) void {
        _ = self;
        // TreeNode.deinit() handles recursive child cleanup
        node.deinit();
    }

    /// Set error callback for parse error reporting.
    pub fn setErrorCallback(self: *TreeBuilder, callback: ParseErrorCallback, context: ?*anyopaque) void {
        self.error_callback = callback;
        self.error_context = context;
    }

    /// Report a parse error.
    fn reportError(self: *TreeBuilder, code: ParseErrorCode) void {
        if (self.error_callback) |callback| {
            callback(.{ .code = code, .line = 0, .column = 0, .offset = 0 }, self.error_context);
        }
    }

    /// Get the current node (bottommost in stack of open elements).
    pub fn currentNode(self: *TreeBuilder) ?*TreeNode {
        if (self.open_elements.len > 0) {
            return self.open_elements.get(self.open_elements.len - 1);
        }
        return null;
    }

    /// Get the adjusted current node.
    /// HTML Standard §13.2.6: "The adjusted current node is the context
    /// element if the parser was created as part of the HTML fragment parsing
    /// algorithm and the stack of open elements has only one element in it
    /// (fragment case); otherwise, the adjusted current node is the current
    /// node."
    pub fn adjustedCurrentNode(self: *TreeBuilder) ?*TreeNode {
        if (self.fragment_context) |context| {
            if (self.open_elements.len == 1) return context;
        }
        return self.currentNode();
    }

    /// "There is an adjusted current node and it is not an element in the HTML
    /// namespace."
    pub fn adjustedCurrentNodeIsForeign(self: *TreeBuilder) bool {
        const node = self.adjustedCurrentNode() orelse return false;
        return node.node_type == .element and node.namespace != .html;
    }

    /// Parse the entire document.
    pub fn parse(self: *TreeBuilder) !void {
        // Whatever stops the loop, the adapter hears the last run of text.
        defer self.flushPendingText();
        while (true) {
            // "If the parser pause flag is set, the tokenizer will abort
            // immediately" - a nested invocation (document.write's) stops
            // here, and the outer one resumes when the script that paused it
            // has returned.
            if (self.parser_pause_flag) return;

            // The markup declaration open state asks whether the adjusted
            // current node is foreign before it opens a CDATA section.
            self.tokenizer.allow_cdata = self.adjustedCurrentNodeIsForeign();
            const token = try self.tokenizer.nextToken();
            if (token == null) {
                // The readable input ran out with more to come: the insertion
                // point document.write()'s characters are processed to, or
                // input not yet written. Not the end of the input.
                if (self.tokenizer.suspended) return;

                // The tokenizer signals end of input by returning NULL, not by
                // emitting an EOF token - so breaking here skipped tree
                // construction's EOF work entirely, and the `.eof` branch of
                // every insertion mode was dead code.
                //
                // That is where the implied <body> comes from: HTML §13.2.6.4.4
                // "in head" at EOF pops head and reprocesses in "after head",
                // which inserts a body. Without it, a document whose content is
                // entirely head-level - a doctype, a meta, a title and some
                // scripts, which is MOST WPT files - got <html><head> and
                // nothing else, so `document.body` was null.
                //
                // dom/common.js line 25 is `document.body.insertBefore(...)`,
                // run from `setup()`, and testharness rethrows out of setup, so
                // that one null turned whole files into a harness ERROR with
                // zero subtests.
                try self.processToken(Token.eof);
                break;
            }

            var tok = token.?;
            defer tok.deinit();

            try self.processToken(tok);

            // Check for EOF
            if (tok == .eof) break;
        }
        // The end of the input: "stop parsing" pops every open element.
        self.popAllOpenElements();
    }

    /// Process a single token.
    pub fn processToken(self: *TreeBuilder, token: Token) Allocator.Error!void {
        // Tree construction dispatcher
        // HTML Standard §13.2.6: Check if we should use foreign content rules
        const use_foreign = self.shouldUseForeignContent(token);

        if (use_foreign) {
            try self.processTokenInForeignContent(token);
        } else {
            try self.processTokenInHtmlContent(token);
        }
    }

    /// Determine if foreign content rules should be used.
    fn shouldUseForeignContent(self: *TreeBuilder, token: Token) bool {
        // HTML Standard §13.2.6: Use foreign content rules when:
        // - Stack is not empty
        // - Adjusted current node is not in HTML namespace
        // - Adjusted current node is not a MathML text integration point (with certain tokens)
        // - Adjusted current node is not an HTML integration point (with certain tokens)
        // - Token is not EOF

        if (self.open_elements.len == 0) return false;

        const current = self.adjustedCurrentNode() orelse return false;

        // If in HTML namespace, use HTML content rules
        if (current.namespace == .html) return false;

        // Check for MathML text integration point
        if (self.isMathMLTextIntegrationPoint(current)) {
            switch (token) {
                .start_tag => |tag| {
                    const name = tag.getTagName();
                    if (!std.mem.eql(u8, name, "mglyph") and !std.mem.eql(u8, name, "malignmark")) {
                        return false;
                    }
                },
                .character, .text_run => return false,
                else => {},
            }
        }

        // "If the adjusted current node is a MathML annotation-xml element and
        // the token is a start tag whose tag name is "svg"".
        if (current.namespace == .mathml and current.hasTagName("annotation-xml")) {
            switch (token) {
                .start_tag => |tag| if (std.mem.eql(u8, tag.getTagName(), "svg")) return false,
                else => {},
            }
        }

        // Check for HTML integration point
        if (self.isHtmlIntegrationPoint(current)) {
            switch (token) {
                .start_tag, .character, .text_run => return false,
                else => {},
            }
        }

        // EOF always uses HTML content rules
        if (token == .eof) return false;

        return true;
    }

    /// Check if node is a MathML text integration point.
    fn isMathMLTextIntegrationPoint(self: *TreeBuilder, node: *TreeNode) bool {
        _ = self;
        if (node.namespace != .mathml) return false;
        if (node.local_name) |name| {
            return std.mem.eql(u8, name, "mi") or
                std.mem.eql(u8, name, "mo") or
                std.mem.eql(u8, name, "mn") or
                std.mem.eql(u8, name, "ms") or
                std.mem.eql(u8, name, "mtext");
        }
        return false;
    }

    /// Check if node is an HTML integration point.
    fn isHtmlIntegrationPoint(self: *TreeBuilder, node: *TreeNode) bool {
        _ = self;
        // "A MathML annotation-xml element whose start tag token had an
        // attribute with the name "encoding" whose value was an ASCII
        // case-insensitive match for the string "text/html" [or]
        // "application/xhtml+xml"".
        if (node.namespace == .mathml and node.hasTagName("annotation-xml")) {
            const encoding = node.getAttribute("encoding") orelse return false;
            return std.ascii.eqlIgnoreCase(encoding, "text/html") or
                std.ascii.eqlIgnoreCase(encoding, "application/xhtml+xml");
        }
        // SVG foreignObject, desc, title
        if (node.namespace == .svg) {
            if (node.local_name) |name| {
                return std.mem.eql(u8, name, "foreignObject") or
                    std.mem.eql(u8, name, "desc") or
                    std.mem.eql(u8, name, "title");
            }
        }
        return false;
    }

    /// Process token using HTML content rules.
    fn processTokenInHtmlContent(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (self.insertion_mode) {
            .initial => try self.handleInitialMode(token),
            .before_html => try self.handleBeforeHtmlMode(token),
            .before_head => try self.handleBeforeHeadMode(token),
            .in_head => try self.handleInHeadMode(token),
            .in_head_noscript => try self.handleInHeadNoscriptMode(token),
            .after_head => try self.handleAfterHeadMode(token),
            .in_body => try self.handleInBodyMode(token),
            .text => try self.handleTextMode(token),
            .in_table => try self.handleInTableMode(token),
            .in_table_text => try self.handleInTableTextMode(token),
            .in_caption => try self.handleInCaptionMode(token),
            .in_column_group => try self.handleInColumnGroupMode(token),
            .in_table_body => try self.handleInTableBodyMode(token),
            .in_row => try self.handleInRowMode(token),
            .in_cell => try self.handleInCellMode(token),
            .in_select => try self.handleInSelectMode(token),
            .in_select_in_table => try self.handleInSelectInTableMode(token),
            .in_template => try self.handleInTemplateMode(token),
            .after_body => try self.handleAfterBodyMode(token),
            .in_frameset => try self.handleInFramesetMode(token),
            .after_frameset => try self.handleAfterFramesetMode(token),
            .after_after_body => try self.handleAfterAfterBodyMode(token),
            .after_after_frameset => try self.handleAfterAfterFramesetMode(token),
        }
    }

    /// Process token in foreign content.
    ///
    /// HTML Standard §13.2.6.5: The rules for parsing tokens in foreign content.
    fn processTokenInForeignContent(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                if (char == 0x0000) {
                    // NULL: Parse error, insert U+FFFD REPLACEMENT CHARACTER
                    self.reportError(.unexpected_null_character);
                    try self.insertCharacter(0xFFFD);
                } else if (isHtmlWhitespace(char)) {
                    // Whitespace: Insert the token's character
                    try self.insertCharacter(char);
                } else {
                    // Any other character: Insert and set frameset-ok to "not ok"
                    try self.insertCharacter(char);
                    self.frameset_ok = false;
                }
            },
            .text_run => |text_run| {
                // Batch text insertion in foreign content
                // Text runs are guaranteed non-whitespace, so set frameset-ok to "not ok"
                try self.insertTextRun(text_run.data);
                self.frameset_ok = false;
            },
            .comment => |comment| {
                // Insert a comment
                try self.insertComment(comment);
            },
            .doctype => {
                // Parse error, ignore the token
                self.reportError(.unexpected_token_in_foreign_content);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();

                // Check for HTML breakout tags
                if (isForeignContentHtmlBreakout(name) or
                    (std.mem.eql(u8, name, "font") and hasFontBreakoutAttribute(tag)))
                {
                    // Parse error
                    self.reportError(.unexpected_token_in_foreign_content);

                    // Pop elements until we're back in HTML namespace or at an integration point
                    while (self.open_elements.len > 0) {
                        const current = self.currentNode() orelse break;
                        if (current.namespace == .html or
                            self.isMathMLTextIntegrationPoint(current) or
                            self.isHtmlIntegrationPoint(current))
                        {
                            break;
                        }
                        if (self.popCurrentNode() == null) break;
                    }

                    // Reprocess the token according to the current insertion mode
                    try self.processTokenInHtmlContent(token);
                } else {
                    // Any other start tag: adjust it for the adjusted current
                    // node's namespace and insert a foreign element in it.
                    const adjusted_current = self.adjustedCurrentNode() orelse {
                        try self.processTokenInHtmlContent(token);
                        return;
                    };
                    _ = try self.insertForeignElement(tag, adjusted_current.namespace);

                    if (tag.self_closing) {
                        const current = self.currentNode().?;
                        if (std.mem.eql(u8, name, "script") and current.namespace == .svg) {
                            // "Acknowledge the token's self-closing flag, and
                            // then act as described in the steps for a
                            // "script" end tag below."
                            self.processSvgScriptEndTag();
                        } else {
                            // "Pop the current node off the stack of open
                            // elements and acknowledge the token's
                            // self-closing flag."
                            _ = self.popCurrentNode();
                        }
                    }
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();

                // "br" or "p" end tags break out of foreign content
                if (std.mem.eql(u8, name, "br") or std.mem.eql(u8, name, "p")) {
                    // Parse error
                    self.reportError(.unexpected_token_in_foreign_content);

                    // Pop elements until we're back in HTML namespace
                    while (self.open_elements.len > 0) {
                        const current = self.currentNode() orelse break;
                        if (current.namespace == .html or
                            self.isMathMLTextIntegrationPoint(current) or
                            self.isHtmlIntegrationPoint(current))
                        {
                            break;
                        }
                        if (self.popCurrentNode() == null) break;
                    }

                    // Reprocess the token
                    try self.processTokenInHtmlContent(token);
                } else if (std.mem.eql(u8, name, "script") and
                    self.currentNode() != null and
                    self.currentNode().?.namespace == .svg and
                    self.currentNode().?.hasTagName("script"))
                {
                    self.processSvgScriptEndTag();
                } else {
                    // Any other end tag.
                    // Step 1: node is the current node.
                    if (self.open_elements.len == 0) return;
                    var node_index: usize = self.open_elements.len - 1;
                    while (true) {
                        const node = self.open_elements.get(node_index) orelse return;
                        // Step 3: the topmost element - return (fragment case).
                        if (node_index == 0) return;
                        // Step 4: a match, ASCII case-insensitively (an SVG
                        // name like clipPath against the token's clippath):
                        // pop up to and including it.
                        if (node.local_name != null and std.ascii.eqlIgnoreCase(node.local_name.?, name)) {
                            while (self.open_elements.len > node_index) {
                                if (self.popCurrentNode() == null) break;
                            }
                            return;
                        }
                        // Step 5: the previous entry.
                        node_index -= 1;
                        const previous = self.open_elements.get(node_index) orelse return;
                        // Steps 6-7: an HTML element - process the token by
                        // the current insertion mode's rules.
                        if (previous.namespace == .html) {
                            try self.processTokenInHtmlContent(token);
                            return;
                        }
                    }
                }
            },
            .eof => {
                // Should not happen - EOF uses HTML content rules
                try self.processTokenInHtmlContent(token);
            },
        }
    }

    /// Check if tag name is an HTML breakout tag for foreign content.
    fn isForeignContentHtmlBreakout(name: []const u8) bool {
        const breakout_tags = [_][]const u8{
            "b",       "big",  "blockquote", "body",  "br",   "center",
            "code",    "dd",   "div",        "dl",    "dt",   "em",
            "embed",   "h1",   "h2",         "h3",    "h4",   "h5",
            "h6",      "head", "hr",         "i",     "img",  "li",
            "listing", "menu", "meta",       "nobr",  "ol",   "p",
            "pre",     "ruby", "s",          "small", "span", "strong",
            "strike",  "sub",  "sup",        "table", "tt",   "u",
            "ul",      "var",
        };
        for (breakout_tags) |tag| {
            if (std.mem.eql(u8, name, tag)) return true;
        }
        return false;
    }

    /// Check if font tag has breakout attributes (color, face, size).
    fn hasFontBreakoutAttribute(tag: TagToken) bool {
        const attrs = tag.attributes.toSlice();
        for (attrs) |attr| {
            const attr_name = attr.getName();
            if (std.mem.eql(u8, attr_name, "color") or
                std.mem.eql(u8, attr_name, "face") or
                std.mem.eql(u8, attr_name, "size"))
            {
                return true;
            }
        }
        return false;
    }

    /// Adjust SVG tag name (case correction).
    fn adjustSvgTagName(name: []const u8) []const u8 {
        // Map lowercase to proper case for SVG elements
        const svg_tag_map = [_]struct { from: []const u8, to: []const u8 }{
            .{ .from = "altglyph", .to = "altGlyph" },
            .{ .from = "altglyphdef", .to = "altGlyphDef" },
            .{ .from = "altglyphitem", .to = "altGlyphItem" },
            .{ .from = "animatecolor", .to = "animateColor" },
            .{ .from = "animatemotion", .to = "animateMotion" },
            .{ .from = "animatetransform", .to = "animateTransform" },
            .{ .from = "clippath", .to = "clipPath" },
            .{ .from = "feblend", .to = "feBlend" },
            .{ .from = "fecolormatrix", .to = "feColorMatrix" },
            .{ .from = "fecomponenttransfer", .to = "feComponentTransfer" },
            .{ .from = "fecomposite", .to = "feComposite" },
            .{ .from = "feconvolvematrix", .to = "feConvolveMatrix" },
            .{ .from = "fediffuselighting", .to = "feDiffuseLighting" },
            .{ .from = "fedisplacementmap", .to = "feDisplacementMap" },
            .{ .from = "fedistantlight", .to = "feDistantLight" },
            .{ .from = "fedropshadow", .to = "feDropShadow" },
            .{ .from = "feflood", .to = "feFlood" },
            .{ .from = "fefunca", .to = "feFuncA" },
            .{ .from = "fefuncb", .to = "feFuncB" },
            .{ .from = "fefuncg", .to = "feFuncG" },
            .{ .from = "fefuncr", .to = "feFuncR" },
            .{ .from = "fegaussianblur", .to = "feGaussianBlur" },
            .{ .from = "feimage", .to = "feImage" },
            .{ .from = "femerge", .to = "feMerge" },
            .{ .from = "femergenode", .to = "feMergeNode" },
            .{ .from = "femorphology", .to = "feMorphology" },
            .{ .from = "feoffset", .to = "feOffset" },
            .{ .from = "fepointlight", .to = "fePointLight" },
            .{ .from = "fespecularlighting", .to = "feSpecularLighting" },
            .{ .from = "fespotlight", .to = "feSpotLight" },
            .{ .from = "fetile", .to = "feTile" },
            .{ .from = "feturbulence", .to = "feTurbulence" },
            .{ .from = "foreignobject", .to = "foreignObject" },
            .{ .from = "glyphref", .to = "glyphRef" },
            .{ .from = "lineargradient", .to = "linearGradient" },
            .{ .from = "radialgradient", .to = "radialGradient" },
            .{ .from = "textpath", .to = "textPath" },
        };

        for (svg_tag_map) |entry| {
            if (std.mem.eql(u8, name, entry.from)) {
                return entry.to;
            }
        }
        return name;
    }

    /// Adjust MathML attribute (case correction).
    fn adjustMathMLAttribute(name: []const u8) struct { name: []const u8 } {
        // MathML attribute adjustment (definitionurl -> definitionURL)
        if (std.mem.eql(u8, name, "definitionurl")) {
            return .{ .name = "definitionURL" };
        }
        return .{ .name = name };
    }

    /// Adjust SVG attribute (case correction).
    fn adjustSvgAttribute(name: []const u8) struct { name: []const u8 } {
        // SVG attribute case adjustments
        const svg_attr_map = [_]struct { from: []const u8, to: []const u8 }{
            .{ .from = "attributename", .to = "attributeName" },
            .{ .from = "attributetype", .to = "attributeType" },
            .{ .from = "basefrequency", .to = "baseFrequency" },
            .{ .from = "baseprofile", .to = "baseProfile" },
            .{ .from = "calcmode", .to = "calcMode" },
            .{ .from = "clippathunits", .to = "clipPathUnits" },
            .{ .from = "diffuseconstant", .to = "diffuseConstant" },
            .{ .from = "edgemode", .to = "edgeMode" },
            .{ .from = "filterunits", .to = "filterUnits" },
            .{ .from = "glyphref", .to = "glyphRef" },
            .{ .from = "gradienttransform", .to = "gradientTransform" },
            .{ .from = "gradientunits", .to = "gradientUnits" },
            .{ .from = "kernelmatrix", .to = "kernelMatrix" },
            .{ .from = "kernelunitlength", .to = "kernelUnitLength" },
            .{ .from = "keypoints", .to = "keyPoints" },
            .{ .from = "keysplines", .to = "keySplines" },
            .{ .from = "keytimes", .to = "keyTimes" },
            .{ .from = "lengthadjust", .to = "lengthAdjust" },
            .{ .from = "limitingconeangle", .to = "limitingConeAngle" },
            .{ .from = "markerheight", .to = "markerHeight" },
            .{ .from = "markerunits", .to = "markerUnits" },
            .{ .from = "markerwidth", .to = "markerWidth" },
            .{ .from = "maskcontentunits", .to = "maskContentUnits" },
            .{ .from = "maskunits", .to = "maskUnits" },
            .{ .from = "numoctaves", .to = "numOctaves" },
            .{ .from = "pathlength", .to = "pathLength" },
            .{ .from = "patterncontentunits", .to = "patternContentUnits" },
            .{ .from = "patterntransform", .to = "patternTransform" },
            .{ .from = "patternunits", .to = "patternUnits" },
            .{ .from = "pointsatx", .to = "pointsAtX" },
            .{ .from = "pointsaty", .to = "pointsAtY" },
            .{ .from = "pointsatz", .to = "pointsAtZ" },
            .{ .from = "preservealpha", .to = "preserveAlpha" },
            .{ .from = "preserveaspectratio", .to = "preserveAspectRatio" },
            .{ .from = "primitiveunits", .to = "primitiveUnits" },
            .{ .from = "refx", .to = "refX" },
            .{ .from = "refy", .to = "refY" },
            .{ .from = "repeatcount", .to = "repeatCount" },
            .{ .from = "repeatdur", .to = "repeatDur" },
            .{ .from = "requiredextensions", .to = "requiredExtensions" },
            .{ .from = "requiredfeatures", .to = "requiredFeatures" },
            .{ .from = "specularconstant", .to = "specularConstant" },
            .{ .from = "specularexponent", .to = "specularExponent" },
            .{ .from = "spreadmethod", .to = "spreadMethod" },
            .{ .from = "startoffset", .to = "startOffset" },
            .{ .from = "stddeviation", .to = "stdDeviation" },
            .{ .from = "stitchtiles", .to = "stitchTiles" },
            .{ .from = "surfacescale", .to = "surfaceScale" },
            .{ .from = "systemlanguage", .to = "systemLanguage" },
            .{ .from = "tablevalues", .to = "tableValues" },
            .{ .from = "targetx", .to = "targetX" },
            .{ .from = "targety", .to = "targetY" },
            .{ .from = "textlength", .to = "textLength" },
            .{ .from = "viewbox", .to = "viewBox" },
            .{ .from = "viewtarget", .to = "viewTarget" },
            .{ .from = "xchannelselector", .to = "xChannelSelector" },
            .{ .from = "ychannelselector", .to = "yChannelSelector" },
            .{ .from = "zoomandpan", .to = "zoomAndPan" },
        };

        for (svg_attr_map) |entry| {
            if (std.mem.eql(u8, name, entry.from)) {
                return .{ .name = entry.to };
            }
        }
        return .{ .name = name };
    }

    /// "Adjust foreign attributes" for one attribute: an attribute whose name
    /// is in the table becomes namespaced, with the table's prefix and local
    /// name; any other name is left alone (an "xlink:foo" is an attribute
    /// with a colon in its name, in no namespace).
    ///
    /// Spec: https://html.spec.whatwg.org/multipage/parsing.html#adjust-foreign-attributes
    const ForeignAttribute = struct { prefix: ?[]const u8, local_name: []const u8, namespace: ?AttributeNamespace };

    fn adjustForeignAttribute(name: []const u8) ForeignAttribute {
        const table = [_]struct { name: []const u8, attr: ForeignAttribute }{
            .{ .name = "xlink:actuate", .attr = .{ .prefix = "xlink", .local_name = "actuate", .namespace = .xlink } },
            .{ .name = "xlink:arcrole", .attr = .{ .prefix = "xlink", .local_name = "arcrole", .namespace = .xlink } },
            .{ .name = "xlink:href", .attr = .{ .prefix = "xlink", .local_name = "href", .namespace = .xlink } },
            .{ .name = "xlink:role", .attr = .{ .prefix = "xlink", .local_name = "role", .namespace = .xlink } },
            .{ .name = "xlink:show", .attr = .{ .prefix = "xlink", .local_name = "show", .namespace = .xlink } },
            .{ .name = "xlink:title", .attr = .{ .prefix = "xlink", .local_name = "title", .namespace = .xlink } },
            .{ .name = "xlink:type", .attr = .{ .prefix = "xlink", .local_name = "type", .namespace = .xlink } },
            .{ .name = "xml:lang", .attr = .{ .prefix = "xml", .local_name = "lang", .namespace = .xml } },
            .{ .name = "xml:space", .attr = .{ .prefix = "xml", .local_name = "space", .namespace = .xml } },
            .{ .name = "xmlns", .attr = .{ .prefix = null, .local_name = "xmlns", .namespace = .xmlns } },
            .{ .name = "xmlns:xlink", .attr = .{ .prefix = "xmlns", .local_name = "xlink", .namespace = .xmlns } },
        };
        for (table) |entry| {
            if (std.mem.eql(u8, name, entry.name)) return entry.attr;
        }
        return .{ .prefix = null, .local_name = name, .namespace = null };
    }

    /// "Insert a foreign element" for `tag` in `namespace` (SVG or MathML),
    /// having adjusted the token as the caller's step says: the SVG tag name
    /// and attributes for SVG, the MathML attributes for MathML, and the
    /// foreign attributes for both.
    ///
    /// Spec: https://html.spec.whatwg.org/multipage/parsing.html#insert-a-foreign-element
    fn insertForeignElement(self: *TreeBuilder, tag: TagToken, namespace: Namespace) !*TreeNode {
        const element = try createForeignElement(self.allocator, tag, namespace);

        // "Create an element for the token", then "insert an element at the
        // adjusted insertion location", then push it.
        self.flushPendingText();
        if (self.dom_adapter_on_node_created) |callback| {
            callback(element, self.dom_adapter_context);
        }
        self.insertAtAppropriatePlace(element);
        try self.open_elements.append(element);
        return element;
    }

    /// "Create an element for the token" for a foreign element: the adjusted
    /// tag name, and the token's attributes adjusted and appended. Owned by
    /// the caller until inserted.
    fn createForeignElement(allocator: Allocator, tag: TagToken, namespace: Namespace) !*TreeNode {
        const name = tag.getTagName();
        const element_name = if (namespace == .svg) adjustSvgTagName(name) else name;
        const element = try TreeNode.initElement(allocator, element_name, namespace);
        errdefer element.deinit();

        for (tag.attributes.toSlice()) |attr| {
            var attr_name = attr.getName();
            switch (namespace) {
                .mathml => attr_name = adjustMathMLAttribute(attr_name).name,
                .svg => attr_name = adjustSvgAttribute(attr_name).name,
                .html => {},
            }
            const foreign = adjustForeignAttribute(attr_name);
            try element.addNamespacedAttribute(foreign.local_name, attr.getValue(), foreign.namespace, foreign.prefix);
        }
        return element;
    }

    /// The "script" end tag steps for an SVG script, which is the current
    /// node: pop it, and process it with the parser's script nesting level
    /// raised - the callback runs it.
    ///
    /// Spec: https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-inforeign
    /// ("An end tag whose tag name is "script", if the current node is an SVG
    /// script element")
    fn processSvgScriptEndTag(self: *TreeBuilder) void {
        const script_element = self.currentNode() orelse return;
        if (self.popCurrentNode() == null) return;

        if (!self.scripting_enabled) return;
        self.flushPendingText();
        const callback = self.script_execution_callback orelse return;
        if (self.input_stream_manager) |stream| stream.pushInsertionPoint();
        self.script_nesting_level += 1;
        self.parser_pause_flag = true;
        callback(script_element, self.script_execution_context);
        self.script_nesting_level -|= 1;
        if (self.script_nesting_level == 0) self.parser_pause_flag = false;
        if (self.input_stream_manager) |stream| stream.popInsertionPoint();
    }

    // =========================================================================
    // Insertion Mode Handlers
    // =========================================================================

    /// Handle token in "initial" insertion mode.
    /// HTML Standard §13.2.6.4.1
    fn handleInitialMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                // Ignore whitespace
                if (isHtmlWhitespace(char)) return;
                // Fall through to anything else
                self.handleInitialAnythingElse(token);
            },
            .comment => |comment| {
                // Insert comment as last child of Document
                try self.insertCommentIn(self.document, comment);
            },
            .doctype => |doctype| {
                // Handle DOCTYPE
                try self.handleInitialDoctype(doctype);
            },
            else => {
                self.handleInitialAnythingElse(token);
            },
        }
    }

    fn handleInitialDoctype(self: *TreeBuilder, doctype: DoctypeToken) !void {
        const name = doctype.getName();
        const public_id = doctype.getPublicIdentifier();
        const system_id = doctype.getSystemIdentifier();

        // Check for parse errors (non-conforming DOCTYPE)
        const is_html = if (name) |n| std.mem.eql(u8, n, "html") else false;
        if (!is_html or public_id != null or (system_id != null and !std.mem.eql(u8, system_id.?, "about:legacy-compat"))) {
            self.reportError(.invalid_character_sequence_after_doctype_name);
        }

        // Append DocumentType node
        const doctype_node = try TreeNode.initDoctype(
            self.allocator,
            name,
            public_id,
            system_id,
            doctype.force_quirks,
        );
        self.document.appendChild(doctype_node);

        // Notify DOM adapter of doctype creation and parent-child relationship
        self.flushPendingText();
        if (self.dom_adapter_on_node_created) |callback| {
            callback(doctype_node, self.dom_adapter_context);
        }
        self.flushPendingText();
        if (self.dom_adapter_on_child_appended) |callback| {
            callback(self.document, doctype_node, self.dom_adapter_context);
        }

        // "Then, if the document is not an iframe srcdoc document, and the
        // parser cannot change the mode flag is false, and the DOCTYPE token
        // matches one of the conditions in the following list, then set the
        // Document to quirks mode ... Otherwise, if ... limited-quirks mode".
        // No-quirks is set too: it is the default, but a Document the parser
        // is handed may not be fresh.
        if (!self.iframe_srcdoc and !self.parser_cannot_change_mode) {
            self.setDocumentMode(doctypeMode(name, public_id, system_id, doctype.force_quirks));
        }

        // Switch to "before html" mode
        self.insertion_mode = .before_html;
    }

    /// Set the document's mode: the tree builder's copy, and the Document
    /// the DOM adapter builds.
    fn setDocumentMode(self: *TreeBuilder, mode: QuirksMode) void {
        self.quirks_mode = mode;
        if (self.dom_adapter_on_mode_set) |callback| callback(mode, self.dom_adapter_context);
    }

    fn handleInitialAnythingElse(self: *TreeBuilder, token: Token) void {
        // "If the document is not an iframe srcdoc document, then this is a
        // parse error; if the parser cannot change the mode flag is false, set
        // the Document to quirks mode."
        if (!self.iframe_srcdoc) {
            self.reportError(.missing_doctype_name);
            if (!self.parser_cannot_change_mode) self.setDocumentMode(.quirks);
        }
        // Switch to "before html" and reprocess
        self.insertion_mode = .before_html;
        // Reprocess is handled by caller returning and re-calling processToken
        self.processToken(token) catch {};
    }

    /// Handle token in "before html" insertion mode.
    /// HTML Standard §13.2.6.4.2
    fn handleBeforeHtmlMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .doctype => {
                // Parse error, ignore
                self.reportError(.missing_doctype_name);
            },
            .comment => |comment| {
                // Insert comment as last child of Document
                try self.insertCommentIn(self.document, comment);
            },
            .character => |char| {
                // Ignore whitespace
                if (isHtmlWhitespace(char)) return;
                // Fall through to anything else
                try self.handleBeforeHtmlAnythingElse();
                try self.processToken(token);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    // Create html element and append to document
                    const html = try self.createElementForToken(tag, .html, .{ .parent = self.document });
                    self.document.appendChild(html);
                    self.releaseDetached(html);

                    // Notify DOM adapter of parent-child relationship
                    self.flushPendingText();
                    if (self.dom_adapter_on_child_appended) |callback| {
                        callback(self.document, html, self.dom_adapter_context);
                    }

                    try self.open_elements.append(html);
                    self.insertion_mode = .before_head;
                } else {
                    try self.handleBeforeHtmlAnythingElse();
                    try self.processToken(token);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "head") or
                    std.mem.eql(u8, name, "body") or
                    std.mem.eql(u8, name, "html") or
                    std.mem.eql(u8, name, "br"))
                {
                    try self.handleBeforeHtmlAnythingElse();
                    try self.processToken(token);
                } else {
                    // Parse error, ignore
                    self.reportError(.invalid_first_character_of_tag_name);
                }
            },
            .eof => {
                try self.handleBeforeHtmlAnythingElse();
                try self.processToken(token);
            },
            .text_run => {
                // Text runs contain non-whitespace text, treat as "anything else"
                try self.handleBeforeHtmlAnythingElse();
                try self.processToken(token);
            },
        }
    }

    fn handleBeforeHtmlAnythingElse(self: *TreeBuilder) !void {
        // Create html element and append to document
        const html = try TreeNode.initElement(self.allocator, "html", .html);

        // Notify DOM adapter of element creation
        self.flushPendingText();
        if (self.dom_adapter_on_node_created) |callback| {
            callback(html, self.dom_adapter_context);
        }

        self.document.appendChild(html);

        // Notify DOM adapter of parent-child relationship
        self.flushPendingText();
        if (self.dom_adapter_on_child_appended) |callback| {
            callback(self.document, html, self.dom_adapter_context);
        }

        try self.open_elements.append(html);
        self.insertion_mode = .before_head;
    }

    /// Handle token in "before head" insertion mode.
    /// HTML Standard §13.2.6.4.3
    fn handleBeforeHeadMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                if (isHtmlWhitespace(char)) return;
                try self.handleBeforeHeadAnythingElse();
                try self.processToken(token);
            },
            .comment => |comment| {
                try self.insertComment(comment);
            },
            .doctype => {
                self.reportError(.missing_doctype_name);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    try self.handleInBodyMode(token);
                } else if (std.mem.eql(u8, name, "head")) {
                    const head = try self.insertHtmlElement(tag);
                    self.head_element = head;
                    self.insertion_mode = .in_head;
                } else {
                    try self.handleBeforeHeadAnythingElse();
                    try self.processToken(token);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "head") or
                    std.mem.eql(u8, name, "body") or
                    std.mem.eql(u8, name, "html") or
                    std.mem.eql(u8, name, "br"))
                {
                    try self.handleBeforeHeadAnythingElse();
                    try self.processToken(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                }
            },
            .eof => {
                try self.handleBeforeHeadAnythingElse();
                try self.processToken(token);
            },
            .text_run => {
                // Text runs contain non-whitespace text, treat as "anything else"
                try self.handleBeforeHeadAnythingElse();
                try self.processToken(token);
            },
        }
    }

    fn handleBeforeHeadAnythingElse(self: *TreeBuilder) !void {
        // Insert implicit head element
        const head = try TreeNode.initElement(self.allocator, "head", .html);

        // Notify DOM adapter of element creation
        self.flushPendingText();
        if (self.dom_adapter_on_node_created) |callback| {
            callback(head, self.dom_adapter_context);
        }

        self.insertAtAppropriatePlace(head);
        try self.open_elements.append(head);
        self.head_element = head;
        self.insertion_mode = .in_head;
    }

    /// Handle token in "in head" insertion mode.
    /// HTML Standard §13.2.6.4.4
    fn handleInHeadMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                if (isHtmlWhitespace(char)) {
                    try self.insertCharacter(char);
                } else {
                    try self.handleInHeadAnythingElse();
                    try self.processToken(token);
                }
            },
            .comment => |comment| {
                try self.insertComment(comment);
            },
            .doctype => {
                self.reportError(.missing_doctype_name);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    try self.handleInBodyMode(token);
                } else if (std.mem.eql(u8, name, "base") or
                    std.mem.eql(u8, name, "basefont") or
                    std.mem.eql(u8, name, "bgsound") or
                    std.mem.eql(u8, name, "link"))
                {
                    _ = try self.insertHtmlElement(tag);
                    _ = self.popCurrentNode();
                    // Acknowledge self-closing flag
                } else if (std.mem.eql(u8, name, "meta")) {
                    _ = try self.insertHtmlElement(tag);
                    _ = self.popCurrentNode();

                    // "If the active speculative HTML parser is null" -
                    // Crane has none - the encoding the element declares
                    // changes the encoding (the driver checks that the
                    // confidence is tentative).
                    if (self.change_the_encoding) |hook| {
                        if (metaDeclaredEncoding(tag)) |requested| hook.change(hook.context, requested);
                    }
                } else if (std.mem.eql(u8, name, "title")) {
                    try self.parseGenericRCDATA(tag);
                } else if (std.mem.eql(u8, name, "noscript") and self.scripting_enabled) {
                    try self.parseGenericRawText(tag);
                } else if (std.mem.eql(u8, name, "noframes") or
                    std.mem.eql(u8, name, "style"))
                {
                    try self.parseGenericRawText(tag);
                } else if (std.mem.eql(u8, name, "noscript") and !self.scripting_enabled) {
                    _ = try self.insertHtmlElement(tag);
                    self.insertion_mode = .in_head_noscript;
                } else if (std.mem.eql(u8, name, "script")) {
                    try self.handleScriptStartTag(tag);
                } else if (std.mem.eql(u8, name, "template")) {
                    _ = try self.insertHtmlElement(tag);
                    try self.active_formatting_elements.append(.marker);
                    self.frameset_ok = false;
                    self.insertion_mode = .in_template;
                    try self.template_insertion_modes.append(.in_template);
                } else if (std.mem.eql(u8, name, "head")) {
                    self.reportError(.invalid_first_character_of_tag_name);
                } else {
                    try self.handleInHeadAnythingElse();
                    try self.processToken(token);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "head")) {
                    _ = self.popCurrentNode();
                    self.insertion_mode = .after_head;
                } else if (std.mem.eql(u8, name, "body") or
                    std.mem.eql(u8, name, "html") or
                    std.mem.eql(u8, name, "br"))
                {
                    try self.handleInHeadAnythingElse();
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "template")) {
                    try self.handleTemplateEndTag();
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                }
            },
            .eof => {
                try self.handleInHeadAnythingElse();
                try self.processToken(token);
            },
            .text_run => {
                // Text runs contain non-whitespace text, treat as "anything else"
                try self.handleInHeadAnythingElse();
                try self.processToken(token);
            },
        }
    }

    fn handleInHeadAnythingElse(self: *TreeBuilder) !void {
        // Pop head and switch to after_head
        _ = self.popCurrentNode();
        self.insertion_mode = .after_head;
    }

    fn handleScriptStartTag(self: *TreeBuilder, tag: TagToken) !void {
        // Insert script element
        _ = try self.insertHtmlElement(tag);
        self.tokenizer.state = .script_data;
        self.original_insertion_mode = self.insertion_mode;
        self.insertion_mode = .text;
    }

    /// Pop the current template insertion mode, if there is one.
    ///
    /// https://html.spec.whatwg.org/multipage/parsing.html#the-insertion-mode
    /// says "pop the current template insertion mode off the stack of template
    /// insertion modes" - and the stack can legitimately be empty when a
    /// fragment is parsed straight into an "in template" mode, which is exactly
    /// what `Element.innerHTML` does.
    ///
    /// `len - 1` on an unsigned length underflows there, and Zig's safety check
    /// ABORTS THE PROCESS rather than failing the parse: a WPT run hit it with
    /// `thread ... panic: integer overflow` and took the whole shard down.
    /// Five of the eight pop sites had no emptiness check; three already did.
    fn popTemplateInsertionMode(self: *TreeBuilder) void {
        if (self.template_insertion_modes.len == 0) return;
        _ = self.template_insertion_modes.remove(self.template_insertion_modes.len - 1) catch {};
    }

    fn handleTemplateEndTag(self: *TreeBuilder) !void {
        // Check if template is in stack
        var has_template = false;
        const elements = self.open_elements.toSlice();
        for (elements) |elem| {
            if (elem.hasTagName("template")) {
                has_template = true;
                break;
            }
        }
        if (!has_template) {
            self.reportError(.invalid_first_character_of_tag_name);
            return;
        }

        // Generate all implied end tags thoroughly
        try self.generateAllImpliedEndTagsThoroughly();

        // Check if current node is template
        if (self.currentNode()) |current| {
            if (!current.hasTagName("template")) {
                self.reportError(.invalid_first_character_of_tag_name);
            }
        }

        // Pop elements until template
        while (self.open_elements.len > 0) {
            const elem = self.popCurrentNode() orelse break;
            if (elem.hasTagName("template")) break;
        }

        // Clear active formatting elements to last marker
        self.clearActiveFormattingToMarker();

        // Pop template insertion mode
        if (self.template_insertion_modes.len > 0) {
            _ = self.template_insertion_modes.remove(self.template_insertion_modes.len - 1) catch {};
        }

        // Reset insertion mode appropriately
        self.resetInsertionModeAppropriately();
    }

    /// Handle token in "in head noscript" insertion mode.
    fn handleInHeadNoscriptMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .doctype => {
                self.reportError(.missing_doctype_name);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    try self.handleInBodyMode(token);
                } else if (std.mem.eql(u8, name, "basefont") or
                    std.mem.eql(u8, name, "bgsound") or
                    std.mem.eql(u8, name, "link") or
                    std.mem.eql(u8, name, "meta") or
                    std.mem.eql(u8, name, "noframes") or
                    std.mem.eql(u8, name, "style"))
                {
                    try self.handleInHeadMode(token);
                } else if (std.mem.eql(u8, name, "head") or std.mem.eql(u8, name, "noscript")) {
                    self.reportError(.invalid_first_character_of_tag_name);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    _ = self.popCurrentNode();
                    self.insertion_mode = .in_head;
                    try self.processToken(token);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "noscript")) {
                    _ = self.popCurrentNode();
                    self.insertion_mode = .in_head;
                } else if (std.mem.eql(u8, name, "br")) {
                    self.reportError(.invalid_first_character_of_tag_name);
                    _ = self.popCurrentNode();
                    self.insertion_mode = .in_head;
                    try self.processToken(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                }
            },
            .character => |char| {
                if (isHtmlWhitespace(char)) {
                    try self.handleInHeadMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    _ = self.popCurrentNode();
                    self.insertion_mode = .in_head;
                    try self.processToken(token);
                }
            },
            .comment => {
                try self.handleInHeadMode(token);
            },
            .eof => {
                self.reportError(.invalid_first_character_of_tag_name);
                _ = self.popCurrentNode();
                self.insertion_mode = .in_head;
                try self.processToken(token);
            },
            .text_run => {
                // Text runs contain non-whitespace text
                self.reportError(.invalid_first_character_of_tag_name);
                _ = self.popCurrentNode();
                self.insertion_mode = .in_head;
                try self.processToken(token);
            },
        }
    }

    /// Handle token in "after head" insertion mode.
    fn handleAfterHeadMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                if (isHtmlWhitespace(char)) {
                    try self.insertCharacter(char);
                } else {
                    try self.handleAfterHeadAnythingElse();
                    try self.processToken(token);
                }
            },
            .comment => |comment| {
                try self.insertComment(comment);
            },
            .doctype => {
                self.reportError(.missing_doctype_name);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    try self.handleInBodyMode(token);
                } else if (std.mem.eql(u8, name, "body")) {
                    _ = try self.insertHtmlElement(tag);
                    self.frameset_ok = false;
                    self.insertion_mode = .in_body;
                } else if (std.mem.eql(u8, name, "frameset")) {
                    _ = try self.insertHtmlElement(tag);
                    self.insertion_mode = .in_frameset;
                } else if (std.mem.eql(u8, name, "base") or
                    std.mem.eql(u8, name, "basefont") or
                    std.mem.eql(u8, name, "bgsound") or
                    std.mem.eql(u8, name, "link") or
                    std.mem.eql(u8, name, "meta") or
                    std.mem.eql(u8, name, "noframes") or
                    std.mem.eql(u8, name, "script") or
                    std.mem.eql(u8, name, "style") or
                    std.mem.eql(u8, name, "template") or
                    std.mem.eql(u8, name, "title"))
                {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Push head back onto stack
                    if (self.head_element) |head| {
                        try self.open_elements.append(head);
                        try self.handleInHeadMode(token);
                        // Remove head from stack
                        var i: usize = 0;
                        while (i < self.open_elements.len) : (i += 1) {
                            if (self.open_elements.get(i) == head) {
                                _ = self.removeOpenElementAt(i);
                                break;
                            }
                        }
                    }
                } else if (std.mem.eql(u8, name, "head")) {
                    self.reportError(.invalid_first_character_of_tag_name);
                } else {
                    try self.handleAfterHeadAnythingElse();
                    try self.processToken(token);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "template")) {
                    try self.handleInHeadMode(token);
                } else if (std.mem.eql(u8, name, "body") or
                    std.mem.eql(u8, name, "html") or
                    std.mem.eql(u8, name, "br"))
                {
                    try self.handleAfterHeadAnythingElse();
                    try self.processToken(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                }
            },
            .eof => {
                try self.handleAfterHeadAnythingElse();
                try self.processToken(token);
            },
            .text_run => {
                // Text runs contain non-whitespace text, treat as "anything else"
                try self.handleAfterHeadAnythingElse();
                try self.processToken(token);
            },
        }
    }

    fn handleAfterHeadAnythingElse(self: *TreeBuilder) !void {
        // Insert implicit body element
        const body = try TreeNode.initElement(self.allocator, "body", .html);

        // Notify DOM adapter of element creation
        self.flushPendingText();
        if (self.dom_adapter_on_node_created) |callback| {
            callback(body, self.dom_adapter_context);
        }

        self.insertAtAppropriatePlace(body);
        try self.open_elements.append(body);
        self.insertion_mode = .in_body;
    }

    /// Handle token in "in body" insertion mode.
    /// HTML Standard §13.2.6.4.7 (simplified)
    fn handleInBodyMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                if (char == 0) {
                    self.reportError(.unexpected_null_character);
                } else {
                    // Reconstruct active formatting elements
                    try self.reconstructActiveFormattingElements();
                    try self.insertCharacter(char);
                    if (!isHtmlWhitespace(char)) {
                        self.frameset_ok = false;
                    }
                }
            },
            .text_run => |text_run| {
                // Batch text insertion - much faster than per-character
                // Note: text_run data is guaranteed to be simple ASCII text without
                // NULL, CR, LF, or character references (pre-validated by tokenizer)
                try self.reconstructActiveFormattingElements();
                try self.insertTextRun(text_run.data);
                // Text runs contain non-whitespace text, so clear frameset_ok
                self.frameset_ok = false;
            },
            .comment => |comment| {
                try self.insertComment(comment);
            },
            .doctype => {
                self.reportError(.missing_doctype_name);
            },
            .start_tag => |tag| {
                try self.handleInBodyStartTag(tag);
            },
            .end_tag => |tag| {
                try self.handleInBodyEndTag(tag);
            },
            .eof => {
                // Check for unclosed elements
                if (self.template_insertion_modes.len > 0) {
                    try self.handleInTemplateMode(token);
                } else {
                    // Stop parsing
                }
            },
        }
    }

    fn handleInBodyStartTag(self: *TreeBuilder, tag: TagToken) !void {
        const name = tag.getTagName();

        // In-body start tags caption/col/colgroup/frame/head/tbody/td/tfoot/
        // th/thead/tr: parse error, ignore. Other modes handle these before
        // delegating here; in particular a template must not create a head.
        if (std.StaticStringMap(void).initComptime(.{
            .{ "caption", {} }, .{ "col", {} },   .{ "colgroup", {} },
            .{ "frame", {} },   .{ "head", {} },  .{ "tbody", {} },
            .{ "td", {} },      .{ "tfoot", {} }, .{ "th", {} },
            .{ "thead", {} },   .{ "tr", {} },
        }).has(name)) {
            self.reportError(.invalid_first_character_of_tag_name);
            return;
        }

        if (std.mem.eql(u8, name, "html")) {
            self.reportError(.invalid_first_character_of_tag_name);

            // "In body", html start tag: a template confines these attributes.
            if (self.hasTemplateInStack()) return;

            // Add attributes from the token to the html element if they don't exist
            // HTML Standard §13.2.6.4.7: "Otherwise, for each attribute on the token,
            // check to see if the attribute is already present on the top element of
            // the stack of open elements. If it is not, add the attribute and its
            // corresponding value to that element."
            if (self.open_elements.len > 0) {
                if (self.open_elements.get(0)) |html_element| {
                    try self.copyMissingAttributes(html_element, tag);
                }
            }
        } else if (std.mem.eql(u8, name, "base") or
            std.mem.eql(u8, name, "basefont") or
            std.mem.eql(u8, name, "bgsound") or
            std.mem.eql(u8, name, "link") or
            std.mem.eql(u8, name, "meta") or
            std.mem.eql(u8, name, "noframes") or
            std.mem.eql(u8, name, "script") or
            std.mem.eql(u8, name, "style") or
            std.mem.eql(u8, name, "template") or
            std.mem.eql(u8, name, "title"))
        {
            try self.handleInHeadMode(Token{ .start_tag = tag });
        } else if (std.mem.eql(u8, name, "body")) {
            self.reportError(.invalid_first_character_of_tag_name);
            if (self.hasTemplateInStack()) return;

            // Add attributes to body element if not already present
            // HTML Standard §13.2.6.4.7: Similar to html element handling
            // Find the body element (second element on stack if present)
            if (self.open_elements.len >= 2) {
                if (self.open_elements.get(1)) |body_candidate| {
                    if (body_candidate.hasTagName("body")) {
                        try self.copyMissingAttributes(body_candidate, tag);
                        self.frameset_ok = false;
                    }
                }
            }
        } else if (std.mem.eql(u8, name, "frameset")) {
            self.reportError(.invalid_first_character_of_tag_name);
            if (self.open_elements.len < 2 or !self.open_elements.get(1).?.hasTagName("body") or !self.frameset_ok) return;
            // In-body frameset, steps 1–4. The removed body still belongs to
            // the parser's detached-node list until parsing ends.
            const body = self.open_elements.get(1).?;
            self.flushPendingText();
            body.remove();
            self.keepDetached(body);
            if (self.dom_adapter_on_removed) |callback| callback(body, self.dom_adapter_context);
            while (self.open_elements.len > 1) _ = self.popCurrentNode();
            _ = try self.insertHtmlElement(tag);
            self.insertion_mode = .in_frameset;
        } else if (std.mem.eql(u8, name, "form")) {
            // "In body", form start tag: the pointer is ignored in templates.
            const in_template = self.parsingTemplateContents();
            if (self.form_element != null and !in_template) {
                self.reportError(.invalid_first_character_of_tag_name);
                return;
            }
            // Otherwise, steps 1–2.
            try self.closePElementIfInButtonScope();
            const form = try self.insertHtmlElement(tag);
            if (!in_template) self.form_element = form;
        } else if (std.mem.eql(u8, name, "noembed") or
            (std.mem.eql(u8, name, "noscript") and self.scripting_enabled))
        {
            try self.parseGenericRawText(tag);
        } else if (isSpecialBlockElement(name)) {
            try self.closePElementIfInButtonScope();
            _ = try self.insertHtmlElement(tag);
        } else if (std.mem.eql(u8, name, "a")) {
            // In-body anchor start, step 1: close the last active anchor after
            // the marker, including one outside the current table scope.
            var index = self.active_formatting_elements.len;
            while (index > 0) {
                index -= 1;
                const entry = self.active_formatting_elements.get(index).?;
                if (entry == .marker) break;
                if (!entry.element.node.hasTagName("a")) continue;
                const previous = entry.element.node;
                self.reportError(.invalid_first_character_of_tag_name);
                try self.adoptionAgencyAlgorithm("a");
                if (self.formattingIndex(previous)) |position| self.removeFormattingAt(position);
                if (self.openIndex(previous)) |position| _ = self.removeOpenElementAt(position);
                break;
            }
            try self.reconstructActiveFormattingElements();
            const element = try self.insertHtmlElement(tag);
            try self.pushOntoActiveFormattingElements(element, tag);
        } else if (std.mem.eql(u8, name, "nobr")) {
            try self.reconstructActiveFormattingElements();
            if (self.hasElementInScope("nobr")) {
                self.reportError(.invalid_first_character_of_tag_name);
                try self.adoptionAgencyAlgorithm("nobr");
                try self.reconstructActiveFormattingElements();
            }
            const element = try self.insertHtmlElement(tag);
            try self.pushOntoActiveFormattingElements(element, tag);
        } else if (isFormattingElement(name)) {
            try self.reconstructActiveFormattingElements();
            const element = try self.insertHtmlElement(tag);
            try self.pushOntoActiveFormattingElements(element, tag);
        } else if (std.mem.eql(u8, name, "applet") or std.mem.eql(u8, name, "marquee") or std.mem.eql(u8, name, "object")) {
            try self.reconstructActiveFormattingElements();
            _ = try self.insertHtmlElement(tag);
            try self.active_formatting_elements.append(.marker);
            self.frameset_ok = false;
        } else if (std.mem.eql(u8, name, "table")) {
            // In-body table start, steps 1–4.
            if (self.quirks_mode != .quirks) try self.closePElementIfInButtonScope();
            _ = try self.insertHtmlElement(tag);
            self.frameset_ok = false;
            self.insertion_mode = .in_table;
        } else if (std.mem.eql(u8, name, "br")) {
            try self.reconstructActiveFormattingElements();
            _ = try self.insertHtmlElement(tag);
            _ = self.popCurrentNode();
            self.frameset_ok = false;
        } else if (isVoidElement(name)) {
            try self.reconstructActiveFormattingElements();
            _ = try self.insertHtmlElement(tag);
            _ = self.popCurrentNode();
        } else if (std.mem.eql(u8, name, "math") or std.mem.eql(u8, name, "svg")) {
            // "A start tag whose tag name is "math"" / ""svg"": reconstruct
            // the active formatting elements, adjust the MathML or SVG
            // attributes and the foreign attributes, and insert a foreign
            // element in the MathML or SVG namespace. Self-closing: pop it and
            // acknowledge the flag.
            try self.reconstructActiveFormattingElements();
            _ = try self.insertForeignElement(tag, if (name[0] == 'm') .mathml else .svg);
            if (tag.self_closing) {
                _ = self.popCurrentNode();
            }
        } else {
            // Generic handling for other start tags
            try self.reconstructActiveFormattingElements();
            _ = try self.insertHtmlElement(tag);
        }
    }

    fn handleInBodyEndTag(self: *TreeBuilder, tag: TagToken) !void {
        const name = tag.getTagName();

        if (std.mem.eql(u8, name, "template")) {
            try self.handleInHeadMode(Token{ .end_tag = tag });
        } else if (std.mem.eql(u8, name, "form")) {
            if (!self.parsingTemplateContents()) {
                // "In body", form end tag, steps 1–6. Remove only the form
                // from the stack; descendants stay open in malformed markup.
                const form = self.form_element;
                self.form_element = null;
                if (form == null or !self.hasNodeInScope(form.?)) {
                    self.reportError(.invalid_first_character_of_tag_name);
                    return;
                }
                self.generateImpliedEndTags(null);
                if (self.currentNode() != form) self.reportError(.invalid_first_character_of_tag_name);
                for (self.open_elements.toSlice(), 0..) |node, index| {
                    if (node == form.?) {
                        _ = self.removeOpenElementAt(index);
                        break;
                    }
                }
            } else {
                // Template branch, steps 1–4: leave the outer pointer alone.
                if (!self.hasElementInScope("form")) {
                    self.reportError(.invalid_first_character_of_tag_name);
                    return;
                }
                self.generateImpliedEndTags(null);
                if (self.currentNode()) |current| {
                    if (!current.hasTagName("form")) self.reportError(.invalid_first_character_of_tag_name);
                }
                self.popUntilTagName("form");
            }
        } else if (std.mem.eql(u8, name, "body")) {
            if (!self.hasElementInScope("body")) {
                self.reportError(.invalid_first_character_of_tag_name);
                return;
            }
            self.insertion_mode = .after_body;
        } else if (std.mem.eql(u8, name, "html")) {
            if (!self.hasElementInScope("body")) {
                self.reportError(.invalid_first_character_of_tag_name);
                return;
            }
            self.insertion_mode = .after_body;
            try self.processToken(Token{ .end_tag = tag });
        } else if (std.mem.eql(u8, name, "p")) {
            // HTML Standard §13.2.6.4.7: End tag "p" has special handling
            // Uses BUTTON scope, not general scope, and inserts element if not in scope
            const has_p_in_button_scope = self.hasElementInButtonScope("p");
            if (!has_p_in_button_scope) {
                // Parse error - insert an HTML element for a "p" start tag with no attributes
                self.reportError(.invalid_first_character_of_tag_name);
                const p_element = try TreeNode.initElement(self.allocator, "p", .html);
                self.flushPendingText();
                if (self.dom_adapter_on_node_created) |callback| {
                    callback(p_element, self.dom_adapter_context);
                }
                self.insertAtAppropriatePlace(p_element);
                try self.open_elements.append(p_element);
            }
            // Close the p element
            self.generateImpliedEndTags("p");
            if (self.currentNode()) |current| {
                if (!current.hasTagName("p")) {
                    self.reportError(.invalid_first_character_of_tag_name);
                }
            }
            self.popUntilTagName("p");
        } else if (std.mem.eql(u8, name, "applet") or std.mem.eql(u8, name, "marquee") or std.mem.eql(u8, name, "object")) {
            if (!self.hasElementInScope(name)) {
                self.reportError(.invalid_first_character_of_tag_name);
                return;
            }
            // In-body object end, steps 1–4.
            self.generateImpliedEndTags(null);
            if (!self.currentNode().?.hasTagName(name)) self.reportError(.invalid_first_character_of_tag_name);
            self.popUntilTagName(name);
            self.clearActiveFormattingToMarker();
        } else if (isSpecialBlockElement(name)) {
            if (!self.hasElementInScope(name)) {
                self.reportError(.invalid_first_character_of_tag_name);
                return;
            }
            self.generateImpliedEndTags(name);
            if (self.currentNode()) |current| {
                if (!current.hasTagName(name)) {
                    self.reportError(.invalid_first_character_of_tag_name);
                }
            }
            self.popUntilTagName(name);
        } else if (isFormattingElement(name)) {
            try self.adoptionAgencyAlgorithm(name);
        } else {
            // Any other end tag
            try self.handleAnyOtherEndTag(name);
        }
    }

    fn handleAnyOtherEndTag(self: *TreeBuilder, name: []const u8) !void {
        // Walk through stack from bottom to top
        var i = self.open_elements.len;
        while (i > 0) {
            i -= 1;
            const node = self.open_elements.get(i) orelse continue;

            if (node.hasTagName(name)) {
                self.generateImpliedEndTags(name);
                if (self.currentNode()) |current| {
                    if (!current.hasTagName(name)) {
                        self.reportError(.invalid_first_character_of_tag_name);
                    }
                }
                // Pop until and including this element
                while (self.open_elements.len > i) {
                    if (self.popCurrentNode() == null) break;
                }
                break;
            }

            if (self.isSpecialElement(node)) {
                self.reportError(.invalid_first_character_of_tag_name);
                return;
            }
        }
    }

    /// Handle token in "text" insertion mode.
    fn handleTextMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                try self.insertCharacter(char);
            },
            .text_run => |text_run| {
                // Batch text insertion for script/style content
                try self.insertTextRun(text_run.data);
            },
            .eof => {
                self.reportError(.eof_in_tag);
                const popped = self.open_elements.get(self.open_elements.len - 1);
                _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                self.insertion_mode = self.original_insertion_mode;
                if (popped) |element| self.textModePopped(element);
                try self.processToken(token);
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "script")) {
                    // HTML Standard §13.2.6.4.20: Script end tag processing
                    // 1. Pop the current node (script element)
                    const script_element = self.open_elements.get(self.open_elements.len - 1);
                    _ = self.popCurrentNode();

                    // 2. Switch back to original insertion mode
                    self.insertion_mode = self.original_insertion_mode;

                    // 3-4. Execute the script (via callback)
                    // HTML Standard: If scripting is enabled for the Document, then:
                    // - Let the old insertion point have the same value as
                    //   the current insertion point; let the insertion point
                    //   be just before the next input character.
                    // - Increment script nesting level
                    // - Prepare the script element (and, at this stage, run
                    //   the pending parsing-blocking script - the callback's)
                    // - Decrement script nesting level; at zero, unset the
                    //   parser pause flag
                    // - Restore the old insertion point.
                    if (self.scripting_enabled) {
                        if (script_element) |script| {
                            self.flushPendingText();
                            if (self.script_execution_callback) |callback| {
                                if (self.input_stream_manager) |stream| stream.pushInsertionPoint();
                                self.script_nesting_level += 1;
                                callback(script, self.script_execution_context);
                                self.script_nesting_level -|= 1;
                                if (self.script_nesting_level == 0) self.parser_pause_flag = false;
                                if (self.input_stream_manager) |stream| stream.popInsertionPoint();
                            }
                        }
                    }
                } else {
                    const popped = self.open_elements.get(self.open_elements.len - 1);
                    _ = self.open_elements.remove(self.open_elements.len - 1) catch {};
                    self.insertion_mode = self.original_insertion_mode;
                    if (popped) |element| self.textModePopped(element);
                }
            },
            else => {},
        }
    }

    /// The "text" insertion mode popped `element` (not a script): its text
    /// goes to the DOM adapter first, then the adapter hears of the pop - a
    /// style element updates its style block with all of its text.
    fn textModePopped(self: *TreeBuilder, element: *TreeNode) void {
        self.flushPendingText();
        if (self.dom_adapter_on_element_popped) |callback| callback(element, self.dom_adapter_context);
        self.finishedParsingChildren(element);
    }

    /// Pop the current node off the stack of open elements, and tell the
    /// adapter its children are parsed. Null when the stack is empty.
    fn popCurrentNode(self: *TreeBuilder) ?*TreeNode {
        if (self.open_elements.len == 0) return null;
        const node = self.open_elements.remove(self.open_elements.len - 1) catch return null;
        self.finishedParsingChildren(node);
        return node;
    }

    /// Remove the element at `index` - not necessarily the current node -
    /// from the stack of open elements, and tell the adapter. Blink's
    /// HTMLElementStack::RemoveNonTopCommon calls FinishParsingChildren for
    /// such a removal too.
    fn removeOpenElementAt(self: *TreeBuilder, index: usize) ?*TreeNode {
        const node = self.open_elements.remove(index) catch return null;
        self.finishedParsingChildren(node);
        return node;
    }

    /// HTML "stop parsing" (13.2.7 "the end") step 4: "Pop all the nodes off
    /// the stack of open elements", the current node first - each one
    /// finished parsing its children (Blink's HTMLElementStack::PopAll).
    ///
    /// Deviation, stated: it runs as the tree builder stops at the end of
    /// the input, before step 3's readiness change to "interactive", which
    /// the callers run once parse() returns (HTMLParser's
    /// parseHTMLWithScripting, a frame's document). What an element type
    /// does on the pop queues its work (the object element's processing is
    /// a task), so nothing can observe the order.
    fn popAllOpenElements(self: *TreeBuilder) void {
        while (self.popCurrentNode() != null) {}
    }

    /// `element` left the stack of open elements: the adapter hears that its
    /// children are parsed. Text the parser still holds for `element` - its
    /// last child, a run not yet told - goes to the adapter first; text held
    /// anywhere else is left to the next flush, so no run is told in pieces.
    fn finishedParsingChildren(self: *TreeBuilder, element: *TreeNode) void {
        const callback = self.dom_adapter_on_children_finished orelse return;
        if (self.pending_text) |text| {
            if (text.parent == element) self.flushPendingText();
        }
        callback(element, self.dom_adapter_context);
    }

    /// Handle token in "in table" insertion mode.
    /// HTML Standard §13.2.6.4.9
    fn handleInTableMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character, .text_run => {
                // Character token, if current node is table/tbody/template/tfoot/thead/tr
                if (self.currentNode()) |current| {
                    if (current.hasTagName("table") or
                        current.hasTagName("tbody") or
                        current.hasTagName("template") or
                        current.hasTagName("tfoot") or
                        current.hasTagName("thead") or
                        current.hasTagName("tr"))
                    {
                        // Clear pending table character tokens
                        self.pending_table_char_tokens.clear();
                        self.original_insertion_mode = self.insertion_mode;
                        self.insertion_mode = .in_table_text;
                        try self.processToken(token);
                        return;
                    }
                }
                // Otherwise process as "anything else"
                self.reportError(.invalid_first_character_of_tag_name);
                self.foster_parenting = true;
                try self.handleInBodyMode(token);
                self.foster_parenting = false;
            },
            .comment => |comment| {
                try self.insertComment(comment);
            },
            .doctype => {
                self.reportError(.missing_doctype_name);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "caption")) {
                    self.clearStackBackToTableContext();
                    try self.active_formatting_elements.append(.marker);
                    _ = try self.insertHtmlElement(tag);
                    self.insertion_mode = .in_caption;
                } else if (std.mem.eql(u8, name, "colgroup")) {
                    self.clearStackBackToTableContext();
                    _ = try self.insertHtmlElement(tag);
                    self.insertion_mode = .in_column_group;
                } else if (std.mem.eql(u8, name, "col")) {
                    self.clearStackBackToTableContext();
                    // Insert implicit colgroup
                    const colgroup = try TreeNode.initElement(self.allocator, "colgroup", .html);
                    // Notify DOM adapter of element creation
                    self.flushPendingText();
                    if (self.dom_adapter_on_node_created) |callback| {
                        callback(colgroup, self.dom_adapter_context);
                    }
                    self.insertAtAppropriatePlace(colgroup);
                    try self.open_elements.append(colgroup);
                    self.insertion_mode = .in_column_group;
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "thead"))
                {
                    self.clearStackBackToTableContext();
                    _ = try self.insertHtmlElement(tag);
                    self.insertion_mode = .in_table_body;
                } else if (std.mem.eql(u8, name, "td") or
                    std.mem.eql(u8, name, "th") or
                    std.mem.eql(u8, name, "tr"))
                {
                    self.clearStackBackToTableContext();
                    // Insert implicit tbody
                    const tbody = try TreeNode.initElement(self.allocator, "tbody", .html);
                    // Notify DOM adapter of element creation
                    self.flushPendingText();
                    if (self.dom_adapter_on_node_created) |callback| {
                        callback(tbody, self.dom_adapter_context);
                    }
                    self.insertAtAppropriatePlace(tbody);
                    try self.open_elements.append(tbody);
                    self.insertion_mode = .in_table_body;
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "table")) {
                    self.reportError(.invalid_first_character_of_tag_name);
                    if (!self.hasElementInTableScope("table")) {
                        return; // Ignore
                    }
                    self.popUntilTagName("table");
                    self.resetInsertionModeAppropriately();
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "style") or
                    std.mem.eql(u8, name, "script") or
                    std.mem.eql(u8, name, "template"))
                {
                    try self.handleInHeadMode(token);
                } else if (std.mem.eql(u8, name, "input")) {
                    // Check for hidden type
                    if (self.hasTypeHiddenAttribute(tag)) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        _ = try self.insertHtmlElement(tag);
                        _ = self.popCurrentNode();
                    } else {
                        // Anything else
                        self.reportError(.invalid_first_character_of_tag_name);
                        self.foster_parenting = true;
                        try self.handleInBodyMode(token);
                        self.foster_parenting = false;
                    }
                } else if (std.mem.eql(u8, name, "form")) {
                    self.reportError(.invalid_first_character_of_tag_name);
                    const in_template = self.parsingTemplateContents();
                    if (self.form_element != null and !in_template) {
                        return; // Ignore
                    }
                    const form = try self.insertHtmlElement(tag);
                    if (!in_template) self.form_element = form;
                    _ = self.popCurrentNode();
                } else {
                    // Anything else
                    self.reportError(.invalid_first_character_of_tag_name);
                    self.foster_parenting = true;
                    try self.handleInBodyMode(token);
                    self.foster_parenting = false;
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "table")) {
                    if (!self.hasElementInTableScope("table")) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.popUntilTagName("table");
                    self.resetInsertionModeAppropriately();
                } else if (std.mem.eql(u8, name, "body") or
                    std.mem.eql(u8, name, "caption") or
                    std.mem.eql(u8, name, "col") or
                    std.mem.eql(u8, name, "colgroup") or
                    std.mem.eql(u8, name, "html") or
                    std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "td") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "th") or
                    std.mem.eql(u8, name, "thead") or
                    std.mem.eql(u8, name, "tr"))
                {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                } else if (std.mem.eql(u8, name, "template")) {
                    try self.handleInHeadMode(token);
                } else {
                    // Anything else
                    self.reportError(.invalid_first_character_of_tag_name);
                    self.foster_parenting = true;
                    try self.handleInBodyMode(token);
                    self.foster_parenting = false;
                }
            },
            .eof => {
                try self.handleInBodyMode(token);
            },
        }
    }

    /// Handle token in "in table text" insertion mode.
    /// HTML Standard §13.2.6.4.10
    fn handleInTableTextMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                if (char == 0) {
                    self.reportError(.unexpected_null_character);
                    return;
                }
                try self.pending_table_char_tokens.append(char);
            },
            .text_run => |text_run| {
                // Add all characters from text run to pending tokens
                // Text runs are ASCII, so each byte is a codepoint
                for (text_run.data) |byte| {
                    try self.pending_table_char_tokens.append(@intCast(byte));
                }
            },
            else => {
                // Anything else - process pending characters
                var has_non_whitespace = false;
                for (0..self.pending_table_char_tokens.len) |i| {
                    const c = self.pending_table_char_tokens.get(i) orelse continue;
                    if (!isHtmlWhitespace(c)) {
                        has_non_whitespace = true;
                        break;
                    }
                }

                if (has_non_whitespace) {
                    // Parse error, process with foster parenting
                    self.reportError(.invalid_first_character_of_tag_name);
                    self.foster_parenting = true;
                    for (0..self.pending_table_char_tokens.len) |i| {
                        const c = self.pending_table_char_tokens.get(i) orelse continue;
                        try self.handleInBodyMode(.{ .character = c });
                    }
                    self.foster_parenting = false;
                } else {
                    // Insert whitespace characters
                    for (0..self.pending_table_char_tokens.len) |i| {
                        const c = self.pending_table_char_tokens.get(i) orelse continue;
                        try self.insertCharacter(c);
                    }
                }

                self.pending_table_char_tokens.clear();
                self.insertion_mode = self.original_insertion_mode;
                try self.processToken(token);
            },
        }
    }

    /// Handle token in "in caption" insertion mode.
    /// HTML Standard §13.2.6.4.11
    fn handleInCaptionMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "caption")) {
                    if (!self.hasElementInTableScope("caption")) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.generateImpliedEndTags(null);
                    if (self.currentNode()) |current| {
                        if (!current.hasTagName("caption")) {
                            self.reportError(.invalid_first_character_of_tag_name);
                        }
                    }
                    self.popUntilTagName("caption");
                    self.clearActiveFormattingToMarker();
                    self.insertion_mode = .in_table;
                } else if (std.mem.eql(u8, name, "table")) {
                    if (!self.hasElementInTableScope("caption")) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.generateImpliedEndTags(null);
                    if (self.currentNode()) |current| {
                        if (!current.hasTagName("caption")) {
                            self.reportError(.invalid_first_character_of_tag_name);
                        }
                    }
                    self.popUntilTagName("caption");
                    self.clearActiveFormattingToMarker();
                    self.insertion_mode = .in_table;
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "body") or
                    std.mem.eql(u8, name, "col") or
                    std.mem.eql(u8, name, "colgroup") or
                    std.mem.eql(u8, name, "html") or
                    std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "td") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "th") or
                    std.mem.eql(u8, name, "thead") or
                    std.mem.eql(u8, name, "tr"))
                {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                } else {
                    try self.handleInBodyMode(token);
                }
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "caption") or
                    std.mem.eql(u8, name, "col") or
                    std.mem.eql(u8, name, "colgroup") or
                    std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "td") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "th") or
                    std.mem.eql(u8, name, "thead") or
                    std.mem.eql(u8, name, "tr"))
                {
                    if (!self.hasElementInTableScope("caption")) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.generateImpliedEndTags(null);
                    if (self.currentNode()) |current| {
                        if (!current.hasTagName("caption")) {
                            self.reportError(.invalid_first_character_of_tag_name);
                        }
                    }
                    self.popUntilTagName("caption");
                    self.clearActiveFormattingToMarker();
                    self.insertion_mode = .in_table;
                    try self.processToken(token);
                } else {
                    try self.handleInBodyMode(token);
                }
            },
            else => {
                try self.handleInBodyMode(token);
            },
        }
    }

    /// Handle token in "in column group" insertion mode.
    /// HTML Standard §13.2.6.4.12
    fn handleInColumnGroupMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                if (isHtmlWhitespace(char)) {
                    try self.insertCharacter(char);
                } else {
                    // Anything else
                    if (self.currentNode()) |current| {
                        if (!current.hasTagName("colgroup")) {
                            self.reportError(.invalid_first_character_of_tag_name);
                            return;
                        }
                    }
                    _ = self.popCurrentNode();
                    self.insertion_mode = .in_table;
                    try self.processToken(token);
                }
            },
            .comment => |comment| {
                try self.insertComment(comment);
            },
            .doctype => {
                self.reportError(.missing_doctype_name);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    try self.handleInBodyMode(token);
                } else if (std.mem.eql(u8, name, "col")) {
                    _ = try self.insertHtmlElement(tag);
                    _ = self.popCurrentNode();
                } else if (std.mem.eql(u8, name, "template")) {
                    try self.handleInHeadMode(token);
                } else {
                    // Anything else
                    if (self.currentNode()) |current| {
                        if (!current.hasTagName("colgroup")) {
                            self.reportError(.invalid_first_character_of_tag_name);
                            return;
                        }
                    }
                    _ = self.popCurrentNode();
                    self.insertion_mode = .in_table;
                    try self.processToken(token);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "colgroup")) {
                    if (self.currentNode()) |current| {
                        if (!current.hasTagName("colgroup")) {
                            self.reportError(.invalid_first_character_of_tag_name);
                            return;
                        }
                    }
                    _ = self.popCurrentNode();
                    self.insertion_mode = .in_table;
                } else if (std.mem.eql(u8, name, "col")) {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                } else if (std.mem.eql(u8, name, "template")) {
                    try self.handleInHeadMode(token);
                } else {
                    // Anything else
                    if (self.currentNode()) |current| {
                        if (!current.hasTagName("colgroup")) {
                            self.reportError(.invalid_first_character_of_tag_name);
                            return;
                        }
                    }
                    _ = self.popCurrentNode();
                    self.insertion_mode = .in_table;
                    try self.processToken(token);
                }
            },
            .eof => {
                try self.handleInBodyMode(token);
            },
            .text_run => {
                // Text runs are non-whitespace, treat as "anything else"
                if (self.currentNode()) |current| {
                    if (!current.hasTagName("colgroup")) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                }
                _ = self.popCurrentNode();
                self.insertion_mode = .in_table;
                try self.processToken(token);
            },
        }
    }

    /// Handle token in "in table body" insertion mode.
    /// HTML Standard §13.2.6.4.13
    fn handleInTableBodyMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "tr")) {
                    self.clearStackBackToTableBodyContext();
                    _ = try self.insertHtmlElement(tag);
                    self.insertion_mode = .in_row;
                } else if (std.mem.eql(u8, name, "th") or std.mem.eql(u8, name, "td")) {
                    self.reportError(.invalid_first_character_of_tag_name);
                    self.clearStackBackToTableBodyContext();
                    // Insert implicit tr
                    const tr = try TreeNode.initElement(self.allocator, "tr", .html);
                    // Notify DOM adapter of element creation
                    self.flushPendingText();
                    if (self.dom_adapter_on_node_created) |callback| {
                        callback(tr, self.dom_adapter_context);
                    }
                    self.insertAtAppropriatePlace(tr);
                    try self.open_elements.append(tr);
                    self.insertion_mode = .in_row;
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "caption") or
                    std.mem.eql(u8, name, "col") or
                    std.mem.eql(u8, name, "colgroup") or
                    std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "thead"))
                {
                    if (!self.hasTableBodyElementInTableScope()) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.clearStackBackToTableBodyContext();
                    _ = self.popCurrentNode();
                    self.insertion_mode = .in_table;
                    try self.processToken(token);
                } else {
                    try self.handleInTableMode(token);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "thead"))
                {
                    if (!self.hasElementInTableScope(name)) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.clearStackBackToTableBodyContext();
                    _ = self.popCurrentNode();
                    self.insertion_mode = .in_table;
                } else if (std.mem.eql(u8, name, "table")) {
                    if (!self.hasTableBodyElementInTableScope()) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.clearStackBackToTableBodyContext();
                    _ = self.popCurrentNode();
                    self.insertion_mode = .in_table;
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "body") or
                    std.mem.eql(u8, name, "caption") or
                    std.mem.eql(u8, name, "col") or
                    std.mem.eql(u8, name, "colgroup") or
                    std.mem.eql(u8, name, "html") or
                    std.mem.eql(u8, name, "td") or
                    std.mem.eql(u8, name, "th") or
                    std.mem.eql(u8, name, "tr"))
                {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                } else {
                    try self.handleInTableMode(token);
                }
            },
            else => {
                try self.handleInTableMode(token);
            },
        }
    }

    /// Handle token in "in row" insertion mode.
    /// HTML Standard §13.2.6.4.14
    fn handleInRowMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "th") or std.mem.eql(u8, name, "td")) {
                    self.clearStackBackToTableRowContext();
                    _ = try self.insertHtmlElement(tag);
                    self.insertion_mode = .in_cell;
                    try self.active_formatting_elements.append(.marker);
                } else if (std.mem.eql(u8, name, "caption") or
                    std.mem.eql(u8, name, "col") or
                    std.mem.eql(u8, name, "colgroup") or
                    std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "thead") or
                    std.mem.eql(u8, name, "tr"))
                {
                    if (!self.hasElementInTableScope("tr")) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.clearStackBackToTableRowContext();
                    _ = self.popCurrentNode();
                    self.insertion_mode = .in_table_body;
                    try self.processToken(token);
                } else {
                    try self.handleInTableMode(token);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "tr")) {
                    if (!self.hasElementInTableScope("tr")) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.clearStackBackToTableRowContext();
                    _ = self.popCurrentNode();
                    self.insertion_mode = .in_table_body;
                } else if (std.mem.eql(u8, name, "table")) {
                    if (!self.hasElementInTableScope("tr")) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.clearStackBackToTableRowContext();
                    _ = self.popCurrentNode();
                    self.insertion_mode = .in_table_body;
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "thead"))
                {
                    if (!self.hasElementInTableScope(name)) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    if (!self.hasElementInTableScope("tr")) {
                        return; // Ignore
                    }
                    self.clearStackBackToTableRowContext();
                    _ = self.popCurrentNode();
                    self.insertion_mode = .in_table_body;
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "body") or
                    std.mem.eql(u8, name, "caption") or
                    std.mem.eql(u8, name, "col") or
                    std.mem.eql(u8, name, "colgroup") or
                    std.mem.eql(u8, name, "html") or
                    std.mem.eql(u8, name, "td") or
                    std.mem.eql(u8, name, "th"))
                {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                } else {
                    try self.handleInTableMode(token);
                }
            },
            else => {
                try self.handleInTableMode(token);
            },
        }
    }

    /// Handle token in "in cell" insertion mode.
    /// HTML Standard §13.2.6.4.15
    fn handleInCellMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "td") or std.mem.eql(u8, name, "th")) {
                    if (!self.hasElementInTableScope(name)) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.generateImpliedEndTags(null);
                    if (self.currentNode()) |current| {
                        if (!current.hasTagName(name)) {
                            self.reportError(.invalid_first_character_of_tag_name);
                        }
                    }
                    self.popUntilTagName(name);
                    self.clearActiveFormattingToMarker();
                    self.insertion_mode = .in_row;
                } else if (std.mem.eql(u8, name, "body") or
                    std.mem.eql(u8, name, "caption") or
                    std.mem.eql(u8, name, "col") or
                    std.mem.eql(u8, name, "colgroup") or
                    std.mem.eql(u8, name, "html"))
                {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                } else if (std.mem.eql(u8, name, "table") or
                    std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "thead") or
                    std.mem.eql(u8, name, "tr"))
                {
                    if (!self.hasElementInTableScope(name)) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    try self.closeCell();
                    try self.processToken(token);
                } else {
                    try self.handleInBodyMode(token);
                }
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "caption") or
                    std.mem.eql(u8, name, "col") or
                    std.mem.eql(u8, name, "colgroup") or
                    std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "td") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "th") or
                    std.mem.eql(u8, name, "thead") or
                    std.mem.eql(u8, name, "tr"))
                {
                    // Assert: has td or th in table scope
                    try self.closeCell();
                    try self.processToken(token);
                } else {
                    try self.handleInBodyMode(token);
                }
            },
            else => {
                try self.handleInBodyMode(token);
            },
        }
    }

    /// Handle token in "in select" insertion mode.
    /// HTML Standard §13.2.6.4.16 (not in main parsing.md, simplified)
    fn handleInSelectMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                if (char == 0) {
                    self.reportError(.unexpected_null_character);
                } else {
                    try self.insertCharacter(char);
                }
            },
            .comment => |comment| {
                try self.insertComment(comment);
            },
            .doctype => {
                self.reportError(.missing_doctype_name);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    try self.handleInBodyMode(token);
                } else if (std.mem.eql(u8, name, "option")) {
                    if (self.currentNode()) |current| {
                        if (current.hasTagName("option")) {
                            _ = self.popCurrentNode();
                        }
                    }
                    _ = try self.insertHtmlElement(tag);
                } else if (std.mem.eql(u8, name, "optgroup")) {
                    if (self.currentNode()) |current| {
                        if (current.hasTagName("option")) {
                            _ = self.popCurrentNode();
                        }
                    }
                    if (self.currentNode()) |current| {
                        if (current.hasTagName("optgroup")) {
                            _ = self.popCurrentNode();
                        }
                    }
                    _ = try self.insertHtmlElement(tag);
                } else if (std.mem.eql(u8, name, "hr")) {
                    if (self.currentNode()) |current| {
                        if (current.hasTagName("option")) {
                            _ = self.popCurrentNode();
                        }
                    }
                    if (self.currentNode()) |current| {
                        if (current.hasTagName("optgroup")) {
                            _ = self.popCurrentNode();
                        }
                    }
                    _ = try self.insertHtmlElement(tag);
                    _ = self.popCurrentNode();
                } else if (std.mem.eql(u8, name, "select")) {
                    self.reportError(.invalid_first_character_of_tag_name);
                    if (!self.hasElementInSelectScope("select")) {
                        return;
                    }
                    self.popUntilTagName("select");
                    self.resetInsertionModeAppropriately();
                } else if (std.mem.eql(u8, name, "input") or
                    std.mem.eql(u8, name, "keygen") or
                    std.mem.eql(u8, name, "textarea"))
                {
                    self.reportError(.invalid_first_character_of_tag_name);
                    if (!self.hasElementInSelectScope("select")) {
                        return;
                    }
                    self.popUntilTagName("select");
                    self.resetInsertionModeAppropriately();
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "script") or std.mem.eql(u8, name, "template")) {
                    try self.handleInHeadMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "optgroup")) {
                    // Pop optgroup handling
                    if (self.currentNode()) |current| {
                        if (current.hasTagName("option")) {
                            if (self.open_elements.len > 1) {
                                const prev = self.open_elements.get(self.open_elements.len - 2);
                                if (prev) |p| {
                                    if (p.hasTagName("optgroup")) {
                                        _ = self.popCurrentNode();
                                    }
                                }
                            }
                        }
                    }
                    if (self.currentNode()) |current| {
                        if (current.hasTagName("optgroup")) {
                            _ = self.popCurrentNode();
                        } else {
                            self.reportError(.invalid_first_character_of_tag_name);
                        }
                    }
                } else if (std.mem.eql(u8, name, "option")) {
                    if (self.currentNode()) |current| {
                        if (current.hasTagName("option")) {
                            _ = self.popCurrentNode();
                        } else {
                            self.reportError(.invalid_first_character_of_tag_name);
                        }
                    }
                } else if (std.mem.eql(u8, name, "select")) {
                    if (!self.hasElementInSelectScope("select")) {
                        self.reportError(.invalid_first_character_of_tag_name);
                        return;
                    }
                    self.popUntilTagName("select");
                    self.resetInsertionModeAppropriately();
                } else if (std.mem.eql(u8, name, "template")) {
                    try self.handleInHeadMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                }
            },
            .eof => {
                try self.handleInBodyMode(token);
            },
            .text_run => |text_run| {
                // Insert text run in select element
                try self.insertTextRun(text_run.data);
            },
        }
    }

    /// Handle token in "in select in table" insertion mode.
    fn handleInSelectInTableMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "caption") or
                    std.mem.eql(u8, name, "table") or
                    std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "thead") or
                    std.mem.eql(u8, name, "tr") or
                    std.mem.eql(u8, name, "td") or
                    std.mem.eql(u8, name, "th"))
                {
                    self.reportError(.invalid_first_character_of_tag_name);
                    self.popUntilTagName("select");
                    self.resetInsertionModeAppropriately();
                    try self.processToken(token);
                } else {
                    try self.handleInSelectMode(token);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "caption") or
                    std.mem.eql(u8, name, "table") or
                    std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "thead") or
                    std.mem.eql(u8, name, "tr") or
                    std.mem.eql(u8, name, "td") or
                    std.mem.eql(u8, name, "th"))
                {
                    self.reportError(.invalid_first_character_of_tag_name);
                    if (!self.hasElementInTableScope(name)) {
                        return;
                    }
                    self.popUntilTagName("select");
                    self.resetInsertionModeAppropriately();
                    try self.processToken(token);
                } else {
                    try self.handleInSelectMode(token);
                }
            },
            else => {
                try self.handleInSelectMode(token);
            },
        }
    }

    /// Handle token in "in template" insertion mode.
    /// HTML Standard §13.2.6.4.16
    fn handleInTemplateMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character, .comment, .doctype, .text_run => {
                try self.handleInBodyMode(token);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "base") or
                    std.mem.eql(u8, name, "basefont") or
                    std.mem.eql(u8, name, "bgsound") or
                    std.mem.eql(u8, name, "link") or
                    std.mem.eql(u8, name, "meta") or
                    std.mem.eql(u8, name, "noframes") or
                    std.mem.eql(u8, name, "script") or
                    std.mem.eql(u8, name, "style") or
                    std.mem.eql(u8, name, "template") or
                    std.mem.eql(u8, name, "title"))
                {
                    try self.handleInHeadMode(token);
                } else if (std.mem.eql(u8, name, "caption") or
                    std.mem.eql(u8, name, "colgroup") or
                    std.mem.eql(u8, name, "tbody") or
                    std.mem.eql(u8, name, "tfoot") or
                    std.mem.eql(u8, name, "thead"))
                {
                    self.popTemplateInsertionMode();
                    try self.template_insertion_modes.append(.in_table);
                    self.insertion_mode = .in_table;
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "col")) {
                    self.popTemplateInsertionMode();
                    try self.template_insertion_modes.append(.in_column_group);
                    self.insertion_mode = .in_column_group;
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "tr")) {
                    self.popTemplateInsertionMode();
                    try self.template_insertion_modes.append(.in_table_body);
                    self.insertion_mode = .in_table_body;
                    try self.processToken(token);
                } else if (std.mem.eql(u8, name, "td") or std.mem.eql(u8, name, "th")) {
                    self.popTemplateInsertionMode();
                    try self.template_insertion_modes.append(.in_row);
                    self.insertion_mode = .in_row;
                    try self.processToken(token);
                } else {
                    // Any other start tag
                    self.popTemplateInsertionMode();
                    try self.template_insertion_modes.append(.in_body);
                    self.insertion_mode = .in_body;
                    try self.processToken(token);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "template")) {
                    try self.handleInHeadMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                }
            },
            .eof => {
                if (!self.hasTemplateInStack()) {
                    // Stop parsing
                    return;
                }
                self.reportError(.eof_in_tag);
                self.popUntilTagName("template");
                self.clearActiveFormattingToMarker();
                if (self.template_insertion_modes.len > 0) {
                    _ = self.template_insertion_modes.remove(self.template_insertion_modes.len - 1) catch {};
                }
                self.resetInsertionModeAppropriately();
                try self.processToken(token);
            },
        }
    }

    fn handleAfterBodyMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                if (isHtmlWhitespace(char)) {
                    try self.handleInBodyMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    self.insertion_mode = .in_body;
                    try self.processToken(token);
                }
            },
            .comment => |comment| {
                // Insert as last child of html element
                const html = self.open_elements.get(0);
                if (html) |h| try self.insertCommentIn(h, comment);
            },
            .doctype => {
                self.reportError(.missing_doctype_name);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    try self.handleInBodyMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    self.insertion_mode = .in_body;
                    try self.processToken(token);
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    self.insertion_mode = .after_after_body;
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    self.insertion_mode = .in_body;
                    try self.processToken(token);
                }
            },
            .eof => {
                // Stop parsing
            },
            .text_run => {
                // Text runs contain non-whitespace text
                self.reportError(.invalid_first_character_of_tag_name);
                self.insertion_mode = .in_body;
                try self.processToken(token);
            },
        }
    }

    /// Handle token in "in frameset" insertion mode.
    /// HTML Standard §13.2.6.4.18
    fn handleInFramesetMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                if (isHtmlWhitespace(char)) {
                    try self.insertCharacter(char);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                }
            },
            .comment => |comment| {
                try self.insertComment(comment);
            },
            .doctype => {
                self.reportError(.missing_doctype_name);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    try self.handleInBodyMode(token);
                } else if (std.mem.eql(u8, name, "frameset")) {
                    _ = try self.insertHtmlElement(tag);
                } else if (std.mem.eql(u8, name, "frame")) {
                    _ = try self.insertHtmlElement(tag);
                    _ = self.popCurrentNode();
                } else if (std.mem.eql(u8, name, "noframes")) {
                    try self.handleInHeadMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "frameset")) {
                    // Check if root html element
                    if (self.currentNode()) |current| {
                        if (current.hasTagName("html")) {
                            self.reportError(.invalid_first_character_of_tag_name);
                            return;
                        }
                    }
                    _ = self.popCurrentNode();
                    // If not root and not frameset, switch mode
                    if (self.currentNode()) |current| {
                        if (!current.hasTagName("frameset")) {
                            self.insertion_mode = .after_frameset;
                        }
                    }
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                }
            },
            .eof => {
                if (self.currentNode()) |current| {
                    if (!current.hasTagName("html")) {
                        self.reportError(.eof_in_tag);
                    }
                }
                // Stop parsing
            },
            .text_run => |text_run| try self.processRunPerCharacter(text_run.data, handleInFramesetMode),
        }
    }

    /// Handle token in "after frameset" insertion mode.
    /// HTML Standard §13.2.6.4.19
    fn handleAfterFramesetMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .character => |char| {
                if (isHtmlWhitespace(char)) {
                    try self.insertCharacter(char);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                }
            },
            .comment => |comment| {
                try self.insertComment(comment);
            },
            .doctype => {
                self.reportError(.missing_doctype_name);
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    try self.handleInBodyMode(token);
                } else if (std.mem.eql(u8, name, "noframes")) {
                    try self.handleInHeadMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                }
            },
            .end_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    self.insertion_mode = .after_after_frameset;
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                }
            },
            .eof => {
                // Stop parsing
            },
            .text_run => |text_run| try self.processRunPerCharacter(text_run.data, handleAfterFramesetMode),
        }
    }

    fn handleAfterAfterBodyMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .comment => |comment| {
                try self.insertCommentIn(self.document, comment);
            },
            .doctype, .eof => {},
            .character => |char| {
                if (isHtmlWhitespace(char)) {
                    try self.handleInBodyMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    self.insertion_mode = .in_body;
                    try self.processToken(token);
                }
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    try self.handleInBodyMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    self.insertion_mode = .in_body;
                    try self.processToken(token);
                }
            },
            .end_tag => {
                self.reportError(.invalid_first_character_of_tag_name);
                self.insertion_mode = .in_body;
                try self.processToken(token);
            },
            .text_run => {
                // Text runs contain non-whitespace text
                self.reportError(.invalid_first_character_of_tag_name);
                self.insertion_mode = .in_body;
                try self.processToken(token);
            },
        }
    }

    /// Handle token in "after after frameset" insertion mode.
    /// HTML Standard §13.2.6.4.21
    fn handleAfterAfterFramesetMode(self: *TreeBuilder, token: Token) Allocator.Error!void {
        switch (token) {
            .comment => |comment| {
                try self.insertCommentIn(self.document, comment);
            },
            .doctype => {
                try self.handleInBodyMode(token);
            },
            .character => |char| {
                if (isHtmlWhitespace(char)) {
                    try self.handleInBodyMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                }
            },
            .start_tag => |tag| {
                const name = tag.getTagName();
                if (std.mem.eql(u8, name, "html")) {
                    try self.handleInBodyMode(token);
                } else if (std.mem.eql(u8, name, "noframes")) {
                    try self.handleInHeadMode(token);
                } else {
                    self.reportError(.invalid_first_character_of_tag_name);
                    // Ignore
                }
            },
            .end_tag => {
                self.reportError(.invalid_first_character_of_tag_name);
                // Ignore
            },
            .eof => {
                // Stop parsing
            },
            .text_run => |text_run| try self.processRunPerCharacter(text_run.data, handleAfterAfterFramesetMode),
        }
    }

    /// A text run in a mode that stays put on "anything else" - "in
    /// frameset", "after frameset", "after after frameset" ignore it - while
    /// inserting whitespace: the run's characters one token each, so the
    /// whitespace after its first character is inserted and the rest ignored.
    /// (Text runs are ASCII, so each byte is a code point.)
    fn processRunPerCharacter(
        self: *TreeBuilder,
        data: []const u8,
        comptime handler: fn (*TreeBuilder, Token) Allocator.Error!void,
    ) Allocator.Error!void {
        for (data) |byte| try handler(self, .{ .character = byte });
    }

    // =========================================================================
    // Helper Functions
    // =========================================================================

    /// Create element for token.
    fn createElementForToken(self: *TreeBuilder, tag: TagToken, namespace: Namespace, intended: InsertionLocation) !*TreeNode {
        const name = tag.getTagName();
        const element = try TreeNode.initElement(self.allocator, name, namespace);
        errdefer element.deinit();
        element.creation_location = intended;

        // Copy attributes
        const attrs = tag.attributes.toSlice();
        for (attrs) |attr| {
            try element.addAttribute(attr.getName(), attr.getValue(), null);
        }
        self.keepDetached(element);

        // Notify DOM adapter of element creation (for incremental DOM conversion)
        self.flushPendingText();
        if (self.dom_adapter_on_node_created) |callback| {
            callback(element, self.dom_adapter_context);
        }

        return element;
    }

    /// Insert HTML element for token.
    fn insertHtmlElement(self: *TreeBuilder, tag: TagToken) !*TreeNode {
        const element = try self.createElementForToken(tag, .html, self.appropriateLocation(null));
        self.insertAtAppropriatePlace(element);
        try self.open_elements.append(element);
        return element;
    }

    /// Insert at the appropriate place.
    fn insertAtAppropriatePlace(self: *TreeBuilder, node: *TreeNode) void {
        const location = self.appropriateLocation(null);
        self.insertNodeAt(location, node);
    }

    pub const InsertionLocation = struct {
        parent: *TreeNode,
        before: ?*TreeNode = null,
        foster_table: ?*TreeNode = null,
        foster_fallback: ?*TreeNode = null,
        move: bool = false,
    };

    /// HTML appropriate place for inserting a node, steps 1–3. The TreeNode
    /// models template contents as children; the DOM adapter resolves step 6.
    fn appropriateLocation(self: *TreeBuilder, override: ?*TreeNode) InsertionLocation {
        const target = override orelse self.currentNode() orelse self.document;
        if (self.foster_parenting and target.namespace == .html and
            (target.hasTagName("table") or target.hasTagName("tbody") or target.hasTagName("tfoot") or
                target.hasTagName("thead") or target.hasTagName("tr")))
        {
            var i = self.open_elements.len;
            while (i > 0) {
                i -= 1;
                const node = self.open_elements.get(i).?;
                if (node.namespace != .html) continue;
                if (node.hasTagName("template")) return .{ .parent = node };
                if (node.hasTagName("table")) {
                    const fallback = self.open_elements.get(i - 1).?;
                    return .{
                        .parent = node.parent orelse fallback,
                        .before = if (node.parent != null) node else null,
                        .foster_table = node,
                        .foster_fallback = fallback,
                    };
                }
            }
            return .{ .parent = self.open_elements.get(0) orelse self.document };
        }
        return .{ .parent = target };
    }

    fn keepDetached(self: *TreeBuilder, node: *TreeNode) void {
        var current = self.detached_nodes;
        while (current) |entry| : (current = entry.detached_next) if (entry == node) return;
        node.detached_next = self.detached_nodes;
        self.detached_nodes = node;
    }

    fn releaseDetached(self: *TreeBuilder, node: *TreeNode) void {
        var slot = &self.detached_nodes;
        while (slot.*) |entry| {
            if (entry == node) {
                slot.* = entry.detached_next;
                entry.detached_next = null;
                return;
            }
            slot = &entry.detached_next;
        }
    }

    fn insertNode(self: *TreeBuilder, parent: *TreeNode, node: *TreeNode, before: ?*TreeNode) void {
        self.insertNodeAt(.{ .parent = parent, .before = before, .move = true }, node);
    }

    fn insertNodeAt(self: *TreeBuilder, location: InsertionLocation, node: *TreeNode) void {
        self.flushPendingText();
        const parent = location.parent;
        const before = location.before;
        node.remove();
        var ancestor: ?*TreeNode = parent;
        while (ancestor) |value| : (ancestor = value.parent) {
            if (value == node) {
                self.keepDetached(node);
                return;
            }
        }
        if (before) |reference| if (reference.parent != parent) {
            self.keepDetached(node);
            return;
        };
        parent.insertBefore(node, before);
        self.releaseDetached(node);
        if (self.dom_adapter_on_inserted) |callback| {
            callback(location, node, self.dom_adapter_context);
        } else if (self.dom_adapter_on_child_appended) |callback| {
            callback(parent, node, self.dom_adapter_context);
        }
    }

    /// Insert a character.
    fn insertCharacter(self: *TreeBuilder, char: u21) !void {
        var bytes: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(char, &bytes) catch unreachable;
        try self.insertTextRun(bytes[0..len]);
    }

    /// Insert a text run (batch of characters).
    /// Performance optimization: appends entire slice at once, avoiding per-character overhead.
    fn insertTextRun(self: *TreeBuilder, data: []const u8) !void {
        if (data.len == 0) return;

        // Insert a character, steps 2–4: coalesce immediately BEFORE the
        // adjusted insertion location, including foster-parented text.
        const location = self.appropriateLocation(null);
        if (location.parent.node_type == .document) return;
        const previous = if (location.before) |reference| reference.prev_sibling else location.parent.last_child;
        if (previous) |last| {
            if (last.node_type == .text) {
                // Append entire slice at once (much faster than per-character)
                try last.text_content.appendSlice(data);
                self.markTextPending(last);
                return;
            }
        }

        // Create new text node with entire content at once
        const text = try TreeNode.initText(self.allocator);
        errdefer text.deinit();
        try text.text_content.appendSlice(data);

        // Notify DOM adapter of new text node creation and parent-child relationship
        self.flushPendingText();
        if (self.dom_adapter_on_node_created) |callback| {
            callback(text, self.dom_adapter_context);
        }
        self.insertNodeAt(location, text);
    }

    /// Note that `node`'s text has grown without telling the DOM adapter.
    ///
    /// The adapter mirrors a notification into the DOM with
    /// `CharacterData.set_data`, which copies the whole string, so notifying
    /// per character made a run of N characters cost O(N^2) - 30 seconds of CPU
    /// for a frame with two 100,000-character runs. Blink's
    /// HTMLConstructionSite buffers the same way (`pending_text_`, flushed by
    /// `FlushPendingText`): the adapter hears once per run.
    fn markTextPending(self: *TreeBuilder, node: *TreeNode) void {
        if (self.pending_text) |pending| {
            if (pending == node) return;
            self.flushPendingText();
        }
        self.pending_text = node;
    }

    /// Tell the DOM adapter about the pending text node, if any. Runs before
    /// every other adapter notification and before a script runs - so nothing
    /// script can observe, neither a script nor a node created after the text,
    /// sees a run cut short - and when parsing stops.
    fn flushPendingText(self: *TreeBuilder) void {
        const node = self.pending_text orelse return;
        self.pending_text = null;
        if (self.dom_adapter_on_text_content_changed) |callback| {
            callback(node, self.dom_adapter_context);
        }
    }

    /// Insert a comment.
    fn insertComment(self: *TreeBuilder, comment: CommentToken) !void {
        try self.insertCommentIn(self.currentNode() orelse self.document, comment);
    }

    /// "Insert a comment" as the last child of `parent` - the document, the
    /// html element, or the current node - telling the DOM adapter, which
    /// otherwise never hears of a comment outside the html element.
    fn insertCommentIn(self: *TreeBuilder, parent: *TreeNode, comment: CommentToken) !void {
        const node = try TreeNode.initComment(self.allocator);
        try node.appendText(comment.getData());
        parent.appendChild(node);

        // Notify DOM adapter of comment creation and parent-child relationship
        self.flushPendingText();
        if (self.dom_adapter_on_node_created) |callback| {
            callback(node, self.dom_adapter_context);
        }
        self.flushPendingText();
        if (self.dom_adapter_on_child_appended) |callback| {
            callback(parent, node, self.dom_adapter_context);
        }
    }

    /// Generic raw text element parsing algorithm.
    fn parseGenericRawText(self: *TreeBuilder, tag: TagToken) !void {
        _ = try self.insertHtmlElement(tag);
        self.tokenizer.state = .rawtext;
        self.original_insertion_mode = self.insertion_mode;
        self.insertion_mode = .text;
    }

    /// Generic RCDATA element parsing algorithm.
    fn parseGenericRCDATA(self: *TreeBuilder, tag: TagToken) !void {
        _ = try self.insertHtmlElement(tag);
        self.tokenizer.state = .rcdata;
        self.original_insertion_mode = self.insertion_mode;
        self.insertion_mode = .text;
    }

    /// Generate implied end tags.
    fn generateImpliedEndTags(self: *TreeBuilder, exclude: ?[]const u8) void {
        const implied_tags = [_][]const u8{ "dd", "dt", "li", "optgroup", "option", "p", "rb", "rp", "rt", "rtc" };
        while (self.currentNode()) |current| {
            var should_pop = false;
            if (current.local_name) |name| {
                for (implied_tags) |implied| {
                    if (std.mem.eql(u8, name, implied)) {
                        if (exclude) |exc| {
                            if (!std.mem.eql(u8, name, exc)) {
                                should_pop = true;
                            }
                        } else {
                            should_pop = true;
                        }
                        break;
                    }
                }
            }
            if (should_pop) {
                if (self.popCurrentNode() == null) break;
            } else {
                break;
            }
        }
    }

    /// Generate all implied end tags thoroughly.
    fn generateAllImpliedEndTagsThoroughly(self: *TreeBuilder) !void {
        const implied_tags = [_][]const u8{
            "caption", "colgroup", "dd",    "dt", "li",  "optgroup", "option",
            "p",       "rb",       "rp",    "rt", "rtc", "tbody",    "td",
            "tfoot",   "th",       "thead", "tr",
        };
        while (self.currentNode()) |current| {
            var should_pop = false;
            if (current.local_name) |name| {
                for (implied_tags) |implied| {
                    if (std.mem.eql(u8, name, implied)) {
                        should_pop = true;
                        break;
                    }
                }
            }
            if (should_pop) {
                if (self.popCurrentNode() == null) break;
            } else {
                break;
            }
        }
    }

    // === Scope Boundary Helper Functions ===
    // These use compile-time string matching for faster scope checking.

    /// Check if element name is a general scope boundary.
    /// Scope boundary elements: applet, caption, html, table, td, th, marquee, object, select, template
    fn isGeneralScopeBoundary(name: []const u8) bool {
        // Use length-based dispatch for faster rejection of non-matching strings
        return switch (name.len) {
            2 => std.mem.eql(u8, name, "td") or std.mem.eql(u8, name, "th"),
            4 => std.mem.eql(u8, name, "html"),
            5 => std.mem.eql(u8, name, "table"),
            6 => std.mem.eql(u8, name, "applet") or std.mem.eql(u8, name, "object") or std.mem.eql(u8, name, "select"),
            7 => std.mem.eql(u8, name, "caption") or std.mem.eql(u8, name, "marquee"),
            8 => std.mem.eql(u8, name, "template"),
            else => false,
        };
    }

    /// Check if element name is a button scope boundary.
    fn isButtonScopeBoundary(name: []const u8) bool {
        return isGeneralScopeBoundary(name) or (name.len == 6 and std.mem.eql(u8, name, "button"));
    }

    /// Check if element name is a table scope boundary.
    fn isTableScopeBoundary(name: []const u8) bool {
        return switch (name.len) {
            4 => std.mem.eql(u8, name, "html"),
            5 => std.mem.eql(u8, name, "table"),
            8 => std.mem.eql(u8, name, "template"),
            else => false,
        };
    }

    /// Check if element is transparent in select scope (not a boundary).
    fn isSelectScopeTransparent(name: []const u8) bool {
        return (name.len == 8 and std.mem.eql(u8, name, "optgroup")) or
            (name.len == 6 and std.mem.eql(u8, name, "option"));
    }

    /// Check if element is in scope.
    /// Optimized with length-based scope boundary checks.
    fn hasElementInScope(self: *TreeBuilder, tag_name: []const u8) bool {
        var i = self.open_elements.len;
        while (i > 0) {
            i -= 1;
            const node = self.open_elements.get(i) orelse continue;
            if (node.namespace == .html and node.hasTagName(tag_name)) return true;
            if (isScopeBoundary(node)) return false;
        }
        return false;
    }

    /// Scope tests naming a node (form/adoption agency) compare identity.
    fn hasNodeInScope(self: *TreeBuilder, target: *TreeNode) bool {
        var i = self.open_elements.len;
        while (i > 0) {
            i -= 1;
            const node = self.open_elements.get(i) orelse continue;
            if (node == target) return true;
            if (isScopeBoundary(node)) return false;
        }
        return false;
    }

    /// Close p element if in button scope.
    fn closePElementIfInButtonScope(self: *TreeBuilder) !void {
        if (self.hasElementInButtonScope("p")) {
            self.generateImpliedEndTags("p");
            self.popUntilTagName("p");
        }
    }

    /// Check if element is in button scope.
    /// Optimized with length-based scope boundary checks.
    fn hasElementInButtonScope(self: *TreeBuilder, tag_name: []const u8) bool {
        var i = self.open_elements.len;
        while (i > 0) {
            i -= 1;
            const node = self.open_elements.get(i) orelse continue;
            if (node.namespace == .html and node.hasTagName(tag_name)) return true;
            if (isScopeBoundary(node) or (node.namespace == .html and node.hasTagName("button"))) return false;
        }
        return false;
    }

    /// Pop elements until tag name.
    fn popUntilTagName(self: *TreeBuilder, tag_name: []const u8) void {
        while (self.open_elements.len > 0) {
            const node = self.popCurrentNode() orelse break;
            if (node.hasTagName(tag_name)) break;
        }
    }

    /// Copy the complete creation token. Reconstructed elements must retain
    /// attributes even after script changes the original DOM element.
    fn copyFormattingToken(self: *TreeBuilder, tag: TagToken) !TagToken {
        var copy = TagToken.init(self.allocator, false);
        errdefer copy.deinit();
        for (tag.getTagName()) |byte| try copy.appendToTagName(byte);
        for (tag.attributes.toSlice()) |attribute| {
            try copy.startNewAttribute();
            for (attribute.getName()) |byte| try copy.appendToAttributeName(byte);
            for (attribute.getValue()) |byte| try copy.appendToAttributeValue(byte);
        }
        try copy.finishCurrentAttribute();
        return copy;
    }

    fn sameFormattingToken(a: TagToken, b: TagToken) bool {
        if (!std.mem.eql(u8, a.getTagName(), b.getTagName()) or a.attributes.len != b.attributes.len) return false;
        for (a.attributes.toSlice()) |left| {
            for (b.attributes.toSlice()) |right| {
                if (std.mem.eql(u8, left.getName(), right.getName()) and
                    std.mem.eql(u8, left.getValue(), right.getValue())) break;
            } else return false;
        }
        return true;
    }

    fn removeFormattingAt(self: *TreeBuilder, index: usize) void {
        var entry = self.active_formatting_elements.remove(index) catch unreachable;
        if (entry == .element) entry.element.token.deinit();
    }

    fn formattingIndex(self: *TreeBuilder, node: *TreeNode) ?usize {
        for (self.active_formatting_elements.toSlice(), 0..) |entry, index| {
            if (entry == .element and entry.element.node == node) return index;
        }
        return null;
    }

    fn openIndex(self: *TreeBuilder, node: *TreeNode) ?usize {
        for (self.open_elements.toSlice(), 0..) |open, index| {
            if (open == node) return index;
        }
        return null;
    }

    /// HTML 13.2.4.3, push steps 1–2 (Noah's Ark).
    fn pushOntoActiveFormattingElements(self: *TreeBuilder, element: *TreeNode, tag: TagToken) !void {
        var count: usize = 0;
        var earliest: ?usize = null;
        var i = self.active_formatting_elements.len;
        while (i > 0) {
            i -= 1;
            const entry = self.active_formatting_elements.get(i).?;
            if (entry == .marker) break;
            if (entry.element.node.namespace == element.namespace and sameFormattingToken(entry.element.token, tag)) {
                count += 1;
                earliest = i;
            }
        }
        var copy = try self.copyFormattingToken(tag);
        errdefer copy.deinit();
        if (count >= 3) self.removeFormattingAt(earliest.?);
        try self.active_formatting_elements.append(.{ .element = .{ .node = element, .token = copy } });
    }

    /// HTML 13.2.4.3, clear steps 1–4.
    fn clearActiveFormattingToMarker(self: *TreeBuilder) void {
        while (self.active_formatting_elements.len > 0) {
            const index = self.active_formatting_elements.len - 1;
            const marker = self.active_formatting_elements.get(index).? == .marker;
            self.removeFormattingAt(index);
            if (marker) break;
        }
    }

    /// HTML 13.2.4.3, reconstruction steps 1–10.
    fn reconstructActiveFormattingElements(self: *TreeBuilder) !void {
        if (self.active_formatting_elements.len == 0) return;
        var index = self.active_formatting_elements.len;
        // Rewind through unopened entries. A marker or an open node is the
        // boundary; the first unopened entry is included, even at index zero.
        while (index > 0) {
            const previous = self.active_formatting_elements.get(index - 1).?;
            if (previous == .marker or self.openIndex(previous.element.node) != null) break;
            index -= 1;
        }
        while (index < self.active_formatting_elements.len) : (index += 1) {
            const token = self.active_formatting_elements.get(index).?.element.token;
            const element = try self.insertHtmlElement(token);
            self.active_formatting_elements.toSliceMut()[index].element.node = element;
        }
    }

    /// HTML 13.2.6.4.7, adoption agency. Model the two independent structures:
    /// the DOM tree and the open/formatting lists (WebKit HTMLTreeBuilder's
    /// callTheAdoptionAgency also replaces entries rather than moving them).
    fn adoptionAgencyAlgorithm(self: *TreeBuilder, subject: []const u8) !void {
        // Steps 1–2.
        if (self.currentNode()) |current| {
            if (current.namespace == .html and current.hasTagName(subject) and self.formattingIndex(current) == null) {
                _ = self.popCurrentNode();
                return;
            }
        }
        // Steps 3–4.2.
        var outer: usize = 0;
        while (outer < 8) : (outer += 1) {
            // Step 4.3.
            var formatting_index: ?usize = null;
            var search = self.active_formatting_elements.len;
            while (search > 0) {
                search -= 1;
                const entry = self.active_formatting_elements.get(search).?;
                if (entry == .marker) break;
                if (entry.element.node.hasTagName(subject)) {
                    formatting_index = search;
                    break;
                }
            }
            const initial_index = formatting_index orelse {
                try self.handleAnyOtherEndTag(subject);
                return;
            };
            const formatting = self.active_formatting_elements.get(initial_index).?.element.node;
            // Steps 4.4–4.6.
            const stack_index = self.openIndex(formatting) orelse {
                self.reportError(.invalid_first_character_of_tag_name);
                self.removeFormattingAt(initial_index);
                return;
            };
            if (!self.hasNodeInScope(formatting)) {
                self.reportError(.invalid_first_character_of_tag_name);
                return;
            }
            if (self.currentNode() != formatting) self.reportError(.invalid_first_character_of_tag_name);
            // Steps 4.7–4.8.
            var block_index: ?usize = null;
            var index = stack_index + 1;
            while (index < self.open_elements.len) : (index += 1) {
                if (self.isSpecialElement(self.open_elements.get(index).?)) {
                    block_index = index;
                    break;
                }
            }
            const furthest_index = block_index orelse {
                while (self.open_elements.len > stack_index) _ = self.popCurrentNode();
                self.removeFormattingAt(initial_index);
                return;
            };
            const furthest = self.open_elements.get(furthest_index).?;
            const ancestor = self.open_elements.get(stack_index - 1).?;
            var bookmark = initial_index;
            var node_index = furthest_index;
            var last = furthest;
            var inner: usize = 0;
            // Steps 4.9–4.13.
            while (true) {
                inner += 1;
                node_index -= 1;
                const node = self.open_elements.get(node_index).?;
                if (node == formatting) break;
                var active = self.formattingIndex(node);
                if (inner > 3) {
                    if (active) |position| {
                        self.removeFormattingAt(position);
                        if (position < bookmark) bookmark -= 1;
                        active = null;
                    }
                }
                const active_index = active orelse {
                    _ = self.removeOpenElementAt(node_index);
                    continue;
                };
                const token = self.active_formatting_elements.get(active_index).?.element.token;
                const replacement = try self.createElementForToken(token, .html, .{ .parent = ancestor });
                self.active_formatting_elements.toSliceMut()[active_index].element.node = replacement;
                self.open_elements.toSliceMut()[node_index] = replacement;
                if (last == furthest) bookmark = active_index + 1;
                self.insertNode(replacement, last, null);
                last = replacement;
            }
            // Steps 4.14–4.16. The adapter repeats the validity checks against
            // the live DOM, which script can have changed since tokenization.
            var location = self.appropriateLocation(ancestor);
            location.move = true;
            self.insertNodeAt(location, last);
            // Steps 4.17–4.19.
            const current_index = self.formattingIndex(formatting).?;
            const token = self.active_formatting_elements.get(current_index).?.element.token;
            const replacement = try self.createElementForToken(token, .html, .{ .parent = furthest });
            self.flushPendingText();
            if (self.dom_adapter_on_children_moved) |callback| {
                // Step 4.18 acts on ALL live children, including script's.
                callback(furthest, replacement, self.dom_adapter_context);
                while (furthest.first_child) |child| replacement.appendChild(child);
            } else {
                while (furthest.first_child) |child| self.insertNode(replacement, child, null);
            }
            self.insertNode(furthest, replacement, null);
            // Step 4.20: transfer token ownership without copying or freeing it.
            const entry = self.active_formatting_elements.remove(current_index) catch unreachable;
            if (current_index < bookmark) bookmark -= 1;
            // Removal leaves enough capacity for this insertion.
            self.active_formatting_elements.insert(bookmark, .{ .element = .{ .node = replacement, .token = entry.element.token } }) catch unreachable;
            // Step 4.21.
            _ = self.removeOpenElementAt(self.openIndex(formatting).?);
            self.open_elements.insert(self.openIndex(furthest).? + 1, replacement) catch unreachable;
        }
    }

    /// Reset insertion mode appropriately.
    pub fn resetInsertionModeAppropriately(self: *TreeBuilder) void {
        var last = false;
        var i = self.open_elements.len;
        while (i > 0) {
            i -= 1;
            var node = self.open_elements.get(i) orelse continue;

            if (i == 0) {
                last = true;
                // Reset insertion mode, step 3: substitute the fragment's
                // context at the root, including after a nested template ends.
                if (self.fragment_context) |context| node = context;
            }

            // Each named element in steps 4–14 is in the HTML namespace.
            if (node.namespace != .html) {
                if (last) {
                    self.insertion_mode = .in_body;
                    return;
                }
                continue;
            }

            if (node.hasTagName("select")) {
                self.insertion_mode = .in_select;
                return;
            }
            if (node.hasTagName("td") or node.hasTagName("th")) {
                if (!last) {
                    self.insertion_mode = .in_cell;
                    return;
                }
            }
            if (node.hasTagName("tr")) {
                self.insertion_mode = .in_row;
                return;
            }
            if (node.hasTagName("tbody") or node.hasTagName("thead") or node.hasTagName("tfoot")) {
                self.insertion_mode = .in_table_body;
                return;
            }
            if (node.hasTagName("caption")) {
                self.insertion_mode = .in_caption;
                return;
            }
            if (node.hasTagName("colgroup")) {
                self.insertion_mode = .in_column_group;
                return;
            }
            if (node.hasTagName("table")) {
                self.insertion_mode = .in_table;
                return;
            }
            if (node.hasTagName("template")) {
                if (self.template_insertion_modes.len > 0) {
                    self.insertion_mode = self.template_insertion_modes.get(self.template_insertion_modes.len - 1) orelse .in_template;
                }
                return;
            }
            if (node.hasTagName("head") and !last) {
                self.insertion_mode = .in_head;
                return;
            }
            if (node.hasTagName("body")) {
                self.insertion_mode = .in_body;
                return;
            }
            if (node.hasTagName("frameset")) {
                self.insertion_mode = .in_frameset;
                return;
            }
            if (node.hasTagName("html")) {
                if (self.head_element == null) {
                    self.insertion_mode = .before_head;
                } else {
                    self.insertion_mode = .after_head;
                }
                return;
            }

            if (last) {
                self.insertion_mode = .in_body;
                return;
            }
        }
    }

    /// Check if element is special.
    fn isSpecialElement(self: *TreeBuilder, node: *TreeNode) bool {
        _ = self;
        if (node.namespace != .html) return isForeignScopeBoundary(node);
        // HTML 13.2.4.2's special category is larger than block/void tags.
        const special = std.StaticStringMap(void).initComptime(.{
            .{ "address", {} },
            .{ "applet", {} },
            .{ "area", {} },
            .{ "article", {} },
            .{ "aside", {} },
            .{ "base", {} },
            .{ "basefont", {} },
            .{ "bgsound", {} },
            .{ "blockquote", {} },
            .{ "body", {} },
            .{ "br", {} },
            .{ "button", {} },
            .{ "caption", {} },
            .{ "center", {} },
            .{ "col", {} },
            .{ "colgroup", {} },
            .{ "dd", {} },
            .{ "details", {} },
            .{ "dir", {} },
            .{ "div", {} },
            .{ "dl", {} },
            .{ "dt", {} },
            .{ "embed", {} },
            .{ "fieldset", {} },
            .{ "figcaption", {} },
            .{ "figure", {} },
            .{ "footer", {} },
            .{ "form", {} },
            .{ "frame", {} },
            .{ "frameset", {} },
            .{ "h1", {} },
            .{ "h2", {} },
            .{ "h3", {} },
            .{ "h4", {} },
            .{ "h5", {} },
            .{ "h6", {} },
            .{ "head", {} },
            .{ "header", {} },
            .{ "hgroup", {} },
            .{ "hr", {} },
            .{ "html", {} },
            .{ "iframe", {} },
            .{ "img", {} },
            .{ "input", {} },
            .{ "keygen", {} },
            .{ "li", {} },
            .{ "link", {} },
            .{ "listing", {} },
            .{ "main", {} },
            .{ "marquee", {} },
            .{ "menu", {} },
            .{ "meta", {} },
            .{ "nav", {} },
            .{ "noembed", {} },
            .{ "noframes", {} },
            .{ "noscript", {} },
            .{ "object", {} },
            .{ "ol", {} },
            .{ "p", {} },
            .{ "param", {} },
            .{ "plaintext", {} },
            .{ "pre", {} },
            .{ "script", {} },
            .{ "search", {} },
            .{ "section", {} },
            .{ "select", {} },
            .{ "source", {} },
            .{ "style", {} },
            .{ "summary", {} },
            .{ "table", {} },
            .{ "tbody", {} },
            .{ "td", {} },
            .{ "template", {} },
            .{ "textarea", {} },
            .{ "tfoot", {} },
            .{ "th", {} },
            .{ "thead", {} },
            .{ "title", {} },
            .{ "tr", {} },
            .{ "track", {} },
            .{ "ul", {} },
            .{ "wbr", {} },
            .{ "xmp", {} },
        });
        return special.has(node.local_name orelse "");
    }

    fn isForeignScopeBoundary(node: *TreeNode) bool {
        return switch (node.namespace) {
            .html => false,
            .mathml => node.hasTagName("mi") or node.hasTagName("mo") or node.hasTagName("mn") or
                node.hasTagName("ms") or node.hasTagName("mtext") or node.hasTagName("annotation-xml"),
            .svg => node.hasTagName("foreignObject") or node.hasTagName("desc") or node.hasTagName("title"),
        };
    }

    fn isScopeBoundary(node: *TreeNode) bool {
        return if (node.namespace == .html) isGeneralScopeBoundary(node.local_name orelse "") else isForeignScopeBoundary(node);
    }

    /// Clear the stack back to a table context.
    /// HTML Standard: Pop until table, template, or html.
    fn clearStackBackToTableContext(self: *TreeBuilder) void {
        while (self.open_elements.len > 0) {
            const node = self.currentNode() orelse break;
            if (node.hasTagName("table") or node.hasTagName("template") or node.hasTagName("html")) {
                break;
            }
            if (self.popCurrentNode() == null) break;
        }
    }

    /// Clear the stack back to a table body context.
    /// HTML Standard: Pop until tbody, tfoot, thead, template, or html.
    fn clearStackBackToTableBodyContext(self: *TreeBuilder) void {
        while (self.open_elements.len > 0) {
            const node = self.currentNode() orelse break;
            if (node.hasTagName("tbody") or
                node.hasTagName("tfoot") or
                node.hasTagName("thead") or
                node.hasTagName("template") or
                node.hasTagName("html"))
            {
                break;
            }
            if (self.popCurrentNode() == null) break;
        }
    }

    /// Clear the stack back to a table row context.
    /// HTML Standard: Pop until tr, template, or html.
    fn clearStackBackToTableRowContext(self: *TreeBuilder) void {
        while (self.open_elements.len > 0) {
            const node = self.currentNode() orelse break;
            if (node.hasTagName("tr") or node.hasTagName("template") or node.hasTagName("html")) {
                break;
            }
            if (self.popCurrentNode() == null) break;
        }
    }

    /// Check if element is in table scope.
    /// Optimized with length-based scope boundary checks.
    fn hasElementInTableScope(self: *TreeBuilder, tag_name: []const u8) bool {
        var i = self.open_elements.len;
        while (i > 0) {
            i -= 1;
            const node = self.open_elements.get(i) orelse continue;
            if (node.hasTagName(tag_name)) return true;

            if (node.local_name) |name| {
                if (isTableScopeBoundary(name)) return false;
            }
        }
        return false;
    }

    /// Check if element is in select scope.
    /// Optimized with length-based scope boundary checks.
    fn hasElementInSelectScope(self: *TreeBuilder, tag_name: []const u8) bool {
        var i = self.open_elements.len;
        while (i > 0) {
            i -= 1;
            const node = self.open_elements.get(i) orelse continue;
            if (node.hasTagName(tag_name)) return true;

            // In select scope, only optgroup and option are transparent
            if (node.local_name) |name| {
                if (!isSelectScopeTransparent(name)) return false;
            }
        }
        return false;
    }

    /// Check if there is a tbody, thead, or tfoot in table scope.
    fn hasTableBodyElementInTableScope(self: *TreeBuilder) bool {
        return self.hasElementInTableScope("tbody") or
            self.hasElementInTableScope("thead") or
            self.hasElementInTableScope("tfoot");
    }

    /// Check if there's a template element in the stack.
    fn hasTemplateInStack(self: *TreeBuilder) bool {
        for (self.open_elements.toSlice()) |elem| {
            if (elem.namespace == .html and elem.hasTagName("template")) return true;
        }
        return false;
    }

    /// HTML "parsing template contents" includes a template fragment context.
    fn parsingTemplateContents(self: *TreeBuilder) bool {
        if (self.hasTemplateInStack()) return true;
        const context = self.fragment_context orelse return false;
        return context.namespace == .html and context.hasTagName("template");
    }

    /// Check if a tag token has type="hidden" attribute.
    fn hasTypeHiddenAttribute(self: *TreeBuilder, tag: TagToken) bool {
        _ = self;
        const attrs = tag.attributes.toSlice();
        for (attrs) |attr| {
            if (std.ascii.eqlIgnoreCase(attr.getName(), "type")) {
                return std.ascii.eqlIgnoreCase(attr.getValue(), "hidden");
            }
        }
        return false;
    }

    /// Close the cell algorithm.
    fn closeCell(self: *TreeBuilder) !void {
        self.generateImpliedEndTags(null);
        if (self.currentNode()) |current| {
            if (!current.hasTagName("td") and !current.hasTagName("th")) {
                self.reportError(.invalid_first_character_of_tag_name);
            }
        }
        // Pop until td or th
        while (self.open_elements.len > 0) {
            const node = self.popCurrentNode() orelse break;
            if (node.hasTagName("td") or node.hasTagName("th")) break;
        }
        self.clearActiveFormattingToMarker();
        self.insertion_mode = .in_row;
    }

    /// Copy attributes from a token to an element if they don't already exist.
    ///
    /// HTML Standard: For each attribute on the token, check if already present
    /// on the element. If not, add it.
    /// "For each attribute on the token, check to see if the attribute is
    /// already present on the [element]. If it is not, add the attribute and
    /// its corresponding value to that element." The element is in the DOM
    /// already, so the adapter hears each one it gains.
    fn copyMissingAttributes(self: *TreeBuilder, element: *TreeNode, tag: TagToken) !void {
        const token_attrs = tag.attributes.toSlice();
        for (token_attrs) |attr| {
            const attr_name = attr.getName();

            // Check if attribute already exists on element
            var exists = false;
            const elem_attrs = element.attributes.toSlice();
            for (elem_attrs) |existing| {
                if (std.mem.eql(u8, existing.name, attr_name)) {
                    exists = true;
                    break;
                }
            }

            // If not present, add it
            if (!exists) {
                try element.addAttribute(attr_name, attr.getValue(), null);
                if (self.dom_adapter_on_attribute_added) |callback| {
                    const attrs = element.attributes.toSlice();
                    callback(element, &attrs[attrs.len - 1], self.dom_adapter_context);
                }
            }
        }
    }
};

// =========================================================================
// Helper Functions
// =========================================================================

/// Check if character is HTML whitespace.
/// The document mode a DOCTYPE token sets in the "initial" insertion mode:
/// quirks if it matches the first list, limited-quirks if it matches the
/// second, no-quirks otherwise. Identifiers compare ASCII case-insensitively;
/// "A system identifier whose value is the empty string is not considered
/// missing." (The name is compared as the tokenizer left it, lowercased.)
///
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html#the-initial-insertion-mode
pub fn doctypeMode(name: ?[]const u8, public_id: ?[]const u8, system_id: ?[]const u8, force_quirks: bool) QuirksMode {
    if (force_quirks) return .quirks;
    const n = name orelse return .quirks;
    if (!std.mem.eql(u8, n, "html")) return .quirks;

    if (public_id) |pid| {
        for (quirks_public_ids) |exact| {
            if (std.ascii.eqlIgnoreCase(pid, exact)) return .quirks;
        }
    }
    if (system_id) |sid| {
        if (std.ascii.eqlIgnoreCase(sid, "http://www.ibm.com/data/dtd/v11/ibmxhtml1-transitional.dtd")) return .quirks;
    }
    if (public_id) |pid| {
        for (quirks_public_id_prefixes) |prefix| {
            if (std.ascii.startsWithIgnoreCase(pid, prefix)) return .quirks;
        }
        const html401 = std.ascii.startsWithIgnoreCase(pid, "-//W3C//DTD HTML 4.01 Frameset//") or
            std.ascii.startsWithIgnoreCase(pid, "-//W3C//DTD HTML 4.01 Transitional//");
        // "The system identifier is missing and the public identifier starts
        // with" either 4.01 prefix: quirks. With a system identifier:
        // limited-quirks.
        if (html401 and system_id == null) return .quirks;
        if (std.ascii.startsWithIgnoreCase(pid, "-//W3C//DTD XHTML 1.0 Frameset//") or
            std.ascii.startsWithIgnoreCase(pid, "-//W3C//DTD XHTML 1.0 Transitional//"))
        {
            return .limited_quirks;
        }
        if (html401) return .limited_quirks;
    }
    return .no_quirks;
}

/// "The public identifier is set to:" - equal, not a prefix.
const quirks_public_ids = [_][]const u8{
    "-//W3O//DTD W3 HTML Strict 3.0//EN//",
    "-/W3C/DTD HTML 4.0 Transitional/EN",
    "HTML",
};

/// "The public identifier starts with:"
const quirks_public_id_prefixes = [_][]const u8{
    "+//Silmaril//dtd html Pro v0r11 19970101//",
    "-//AS//DTD HTML 3.0 asWedit + extensions//",
    "-//AdvaSoft Ltd//DTD HTML 3.0 asWedit + extensions//",
    "-//IETF//DTD HTML 2.0 Level 1//",
    "-//IETF//DTD HTML 2.0 Level 2//",
    "-//IETF//DTD HTML 2.0 Strict Level 1//",
    "-//IETF//DTD HTML 2.0 Strict Level 2//",
    "-//IETF//DTD HTML 2.0 Strict//",
    "-//IETF//DTD HTML 2.0//",
    "-//IETF//DTD HTML 2.1E//",
    "-//IETF//DTD HTML 3.0//",
    "-//IETF//DTD HTML 3.2 Final//",
    "-//IETF//DTD HTML 3.2//",
    "-//IETF//DTD HTML 3//",
    "-//IETF//DTD HTML Level 0//",
    "-//IETF//DTD HTML Level 1//",
    "-//IETF//DTD HTML Level 2//",
    "-//IETF//DTD HTML Level 3//",
    "-//IETF//DTD HTML Strict Level 0//",
    "-//IETF//DTD HTML Strict Level 1//",
    "-//IETF//DTD HTML Strict Level 2//",
    "-//IETF//DTD HTML Strict Level 3//",
    "-//IETF//DTD HTML Strict//",
    "-//IETF//DTD HTML//",
    "-//Metrius//DTD Metrius Presentational//",
    "-//Microsoft//DTD Internet Explorer 2.0 HTML Strict//",
    "-//Microsoft//DTD Internet Explorer 2.0 HTML//",
    "-//Microsoft//DTD Internet Explorer 2.0 Tables//",
    "-//Microsoft//DTD Internet Explorer 3.0 HTML Strict//",
    "-//Microsoft//DTD Internet Explorer 3.0 HTML//",
    "-//Microsoft//DTD Internet Explorer 3.0 Tables//",
    "-//Netscape Comm. Corp.//DTD HTML//",
    "-//Netscape Comm. Corp.//DTD Strict HTML//",
    "-//O'Reilly and Associates//DTD HTML 2.0//",
    "-//O'Reilly and Associates//DTD HTML Extended 1.0//",
    "-//O'Reilly and Associates//DTD HTML Extended Relaxed 1.0//",
    "-//SQ//DTD HTML 2.0 HoTMetaL + extensions//",
    "-//SoftQuad Software//DTD HoTMetaL PRO 6.0::19990601::extensions to HTML 4.0//",
    "-//SoftQuad//DTD HoTMetaL PRO 4.0::19971010::extensions to HTML 4.0//",
    "-//Spyglass//DTD HTML 2.0 Extended//",
    "-//Sun Microsystems Corp.//DTD HotJava HTML//",
    "-//Sun Microsystems Corp.//DTD HotJava Strict HTML//",
    "-//W3C//DTD HTML 3 1995-03-24//",
    "-//W3C//DTD HTML 3.2 Draft//",
    "-//W3C//DTD HTML 3.2 Final//",
    "-//W3C//DTD HTML 3.2//",
    "-//W3C//DTD HTML 3.2S Draft//",
    "-//W3C//DTD HTML 4.0 Frameset//",
    "-//W3C//DTD HTML 4.0 Transitional//",
    "-//W3C//DTD HTML Experimental 19960712//",
    "-//W3C//DTD HTML Experimental 970421//",
    "-//W3C//DTD W3 HTML//",
    "-//W3O//DTD W3 HTML 3.0//",
    "-//WebTechs//DTD Mozilla HTML 2.0//",
    "-//WebTechs//DTD Mozilla HTML//",
};

fn isHtmlWhitespace(char: u21) bool {
    return char == 0x09 or char == 0x0A or char == 0x0C or char == 0x0D or char == 0x20;
}

/// Check if tag name is a special block element.
fn isSpecialBlockElement(name: []const u8) bool {
    const special = [_][]const u8{
        "address", "article", "aside",   "blockquote", "center",     "details", "dialog",
        "dir",     "div",     "dl",      "fieldset",   "figcaption", "figure",  "footer",
        "header",  "hgroup",  "main",    "menu",       "nav",        "ol",      "p",
        "search",  "section", "summary", "ul",         "h1",         "h2",      "h3",
        "h4",      "h5",      "h6",      "pre",        "listing",
    };
    for (special) |s| {
        if (std.mem.eql(u8, name, s)) return true;
    }
    return false;
}

/// Check if tag name is a formatting element.
fn isFormattingElement(name: []const u8) bool {
    const formatting = [_][]const u8{
        "a", "b", "big", "code", "em", "font", "i", "nobr", "s", "small", "strike", "strong", "tt", "u",
    };
    for (formatting) |f| {
        if (std.mem.eql(u8, name, f)) return true;
    }
    return false;
}

/// Check if tag name is a void element.
fn isVoidElement(name: []const u8) bool {
    const void_elements = [_][]const u8{
        "area",  "base", "br",   "col",   "embed",  "hr",    "img",
        "input", "link", "meta", "param", "source", "track", "wbr",
    };
    for (void_elements) |v| {
        if (std.mem.eql(u8, name, v)) return true;
    }
    return false;
}

/// The encoding a meta start tag declares, per the "in head" insertion
/// mode's meta steps: 1. its charset attribute, when getting an encoding from
/// the value gives one; 2. otherwise, with an http-equiv attribute that is an
/// ASCII case-insensitive match for "Content-Type", the encoding its content
/// attribute gives the algorithm for extracting a character encoding from a
/// meta element. Null when it declares none.
///
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-inhead
fn metaDeclaredEncoding(tag: anytype) ?encoding_sniffing.Encoding {
    if (tag.getAttribute("charset")) |charset| {
        if (encoding_sniffing.lookup(charset.getValue())) |found| return found;
    }
    const http_equiv = tag.getAttribute("http-equiv") orelse return null;
    if (!std.ascii.eqlIgnoreCase(http_equiv.getValue(), "Content-Type")) return null;
    const content = tag.getAttribute("content") orelse return null;
    return encoding_sniffing.extractFromMetaContent(content.getValue());
}

// =========================================================================
// Tests
// =========================================================================

test "TreeNode - create document" {
    const allocator = std.testing.allocator;
    const doc = try TreeNode.initDocument(allocator);
    defer doc.deinit();

    try std.testing.expectEqual(TreeNode.NodeType.document, doc.node_type);
    try std.testing.expectEqual(@as(?*TreeNode, null), doc.parent);
}

test "TreeNode - create element" {
    const allocator = std.testing.allocator;
    const elem = try TreeNode.initElement(allocator, "div", .html);
    defer elem.deinit();

    try std.testing.expectEqual(TreeNode.NodeType.element, elem.node_type);
    try std.testing.expectEqualStrings("div", elem.local_name.?);
    try std.testing.expectEqual(Namespace.html, elem.namespace);
}

test "TreeNode - append child" {
    const allocator = std.testing.allocator;
    const parent = try TreeNode.initElement(allocator, "div", .html);
    defer parent.deinit();

    const child = try TreeNode.initElement(allocator, "span", .html);
    // Don't defer child - parent owns it

    parent.appendChild(child);

    try std.testing.expectEqual(parent, child.parent);
    try std.testing.expectEqual(child, parent.first_child);
    try std.testing.expectEqual(child, parent.last_child);
}

test "TreeBuilder - init" {
    const allocator = std.testing.allocator;
    const input = "<!DOCTYPE html><html><head></head><body></body></html>";

    var tokenizer = Tokenizer.init(allocator, input);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    try std.testing.expectEqual(InsertionMode.initial, builder.insertion_mode);
    try std.testing.expectEqual(@as(?*TreeNode, null), builder.head_element);
}

test "InsertionMode - all modes defined" {
    // Verify all 24 insertion modes are defined
    const modes = [_]InsertionMode{
        .initial,
        .before_html,
        .before_head,
        .in_head,
        .in_head_noscript,
        .after_head,
        .in_body,
        .text,
        .in_table,
        .in_table_text,
        .in_caption,
        .in_column_group,
        .in_table_body,
        .in_row,
        .in_cell,
        .in_select,
        .in_select_in_table,
        .in_template,
        .after_body,
        .in_frameset,
        .after_frameset,
        .after_after_body,
        .after_after_frameset,
    };
    try std.testing.expectEqual(@as(usize, 23), modes.len);
}

test "isHtmlWhitespace" {
    try std.testing.expect(isHtmlWhitespace(0x09)); // tab
    try std.testing.expect(isHtmlWhitespace(0x0A)); // LF
    try std.testing.expect(isHtmlWhitespace(0x0C)); // FF
    try std.testing.expect(isHtmlWhitespace(0x0D)); // CR
    try std.testing.expect(isHtmlWhitespace(0x20)); // space
    try std.testing.expect(!isHtmlWhitespace('a'));
    try std.testing.expect(!isHtmlWhitespace('<'));
}

test "isSpecialBlockElement" {
    try std.testing.expect(isSpecialBlockElement("div"));
    try std.testing.expect(isSpecialBlockElement("p"));
    try std.testing.expect(isSpecialBlockElement("h1"));
    try std.testing.expect(!isSpecialBlockElement("span"));
    try std.testing.expect(!isSpecialBlockElement("a"));
}

test "isFormattingElement" {
    try std.testing.expect(isFormattingElement("b"));
    try std.testing.expect(isFormattingElement("i"));
    try std.testing.expect(isFormattingElement("a"));
    try std.testing.expect(!isFormattingElement("div"));
    try std.testing.expect(!isFormattingElement("p"));
}

test "isVoidElement" {
    try std.testing.expect(isVoidElement("br"));
    try std.testing.expect(isVoidElement("hr"));
    try std.testing.expect(isVoidElement("img"));
    try std.testing.expect(!isVoidElement("div"));
    try std.testing.expect(!isVoidElement("span"));
}

test "TreeBuilder - clearStackBackToTableContext" {
    const allocator = std.testing.allocator;
    const input = "<table><div><p>";

    var tokenizer = Tokenizer.init(allocator, input);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    // Manually set up the stack - nodes must be connected to document tree
    // so they get freed when builder.deinit() calls freeTree(document)
    const html = try TreeNode.initElement(allocator, "html", .html);
    const table = try TreeNode.initElement(allocator, "table", .html);
    const div = try TreeNode.initElement(allocator, "div", .html);
    const p = try TreeNode.initElement(allocator, "p", .html);

    // Build a proper tree structure - document -> html -> table -> div -> p
    builder.document.appendChild(html);
    html.appendChild(table);
    table.appendChild(div);
    div.appendChild(p);

    try builder.open_elements.append(html);
    try builder.open_elements.append(table);
    try builder.open_elements.append(div);
    try builder.open_elements.append(p);

    // Clear back to table context
    builder.clearStackBackToTableContext();

    // Should stop at table
    try std.testing.expectEqual(@as(usize, 2), builder.open_elements.len);
    const current = builder.currentNode().?;
    try std.testing.expectEqualStrings("table", current.local_name.?);
}

test "TreeBuilder - hasElementInTableScope" {
    const allocator = std.testing.allocator;
    const input = "<table>";

    var tokenizer = Tokenizer.init(allocator, input);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    // Manually set up the stack: html > table > tbody > tr > td
    // Nodes must be connected to document tree for proper cleanup
    const html = try TreeNode.initElement(allocator, "html", .html);
    const table = try TreeNode.initElement(allocator, "table", .html);
    const tbody = try TreeNode.initElement(allocator, "tbody", .html);
    const tr = try TreeNode.initElement(allocator, "tr", .html);
    const td = try TreeNode.initElement(allocator, "td", .html);

    // Build proper tree structure: document -> html -> table -> tbody -> tr -> td
    builder.document.appendChild(html);
    html.appendChild(table);
    table.appendChild(tbody);
    tbody.appendChild(tr);
    tr.appendChild(td);

    try builder.open_elements.append(html);
    try builder.open_elements.append(table);
    try builder.open_elements.append(tbody);
    try builder.open_elements.append(tr);
    try builder.open_elements.append(td);

    // td is in table scope
    try std.testing.expect(builder.hasElementInTableScope("td"));
    // tr is in table scope
    try std.testing.expect(builder.hasElementInTableScope("tr"));
    // table is in table scope
    try std.testing.expect(builder.hasElementInTableScope("table"));
    // div is NOT in scope (not present)
    try std.testing.expect(!builder.hasElementInTableScope("div"));
}

test "TreeBuilder - hasTableBodyElementInTableScope" {
    const allocator = std.testing.allocator;
    const input = "<table>";

    var tokenizer = Tokenizer.init(allocator, input);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    // Stack without tbody - nodes must be connected to document for cleanup
    const html = try TreeNode.initElement(allocator, "html", .html);
    const table = try TreeNode.initElement(allocator, "table", .html);

    // Build tree structure: document -> html -> table
    builder.document.appendChild(html);
    html.appendChild(table);

    try builder.open_elements.append(html);
    try builder.open_elements.append(table);

    // No tbody/thead/tfoot in scope
    try std.testing.expect(!builder.hasTableBodyElementInTableScope());

    // Add tbody
    const tbody = try TreeNode.initElement(allocator, "tbody", .html);
    table.appendChild(tbody); // Connect to tree
    try builder.open_elements.append(tbody);

    // Now has tbody in scope
    try std.testing.expect(builder.hasTableBodyElementInTableScope());
}
