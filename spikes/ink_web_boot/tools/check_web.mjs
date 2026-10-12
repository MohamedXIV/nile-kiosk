import { chromium } from "playwright-core";

const url = process.argv[2] || "http://127.0.0.1:8765";
const browser = await chromium.launch({
  executablePath: process.env.CHROME_BINARY || "/usr/bin/google-chrome",
  headless: true,
  args: ["--no-sandbox", "--enable-webgl", "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"]
});

let webPass = false;
const faults = [];
try {
  const page = await browser.newPage({ viewport: { width: 960, height: 600 } });
  page.on("console", (msg) => {
    const t = msg.text();
    if (t.includes("INK_WEB_BOOT_PASS:")) webPass = true;
    if (t.includes("INK_WEB_BOOT_FAIL:")) faults.push(t);
  });
  page.on("pageerror", (err) => faults.push(err.message));
  await page.goto(url, { waitUntil: "load", timeout: 30000 });
  const deadline = Date.now() + 30000;
  while (!webPass && !faults.length && Date.now() < deadline) {
    await page.waitForTimeout(250);
  }
  await page.screenshot({ path: process.env.INK_SCREENSHOT || "/tmp/ink-web-boot.png" });
  if (!webPass || faults.length) {
    console.error("Ink Web boot failed", JSON.stringify({ webPass, faults }));
    process.exitCode = 1;
  } else {
    console.log("D001 P2: REAL CHROMIUM WEB BOOT PASS");
  }
} finally {
  await browser.close();
}
