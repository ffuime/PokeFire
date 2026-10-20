import { readdirSync, mkdirSync, copyFileSync, writeFileSync, rmSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const sources = [join(here, "..", "sprite"), join(here, "sprites")];
const catalog = join(here, "PokeFire", "Assets.xcassets");

for (const dir of readdirSync(catalog)) {
    if (dir.startsWith("sprite_") && dir.endsWith(".imageset")) rmSync(join(catalog, dir), { recursive: true });
}

let count = 0;
for (const source of sources) for (const file of readdirSync(source)) {
    if (!file.endsWith(".png")) continue;
    const name = file.slice(0, -4).normalize("NFC");
    const id = `sprite_${Buffer.from(name, "utf8").toString("hex")}`;
    const dir = join(catalog, `${id}.imageset`);
    mkdirSync(dir, { recursive: true });
    copyFileSync(join(source, file), join(dir, `${id}.png`));
    writeFileSync(join(dir, "Contents.json"), JSON.stringify({
        images: [{ filename: `${id}.png`, idiom: "universal" }],
        info: { author: "xcode", version: 1 },
    }, null, 2));
    count += 1;
}
console.log(`${count} sprites`);
