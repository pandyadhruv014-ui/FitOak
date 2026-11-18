// 1. Mobile Navigation Drawer Toggle
const menuToggle = document.getElementById('menuToggle');
const mobileDrawer = document.getElementById('mobileDrawer');

if (menuToggle && mobileDrawer) {
  menuToggle.addEventListener('click', () => {
    const isOpen = mobileDrawer.classList.toggle('open');
    menuToggle.setAttribute('aria-expanded', String(isOpen));
  });

  document.querySelectorAll('.drawer-link').forEach((link) => {
    link.addEventListener('click', () => {
      mobileDrawer.classList.remove('open');
      menuToggle.setAttribute('aria-expanded', 'false');
    });
  });
}

// 2. Interactive Cursor Aura + Local Surface Spotlight Glow (Cards, Nav, Device, Footer)
const cursorAura = document.getElementById('cursorAura');
let cursorX = window.innerWidth / 2;
let cursorY = window.innerHeight / 2;

window.addEventListener('mousemove', (e) => {
  cursorX = e.clientX;
  cursorY = e.clientY;
  document.body.classList.add('cursor-active');
  if (cursorAura) {
    cursorAura.style.left = `${cursorX}px`;
    cursorAura.style.top = `${cursorY}px`;
  }
}, { passive: true });

window.addEventListener('mouseleave', () => {
  document.body.classList.remove('cursor-active');
});

document.querySelectorAll('.glow-surface').forEach((surface) => {
  surface.addEventListener('mousemove', (e) => {
    const rect = surface.getBoundingClientRect();
    surface.style.setProperty('--gx', `${e.clientX - rect.left}px`);
    surface.style.setProperty('--gy', `${e.clientY - rect.top}px`);
  }, { passive: true });
});

// 3. Continuous Glowing Trails Running Along Background Square Grid Boxes
(function initGridGlowTrails() {
  const canvas = document.getElementById('gridTrailCanvas');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');

  const GRID_SIZE = 48; // Matches .grid-overlay background-size: 48px 48px
  let width = 0;
  let height = 0;
  let cols = 0;
  let rows = 0;
  const dpr = Math.min(window.devicePixelRatio || 1, 2);

  function resize() {
    width = window.innerWidth;
    height = window.innerHeight;
    canvas.width = width * dpr;
    canvas.height = height * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    cols = Math.ceil(width / GRID_SIZE) + 1;
    rows = Math.ceil(height / GRID_SIZE) + 1;
  }
  resize();
  window.addEventListener('resize', resize);

  const PALETTE = [
    { head: 'rgba(255, 87, 34, 0.95)', tail: 'rgba(255, 87, 34, 0)' },
    { head: 'rgba(99, 102, 241, 0.92)', tail: 'rgba(99, 102, 241, 0)' },
    { head: 'rgba(14, 165, 233, 0.90)', tail: 'rgba(14, 165, 233, 0)' },
    { head: 'rgba(255, 143, 0, 0.92)', tail: 'rgba(255, 143, 0, 0)' }
  ];

  // Directions: 0 = right, 1 = down, 2 = left, 3 = up
  const DIRS = [
    { dx: 1, dy: 0 },
    { dx: 0, dy: 1 },
    { dx: -1, dy: 0 },
    { dx: 0, dy: -1 }
  ];

  class GridRunner {
    constructor() {
      this.reset();
    }

    reset() {
      this.gx = Math.floor(Math.random() * Math.max(1, cols));
      this.gy = Math.floor(Math.random() * Math.max(1, rows));
      this.dir = Math.floor(Math.random() * 4);
      this.progress = 0;
      this.speed = 0.032 + Math.random() * 0.035;
      this.color = PALETTE[Math.floor(Math.random() * PALETTE.length)];
      this.history = [{ x: this.gx * GRID_SIZE, y: this.gy * GRID_SIZE }];
      this.maxHistory = 14 + Math.floor(Math.random() * 10);
    }

    update() {
      this.progress += this.speed;
      if (this.progress >= 1) {
        this.progress -= 1;
        this.gx += DIRS[this.dir].dx;
        this.gy += DIRS[this.dir].dy;

        // Respawn if runner exits viewport bounds
        if (this.gx < -1 || this.gx > cols + 1 || this.gy < -1 || this.gy > rows + 1) {
          this.reset();
          return;
        }

        // Occasionally make a 90-degree turn around a square box corner
        if (Math.random() < 0.35) {
          const turn = Math.random() < 0.5 ? 1 : 3;
          this.dir = (this.dir + turn) % 4;
        }
      }

      const px = (this.gx + DIRS[this.dir].dx * this.progress) * GRID_SIZE;
      const py = (this.gy + DIRS[this.dir].dy * this.progress) * GRID_SIZE;
      this.history.push({ x: px, y: py });
      if (this.history.length > this.maxHistory) {
        this.history.shift();
      }
    }

    draw() {
      if (this.history.length < 2) return;
      const start = this.history[0];
      const end = this.history[this.history.length - 1];

      const grad = ctx.createLinearGradient(start.x, start.y, end.x, end.y);
      grad.addColorStop(0, this.color.tail);
      grad.addColorStop(1, this.color.head);

      ctx.save();
      ctx.beginPath();
      ctx.moveTo(this.history[0].x, this.history[0].y);
      for (let i = 1; i < this.history.length; i++) {
        ctx.lineTo(this.history[i].x, this.history[i].y);
      }
      ctx.strokeStyle = grad;
      ctx.lineWidth = 2.2;
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';
      ctx.shadowBlur = 12;
      ctx.shadowColor = this.color.head;
      ctx.stroke();

      // Glowing spark head
      ctx.beginPath();
      ctx.arc(end.x, end.y, 2.6, 0, Math.PI * 2);
      ctx.fillStyle = '#ffffff';
      ctx.fill();
      ctx.restore();
    }
  }

  const runnerCount = window.innerWidth < 768 ? 14 : 26;
  const runners = Array.from({ length: runnerCount }, () => new GridRunner());

  function loop() {
    ctx.clearRect(0, 0, width, height);

    // Subtle cursor-proximity square highlight
    if (document.body.classList.contains('cursor-active')) {
      const snapX = Math.floor(cursorX / GRID_SIZE) * GRID_SIZE;
      const snapY = Math.floor(cursorY / GRID_SIZE) * GRID_SIZE;
      ctx.save();
      ctx.fillStyle = 'rgba(255, 87, 34, 0.05)';
      ctx.strokeStyle = 'rgba(255, 87, 34, 0.35)';
      ctx.lineWidth = 1.5;
      ctx.shadowBlur = 16;
      ctx.shadowColor = 'rgba(255, 87, 34, 0.45)';
      ctx.fillRect(snapX, snapY, GRID_SIZE, GRID_SIZE);
      ctx.strokeRect(snapX, snapY, GRID_SIZE, GRID_SIZE);
      ctx.restore();
    }

    for (const runner of runners) {
      runner.update();
      runner.draw();
    }

    requestAnimationFrame(loop);
  }
  loop();
})();

// 4. Subtle Desktop Glass Tilt on Hero App Card
const glassDevice = document.getElementById('glassDevice');
if (glassDevice && window.matchMedia('(hover: hover)').matches) {
  glassDevice.addEventListener('mousemove', (e) => {
    const rect = glassDevice.getBoundingClientRect();
    const x = (e.clientX - rect.left) / rect.width - 0.5;
    const y = (e.clientY - rect.top) / rect.height - 0.5;
    glassDevice.style.transform = `perspective(900px) rotateY(${x * 8}deg) rotateX(${-y * 8}deg)`;
  });

  glassDevice.addEventListener('mouseleave', () => {
    glassDevice.style.transform = 'perspective(900px) rotateY(0deg) rotateX(0deg)';
  });
}

// 5. Interactive AI Meal Log Simulation in Hero Glass Card
let currentCal = 1420;
let currentP = 98;
let currentC = 164;
let currentF = 41;

const simulateMealBtn = document.getElementById('simulateMealBtn');
if (simulateMealBtn) {
  simulateMealBtn.addEventListener('click', () => {
    if (currentCal >= 2600) {
      currentCal = 1420;
      currentP = 98;
      currentC = 164;
      currentF = 41;
    } else {
      currentCal = Math.min(2600, currentCal + 450);
      currentP = Math.min(150, currentP + 26);
      currentC = Math.min(300, currentC + 52);
      currentF = Math.min(75, currentF + 14);
    }

    document.getElementById('hudCalText').textContent = `${currentCal.toLocaleString()} / 2,600 kcal`;
    document.getElementById('hudCalBar').style.width = `${Math.round((currentCal / 2600) * 100)}%`;
    document.getElementById('hudProt').textContent = `${currentP}g`;
    document.getElementById('hudCarb').textContent = `${currentC}g`;
    document.getElementById('hudFat').textContent = `${currentF}g`;
  });
}

// 6. Interactive AI Macro Parser Demo Chips
document.querySelectorAll('#mealChips .glass-chip').forEach((chip) => {
  chip.addEventListener('click', () => {
    document.querySelectorAll('#mealChips .glass-chip').forEach((c) => c.classList.remove('active'));
    chip.classList.add('active');

    document.getElementById('simMealTitle').textContent = chip.dataset.name;
    document.getElementById('simMealCal').textContent = `${chip.dataset.cal} kcal`;
    document.getElementById('simMealP').textContent = `${chip.dataset.p}g`;
    document.getElementById('simMealC').textContent = `${chip.dataset.c}g`;
    document.getElementById('simMealF').textContent = `${chip.dataset.f}g`;
  });
});

// 7. Interactive 20% Drop-Set Calculator Slider
const weightSlider = document.getElementById('weightSlider');
if (weightSlider) {
  weightSlider.addEventListener('input', (e) => {
    const w = Number(e.target.value);
    document.getElementById('topWeightLabel').textContent = `${w} kg`;
    document.getElementById('dropSet1').textContent = `${w} kg`;
    document.getElementById('dropSet2').textContent = `${Math.round(w * 0.8)} kg`;
    document.getElementById('dropSet3').textContent = `${Math.round(w * 0.64)} kg`;
  });
}

// 8. Scroll Reveal Observer
const revealObserver = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
      }
    });
  },
  { threshold: 0.1 }
);

document.querySelectorAll('.reveal').forEach((el) => revealObserver.observe(el));
