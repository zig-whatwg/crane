'use strict';

// Node's worker_threads in the browser page: the browser's own MessageChannel, MessagePort and
// BroadcastChannel (internal-test-utils/enqueueTask uses Node's MessageChannel for a real task);
// the page is the main thread and starts no workers.

const {native} = __reactJestPage;

module.exports = {
  MessageChannel: native.MessageChannel,
  MessagePort: native.MessagePort,
  BroadcastChannel: native.BroadcastChannel,
  isMainThread: true,
  parentPort: null,
  threadId: 0,
  workerData: null,
  resourceLimits: {},
  SHARE_ENV: Symbol('nodejs.worker_threads.SHARE_ENV'),
  Worker: class Worker {
    constructor() {
      throw new Error('worker_threads.Worker is not available in the browser page');
    }
  },
  markAsUntransferable() {},
  receiveMessageOnPort() {
    throw new Error('worker_threads.receiveMessageOnPort is not available in the browser page');
  },
};
