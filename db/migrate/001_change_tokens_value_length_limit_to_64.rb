class ChangeTokensValueLimitTo64 < ActiveRecord::Migration
  def up
    change_column :tokens, :value, :string, :limit => 64, :default => "", :null => false
  end

  def down
    change_column :tokens, :value, :string, :limit => 40, :default => "", :null => false
  end
end
