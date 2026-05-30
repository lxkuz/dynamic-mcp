module Books
  class SectionTreeBuilder
    FlatEntry = Data.define(:title, :plain_text, :depth, :position, :page_start, :page_end)

    def self.build(flat_sections)
      new(flat_sections).build
    end

    def initialize(flat_sections)
      @flat_sections = Array(flat_sections)
    end

    def build
      return [] if @flat_sections.empty?

      roots = []
      stack = []

      @flat_sections.each_with_index do |entry, index|
        depth = entry.depth.to_i
        while stack.any? && stack.last[:depth] >= depth
          stack.pop
        end

        node = {
          title: entry.title,
          plain_text: entry.plain_text.to_s,
          depth: depth,
          position: index,
          page_start: entry.page_start,
          page_end: entry.page_end,
          children: []
        }

        if stack.empty?
          node[:path] = (roots.size + 1).to_s
          roots << node
        else
          parent = stack.last[:node]
          node[:path] = "#{parent[:path]}.#{parent[:children].size + 1}"
          parent[:children] << node
        end

        stack << { depth: depth, node: node }
      end

      roots.map { |node| to_parsed_section(node) }
    end

    private

    def to_parsed_section(node)
      ParsedSection.new(
        title: node[:title],
        plain_text: node[:plain_text],
        depth: node[:depth],
        position: node[:position],
        path: node[:path].to_s,
        page_start: node[:page_start],
        page_end: node[:page_end],
        children: node[:children].map { |child| to_parsed_section(child) }
      )
    end
  end
end
