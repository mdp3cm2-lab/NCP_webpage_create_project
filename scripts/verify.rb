#!/usr/bin/env ruby
# encoding: UTF-8
# frozen_string_literal: true

require 'cgi'
require 'uri'

root = File.expand_path('..', __dir__)
dist = File.join(root, 'dist')
abort 'Run ruby scripts/build.rb first.' unless Dir.exist?(dist)

failures = []
html_files = Dir[File.join(dist, '**', '*.html')]

html_files.each do |file|
  html = File.read(file, encoding: 'UTF-8')
  relative_file = file.delete_prefix("#{dist}/")

  failures << "#{relative_file}: inline event handler" if html.match?(/\son[a-z]+\s*=/i)
  failures << "#{relative_file}: javascript URL" if html.match?(/javascript\s*:/i)

  html.scan(/\b(?:href|poster|src)=(['"])(\/uploads\/.*?)\1/i).each do |_quote, asset_url|
    failures << "#{relative_file}: non-ASCII upload URL #{asset_url}" unless asset_url.ascii_only?
  end

  html.scan(/<[^>]+\starget=(['"])_blank\1[^>]*>/i) do
    tag = Regexp.last_match(0)
    rel = tag[/\srel=(['"])(.*?)\1/i, 2].to_s.split
    failures << "#{relative_file}: target=_blank without noopener noreferrer" unless %w[noopener noreferrer].all? { |value| rel.include?(value) }
  end

  html.scan(/\s(?:href|src)=(['"])(.*?)\1/i).each do |_quote, raw_url|
    url = CGI.unescapeHTML(raw_url).split(/[?#]/, 2).first
    next unless url.start_with?('/') && !url.start_with?('//')

    decoded = URI::DEFAULT_PARSER.unescape(url).delete_prefix('/')
    target = if decoded.empty?
               File.join(dist, 'index.html')
             elsif decoded.end_with?('/')
               File.join(dist, decoded, 'index.html')
             else
               File.join(dist, decoded)
             end
    failures << "#{relative_file}: missing internal target #{url}" unless File.exist?(target)
  end
end

headers_path = File.join(dist, '_headers')
if File.file?(headers_path)
  headers = File.read(headers_path, encoding: 'UTF-8')
  %w[Content-Security-Policy Permissions-Policy Referrer-Policy Strict-Transport-Security X-Content-Type-Options].each do |header|
    failures << "_headers: missing #{header}" unless headers.include?("#{header}:")
  end
else
  failures << 'missing dist/_headers'
end

oversized = Dir[File.join(dist, '**', '*')].select { |file| File.file?(file) && File.size(file) > 25 * 1024 * 1024 }
failures.concat(oversized.map { |file| "oversized output: #{file.delete_prefix("#{dist}/")}" })

abort failures.join("\n") unless failures.empty?
puts "Verified #{html_files.length} HTML pages: links, assets, headers, and output sizes are valid."
