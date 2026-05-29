module Fb2
  class Parser
    TEXT_TAGS = %w[p v subtitle text emphasis strong emphasis style].freeze

    def self.parse(io)
      new(io).parse
    end

    def self.paginate(text, chars_per_page: Book::CHARS_PER_PAGE)
      Books::TextPaginator.paginate(text, chars_per_page: chars_per_page)
    end

    def initialize(io)
      @doc = Nokogiri::XML(io)
      @doc.remove_namespaces!
    end

    def parse
      body = main_body
      Books::ParsedDocument.new(
        title: book_title,
        author: book_author,
        sections: build_sections(body),
        reading_text: extract_reading_text(body),
        pages: nil
      )
    end

    private

    def main_body
      bodies = @doc.xpath("//body")
      bodies.find { |node| node["name"].to_s.strip.empty? } || bodies.first
    end

    def book_title
      @doc.at_xpath("//description/title-info/book-title")&.text&.strip.presence ||
        @doc.at_xpath("//description/title-info/genre")&.text&.strip.presence ||
        "Untitled"
    end

    def book_author
      author_node = @doc.at_xpath("//description/title-info/author")
      return "" unless author_node

      parts = author_node.element_children.map { |child| child.text.strip }.reject(&:blank?)
      parts.join(" ").presence || author_node.text.strip
    end

    def build_sections(body_node)
      return [] unless body_node

      body_node.xpath("./section").map.with_index do |section_node, index|
        build_section_node(section_node, depth: 0, position: index, path_parts: [])
      end
    end

    def build_section_node(node, depth:, position:, path_parts:)
      title = extract_title(node)
      path = (path_parts + [ title.presence || "Без названия" ]).join(" > ")
      children_nodes = node.xpath("./section")
      own_text = collect_section_text(node, skip_sections: children_nodes)

      children = children_nodes.map.with_index do |child, index|
        build_section_node(child, depth: depth + 1, position: index, path_parts: path_parts + [ title ])
      end

      Books::ParsedSection.new(
        title: title,
        plain_text: own_text,
        depth: depth,
        position: position,
        path: path,
        children: children
      )
    end

    def extract_title(section_node)
      title_node = section_node.at_xpath("./title")
      return "" unless title_node

      extract_text(title_node).strip
    end

    def collect_section_text(section_node, skip_sections:)
      parts = []
      section_node.children.each do |child|
        next unless child.element?
        next if child.name == "section" || child.name == "title"
        next if skip_sections.include?(child)

        text = extract_text(child).strip
        parts << text if text.present?
      end
      parts.join("\n\n")
    end

    def extract_reading_text(body_node)
      return "" unless body_node

      paragraphs = []
      body_node.xpath(".//p").each do |p|
        text = extract_text(p).strip
        paragraphs << text if text.present?
      end
      paragraphs.join("\n\n")
    end

    def extract_text(node)
      return node.text.strip unless node.element?

      node.children.map do |child|
        child.text? ? child.text : extract_text(child)
      end.join
    end
  end
end
