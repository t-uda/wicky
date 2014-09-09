class CreatePatch < ActiveRecord::Migration
  def change
    create_table :patches do |table|
      table.text :content
      table.references :histories, polymorphic: true
      table.timestamps
    end
    add_reference :projects, :histories, index: true
    add_reference :schedules, :histories, index: true
  end
end
