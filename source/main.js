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

