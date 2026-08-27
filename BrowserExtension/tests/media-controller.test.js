import assert from "node:assert/strict";
import test from "node:test";
import { MediaController } from "../shared/media-controller.js";
import { FakeMedia, FakeRoot, observerHarness } from "./fakes.js";

function setup(media = []) {
  const messages = [];
  const ids = ["document", "session-1", "session-2", "session-3"];
  const observer = observerHarness();
  const controller = new MediaController({
    document: new FakeRoot(media),
    createObserver: observer.createObserver,
    createId: () => ids.shift(),
    send: (message) => messages.push(message),
  });
  controller.start();
  return { controller, messages, observer };
}

test("discovers existing and dynamically added media and tracks events", () => {
  const first = new FakeMedia();
  const { messages, observer } = setup([first]);
  const second = new FakeMedia({ paused: false });
  observer.mutate({ addedNodes: [new FakeRoot([second])], removedNodes: [] });
  for (const event of ["play", "playing", "pause", "timeupdate", "seeking", "ended"]) {
    first.emit(event);
  }

  assert.deepEqual(messages.map(({ sessionId, event }) => [sessionId, event]), [
    ["session-1", "discovered"],
    ["session-2", "discovered"],
    ["session-1", "play"],
    ["session-1", "playing"],
    ["session-1", "pause"],
    ["session-1", "timeupdate"],
    ["session-1", "seeking"],
    ["session-1", "ended"],
  ]);
  assert.ok(messages.every((message) => !("url" in message) && !("title" in message)));
});

test("tracks multiple media independently and reports removal", () => {
  const first = new FakeMedia();
  const second = new FakeMedia();
  const { messages, observer } = setup([first, second]);
  first.isConnected = false;
  observer.mutate({ addedNodes: [], removedNodes: [first] });
  second.emit("play");

  assert.equal(messages.at(-2).event, "removed");
  assert.equal(messages.at(-2).sessionId, "session-1");
  assert.equal(messages.at(-1).sessionId, "session-2");
});

test("removed or replaced media cannot be resumed by its old session", async () => {
  const removed = new FakeMedia({ currentTime: 12 });
  const { controller, observer } = setup([removed]);
  removed.isConnected = false;
  observer.mutate({ addedNodes: [new FakeMedia()], removedNodes: [removed] });

  const result = await controller.resume({
    documentId: "document", sessionId: "session-1", rewindSeconds: 5,
  });
  assert.equal(result.status, "session-not-found");
  assert.equal(removed.currentTime, 12);
});

test("rejects document and session identity mismatches", async () => {
  const { controller } = setup([new FakeMedia()]);
  assert.equal((await controller.resume({ documentId: "old", sessionId: "session-1", rewindSeconds: 5 })).status, "document-changed");
  assert.equal((await controller.resume({ documentId: "document", sessionId: "missing", rewindSeconds: 5 })).status, "session-not-found");
});

test("clamps rewind at zero and resumes exact media", async () => {
  const media = new FakeMedia({ currentTime: 3 });
  const { controller } = setup([media]);
  const result = await controller.resume({ documentId: "document", sessionId: "session-1", rewindSeconds: 5 });
  assert.equal(media.currentTime, 0);
  assert.equal(result.status, "resumed");
});

test("reports ended and rejected playback", async () => {
  const ended = new FakeMedia({ ended: true });
  const rejected = new FakeMedia({ currentTime: 10, playError: new Error("denied") });
  const { controller } = setup([ended, rejected]);
  assert.equal((await controller.resume({ documentId: "document", sessionId: "session-1", rewindSeconds: 2 })).status, "media-ended");
  assert.equal((await controller.resume({ documentId: "document", sessionId: "session-2", rewindSeconds: 2 })).status, "play-rejected");
});

test("reports seek failure without attempting playback", async () => {
  const media = new FakeMedia({ currentTime: 10, seekError: new Error("not seekable") });
  const { controller } = setup([media]);
  const result = await controller.resume({
    documentId: "document", sessionId: "session-1", rewindSeconds: 2,
  });
  assert.equal(result.status, "seek-failed");
  assert.equal(media.paused, true);
});