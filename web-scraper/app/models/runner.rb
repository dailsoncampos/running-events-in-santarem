class Runner < ApplicationRecord
  belongs_to :event

  validates :name, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }

  scope :by_position, -> { order(position: :asc) }
  scope :by_gender, ->(gender) { where(gender: gender) if gender.present? }
  scope :by_category, ->(category) { where(category: category) if category.present? }
end
