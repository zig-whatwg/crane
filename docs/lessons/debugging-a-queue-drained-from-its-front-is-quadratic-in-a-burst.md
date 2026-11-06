# Debugging: A queue drained by removing from its front is quadratic in a burst

**Date**: 2026-11-06
**Lesson**: The event loop's drain removed each task from the front of an array (orderedRemove), so every run moved every task behind it, and a burst of n tasks cost n²/2 task copies.

**Why**: An array-backed queue is cheap while it holds a few items, and every unit test drains a few. In 212dcdf7360 window timers became tasks, and gc_bench's setTimeout(0) burst and setInterval chain then put 5,000 tasks in the queue at once. The per-firing cost tracks the queue's length, so it showed only as a percentage on a cost page: +38% for the burst, +77% for the interval chain.

**What Happened**: Lane loadpath1's first suspect was a second microtask checkpoint per timer task. It was real, but a small part. macOS `sample` on gc_bench's interval row, run on the pool host as its own process, put 66% of all samples at one unsymbolized address in gc_bench's own image under `runOnceBlocking` -> the inlined drain: the memmove inside orderedRemove. Once the drain was fixed, the burst went from 115,071 instructions per firing to 86,570 (main: 83,367) and the chain from 72,773 to 41,174 (main: 40,952).

**Fix**: Walk the tasks in place. Copy each task left waiting down behind the waiting ones before it, and once the walk ends, move the tasks queued meanwhile down in one copy (`drainTasks`). That is how WebKit's EventLoop::run handles its queue: it exchanges the queue for an empty one, walks the old one, and appends the kept tasks and the ones queued meanwhile to a new vector. A test pins a 5,000-task burst draining in order, with what it queues running once, at the next drain.

**Takeaway**: **Never remove items one at a time from the front of an array a burst can fill: walk it and compact once. In a profile, an unsymbolized hot address under a queue's drain is usually that memmove.**
