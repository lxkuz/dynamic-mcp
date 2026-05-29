class Page < ApplicationRecord
  belongs_to :book

  validates :number, numericality: { only_integer: true, greater_than: 0 }

  def readable_text
    content.to_s.delete("\u0000")
  end
end
