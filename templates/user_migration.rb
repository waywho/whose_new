class AddUserAttributes < ActiveRecord::Migration<%= migration_version %>
  def change
    add_column :users, :email, :

<% attributes.each do |attribute| -%>
      t.<%= attribute.type %> :<%= attribute.name %>
<% end -%>

      t.timestamps null: false
    end

    add_index :<%= table_name %>, :email,                unique: true
    add_index :<%= table_name %>, :reset_password_token, unique: true
    # add_index :<%= table_name %>, :confirmation_token,   unique: true
    # add_index :<%= table_name %>, :unlock_token,         unique: true
  end
end
