const button = document.querySelector('[data-menu-button]');
const nav = document.querySelector('[data-nav]');

button?.addEventListener('click', () => {
  const open = button.getAttribute('aria-expanded') === 'true';
  button.setAttribute('aria-expanded', String(!open));
  nav?.classList.toggle('is-open', !open);
});

document.querySelectorAll('[data-nav] a').forEach((link) => {
  link.addEventListener('click', () => {
    button?.setAttribute('aria-expanded', 'false');
    nav?.classList.remove('is-open');
  });
});

const observer = new IntersectionObserver((entries) => {
  entries.forEach((entry) => {
    if (entry.isIntersecting) entry.target.classList.add('is-visible');
  });
}, { threshold: 0.12 });

document.querySelectorAll('.reveal').forEach((element) => observer.observe(element));

const slider = document.querySelector('[data-slider]');
if (slider) {
  const slides = [...slider.querySelectorAll('.legacy-slide')];
  let current = 0;
  let timer;

  const show = (next) => {
    slides[current]?.classList.remove('is-active');
    current = (next + slides.length) % slides.length;
    slides[current]?.classList.add('is-active');
  };
  const restart = () => {
    window.clearInterval(timer);
    timer = window.setInterval(() => show(current + 1), 5000);
  };

  slider.querySelector('[data-slide-prev]')?.addEventListener('click', () => { show(current - 1); restart(); });
  slider.querySelector('[data-slide-next]')?.addEventListener('click', () => { show(current + 1); restart(); });
  restart();
}
