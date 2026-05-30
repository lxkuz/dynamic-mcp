module Books
  class SectionHierarchyNormalizer
    def self.call(sections)
      new(sections).call
    end

    def initialize(sections)
      @sections = sections
    end

    def call
      flat = flatten(@sections)
      flat = infer_depths(flat) if flat.all? { |entry| entry.depth.zero? }
      SectionTreeBuilder.build(flat)
    end

    private

    def flatten(nodes, inherited_depth: 0)
      Array(nodes).flat_map do |node|
        node = node.deep_stringify_keys if node.is_a?(Hash)
        depth = node.is_a?(Hash) ? node.fetch("depth", inherited_depth).to_i : node.depth.to_i
        title = node.is_a?(Hash) ? node["title"] : node.title
        plain_text = node.is_a?(Hash) ? node["plain_text"] : node.plain_text
        page_start = node.is_a?(Hash) ? node["page_start"] : node.page_start
        page_end = node.is_a?(Hash) ? node["page_end"] : node.page_end
        children = node.is_a?(Hash) ? node["children"] : node.children

        entry = SectionTreeBuilder::FlatEntry.new(
          title: title,
          plain_text: plain_text.to_s,
          depth: depth,
          position: 0,
          page_start: page_start,
          page_end: page_end
        )

        [ entry ] + flatten(children, inherited_depth: depth + 1)
      end
    end

    def infer_depths(flat)
      flat.map.with_index do |entry, index|
        SectionTreeBuilder::FlatEntry.new(
          title: entry.title,
          plain_text: entry.plain_text,
          depth: SectionDepthInferer.call(entry.title),
          position: index,
          page_start: entry.page_start,
          page_end: entry.page_end
        )
      end
    end
  end
end
