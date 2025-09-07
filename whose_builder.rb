class WhoseBuilder < Rails::AppBuilder
  def self.source_root
    File.expand_path("../whose_new/templates", __dir__)
    # Adjust the path to point to your 'templates' folder
  end

  def replace_devise_forms
    [["sessions", "new"], ["passwords", "edit"], ["passwords", "new"], ["registrations", "edit"], ["registrations", "new"]].each do |scope, file|
      replace_devise_view(scope, file, generate_views: false)
    end
  end

  def config_development
    development_file = File.join(destination_root, "config", "environments", "development.rb")
    gsub_file development_file, /^(\s*).*config.action_mailer.raise_delivery_errors.*/ do |match|
      "\tconfig.action_mailer.raise_delivery_errors = true"
    end
    gsub_file development_file, /^(\s*).*config.action_mailer.default_url_options.*/ do |match|
      "\tconfig.action_mailer.default_url_options = { host: 'localhost', port: 3000 }"
    end

    inject_into_file development_file, after: "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }\n" do
      <<~RUBY
        \tconfig.action_mailer.delivery_method = :letter_opener
      RUBY
    end
  end

  def modify_devise_user_migration
    migration_file = latest_devise_user_migration
    return unless migration_file && File.exist?(migration_file)

    # Example: add a 'username' column
    inject_into_file migration_file, after: /^(\s*)create_table :users do \|t\|.*/ do
      <<~RUBY
        \n\t\t\t\#\# User Details
        \t\t\tt.string :username, null: false, default: ""
        \t\t\tt.string :first_name, null: false, default: ""
        \t\t\tt.string :last_name, null: false, default: ""

        # \t\t\t\#\# Admin association
        # \t\t\tt.boolean :admin, default: false
      RUBY
    end

    user_modules(migration_file)
  end

  def modify_devise_admin_user_migration
    migration_file = latest_devise_admin_user_migration
    return unless migration_file && File.exist?(migration_file)

    # Example: add a 'username' column
    inject_into_file migration_file, after: /^(\s*)create_table :admin_users do \|t\|.*/ do
      <<~RUBY
        \n\t\t\t\#\# User Details
        \t\t\tt.string :username, null: false, default: ""
        \t\t\tt.string :first_name, null: false, default: ""
        \t\t\tt.string :last_name, null: false, default: ""
      RUBY
    end

    user_modules(migration_file, "Admin")
  end

  def replace_database_config
    database_yml = File.join(destination_root, "config", "database.yml")
    if File.exist?(database_yml)
      remove_file database_yml
    end
    template "#{self.class.source_root}/database.yml.tt", database_yml
  end

  def replace_storage_config
    storage_yml = File.join(destination_root, "config", "storage.yml")
    if File.exist?(storage_yml)
      remove_file storage_yml
    end
    template "#{self.class.source_root}/storage.yml.tt", storage_yml
  end

  def insert_nilify_blanks
    initializer "nilify_blanks.rb",
    <<~RUBY
      ActiveRecord::Base.nilify_blanks
    RUBY
  end

  def insert_activeadmin_procfile
    procfile = File.join(destination_root, "Procfile.dev")
    template "#{self.class.source_root}/procfile.dev.tt", procfile
  end

  def user_migration_exist?
    latest_devise_user_migration
    latest_devise_user_migration && File.exist?(latest_devise_user_migration)
  end

  def admin_user_migration_exist?
    latest_devise_admin_user_migration
    latest_devise_admin_user_migration && File.exist?(latest_devise_admin_user_migration)
  end

  private

  def user_modules(migration_file, scope = nil)
    if yes?("Should #{scope} User be confirmable? [Ynaqdhm]")
      uncomment_lines migration_file, /t.string   :confirmation_token/
      uncomment_lines migration_file, /t.datetime :confirmed_at/
      uncomment_lines migration_file, /t.datetime :confirmation_sent_at/
      uncomment_lines migration_file, /t.string   :unconfirmed_email/
      uncomment_lines migration_file, /add_index :users, :confirmation_token/


      replace_devise_view("confirmations", "new")

      say "Make sure to add `:confirmable` to the User model", :magenta
    end

    if yes?("Should #{scope} User be trackable? [Ynaqdhm]")
      uncomment_lines migration_file, /t.string   :sign_in_count/
      uncomment_lines migration_file, /t.datetime :current_sign_in_at/
      uncomment_lines migration_file, /t.datetime :last_sign_in_at/
      uncomment_lines migration_file, /t.string   :current_sign_in_ip/
      uncomment_lines migration_file, /t.string   :last_sign_in_ip/

      say "Make sure to add `:trackable` to the User model", :magenta
    end

    if yes?("Should #{scope} User be lockable? [Ynaqdhm]")
      uncomment_lines migration_file, /t.integer  :failed_attempts/
      uncomment_lines migration_file, /t.string   :unlock_token/
      uncomment_lines migration_file, /t.datetime :locked_at/
      uncomment_lines migration_file, /add_index :users, :unlock_token/

      replace_devise_view("unlocks", "new")

      say "Make sure to add `:lockable` to the User model", :magenta
    end
  end

  def replace_devise_view(scope, file, generate_views: true)
    erb_file = File.join(destination_root, "app", "views", "devise", scope, "#{file}.html.erb")
    haml_file = File.join(destination_root, "app", "views", "devise", scope, "#{file}.html.haml")
    return if File.exist?(haml_file)

    generate "devise:views -v #{scope}" if generate_views

    template = "#{self.class.source_root}/devise/#{scope}/#{file}.html.haml.tt"

    say "..replace devise #{scope}/#{file} templates", :blue

    if File.exist?(erb_file)
      remove_file(erb_file)
    elsif File.exist?(haml_file)
      remove_file(haml_file)
    end

    template template, haml_file
  end

  def app_name
    File.basename(destination_root)
  end

  def latest_devise_user_migration
    user_migration_file = File.join(destination_root, "db", "migrate", "*_devise_create_users.rb")
    Dir[user_migration_file].max_by { |f| File.mtime(f) }
  end

  def latest_devise_admin_user_migration
    admin_user_migration_file = File.join(destination_root, "db", "migrate", "*_devise_create_admin_users.rb")
    Dir[admin_user_migration_file].max_by { |f| File.mtime(f) }
  end
end
