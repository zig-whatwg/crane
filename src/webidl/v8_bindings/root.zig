//! V8 Bindings Module
//!
//! This module provides helper types for V8 binding architecture:
//!
//! - CallbackWrapper: Wraps V8 functions as callback interfaces
//! - BindingGenerator: Generates V8 binding code per interface
//!
//! NOTE: WrapperTypeInfo and related type-safe unwrapping utilities are now
//! in src/runtime/engines/v8/wrapper_type_info.zig and accessible via the v8 module.
//!
//! ## Architecture Overview
//!
//! ```
//! ┌─────────────────────────────────────────────────────────────┐
//! │                    WebIDL Interface                          │
//! │                   (e.g., Element.idl)                        │
//! └─────────────────────────────────────────────────────────────┘
//!                              │
//!                              ▼
//! ┌─────────────────────────────────────────────────────────────┐
//! │                 Codegen (generates 3 files)                  │
//! └─────────────────────────────────────────────────────────────┘
//!           │                    │                    │
//!           ▼                    ▼                    ▼
//! ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
//! │   Interface     │  │   V8 Binding    │  │   Impl Stub     │
//! │ (Element.zig)   │  │ (v8_element.zig)│  │ (Element.zig)   │
//! │                 │  │                 │  │                 │
//! │ - Meta struct   │  │ - WrapperTypeInfo│ │ - Business logic│
//! │ - State type    │  │ - installTemplate│ │ - Constructor   │
//! │ - Delegates     │  │ - Callbacks     │  │ - Methods       │
//! └─────────────────┘  └─────────────────┘  └─────────────────┘
//!           interfaces/         v8_bindings/       impls/
//! ```

pub const CallbackWrapper = @import("callback_wrapper.zig").CallbackWrapper;
pub const EventListenerCallback = @import("callback_wrapper.zig").EventListenerCallback;
pub const createCallbackFromV8Value = @import("callback_wrapper.zig").createFromV8Value;

pub const BindingGenerator = @import("binding_generator.zig");

// ============================================================================
// Tag Allocation Constants
// ============================================================================

/// Type tag for WebIDL interfaces (same as in wrapper_type_info.zig)
pub const TypeTag = u16;

/// Reserved tag ranges for interface categories
/// Tags are assigned by codegen within these ranges
pub const TagRanges = struct {
    /// EventTarget and subclasses (base of most DOM objects)
    pub const event_target_start: TypeTag = 100;
    pub const event_target_end: TypeTag = 999;

    /// Node and subclasses
    pub const node_start: TypeTag = 110;
    pub const node_end: TypeTag = 899;

    /// Element and subclasses
    pub const element_start: TypeTag = 120;
    pub const element_end: TypeTag = 799;

    /// HTMLElement and subclasses
    pub const html_element_start: TypeTag = 130;
    pub const html_element_end: TypeTag = 599;

    /// Document and subclasses
    pub const document_start: TypeTag = 800;
    pub const document_end: TypeTag = 849;

    /// Non-Node interfaces (Event, Range, etc.)
    pub const other_start: TypeTag = 1000;
    pub const other_end: TypeTag = 1999;
};
