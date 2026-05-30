module Books
  class SectionDepthInferer
    NUMBERING_PREFIX = /\A(\d+(?:\.\d+)*)\s*[.)]?\s+/

    def self.call(title)
      new(title).call
    end

    def initialize(title)
      @title = title.to_s
    end

    def call
      match = @title.match(NUMBERING_PREFIX)
      return 0 unless match

      [ match[1].split(".").length - 1, 0 ].max
    end
  end
end
