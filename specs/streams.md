# Introduction

*This section is non-normative.*

Large swathes of the web platform are built on streaming data: that is, data that is created, processed, and consumed in an incremental fashion, without ever reading all of it into memory. The Streams Standard provides a common set of APIs for creating and interfacing with such streaming data, embodied in readable streams, writable streams, and transform streams.

These APIs have been designed to efficiently map to low-level I/O primitives, including specializations for byte streams where appropriate. They allow easy composition of multiple streams into pipe chains, or can be used directly via readers and writers. Finally, they are designed to automatically provide backpressure and queuing.

This standard provides the base stream primitives which other parts of the web platform can use to expose their streaming data. For example, [FETCH] exposes `Response` bodies as `ReadableStream` instances. More generally, the platform is full of streaming abstractions waiting to be expressed as streams: multimedia streams, file streams, inter-global communication, and more benefit from being able to process data incrementally instead of buffering it all into memory and processing it in one go. By providing the foundation for these streams to be exposed to developers, the Streams Standard enables use cases like:

- Video effects: piping a readable video stream through a transform stream that applies effects in real time.

- Decompression: piping a file stream through a transform stream that selectively decompresses files from a .tgz archive, turning them into `img` elements as the user scrolls through an image gallery.

- Image decoding: piping an HTTP response stream through a transform stream that decodes bytes into bitmap data, and then through another transform that translates bitmaps into PNGs. If installed inside the `fetch` hook of a service worker, this would allow developers to transparently polyfill new image formats. [SERVICE-WORKERS]

Web developers can also use the APIs described here to create their own streams, with the same APIs as those provided by the platform. Other developers can then transparently compose platform-provided streams with those supplied by libraries. In this way, the APIs described here provide unifying abstraction for all streams, encouraging an ecosystem to grow around these shared and composable interfaces.


## Model

A **chunk** is a single piece of data that is written to or read from a stream. It can be of any type; streams can even contain chunks of different types. A chunk will often not be the most atomic unit of data for a given stream; for example a byte stream might contain chunks consisting of 16 KiB `Uint8Array`s, instead of single bytes.


### Readable streams

A **readable stream** represents a source of data, from which you can read. In other words, data comes *out* of a readable stream. Concretely, a readable stream is an instance of the `ReadableStream` class.

Although a readable stream can be created with arbitrary behavior, most readable streams wrap a lower-level I/O source, called the **underlying source**. There are two types of underlying source: push sources and pull sources.

**Push sources** push data at you, whether or not you are listening for it. They may also provide a mechanism for pausing and resuming the flow of data. An example push source is a TCP socket, where data is constantly being pushed from the OS level, at a rate that can be controlled by changing the TCP window size.

**Pull sources** require you to request data from them. The data may be available synchronously, e.g. if it is held by the operating system's in-memory buffers, or asynchronously, e.g. if it has to be read from disk. An example pull source is a file handle, where you seek to specific locations and read specific amounts.

Readable streams are designed to wrap both types of sources behind a single, unified interface. For web developer--created streams, the implementation details of a source are provided by an object with certain methods and properties that is passed to the `ReadableStream()` constructor.

Chunks are enqueued into the stream by the stream's underlying source. They can then be read one at a time via the stream's public interface, in particular by using a readable stream reader acquired using the stream's `getReader()` method.

Code that reads from a readable stream using its public interface is known as a **consumer**.

Consumers also have the ability to **cancel** a readable stream, using its `cancel()` method. This indicates that the consumer has lost interest in the stream, and will immediately close the stream, throw away any queued chunks, and execute any cancellation mechanism of the underlying source.

Consumers can also **tee** a readable stream using its `tee()` method. This will lock the stream, making it no longer directly usable; however, it will create two new streams, called **branches**, which can be consumed independently.

For streams representing bytes, an extended version of the readable stream is provided to handle bytes efficiently, in particular by minimizing copies. The underlying source for such a readable stream is called an **underlying byte source**. A readable stream whose underlying source is an underlying byte source is sometimes called a **readable byte stream**. Consumers of a readable byte stream can acquire a BYOB reader using the stream's `getReader()` method.


### Writable streams

A **writable stream** represents a destination for data, into which you can write. In other words, data goes *in* to a writable stream. Concretely, a writable stream is an instance of the `WritableStream` class.

Analogously to readable streams, most writable streams wrap a lower-level I/O sink, called the **underlying sink**. Writable streams work to abstract away some of the complexity of the underlying sink, by queuing subsequent writes and only delivering them to the underlying sink one by one.

Chunks are written to the stream via its public interface, and are passed one at a time to the stream's underlying sink. For web developer-created streams, the implementation details of the sink are provided by an object with certain methods that is passed to the `WritableStream()` constructor.

Code that writes into a writable stream using its public interface is known as a **producer**.

Producers also have the ability to **abort** a writable stream, using its `abort()` method. This indicates that the producer believes something has gone wrong, and that future writes should be discontinued. It puts the stream in an errored state, even without a signal from the underlying sink, and it discards all writes in the stream's internal queue.


### Transform streams

A **transform stream** consists of a pair of streams: a writable stream, known as its **writable side**, and a readable stream, known as its **readable side**. In a manner specific to the transform stream in question, writes to the writable side result in new data being made available for reading from the readable side.

Concretely, any object with a `writable` property and a `readable` property can serve as a transform stream. However, the standard `TransformStream` class makes it much easier to create such a pair that is properly entangled. It wraps a **transformer**, which defines algorithms for the specific transformation to be performed. For web developer--created streams, the implementation details of a transformer are provided by an object with certain methods and properties that is passed to the `TransformStream()` constructor. Other specifications might use the `GenericTransformStream` mixin to create classes with the same `writable`/`readable` property pair but other custom APIs layered on top.

An **identity transform stream** is a type of transform stream which forwards all chunks written to its writable side to its readable side, without any changes. This can be useful in a variety of scenarios. By default, the `TransformStream` constructor will create an identity transform stream, when no `transform()` method is present on the transformer object.

Some examples of potential transform streams include:

- A GZIP compressor, to which uncompressed bytes are written and from which compressed bytes are read;

- A video decoder, to which encoded bytes are written and from which uncompressed video frames are read;

- A text decoder, to which bytes are written and from which strings are read;

- A CSV-to-JSON converter, to which strings representing lines of a CSV file are written and from which corresponding JavaScript objects are read.


### Pipe chains and backpressure

Streams are primarily used by **piping** them to each other. A readable stream can be piped directly to a writable stream, using its `pipeTo()` method, or it can be piped through one or more transform streams first, using its `pipeThrough()` method.

A set of streams piped together in this way is referred to as a **pipe chain**. In a pipe chain, the **original source** is the underlying source of the first readable stream in the chain; the **ultimate sink** is the underlying sink of the final writable stream in the chain.

Once a pipe chain is constructed, it will propagate signals regarding how fast chunks should flow through it. If any step in the chain cannot yet accept chunks, it propagates a signal backwards through the pipe chain, until eventually the original source is told to stop producing chunks so fast. This process of normalizing flow from the original source according to how fast the chain can process chunks is called **backpressure**.

Concretely, the original source is given the `controller.desiredSize` (or `byteController.desiredSize`) value, and can then adjust its rate of data flow accordingly. This value is derived from the `writer.desiredSize` corresponding to the ultimate sink, which gets updated as the ultimate sink finishes writing chunks. The `pipeTo()` method used to construct the chain automatically ensures this information propagates back through the pipe chain.

When teeing a readable stream, the backpressure signals from its two branches will aggregate, such that if neither branch is read from, a backpressure signal will be sent to the underlying source of the original stream.

Piping locks the readable and writable streams, preventing them from being manipulated for the duration of the pipe operation. This allows the implementation to perform important optimizations, such as directly shuttling data from the underlying source to the underlying sink while bypassing many of the intermediate queues.


### Internal queues and queuing strategies

Both readable and writable streams maintain **internal queues**, which they use for similar purposes. In the case of a readable stream, the internal queue contains chunks that have been enqueued by the underlying source, but not yet read by the consumer. In the case of a writable stream, the internal queue contains chunks which have been written to the stream by the producer, but not yet processed and acknowledged by the underlying sink.

A **queuing strategy** is an object that determines how a stream should signal backpressure based on the state of its internal queue. The queuing strategy assigns a size to each chunk, and compares the total size of all chunks in the queue to a specified number, known as the **high water mark**. The resulting difference, high water mark minus total size, is used to determine the **desired size to fill the stream's queue**.

For readable streams, an underlying source can use this desired size as a backpressure signal, slowing down chunk generation so as to try to keep the desired size above or at zero. For writable streams, a producer can behave similarly, avoiding writes that would cause the desired size to go negative.

Concretely, a queuing strategy for web developer--created streams is given by any JavaScript object with a `highWaterMark` property. For byte streams the `highWaterMark` always has units of bytes. For other streams the default unit is chunks, but a `size()` function can be included in the strategy object which returns the size for a given chunk. This permits the `highWaterMark` to be specified in arbitrary floating-point units.

A simple example of a queuing strategy would be one that assigns a size of one to each chunk, and has a high water mark of three. This would mean that up to three chunks could be enqueued in a readable stream, or three chunks written to a writable stream, before the streams are considered to be applying backpressure.

In JavaScript, such a strategy could be written manually as `{ highWaterMark: 3, size() { return 1; } }`, or using the built-in `CountQueuingStrategy` class, as `new CountQueuingStrategy({ highWaterMark: 3 })`.


### Locking

A **readable stream reader**, or simply reader, is an object that allows direct reading of chunks from a readable stream. Without a reader, a consumer can only perform high-level operations on the readable stream: canceling the stream, or piping the readable stream to a writable stream. A reader is acquired via the stream's `getReader()` method.

A readable byte stream has the ability to vend two types of readers: **default readers** and **BYOB readers**. BYOB ("bring your own buffer") readers allow reading into a developer-supplied buffer, thus minimizing copies. A non-byte readable stream can only vend default readers. Default readers are instances of the `ReadableStreamDefaultReader` class, while BYOB readers are instances of `ReadableStreamBYOBReader`.

Similarly, a **writable stream writer**, or simply writer, is an object that allows direct writing of chunks to a writable stream. Without a writer, a producer can only perform the high-level operations of aborting the stream or piping a readable stream to the writable stream. Writers are represented by the `WritableStreamDefaultWriter` class.

Under the covers, these high-level operations actually use a reader or writer themselves.

A given readable or writable stream only has at most one reader or writer at a time. We say in this case the stream is **locked**, and that the reader or writer is **active**. This state can be determined using the `readableStream.locked` or `writableStream.locked` properties.

A reader or writer also has the capability to **release its lock**, which makes it no longer active, and allows further readers or writers to be acquired. This is done via the `defaultReader.releaseLock()`, `byobReader.releaseLock()`, or `writer.releaseLock()` method, as appropriate.


## Conventions

This specification depends on the Infra Standard. [INFRA]

This specification uses the abstract operation concept from the JavaScript specification for its internal algorithms. This includes treating their return values as completion records, and the use of ! and ? prefixes for unwrapping those completion records. [ECMASCRIPT]

This specification also uses the internal slot concept and notation from the JavaScript specification. (Although, the internal slots are on Web IDL platform objects instead of on JavaScript objects.)

The reasons for the usage of these foreign JavaScript specification conventions are largely historical. We urge you to avoid following our example when writing your own web specifications.

In this specification, all numbers are represented as double-precision 64-bit IEEE 754 floating point values (like the JavaScript Number type or Web IDL `unrestricted double` type), and all arithmetic operations performed on them must be done in the standard way for such values. This is particularly important for the data structure described in § 8.1 Queue-with-sizes. [IEEE-754]


## Readable streams


### Using readable streams

The simplest way to consume a readable stream is to simply pipe it to a writable stream. This ensures that backpressure is respected, and any errors (either writing or reading) are propagated through the chain:

```
readableStream.pipeTo(writableStream)
  .then(() => console.log("All data successfully written!"))
  .catch(e => console.error("Something went wrong!", e));
```

If you simply want to be alerted of each new chunk from a readable stream, you can pipe it to a new writable stream that you custom-create for that purpose:

```
readableStream.pipeTo(new WritableStream({
  write(chunk) {
    console.log("Chunk received", chunk);
  },
  close() {
    console.log("All data successfully read!");
  },
  abort(e) {
    console.error("Something went wrong!", e);
  }
}));
```

By returning promises from your `write()` implementation, you can signal backpressure to the readable stream.

Although readable streams will usually be used by piping them to a writable stream, you can also read them directly by acquiring a reader and using its `read()` method to get successive chunks. For example, this code logs the next chunk in the stream, if available:

```
const reader = readableStream.getReader();

reader.read().then(
  ({ value, done }) => {
    if (done) {
      console.log("The stream was already closed!");
    } else {
      console.log(value);
    }
  },
  e => console.error("The stream became errored and cannot be read from!", e)
);
```

This more manual method of reading a stream is mainly useful for library authors building new high-level operations on streams, beyond the provided ones of piping and teeing.

The above example showed using the readable stream's default reader. If the stream is a readable byte stream, you can also acquire a BYOB reader for it, which allows more precise control over buffer allocation in order to avoid copies. For example, this code reads the first 1024 bytes from the stream into a single memory buffer:

```
const reader = readableStream.getReader({ mode: "byob" });

let startingAB = new ArrayBuffer(1024);
const buffer = await readInto(startingAB);
console.log("The first 1024 bytes: ", buffer);

async function readInto(buffer) {
  let offset = 0;

  while (offset < buffer.byteLength) {
    const { value: view, done } =
     await reader.read(new Uint8Array(buffer, offset, buffer.byteLength - offset));
    buffer = view.buffer;
    if (done) {
      break;
    }
    offset += view.byteLength;
  }

  return buffer;
}
```

An important thing to note here is that the final `buffer` value is different from the `startingAB`, but it (and all intermediate buffers) shares the same backing memory allocation. At each step, the buffer is transferred to a new `ArrayBuffer` object. The `view` is destructured from the return value of reading a new `Uint8Array`, with that `ArrayBuffer` object as its `buffer` property, the offset that bytes were written to as its `byteOffset` property, and the number of bytes that were written as its `byteLength` property.

Note that this example is mostly educational. For practical purposes, the `min` option of `read()` provides an easier and more direct way to read an exact number of bytes:

```
const reader = readableStream.getReader({ mode: "byob" });
const { value: view, done } = await reader.read(new Uint8Array(1024), { min: 1024 });
console.log("The first 1024 bytes: ", view);
```


### The `ReadableStream` class

The `ReadableStream` class is a concrete instance of the general readable stream concept. It is adaptable to any chunk type, and maintains an internal queue to keep track of data supplied by the underlying source but not yet read by any consumer.


#### Interface definition

The Web IDL definition for the `ReadableStream` class is given as follows:

```
[Exposed=*, Transferable]
interface ReadableStream {
  constructor(optional object underlyingSource, optional QueuingStrategy strategy = {});

  static ReadableStream from(any asyncIterable);

  readonly attribute boolean locked;

  Promise<undefined> cancel(optional any reason);
  ReadableStreamReader getReader(optional ReadableStreamGetReaderOptions options = {});
  ReadableStream pipeThrough(ReadableWritablePair transform, optional StreamPipeOptions options = {});
  Promise<undefined> pipeTo(WritableStream destination, optional StreamPipeOptions options = {});
  sequence<ReadableStream> tee();

  async_iterable<any>(optional ReadableStreamIteratorOptions options = {});
};

typedef (ReadableStreamDefaultReader or ReadableStreamBYOBReader) ReadableStreamReader;

enum ReadableStreamReaderMode { "byob" };

dictionary ReadableStreamGetReaderOptions {
  ReadableStreamReaderMode mode;
};

dictionary ReadableStreamIteratorOptions {
  boolean preventCancel = false;
};

dictionary ReadableWritablePair {
  required ReadableStream readable;
  required WritableStream writable;
};

dictionary StreamPipeOptions {
  boolean preventClose = false;
  boolean preventAbort = false;
  boolean preventCancel = false;
  AbortSignal signal;
};
```


#### Internal slots

Instances of `ReadableStream` are created with the internal slots described in the following table:

| Internal Slot | Description (*non-normative*) |
|---|---|
| [[controller]] | A `ReadableStreamDefaultController` or `ReadableByteStreamController` created with the ability to control the state and queue of this stream |
| [[Detached]] | A boolean flag set to true when the stream is transferred |
| [[disturbed]] | A boolean flag set to true when the stream has been read from or canceled |
| [[reader]] | A `ReadableStreamDefaultReader` or `ReadableStreamBYOBReader` instance, if the stream is locked to a reader, or undefined if it is not |
| [[state]] | A string containing the stream's current state, used internally; one of "`readable`", "`closed`", or "`errored`" |
| [[storedError]] | A value indicating how the stream failed, to be given as a failure reason or exception when trying to operate on an errored stream |


#### The underlying source API

The `ReadableStream()` constructor accepts as its first argument a JavaScript object representing the underlying source. Such objects can contain any of the following properties:

```
dictionary UnderlyingSource {
  UnderlyingSourceStartCallback start;
  UnderlyingSourcePullCallback pull;
  UnderlyingSourceCancelCallback cancel;
  ReadableStreamType type;
  [EnforceRange] unsigned long long autoAllocateChunkSize;
};

typedef (ReadableStreamDefaultController or ReadableByteStreamController) ReadableStreamController;

callback UnderlyingSourceStartCallback = any (ReadableStreamController controller);
callback UnderlyingSourcePullCallback = Promise<undefined> (ReadableStreamController controller);
callback UnderlyingSourceCancelCallback = Promise<undefined> (optional any reason);

enum ReadableStreamType { "bytes" };
```

**`start(controller)`**, of type UnderlyingSourceStartCallback

A function that is called immediately during creation of the `ReadableStream`.

Typically this is used to adapt a push source by setting up relevant event listeners, as in the example of § 10.1 A readable stream with an underlying push source (no backpressure support), or to acquire access to a pull source, as in § 10.4 A readable stream with an underlying pull source.

If this setup process is asynchronous, it can return a promise to signal success or failure; a rejected promise will error the stream. Any thrown exceptions will be re-thrown by the `ReadableStream()` constructor.

**`pull(controller)`**, of type UnderlyingSourcePullCallback

A function that is called whenever the stream's internal queue of chunks becomes not full, i.e. whenever the queue's desired size becomes positive. Generally, it will be called repeatedly until the queue reaches its high water mark (i.e. until the desired size becomes non-positive).

For push sources, this can be used to resume a paused flow, as in § 10.2 A readable stream with an underlying push source and backpressure support. For pull sources, it is used to acquire new chunks to enqueue into the stream, as in § 10.4 A readable stream with an underlying pull source.

This function will not be called until `start()` successfully completes. Additionally, it will only be called repeatedly if it enqueues at least one chunk or fulfills a BYOB request; a no-op `pull()` implementation will not be continually called.

If the function returns a promise, then it will not be called again until that promise fulfills. (If the promise rejects, the stream will become errored.) This is mainly used in the case of pull sources, where the promise returned represents the process of acquiring a new chunk. Throwing an exception is treated the same as returning a rejected promise.

**`cancel(reason)`**, of type UnderlyingSourceCancelCallback

A function that is called whenever the consumer cancels the stream, via `stream.cancel()` or `reader.cancel()`. It takes as its argument the same value as was passed to those methods by the consumer.

Readable streams can additionally be canceled under certain conditions during piping; see the definition of the `pipeTo()` method for more details.

For all streams, this is generally used to release access to the underlying resource; see for example § 10.1 A readable stream with an underlying push source (no backpressure support).

If the shutdown process is asynchronous, it can return a promise to signal success or failure; the result will be communicated via the return value of the `cancel()` method that was called. Throwing an exception is treated the same as returning a rejected promise.

Even if the cancelation process fails, the stream will still close; it will not be put into an errored state. This is because a failure in the cancelation process doesn't matter to the consumer's view of the stream, once they've expressed disinterest in it by canceling. The failure is only communicated to the immediate caller of the corresponding method.

This is different from the behavior of the `close` and `abort` options of a `WritableStream`'s underlying sink, which upon failure put the corresponding `WritableStream` into an errored state. Those correspond to specific actions the producer is requesting and, if those actions fail, they indicate something more persistently wrong.

**`type`** (byte streams only), of type ReadableStreamType

Can be set to "`bytes`" to signal that the constructed `ReadableStream` is a readable byte stream. This ensures that the resulting `ReadableStream` will successfully be able to vend BYOB readers via its `getReader()` method. It also affects the `controller` argument passed to the `start()` and `pull()` methods; see below.

For an example of how to set up a readable byte stream, including using the different controller interface, see § 10.3 A readable byte stream with an underlying push source (no backpressure support).

Setting any value other than "`bytes`" or undefined will cause the `ReadableStream()` constructor to throw an exception.

**`autoAllocateChunkSize`** (byte streams only), of type unsigned long long

Can be set to a positive integer to cause the implementation to automatically allocate buffers for the underlying source code to write into. In this case, when a consumer is using a default reader, the stream implementation will automatically allocate an `ArrayBuffer` of the given size, so that `controller.byobRequest` is always present, as if the consumer was using a BYOB reader.

This is generally used to cut down on the amount of code needed to handle consumers that use default readers, as can be seen by comparing § 10.3 A readable byte stream with an underlying push source (no backpressure support) without auto-allocation to § 10.5 A readable byte stream with an underlying pull source with auto-allocation.

The type of the `controller` argument passed to the `start()` and `pull()` methods depends on the value of the `type` option. If `type` is set to undefined (including via omission), then `controller` will be a `ReadableStreamDefaultController`. If it's set to "`bytes`", then `controller` will be a `ReadableByteStreamController`.


#### Constructor, methods, and properties

`stream = new ReadableStream(underlyingSource[, strategy])`

Creates a new `ReadableStream` wrapping the provided underlying source. See § 4.2.3 The underlying source API for more details on the `underlyingSource` argument.

The `strategy` argument represents the stream's queuing strategy, as described in § 7.1 The queuing strategy API. If it is not provided, the default behavior will be the same as a `CountQueuingStrategy` with a high water mark of 1.

`stream = ReadableStream.from(asyncIterable)`

Creates a new `ReadableStream` wrapping the provided iterable or async iterable.

This can be used to adapt various kinds of objects into a readable stream, such as an array, an async generator, or a Node.js readable stream.

`isLocked = stream.locked`

Returns whether or not the readable stream is locked to a reader.

`await stream.cancel([ reason ])`

Cancels the stream, signaling a loss of interest in the stream by a consumer. The supplied `reason` argument will be given to the underlying source's `cancel()` method, which might or might not use it.

The returned promise will fulfill if the stream shuts down successfully, or reject if the underlying source signaled that there was an error doing so. Additionally, it will reject with a `TypeError` (without attempting to cancel the stream) if the stream is currently locked.

`reader = stream.getReader()`

Creates a `ReadableStreamDefaultReader` and locks the stream to the new reader. While the stream is locked, no other reader can be acquired until this one is released.

This functionality is especially useful for creating abstractions that desire the ability to consume a stream in its entirety. By getting a reader for the stream, you can ensure nobody else can interleave reads with yours or cancel the stream, which would interfere with your abstraction.

`reader = stream.getReader({ mode: "byob" })`

Creates a `ReadableStreamBYOBReader` and locks the stream to the new reader.

This call behaves the same way as the no-argument variant, except that it only works on readable byte streams, i.e. streams which were constructed specifically with the ability to handle "bring your own buffer" reading. The returned BYOB reader provides the ability to directly read individual chunks from the stream via its `read()` method, into developer-supplied buffers, allowing more precise control over allocation.

`readable = stream.pipeThrough({ writable, readable }[, { preventClose, preventAbort, preventCancel, signal }])`

Provides a convenient, chainable way of piping this readable stream through a transform stream (or any other `{ writable, readable }` pair). It simply pipes the stream into the writable side of the supplied pair, and returns the readable side for further use.

Piping a stream will lock it for the duration of the pipe, preventing any other consumer from acquiring a reader.

`await stream.pipeTo(destination[, { preventClose, preventAbort, preventCancel, signal }])`

Pipes this readable stream to a given writable stream `destination`. The way in which the piping process behaves under various error conditions can be customized with a number of passed options. It returns a promise that fulfills when the piping process completes successfully, or rejects if any errors were encountered.

Piping a stream will lock it for the duration of the pipe, preventing any other consumer from acquiring a reader.

Errors and closures of the source and destination streams propagate as follows:

- An error in this source readable stream will abort `destination`, unless `preventAbort` is truthy. The returned promise will be rejected with the source's error, or with any error that occurs during aborting the destination.

- An error in `destination` will cancel this source readable stream, unless `preventCancel` is truthy. The returned promise will be rejected with the destination's error, or with any error that occurs during canceling the source.

- When this source readable stream closes, `destination` will be closed, unless `preventClose` is truthy. The returned promise will be fulfilled once this process completes, unless an error is encountered while closing the destination, in which case it will be rejected with that error.

- If `destination` starts out closed or closing, this source readable stream will be canceled, unless `preventCancel` is true. The returned promise will be rejected with an error indicating piping to a closed stream failed, or with any error that occurs during canceling the source.

The `signal` option can be set to an `AbortSignal` to allow aborting an ongoing pipe operation via the corresponding `AbortController`. In this case, this source readable stream will be canceled, and `destination` aborted, unless the respective options `preventCancel` or `preventAbort` are set.

`[branch1, branch2] = stream.tee()`

Tees this readable stream, returning a two-element array containing the two resulting branches as new `ReadableStream` instances.

Teeing a stream will lock it, preventing any other consumer from acquiring a reader. To cancel the stream, cancel both of the resulting branches; a composite cancellation reason will then be propagated to the stream's underlying source.

If this stream is a readable byte stream, then each branch will receive its own copy of each chunk. If not, then the chunks seen in each branch will be the same object. If the chunks are not immutable, this could allow interference between the two branches.

The `new ReadableStream(underlyingSource, strategy)` constructor steps are:

1. If `underlyingSource` is missing, set it to null.

2. Let `underlyingSourceDict` be `underlyingSource`, converted to an IDL value of type `UnderlyingSource`.

We cannot declare the `underlyingSource` argument as having the `UnderlyingSource` type directly, because doing so would lose the reference to the original object. We need to retain the object so we can invoke the various methods on it.

3. Perform ! InitializeReadableStream(this).

4. If `underlyingSourceDict`["`type`"] is "`bytes`":

   1. If `strategy`["`size`"] exists, throw a `RangeError` exception.

   2. Let `highWaterMark` be ? ExtractHighWaterMark(`strategy`, 0).

   3. Perform ? SetUpReadableByteStreamControllerFromUnderlyingSource(this, `underlyingSource`, `underlyingSourceDict`, `highWaterMark`).

5. Otherwise,

   1. Assert: `underlyingSourceDict`["`type`"] does not exist.

   2. Let `sizeAlgorithm` be ! ExtractSizeAlgorithm(`strategy`).

   3. Let `highWaterMark` be ? ExtractHighWaterMark(`strategy`, 1).

   4. Perform ? SetUpReadableStreamDefaultControllerFromUnderlyingSource(this, `underlyingSource`, `underlyingSourceDict`, `highWaterMark`, `sizeAlgorithm`).

The static `from(asyncIterable)` method steps are:

1. Return ? ReadableStreamFromIterable(`asyncIterable`).

The `locked` getter steps are:

1. Return ! IsReadableStreamLocked(this).

The `cancel(reason)` method steps are:

1. If ! IsReadableStreamLocked(this) is true, return a promise rejected with a `TypeError` exception.

2. Return ! ReadableStreamCancel(this, `reason`).

The `getReader(options)` method steps are:

1. If `options`["`mode`"] does not exist, return ? AcquireReadableStreamDefaultReader(this).

2. Assert: `options`["`mode`"] is "`byob`".

3. Return ? AcquireReadableStreamBYOBReader(this).

An example of an abstraction that might benefit from using a reader is a function like the following, which is designed to read an entire readable stream into memory as an array of chunks.

```
function readAllChunks(readableStream) {
  const reader = readableStream.getReader();
  const chunks = [];

  return pump();

  function pump() {
    return reader.read().then(({ value, done }) => {
      if (done) {
        return chunks;
      }

      chunks.push(value);
      return pump();
    });
  }
}
```

Note how the first thing it does is obtain a reader, and from then on it uses the reader exclusively. This ensures that no other consumer can interfere with the stream, either by reading chunks or by canceling the stream.

The `pipeThrough(transform, options)` method steps are:

1. If ! IsReadableStreamLocked(this) is true, throw a `TypeError` exception.

2. If ! IsWritableStreamLocked(`transform`["`writable`"]) is true, throw a `TypeError` exception.

3. Let `signal` be `options`["`signal`"] if it exists, or undefined otherwise.

4. Let `promise` be ! ReadableStreamPipeTo(this, `transform`["`writable`"], `options`["`preventClose`"], `options`["`preventAbort`"], `options`["`preventCancel`"], `signal`).

5. Set `promise`.[[PromiseIsHandled]] to true.

6. Return `transform`["`readable`"].

A typical example of constructing pipe chain using `pipeThrough(transform, options)` would look like

```
httpResponseBody
  .pipeThrough(decompressorTransform)
  .pipeThrough(ignoreNonImageFilesTransform)
  .pipeTo(mediaGallery);
```

The `pipeTo(destination, options)` method steps are:

1. If ! IsReadableStreamLocked(this) is true, return a promise rejected with a `TypeError` exception.

2. If ! IsWritableStreamLocked(`destination`) is true, return a promise rejected with a `TypeError` exception.

3. Let `signal` be `options`["`signal`"] if it exists, or undefined otherwise.

4. Return ! ReadableStreamPipeTo(this, `destination`, `options`["`preventClose`"], `options`["`preventAbort`"], `options`["`preventCancel`"], `signal`).

An ongoing pipe operation can be stopped using an `AbortSignal`, as follows:

```
const controller = new AbortController();
readable.pipeTo(writable, { signal: controller.signal });

// ... some time later ...
controller.abort();
```

(The above omits error handling for the promise returned by `pipeTo()`. Additionally, the impact of the `preventAbort` and `preventCancel` options what happens when piping is stopped are worth considering.)

The above technique can be used to switch the `ReadableStream` being piped, while writing into the same `WritableStream`:

```
const controller = new AbortController();
const pipePromise = readable1.pipeTo(writable, { preventAbort: true, signal: controller.signal });

// ... some time later ...
controller.abort();

// Wait for the pipe to complete before starting a new one:
try {
 await pipePromise;
} catch (e) {
 // Swallow "AbortError" DOMExceptions as expected, but rethrow any unexpected failures.
 if (e.name !== "AbortError") {
  throw e;
 }
}

// Start the new pipe!
readable2.pipeTo(writable);
```

The `tee()` method steps are:

1. Return ? ReadableStreamTee(this, false).

Teeing a stream is most useful when you wish to let two independent consumers read from the stream in parallel, perhaps even at different speeds. For example, given a writable stream `cacheEntry` representing an on-disk file, and another writable stream `httpRequestBody` representing an upload to a remote server, you could pipe the same readable stream to both destinations at once:

```
const [forLocal, forRemote] = readableStream.tee();

Promise.all([
  forLocal.pipeTo(cacheEntry),
  forRemote.pipeTo(httpRequestBody)
])
.then(() => console.log("Saved the stream to the cache and also uploaded it!"))
.catch(e => console.error("Either caching or uploading failed: ", e));
```


#### Asynchronous iteration

`for await (const chunk of stream) { ... }`
`for await (const chunk of stream.values({ preventCancel: true })) { ... }`

Asynchronously iterates over the chunks in the stream's internal queue.

Asynchronously iterating over the stream will lock it, preventing any other consumer from acquiring a reader. The lock will be released if the async iterator's `return()` method is called, e.g. by `break`ing out of the loop.

By default, calling the async iterator's `return()` method will also cancel the stream. To prevent this, use the stream's `values()` method, passing true for the `preventCancel` option.

The asynchronous iterator initialization steps for a `ReadableStream`, given `stream`, `iterator`, and `args`, are:

1. Let `reader` be ? AcquireReadableStreamDefaultReader(`stream`).

2. Set `iterator`'s reader to `reader`.

3. Let `preventCancel` be `args`[0]["`preventCancel`"].

4. Set `iterator`'s prevent cancel to `preventCancel`.

The get the next iteration result steps for a `ReadableStream`, given `stream` and `iterator`, are:

1. Let `reader` be `iterator`'s reader.

2. Assert: `reader`.[[stream]] is not undefined.

3. Let `promise` be a new promise.

4. Let `readRequest` be a new read request with the following items:

   chunk steps, given `chunk`

   1. Resolve `promise` with `chunk`.

   close steps

   1. Perform ! ReadableStreamDefaultReaderRelease(`reader`).

   2. Resolve `promise` with end of iteration.

   error steps, given `e`

   1. Perform ! ReadableStreamDefaultReaderRelease(`reader`).

   2. Reject `promise` with `e`.

5. Perform ! ReadableStreamDefaultReaderRead(this, `readRequest`).

6. Return `promise`.

The asynchronous iterator return steps for a `ReadableStream`, given `stream`, `iterator`, and `arg`, are:

1. Let `reader` be `iterator`'s reader.

2. Assert: `reader`.[[stream]] is not undefined.

3. Assert: `reader`.[[readRequests]] is empty, as the async iterator machinery guarantees that any previous calls to `next()` have settled before this is called.

4. If `iterator`'s prevent cancel is false:

   1. Let `result` be ! ReadableStreamReaderGenericCancel(`reader`, `arg`).

   2. Perform ! ReadableStreamDefaultReaderRelease(`reader`).

   3. Return `result`.

5. Perform ! ReadableStreamDefaultReaderRelease(`reader`).

6. Return a promise resolved with undefined.


#### Transfer via `postMessage()`

`destination.postMessage(rs, { transfer: [rs] });`

Sends a `ReadableStream` to another frame, window, or worker.

The transferred stream can be used exactly like the original. The original will become locked and no longer directly usable.

`ReadableStream` objects are transferable objects. Their transfer steps, given `value` and `dataHolder`, are:

1. If ! IsReadableStreamLocked(`value`) is true, throw a "`DataCloneError`" `DOMException`.

2. Let `port1` be a new `MessagePort` in the current Realm.

3. Let `port2` be a new `MessagePort` in the current Realm.

4. Entangle `port1` and `port2`.

5. Let `writable` be a new `WritableStream` in the current Realm.

6. Perform ! SetUpCrossRealmTransformWritable(`writable`, `port1`).

7. Let `promise` be ! ReadableStreamPipeTo(`value`, `writable`, false, false, false).

8. Set `promise`.[[PromiseIsHandled]] to true.

9. Set `dataHolder`.[[port]] to ! StructuredSerializeWithTransfer(`port2`, « `port2` »).

Their transfer-receiving steps, given `dataHolder` and `value`, are:

1. Let `deserializedRecord` be ! StructuredDeserializeWithTransfer(`dataHolder`.[[port]], the current Realm).

2. Let `port` be `deserializedRecord`.[[Deserialized]].

3. Perform ! SetUpCrossRealmTransformReadable(`value`, `port`).


### The `ReadableStreamGenericReader` mixin

The `ReadableStreamGenericReader` mixin defines common internal slots, getters and methods that are shared between `ReadableStreamDefaultReader` and `ReadableStreamBYOBReader` objects.


#### Mixin definition

The Web IDL definition for the `ReadableStreamGenericReader` mixin is given as follows:

```
interface mixin ReadableStreamGenericReader {
  readonly attribute Promise<undefined> closed;

  Promise<undefined> cancel(optional any reason);
};
```


#### Internal slots

Instances of classes including the `ReadableStreamGenericReader` mixin are created with the internal slots described in the following table:

| Internal Slot | Description (*non-normative*) |
|---|---|
| [[closedPromise]] | A promise returned by the reader's `closed` getter |
| [[stream]] | A `ReadableStream` instance that owns this reader |


#### Methods and properties

The `closed` getter steps are:

1. Return this.[[closedPromise]].

The `cancel(reason)` method steps are:

1. If this.[[stream]] is undefined, return a promise rejected with a `TypeError` exception.

2. Return ! ReadableStreamReaderGenericCancel(this, `reason`).


### The `ReadableStreamDefaultReader` class

The `ReadableStreamDefaultReader` class represents a default reader designed to be vended by a `ReadableStream` instance.


#### Interface definition

The Web IDL definition for the `ReadableStreamDefaultReader` class is given as follows:

```
[Exposed=*]
interface ReadableStreamDefaultReader {
  constructor(ReadableStream stream);

  Promise<ReadableStreamReadResult> read();
  undefined releaseLock();
};
ReadableStreamDefaultReader includes ReadableStreamGenericReader;

dictionary ReadableStreamReadResult {
  any value;
  boolean done;
};
```


#### Internal slots

Instances of `ReadableStreamDefaultReader` are created with the internal slots defined by `ReadableStreamGenericReader`, and those described in the following table:

| Internal Slot | Description (*non-normative*) |
|---|---|
| [[readRequests]] | A list of read requests, used when a consumer requests chunks sooner than they are available |

A read request is a struct containing three algorithms to perform in reaction to filling the readable stream's internal queue or changing its state. It has the following items:

**chunk steps**

An algorithm taking a chunk, called when a chunk is available for reading

**close steps**

An algorithm taking no arguments, called when no chunks are available because the stream is closed

**error steps**

An algorithm taking a JavaScript value, called when no chunks are available because the stream is errored


#### Constructor, methods, and properties

`reader = new ReadableStreamDefaultReader(stream)`

This is equivalent to calling `stream.getReader()`.

`await reader.closed`

Returns a promise that will be fulfilled when the stream becomes closed, or rejected if the stream ever errors or the reader's lock is released before the stream finishes closing.

`await reader.cancel([ reason ])`

If the reader is active, behaves the same as `stream.cancel(reason)`.

`{ value, done } = await reader.read()`

Returns a promise that allows access to the next chunk from the stream's internal queue, if available.

- If the chunk does become available, the promise will be fulfilled with an object of the form `{ value: theChunk, done: false }`.
- If the stream becomes closed, the promise will be fulfilled with an object of the form `{ value: undefined, done: true }`.
- If the stream becomes errored, the promise will be rejected with the relevant error.

If reading a chunk causes the queue to become empty, more data will be pulled from the underlying source.

`reader.releaseLock()`

Releases the reader's lock on the corresponding stream. After the lock is released, the reader is no longer active. If the associated stream is errored when the lock is released, the reader will appear errored in the same way from now on; otherwise, the reader will appear closed.

If the reader's lock is released while it still has pending read requests, then the promises returned by the reader's `read()` method are immediately rejected with a `TypeError`. Any unread chunks remain in the stream's internal queue and can be read later by acquiring a new reader.

The `new ReadableStreamDefaultReader(stream)` constructor steps are:

1. Perform ? SetUpReadableStreamDefaultReader(this, `stream`).

The `read()` method steps are:

1. If this.[[stream]] is undefined, return a promise rejected with a `TypeError` exception.

2. Let `promise` be a new promise.

3. Let `readRequest` be a new read request with the following items:

   chunk steps, given `chunk`

   1. Resolve `promise` with «[ "`value`" → `chunk`, "`done`" → false ]».

   close steps

   1. Resolve `promise` with «[ "`value`" → undefined, "`done`" → true ]».

   error steps, given `e`

   1. Reject `promise` with `e`.

4. Perform ! ReadableStreamDefaultReaderRead(this, `readRequest`).

5. Return `promise`.

The `releaseLock()` method steps are:

1. If this.[[stream]] is undefined, return.

2. Perform ! ReadableStreamDefaultReaderRelease(this).


### The `ReadableStreamBYOBReader` class

The `ReadableStreamBYOBReader` class represents a BYOB reader designed to be vended by a `ReadableStream` instance.


#### Interface definition

The Web IDL definition for the `ReadableStreamBYOBReader` class is given as follows:

```
[Exposed=*]
interface ReadableStreamBYOBReader {
  constructor(ReadableStream stream);

  Promise<ReadableStreamReadResult> read(ArrayBufferView view, optional ReadableStreamBYOBReaderReadOptions options = {});
  undefined releaseLock();
};
ReadableStreamBYOBReader includes ReadableStreamGenericReader;

dictionary ReadableStreamBYOBReaderReadOptions {
  [EnforceRange] unsigned long long min = 1;
};
```


#### Internal slots

Instances of `ReadableStreamBYOBReader` are created with the internal slots defined by `ReadableStreamGenericReader`, and those described in the following table:

| Internal Slot | Description (*non-normative*) |
|---|---|
| [[readIntoRequests]] | A list of read-into requests, used when a consumer requests chunks sooner than they are available |

A read-into request is a struct containing three algorithms to perform in reaction to filling the readable byte stream's internal queue or changing its state. It has the following items:

**chunk steps**

An algorithm taking a chunk, called when a chunk is available for reading

**close steps**

An algorithm taking a chunk or undefined, called when no chunks are available because the stream is closed

**error steps**

An algorithm taking a JavaScript value, called when no chunks are available because the stream is errored

The close steps take a chunk so that it can return the backing memory to the caller if possible. For example, `byobReader.read(chunk)` will fulfill with `{ value: newViewOnSameMemory, done: true }` for closed streams. If the stream is canceled, the backing memory is discarded and `byobReader.read(chunk)` fulfills with the more traditional `{ value: undefined, done: true }` instead.


#### Constructor, methods, and properties

`reader = new ReadableStreamBYOBReader(stream)`

This is equivalent to calling `stream.getReader({ mode: "byob" })`.

`await reader.closed`

Returns a promise that will be fulfilled when the stream becomes closed, or rejected if the stream ever errors or the reader's lock is released before the stream finishes closing.

`await reader.cancel([ reason ])`

If the reader is active, behaves the same `stream.cancel(reason)`.

`{ value, done } = await reader.read(view[, { min }])`

Attempts to read bytes into `view`, and returns a promise resolved with the result:

- If the chunk does become available, the promise will be fulfilled with an object of the form `{ value: newView, done: false }`. In this case, `view` will be detached and no longer usable, but `newView` will be a new view (of the same type) onto the same backing memory region, with the chunk's data written into it.
- If the stream becomes closed, the promise will be fulfilled with an object of the form `{ value: newView, done: true }`. In this case, `view` will be detached and no longer usable, but `newView` will be a new view (of the same type) onto the same backing memory region, with no modifications, to ensure the memory is returned to the caller.
- If the reader is canceled, the promise will be fulfilled with an object of the form `{ value: undefined, done: true }`. In this case, the backing memory region of `view` is discarded and not returned to the caller.
- If the stream becomes errored, the promise will be rejected with the relevant error.

If reading a chunk causes the queue to become empty, more data will be pulled from the underlying source.

If `min` is given, then the promise will only be fulfilled as soon as the given minimum number of elements are available. Here, the "number of elements" is given by `newView`'s `length` (for typed arrays) or `newView`'s `byteLength` (for `DataView`s). If the stream becomes closed, then the promise is fulfilled with the remaining elements in the stream, which might be fewer than the initially requested amount. If not given, then the promise resolves when at least one element is available.

`reader.releaseLock()`

Releases the reader's lock on the corresponding stream. After the lock is released, the reader is no longer active. If the associated stream is errored when the lock is released, the reader will appear errored in the same way from now on; otherwise, the reader will appear closed.

If the reader's lock is released while it still has pending read requests, then the promises returned by the reader's `read()` method are immediately rejected with a `TypeError`. Any unread chunks remain in the stream's internal queue and can be read later by acquiring a new reader.

The `new ReadableStreamBYOBReader(stream)` constructor steps are:

1. Perform ? SetUpReadableStreamBYOBReader(this, `stream`).

The `read(view, options)` method steps are:

1. If `view`.[[ByteLength]] is 0, return a promise rejected with a `TypeError` exception.

2. If `view`.[[ViewedArrayBuffer]].[[ByteLength]] is 0, return a promise rejected with a `TypeError` exception.

3. If ! IsDetachedBuffer(`view`.[[ViewedArrayBuffer]]) is true, return a promise rejected with a `TypeError` exception.

4. If `options`["`min`"] is 0, return a promise rejected with a `TypeError` exception.

5. If `view` has a [[TypedArrayName]] internal slot,

   1. If `options`["`min`"] > `view`.[[ArrayLength]], return a promise rejected with a `RangeError` exception.

6. Otherwise (i.e., it is a `DataView`),

   1. If `options`["`min`"] > `view`.[[ByteLength]], return a promise rejected with a `RangeError` exception.

7. If this.[[stream]] is undefined, return a promise rejected with a `TypeError` exception.

8. Let `promise` be a new promise.

9. Let `readIntoRequest` be a new read-into request with the following items:

   chunk steps, given `chunk`

   1. Resolve `promise` with «[ "`value`" → `chunk`, "`done`" → false ]».

   close steps, given `chunk`

   1. Resolve `promise` with «[ "`value`" → `chunk`, "`done`" → true ]».

   error steps, given `e`

   1. Reject `promise` with `e`.

10. Perform ! ReadableStreamBYOBReaderRead(this, `view`, `options`["`min`"], `readIntoRequest`).

11. Return `promise`.

The `releaseLock()` method steps are:

1. If this.[[stream]] is undefined, return.

2. Perform ! ReadableStreamBYOBReaderRelease(this).


### The `ReadableStreamDefaultController` class

The `ReadableStreamDefaultController` class has methods that allow control of a `ReadableStream`'s state and internal queue. When constructing a `ReadableStream` that is not a readable byte stream, the underlying source is given a corresponding `ReadableStreamDefaultController` instance to manipulate.


#### Interface definition

The Web IDL definition for the `ReadableStreamDefaultController` class is given as follows:

```
[Exposed=*]
interface ReadableStreamDefaultController {
  readonly attribute unrestricted double? desiredSize;

  undefined close();
  undefined enqueue(optional any chunk);
  undefined error(optional any e);
};
```


#### Internal slots

Instances of `ReadableStreamDefaultController` are created with the internal slots described in the following table:

| Internal Slot | Description (*non-normative*) |
|---|---|
| [[cancelAlgorithm]] | A promise-returning algorithm, taking one argument (the cancel reason), which communicates a requested cancelation to the underlying source |
| [[closeRequested]] | A boolean flag indicating whether the stream has been closed by its underlying source, but still has chunks in its internal queue that have not yet been read |
| [[pullAgain]] | A boolean flag set to true if the stream's mechanisms requested a call to the underlying source's pull algorithm to pull more data, but the pull could not yet be done since a previous call is still executing |
| [[pullAlgorithm]] | A promise-returning algorithm that pulls data from the underlying source |
| [[pulling]] | A boolean flag set to true while the underlying source's pull algorithm is executing and the returned promise has not yet fulfilled, used to prevent reentrant calls |
| [[queue]] | A list representing the stream's internal queue of chunks |
| [[queueTotalSize]] | The total size of all the chunks stored in [[queue]] (see § 8.1 Queue-with-sizes) |
| [[started]] | A boolean flag indicating whether the underlying source has finished starting |
| [[strategyHWM]] | A number supplied to the constructor as part of the stream's queuing strategy, indicating the point at which the stream will apply backpressure to its underlying source |
| [[strategySizeAlgorithm]] | An algorithm to calculate the size of enqueued chunks, as part of the stream's queuing strategy |
| [[stream]] | The `ReadableStream` instance controlled |


#### Methods and properties

`desiredSize = controller.desiredSize`

Returns the desired size to fill the controlled stream's internal queue. It can be negative, if the queue is over-full. An underlying source ought to use this information to determine when and how to apply backpressure.

`controller.close()`

Closes the controlled readable stream. Consumers will still be able to read any previously-enqueued chunks from the stream, but once those are read, the stream will become closed.

`controller.enqueue(chunk)`

Enqueues the given chunk `chunk` in the controlled readable stream.

`controller.error(e)`

Errors the controlled readable stream, making all future interactions with it fail with the given error `e`.

The `desiredSize` getter steps are:

1. Return ! ReadableStreamDefaultControllerGetDesiredSize(this).

The `close()` method steps are:

1. If ! ReadableStreamDefaultControllerCanCloseOrEnqueue(this) is false, throw a `TypeError` exception.

2. Perform ! ReadableStreamDefaultControllerClose(this).

The `enqueue(chunk)` method steps are:

1. If ! ReadableStreamDefaultControllerCanCloseOrEnqueue(this) is false, throw a `TypeError` exception.

2. Perform ? ReadableStreamDefaultControllerEnqueue(this, `chunk`).

The `error(e)` method steps are:

1. Perform ! ReadableStreamDefaultControllerError(this, `e`).


#### Internal methods

The following are internal methods implemented by each `ReadableStreamDefaultController` instance. The readable stream implementation will polymorphically call to either these, or to their counterparts for BYOB controllers, as discussed in § 4.9.2 Interfacing with controllers.

[[CancelSteps]](`reason`) implements the [[CancelSteps]] contract. It performs the following steps:

1. Perform ! ResetQueue(this).

2. Let `result` be the result of performing this.[[cancelAlgorithm]], passing `reason`.

3. Perform ! ReadableStreamDefaultControllerClearAlgorithms(this).

4. Return `result`.

[[PullSteps]](`readRequest`) implements the [[PullSteps]] contract. It performs the following steps:

1. Let `stream` be this.[[stream]].

2. If this.[[queue]] is not empty,

   1. Let `chunk` be ! DequeueValue(this).

   2. If this.[[closeRequested]] is true and this.[[queue]] is empty,

      1. Perform ! ReadableStreamDefaultControllerClearAlgorithms(this).

      2. Perform ! ReadableStreamClose(`stream`).

   3. Otherwise, perform ! ReadableStreamDefaultControllerCallPullIfNeeded(this).

   4. Perform `readRequest`'s chunk steps, given `chunk`.

3. Otherwise,

   1. Perform ! ReadableStreamAddReadRequest(`stream`, `readRequest`).

   2. Perform ! ReadableStreamDefaultControllerCallPullIfNeeded(this).

[[ReleaseSteps]]() implements the [[ReleaseSteps]] contract. It performs the following steps:

1. Return.


### The `ReadableByteStreamController` class

The `ReadableByteStreamController` class has methods that allow control of a `ReadableStream`'s state and internal queue. When constructing a `ReadableStream` that is a readable byte stream, the underlying source is given a corresponding `ReadableByteStreamController` instance to manipulate.


#### Interface definition

The Web IDL definition for the `ReadableByteStreamController` class is given as follows:

```
[Exposed=*]
interface ReadableByteStreamController {
  readonly attribute ReadableStreamBYOBRequest? byobRequest;
  readonly attribute unrestricted double? desiredSize;

  undefined close();
  undefined enqueue(ArrayBufferView chunk);
  undefined error(optional any e);
};
```


#### Internal slots

Instances of `ReadableByteStreamController` are created with the internal slots described in the following table:

| Internal Slot | Description (*non-normative*) |
|---|---|
| [[autoAllocateChunkSize]] | A positive integer, when the automatic buffer allocation feature is enabled. In that case, this value specifies the size of buffer to allocate. It is undefined otherwise. |
| [[byobRequest]] | A `ReadableStreamBYOBRequest` instance representing the current BYOB pull request, or null if there are no pending requests |
| [[cancelAlgorithm]] | A promise-returning algorithm, taking one argument (the cancel reason), which communicates a requested cancelation to the underlying byte source |
| [[closeRequested]] | A boolean flag indicating whether the stream has been closed by its underlying byte source, but still has chunks in its internal queue that have not yet been read |
| [[pullAgain]] | A boolean flag set to true if the stream's mechanisms requested a call to the underlying byte source's pull algorithm to pull more data, but the pull could not yet be done since a previous call is still executing |
| [[pullAlgorithm]] | A promise-returning algorithm that pulls data from the underlying byte source |
| [[pulling]] | A boolean flag set to true while the underlying byte source's pull algorithm is executing and the returned promise has not yet fulfilled, used to prevent reentrant calls |
| [[pendingPullIntos]] | A list of pull-into descriptors |
| [[queue]] | A list of readable byte stream queue entries representing the stream's internal queue of chunks |
| [[queueTotalSize]] | The total size, in bytes, of all the chunks stored in [[queue]] (see § 8.1 Queue-with-sizes) |
| [[started]] | A boolean flag indicating whether the underlying byte source has finished starting |
| [[strategyHWM]] | A number supplied to the constructor as part of the stream's queuing strategy, indicating the point at which the stream will apply backpressure to its underlying byte source |
| [[stream]] | The `ReadableStream` instance controlled |

Although `ReadableByteStreamController` instances have [[queue]] and [[queueTotalSize]] slots, we do not use most of the abstract operations in § 8.1 Queue-with-sizes on them, as the way in which we manipulate this queue is rather different than the others in the spec. Instead, we update the two slots together manually.

This might be cleaned up in a future spec refactoring.

A readable byte stream queue entry is a struct encapsulating the important aspects of a chunk for the specific case of readable byte streams. It has the following items:

**buffer**

An `ArrayBuffer`, which will be a transferred version of the one originally supplied by the underlying byte source

**byte offset**

A nonnegative integer number giving the byte offset derived from the view originally supplied by the underlying byte source

**byte length**

A nonnegative integer number giving the byte length derived from the view originally supplied by the underlying byte source

A pull-into descriptor is a struct used to represent pending BYOB pull requests. It has the following items:

**buffer**

An `ArrayBuffer`

**buffer byte length**

A positive integer representing the initial byte length of buffer

**byte offset**

A nonnegative integer byte offset into the buffer where the underlying byte source will start writing

**byte length**

A positive integer number of bytes which can be written into the buffer

**bytes filled**

A nonnegative integer number of bytes that have been written into the buffer so far

**minimum fill**

A positive integer representing the minimum number of bytes that must be written into the buffer before the associated `read()` request may be fulfilled. By default, this equals the element size.

**element size**

A positive integer representing the number of bytes that can be written into the buffer at a time, using views of the type described by the view constructor

**view constructor**

A typed array constructor or `%DataView%`, which will be used for constructing a view with which to write into the buffer

**reader type**

Either "`default`" or "`byob`", indicating what type of readable stream reader initiated this request, or "`none`" if the initiating reader was released


#### Methods and properties

`byobRequest = controller.byobRequest`

Returns the current BYOB pull request, or null if there isn't one.

`desiredSize = controller.desiredSize`

Returns the desired size to fill the controlled stream's internal queue. It can be negative, if the queue is over-full. An underlying byte source ought to use this information to determine when and how to apply backpressure.

`controller.close()`

Closes the controlled readable stream. Consumers will still be able to read any previously-enqueued chunks from the stream, but once those are read, the stream will become closed.

`controller.enqueue(chunk)`

Enqueues the given chunk `chunk` in the controlled readable stream. The chunk has to be an `ArrayBufferView` instance, or else a `TypeError` will be thrown.

`controller.error(e)`

Errors the controlled readable stream, making all future interactions with it fail with the given error `e`.

The `byobRequest` getter steps are:

1. Return ! ReadableByteStreamControllerGetBYOBRequest(this).

The `desiredSize` getter steps are:

1. Return ! ReadableByteStreamControllerGetDesiredSize(this).

The `close()` method steps are:

1. If this.[[closeRequested]] is true, throw a `TypeError` exception.

2. If this.[[stream]].[[state]] is not "`readable`", throw a `TypeError` exception.

3. Perform ? ReadableByteStreamControllerClose(this).

The `enqueue(chunk)` method steps are:

1. If `chunk`.[[ByteLength]] is 0, throw a `TypeError` exception.

2. If `chunk`.[[ViewedArrayBuffer]].[[ByteLength]] is 0, throw a `TypeError` exception.

3. If this.[[closeRequested]] is true, throw a `TypeError` exception.

4. If this.[[stream]].[[state]] is not "`readable`", throw a `TypeError` exception.

5. Return ? ReadableByteStreamControllerEnqueue(this, `chunk`).

The `error(e)` method steps are:

1. Perform ! ReadableByteStreamControllerError(this, `e`).


#### Internal methods

The following are internal methods implemented by each `ReadableByteStreamController` instance. The readable stream implementation will polymorphically call to either these, or to their counterparts for default controllers, as discussed in § 4.9.2 Interfacing with controllers.

[[CancelSteps]](`reason`) implements the [[CancelSteps]] contract. It performs the following steps:

1. Perform ! ReadableByteStreamControllerClearPendingPullIntos(this).

2. Perform ! ResetQueue(this).

3. Let `result` be the result of performing this.[[cancelAlgorithm]], passing in `reason`.

4. Perform ! ReadableByteStreamControllerClearAlgorithms(this).

5. Return `result`.

[[PullSteps]](`readRequest`) implements the [[PullSteps]] contract. It performs the following steps:

1. Let `stream` be this.[[stream]].

2. Assert: ! ReadableStreamHasDefaultReader(`stream`) is true.

3. If this.[[queueTotalSize]] > 0,

   1. Assert: ! ReadableStreamGetNumReadRequests(`stream`) is 0.

   2. Perform ! ReadableByteStreamControllerFillReadRequestFromQueue(this, `readRequest`).

   3. Return.

4. Let `autoAllocateChunkSize` be this.[[autoAllocateChunkSize]].

5. If `autoAllocateChunkSize` is not undefined,

   1. Let `buffer` be Construct(`%ArrayBuffer%`, « `autoAllocateChunkSize` »).

   2. If `buffer` is an abrupt completion,

      1. Perform `readRequest`'s error steps, given `buffer`.[[Value]].

      2. Return.

   3. Let `pullIntoDescriptor` be a new pull-into descriptor with

      buffer
      :   `buffer`.[[Value]]

      buffer byte length
      :   `autoAllocateChunkSize`

      byte offset
      :   0

      byte length
      :   `autoAllocateChunkSize`

      bytes filled
      :   0

      minimum fill
      :   1

      element size
      :   1

      view constructor
      :   `%Uint8Array%`

      reader type
      :   "`default`"

   4. Append `pullIntoDescriptor` to this.[[pendingPullIntos]].

6. Perform ! ReadableStreamAddReadRequest(`stream`, `readRequest`).

7. Perform ! ReadableByteStreamControllerCallPullIfNeeded(this).

[[ReleaseSteps]]() implements the [[ReleaseSteps]] contract. It performs the following steps:

1. If this.[[pendingPullIntos]] is not empty,

   1. Let `firstPendingPullInto` be this.[[pendingPullIntos]][0].

   2. Set `firstPendingPullInto`'s reader type to "`none`".

   3. Set this.[[pendingPullIntos]] to the list « `firstPendingPullInto` ».


### The `ReadableStreamBYOBRequest` class

The `ReadableStreamBYOBRequest` class represents a pull-into request in a `ReadableByteStreamController`.


#### Interface definition

The Web IDL definition for the `ReadableStreamBYOBRequest` class is given as follows:

```
[Exposed=*]
interface ReadableStreamBYOBRequest {
  readonly attribute ArrayBufferView? view;

  undefined respond([EnforceRange] unsigned long long bytesWritten);
  undefined respondWithNewView(ArrayBufferView view);
};
```


#### Internal slots

Instances of `ReadableStreamBYOBRequest` are created with the internal slots described in the following table:

| Internal Slot | Description (*non-normative*) |
|---|---|
| [[controller]] | The parent `ReadableByteStreamController` instance |
| [[view]] | A typed array representing the destination region to which the controller can write generated data, or null after the BYOB request has been invalidated. |


#### Methods and properties

`view = byobRequest.view`

Returns the view for writing in to, or null if the BYOB request has already been responded to.

`byobRequest.respond(bytesWritten)`

Indicates to the associated readable byte stream that `bytesWritten` bytes were written into `view`, causing the result be surfaced to the consumer.

After this method is called, `view` will be transferred and no longer modifiable.

`byobRequest.respondWithNewView(view)`

Indicates to the associated readable byte stream that instead of writing into `view`, the underlying byte source is providing a new `ArrayBufferView`, which will be given to the consumer of the readable byte stream.

The new `view` has to be a view onto the same backing memory region as `view`, i.e. its buffer has to equal (or be a transferred version of) `view`'s buffer. Its `byteOffset` has to equal `view`'s `byteOffset`, and its `byteLength` (representing the number of bytes written) has to be less than or equal to that of `view`.

After this method is called, `view` will be transferred and no longer modifiable.

The `view` getter steps are:

1. Return this.[[view]].

The `respond(bytesWritten)` method steps are:

1. If this.[[controller]] is undefined, throw a `TypeError` exception.

2. If ! IsDetachedBuffer(this.[[view]].[[ArrayBuffer]]) is true, throw a `TypeError` exception.

3. Assert: this.[[view]].[[ByteLength]] > 0.

4. Assert: this.[[view]].[[ViewedArrayBuffer]].[[ByteLength]] > 0.

5. Perform ? ReadableByteStreamControllerRespond(this.[[controller]], `bytesWritten`).

The `respondWithNewView(view)` method steps are:

1. If this.[[controller]] is undefined, throw a `TypeError` exception.

2. If ! IsDetachedBuffer(`view`.[[ViewedArrayBuffer]]) is true, throw a `TypeError` exception.

3. Return ? ReadableByteStreamControllerRespondWithNewView(this.[[controller]], `view`).


### Abstract operations


#### Working with readable streams

The following abstract operations operate on `ReadableStream` instances at a higher level.

AcquireReadableStreamBYOBReader(`stream`) performs the following steps:

1. Let `reader` be a new `ReadableStreamBYOBReader`.

2. Perform ? SetUpReadableStreamBYOBReader(`reader`, `stream`).

3. Return `reader`.

AcquireReadableStreamDefaultReader(`stream`) performs the following steps:

1. Let `reader` be a new `ReadableStreamDefaultReader`.

2. Perform ? SetUpReadableStreamDefaultReader(`reader`, `stream`).

3. Return `reader`.

CreateReadableStream(`startAlgorithm`, `pullAlgorithm`, `cancelAlgorithm`[, `highWaterMark`, [, `sizeAlgorithm`]]) performs the following steps:

1. If `highWaterMark` was not passed, set it to 1.

2. If `sizeAlgorithm` was not passed, set it to an algorithm that returns 1.

3. Assert: ! IsNonNegativeNumber(`highWaterMark`) is true.

4. Let `stream` be a new `ReadableStream`.

5. Perform ! InitializeReadableStream(`stream`).

6. Let `controller` be a new `ReadableStreamDefaultController`.

7. Perform ? SetUpReadableStreamDefaultController(`stream`, `controller`, `startAlgorithm`, `pullAlgorithm`, `cancelAlgorithm`, `highWaterMark`, `sizeAlgorithm`).

8. Return `stream`.

This abstract operation will throw an exception if and only if the supplied `startAlgorithm` throws.

CreateReadableByteStream(`startAlgorithm`, `pullAlgorithm`, `cancelAlgorithm`) performs the following steps:

1. Let `stream` be a new `ReadableStream`.

2. Perform ! InitializeReadableStream(`stream`).

3. Let `controller` be a new `ReadableByteStreamController`.

4. Perform ? SetUpReadableByteStreamController(`stream`, `controller`, `startAlgorithm`, `pullAlgorithm`, `cancelAlgorithm`, 0, undefined).

5. Return `stream`.

This abstract operation will throw an exception if and only if the supplied `startAlgorithm` throws.

InitializeReadableStream(`stream`) performs the following steps:

1. Set `stream`.[[state]] to "`readable`".

2. Set `stream`.[[reader]] and `stream`.[[storedError]] to undefined.

3. Set `stream`.[[disturbed]] to false.

IsReadableStreamLocked(`stream`) performs the following steps:

1. If `stream`.[[reader]] is undefined, return false.

2. Return true.

ReadableStreamFromIterable(`asyncIterable`) performs the following steps:

1. Let `stream` be undefined.

2. Let `iteratorRecord` be ? GetIterator(`asyncIterable`, async).

3. Let `startAlgorithm` be an algorithm that returns undefined.

4. Let `pullAlgorithm` be the following steps:

   1. Let `nextResult` be IteratorNext(`iteratorRecord`).

   2. If `nextResult` is an abrupt completion, return a promise rejected with `nextResult`.[[Value]].

   3. Let `nextPromise` be a promise resolved with `nextResult`.[[Value]].

   4. Return the result of reacting to `nextPromise` with the following fulfillment steps, given `iterResult`:

      1. If `iterResult` is not an Object, throw a `TypeError`.

      2. Let `done` be ? IteratorComplete(`iterResult`).

      3. If `done` is true:

         1. Perform ! ReadableStreamDefaultControllerClose(`stream`.[[controller]]).

      4. Otherwise:

         1. Let `value` be ? IteratorValue(`iterResult`).

         2. Perform ! ReadableStreamDefaultControllerEnqueue(`stream`.[[controller]], `value`).

5. Let `cancelAlgorithm` be the following steps, given `reason`:

   1. Let `iterator` be `iteratorRecord`.[[Iterator]].

   2. Let `returnMethod` be GetMethod(`iterator`, "`return`").

   3. If `returnMethod` is an abrupt completion, return a promise rejected with `returnMethod`.[[Value]].

   4. If `returnMethod`.[[Value]] is undefined, return a promise resolved with undefined.

   5. Let `returnResult` be Call(`returnMethod`.[[Value]], `iterator`, « `reason` »).

   6. If `returnResult` is an abrupt completion, return a promise rejected with `returnResult`.[[Value]].

   7. Let `returnPromise` be a promise resolved with `returnResult`.[[Value]].

   8. Return the result of reacting to `returnPromise` with the following fulfillment steps, given `iterResult`:

      1. If `iterResult` is not an Object, throw a `TypeError`.

      2. Return undefined.

6. Set `stream` to ! CreateReadableStream(`startAlgorithm`, `pullAlgorithm`, `cancelAlgorithm`, 0).

7. Return `stream`.

ReadableStreamPipeTo(`source`, `dest`, `preventClose`, `preventAbort`, `preventCancel`[, `signal`]) performs the following steps:

1. Assert: `source` implements `ReadableStream`.

2. Assert: `dest` implements `WritableStream`.

3. Assert: `preventClose`, `preventAbort`, and `preventCancel` are all booleans.

4. If `signal` was not given, let `signal` be undefined.

5. Assert: either `signal` is undefined, or `signal` implements `AbortSignal`.

6. Assert: ! IsReadableStreamLocked(`source`) is false.

7. Assert: ! IsWritableStreamLocked(`dest`) is false.

8. If `source`.[[controller]] implements `ReadableByteStreamController`, let `reader` be either ! AcquireReadableStreamBYOBReader(`source`) or ! AcquireReadableStreamDefaultReader(`source`), at the user agent's discretion.

9. Otherwise, let `reader` be ! AcquireReadableStreamDefaultReader(`source`).

10. Let `writer` be ! AcquireWritableStreamDefaultWriter(`dest`).

11. Set `source`.[[disturbed]] to true.

12. Let `shuttingDown` be false.

13. Let `promise` be a new promise.

14. If `signal` is not undefined,

    1. Let `abortAlgorithm` be the following steps:

       1. Let `error` be `signal`'s abort reason.

       2. Let `actions` be an empty ordered set.

       3. If `preventAbort` is false, append the following action to `actions`:

          1. If `dest`.[[state]] is "`writable`", return ! WritableStreamAbort(`dest`, `error`).

          2. Otherwise, return a promise resolved with undefined.

       4. If `preventCancel` is false, append the following action action to `actions`:

          1. If `source`.[[state]] is "`readable`", return ! ReadableStreamCancel(`source`, `error`).

          2. Otherwise, return a promise resolved with undefined.

       5. Shutdown with an action consisting of getting a promise to wait for all of the actions in `actions`, and with `error`.

    2. If `signal` is aborted, perform `abortAlgorithm` and return `promise`.

    3. Add `abortAlgorithm` to `signal`.

15. In parallel but not really; see #905, using `reader` and `writer`, read all chunks from `source` and write them to `dest`. Due to the locking provided by the reader and writer, the exact manner in which this happens is not observable to author code, and so there is flexibility in how this is done. The following constraints apply regardless of the exact algorithm used:

    - **Public API must not be used:** while reading or writing, or performing any of the operations below, the JavaScript-modifiable reader, writer, and stream APIs (i.e. methods on the appropriate prototypes) must not be used. Instead, the streams must be manipulated directly.

    - **Backpressure must be enforced:**

      - While WritableStreamDefaultWriterGetDesiredSize(`writer`) is ≤ 0 or is null, the user agent must not read from `reader`.

      - If `reader` is a BYOB reader, WritableStreamDefaultWriterGetDesiredSize(`writer`) should be used as a basis to determine the size of the chunks read from `reader`.

        It's frequently inefficient to read chunks that are too small or too large. Other information might be factored in to determine the optimal chunk size.

      - Reads or writes should not be delayed for reasons other than these backpressure signals.

        An implementation that waits for each write to successfully complete before proceeding to the next read/write operation violates this recommendation. In doing so, such an implementation makes the internal queue of `dest` useless, as it ensures `dest` always contains at most one queued chunk.

    - **Shutdown must stop activity:** if `shuttingDown` becomes true, the user agent must not initiate further reads from `reader`, and must only perform writes of already-read chunks, as described below. In particular, the user agent must check the below conditions before performing any reads or writes, since they might lead to immediate shutdown.

    - **Error and close states must be propagated:** the following conditions must be applied in order.

      1. **Errors must be propagated forward:** if `source`.[[state]] is or becomes "`errored`", then

         1. If `preventAbort` is false, shutdown with an action of ! WritableStreamAbort(`dest`, `source`.[[storedError]]) and with `source`.[[storedError]].

         2. Otherwise, shutdown with `source`.[[storedError]].

      2. **Errors must be propagated backward:** if `dest`.[[state]] is or becomes "`errored`", then

         1. If `preventCancel` is false, shutdown with an action of ! ReadableStreamCancel(`source`, `dest`.[[storedError]]) and with `dest`.[[storedError]].

         2. Otherwise, shutdown with `dest`.[[storedError]].

      3. **Closing must be propagated forward:** if `source`.[[state]] is or becomes "`closed`", then

         1. If `preventClose` is false, shutdown with an action of ! WritableStreamDefaultWriterCloseWithErrorPropagation(`writer`).

         2. Otherwise, shutdown.

      4. **Closing must be propagated backward:** if ! WritableStreamCloseQueuedOrInFlight(`dest`) is true or `dest`.[[state]] is "`closed`", then

         1. Assert: no chunks have been read or written.

         2. Let `destClosed` be a new `TypeError`.

         3. If `preventCancel` is false, shutdown with an action of ! ReadableStreamCancel(`source`, `destClosed`) and with `destClosed`.

         4. Otherwise, shutdown with `destClosed`.

    - *Shutdown with an action*: if any of the above requirements ask to shutdown with an action `action`, optionally with an error `originalError`, then:

      1. If `shuttingDown` is true, abort these substeps.

      2. Set `shuttingDown` to true.

      3. If `dest`.[[state]] is "`writable`" and ! WritableStreamCloseQueuedOrInFlight(`dest`) is false,

         1. If any chunks have been read but not yet written, write them to `dest`.

         2. Wait until every chunk that has been read has been written (i.e. the corresponding promises have settled).

      4. Let `p` be the result of performing `action`.

      5. Upon fulfillment of `p`, finalize, passing along `originalError` if it was given.

      6. Upon rejection of `p` with reason `newError`, finalize with `newError`.

    - *Shutdown*: if any of the above requirements or steps ask to shutdown, optionally with an error `error`, then:

      1. If `shuttingDown` is true, abort these substeps.

      2. Set `shuttingDown` to true.

      3. If `dest`.[[state]] is "`writable`" and ! WritableStreamCloseQueuedOrInFlight(`dest`) is false,

         1. If any chunks have been read but not yet written, write them to `dest`.

         2. Wait until every chunk that has been read has been written (i.e. the corresponding promises have settled).

      4. Finalize, passing along `error` if it was given.

    - *Finalize*: both forms of shutdown will eventually ask to finalize, optionally with an error `error`, which means to perform the following steps:

      1. Perform ! WritableStreamDefaultWriterRelease(`writer`).

      2. If `reader` implements `ReadableStreamBYOBReader`, perform ! ReadableStreamBYOBReaderRelease(`reader`).

      3. Otherwise, perform ! ReadableStreamDefaultReaderRelease(`reader`).

      4. If `signal` is not undefined, remove `abortAlgorithm` from `signal`.

      5. If `error` was given, reject `promise` with `error`.

      6. Otherwise, resolve `promise` with undefined.

16. Return `promise`.

Various abstract operations performed here include object creation (often of promises), which usually would require specifying a realm for the created object. However, because of the locking, none of these objects can be observed by author code. As such, the realm used to create them does not matter.

ReadableStreamTee(`stream`, `cloneForBranch2`) will tee a given readable stream.

The second argument, `cloneForBranch2`, governs whether or not the data from the original stream will be cloned (using HTML's serializable objects framework) before appearing in the second of the returned branches. This is useful for scenarios where both branches are to be consumed in such a way that they might otherwise interfere with each other, such as by transferring their chunks. However, it does introduce a noticeable asymmetry between the two branches, and limits the possible chunks to serializable ones. [HTML]

If `stream` is a readable byte stream, then `cloneForBranch2` is ignored and chunks are cloned unconditionally.

In this standard ReadableStreamTee is always called with `cloneForBranch2` set to false; other specifications pass true via the tee wrapper algorithm.

It performs the following steps:

1. Assert: `stream` implements `ReadableStream`.

2. Assert: `cloneForBranch2` is a boolean.

3. If `stream`.[[controller]] implements `ReadableByteStreamController`, return ? ReadableByteStreamTee(`stream`).

4. Return ? ReadableStreamDefaultTee(`stream`, `cloneForBranch2`).

ReadableStreamDefaultTee(`stream`, `cloneForBranch2`) performs the following steps:

1. Assert: `stream` implements `ReadableStream`.

2. Assert: `cloneForBranch2` is a boolean.

3. Let `reader` be ? AcquireReadableStreamDefaultReader(`stream`).

4. Let `reading` be false.

5. Let `readAgain` be false.

6. Let `canceled1` be false.

7. Let `canceled2` be false.

8. Let `reason1` be undefined.

9. Let `reason2` be undefined.

10. Let `branch1` be undefined.

11. Let `branch2` be undefined.

12. Let `cancelPromise` be a new promise.

13. Let `pullAlgorithm` be the following steps:

    1. If `reading` is true,

       1. Set `readAgain` to true.

       2. Return a promise resolved with undefined.

    2. Set `reading` to true.

    3. Let `readRequest` be a read request with the following items:

       chunk steps, given `chunk`

       1. Queue a microtask to perform the following steps:

          1. Set `readAgain` to false.

          2. Let `chunk1` and `chunk2` be `chunk`.

          3. If `canceled2` is false and `cloneForBranch2` is true,

             1. Let `cloneResult` be StructuredClone(`chunk2`).

             2. If `cloneResult` is an abrupt completion,

                1. Perform ! ReadableStreamDefaultControllerError(`branch1`.[[controller]], `cloneResult`.[[Value]]).

                2. Perform ! ReadableStreamDefaultControllerError(`branch2`.[[controller]], `cloneResult`.[[Value]]).

                3. Resolve `cancelPromise` with ! ReadableStreamCancel(`stream`, `cloneResult`.[[Value]]).

                4. Return.

             3. Otherwise, set `chunk2` to `cloneResult`.[[Value]].

          4. If `canceled1` is false, perform ! ReadableStreamDefaultControllerEnqueue(`branch1`.[[controller]], `chunk1`).

          5. If `canceled2` is false, perform ! ReadableStreamDefaultControllerEnqueue(`branch2`.[[controller]], `chunk2`).

          6. Set `reading` to false.

          7. If `readAgain` is true, perform `pullAlgorithm`.

       The microtask delay here is necessary because it takes at least a microtask to detect errors, when we use `reader`.[[closedPromise]] below. We want errors in `stream` to error both branches immediately, so we cannot let successful synchronously-available reads happen ahead of asynchronously-available errors.

       close steps

       1. Set `reading` to false.

       2. If `canceled1` is false, perform ! ReadableStreamDefaultControllerClose(`branch1`.[[controller]]).

       3. If `canceled2` is false, perform ! ReadableStreamDefaultControllerClose(`branch2`.[[controller]]).

       4. If `canceled1` is false or `canceled2` is false, resolve `cancelPromise` with undefined.

       error steps

       1. Set `reading` to false.

    4. Perform ! ReadableStreamDefaultReaderRead(`reader`, `readRequest`).

    5. Return a promise resolved with undefined.

14. Let `cancel1Algorithm` be the following steps, taking a `reason` argument:

    1. Set `canceled1` to true.

    2. Set `reason1` to `reason`.

    3. If `canceled2` is true,

       1. Let `compositeReason` be ! CreateArrayFromList(« `reason1`, `reason2` »).

       2. Let `cancelResult` be ! ReadableStreamCancel(`stream`, `compositeReason`).

       3. Resolve `cancelPromise` with `cancelResult`.

    4. Return `cancelPromise`.

15. Let `cancel2Algorithm` be the following steps, taking a `reason` argument:

    1. Set `canceled2` to true.

    2. Set `reason2` to `reason`.

    3. If `canceled1` is true,

       1. Let `compositeReason` be ! CreateArrayFromList(« `reason1`, `reason2` »).

       2. Let `cancelResult` be ! ReadableStreamCancel(`stream`, `compositeReason`).

       3. Resolve `cancelPromise` with `cancelResult`.

    4. Return `cancelPromise`.

16. Let `startAlgorithm` be an algorithm that returns undefined.

17. Set `branch1` to ! CreateReadableStream(`startAlgorithm`, `pullAlgorithm`, `cancel1Algorithm`).

18. Set `branch2` to ! CreateReadableStream(`startAlgorithm`, `pullAlgorithm`, `cancel2Algorithm`).

19. Upon rejection of `reader`.[[closedPromise]] with reason `r`,

    1. Perform ! ReadableStreamDefaultControllerError(`branch1`.[[controller]], `r`).

    2. Perform ! ReadableStreamDefaultControllerError(`branch2`.[[controller]], `r`).

    3. If `canceled1` is false or `canceled2` is false, resolve `cancelPromise` with undefined.

20. Return « `branch1`, `branch2` ».

ReadableByteStreamTee(`stream`) performs the following steps:

1. Assert: `stream` implements `ReadableStream`.

2. Assert: `stream`.[[controller]] implements `ReadableByteStreamController`.

3. Let `reader` be ? AcquireReadableStreamDefaultReader(`stream`).

4. Let `reading` be false.

5. Let `readAgainForBranch1` be false.

6. Let `readAgainForBranch2` be false.

7. Let `canceled1` be false.

8. Let `canceled2` be false.

9. Let `reason1` be undefined.

10. Let `reason2` be undefined.

11. Let `branch1` be undefined.

12. Let `branch2` be undefined.

13. Let `cancelPromise` be a new promise.

14. Let `forwardReaderError` be the following steps, taking a `thisReader` argument:

    1. Upon rejection of `thisReader`.[[closedPromise]] with reason `r`,

       1. If `thisReader` is not `reader`, return.

       2. Perform ! ReadableByteStreamControllerError(`branch1`.[[controller]], `r`).

       3. Perform ! ReadableByteStreamControllerError(`branch2`.[[controller]], `r`).

       4. If `canceled1` is false or `canceled2` is false, resolve `cancelPromise` with undefined.

15. Let `pullWithDefaultReader` be the following steps:

    1. If `reader` implements `ReadableStreamBYOBReader`,

       1. Assert: `reader`.[[readIntoRequests]] is empty.

       2. Perform ! ReadableStreamBYOBReaderRelease(`reader`).

       3. Set `reader` to ! AcquireReadableStreamDefaultReader(`stream`).

       4. Perform `forwardReaderError`, given `reader`.

    2. Let `readRequest` be a read request with the following items:

       chunk steps, given `chunk`

       1. Queue a microtask to perform the following steps:

          1. Set `readAgainForBranch1` to false.

          2. Set `readAgainForBranch2` to false.

          3. Let `chunk1` and `chunk2` be `chunk`.

          4. If `canceled1` is false and `canceled2` is false,

             1. Let `cloneResult` be CloneAsUint8Array(`chunk`).

             2. If `cloneResult` is an abrupt completion,

                1. Perform ! ReadableByteStreamControllerError(`branch1`.[[controller]], `cloneResult`.[[Value]]).

                2. Perform ! ReadableByteStreamControllerError(`branch2`.[[controller]], `cloneResult`.[[Value]]).

                3. Resolve `cancelPromise` with ! ReadableStreamCancel(`stream`, `cloneResult`.[[Value]]).

                4. Return.

             3. Otherwise, set `chunk2` to `cloneResult`.[[Value]].

          5. If `canceled1` is false, perform ! ReadableByteStreamControllerEnqueue(`branch1`.[[controller]], `chunk1`).

          6. If `canceled2` is false, perform ! ReadableByteStreamControllerEnqueue(`branch2`.[[controller]], `chunk2`).

          7. Set `reading` to false.

          8. If `readAgainForBranch1` is true, perform `pull1Algorithm`.

          9. Otherwise, if `readAgainForBranch2` is true, perform `pull2Algorithm`.

       The microtask delay here is necessary because it takes at least a microtask to detect errors, when we use `reader`.[[closedPromise]] below. We want errors in `stream` to error both branches immediately, so we cannot let successful synchronously-available reads happen ahead of asynchronously-available errors.

       close steps

       1. Set `reading` to false.

       2. If `canceled1` is false, perform ! ReadableByteStreamControllerClose(`branch1`.[[controller]]).

       3. If `canceled2` is false, perform ! ReadableByteStreamControllerClose(`branch2`.[[controller]]).

       4. If `branch1`.[[controller]].[[pendingPullIntos]] is not empty, perform ! ReadableByteStreamControllerRespond(`branch1`.[[controller]], 0).

       5. If `branch2`.[[controller]].[[pendingPullIntos]] is not empty, perform ! ReadableByteStreamControllerRespond(`branch2`.[[controller]], 0).

       6. If `canceled1` is false or `canceled2` is false, resolve `cancelPromise` with undefined.

       error steps

       1. Set `reading` to false.

    3. Perform ! ReadableStreamDefaultReaderRead(`reader`, `readRequest`).

16. Let `pullWithBYOBReader` be the following steps, given `view` and `forBranch2`:

    1. If `reader` implements `ReadableStreamDefaultReader`,

       1. Assert: `reader`.[[readRequests]] is empty.

       2. Perform ! ReadableStreamDefaultReaderRelease(`reader`).

       3. Set `reader` to ! AcquireReadableStreamBYOBReader(`stream`).

       4. Perform `forwardReaderError`, given `reader`.

    2. Let `byobBranch` be `branch2` if `forBranch2` is true, and `branch1` otherwise.

    3. Let `otherBranch` be `branch2` if `forBranch2` is false, and `branch1` otherwise.

    4. Let `readIntoRequest` be a read-into request with the following items:

       chunk steps, given `chunk`

       1. Queue a microtask to perform the following steps:

          1. Set `readAgainForBranch1` to false.

          2. Set `readAgainForBranch2` to false.

          3. Let `byobCanceled` be `canceled2` if `forBranch2` is true, and `canceled1` otherwise.

          4. Let `otherCanceled` be `canceled2` if `forBranch2` is false, and `canceled1` otherwise.

          5. If `otherCanceled` is false,

             1. Let `cloneResult` be CloneAsUint8Array(`chunk`).

             2. If `cloneResult` is an abrupt completion,

                1. Perform ! ReadableByteStreamControllerError(`byobBranch`.[[controller]], `cloneResult`.[[Value]]).

                2. Perform ! ReadableByteStreamControllerError(`otherBranch`.[[controller]], `cloneResult`.[[Value]]).

                3. Resolve `cancelPromise` with ! ReadableStreamCancel(`stream`, `cloneResult`.[[Value]]).

                4. Return.

             3. Otherwise, let `clonedChunk` be `cloneResult`.[[Value]].

             4. If `byobCanceled` is false, perform ! ReadableByteStreamControllerRespondWithNewView(`byobBranch`.[[controller]], `chunk`).

             5. Perform ! ReadableByteStreamControllerEnqueue(`otherBranch`.[[controller]], `clonedChunk`).

          6. Otherwise, if `byobCanceled` is false, perform ! ReadableByteStreamControllerRespondWithNewView(`byobBranch`.[[controller]], `chunk`).

          7. Set `reading` to false.

          8. If `readAgainForBranch1` is true, perform `pull1Algorithm`.

          9. Otherwise, if `readAgainForBranch2` is true, perform `pull2Algorithm`.

       The microtask delay here is necessary because it takes at least a microtask to detect errors, when we use `reader`.[[closedPromise]] below. We want errors in `stream` to error both branches immediately, so we cannot let successful synchronously-available reads happen ahead of asynchronously-available errors.

       close steps, given `chunk`

       1. Set `reading` to false.

       2. Let `byobCanceled` be `canceled2` if `forBranch2` is true, and `canceled1` otherwise.

       3. Let `otherCanceled` be `canceled2` if `forBranch2` is false, and `canceled1` otherwise.

       4. If `byobCanceled` is false, perform ! ReadableByteStreamControllerClose(`byobBranch`.[[controller]]).

       5. If `otherCanceled` is false, perform ! ReadableByteStreamControllerClose(`otherBranch`.[[controller]]).

       6. If `chunk` is not undefined,

          1. Assert: `chunk`.[[ByteLength]] is 0.

          2. If `byobCanceled` is false, perform ! ReadableByteStreamControllerRespondWithNewView(`byobBranch`.[[controller]], `chunk`).

          3. If `otherCanceled` is false and `otherBranch`.[[controller]].[[pendingPullIntos]] is not empty, perform ! ReadableByteStreamControllerRespond(`otherBranch`.[[controller]], 0).

       7. If `byobCanceled` is false or `otherCanceled` is false, resolve `cancelPromise` with undefined.

       error steps

       1. Set `reading` to false.

    5. Perform ! ReadableStreamBYOBReaderRead(`reader`, `view`, 1, `readIntoRequest`).

17. Let `pull1Algorithm` be the following steps:

    1. If `reading` is true,

       1. Set `readAgainForBranch1` to true.

       2. Return a promise resolved with undefined.

    2. Set `reading` to true.

    3. Let `byobRequest` be ! ReadableByteStreamControllerGetBYOBRequest(`branch1`.[[controller]]).

    4. If `byobRequest` is null, perform `pullWithDefaultReader`.

    5. Otherwise, perform `pullWithBYOBReader`, given `byobRequest`.[[view]] and false.

    6. Return a promise resolved with undefined.

18. Let `pull2Algorithm` be the following steps:

    1. If `reading` is true,

       1. Set `readAgainForBranch2` to true.

       2. Return a promise resolved with undefined.

    2. Set `reading` to true.

    3. Let `byobRequest` be ! ReadableByteStreamControllerGetBYOBRequest(`branch2`.[[controller]]).

    4. If `byobRequest` is null, perform `pullWithDefaultReader`.

    5. Otherwise, perform `pullWithBYOBReader`, given `byobRequest`.[[view]] and true.

    6. Return a promise resolved with undefined.

19. Let `cancel1Algorithm` be the following steps, taking a `reason` argument:

    1. Set `canceled1` to true.

    2. Set `reason1` to `reason`.

    3. If `canceled2` is true,

       1. Let `compositeReason` be ! CreateArrayFromList(« `reason1`, `reason2` »).

       2. Let `cancelResult` be ! ReadableStreamCancel(`stream`, `compositeReason`).

       3. Resolve `cancelPromise` with `cancelResult`.

    4. Return `cancelPromise`.

20. Let `cancel2Algorithm` be the following steps, taking a `reason` argument:

    1. Set `canceled2` to true.

    2. Set `reason2` to `reason`.

    3. If `canceled1` is true,

       1. Let `compositeReason` be ! CreateArrayFromList(« `reason1`, `reason2` »).

       2. Let `cancelResult` be ! ReadableStreamCancel(`stream`, `compositeReason`).

       3. Resolve `cancelPromise` with `cancelResult`.

    4. Return `cancelPromise`.

21. Let `startAlgorithm` be an algorithm that returns undefined.

22. Set `branch1` to ! CreateReadableByteStream(`startAlgorithm`, `pull1Algorithm`, `cancel1Algorithm`).

23. Set `branch2` to ! CreateReadableByteStream(`startAlgorithm`, `pull2Algorithm`, `cancel2Algorithm`).

24. Perform `forwardReaderError`, given `reader`.

25. Return « `branch1`, `branch2` ».


#### Interfacing with controllers

In terms of specification factoring, the way that the `ReadableStream` class encapsulates the behavior of both simple readable streams and readable byte streams into a single class is by centralizing most of the potentially-varying logic inside the two controller classes, `ReadableStreamDefaultController` and `ReadableByteStreamController`. Those classes define most of the stateful internal slots and abstract operations for how a stream's internal queue is managed and how it interfaces with its underlying source or underlying byte source.

Each controller class defines three internal methods, which are called by the `ReadableStream` algorithms:

**[[CancelSteps]](`reason`)**

The controller's steps that run in reaction to the stream being canceled, used to clean up the state stored in the controller and inform the underlying source.

**[[PullSteps]](`readRequest`)**

The controller's steps that run when a default reader is read from, used to pull from the controller any queued chunks, or pull from the underlying source to get more chunks.

**[[ReleaseSteps]]()**

The controller's steps that run when a reader is released, used to clean up reader-specific resources stored in the controller.

(These are defined as internal methods, instead of as abstract operations, so that they can be called polymorphically by the `ReadableStream` algorithms, without having to branch on which type of controller is present.)

The rest of this section concerns abstract operations that go in the other direction: they are used by the controller implementations to affect their associated `ReadableStream` object. This translates internal state changes of the controller into developer-facing results visible through the `ReadableStream`'s public API.

ReadableStreamAddReadIntoRequest(`stream`, `readRequest`) performs the following steps:

1. Assert: `stream`.[[reader]] implements `ReadableStreamBYOBReader`.

2. Assert: `stream`.[[state]] is "`readable`" or "`closed`".

3. Append `readRequest` to `stream`.[[reader]].[[readIntoRequests]].

ReadableStreamAddReadRequest(`stream`, `readRequest`) performs the following steps:

1. Assert: `stream`.[[reader]] implements `ReadableStreamDefaultReader`.

2. Assert: `stream`.[[state]] is "`readable`".

3. Append `readRequest` to `stream`.[[reader]].[[readRequests]].

ReadableStreamCancel(`stream`, `reason`) performs the following steps:

1. Set `stream`.[[disturbed]] to true.

2. If `stream`.[[state]] is "`closed`", return a promise resolved with undefined.

3. If `stream`.[[state]] is "`errored`", return a promise rejected with `stream`.[[storedError]].

4. Perform ! ReadableStreamClose(`stream`).

5. Let `reader` be `stream`.[[reader]].

6. If `reader` is not undefined and `reader` implements `ReadableStreamBYOBReader`,

   1. Let `readIntoRequests` be `reader`.[[readIntoRequests]].

   2. Set `reader`.[[readIntoRequests]] to an empty list.

   3. For each `readIntoRequest` of `readIntoRequests`,

      1. Perform `readIntoRequest`'s close steps, given undefined.

7. Let `sourceCancelPromise` be ! `stream`.[[controller]].[[CancelSteps]](`reason`).

8. Return the result of reacting to `sourceCancelPromise` with a fulfillment step that returns undefined.

ReadableStreamClose(`stream`) performs the following steps:

1. Assert: `stream`.[[state]] is "`readable`".

2. Set `stream`.[[state]] to "`closed`".

3. Let `reader` be `stream`.[[reader]].

4. If `reader` is undefined, return.

5. Resolve `reader`.[[closedPromise]] with undefined.

6. If `reader` implements `ReadableStreamDefaultReader`,

   1. Let `readRequests` be `reader`.[[readRequests]].

   2. Set `reader`.[[readRequests]] to an empty list.

   3. For each `readRequest` of `readRequests`,

      1. Perform `readRequest`'s close steps.

ReadableStreamError(`stream`, `e`) performs the following steps:

1. Assert: `stream`.[[state]] is "`readable`".

2. Set `stream`.[[state]] to "`errored`".

3. Set `stream`.[[storedError]] to `e`.

4. Let `reader` be `stream`.[[reader]].

5. If `reader` is undefined, return.

6. Reject `reader`.[[closedPromise]] with `e`.

7. Set `reader`.[[closedPromise]].[[PromiseIsHandled]] to true.

8. If `reader` implements `ReadableStreamDefaultReader`,

   1. Perform ! ReadableStreamDefaultReaderErrorReadRequests(`reader`, `e`).

9. Otherwise,

   1. Assert: `reader` implements `ReadableStreamBYOBReader`.

   2. Perform ! ReadableStreamBYOBReaderErrorReadIntoRequests(`reader`, `e`).

ReadableStreamFulfillReadIntoRequest(`stream`, `chunk`, `done`) performs the following steps:

1. Assert: ! ReadableStreamHasBYOBReader(`stream`) is true.

2. Let `reader` be `stream`.[[reader]].

3. Assert: `reader`.[[readIntoRequests]] is not empty.

4. Let `readIntoRequest` be `reader`.[[readIntoRequests]][0].

5. Remove `readIntoRequest` from `reader`.[[readIntoRequests]].

6. If `done` is true, perform `readIntoRequest`'s close steps, given `chunk`.

7. Otherwise, perform `readIntoRequest`'s chunk steps, given `chunk`.

ReadableStreamFulfillReadRequest(`stream`, `chunk`, `done`) performs the following steps:

1. Assert: ! ReadableStreamHasDefaultReader(`stream`) is true.

2. Let `reader` be `stream`.[[reader]].

3. Assert: `reader`.[[readRequests]] is not empty.

4. Let `readRequest` be `reader`.[[readRequests]][0].

5. Remove `readRequest` from `reader`.[[readRequests]].

6. If `done` is true, perform `readRequest`'s close steps.

7. Otherwise, perform `readRequest`'s chunk steps, given `chunk`.

ReadableStreamGetNumReadIntoRequests(`stream`) performs the following steps:

1. Assert: ! ReadableStreamHasBYOBReader(`stream`) is true.

2. Return `stream`.[[reader]].[[readIntoRequests]]'s size.

ReadableStreamGetNumReadRequests(`stream`) performs the following steps:

1. Assert: ! ReadableStreamHasDefaultReader(`stream`) is true.

2. Return `stream`.[[reader]].[[readRequests]]'s size.

ReadableStreamHasBYOBReader(`stream`) performs the following steps:

1. Let `reader` be `stream`.[[reader]].

2. If `reader` is undefined, return false.

3. If `reader` implements `ReadableStreamBYOBReader`, return true.

4. Return false.

ReadableStreamHasDefaultReader(`stream`) performs the following steps:

1. Let `reader` be `stream`.[[reader]].

2. If `reader` is undefined, return false.

3. If `reader` implements `ReadableStreamDefaultReader`, return true.

4. Return false.


#### Readers

The following abstract operations support the implementation and manipulation of `ReadableStreamDefaultReader` and `ReadableStreamBYOBReader` instances.

ReadableStreamReaderGenericCancel(`reader`, `reason`) performs the following steps:

1. Let `stream` be `reader`.[[stream]].

2. Assert: `stream` is not undefined.

3. Return ! ReadableStreamCancel(`stream`, `reason`).

ReadableStreamReaderGenericInitialize(`reader`, `stream`) performs the following steps:

1. Set `reader`.[[stream]] to `stream`.

2. Set `stream`.[[reader]] to `reader`.

3. If `stream`.[[state]] is "`readable`",

   1. Set `reader`.[[closedPromise]] to a new promise.

4. Otherwise, if `stream`.[[state]] is "`closed`",

   1. Set `reader`.[[closedPromise]] to a promise resolved with undefined.

5. Otherwise,

   1. Assert: `stream`.[[state]] is "`errored`".

   2. Set `reader`.[[closedPromise]] to a promise rejected with `stream`.[[storedError]].

   3. Set `reader`.[[closedPromise]].[[PromiseIsHandled]] to true.

ReadableStreamReaderGenericRelease(`reader`) performs the following steps:

1. Let `stream` be `reader`.[[stream]].

2. Assert: `stream` is not undefined.

3. Assert: `stream`.[[reader]] is `reader`.

4. If `stream`.[[state]] is "`readable`", reject `reader`.[[closedPromise]] with a `TypeError` exception.

5. Otherwise, set `reader`.[[closedPromise]] to a promise rejected with a `TypeError` exception.

6. Set `reader`.[[closedPromise]].[[PromiseIsHandled]] to true.

7. Perform ! `stream`.[[controller]].[[ReleaseSteps]]().

8. Set `stream`.[[reader]] to undefined.

9. Set `reader`.[[stream]] to undefined.

ReadableStreamBYOBReaderErrorReadIntoRequests(`reader`, `e`) performs the following steps:

1. Let `readIntoRequests` be `reader`.[[readIntoRequests]].

2. Set `reader`.[[readIntoRequests]] to a new empty list.

3. For each `readIntoRequest` of `readIntoRequests`,

   1. Perform `readIntoRequest`'s error steps, given `e`.

ReadableStreamBYOBReaderRead(`reader`, `view`, `min`, `readIntoRequest`) performs the following steps:

1. Let `stream` be `reader`.[[stream]].

2. Assert: `stream` is not undefined.

3. Set `stream`.[[disturbed]] to true.

4. If `stream`.[[state]] is "`errored`", perform `readIntoRequest`'s error steps given `stream`.[[storedError]].

5. Otherwise, perform ! ReadableByteStreamControllerPullInto(`stream`.[[controller]], `view`, `min`, `readIntoRequest`).

ReadableStreamBYOBReaderRelease(`reader`) performs the following steps:

1. Perform ! ReadableStreamReaderGenericRelease(`reader`).

2. Let `e` be a new `TypeError` exception.

3. Perform ! ReadableStreamBYOBReaderErrorReadIntoRequests(`reader`, `e`).

ReadableStreamDefaultReaderErrorReadRequests(`reader`, `e`) performs the following steps:

1. Let `readRequests` be `reader`.[[readRequests]].

2. Set `reader`.[[readRequests]] to a new empty list.

3. For each `readRequest` of `readRequests`,

   1. Perform `readRequest`'s error steps, given `e`.

ReadableStreamDefaultReaderRead(`reader`, `readRequest`) performs the following steps:

1. Let `stream` be `reader`.[[stream]].

2. Assert: `stream` is not undefined.

3. Set `stream`.[[disturbed]] to true.

4. If `stream`.[[state]] is "`closed`", perform `readRequest`'s close steps.

5. Otherwise, if `stream`.[[state]] is "`errored`", perform `readRequest`'s error steps given `stream`.[[storedError]].

6. Otherwise,

   1. Assert: `stream`.[[state]] is "`readable`".

   2. Perform ! `stream`.[[controller]].[[PullSteps]](`readRequest`).

ReadableStreamDefaultReaderRelease(`reader`) performs the following steps:

1. Perform ! ReadableStreamReaderGenericRelease(`reader`).

2. Let `e` be a new `TypeError` exception.

3. Perform ! ReadableStreamDefaultReaderErrorReadRequests(`reader`, `e`).

SetUpReadableStreamBYOBReader(`reader`, `stream`) performs the following steps:

1. If ! IsReadableStreamLocked(`stream`) is true, throw a `TypeError` exception.

2. If `stream`.[[controller]] does not implement `ReadableByteStreamController`, throw a `TypeError` exception.

3. Perform ! ReadableStreamReaderGenericInitialize(`reader`, `stream`).

4. Set `reader`.[[readIntoRequests]] to a new empty list.

SetUpReadableStreamDefaultReader(`reader`, `stream`) performs the following steps:

1. If ! IsReadableStreamLocked(`stream`) is true, throw a `TypeError` exception.

2. Perform ! ReadableStreamReaderGenericInitialize(`reader`, `stream`).

3. Set `reader`.[[readRequests]] to a new empty list.


#### Default controllers

The following abstract operations support the implementation of the `ReadableStreamDefaultController` class.

ReadableStreamDefaultControllerCallPullIfNeeded(`controller`) performs the following steps:

1. Let `shouldPull` be ! ReadableStreamDefaultControllerShouldCallPull(`controller`).

2. If `shouldPull` is false, return.

3. If `controller`.[[pulling]] is true,

   1. Set `controller`.[[pullAgain]] to true.

   2. Return.

4. Assert: `controller`.[[pullAgain]] is false.

5. Set `controller`.[[pulling]] to true.

6. Let `pullPromise` be the result of performing `controller`.[[pullAlgorithm]].

7. Upon fulfillment of `pullPromise`,

   1. Set `controller`.[[pulling]] to false.

   2. If `controller`.[[pullAgain]] is true,

      1. Set `controller`.[[pullAgain]] to false.

      2. Perform ! ReadableStreamDefaultControllerCallPullIfNeeded(`controller`).

8. Upon rejection of `pullPromise` with reason `e`,

   1. Perform ! ReadableStreamDefaultControllerError(`controller`, `e`).

ReadableStreamDefaultControllerShouldCallPull(`controller`) performs the following steps:

1. Let `stream` be `controller`.[[stream]].

2. If ! ReadableStreamDefaultControllerCanCloseOrEnqueue(`controller`) is false, return false.

3. If `controller`.[[started]] is false, return false.

4. If ! IsReadableStreamLocked(`stream`) is true and ! ReadableStreamGetNumReadRequests(`stream`) > 0, return true.

5. Let `desiredSize` be ! ReadableStreamDefaultControllerGetDesiredSize(`controller`).

6. Assert: `desiredSize` is not null.

7. If `desiredSize` > 0, return true.

8. Return false.

ReadableStreamDefaultControllerClearAlgorithms(`controller`) is called once the stream is closed or errored and the algorithms will not be executed any more. By removing the algorithm references it permits the underlying source object to be garbage collected even if the `ReadableStream` itself is still referenced.

This is observable using weak references. See tc39/proposal-weakrefs#31 for more detail.

It performs the following steps:

1. Set `controller`.[[pullAlgorithm]] to undefined.

2. Set `controller`.[[cancelAlgorithm]] to undefined.

3. Set `controller`.[[strategySizeAlgorithm]] to undefined.

ReadableStreamDefaultControllerClose(`controller`) performs the following steps:

1. If ! ReadableStreamDefaultControllerCanCloseOrEnqueue(`controller`) is false, return.

2. Let `stream` be `controller`.[[stream]].

3. Set `controller`.[[closeRequested]] to true.

4. If `controller`.[[queue]] is empty,

   1. Perform ! ReadableStreamDefaultControllerClearAlgorithms(`controller`).

   2. Perform ! ReadableStreamClose(`stream`).

ReadableStreamDefaultControllerEnqueue(`controller`, `chunk`) performs the following steps:

1. If ! ReadableStreamDefaultControllerCanCloseOrEnqueue(`controller`) is false, return.

2. Let `stream` be `controller`.[[stream]].

3. If ! IsReadableStreamLocked(`stream`) is true and ! ReadableStreamGetNumReadRequests(`stream`) > 0, perform ! ReadableStreamFulfillReadRequest(`stream`, `chunk`, false).

4. Otherwise,

   1. Let `result` be the result of performing `controller`.[[strategySizeAlgorithm]], passing in `chunk`, and interpreting the result as a completion record.

   2. If `result` is an abrupt completion,

      1. Perform ! ReadableStreamDefaultControllerError(`controller`, `result`.[[Value]]).

      2. Return `result`.

   3. Let `chunkSize` be `result`.[[Value]].

   4. Let `enqueueResult` be EnqueueValueWithSize(`controller`, `chunk`, `chunkSize`).

   5. If `enqueueResult` is an abrupt completion,

      1. Perform ! ReadableStreamDefaultControllerError(`controller`, `enqueueResult`.[[Value]]).

      2. Return `enqueueResult`.

5. Perform ! ReadableStreamDefaultControllerCallPullIfNeeded(`controller`).

ReadableStreamDefaultControllerError(`controller`, `e`) performs the following steps:

1. Let `stream` be `controller`.[[stream]].

2. If `stream`.[[state]] is not "`readable`", return.

3. Perform ! ResetQueue(`controller`).

4. Perform ! ReadableStreamDefaultControllerClearAlgorithms(`controller`).

5. Perform ! ReadableStreamError(`stream`, `e`).

ReadableStreamDefaultControllerGetDesiredSize(`controller`) performs the following steps:

1. Let `state` be `controller`.[[stream]].[[state]].

2. If `state` is "`errored`", return null.

3. If `state` is "`closed`", return 0.

4. Return `controller`.[[strategyHWM]] − `controller`.[[queueTotalSize]].

ReadableStreamDefaultControllerHasBackpressure(`controller`) is used in the implementation of `TransformStream`. It performs the following steps:

1. If ! ReadableStreamDefaultControllerShouldCallPull(`controller`) is true, return false.

2. Otherwise, return true.

ReadableStreamDefaultControllerCanCloseOrEnqueue(`controller`) performs the following steps:

1. Let `state` be `controller`.[[stream]].[[state]].

2. If `controller`.[[closeRequested]] is false and `state` is "`readable`", return true.

3. Otherwise, return false.

The case where `controller`.[[closeRequested]] is false, but `state` is not "`readable`", happens when the stream is errored via `controller.error()`, or when it is closed without its controller's `controller.close()` method ever being called: e.g., if the stream was closed by a call to `stream.cancel()`.

SetUpReadableStreamDefaultController(`stream`, `controller`, `startAlgorithm`, `pullAlgorithm`, `cancelAlgorithm`, `highWaterMark`, `sizeAlgorithm`) performs the following steps:

1. Assert: `stream`.[[controller]] is undefined.

2. Set `controller`.[[stream]] to `stream`.

3. Perform ! ResetQueue(`controller`).

4. Set `controller`.[[started]], `controller`.[[closeRequested]], `controller`.[[pullAgain]], and `controller`.[[pulling]] to false.

5. Set `controller`.[[strategySizeAlgorithm]] to `sizeAlgorithm` and `controller`.[[strategyHWM]] to `highWaterMark`.

6. Set `controller`.[[pullAlgorithm]] to `pullAlgorithm`.

7. Set `controller`.[[cancelAlgorithm]] to `cancelAlgorithm`.

8. Set `stream`.[[controller]] to `controller`.

9. Let `startResult` be the result of performing `startAlgorithm`. (This might throw an exception.)

10. Let `startPromise` be a promise resolved with `startResult`.

11. Upon fulfillment of `startPromise`,

    1. Set `controller`.[[started]] to true.

    2. Assert: `controller`.[[pulling]] is false.

    3. Assert: `controller`.[[pullAgain]] is false.

    4. Perform ! ReadableStreamDefaultControllerCallPullIfNeeded(`controller`).

12. Upon rejection of `startPromise` with reason `r`,

    1. Perform ! ReadableStreamDefaultControllerError(`controller`, `r`).

SetUpReadableStreamDefaultControllerFromUnderlyingSource(`stream`, `underlyingSource`, `underlyingSourceDict`, `highWaterMark`, `sizeAlgorithm`) performs the following steps:

1. Let `controller` be a new `ReadableStreamDefaultController`.

2. Let `startAlgorithm` be an algorithm that returns undefined.

3. Let `pullAlgorithm` be an algorithm that returns a promise resolved with undefined.

4. Let `cancelAlgorithm` be an algorithm that returns a promise resolved with undefined.

5. If `underlyingSourceDict`["`start`"] exists, then set `startAlgorithm` to an algorithm which returns the result of invoking `underlyingSourceDict`["`start`"] with argument list « `controller` » and callback this value `underlyingSource`.

6. If `underlyingSourceDict`["`pull`"] exists, then set `pullAlgorithm` to an algorithm which returns the result of invoking `underlyingSourceDict`["`pull`"] with argument list « `controller` » and callback this value `underlyingSource`.

7. If `underlyingSourceDict`["`cancel`"] exists, then set `cancelAlgorithm` to an algorithm which takes an argument `reason` and returns the result of invoking `underlyingSourceDict`["`cancel`"] with argument list « `reason` » and callback this value `underlyingSource`.

8. Perform ? SetUpReadableStreamDefaultController(`stream`, `controller`, `startAlgorithm`, `pullAlgorithm`, `cancelAlgorithm`, `highWaterMark`, `sizeAlgorithm`).


#### Byte stream controllers

ReadableByteStreamControllerCallPullIfNeeded(`controller`) performs the following steps:

1. Let `shouldPull` be ! ReadableByteStreamControllerShouldCallPull(`controller`).

2. If `shouldPull` is false, return.

3. If `controller`.[[pulling]] is true,

   1. Set `controller`.[[pullAgain]] to true.

   2. Return.

4. Assert: `controller`.[[pullAgain]] is false.

5. Set `controller`.[[pulling]] to true.

6. Let `pullPromise` be the result of performing `controller`.[[pullAlgorithm]].

7. Upon fulfillment of `pullPromise`,

   1. Set `controller`.[[pulling]] to false.

   2. If `controller`.[[pullAgain]] is true,

      1. Set `controller`.[[pullAgain]] to false.

      2. Perform ! ReadableByteStreamControllerCallPullIfNeeded(`controller`).

8. Upon rejection of `pullPromise` with reason `e`,

   1. Perform ! ReadableByteStreamControllerError(`controller`, `e`).

ReadableByteStreamControllerClearAlgorithms(`controller`) is called once the stream is closed or errored and the algorithms will not be executed any more. By removing the algorithm references it permits the underlying byte source object to be garbage collected even if the `ReadableStream` itself is still referenced.

This is observable using weak references. See tc39/proposal-weakrefs#31 for more detail.

It performs the following steps:

1. Set `controller`.[[pullAlgorithm]] to undefined.

2. Set `controller`.[[cancelAlgorithm]] to undefined.

ReadableByteStreamControllerClearPendingPullIntos(`controller`) performs the following steps:

1. Perform ! ReadableByteStreamControllerInvalidateBYOBRequest(`controller`).

2. Set `controller`.[[pendingPullIntos]] to a new empty list.

ReadableByteStreamControllerClose(`controller`) performs the following steps:

1. Let `stream` be `controller`.[[stream]].

2. If `controller`.[[closeRequested]] is true or `stream`.[[state]] is not "`readable`", return.

3. If `controller`.[[queueTotalSize]] > 0,

   1. Set `controller`.[[closeRequested]] to true.

   2. Return.

4. If `controller`.[[pendingPullIntos]] is not empty,

   1. Let `firstPendingPullInto` be `controller`.[[pendingPullIntos]][0].

   2. If the remainder after dividing `firstPendingPullInto`'s bytes filled by `firstPendingPullInto`'s element size is not 0,

      1. Let `e` be a new `TypeError` exception.

      2. Perform ! ReadableByteStreamControllerError(`controller`, `e`).

      3. Throw `e`.

5. Perform ! ReadableByteStreamControllerClearAlgorithms(`controller`).

6. Perform ! ReadableStreamClose(`stream`).

ReadableByteStreamControllerCommitPullIntoDescriptor(`stream`, `pullIntoDescriptor`) performs the following steps:

1. Assert: `stream`.[[state]] is not "`errored`".

2. Assert: `pullIntoDescriptor`.reader type is not "`none`".

3. Let `done` be false.

4. If `stream`.[[state]] is "`closed`",

   1. Assert: the remainder after dividing `pullIntoDescriptor`'s bytes filled by `pullIntoDescriptor`'s element size is 0.

   2. Set `done` to true.

5. Let `filledView` be ! ReadableByteStreamControllerConvertPullIntoDescriptor(`pullIntoDescriptor`).

6. If `pullIntoDescriptor`'s reader type is "`default`",

   1. Perform ! ReadableStreamFulfillReadRequest(`stream`, `filledView`, `done`).

7. Otherwise,

   1. Assert: `pullIntoDescriptor`'s reader type is "`byob`".

   2. Perform ! ReadableStreamFulfillReadIntoRequest(`stream`, `filledView`, `done`).

ReadableByteStreamControllerConvertPullIntoDescriptor(`pullIntoDescriptor`) performs the following steps:

1. Let `bytesFilled` be `pullIntoDescriptor`'s bytes filled.

2. Let `elementSize` be `pullIntoDescriptor`'s element size.

3. Assert: `bytesFilled` ≤ `pullIntoDescriptor`'s byte length.

4. Assert: the remainder after dividing `bytesFilled` by `elementSize` is 0.

5. Let `buffer` be ! TransferArrayBuffer(`pullIntoDescriptor`'s buffer).

6. Return ! Construct(`pullIntoDescriptor`'s view constructor, « `buffer`, `pullIntoDescriptor`'s byte offset, `bytesFilled` ÷ `elementSize` »).

ReadableByteStreamControllerEnqueue(`controller`, `chunk`) performs the following steps:

1. Let `stream` be `controller`.[[stream]].

2. If `controller`.[[closeRequested]] is true or `stream`.[[state]] is not "`readable`", return.

3. Let `buffer` be `chunk`.[[ViewedArrayBuffer]].

4. Let `byteOffset` be `chunk`.[[ByteOffset]].

5. Let `byteLength` be `chunk`.[[ByteLength]].

6. If ! IsDetachedBuffer(`buffer`) is true, throw a `TypeError` exception.

7. Let `transferredBuffer` be ? TransferArrayBuffer(`buffer`).

8. If `controller`.[[pendingPullIntos]] is not empty,

   1. Let `firstPendingPullInto` be `controller`.[[pendingPullIntos]][0].

   2. If ! IsDetachedBuffer(`firstPendingPullInto`'s buffer) is true, throw a `TypeError` exception.

   3. Perform ! ReadableByteStreamControllerInvalidateBYOBRequest(`controller`).

   4. Set `firstPendingPullInto`'s buffer to ! TransferArrayBuffer(`firstPendingPullInto`'s buffer).

   5. If `firstPendingPullInto`'s reader type is "`none`", perform ? ReadableByteStreamControllerEnqueueDetachedPullIntoToQueue(`controller`, `firstPendingPullInto`).

9. If ! ReadableStreamHasDefaultReader(`stream`) is true,

   1. Perform ! ReadableByteStreamControllerProcessReadRequestsUsingQueue(`controller`).

   2. If ! ReadableStreamGetNumReadRequests(`stream`) is 0,

      1. Assert: `controller`.[[pendingPullIntos]] is empty.

      2. Perform ! ReadableByteStreamControllerEnqueueChunkToQueue(`controller`, `transferredBuffer`, `byteOffset`, `byteLength`).

   3. Otherwise,

      1. Assert: `controller`.[[queue]] is empty.

      2. If `controller`.[[pendingPullIntos]] is not empty,

         1. Assert: `controller`.[[pendingPullIntos]][0]\'s reader type is "`default`".

         2. Perform ! ReadableByteStreamControllerShiftPendingPullInto(`controller`).

      3. Let `transferredView` be ! Construct(`%Uint8Array%`, « `transferredBuffer`, `byteOffset`, `byteLength` »).

      4. Perform ! ReadableStreamFulfillReadRequest(`stream`, `transferredView`, false).

10. Otherwise, if ! ReadableStreamHasBYOBReader(`stream`) is true,

    1. Perform ! ReadableByteStreamControllerEnqueueChunkToQueue(`controller`, `transferredBuffer`, `byteOffset`, `byteLength`).

    2. Let `filledPullIntos` be the result of performing ! ReadableByteStreamControllerProcessPullIntoDescriptorsUsingQueue(`controller`).

    3. For each `filledPullInto` of `filledPullIntos`,

       1. Perform ! ReadableByteStreamControllerCommitPullIntoDescriptor(`stream`, `filledPullInto`).

11. Otherwise,

    1. Assert: ! IsReadableStreamLocked(`stream`) is false.

    2. Perform ! ReadableByteStreamControllerEnqueueChunkToQueue(`controller`, `transferredBuffer`, `byteOffset`, `byteLength`).

12. Perform ! ReadableByteStreamControllerCallPullIfNeeded(`controller`).

ReadableByteStreamControllerEnqueueChunkToQueue(`controller`, `buffer`, `byteOffset`, `byteLength`) performs the following steps:

1. Append a new readable byte stream queue entry with buffer `buffer`, byte offset `byteOffset`, and byte length `byteLength` to `controller`.[[queue]].

2. Set `controller`.[[queueTotalSize]] to `controller`.[[queueTotalSize]] + `byteLength`.

ReadableByteStreamControllerEnqueueClonedChunkToQueue(`controller`, `buffer`, `byteOffset`, `byteLength`) performs the following steps:

1. Let `cloneResult` be CloneArrayBuffer(`buffer`, `byteOffset`, `byteLength`, `%ArrayBuffer%`).

2. If `cloneResult` is an abrupt completion,

   1. Perform ! ReadableByteStreamControllerError(`controller`, `cloneResult`.[[Value]]).

   2. Return `cloneResult`.

3. Perform ! ReadableByteStreamControllerEnqueueChunkToQueue(`controller`, `cloneResult`.[[Value]], 0, `byteLength`).

ReadableByteStreamControllerEnqueueDetachedPullIntoToQueue(`controller`, `pullIntoDescriptor`) performs the following steps:

1. Assert: `pullIntoDescriptor`'s reader type is "`none`".

2. If `pullIntoDescriptor`'s bytes filled > 0, perform ? ReadableByteStreamControllerEnqueueClonedChunkToQueue(`controller`, `pullIntoDescriptor`'s buffer, `pullIntoDescriptor`'s byte offset, `pullIntoDescriptor`'s bytes filled).

3. Perform ! ReadableByteStreamControllerShiftPendingPullInto(`controller`).

ReadableByteStreamControllerError(`controller`, `e`) performs the following steps:

1. Let `stream` be `controller`.[[stream]].

2. If `stream`.[[state]] is not "`readable`", return.

3. Perform ! ReadableByteStreamControllerClearPendingPullIntos(`controller`).

4. Perform ! ResetQueue(`controller`).

5. Perform ! ReadableByteStreamControllerClearAlgorithms(`controller`).

6. Perform ! ReadableStreamError(`stream`, `e`).

ReadableByteStreamControllerFillHeadPullIntoDescriptor(`controller`, `size`, `pullIntoDescriptor`) performs the following steps:

1. Assert: either `controller`.[[pendingPullIntos]] is empty, or `controller`.[[pendingPullIntos]][0] is `pullIntoDescriptor`.

2. Assert: `controller`.[[byobRequest]] is null.

3. Set `pullIntoDescriptor`'s bytes filled to bytes filled + `size`.

ReadableByteStreamControllerFillPullIntoDescriptorFromQueue(`controller`, `pullIntoDescriptor`) performs the following steps:

1. Let `maxBytesToCopy` be min(`controller`.[[queueTotalSize]], `pullIntoDescriptor`'s byte length − `pullIntoDescriptor`'s bytes filled).

2. Let `maxBytesFilled` be `pullIntoDescriptor`'s bytes filled + `maxBytesToCopy`.

3. Let `totalBytesToCopyRemaining` be `maxBytesToCopy`.

4. Let `ready` be false.

5. Assert: ! IsDetachedBuffer(`pullIntoDescriptor`'s buffer) is false.

6. Assert: `pullIntoDescriptor`'s bytes filled < `pullIntoDescriptor`'s minimum fill.

7. Let `remainderBytes` be the remainder after dividing `maxBytesFilled` by `pullIntoDescriptor`'s element size.

8. Let `maxAlignedBytes` be `maxBytesFilled` − `remainderBytes`.

9. If `maxAlignedBytes` ≥ `pullIntoDescriptor`'s minimum fill,

   1. Set `totalBytesToCopyRemaining` to `maxAlignedBytes` − `pullIntoDescriptor`'s bytes filled.

   2. Set `ready` to true.

   A descriptor for a `read()` request that is not yet filled up to its minimum length will stay at the head of the queue, so the underlying source can keep filling it.

10. Let `queue` be `controller`.[[queue]].

11. While `totalBytesToCopyRemaining` > 0,

    1. Let `headOfQueue` be `queue`[0].

    2. Let `bytesToCopy` be min(`totalBytesToCopyRemaining`, `headOfQueue`'s byte length).

    3. Let `destStart` be `pullIntoDescriptor`'s byte offset + `pullIntoDescriptor`'s bytes filled.

    4. Let `descriptorBuffer` be `pullIntoDescriptor`'s buffer.

    5. Let `queueBuffer` be `headOfQueue`'s buffer.

    6. Let `queueByteOffset` be `headOfQueue`'s byte offset.

    7. Assert: ! CanCopyDataBlockBytes(`descriptorBuffer`, `destStart`, `queueBuffer`, `queueByteOffset`, `bytesToCopy`) is true.

    If this assertion were to fail (due to a bug in this specification or its implementation), then the next step may read from or write to potentially invalid memory. The user agent should always check this assertion, and stop in an implementation-defined manner if it fails (e.g. by crashing the process, or by erroring the stream).

    8. Perform ! CopyDataBlockBytes(`descriptorBuffer`.[[ArrayBufferData]], `destStart`, `queueBuffer`.[[ArrayBufferData]], `queueByteOffset`, `bytesToCopy`).

    9. If `headOfQueue`'s byte length is `bytesToCopy`,

       1. Remove `queue`[0].

    10. Otherwise,

        1. Set `headOfQueue`'s byte offset to `headOfQueue`'s byte offset + `bytesToCopy`.

        2. Set `headOfQueue`'s byte length to `headOfQueue`'s byte length − `bytesToCopy`.

    11. Set `controller`.[[queueTotalSize]] to `controller`.[[queueTotalSize]] − `bytesToCopy`.

    12. Perform ! ReadableByteStreamControllerFillHeadPullIntoDescriptor(`controller`, `bytesToCopy`, `pullIntoDescriptor`).

    13. Set `totalBytesToCopyRemaining` to `totalBytesToCopyRemaining` − `bytesToCopy`.

12. If `ready` is false,

    1. Assert: `controller`.[[queueTotalSize]] is 0.

    2. Assert: `pullIntoDescriptor`'s bytes filled > 0.

    3. Assert: `pullIntoDescriptor`'s bytes filled < `pullIntoDescriptor`'s minimum fill.

13. Return `ready`.

ReadableByteStreamControllerFillReadRequestFromQueue(`controller`, `readRequest`) performs the following steps:

1. Assert: `controller`.[[queueTotalSize]] > 0.

2. Let `entry` be `controller`.[[queue]][0].

3. Remove `entry` from `controller`.[[queue]].

4. Set `controller`.[[queueTotalSize]] to `controller`.[[queueTotalSize]] − `entry`'s byte length.

5. Perform ! ReadableByteStreamControllerHandleQueueDrain(`controller`).

6. Let `view` be ! Construct(`%Uint8Array%`, « `entry`'s buffer, `entry`'s byte offset, `entry`'s byte length »).

7. Perform `readRequest`'s chunk steps, given `view`.

ReadableByteStreamControllerGetBYOBRequest(`controller`) performs the following steps:

1. If `controller`.[[byobRequest]] is null and `controller`.[[pendingPullIntos]] is not empty,

   1. Let `firstDescriptor` be `controller`.[[pendingPullIntos]][0].

   2. Let `view` be ! Construct(`%Uint8Array%`, « `firstDescriptor`'s buffer, `firstDescriptor`'s byte offset + `firstDescriptor`'s bytes filled, `firstDescriptor`'s byte length − `firstDescriptor`'s bytes filled »).

   3. Let `byobRequest` be a new `ReadableStreamBYOBRequest`.

   4. Set `byobRequest`.[[controller]] to `controller`.

   5. Set `byobRequest`.[[view]] to `view`.

   6. Set `controller`.[[byobRequest]] to `byobRequest`.

2. Return `controller`.[[byobRequest]].

ReadableByteStreamControllerGetDesiredSize(`controller`) performs the following steps:

1. Let `state` be `controller`.[[stream]].[[state]].

2. If `state` is "`errored`", return null.

3. If `state` is "`closed`", return 0.

4. Return `controller`.[[strategyHWM]] − `controller`.[[queueTotalSize]].

ReadableByteStreamControllerHandleQueueDrain(`controller`) performs the following steps:

1. Assert: `controller`.[[stream]].[[state]] is "`readable`".

2. If `controller`.[[queueTotalSize]] is 0 and `controller`.[[closeRequested]] is true,

   1. Perform ! ReadableByteStreamControllerClearAlgorithms(`controller`).

   2. Perform ! ReadableStreamClose(`controller`.[[stream]]).

3. Otherwise,

   1. Perform ! ReadableByteStreamControllerCallPullIfNeeded(`controller`).

ReadableByteStreamControllerInvalidateBYOBRequest(`controller`) performs the following steps:

1. If `controller`.[[byobRequest]] is null, return.

2. Set `controller`.[[byobRequest]].[[controller]] to undefined.

3. Set `controller`.[[byobRequest]].[[view]] to null.

4. Set `controller`.[[byobRequest]] to null.

ReadableByteStreamControllerProcessPullIntoDescriptorsUsingQueue(`controller`) performs the following steps:

1. Assert: `controller`.[[closeRequested]] is false.

2. Let `filledPullIntos` be a new empty list.

3. While `controller`.[[pendingPullIntos]] is not empty,

   1. If `controller`.[[queueTotalSize]] is 0, then break.

   2. Let `pullIntoDescriptor` be `controller`.[[pendingPullIntos]][0].

   3. If ! ReadableByteStreamControllerFillPullIntoDescriptorFromQueue(`controller`, `pullIntoDescriptor`) is true,

      1. Perform ! ReadableByteStreamControllerShiftPendingPullInto(`controller`).

      2. Append `pullIntoDescriptor` to `filledPullIntos`.

4. Return `filledPullIntos`.

ReadableByteStreamControllerProcessReadRequestsUsingQueue(`controller`) performs the following steps:

1. Let `reader` be `controller`.[[stream]].[[reader]].

2. Assert: `reader` implements `ReadableStreamDefaultReader`.

3. While `reader`.[[readRequests]] is not empty,

   1. If `controller`.[[queueTotalSize]] is 0, return.

   2. Let `readRequest` be `reader`.[[readRequests]][0].

   3. Remove `readRequest` from `reader`.[[readRequests]].

   4. Perform ! ReadableByteStreamControllerFillReadRequestFromQueue(`controller`, `readRequest`).

ReadableByteStreamControllerPullInto(`controller`, `view`, `min`, `readIntoRequest`) performs the following steps:

1. Let `stream` be `controller`.[[stream]].

2. Let `elementSize` be 1.

3. Let `ctor` be `%DataView%`.

4. If `view` has a [[TypedArrayName]] internal slot (i.e., it is not a `DataView`),

   1. Set `elementSize` to the element size specified in the typed array constructors table for `view`.[[TypedArrayName]].

   2. Set `ctor` to the constructor specified in the typed array constructors table for `view`.[[TypedArrayName]].

5. Let `minimumFill` be `min` × `elementSize`.

6. Assert: `minimumFill` ≥ 0 and `minimumFill` ≤ `view`.[[ByteLength]].

7. Assert: the remainder after dividing `minimumFill` by `elementSize` is 0.

8. Let `byteOffset` be `view`.[[ByteOffset]].

9. Let `byteLength` be `view`.[[ByteLength]].

10. Let `bufferResult` be TransferArrayBuffer(`view`.[[ViewedArrayBuffer]]).

11. If `bufferResult` is an abrupt completion,

    1. Perform `readIntoRequest`'s error steps, given `bufferResult`.[[Value]].

    2. Return.

12. Let `buffer` be `bufferResult`.[[Value]].

13. Let `pullIntoDescriptor` be a new pull-into descriptor with

    buffer
    :   `buffer`

    buffer byte length
    :   `buffer`.[[ArrayBufferByteLength]]

    byte offset
    :   `byteOffset`

    byte length
    :   `byteLength`

    bytes filled
    :   0

    minimum fill
    :   `minimumFill`

    element size
    :   `elementSize`

    view constructor
    :   `ctor`

    reader type
    :   "`byob`"

14. If `controller`.[[pendingPullIntos]] is not empty,

    1. Append `pullIntoDescriptor` to `controller`.[[pendingPullIntos]].

    2. Perform ! ReadableStreamAddReadIntoRequest(`stream`, `readIntoRequest`).

    3. Return.

15. If `stream`.[[state]] is "`closed`",

    1. Let `emptyView` be ! Construct(`ctor`, « `pullIntoDescriptor`'s buffer, `pullIntoDescriptor`'s byte offset, 0 »).

    2. Perform `readIntoRequest`'s close steps, given `emptyView`.

    3. Return.

16. If `controller`.[[queueTotalSize]] > 0,

    1. If ! ReadableByteStreamControllerFillPullIntoDescriptorFromQueue(`controller`, `pullIntoDescriptor`) is true,

       1. Let `filledView` be ! ReadableByteStreamControllerConvertPullIntoDescriptor(`pullIntoDescriptor`).

       2. Perform ! ReadableByteStreamControllerHandleQueueDrain(`controller`).

       3. Perform `readIntoRequest`'s chunk steps, given `filledView`.

       4. Return.

    2. If `controller`.[[closeRequested]] is true,

       1. Let `e` be a `TypeError` exception.

       2. Perform ! ReadableByteStreamControllerError(`controller`, `e`).

       3. Perform `readIntoRequest`'s error steps, given `e`.

       4. Return.

17. Append `pullIntoDescriptor` to `controller`.[[pendingPullIntos]].

18. Perform ! ReadableStreamAddReadIntoRequest(`stream`, `readIntoRequest`).

19. Perform ! ReadableByteStreamControllerCallPullIfNeeded(`controller`).

ReadableByteStreamControllerRespond(`controller`, `bytesWritten`) performs the following steps:

1. Assert: `controller`.[[pendingPullIntos]] is not empty.

2. Let `firstDescriptor` be `controller`.[[pendingPullIntos]][0].

3. Let `state` be `controller`.[[stream]].[[state]].

4. If `state` is "`closed`",

   1. If `bytesWritten` is not 0, throw a `TypeError` exception.

5. Otherwise,

   1. Assert: `state` is "`readable`".

   2. If `bytesWritten` is 0, throw a `TypeError` exception.

   3. If `firstDescriptor`'s bytes filled + `bytesWritten` > `firstDescriptor`'s byte length, throw a `RangeError` exception.

6. Set `firstDescriptor`'s buffer to ! TransferArrayBuffer(`firstDescriptor`'s buffer).

7. Perform ? ReadableByteStreamControllerRespondInternal(`controller`, `bytesWritten`).

ReadableByteStreamControllerRespondInClosedState(`controller`, `firstDescriptor`) performs the following steps:

1. Assert: the remainder after dividing `firstDescriptor`'s bytes filled by `firstDescriptor`'s element size is 0.

2. If `firstDescriptor`'s reader type is "`none`", perform ! ReadableByteStreamControllerShiftPendingPullInto(`controller`).

3. Let `stream` be `controller`.[[stream]].

4. If ! ReadableStreamHasBYOBReader(`stream`) is true,

   1. Let `filledPullIntos` be a new empty list.

   2. While `filledPullIntos`'s size < ! ReadableStreamGetNumReadIntoRequests(`stream`),

      1. Let `pullIntoDescriptor` be ! ReadableByteStreamControllerShiftPendingPullInto(`controller`).

      2. Append `pullIntoDescriptor` to `filledPullIntos`.

   3. For each `filledPullInto` of `filledPullIntos`,

      1. Perform ! ReadableByteStreamControllerCommitPullIntoDescriptor(`stream`, `filledPullInto`).

ReadableByteStreamControllerRespondInReadableState(`controller`, `bytesWritten`, `pullIntoDescriptor`) performs the following steps:

1. Assert: `pullIntoDescriptor`'s bytes filled + `bytesWritten` ≤ `pullIntoDescriptor`'s byte length.

2. Perform ! ReadableByteStreamControllerFillHeadPullIntoDescriptor(`controller`, `bytesWritten`, `pullIntoDescriptor`).

3. If `pullIntoDescriptor`'s reader type is "`none`",

   1. Perform ? ReadableByteStreamControllerEnqueueDetachedPullIntoToQueue(`controller`, `pullIntoDescriptor`).

   2. Let `filledPullIntos` be the result of performing ! ReadableByteStreamControllerProcessPullIntoDescriptorsUsingQueue(`controller`).

   3. For each `filledPullInto` of `filledPullIntos`,

      1. Perform ! ReadableByteStreamControllerCommitPullIntoDescriptor(`controller`.[[stream]], `filledPullInto`).

   4. Return.

4. If `pullIntoDescriptor`'s bytes filled < `pullIntoDescriptor`'s minimum fill, return.

A descriptor for a `read()` request that is not yet filled up to its minimum length will stay at the head of the queue, so the underlying source can keep filling it.

5. Perform ! ReadableByteStreamControllerShiftPendingPullInto(`controller`).

6. Let `remainderSize` be the remainder after dividing `pullIntoDescriptor`'s bytes filled by `pullIntoDescriptor`'s element size.

7. If `remainderSize` > 0,

   1. Let `end` be `pullIntoDescriptor`'s byte offset + `pullIntoDescriptor`'s bytes filled.

   2. Perform ? ReadableByteStreamControllerEnqueueClonedChunkToQueue(`controller`, `pullIntoDescriptor`'s buffer, `end` − `remainderSize`, `remainderSize`).

8. Set `pullIntoDescriptor`'s bytes filled to `pullIntoDescriptor`'s bytes filled − `remainderSize`.

9. Let `filledPullIntos` be the result of performing ! ReadableByteStreamControllerProcessPullIntoDescriptorsUsingQueue(`controller`).

10. Perform ! ReadableByteStreamControllerCommitPullIntoDescriptor(`controller`.[[stream]], `pullIntoDescriptor`).

11. For each `filledPullInto` of `filledPullIntos`,

    1. Perform ! ReadableByteStreamControllerCommitPullIntoDescriptor(`controller`.[[stream]], `filledPullInto`).

ReadableByteStreamControllerRespondInternal(`controller`, `bytesWritten`) performs the following steps:

1. Let `firstDescriptor` be `controller`.[[pendingPullIntos]][0].

2. Assert: ! CanTransferArrayBuffer(`firstDescriptor`'s buffer) is true.

3. Perform ! ReadableByteStreamControllerInvalidateBYOBRequest(`controller`).

4. Let `state` be `controller`.[[stream]].[[state]].

5. If `state` is "`closed`",

   1. Assert: `bytesWritten` is 0.

   2. Perform ! ReadableByteStreamControllerRespondInClosedState(`controller`, `firstDescriptor`).

6. Otherwise,

   1. Assert: `state` is "`readable`".

   2. Assert: `bytesWritten` > 0.

   3. Perform ? ReadableByteStreamControllerRespondInReadableState(`controller`, `bytesWritten`, `firstDescriptor`).

7. Perform ! ReadableByteStreamControllerCallPullIfNeeded(`controller`).

ReadableByteStreamControllerRespondWithNewView(`controller`, `view`) performs the following steps:

1. Assert: `controller`.[[pendingPullIntos]] is not empty.

2. Assert: ! IsDetachedBuffer(`view`.[[ViewedArrayBuffer]]) is false.

3. Let `firstDescriptor` be `controller`.[[pendingPullIntos]][0].

4. Let `state` be `controller`.[[stream]].[[state]].

5. If `state` is "`closed`",

   1. If `view`.[[ByteLength]] is not 0, throw a `TypeError` exception.

6. Otherwise,

   1. Assert: `state` is "`readable`".

   2. If `view`.[[ByteLength]] is 0, throw a `TypeError` exception.

7. If `firstDescriptor`'s byte offset + `firstDescriptor`' bytes filled is not `view`.[[ByteOffset]], throw a `RangeError` exception.

8. If `firstDescriptor`'s buffer byte length is not `view`.[[ViewedArrayBuffer]].[[ByteLength]], throw a `RangeError` exception.

9. If `firstDescriptor`'s bytes filled + `view`.[[ByteLength]] > `firstDescriptor`'s byte length, throw a `RangeError` exception.

10. Let `viewByteLength` be `view`.[[ByteLength]].

11. Set `firstDescriptor`'s buffer to ? TransferArrayBuffer(`view`.[[ViewedArrayBuffer]]).

12. Perform ? ReadableByteStreamControllerRespondInternal(`controller`, `viewByteLength`).

ReadableByteStreamControllerShiftPendingPullInto(`controller`) performs the following steps:

1. Assert: `controller`.[[byobRequest]] is null.

2. Let `descriptor` be `controller`.[[pendingPullIntos]][0].

3. Remove `descriptor` from `controller`.[[pendingPullIntos]].

4. Return `descriptor`.

ReadableByteStreamControllerShouldCallPull(`controller`) performs the following steps:

1. Let `stream` be `controller`.[[stream]].

2. If `stream`.[[state]] is not "`readable`", return false.

3. If `controller`.[[closeRequested]] is true, return false.

4. If `controller`.[[started]] is false, return false.

5. If ! ReadableStreamHasDefaultReader(`stream`) is true and ! ReadableStreamGetNumReadRequests(`stream`) > 0, return true.

6. If ! ReadableStreamHasBYOBReader(`stream`) is true and ! ReadableStreamGetNumReadIntoRequests(`stream`) > 0, return true.

7. Let `desiredSize` be ! ReadableByteStreamControllerGetDesiredSize(`controller`).

8. Assert: `desiredSize` is not null.

9. If `desiredSize` > 0, return true.

10. Return false.

SetUpReadableByteStreamController(`stream`, `controller`, `startAlgorithm`, `pullAlgorithm`, `cancelAlgorithm`, `highWaterMark`, `autoAllocateChunkSize`) performs the following steps:

1. Assert: `stream`.[[controller]] is undefined.

2. If `autoAllocateChunkSize` is not undefined,

   1. Assert: ! IsInteger(`autoAllocateChunkSize`) is true.

   2. Assert: `autoAllocateChunkSize` is positive.

3. Set `controller`.[[stream]] to `stream`.

4. Set `controller`.[[pullAgain]] and `controller`.[[pulling]] to false.

5. Set `controller`.[[byobRequest]] to null.

6. Perform ! ResetQueue(`controller`).

7. Set `controller`.[[closeRequested]] and `controller`.[[started]] to false.

8. Set `controller`.[[strategyHWM]] to `highWaterMark`.

9. Set `controller`.[[pullAlgorithm]] to `pullAlgorithm`.

10. Set `controller`.[[cancelAlgorithm]] to `cancelAlgorithm`.

11. Set `controller`.[[autoAllocateChunkSize]] to `autoAllocateChunkSize`.

12. Set `controller`.[[pendingPullIntos]] to a new empty list.

13. Set `stream`.[[controller]] to `controller`.

14. Let `startResult` be the result of performing `startAlgorithm`.

15. Let `startPromise` be a promise resolved with `startResult`.

16. Upon fulfillment of `startPromise`,

    1. Set `controller`.[[started]] to true.

    2. Assert: `controller`.[[pulling]] is false.

    3. Assert: `controller`.[[pullAgain]] is false.

    4. Perform ! ReadableByteStreamControllerCallPullIfNeeded(`controller`).

17. Upon rejection of `startPromise` with reason `r`,

    1. Perform ! ReadableByteStreamControllerError(`controller`, `r`).

SetUpReadableByteStreamControllerFromUnderlyingSource(`stream`, `underlyingSource`, `underlyingSourceDict`, `highWaterMark`) performs the following steps:

1. Let `controller` be a new `ReadableByteStreamController`.

2. Let `startAlgorithm` be an algorithm that returns undefined.

3. Let `pullAlgorithm` be an algorithm that returns a promise resolved with undefined.

4. Let `cancelAlgorithm` be an algorithm that returns a promise resolved with undefined.

5. If `underlyingSourceDict`["`start`"] exists, then set `startAlgorithm` to an algorithm which returns the result of invoking `underlyingSourceDict`["`start`"] with argument list « `controller` » and callback this value `underlyingSource`.

6. If `underlyingSourceDict`["`pull`"] exists, then set `pullAlgorithm` to an algorithm which returns the result of invoking `underlyingSourceDict`["`pull`"] with argument list « `controller` » and callback this value `underlyingSource`.

7. If `underlyingSourceDict`["`cancel`"] exists, then set `cancelAlgorithm` to an algorithm which takes an argument `reason` and returns the result of invoking `underlyingSourceDict`["`cancel`"] with argument list « `reason` » and callback this value `underlyingSource`.

8. Let `autoAllocateChunkSize` be `underlyingSourceDict`["`autoAllocateChunkSize`"], if it exists, or undefined otherwise.

9. If `autoAllocateChunkSize` is 0, then throw a `TypeError` exception.

10. Perform ? SetUpReadableByteStreamController(`stream`, `controller`, `startAlgorithm`, `pullAlgorithm`, `cancelAlgorithm`, `highWaterMark`, `autoAllocateChunkSize`).


## Writable streams


### Using writable streams

The usual way to write to a writable stream is to simply pipe a readable stream to it. This ensures that backpressure is respected, so that if the writable stream's underlying sink is not able to accept data as fast as the readable stream can produce it, the readable stream is informed of this and has a chance to slow down its data production.

``` highlight
readableStream.pipeTo(writableStream)
  .then(() => console.log("All data successfully written!"))
  .catch(e => console.error("Something went wrong!", e));
```

You can also write directly to writable streams by acquiring a writer and using its `write()` and `close()` methods. Since writable streams queue any incoming writes, and take care internally to forward them to the underlying sink in sequence, you can indiscriminately write to a writable stream without much ceremony:

``` highlight
function writeArrayToStream(array, writableStream) {
  const writer = writableStream.getWriter();
  array.forEach(chunk => writer.write(chunk).catch(() => {}));

  return writer.close();
}

writeArrayToStream([1, 2, 3, 4, 5], writableStream)
  .then(() => console.log("All done!"))
  .catch(e => console.error("Error with the stream: " + e));
```

Note how we use `.catch(() => {})` to suppress any rejections from the `write()` method; we'll be notified of any fatal errors via a rejection of the `close()` method, and leaving them un-caught would cause potential `unhandledrejection` events and console warnings.

In the previous example we only paid attention to the success or failure of the entire stream, by looking at the promise returned by the writer's `close()` method. That promise will reject if anything goes wrong with the stream---initializing it, writing to it, or closing it. And it will fulfill once the stream is successfully closed. Often this is all you care about.

However, if you care about the success of writing a specific chunk, you can use the promise returned by the writer's `write()` method:

``` highlight
writer.write("i am a chunk of data")
  .then(() => console.log("chunk successfully written!"))
  .catch(e => console.error(e));
```

What "success" means is up to a given stream instance (or more precisely, its underlying sink) to decide. For example, for a file stream it could simply mean that the OS has accepted the write, and not necessarily that the chunk has been flushed to disk. Some streams might not be able to give such a signal at all, in which case the returned promise will fulfill immediately.

The `desiredSize` and `ready` properties of writable stream writers allow producers to more precisely respond to flow control signals from the stream, to keep memory usage below the stream's specified high water mark. The following example writes an infinite sequence of random bytes to a stream, using `desiredSize` to determine how many bytes to generate at a given time, and using `ready` to wait for the backpressure to subside.

``` highlight
async function writeRandomBytesForever(writableStream) {
  const writer = writableStream.getWriter();

  while (true) {
    await writer.ready;

    const bytes = new Uint8Array(writer.desiredSize);
    crypto.getRandomValues(bytes);

    // Purposefully don't await; awaiting writer.ready is enough.
    writer.write(bytes).catch(() => {});
  }
}

writeRandomBytesForever(myWritableStream).catch(e => console.error("Something broke", e));
```

Note how we don't `await` the promise returned by `write()`; this would be redundant with `await`ing the `ready` promise. Additionally, similar to a previous example, we use the `.catch(() => {})` pattern on the promises returned by `write()`; in this case we'll be notified about any failures `await`ing the `ready` promise.

To further emphasize how it's a bad idea to `await` the promise returned by `write()`, consider a modification of the above example, where we continue to use the `WritableStreamDefaultWriter` interface directly, but we don't control how many bytes we have to write at a given time. In that case, the backpressure-respecting code looks the same:

``` highlight
async function writeSuppliedBytesForever(writableStream, getBytes) {
  const writer = writableStream.getWriter();

  while (true) {
    await writer.ready;

    const bytes = getBytes();
    writer.write(bytes).catch(() => {});
  }
}
```

Unlike the previous example, where---because we were always writing exactly `writer.desiredSize` bytes each time---the `write()` and `ready` promises were synchronized, in this case it's quite possible that the `ready` promise fulfills before the one returned by `write()` does. Remember, the `ready` promise fulfills when the desired size becomes positive, which might be before the write succeeds (especially in cases with a larger high water mark).

In other words, `await`ing the return value of `write()` means you never queue up writes in the stream's internal queue, instead only executing a write after the previous one succeeds, which can result in low throughput.


### The `WritableStream` class

The `WritableStream` represents a writable stream.


#### Interface definition

The Web IDL definition for the `WritableStream` class is given as follows:

``` idl
[Exposed=*, Transferable]
interface WritableStream {
  constructor(optional object underlyingSink, optional QueuingStrategy strategy = {});

  readonly attribute boolean locked;

  Promise<undefined> abort(optional any reason);
  Promise<undefined> close();
  WritableStreamDefaultWriter getWriter();
};
```


#### Internal slots

Instances of `WritableStream` are created with the internal slots described in the following table:

| Internal Slot | Description (*non-normative*) |
|---|---|
| [[backpressure]] | A boolean indicating the backpressure signal set by the controller |
| [[closeRequest]] | The promise returned from the writer's `close()` method |
| [[controller]] | A `WritableStreamDefaultController` created with the ability to control the state and queue of this stream |
| [[Detached]] | A boolean flag set to true when the stream is transferred |
| [[inFlightWriteRequest]] | A slot set to the promise for the current in-flight write operation while the underlying sink's write algorithm is executing and has not yet fulfilled, used to prevent reentrant calls |
| [[inFlightCloseRequest]] | A slot set to the promise for the current in-flight close operation while the underlying sink's close algorithm is executing and has not yet fulfilled, used to prevent the `abort()` method from interrupting close |
| [[pendingAbortRequest]] | A pending abort request |
| [[state]] | A string containing the stream's current state, used internally; one of "`writable`", "`closed`", "`erroring`", or "`errored`" |
| [[storedError]] | A value indicating how the stream failed, to be given as a failure reason or exception when trying to operate on the stream while in the "`errored`" state |
| [[writer]] | A `WritableStreamDefaultWriter` instance, if the stream is locked to a writer, or undefined if it is not |
| [[writeRequests]] | A list of promises representing the stream's internal queue of write requests not yet processed by the underlying sink |

The [[inFlightCloseRequest]] slot and [[closeRequest]] slot are mutually exclusive. Similarly, no element will be removed from [[writeRequests]] while [[inFlightWriteRequest]] is not undefined. Implementations can optimize storage for these slots based on these invariants.

A **pending abort request** is a struct used to track a request to abort the stream before that request is finally processed. It has the following items:

promise
:   A promise returned from WritableStreamAbort

reason
:   A JavaScript value that was passed as the abort reason to WritableStreamAbort

was already erroring
:   A boolean indicating whether or not the stream was in the "`erroring`" state when WritableStreamAbort was called, which impacts the outcome of the abort request


#### The underlying sink API

The `WritableStream()` constructor accepts as its first argument a JavaScript object representing the underlying sink. Such objects can contain any of the following properties:

``` idl
dictionary UnderlyingSink {
  UnderlyingSinkStartCallback start;
  UnderlyingSinkWriteCallback write;
  UnderlyingSinkCloseCallback close;
  UnderlyingSinkAbortCallback abort;
  any type;
};

callback UnderlyingSinkStartCallback = any (WritableStreamDefaultController controller);
callback UnderlyingSinkWriteCallback = Promise<undefined> (any chunk, WritableStreamDefaultController controller);
callback UnderlyingSinkCloseCallback = Promise<undefined> ();
callback UnderlyingSinkAbortCallback = Promise<undefined> (optional any reason);
```

`start(controller)`, of type UnderlyingSinkStartCallback

:   A function that is called immediately during creation of the `WritableStream`.

    Typically this is used to acquire access to the underlying sink resource being represented.

    If this setup process is asynchronous, it can return a promise to signal success or failure; a rejected promise will error the stream. Any thrown exceptions will be re-thrown by the `WritableStream()` constructor.

`write(chunk, controller)`, of type UnderlyingSinkWriteCallback

:   A function that is called when a new chunk of data is ready to be written to the underlying sink. The stream implementation guarantees that this function will be called only after previous writes have succeeded, and never before `start()` has succeeded or after `close()` or `abort()` have been called.

    This function is used to actually send the data to the resource presented by the underlying sink, for example by calling a lower-level API.

    If the process of writing data is asynchronous, and communicates success or failure signals back to its user, then this function can return a promise to signal success or failure. This promise return value will be communicated back to the caller of `writer.write()`, so they can monitor that individual write. Throwing an exception is treated the same as returning a rejected promise.

    Note that such signals are not always available; compare e.g. § 10.6 A writable stream with no backpressure or success signals with § 10.7 A writable stream with backpressure and success signals. In such cases, it's best to not return anything.

    The promise potentially returned by this function also governs whether the given chunk counts as written for the purposes of computed the desired size to fill the stream's internal queue. That is, during the time it takes the promise to settle, `writer.desiredSize` will stay at its previous value, only increasing to signal the desire for more chunks once the write succeeds.

    Finally, the promise potentially returned by this function is used to ensure that well-behaved producers do not attempt to mutate the chunk before it has been fully processed. (This is not guaranteed by any specification machinery, but instead is an informal contract between producers and the underlying sink.)

`close()`, of type UnderlyingSinkCloseCallback

:   A function that is called after the producer signals, via `writer.close()`, that they are done writing chunks to the stream, and subsequently all queued-up writes have successfully completed.

    This function can perform any actions necessary to finalize or flush writes to the underlying sink, and release access to any held resources.

    If the shutdown process is asynchronous, the function can return a promise to signal success or failure; the result will be communicated via the return value of the called `writer.close()` method. Additionally, a rejected promise will error the stream, instead of letting it close successfully. Throwing an exception is treated the same as returning a rejected promise.

`abort(reason)`, of type UnderlyingSinkAbortCallback

:   A function that is called after the producer signals, via `stream.abort()` or `writer.abort()`, that they wish to abort the stream. It takes as its argument the same value as was passed to those methods by the producer.

    Writable streams can additionally be aborted under certain conditions during piping; see the definition of the `pipeTo()` method for more details.

    This function can clean up any held resources, much like `close()`, but perhaps with some custom handling.

    If the shutdown process is asynchronous, the function can return a promise to signal success or failure; the result will be communicated via the return value of the called `writer.abort()` method. Throwing an exception is treated the same as returning a rejected promise. Regardless, the stream will be errored with a new `TypeError` indicating that it was aborted.

`type`, of type any

:   This property is reserved for future use, so any attempts to supply a value will throw an exception.

The `controller` argument passed to `start()` and `write()` is an instance of `WritableStreamDefaultController`, and has the ability to error the stream. This is mainly used for bridging the gap with non-promise-based APIs, as seen for example in § 10.6 A writable stream with no backpressure or success signals.


#### Constructor, methods, and properties

`stream = new WritableStream(underlyingSink[, strategy)`

:   Creates a new `WritableStream` wrapping the provided underlying sink. See § 5.2.3 The underlying sink API for more details on the `underlyingSink` argument.

    The `strategy` argument represents the stream's queuing strategy, as described in § 7.1 The queuing strategy API. If it is not provided, the default behavior will be the same as a `CountQueuingStrategy` with a high water mark of 1.

`isLocked = stream.locked`

:   Returns whether or not the writable stream is locked to a writer.

`await stream.abort([ reason ])`

:   Aborts the stream, signaling that the producer can no longer successfully write to the stream and it is to be immediately moved to an errored state, with any queued-up writes discarded. This will also execute any abort mechanism of the underlying sink.

    The returned promise will fulfill if the stream shuts down successfully, or reject if the underlying sink signaled that there was an error doing so. Additionally, it will reject with a `TypeError` (without attempting to cancel the stream) if the stream is currently locked.

`await stream.close()`

:   Closes the stream. The underlying sink will finish processing any previously-written chunks, before invoking its close behavior. During this time any further attempts to write will fail (without erroring the stream).

    The method returns a promise that will fulfill if all remaining chunks are successfully written and the stream successfully closes, or rejects if an error is encountered during this process. Additionally, it will reject with a `TypeError` (without attempting to cancel the stream) if the stream is currently locked.

`writer = stream.getWriter()`

:   Creates a writer (an instance of `WritableStreamDefaultWriter`) and locks the stream to the new writer. While the stream is locked, no other writer can be acquired until this one is released.

    This functionality is especially useful for creating abstractions that desire the ability to write to a stream without interruption or interleaving. By getting a writer for the stream, you can ensure nobody else can write at the same time, which would cause the resulting written data to be unpredictable and probably useless.

The `new WritableStream(underlyingSink, strategy)` constructor steps are:

1.  If `underlyingSink` is missing, set it to null.

2.  Let `underlyingSinkDict` be `underlyingSink`, converted to an IDL value of type `UnderlyingSink`.

    We cannot declare the `underlyingSink` argument as having the `UnderlyingSink` type directly, because doing so would lose the reference to the original object. We need to retain the object so we can invoke the various methods on it.

3.  If `underlyingSinkDict`["`type`"] exists, throw a `RangeError` exception.

    This is to allow us to add new potential types in the future, without backward-compatibility concerns.

4.  Perform ! InitializeWritableStream(this).

5.  Let `sizeAlgorithm` be ! ExtractSizeAlgorithm(`strategy`).

6.  Let `highWaterMark` be ? ExtractHighWaterMark(`strategy`, 1).

7.  Perform ? SetUpWritableStreamDefaultControllerFromUnderlyingSink(this, `underlyingSink`, `underlyingSinkDict`, `highWaterMark`, `sizeAlgorithm`).

The `locked` getter steps are:

1.  Return ! IsWritableStreamLocked(this).

The `abort(reason)` method steps are:

1.  If ! IsWritableStreamLocked(this) is true, return a promise rejected with a `TypeError` exception.

2.  Return ! WritableStreamAbort(this, `reason`).

The `close()` method steps are:

1.  If ! IsWritableStreamLocked(this) is true, return a promise rejected with a `TypeError` exception.

2.  If ! WritableStreamCloseQueuedOrInFlight(this) is true, return a promise rejected with a `TypeError` exception.

3.  Return ! WritableStreamClose(this).

The `getWriter()` method steps are:

1.  Return ? AcquireWritableStreamDefaultWriter(this).


#### Transfer via `postMessage()`

`destination.postMessage(ws, { transfer: [ws] });`

:   Sends a `WritableStream` to another frame, window, or worker.

    The transferred stream can be used exactly like the original. The original will become locked and no longer directly usable.

`WritableStream` objects are transferable objects. Their transfer steps, given `value` and `dataHolder`, are:

1.  If ! IsWritableStreamLocked(`value`) is true, throw a "`DataCloneError`" `DOMException`.

2.  Let `port1` be a new `MessagePort` in the current Realm.

3.  Let `port2` be a new `MessagePort` in the current Realm.

4.  Entangle `port1` and `port2`.

5.  Let `readable` be a new `ReadableStream` in the current Realm.

6.  Perform ! SetUpCrossRealmTransformReadable(`readable`, `port1`).

7.  Let `promise` be ! ReadableStreamPipeTo(`readable`, `value`, false, false, false).

8.  Set `promise`.[[PromiseIsHandled]] to true.

9.  Set `dataHolder`.[[port]] to ! StructuredSerializeWithTransfer(`port2`, « `port2` »).

Their transfer-receiving steps, given `dataHolder` and `value`, are:

1.  Let `deserializedRecord` be ! StructuredDeserializeWithTransfer(`dataHolder`.[[port]], the current Realm).

2.  Let `port` be a `deserializedRecord`.[[Deserialized]].

3.  Perform ! SetUpCrossRealmTransformWritable(`value`, `port`).


### The `WritableStreamDefaultWriter` class

The `WritableStreamDefaultWriter` class represents a writable stream writer designed to be vended by a `WritableStream` instance.


#### Interface definition

The Web IDL definition for the `WritableStreamDefaultWriter` class is given as follows:

``` idl
[Exposed=*]
interface WritableStreamDefaultWriter {
  constructor(WritableStream stream);

  readonly attribute Promise<undefined> closed;
  readonly attribute unrestricted double? desiredSize;
  readonly attribute Promise<undefined> ready;

  Promise<undefined> abort(optional any reason);
  Promise<undefined> close();
  undefined releaseLock();
  Promise<undefined> write(optional any chunk);
};
```


#### Internal slots

Instances of `WritableStreamDefaultWriter` are created with the internal slots described in the following table:

| Internal Slot | Description (*non-normative*) |
|---|---|
| [[closedPromise]] | A promise returned by the writer's `closed` getter |
| [[readyPromise]] | A promise returned by the writer's `ready` getter |
| [[stream]] | A `WritableStream` instance that owns this reader |


#### Constructor, methods, and properties

`writer = new WritableStreamDefaultWriter(stream)`

:   This is equivalent to calling `stream.getWriter()`.

`await writer.closed`

:   Returns a promise that will be fulfilled when the stream becomes closed, or rejected if the stream ever errors or the writer's lock is released before the stream finishes closing.

`desiredSize = writer.desiredSize`

:   Returns the desired size to fill the stream's internal queue. It can be negative, if the queue is over-full. A producer can use this information to determine the right amount of data to write.

    It will be null if the stream cannot be successfully written to (due to either being errored, or having an abort queued up). It will return zero if the stream is closed. And the getter will throw an exception if invoked when the writer's lock is released.

`await writer.ready`

:   Returns a promise that will be fulfilled when the desired size to fill the stream's internal queue transitions from non-positive to positive, signaling that it is no longer applying backpressure. Once the desired size dips back to zero or below, the getter will return a new promise that stays pending until the next transition.

    If the stream becomes errored or aborted, or the writer's lock is released, the returned promise will become rejected.

`await writer.abort([ reason ])`

:   If the reader is active, behaves the same as `stream.abort(reason)`.

`await writer.close()`

:   If the reader is active, behaves the same as `stream.close()`.

`writer.releaseLock()`

:   Releases the writer's lock on the corresponding stream. After the lock is released, the writer is no longer active. If the associated stream is errored when the lock is released, the writer will appear errored in the same way from now on; otherwise, the writer will appear closed.

    Note that the lock can still be released even if some ongoing writes have not yet finished (i.e. even if the promises returned from previous calls to `write()` have not yet settled). It's not necessary to hold the lock on the writer for the duration of the write; the lock instead simply prevents other producers from writing in an interleaved manner.

`await writer.write(chunk)`

:   Writes the given chunk to the writable stream, by waiting until any previous writes have finished successfully, and then sending the chunk to the underlying sink's `write()` method. It will return a promise that fulfills with undefined upon a successful write, or rejects if the write fails or stream becomes errored before the writing process is initiated.

    Note that what "success" means is up to the underlying sink; it might indicate simply that the chunk has been accepted, and not necessarily that it is safely saved to its ultimate destination.

    If `chunk` is mutable, producers are advised to avoid mutating it after passing it to `write()`, until after the promise returned by `write()` settles. This ensures that the underlying sink receives and processes the same value that was passed in.

The `new WritableStreamDefaultWriter(stream)` constructor steps are:

1.  Perform ? SetUpWritableStreamDefaultWriter(this, `stream`).

The `closed` getter steps are:

1.  Return this.[[closedPromise]].

The `desiredSize` getter steps are:

1.  If this.[[stream]] is undefined, throw a `TypeError` exception.

2.  Return ! WritableStreamDefaultWriterGetDesiredSize(this).

The `ready` getter steps are:

1.  Return this.[[readyPromise]].

The `abort(reason)` method steps are:

1.  If this.[[stream]] is undefined, return a promise rejected with a `TypeError` exception.

2.  Return ! WritableStreamDefaultWriterAbort(this, `reason`).

The `close()` method steps are:

1.  Let `stream` be this.[[stream]].

2.  If `stream` is undefined, return a promise rejected with a `TypeError` exception.

3.  If ! WritableStreamCloseQueuedOrInFlight(`stream`) is true, return a promise rejected with a `TypeError` exception.

4.  Return ! WritableStreamDefaultWriterClose(this).

The `releaseLock()` method steps are:

1.  Let `stream` be this.[[stream]].

2.  If `stream` is undefined, return.

3.  Assert: `stream`.[[writer]] is not undefined.

4.  Perform ! WritableStreamDefaultWriterRelease(this).

The `write(chunk)` method steps are:

1.  If this.[[stream]] is undefined, return a promise rejected with a `TypeError` exception.

2.  Return ! WritableStreamDefaultWriterWrite(this, `chunk`).


### The `WritableStreamDefaultController` class

The `WritableStreamDefaultController` class has methods that allow control of a `WritableStream`'s state. When constructing a `WritableStream`, the underlying sink is given a corresponding `WritableStreamDefaultController` instance to manipulate.


#### Interface definition

The Web IDL definition for the `WritableStreamDefaultController` class is given as follows:

``` idl
[Exposed=*]
interface WritableStreamDefaultController {
  readonly attribute AbortSignal signal;
  undefined error(optional any e);
};
```


#### Internal slots

Instances of `WritableStreamDefaultController` are created with the internal slots described in the following table:

| Internal Slot | Description (*non-normative*) |
|---|---|
| [[abortAlgorithm]] | A promise-returning algorithm, taking one argument (the abort reason), which communicates a requested abort to the underlying sink |
| [[abortController]] | An `AbortController` that can be used to abort the pending write or close operation when the stream is aborted. |
| [[closeAlgorithm]] | A promise-returning algorithm which communicates a requested close to the underlying sink |
| [[queue]] | A list representing the stream's internal queue of chunks |
| [[queueTotalSize]] | The total size of all the chunks stored in [[queue]] (see § 8.1 Queue-with-sizes) |
| [[started]] | A boolean flag indicating whether the underlying sink has finished starting |
| [[strategyHWM]] | A number supplied by the creator of the stream as part of the stream's queuing strategy, indicating the point at which the stream will apply backpressure to its underlying sink |
| [[strategySizeAlgorithm]] | An algorithm to calculate the size of enqueued chunks, as part of the stream's queuing strategy |
| [[stream]] | The `WritableStream` instance controlled |
| [[writeAlgorithm]] | A promise-returning algorithm, taking one argument (the chunk to write), which writes data to the underlying sink |

The **close sentinel** is a unique value enqueued into [[queue]], in lieu of a chunk, to signal that the stream is closed. It is only used internally, and is never exposed to web developers.


#### Methods and properties

`controller.signal`

:   An AbortSignal that can be used to abort the pending write or close operation when the stream is aborted.

`controller.error(e)`

:   Closes the controlled writable stream, making all future interactions with it fail with the given error `e`.

    This method is rarely used, since usually it suffices to return a rejected promise from one of the underlying sink's methods. However, it can be useful for suddenly shutting down a stream in response to an event outside the normal lifecycle of interactions with the underlying sink.

The `signal` getter steps are:

1.  Return this.[[abortController]]'s signal.

The `error(e)` method steps are:

1.  Let `state` be this.[[stream]].[[state]].

2.  If `state` is not "`writable`", return.

3.  Perform ! WritableStreamDefaultControllerError(this, `e`).


#### Internal methods

The following are internal methods implemented by each `WritableStreamDefaultController` instance. The writable stream implementation will call into these.

The reason these are in method form, instead of as abstract operations, is to make it clear that the writable stream implementation is decoupled from the controller implementation, and could in the future be expanded with other controllers, as long as those controllers implemented such internal methods. A similar scenario is seen for readable streams (see § 4.9.2 Interfacing with controllers), where there actually are multiple controller types and as such the counterpart internal methods are used polymorphically.

[[AbortSteps]](`reason`) implements the [[AbortSteps]] contract. It performs the following steps:

1.  Let `result` be the result of performing this.[[abortAlgorithm]], passing `reason`.

2.  Perform ! WritableStreamDefaultControllerClearAlgorithms(this).

3.  Return `result`.

[[ErrorSteps]]() implements the [[ErrorSteps]] contract. It performs the following steps:

1.  Perform ! ResetQueue(this).


#### Working with writable streams

The following abstract operations operate on `WritableStream` instances at a higher level.

AcquireWritableStreamDefaultWriter(`stream`) performs the following steps:

1.  Let `writer` be a new `WritableStreamDefaultWriter`.

2.  Perform ? SetUpWritableStreamDefaultWriter(`writer`, `stream`).

3.  Return `writer`.

CreateWritableStream(`startAlgorithm`, `writeAlgorithm`, `closeAlgorithm`, `abortAlgorithm`, `highWaterMark`, `sizeAlgorithm`) performs the following steps:

1.  Assert: ! IsNonNegativeNumber(`highWaterMark`) is true.

2.  Let `stream` be a new `WritableStream`.

3.  Perform ! InitializeWritableStream(`stream`).

4.  Let `controller` be a new `WritableStreamDefaultController`.

5.  Perform ? SetUpWritableStreamDefaultController(`stream`, `controller`, `startAlgorithm`, `writeAlgorithm`, `closeAlgorithm`, `abortAlgorithm`, `highWaterMark`, `sizeAlgorithm`).

6.  Return `stream`.

This abstract operation will throw an exception if and only if the supplied `startAlgorithm` throws.

InitializeWritableStream(`stream`) performs the following steps:

1.  Set `stream`.[[state]] to "`writable`".

2.  Set `stream`.[[storedError]], `stream`.[[writer]], `stream`.[[controller]], `stream`.[[inFlightWriteRequest]], `stream`.[[closeRequest]], `stream`.[[inFlightCloseRequest]], and `stream`.[[pendingAbortRequest]] to undefined.

3.  Set `stream`.[[writeRequests]] to a new empty list.

4.  Set `stream`.[[backpressure]] to false.

IsWritableStreamLocked(`stream`) performs the following steps:

1.  If `stream`.[[writer]] is undefined, return false.

2.  Return true.

SetUpWritableStreamDefaultWriter(`writer`, `stream`) performs the following steps:

1.  If ! IsWritableStreamLocked(`stream`) is true, throw a `TypeError` exception.

2.  Set `writer`.[[stream]] to `stream`.

3.  Set `stream`.[[writer]] to `writer`.

4.  Let `state` be `stream`.[[state]].

5.  If `state` is "`writable`",

    1.  If ! WritableStreamCloseQueuedOrInFlight(`stream`) is false and `stream`.[[backpressure]] is true, set `writer`.[[readyPromise]] to a new promise.

    2.  Otherwise, set `writer`.[[readyPromise]] to a promise resolved with undefined.

    3.  Set `writer`.[[closedPromise]] to a new promise.

6.  Otherwise, if `state` is "`erroring`",

    1.  Set `writer`.[[readyPromise]] to a promise rejected with `stream`.[[storedError]].

    2.  Set `writer`.[[readyPromise]].[[PromiseIsHandled]] to true.

    3.  Set `writer`.[[closedPromise]] to a new promise.

7.  Otherwise, if `state` is "`closed`",

    1.  Set `writer`.[[readyPromise]] to a promise resolved with undefined.

    2.  Set `writer`.[[closedPromise]] to a promise resolved with undefined.

8.  Otherwise,

    1.  Assert: `state` is "`errored`".

    2.  Let `storedError` be `stream`.[[storedError]].

    3.  Set `writer`.[[readyPromise]] to a promise rejected with `storedError`.

    4.  Set `writer`.[[readyPromise]].[[PromiseIsHandled]] to true.

    5.  Set `writer`.[[closedPromise]] to a promise rejected with `storedError`.

    6.  Set `writer`.[[closedPromise]].[[PromiseIsHandled]] to true.

WritableStreamAbort(`stream`, `reason`) performs the following steps:

1.  If `stream`.[[state]] is "`closed`" or "`errored`", return a promise resolved with undefined.

2.  Signal abort on `stream`.[[controller]].[[abortController]] with `reason`.

3.  Let `state` be `stream`.[[state]].

4.  If `state` is "`closed`" or "`errored`", return a promise resolved with undefined.

    We re-check the state because signaling abort runs author code and that might have changed the state.

5.  If `stream`.[[pendingAbortRequest]] is not undefined, return `stream`.[[pendingAbortRequest]]'s promise.

6.  Assert: `state` is "`writable`" or "`erroring`".

7.  Let `wasAlreadyErroring` be false.

8.  If `state` is "`erroring`",

    1.  Set `wasAlreadyErroring` to true.

    2.  Set `reason` to undefined.

9.  Let `promise` be a new promise.

10. Set `stream`.[[pendingAbortRequest]] to a new pending abort request whose promise is `promise`, reason is `reason`, and was already erroring is `wasAlreadyErroring`.

11. If `wasAlreadyErroring` is false, perform ! WritableStreamStartErroring(`stream`, `reason`).

12. Return `promise`.

WritableStreamClose(`stream`) performs the following steps:

1.  Let `state` be `stream`.[[state]].

2.  If `state` is "`closed`" or "`errored`", return a promise rejected with a `TypeError` exception.

3.  Assert: `state` is "`writable`" or "`erroring`".

4.  Assert: ! WritableStreamCloseQueuedOrInFlight(`stream`) is false.

5.  Let `promise` be a new promise.

6.  Set `stream`.[[closeRequest]] to `promise`.

7.  Let `writer` be `stream`.[[writer]].

8.  If `writer` is not undefined, and `stream`.[[backpressure]] is true, and `state` is "`writable`", resolve `writer`.[[readyPromise]] with undefined.

9.  Perform ! WritableStreamDefaultControllerClose(`stream`.[[controller]]).

10. Return `promise`.


#### Interfacing with controllers

To allow future flexibility to add different writable stream behaviors (similar to the distinction between default readable streams and readable byte streams), much of the internal state of a writable stream is encapsulated by the `WritableStreamDefaultController` class.

Each controller class defines two internal methods, which are called by the `WritableStream` algorithms:

[[AbortSteps]](`reason`)
:   The controller's steps that run in reaction to the stream being aborted, used to clean up the state stored in the controller and inform the underlying sink.

[[ErrorSteps]]()
:   The controller's steps that run in reaction to the stream being errored, used to clean up the state stored in the controller.

(These are defined as internal methods, instead of as abstract operations, so that they can be called polymorphically by the `WritableStream` algorithms, without having to branch on which type of controller is present. This is a bit theoretical for now, given that only `WritableStreamDefaultController` exists so far.)

The rest of this section concerns abstract operations that go in the other direction: they are used by the controller implementation to affect its associated `WritableStream` object. This translates internal state changes of the controllerinto developer-facing results visible through the `WritableStream`'s public API.

WritableStreamAddWriteRequest(`stream`) performs the following steps:

1.  Assert: ! IsWritableStreamLocked(`stream`) is true.

2.  Assert: `stream`.[[state]] is "`writable`".

3.  Let `promise` be a new promise.

4.  Append `promise` to `stream`.[[writeRequests]].

5.  Return `promise`.

WritableStreamCloseQueuedOrInFlight(`stream`) performs the following steps:

1.  If `stream`.[[closeRequest]] is undefined and `stream`.[[inFlightCloseRequest]] is undefined, return false.

2.  Return true.

WritableStreamDealWithRejection(`stream`, `error`) performs the following steps:

1.  Let `state` be `stream`.[[state]].

2.  If `state` is "`writable`",

    1.  Perform ! WritableStreamStartErroring(`stream`, `error`).

    2.  Return.

3.  Assert: `state` is "`erroring`".

4.  Perform ! WritableStreamFinishErroring(`stream`).

WritableStreamFinishErroring(`stream`) performs the following steps:

1.  Assert: `stream`.[[state]] is "`erroring`".

2.  Assert: ! WritableStreamHasOperationMarkedInFlight(`stream`) is false.

3.  Set `stream`.[[state]] to "`errored`".

4.  Perform ! `stream`.[[controller]].[[ErrorSteps]]().

5.  Let `storedError` be `stream`.[[storedError]].

6.  For each `writeRequest` of `stream`.[[writeRequests]]:

    1.  Reject `writeRequest` with `storedError`.

7.  Set `stream`.[[writeRequests]] to an empty list.

8.  If `stream`.[[pendingAbortRequest]] is undefined,

    1.  Perform ! WritableStreamRejectCloseAndClosedPromiseIfNeeded(`stream`).

    2.  Return.

9.  Let `abortRequest` be `stream`.[[pendingAbortRequest]].

10. Set `stream`.[[pendingAbortRequest]] to undefined.

11. If `abortRequest`'s was already erroring is true,

    1.  Reject `abortRequest`'s promise with `storedError`.

    2.  Perform ! WritableStreamRejectCloseAndClosedPromiseIfNeeded(`stream`).

    3.  Return.

12. Let `promise` be ! `stream`.[[controller]].[[AbortSteps]](`abortRequest`'s reason).

13. Upon fulfillment of `promise`,

    1.  Resolve `abortRequest`'s promise with undefined.

    2.  Perform ! WritableStreamRejectCloseAndClosedPromiseIfNeeded(`stream`).

14. Upon rejection of `promise` with reason `reason`,

    1.  Reject `abortRequest`'s promise with `reason`.

    2.  Perform ! WritableStreamRejectCloseAndClosedPromiseIfNeeded(`stream`).

WritableStreamFinishInFlightClose(`stream`) performs the following steps:

1.  Assert: `stream`.[[inFlightCloseRequest]] is not undefined.

2.  Resolve `stream`.[[inFlightCloseRequest]] with undefined.

3.  Set `stream`.[[inFlightCloseRequest]] to undefined.

4.  Let `state` be `stream`.[[state]].

5.  Assert: `stream`.[[state]] is "`writable`" or "`erroring`".

6.  If `state` is "`erroring`",

    1.  Set `stream`.[[storedError]] to undefined.

    2.  If `stream`.[[pendingAbortRequest]] is not undefined,

        1.  Resolve `stream`.[[pendingAbortRequest]]'s promise with undefined.

        2.  Set `stream`.[[pendingAbortRequest]] to undefined.

7.  Set `stream`.[[state]] to "`closed`".

8.  Let `writer` be `stream`.[[writer]].

9.  If `writer` is not undefined, resolve `writer`.[[closedPromise]] with undefined.

10. Assert: `stream`.[[pendingAbortRequest]] is undefined.

11. Assert: `stream`.[[storedError]] is undefined.

WritableStreamFinishInFlightCloseWithError(`stream`, `error`) performs the following steps:

1.  Assert: `stream`.[[inFlightCloseRequest]] is not undefined.

2.  Reject `stream`.[[inFlightCloseRequest]] with `error`.

3.  Set `stream`.[[inFlightCloseRequest]] to undefined.

4.  Assert: `stream`.[[state]] is "`writable`" or "`erroring`".

5.  If `stream`.[[pendingAbortRequest]] is not undefined,

    1.  Reject `stream`.[[pendingAbortRequest]]'s promise with `error`.

    2.  Set `stream`.[[pendingAbortRequest]] to undefined.

6.  Perform ! WritableStreamDealWithRejection(`stream`, `error`).

WritableStreamFinishInFlightWrite(`stream`) performs the following steps:

1.  Assert: `stream`.[[inFlightWriteRequest]] is not undefined.

2.  Resolve `stream`.[[inFlightWriteRequest]] with undefined.

3.  Set `stream`.[[inFlightWriteRequest]] to undefined.

WritableStreamFinishInFlightWriteWithError(`stream`, `error`) performs the following steps:

1.  Assert: `stream`.[[inFlightWriteRequest]] is not undefined.

2.  Reject `stream`.[[inFlightWriteRequest]] with `error`.

3.  Set `stream`.[[inFlightWriteRequest]] to undefined.

4.  Assert: `stream`.[[state]] is "`writable`" or "`erroring`".

5.  Perform ! WritableStreamDealWithRejection(`stream`, `error`).

WritableStreamHasOperationMarkedInFlight(`stream`) performs the following steps:

1.  If `stream`.[[inFlightWriteRequest]] is undefined and `stream`.[[inFlightCloseRequest]] is undefined, return false.

2.  Return true.

WritableStreamMarkCloseRequestInFlight(`stream`) performs the following steps:

1.  Assert: `stream`.[[inFlightCloseRequest]] is undefined.

2.  Assert: `stream`.[[closeRequest]] is not undefined.

3.  Set `stream`.[[inFlightCloseRequest]] to `stream`.[[closeRequest]].

4.  Set `stream`.[[closeRequest]] to undefined.

WritableStreamMarkFirstWriteRequestInFlight(`stream`) performs the following steps:

1.  Assert: `stream`.[[inFlightWriteRequest]] is undefined.

2.  Assert: `stream`.[[writeRequests]] is not empty.

3.  Let `writeRequest` be `stream`.[[writeRequests]][0].

4.  Remove `writeRequest` from `stream`.[[writeRequests]].

5.  Set `stream`.[[inFlightWriteRequest]] to `writeRequest`.

WritableStreamRejectCloseAndClosedPromiseIfNeeded(`stream`) performs the following steps:

1.  Assert: `stream`.[[state]] is "`errored`".

2.  If `stream`.[[closeRequest]] is not undefined,

    1.  Assert: `stream`.[[inFlightCloseRequest]] is undefined.

    2.  Reject `stream`.[[closeRequest]] with `stream`.[[storedError]].

    3.  Set `stream`.[[closeRequest]] to undefined.

3.  Let `writer` be `stream`.[[writer]].

4.  If `writer` is not undefined,

    1.  Reject `writer`.[[closedPromise]] with `stream`.[[storedError]].

    2.  Set `writer`.[[closedPromise]].[[PromiseIsHandled]] to true.

WritableStreamStartErroring(`stream`, `reason`) performs the following steps:

1.  Assert: `stream`.[[storedError]] is undefined.

2.  Assert: `stream`.[[state]] is "`writable`".

3.  Let `controller` be `stream`.[[controller]].

4.  Assert: `controller` is not undefined.

5.  Set `stream`.[[state]] to "`erroring`".

6.  Set `stream`.[[storedError]] to `reason`.

7.  Let `writer` be `stream`.[[writer]].

8.  If `writer` is not undefined, perform ! WritableStreamDefaultWriterEnsureReadyPromiseRejected(`writer`, `reason`).

9.  If ! WritableStreamHasOperationMarkedInFlight(`stream`) is false and `controller`.[[started]] is true, perform ! WritableStreamFinishErroring(`stream`).

WritableStreamUpdateBackpressure(`stream`, `backpressure`) performs the following steps:

1.  Assert: `stream`.[[state]] is "`writable`".

2.  Assert: ! WritableStreamCloseQueuedOrInFlight(`stream`) is false.

3.  Let `writer` be `stream`.[[writer]].

4.  If `writer` is not undefined and `backpressure` is not `stream`.[[backpressure]],

    1.  If `backpressure` is true, set `writer`.[[readyPromise]] to a new promise.

    2.  Otherwise,

        1.  Assert: `backpressure` is false.

        2.  Resolve `writer`.[[readyPromise]] with undefined.

5.  Set `stream`.[[backpressure]] to `backpressure`.


#### Writers

The following abstract operations support the implementation and manipulation of `WritableStreamDefaultWriter` instances.

WritableStreamDefaultWriterAbort(`writer`, `reason`) performs the following steps:

1.  Let `stream` be `writer`.[[stream]].

2.  Assert: `stream` is not undefined.

3.  Return ! WritableStreamAbort(`stream`, `reason`).

WritableStreamDefaultWriterClose(`writer`) performs the following steps:

1.  Let `stream` be `writer`.[[stream]].

2.  Assert: `stream` is not undefined.

3.  Return ! WritableStreamClose(`stream`).

WritableStreamDefaultWriterCloseWithErrorPropagation(`writer`) performs the following steps:

1.  Let `stream` be `writer`.[[stream]].

2.  Assert: `stream` is not undefined.

3.  Let `state` be `stream`.[[state]].

4.  If ! WritableStreamCloseQueuedOrInFlight(`stream`) is true or `state` is "`closed`", return a promise resolved with undefined.

5.  If `state` is "`errored`", return a promise rejected with `stream`.[[storedError]].

6.  Assert: `state` is "`writable`" or "`erroring`".

7.  Return ! WritableStreamDefaultWriterClose(`writer`).

This abstract operation helps implement the error propagation semantics of `ReadableStream`'s `pipeTo()`.

WritableStreamDefaultWriterEnsureClosedPromiseRejected(`writer`, `error`) performs the following steps:

1.  If `writer`.[[closedPromise]].[[PromiseState]] is "`pending`", reject `writer`.[[closedPromise]] with `error`.

2.  Otherwise, set `writer`.[[closedPromise]] to a promise rejected with `error`.

3.  Set `writer`.[[closedPromise]].[[PromiseIsHandled]] to true.

WritableStreamDefaultWriterEnsureReadyPromiseRejected(`writer`, `error`) performs the following steps:

1.  If `writer`.[[readyPromise]].[[PromiseState]] is "`pending`", reject `writer`.[[readyPromise]] with `error`.

2.  Otherwise, set `writer`.[[readyPromise]] to a promise rejected with `error`.

3.  Set `writer`.[[readyPromise]].[[PromiseIsHandled]] to true.

WritableStreamDefaultWriterGetDesiredSize(`writer`) performs the following steps:

1.  Let `stream` be `writer`.[[stream]].

2.  Let `state` be `stream`.[[state]].

3.  If `state` is "`errored`" or "`erroring`", return null.

4.  If `state` is "`closed`", return 0.

5.  Return ! WritableStreamDefaultControllerGetDesiredSize(`stream`.[[controller]]).

WritableStreamDefaultWriterRelease(`writer`) performs the following steps:

1.  Let `stream` be `writer`.[[stream]].

2.  Assert: `stream` is not undefined.

3.  Assert: `stream`.[[writer]] is `writer`.

4.  Let `releasedError` be a new `TypeError`.

5.  Perform ! WritableStreamDefaultWriterEnsureReadyPromiseRejected(`writer`, `releasedError`).

6.  Perform ! WritableStreamDefaultWriterEnsureClosedPromiseRejected(`writer`, `releasedError`).

7.  Set `stream`.[[writer]] to undefined.

8.  Set `writer`.[[stream]] to undefined.

WritableStreamDefaultWriterWrite(`writer`, `chunk`) performs the following steps:

1.  Let `stream` be `writer`.[[stream]].

2.  Assert: `stream` is not undefined.

3.  Let `controller` be `stream`.[[controller]].

4.  Let `chunkSize` be ! WritableStreamDefaultControllerGetChunkSize(`controller`, `chunk`).

5.  If `stream` is not equal to `writer`.[[stream]], return a promise rejected with a `TypeError` exception.

6.  Let `state` be `stream`.[[state]].

7.  If `state` is "`errored`", return a promise rejected with `stream`.[[storedError]].

8.  If ! WritableStreamCloseQueuedOrInFlight(`stream`) is true or `state` is "`closed`", return a promise rejected with a `TypeError` exception indicating that the stream is closing or closed.

9.  If `state` is "`erroring`", return a promise rejected with `stream`.[[storedError]].

10. Assert: `state` is "`writable`".

11. Let `promise` be ! WritableStreamAddWriteRequest(`stream`).

12. Perform ! WritableStreamDefaultControllerWrite(`controller`, `chunk`, `chunkSize`).

13. Return `promise`.


#### Default controllers

The following abstract operations support the implementation of the `WritableStreamDefaultController` class.

SetUpWritableStreamDefaultController(`stream`, `controller`, `startAlgorithm`, `writeAlgorithm`, `closeAlgorithm`, `abortAlgorithm`, `highWaterMark`, `sizeAlgorithm`) performs the following steps:

1.  Assert: `stream` implements `WritableStream`.

2.  Assert: `stream`.[[controller]] is undefined.

3.  Set `controller`.[[stream]] to `stream`.

4.  Set `stream`.[[controller]] to `controller`.

5.  Perform ! ResetQueue(`controller`).

6.  Set `controller`.[[abortController]] to a new `AbortController`.

7.  Set `controller`.[[started]] to false.

8.  Set `controller`.[[strategySizeAlgorithm]] to `sizeAlgorithm`.

9.  Set `controller`.[[strategyHWM]] to `highWaterMark`.

10. Set `controller`.[[writeAlgorithm]] to `writeAlgorithm`.

11. Set `controller`.[[closeAlgorithm]] to `closeAlgorithm`.

12. Set `controller`.[[abortAlgorithm]] to `abortAlgorithm`.

13. Let `backpressure` be ! WritableStreamDefaultControllerGetBackpressure(`controller`).

14. Perform ! WritableStreamUpdateBackpressure(`stream`, `backpressure`).

15. Let `startResult` be the result of performing `startAlgorithm`. (This may throw an exception.)

16. Let `startPromise` be a promise resolved with `startResult`.

17. Upon fulfillment of `startPromise`,

    1.  Assert: `stream`.[[state]] is "`writable`" or "`erroring`".

    2.  Set `controller`.[[started]] to true.

    3.  Perform ! WritableStreamDefaultControllerAdvanceQueueIfNeeded(`controller`).

18. Upon rejection of `startPromise` with reason `r`,

    1.  Assert: `stream`.[[state]] is "`writable`" or "`erroring`".

    2.  Set `controller`.[[started]] to true.

    3.  Perform ! WritableStreamDealWithRejection(`stream`, `r`).

SetUpWritableStreamDefaultControllerFromUnderlyingSink(`stream`, `underlyingSink`, `underlyingSinkDict`, `highWaterMark`, `sizeAlgorithm`) performs the following steps:

1.  Let `controller` be a new `WritableStreamDefaultController`.

2.  Let `startAlgorithm` be an algorithm that returns undefined.

3.  Let `writeAlgorithm` be an algorithm that returns a promise resolved with undefined.

4.  Let `closeAlgorithm` be an algorithm that returns a promise resolved with undefined.

5.  Let `abortAlgorithm` be an algorithm that returns a promise resolved with undefined.

6.  If `underlyingSinkDict`["`start`"] exists, then set `startAlgorithm` to an algorithm which returns the result of invoking `underlyingSinkDict`["`start`"] with argument list « `controller` », exception behavior "`rethrow`", and callback this value `underlyingSink`.

7.  If `underlyingSinkDict`["`write`"] exists, then set `writeAlgorithm` to an algorithm which takes an argument `chunk` and returns the result of invoking `underlyingSinkDict`["`write`"] with argument list « `chunk`, `controller` » and callback this value `underlyingSink`.

8.  If `underlyingSinkDict`["`close`"] exists, then set `closeAlgorithm` to an algorithm which returns the result of invoking `underlyingSinkDict`["`close`"] with argument list «» and callback this value `underlyingSink`.

9.  If `underlyingSinkDict`["`abort`"] exists, then set `abortAlgorithm` to an algorithm which takes an argument `reason` and returns the result of invoking `underlyingSinkDict`["`abort`"] with argument list « `reason` » and callback this value `underlyingSink`.

10. Perform ? SetUpWritableStreamDefaultController(`stream`, `controller`, `startAlgorithm`, `writeAlgorithm`, `closeAlgorithm`, `abortAlgorithm`, `highWaterMark`, `sizeAlgorithm`).

WritableStreamDefaultControllerAdvanceQueueIfNeeded(`controller`) performs the following steps:

1.  Let `stream` be `controller`.[[stream]].

2.  If `controller`.[[started]] is false, return.

3.  If `stream`.[[inFlightWriteRequest]] is not undefined, return.

4.  Let `state` be `stream`.[[state]].

5.  Assert: `state` is not "`closed`" or "`errored`".

6.  If `state` is "`erroring`",

    1.  Perform ! WritableStreamFinishErroring(`stream`).

    2.  Return.

7.  If `controller`.[[queue]] is empty, return.

8.  Let `value` be ! PeekQueueValue(`controller`).

9.  If `value` is the close sentinel, perform ! WritableStreamDefaultControllerProcessClose(`controller`).

10. Otherwise, perform ! WritableStreamDefaultControllerProcessWrite(`controller`, `value`).

WritableStreamDefaultControllerClearAlgorithms(`controller`) is called once the stream is closed or errored and the algorithms will not be executed any more. By removing the algorithm references it permits the underlying sink object to be garbage collected even if the `WritableStream` itself is still referenced.

This is observable using weak references. See tc39/proposal-weakrefs#31 for more detail.

It performs the following steps:

1.  Set `controller`.[[writeAlgorithm]] to undefined.

2.  Set `controller`.[[closeAlgorithm]] to undefined.

3.  Set `controller`.[[abortAlgorithm]] to undefined.

4.  Set `controller`.[[strategySizeAlgorithm]] to undefined.

This algorithm will be performed multiple times in some edge cases. After the first time it will do nothing.

WritableStreamDefaultControllerClose(`controller`) performs the following steps:

1.  Perform ! EnqueueValueWithSize(`controller`, close sentinel, 0).

2.  Perform ! WritableStreamDefaultControllerAdvanceQueueIfNeeded(`controller`).

WritableStreamDefaultControllerError(`controller`, `error`) performs the following steps:

1.  Let `stream` be `controller`.[[stream]].

2.  Assert: `stream`.[[state]] is "`writable`".

3.  Perform ! WritableStreamDefaultControllerClearAlgorithms(`controller`).

4.  Perform ! WritableStreamStartErroring(`stream`, `error`).

WritableStreamDefaultControllerErrorIfNeeded(`controller`, `error`) performs the following steps:

1.  If `controller`.[[stream]].[[state]] is "`writable`", perform ! WritableStreamDefaultControllerError(`controller`, `error`).

WritableStreamDefaultControllerGetBackpressure(`controller`) performs the following steps:

1.  Let `desiredSize` be ! WritableStreamDefaultControllerGetDesiredSize(`controller`).

2.  Return true if `desiredSize` ≤ 0, or false otherwise.

WritableStreamDefaultControllerGetChunkSize(`controller`, `chunk`) performs the following steps:

1.  If `controller`.[[strategySizeAlgorithm]] is undefined, then:

    1.  Assert: `controller`.[[stream]].[[state]] is not "`writable`".

    2.  Return 1.

2.  Let `returnValue` be the result of performing `controller`.[[strategySizeAlgorithm]], passing in `chunk`, and interpreting the result as a completion record.

3.  If `returnValue` is an abrupt completion,

    1.  Perform ! WritableStreamDefaultControllerErrorIfNeeded(`controller`, `returnValue`.[[Value]]).

    2.  Return 1.

4.  Return `returnValue`.[[Value]].

WritableStreamDefaultControllerGetDesiredSize(`controller`) performs the following steps:

1.  Return `controller`.[[strategyHWM]] − `controller`.[[queueTotalSize]].

WritableStreamDefaultControllerProcessClose(`controller`) performs the following steps:

1.  Let `stream` be `controller`.[[stream]].

2.  Perform ! WritableStreamMarkCloseRequestInFlight(`stream`).

3.  Perform ! DequeueValue(`controller`).

4.  Assert: `controller`.[[queue]] is empty.

5.  Let `sinkClosePromise` be the result of performing `controller`.[[closeAlgorithm]].

6.  Perform ! WritableStreamDefaultControllerClearAlgorithms(`controller`).

7.  Upon fulfillment of `sinkClosePromise`,

    1.  Perform ! WritableStreamFinishInFlightClose(`stream`).

8.  Upon rejection of `sinkClosePromise` with reason `reason`,

    1.  Perform ! WritableStreamFinishInFlightCloseWithError(`stream`, `reason`).

WritableStreamDefaultControllerProcessWrite(`controller`, `chunk`) performs the following steps:

1.  Let `stream` be `controller`.[[stream]].

2.  Perform ! WritableStreamMarkFirstWriteRequestInFlight(`stream`).

3.  Let `sinkWritePromise` be the result of performing `controller`.[[writeAlgorithm]], passing in `chunk`.

4.  Upon fulfillment of `sinkWritePromise`,

    1.  Perform ! WritableStreamFinishInFlightWrite(`stream`).

    2.  Let `state` be `stream`.[[state]].

    3.  Assert: `state` is "`writable`" or "`erroring`".

    4.  Perform ! DequeueValue(`controller`).

    5.  If ! WritableStreamCloseQueuedOrInFlight(`stream`) is false and `state` is "`writable`",

        1.  Let `backpressure` be ! WritableStreamDefaultControllerGetBackpressure(`controller`).

        2.  Perform ! WritableStreamUpdateBackpressure(`stream`, `backpressure`).

    6.  Perform ! WritableStreamDefaultControllerAdvanceQueueIfNeeded(`controller`).

5.  Upon rejection of `sinkWritePromise` with `reason`,

    1.  If `stream`.[[state]] is "`writable`", perform ! WritableStreamDefaultControllerClearAlgorithms(`controller`).

    2.  Perform ! WritableStreamFinishInFlightWriteWithError(`stream`, `reason`).

WritableStreamDefaultControllerWrite(`controller`, `chunk`, `chunkSize`) performs the following steps:

1.  Let `enqueueResult` be EnqueueValueWithSize(`controller`, `chunk`, `chunkSize`).

2.  If `enqueueResult` is an abrupt completion,

    1.  Perform ! WritableStreamDefaultControllerErrorIfNeeded(`controller`, `enqueueResult`.[[Value]]).

    2.  Return.

3.  Let `stream` be `controller`.[[stream]].

4.  If ! WritableStreamCloseQueuedOrInFlight(`stream`) is false and `stream`.[[state]] is "`writable`",

    1.  Let `backpressure` be ! WritableStreamDefaultControllerGetBackpressure(`controller`).

    2.  Perform ! WritableStreamUpdateBackpressure(`stream`, `backpressure`).

5.  Perform ! WritableStreamDefaultControllerAdvanceQueueIfNeeded(`controller`).


## Transform streams


### Using transform streams

The natural way to use a transform stream is to place it in a pipe between a readable stream and a writable stream. Chunks that travel from the readable stream to the writable stream will be transformed as they pass through the transform stream. Backpressure is respected, so data will not be read faster than it can be transformed and consumed.

```
readableStream
  .pipeThrough(transformStream)
  .pipeTo(writableStream)
  .then(() => console.log("All data successfully transformed!"))
  .catch(e => console.error("Something went wrong!", e));
```

You can also use the `readable` and `writable` properties of a transform stream directly to access the usual interfaces of a readable stream and writable stream. In this example we supply data to the writable side of the stream using its writer interface. The readable side is then piped to `anotherWritableStream`.

```
const writer = transformStream.writable.getWriter();
writer.write("input chunk");
transformStream.readable.pipeTo(anotherWritableStream);
```

One use of identity transform streams is to easily convert between readable and writable streams. For example, the `fetch()` API accepts a readable stream request body, but it can be more convenient to write data for uploading via a writable stream interface. Using an identity transform stream addresses this:

```
const { writable, readable } = new TransformStream();
fetch("...", { body: readable }).then(response => /* ... */);

const writer = writable.getWriter();
writer.write(new Uint8Array([0x73, 0x74, 0x72, 0x65, 0x61, 0x6D, 0x73, 0x21]));
writer.close();
```

Another use of identity transform streams is to add additional buffering to a pipe. In this example we add extra buffering between `readableStream` and `writableStream`.

```
const writableStrategy = new ByteLengthQueuingStrategy({ highWaterMark: 1024 * 1024 });

readableStream
  .pipeThrough(new TransformStream(undefined, writableStrategy))
  .pipeTo(writableStream);
```


### The `TransformStream` class

The `TransformStream` class is a concrete instance of the general transform stream concept.


#### Interface definition

The Web IDL definition for the `TransformStream` class is given as follows:

```idl
[Exposed=*, Transferable]
interface TransformStream {
  constructor(optional object transformer,
              optional QueuingStrategy writableStrategy = {},
              optional QueuingStrategy readableStrategy = {});

  readonly attribute ReadableStream readable;
  readonly attribute WritableStream writable;
};
```


#### Internal slots

Instances of `TransformStream` are created with the internal slots described in the following table:

| Internal Slot | Description (*non-normative*) |
|---------------|-------------------------------|
| [[backpressure]] | Whether there was backpressure on [[readable]] the last time it was observed |
| [[backpressureChangePromise]] | A promise which is fulfilled and replaced every time the value of [[backpressure]] changes |
| [[controller]] | A `TransformStreamDefaultController` created with the ability to control [[readable]] and [[writable]] |
| [[Detached]] | A boolean flag set to true when the stream is transferred |
| [[readable]] | The `ReadableStream` instance controlled by this object |
| [[writable]] | The `WritableStream` instance controlled by this object |


#### The transformer API

The `TransformStream()` constructor accepts as its first argument a JavaScript object representing the transformer. Such objects can contain any of the following methods:

```idl
dictionary Transformer {
  TransformerStartCallback start;
  TransformerTransformCallback transform;
  TransformerFlushCallback flush;
  TransformerCancelCallback cancel;
  any readableType;
  any writableType;
};

callback TransformerStartCallback = any (TransformStreamDefaultController controller);
callback TransformerFlushCallback = Promise<undefined> (TransformStreamDefaultController controller);
callback TransformerTransformCallback = Promise<undefined> (any chunk, TransformStreamDefaultController controller);
callback TransformerCancelCallback = Promise<undefined> (any reason);
```

`start(controller)`, of type TransformerStartCallback

A function that is called immediately during creation of the `TransformStream`.

Typically this is used to enqueue prefix chunks, using `controller.enqueue()`. Those chunks will be read from the readable side but don't depend on any writes to the writable side.

If this initial process is asynchronous, for example because it takes some effort to acquire the prefix chunks, the function can return a promise to signal success or failure; a rejected promise will error the stream. Any thrown exceptions will be re-thrown by the `TransformStream()` constructor.

`transform(chunk, controller)`, of type TransformerTransformCallback

A function called when a new chunk originally written to the writable side is ready to be transformed. The stream implementation guarantees that this function will be called only after previous transforms have succeeded, and never before `start()` has completed or after `flush()` has been called.

This function performs the actual transformation work of the transform stream. It can enqueue the results using `controller.enqueue()`. This permits a single chunk written to the writable side to result in zero or multiple chunks on the readable side, depending on how many times `controller.enqueue()` is called. § 10.9 A transform stream that replaces template tags demonstrates this by sometimes enqueuing zero chunks.

If the process of transforming is asynchronous, this function can return a promise to signal success or failure of the transformation. A rejected promise will error both the readable and writable sides of the transform stream.

The promise potentially returned by this function is used to ensure that well-behaved producers do not attempt to mutate the chunk before it has been fully transformed. (This is not guaranteed by any specification machinery, but instead is an informal contract between producers and the transformer.)

If no `transform()` method is supplied, the identity transform is used, which enqueues chunks unchanged from the writable side to the readable side.

`flush(controller)`, of type TransformerFlushCallback

A function called after all chunks written to the writable side have been transformed by successfully passing through `transform()`, and the writable side is about to be closed.

Typically this is used to enqueue suffix chunks to the readable side, before that too becomes closed. An example can be seen in § 10.9 A transform stream that replaces template tags.

If the flushing process is asynchronous, the function can return a promise to signal success or failure; the result will be communicated to the caller of `stream.writable.write()`. Additionally, a rejected promise will error both the readable and writable sides of the stream. Throwing an exception is treated the same as returning a rejected promise.

(Note that there is no need to call `controller.terminate()` inside `flush()`; the stream is already in the process of successfully closing down, and terminating it would be counterproductive.)

`cancel(reason)`, of type TransformerCancelCallback

A function called when the readable side is cancelled, or when the writable side is aborted.

Typically this is used to clean up underlying transformer resources when the stream is aborted or cancelled.

If the cancellation process is asynchronous, the function can return a promise to signal success or failure; the result will be communicated to the caller of `stream.writable.abort()` or `stream.readable.cancel()`. Throwing an exception is treated the same as returning a rejected promise.

(Note that there is no need to call `controller.terminate()` inside `cancel()`; the stream is already in the process of cancelling/aborting, and terminating it would be counterproductive.)

`readableType`, of type any

This property is reserved for future use, so any attempts to supply a value will throw an exception.

`writableType`, of type any

This property is reserved for future use, so any attempts to supply a value will throw an exception.

The `controller` object passed to `start()`, `transform()`, and `flush()` is an instance of `TransformStreamDefaultController`, and has the ability to enqueue chunks to the readable side, or to terminate or error the stream.


#### Constructor and properties

`stream = new TransformStream([transformer[, writableStrategy[, readableStrategy]]])`

Creates a new `TransformStream` wrapping the provided transformer. See § 6.2.3 The transformer API for more details on the `transformer` argument.

If no `transformer` argument is supplied, then the result will be an identity transform stream. See this example for some cases where that can be useful.

The `writableStrategy` and `readableStrategy` arguments are the queuing strategy objects for the writable and readable sides respectively. These are used in the construction of the `WritableStream` and `ReadableStream` objects and can be used to add buffering to a `TransformStream`, in order to smooth out variations in the speed of the transformation, or to increase the amount of buffering in a pipe. If they are not provided, the default behavior will be the same as a `CountQueuingStrategy`, with respective high water marks of 1 and 0.

`readable = stream.readable`

Returns a `ReadableStream` representing the readable side of this transform stream.

`writable = stream.writable`

Returns a `WritableStream` representing the writable side of this transform stream.

The `new TransformStream(transformer, writableStrategy, readableStrategy)` constructor steps are:

1. If `transformer` is missing, set it to null.

2. Let `transformerDict` be `transformer`, converted to an IDL value of type `Transformer`.

   We cannot declare the `transformer` argument as having the `Transformer` type directly, because doing so would lose the reference to the original object. We need to retain the object so we can invoke the various methods on it.

3. If `transformerDict`["readableType"] exists, throw a `RangeError` exception.

4. If `transformerDict`["writableType"] exists, throw a `RangeError` exception.

5. Let `readableHighWaterMark` be ? ExtractHighWaterMark(`readableStrategy`, 0).

6. Let `readableSizeAlgorithm` be ! ExtractSizeAlgorithm(`readableStrategy`).

7. Let `writableHighWaterMark` be ? ExtractHighWaterMark(`writableStrategy`, 1).

8. Let `writableSizeAlgorithm` be ! ExtractSizeAlgorithm(`writableStrategy`).

9. Let `startPromise` be a new promise.

10. Perform ! InitializeTransformStream(this, `startPromise`, `writableHighWaterMark`, `writableSizeAlgorithm`, `readableHighWaterMark`, `readableSizeAlgorithm`).

11. Perform ? SetUpTransformStreamDefaultControllerFromTransformer(this, `transformer`, `transformerDict`).

12. If `transformerDict`["start"] exists, then resolve `startPromise` with the result of invoking `transformerDict`["start"] with argument list « this.[[controller]] » and callback this value `transformer`.

13. Otherwise, resolve `startPromise` with undefined.

The `readable` getter steps are:

1. Return this.[[readable]].

The `writable` getter steps are:

1. Return this.[[writable]].


#### Transfer via `postMessage()`

`destination.postMessage(ts, { transfer: [ts] });`

Sends a `TransformStream` to another frame, window, or worker.

The transferred stream can be used exactly like the original. Its readable and writable sides will become locked and no longer directly usable.

`TransformStream` objects are transferable objects. Their transfer steps, given `value` and `dataHolder`, are:

1. Let `readable` be `value`.[[readable]].

2. Let `writable` be `value`.[[writable]].

3. If ! IsReadableStreamLocked(`readable`) is true, throw a "`DataCloneError`" `DOMException`.

4. If ! IsWritableStreamLocked(`writable`) is true, throw a "`DataCloneError`" `DOMException`.

5. Set `dataHolder`.[[readable]] to ! StructuredSerializeWithTransfer(`readable`, « `readable` »).

6. Set `dataHolder`.[[writable]] to ! StructuredSerializeWithTransfer(`writable`, « `writable` »).

Their transfer-receiving steps, given `dataHolder` and `value`, are:

1. Let `readableRecord` be ! StructuredDeserializeWithTransfer(`dataHolder`.[[readable]], the current Realm).

2. Let `writableRecord` be ! StructuredDeserializeWithTransfer(`dataHolder`.[[writable]], the current Realm).

3. Set `value`.[[readable]] to `readableRecord`.[[Deserialized]].

4. Set `value`.[[writable]] to `writableRecord`.[[Deserialized]].

5. Set `value`.[[backpressure]], `value`.[[backpressureChangePromise]], and `value`.[[controller]] to undefined.

The [[backpressure]], [[backpressureChangePromise]], and [[controller]] slots are not used in a transferred `TransformStream`.


### The `TransformStreamDefaultController` class

The `TransformStreamDefaultController` class has methods that allow manipulation of the associated `ReadableStream` and `WritableStream`. When constructing a `TransformStream`, the transformer object is given a corresponding `TransformStreamDefaultController` instance to manipulate.


#### Interface definition

The Web IDL definition for the `TransformStreamDefaultController` class is given as follows:

```idl
[Exposed=*]
interface TransformStreamDefaultController {
  readonly attribute unrestricted double? desiredSize;

  undefined enqueue(optional any chunk);
  undefined error(optional any reason);
  undefined terminate();
};
```


#### Internal slots

Instances of `TransformStreamDefaultController` are created with the internal slots described in the following table:

| Internal Slot | Description (*non-normative*) |
|---------------|-------------------------------|
| [[cancelAlgorithm]] | A promise-returning algorithm, taking one argument (the reason for cancellation), which communicates a requested cancellation to the transformer |
| [[finishPromise]] | A promise which resolves on completion of either the [[cancelAlgorithm]] or the [[flushAlgorithm]]. If this field is unpopulated (that is, undefined), then neither of those algorithms have been invoked yet |
| [[flushAlgorithm]] | A promise-returning algorithm which communicates a requested close to the transformer |
| [[stream]] | The `TransformStream` instance controlled |
| [[transformAlgorithm]] | A promise-returning algorithm, taking one argument (the chunk to transform), which requests the transformer perform its transformation |


#### Methods and properties

`desiredSize = controller.desiredSize`

Returns the desired size to fill the readable side's internal queue. It can be negative, if the queue is over-full.

`controller.enqueue(chunk)`

Enqueues the given chunk `chunk` in the readable side of the controlled transform stream.

`controller.error(e)`

Errors both the readable side and the writable side of the controlled transform stream, making all future interactions with it fail with the given error `e`. Any chunks queued for transformation will be discarded.

`controller.terminate()`

Closes the readable side and errors the writable side of the controlled transform stream. This is useful when the transformer only needs to consume a portion of the chunks written to the writable side.

The `desiredSize` getter steps are:

1. Let `readableController` be this.[[stream]].[[readable]].[[controller]].

2. Return ! ReadableStreamDefaultControllerGetDesiredSize(`readableController`).

The `enqueue(chunk)` method steps are:

1. Perform ? TransformStreamDefaultControllerEnqueue(this, `chunk`).

The `error(e)` method steps are:

1. Perform ? TransformStreamDefaultControllerError(this, `e`).

The `terminate()` method steps are:

1. Perform ? TransformStreamDefaultControllerTerminate(this).


#### Working with transform streams

The following abstract operations operate on `TransformStream` instances at a higher level.

InitializeTransformStream(`stream`, `startPromise`, `writableHighWaterMark`, `writableSizeAlgorithm`, `readableHighWaterMark`, `readableSizeAlgorithm`) performs the following steps:

1. Let `startAlgorithm` be an algorithm that returns `startPromise`.

2. Let `writeAlgorithm` be the following steps, taking a `chunk` argument:

   1. Return ! TransformStreamDefaultSinkWriteAlgorithm(`stream`, `chunk`).

3. Let `abortAlgorithm` be the following steps, taking a `reason` argument:

   1. Return ! TransformStreamDefaultSinkAbortAlgorithm(`stream`, `reason`).

4. Let `closeAlgorithm` be the following steps:

   1. Return ! TransformStreamDefaultSinkCloseAlgorithm(`stream`).

5. Set `stream`.[[writable]] to ! CreateWritableStream(`startAlgorithm`, `writeAlgorithm`, `closeAlgorithm`, `abortAlgorithm`, `writableHighWaterMark`, `writableSizeAlgorithm`).

6. Let `pullAlgorithm` be the following steps:

   1. Return ! TransformStreamDefaultSourcePullAlgorithm(`stream`).

7. Let `cancelAlgorithm` be the following steps, taking a `reason` argument:

   1. Return ! TransformStreamDefaultSourceCancelAlgorithm(`stream`, `reason`).

8. Set `stream`.[[readable]] to ! CreateReadableStream(`startAlgorithm`, `pullAlgorithm`, `cancelAlgorithm`, `readableHighWaterMark`, `readableSizeAlgorithm`).

9. Set `stream`.[[backpressure]] and `stream`.[[backpressureChangePromise]] to undefined.

   The [[backpressure]] slot is set to undefined so that it can be initialized by TransformStreamSetBackpressure. Alternatively, implementations can use a strictly boolean value for [[backpressure]] and change the way it is initialized. This will not be visible to user code so long as the initialization is correctly completed before the transformer's `start()` method is called.

10. Perform ! TransformStreamSetBackpressure(`stream`, true).

11. Set `stream`.[[controller]] to undefined.

TransformStreamError(`stream`, `e`) performs the following steps:

1. Perform ! ReadableStreamDefaultControllerError(`stream`.[[readable]].[[controller]], `e`).

2. Perform ! TransformStreamErrorWritableAndUnblockWrite(`stream`, `e`).

This operation works correctly when one or both sides are already errored. As a result, calling algorithms do not need to check stream states when responding to an error condition.

TransformStreamErrorWritableAndUnblockWrite(`stream`, `e`) performs the following steps:

1. Perform ! TransformStreamDefaultControllerClearAlgorithms(`stream`.[[controller]]).

2. Perform ! WritableStreamDefaultControllerErrorIfNeeded(`stream`.[[writable]].[[controller]], `e`).

3. Perform ! TransformStreamUnblockWrite(`stream`).

TransformStreamSetBackpressure(`stream`, `backpressure`) performs the following steps:

1. Assert: `stream`.[[backpressure]] is not `backpressure`.

2. If `stream`.[[backpressureChangePromise]] is not undefined, resolve stream.[[backpressureChangePromise]] with undefined.

3. Set `stream`.[[backpressureChangePromise]] to a new promise.

4. Set `stream`.[[backpressure]] to `backpressure`.

TransformStreamUnblockWrite(`stream`) performs the following steps:

1. If `stream`.[[backpressure]] is true, perform ! TransformStreamSetBackpressure(`stream`, false).

The TransformStreamDefaultSinkWriteAlgorithm abstract operation could be waiting for the promise stored in the [[backpressureChangePromise]] slot to resolve. The call to TransformStreamSetBackpressure ensures that the promise always resolves.


#### Default controllers

The following abstract operations support the implementaiton of the `TransformStreamDefaultController` class.

SetUpTransformStreamDefaultController(`stream`, `controller`, `transformAlgorithm`, `flushAlgorithm`, `cancelAlgorithm`) performs the following steps:

1. Assert: `stream` implements `TransformStream`.

2. Assert: `stream`.[[controller]] is undefined.

3. Set `controller`.[[stream]] to `stream`.

4. Set `stream`.[[controller]] to `controller`.

5. Set `controller`.[[transformAlgorithm]] to `transformAlgorithm`.

6. Set `controller`.[[flushAlgorithm]] to `flushAlgorithm`.

7. Set `controller`.[[cancelAlgorithm]] to `cancelAlgorithm`.

SetUpTransformStreamDefaultControllerFromTransformer(`stream`, `transformer`, `transformerDict`) performs the following steps:

1. Let `controller` be a new `TransformStreamDefaultController`.

2. Let `transformAlgorithm` be the following steps, taking a `chunk` argument:

   1. Let `result` be TransformStreamDefaultControllerEnqueue(`controller`, `chunk`).

   2. If `result` is an abrupt completion, return a promise rejected with `result`.[[Value]].

   3. Otherwise, return a promise resolved with undefined.

3. Let `flushAlgorithm` be an algorithm which returns a promise resolved with undefined.

4. Let `cancelAlgorithm` be an algorithm which returns a promise resolved with undefined.

5. If `transformerDict`["transform"] exists, set `transformAlgorithm` to an algorithm which takes an argument `chunk` and returns the result of invoking `transformerDict`["transform"] with argument list « `chunk`, `controller` » and callback this value `transformer`.

6. If `transformerDict`["flush"] exists, set `flushAlgorithm` to an algorithm which returns the result of invoking `transformerDict`["flush"] with argument list « `controller` » and callback this value `transformer`.

7. If `transformerDict`["cancel"] exists, set `cancelAlgorithm` to an algorithm which takes an argument `reason` and returns the result of invoking `transformerDict`["cancel"] with argument list « `reason` » and callback this value `transformer`.

8. Perform ! SetUpTransformStreamDefaultController(`stream`, `controller`, `transformAlgorithm`, `flushAlgorithm`, `cancelAlgorithm`).

TransformStreamDefaultControllerClearAlgorithms(`controller`) is called once the stream is closed or errored and the algorithms will not be executed any more. By removing the algorithm references it permits the transformer object to be garbage collected even if the `TransformStream` itself is still referenced.

This is observable using weak references. See tc39/proposal-weakrefs#31 for more detail.

It performs the following steps:

1. Set `controller`.[[transformAlgorithm]] to undefined.

2. Set `controller`.[[flushAlgorithm]] to undefined.

3. Set `controller`.[[cancelAlgorithm]] to undefined.

TransformStreamDefaultControllerEnqueue(`controller`, `chunk`) performs the following steps:

1. Let `stream` be `controller`.[[stream]].

2. Let `readableController` be `stream`.[[readable]].[[controller]].

3. If ! ReadableStreamDefaultControllerCanCloseOrEnqueue(`readableController`) is false, throw a `TypeError` exception.

4. Let `enqueueResult` be ReadableStreamDefaultControllerEnqueue(`readableController`, `chunk`).

5. If `enqueueResult` is an abrupt completion,

   1. Perform ! TransformStreamErrorWritableAndUnblockWrite(`stream`, `enqueueResult`.[[Value]]).

   2. Throw `stream`.[[readable]].[[storedError]].

6. Let `backpressure` be ! ReadableStreamDefaultControllerHasBackpressure(`readableController`).

7. If `backpressure` is not `stream`.[[backpressure]],

   1. Assert: `backpressure` is true.

   2. Perform ! TransformStreamSetBackpressure(`stream`, true).

TransformStreamDefaultControllerError(`controller`, `e`) performs the following steps:

1. Perform ! TransformStreamError(`controller`.[[stream]], `e`).

TransformStreamDefaultControllerPerformTransform(`controller`, `chunk`) performs the following steps:

1. Let `transformPromise` be the result of performing `controller`.[[transformAlgorithm]], passing `chunk`.

2. Return the result of reacting to `transformPromise` with the following rejection steps given the argument `r`:

   1. Perform ! TransformStreamError(`controller`.[[stream]], `r`).

   2. Throw `r`.

TransformStreamDefaultControllerTerminate(`controller`) performs the following steps:

1. Let `stream` be `controller`.[[stream]].

2. Let `readableController` be `stream`.[[readable]].[[controller]].

3. Perform ! ReadableStreamDefaultControllerClose(`readableController`).

4. Let `error` be a `TypeError` exception indicating that the stream has been terminated.

5. Perform ! TransformStreamErrorWritableAndUnblockWrite(`stream`, `error`).


#### Default sinks

The following abstract operations are used to implement the underlying sink for the writable side of transform streams.

TransformStreamDefaultSinkWriteAlgorithm(`stream`, `chunk`) performs the following steps:

1. Assert: `stream`.[[writable]].[[state]] is "`writable`".

2. Let `controller` be `stream`.[[controller]].

3. If `stream`.[[backpressure]] is true,

   1. Let `backpressureChangePromise` be `stream`.[[backpressureChangePromise]].

   2. Assert: `backpressureChangePromise` is not undefined.

   3. Return the result of reacting to `backpressureChangePromise` with the following fulfillment steps:

      1. Let `writable` be `stream`.[[writable]].

      2. Let `state` be `writable`.[[state]].

      3. If `state` is "`erroring`", throw `writable`.[[storedError]].

      4. Assert: `state` is "`writable`".

      5. Return ! TransformStreamDefaultControllerPerformTransform(`controller`, `chunk`).

4. Return ! TransformStreamDefaultControllerPerformTransform(`controller`, `chunk`).

TransformStreamDefaultSinkAbortAlgorithm(`stream`, `reason`) performs the following steps:

1. Let `controller` be `stream`.[[controller]].

2. If `controller`.[[finishPromise]] is not undefined, return `controller`.[[finishPromise]].

3. Let `readable` be `stream`.[[readable]].

4. Let `controller`.[[finishPromise]] be a new promise.

5. Let `cancelPromise` be the result of performing `controller`.[[cancelAlgorithm]], passing `reason`.

6. Perform ! TransformStreamDefaultControllerClearAlgorithms(`controller`).

7. React to `cancelPromise`:

   1. If `cancelPromise` was fulfilled, then:

      1. If `readable`.[[state]] is "`errored`", reject `controller`.[[finishPromise]] with `readable`.[[storedError]].

      2. Otherwise:

         1. Perform ! ReadableStreamDefaultControllerError(`readable`.[[controller]], `reason`).

         2. Resolve `controller`.[[finishPromise]] with undefined.

   2. If `cancelPromise` was rejected with reason `r`, then:

      1. Perform ! ReadableStreamDefaultControllerError(`readable`.[[controller]], `r`).

      2. Reject `controller`.[[finishPromise]] with `r`.

8. Return `controller`.[[finishPromise]].

TransformStreamDefaultSinkCloseAlgorithm(`stream`) performs the following steps:

1. Let `controller` be `stream`.[[controller]].

2. If `controller`.[[finishPromise]] is not undefined, return `controller`.[[finishPromise]].

3. Let `readable` be `stream`.[[readable]].

4. Let `controller`.[[finishPromise]] be a new promise.

5. Let `flushPromise` be the result of performing `controller`.[[flushAlgorithm]].

6. Perform ! TransformStreamDefaultControllerClearAlgorithms(`controller`).

7. React to `flushPromise`:

   1. If `flushPromise` was fulfilled, then:

      1. If `readable`.[[state]] is "`errored`", reject `controller`.[[finishPromise]] with `readable`.[[storedError]].

      2. Otherwise:

         1. Perform ! ReadableStreamDefaultControllerClose(`readable`.[[controller]]).

         2. Resolve `controller`.[[finishPromise]] with undefined.

   2. If `flushPromise` was rejected with reason `r`, then:

      1. Perform ! ReadableStreamDefaultControllerError(`readable`.[[controller]], `r`).

      2. Reject `controller`.[[finishPromise]] with `r`.

8. Return `controller`.[[finishPromise]].


#### Default sources

The following abstract operation is used to implement the underlying source for the readable side of transform streams.

TransformStreamDefaultSourceCancelAlgorithm(`stream`, `reason`) performs the following steps:

1. Let `controller` be `stream`.[[controller]].

2. If `controller`.[[finishPromise]] is not undefined, return `controller`.[[finishPromise]].

3. Let `writable` be `stream`.[[writable]].

4. Let `controller`.[[finishPromise]] be a new promise.

5. Let `cancelPromise` be the result of performing `controller`.[[cancelAlgorithm]], passing `reason`.

6. Perform ! TransformStreamDefaultControllerClearAlgorithms(`controller`).

7. React to `cancelPromise`:

   1. If `cancelPromise` was fulfilled, then:

      1. If `writable`.[[state]] is "`errored`", reject `controller`.[[finishPromise]] with `writable`.[[storedError]].

      2. Otherwise:

         1. Perform ! WritableStreamDefaultControllerErrorIfNeeded(`writable`.[[controller]], `reason`).

         2. Perform ! TransformStreamUnblockWrite(`stream`).

         3. Resolve `controller`.[[finishPromise]] with undefined.

   2. If `cancelPromise` was rejected with reason `r`, then:

      1. Perform ! WritableStreamDefaultControllerErrorIfNeeded(`writable`.[[controller]], `r`).

      2. Perform ! TransformStreamUnblockWrite(`stream`).

      3. Reject `controller`.[[finishPromise]] with `r`.

8. Return `controller`.[[finishPromise]].

TransformStreamDefaultSourcePullAlgorithm(`stream`) performs the following steps:

1. Assert: `stream`.[[backpressure]] is true.

2. Assert: `stream`.[[backpressureChangePromise]] is not undefined.

3. Perform ! TransformStreamSetBackpressure(`stream`, false).

4. Return `stream`.[[backpressureChangePromise]].


## Queuing strategies


### The queuing strategy API

The `ReadableStream()`, `WritableStream()`, and `TransformStream()` constructors all accept at least one argument representing an appropriate queuing strategy for the stream being created. Such objects contain the following properties:

```idl
dictionary QueuingStrategy {
  unrestricted double highWaterMark;
  QueuingStrategySize size;
};

callback QueuingStrategySize = unrestricted double (any chunk);
```

`highWaterMark`, of type unrestricted double

:   A non-negative number indicating the high water mark of the stream using this queuing strategy.

`size(chunk)` (non-byte streams only), of type QueuingStrategySize

:   A function that computes and returns the finite non-negative size of the given chunk value.

    The result is used to determine backpressure, manifesting via the appropriate `desiredSize` property: either `defaultController.desiredSize`, `byteController.desiredSize`, or `writer.desiredSize`, depending on where the queuing strategy is being used. For readable streams, it also governs when the underlying source's `pull()` method is called.

    This function has to be idempotent and not cause side effects; very strange results can occur otherwise.

    For readable byte streams, this function is not used, as chunks are always measured in bytes.

Any object with these properties can be used when a queuing strategy object is expected. However, we provide two built-in queuing strategy classes that provide a common vocabulary for certain cases: `ByteLengthQueuingStrategy` and `CountQueuingStrategy`. They both make use of the following Web IDL fragment for their constructors:

```idl
dictionary QueuingStrategyInit {
  required unrestricted double highWaterMark;
};
```


### The `ByteLengthQueuingStrategy` class

A common queuing strategy when dealing with bytes is to wait until the accumulated `byteLength` properties of the incoming chunks reaches a specified high-water mark. As such, this is provided as a built-in queuing strategy that can be used when constructing streams.

When creating a readable stream or writable stream, you can supply a byte-length queuing strategy directly:

```highlight
const stream = new ReadableStream(
  { ... },
  new ByteLengthQueuingStrategy({ highWaterMark: 16 * 1024 })
);
```

In this case, 16 KiB worth of chunks can be enqueued by the readable stream's underlying source before the readable stream implementation starts sending backpressure signals to the underlying source.

```highlight
const stream = new WritableStream(
  { ... },
  new ByteLengthQueuingStrategy({ highWaterMark: 32 * 1024 })
);
```

In this case, 32 KiB worth of chunks can be accumulated in the writable stream's internal queue, waiting for previous writes to the underlying sink to finish, before the writable stream starts sending backpressure signals to any producers.

It is not necessary to use `ByteLengthQueuingStrategy` with readable byte streams, as they always measure chunks in bytes. Attempting to construct a byte stream with a `ByteLengthQueuingStrategy` will fail.


#### Interface definition

The Web IDL definition for the `ByteLengthQueuingStrategy` class is given as follows:

```idl
[Exposed=*]
interface ByteLengthQueuingStrategy {
  constructor(QueuingStrategyInit init);

  readonly attribute unrestricted double highWaterMark;
  readonly attribute Function size;
};
```


#### Internal slots

Instances of `ByteLengthQueuingStrategy` have a [[highWaterMark]] internal slot, storing the value given in the constructor.

Additionally, every global object `globalObject` has an associated byte length queuing strategy size function, which is a `Function` whose value must be initialized as follows:

1.  Let `steps` be the following steps, given `chunk`:

    1.  Return ? GetV(`chunk`, "`byteLength`").

2.  Let `F` be ! CreateBuiltinFunction(`steps`, 1, "`size`", « », `globalObject`'s relevant Realm).

3.  Set `globalObject`'s byte length queuing strategy size function to a `Function` that represents a reference to `F`, with callback context equal to `globalObject`'s relevant settings object.

This design is somewhat historical. It is motivated by the desire to ensure that `size` is a function, not a method, i.e. it does not check its `this` value. See [whatwg/streams#1005](https://github.com/whatwg/streams/issues/1005) and [heycam/webidl#819](https://github.com/heycam/webidl/issues/819) for more background.


#### Constructor and properties

`strategy = new ByteLengthQueuingStrategy({ highWaterMark })`

:   Creates a new `ByteLengthQueuingStrategy` with the provided high water mark.

    Note that the provided high water mark will not be validated ahead of time. Instead, if it is negative, NaN, or not a number, the resulting `ByteLengthQueuingStrategy` will cause the corresponding stream constructor to throw.

`highWaterMark = strategy.highWaterMark`

:   Returns the high water mark provided to the constructor.

`strategy.size(chunk)`

:   Measures the size of `chunk` by returning the value of its `byteLength` property.

The `new ByteLengthQueuingStrategy(init)` constructor steps are:

1.  Set this.[[highWaterMark]] to `init`["`highWaterMark`"].

The `highWaterMark` getter steps are:

1.  Return this.[[highWaterMark]].

The `size` getter steps are:

1.  Return this's relevant global object's byte length queuing strategy size function.


### The `CountQueuingStrategy` class

A common queuing strategy when dealing with streams of generic objects is to simply count the number of chunks that have been accumulated so far, waiting until this number reaches a specified high-water mark. As such, this strategy is also provided out of the box.

When creating a readable stream or writable stream, you can supply a count queuing strategy directly:

```highlight
const stream = new ReadableStream(
  { ... },
  new CountQueuingStrategy({ highWaterMark: 10 })
);
```

In this case, 10 chunks (of any kind) can be enqueued by the readable stream's underlying source before the readable stream implementation starts sending backpressure signals to the underlying source.

```highlight
const stream = new WritableStream(
  { ... },
  new CountQueuingStrategy({ highWaterMark: 5 })
);
```

In this case, five chunks (of any kind) can be accumulated in the writable stream's internal queue, waiting for previous writes to the underlying sink to finish, before the writable stream starts sending backpressure signals to any producers.


#### Interface definition

The Web IDL definition for the `CountQueuingStrategy` class is given as follows:

```idl
[Exposed=*]
interface CountQueuingStrategy {
  constructor(QueuingStrategyInit init);

  readonly attribute unrestricted double highWaterMark;
  readonly attribute Function size;
};
```


#### Internal slots

Instances of `CountQueuingStrategy` have a [[highWaterMark]] internal slot, storing the value given in the constructor.

Additionally, every global object `globalObject` has an associated count queuing strategy size function, which is a `Function` whose value must be initialized as follows:

1.  Let `steps` be the following steps:

    1.  Return 1.

2.  Let `F` be ! CreateBuiltinFunction(`steps`, 0, "`size`", « », `globalObject`'s relevant Realm).

3.  Set `globalObject`'s count queuing strategy size function to a `Function` that represents a reference to `F`, with callback context equal to `globalObject`'s relevant settings object.

This design is somewhat historical. It is motivated by the desire to ensure that `size` is a function, not a method, i.e. it does not check its `this` value. See [whatwg/streams#1005](https://github.com/whatwg/streams/issues/1005) and [heycam/webidl#819](https://github.com/heycam/webidl/issues/819) for more background.


#### Constructor and properties

`strategy = new CountQueuingStrategy({ highWaterMark })`

:   Creates a new `CountQueuingStrategy` with the provided high water mark.

    Note that the provided high water mark will not be validated ahead of time. Instead, if it is negative, NaN, or not a number, the resulting `CountQueuingStrategy` will cause the corresponding stream constructor to throw.

`highWaterMark = strategy.highWaterMark`

:   Returns the high water mark provided to the constructor.

`strategy.size(chunk)`

:   Measures the size of `chunk` by always returning 1. This ensures that the total queue size is a count of the number of chunks in the queue.

The `new CountQueuingStrategy(init)` constructor steps are:

1.  Set this.[[highWaterMark]] to `init`["`highWaterMark`"].

The `highWaterMark` getter steps are:

1.  Return this.[[highWaterMark]].

The `size` getter steps are:

1.  Return this's relevant global object's count queuing strategy size function.


### Abstract operations

The following algorithms are used by the stream constructors to extract the relevant pieces from a `QueuingStrategy` dictionary.

ExtractHighWaterMark(`strategy`, `defaultHWM`) performs the following steps:

1.  If `strategy`["`highWaterMark`"] does not exist, return `defaultHWM`.

2.  Let `highWaterMark` be `strategy`["`highWaterMark`"].

3.  If `highWaterMark` is NaN or `highWaterMark` < 0, throw a `RangeError` exception.

4.  Return `highWaterMark`.

+∞ is explicitly allowed as a valid high water mark. It causes backpressure to never be applied.

ExtractSizeAlgorithm(`strategy`) performs the following steps:

1.  If `strategy`["`size`"] does not exist, return an algorithm that returns 1.

2.  Return an algorithm that performs the following steps, taking a `chunk` argument:

    1.  Return the result of invoking `strategy`["`size`"] with argument list « `chunk` ».


## Supporting abstract operations

The following abstract operations each support the implementation of more than one type of stream, and as such are not grouped under the major sections above.


### Queue-with-sizes

The streams in this specification use a "queue-with-sizes" data structure to store queued up values, along with their determined sizes. Various specification objects contain a queue-with-sizes, represented by the object having two paired internal slots, always named [[queue]] and [[queueTotalSize]]. [[queue]] is a list of value-with-sizes, and [[queueTotalSize]] is a JavaScript `Number`, i.e. a double-precision floating point number.

The following abstract operations are used when operating on objects that contain queues-with-sizes, in order to ensure that the two internal slots stay synchronized.

Due to the limited precision of floating-point arithmetic, the framework specified here, of keeping a running total in the [[queueTotalSize]] slot, is *not* equivalent to adding up the size of all chunks in [[queue]]. (However, this only makes a difference when there is a huge (~10^15^) variance in size between chunks, or when trillions of chunks are enqueued.)

In what follows, a value-with-size is a struct with the two items value and size.

DequeueValue(`container`) performs the following steps:

1.  Assert: `container` has [[queue]] and [[queueTotalSize]] internal slots.

2.  Assert: `container`.[[queue]] is not empty.

3.  Let `valueWithSize` be `container`.[[queue]][0].

4.  Remove `valueWithSize` from `container`.[[queue]].

5.  Set `container`.[[queueTotalSize]] to `container`.[[queueTotalSize]] − `valueWithSize`'s size.

6.  If `container`.[[queueTotalSize]] < 0, set `container`.[[queueTotalSize]] to 0. (This can occur due to rounding errors.)

7.  Return `valueWithSize`'s value.

EnqueueValueWithSize(`container`, `value`, `size`) performs the following steps:

1.  Assert: `container` has [[queue]] and [[queueTotalSize]] internal slots.

2.  If ! IsNonNegativeNumber(`size`) is false, throw a `RangeError` exception.

3.  If `size` is +∞, throw a `RangeError` exception.

4.  Append a new value-with-size with value `value` and size `size` to `container`.[[queue]].

5.  Set `container`.[[queueTotalSize]] to `container`.[[queueTotalSize]] + `size`.

PeekQueueValue(`container`) performs the following steps:

1.  Assert: `container` has [[queue]] and [[queueTotalSize]] internal slots.

2.  Assert: `container`.[[queue]] is not empty.

3.  Let `valueWithSize` be `container`.[[queue]][0].

4.  Return `valueWithSize`'s value.

ResetQueue(`container`) performs the following steps:

1.  Assert: `container` has [[queue]] and [[queueTotalSize]] internal slots.

2.  Set `container`.[[queue]] to a new empty list.

3.  Set `container`.[[queueTotalSize]] to 0.


### Transferable streams

Transferable streams are implemented using a special kind of identity transform which has the writable side in one realm and the readable side in another realm. The following abstract operations are used to implement these "cross-realm transforms".

CrossRealmTransformSendError(`port`, `error`) performs the following steps:

1.  Perform PackAndPostMessage(`port`, "`error`", `error`), discarding the result.

As we are already in an errored state when this abstract operation is performed, we cannot handle further errors, so we just discard them.

PackAndPostMessage(`port`, `type`, `value`) performs the following steps:

1.  Let `message` be OrdinaryObjectCreate(null).

2.  Perform ! CreateDataProperty(`message`, "`type`", `type`).

3.  Perform ! CreateDataProperty(`message`, "`value`", `value`).

4.  Let `targetPort` be the port with which `port` is entangled, if any; otherwise let it be null.

5.  Let `options` be «[ "`transfer`" → « » ]».

6.  Run the message port post message steps providing `targetPort`, `message`, and `options`.

A JavaScript object is used for transfer to avoid having to duplicate the message port post message steps. The prototype of the object is set to null to avoid interference from `%Object.prototype%`.

PackAndPostMessageHandlingError(`port`, `type`, `value`) performs the following steps:

1.  Let `result` be PackAndPostMessage(`port`, `type`, `value`).

2.  If `result` is an abrupt completion,

    1.  Perform ! CrossRealmTransformSendError(`port`, `result`.[[Value]]).

3.  Return `result` as a completion record.

SetUpCrossRealmTransformReadable(`stream`, `port`) performs the following steps:

1.  Perform ! InitializeReadableStream(`stream`).

2.  Let `controller` be a new `ReadableStreamDefaultController`.

3.  Add a handler for `port`'s `message` event with the following steps:

    1.  Let `data` be the data of the message.

    2.  Assert: `data` is an Object.

    3.  Let `type` be ! Get(`data`, "`type`").

    4.  Let `value` be ! Get(`data`, "`value`").

    5.  Assert: `type` is a String.

    6.  If `type` is "`chunk`",

        1.  Perform ! ReadableStreamDefaultControllerEnqueue(`controller`, `value`).

    7.  Otherwise, if `type` is "`close`",

        1.  Perform ! ReadableStreamDefaultControllerClose(`controller`).

        2.  Disentangle `port`.

    8.  Otherwise, if `type` is "`error`",

        1.  Perform ! ReadableStreamDefaultControllerError(`controller`, `value`).

        2.  Disentangle `port`.

4.  Add a handler for `port`'s `messageerror` event with the following steps:

    1.  Let `error` be a new "`DataCloneError`" `DOMException`.

    2.  Perform ! CrossRealmTransformSendError(`port`, `error`).

    3.  Perform ! ReadableStreamDefaultControllerError(`controller`, `error`).

    4.  Disentangle `port`.

5.  Enable `port`'s port message queue.

6.  Let `startAlgorithm` be an algorithm that returns undefined.

7.  Let `pullAlgorithm` be the following steps:

    1.  Perform ! PackAndPostMessage(`port`, "`pull`", undefined).

    2.  Return a promise resolved with undefined.

8.  Let `cancelAlgorithm` be the following steps, taking a `reason` argument:

    1.  Let `result` be PackAndPostMessageHandlingError(`port`, "`error`", `reason`).

    2.  Disentangle `port`.

    3.  If `result` is an abrupt completion, return a promise rejected with `result`.[[Value]].

    4.  Otherwise, return a promise resolved with undefined.

9.  Let `sizeAlgorithm` be an algorithm that returns 1.

10. Perform ! SetUpReadableStreamDefaultController(`stream`, `controller`, `startAlgorithm`, `pullAlgorithm`, `cancelAlgorithm`, 0, `sizeAlgorithm`).

Implementations are encouraged to explicitly handle failures from the asserts in this algorithm, as the input might come from an untrusted context. Failure to do so could lead to security issues.

SetUpCrossRealmTransformWritable(`stream`, `port`) performs the following steps:

1.  Perform ! InitializeWritableStream(`stream`).

2.  Let `controller` be a new `WritableStreamDefaultController`.

3.  Let `backpressurePromise` be a new promise.

4.  Add a handler for `port`'s `message` event with the following steps:

    1.  Let `data` be the data of the message.

    2.  Assert: `data` is an Object.

    3.  Let `type` be ! Get(`data`, "`type`").

    4.  Let `value` be ! Get(`data`, "`value`").

    5.  Assert: `type` is a String.

    6.  If `type` is "`pull`",

        1.  If `backpressurePromise` is not undefined,

            1.  Resolve `backpressurePromise` with undefined.

            2.  Set `backpressurePromise` to undefined.

    7.  Otherwise, if `type` is "`error`",

        1.  Perform ! WritableStreamDefaultControllerErrorIfNeeded(`controller`, `value`).

        2.  If `backpressurePromise` is not undefined,

            1.  Resolve `backpressurePromise` with undefined.

            2.  Set `backpressurePromise` to undefined.

5.  Add a handler for `port`'s `messageerror` event with the following steps:

    1.  Let `error` be a new "`DataCloneError`" `DOMException`.

    2.  Perform ! CrossRealmTransformSendError(`port`, `error`).

    3.  Perform ! WritableStreamDefaultControllerErrorIfNeeded(`controller`, `error`).

    4.  Disentangle `port`.

6.  Enable `port`'s port message queue.

7.  Let `startAlgorithm` be an algorithm that returns undefined.

8.  Let `writeAlgorithm` be the following steps, taking a `chunk` argument:

    1.  If `backpressurePromise` is undefined, set `backpressurePromise` to a promise resolved with undefined.

    2.  Return the result of reacting to `backpressurePromise` with the following fulfillment steps:

        1.  Set `backpressurePromise` to a new promise.

        2.  Let `result` be PackAndPostMessageHandlingError(`port`, "`chunk`", `chunk`).

        3.  If `result` is an abrupt completion,

            1.  Disentangle `port`.

            2.  Return a promise rejected with `result`.[[Value]].

        4.  Otherwise, return a promise resolved with undefined.

9.  Let `closeAlgorithm` be the following steps:

    1.  Perform ! PackAndPostMessage(`port`, "`close`", undefined).

    2.  Disentangle `port`.

    3.  Return a promise resolved with undefined.

10. Let `abortAlgorithm` be the following steps, taking a `reason` argument:

    1.  Let `result` be PackAndPostMessageHandlingError(`port`, "`error`", `reason`).

    2.  Disentangle `port`.

    3.  If `result` is an abrupt completion, return a promise rejected with `result`.[[Value]].

    4.  Otherwise, return a promise resolved with undefined.

11. Let `sizeAlgorithm` be an algorithm that returns 1.

12. Perform ! SetUpWritableStreamDefaultController(`stream`, `controller`, `startAlgorithm`, `writeAlgorithm`, `closeAlgorithm`, `abortAlgorithm`, 1, `sizeAlgorithm`).

Implementations are encouraged to explicitly handle failures from the asserts in this algorithm, as the input might come from an untrusted context. Failure to do so could lead to security issues.


### Miscellaneous

The following abstract operations are a grab-bag of utilities.

CanTransferArrayBuffer(`O`) performs the following steps:

1.  Assert: `O` is an Object.

2.  Assert: `O` has an [[ArrayBufferData]] internal slot.

3.  If ! IsDetachedBuffer(`O`) is true, return false.

4.  If SameValue(`O`.[[ArrayBufferDetachKey]], undefined) is false, return false.

5.  Return true.

IsNonNegativeNumber(`v`) performs the following steps:

1.  If `v` is not a Number, return false.

2.  If `v` is NaN, return false.

3.  If `v` < 0, return false.

4.  Return true.

TransferArrayBuffer(`O`) performs the following steps:

1.  Assert: ! IsDetachedBuffer(`O`) is false.

2.  Let `arrayBufferData` be `O`.[[ArrayBufferData]].

3.  Let `arrayBufferByteLength` be `O`.[[ArrayBufferByteLength]].

4.  Perform ? DetachArrayBuffer(`O`).

    This will throw an exception if `O` has an [[ArrayBufferDetachKey]] that is not undefined, such as a `WebAssembly.Memory`'s `buffer`.

5.  Return a new `ArrayBuffer` object, created in the current Realm, whose [[ArrayBufferData]] internal slot value is `arrayBufferData` and whose [[ArrayBufferByteLength]] internal slot value is `arrayBufferByteLength`.

CloneAsUint8Array(`O`) performs the following steps:

1.  Assert: `O` is an Object.

2.  Assert: `O` has an [[ViewedArrayBuffer]] internal slot.

3.  Assert: ! IsDetachedBuffer(`O`.[[ViewedArrayBuffer]]) is false.

4.  Let `buffer` be ? CloneArrayBuffer(`O`.[[ViewedArrayBuffer]], `O`.[[ByteOffset]], `O`.[[ByteLength]], `%ArrayBuffer%`).

5.  Let `array` be ! Construct(`%Uint8Array%`, « `buffer` »).

6.  Return `array`.

StructuredClone(`v`) performs the following steps:

1.  Let `serialized` be ? StructuredSerialize(`v`).

2.  Return ? StructuredDeserialize(`serialized`, the current Realm).

CanCopyDataBlockBytes(`toBuffer`, `toIndex`, `fromBuffer`, `fromIndex`, `count`) performs the following steps:

1.  Assert: `toBuffer` is an Object.

2.  Assert: `toBuffer` has an [[ArrayBufferData]] internal slot.

3.  Assert: `fromBuffer` is an Object.

4.  Assert: `fromBuffer` has an [[ArrayBufferData]] internal slot.

5.  If `toBuffer` is `fromBuffer`, return false.

6.  If ! IsDetachedBuffer(`toBuffer`) is true, return false.

7.  If ! IsDetachedBuffer(`fromBuffer`) is true, return false.

8.  If `toIndex` + `count` > `toBuffer`.[[ArrayBufferByteLength]], return false.

9.  If `fromIndex` + `count` > `fromBuffer`.[[ArrayBufferByteLength]], return false.

10. Return true.


## Using streams in other specifications

Much of this standard concerns itself with the internal machinery of streams. Other specifications generally do not need to worry about these details. Instead, they should interface with this standard via the various IDL types it defines, along with the following definitions.

Specifications should not directly inspect or manipulate the various internal slots defined in this standard. Similarly, they should not use the abstract operations defined here. Such direct usage can break invariants that this standard otherwise maintains.

If your specification wants to interface with streams in a way not supported here, [file an issue](https://github.com/whatwg/streams/issues/new). This section is intended to grow organically as needed.


### Readable streams


#### Creation and manipulation

To **set up** a newly-created-via-Web IDL `ReadableStream` object `stream`, given an optional algorithm **`pullAlgorithm`**, an optional algorithm **`cancelAlgorithm`**, an optional number **`highWaterMark`** (default 1), and an optional algorithm **`sizeAlgorithm`**, perform the following steps. If given, `pullAlgorithm` and `cancelAlgorithm` may return a promise. If given, `sizeAlgorithm` must be an algorithm accepting chunk objects and returning a number; and if given, `highWaterMark` must be a non-negative, non-NaN number.

1. Let `startAlgorithm` be an algorithm that returns undefined.

2. Let `pullAlgorithmWrapper` be an algorithm that runs these steps:

   1. Let `result` be the result of running `pullAlgorithm`, if `pullAlgorithm` was given, or null otherwise. If this throws an exception `e`, return a promise rejected with `e`.

   2. If `result` is a `Promise`, then return `result`.

   3. Return a promise resolved with undefined.

3. Let `cancelAlgorithmWrapper` be an algorithm that runs these steps given `reason`:

   1. Let `result` be the result of running `cancelAlgorithm` given `reason`, if `cancelAlgorithm` was given, or null otherwise. If this throws an exception `e`, return a promise rejected with `e`.

   2. If `result` is a `Promise`, then return `result`.

   3. Return a promise resolved with undefined.

4. If `sizeAlgorithm` was not given, then set it to an algorithm that returns 1.

5. Perform ! InitializeReadableStream(`stream`).

6. Let `controller` be a new `ReadableStreamDefaultController`.

7. Perform ! SetUpReadableStreamDefaultController(`stream`, `controller`, `startAlgorithm`, `pullAlgorithmWrapper`, `cancelAlgorithmWrapper`, `highWaterMark`, `sizeAlgorithm`).

To **set up with byte reading support** a newly-created-via-Web IDL `ReadableStream` object `stream`, given an optional algorithm **`pullAlgorithm`**, an optional algorithm **`cancelAlgorithm`**, and an optional number **`highWaterMark`** (default 0), perform the following steps. If given, `pullAlgorithm` and `cancelAlgorithm` may return a promise. If given, `highWaterMark` must be a non-negative, non-NaN number.

1. Let `startAlgorithm` be an algorithm that returns undefined.

2. Let `pullAlgorithmWrapper` be an algorithm that runs these steps:

   1. Let `result` be the result of running `pullAlgorithm`, if `pullAlgorithm` was given, or null otherwise. If this throws an exception `e`, return a promise rejected with `e`.

   2. If `result` is a `Promise`, then return `result`.

   3. Return a promise resolved with undefined.

3. Let `cancelAlgorithmWrapper` be an algorithm that runs these steps:

   1. Let `result` be the result of running `cancelAlgorithm`, if `cancelAlgorithm` was given, or null otherwise. If this throws an exception `e`, return a promise rejected with `e`.

   2. If `result` is a `Promise`, then return `result`.

   3. Return a promise resolved with undefined.

4. Perform ! InitializeReadableStream(`stream`).

5. Let `controller` be a new `ReadableByteStreamController`.

6. Perform ! SetUpReadableByteStreamController(`stream`, `controller`, `startAlgorithm`, `pullAlgorithmWrapper`, `cancelAlgorithmWrapper`, `highWaterMark`, undefined).

Creating a `ReadableStream` from other specifications is thus a two-step process, like so:

1. Let `readableStream` be a new `ReadableStream`.

2. Set up `readableStream` given....

Subclasses of `ReadableStream` will use the set up or set up with byte reading support operations directly on the this value inside their constructor steps.

The following algorithms must only be used on `ReadableStream` instances initialized via the above set up or set up with byte reading support algorithms (not, e.g., on web-developer-created instances):

A `ReadableStream` `stream`'s **desired size to fill up to the high water mark** is the result of running the following steps:

1. If `stream` is not readable, then return 0.

2. If `stream`.[[\[controller\]]] implements `ReadableByteStreamController`, then return ! ReadableByteStreamControllerGetDesiredSize(`stream`.[[\[controller\]]]).

3. Return ! ReadableStreamDefaultControllerGetDesiredSize(`stream`.[[\[controller\]]]).

A `ReadableStream` **needs more data** if its desired size to fill up to the high water mark is greater than zero.

To **close** a `ReadableStream` `stream`:

1. If `stream`.[[\[controller\]]] implements `ReadableByteStreamController`,

   1. Perform ! ReadableByteStreamControllerClose(`stream`.[[\[controller\]]]).

   2. If `stream`.[[\[controller\]]].[[\[pendingPullIntos\]]] is not empty, perform ! ReadableByteStreamControllerRespond(`stream`.[[\[controller\]]], 0).

2. Otherwise, perform ! ReadableStreamDefaultControllerClose(`stream`.[[\[controller\]]]).

To **error** a `ReadableStream` `stream` given a JavaScript value `e`:

1. If `stream`.[[\[controller\]]] implements `ReadableByteStreamController`, then perform ! ReadableByteStreamControllerError(`stream`.[[\[controller\]]], `e`).

2. Otherwise, perform ! ReadableStreamDefaultControllerError(`stream`.[[\[controller\]]], `e`).

To **enqueue** the JavaScript value `chunk` into a `ReadableStream` `stream`:

1. If `stream`.[[\[controller\]]] implements `ReadableStreamDefaultController`,

   1. Perform ! ReadableStreamDefaultControllerEnqueue(`stream`.[[\[controller\]]], `chunk`).

2. Otherwise,

   1. Assert: `stream`.[[\[controller\]]] implements `ReadableByteStreamController`.

   2. Assert: `chunk` is an `ArrayBufferView`.

   3. Let `byobView` be the current BYOB request view for `stream`.

   4. If `byobView` is non-null, and `chunk`.\[\[ViewedArrayBuffer\]\] is `byobView`.\[\[ViewedArrayBuffer\]\], then:

      1. Assert: `chunk`.\[\[ByteOffset\]\] is `byobView`.\[\[ByteOffset\]\].

      2. Assert: `chunk`.\[\[ByteLength\]\] ≤ `byobView`.\[\[ByteLength\]\].

         These asserts ensure that the caller does not write outside the requested range in the current BYOB request view.

      3. Perform ? ReadableByteStreamControllerRespond(`stream`.[[\[controller\]]], `chunk`.\[\[ByteLength\]\]).

   5. Otherwise, perform ? ReadableByteStreamControllerEnqueue(`stream`.[[\[controller\]]], `chunk`).

The following algorithms must only be used on `ReadableStream` instances initialized via the above set up with byte reading support algorithm:

The **current BYOB request view** for a `ReadableStream` `stream` is either an `ArrayBufferView` or null, determined by the following steps:

1. Assert: `stream`.[[\[controller\]]] implements `ReadableByteStreamController`.

2. Let `byobRequest` be ! ReadableByteStreamControllerGetBYOBRequest(`stream`.[[\[controller\]]]).

3. If `byobRequest` is null, then return null.

4. Return `byobRequest`.[[\[view\]]].

Specifications must not transfer or detach the underlying buffer of the current BYOB request view.

Implementations could do something equivalent to transferring, e.g. if they want to write into the memory from another thread. But they would need to make a few adjustments to how they implement the enqueue and close algorithms to keep the same observable consequences. In specification-land, transferring and detaching is just disallowed.

Specifications should, when possible, write into the current BYOB request view when it is non-null, and then call enqueue with that view. They should only create a new `ArrayBufferView` to pass to enqueue when the current BYOB request view is null, or when they have more bytes on hand than the current BYOB request view's byte length. This avoids unnecessary copies and better respects the wishes of the stream's consumer.

The following pull from bytes algorithm implements these requirements, for the common case where bytes are derived from a byte sequence that serves as the specification-level representation of an underlying byte source. Note that it is conservative and leaves bytes in the byte sequence, instead of aggressively enqueueing them, so callers of this algorithm might want to use the number of remaining bytes as a backpressure signal.

To **pull from bytes** with a byte sequence `bytes` into a `ReadableStream` `stream`:

1. Assert: `stream`.[[\[controller\]]] implements `ReadableByteStreamController`.

2. Let `available` be `bytes`'s length.

3. Let `desiredSize` be `available`.

4. If `stream`'s current BYOB request view is non-null, then set `desiredSize` to `stream`'s current BYOB request view's byte length.

5. Let `pullSize` be the smaller value of `available` and `desiredSize`.

6. Let `pulled` be the first `pullSize` bytes of `bytes`.

7. Remove the first `pullSize` bytes from `bytes`.

8. If `stream`'s current BYOB request view is non-null, then:

   1. Write `pulled` into `stream`'s current BYOB request view.

   2. Perform ? ReadableByteStreamControllerRespond(`stream`.[[\[controller\]]], `pullSize`).

9. Otherwise,

   1. Set `view` to the result of creating a `Uint8Array` from `pulled` in `stream`'s relevant Realm.

   2. Perform ? ReadableByteStreamControllerEnqueue(`stream`.[[\[controller\]]], `view`).

Specifications must not write into the current BYOB request view or pull from bytes after closing the corresponding `ReadableStream`.


#### Reading

The following algorithms can be used on arbitrary `ReadableStream` instances, including ones that are created by web developers. They can all fail in various operation-specific ways, and these failures should be handled by the calling specification.

To **get a reader** for a `ReadableStream` `stream`, return ? AcquireReadableStreamDefaultReader(`stream`). The result will be a `ReadableStreamDefaultReader`.

This will throw an exception if `stream` is already locked.

To **read a chunk** from a `ReadableStreamDefaultReader` `reader`, given a read request `readRequest`, perform ! ReadableStreamDefaultReaderRead(`reader`, `readRequest`).

To **read all bytes** from a `ReadableStreamDefaultReader` `reader`, given `successSteps`, which is an algorithm accepting a byte sequence, and `failureSteps`, which is an algorithm accepting a JavaScript value: read-loop given `reader`, a new byte sequence, `successSteps`, and `failureSteps`.

For the purposes of the above algorithm, to **read-loop** given `reader`, `bytes`, `successSteps`, and `failureSteps`:

1. Let `readRequest` be a new read request with the following items:

   **chunk steps**, given `chunk`

   : 1. If `chunk` is not a `Uint8Array` object, call `failureSteps` with a `TypeError` and abort these steps.

     2. Append the bytes represented by `chunk` to `bytes`.

     3. Read-loop given `reader`, `bytes`, `successSteps`, and `failureSteps`.

        This recursion could potentially cause a stack overflow if implemented directly. Implementations will need to mitigate this, e.g. by using a non-recursive variant of this algorithm, or queuing a microtask, or using a more direct method of byte-reading as noted below.

   **close steps**

   : 1. Call `successSteps` with `bytes`.

   **error steps**, given `e`

   : 1. Call `failureSteps` with `e`.

2. Perform ! ReadableStreamDefaultReaderRead(`reader`, `readRequest`).

Because `reader` grants exclusive access to its corresponding `ReadableStream`, the actual mechanism of how to read cannot be observed. Implementations could use a more direct mechanism if convenient, such as acquiring and using a `ReadableStreamBYOBReader` instead of a `ReadableStreamDefaultReader`, or accessing the chunks directly.

To **release** a `ReadableStreamDefaultReader` `reader`, perform ! ReadableStreamDefaultReaderRelease(`reader`).

To **cancel** a `ReadableStreamDefaultReader` `reader` with `reason`, perform ! ReadableStreamReaderGenericCancel(`reader`, `reason`). The return value will be a promise that either fulfills with undefined, or rejects with a failure reason.

To **cancel** a `ReadableStream` `stream` with `reason`, return ! ReadableStreamCancel(`stream`, `reason`). The return value will be a promise that either fulfills with undefined, or rejects with a failure reason.

To **tee** a `ReadableStream` `stream`, return ? ReadableStreamTee(`stream`, true).

Because we pass true as the second argument to ReadableStreamTee, the second branch returned will have its chunks cloned (using HTML's serializable objects framework) from those of the first branch. This prevents consumption of one of the branches from interfering with the other.


#### Introspection

The following predicates can be used on arbitrary `ReadableStream` objects. However, note that apart from checking whether or not the stream is locked, this direct introspection is not possible via the public JavaScript API, and so specifications should instead use the algorithms in § 9.1.2 Reading. (For example, instead of testing if the stream is readable, attempt to get a reader and handle any exception.)

A `ReadableStream` `stream` is **readable** if `stream`.[[\[state\]]] is "`readable`".

A `ReadableStream` `stream` is **closed** if `stream`.[[\[state\]]] is "`closed`".

A `ReadableStream` `stream` is **errored** if `stream`.[[\[state\]]] is "`errored`".

A `ReadableStream` `stream` is **locked** if ! IsReadableStreamLocked(`stream`) returns true.

A `ReadableStream` `stream` is **disturbed** if `stream`.[[\[disturbed\]]] is true.

This indicates whether the stream has ever been read from or canceled. Even more so than other predicates in this section, it is best consulted sparingly, since this is not information web developers have access to even indirectly. As such, branching platform behavior on it is undesirable.


### Writable streams


#### Creation and manipulation

To **set up** a newly-created-via-Web IDL `WritableStream` object `stream`, given an algorithm **`writeAlgorithm`**, an optional algorithm **`closeAlgorithm`**, an optional algorithm **`abortAlgorithm`**, an optional number **`highWaterMark`** (default 1), an optional algorithm **`sizeAlgorithm`**, perform the following steps. `writeAlgorithm` must be an algorithm that accepts a chunk object and returns a promise. If given, `closeAlgorithm` and `abortAlgorithm` may return a promise. If given, `sizeAlgorithm` must be an algorithm accepting chunk objects and returning a number; and if given, `highWaterMark` must be a non-negative, non-NaN number.

1. Let `startAlgorithm` be an algorithm that returns undefined.

2. Let `closeAlgorithmWrapper` be an algorithm that runs these steps:

   1. Let `result` be the result of running `closeAlgorithm`, if `closeAlgorithm` was given, or null otherwise. If this throws an exception `e`, return a promise rejected with `e`.

   2. If `result` is a `Promise`, then return `result`.

   3. Return a promise resolved with undefined.

3. Let `abortAlgorithmWrapper` be an algorithm that runs these steps given `reason`:

   1. Let `result` be the result of running `abortAlgorithm` given `reason`, if `abortAlgorithm` was given, or null otherwise. If this throws an exception `e`, return a promise rejected with `e`.

   2. If `result` is a `Promise`, then return `result`.

   3. Return a promise resolved with undefined.

4. If `sizeAlgorithm` was not given, then set it to an algorithm that returns 1.

5. Perform ! InitializeWritableStream(`stream`).

6. Let `controller` be a new `WritableStreamDefaultController`.

7. Perform ! SetUpWritableStreamDefaultController(`stream`, `controller`, `startAlgorithm`, `writeAlgorithm`, `closeAlgorithmWrapper`, `abortAlgorithmWrapper`, `highWaterMark`, `sizeAlgorithm`).

Other specifications should be careful when constructing their *`writeAlgorithm`* to avoid in parallel reads from the given chunk, as such reads can violate the run-to-completion semantics of JavaScript. To avoid this, they can make a synchronous copy or transfer of the given value, using operations such as StructuredSerializeWithTransfer, get a copy of the bytes held by the buffer source, or transferring an `ArrayBuffer`. An exception is when the chunk is a `SharedArrayBuffer`, for which it is understood that parallel mutations are a fact of life.

Creating a `WritableStream` from other specifications is thus a two-step process, like so:

1. Let `writableStream` be a new `WritableStream`.

2. Set up `writableStream` given....

Subclasses of `WritableStream` will use the set up operation directly on the this value inside their constructor steps.

The following definitions must only be used on `WritableStream` instances initialized via the above set up algorithm:

To **error** a `WritableStream` `stream` given a JavaScript value `e`, perform ! WritableStreamDefaultControllerErrorIfNeeded(`stream`.[[\[controller\]]], `e`).

The **signal** of a `WritableStream` `stream` is `stream`.[[\[controller\]]].[[\[abortController\]]]'s signal. Specifications can add or remove algorithms to this `AbortSignal`, or consult whether it is aborted and its abort reason.

The usual usage is, after setting up the `WritableStream`, add an algorithm to its signal, which aborts any ongoing write operation to the underlying sink. Then, inside the `writeAlgorithm`, once the underlying sink has responded, check if the signal is aborted, and reject the returned promise with the signal's abort reason if so.


#### Writing

The following algorithms can be used on arbitrary `WritableStream` instances, including ones that are created by web developers. They can all fail in various operation-specific ways, and these failures should be handled by the calling specification.

To **get a writer** for a `WritableStream` `stream`, return ? AcquireWritableStreamDefaultWriter(`stream`). The result will be a `WritableStreamDefaultWriter`.

This will throw an exception if `stream` is already locked.

To **write a chunk** to a `WritableStreamDefaultWriter` `writer`, given a value `chunk`, return ! WritableStreamDefaultWriterWrite(`writer`, `chunk`).

To **release** a `WritableStreamDefaultWriter` `writer`, perform ! WritableStreamDefaultWriterRelease(`writer`).

To **close** a `WritableStream` `stream`, return ! WritableStreamClose(`stream`). The return value will be a promise that either fulfills with undefined, or rejects with a failure reason.

To **abort** a `WritableStream` `stream` with `reason`, return ! WritableStreamAbort(`stream`, `reason`). The return value will be a promise that either fulfills with undefined, or rejects with a failure reason.


### Transform streams


#### Creation and manipulation

To **set up** a newly-created-via-Web IDL `TransformStream` `stream` given an algorithm **`transformAlgorithm`**, an optional algorithm **`flushAlgorithm`**, and an optional algorithm **`cancelAlgorithm`**, perform the following steps. `transformAlgorithm` and, if given, `flushAlgorithm` and `cancelAlgorithm`, may return a promise.

1. Let `writableHighWaterMark` be 1.

2. Let `writableSizeAlgorithm` be an algorithm that returns 1.

3. Let `readableHighWaterMark` be 0.

4. Let `readableSizeAlgorithm` be an algorithm that returns 1.

5. Let `transformAlgorithmWrapper` be an algorithm that runs these steps given a value `chunk`:

   1. Let `result` be the result of running `transformAlgorithm` given `chunk`. If this throws an exception `e`, return a promise rejected with `e`.

   2. If `result` is a `Promise`, then return `result`.

   3. Return a promise resolved with undefined.

6. Let `flushAlgorithmWrapper` be an algorithm that runs these steps:

   1. Let `result` be the result of running `flushAlgorithm`, if `flushAlgorithm` was given, or null otherwise. If this throws an exception `e`, return a promise rejected with `e`.

   2. If `result` is a `Promise`, then return `result`.

   3. Return a promise resolved with undefined.

7. Let `cancelAlgorithmWrapper` be an algorithm that runs these steps given a value `reason`:

   1. Let `result` be the result of running `cancelAlgorithm` given `reason`, if `cancelAlgorithm` was given, or null otherwise. If this throws an exception `e`, return a promise rejected with `e`.

   2. If `result` is a `Promise`, then return `result`.

   3. Return a promise resolved with undefined.

8. Let `startPromise` be a promise resolved with undefined.

9. Perform ! InitializeTransformStream(`stream`, `startPromise`, `writableHighWaterMark`, `writableSizeAlgorithm`, `readableHighWaterMark`, `readableSizeAlgorithm`).

10. Let `controller` be a new `TransformStreamDefaultController`.

11. Perform ! SetUpTransformStreamDefaultController(`stream`, `controller`, `transformAlgorithmWrapper`, `flushAlgorithmWrapper`, `cancelAlgorithmWrapper`).

Other specifications should be careful when constructing their *`transformAlgorithm`* to avoid in parallel reads from the given chunk, as such reads can violate the run-to-completion semantics of JavaScript. To avoid this, they can make a synchronous copy or transfer of the given value, using operations such as StructuredSerializeWithTransfer, get a copy of the bytes held by the buffer source, or transferring an `ArrayBuffer`. An exception is when the chunk is a `SharedArrayBuffer`, for which it is understood that parallel mutations are a fact of life.

Creating a `TransformStream` from other specifications is thus a two-step process, like so:

1. Let `transformStream` be a new `TransformStream`.

2. Set up `transformStream` given....

Subclasses of `TransformStream` will use the set up operation directly on the this value inside their constructor steps.

To **create an identity `TransformStream`**:

1. Let `transformStream` be a new `TransformStream`.

2. Set up `transformStream` with `transformAlgorithm` set to an algorithm which, given `chunk`, enqueues `chunk` in `transformStream`.

3. Return `transformStream`.

The following algorithms must only be used on `TransformStream` instances initialized via the above set up algorithm. Usually they are called as part of `transformAlgorithm` or `flushAlgorithm`.

To **enqueue** the JavaScript value `chunk` into a `TransformStream` `stream`, perform ! TransformStreamDefaultControllerEnqueue(`stream`.[[\[controller\]]], `chunk`).

To **terminate** a `TransformStream` `stream`, perform ! TransformStreamDefaultControllerTerminate(`stream`.[[\[controller\]]]).

To **error** a `TransformStream` `stream` given a JavaScript value `e`, perform ! TransformStreamDefaultControllerError(`stream`.[[\[controller\]]], `e`).


#### Wrapping into a custom class

Other specifications which mean to define custom transform streams might not want to subclass from the `TransformStream` interface directly. Instead, if they need a new class, they can create their own independent Web IDL interfaces, and use the following mixin:

```idl
interface mixin GenericTransformStream {
  readonly attribute ReadableStream readable;
  readonly attribute WritableStream writable;
};
```

Any platform object that includes the `GenericTransformStream` mixin has an associated **transform**, which is an actual `TransformStream`.

The `readable` getter steps are to return this's transform.[[\[readable\]]].

The `writable` getter steps are to return this's transform.[[\[writable\]]].

Including the `GenericTransformStream` mixin will give an IDL interface the appropriate `readable` and `writable` properties. To customize the behavior of the resulting interface, its constructor (or other initialization code) must set each instance's transform to a new `TransformStream`, and then set it up with appropriate customizations via the `transformAlgorithm` and optionally `flushAlgorithm` arguments.

**Note:** Existing examples of this pattern on the web platform include `CompressionStream` and `TextDecoderStream`. [COMPRESSION] [ENCODING]

There's no need to create a wrapper class if you don't need any API beyond what the base `TransformStream` class provides. The most common driver for such a wrapper is needing custom constructor steps, but if your conceptual transform stream isn't meant to be constructed, then using `TransformStream` directly is fine.


### Other stream pairs

Apart from transform streams, discussed above, specifications often create pairs of readable and writable streams. This section gives some guidance for such situations.

In all such cases, specifications should use the names `readable` and `writable` for the two properties exposing the streams in question. They should not use other names (such as `input`/`output` or `readableStream`/`writableStream`), and they should not use methods or other non-property means of access to the streams.


#### Duplex streams

The most common readable/writable pair is a **duplex stream**, where the readable and writable streams represent two sides of a single shared resource, such as a socket, connection, or device.

The trickiest thing to consider when specifying duplex streams is how to handle operations like canceling the readable side, or closing or aborting the writable side. It might make sense to leave duplex streams "half open", with such operations one one side not impacting the other side. Or it might be best to carry over their effects to the other side, e.g. by specifying that your readable side's `cancelAlgorithm` will close the writable side.

A basic example of a duplex stream, created through JavaScript instead of through specification prose, is found in § 10.8 A { readable, writable } stream pair wrapping the same underlying resource. It illustrates this carry-over behavior.

Another consideration is how to handle the creation of duplex streams which need to be acquired asynchronously, e.g. via establishing a connection. The preferred pattern here is to have a constructible class with a promise-returning property that fulfills with the actual duplex stream object. That duplex stream object can also then expose any information that is only available asynchronously, e.g. connection data. The container class can then provide convenience APIs, such as a function to close the entire connection instead of only closing individual sides.

An example of this more complex type of duplex stream is the still-being-specified `WebSocketStream`. See its [explainer](https://github.com/ricea/websocketstream-explainer/blob/master/README.md) and [design notes](https://docs.google.com/document/d/1La1ehXw76HP6n1uUeks-WJGFgAnpX2tCjKts7QFJ57Y/edit#).

Because duplex streams obey the `readable`/`writable` property contract, they can be used with `pipeThrough()`. This doesn't always make sense, but it could in cases where the underlying resource is in fact performing some sort of transformation.

For an arbitrary WebSocket, piping through a WebSocket-derived duplex stream doesn't make sense. However, if the WebSocket server is specifically written so that it responds to incoming messages by sending the same data back in some transformed form, then this could be useful and convenient.


#### Endpoint pairs

Another type of readable/writable pair is an **endpoint pair**. In these cases the readable and writable streams represent the two ends of a longer pipeline, with the intention that web developer code insert transform streams into the middle of them.

Assuming we had a web-platform-provided function `createEndpointPair()`, web developers would write code like so:

```
const { readable, writable } = createEndpointPair();
await readable.pipeThrough(new TransformStream(...)).pipeTo(writable);
```

WebRTC Encoded Transform is an example of this technique, with its `RTCRtpScriptTransformer` interface which has both `readable` and `writable` attributes.

Despite such endpoint pairs obeying the `readable`/`writable` property contract, it never makes sense to pass them to `pipeThrough()`.


### Piping

The result of a `ReadableStream` `readable` **piped to** a `WritableStream` `writable`, given an optional boolean **`preventClose`** (default false), an optional boolean **`preventAbort`** (default false), an optional boolean **`preventCancel`** (default false), and an optional `AbortSignal` **`signal`**, is given by performing the following steps. They will return a `Promise` that fulfills when the pipe completes, or rejects with an exception if it fails.

1. Assert: ! IsReadableStreamLocked(`readable`) is false.

2. Assert: ! IsWritableStreamLocked(`writable`) is false.

3. Let `signalArg` be `signal` if `signal` was given, or undefined otherwise.

4. Return ! ReadableStreamPipeTo(`readable`, `writable`, `preventClose`, `preventAbort`, `preventCancel`, `signalArg`).

If one doesn't care about the promise returned, referencing this concept can be a bit awkward. The best we can suggest is "pipe `readable` to `writable`".

The result of a `ReadableStream` `readable` **piped through** a `TransformStream` `transform`, given an optional boolean **`preventClose`** (default false), an optional boolean **`preventAbort`** (default false), an optional boolean **`preventCancel`** (default false), and an optional `AbortSignal` **`signal`**, is given by performing the following steps. The result will be the readable side of `transform`.

1. Assert: ! IsReadableStreamLocked(`readable`) is false.

2. Assert: ! IsWritableStreamLocked(`transform`.[[\[writable\]]]) is false.

3. Let `signalArg` be `signal` if `signal` was given, or undefined otherwise.

4. Let `promise` be ! ReadableStreamPipeTo(`readable`, `transform`.[[\[writable\]]], `preventClose`, `preventAbort`, `preventCancel`, `signalArg`).

5. Set `promise`.\[\[PromiseIsHandled\]\] to true.

6. Return `transform`.[[\[readable\]]].

To **create a proxy** for a `ReadableStream` `stream`, perform the following steps. The result will be a new `ReadableStream` object which pulls its data from `stream`, while `stream` itself becomes immediately locked and disturbed.

1. Let `identityTransform` be the result of creating an identity `TransformStream`.

2. Return the result of `stream` piped through `identityTransform`.


## Examples of creating streams

*This section, and all its subsections, are non-normative.*

The previous examples throughout the standard have focused on how to use streams. Here we show how to create a stream, using the `ReadableStream`, `WritableStream`, and `TransformStream` constructors.


### A readable stream with an underlying push source (no backpressure support)

The following function creates readable streams that wrap `WebSocket` instances, which are push sources that do not support backpressure signals. It illustrates how, when adapting a push source, usually most of the work happens in the `start()` method.

``` highlight
function makeReadableWebSocketStream(url, protocols) {
  const ws = new WebSocket(url, protocols);
  ws.binaryType = "arraybuffer";

  return new ReadableStream({
    start(controller) {
      ws.onmessage = event => controller.enqueue(event.data);
      ws.onclose = () => controller.close();
      ws.onerror = () => controller.error(new Error("The WebSocket errored!"));
    },

    cancel() {
      ws.close();
    }
  });
}
```

We can then use this function to create readable streams for a web socket, and pipe that stream to an arbitrary writable stream:

``` highlight
const webSocketStream = makeReadableWebSocketStream("wss://example.com:443/", "protocol");

webSocketStream.pipeTo(writableStream)
  .then(() => console.log("All data successfully written!"))
  .catch(e => console.error("Something went wrong!", e));
```

Note: This specific style of wrapping a web socket interprets web socket messages directly as chunks. This can be a convenient abstraction, for example when piping to a writable stream or transform stream for which each web socket message makes sense as a chunk to consume or transform.

However, often when people talk about "adding streams support to web sockets", they are hoping instead for a new capability to send an individual web socket message in a streaming fashion, so that e.g. a file could be transferred in a single message without holding all of its contents in memory on the client side. To accomplish this goal, we'd instead want to allow individual web socket messages to themselves be `ReadableStream` instances. That isn't what we show in the above example.

For more background, see [this discussion](https://github.com/w3c/webrtc-pc/issues/1732#issuecomment-358428651).


### A readable stream with an underlying push source and backpressure support

The following function returns readable streams that wrap "backpressure sockets," which are hypothetical objects that have the same API as web sockets, but also provide the ability to pause and resume the flow of data with their `readStop` and `readStart` methods. In doing so, this example shows how to apply backpressure to underlying sources that support it.

``` highlight
function makeReadableBackpressureSocketStream(host, port) {
  const socket = createBackpressureSocket(host, port);

  return new ReadableStream({
    start(controller) {
      socket.ondata = event => {
        controller.enqueue(event.data);

        if (controller.desiredSize <= 0) {
          // The internal queue is full, so propagate
          // the backpressure signal to the underlying source.
          socket.readStop();
        }
      };

      socket.onend = () => controller.close();
      socket.onerror = () => controller.error(new Error("The socket errored!"));
    },

    pull() {
      // This is called if the internal queue has been emptied, but the
      // stream's consumer still wants more data. In that case, restart
      // the flow of data if we have previously paused it.
      socket.readStart();
    },

    cancel() {
      socket.close();
    }
  });
}
```

We can then use this function to create readable streams for such "backpressure sockets" in the same way we do for web sockets. This time, however, when we pipe to a destination that cannot accept data as fast as the socket is producing it, or if we leave the stream alone without reading from it for some time, a backpressure signal will be sent to the socket.


### A readable byte stream with an underlying push source (no backpressure support)

The following function returns readable byte streams that wraps a hypothetical UDP socket API, including a promise-returning `select2()` method that is meant to be evocative of the POSIX select(2) system call.

Since the UDP protocol does not have any built-in backpressure support, the backpressure signal given by `desiredSize` is ignored, and the stream ensures that when data is available from the socket but not yet requested by the developer, it is enqueued in the stream's internal queue, to avoid overflow of the kernel-space queue and a consequent loss of data.

This has some interesting consequences for how consumers interact with the stream. If the consumer does not read data as fast as the socket produces it, the chunks will remain in the stream's internal queue indefinitely. In this case, using a BYOB reader will cause an extra copy, to move the data from the stream's internal queue to the developer-supplied buffer. However, if the consumer consumes the data quickly enough, a BYOB reader will allow zero-copy reading directly into developer-supplied buffers.

(You can imagine a more complex version of this example which uses `desiredSize` to inform an out-of-band backpressure signaling mechanism, for example by sending a message down the socket to adjust the rate of data being sent. That is left as an exercise for the reader.)

``` highlight
const DEFAULT_CHUNK_SIZE = 65536;

function makeUDPSocketStream(host, port) {
  const socket = createUDPSocket(host, port);

  return new ReadableStream({
    type: "bytes",

    start(controller) {
      readRepeatedly().catch(e => controller.error(e));

      function readRepeatedly() {
        return socket.select2().then(() => {
          // Since the socket can become readable even when there's
          // no pending BYOB requests, we need to handle both cases.
          let bytesRead;
          if (controller.byobRequest) {
            const v = controller.byobRequest.view;
            bytesRead = socket.readInto(v.buffer, v.byteOffset, v.byteLength);
            if (bytesRead === 0) {
              controller.close();
            }
            controller.byobRequest.respond(bytesRead);
          } else {
            const buffer = new ArrayBuffer(DEFAULT_CHUNK_SIZE);
            bytesRead = socket.readInto(buffer, 0, DEFAULT_CHUNK_SIZE);
            if (bytesRead === 0) {
              controller.close();
            } else {
              controller.enqueue(new Uint8Array(buffer, 0, bytesRead));
            }
          }

          if (bytesRead === 0) {
            return;
          }

          return readRepeatedly();
        });
      }
    },

    cancel() {
      socket.close();
    }
  });
}
```

`ReadableStream` instances returned from this function can now vend BYOB readers, with all of the aforementioned benefits and caveats.


### A readable stream with an underlying pull source

The following function returns readable streams that wrap portions of the [Node.js file system API](https://nodejs.org/api/fs.html) (which themselves map fairly directly to C's `fopen`, `fread`, and `fclose` trio). Files are a typical example of pull sources. Note how in contrast to the examples with push sources, most of the work here happens on-demand in the `pull()` function, and not at startup time in the `start()` function.

``` highlight
const fs = require("fs").promises;
const CHUNK_SIZE = 1024;

function makeReadableFileStream(filename) {
  let fileHandle;
  let position = 0;

  return new ReadableStream({
    async start() {
      fileHandle = await fs.open(filename, "r");
    },

    async pull(controller) {
      const buffer = new Uint8Array(CHUNK_SIZE);

      const { bytesRead } = await fileHandle.read(buffer, 0, CHUNK_SIZE, position);
      if (bytesRead === 0) {
        await fileHandle.close();
        controller.close();
      } else {
        position += bytesRead;
        controller.enqueue(buffer.subarray(0, bytesRead));
      }
    },

    cancel() {
      return fileHandle.close();
    }
  });
}
```

We can then create and use readable streams for files just as we could before for sockets.


### A readable byte stream with an underlying pull source

The following function returns readable byte streams that allow efficient zero-copy reading of files, again using the [Node.js file system API](https://nodejs.org/api/fs.html). Instead of using a predetermined chunk size of 1024, it attempts to fill the developer-supplied buffer, allowing full control.

``` highlight
const fs = require("fs").promises;
const DEFAULT_CHUNK_SIZE = 1024;

function makeReadableByteFileStream(filename) {
 let fileHandle;
 let position = 0;

  return new ReadableStream({
    type: "bytes",

    async start() {
      fileHandle = await fs.open(filename, "r");
    },

    async pull(controller) {
      // Even when the consumer is using the default reader, the auto-allocation
      // feature allocates a buffer and passes it to us via byobRequest.
      const v = controller.byobRequest.view;

      const { bytesRead } = await fileHandle.read(v, 0, v.byteLength, position);
      if (bytesRead === 0) {
        await fileHandle.close();
        controller.close();
        controller.byobRequest.respond(0);
      } else {
        position += bytesRead;
        controller.byobRequest.respond(bytesRead);
      }
    },

    cancel() {
      return fileHandle.close();
    },

    autoAllocateChunkSize: DEFAULT_CHUNK_SIZE
  });
}
```

With this in hand, we can create and use BYOB readers for the returned `ReadableStream`. But we can also create default readers, using them in the same simple and generic manner as usual. The adaptation between the low-level byte tracking of the underlying byte source shown here, and the higher-level chunk-based consumption of a default reader, is all taken care of automatically by the streams implementation. The auto-allocation feature, via the `autoAllocateChunkSize` option, even allows us to write less code, compared to the manual branching in § A readable byte stream with an underlying push source (no backpressure support).


### A writable stream with no backpressure or success signals

The following function returns a writable stream that wraps a `WebSocket`. Web sockets do not provide any way to tell when a given chunk of data has been successfully sent (without awkward polling of `bufferedAmount`, which we leave as an exercise to the reader). As such, this writable stream has no ability to communicate accurate backpressure signals or write success/failure to its producers. That is, the promises returned by its writer's `write()` method and `ready` getter will always fulfill immediately.

``` highlight
function makeWritableWebSocketStream(url, protocols) {
  const ws = new WebSocket(url, protocols);

  return new WritableStream({
    start(controller) {
      ws.onerror = () => {
        controller.error(new Error("The WebSocket errored!"));
        ws.onclose = null;
      };
      ws.onclose = () => controller.error(new Error("The server closed the connection unexpectedly!"));
      return new Promise(resolve => ws.onopen = resolve);
    },

    write(chunk) {
      ws.send(chunk);
      // Return immediately, since the web socket gives us no easy way to tell
      // when the write completes.
    },

    close() {
      return closeWS(1000);
    },

    abort(reason) {
      return closeWS(4000, reason && reason.message);
    },
  });

  function closeWS(code, reasonString) {
    return new Promise((resolve, reject) => {
      ws.onclose = e => {
        if (e.wasClean) {
          resolve();
        } else {
          reject(new Error("The connection was not closed cleanly"));
        }
      };
      ws.close(code, reasonString);
    });
  }
}
```

We can then use this function to create writable streams for a web socket, and pipe an arbitrary readable stream to it:

``` highlight
const webSocketStream = makeWritableWebSocketStream("wss://example.com:443/", "protocol");

readableStream.pipeTo(webSocketStream)
  .then(() => console.log("All data successfully written!"))
  .catch(e => console.error("Something went wrong!", e));
```

See the earlier note about this style of wrapping web sockets into streams.


### A writable stream with backpressure and success signals

The following function returns writable streams that wrap portions of the [Node.js file system API](https://nodejs.org/api/fs.html) (which themselves map fairly directly to C's `fopen`, `fwrite`, and `fclose` trio). Since the API we are wrapping provides a way to tell when a given write succeeds, this stream will be able to communicate backpressure signals as well as whether an individual write succeeded or failed.

``` highlight
const fs = require("fs").promises;

function makeWritableFileStream(filename) {
  let fileHandle;

  return new WritableStream({
    async start() {
      fileHandle = await fs.open(filename, "w");
    },

    write(chunk) {
      return fileHandle.write(chunk, 0, chunk.length);
    },

    close() {
      return fileHandle.close();
    },

    abort() {
      return fileHandle.close();
    }
  });
}
```

We can then use this function to create a writable stream for a file, and write individual chunks of data to it:

``` highlight
const fileStream = makeWritableFileStream("/example/path/on/fs.txt");
const writer = fileStream.getWriter();

writer.write("To stream, or not to stream\n");
writer.write("That is the question\n");

writer.close()
  .then(() => console.log("chunks written and stream closed successfully!"))
  .catch(e => console.error(e));
```

Note that if a particular call to `fileHandle.write` takes a longer time, the returned promise will fulfill later. In the meantime, additional writes can be queued up, which are stored in the stream's internal queue. The accumulation of chunks in this queue can change the stream to return a pending promise from the `ready` getter, which is a signal to producers that they would benefit from backing off and stopping writing, if possible.

The way in which the writable stream queues up writes is especially important in this case, since as stated in [the documentation for `fileHandle.write`](https://nodejs.org/api/fs.html#fs_filehandle_write_buffer_offset_length_position), "it is unsafe to use `filehandle.write` multiple times on the same file without waiting for the promise." But we don't have to worry about that when writing the `makeWritableFileStream` function, since the stream implementation guarantees that the underlying sink's `write()` method will not be called until any promises returned by previous calls have fulfilled!


### A { readable, writable } stream pair wrapping the same underlying resource

The following function returns an object of the form `{ readable, writable }`, with the `readable` property containing a readable stream and the `writable` property containing a writable stream, where both streams wrap the same underlying web socket resource. In essence, this combines § A readable stream with an underlying push source (no backpressure support) and § A writable stream with no backpressure or success signals.

While doing so, it illustrates how you can use JavaScript classes to create reusable underlying sink and underlying source abstractions.

``` highlight
function streamifyWebSocket(url, protocol) {
  const ws = new WebSocket(url, protocols);
  ws.binaryType = "arraybuffer";

  return {
    readable: new ReadableStream(new WebSocketSource(ws)),
    writable: new WritableStream(new WebSocketSink(ws))
  };
}

class WebSocketSource {
  constructor(ws) {
    this._ws = ws;
  }

  start(controller) {
    this._ws.onmessage = event => controller.enqueue(event.data);
    this._ws.onclose = () => controller.close();

    this._ws.addEventListener("error", () => {
      controller.error(new Error("The WebSocket errored!"));
    });
  }

  cancel() {
    this._ws.close();
  }
}

class WebSocketSink {
  constructor(ws) {
    this._ws = ws;
  }

  start(controller) {
    this._ws.onclose = () => controller.error(new Error("The server closed the connection unexpectedly!"));
    this._ws.addEventListener("error", () => {
      controller.error(new Error("The WebSocket errored!"));
      this._ws.onclose = null;
    });

    return new Promise(resolve => this._ws.onopen = resolve);
  }

  write(chunk) {
    this._ws.send(chunk);
  }

  close() {
    return this._closeWS(1000);
  }

  abort(reason) {
    return this._closeWS(4000, reason && reason.message);
  }

  _closeWS(code, reasonString) {
    return new Promise((resolve, reject) => {
      this._ws.onclose = e => {
        if (e.wasClean) {
          resolve();
        } else {
          reject(new Error("The connection was not closed cleanly"));
        }
      };
      this._ws.close(code, reasonString);
    });
  }
}
```

We can then use the objects created by this function to communicate with a remote web socket, using the standard stream APIs:

``` highlight
const streamyWS = streamifyWebSocket("wss://example.com:443/", "protocol");
const writer = streamyWS.writable.getWriter();
const reader = streamyWS.readable.getReader();

writer.write("Hello");
writer.write("web socket!");

reader.read().then(({ value, done }) => {
  console.log("The web socket says: ", value);
});
```

Note how in this setup canceling the `readable` side will implicitly close the `writable` side, and similarly, closing or aborting the `writable` side will implicitly close the `readable` side.

See the earlier note about this style of wrapping web sockets into streams.


### A transform stream that replaces template tags

It's often useful to substitute tags with variables on a stream of data, where the parts that need to be replaced are small compared to the overall data size. This example presents a simple way to do that. It maps strings to strings, transforming a template like `"Time: {{time}} Message: {{message}}"` to `"Time: 15:36 Message: hello"` assuming that `{ time: "15:36", message: "hello" }` was passed in the `substitutions` parameter to `LipFuzzTransformer`.

This example also demonstrates one way to deal with a situation where a chunk contains partial data that cannot be transformed until more data is received. In this case, a partial template tag will be accumulated in the `partialChunk` property until either the end of the tag is found or the end of the stream is reached.

``` highlight
class LipFuzzTransformer {
  constructor(substitutions) {
    this.substitutions = substitutions;
    this.partialChunk = "";
    this.lastIndex = undefined;
  }

  transform(chunk, controller) {
    chunk = this.partialChunk + chunk;
    this.partialChunk = "";
    // lastIndex is the index of the first character after the last substitution.
    this.lastIndex = 0;
    chunk = chunk.replace(/\{\{([a-zA-Z0-9_-]+)\}\}/g, this.replaceTag.bind(this));
    // Regular expression for an incomplete template at the end of a string.
    const partialAtEndRegexp = /\{(\{([a-zA-Z0-9_-]+(\})?)?)?$/g;
    // Avoid looking at any characters that have already been substituted.
    partialAtEndRegexp.lastIndex = this.lastIndex;
    this.lastIndex = undefined;
    const match = partialAtEndRegexp.exec(chunk);
    if (match) {
      this.partialChunk = chunk.substring(match.index);
      chunk = chunk.substring(0, match.index);
    }
    controller.enqueue(chunk);
  }

  flush(controller) {
    if (this.partialChunk.length > 0) {
      controller.enqueue(this.partialChunk);
    }
  }

  replaceTag(match, p1, offset) {
    let replacement = this.substitutions[p1];
    if (replacement === undefined) {
      replacement = "";
    }
    this.lastIndex = offset + replacement.length;
    return replacement;
  }
}
```

In this case we define the transformer to be passed to the `TransformStream` constructor as a class. This is useful when there is instance data to track.

The class would be used in code like:

``` highlight
const data = { userName, displayName, icon, date };
const ts = new TransformStream(new LipFuzzTransformer(data));

fetchEvent.respondWith(
  fetch(fetchEvent.request.url).then(response => {
    const transformedBody = response.body
      // Decode the binary-encoded response to string
      .pipeThrough(new TextDecoderStream())
      // Apply the LipFuzzTransformer
      .pipeThrough(ts)
      // Encode the transformed string
      .pipeThrough(new TextEncoderStream());
    return new Response(transformedBody);
  })
);
```

For simplicity, `LipFuzzTransformer` performs unescaped text substitutions. In real applications, a template system that performs context-aware escaping is good practice for security and robustness.


### A transform stream created from a sync mapper function

The following function allows creating new `TransformStream` instances from synchronous "mapper" functions, of the type you would normally pass to `Array.prototype.map`. It demonstrates that the API is concise even for trivial transforms.

``` highlight
function mapperTransformStream(mapperFunction) {
  return new TransformStream({
    transform(chunk, controller) {
      controller.enqueue(mapperFunction(chunk));
    }
  });
}
```

This function can then be used to create a `TransformStream` that uppercases all its inputs:

``` highlight
const ts = mapperTransformStream(chunk => chunk.toUpperCase());
const writer = ts.writable.getWriter();
const reader = ts.readable.getReader();

writer.write("No need to shout");

// Logs "NO NEED TO SHOUT":
reader.read().then(({ value }) => console.log(value));
```

Although a synchronous transform never causes backpressure itself, it will only transform chunks as long as there is no backpressure, so resources will not be wasted.

Exceptions error the stream in a natural way:

``` highlight
const ts = mapperTransformStream(chunk => JSON.parse(chunk));
const writer = ts.writable.getWriter();
const reader = ts.readable.getReader();

writer.write("[1, ");

// Logs a SyntaxError, twice:
reader.read().catch(e => console.error(e));
writer.write("{}").catch(e => console.error(e));
```


### Using an identity transform stream as a primitive to create new readable streams

Combining an identity transform stream with `pipeTo()` is a powerful way to manipulate streams. This section contains a couple of examples of this general technique.

It's sometimes natural to treat a promise for a readable stream as if it were a readable stream. A simple adapter function is all that's needed:

``` highlight
function promiseToReadable(promiseForReadable) {
  const ts = new TransformStream();

  promiseForReadable
      .then(readable => readable.pipeTo(ts.writable))
      .catch(reason => ts.writable.abort(reason))
      .catch(() => {});

  return ts.readable;
}
```

Here, we pipe the data to the writable side and return the readable side. If the pipe errors, we abort the writable side, which automatically propagates the error to the returned readable side. If the writable side had already been errored by `pipeTo()`, then the `abort()` call will return a rejection, which we can safely ignore.

A more complex extension of this is concatenating multiple readable streams into one:

``` highlight
function concatenateReadables(readables) {
  const ts = new TransformStream();
  let promise = Promise.resolve();

  for (const readable of readables) {
    promise = promise.then(
     () => readable.pipeTo(ts.writable, { preventClose: true }),
     reason => {
       return Promise.all([
         ts.writable.abort(reason),
         readable.cancel(reason)
       ]);
     }
   );
  }

  promise.then(() => ts.writable.close(),
               reason => ts.writable.abort(reason))
         .catch(() => {});

  return ts.readable;
}
```

The error handling here is subtle because canceling the concatenated stream has to cancel all the input streams. However, the success case is simple enough. We just pipe each stream in the `readables` iterable one at a time to the identity transform stream's writable side, and then close it when we are done. The readable side is then a concatenation of all the chunks from all of of the streams. We return it from the function. Backpressure is applied as usual.