//! HTML Module with Full Interface Access
//!
//! This module provides the complete HTML specification implementation with
//! access to WebIDL interfaces. It re-exports everything from html_core plus
//! provides access to interfaces and impls for script execution.
//!
//! ## Module Architecture
//!
//! ```
//! html_core_mod ← infra, dom, platform (NO interfaces)
//!      ↓
//! impls_mod ← html_core_mod, interfaces_mod, ...
//!      ↓
//! html_mod ← html_core_mod, interfaces_mod (CAN use interfaces)
//! ```
//!
//! This layering ensures no cycles:
//! - impls imports html_core (not html), so no cycle with interfaces
//! - html imports interfaces, but html is not imported by impls
//!
//! ## Usage
//!
//! For external consumers (tests, applications):
//! ```zig
//! const html = @import("html");  // Gets full HTML with interfaces
//! ```
//!
//! For impls (internal WebIDL implementations):
//! ```zig
//! const html_core = @import("html_core");  // Gets interface-free HTML core
//! ```

const std = @import("std");

// Re-export all of html_core via module import (not file import)
// This ensures Zig sees html_core as one module, not two modules owning same files
const core = @import("html_core");

// Event Loop (§8.1.7)
pub const event_loop = core.event_loop;

// Re-export commonly used types
pub const EventLoop = core.EventLoop;
pub const EventLoopType = core.EventLoopType;
pub const Task = core.Task;
pub const TaskSource = core.TaskSource;
pub const Microtask = core.Microtask;
pub const Timer = core.Timer;
pub const TimerManager = core.TimerManager;
pub const VisibilityState = core.VisibilityState;
pub const RenderingCallbacks = core.RenderingCallbacks;

// Parser (§13)
pub const parser = core.parser;

// Navigation and session history (§7.4): the document a response makes
// ("load a document"), the steps of "navigate".
pub const navigation = core.navigation;

// Re-export commonly used parser types
pub const Tokenizer = core.Tokenizer;
pub const TreeBuilder = core.TreeBuilder;
pub const Token = core.Token;
pub const TagToken = core.TagToken;
pub const DoctypeToken = core.DoctypeToken;
pub const CommentToken = core.CommentToken;
pub const ParseError = core.ParseError;
pub const ParseErrorCode = core.ParseErrorCode;
pub const ParseErrorCollector = core.ParseErrorCollector;

// Fragment parsing (§13.5 - innerHTML, DOMParser, etc.)
pub const parseFragment = core.parseFragment;
pub const parseHTMLFromString = core.parseHTMLFromString;
pub const FragmentParseResult = core.FragmentParseResult;
pub const FragmentParseOptions = core.FragmentParseOptions;

// Document write support (§8.4 - document.write/writeln/open/close)
pub const DocumentWriteState = core.DocumentWriteState;
pub const DocumentWriteError = core.DocumentWriteError;
pub const documentOpen = core.documentOpen;
pub const documentWrite = core.documentWrite;
pub const documentWriteln = core.documentWriteln;
pub const documentClose = core.documentClose;

// Custom Elements (requires webidl access for CustomElementDefinition)
// Note: These modules are NOT available from html_core because they access
// CustomElementDefinition fields which require typed webidl imports.
/// Autofill field names - shared by input, select and textarea, which
/// cannot share a helper through impls/ because impls are private to
/// one another.
pub const autofill = @import("autofill.zig");
pub const form_associated = @import("form_associated.zig");
pub const custom_elements = @import("custom_elements.zig");
pub const upgrade = @import("upgrade.zig");

// Structured Clone (§2.7)
pub const structured_clone = core.structured_clone;

// Re-export commonly used structured clone types
pub const structuredClone = core.structuredClone;
pub const structuredSerialize = core.structuredSerialize;
pub const structuredDeserialize = core.structuredDeserialize;
pub const CloneError = core.CloneError;
pub const SerializedValue = core.SerializedValue;
pub const Transferable = core.Transferable;

// Window & Global Environment (§7)
pub const window = core.window;

// Re-export commonly used window types
pub const BrowsingContext = core.BrowsingContext;
pub const BrowsingContextGroup = core.BrowsingContextGroup;
pub const WindowProxy = core.WindowProxy;
pub const Origin = core.Origin;
pub const CrossOriginProperty = core.CrossOriginProperty;
pub const WindowProxyError = core.WindowProxyError;
pub const IFrameIntegration = core.IFrameIntegration;
pub const IFrameState = core.IFrameState;
pub const IFrameError = core.IFrameError;
pub const UIBackend = core.UIBackend;
pub const StubUIBackend = core.StubUIBackend;
pub const AnimationFrameScheduler = core.AnimationFrameScheduler;
pub const FrameTimingBackend = core.FrameTimingBackend;
pub const StubFrameTimingBackend = core.StubFrameTimingBackend;
pub const MockFrameTimingBackend = core.MockFrameTimingBackend;
pub const DOMHighResTimeStamp = core.DOMHighResTimeStamp;

// Web Workers (§10)
pub const workers = core.workers;

// Re-export commonly used worker types
pub const WorkerType = core.WorkerType;
pub const WorkerOptions = core.WorkerOptions;
pub const WorkerState = core.WorkerState;
pub const WorkerError = core.WorkerError;
pub const WorkerLocation = core.WorkerLocation;
pub const WorkerNavigator = core.WorkerNavigator;

// ============================================================================
// Interface Access (NOT available in html_core)
// ============================================================================

// Access to interfaces module - available for script execution files
// when they are moved back to src/html/ from src/webidl/impls/
pub const interfaces = @import("interfaces");

// Access to impls module - for script execution coordination
pub const impls = @import("impls");

// Access to runtime module - for JS execution context
pub const runtime = @import("runtime");

// ============================================================================
// Script Execution (HTML §4.12.1.1)
// ============================================================================

// These modules implement the HTML script processing model.
// They're in src/html/ because they legitimately need interfaces access.

/// Script execution algorithms (prepare/execute script element)
pub const script_execution = @import("script_execution.zig");
pub const script_request = @import("script_request.zig");

/// A script element's processing-model state (its parser document, already
/// started, result, ...), and the hook the processing model reaches an
/// element's through - Blink's ScriptLoader, WebKit's ScriptElement.
pub const script_element = @import("script_element.zig");

/// "Report an exception": runtime script errors reach the global's error
/// event and `onerror` through here.
pub const report_exception = @import("report_exception.zig");

pub const agent_host = core.agent_host;
pub const microtask_checkpoint = @import("microtask_checkpoint.zig");

/// Unhandled promise rejections: HostPromiseRejectionTracker and the
/// unhandledrejection / rejectionhandled events.
pub const rejected_promises = @import("rejected_promises.zig");

/// Script runner for coordinating script scheduling
pub const script_runner = @import("script_runner.zig");

/// DOM tree adapter for incremental TreeNode to DOM conversion during parsing.
/// This enables scripts to access DOM nodes that were parsed before them.
pub const dom_tree_adapter = @import("dom_tree_adapter.zig");
pub const DomTreeAdapter = dom_tree_adapter.DomTreeAdapter;
pub const DomTreeAdapterError = dom_tree_adapter.DomTreeAdapterError;

/// External script loader for loading external scripts during parsing.
/// Handles parser-blocking, async, and deferred scripts.
pub const external_script_loader = @import("external_script_loader.zig");
pub const ExternalScriptLoader = external_script_loader.ExternalScriptLoader;
pub const PendingScript = external_script_loader.PendingScript;
pub const ExternalScriptType = external_script_loader.ScriptType;
pub const ScriptExecutor = external_script_loader.ScriptExecutor;
pub const ScriptLoaderFn = external_script_loader.ScriptLoaderFn;

/// HTML "hyperlink auditing": the pings an a or area element's hyperlink
/// sends when it is followed.
pub const hyperlink_auditing = @import("hyperlink_auditing.zig");

/// A link or style element's style sheet load, with its critical
/// subresources, and a link's preload.
pub const style_sheet_loading = @import("style_sheet_loading.zig");

/// Scripted HTML parser with incremental DOM conversion
/// Use this when scripts need access to DOM nodes during parsing
pub const scripted_parser = @import("scripted_parser.zig");
/// HTML "encoding-parse a URL" relative to a Document.
pub const encoding_parse = @import("encoding_parse.zig");

/// Parser script execution callback and context for V8 integration.
/// Provides the bridge between tree builder's script callback and V8 execution.
pub const parser_script_execution = @import("parser_script_execution.zig");
pub const ParserScriptContext = parser_script_execution.ParserScriptContext;

/// Event utilities for firing events during script processing
pub const event_utils = @import("event_utils.zig");

/// Selection command implementations with DOM integration
/// (Used by execCommand for selectAll, delete, forwardDelete)
pub const selection_commands = @import("selection_commands.zig");

/// Formatting command implementations with DOM integration
/// (Used by execCommand for font/color/alignment commands)
pub const formatting_commands = @import("formatting_commands.zig");

/// Structure command implementations with DOM integration
/// (Used by execCommand for list, paragraph, link, and media commands)
pub const structure_commands = @import("structure_commands.zig");

/// The worker host: the HTML half of "run a worker" (its event loop, timers,
/// messages, errors and life); the engine half is behind the engine.
pub const worker_host = @import("worker_host.zig");
pub const WorkerHost = worker_host.WorkerHost;

/// A worker on a thread of its own: the link both threads share (its life,
/// its agent for "terminate a worker", its thread), the event loop the thread
/// spins, the thread's body, and the Browser's registry of live workers (a
/// BrowserScope supplement).
pub const worker_link = @import("worker_link.zig");
pub const WorkerLink = worker_link.WorkerLink;
pub const worker_event_loop = @import("worker_event_loop.zig");
pub const WorkerEventLoop = worker_event_loop.WorkerEventLoop;
pub const worker_thread = @import("worker_thread.zig");
pub const WorkerThread = worker_thread.WorkerThread;
pub const worker_registry = @import("worker_registry.zig");
pub const WorkerRegistry = worker_registry.WorkerRegistry;

/// The embedder's answer for the scripts of frame and popup documents
/// (the WPT runner's testdriver vendor file).
pub const embedder_scripts = @import("embedder_scripts.zig");
/// HTML 6.4 user activation.
pub const user_activation = @import("user_activation.zig");

// "same origin-domain" between the entry settings object and a Window (the
// Location interface's security check).
pub const origin_domain = @import("origin_domain.zig");
/// HTML 6.6 focus: focusable areas, the focusing steps, activeElement.
pub const focus = @import("focus.zig");
/// The events a user's pointer and keyboard produce, and their default
/// actions (UI Events, Pointer Events, Input Events).
pub const user_input = @import("user_input.zig");

// ============================================================================
// Re-exports for Testing Convenience
// ============================================================================

/// ScriptRunner type for coordinating script execution
pub const ScriptRunner = script_runner.ScriptRunner;

/// Extract error information from a JavaScript exception
/// Re-exported from event_utils for convenience
pub const extractErrorInfo = event_utils.extractErrorInfo;

/// Error information structure
pub const ErrorInfo = event_utils.ErrorInfo;

test {
    std.testing.refAllDecls(@This());
}
