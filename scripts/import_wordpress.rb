#!/usr/bin/env ruby
# encoding: UTF-8
# frozen_string_literal: true

require 'cgi'
require 'fileutils'
require 'rexml/document'
require 'uri'
require 'yaml'

abort "Usage: ruby scripts/import_wordpress.rb path/to/export.xml" unless ARGV[0]

xml_path = File.expand_path(ARGV[0])
root = File.expand_path('..', __dir__)
xml = REXML::Document.new(File.read(xml_path, encoding: 'UTF-8'))
ns = {
  'wp' => 'http://wordpress.org/export/1.2/',
  'content' => 'http://purl.org/rss/1.0/modules/content/'
}

def node_text(node, path, namespaces = {})
  REXML::XPath.first(node, path, namespaces)&.text.to_s
end

def clean_title(value)
  CGI.unescapeHTML(value.gsub(/<br\s*\/?\s*>/i, ' ').gsub(/<[^>]+>/, '').gsub(/\s+/, ' ').strip)
end

def plain_excerpt(html, limit = 150)
  text = html.gsub(/<!--.*?-->/m, ' ')
             .gsub(/<script.*?<\/script>/mi, ' ')
             .gsub(/<style.*?<\/style>/mi, ' ')
             .gsub(/<[^>]+>/, ' ')
  text = CGI.unescapeHTML(text).gsub(/\s+/, ' ').strip
  text.length > limit ? "#{text[0, limit]}…" : text
end

def yaml_frontmatter(data)
  yaml = data.to_yaml.sub(/\A---\s*\n/, '')
  "---\n#{yaml}---\n"
end

items = REXML::XPath.match(xml, '//item')
attachments = {}

items.each do |item|
  next unless node_text(item, 'wp:post_type', ns) == 'attachment'

  id = node_text(item, 'wp:post_id', ns)
  url = node_text(item, 'wp:attachment_url', ns)
  attachments[id] = url unless url.empty?
end

%w[news topics].each do |directory|
  FileUtils.mkdir_p(File.join(root, 'content', directory))
end
FileUtils.mkdir_p(File.join(root, 'tmp'))

manifest = []
imported = Hash.new(0)

items.each do |item|
  next unless node_text(item, 'wp:post_type', ns) == 'post'
  next unless node_text(item, 'wp:status', ns) == 'publish'

  id = node_text(item, 'wp:post_id', ns)
  title = clean_title(node_text(item, 'title'))
  date = node_text(item, 'wp:post_date', ns)[0, 10]
  raw_slug = node_text(item, 'wp:post_name', ns)
  slug = begin
    URI.decode_www_form_component(raw_slug)
  rescue ArgumentError
    raw_slug
  end
  slug = "post-#{id}" if slug.empty?

  categories = REXML::XPath.match(item, 'category').map { |category| category.text.to_s }
  collection = categories.include?('インタビュー') ? 'topics' : 'news'

  metadata = REXML::XPath.match(item, 'wp:postmeta', ns).each_with_object({}) do |entry, result|
    key = node_text(entry, 'wp:meta_key', ns)
    result[key] = node_text(entry, 'wp:meta_value', ns)
  end
  image_url = attachments[metadata['_thumbnail_id']]
  image_path = image_url&.sub(%r{\Ahttps?://[^/]+/wp-content}, '')

  body = node_text(item, 'content:encoded', ns)
           .gsub(/<!--\s*\/?wp:.*?-->/m, '')
           .gsub(%r{https?://ncptokyo\.net/wp-content}, '')
           .strip

  data = {
    'title' => title,
    'slug' => slug,
    'date' => date,
    'published' => true,
    'excerpt' => plain_excerpt(body),
    'image' => image_path.to_s,
    'legacy_id' => id
  }

  filename = "#{date}-#{id}.md"
  output = File.join(root, 'content', collection, filename)
  File.write(output, yaml_frontmatter(data) + "\n" + body + "\n")
  imported[collection] += 1
end

attachments.each_value do |url|
  relative = url.sub(%r{\Ahttps?://[^/]+/wp-content/}, '')
  manifest << [url, File.join('public', relative)]
end

File.write(
  File.join(root, 'tmp', 'attachments.tsv'),
  manifest.map { |url, destination| "#{url}\t#{destination}" }.join("\n") + "\n"
)

puts "Imported #{imported['news']} NEWS and #{imported['topics']} TOPIC entries."
puts "Wrote #{manifest.length} attachment URLs to tmp/attachments.tsv."
