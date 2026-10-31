import { copyFileSync, mkdirSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const projectRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const binDir = join(projectRoot, ".hyperframes", "bin");

mkdirSync(binDir, { recursive: true });
copyFileSync(require("ffmpeg-static"), join(binDir, "ffmpeg"));
copyFileSync(require("ffprobe-static").path, join(binDir, "ffprobe"));

console.log(`Installed project-local media tools in ${binDir}`);
