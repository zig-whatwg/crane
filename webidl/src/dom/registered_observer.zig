//! RegisteredObserver types for mutation observation
//! Spec: https://dom.spec.whatwg.org/#mutation-observers

const MutationObserverInit = @import("mutation_observer_init").MutationObserverInit;

/// Forward declaration - resolved when all modules are loaded
const MutationObserver = opaque {};

/// DOM §7.1 - RegisteredObserver
///
/// Represents an observer registered on a node.
pub const RegisteredObserver = struct {
    /// The MutationObserver object
    observer: *MutationObserver,

    /// The options for this registration
    options: MutationObserverInit,
};

/// DOM §7.1 - TransientRegisteredObserver
///
/// A registered observer that tracks mutations within a removed node's descendants.
pub const TransientRegisteredObserver = struct {
    /// The base registered observer
    registered: RegisteredObserver,

    /// The source registered observer (from parent node)
    source: *RegisteredObserver,
};
