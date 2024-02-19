class CreatePayment < ActiveRecord::Migration[7.1]
  def change
    create_table :payments do |t|
      t.string :fincode_payment_id
      t.string :fincode_payment_access_id
      t.integer :amount
      t.integer :status
      t.integer :credit_card_id

      t.timestamps
    end
  end
end
