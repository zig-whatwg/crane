# Architecture: State an event announces is read from the realm's copy

**Date**: 2026-10-19
**Lesson**: When a queued event announces a change to shared state, the getter script reads must return the value the realm was last told, updated in the event's own task - never the shared record, which changed before the event was queued.

**Why**: A cross-thread change is made in one place (the service worker registry, under its lock, on the job thread) and announced to each realm as a queued task. Every task already in the realm's queue runs after the change but before the announcement. A getter that reads the shared record shows those tasks the new value while the event that says it changed is still to come.

**What Happened**: ServiceWorkerContainer.controller read the registry's live record (manager.controllerOf) while controllerchange arrived as a queued Delivery. tests/service_worker/clear_site_data_browsers_test failed about one gate in three: Browser B's page saw `controller !== null`, reset its controllerchange counter to 0, and then the claim's controllerchange task ran and made it 1. The race was invisible in single-file runs. A deterministic test (controller_task_test) queues a getRegistration() resolution, waits off-loop until the registry has the page controlled, then runs the loop: the resolution's reaction saw [object ServiceWorker] before controllerchange fired. Chromium (ServiceWorkerContainer::SetController) and Gecko (ServiceWorkerContainer::ControllerChanged) keep the container's controller as a field and set it in the same step that fires the event.

**Fix**:
1. The realm keeps `controller` (RealmEnvironment.controller): the active service worker the client was made with, snapshotted under the same lock that posts every later change (Manager.createClientControlled), so none is missed or seen twice.
2. The controller_change delivery replaces it in the task that fires controllerchange - whether or not the container exists yet, so a container made later reads it.
3. The worker_state deliveries update the kept copy's state too, so an object made from it later shows the state the queue has reached (the companion lesson on objects made on first read).
4. Pin it with a test that queues a task BEFORE the change and waits for the shared record to change without turning the realm's loop.

**Takeaway**: **A getter for state that an event announces reads the realm's copy, set in the event's task; reading the shared record lets every task queued before the event see the change first.**
