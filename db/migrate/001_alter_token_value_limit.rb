class AlertTokenValueLimit < ActiveRecord::Migration::V5_1
  def up
    change_column :tokens, :value, :string, :limit => 64
  end

  def down
  end
end
