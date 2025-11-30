::: {#abstract .section}
This specification extends the High Resolution Time specification
\[\[HR-TIME-3\]\] by providing methods to store and retrieve high
resolution performance metric data.
:::

::: {#sotd .section}
This Performance Timeline specification replaces the first version of
\[\[PERFORMANCE-TIMELINE\]\] and includes:

- Extends the base definition of the {{Performance}} interface defined
  by \[\[HR-TIME-3\]\];
- Exposes {{PerformanceEntry}} in Web Workers \[\[WORKERS\]\];
- Formalizes support for multiple navigation events over a document\'s
  lifetime.
- Adds support for {{PerformanceObserver}}.
:::

::: {.section .informative}
## Introduction

Accurately measuring performance characteristics of web applications is
an important aspect of making web applications faster. This
specification defines the necessary Performance Timeline primitives that
enable web developers to access, instrument, and retrieve various
performance metrics from the full lifecycle of a web application.

\[\[NAVIGATION-TIMING-2\]\], \[\[RESOURCE-TIMING-2\]\], and
\[\[USER-TIMING-2\]\] are examples of specifications that define timing
information related to the navigation of the document, resources on the
page, and developer scripts, respectively. Together these and other
performance interfaces define performance metrics that describe the
Performance Timeline of a web application. For example, the following
script shows how a developer can access the Performance Timeline to
obtain performance metrics related to the navigation of the document,
resources on the page, and developer scripts:

``` {.example .html}

      <!doctype html>
      <html>
      <head></head>
      <body onload="init()">
        <img id="image0" src="https://www.w3.org/Icons/w3c_main.png" />
        <script>
          function init() {
            // see [[USER-TIMING-2]]
            performance.mark("startWork");
            doWork(); // Some developer code
            performance.mark("endWork");
            measurePerf();
          }
          function measurePerf() {
            performance
              .getEntries()
              .map(entry => JSON.stringify(entry, null, 2))
              .forEach(json => console.log(json));
          }
        </script>
        </body>
      </html>
    
```

Alternatively, the developer can observe the Performance Timeline and be
notified of new performance metrics and, optionally, previously buffered
performance metrics of specified type, via the PerformanceObserver
interface.

The PerformanceObserver interface was added and is designed to address
limitations of the buffer-based approach shown in the first example. By
using the PerformanceObserver interface, the application can:

- Avoid polling the timeline to detect new metrics
- Eliminate costly deduplication logic to identify new metrics
- Eliminate race conditions with other consumers that may want to
  manipulate the buffer

The developer is encouraged to use PerformanceObserver where possible.
Further, new performance API\'s and metrics may only be available
through the PerformanceObserver interface. The observer works by
specifying a callback in the constructor and specifying the performance
entries it\'s interested in via the
[observe()]{link-for="PerformanceObserver"} method. The user agent
chooses when to execute the callback, which receives performance entries
that have been queued.

There are special considerations regarding initial page load when using
the PerformanceObserver interface: a registration must be active to
receive events but the registration script may not be available or may
not be desired in the critical path. To address this, user agents buffer
some number of events while the page is being constructed, and these
buffered events can be accessed via the
[buffered]{link-for="PerformanceObserverInit"} flag when registering the
observer. When this flag is set, the user agent retrieves and dispatches
events that it has buffered, for the specified entry type, and delivers
them in the first callback after the
[observe()]{link-for="PerformanceObserver"} call occurs.

The number of buffered events is determined by the specification that
defines the metric and buffering is intended to used for first-N events
only; buffering is not unbounded or continuous.

``` example

    <!doctype html>
    <html>
    <head></head>
    <body>
    <img id="image0" src="https://www.w3.org/Icons/w3c_main.png" />
    <script>
    // Know when the entry types we would like to use are not supported.
    function detectSupport(entryTypes) {
      for (const entryType of entryTypes) {
        if (!PerformanceObserver.supportedEntryTypes.includes(entryType)) {
          // Indicate to client-side analytics that |entryType| is not supported.
        }
      }
    }
    detectSupport(["resource", "mark", "measure"]);
    const userTimingObserver = new PerformanceObserver(list => {
      list
        .getEntries()
        // Get the values we are interested in
        .map(({ name, entryType, startTime, duration }) => {
          const obj = {
            "Duration": duration,
            "Entry Type": entryType,
            "Name": name,
            "Start Time": startTime,
          };
          return JSON.stringify(obj, null, 2);
        })
        // Display them to the console.
        .forEach(console.log);
      // Disconnect after processing the events.
      userTimingObserver.disconnect();
    });
    // Subscribe to new events for User-Timing.
    userTimingObserver.observe({entryTypes: ["mark", "measure"]});
    const resourceObserver = new PerformanceObserver(list => {
      list
        .getEntries()
        // Get the values we are interested in
        .map(({ name, startTime, fetchStart, responseStart, responseEnd }) => {
          const obj = {
            "Name": name,
            "Start Time": startTime,
            "Fetch Start": fetchStart,
            "Response Start": responseStart,
            "Response End": responseEnd,
          };
          return JSON.stringify(obj, null, 2);
        })
        // Display them to the console.
        .forEach(console.log);
      // Disconnect after processing the events.
      resourceObserver.disconnect();
    });
    // Retrieve buffered events and subscribe to newer events for Resource Timing.
    resourceObserver.observe({type: "resource", buffered: true});
    </script>
    </body>
    </html>
    
```
:::

::: {#conformance .section}
Conformance requirements phrased as algorithms or specific steps may be
implemented in any manner, so long as the end result is equivalent. (In
particular, the algorithms defined in this specification are intended to
be easy to follow, and not intended to be performant).
:::

::::::: section
## [Performance Timeline]{.dfn}

Each global object has:

- a [performance observer task queued flag]{.dfn}
- a [list of registered performance observer objects]{.dfn} that is
  initially empty
- a [performance entry buffer map]{.dfn} [map]{data-cite="infra"}, keyed
  on a `DOMString`, representing the entry type to which the buffer
  belongs. The [map]{data-cite="infra"}\'s
  [value]{data-cite="INFRA#map-value"} is the following tuple:
  - A [performance entry buffer]{.dfn .export} to store PerformanceEntry
    objects, that is initially empty.
  - An integer [maxBufferSize]{.dfn}, initialized to the
    [registry](https://w3c.github.io/timing-entrytypes-registry/#registry)
    value for this entry type.
  - A `boolean` [availableFromTimeline]{.dfn}, initialized to the
    [registry](https://w3c.github.io/timing-entrytypes-registry/#registry)
    value for this entry type.
  - An integer [dropped entries count]{.dfn} that is initially 0.
- An integer [last performance entry id]{.dfn} that is initially set to
  a random integer between 100 and 10000.

Each Document has:

- A [most recent navigation]{.dfn}, which is a PerformanceEntry,
  initially unset.

In order to get the [relevant performance entry tuple]{.dfn}, given
`entryType`{.variable} and `globalObject`{.variable} as input, run the
following steps:

1.  Let `map`{.variable} be the performance entry buffer map associated
    with `globalObject`{.variable}.
2.  Return the result of getting the value of an entry from
    ` map`{.variable}, given `entryType`{.variable} as the key.

:::::: {.section dfn-for="Performance" link-for="Performance"}
## Extensions to the {{Performance}} interface

This extends the {{Performance}} interface from \[\[HR-TIME-3\]\] and
hosts performance related attributes and methods used to retrieve the
performance metric data from the Performance Timeline.

``` idl

      partial interface Performance {
        PerformanceEntryList getEntries ();
        PerformanceEntryList getEntriesByType (DOMString type);
        PerformanceEntryList getEntriesByName (DOMString name, optional DOMString type);
      };
      typedef sequence<PerformanceEntry> PerformanceEntryList;
      
```

The [PerformanceEntryList]{.dfn} represents a sequence of
PerformanceEntry, providing developers with all the convenience methods
found on JavaScript arrays.

::: section
## [getEntries()]{.dfn} method

Returns a PerformanceEntryList object returned by the filter buffer map
by name and type algorithm with `name`{.variable} and `type`{.variable}
set to `null`.
:::

::: section
## [getEntriesByType()]{.dfn} method

Returns a PerformanceEntryList object returned by filter buffer map by
name and type algorithm with `name`{.variable} set to `null`, and
`type`{.variable} set to the method\'s input `type` parameter.
:::

::: section
## [getEntriesByName()]{.dfn} method

Returns a PerformanceEntryList object returned by filter buffer map by
name and type algorithm with `name`{.variable} set to the method input
`name` parameter, and `type`{.variable} set to `null` if optional
\`entryType\` is omitted, or set to the method\'s input `type` parameter
otherwise.
:::
::::::
:::::::

::: {.section dfn-for="PerformanceEntry" link-for="PerformanceEntry"}
## The [PerformanceEntry]{.dfn} interface

The PerformanceEntry interface hosts the performance data of various
metrics.

``` idl

      [Exposed=(Window,Worker)]
      interface PerformanceEntry {
        readonly    attribute unsigned long long  id;
        readonly    attribute DOMString           name;
        readonly    attribute DOMString           entryType;
        readonly    attribute DOMHighResTimeStamp startTime;
        readonly    attribute DOMHighResTimeStamp duration;
        readonly    attribute unsigned long long  navigationId;
        [Default] object toJSON();
      };
```

[name]{.dfn}
:   This attribute must return the value it is initialized to. It
    represents an identifier for this PerformanceEntry object. This
    identifier does not have to be unique.

[entryType]{.dfn}

:   This attribute must return the value it is initialized to.

    All \`entryType\` values are defined in the
    relevant[registry](https://w3c.github.io/timing-entrytypes-registry/#registry).
    Examples include: `"mark"` and `"measure"` \[\[USER-TIMING-2\]\],
    `"navigation"` \[\[NAVIGATION-TIMING-2\]\], and `"resource"`
    \[\[RESOURCE-TIMING-2\]\].

[startTime]{.dfn}
:   This attribute must return the value it is initialized to. It
    represents the time value of the first recorded timestamp of this
    performance metric.

[duration]{.dfn}
:   The getter steps for the duration attribute are to return 0 if
    this\'s end time is 0; otherwise this\'s end time - this\'s
    startTime.

[navigationId]{.dfn}
:   This attribute MUST return the value it is initialized to.

When [toJSON]{.dfn} is called, run \[\[WebIDL\]\]\'s default toJSON
steps.

A PerformanceEntry has a {{DOMHighResTimeStamp}} [end time]{.dfn
.export}, initially 0.

To [initialize a PerformanceEntry]{.dfn .export} `entry`{.variable}
given a {{DOMHighResTimeStamp}} `startTime`{.variable}, a `DOMString`
`entryType`{.variable}, a `DOMString` name, and an optional
{{DOMHighResTimeStamp}} `endTime`{.variable} (default `0`):

1.  Assert: `entryType`{.variable} is defined in the [entry type
    registry](https://w3c.github.io/timing-entrytypes-registry/#registry).
2.  Initialize `entry`{.variable}\'s startTime to
    `startTime`{.variable}.
3.  Initialize `entry`{.variable}\'s entryType to
    `entryType`{.variable}.
4.  Initialize `entry`{.variable}\'s name to `name`{.variable}.
5.  Initialize `entry`{.variable}\'s end time to `endTime`{.variable}.
:::

::::::::::::: {.section link-for="PerformanceObserver" dfn-for="PerformanceObserver"}
## The [PerformanceObserver]{.dfn} interface

The PerformanceObserver interface can be used to observe the Performance
Timeline to be notified of new performance metrics as they are recorded,
and optionally buffered performance metrics.

Each PerformanceObserver has these associated concepts:

- A [PerformanceObserverCallback]{.dfn} [observer callback]{.dfn} set on
  creation.
- A PerformanceEntryList object called the [observer buffer]{.dfn} that
  is initially empty.
- A `DOMString` [observer type]{.dfn} which is initially `"undefined"`.
- A boolean [requires dropped entries]{.dfn} which is initially set to
  false.

The \`PerformanceObserver(callback)\` constructor must create a new
PerformanceObserver object with its observer callback set to
`callback`{.variable} and then return it.

A [registered performance observer]{.dfn} is a struct consisting of an
[observer]{.dfn} member (a PerformanceObserver object) and an [options
list]{.dfn} member (a list of PerformanceObserverInit dictionaries).

``` idl

      callback PerformanceObserverCallback = undefined (PerformanceObserverEntryList entries,
                                                   PerformanceObserver observer,
                                                   optional PerformanceObserverCallbackOptions options = {});
      [Exposed=(Window,Worker)]
      interface PerformanceObserver {
        constructor(PerformanceObserverCallback callback);
        undefined observe (optional PerformanceObserverInit options = {});
        undefined disconnect ();
        PerformanceEntryList takeRecords();
        [SameObject] static readonly attribute FrozenArray<DOMString> supportedEntryTypes;
      };
    
```

To keep the performance overhead to minimum the application ought to
only subscribe to event types that it is interested in, and disconnect
the observer once it no longer needs to observe the performance data.
Filtering by name is not supported, as it would implicitly require a
subscription for all event types --- this is possible, but discouraged,
as it will generate a significant volume of events.

::: {.section dfn-for="PerformanceObserverCallbackOptions" link-for="PerformanceObserverCallbackOptions"}
## [PerformanceObserverCallbackOptions]{.dfn} dictionary

``` idl

        dictionary PerformanceObserverCallbackOptions {
          unsigned long long droppedEntriesCount;
        };
      
```

[droppedEntriesCount]{.dfn}
:   An integer representing the dropped entries count for the entry
    types that the observer is observing when the PerformanceObserver\'s
    requires dropped entries is set.
:::

:::::::: section
## [observe()]{.dfn} method

The observe() method instructs the user agent to register the observer
and must run these steps:

1.  Let `relevantGlobal`{.variable} be this\'s relevant global object.
2.  If `options`{.variable}\'s entryTypes and type members are both
    omitted, then \[=exception/throw=\] a {{\"TypeError\"}}.
3.  If `options`{.variable}\'s entryTypes is present and any other
    member is also present, then \[=exception/throw=\] a
    {{\"TypeError\"}}.
4.  Update or check this\'s observer type by running these steps:
    1.  If this\'s observer type is `"undefined"`:
        1.  If `options`{.variable}\'s entryTypes member is present,
            then set this\'s observer type to `"multiple"`.
        2.  If `options`{.variable}\'s type member is present, then set
            this\'s observer type to `"single"`.
    2.  If this\'s observer type is `"single"` and
        `options`{.variable}\'s entryTypes member is present, then
        \[=exception/throw=\] an {{\"InvalidModificationError\"}}.
    3.  If this\'s observer type is `"multiple"` and
        `options`{.variable}\'s type member is present, then
        \[=exception/throw=\] an {{\"InvalidModificationError\"}}.
5.  Set this\'s requires dropped entries to true.
6.  If this\'s observer type is `"multiple"`, run the following steps:
    1.  Let `entry types`{.variable} be `options`{.variable}\'s
        entryTypes sequence.
    2.  Remove all types from `entry types`{.variable} that are not
        contained in `relevantGlobal`{.variable}\'s frozen array of
        supported entry types. The user agent SHOULD notify developers
        if `entry types`{.variable} is modified. For example, a console
        warning listing removed types might be appropriate.
    3.  If the resulting `entry types`{.variable} sequence is an empty
        sequence, abort these steps. The user agent SHOULD notify
        developers when the steps are aborted to notify that
        registration has been aborted. For example, a console warning
        might be appropriate.
    4.  If the list of registered performance observer objects of
        `relevantGlobal`{.variable} contains a registered performance
        observer whose observer is this, replace its options list with a
        list containing `options`{.variable} as its only item.
    5.  Otherwise, create and append a registered performance observer
        object to the list of registered performance observer objects of
        `relevantGlobal`{.variable}, with observer set to this and
        options list set to a list containing `options`{.variable} as
        its only item.
7.  Otherwise, run the following steps:
    1.  Assert that this\'s observer type is `"single"`.
    2.  If `options`{.variable}\'s type is not contained in the
        `relevantGlobal`{.variable}\'s frozen array of supported entry
        types, abort these steps. The user agent SHOULD notify
        developers when this happens, for instance via a console
        warning.
    3.  If the list of registered performance observer objects of
        `relevantGlobal`{.variable} contains a registered performance
        observer `obs`{.variable} whose observer is this:
        1.  If `obs`{.variable}\'s options list contains a
            PerformanceObserverInit item `currentOptions`{.variable}
            whose type is equal to `options`{.variable}\'s type, replace
            `currentOptions`{.variable} with `options`{.variable} in
            `obs`{.variable}\'s options list.
        2.  Otherwise, append `options`{.variable} to
            `obs`{.variable}\'s options list.
    4.  Otherwise, create and append a registered performance observer
        object to the list of registered performance observer objects of
        `relevantGlobal`{.variable}, with observer set to the this and
        options list set to a list containing `options`{.variable} as
        its only item.
    5.  If `options`{.variable}\'s buffered flag is set:
        1.  Let `tuple`{.variable} be the relevant performance entry
            tuple of `options`{.variable}\'s type and
            `relevantGlobal`{.variable}.

        2.  For each `entry`{.variable} in `tuple`{.variable}\'s
            performance entry buffer:

            1.  If [should add
                entry](https://w3c.github.io/timing-entrytypes-registry/#dfn-should-add-entry)
                with `entry`{.variable} and `options`{.variable} as
                parameters returns true, \[=list/append=\]
                `entry`{.variable} to the observer buffer.

        3.  Queue the PerformanceObserver task with
            `relevantGlobal`{.variable} as input.

A PerformanceObserver object needs to always call observe() with
`options`{.variable}\'s [entryTypes]{link-for="PerformanceObserverInit"}
set OR always call observe() with `options`{.variable}\'s
[type]{link-for="PerformanceObserverInit"} set. If one
PerformanceObserver calls observe() with
[entryTypes]{link-for="PerformanceObserverInit"} and also calls observe
with [type]{link-for="PerformanceObserverInit"}, then an exception is
thrown. This is meant to avoid confusion with how calls would stack.
When using [entryTypes]{link-for="PerformanceObserverInit"}, no other
parameters in PerformanceObserverInit can be used. In addition, multiple
observe() calls will override for backwards compatibility and because a
single call should suffice in this case. On the other hand, when using
[type]{link-for="PerformanceObserverInit"}, calls will stack because a
single call can only specify one type. Calling observe() with a repeated
[type]{link-for="PerformanceObserverInit"} will also override.

::: {.section dfn-for="PerformanceObserverInit" link-for="PerformanceObserverInit"}
## [PerformanceObserverInit]{.dfn} dictionary

``` idl

          dictionary PerformanceObserverInit {
            sequence<DOMString> entryTypes;
            DOMString type;
            boolean buffered;
          };
          
```

[entryTypes]{.dfn}
:   A list of entry types to be observed. If present, the list MUST NOT
    be empty and all other members MUST NOT be present. Types not
    recognized by the user agent MUST be ignored.

<!-- -->

[type]{.dfn}
:   A single entry type to be observed. A type that is not recognized by
    the user agent MUST be ignored. Other members may be present.

<!-- -->

[buffered]{.dfn}
:   A flag to indicate whether buffered entries should be queued into
    observer\'s buffer.
:::

:::::: {.section dfn-for="PerformanceObserverEntryList" link-for="PerformanceObserverEntryList"}
## [PerformanceObserverEntryList]{.dfn} interface

``` idl

          [Exposed=(Window,Worker)]
          interface PerformanceObserverEntryList {
            PerformanceEntryList getEntries();
            PerformanceEntryList getEntriesByType (DOMString type);
            PerformanceEntryList getEntriesByName (DOMString name, optional DOMString type);
          };
          
```

Each {{PerformanceObserverEntryList}} object has an associated [entry
list]{.dfn}, which consists of a {{PerformanceEntryList}} and is
initialized upon construction.

::: section
## [getEntries()]{.dfn} method

Returns a PerformanceEntryList object returned by filter buffer by name
and type algorithm with this\'s entry list, `name`{.variable} and
`type`{.variable} set to `null`.
:::

::: section
## [getEntriesByType()]{.dfn} method

Returns a PerformanceEntryList object returned by filter buffer by name
and type algorithm with this\'s entry list, `name`{.variable} set to
`null`, and `type`{.variable} set to the method\'s input `type`
parameter.
:::

::: section
## [getEntriesByName()]{.dfn} method

Returns a PerformanceEntryList object returned by filter buffer by name
and type algorithm with this\'s entry list, `name`{.variable} set to the
method input `name` parameter, and `type`{.variable} set to `null` if
optional \`entryType\` is omitted, or set to the method\'s input `type`
parameter otherwise.
:::
::::::
::::::::

::: section
## [takeRecords()]{.dfn} method

The takeRecords() method must return a copy of this\'s observer buffer,
and also empty this\'s observer buffer.
:::

::: section
## [disconnect()]{.dfn} method

The disconnect() method must do the following:

1.  Remove this from the list of registered performance observer objects
    of relevant global object.
2.  Empty this\'s observer buffer.
3.  Empty this\'s options list.
:::

::: section
## supportedEntryTypes attribute

Each [global object]{data-cite="HTML/webappapis.html#global-object"} has
an associated [frozen array of supported entry types]{.dfn}, which is
initialized to the [FrozenArray]{data-cite="WEBIDL/#es-frozen-array"}
[created]{data-cite="WEBIDL/#dfn-create-frozen-array"} from the sequence
of strings among the
[registry](https://w3c.github.io/timing-entrytypes-registry/#registry)
that are supported for the global object, in alphabetical order.

When [supportedEntryTypes]{.dfn}\'s attribute getter is called, run the
following steps:

1.  Let `globalObject`{.variable} be the [environment settings object\'s
    global
    object]{data-cite="HTML/webappapis.html#concept-settings-object-global"}.
2.  Return `globalObject`{.variable}\'s frozen array of supported entry
    types.

This attribute allows web developers to easily know which entry types
are supported by the user agent.
:::
:::::::::::::

:::::::::: section
## Processing

::: {.section link-for="PerformanceObserver"}
## Queue a `PerformanceEntry`

To [queue a PerformanceEntry]{.dfn .export} (`newEntry`{.variable}), run
these steps:

1.  If `newEntry`{.variable}\'s {{PerformanceEntry/id}} is unset:
    1.  Let `id`{.variable} be the result of running generate an id for
        `newEntry`{.variable}.
    2.  Set `newEntry`{.variable}\'s {{PerformanceEntry/id}} to
        `id`{.variable}.
2.  Let `interested observers`{.variable} be an initially empty set of
    PerformanceObserver objects.
3.  Let `entryType`{.variable} be `newEntry`{.variable}'s
    [entryType]{lt="PerformanceEntry.entryType"} value.
4.  Let `relevantGlobal`{.variable} be `newEntry`{.variable}\'s relevant
    global object.
5.  If `relevantGlobal`{.variable} has an \[=associated document=\]:
    1.  Set `newEntry`{.variable}\'s
        [navigationId]{lt="PerformanceEntry.navigationId"} to the value
        of `relevantGlobal`{.variable}\'s \[=associated document=\]\'s
        \[=most recent navigation=\]\'s {{PerformanceEntry/id}}.
6.  Otherwise, set `newEntry`{.variable}\'s
    [navigationId]{lt="PerformanceEntry.navigationId"} to null.
7.  For each registered performance observer `regObs`{.variable} in
    `relevantGlobal`{.variable}\'s list of registered performance
    observer objects:
    1.  If `regObs`{.variable}\'s options list contains a
        PerformanceObserverInit `options`{.variable} whose
        [entryTypes]{link-for="PerformanceObserverInit"} member includes
        `entryType`{.variable} or whose
        [type]{link-for="PerformanceObserverInit"} member equals to
        `entryType`{.variable}:

        1.  If [should add
            entry](https://w3c.github.io/timing-entrytypes-registry/#dfn-should-add-entry)
            with `newEntry`{.variable} and `options`{.variable} returns
            true, append `regObs`{.variable}\'s observer to
            `interested observers`{.variable}.
8.  For each `observer`{.variable} in `interested observers`{.variable}:
    1.  Append `newEntry`{.variable} to `observer`{.variable}\'s
        observer buffer.
9.  Let `tuple`{.variable} be the relevant performance entry tuple of
    `entryType`{.variable} and `relevantGlobal`{.variable}.
10. Let `isBufferFull`{.variable} be the return value of the determine
    if a performance entry buffer is full algorithm with
    `tuple`{.variable} as input.
11. Let `shouldAdd`{.variable} be the result of [should add
    entry](https://w3c.github.io/timing-entrytypes-registry/#dfn-should-add-entry)
    with `newEntry`{.variable} as input.
12. If `isBufferFull`{.variable} is false and `shouldAdd`{.variable} is
    true, \[=list/append=\] `newEntry`{.variable} to
    `tuple`{.variable}\'s performance entry buffer.
13. Queue the PerformanceObserver task with `relevantGlobal`{.variable}
    as input.
:::

::: {.section link-for="PerformanceObserver"}
## Queue a navigation `PerformanceEntry`

To [queue a navigation PerformanceEntry]{.dfn .export}
(`newEntry`{.variable}), run these steps:

1.  Let `id`{.variable} be the result of running generate an id for
    `newEntry`{.variable}.
2.  Let `relevantGlobal`{.variable} be `newEntry`{.variable}\'s relevant
    global object.
3.  Set `newEntry`{.variable}\'s {{PerformanceEntry/id}} to
    `id`{.variable}.
4.  Set `newEntry`{.variable}\'s {{PerformanceEntry/navigationId}} to
    `id`{.variable}.
5.  If `relevantGlobal`{.variable} has an \[=associated document=\]:
    1.  Set `relevantGlobal`{.variable}\'s \[=associated document=\]\'s
        \[=most recent navigation=\] to `newEntry`{.variable}.
6.  Queue a PerformanceEntry with `newEntry`{.variable} as input.
:::

::: {.section link-for="PerformanceObserver"}
## Queue the PerformanceObserver task

When asked to [queue the PerformanceObserver task]{.dfn}, given
`relevantGlobal`{.variable} as input, run the following steps:

1.  If `relevantGlobal`{.variable}\'s performance observer task queued
    flag is set, terminate these steps.
2.  Set `relevantGlobal`{.variable}\'s performance observer task queued
    flag.
3.  Queue a task that consists of running the following substeps. The
    task source for the queued task is the [performance timeline task
    source]{.dfn .export}.
    1.  Unset performance observer task queued flag of
        `relevantGlobal`{.variable}.
    2.  Let `notifyList`{.variable} be a copy of
        `relevantGlobal`{.variable}\'s list of registered performance
        observer objects.
    3.  For each registered performance observer object
        `registeredObserver`{.variable} in `notifyList`{.variable}, run
        these steps:
        1.  Let `po`{.variable} be `registeredObserver`{.variable}\'s
            observer.
        2.  Let `entries`{.variable} be a copy of `po`{.variable}'s
            observer buffer.
        3.  If `entries`{.variable} is empty, return.
        4.  Empty `po`{.variable}'s observer buffer.
        5.  Let `observerEntryList`{.variable} be a new
            {{PerformanceObserverEntryList}}, with its entry list set to
            `entries`{.variable}.
        6.  Let `droppedEntriesCount`{.variable} be null.
        7.  If `po`{.variable}\'s requires dropped entries is set,
            perform the following steps:
            1.  Set `droppedEntriesCount`{.variable} to 0.
            2.  For each PerformanceObserverInit `item`{.variable} in
                `registeredObserver`{.variable}\'s options list:
                1.  For each
                    [DOMString]{data-cite="WEBIDL#idl-DOMString"}
                    `entryType`{.variable} that appears either as
                    `item`{.variable}\'s
                    [type]{link-for="PerformanceObserverInit"} or in
                    `item`{.variable}\'s
                    [entryTypes]{link-for="PerformanceObserverInit"}:
                    1.  Let `map`{.variable} be
                        `relevantGlobal`{.variable}\'s performance entry
                        buffer map.
                    2.  Let `tuple`{.variable} be the result of getting
                        the value of entry on `map`{.variable} given
                        `entryType`{.variable} as key.
                    3.  Increase `droppedEntriesCount`{.variable} by
                        `tuple`{.variable}\'s dropped entries count.
            3.  Set `po`{.variable}\'s requires dropped entries to
                false.
        8.  Let `callbackOptions`{.variable} be a
            PerformanceObserverCallbackOptions with its
            [droppedEntriesCount]{link-for="PerformanceObserverCallbackOptions"}
            set to `droppedEntriesCount`{.variable} if
            `droppedEntriesCount`{.variable} is not null, otherwise
            unset.
        9.  \[=Invoke=\] `po`{.variable}'s observer callback with «
            `observerEntryList`{.variable}, `po`{.variable},
            `callbackOptions`{.variable} », \"\`report\`\", and
            `po`{.variable}.

The *performance timeline* [task queue]{lt="queue a task"} is a low
priority queue that, if possible, should be processed by the user agent
during idle periods to minimize impact of performance monitoring code.
:::

::: {.section link-for="PerformanceEntry"}
## Filter buffer map by name and type

When asked to run the [filter buffer map by name and type]{.dfn}
algorithm with optional `name`{.variable} and `type`{.variable}, run the
following steps:

1.  Let `result`{.variable} be an initially empty list.
2.  Let `map`{.variable} be the performance entry buffer map associated
    with the relevant global object of this.
3.  Let `tuple list`{.variable} be an empty list.
4.  If `type`{.variable} is not null, append the result of getting the
    value of entry on `map`{.variable} given `type`{.variable} as key to
    `tuple list`{.variable}. Otherwise, assign the result of [get the
    values]{data-cite="INFRA/#map-getting-the-values"} on
    `map`{.variable} to `tuple list`{.variable}.
5.  For each `tuple`{.variable} in `tuple list`{.variable}, run the
    following steps:
    1.  Let `buffer`{.variable} be `tuple`{.variable}\'s performance
        entry buffer.
    2.  If `tuple`{.variable}\'s availableFromTimeline is false,
        continue to the next `tuple`{.variable}.
    3.  Let `entries`{.variable} be the result of running filter buffer
        by name and type with `buffer`{.variable}, `name`{.variable} and
        `type`{.variable} as inputs.
    4.  For each `entry`{.variable} in `entries`{.variable},
        \[=list/append=\] `entry`{.variable} to `result`{.variable}.
6.  Sort `results`{.variable}\'s entries in chronological order with
    respect to startTime
7.  Return `result`{.variable}.
:::

::: {.section link-for="PerformanceEntry"}
## Filter buffer by name and type

When asked to run the [filter buffer by name and type]{.dfn} algorithm,
with `buffer`{.variable}, `name`{.variable}, and `type`{.variable} as
inputs, run the following steps:

1.  Let `result`{.variable} be an initially empty list.
2.  For each PerformanceEntry `entry`{.variable} in `buffer`{.variable},
    run the following steps:
    1.  If `type`{.variable} is not null and if `type`{.variable} is not
        [identical to]{data-cite="INFRA#string-is"}
        `entry`{.variable}\'s `entryType` attribute, continue to next
        `entry`{.variable}.
    2.  If `name`{.variable} is not null and if `name`{.variable} is not
        [identical to]{data-cite="INFRA#string-is"}
        `entry`{.variable}\'s `name` attribute, continue to next
        `entry`{.variable}.
    3.  \[=list/append=\] `entry`{.variable} to `result`{.variable}.
3.  Sort `results`{.variable}\'s entries in chronological order with
    respect to startTime
4.  Return `result`{.variable}.
:::

::: {.section link-for="PerformanceObserver"}
## Determine if a performance entry buffer is full

To [determine if a performance entry buffer is full]{.dfn}, with
`tuple`{.variable} as input, run the following steps:

1.  Let `num current entries`{.variable} be the size of
    `tuple`{.variable}\'s performance entry buffer.
2.  If `num current entries`{.variable} is less than
    `tuples`{.variable}\'s maxBufferSize, return false.
3.  Increase `tuple`{.variable}\'s dropped entries count by 1.
4.  Return true.
:::

::: {.section link-for="PerformanceEntry"}
## Generate a Performance Entry id

When asked to [generate an id]{.dfn .export} for a PerformanceEntry

entry, run the following steps:

1.  Let `relevantGlobal`{.variable} be `entry`{.variable}\'s relevant
    global object.
2.  Increase `relevantGlobal`{.variable}\'s last performance entry id by
    a small number chosen by the user agent.
3.  Return `relevantGlobal`{.variable}\'s last performance entry id.

A user agent may choose to increase the last performance entry idit by a
small random integer every time. A user agent must not pick a single
global random integer and increase the last performance entry id of all
global objects by that amount because this could introduce cross origin
leaks.

The last performance entry id has an initial random value, and is
increased by a small number chosen by the user agent instead of 1 to
discourage developers from considering it as a counter of the number of
entries that have been generated in the web application.
:::
::::::::::

::: {#privacy .section}
### Privacy Considerations

This specification extends the {{Performance}} interface defined by
\[\[HR-TIME-3\]\] and provides methods to queue and retrieve entries
from the performance timeline. Please refer to \[\[HR-TIME-3\]\] for
privacy considerations of exposing high-resoluting timing information.
Each new specification introducing new performance entries should have
its own privacy considerations as well.

The last performance entry id is deliberately initialized to a random
value, and is incremented by another small value every time a new
{{PerformanceEntry}} is queued. User agents may choose to use a
consistent increment for all users, or may pick a different increment
for each global object, or may choose a new random increment for each
{{PerformanceEntry}}. However, in order to prevent cross-origin leaks,
and ensure that this does not enable fingerprinting, user agents must
not just pick a unique random integer, and use it as a consistent
increment for all {{PerformanceEntry}} objects across all global
objects.
:::

::: {#security .section}
### Security Considerations

This specification extends the {{Performance}} interface defined by
\[\[HR-TIME-3\]\] and provides methods to queue and retrieve entries
from the performance timeline. Please refer to \[\[HR-TIME-3\]\] for
security considerations of exposing high-resoluting timing information.
Each new specification introducing new performance entries should have
its own security considerations as well.
:::

::: section
## Dependencies

The \[\[INFRA\]\] specification defines the following: [key]{.dfn
lt="keyed" data-cite="INFRA#map-key"}, [getting the value of an
entry]{.dfn lt="getting the value of entry" data-cite="INFRA#map-get"}.
:::

::: {#idl-index .section .appendix}
:::

::: {.section .appendix}
## Acknowledgments

Thanks to Arvind Jain, Boris Zbarsky, Jatinder Mann, Nat Duca, Philippe
Le Hegaret, Ryosuke Niwa, Shubhie Panicker, Todd Reifsteck, Yoav Weiss,
and Zhiheng Wang, for their contributions to this work.
:::
