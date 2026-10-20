import { readFileSync, writeFileSync, mkdirSync, rmSync, readdirSync, copyFileSync } from "node:fs";
import { join } from "node:path";

const root = process.argv[2];
const out = join(root, "ios/PokeFire/Assets.xcassets");
const html = readFileSync(join(root, "index.html"), "utf8");
const app = readFileSync(join(root, "app.js"), "utf8");

for (const dir of readdirSync(out)) {
    if (dir.endsWith(".imageset") && !dir.startsWith("sprite_")) rmSync(join(out, dir), { recursive: true });
}

const symbols = {};
for (const m of html.matchAll(/<symbol id="([^"]+)" viewBox="([^"]+)">(.*?)<\/symbol>/g)) symbols[m[1]] = { viewBox: m[2], body: m[3] };

const stroke = (body, width = 2, viewBox = "0 0 24 24") => ({ viewBox, attrs: `fill="none" stroke="#000000" stroke-width="${width}" stroke-linecap="round" stroke-linejoin="round"`, body });
const fill = (body, viewBox = "0 0 24 24") => ({ viewBox, attrs: `fill="#000000"`, body });

const icons = {
    tab_attack: stroke(symbols.i1.body),
    tab_damage: stroke(symbols.i3.body),
    tab_heel: stroke(symbols.i4.body),
    close_circle: fill(symbols.i2.body),
    chevron_up: stroke(symbols["i-up"].body),
    chevron_down: stroke(symbols["i-down"].body),
    forms: stroke(symbols.i6.body),
    edit: stroke(symbols.i7.body),
    xmark: fill(symbols.i8.body),
    search: stroke(symbols.i9.body),
    speed: stroke(symbols.i10.body),
    add: fill('<path d="M11.252 20.2498C11.252 20.6641 11.5878 20.9999 12.002 20.9999C12.4162 20.9999 12.752 20.6641 12.752 20.2499V12.7498H20.2519C20.6661 12.7498 21.0019 12.414 21.0019 11.9998C21.0019 11.5856 20.6661 11.2498 20.2519 11.2498H12.752V3.74988C12.752 3.33567 12.4162 2.99988 12.002 2.99988C11.5878 2.99988 11.252 3.33566 11.252 3.74988V11.2498H3.75195C3.33774 11.2498 3.00195 11.5856 3.00195 11.9998C3.00195 12.414 3.33774 12.7498 3.75195 12.7498H11.252V20.2498Z"/>'),
    move_left: stroke('<path d="M13 9a1 1 0 0 1-1-1V4.707a.707.707 0 0 0-1.207-.5l-6.94 6.94a1.207 1.207 0 0 0 0 1.707l6.94 6.94a.707.707 0 0 0 1.207-.5V16a1 1 0 0 1 1-1h2a1 1 0 0 0 1-1v-4a1 1 0 0 0-1-1z"/><path d="M20 9v6"/>'),
    move_right: stroke('<path d="M11 9a1 1 0 0 0 1-1V4.707a.707.707 0 0 1 1.207-.5l6.94 6.94a1.207 1.207 0 0 1 0 1.707l-6.94 6.94a.707.707 0 0 1-1.207-.5V16a1 1 0 0 0-1-1H9a1 1 0 0 1-1-1v-4a1 1 0 0 1 1-1z"/><path d="M4 9v6"/>'),
    help: stroke('<circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><path d="M12 17h.01"/>'),
    history: stroke('<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/><path d="M12 7v5l4 2"/>'),
    menu: stroke('<path d="M4 6h16"/><path d="M4 12h11"/><path d="M4 18h6"/>'),
    swap: stroke('<path d="m16 3 4 4-4 4"/><path d="M20 7H4"/><path d="m8 21-4-4 4-4"/><path d="M4 17h16"/>'),
    shield: stroke('<path d="M12 3a12 12 0 0 0 8.5 3a12 12 0 0 1 -8.5 15a12 12 0 0 1 -8.5 -15a12 12 0 0 0 8.5 -3"/>'),
    share: stroke('<circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="m8.59 13.51 6.83 3.98"/><path d="m15.41 6.51-6.82 3.98"/>'),
    lock: stroke('<circle cx="12" cy="16" r="1"/><rect x="3" y="10" width="18" height="12" rx="2"/><path d="M7 10V7a5 5 0 0 1 10 0v3"/>'),
    pin: stroke('<path d="M12 17v5"/><path d="M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z"/>'),
    trash: stroke('<path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/>'),
    chevron_left: stroke('<path d="m15 18-6-6 6-6"/>'),
    minus: stroke('<path d="M5 12h14"/>'),
    plus: stroke('<path d="M5 12h14"/><path d="M12 5v14"/>'),
    watermark_attack: fill(symbols.i1.body),
    watermark_defense: fill('<path d="M12 3a12 12 0 0 0 8.5 3a12 12 0 0 1 -8.5 15a12 12 0 0 1 -8.5 -15a12 12 0 0 0 8.5 -3"/>'),
    weather_none: { viewBox: "0 0 24 24", attrs: 'fill="none" stroke="#000000" stroke-linecap="round" stroke-width="2.6"', body: symbols.i12.body },
    field_none: { viewBox: "0 0 24 24", attrs: 'fill="none" stroke="#000000" stroke-linecap="round" stroke-width="2.6"', body: symbols.i12.body },
};

for (const m of html.matchAll(/<button class="modal_environment_(weather|field)_select_(\w+)">\s*<svg ([^>]*)>([\s\S]*?)<\/svg>/g)) {
    const [, kind, key, attrText, body] = m;
    if (key === "none") continue;
    const viewBox = attrText.match(/viewBox="([^"]+)"/)[1];
    const attrs = attrText.replace(/viewBox="[^"]+"\s*/, "").replace(/currentColor/g, "#000000");
    icons[`${kind}_${key}`] = { viewBox, attrs, body: body.replace(/currentColor/g, "#000000") };
}

const categories = app.match(/const CATEGORY_SVG = \{([\s\S]*?)\n\};/)[1];
for (const [ja, id] of [["物理", "category_physical"], ["特殊", "category_special"]]) {
    const svg = categories.match(new RegExp(`"${ja}": '(<svg[\\s\\S]*?</svg>)'`))[1];
    const viewBox = svg.match(/viewBox="([^"]+)"/)[1];
    const body = svg.replace(/^<svg[^>]*>/, "").replace(/<\/svg>$/, "");
    icons[id] = fill(body, viewBox);
}

const typeIcons = {};
for (const m of app.matchAll(/\["(\w+)", "([^"]+)", "(#[0-9a-f]{6})", '(.*?)'\],?\n/g)) {
    const [, id, , color, shapes] = m;
    typeIcons[`type_${id}`] = `<rect width="76.71" height="76.71" rx="15" fill="${color}"/><g fill="#ffffff">${shapes}</g>`;
    icons[`glyph_${id}`] = { viewBox: "0 0 76.71 76.71", attrs: 'fill="#000000"', body: shapes.replace(/fill="#?[0-9a-fA-F]{3,6}"/g, "") };
}

icons.category_status = stroke('<circle cx="12" cy="12" r="9"/><path d="M12 3a4.5 4.5 0 0 1 0 9a4.5 4.5 0 0 0 0 9"/><circle cx="12" cy="7.5" r="0.6"/><circle cx="12" cy="16.5" r="0.6"/>');
icons.eff_x4 = fill('<path d="M12 2.2l2.95 6.3 6.85.8-5.1 4.7 1.4 6.8L12 17.4l-6.1 3.4 1.4-6.8-5.1-4.7 6.85-.8z"/>');
icons.eff_x2 = stroke('<circle cx="12" cy="12" r="9.2"/><circle cx="12" cy="12" r="4.6"/>', 2.2);
icons.eff_half = stroke('<path d="M12 4.2 21 19.8H3z"/>', 2.2);
icons.eff_quarter = fill('<path d="M3 4.6h18a1 1 0 0 1 .86 1.5l-9 15.2a1 1 0 0 1-1.72 0l-9-15.2A1 1 0 0 1 3 4.6z"/>');
icons.eff_zero = stroke('<path d="M4.5 4.5l15 15"/><path d="M19.5 4.5l-15 15"/>', 2.6);
if (Object.keys(typeIcons).length !== 18) throw new Error(`types: ${Object.keys(typeIcons).length}`);

const writeSet = (name, svg, template) => {
    const dir = join(out, `${name}.imageset`);
    mkdirSync(dir, { recursive: true });
    writeFileSync(join(dir, `${name}.svg`), svg);
    writeFileSync(join(dir, "Contents.json"), JSON.stringify({
        images: [{ filename: `${name}.svg`, idiom: "universal" }],
        info: { author: "xcode", version: 1 },
        properties: { "preserves-vector-representation": true, ...(template ? { "template-rendering-intent": "template" } : { "template-rendering-intent": "original" }) },
    }, null, 2));
};

const size = (viewBox) => viewBox.split(/\s+/).slice(2);
for (const [name, { viewBox, attrs, body }] of Object.entries(icons)) {
    const [w, h] = size(viewBox);
    writeSet(name, `<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" viewBox="${viewBox}" width="${w}" height="${h}" ${attrs}>${body.replace(/\s+/g, " ").trim()}</svg>\n`, true);
}
for (const [name, body] of Object.entries(typeIcons)) {
    writeSet(name, `<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 76.71 76.71" width="76.71" height="76.71">${body}</svg>\n`, false);
}

const scarf = join(out, "scarf.imageset");
mkdirSync(scarf, { recursive: true });
copyFileSync(join(root, "sprite/scarf.png"), join(scarf, "scarf.png"));
writeFileSync(join(scarf, "Contents.json"), JSON.stringify({
    images: [{ filename: "scarf.png", idiom: "universal" }],
    info: { author: "xcode", version: 1 },
}, null, 2));

console.log(Object.keys(icons).length + Object.keys(typeIcons).length + 1, "assets");
