#!/usr/bin/env ruby
# encoding: UTF-8
# frozen_string_literal: true

require 'cgi'
require 'date'
require 'fileutils'
require 'find'
require 'rexml/document'
require 'uri'
require 'yaml'

ROOT = File.expand_path('..', __dir__)
DIST = File.join(ROOT, 'dist')
MAX_STATIC_FILE_SIZE = 25 * 1024 * 1024
COPYRIGHT_YEAR = '2025'
FOOD_COPYRIGHT_YEAR = '2026'
LOGO_PATH = '/uploads/2026/08/260607_ncp_210_297_mm_堤_川上_ロゴ作成_01.png'
ALLOWED_CONTENT_ELEMENTS = %w[
  a b blockquote br div em figcaption figure h2 h3 h4 i img li mark ol p s span strong
  table tbody td th thead tr ul
].freeze
GLOBAL_CONTENT_ATTRIBUTES = %w[aria-hidden class data-align title].freeze
CONTENT_ATTRIBUTES = {
  'a' => %w[href rel target],
  'img' => %w[alt height loading src width],
  'td' => %w[colspan rowspan],
  'th' => %w[colspan rowspan scope]
}.freeze
PARTNERS = [
  { name: '僕のAIアカデミー', image: '/uploads/2025/04/S__45875216_0.jpg', url: 'https://www.b-aiacademy.com', label: 'WEB SITE ↗' },
  { name: '竜山口建築', image: '/uploads/2025/04/S__45875214_0.jpg' },
  { name: 'BRILLANTE', image: '/uploads/2025/04/ブリランテ.png', url: 'https://www.instagram.com/brillante.17/', label: 'INSTAGRAM ↗' },
  { name: 'bobororo cinematic restaurant', image: '/uploads/2025/04/S__45867056_0.jpg', url: 'https://shurina.jp/2024/03/11/555/', label: 'WEB SITE ↗' },
  { name: 'CAR DEALER ISM', image: '/uploads/2025/04/S__45867055_0.jpg', url: 'https://www.cardealer-ism.jp', label: 'WEB SITE ↗' },
  { name: 'エム動物病院', image: '/uploads/2025/04/S__45875217.png', url: 'https://www.emu-vet.jp', label: 'WEB SITE ↗' },
  { name: 'RICE FARM REINAN', image: '/uploads/2025/04/S__45867053_0.png', url: 'https://www.instagram.com/ricefarmreinan?igsh=dDJubTFiaGpwemsx', label: 'INSTAGRAM ↗' }
].freeze

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
  data['body'] = sanitize_article_html(match[2].to_s.strip, path)
  data['source_path'] = path
  data
rescue ArgumentError
  data = YAML.safe_load(match[1], permitted_classes: [Date, Time], aliases: true) || {}
  data['body'] = sanitize_article_html(match[2].to_s.strip, path)
  data['source_path'] = path
  data
end

def h(value)
  CGI.escapeHTML(value.to_s)
end

def safe_link?(value)
  link = CGI.unescapeHTML(value.to_s).strip
  return false if link.empty? || link.include?("\0") || link.include?('\\') || link.start_with?('//')
  return true if link.start_with?('/', '#')

  uri = URI.parse(link)
  scheme = uri.scheme&.downcase
  %w[http https mailto tel].include?(scheme) && (%w[mailto tel].include?(scheme) || !uri.host.to_s.empty?)
rescue URI::InvalidURIError
  false
end

def safe_asset_path?(value)
  path = value.to_s
  path.start_with?('/uploads/') && !path.include?("\0") && !path.include?('\\') && !path.split('/').include?('..')
end

def external_url(value, field_name)
  url = value.to_s.strip
  uri = URI.parse(url)
  valid = %w[http https].include?(uri.scheme&.downcase) && !uri.host.to_s.empty? && !url.include?("\0")
  raise "Invalid #{field_name}: #{value.inspect}" unless valid

  url
rescue URI::InvalidURIError
  raise "Invalid #{field_name}: #{value.inspect}"
end

def contact_email(value)
  email = value.to_s.strip
  email = 'info@ncptokyo.net' if email.empty?
  raise "Invalid contact_email: #{value.inspect}" unless email.length <= 254 && email.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)

  email
end

def article_asset(value, field_name)
  path = value.to_s.strip
  return '' if path.empty?
  raise "Invalid #{field_name}: #{value.inspect}" unless safe_asset_path?(path)

  absolute = File.join(ROOT, 'public', path.delete_prefix('/'))
  raise "Missing #{field_name}: #{path}" unless File.file?(absolute)

  path
end

def validate_articles!(articles)
  reserved_paths = %w[assets contact food news partners soccer sns topic uploads we-are]
  slugs = articles.map { |article| article['slug'].to_s.strip }
  raise 'Every article requires a slug.' if slugs.any?(&:empty?)
  invalid_slugs = slugs.reject { |slug| slug.length <= 100 && slug.match?(/\A[\p{L}\p{N}_\-！]+\z/u) }
  raise "Invalid article slugs: #{invalid_slugs.join(', ')}" unless invalid_slugs.empty?

  duplicates = slugs.group_by(&:itself).select { |_slug, values| values.length > 1 }.keys
  raise "Duplicate article slugs: #{duplicates.join(', ')}" unless duplicates.empty?

  conflicts = slugs & reserved_paths
  raise "Article slugs conflict with site pages: #{conflicts.join(', ')}" unless conflicts.empty?
end

def sanitize_article_html(html, source_path)
  normalized = html.gsub(/<br\s*>/i, '<br/>')
  document = REXML::Document.new("<root>#{normalized}</root>")

  REXML::XPath.each(document, '//*') do |element|
    next if element.name == 'root'
    raise "Unsafe HTML element <#{element.name}> in #{source_path}" unless ALLOWED_CONTENT_ELEMENTS.include?(element.name)

    allowed_attributes = GLOBAL_CONTENT_ATTRIBUTES + CONTENT_ATTRIBUTES.fetch(element.name, [])
    element.attributes.each_attribute.to_a.each do |attribute|
      element.delete_attribute(attribute.name) unless allowed_attributes.include?(attribute.name)
    end

    if element.name == 'a'
      if safe_link?(element.attributes['href'])
        if element.attributes['target'] == '_blank'
          element.attributes['rel'] = 'noopener noreferrer'
        else
          element.delete_attribute('target')
          element.delete_attribute('rel')
        end
      else
        element.delete_attribute('href')
        element.delete_attribute('target')
        element.delete_attribute('rel')
      end
    elsif element.name == 'img' && !safe_asset_path?(element.attributes['src'])
      raise "Unsafe image path in #{source_path}: #{element.attributes['src']}"
    end
  end

  document.root.children.map(&:to_s).join.strip
rescue REXML::ParseException => e
  raise "Invalid article HTML in #{source_path}: #{e.message.lines.first.to_s.strip}"
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
  relative = path.to_s
  segments = relative.split('/')
  invalid = relative.start_with?('/') || relative.include?("\0") || relative.include?('\\') || segments.any? { |segment| segment.empty? || %w[. ..].include?(segment) }
  raise "Unsafe output path: #{relative.inspect}" if invalid && !relative.empty?

  absolute = File.expand_path(File.join(DIST, relative, 'index.html'))
  raise "Output path escaped dist: #{relative.inspect}" unless absolute.start_with?("#{File.expand_path(DIST)}#{File::SEPARATOR}")

  FileUtils.mkdir_p(File.dirname(absolute))
  File.write(absolute, contents)
end

def copy_public_tree(source, destination)
  skipped = []
  Find.find(source) do |path|
    relative = path.delete_prefix("#{source}/")
    next if relative.empty?
    if File.basename(path).start_with?('.')
      Find.prune if File.directory?(path)
      next
    end
    raise "Symbolic links are not allowed in public/: #{relative}" if File.symlink?(path)

    target = File.join(destination, relative)
    if File.directory?(path)
      FileUtils.mkdir_p(target)
    elsif File.size(path) > MAX_STATIC_FILE_SIZE
      skipped << relative
    else
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(path, target)
    end
  end
  skipped
end

def nav
  <<~HTML
    <header class="site-header" data-header>
      <div class="header-inner">
        <a class="brand" href="/soccer/" aria-label="サッカー事業 ホーム"><img src="#{LOGO_PATH}" alt="NCP"></a>
        <a class="business-top-link" href="/" aria-label="事業選択トップへ戻る"><span aria-hidden="true">←</span> 事業TOP</a>
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
  instagram = external_url(site['instagram_url'], 'instagram_url')
  youtube = external_url(site['youtube_url'], 'youtube_url')
  social = []
  unless instagram.empty?
    social << %(<a class="footer-social-icon" href="#{h(instagram)}" target="_blank" rel="noopener noreferrer" aria-label="Instagram"><svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="3" width="18" height="18" rx="5"></rect><circle cx="12" cy="12" r="4.2"></circle><circle class="icon-dot" cx="17.5" cy="6.7" r="1.1"></circle></svg></a>)
  end
  unless youtube.empty?
    social << %(<a class="footer-social-icon" href="#{h(youtube)}" target="_blank" rel="noopener noreferrer" aria-label="YouTube"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M21.2 7.1c-.2-1.3-1.2-2.3-2.5-2.5C16.9 4.3 14.7 4.2 12 4.2s-4.9.1-6.7.4C4 4.8 3 5.8 2.8 7.1 2.5 8.5 2.4 10.1 2.4 12s.1 3.5.4 4.9c.2 1.3 1.2 2.3 2.5 2.5 1.8.3 4 .4 6.7.4s4.9-.1 6.7-.4c1.3-.2 2.3-1.2 2.5-2.5.3-1.4.4-3 .4-4.9s-.1-3.5-.4-4.9Z"></path><path class="icon-play" d="m10 8.5 5.5 3.5-5.5 3.5Z"></path></svg></a>)
  end
  <<~HTML
    <footer class="site-footer">
      <div>
        <a class="footer-brand" href="/soccer/"><img src="#{LOGO_PATH}" alt="NCP"></a>
      </div>
      <div class="footer-links">#{social.join}</div>
      <small>© #{COPYRIGHT_YEAR} NCP</small>
    </footer>
    <script src="/assets/main.js" defer></script>
  HTML
end

def social_section(site)
  instagram_url = external_url(site['instagram_url'], 'instagram_url')
  youtube_url = external_url(site['youtube_url'], 'youtube_url')
  <<~HTML
    <section class="social-section">
      <div class="social-panel social-panel--instagram">
        <h2>INSTAGRAM</h2>
        <p>最新の投稿をInstagramからお届けします。</p>
        <div class="instagram-profile-crop">
          <iframe class="instagram-profile-embed" src="https://www.instagram.com/ncptokyo.net_official/embed/" title="NCP TOKYO Instagram 最新投稿" loading="lazy" scrolling="no" allowtransparency="true"></iframe>
        </div>
        <a class="social-link" href="#{h(instagram_url)}" target="_blank" rel="noopener noreferrer">Instagramでもっと見る <span>→</span></a>
      </div>
      <div class="social-panel social-panel--youtube">
        <h2>YOUTUBE</h2>
        <p>NCPの大会・活動動画をご覧いただけます。</p>
        <div class="youtube-embed">
          <iframe src="https://www.youtube-nocookie.com/embed/ZHj4lp83VuA?start=1&amp;rel=0" title="NCP TOKYO YouTube動画" loading="lazy" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>
        </div>
        <a class="social-link" href="#{h(youtube_url)}" target="_blank" rel="noopener noreferrer">YouTubeチャンネルを見る <span>→</span></a>
      </div>
    </section>
  HTML
end

def partner_logo(partner, class_name: nil, show_label: false)
  image = %(<img src="#{h(partner[:image])}" alt="#{h(partner[:name])}">)
  label = show_label && partner[:label] ? %(<span>#{h(partner[:label])}</span>) : ''
  css_class = class_name ? %( class="#{h(class_name)}") : ''
  return %(<div#{css_class}>#{image}#{label}</div>) unless partner[:url]

  url = external_url(partner[:url], "partner URL for #{partner[:name]}")
  %(<a#{css_class} href="#{h(url)}" target="_blank" rel="noopener noreferrer">#{image}#{label}</a>)
end

def partner_logos(class_name: nil, show_labels: false)
  PARTNERS.map { |partner| partner_logo(partner, class_name: class_name, show_label: show_labels) }.join("\n")
end

def document_head(title:, description:, path:)
  canonical = "https://ncptokyo.net#{path}"
  <<~HTML
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
  HTML
end

def layout(site, title:, description:, path:, body:)
  site_name = site['site_name'] || 'NCP'
  full_title = title == site_name ? title : "#{title} | #{site_name}"
  <<~HTML
    <!doctype html>
    <html lang="ja">
    #{document_head(title: full_title, description: description, path: path)}
    <body>
      #{nav}
      <main>#{body}</main>
      #{footer(site)}
    </body>
    </html>
  HTML
end

def portal_layout(title:, description:, path:, body:)
  <<~HTML
    <!doctype html>
    <html lang="ja">
    #{document_head(title: title, description: description, path: path)}
    <body class="portal-page">
      #{body}
    </body>
    </html>
  HTML
end

def food_layout(title:, description:, body:)
  canonical = 'https://ncptokyo.net/food/'
  <<~HTML
    <!doctype html>
    <html lang="ja">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>#{h(title)}</title>
      <meta name="description" content="#{h(description)}">
      <link rel="canonical" href="#{canonical}">
      <meta property="og:title" content="#{h(title)}">
      <meta property="og:description" content="#{h(description)}">
      <meta property="og:type" content="website">
      <meta property="og:url" content="#{canonical}">
      <link rel="stylesheet" href="/assets/food.css">
      <script src="/assets/food.js"></script>
    </head>
    <body>
      #{body}
    </body>
    </html>
  HTML
end

def card(article, label)
  image = article_asset(article['image'], "image for #{article['source_path']}")
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
validate_articles!(news + topics)

FileUtils.rm_rf(DIST)
FileUtils.mkdir_p(File.join(DIST, 'assets'))
FileUtils.cp(File.join(ROOT, 'source', 'style.css'), File.join(DIST, 'assets', 'style.css'))
FileUtils.cp(File.join(ROOT, 'source', 'main.js'), File.join(DIST, 'assets', 'main.js'))
FileUtils.cp(File.join(ROOT, 'source', 'food.css'), File.join(DIST, 'assets', 'food.css'))
FileUtils.cp(File.join(ROOT, 'source', 'food.js'), File.join(DIST, 'assets', 'food.js'))
public_root = File.join(ROOT, 'public')
skipped_large_files = Dir.exist?(public_root) ? copy_public_tree(public_root, DIST) : []

event_link = site['event_link'].to_s
raise "Invalid event_link: #{event_link.inspect}" unless safe_link?(event_link)

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
      <article class="schedule-card schedule-card--next"><p class="schedule-label">NEXT EVENT</p><div class="schedule-date"><strong>10.10</strong><span>SAT<br>2026</span></div><h3>第3回ユニックカップ<br>U-9 サッカー大会</h3><p>#{h(site['event_place'])}</p><a href="#{h(event_link)}">大会情報</a></article>
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

  #{social_section(site)}

  <section class="home-partners" aria-labelledby="home-partners-title">
    <h2 id="home-partners-title">PARTNERS</h2>
    <div class="home-partner-grid">
      #{partner_logos}
    </div>
    <a class="home-partners-more" href="/partners/">MORE PARTNERS <span>→</span></a>
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
        <div class="business-choice-logo"><img src="#{LOGO_PATH}" alt="NCP"></div>
        <div class="business-choice-copy">
          <span>SOCCER BUSINESS</span>
          <h2>サッカー事業</h2>
          <p>大会・イベントを通じて、子どもたちの挑戦を支える。</p>
          <b>VIEW BUSINESS <i>→</i></b>
        </div>
      </a>
    </div>
    <footer class="portal-footer">© #{COPYRIGHT_YEAR} NCP</footer>
  </main>
HTML

food_body = <<~HTML
  <header>
    <a href="#top"><img src="/food-assets/logo.png" alt="炭火焼鶏 いぶり"></a>
    <a class="portal-return" href="/">← 事業TOP</a>
    <nav><a href="#craft">こだわり</a><a href="#menu">メニュー</a><a href="#scene">炭火焼</a><a href="#contact">お問い合わせ</a></nav>
  </header>
  <main id="top">
    <section class="hero"><video autoplay muted loop playsinline poster="/food-assets/fire.jpg"><source src="/food-assets/hero.mp4" type="video/mp4"></video><div class="shade"></div><div class="hero-copy"><p class="kicker">SUMIBI YAKITORI FOOD TRUCK</p><h1><span class="hero-line">銘柄鶏、昆布と塩、炭。</span><strong>以上。</strong></h1><p>選ぶ。味を引き出す。炭で焼く。<br>いぶりの炭火焼鶏。</p><a href="#menu">メニューを見る</a></div></section>
    <section id="craft" class="craft reveal"><div class="craft-copy"><p class="en">KODAWARI</p><h2>こだわり</h2><p>銘柄鶏、昆布だしと塩、そして炭。素材の持ち味をまっすぐに引き出す、いぶりの三つの軸です。</p><p class="note">※使用する銘柄鶏は出店地域・仕入れ状況により異なる場合があります。現在は群馬県の「赤城鶏」を採用候補として調整中です。</p></div><img src="/food-assets/charcoal.jpg" alt="赤く熾った炭"></section>
    <section class="pillars" aria-label="いぶりの3つのこだわり"><article class="pillar-chicken"><div class="pillar-visual"><img src="/food-assets/image3.jpg" alt="銘柄鶏のイメージ"></div><b>01</b><h3>銘柄鶏</h3><p>現在採用を調整しているのは、群馬県の銘柄鶏「赤城鶏」。植物性主体の飼料や平飼いなど、丁寧な飼育管理のもと育てられた鶏です。脂身が少なく引き締まった肉質を、炭火で香ばしく仕上げます。</p></article><article class="pillar-seasoning"><div class="seasoning-mark"><span>昆布</span><i>＋</i><span>塩</span></div><b>02</b><h3>昆布だしと塩</h3><p>味付けは、昆布だしと塩だけ。調味料そのものも無添加にこだわり、余計な味を重ねず、鶏の旨みをまっすぐ引き出します。</p></article><article class="pillar-charcoal"><div class="ember-visual"><img src="/food-assets/charcoal.jpg" alt="赤く熾った炭"></div><b>03</b><h3>炭</h3><p>焼き上げに使うのは、厳選した備長炭。力強い火力で表面を香ばしく焼き、炭火ならではの香りをまとわせます。いぶりの味を最後に仕上げる、大切な火です。</p></article><p class="craft-closing">すべては、鶏を旨くするために。</p></section>
    <section id="menu" class="menu section-rule"><div class="title reveal"><p class="en">MENU</p><h2>お品書き</h2><p>串には刺さず、炭火で焼いた鶏をパックで。<br>味付けはすべて、昆布だしと塩だけ。</p></div><div class="menu-board" aria-label="いぶりのお品書き"><div class="menu-card"><img src="/food-assets/menu-breast.jpg" alt="炭火で焼いたむね肉"><div class="menu-card-copy"><span>あっさり、しっとり。</span><h3>むね肉</h3><p>やわらかな食感と上品な旨み。シンプルな味付けだからこそ、鶏本来の味を楽しめます。</p></div></div><div class="menu-card"><img src="/food-assets/menu-thigh.jpg" alt="炭火で焼いたもも肉"><div class="menu-card-copy"><span>ジューシーな旨み。</span><h3>もも肉</h3><p>ほどよい脂と濃厚な旨み。炭火の香ばしさが、もも肉のおいしさを引き立てます。</p></div></div><div class="menu-card"><img src="/food-assets/menu-mix.jpg" alt="炭火で焼いたむね肉ともも肉のミックス"><div class="menu-card-copy"><span>ふたつのおいしさ。</span><h3>ミックス</h3><p>むね肉ともも肉を一度に。どちらも楽しみたい方におすすめの一品です。</p></div></div></div></section>
    <section id="scene" class="scene"><div class="scene-copy reveal"><p class="en">SUMIBI</p><h2>目の前の炭と、<br>向き合って焼く。</h2><p>火力も、煙も、その日の炭の状態も同じではありません。網の上の鶏を見ながら、炭火ならではの香りと焼き目をまとわせます。</p></div><div class="photos"><img src="/food-assets/grilling1.jpg" alt="炭火で鶏を焼く様子"><img src="/food-assets/grilling2.jpg" alt="キッチンカーで炭火焼をする様子"><img src="/food-assets/fire.jpg" alt="炎が上がる炭火焼"></div></section>
    <section id="contact" class="contact reveal"><img src="/food-assets/logo.png" alt="いぶり"><h2>炭火の香りを、街角へ。</h2><p>出店情報・イベント出店・フランチャイズについての情報は、順次こちらでお知らせします。</p><a href="mailto:#{h(contact_email(site['contact_email']))}?subject=#{CGI.escape('いぶりへのお問い合わせ')}">お問い合わせ</a></section>
  </main>
  <footer>© #{FOOD_COPYRIGHT_YEAR} 炭火焼鶏 いぶり</footer>
HTML

write_page('', portal_layout(title: site['site_name'], description: 'NCPの飲食事業とサッカー事業をご案内します。', path: '/', body: portal_body))
write_page('soccer', layout(site, title: 'サッカー事業', description: site['description'], path: '/soccer/', body: soccer_body))
write_page('food', food_layout(title: "炭火焼鶏 いぶり | #{site['site_name']}", description: '銘柄鶏を昆布だしと塩だけで味付けし、炭火で焼き上げるキッチンカー「いぶり」。', body: food_body))

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
  image = article_asset(article['image'], "image for #{article['source_path']}")
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
      #{partner_logos(class_name: 'partner-card', show_labels: true)}
    </div>
    <div class="partner-cta"><p>協賛・パートナーシップについて、お気軽にご相談ください。</p><a class="legacy-button legacy-button--navy" href="/contact/">お問い合わせ</a></div>
  </section>
HTML
write_page('partners', layout(site, title: 'PARTNERS', description: 'NCPのパートナー情報', path: '/partners/', body: partners_body))

sns_body = <<~HTML
  <section class="page-hero"><p class="eyebrow">NCP OFFICIAL</p><h1>SNS</h1><p>InstagramとYouTubeで活動の様子をお届けします。</p></section>
  #{social_section(site)}
HTML
write_page('sns', layout(site, title: 'SNS', description: 'NCP公式SNS', path: '/sns/', body: sns_body))

contact_email = contact_email(site['contact_email'])
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
      <label><span>お名前 <b>必須</b></span><input type="text" name="name" autocomplete="name" maxlength="100" required></label>
      <label><span>電話番号</span><input type="tel" name="phone" autocomplete="tel" inputmode="tel" maxlength="30"></label>
      <label><span>メールアドレス <b>必須</b></span><input type="email" name="email" autocomplete="email" maxlength="254" required></label>
      <label><span>タイトル <b>必須</b></span><input type="text" name="subject" maxlength="150" required></label>
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

unless skipped_large_files.empty?
  generated_files = Dir[File.join(DIST, '**', '*.{html,css,js,xml,txt}')]
  referenced_large_files = skipped_large_files.select do |path|
    needle = "/#{path}".b
    generated_files.any? { |generated_path| File.binread(generated_path).include?(needle) }
  end
  raise "Oversized static files are referenced by generated pages: #{referenced_large_files.join(', ')}" unless referenced_large_files.empty?

  warn "Skipped #{skipped_large_files.length} unused files larger than 25 MiB: #{skipped_large_files.join(', ')}"
end

puts "Built #{urls.length} pages in dist/."
