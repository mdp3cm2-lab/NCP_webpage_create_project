#!/usr/bin/env ruby
# encoding: UTF-8
# frozen_string_literal: true

require 'fileutils'
require 'net/http'
require 'uri'

root = File.expand_path('..', __dir__)
manifest_path = File.join(root, 'tmp', 'attachments.tsv')
public_root = File.join(root, 'public')
max_download_size = 100 * 1024 * 1024
abort 'Run scripts/import_wordpress.rb first.' unless File.exist?(manifest_path)

success = 0
failed = []

File.foreach(manifest_path, chomp: true, encoding: 'UTF-8') do |line|
  url, relative_destination = line.split("\t", 2)
  next if url.to_s.empty? || relative_destination.to_s.empty?

  destination = File.expand_path(relative_destination, root)
  allowed_extensions = %w[.avif .gif .jpeg .jpg .mp4 .pdf .png .webm .webp]
  unless destination.start_with?("#{public_root}#{File::SEPARATOR}") && allowed_extensions.include?(File.extname(destination).downcase)
    failed << [url, 'destination path or file type is not allowed']
    next
  end
  next success += 1 if File.exist?(destination) && File.size(destination).positive?

  FileUtils.mkdir_p(File.dirname(destination))
  begin
    uri = URI.parse(URI::DEFAULT_PARSER.escape(url))
    unless %w[http https].include?(uri.scheme&.downcase) && %w[ncptokyo.net www.ncptokyo.net].include?(uri.host&.downcase)
      raise 'URL host or scheme is not allowed'
    end

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.open_timeout = 10
    http.read_timeout = 30
    response = http.get(uri.request_uri)
    raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    raise 'download exceeds 100 MiB' if response.body.bytesize > max_download_size

    File.binwrite(destination, response.body)
    success += 1
    puts "Downloaded #{relative_destination}"
  rescue StandardError => e
    failed << [url, e.message]
    warn "Failed #{url}: #{e.message}"
  end
end

puts "Media ready: #{success}; failed: #{failed.length}"
exit 1 unless failed.empty?
