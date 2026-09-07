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
  const thumbs = [...document.querySelectorAll('[data-slide-to]')];
  let current = 0;
  let timer;

  const show = (next) => {
    slides[current]?.classList.remove('is-active');
    current = (next + slides.length) % slides.length;
    slides[current]?.classList.add('is-active');
    thumbs.forEach((thumb, index) => thumb.classList.toggle('is-active', index === current));
  };
  const restart = () => {
    window.clearInterval(timer);
    timer = window.setInterval(() => show(current + 1), 5000);
  };

  slider.querySelector('[data-slide-prev]')?.addEventListener('click', () => { show(current - 1); restart(); });
  slider.querySelector('[data-slide-next]')?.addEventListener('click', () => { show(current + 1); restart(); });
  thumbs.forEach((thumb) => thumb.addEventListener('click', () => { show(Number(thumb.dataset.slideTo)); restart(); }));
  restart();
}

const contactForm = document.querySelector('[data-contact-form]');
contactForm?.addEventListener('submit', (event) => {
  event.preventDefault();
  if (!contactForm.reportValidity()) return;

  const data = new FormData(contactForm);
  const subject = String(data.get('subject') || 'NCPサイトからのお問い合わせ');
  const message = [
    `お名前: ${data.get('name') || ''}`,
    `電話番号: ${data.get('phone') || ''}`,
    `メールアドレス: ${data.get('email') || ''}`,
    '',
    String(data.get('message') || '')
  ].join('\n');
  const recipient = contactForm.dataset.contactEmail || 'info@ncptokyo.net';
  window.location.href = `mailto:${recipient}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(message)}`;
});
