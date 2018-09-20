class AlertTokenValueLimit < ActiveRecord::Migration
  def up
    change_column :tokens, :value, :string, :limit => 64
  end

  def down
  end
end
