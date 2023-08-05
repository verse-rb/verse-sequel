# frozen_string_literal: true

require_relative "lib/verse/sequel/version"

Gem::Specification.new do |spec|
  spec.name = "verse-sequel"
  spec.version = Verse::Sequel::VERSION
  spec.authors = ["Yacine Petitprez"]
  spec.email = ["anykeyh@gmail.com"]

  spec.summary = "Repository system using Sequel as backend for the verse framework."
  spec.description = "Repository system using Sequel as backend for the verse framework."
  spec.homepage = "https://todo.com"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = ""

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://todo.com"
  spec.metadata["changelog_uri"] = "https://todo.com"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
