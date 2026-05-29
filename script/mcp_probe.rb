#!/usr/bin/env ruby
# frozen_string_literal: true

# Probe MCP via SSE on the web port (same process as Rails).
# Usage: BOOK_UID=... BASE_URL=http://127.0.0.1:3000 ruby script/mcp_probe.rb

require "json"
require "net/http"
require "uri"

book_uid = ENV.fetch("BOOK_UID")
base_url = ENV.fetch("BASE_URL", "http://127.0.0.1:3000").chomp("/")
SSE = "#{base_url}/books/#{book_uid}/mcp/sse"
MSG = "#{base_url}/books/#{book_uid}/mcp/messages"

queue = Queue.new
stop = false

Thread.new do
  uri = URI(SSE)
  Net::HTTP.start(uri.host, uri.port) do |http|
    req = Net::HTTP::Get.new(uri)
    req["Accept"] = "text/event-stream"
    http.request(req) do |res|
      buf = +""
      res.read_body do |chunk|
        buf << chunk
        while buf.include?("\n\n")
          block, buf = buf.split("\n\n", 2)
          data = block.lines.filter_map { |line| line.delete_prefix("data: ").strip if line.start_with?("data: ") }.join
          unless data.empty? || data.start_with?("/")
            begin
              queue << JSON.parse(data)
            rescue JSON::ParserError
              nil
            end
          end
        end
        break if stop
      end
    end
  end
end

sleep 1

def rpc(queue, url, method, params, id)
  body = { jsonrpc: "2.0", id: id, method: method }
  body[:params] = params if params
  Net::HTTP.post(URI(url), body.to_json, "Content-Type" => "application/json")

  12.times do
    sleep 0.5
    begin
      loop do
        msg = queue.pop(true)
        return msg if msg["id"] == id
      end
    rescue ThreadError
      nil
    end
  end
  nil
end

rpc(queue, MSG, "initialize", { protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: "probe", version: "1" } }, 1)
Net::HTTP.post(URI(MSG), { jsonrpc: "2.0", method: "notifications/initialized", params: {} }.to_json, "Content-Type" => "application/json")

result = rpc(queue, MSG, "tools/call", { name: "book_info", arguments: {} }, 2)
puts "book_info:"
puts JSON.pretty_generate(result)

page_result = rpc(queue, MSG, "tools/call", { name: "get_page", arguments: { number: 1 } }, 3)
puts "get_page:"
puts JSON.pretty_generate(page_result)

stop = true
