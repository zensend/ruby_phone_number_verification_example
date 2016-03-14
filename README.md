Dependencies
---------------

Redis


Getting Started
---------------

Edit `config.yml` to add your Zensend API key and Redis URL. If you're running in production, make sure you add a secret_key as well.

Run `bundle install` in the root directory

Run `bundle exec ruby server.rb -p 4567` in the root directory

Visit http://localhost:4567/verify_number to run the number verification flow


