class Payment < ApplicationRecord
  belongs_to :credit_card
  has_many :refunds
  enum status: { pending: 0, processing: 1, completed: 2, voided: 3, authorized: 4 }

  def actual_amount
    amount - refunds.completed.sum(&:amount)
  end
end