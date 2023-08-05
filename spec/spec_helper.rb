# frozen_string_literal: true

require "bootsnap"
Bootsnap.setup(cache_dir: "tmp/cache")

require "simplecov"
SimpleCov.start do
  add_filter do |file|
    file.filename !~ /lib/
  end
end

require "pry"
require "verse/sequel"

require "bundler"
Bundler.require

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
