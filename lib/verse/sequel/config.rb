# frozen_string_literal: true

module Verse
  module Sequel
    # The configuration schema for the Verse::Sequel::Plugin
    # plugin configuration
    class Config < Verse::Validation::Contract
      params do
        optional(:adapter).filled(:string)
        optional(:mode)
          .filled(:string)
          .value(included_in?: %w[cluster simple])

        optional(:master).filled(:hash)
        optional(:replica).filled(:hash)
        optional(:db).filled(:hash)
      end

      rule(:mode, :master, :replica, :db) do
        if values[:mode].to_s == "cluster"
          if values[:master].nil? || values[:replica].nil?
            # :nocov:
            key.failure("must contains the master and replica keys")
            # :nocov:
          end

          if values[:db]
            # :nocov:
            key.failures("must not define db keys")
            # :nocov:
          end
        end

        if values[:mode].to_s == "simple"
          if values[:db].nil?
            # :nocov:
            key.failure("must define db keys")
            # :nocov:
          end

          if values[:master] || values[:replica]
            # :nocov:
            key.failures("must not define master or replica keys")
            # :nocov:
          end
        end
      end
    end
  end
end
