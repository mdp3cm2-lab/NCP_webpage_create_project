document.documentElement.classList.add('js');

document.addEventListener('DOMContentLoaded', () => {
  const animatedElements = document.querySelectorAll('.reveal, .pillars, .menu-board, .photos');

  if (!('IntersectionObserver' in window)) {
    animatedElements.forEach((element) => element.classList.add('is-visible'));
    return;
  }

  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add('is-visible');
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.18, rootMargin: '0px 0px -8% 0px' });

  animatedElements.forEach((element) => observer.observe(element));
});
