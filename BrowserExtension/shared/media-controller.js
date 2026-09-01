const MEDIA_EVENTS = ["play", "playing", "pause", "timeupdate", "seeking", "ended"];

export class MediaController {
  #document;
  #createObserver;
  #createId;
  #send;
  #sessions = new Map();
  #sessionByElement = new WeakMap();
  #observer;

  constructor({ document, createObserver, createId, send }) {
    this.#document = document;
    this.#createObserver = createObserver;
    this.#createId = createId;
    this.#send = send;
    this.documentId = createId();
  }

  start() {
    this.#discover(this.#document);
    this.#observer = this.#createObserver((records) => this.#mutations(records));
    this.#observer.observe(this.#document, { childList: true, subtree: true });
  }

  stop() {
    this.#observer?.disconnect();
    for (const sessionId of this.#sessions.keys()) this.#remove(sessionId);
  }

  async resume(command) {
    if (command.documentId !== this.documentId) return this.#result(command, "document-changed");
    const entry = this.#sessions.get(command.sessionId);
    const element = entry?.element;
    if (!element?.isConnected || this.#sessionByElement.get(element) !== command.sessionId) {
      return this.#result(command, "session-not-found");
    }
    if (element.ended) return this.#result(command, "media-ended");

    try {
      const rewindSeconds = Number.isFinite(command.rewindSeconds) ? command.rewindSeconds : 0;
      element.currentTime = Math.max(0, element.currentTime - rewindSeconds);
    } catch {
      return this.#result(command, "seek-failed");
    }

    try {
      await element.play();
      return this.#result(command, "resumed");
    } catch {
      return this.#result(command, "play-rejected");
    }
  }

  #discover(root) {
    if (this.#isMedia(root)) this.#add(root);
    for (const element of root.querySelectorAll?.("audio,video") ?? []) this.#add(element);
  }

  #add(element) {
    if (this.#sessionByElement.has(element)) return;
    const sessionId = this.#createId();
    const listener = (event) => this.#report(sessionId, event.type);
    for (const eventName of MEDIA_EVENTS) element.addEventListener(eventName, listener);
    this.#sessions.set(sessionId, { element, listener });
    this.#sessionByElement.set(element, sessionId);
    this.#report(sessionId, "discovered");
  }

  #remove(sessionId) {
    const entry = this.#sessions.get(sessionId);
    if (!entry) return;
    this.#report(sessionId, "removed");
    for (const eventName of MEDIA_EVENTS) entry.element.removeEventListener(eventName, entry.listener);
    this.#sessions.delete(sessionId);
    this.#sessionByElement.delete(entry.element);
  }

  #mutations(records) {
    for (const record of records) {
      this.#added(record.addedNodes);
      this.#removed(record.removedNodes);
    }
  }

  #added(nodes) {
    for (const node of nodes) this.#discover(node);
  }

  #removed(nodes) {
    for (const node of nodes) {
      const elements = [node, ...(node.querySelectorAll?.("audio,video") ?? [])];
      for (const element of elements) this.#removeIfDetached(element);
    }
  }

  #removeIfDetached(element) {
    if (element.isConnected) return;
    const sessionId = this.#sessionByElement.get(element);
    if (sessionId) this.#remove(sessionId);
  }

  #report(sessionId, event) {
    const element = this.#sessions.get(sessionId)?.element;
    this.#send({
      type: "media-state",
      documentId: this.documentId,
      sessionId,
      event,
      isPlaying: event === "removed" ? false : !element.paused && !element.ended,
      ended: event === "removed" ? false : element.ended,
      currentTime: event === "removed" ? null : element.currentTime,
      duration: event === "removed" || !Number.isFinite(element.duration) ? null : element.duration,
    });
  }

  #result(command, status) {
    return {
      version: 1,
      type: "resume-result",
      documentId: this.documentId,
      sessionId: command.sessionId,
      status,
    };
  }

  #isMedia(node) {
    return node?.matches?.("audio,video") === true;
  }
}