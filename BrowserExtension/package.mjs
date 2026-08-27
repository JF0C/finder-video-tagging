import { cp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";

const root = new URL(".", import.meta.url);
const output = new URL("dist/", root);
const browsers = ["chrome", "firefox"];

await rm(output, { recursive: true, force: true });
for (const browser of browsers) {
  const destination = new URL(`${browser}/`, output);
  await mkdir(destination, { recursive: true });
  await cp(new URL("shared/", root), destination, { recursive: true });
  const manifest = JSON.parse(await readFile(new URL(`${browser}/manifest.json`, root), "utf8"));
  await writeFile(join(destination.pathname, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
}