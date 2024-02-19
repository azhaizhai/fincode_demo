class Refund < ApplicationRecord
  belongs_to :payment
  enum status: { pending: 0, processing: 1, completed: 2, failed: 3 }
end