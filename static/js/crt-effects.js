/**
 * crt-effects.js
 *
 * Canvas overlay that adds subtle CRT interference effects:
 *   - Phosphor ghosting: previous frame persists at decaying opacity
 *   - Occasional horizontal noise/static bands (short bursts)
 *   - Very rare full-screen flicker (brightness dip)
 *   - Slow horizontal jitter (geometry instability)
 *
 * All effects are intentionally rare and subtle — they should feel like
 * a warm CRT monitor, not a broken TV.
 */

(function () {
    'use strict';

    var canvas = document.createElement('canvas');
    canvas.style.cssText = [
        'position: fixed',
        'top: 0',
        'left: 0',
        'width: 100%',
        'height: 100%',
        'pointer-events: none',
        'z-index: 1000',
        'opacity: 1',
        'mix-blend-mode: screen',
    ].join(';');
    document.body.appendChild(canvas);

    var ctx = canvas.getContext('2d');

    // Offscreen canvas used to accumulate phosphor ghost trails.
    // Each frame we draw the ghost buffer back at low opacity (decay),
    // then add the new scanline bright-spot on top. Result: pixels
    // linger and fade like phosphor persistence on a real CRT.
    var ghostCanvas = document.createElement('canvas');
    var ghostCtx    = ghostCanvas.getContext('2d');

    var W, H;
    function resize() {
        W = canvas.width  = ghostCanvas.width  = window.innerWidth;
        H = canvas.height = ghostCanvas.height = window.innerHeight;
    }
    resize();
    window.addEventListener('resize', resize);

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    // Noise bands: each is { y, height, alpha, life, maxLife }
    var bands = [];

    // Full-screen flicker
    var flickerAlpha  = 0;
    var flickerTarget = 0;
    var flickerTimer  = 0;

    // Horizontal jitter
    var jitterOffset  = 0;
    var jitterTarget  = 0;
    var jitterTimer   = 0;
    var jitterActive  = false;

    // Rolling bright scanline (very faint, slow)
    var rollY     = 0;
    var rollSpeed = 0.4; // px per frame

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------
    function rand(min, max) {
        return min + Math.random() * (max - min);
    }
    function randInt(min, max) {
        return Math.floor(rand(min, max + 1));
    }

    // -------------------------------------------------------------------------
    // Spawn events (called on a stochastic timer each frame)
    // -------------------------------------------------------------------------

    // Average interval between noise band events: ~8 seconds
    var BAND_RATE    = 1 / (8 * 60);
    // Average interval between flicker events: ~20 seconds
    var FLICKER_RATE = 1 / (20 * 60);
    // Average interval between jitter events: ~15 seconds
    var JITTER_RATE  = 1 / (15 * 60);

    function maybeSpawnBand() {
        if (Math.random() > BAND_RATE) return;
        // 1-3 bands in a cluster
        var count = randInt(1, 3);
        var baseY = rand(0, H);
        for (var i = 0; i < count; i++) {
            var life = randInt(4, 18);
            bands.push({
                y:       baseY + rand(-20, 20),
                height:  rand(1, 6),
                alpha:   rand(0.04, 0.12),
                life:    life,
                maxLife: life,
            });
        }
    }

    function maybeSpawnFlicker() {
        if (flickerAlpha > 0 || Math.random() > FLICKER_RATE) return;
        // Dip brightness by overlaying a dark semi-transparent rect
        flickerTarget = rand(0.05, 0.18);
        flickerTimer  = randInt(2, 6);
    }

    function maybeSpawnJitter() {
        if (jitterActive || Math.random() > JITTER_RATE) return;
        jitterActive = true;
        jitterTarget = rand(-3, 3);
        jitterTimer  = randInt(3, 10);
    }

    // -------------------------------------------------------------------------
    // Draw
    // -------------------------------------------------------------------------
    function draw() {
        ctx.clearRect(0, 0, W, H);

        // --- Phosphor ghosting ---
        // 1. Decay the ghost buffer: overdraw it with a near-opaque black rect
        //    so previous content fades toward black each frame.
        ghostCtx.globalCompositeOperation = 'source-over';
        ghostCtx.fillStyle = 'rgba(0,0,0,0.18)'; // decay rate: ~18% per frame
        ghostCtx.fillRect(0, 0, W, H);

        // --- Rolling faint bright scanline (phosphor sweep) ---
        rollY = (rollY + rollSpeed) % H;
        var rollGrad = ctx.createLinearGradient(0, rollY - 6, 0, rollY + 6);
        rollGrad.addColorStop(0,   'rgba(51,255,51,0)');
        rollGrad.addColorStop(0.5, 'rgba(51,255,51,0.03)');
        rollGrad.addColorStop(1,   'rgba(51,255,51,0)');

        // 2. Paint the current scanline bright-spot onto the ghost buffer.
        ghostCtx.globalCompositeOperation = 'screen';
        ghostCtx.fillStyle = rollGrad;
        ghostCtx.fillRect(0, rollY - 6, W, 12);

        // 3. Composite the ghost buffer onto the main canvas at full opacity.
        ctx.globalCompositeOperation = 'source-over';
        ctx.globalAlpha = 1;
        ctx.drawImage(ghostCanvas, 0, 0);

        // Draw the current scanline on the main canvas too (so it's crisp).
        ctx.fillStyle = rollGrad;
        ctx.fillRect(0, rollY - 6, W, 12);

        // --- Noise bands ---
        maybeSpawnBand();
        for (var i = bands.length - 1; i >= 0; i--) {
            var b = bands[i];
            // Fade out over lifetime
            var progress = b.life / b.maxLife;
            var a = b.alpha * progress;

            // Noise band: random horizontal static
            var imageData = ctx.createImageData(W, Math.ceil(b.height));
            var data = imageData.data;
            for (var p = 0; p < data.length; p += 4) {
                var v = Math.random() < 0.5 ? randInt(30, 80) : 0;
                data[p]     = 0;       // R
                data[p + 1] = v;       // G — green channel only
                data[p + 2] = 0;       // B
                data[p + 3] = Math.floor(a * 255);
            }
            ctx.putImageData(imageData, 0, b.y);

            // Also burn noise bands into the ghost buffer so they ghost too.
            ghostCtx.globalCompositeOperation = 'screen';
            ghostCtx.putImageData(imageData, 0, b.y);

            b.life--;
            if (b.life <= 0) bands.splice(i, 1);
        }

        // --- Full-screen flicker ---
        maybeSpawnFlicker();
        if (flickerTimer > 0) {
            flickerAlpha = flickerTarget;
            flickerTimer--;
        } else {
            flickerAlpha = 0;
        }
        if (flickerAlpha > 0) {
            ctx.fillStyle = 'rgba(0,0,0,' + flickerAlpha + ')';
            ctx.fillRect(0, 0, W, H);
        }

        // --- Horizontal jitter ---
        maybeSpawnJitter();
        if (jitterActive) {
            // Apply a CSS transform to .main to simulate geometry instability
            var main = document.querySelector('.main');
            if (main) {
                main.style.transform = 'translateX(' + jitterOffset.toFixed(1) + 'px)';
            }
            jitterOffset += (jitterTarget - jitterOffset) * 0.3;
            jitterTimer--;
            if (jitterTimer <= 0) {
                jitterActive = false;
                jitterTarget = 0;
                jitterOffset = 0;
                if (main) main.style.transform = '';
            }
        }

        requestAnimationFrame(draw);
    }

    requestAnimationFrame(draw);

}());
