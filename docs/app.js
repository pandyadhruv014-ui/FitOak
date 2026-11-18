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

// 2. Subtle Desktop Glass Tilt on Hero App Card
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

// 3. Interactive AI Meal Log Simulation in Hero Glass Card
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

// 4. Interactive AI Macro Parser Demo Chips
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

// 5. Interactive 20% Drop-Set Calculator Slider
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

// 6. Scroll Reveal Observer
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
