#!/usr/bin/env ruby
# encoding: UTF-8
# frozen_string_literal: true

require 'fileutils'
require 'net/http'
require 'uri'

root = File.expand_path('..', __dir__)
manifest_path = File.join(root, 'tmp', 'attachments.tsv')
abort 'Run scripts/import_wordpress.rb first.' unless File.exist?(manifest_path)

success = 0
failed = []

File.foreach(manifest_path, chomp: true, encoding: 'UTF-8') do |line|
  url, relative_destination = line.split("\t", 2)
  next if url.to_s.empty? || relative_destination.to_s.empty?

  destination = File.join(root, relative_destination)
  next success += 1 if File.exist?(destination) && File.size(destination).positive?

  FileUtils.mkdir_p(File.dirname(destination))
  begin
    uri = URI.parse(URI::DEFAULT_PARSER.escape(url))
    response = Net::HTTP.get_response(uri)
    raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

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
