class Book < ApplicationRecord
  CHARS_PER_PAGE = 1800
  SOURCE_FORMATS = %w[fb2 pdf].freeze
  MCP_STATUSES = %w[stopped starting running failed].freeze

  has_many :sections, -> { order(:depth, :position) }, dependent: :destroy
  has_many :pages, -> { order(:number) }, dependent: :destroy
  has_one_attached :source_file

  STATUSES = %w[pending processing ready failed].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :source_format, inclusion: { in: SOURCE_FORMATS }
  validates :mcp_status, inclusion: { in: MCP_STATUSES }
  validates :uid, presence: true, uniqueness: true

  before_validation :assign_uid, on: :create

  scope :ready, -> { where(status: "ready") }

  def ready?
    status == "ready"
  end

  def pdf?
    source_format == "pdf"
  end

  def fb2?
    source_format == "fb2"
  end

  def physical_pages?
    pdf?
  end

  def to_param
    uid
  end

  def self.generate_uid
    loop do
      candidate = SecureRandom.urlsafe_base64(32)
      break candidate unless exists?(uid: candidate)
    end
  end

  private

  def assign_uid
    self.uid = self.class.generate_uid if uid.blank?
  end
end
