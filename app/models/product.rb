class Product < ApplicationRecord
  has_many :line_items, dependent: :restrict_with_error

  validates :name, presence: true
  validates :sku, presence: true, uniqueness: true
  validates :price, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
