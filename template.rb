run "echo '' > Gemfile"

gem 'dalli'
gem 'decent_exposure'
gem 'devise'

gem 'dm-active_model'
gem 'dm-aggregates'
gem 'dm-core'
gem 'dm-devise'
gem 'dm-dragonfly'
gem 'dm-migrations'
gem 'dm-observer'
gem 'dm-postgres-adapter'
gem 'dm-rails'
gem 'dm-tags', git: 'git://github.com/mattbeedle/dm-tags.git'
gem 'dm-timestamps'
gem 'dm-transactions'
gem 'dm-types'
gem 'dm-validations'

gem 'dragonfly'
gem 'dragonfly-ffmpeg'
gem 'draper'
gem 'jquery-rails'
gem 'kaminari'
gem 'has_scope'
gem 'param_protected'
gem 'pg'
gem 'rack-cache'
gem 'rails'
gem 'resque'
gem 'resque-scheduler', :require => 'resque_scheduler'
gem 'simple_form'
gem 'slim-rails'
gem 'texticle', :require => 'texticle/rails'
gem 'therubyracer', platform: :ruby
gem 'twitter-bootstrap-rails'
gem 'unicorn'

gem 'coffee-rails', '~> 3.2.1', group: [ :assets ]
gem 'uglifier', '>= 1.0.3', group: [ :assets ]

gem 'fabrication', group: [ :development, :test ]
gem 'guard-bundler', group: [ :development, :test ]
gem 'guard-rspec', group: [ :development, :test ]
gem 'guard-spork', group: [ :development, :test ]
gem 'heroku', group: [ :development, :test ]
gem 'rspec-rails', group: [ :development, :test ]
gem 'spork', group: [ :development, :test ]

gem 'dm-rspec', group: [ :test ]
gem 'capybara', group: [ :test ]
gem 'database_cleaner', group: [ :test ]
gem 'faker', group: [ :test ]
gem 'launchy', group: [ :test ]
gem 'rb-fsevent', group: [ :test ]
gem 'timecop', group: [ :test ]

run 'bundle install'

run 'touch config/database.yml'
username = ENV['USER']
inject_into_file 'config/database.yml', after: '' do

<<-eos
base: &base
  adapter: postgresql
  host: 127.0.0.1
  # encoding: utf8
  pool: 5
  username: #{username}
  password:

development:
  <<: *base
  database: #{@app_name}_development

test: &test
  <<: *base
  database: #{@app_name}_test

production:
  <<: *base
  database: #{@app_name}_production
  host: <%= ENV['DB_HOST'] %>
  username: <%= ENV['DB_USER'] %>
  password: <%= ENV['DB_PASSWORD'] %>
eos
end

inject_into_file 'config/application.rb', after: 'config.filter_parameters += [:password]' do
  <<-eos

    config.generators do |g|
      g.fixture_replacement :fabrication, :dir => 'spec/fabricators'
      g.orm                 :data_mapper
      g.test_framework      :rspec
      g.template_engine     :slim
      g.stylesheet_engine   :less
    end
  eos
end

username = ENV['USER']
gsub_file 'config/database.yml', /^(  username: ).*$/, '\1%s' % username

rake 'db:create'

generate 'bootstrap:install'
generate 'bootstrap:layout'
generate 'data_mapper:devise_install'
generate 'data_mapper:devise User'
generate 'devise:views'
generate 'draper:install'
generate 'kaminari:config'
generate 'kaminari:views default'
generate 'simple_form:install --bootstrap'
generate 'rspec:install'
generate 'controller pages'

gsub_file 'spec/spec_helper.rb', 'config.fixture_path = "#{::Rails.root}/spec/fixtures"', '# config.fixture_path = "#{::Rails.root}/spec/fixtures"'

run "echo '--format documentation' >> .rspec"

remove_file 'public/index.html'
remove_file 'public/images/rails.png'

run "echo 'config/database.yml' >> .gitignore"

run 'bundle exec spork rspec --bootstrap'
run 'bundle exec guard init spork'
run 'bundle exec guard init rspec'

gsub_file 'Guardfile', "guard 'rspec', :version => 2 do", "guard 'rspec', :version => 2, :cli => '--drb' do"

inject_into_file 'Guardfile', "notification :libnotify\n\n", :before => /^guard 'spork'.*/

route "root to: 'pages#index'"
inside('app/views/pages') do
  run 'touch index.html.slim'
end

run 'touch config/initializers/dragonfly.rb'
inject_into_file 'config/initializers/dragonfly.rb', after: '' do
  <<-eos
    require 'dm-dragonfly'

    app = Dragonfly[:images]
    app.configure_with(:imagemagick)
    app.configure_with(:rails)

    app.define_dm_macro(DataMapper::Resource, :image_accessor)
  eos
end

metastore = 'URI.encode("file:#{Rails.root}/tmp/dragonfly/cache/meta")'
entitystore = 'URI.encode("file:#{Rails.root}/tmp/dragonfly/cache/body")'

inject_into_file 'config/application.rb', after: "config.assets.version = '1.0'" do
  <<-eos
    config.middleware.insert_before Rack::Lock, Rack::Cache, {
      :verbose     => true,
      :metastore   => #{metastore},
      :entitystore => #{entitystore}
    }

    config.middleware.insert_after 'Rack::Cache', 'Dragonfly::Middleware', :images
  eos
end


run 'touch config/initializers/resque.rb'
inject_into_file 'config/initializers/resque.rb', after: '' do
  <<-eos
    require 'resque'

    uri = URI.parse(ENV['REDISTOGO_URL'] || 'localhost')
    REDIS = Redis.new(host: uri.host, port: uri.port, password: uri.password)

    if Rails.env.test?
      Resque.inline = true
    else
      Resque.redis = REDIS
    end

    require 'resque_scheduler'

    # schedule = YAML.load_file(Rails.root.join('config', 'schedule.yml'))

    # Resque.schedule = schedule

    Resque.redis.namespace = 'resque:#{@app_name}'
  eos
end

run 'touch config/initializers/resque_auth.rb'
inject_into_file 'config/initializers/resque_auth.rb', after: '' do
  <<-eos
    Resque::Server.use(Rack::Auth::Basic) do |user, password|
      user == 'matt' && password == 'EmBW0qxEDLmhixRbhMIYVl8LIKyWiHHDuivQkVzcXFBQHAeiKj'
    end
  eos
end

run "mkdir -p lib/#{@app_name.classify}"
run "touch lib/#{@app_name.classify}/async.rb"
method = '#{method}'
inject_into_file "lib/#{@app_name.classify}/async.rb", after: '' do
  <<-eos
    module Pornbook
      module Async
        extend ActiveSupport::Concern

        module ClassMethods
          def perform(id, method, *args)
            get(id).send("#{method}_without_async", *args)
          end

          def handle_asyncronously(*args)
            args.each do |method|
              define_method "#{method}_with_async" do |*args|
                async(method, *args)
              end
              alias_method_chain method.to_sym, :async
            end
          end
        end

        def async(method, *args)
          Resque.enqueue(self.class, id, method, *args)
        end
      end
    end
  eos
end

rake 'db:automigrate'

git :init
git add: '.'
git commit: "-m 'create initial application'"
