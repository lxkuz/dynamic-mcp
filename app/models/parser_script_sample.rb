class ParserScriptSample < ApplicationRecord
  belongs_to :book, optional: true
  belongs_to :book_import, optional: true

  validates :source_format, presence: true
  validates :script, presence: true
  validates :script_sha256, presence: true, uniqueness: { scope: :source_format }

  before_validation :assign_script_sha256

  scope :for_format, ->(format) { where(source_format: format.to_s) }
  scope :recent_first, -> { order(updated_at: :desc) }

  private

  def assign_script_sha256
    self.script_sha256 = Digest::SHA256.hexdigest(script.to_s) if script.present?
  end
end
