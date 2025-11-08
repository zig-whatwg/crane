## Terminology

This specification depends on the Infra Standard. [INFRA](#biblio-infra "Infra Standard")

Some terms used in this specification are defined in the DOM, Fetch, High Resolution Time, HTML, IDL, Service Workers, URL, and Vibration API Standards. [DOM](#biblio-dom "DOM Standard") [FETCH](#biblio-fetch "Fetch Standard") [HR-TIME](#biblio-hr-time "High Resolution Time") [HTML](#biblio-html "HTML Standard") [WEBIDL](#biblio-webidl "Web IDL Standard") [SERVICE-WORKERS](#biblio-service-workers "Service Workers") [URL](#biblio-url "URL Standard") [VIBRATION](#biblio-vibration "Vibration API")


## Notifications

A **notification** is an abstract representation of something that happened, such as the delivery of a message.

A notification has an associated **service worker registration** (null or a [service worker registration](https://w3c.github.io/ServiceWorker/#dfn-service-worker-registration)). It is initially null.

A notification has an associated **title** (a string).

A notification has an associated **direction** ("`auto`", "`ltr`", or "`rtl`").

A notification has an associated **language** (a string).

A notification has an associated **body** (a string).

A notification has an associated **navigation URL** (null or a [URL](https://url.spec.whatwg.org/#concept-url)). It is initially null.

A notification has an associated **tag** (a string).

A notification has an associated **data** (a [Record](https://tc39.github.io/ecma262/#sec-list-and-record-specification-type)).

A notification has an associated **timestamp** (an [`EpochTimeStamp`](https://w3c.github.io/hr-time/#dom-epochtimestamp)).

Timestamps can be used to indicate the time at which a notification is actual. For example, this could be in the past when a notification is used for a message that couldn't immediately be delivered because the device was offline, or in the future for a meeting that is about to start.

A notification has an associated **origin** (an [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin)).

A notification has an associated **renotify preference** (a boolean). It is initially false. When true, indicates that the end user should be alerted after the notification show steps have run with a new notification that has the same tag as an existing notification.

A notification has an associated **silent preference** (null or a boolean). It is initially null. When true, indicates that no sounds or vibrations should be made. When null, indicates that producing sounds or vibrations should be left to platform conventions.

A notification has an associated **require interaction preference** (a boolean). It is initially false. When true, indicates that on devices with a sufficiently large screen, the notification should remain readily available until the end user activates or dismisses the notification.

A notification *can* have these associated graphics: an **image URL**, **icon URL**, and **badge URL**; and their corresponding **image resource**, **icon resource**, and **badge resource**.

An **image resource** is a picture shown as part of the content of the notification, and should be displayed with higher visual priority than the icon resource and badge resource, though it may be displayed in fewer circumstances.

An **icon resource** is an image that reinforces the notification (such as an icon, or a photo of the sender).

A **badge resource** is an icon representing the web application, or the category of the notification if the web application sends a wide variety of notifications. It *may* be used to represent the notification when there is not enough space to display the notification itself. It *may* also be displayed inside the notification, but then it should have less visual priority than the image resource and icon resource.

A notification has an associated **vibration pattern** (a [list](https://infra.spec.whatwg.org/#list)). It is initially « ».

Developers are encouraged to not convey information through an image, icon, badge, or vibration pattern that is not otherwise accessible to the end user, especially since notification platforms that do not support these features might ignore them.

A notification has associated **actions** (a [list](https://infra.spec.whatwg.org/#list) of zero or more notification actions). A **notification action** represents a choice for an end user. Each notification action has an associated:

**name**
:   A string.

**title**
:   A string.

**navigation URL**
:   Null or a [URL](https://url.spec.whatwg.org/#concept-url). It is initially null.

**icon URL**
:   Null or a [URL](https://url.spec.whatwg.org/#concept-url). It is initially null.

**icon resource**
:   Null or a resource. It is initially null.

Users may activate actions, as alternatives to activating the notification itself. The **maximum number of actions** supported is an [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) integer of zero or more, within the constraints of the notification platform.

Since display of actions is platform-dependent, developers are encouraged to make sure that any action an end user can invoke from a notification is also available within the web application.

Some platforms might modify an icon resource to better match the platform's visual style before displaying it to the end user, for example by rounding the corners or painting it in a specific color. Developers are encouraged to use an icon that handles such cases gracefully and does not lose important information through, e.g., loss of color or clipped corners.

A **non-persistent notification** is a notification whose service worker registration is null.

A **persistent notification** is a notification whose service worker registration is non-null.


To **create a notification with a settings object**, given a string `title`, [`NotificationOptions`](#dictdef-notificationoptions) [dictionary](https://webidl.spec.whatwg.org/#dfn-dictionary) `options`, and [environment settings object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) `settings`:

1.  Let `origin` be `settings`'s [origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-origin).

2.  Let `baseURL` be `settings`'s [API base URL](https://html.spec.whatwg.org/multipage/webappapis.html#api-base-url).

3.  Let `fallbackTimestamp` be the number of milliseconds from the [Unix epoch](https://w3c.github.io/hr-time/#dfn-unix-epoch) to `settings`'s [current wall time](https://w3c.github.io/hr-time/#dfn-eso-current-wall-time), rounded to the nearest integer.

4.  Return the result of creating a notification given `title`, `options`, `origin`, `baseURL`, and `fallbackTimestamp`.

To **create a notification**, given a string `title`, [`NotificationOptions`](#dictdef-notificationoptions) [dictionary](https://webidl.spec.whatwg.org/#dfn-dictionary) `options`, an [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) `origin`, a [URL](https://url.spec.whatwg.org/#concept-url) `baseURL`, and an [`EpochTimeStamp`](https://w3c.github.io/hr-time/#dom-epochtimestamp) `fallbackTimestamp`:

1.  Let `notification` be a new notification.

2.  If `options`["`silent`"] is true and `options`["`vibrate`"] [exists](https://infra.spec.whatwg.org/#map-exists), then [throw](https://webidl.spec.whatwg.org/#dfn-throw) a [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

3.  If `options`["`renotify`"] is true and `options`["`tag`"] is the empty string, then [throw](https://webidl.spec.whatwg.org/#dfn-throw) a [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

4.  Set `notification`'s data to [StructuredSerializeForStorage](https://html.spec.whatwg.org/multipage/structured-data.html#structuredserializeforstorage)(`options`["`data`"]).

5.  Set `notification`'s title to `title`.

6.  Set `notification`'s direction to `options`["`dir`"].

7.  Set `notification`'s language to `options`["`lang`"].

8.  Set `notification`'s origin to `origin`.

9.  Set `notification`'s body to `options`["`body`"].

10. If `options`["`navigate`"] [exists](https://infra.spec.whatwg.org/#map-exists), then [parse](https://url.spec.whatwg.org/#concept-url-parser) it using `baseURL`, and if that does not return failure, set `notification`'s navigation URL to the return value. (Otherwise `notification`'s navigation URL remains null.)

11. Set `notification`'s tag to `options`["`tag`"].

12. If `options`["`image`"] [exists](https://infra.spec.whatwg.org/#map-exists), then [parse](https://url.spec.whatwg.org/#concept-url-parser) it using `baseURL`, and if that does not return failure, set `notification`'s image URL to the return value. (Otherwise `notification`'s image URL is not set.)

13. If `options`["`icon`"] [exists](https://infra.spec.whatwg.org/#map-exists), then [parse](https://url.spec.whatwg.org/#concept-url-parser) it using `baseURL`, and if that does not return failure, set `notification`'s icon URL to the return value. (Otherwise `notification`'s icon URL is not set.)

14. If `options`["`badge`"] [exists](https://infra.spec.whatwg.org/#map-exists), then [parse](https://url.spec.whatwg.org/#concept-url-parser) it using `baseURL`, and if that does not return failure, set `notification`'s badge URL to the return value. (Otherwise `notification`'s badge URL is not set.)

15. If `options`["`vibrate`"] [exists](https://infra.spec.whatwg.org/#map-exists), then [validate and normalize](https://w3c.github.io/vibration/#dfn-validate-and-normalize) it and set `notification`'s vibration pattern to the return value.

16. If `options`["`timestamp`"] [exists](https://infra.spec.whatwg.org/#map-exists), then set `notification`'s timestamp to the value. Otherwise, set `notification`'s timestamp to `fallbackTimestamp`.

17. Set `notification`'s renotify preference to `options`["`renotify`"].

18. Set `notification`'s silent preference to `options`["`silent`"].

19. Set `notification`'s require interaction preference to `options`["`requireInteraction`"].

20. Set `notification`'s actions to « ».

21. For each `entry` in `options`["`actions`"], up to the maximum number of actions supported (skip any excess entries):

    1.  Let `action` be a new notification action.

    2.  Set `action`'s name to `entry`["`action`"].

    3.  Set `action`'s title to `entry`["`title`"].

    4.  If `entry`["`navigate`"] [exists](https://infra.spec.whatwg.org/#map-exists), then [parse](https://url.spec.whatwg.org/#concept-url-parser) it using `baseURL`, and if that does not return failure, set `action`'s navigation URL to the return value. (Otherwise `action`'s navigation URL remains null.)

    5.  If `entry`["`icon`"] [exists](https://infra.spec.whatwg.org/#map-exists), then [parse](https://url.spec.whatwg.org/#concept-url-parser) it using `baseURL`, and if that does not return failure, set `action`'s icon URL to the return value. (Otherwise `action`'s icon URL remains null.)

    6.  Append `action` to `notification`'s actions.

22. Return `notification`.


### Lifetime and UI integration

The user agent must keep a **list of notifications**, which is a [list](https://infra.spec.whatwg.org/#list) of zero or more notifications.

User agents should run the close steps for a non-persistent notification a couple of seconds after they have been created.

User agents should not display non-persistent notification in a platform's "notification center" (if available).

User agents should persist persistent notifications until they are removed from the list of notifications.

A persistent notification could have the `close()` method invoked of one of its `Notification` objects.

User agents should display persistent notifications in a platform's "notification center" (if available).


### Permissions integration

The Notifications API is a [powerful feature](https://w3c.github.io/permissions/#dfn-powerful-feature) which is identified by the [name](https://w3c.github.io/permissions/#dfn-name) "`notifications`". [\[Permissions\]](#biblio-permissions)

To **get the notifications permission state**, run these steps:

1.  Let `permissionState` be the result of [getting the current permission state](https://w3c.github.io/permissions/#dfn-getting-the-current-permission-state) with "`notifications`".

2.  If `permissionState` is "`prompt`", then return "`default`".

3.  Return `permissionState`.


### Direction

This section is written in terms equivalent to those used in the Rendering section of HTML. [\[HTML\]](#biblio-html)

User agents are expected to honor the Unicode semantics of the text of a notification's title, body, and the title of each of its actions. Each is expected to be treated as an independent set of one or more bidirectional algorithm paragraphs when displayed, as defined by the bidirectional algorithm's rules P1, P2, and P3, including, for instance, supporting the paragraph-breaking behavior of U+000A LINE FEED (LF) characters. For each paragraph of the title, body and the title of each of the actions, the notification's direction provides the higher-level override of rules P2 and P3 if it has a value other than "`auto`". [\[BIDI\]](#biblio-bidi)

The notification's direction also determines the relative order in which the notification's actions should be displayed to the end user, if the notification platform displays them side by side.


### Language

The notification's language specifies the primary language for the notification's title, body and the title of each of its actions. Its value is a string. The empty string indicates that the primary language is unknown. Any other string must be interpreted as a language tag. Validity or well-formedness are not enforced. [\[BCP47\]](#biblio-bcp47)

Developers are encouraged to only use valid language tags.


### Resources

The **fetch steps** for a given notification `notification` are:

1.  If the notification platform supports images, [fetch](https://fetch.spec.whatwg.org/#concept-fetch) `notification`'s image URL, if image URL is set.

    The intent is to fetch this resource similar to an [`<img>`](https://html.spec.whatwg.org/multipage/images.html#update-the-image-data), but this [needs abstracting](https://www.w3.org/Bugs/Public/show_bug.cgi?id=24055).

    Then, [in parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

    1.  Wait for the [response](https://fetch.spec.whatwg.org/#concept-response).

    2.  If the [response](https://fetch.spec.whatwg.org/#concept-response)'s [internal response](https://fetch.spec.whatwg.org/#concept-internal-response)'s [type](https://fetch.spec.whatwg.org/#concept-response-type) is "`default`", then attempt to decode the resource as image.

    3.  If the image format is supported, set `notification`'s image resource to the decoded resource. (Otherwise `notification` has no image resource.)

2.  If the notification platform supports icons, [fetch](https://fetch.spec.whatwg.org/#concept-fetch) `notification`'s icon URL, if icon URL is set.

    The intent is to fetch this resource similar to an [`<img>`](https://html.spec.whatwg.org/multipage/images.html#update-the-image-data), but this [needs abstracting](https://www.w3.org/Bugs/Public/show_bug.cgi?id=24055).

    Then, [in parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

    1.  Wait for the [response](https://fetch.spec.whatwg.org/#concept-response).

    2.  If the [response](https://fetch.spec.whatwg.org/#concept-response)'s [internal response](https://fetch.spec.whatwg.org/#concept-internal-response)'s [type](https://fetch.spec.whatwg.org/#concept-response-type) is "`default`", then attempt to decode the resource as image.

    3.  If the image format is supported, set `notification`'s icon resource to the decoded resource. (Otherwise `notification` has no icon resource.)

3.  If the notification platform supports badges, [fetch](https://fetch.spec.whatwg.org/#concept-fetch) `notification`'s badge URL, if badge URL is set.

    The intent is to fetch this resource similar to an [`<img>`](https://html.spec.whatwg.org/multipage/images.html#update-the-image-data), but this [needs abstracting](https://www.w3.org/Bugs/Public/show_bug.cgi?id=24055).

    Then, [in parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

    1.  Wait for the [response](https://fetch.spec.whatwg.org/#concept-response).

    2.  If the [response](https://fetch.spec.whatwg.org/#concept-response)'s [internal response](https://fetch.spec.whatwg.org/#concept-internal-response)'s [type](https://fetch.spec.whatwg.org/#concept-response-type) is "`default`", then attempt to decode the resource as image.

    3.  If the image format is supported, set `notification`'s badge resource to the decoded resource. (Otherwise `notification` has no badge resource.)

4.  If the notification platform supports actions and action icons, then for each `action` in `notification`'s actions: if icon URL is non-null, [fetch](https://fetch.spec.whatwg.org/#concept-fetch) `action`'s icon URL.

    The intent is to fetch this resource similar to an [`<img>`](https://html.spec.whatwg.org/multipage/images.html#update-the-image-data), but this [needs abstracting](https://github.com/whatwg/html/issues/4474).

    Then, [in parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

    1.  Wait for the [response](https://fetch.spec.whatwg.org/#concept-response).

    2.  If the [response](https://fetch.spec.whatwg.org/#concept-response)'s [internal response](https://fetch.spec.whatwg.org/#concept-internal-response)'s [type](https://fetch.spec.whatwg.org/#concept-response-type) is "`default`", then attempt to decode the resource as image.

    3.  If the image format is supported, then set `action`'s icon resource to the decoded resource. (Otherwise `action`'s icon resource remains null.)


### Showing a notification

The **notification show steps** for a given notification `notification` are:

1.  Run the fetch steps for `notification`.

2.  Wait for any [fetches](https://fetch.spec.whatwg.org/#concept-fetch) to complete and `notification`'s image resource, icon resource, and badge resource to be set (if any), as well as the icon resources for the `notification`'s actions (if any).

3.  Let `shown` be false.

4.  Let `oldNotification` be the notification in the list of notifications whose tag is not the empty string and is `notification`'s tag, and whose origin is [same origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin) with `notification`'s origin, if any, and null otherwise.

5.  If `oldNotification` is non-null:

    1.  Handle close events with `oldNotification`.

    2.  If the notification platform supports replacement:

        1.  [Replace](https://infra.spec.whatwg.org/#list-replace) `oldNotification` with `notification`, in the list of notifications.

        2.  Set `shown` to true.

        Notification platforms are strongly encouraged to support native replacement as it leads to a better user experience.

    3.  Otherwise, [remove](https://infra.spec.whatwg.org/#list-remove) `oldNotification` from the list of notifications.

6.  If `shown` is false:

    1.  [Append](https://infra.spec.whatwg.org/#list-append) `notification` to the list of notifications.

    2.  Display `notification` on the device (e.g., by calling the appropriate notification platform API).

7.  If `shown` is false or `oldNotification` is non-null, and `notification`'s renotify preference is true, then run the alert steps for `notification`.

8.  If `notification` is a non-persistent notification, then [queue a task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to [fire an event](https://dom.spec.whatwg.org/#concept-event-fire) named `show` on the `Notification` object representing `notification`.


### Activating a notification

When a notification `notification`, or one of its actions, is activated by the end user, assuming the underlying notification platform supports activation, the user agent must (unless otherwise specified) run these steps:

1.  Let `action` be null.

2.  If one of `notification`'s actions was activated by the end user, then set `action` to that notification action.

3.  Let `navigationURL` be `notification`'s navigation URL.

4.  If `action` is non-null, then set `navigationURL` to `action`'s navigation URL.

    This intentionally makes it so that when a notification action's navigation URL is null, it falls through to the `click` event, providing more flexibility to the web developer.

5.  If `navigationURL` is non-null:

    1.  Select one of the following two options in an [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) manner:

        - [Navigate](https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigate) an existing [top-level traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) within the user agent's [top-level traversable set](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable-set) to `navigationURL`.

        - [Create a fresh top-level traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#create-a-fresh-top-level-traversable) given `navigationURL`.

        User agents are strongly encouraged to match platform conventions.

    2.  Return.

6.  If `notification` is a persistent notification:

    1.  Let `actionName` be the empty string.

    2.  If `action` is non-null, then set `actionName` to `action`'s name.

    3.  Fire a service worker notification event named "`notificationclick`" given `notification` and `actionName`.

7.  Otherwise, [queue a task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run these steps:

    1.  Let `intoFocus` be the result of [firing an event](https://dom.spec.whatwg.org/#concept-event-fire) named `click` on the `Notification` object representing `notification`, with its [`cancelable`](https://dom.spec.whatwg.org/#dom-event-cancelable) attribute initialized to true.

        User agents are encouraged to make [`focus()`](https://html.spec.whatwg.org/multipage/interaction.html#dom-window-focus) work from within the event listener for the event named `click`.

    2.  If `intoFocus` is true, then the user agent should bring the `notification`'s related [browsing context](https://html.spec.whatwg.org/multipage/document-sequences.html#browsing-context)'s viewport into focus.

Throughout the web platform "activate" is intentionally misnamed as "click".


### Closing a notification

When a notification is closed, either by the underlying notification platform or by the end user, the close steps for it must be run.

The **close steps** for a given notification `notification` are:

1.  If the list of notifications does not [contain](https://infra.spec.whatwg.org/#list-contain) `notification`, then abort these steps.

2.  Handle close events with `notification`.

3.  [Remove](https://infra.spec.whatwg.org/#list-remove) `notification` from the list of notifications.

To **handle close events** given a notification `notification`:

1.  If `notification` is a persistent notification and `notification` was closed by the end user, then fire a service worker notification event named "`notificationclose`" given `notification`.

2.  If `notification` is a non-persistent notification, then [queue a task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to [fire an event](https://dom.spec.whatwg.org/#concept-event-fire) named `close` on the `Notification` object representing `notification`.


### Alerting the end user

The **alert steps** for alerting the end user about a given notification `notification` are:

1.  [Perform vibration](https://w3c.github.io/vibration/#dfn-perform-vibration) using `notification`'s vibration pattern, if any.


## API

```idl
[Exposed=(Window,Worker)]
interface Notification : EventTarget {
  constructor(DOMString title, optional NotificationOptions options = {});

  static readonly attribute NotificationPermission permission;
  [Exposed=Window] static Promise<NotificationPermission> requestPermission(optional NotificationPermissionCallback deprecatedCallback);

  static readonly attribute unsigned long maxActions;

  attribute EventHandler onclick;
  attribute EventHandler onshow;
  attribute EventHandler onerror;
  attribute EventHandler onclose;

  readonly attribute DOMString title;
  readonly attribute NotificationDirection dir;
  readonly attribute DOMString lang;
  readonly attribute DOMString body;
  readonly attribute USVString navigate;
  readonly attribute DOMString tag;
  readonly attribute USVString image;
  readonly attribute USVString icon;
  readonly attribute USVString badge;
  [SameObject] readonly attribute FrozenArray<unsigned long> vibrate;
  readonly attribute EpochTimeStamp timestamp;
  readonly attribute boolean renotify;
  readonly attribute boolean? silent;
  readonly attribute boolean requireInteraction;
  [SameObject] readonly attribute any data;
  [SameObject] readonly attribute FrozenArray<NotificationAction> actions;

  undefined close();
};

dictionary NotificationOptions {
  NotificationDirection dir = "auto";
  DOMString lang = "";
  DOMString body = "";
  USVString navigate;
  DOMString tag = "";
  USVString image;
  USVString icon;
  USVString badge;
  VibratePattern vibrate;
  EpochTimeStamp timestamp;
  boolean renotify = false;
  boolean? silent = null;
  boolean requireInteraction = false;
  any data = null;
  sequence<NotificationAction> actions = [];
};

enum NotificationPermission {
  "default",
  "denied",
  "granted"
};

enum NotificationDirection {
  "auto",
  "ltr",
  "rtl"
};

dictionary NotificationAction {
  required DOMString action;
  required DOMString title;
  USVString navigate;
  USVString icon;
};

callback NotificationPermissionCallback = undefined (NotificationPermission permission);
```

A non-persistent notification is represented by one `Notification` object and can be created through `Notification`'s constructor.

A persistent notification is represented by zero or more `Notification` objects and can be created through the `showNotification()` method.


### Garbage collection

A `Notification` object must not be garbage collected while the list of notifications contains its corresponding notification and it has an event listener whose **type** is `click`, `show`, `close`, or `error`.


### Constructors

The `new Notification(title, options)` constructor steps are:

1.  If this's relevant global object is a `ServiceWorkerGlobalScope` object, then throw a `TypeError`.

2.  If `options`["actions"] is not empty, then throw a `TypeError`.

    Actions are only supported for persistent notifications.

3.  Let `notification` be the result of creating a notification with a settings object given `title`, `options`, and this's relevant settings object.

4.  Associate this with `notification`.

5.  Run these steps in parallel:

    1.  If the result of getting the notifications permission state is not "`granted`", then queue a task to fire an event named `error` on this, and abort these steps.

    2.  Run the notification show steps for `notification`.


### Static members

The static `permission` getter steps are to return the result of getting the notifications permission state.

Note: If you edit standards please refrain from copying the above. Synchronous permissions are like synchronous IO, a bad idea.

Developers are encouraged to use the Permissions `query()` method instead. [Permissions]

```
const permission = await navigator.permissions.query({name: "notifications"});
if (permission.state === "granted") {
   // We have permission to use the API…
}
```

The static `requestPermission(deprecatedCallback)` method steps are:

1.  Let `global` be the current global object.

2.  Let `promise` be a new promise in this's relevant Realm.

3.  Run these steps in parallel:

    1.  Let `permissionState` be the result of requesting permission to use "notifications".

    2.  Queue a global task on the DOM manipulation task source given `global` to run these steps:

        1.  If `deprecatedCallback` is given, then invoke `deprecatedCallback` with « `permissionState` » and "`report`".

        2.  Resolve `promise` with `permissionState`.

4.  Return `promise`.

Notifications are the one instance thus far where asking the end user upfront makes sense. Specifications for other APIs should not use this pattern and instead employ one of the many more suitable alternatives.

The static `maxActions` getter steps are to return the maximum number of actions supported.


### Object members

The following are the event handlers (and their corresponding event handler event types) that must be supported as attributes by the `Notification` object.

event handler | event handler event type
---|---
`onclick` | `click`
`onshow` | `show`
`onerror` | `error`
`onclose` | `close`

The `close()` method steps are to run the close steps for this's notification.

The `title` getter steps are to return this's notification's title.

The `dir` getter steps are to return this's notification's direction.

The `lang` getter steps are to return this's notification's language.

The `body` getter steps are to return this's notification's body.

The `navigate` getter steps are:

1.  If this's notification's navigation URL is null, then return the empty string.

2.  Return this's notification's navigation URL, serialized.

The `tag` getter steps are to return this's notification's tag.

The `image` getter steps are:

1.  If there is no this's notification's image URL, then return the empty string.

2.  Return this's notification's image URL, serialized.

The `icon` getter steps are:

1.  If there is no this's notification's icon URL, then return the empty string.

2.  Return this's notification's icon URL, serialized.

The `badge` getter steps are:

1.  If there is no this's notification's badge URL, then return the empty string.

2.  Return this's notification's badge URL, serialized.

The `vibrate` getter steps are to return this's notification's vibration pattern.

The `timestamp` getter steps are to return this's notification's timestamp.

The `renotify` getter steps are to return this's notification's renotify preference.

The `silent` getter steps are to return this's notification's silent preference.

The `requireInteraction` getter steps are to return this's notification's require interaction preference.

The `data` getter steps are to return StructuredDeserialize(this's notification's data, this's relevant Realm). If this throws an exception, then return null.

The `actions` getter steps are:

1.  Let `frozenActions` be an empty list of type `NotificationAction`.

2.  For each `entry` of this's notification's actions:

    1.  Let `action` be a new `NotificationAction`.

    2.  Set `action`["action"] to `entry`'s name.

    3.  Set `action`["title"] to `entry`'s title.

    4.  If `entry`'s navigation URL is non-null, then set `action`["navigate"] to `entry`'s navigation URL, serialized.

    5.  If `entry`'s icon URL is non-null, then set `action`["icon"] to `entry`'s icon URL, serialized.

    6.  Call Object.freeze on `action`, to prevent accidental mutation by scripts.

    7.  Append `action` to `frozenActions`.

3.  Return the result of create a frozen array from `frozenActions`.


### Examples


#### Using events from a page

Non-persistent `Notification` objects dispatch events during their lifecycle, which developers can use to generate desired behaviors.

The `click` event dispatches when the end user activates a notification.

```
var not = new Notification("Gebrünn Gebrünn by Paul Kalkbrenner", { icon: "newsong.svg", tag: "song" });
not.onclick = function() { displaySong(this); };
```


#### Using actions from a service worker

Persistent notifications fire `notificationclick` events on the `ServiceWorkerGlobalScope`.

Here a service worker shows a notification with a single "Archive" notification action, allowing end users to perform this common task from the notification without having to open the website (for example, the notification platform might show a button on the notification). The end user can also activate the main body of the notification to open their inbox.

```
self.registration.showNotification("New mail from Alice", {
  actions: [{action: 'archive', title: "Archive"}]
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  if (event.action === 'archive') {
    silentlyArchiveEmail();
  } else {
    clients.openWindow("/inbox");
  }
}, false);
```


#### Using the `tag` member for multiple instances

Web applications frequently operate concurrently in multiple instances, such as when an end user opens a mail application in multiple browser tabs. Since the desktop is a shared resource, the notifications API provides a way for these instances to easily coordinate, by using the `tag` member.

Notifications which represent the same conceptual event can be tagged in the same way, and when both are shown, the end user will only receive one notification.

```
Instance 1                                   | Instance 2
                                             |
// Instance notices there is new mail.       |
new Notification("New mail from John Doe",   |
                 { tag: 'message1' });       |
                                             |
                                             |  // Slightly later, this instance notices
                                             |  // there is new mail.
                                             |  new Notification("New mail from John Doe",
                                             |                   { tag: 'message1' });
```

The result of this situation, if the user agent follows the algorithms here, is a **single** notification "New mail from John Doe".


#### Using the `tag` member for a single instance

The `tag` member can also be used by a single instance of an application to keep its notifications as current as possible as state changes.

For example, if Alice is using a chat application with Bob, and Bob sends multiple messages while Alice is idle, the application may prefer that Alice not see a desktop notification for each message.

```
// Bob says "Hi"
new Notification("Bob: Hi", { tag: 'chat_Bob' });

// Bob says "Are you free this afternoon?"
new Notification("Bob: Hi / Are you free this afternoon?", { tag: 'chat_Bob' });
```

The result of this situation is a *single* notification; the second one replaces the first having the same tag. In a platform that queues notifications (first-in-first-out), using the tag allows the notification to also maintain its position in the queue. Platforms where the newest notifications are shown first, a similar result could be achieved using the `close()` method.


## Service worker API

```idl
dictionary GetNotificationOptions {
  DOMString tag = "";
};

partial interface ServiceWorkerRegistration {
  Promise<undefined> showNotification(DOMString title, optional NotificationOptions options = {});
  Promise<sequence<Notification>> getNotifications(optional GetNotificationOptions filter = {});
};

[Exposed=ServiceWorker]
interface NotificationEvent : ExtendableEvent {
  constructor(DOMString type, NotificationEventInit eventInitDict);

  readonly attribute Notification notification;
  readonly attribute DOMString action;
};

dictionary NotificationEventInit : ExtendableEventInit {
  required Notification notification;
  DOMString action = "";
};

partial interface ServiceWorkerGlobalScope {
  attribute EventHandler onnotificationclick;
  attribute EventHandler onnotificationclose;
};
```

A service worker registration has an associated **has `showNotification()` been successfully invoked** (a boolean), which is initially false.

This is infrastructure for the Push API standard. [PUSH-API]

The `showNotification(title, options)` method steps are:

1. Let `global` be this's relevant global object.

2. Let `promise` be a new promise in this's relevant Realm.

3. If this's active worker is null, then reject `promise` with a `TypeError` and return `promise`.

4. Let `notification` be the result of creating a notification with a settings object given `title`, `options`, and this's relevant settings object. If this threw an exception, then reject `promise` with that exception and return `promise`.

5. Set `notification`'s service worker registration to this.

6. Run these steps in parallel:

    1. If the result of getting the notifications permission state is not "`granted`", then queue a global task on the DOM manipulation task source given `global` to reject `promise` with a `TypeError`, and abort these steps.

    2. Run the notification show steps for `notification`.

    3. Set `notification`'s service worker registration's has `showNotification()` been successfully invoked to true.

    4. Queue a global task on the DOM manipulation task source given `global` to resolve `promise` with undefined.

7. Return `promise`.

The `getNotifications(filter)` method steps are:

1. Let `global` be this's relevant global object.

2. Let `realm` be this's relevant Realm.

3. Let `origin` be this's relevant settings object's origin.

4. Let `promise` be a new promise in `realm`.

5. Run these steps in parallel:

    1. Let `tag` be `filter`["`tag`"].

    2. Let `notifications` be a list of all notifications in the list of notifications whose origin is same origin with `origin`, whose service worker registration is this, and whose tag, if `tag` is not the empty string, is `tag`.

    3. Queue a global task on the DOM manipulation task source given `global` to run these steps:

        1. Let `objects` be a list.

        2. For each notification in `notifications`, in creation order, create a new `Notification` object with `realm` representing notification, and append it to `objects`.

        3. Resolve `promise` with `objects`.

6. Return `promise`.

This method returns zero or more new `Notification` objects which might represent the same underlying notification of `Notification` objects already in existence.


To **fire a service worker notification event** named `name` given a notification `notification`, and an optional string `action` (default the empty string): run Fire Functional Event given `name`, `NotificationEvent`, `notification`'s service worker registration, and the following initialization:

`notification`
: A new `Notification` object representing `notification`.

`action`
: `action`

The `notification` getter steps are to return the value it was initialized to.

The `action` getter steps are to return the value it was initialized to.

The following is the event handler (and its corresponding event handler event type) that must be supported as attribute by the `ServiceWorkerGlobalScope` object:

| event handler | event handler event type |
|---------------|--------------------------|
| `onnotificationclick` | `notificationclick` |
| `onnotificationclose` | `notificationclose` |