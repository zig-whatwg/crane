/**
 * Custom testharnessreport.js for WPT Runner
 * 
 * This file bridges testharness.js results to the Zig test runner.
 * It registers callbacks that call into native Zig functions exposed
 * in the V8 context.
 * 
 * Native Functions:
 * - __wpt_report_result(name, status, message, stack, duration)
 *   Reports individual test/subtest results
 * 
 * - __wpt_report_completion(status, message)
 *   Signals that all tests in the file have completed
 * 
 * Status Values:
 * - Test status: 0=PASS, 1=FAIL, 2=TIMEOUT, 3=NOTRUN, 4=PRECONDITION_FAILED
 * - Harness status: 0=OK, 1=ERROR, 2=TIMEOUT
 */
(function() {
    'use strict';

    // Verify testharness.js is loaded
    if (typeof add_result_callback === 'undefined' ||
        typeof add_completion_callback === 'undefined') {
        console.error('testharnessreport.js: testharness.js must be loaded first');
        return;
    }

    // Track timing for individual tests
    var testStartTimes = {};

    /**
     * Register callback for individual test results.
     * This is called after each test() or promise_test() completes.
     */
    add_result_callback(function(test) {
        // Calculate duration if we have start time
        var duration = 0;
        if (testStartTimes[test.name]) {
            duration = Date.now() - testStartTimes[test.name];
            delete testStartTimes[test.name];
        }

        // Call native Zig function if available
        if (typeof __wpt_report_result === 'function') {
            __wpt_report_result(
                test.name || '',
                test.status,
                test.message || null,
                test.stack || null,
                duration
            );
        }
    });

    /**
     * Register callback for test file completion.
     * This is called when all tests in the file have finished,
     * including async tests.
     */
    add_completion_callback(function(tests, harness_status) {
        // Debug: Log when completion is called
        if (typeof __wpt_debug_log === 'function') {
            __wpt_debug_log('[testharnessreport] completion callback: status=' + harness_status.status + 
                           ' message=' + (harness_status.message || 'null') +
                           ' tests=' + tests.length);
        }
        
        // Call native Zig function if available
        if (typeof __wpt_report_completion === 'function') {
            __wpt_report_completion(
                harness_status.status,
                harness_status.message || null
            );
        }
    });

    /**
     * Register callback for test start to track timing.
     * add_start_callback is called when each test begins.
     */
    if (typeof add_start_callback === 'function') {
        add_start_callback(function(test) {
            testStartTimes[test.name] = Date.now();
        });
    }

    // Configure testharness.js for our runner
    // - output: false - Don't create results table in DOM
    if (typeof setup === 'function') {
        setup({
            output: false
        });
    }

})();
