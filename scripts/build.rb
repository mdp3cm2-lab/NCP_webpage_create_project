#!/usr/bin/env ruby
# encoding: UTF-8
# frozen_string_literal: true

require 'cgi'
require 'date'
require 'fileutils'
require 'yaml'

ROOT = File.expand_path('..', __dir__)
DIST = File.join(ROOT, 'dist')

def load_yaml(path)
  YAML.safe_load(File.read(path, encoding: 'UTF-8'), [Date, Time], [], true) || {}
rescue ArgumentError
  YAML.safe_load(File.read(path, encoding: 'UTF-8'), permitted_classes: [Date, Time], aliases: true) || {}
end

def parse_document(path)
  source = File.read(path, encoding: 'UTF-8')
  match = source.match(/\A---\s*\n(.*?)\n---\s*\n?(.*)\z/m)
  raise "Invalid frontmatter: #{path}" unless match

  data = YAML.safe_load(match[1], [Date, Time], [], true) || {}
  data['body'] = match[2].to_s.strip
  data['source_path'] = path
  data
rescue ArgumentError
  data = YAML.safe_load(match[1], permitted_classes: [Date, Time], aliases: true) || {}
  data['body'] = match[2].to_s.strip
  data['source_path'] = path
  data
end

def h(value)
  CGI.escapeHTML(value.to_s)
end

def plain_text(html)
  CGI.unescapeHTML(html.to_s.gsub(/<[^>]+>/, ' ').gsub(/\s+/, ' ').strip)
end

def format_date(value)
  date = Date.parse(value.to_s)
  "#{date.year}年#{date.month}月#{date.day}日"
rescue ArgumentError
  value.to_s
end

def write_page(path, contents)
  absolute = File.join(DIST, path, 'index.html')
  FileUtils.mkdir_p(File.dirname(absolute))
  File.write(absolute, contents)
end

def nav
  <<~HTML
    <header class="site-header" data-header>
      <div class="header-inner">
        <a class="brand" href="/" aria-label="NCP ホーム"><img src="/uploads/2026/08/260607_ncp_210_297_mm_堤_川上_ロゴ作成_01.png" alt="NCP"></a>
        <button class="menu-button" type="button" aria-expanded="false" aria-controls="site-nav" data-menu-button>
          <span></span><span></span><span></span><span class="sr-only">メニュー</span>
        </button>
        <nav id="site-nav" class="site-nav" data-nav>
          <a href="/soccer/">HOME</a>
          <a href="/news/">NEWS</a>
          <a href="/topic/">TOPIC</a>
          <a href="/we-are/">WE ARE</a>
          <a href="/sns/">SNS</a>
          <a href="/partners/">PARTNERS</a>
          <a class="nav-contact" href="/contact/">CONTACT</a>
        </nav>
      </div>
    </header>
  HTML
end

def footer(site)
  instagram = site['instagram_url'].to_s
  youtube = site['youtube_url'].to_s
  social = []
  social << %(<a href="#{h(instagram)}" target="_blank" rel="noreferrer">Instagram</a>) unless instagram.empty?
  social << %(<a href="#{h(youtube)}" target="_blank" rel="noreferrer">YouTube</a>) unless youtube.empty?
  <<~HTML
    <footer class="site-footer">
      <div>
        <a class="footer-brand" href="/"><img src="/uploads/2026/08/260607_ncp_210_297_mm_堤_川上_ロゴ作成_01.png" alt="NCP"></a>
      </div>
      <div class="footer-links">#{social.join}</div>
      <small>© #{Time.now.year} NCP</small>
    </footer>
    <script src="/assets/main.js" defer></script>
  HTML
end

def layout(site, title:, description:, path:, body:)
  site_name = site['site_name'] || 'NCP'
  full_title = title == site_name ? title : "#{title} | #{site_name}"
  canonical = "https://ncptokyo.net#{path}"
  <<~HTML
    <!doctype html>
    <html lang="ja">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>#{h(full_title)}</title>
      <meta name="description" content="#{h(description)}">
      <link rel="canonical" href="#{h(canonical)}">
      <meta property="og:title" content="#{h(full_title)}">
      <meta property="og:description" content="#{h(description)}">
      <meta property="og:type" content="website">
      <meta property="og:url" content="#{h(canonical)}">
      <link rel="preconnect" href="https://fonts.googleapis.com">
      <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
      <link href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@600;700;800&amp;family=Noto+Sans+JP:wght@400;500;600;700;800&amp;display=swap" rel="stylesheet">
      <link rel="stylesheet" href="/assets/style.css">
    </head>
    <body>
      #{nav}
      <main>#{body}</main>
      #{footer(site)}
    </body>
    </html>
  HTML
end

def portal_layout(site, title:, description:, path:, body:)
  canonical = "https://ncptokyo.net#{path}"
  <<~HTML
    <!doctype html>
    <html lang="ja">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>#{h(title)}</title>
      <meta name="description" content="#{h(description)}">
      <link rel="canonical" href="#{h(canonical)}">
      <meta property="og:title" content="#{h(title)}">
      <meta property="og:description" content="#{h(description)}">
      <meta property="og:type" content="website">
      <meta property="og:url" content="#{h(canonical)}">
      <link rel="preconnect" href="https://fonts.googleapis.com">
      <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
      <link href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@600;700;800&amp;family=Noto+Sans+JP:wght@400;500;600;700;800&amp;display=swap" rel="stylesheet">
      <link rel="stylesheet" href="/assets/style.css">
    </head>
    <body class="portal-page">
      #{body}
    </body>
    </html>
  HTML
end

def card(article, label)
  image = article['image'].to_s
  image_html = image.empty? ? '<div class="card-image card-image--empty"></div>' : %(<img class="card-image" src="#{h(image)}" alt="" loading="lazy">)
  <<~HTML
    <article class="card reveal">
      <a href="/#{h(article['slug'])}/">
        <div class="card-media">#{image_html}<span>#{h(label)}</span></div>
        <div class="card-copy">
          <time datetime="#{h(article['date'])}">#{h(format_date(article['date']))}</time>
          <h3>#{h(article['title'])}</h3>
          <p>#{h(article['excerpt'])}</p>
          <b>READ MORE <i>→</i></b>
        </div>
      </a>
    </article>
  HTML
end

site = load_yaml(File.join(ROOT, 'content', 'site.yml'))
news = Dir[File.join(ROOT, 'content', 'news', '*.md')].map { |path| parse_document(path) }
topics = Dir[File.join(ROOT, 'content', 'topics', '*.md')].map { |path| parse_document(path) }
[news, topics].each do |entries|
  entries.select! { |entry| entry.fetch('published', true) }
  entries.sort_by! { |entry| entry['date'].to_s }
  entries.reverse!
end

FileUtils.rm_rf(DIST)
FileUtils.mkdir_p(File.join(DIST, 'assets'))
FileUtils.cp(File.join(ROOT, 'source', 'style.css'), File.join(DIST, 'assets', 'style.css'))
FileUtils.cp(File.join(ROOT, 'source', 'main.js'), File.join(DIST, 'assets', 'main.js'))
public_files = Dir[File.join(ROOT, 'public', '*')]
FileUtils.cp_r(public_files, DIST) unless public_files.empty?

latest_news = news.first(4).map { |entry| card(entry, 'NEWS') }.join
latest_topics = topics.first(3).map { |entry| card(entry, 'TOPIC') }.join

soccer_body = <<~HTML
  <section class="legacy-hero" aria-label="大会写真">
    <div class="legacy-slider" data-slider>
      <img class="legacy-slide is-active" src="/uploads/2026/09/01_④_ユニックカップ.jpg" alt="第3回ユニックカップ開催案内">
      <img class="legacy-slide" src="/uploads/2026/09/02_①_ユニックカップ.jpg" alt="ユニックカップ試合風景">
      <img class="legacy-slide" src="/uploads/2026/09/02_④_ユニックカップ.jpg" alt="ユニックカップ優勝チーム">
      <img class="legacy-slide" src="/uploads/2026/09/03_②_ユニックカップ.jpg" alt="ユニックカップ大会ダイジェスト">
      <button class="slider-arrow slider-arrow--prev" type="button" data-slide-prev aria-label="前の画像">‹</button>
      <button class="slider-arrow slider-arrow--next" type="button" data-slide-next aria-label="次の画像">›</button>
    </div>
    <div class="slider-thumbs" aria-label="スライドを選択">
      <button class="is-active" type="button" data-slide-to="0"><img src="/uploads/2026/09/01_④_ユニックカップ.jpg" alt=""></button>
      <button type="button" data-slide-to="1"><img src="/uploads/2026/09/02_①_ユニックカップ.jpg" alt=""></button>
      <button type="button" data-slide-to="2"><img src="/uploads/2026/09/02_④_ユニックカップ.jpg" alt=""></button>
      <button type="button" data-slide-to="3"><img src="/uploads/2026/09/03_②_ユニックカップ.jpg" alt=""></button>
    </div>
  </section>

  <section id="event" class="schedule-section">
    <div class="section-title"><h2>EVENT SCHEDULE</h2><p>大会・イベント情報</p></div>
    <div class="schedule-track">
      <article class="schedule-card schedule-card--next"><p class="schedule-label">NEXT EVENT</p><div class="schedule-date"><strong>10.10</strong><span>SAT<br>2026</span></div><h3>第3回ユニックカップ<br>U-9 サッカー大会</h3><p>#{h(site['event_place'])}</p><a href="#{h(site['event_link'])}">大会情報</a></article>
      <article class="schedule-card"><p class="schedule-label">EVENT REPORT</p><div class="schedule-date"><strong>3.28</strong><span>SAT<br>2026</span></div><h3>第2回ユニックカップ</h3><p>Smile Sports Park</p><a href="/第2回ユニック杯開催/">開催レポート</a></article>
      <article class="schedule-card"><p class="schedule-label">EVENT REPORT</p><div class="schedule-date"><strong>5.03</strong><span>SAT<br>2025</span></div><h3>第1回ユニックカップ<br>U-9 サッカー大会</h3><p>フッティーパーク印西</p><a href="/post-2/">開催レポート</a></article>
    </div>
  </section>

  <section class="section home-section">
    <div class="section-title reveal"><h2>NEWS</h2><p>最新のお知らせ</p></div>
    <div class="card-grid">#{latest_news}</div>
    <div class="center"><a class="legacy-button legacy-button--navy" href="/news/">一覧を見る</a></div>
  </section>

  <section class="mission">
    <div class="mission-photo"><img src="/uploads/2026/09/IMG_0879-1.jpg" alt="大会を終えた選手たち" loading="lazy"></div>
    <div class="mission-copy reveal">
      <div class="section-title"><h2>OUR MISSION</h2><p>NCPについて</p></div>
      <h3>サッカーをこよなく愛する少年少女のため</h3>
      <p>イベントの企画・制作・運営を一貫してサポートいたします。<br>各試合の運営や動画・グッズ制作などのお声にお応えいたします。</p>
      <a class="legacy-button legacy-button--navy" href="/we-are/">詳しく見る</a>
    </div>
  </section>

  <section class="section home-section">
    <div class="section-title reveal"><h2>TOPICS</h2><p>人とチームのストーリー</p></div>
    <div class="card-grid">#{latest_topics}</div>
    <div class="center"><a class="legacy-button legacy-button--navy" href="/topic/">一覧を見る</a></div>
  </section>

  <section class="social-section">
    <div><h2><span>|</span> INSTAGRAM</h2><p>大会や活動の様子をInstagramで発信しています。</p><a class="legacy-button" href="#{h(site['instagram_url'])}" target="_blank" rel="noreferrer">Instagramを見る</a></div>
    <div><h2><span>|</span> YOU TUBE</h2><video controls poster="/uploads/2025/10/2025-10-29-21.17.53.jpg"><source src="/uploads/2025/11/サッカーハイライト-３.mp4" type="video/mp4"></video></div>
  </section>
HTML

portal_body = <<~HTML
  <main class="business-portal">
    <header class="portal-header">
      <div><p>NCP BUSINESS</p><h1>事業を選択してください</h1></div>
    </header>
    <div class="business-choices">
      <a class="business-choice business-choice--food" href="/food/">
        <div class="business-choice-logo"><img src="/uploads/2026/09/iburi-logo.png" alt="いぶり 炭火焼鶏"></div>
        <div class="business-choice-copy">
          <span>FOOD BUSINESS</span>
          <h2>飲食事業</h2>
          <p>食を通じて、人と地域がつながる場所をつくる。</p>
          <b>VIEW BUSINESS <i>→</i></b>
        </div>
      </a>
      <a class="business-choice business-choice--soccer" href="/soccer/">
        <div class="business-choice-logo"><img src="/uploads/2026/08/260607_ncp_210_297_mm_堤_川上_ロゴ作成_01.png" alt="NCP"></div>
        <div class="business-choice-copy">
          <span>SOCCER BUSINESS</span>
          <h2>サッカー事業</h2>
          <p>大会・イベントを通じて、子どもたちの挑戦を支える。</p>
          <b>VIEW BUSINESS <i>→</i></b>
        </div>
      </a>
    </div>
    <footer class="portal-footer">© #{Time.now.year} NCP</footer>
  </main>
HTML

food_body = <<~HTML
  <main class="food-placeholder">
    <a class="placeholder-logo placeholder-logo--food" href="/"><img src="/uploads/2026/09/iburi-logo.png" alt="いぶり 炭火焼鶏"></a>
    <div class="placeholder-copy">
      <p>FOOD BUSINESS</p>
      <h1>飲食事業</h1>
      <h2>ただいま準備中です。</h2>
      <p>店舗・サービス情報は、内容が決まり次第こちらでご案内します。</p>
      <a href="/">事業選択へ戻る <span>→</span></a>
    </div>
  </main>
HTML

write_page('', portal_layout(site, title: site['site_name'], description: 'NCPの飲食事業とサッカー事業をご案内します。', path: '/', body: portal_body))
write_page('soccer', layout(site, title: 'サッカー事業', description: site['description'], path: '/soccer/', body: soccer_body))
write_page('food', portal_layout(site, title: "飲食事業 | #{site['site_name']}", description: 'NCPの飲食事業をご案内します。', path: '/food/', body: food_body))

[['news', 'NEWS', news], ['topic', 'TOPIC', topics]].each do |directory, title, entries|
  intro = title == 'NEWS' ? '大会・イベントの最新情報' : 'サッカーを支える人とチームのストーリー'
  body = <<~HTML
    <section class="page-hero"><p class="eyebrow">NCP JOURNAL</p><h1>#{title}</h1><p>#{h(intro)}</p></section>
    <section class="section"><div class="card-grid">#{entries.map { |entry| card(entry, title) }.join}</div></section>
  HTML
  write_page(directory, layout(site, title: title, description: intro, path: "/#{directory}/", body: body))
end

(news + topics).each do |article|
  section = topics.include?(article) ? 'TOPIC' : 'NEWS'
  description = article['excerpt'].to_s.empty? ? plain_text(article['body'])[0, 150] : article['excerpt']
  image = article['image'].to_s
  visual = image.empty? ? '' : %(<img class="article-visual" src="#{h(image)}" alt="" loading="eager">)
  body = <<~HTML
    <article class="article">
      <header class="article-header">
        <a href="/#{section.downcase}/">#{section}</a>
        <time datetime="#{h(article['date'])}">#{h(format_date(article['date']))}</time>
        <h1>#{h(article['title'])}</h1>
      </header>
      #{visual}
      <div class="article-body">#{article['body']}</div>
      <a class="back-link" href="/#{section.downcase}/">← #{section}一覧へ戻る</a>
    </article>
  HTML
  write_page(article['slug'], layout(site, title: article['title'], description: description, path: "/#{article['slug']}/", body: body))
end

about_body = <<~HTML
  <section class="page-hero page-hero--green"><p class="eyebrow">WHO WE ARE</p><h1>WE ARE</h1><p>子どもたちの挑戦が、未来につながる場所をつくる。</p></section>
  <section class="statement">
    <p class="eyebrow">OUR VISION</p>
    <h2>サッカーをこよなく愛する<br>少年少女のために。</h2>
    <p>イベントの企画・制作・運営を一貫してサポートいたします。各試合の運営や動画・グッズ制作など、チームと地域の想いに応えます。</p>
  </section>
HTML
write_page('we-are', layout(site, title: 'WE ARE', description: site['description'], path: '/we-are/', body: about_body))

partners_body = <<~HTML
  <section class="page-hero"><p class="eyebrow">TOGETHER FOR THE FUTURE</p><h1>PARTNERS</h1><p>NCPの活動をともに支えるパートナー。</p></section>
  <section class="partners-section">
    <div class="partners-intro"><p class="eyebrow">OUR PARTNERS</p><h2>ともに、子どもたちの未来を。</h2><p>NCPの大会・イベントは、多くの企業・団体の皆さまに支えられています。</p></div>
    <div class="partner-grid">
      <a class="partner-card" href="https://www.b-aiacademy.com" target="_blank" rel="noreferrer"><img src="/uploads/2025/04/S__45875216_0.jpg" alt="僕のAIアカデミー"><span>WEB SITE ↗</span></a>
      <div class="partner-card"><img src="/uploads/2025/04/S__45875214_0.jpg" alt="竜山口建築"></div>
      <a class="partner-card" href="https://www.instagram.com/brillante.17/" target="_blank" rel="noreferrer"><img src="/uploads/2025/04/ブリランテ.png" alt="BRILLANTE"><span>INSTAGRAM ↗</span></a>
      <a class="partner-card" href="https://shurina.jp/2024/03/11/555/" target="_blank" rel="noreferrer"><img src="/uploads/2025/04/S__45867056_0.jpg" alt="bobororo cinematic restaurant"><span>WEB SITE ↗</span></a>
      <a class="partner-card" href="https://www.cardealer-ism.jp" target="_blank" rel="noreferrer"><img src="/uploads/2025/04/S__45867055_0.jpg" alt="CAR DEALER ISM"><span>WEB SITE ↗</span></a>
      <a class="partner-card" href="https://www.emu-vet.jp" target="_blank" rel="noreferrer"><img src="/uploads/2025/04/S__45875217.png" alt="エム動物病院"><span>WEB SITE ↗</span></a>
      <a class="partner-card" href="https://www.instagram.com/ricefarmreinan?igsh=dDJubTFiaGpwemsx" target="_blank" rel="noreferrer"><img src="/uploads/2025/04/S__45867053_0.png" alt="RICE FARM REINAN"><span>INSTAGRAM ↗</span></a>
    </div>
    <div class="partner-cta"><p>協賛・パートナーシップについて、お気軽にご相談ください。</p><a class="legacy-button legacy-button--navy" href="/contact/">お問い合わせ</a></div>
  </section>
HTML
write_page('partners', layout(site, title: 'PARTNERS', description: 'NCPのパートナー情報', path: '/partners/', body: partners_body))

sns_body = <<~HTML
  <section class="page-hero"><p class="eyebrow">NCP OFFICIAL</p><h1>SNS</h1><p>InstagramとYouTubeで活動の様子をお届けします。</p></section>
  <section class="social-section"><div><h2><span>|</span> INSTAGRAM</h2><a class="legacy-button" href="#{h(site['instagram_url'])}" target="_blank" rel="noreferrer">Instagramを見る</a></div><div><h2><span>|</span> YOU TUBE</h2><video controls poster="/uploads/2025/10/2025-10-29-21.17.53.jpg"><source src="/uploads/2025/11/サッカーハイライト-３.mp4" type="video/mp4"></video></div></section>
HTML
write_page('sns', layout(site, title: 'SNS', description: 'NCP公式SNS', path: '/sns/', body: sns_body))

email = site['contact_email'].to_s
contact_email = email.empty? ? 'info@ncptokyo.net' : email
contact_body = <<~HTML
  <section class="page-hero page-hero--green"><p class="eyebrow">GET IN TOUCH</p><h1>CONTACT</h1><p>大会運営、制作、協賛についてご相談ください。</p></section>
  <section class="contact-section">
    <div class="contact-intro">
      <p class="eyebrow">CONTACT US</p>
      <h2>一緒に、新しい舞台を。</h2>
      <p>イベントの企画・運営、動画やグッズ制作、パートナーシップについて承ります。以下の項目をご入力ください。</p>
      <div class="contact-direct"><span>MAIL</span><a href="mailto:#{h(contact_email)}">#{h(contact_email)}</a></div>
    </div>
    <form class="contact-form" data-contact-form data-contact-email="#{h(contact_email)}">
      <label><span>お名前 <b>必須</b></span><input type="text" name="name" autocomplete="name" required></label>
      <label><span>電話番号</span><input type="tel" name="phone" autocomplete="tel" inputmode="tel"></label>
      <label><span>メールアドレス <b>必須</b></span><input type="email" name="email" autocomplete="email" required></label>
      <label><span>タイトル <b>必須</b></span><input type="text" name="subject" required></label>
      <label><span>お問い合わせ内容 <b>必須</b></span><textarea name="message" rows="8" maxlength="2000" required></textarea></label>
      <button type="submit">メールを作成する <i>→</i></button>
      <p class="form-note">送信ボタンを押すと、ご利用のメールソフトが開きます。</p>
    </form>
  </section>
HTML
write_page('contact', layout(site, title: 'CONTACT', description: 'NCPへのお問い合わせ', path: '/contact/', body: contact_body))

File.write(File.join(DIST, 'robots.txt'), "User-agent: *\nAllow: /\nSitemap: https://ncptokyo.net/sitemap.xml\n")
urls = ['/', '/food/', '/soccer/', '/news/', '/topic/', '/we-are/', '/sns/', '/partners/', '/contact/'] + (news + topics).map { |entry| "/#{entry['slug']}/" }
sitemap = %(<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n) +
          urls.map { |url| "  <url><loc>https://ncptokyo.net#{h(url)}</loc></url>" }.join("\n") +
          "\n</urlset>\n"
File.write(File.join(DIST, 'sitemap.xml'), sitemap)

puts "Built #{urls.length} pages in dist/."
