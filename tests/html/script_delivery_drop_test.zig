//! Task-drop ownership regressions are colocated with their private owners.
const cases = @import("html").script_execution.delivery_drop_test_cases;

test "synchronous ready-task drop removes its queue root render blocker and load delay" {
    try cases.readyTaskDrop();
}

test "a dropped classic delivery removes each kind of scheduled script" {
    try cases.classicDeliveryDrop();
}

test "initial module graph cancellation prevents later fetching-queue insertion" {
    try cases.initialModuleCancellation();
}

test "ready-task allocation failure discards instead of running inline" {
    try cases.readyTaskAllocationFailure();
}

test "an actual initial graph task drop cleans its owner without recursive continuation" {
    try cases.initialGraphTaskDrop();
}

test "a dropped delivery cannot discard another preparation generation" {
    try cases.generationGuard();
}
