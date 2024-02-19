class CreateRefund < ActiveRecord::Migration[7.1]
  def change
    create_table :refunds do |t|
      t.integer :payment_id
      t.integer :amount
      t.integer :status
      t.timestamps
    end
  end
end
