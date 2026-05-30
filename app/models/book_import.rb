class BookImport < ApplicationRecord
  STATUSES = %w[
    queued sampling analyzing discovering_toc scripting validating running reviewing
    persisting indexing ready failed
  ].freeze
  MODES = %w[ai legacy].freeze

  belongs_to :book
  has_many :events, class_name: "BookImportEvent", dependent: :destroy

  validates :status, inclusion: { in: STATUSES }
  validates :mode, inclusion: { in: MODES }

  def log_event!(step:, status:, message: nil, payload: nil, iteration: self.iteration, duration_seconds: nil)
    events.create!(
      step: step,
      status: status,
      iteration: iteration,
      duration_seconds: duration_seconds,
      payload: payload,
      message: message
    )
    Rails.logger.info("[book_import book=#{book_id} step=#{step} status=#{status}] #{message}")
  end

  def record_llm_usage!(step, usage)
    return if usage.blank?

    self.llm_usage = llm_usage.merge(step.to_s => usage)
    save!
  end

  def fail!(message)
    update!(
      status: "failed",
      error_message: message,
      finished_at: Time.current
    )
    book.update!(status: "failed", error_message: message)
  end

  def succeed!
    update!(
      status: "ready",
      error_message: nil,
      finished_at: Time.current
    )
  end
end
