class ChangeTokensValueLimitTo64 < ActiveRecord::Migration[4.2]
  def up
    change_column :tokens, :value, :string, :limit => 64
  end

  def down
    change_column :tokens, :value, :string, :limit => 40
  end
end
