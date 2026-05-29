class Section < ApplicationRecord
  belongs_to :book
  belongs_to :parent, class_name: "Section", optional: true
  has_many :children, -> { order(:position) },
           class_name: "Section", foreign_key: :parent_id, dependent: :destroy

  def as_toc_node
    {
      id: id,
      title: title,
      path: path,
      depth: depth,
      children: children.map(&:as_toc_node)
    }
  end
end
