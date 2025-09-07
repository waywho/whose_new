# my_template.rb
require_relative "./whose_builder"   # adjust path if needed

# Instantiate the builder with the Rails generator context
builder = WhoseBuilder.new(self)

gem "haml", comment: "\nHaml for templating"
gem "view_component", comment: "\nViewComponent"

gem "activeadmin", comment: "\nActiveAdmin for admin interface"
gem "devise", comment: "\nDevise for user authentication"
gem "friendly_id", comment: "\nFriendlyId for pretty URLs"
gem "nilify_blanks", comment: "\nNilifyBlanks to handle nil values in ActiveRecord"
gem "css-zero", comment: "\nCSS Zero for basic CSS reset"

# Call the methods you want
gem_group :development, :test do
  gem "factory_bot_rails"
  gem "faker"
  gem "rails-controller-testing"
end

gem_group :development do
  gem "haml-rails", comment: "\nHaml generator"
  gem "html2haml"
  gem "foreman"
  gem "letter_opener"
end

after_bundle do
  git :init
  git add: "."
  git commit: %Q{ -m 'Initial commit' }

  say "Setup configs", :blue
  builder.config_development
  builder.replace_database_config
  builder.replace_storage_config

  git add: "."
  git commit: %Q{ -m 'Setup configs' }

  say "Install devise gem and user", :blue
  generate "devise:install"
  generate "devise User"

  say "Install active admin and admin user", :blue
  generate "active_admin:install"
  generate "devise:views -v registrations passwords sessions"

  say "Modifying devise views", :blue
  builder.replace_devise_forms
  
  say "Modifying devise and active admin migrations", :blue
  builder.modify_devise_user_migration
  builder.modify_devise_admin_user_migration

  git add: "."
  git commit: %Q{ -m 'Setup authentication and users' }

  say "Install friendlyId", :blue
  generate "migration", "AddSlugToUsers", "slug:uniq"
  generate "friendly_id"

  git add: "."
  git commit: %Q{ -m 'Setup frendly id' }

  say "Install CSS", :blue
  generate "css_zero:install"
  generate "css_zero:add form layouts flash"

  rails_command "haml:erb2haml HAML_RAILS_DELETE_ERB=true"

  git add: "."
  git commit: %Q{ -m 'CSS and Haml' }

  say "Install nilify blanks", :blue
  builder.insert_nilify_blanks

  git add: "."
  git commit: %Q{ -m 'Setup nilify blanks' }
end
