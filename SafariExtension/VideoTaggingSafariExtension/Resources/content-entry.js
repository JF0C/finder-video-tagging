import { createOpaqueId } from "./ids.js";
import { MediaController } from "./media-controller.js";

const extensionApi = globalThis.browser ?? globalThis.chrome;
const controller = new MediaController({
  document,
  createObserver: (callback) => new MutationObserver(callback),
  createId: () => createOpaqueId(),
  send: (message) => extensionApi.runtime.sendMessage(message),
});

extensionApi.runtime.onMessage.addListener((message) => {
  if (message?.type !== "resume-media") return undefined;
  return controller.resume(message);
});

controller.start();