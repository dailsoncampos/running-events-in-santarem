class Event < ApplicationRecord
  has_many :runners, dependent: :destroy

  validates :name, presence: true
  validates :city, presence: true
  validates :event_date, presence: true

  scope :from_santarem, -> { where(city: 'Santarém') }
  scope :recent, -> { order(event_date: :desc) }
  scope :scraped, -> { where.not(scraped_at: nil) }
  scope :not_scraped, -> { where(scraped_at: nil) }

  def scraped?
    scraped_at.present?
  end

  def mark_as_scraped!
    update(scraped_at: Time.current)
  end
end
