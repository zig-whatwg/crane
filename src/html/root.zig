//! HTML Specification Implementation
//!
//! Spec: https://html.spec.whatwg.org/
//! HTML Living Standard
//!
//! This module provides implementations of various parts of the HTML specification:
//!
//! - **Parser** (§13) - HTML parsing algorithm with tokenizer and tree builder
//! - **Custom Elements** - Custom element registry and lifecycle
//! - **Structured Clone** (§2.7) - Safe passing of structured data
//! - **Web Workers** (§10) - Dedicated and shared workers for background processing
//!
//! ## Architecture
//!
//! The HTML module is organized around the key concepts from the spec:
//!
//! ```
//! src/html/
//! ├── parser/              # HTML parser (§13)
//! │   ├── tokenizer.zig    # Tokenization state machine (84 states)
//! │   ├── tokens.zig       # Token types (DOCTYPE, Tag, Comment, etc.)
//! │   ├── tokenizer_states.zig  # State enum and helpers
//! │   ├── parse_errors.zig # Parse error codes and handling
//! │   ├── input_stream.zig # Input preprocessing
//! │   └── root.zig         # Module exports
//! ├── structured_clone/    # Structured clone algorithm (§2.7)
//! │   ├── types.zig        # Core types and error definitions
//! │   ├── serialize.zig    # StructuredSerialize implementation
//! │   ├── deserialize.zig  # StructuredDeserialize implementation
//! │   ├── transfer.zig     # Transfer algorithm for transferable objects
//! │   ├── clone.zig        # High-level structuredClone() API
//! │   └── root.zig         # Module exports
//! ├── workers/             # Web Workers (§10)
//! │   ├── types.zig        # Core type definitions
//! │   ├── worker_agent.zig # Worker agent (event loop + state)
//! │   ├── dedicated_worker.zig  # DedicatedWorker implementation
//! │   ├── shared_worker.zig     # SharedWorker implementation
//! │   ├── shared_worker_manager.zig  # Registry for shared workers
//! │   ├── worker_location.zig   # WorkerLocation implementation
//! │   ├── worker_navigator.zig  # WorkerNavigator implementation
//! │   └── root.zig         # Module exports
//! ├── custom_elements.zig  # Custom element definitions
//! └── root.zig             # This file
//! ```
//!
//! The event loop that runs is not here: a window's is the Browser's
//! (src/browser/event_loop.zig), a worker's is html/worker_event_loop.zig;
//! timers are runtime.native_timer.

const std = @import("std");

// Parser (§13)
pub const parser = @import("parser/root.zig");

// Re-export commonly used parser types
pub const Tokenizer = parser.Tokenizer;
pub const TreeBuilder = parser.TreeBuilder;
pub const Token = parser.Token;
pub const TagToken = parser.TagToken;
pub const DoctypeToken = parser.DoctypeToken;
pub const CommentToken = parser.CommentToken;
pub const ParseError = parser.ParseError;
pub const ParseErrorCode = parser.ParseErrorCode;

// Fragment parsing (§13.5 - innerHTML, DOMParser, etc.)
pub const parseFragment = parser.parseFragment;
pub const parseHTMLFromString = parser.parseHTMLFromString;
pub const FragmentParseResult = parser.FragmentParseResult;
pub const FragmentParseOptions = parser.FragmentParseOptions;

// Tag name string interning (performance optimization)
pub const tag_name_intern = parser.tag_name_intern;
pub const internTagName = parser.internTagName;
pub const internTagNameExact = parser.internTagNameExact;
/// An element's static name record (lane nd2 N2), or null: dom.element_name.
pub const internElementName = parser.internElementName;

// Custom Elements
pub const custom_element_reactions = @import("custom_elements/reactions.zig");
pub const custom_element_agent = @import("custom_elements/agent.zig");
pub const custom_element_definition = @import("custom_elements/definition.zig");
pub const custom_element_reaction = @import("custom_elements/reaction.zig");
pub const custom_element_returns = @import("custom_elements/returns.zig");

// Note: custom_elements.zig and upgrade.zig require webidl access for
// CustomElementDefinition fields. They are available via the html module
// (full.zig) instead of html_core.

// Nothing here imports the impls: only the generated layer (the interfaces,
// namespaces and mixins modules) can (src/webidl/AGENTS.md "The impls
// boundary"). Reach a type through `interfaces.X`, and a step with no IDL
// member through the src/dom hook its impl installs.

// Structured Clone (§2.7)
pub const structured_clone = @import("structured_clone/root.zig");

// Re-export commonly used structured clone types
pub const structuredClone = structured_clone.structuredClone;
pub const structuredSerialize = structured_clone.structuredSerialize;
pub const structuredDeserialize = structured_clone.structuredDeserialize;
pub const CloneError = structured_clone.CloneError;
pub const SerializedValue = structured_clone.SerializedValue;
pub const Transferable = structured_clone.Transferable;

// Window & Global Environment (§7)
pub const window = @import("window/root.zig");

// Re-export commonly used window types
pub const BrowsingContext = window.BrowsingContext;
pub const Navigables = window.Navigables;
pub const BrowsingContextGroup = window.BrowsingContextGroup;
pub const SandboxingFlagSet = window.SandboxingFlagSet;
pub const WindowProxy = window.WindowProxy;
pub const Origin = window.Origin;
pub const WindowProxyError = window.WindowProxyError;
pub const IFrameIntegration = window.IFrameIntegration;
pub const IFrameState = window.IFrameState;
pub const IFrameError = window.IFrameError;

// Navigation & History (§7.2-7.4)
pub const navigation = @import("navigation/root.zig");

// Web Workers (§10)
pub const workers = @import("workers/root.zig");

// Re-export commonly used worker types
pub const WorkerType = workers.WorkerType;
pub const WorkerOptions = workers.WorkerOptions;
pub const WorkerState = workers.WorkerState;
pub const WorkerError = workers.WorkerError;
pub const WorkerLocation = workers.WorkerLocation;
pub const WorkerNavigator = workers.WorkerNavigator;

// Navigator (§8.8): the Navigator object and the APIs it exposes are the
// impls (src/webidl/impls/Navigator.zig, NavigatorID.zig, ...); what stays
// here is HTML's "PDF viewing support", which the NavigatorPlugins family's
// impls and navigation's document type read.
pub const navigator = struct {
    /// HTML "PDF viewing support": PDF viewer supported, and the fixed plugin
    /// and mime type lists.
    pub const pdf_viewer = @import("navigator/pdf_viewer.zig");

    test {
        std.testing.refAllDecls(@This());
    }
};

// Web Storage (§12)
pub const web_storage = @import("web_storage/root.zig");

// Re-export commonly used storage types
pub const Storage = web_storage.Storage;
pub const StorageEvent = web_storage.StorageEvent;
pub const StorageEventData = web_storage.StorageEventData;
pub const StorageEventBroadcaster = web_storage.StorageEventBroadcaster;
pub const WebStorageType = web_storage.StorageType;
pub const WebStorageError = web_storage.StorageError;
pub const getLocalStorage = web_storage.getLocalStorage;
pub const getSessionStorage = web_storage.getSessionStorage;

// Permissions Policy (W3C Permissions Policy spec)
pub const permissions_policy = @import("permissions_policy.zig");

// The element interface for an element in the HTML namespace (§3.2.2)
pub const element_interface = @import("element_interface.zig");
pub const base64_utility = @import("base64_utility.zig");

// Re-export commonly used permissions policy types
pub const PermissionsPolicy = permissions_policy.PermissionsPolicy;
pub const PermissionsPolicyFeature = permissions_policy.Feature;
pub const PermissionsPolicyAllowlist = permissions_policy.Allowlist;

// Note: The following modules require WebIDL interface access and are NOT available
// from html_core. They are only available from the 'html' module (full.zig):
// - external_script_loader.zig - External script loading during parsing
// - dom_tree_adapter.zig - Incremental TreeNode to DOM conversion

// Editing APIs (§6.5)
pub const editing = @import("editing/root.zig");

// Re-export commonly used editing types
pub const EditingCommand = editing.Command;
pub const EditorState = editing.EditorState;
pub const execCommand = editing.execCommand;
pub const queryCommandEnabled = editing.queryCommandEnabled;
pub const queryCommandState = editing.queryCommandState;
pub const queryCommandSupported = editing.queryCommandSupported;
pub const queryCommandValue = editing.queryCommandValue;

pub const agent_host = @import("agent_host.zig");
pub const media = @import("media/root.zig");

test {
    std.testing.refAllDecls(@This());
}

/// XML byte decoding and XHTML named references, without document state.
pub const xml_document_encoding = @import("xml_document_encoding");
