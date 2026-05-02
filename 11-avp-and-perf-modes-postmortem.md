# AVP / Performance-Mode / Multi-File-Build Lessons (Post-Mortem 2026-04-28)

## What happened

Ruben asked me to fix DNA canvas issues + test on AVP. Over 6+ deploy rounds I:

1. Shipped v16b (confidence + recommendation badges on bubble face) — GOOD fix.
2. Shipped oval-on-drag fix (remove lod2 on drag-start) — GOOD fix.
3. Shipped Open-idea link fix (orchestrator_ideas.php?id=N filter) — GOOD fix.
4. Shipped click-to-collapse size fix (don't add lod1 when removing lod2) — GOOD fix.
5. Shipped v16f auto-refresh (30s polling) — GOOD fix.
6. Shipped AVP perf-mode (disable matrix-bg + freeze bubble/child-dot animations) — **PARTIALLY BROKE THE CANVAS**. The animation freezes killed the DNA helix render.
7. Shipped a brand-new visual_canvas_avp.php (Three.js + WebXR, 428 lines, 17KB) with no testing on actual AVP — **LOCKED UP THE BROWSER**. The Three.js bundle from esm.sh CDN is ~600KB+, the import map style isn't reliable on visionOS Safari, and creating 100+ PBR transmissive bubbles + complex tube geometries on AVP without progressive loading is too much for a first ship.
8. Added an "Open in AVP/VR" link from the 2D canvas — clicking it locked up the server (likely Three.js CDN preload + WebXR session probe + AVP Safari interaction).

Net: 5 good fixes + 2 broken ships. Ruben had to revert.

## What I should have done instead

### 1. NEVER ship a new big feature ahead of a real test cycle on the target hardware

The AVP build went straight from "doesn't exist" → 17KB Three.js scene → live deploy → "test it on your $3500 device" with NO testing in between. There was no:
- Dev environment with a WebXR emulator (browser DevTools has one)
- Local 3D-only test (verifying the Three.js scene renders at all in a desktop browser)
- Smoke test that the import map resolves
- Smoke test that the API call returns
- Bundle-size check (esm.sh dynamic Three.js can be 1MB+ first load)

Result: shipped a brick. Locked up the AVP browser. Wasted Ruben's time mounting/unmounting the headset.

**Rule:** when building a brand-new file with external CDN dependencies for an unfamiliar runtime, ship it as a static HTML test page FIRST (no auth, no API calls), confirm it renders bare-bones geometry on the target device, THEN add data + interactions. Three steps minimum:
1. test1.html = empty canvas + single colored cube. Does it draw? Does Enter VR work? Stop here if no.
2. test2.html = test1 + dynamic mesh. Does it stay smooth at 60fps when it spins?
3. test3.html = test2 + WebXR controller wired. Pinch grabs the cube, releases.

Only after those three steps work in AVP do you wire up the actual data pipeline.

### 2. CSS animations on visualization elements are NOT optional perf overhead — they ARE the visualization

When v16-perf-mode froze `.bubble { animation: none !important }` and `.dna-band-zone.drop-landed { animation: none !important }`, I assumed those were "decorative" animations. They weren't — `.dna-band-zone` uses keyframe pulses to draw the actual band visual, and `.bubble.lod1` has a drift keyframe that gives bubbles their "alive" feel. Disabling them turned the canvas into a static lifeless layout.

**Rule:** when adding a CSS-based "perf mode", NEVER blanket-disable animations on visualization elements. Only kill animations that are pure decoration (matrix rain, ambient drift on background elements, idle pulses on UI chrome). And test the perf-mode side-by-side with normal mode in a regular browser BEFORE deploying — the visual difference is the diagnostic.

### 3. AVP-detection by user-agent sniffing is fragile

visionOS Safari's UA has changed multiple times. My detector was checking for `visionOS|Vision Pro|AppleVisionPro` in UA — but AVP Safari often presents as iPad Safari for compat. So my `__vc_isPerfMode` check probably never even fired on Ruben's actual AVP. Which means the animation freezes I shipped fired on his Mac browser too — meaning the Mac canvas was also visibly broken until the walkback.

**Rule:** feature-detect, don't UA-sniff. For AVP, the right detector is `navigator.xr && await navigator.xr.isSessionSupported('immersive-vr')` — and even that is best-effort. And NEVER apply perf-mode aggressively until that check resolves; load defensively.

### 4. The 2-route split was the right idea executed wrong

Building a separate AVP-only route was conceptually correct — the Mac 2D canvas is fine as-is, and AVP needs an immersive build. Where I went wrong:
- Should not have linked to it from the 2D canvas header (too easy to click accidentally)
- Should have shipped a placeholder 3D scene FIRST (just a spinning cube saying "AVP build under construction"), let Ruben click it once and confirm the URL pattern works
- Should have built it incrementally (one geometry at a time) over 2-3 deploy rounds, not 1

**Rule:** NEW separate routes with new bundles get a placeholder ship FIRST. The placeholder proves: route exists, auth works, asset loads, rendering doesn't crash. THEN add the actual feature in a second deploy. NEVER ship route-and-feature in one go for unfamiliar runtimes.

### 5. CDN-loaded heavy libraries are a different deploy class

On WOPR + nginx + AVP Safari + Spectrum WAN, an unbundled Three.js esm.sh import map fetches:
- The main bundle (~600KB minified)
- The XR controller model factory module (which imports more)
- A tree of dependency modules over HTTP/2

That's potentially 1-2 MB on first load over a flaky carrier connection. AVP Safari may stall on HTTP/2 module-import dependency chains. Ruben said "clicking that link locks up the server" — what likely happened is the import-map preload tree chained 30+ requests through nginx, possibly hitting a per-IP rate limit OR the Spectrum line just choked.

**Rule:** for any NEW route that uses a CDN-loaded heavy library, BUNDLE IT LOCALLY first. Download once, host as a single asset on the server, ship a single `<script src>` tag. esm.sh dynamic import-map style is convenient but production-fragile.

### 6. Ship velocity vs ship quality

I shipped 8 file changes in ~2.5 hours. That's a deploy every 19 minutes. At that pace I cannot test properly between ships. Each fix shipped before verifying the LAST fix didn't regress something else. The walkback was inevitable.

**Rule:** when iterating on a UX surface that Ruben is actively testing, slow down to one ship per 30 minutes minimum. Verify in browser between ships. If Ruben reports a new bug, that's a signal that deploy frequency is faster than test frequency — pause and verify.

## Concrete escape hatch for next time

When Ruben asks "I want to test on AVP":

1. ASK FIRST: "Do you want to test the existing 2D canvas on AVP Safari (will be flat 2D pinned window — same as desktop), OR do you want me to build a new immersive 3D version (multi-day Unity/Three.js build, iterative)?" Do not build silently.
2. If immersive: seed a 5-step chain (placeholder → spinning-cube → dna-helix → bubbles → controllers), each shippable in 30-60 min with AVP test in between.
3. If flat 2D Safari: confirm with Ruben that flat 2D is what he expects, no perf-mode weirdness.

## Reversion trail

Last good state: sha `665c5820...` (after v16b badges + oval fix + click-collapse fix + Open-idea link fix).

Bad states shipped: sha `90c70447...` (perf-mode), sha `140b03d6...` (walkback), sha `69e976e6...` (AVP link). All reverted to `665c5820...` at 22:18 PT 2026-04-28.

The brand-new immersive AVP file has been deleted from the server.
