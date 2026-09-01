import assert from "node:assert/strict";
import test from "node:test";
import { BackgroundRouter } from "../shared/background-router.js";
import { eventHook, fakePort } from "./fakes.js";

function setup({ ports = [fakePort()], sendMessage = async () => ({}) } = {}) {
  const scheduled = [];
  const runtime = {
    onMessage: eventHook(),
    connectNative: () => {
      const next = ports.shift();
      if (next instanceof Error) throw next;
      return next;
    },
  };
  const tabs = { calls: [], async sendMessage(...arguments_) {
    this.calls.push(arguments_);
    return sendMessage(...arguments_);
  } };
  const router = new BackgroundRouter({
    runtime,
    tabs,
    hostName: "native.host",
    browser: "chrome",
    schedule: (callback, delay) => scheduled.push({ callback, delay }),
    reconnectDelays: [10, 20],
  });
  router.start();
  return { runtime, tabs, scheduled };
}

test("adds tab and frame identity to media state", () => {
  const port = fakePort();
  const { runtime } = setup({ ports: [port] });
  const connectionId = port.messages[0].connectionId;
  runtime.onMessage.emit(
    { type: "media-state", documentId: "doc", sessionId: "media" },
    { tab: { id: 7 }, frameId: 3 },
  );
  assert.deepEqual(port.messages[1], {
    version: 1,
    type: "media-state",
    documentId: "doc",
    sessionId: "media",
    browser: "chrome",
    connectionId,
    tabId: 7,
    frameId: 3,
  });
});

test("routes resume to the exact tab and frame and forwards result", async () => {
  const port = fakePort();
  const { tabs } = setup({ ports: [port], sendMessage: async () => ({
    type: "resume-result", documentId: "doc", sessionId: "media", status: "resumed",
  }) });
  const command = {
    version: 1, type: "resume-media", browser: "chrome",
    connectionId: port.messages[0].connectionId,
    tabId: 7, frameId: 3, documentId: "doc", sessionId: "media", rewindSeconds: 5,
  };
  await port.onMessage.emit(command)[0];
  assert.deepEqual(tabs.calls[0], [7, command, { frameId: 3 }]);
  assert.equal(port.messages.at(-1).status, "resumed");
  assert.equal(port.messages.at(-1).frameId, 3);
});

test("rejects stale connection identity without messaging a tab", async () => {
  const port = fakePort();
  const { tabs } = setup({ ports: [port] });
  await port.onMessage.emit({
    version: 1, type: "resume-media", browser: "chrome", connectionId: "stale",
    tabId: 7, frameId: 0, documentId: "doc", sessionId: "media",
  })[0];
  assert.equal(tabs.calls.length, 0);
  assert.equal(port.messages.at(-1).status, "session-not-found");
});

test("reconnects with bounded exponential delays", () => {
  const connected = fakePort();
  const { scheduled } = setup({ ports: [new Error("missing"), new Error("missing"), connected] });
  assert.equal(scheduled[0].delay, 10);
  scheduled.shift().callback();
  assert.equal(scheduled[0].delay, 20);
  scheduled.shift().callback();
  connected.onMessage.emit({ version: 1, type: "connected-result" });
  connected.onDisconnect.emit();
  assert.equal(scheduled[0].delay, 10);
});