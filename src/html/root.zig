//! HTML Specification Implementation
//!
//! Spec: https://html.spec.whatwg.org/
//! HTML Living Standard
//!
//! This module provides implementations of various parts of the HTML specification:
//!
//! - **Event Loop** (§8.1.7) - Core event loop for coordinating events, scripts,
//!   rendering, and more
//! - **Timers** (§8.6) - setTimeout() and setInterval()
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
//! ├── event_loop/          # Event loop, task queues, microtasks, timers
//! │   ├── event_loop.zig   # Main EventLoop struct
//! │   ├── task.zig         # Task and TaskSource definitions
//! │   ├── task_queue.zig   # TaskQueue and TaskQueueSet
//! │   ├── microtask.zig    # Microtask queue and checkpoint
//! │   ├── timers.zig       # setTimeout/setInterval
//! │   └── root.zig         # Module exports
//! ├── parser/              # HTML parser (§13)
//! │   ├── tokenizer.zig    # Tokenization state machine (80 states)
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
//! ## Usage
//!
//! ```zig
//! const html = @import("html/root.zig");
//! const timer_backend = @import("platform/timer_backend.zig");
//!
//! // Create event loop
//! const platform = try timer_backend.RealTimerBackend.init(allocator);
//! var event_loop = try html.EventLoop.init(allocator, .window, platform.backend());
//! defer event_loop.deinit();
//!
//! // Queue tasks
//! _ = try event_loop.queueTask(.dom_manipulation, callback, context, null);
//!
//! // Set timers
//! _ = try event_loop.setTimeout(timerCallback, 1000, null);
//!
//! // Run
//! try event_loop.run();
//! ```

const std = @import("std");

// Event Loop (§8.1.7)
pub const event_loop = @import("event_loop/root.zig");

// Re-export commonly used types
pub const EventLoop = event_loop.EventLoop;
pub const EventLoopType = event_loop.EventLoopType;
pub const Task = event_loop.Task;
pub const TaskSource = event_loop.TaskSource;
pub const Microtask = event_loop.Microtask;
pub const Timer = event_loop.Timer;
pub const TimerManager = event_loop.TimerManager;
pub const VisibilityState = event_loop.VisibilityState;
pub const RenderingCallbacks = event_loop.RenderingCallbacks;

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
pub const ParseErrorCollector = parser.ParseErrorCollector;

// Fragment parsing (§13.5 - innerHTML, DOMParser, etc.)
pub const parseFragment = parser.parseFragment;
pub const parseHTMLFromString = parser.parseHTMLFromString;
pub const FragmentParseResult = parser.FragmentParseResult;
pub const FragmentParseOptions = parser.FragmentParseOptions;

// Tag name string interning (performance optimization)
pub const tag_name_intern = parser.tag_name_intern;
pub const internTagName = parser.internTagName;
pub const isKnownHtmlTag = parser.isKnownHtmlTag;
pub const eqlInternedTag = parser.eqlInternedTag;

// Document write support (§8.4 - document.write/writeln/open/close)
pub const DocumentWriteState = parser.DocumentWriteState;
pub const DocumentWriteError = parser.DocumentWriteError;
pub const documentOpen = parser.documentOpen;
pub const documentWrite = parser.documentWrite;
pub const documentWriteln = parser.documentWriteln;
pub const documentClose = parser.documentClose;

// Custom Elements
// Note: custom_elements.zig and upgrade.zig require webidl access for
// CustomElementDefinition fields. They are available via the html module
// (full.zig) instead of html_core.

// Script Execution (§4.12.1), Script Runner (§4.12.1.1), and Event Utilities
// MOVED to src/webidl/impls/ to break circular dependency:
//   html_mod → interfaces_mod → impls_mod → html_mod (CYCLE!)
//
// These modules are now available via the impls module:
//   - impls.script_execution (prepareScriptElement, executeScriptElement, etc.)
//   - impls.script_runner (ScriptRunner)
//   - impls.event_utils (fireEvent, fireErrorEvent, reportException, etc.)
//
// Example usage:
//   const impls = @import("impls");
//   try impls.script_execution.prepareScriptElement(allocator, script_element);

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
pub const BrowsingContextGroup = window.BrowsingContextGroup;
pub const SandboxFlags = window.SandboxFlags;
pub const WindowProxy = window.WindowProxy;
pub const Origin = window.Origin;
pub const CrossOriginProperty = window.CrossOriginProperty;
pub const WindowProxyError = window.WindowProxyError;
pub const IFrameIntegration = window.IFrameIntegration;
pub const IFrameState = window.IFrameState;
pub const IFrameError = window.IFrameError;
pub const UIBackend = window.UIBackend;
pub const StubUIBackend = window.StubUIBackend;
pub const AnimationFrameScheduler = window.AnimationFrameScheduler;
pub const FrameTimingBackend = window.FrameTimingBackend;
pub const StubFrameTimingBackend = window.StubFrameTimingBackend;
pub const MockFrameTimingBackend = window.MockFrameTimingBackend;
pub const DOMHighResTimeStamp = window.DOMHighResTimeStamp;

// Navigation & History (§7.2-7.4)
pub const navigation = @import("navigation/root.zig");

// Re-export commonly used navigation types
pub const History = navigation.History;
pub const Location = navigation.Location;
pub const SessionHistoryEntry = navigation.SessionHistoryEntry;
pub const Navigable = navigation.Navigable;
pub const TraversableNavigable = navigation.TraversableNavigable;
pub const PopStateEvent = navigation.PopStateEvent;
pub const HashChangeEvent = navigation.HashChangeEvent;
pub const PageTransitionEvent = navigation.PageTransitionEvent;
pub const BeforeUnloadEvent = navigation.BeforeUnloadEvent;
pub const NavigationType = navigation.NavigationType;
pub const ScrollRestorationMode = navigation.ScrollRestorationMode;

// Module Graph and Async Fetching (§8.1.6)
pub const module_graph = @import("module_graph.zig");

// Re-export commonly used module graph types
pub const ModuleGraph = module_graph.ModuleGraph;
pub const ModuleNode = module_graph.ModuleNode;
pub const ModuleStatus = module_graph.ModuleStatus;
pub const ModuleGraphFetcher = module_graph.ModuleGraphFetcher;

// Web Workers (§10)
pub const workers = @import("workers/root.zig");

// Re-export commonly used worker types
pub const WorkerType = workers.WorkerType;
pub const WorkerOptions = workers.WorkerOptions;
pub const WorkerState = workers.WorkerState;
pub const WorkerError = workers.WorkerError;
pub const WorkerAgent = workers.WorkerAgent;
pub const DedicatedWorker = workers.DedicatedWorker;
pub const SharedWorker = workers.SharedWorker;
pub const SharedWorkerConnection = workers.SharedWorkerConnection;
pub const SharedWorkerManager = workers.SharedWorkerManager;
pub const WorkerLocation = workers.WorkerLocation;
pub const WorkerNavigator = workers.WorkerNavigator;

// Navigator (§8.8)
pub const navigator = @import("navigator/root.zig");

// Re-export commonly used navigator types
pub const Navigator = navigator.Navigator;
pub const NavigatorBackend = navigator.NavigatorBackend;
pub const NavigatorId = navigator.NavigatorId;
pub const NavigatorLanguage = navigator.NavigatorLanguage;
pub const NavigatorOnLine = navigator.NavigatorOnLine;
pub const NavigatorConcurrentHardware = navigator.NavigatorConcurrentHardware;
pub const NavigatorContentUtils = navigator.NavigatorContentUtils;
pub const NavigatorCookies = navigator.NavigatorCookies;
pub const NavigatorPlugins = navigator.NavigatorPlugins;

// Hardware APIs (various specs via Navigator)
pub const Geolocation = navigator.geolocation.Geolocation;
pub const MediaDevices = navigator.media_devices.MediaDevices;
pub const Clipboard = navigator.clipboard.Clipboard;
pub const CredentialsContainer = navigator.credentials.CredentialsContainer;
pub const Bluetooth = navigator.bluetooth.Bluetooth;
pub const USB = navigator.usb.USB;
pub const Serial = navigator.serial.Serial;
pub const HID = navigator.hid.HID;
pub const BatteryManager = navigator.battery.BatteryManager;
pub const NavigatorStorageManager = navigator.storage_manager.StorageManager;

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

// Stylesheet Blocking (§14.3.3)
pub const stylesheet_blocking = @import("stylesheet_blocking.zig");

// Re-export commonly used stylesheet blocking types
pub const StylesheetBlockingTracker = stylesheet_blocking.StylesheetBlockingTracker;
pub const PendingStylesheet = stylesheet_blocking.PendingStylesheet;
pub const isBlockingStylesheet = stylesheet_blocking.isBlockingStylesheet;
pub const isStylesheetRel = stylesheet_blocking.isStylesheetRel;
pub const shouldBlockScriptExecution = stylesheet_blocking.shouldBlockScriptExecution;

// Permissions Policy (W3C Permissions Policy spec)
pub const permissions_policy = @import("permissions_policy.zig");

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

test {
    std.testing.refAllDecls(@This());
}
