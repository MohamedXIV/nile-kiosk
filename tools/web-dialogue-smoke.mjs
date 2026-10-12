import { chromium } from "playwright-core";

const url = process.argv[2] || "http://127.0.0.1:8765";
const browser = await chromium.launch({
  executablePath: process.env.CHROME_BINARY || "/usr/bin/google-chrome",
  headless: true,
  args: ["--no-sandbox", "--enable-webgl", "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"]
});
let failures = 0;
try {
  for (const variant of ["dm", "ink"]) {
    const page = await browser.newPage({ viewport: { width: 1100, height: 760 } });
    const target = `D001_FULL_WEB_${variant.toUpperCase()}_PASS`;
    let passed = false;
    const errors = [];
    page.on("console", msg => {
      if (msg.text().includes(target)) passed = true;
      if (/SCRIPT ERROR:|D001_FULL_WEB_.*FAIL/.test(msg.text())) errors.push(msg.text());
    });
    page.on("pageerror", error => errors.push(error.message));
    try {
      await page.goto(`${url}/${variant}/index.html`, { waitUntil: "load", timeout: 30000 });
      await page.waitForTimeout(3500);
      await page.locator("canvas").first().click({ position: { x: 480, y: 260 }, timeout: 12000 });
      for (let i = 0; i < 3; i++) {
        await page.keyboard.press("e");
        await page.waitForTimeout(150);
      }
      const deadline = Date.now() + 25000;
      while (!passed && !errors.length && Date.now() < deadline) await page.waitForTimeout(250);
      await page.screenshot({ path: `/tmp/d001-full-web-${variant}.png` });
      if (!passed || errors.length) {
        failures++;
        console.error(`D001 full ${variant} Web FAIL`, { passed, errors });
      } else {
        console.log(`D001 full ${variant} Web PASS: two sessions completed and tea prepared in Chromium`);
      }
    } catch (err) {
      failures++;
      console.error(`D001 full ${variant} Web harness failure`, String(err));
    } finally {
      await page.close();
    }
  }
} finally {
  await browser.close();
}
if (failures) process.exitCode = 1;
