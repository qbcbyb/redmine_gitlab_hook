class ChangeTokensValueLimitTo64 < ActiveRecord::Migration::V4_2
  def up
    change_column :tokens, :value, :string, :limit => 64
  end

  def down
  end
end
