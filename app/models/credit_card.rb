class CreditCard < ApplicationRecord
  has_many :payments
end