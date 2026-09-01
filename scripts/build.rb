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
        <a class="brand" href="/" aria-label="NCP ホーム">NCP<span>FOOTBALL &amp; FUTURE</span></a>
        <button class="menu-button" type="button" aria-expanded="false" aria-controls="site-nav" data-menu-button>
          <span></span><span></span><span></span><span class="sr-only">メニュー</span>
        </button>
        <nav id="site-nav" class="site-nav" data-nav>
          <a href="/">HOME</a>
          <a href="/news/">NEWS</a>
          <a href="/topic/">TOPIC</a>
          <a href="/we-are/">WE ARE</a>
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
        <a class="footer-brand" href="/">NCP</a>
        <p>WE SUPPORT THE FUTURE.</p>
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

latest_news = news.first(3).map { |entry| card(entry, 'NEWS') }.join
latest_topics = topics.first(3).map { |entry| card(entry, 'TOPIC') }.join
hero_image = news.first&.fetch('image', '').to_s
hero_style = hero_image.empty? ? '' : %( style="--hero-image: url('#{h(hero_image)}')")

home_body = <<~HTML
  <section class="hero"#{hero_style}>
    <div class="hero-shape"></div>
    <div class="hero-content reveal">
      <p class="eyebrow">NEXT GENERATION, NEXT CHALLENGE</p>
      <h1>FOOTBALL<br><em>FOR THE FUTURE.</em></h1>
      <p>サッカーを愛する子どもたちへ。<br>記憶に残る体験と、新しい挑戦の舞台を。</p>
    </div>
    <a class="scroll" href="#event">SCROLL<span>↓</span></a>
  </section>

  <section id="event" class="event-band">
    <p class="eyebrow">GAME INFORMATION</p>
    <div>
      <h2>#{h(site['event_title'])}</h2>
      <p><strong>#{h(site['event_date'])}</strong><br>#{h(site['event_place'])}</p>
    </div>
    <a class="button button--light" href="#{h(site['event_link'])}">大会の詳細を見る <span>→</span></a>
  </section>

  <section class="section">
    <div class="section-heading reveal"><p class="eyebrow">LATEST INFORMATION</p><h2>NEWS</h2><a href="/news/">VIEW ALL →</a></div>
    <div class="card-grid">#{latest_news}</div>
  </section>

  <section class="mission">
    <div class="mission-number">09</div>
    <div class="mission-copy reveal">
      <p class="eyebrow">OUR MISSION</p>
      <h2>WE SUPPORT<br>THE <em>FUTURE.</em></h2>
      <p>#{h(site['description'])}</p>
      <a class="button" href="/we-are/">私たちについて <span>→</span></a>
    </div>
  </section>

  <section class="section section--dark">
    <div class="section-heading reveal"><p class="eyebrow">PEOPLE &amp; STORIES</p><h2>TOPIC</h2><a href="/topic/">VIEW ALL →</a></div>
    <div class="card-grid">#{latest_topics}</div>
  </section>
HTML

write_page('', layout(site, title: site['site_name'], description: site['description'], path: '/', body: home_body))

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
  <section class="statement"><p class="eyebrow">PARTNERSHIP</p><h2>子どもたちの未来を、<br>ともにつくりませんか。</h2><p>大会やイベントへの協賛・連携について、お気軽にお問い合わせください。</p><a class="button" href="/contact/">お問い合わせ <span>→</span></a></section>
HTML
write_page('partners', layout(site, title: 'PARTNERS', description: 'NCPのパートナー情報', path: '/partners/', body: partners_body))

email = site['contact_email'].to_s
contact_action = email.empty? ? '<p class="notice">お問い合わせフォームの送信先は公開前に設定します。</p>' : %(<a class="button" href="mailto:#{h(email)}">メールを送る <span>→</span></a>)
contact_body = <<~HTML
  <section class="page-hero page-hero--green"><p class="eyebrow">GET IN TOUCH</p><h1>CONTACT</h1><p>大会運営、制作、協賛についてご相談ください。</p></section>
  <section class="contact-panel"><p class="eyebrow">CONTACT US</p><h2>一緒に、新しい舞台を。</h2><p>イベントの企画・運営、動画やグッズ制作、パートナーシップについて承ります。</p>#{contact_action}</section>
HTML
write_page('contact', layout(site, title: 'CONTACT', description: 'NCPへのお問い合わせ', path: '/contact/', body: contact_body))

File.write(File.join(DIST, 'robots.txt'), "User-agent: *\nAllow: /\nSitemap: https://ncptokyo.net/sitemap.xml\n")
urls = ['/', '/news/', '/topic/', '/we-are/', '/partners/', '/contact/'] + (news + topics).map { |entry| "/#{entry['slug']}/" }
sitemap = %(<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n) +
          urls.map { |url| "  <url><loc>https://ncptokyo.net#{h(url)}</loc></url>" }.join("\n") +
          "\n</urlset>\n"
File.write(File.join(DIST, 'sitemap.xml'), sitemap)

puts "Built #{urls.length} pages in dist/."
