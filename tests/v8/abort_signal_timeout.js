// AbortSignal.timeout() Integration Tests
//
// Run via: zig build repl -- tests/v8/abort_signal_timeout.js
//
// These tests verify AbortSignal.timeout() behavior:
// 1. Creates signal that starts non-aborted
// 2. After timeout, signal becomes aborted
// 3. Reason is TimeoutError DOMException
// 4. Integration with fetch() for request cancellation

// Test 1: AbortSignal.abort() creates pre-aborted signal
(function testAbortStatic() {
    const signal = AbortSignal.abort();
    console.assert(signal.aborted === true, "AbortSignal.abort() should create aborted signal");
    console.assert(signal.reason instanceof DOMException, "reason should be DOMException");
    console.assert(signal.reason.name === "AbortError", "reason.name should be AbortError");
    console.log("✓ AbortSignal.abort() creates pre-aborted signal");
})();

// Test 2: AbortSignal.abort() with custom reason
(function testAbortWithReason() {
    const customReason = new Error("Custom abort reason");
    const signal = AbortSignal.abort(customReason);
    console.assert(signal.aborted === true, "signal should be aborted");
    console.assert(signal.reason === customReason, "reason should be custom error");
    console.log("✓ AbortSignal.abort(reason) uses custom reason");
})();

// Test 3: AbortSignal.timeout() creates non-aborted signal initially
(function testTimeoutInitial() {
    const signal = AbortSignal.timeout(1000);
    console.assert(signal.aborted === false, "timeout signal should start non-aborted");
    console.log("✓ AbortSignal.timeout() starts non-aborted");
})();

// Test 4: AbortSignal.timeout() aborts after delay
(async function testTimeoutAborts() {
    const signal = AbortSignal.timeout(50);
    console.assert(signal.aborted === false, "should start non-aborted");
    
    await new Promise(resolve => setTimeout(resolve, 100));
    
    console.assert(signal.aborted === true, "should be aborted after timeout");
    console.assert(signal.reason instanceof DOMException, "reason should be DOMException");
    console.assert(signal.reason.name === "TimeoutError", "reason.name should be TimeoutError");
    console.log("✓ AbortSignal.timeout() aborts after delay with TimeoutError");
})();

// Test 5: AbortController can abort signal
(function testAbortController() {
    const controller = new AbortController();
    const signal = controller.signal;
    
    console.assert(signal.aborted === false, "signal should start non-aborted");
    
    controller.abort();
    
    console.assert(signal.aborted === true, "signal should be aborted after controller.abort()");
    console.assert(signal.reason instanceof DOMException, "reason should be DOMException");
    console.assert(signal.reason.name === "AbortError", "reason.name should be AbortError");
    console.log("✓ AbortController.abort() aborts signal");
})();

// Test 6: AbortController.abort() with custom reason
(function testAbortControllerWithReason() {
    const controller = new AbortController();
    const customReason = new Error("User cancelled");
    
    controller.abort(customReason);
    
    console.assert(controller.signal.aborted === true, "signal should be aborted");
    console.assert(controller.signal.reason === customReason, "reason should be custom error");
    console.log("✓ AbortController.abort(reason) uses custom reason");
})();

// Test 7: abort event fires when signal aborts
(function testAbortEvent() {
    const controller = new AbortController();
    let eventFired = false;
    
    controller.signal.addEventListener('abort', () => {
        eventFired = true;
    });
    
    controller.abort();
    
    console.assert(eventFired === true, "abort event should fire");
    console.log("✓ abort event fires when signal aborts");
})();

// Test 8: fetch() with pre-aborted signal rejects immediately
(async function testFetchWithAbortedSignal() {
    const signal = AbortSignal.abort();
    
    try {
        await fetch('http://localhost:8080/test', { signal });
        console.assert(false, "fetch should have thrown");
    } catch (e) {
        console.assert(e.name === "AbortError", "error should be AbortError");
        console.log("✓ fetch() with pre-aborted signal rejects with AbortError");
    }
})();

console.log("\nAll AbortSignal tests completed!");
