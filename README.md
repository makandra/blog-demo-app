A simple blog demonstration app
===============================

This is a *very* simple Rails application for demonstration purposes.

Start
------
1. Clone the repository: `git clone git@github.com:makandra/blog-demo-app.git`
2. Run bundler within the new directory: `cd blog-demo-app && bundle install`
2. Create and migrate your database: `bundle exec rake db:create && bundle exec rake db:migrate && RAILS_ENV=test bundle exec rake db:migrate`
3. Start the development server: `bundle exec rails s`

Tests
-----
You can find a basic cucumber feature in `features/blog.feature`.
It is tagged to run

- with Selenium `(@selenium)` in order to demonstrate automated testing
- slowly `(@run_slowly)` to see what is happening.

You can run the test by saying `bundle exec cucumber features`.

Please keep in mind this was built to start diving into the Rails and TDD world.
