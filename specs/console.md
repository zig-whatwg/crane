## Status

This specification is an early work in progress that welcomes feedback to refine toward more precise and compatible definitions. It is also the editors' first specification, so please be kind and constructive.

Please join us in the [issue tracker](https://github.com/whatwg/console/issues) for more discussion.


## Namespace `console`

```idl
[Exposed=*]
namespace console { // but see namespace object requirements below
  // Logging
  undefined assert(optional boolean condition = false, any... data);
  undefined clear();
  undefined debug(any... data);
  undefined error(any... data);
  undefined info(any... data);
  undefined log(any... data);
  undefined table(optional any tabularData, optional sequence<DOMString> properties);
  undefined trace(any... data);
  undefined warn(any... data);
  undefined dir(optional any item, optional object? options);
  undefined dirxml(any... data);

  // Counting
  undefined count(optional DOMString label = "default");
  undefined countReset(optional DOMString label = "default");

  // Grouping
  undefined group(any... data);
  undefined groupCollapsed(any... data);
  undefined groupEnd();

  // Timing
  undefined time(optional DOMString label = "default");
  undefined timeLog(optional DOMString label = "default", any... data);
  undefined timeEnd(optional DOMString label = "default");
};
```

For historical reasons, `console` is lowercased.

It is important that `console` is always visible and usable to scripts, even if the developer console has not been opened or does not exist.

For historical web-compatibility reasons, the namespace object for `console` must have as its [[Prototype]] an empty object, created as if by ObjectCreate(`%ObjectPrototype%`), instead of `%ObjectPrototype%`.


### Logging functions


#### assert(`condition`, ...`data`)

1.  If `condition` is true, return.

2.  Let `message` be a string without any formatting specifiers indicating generically an assertion failure (such as "Assertion failed").

3.  If `data` is empty, append `message` to `data`.

4.  Otherwise:

    1.  Let `first` be `data`[0].

    2.  If `first` is not a String, then prepend `message` to `data`.

    3.  Otherwise:

        1.  Let `concat` be the concatenation of `message`, U+003A (:), U+0020 SPACE, and `first`.

        2.  Set `data`[0] to `concat`.

5.  Perform Logger("assert", `data`).


#### clear()

1.  Empty the appropriate group stack.

2.  If possible for the environment, clear the console. (Otherwise, do nothing.)


#### debug(...`data`)

1.  Perform Logger("debug", `data`).


#### error(...`data`)

1.  Perform Logger("error", `data`).


#### info(...`data`)

1.  Perform Logger("info", `data`).


#### log(...`data`)

1.  Perform Logger("log", `data`).


#### table(`tabularData`, `properties`)

Try to construct a table with the columns of the properties of `tabularData` (or use `properties`) and rows of `tabularData` and log it with a logLevel of "log". Fall back to just logging the argument if it can't be parsed as tabular.

TODO: This will need a good algorithm.


#### trace(...`data`)

1.  Let `trace` be some implementation-defined, potentially-interactive representation of the callstack from where this function was called.

2.  Optionally, let `formattedData` be the result of Formatter(`data`), and incorporate `formattedData` as a label for `trace`.

3.  Perform Printer("trace", « `trace` »).

The identifier of a function printed in a stack trace is implementation-defined. It is also not guaranteed to be the same identifier that would be seen in `new Error().stack`.


#### warn(...`data`)

1.  Perform Logger("warn", `data`).


#### dir(`item`, `options`)

1.  Let `object` be `item` with generic JavaScript object formatting applied.

2.  Perform Printer("dir", « `object` », `options`).


#### dirxml(...`data`)

1.  Let `finalList` be a new list, initially empty.

2.  For each `item` of `data`:

    1.  Let `converted` be a DOM tree representation of `item` if possible; otherwise let `converted` be `item` with optimally useful formatting applied.

    2.  Append `converted` to `finalList`.

3.  Perform Logger("dirxml", `finalList`).


### Counting functions

Each `console` namespace object has an associated count map, which is a map of strings to numbers, initially empty.


#### count(`label`)

1.  Let `map` be the associated count map.

2.  If `map`[`label`] exists, set `map`[`label`] to `map`[`label`] + 1.

3.  Otherwise, set `map`[`label`] to 1.

4.  Let `concat` be the concatenation of `label`, U+003A (:), U+0020 SPACE, and ToString(`map`[`label`]).

5.  Perform Logger("count", « `concat` »).


#### countReset(`label`)

1.  Let `map` be the associated count map.

2.  If `map`[`label`] exists, set `map`[`label`] to 0.

3.  Otherwise:

    1.  Let `message` be a string without any formatting specifiers indicating generically that the given label does not have an associated count.

    2.  Perform Logger("countReset", « `message` »);


### Grouping functions

A group is an implementation-defined, potentially-interactive view for output produced by calls to Printer, with one further level of indentation than its parent. Each `console` namespace object has an associated group stack, which is a stack, initially empty. Only the last group in a group stack will host output produced by calls to Printer.


#### group(...`data`)

1.  Let `group` be a new group.

2.  If `data` is not empty, let `groupLabel` be the result of Formatter(`data`). Otherwise, let `groupLabel` be an implementation-chosen label representing a group.

3.  Incorporate `groupLabel` as a label for `group`.

4.  Optionally, if the environment supports interactive groups, `group` should be expanded by default.

5.  Perform Printer("group", « `group` »).

6.  Push `group` onto the appropriate group stack.


#### groupCollapsed(...`data`)

1.  Let `group` be a new group.

2.  If `data` is not empty, let `groupLabel` be the result of Formatter(`data`). Otherwise, let `groupLabel` be an implementation-chosen label representing a group.

3.  Incorporate `groupLabel` as a label for `group`.

4.  Optionally, if the environment supports interactive groups, `group` should be collapsed by default.

5.  Perform Printer("groupCollapsed", « `group` »).

6.  Push `group` onto the appropriate group stack.


#### groupEnd()

1.  Pop the last group from the group stack.


### Timing functions

Each `console` namespace object has an associated timer table, which is a map of strings to times, initially empty.


#### time(`label`)

1.  If the associated timer table contains an entry with key `label`, return, optionally reporting a warning to the console indicating that a timer with label `label` has already been started.

2.  Otherwise, set the value of the entry with key `label` in the associated timer table to the current time.


#### timeLog(`label`, ...`data`)

1.  Let `timerTable` be the associated timer table.

2.  Let `startTime` be `timerTable`[`label`].

3.  Let `duration` be a string representing the difference between the current time and `startTime`, in an implementation-defined format.

    "4650", "4650.69 ms", "5 seconds", and "00:05" are all reasonable ways of displaying a 4650.69 ms duration.

4.  Let `concat` be the concatenation of `label`, U+003A (:), U+0020 SPACE, and `duration`.

5.  Prepend `concat` to `data`.

6.  Perform Printer("timeLog", data).

The `data` parameter in calls to `timeLog()` is included in the call to Logger to make it easier for users to supply intermediate timer logs with some extra data throughout the life of a timer. For example:

```javascript
console.time("MyTimer");
console.timeLog("MyTimer", "Starting application up…");
// Perhaps some code runs to bootstrap a complex app
// ...
console.timeLog("MyTimer", "UI is setup, making API calls now");
// Perhaps some fetch()'s here filling the app with data
// ...
console.timeEnd("MyTimer");
```


#### timeEnd(`label`)

1.  Let `timerTable` be the associated timer table.

2.  Let `startTime` be `timerTable`[`label`].

3.  Remove `timerTable`[`label`].

4.  Let `duration` be a string representing the difference between the current time and `startTime`, in an implementation-defined format.

5.  Let `concat` be the concatenation of `label`, U+003A (:), U+0020 SPACE, and `duration`.

6.  Perform Printer("timeEnd", « `concat` »).

See whatwg/console#134 for plans to make `timeEnd()` and `timeLog()` formally report warnings to the console when a given `label` does not exist in the associated timer table.


## Supporting abstract operations


### Logger(`logLevel`, `args`)

The logger operation accepts a log level and a [list](https://infra.spec.whatwg.org/#list) of other arguments. Its main output is the [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) side effect of printing the result to the console. This specification describes how it processes format specifiers while doing so.

1.  If `args` is [empty](https://infra.spec.whatwg.org/#list-is-empty), return.

2.  Let `first` be `args`[0].

3.  Let `rest` be all elements following `first` in `args`.

4.  If `rest` is [empty](https://infra.spec.whatwg.org/#list-is-empty), perform Printer(`logLevel`, « `first` ») and return.

5.  Otherwise, perform Printer(`logLevel`, Formatter(`args`)).

6.  Return *undefined*.

Note: It's important that the printing occurs before returning from the algorithm. Many developer consoles print the result of the last operation entered into them. In such consoles, when a developer enters `console.log("hello!")`, this will first print "hello!", then the undefined return value from the console.log call.


### Formatter(`args`)

The formatter operation tries to format the first argument provided, using the other arguments. It will try to format the input until no formatting specifiers are left in the first argument, or no more arguments are left. It returns a [list](https://infra.spec.whatwg.org/#list) of objects suitable for printing.

1.  If `args`'s [size](https://infra.spec.whatwg.org/#list-size) is 1, return `args`.

2.  Let `target` be the first element of `args`.

3.  Let `current` be the second element of `args`.

4.  Find the first possible format specifier `specifier`, from the left to the right in `target`.

5.  If no format specifier was found, return `args`.

6.  Otherwise:

    1.  If `specifier` is `%s`, let `converted` be the result of [Call](https://tc39.github.io/ecma262/#sec-call)([%String%](https://tc39.github.io/ecma262/#sec-string-constructor), **undefined**, « `current` »).

    2.  If `specifier` is `%d` or `%i`:

        1.  If `current` [is a Symbol](https://tc39.github.io/ecma262/#sec-ecmascript-language-types-symbol-type), let `converted` be `NaN`

        2.  Otherwise, let `converted` be the result of [Call](https://tc39.github.io/ecma262/#sec-call)([%parseInt%](https://tc39.github.io/ecma262/#sec-parseint-string-radix), **undefined**, « `current`, 10 »).

    3.  If `specifier` is `%f`:

        1.  If `current` [is a Symbol](https://tc39.github.io/ecma262/#sec-ecmascript-language-types-symbol-type), let `converted` be `NaN`

        2.  Otherwise, let `converted` be the result of [Call](https://tc39.github.io/ecma262/#sec-call)([%parseFloat%](https://tc39.github.io/ecma262/#sec-parsefloat-string), **undefined**, « `current` »).

    4.  If `specifier` is `%o`, optionally let `converted` be `current` with optimally useful formatting applied.

    5.  If `specifier` is `%O`, optionally let `converted` be `current` with generic JavaScript object formatting applied.

    6.  TODO: process %c

    7.  If any of the previous steps set `converted`, replace `specifier` in `target` with `converted`.

7.  Let `result` be a [list](https://infra.spec.whatwg.org/#list) containing `target` together with the elements of `args` starting from the third onward.

8.  Return Formatter(`result`).


#### Summary of formatting specifiers

The following is an informative summary of the format specifiers processed by the above algorithm.

| Specifier | Purpose | Type Conversion |
|-----------|---------|----------------|
| `%s` | Element which substitutes is converted to a string | [%String%](https://tc39.github.io/ecma262/#sec-string-constructor)(`element`) |
| `%d` or `%i` | Element which substitutes is converted to an integer | [%parseInt%](https://tc39.github.io/ecma262/#sec-parseint-string-radix)(`element`, 10) |
| `%f` | Element which substitutes is converted to a float | [%parseFloat%](https://tc39.github.io/ecma262/#sec-parsefloat-string)(`element`, 10) |
| `%o` | Element is displayed with optimally useful formatting | n/a |
| `%O` | Element is displayed with generic JavaScript object formatting | n/a |
| `%c` | Applies provided CSS | n/a |


### Printer(`logLevel`, `args`[, `options`])

The printer operation is [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined). It accepts a log level indicating severity, a List of arguments to print, and an optional object of implementation-specific formatting options. Elements appearing in `args` will be one of the following:

- JavaScript objects of any type.

- Implementation-specific representations of printable things such as a stack trace or group.

- Objects with either generic JavaScript object formatting or optimally useful formatting applied.

If the `options` object is passed, and is not undefined or null, implementations may use `options` to apply [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) formatting to the elements in `args`.

How the implementation prints `args` is up to the implementation, but implementations should separate the objects by a space or something similar, as that has become a developer expectation.

By the time the printer operation is called, all format specifiers will have been taken into account, and any arguments that are meant to be consumed by format specifiers will not be present in `args`. The implementation's job is simply to print the List. The output produced by calls to Printer should appear only within the last group on the appropriate group stack if the group stack is not empty, or elsewhere in the console otherwise.

If the console is not open when the printer operation is called, implementations should buffer messages to show them in the future up to an [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) limit (typically on the order of at least 100).


#### Indicating `logLevel` severity

Each `console` function uses a unique value for the `logLevel` parameter when calling Printer, allowing implementations to customize each printed message depending on the function from which it originated. However, it is common practice to group together certain functions and treat their output similarly, in four broad categories. This table summarizes these common groupings:

| Grouping | `console` functions | Description |
|----------|---------------------|-------------|
| log | `log()`, `trace()`, `dir()`, `dirxml()`, `group()`, `groupCollapsed()`, `debug()`, `timeLog()` | A generic log |
| info | `count()`, `info()`, `timeEnd()` | An informative log |
| warn | `warn()`, `countReset()` | A log warning the user of something indicated by the message |
| error | `error()`, `assert()` | A log indicating an error to the user |

These groupings are meant to document common practices, and do not constrain implementations from providing special behavior for each function, as in the following examples:

Here you can see one implementation chose to make output produced by calls to `timeEnd()` blue, while leaving `info()` a more neutral color.

Calls to `count()` might not always print new output, but instead could update previously-output counts.


#### Printer user experience innovation

Since Printer is [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined), it is common to see UX innovations in its implementations. The following is a non-exhaustive list of potential UX enhancements:

- De-duplication of identical output to prevent spam.

  In this example, the implementation not only batches multiple identical messages, but also provides the number of messages that have been batched together.

- Extra UI off to the side allowing the user to filter messages by log level severity.

- Extra UI off to the side indicating the current state of the timer table, group stack, or other internally maintained data.

- Flashing portions of the console to alert the user of something important.


#### Common object formats

Typically objects will be printed in a format that is suitable for their context. This section describes common ways in which objects are formatted to be most useful in their context. It should be noted that the formatting described in this section is applied to [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) object representations that will eventually be passed into Printer, where the actual side effect of formatting will be seen.

An object with **generic JavaScript object formatting** is a potentially expandable representation of a generic JavaScript object. An object with **optimally useful formatting** is an [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined), potentially-interactive representation of an object judged to be maximally useful and informative.


#### Example printer in Node.js

The simplest way to implement the printer operation on the Node.js platform is to join the previously formatted arguments separated by a space and write the output to `stdout` or `stderr`.

Example implementation in Node.js using [ECMASCRIPT]:

```javascript
const util = require('util');

function print(logLevel, ...args) {
  const message = util.format(...args);

  if (logLevel === 'error') {
    process.stderr.write(message + '\n');
  } else if (logLevel === 'log' || logLevel === 'info' || logLevel === 'warn') {
    process.stdout.write(message + '\n');
  }
}
```

Here a lot of the work is done by the `util.format` function. It stringifies nested objects, and converts non-string arguments into a readable string version, e.g. undefined becomes the string "undefined" and false becomes "false":

```javascript
print('log', 'duck', [{foo: 'bar'}]);     // prints: duck [ { foo: 'bar' } ]\n on stdout
print('log', 'duck', false);              // prints: duck false\n on stdout
print('log', 'duck', undefined);          // prints: duck undefined\n on stdout
```


### Reporting warnings to the console

To **report a warning to the console** given a generic description of a warning `description`, implementations must run these steps:

1.  Let `warning` be an [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) string derived from `description`.

2.  Perform Printer("reportWarning", « `warning` »).