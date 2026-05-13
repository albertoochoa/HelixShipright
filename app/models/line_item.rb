class LineItem < ApplicationRecord
  belongs_to :order
  belongs_to :product

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :copy_price_from_product, on: :create

  def subtotal_cents
    quantity.to_i * unit_price_cents.to_i
  end

  private
  def copy_price_from_product
    self.unit_price_cents ||= product&.price_cents
  end
end
