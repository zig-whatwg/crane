# Architecture: An object made on first read shows the state of that moment, not of the tasks still queued

**Date**: 2026-10-17
**Lesson**: When queued tasks update an object only "if it exists", make the object before those tasks are queued - an object made lazily by a getter takes the live state and skips the updates still in the queue.

**Why**: Service Workers' Update Worker State and Update Registration State queue a task per realm that updates that realm's ServiceWorker / registration object "if objectMap[worker] exists". Crane's realm made those objects lazily, in their getters, from the registry's state at that moment. The job thread runs ahead of the realm's queue, so a getter that runs after the job thread moved on sees a later state than the tasks still queued say.

**What Happened**: Two WPT files failed the same way in one batch (lane sw1-b5). skip-waiting-using-registration: the controllerchange listener read container.controller, whose object was made then - "activated" where the queued statechange still said "activating". skip-waiting-installed: the worker first read registration.active in skipWaiting()'s reaction, after its activate event had ended on the job thread - "activated" again. A probe that touched registration.active earlier (in its activate listener) passed, which is what pointed at object creation time rather than task order.

**Fix**: Make the object at the point the spec (or Chromium) has it exist: the controller-change message carries the new controller's snapshot and the realm makes the object from it before firing controllerchange; a service worker's global makes its registration and own ServiceWorker objects once its script has run, before the job thread hears so (Chromium: ServiceWorkerContainerHost::SendSetControllerServiceWorker, ServiceWorkerGlobalScope::InitializeGlobalScope).

**Takeaway**: **A getter that builds an object from live state races every task already queued to update it: create the object where the state it should show is still the one the queue starts from.**
