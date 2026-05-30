module Books
  ParsedSection = Data.define(:title, :plain_text, :depth, :position, :path, :children, :page_start, :page_end)
end
