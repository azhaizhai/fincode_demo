class CreateCreditCard < ActiveRecord::Migration[7.1]
  def change
    create_table :credit_cards do |t|
      t.string :fincode_customer_id
      t.string :fincode_credit_card_id

      t.timestamps
    end
  end
end
