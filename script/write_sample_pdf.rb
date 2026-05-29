#!/usr/bin/env ruby
# frozen_string_literal: true

stream_data = "BT /F1 18 Tf 72 720 Td (Dynamic MCP PDF sample) Tj ET\n"

objects = []
objects << "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n"
objects << "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n"
objects << "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>\nendobj\n"
objects << "4 0 obj\n<< /Length #{stream_data.bytesize} >>\nstream\n#{stream_data}endstream\nendobj\n"
objects << "5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n"

body = +"%PDF-1.4\n"
offsets = [ 0 ]
objects.each do |object|
  offsets << body.bytesize
  body << object
end

xref_offset = body.bytesize
body << "xref\n0 #{objects.size + 1}\n"
body << "0000000000 65535 f \n"
offsets[1..].each do |offset|
  body << format("%010d 00000 n \n", offset)
end
body << "trailer\n<< /Size #{objects.size + 1} /Root 1 0 R >>\n"
body << "startxref\n#{xref_offset}\n%%EOF\n"

path = File.expand_path("../spec/fixtures/sample.pdf", __dir__)
File.binwrite(path, body)
puts "Wrote #{path} (#{body.bytesize} bytes)"
