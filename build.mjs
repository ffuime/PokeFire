import { execSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";

const run = (command) => execSync(command, { stdio: "inherit" });
const version = new Date().toISOString().replace(/\D/g, "").slice(0, 14);

for (const dir of [".", "help"]) {
    run(`npx --yes sass@1 --style=compressed --no-source-map ${dir}/style.scss ${dir}/style.css`);
    run(`npx --yes -p postcss-cli@11 -p autoprefixer@10 postcss ${dir}/style.css --use autoprefixer --no-map -o ${dir}/style.css`);
}

writeFileSync("app.bundle.js", ["app.js", "calc.js"].map((file) => readFileSync(file, "utf8")).join("\n"));
run("npx --yes terser@5 app.bundle.js -c passes=2 -m --toplevel -o app.min.js");
execSync(process.platform === "win32" ? "del app.bundle.js" : "rm app.bundle.js");

writeFileSync("sw.js", readFileSync("sw.js", "utf8").replace(/pokefire-[\w-]+/, `pokefire-${version}`));

for (const file of ["index.html", "help/index.html"]) {
    const html = readFileSync(file, "utf8");
    writeFileSync(file, html.replace(/(\.(?:css|js))\?v=\d+/g, `$1?v=${version}`));
}

console.log(`build ${version}`);
