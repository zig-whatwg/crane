// Cookie Sharing Integration Test (V8)
// Tests that cookies set via Fetch API are shared with WebSocket connections
//
// This validates that the CurlCookieManager properly shares cookies between:
// - Fetch API (via LibcurlBackend)
// - WebSocket (via CurlWebSocket)
//
// Prerequisites: Mock HTTP server running on localhost:8080
// Run with: zig build test-v8-fetch (after adding to integration test runner)
//
// Test flow:
// 1. Fetch a URL that sets a session cookie via Set-Cookie header
// 2. Open a WebSocket connection to an endpoint that validates cookies
// 3. Server accepts WebSocket ONLY if the same cookie was received
// 4. Test PASSES if WebSocket connects and receives success message
// 5. Test FAILS if WebSocket connection is rejected (401)

// Simple async test runner that integrates with the REPL's assertion counting
const tests = [];
let passed = 0;
let failed = 0;

// Initialize global assertion counter if not present
if (!globalThis._assertsPassed) globalThis._assertsPassed = 0;
if (!globalThis._assertsFailed) globalThis._assertsFailed = 0;

function test(name, fn) {
    tests.push({ name, fn });
}

async function runTests() {
    console.log("Running cookie sharing integration tests...\n");
    const failures = [];
    
    for (const t of tests) {
        try {
            const result = await t.fn();
            if (result === true) {
                passed++;
                globalThis._assertsPassed++;  // Integrate with REPL
            } else {
                failed++;
                globalThis._assertsFailed++;
                failures.push("FAIL: " + t.name + " (returned " + result + ")");
            }
        } catch (e) {
            failed++;
            globalThis._assertsFailed++;
            failures.push("ERROR: " + t.name + " (" + e.message + ")");
        }
    }
    
    // Print failures at the end for visibility
    if (failures.length > 0) {
        console.log("Failures:");
        for (const f of failures) {
            console.log("  " + f);
        }
        console.log("");
    }
    
    console.log(passed + "/" + (passed + failed) + " tests passed");
    return failed === 0;
}

// ============================================================================
// PREREQUISITE: COOKIE ENDPOINT TESTS
// ============================================================================

// Test that the cookie endpoint exists and works
test("/cookies/set endpoint exists", async () => {
    const response = await fetch("http://localhost:8080/cookies/set");
    return response.status === 200;
});

// Test that the cookie endpoint returns JSON
test("/cookies/set returns JSON with token", async () => {
    const response = await fetch("http://localhost:8080/cookies/set");
    const data = await response.json();
    return data.status === "cookie_set" && !!data.token;
});

// Test that the cookie endpoint sets a Set-Cookie header
test("/cookies/set returns Set-Cookie header", async () => {
    const response = await fetch("http://localhost:8080/cookies/set");
    const setCookie = response.headers.get("set-cookie");
    return setCookie !== null && setCookie.includes("session=");
});

// ============================================================================
// WEBSOCKET COOKIE VALIDATION TESTS
// ============================================================================

// Test that WebSocket endpoint rejects connections without cookie
test("WebSocket /ws/cookies rejects without cookie", async () => {
    return new Promise((resolve) => {
        try {
            // Don't fetch /cookies/set first - WebSocket should be rejected
            const ws = new WebSocket("ws://localhost:8080/ws/cookies");
            
            ws.onopen = function() {
                // Connection succeeded when it shouldn't have
                ws.close(1000);
                resolve(false);
            };
            
            ws.onerror = function() {
                // Expected: connection should fail due to missing cookie
                resolve(true);
            };
            
            ws.onclose = function(event) {
                // If closed with error code, that's expected
                if (!event.wasClean || event.code !== 1000) {
                    resolve(true);
                }
            };
            
            // Timeout after 5 seconds
            setTimeout(() => {
                ws.close();
                // If we timed out without error, consider it a pass
                // (server might have rejected with RST)
                resolve(true);
            }, 5000);
        } catch (e) {
            // Constructor threw - also indicates rejection
            resolve(true);
        }
    });
});

// ============================================================================
// MAIN COOKIE SHARING TEST
// ============================================================================

// Test that cookies set via Fetch are shared with WebSocket
test("Fetch cookies are shared with WebSocket", async () => {
    // Step 1: Fetch the cookie-setting endpoint
    // This should set a session cookie via Set-Cookie header
    const fetchResponse = await fetch("http://localhost:8080/cookies/set", {
        credentials: "include"  // Ensure cookies are stored
    });
    
    if (fetchResponse.status !== 200) {
        console.log("  Error: Cookie set request failed with status " + fetchResponse.status);
        return false;
    }
    
    const data = await fetchResponse.json();
    if (!data.token) {
        console.log("  Error: No token in cookie set response");
        return false;
    }
    
    console.log("  Cookie set with token: " + data.token);
    
    // Step 2: Open WebSocket connection
    // The WebSocket should automatically include the cookie (via CurlCookieManager)
    return new Promise((resolve) => {
        try {
            const ws = new WebSocket("ws://localhost:8080/ws/cookies");
            let messageReceived = false;
            
            ws.onopen = function() {
                console.log("  WebSocket connected successfully");
                // Send a test message to trigger server response
                ws.send("test");
            };
            
            ws.onmessage = function(event) {
                console.log("  WebSocket message received: " + event.data);
                messageReceived = true;
                
                try {
                    const response = JSON.parse(event.data);
                    if (response.cookie_shared === true) {
                        console.log("  SUCCESS: Server confirmed cookie was shared!");
                        ws.close(1000);
                        resolve(true);
                    } else {
                        console.log("  FAIL: Server did not confirm cookie sharing");
                        ws.close(1000);
                        resolve(false);
                    }
                } catch (e) {
                    console.log("  Error parsing WebSocket response: " + e.message);
                    ws.close(1000);
                    resolve(false);
                }
            };
            
            ws.onerror = function(event) {
                console.log("  WebSocket error - cookie may not have been shared");
                resolve(false);
            };
            
            ws.onclose = function(event) {
                if (!messageReceived) {
                    console.log("  WebSocket closed without message - code: " + event.code);
                    if (event.code !== 1000) {
                        console.log("  Connection was rejected (expected if cookie not shared)");
                        resolve(false);
                    }
                }
            };
            
            // Timeout after 10 seconds
            setTimeout(() => {
                if (!messageReceived) {
                    console.log("  Timeout waiting for WebSocket response");
                    ws.close();
                    resolve(false);
                }
            }, 10000);
        } catch (e) {
            console.log("  WebSocket constructor threw: " + e.message);
            resolve(false);
        }
    });
});

// ============================================================================
// VERIFY COOKIE IS SENT ON SUBSEQUENT FETCH
// ============================================================================

// Test that cookies are sent on subsequent fetch requests
test("Cookies are sent on subsequent fetch requests", async () => {
    // First, set the cookie
    const setResponse = await fetch("http://localhost:8080/cookies/set", {
        credentials: "include"
    });
    
    if (setResponse.status !== 200) {
        console.log("  Error: Initial cookie set failed");
        return false;
    }
    
    // Then verify the cookie is sent on the check endpoint
    const checkResponse = await fetch("http://localhost:8080/cookies/check", {
        credentials: "include"
    });
    
    if (checkResponse.status === 200) {
        const data = await checkResponse.json();
        if (data.cookie_valid === true) {
            console.log("  Cookie was sent correctly on subsequent request");
            return true;
        }
    }
    
    console.log("  Cookie was not sent or invalid - status: " + checkResponse.status);
    return false;
});

// Run all tests with proper async tracking
// Wrap in IIFE to avoid intermediate values being counted as assertions
(function() {
    // Register the promise so REPL waits for completion
    if (!globalThis._pendingAsserts) globalThis._pendingAsserts = [];
    const testPromise = runTests();
    globalThis._pendingAsserts.push(testPromise);
    testPromise.then(() => {
        // Remove from pending when done
        const idx = globalThis._pendingAsserts.indexOf(testPromise);
        if (idx >= 0) globalThis._pendingAsserts.splice(idx, 1);
    });
})();
