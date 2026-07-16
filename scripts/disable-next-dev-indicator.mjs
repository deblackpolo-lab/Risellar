import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import { fileURLToPath, URL } from "node:url";

const configPath = fileURLToPath(new URL("../.next/cache/next-devtools-config.json", import.meta.url));

let existingConfig = {};

try {
  existingConfig = JSON.parse(readFileSync(configPath, "utf8"));
} catch {
  existingConfig = {};
}

mkdirSync(dirname(configPath), { recursive: true });
writeFileSync(configPath, JSON.stringify({ ...existingConfig, disableDevIndicator: true }, null, 2));
