//! Promise<T> - JavaScript Promise object reference
//!
//! WebIDL Promise<T> represents a reference to a JavaScript Promise object.
//! Per the spec: "Promise types are references to objects that serve as a
//! place holder for the eventual results of a deferred (and possibly
//! asynchronous) computation."
//!
//! This is NOT a Zig async operation - it's a handle to a JavaScript runtime
//! Promise object. The Promise lives in the JS engine's heap and is manipulated
//! through the JavaScript binding layer.
//!
//! Generic function to create the type (used in generated code):

/// Promise<T> - JavaScript Promise object handle
pub fn Promise(comptime T: type) type {
    return struct {
        const Self = @This();

        /// Opaque handle to JavaScript Promise object
        /// The actual implementation is runtime-specific (V8, JSC, SpiderMonkey, etc.)
        handle: *anyopaque,

        /// Result type
        pub const ResultType = T;

        // TODO: Add methods for Promise interaction:
        // - resolve(value: T) -> void
        // - reject(reason: Error) -> void
        // - then(onFulfilled: fn(T) -> void) -> Promise(void)
        // - catch(onRejected: fn(Error) -> void) -> Promise(void)
        // - finally(onFinally: fn() -> void) -> Promise(T)
        //
        // These will require integration with the JavaScript binding layer
        // to call into the JS runtime's Promise implementation.
    };
}
