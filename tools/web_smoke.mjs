// Drive headless Chromium over CDP: load the Web build, screenshot, press Enter (New voyage), screenshot.
// usage: node web-smoke.mjs <url> <outdir>
import { spawn } from "node:child_process";
import { writeFileSync, mkdirSync } from "node:fs";
const [url, out] = [process.argv[2], process.argv[3]];
mkdirSync(out, { recursive: true });
const chrome = spawn("chromium", ["--headless=new", "--remote-debugging-port=9333", "--window-size=1280,720",
  "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist", "--no-first-run",
  "--user-data-dir=" + out + "/profile", "about:blank"], { stdio: "ignore" });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let tabs;
for (let i = 0; i < 50; i++) { try { tabs = await (await fetch("http://127.0.0.1:9333/json")).json(); break; } catch { await sleep(200); } }
const page = tabs.find((t) => t.type === "page");
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((r) => (ws.onopen = r));
let id = 0; const pending = new Map(); const logs = [];
ws.onmessage = (m) => {
  const msg = JSON.parse(m.data);
  if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); }
  if (msg.method === "Runtime.consoleAPICalled") logs.push(msg.params.type + ": " + msg.params.args.map((a) => a.value ?? a.description).join(" "));
  if (msg.method === "Runtime.exceptionThrown") logs.push("EXCEPTION: " + msg.params.exceptionDetails.text);
};
const send = (method, params = {}) => new Promise((r) => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
const shot = async (name) => { const r = await send("Page.captureScreenshot", { format: "png" }); writeFileSync(`${out}/${name}.png`, Buffer.from(r.result.data, "base64")); console.log("saved", name); };
const key = async (k, code, vk) => { for (const type of ["keyDown", "keyUp"]) await send("Input.dispatchKeyEvent", { type, key: k, code, windowsVirtualKeyCode: vk, nativeVirtualKeyCode: vk }); };
const click = async (x, y) => { for (const type of ["mousePressed", "mouseReleased"]) await send("Input.dispatchMouseEvent", { type, x, y, button: "left", clickCount: 1 }); };
await send("Runtime.enable"); await send("Page.enable");
await send("Emulation.setDeviceMetricsOverride", { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
await send("Page.navigate", { url });
await sleep(15000); await shot("web-title");
const steps = JSON.parse(process.env.STEPS || "[]"); // [[name, "enter"|"click x y", waitMs]]
for (const [name, action, wait] of steps) {
  if (action === "enter") await key("Enter", "Enter", 13);
  else if (action === "reload") await send("Page.reload");
  else if (action.startsWith("click")) { const [, x, y] = action.split(" ").map(Number); await click(x, y); }
  await sleep(wait); await shot(name);
}
const ev = await send("Runtime.evaluate", { expression: "JSON.stringify({title: document.title, canvas: !!document.querySelector('canvas'), status: (document.querySelector('#status')||{}).style?.visibility})", returnByValue: true });
console.log("page", ev.result.result.value);
console.log("console:\n" + logs.slice(-25).join("\n"));
ws.close(); chrome.kill();
process.exit(0);
