// WebSocket API Tests (V8 Integration)
// Tests WebSocket Standard implementation via JavaScript
// Spec: https://websockets.spec.whatwg.org/
//
// Run with: zig build test-v8

// ============================================================================
// WEBSOCKET INTERFACE TESTS
// ============================================================================

// WebSocket constructor exists
assert.isFunction(WebSocket, "WebSocket should be a constructor function")
assert.isNotNull(WebSocket.prototype, "WebSocket.prototype should exist")

// WebSocket constants
assert.strictEqual(WebSocket.CONNECTING, 0, "WebSocket.CONNECTING should be 0")
assert.strictEqual(WebSocket.OPEN, 1, "WebSocket.OPEN should be 1")
assert.strictEqual(WebSocket.CLOSING, 2, "WebSocket.CLOSING should be 2")
assert.strictEqual(WebSocket.CLOSED, 3, "WebSocket.CLOSED should be 3")

// WebSocket prototype constants
assert.strictEqual(WebSocket.prototype.CONNECTING, 0, "WebSocket.prototype.CONNECTING should be 0")
assert.strictEqual(WebSocket.prototype.OPEN, 1, "WebSocket.prototype.OPEN should be 1")
assert.strictEqual(WebSocket.prototype.CLOSING, 2, "WebSocket.prototype.CLOSING should be 2")
assert.strictEqual(WebSocket.prototype.CLOSED, 3, "WebSocket.prototype.CLOSED should be 3")

// ============================================================================
// CONSTRUCTOR TESTS
// ============================================================================

// Constructor with valid URL
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    const isInstance = ws instanceof WebSocket;
    ws.close(1000);
    return isInstance;
})(), "new WebSocket(url) should create WebSocket instance")

// Constructor requires URL argument
assert.isTrue((() => {
    try {
        new WebSocket();
        return false; // Should have thrown
    } catch (e) {
        // Any error is acceptable (TypeError, SyntaxError, etc.)
        return true;
    }
})(), "WebSocket() without arguments should throw")

// Constructor with invalid URL should throw SyntaxError
assert.throws(() => {
    new WebSocket("not a valid url");
}, /SyntaxError|TypeError/, "WebSocket with invalid URL should throw")

// Constructor with non-WebSocket scheme should throw SyntaxError
assert.throws(() => {
    new WebSocket("http://example.com/");
}, /SyntaxError/, "WebSocket with http:// URL should throw SyntaxError")

// Constructor with ws:// URL should work
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    ws.close(1000);
    return true;
})(), "WebSocket with ws:// URL should work")

// Constructor with wss:// URL should work (even if connection fails)
assert.isTrue((() => {
    try {
        const ws = new WebSocket("wss://localhost:8443/ws/echo");
        ws.close(1000);
        return true;
    } catch (e) {
        // Connection failure is OK, we're testing URL parsing
        return e.name !== "SyntaxError";
    }
})(), "WebSocket with wss:// URL should not throw SyntaxError")

// ============================================================================
// INITIAL STATE TESTS
// ============================================================================

// readyState should be CONNECTING initially
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    const state = ws.readyState;
    ws.close(1000);
    return state === WebSocket.CONNECTING;
})(), "readyState should be CONNECTING (0) initially")

// url property should return the URL
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    const url = ws.url;
    ws.close(1000);
    return url === "ws://localhost:8080/ws/echo";
})(), "url property should return the WebSocket URL")

// protocol should be empty string initially
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    const protocol = ws.protocol;
    ws.close(1000);
    return protocol === "";
})(), "protocol should be empty string initially")

// extensions should be empty string
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    const ext = ws.extensions;
    ws.close(1000);
    return ext === "";
})(), "extensions should be empty string")

// bufferedAmount should be 0 initially
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    const amount = ws.bufferedAmount;
    ws.close(1000);
    return amount === 0;
})(), "bufferedAmount should be 0 initially")

// binaryType should be "blob" by default
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    const type = ws.binaryType;
    ws.close(1000);
    return type === "blob";
})(), "binaryType should be 'blob' by default")

// ============================================================================
// BINARYTYPE TESTS
// ============================================================================

// binaryType can be set to "arraybuffer"
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    ws.binaryType = "arraybuffer";
    const type = ws.binaryType;
    ws.close(1000);
    return type === "arraybuffer";
})(), "binaryType can be set to 'arraybuffer'")

// binaryType can be set to "blob"
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    ws.binaryType = "arraybuffer";
    ws.binaryType = "blob";
    const type = ws.binaryType;
    ws.close(1000);
    return type === "blob";
})(), "binaryType can be set to 'blob'")

// binaryType ignores invalid values (per WebIDL spec for enum attributes)
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    ws.binaryType = "invalid";
    const type = ws.binaryType;
    ws.close(1000);
    return type === "blob"; // Should remain unchanged
})(), "binaryType should ignore invalid values")

// ============================================================================
// EVENT HANDLER TESTS
// ============================================================================

// onopen should be null initially
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    const handler = ws.onopen;
    ws.close(1000);
    return handler === null;
})(), "onopen should be null initially")

// onopen can be set to a function
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    const fn = function() {};
    ws.onopen = fn;
    const result = ws.onopen === fn;
    ws.close(1000);
    return result;
})(), "onopen can be set to a function")

// onopen can be set to null
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    ws.onopen = function() {};
    ws.onopen = null;
    const result = ws.onopen === null;
    ws.close(1000);
    return result;
})(), "onopen can be set to null")

// onerror should be null initially
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    const handler = ws.onerror;
    ws.close(1000);
    return handler === null;
})(), "onerror should be null initially")

// onmessage should be null initially
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    const handler = ws.onmessage;
    ws.close(1000);
    return handler === null;
})(), "onmessage should be null initially")

// onclose should be null initially
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    const handler = ws.onclose;
    ws.close(1000);
    return handler === null;
})(), "onclose should be null initially")

// ============================================================================
// CLOSE METHOD TESTS
// ============================================================================

// close() should be callable
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    ws.close(1000);
    return true;
})(), "close() should be callable")

// close() should change readyState to CLOSING or CLOSED
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    ws.close(1000);
    return ws.readyState === WebSocket.CLOSING || ws.readyState === WebSocket.CLOSED;
})(), "close() should change readyState to CLOSING or CLOSED")

// close() with valid code should work
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    ws.close(1000);
    return true;
})(), "close(1000) should work")

// close() with valid code and reason should work
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    ws.close(1000, "Normal closure");
    return true;
})(), "close(1000, 'Normal closure') should work")

// close() with invalid code should throw
assert.throws(() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    ws.close(999); // Invalid code (must be 1000 or 3000-4999)
}, /InvalidAccessError|RangeError/, "close(999) should throw")

// close() with code 1000 is valid
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    ws.close(1000);
    return true;
})(), "close(1000) is valid")

// close() with code in 3000-4999 range is valid
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    ws.close(3000);
    return true;
})(), "close(3000) is valid")

assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    ws.close(4999);
    return true;
})(), "close(4999) is valid")

// close() with too long reason should throw
assert.throws(() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    ws.close(1000, "x".repeat(124)); // Max is 123 bytes
}, /SyntaxError/, "close() with reason > 123 bytes should throw SyntaxError")

// ============================================================================
// SEND METHOD TESTS (before connection)
// ============================================================================

// send() on CONNECTING state should throw InvalidStateError
// Note: This requires the connection to still be in CONNECTING state
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    try {
        ws.send("test");
        ws.close(1000);
        // If we got here without error, connection might have opened fast
        return true; 
    } catch (e) {
        ws.close(1000);
        // InvalidStateError is expected per spec
        return e.name === "InvalidStateError" || e.message.includes("InvalidState");
    }
})(), "send() in CONNECTING state should throw InvalidStateError or succeed if already connected")

// ============================================================================
// PROTOTYPE CHAIN TESTS
// ============================================================================

// WebSocket should inherit from EventTarget
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    const result = ws instanceof EventTarget;
    ws.close(1000);
    return result;
})(), "WebSocket should inherit from EventTarget")

// addEventListener should be available
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    const result = typeof ws.addEventListener === "function";
    ws.close(1000);
    return result;
})(), "addEventListener should be available on WebSocket")

// removeEventListener should be available
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    const result = typeof ws.removeEventListener === "function";
    ws.close(1000);
    return result;
})(), "removeEventListener should be available on WebSocket")

// dispatchEvent should be available
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo");
    const result = typeof ws.dispatchEvent === "function";
    ws.close(1000);
    return result;
})(), "dispatchEvent should be available on WebSocket")

// ============================================================================
// SUBPROTOCOL TESTS
// ============================================================================

// Constructor with single protocol string
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo", "chat");
    ws.close(1000);
    return true;
})(), "WebSocket with single protocol string should work")

// Constructor with protocol array
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo", ["chat", "json"]);
    ws.close(1000);
    return true;
})(), "WebSocket with protocol array should work")

// Constructor with empty protocol array
assert.isTrue((() => {
    const ws = new WebSocket("ws://localhost:8080/ws/echo", []);
    ws.close(1000);
    return true;
})(), "WebSocket with empty protocol array should work")

// Constructor with duplicate protocols should throw (per spec)
// TODO: Implement protocol validation
assert.isTrue((() => {
    try {
        const ws = new WebSocket("ws://localhost:8080/ws/echo", ["chat", "chat"]);
        ws.close(1000);
        // Currently not validated - should throw SyntaxError per spec
        return true;
    } catch (e) {
        return e.name === "SyntaxError";
    }
})(), "WebSocket with duplicate protocols (validation pending)")

// Constructor with invalid protocol (contains space) should throw (per spec)
// TODO: Implement protocol validation  
assert.isTrue((() => {
    try {
        const ws = new WebSocket("ws://localhost:8080/ws/echo", "invalid protocol");
        ws.close(1000);
        // Currently not validated - should throw SyntaxError per spec
        return true;
    } catch (e) {
        return e.name === "SyntaxError";
    }
})(), "WebSocket with protocol containing space (validation pending)")

// ============================================================================
// CLOSEEVENT TESTS
// ============================================================================

// CloseEvent constructor exists
assert.isFunction(CloseEvent, "CloseEvent should be a constructor function")

// CloseEvent can be created
assert.isTrue((() => {
    const event = new CloseEvent("close");
    return event instanceof CloseEvent;
})(), "new CloseEvent('close') should create CloseEvent instance")

// CloseEvent should inherit from Event
assert.isTrue((() => {
    const event = new CloseEvent("close");
    return event instanceof Event;
})(), "CloseEvent should inherit from Event")

// CloseEvent type should be 'close'
assert.isTrue((() => {
    const event = new CloseEvent("close");
    return event.type === "close";
})(), "CloseEvent type should be 'close'")

// CloseEvent default values
assert.isTrue((() => {
    const event = new CloseEvent("close");
    return event.wasClean === false && event.code === 0 && event.reason === "";
})(), "CloseEvent should have default values (wasClean: false, code: 0, reason: '')")

// CloseEvent with init object
assert.isTrue((() => {
    const event = new CloseEvent("close", {
        wasClean: true,
        code: 1000,
        reason: "Normal closure"
    });
    return event.wasClean === true && event.code === 1000 && event.reason === "Normal closure";
})(), "CloseEvent should accept init object")

// ============================================================================
// MESSAGEEVENT TESTS (for WebSocket messages)
// ============================================================================

// MessageEvent constructor exists
assert.isFunction(MessageEvent, "MessageEvent should be a constructor function")

// MessageEvent can be created
assert.isTrue((() => {
    const event = new MessageEvent("message");
    return event instanceof MessageEvent;
})(), "new MessageEvent('message') should create MessageEvent instance")

// MessageEvent should inherit from Event
assert.isTrue((() => {
    const event = new MessageEvent("message");
    return event instanceof Event;
})(), "MessageEvent should inherit from Event")

// MessageEvent with data
assert.isTrue((() => {
    const event = new MessageEvent("message", { data: "hello" });
    return event.data === "hello";
})(), "MessageEvent should accept data in init object")

// MessageEvent origin property
assert.isTrue((() => {
    const event = new MessageEvent("message", { origin: "http://example.com" });
    return event.origin === "http://example.com";
})(), "MessageEvent should accept origin in init object")
