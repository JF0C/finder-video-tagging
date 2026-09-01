import { BackgroundRouter } from "./background-router.js";
import { createSafariNativeRuntime } from "./safari-native-runtime.js";

const extensionApi = globalThis.browser ?? globalThis.chrome;

new BackgroundRouter({
  runtime: createSafariNativeRuntime(extensionApi.runtime),
  tabs: extensionApi.tabs,
  hostName: "com.findervideotagging.safari",
  browser: "safari",
}).start();