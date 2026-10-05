class AddLocationToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :latitude, :decimal, precision: 10, scale: 7
    add_column :posts, :longitude, :decimal, precision: 10, scale: 7
    add_column :posts, :location_name, :string
    add_column :posts, :location_source, :string
  end
end
