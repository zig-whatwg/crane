# Architecture: A parent completes loading in its last child's task

**Date**: 2026-10-08
**Lesson**: Blink and Gecko complete a document's load as soon as its last child frame is done, in the same task. HTML "the end" instead spins the event loop at step 8 and queues step 9's task. Crane now completes the parent from its last child's container load task.

**Why**: Blink's FrameLoader::DidFinishNavigation calls parent->CheckCompleted(), and Gecko's nsDocLoader::NotifyDoneWithOnload calls the parent's ChildDoneWithOnload. Both fire the parent's load synchronously. In the spec text the parent's load lands at least one task later, behind any message the child's load handlers posted. A test that navigates a frame when such a message arrives then sees a frame that has not completely loaded, and "navigate an iframe" makes that navigation a replace.

**What Happened**: grandparent_session_aboutsrcdoc.sub.window.html timed out (0/4; 4/4 in all three browsers). Its child's navigation on the first message replaced instead of pushing, so history.back() had nowhere to go. The first Crane test for the fix read document.readyState inside the child when it forwarded the message. That still said "interactive", because Crane keeps the frame element's load event steps ("completely finish loading" step 4) as a task of their own after the grandchild's onload message. Blink (LocalDOMWindow::DispatchLoadEvent) and Gecko (nsGlobalWindowInner::FireFrameLoadEvent) fire it inside the child's load dispatch. Read at the top when the forwarded message arrives - where the WPT test reads it - the state was "complete".

**Fix**: db136d284e. The container_load lifecycle task, after the container's load event steps, completes the node document's load if its "the end" has already queued step 9's task. A per-document token makes the queued task a no-op. The synchronous step runs inside a guarded document task, never inside the load-delay notification (see "Load-delay notification is not permission to run script").

**Takeaway**: **When the spec spins the event loop before a load task, check how many tasks the browsers put there - Blink and Gecko put none between a last child and its parent - and make a Crane test read the state where the WPT test under study reads it, not at an earlier point where a second, separate difference shows.**
