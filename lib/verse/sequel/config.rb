# frozen_string_literal: true

module Verse
  module Sequel
    # The configuration schema for the Verse::Sequel::Plugin
    # plugin configuration
    class Config < Verse::Validation::Contract
      params do
        optional(:adapter).filled(:string)
        optional(:cluster).hash do
          optional(:master).filled(:hash)
          optional(:replica).filled(:hash)
        end
        optional(:db).filled(:hash)
      end

      rule(:cluster, :db) do
        if value[:cluster].nil? && value[:db].nil?
          key.failure('cluster or db must be defined')
        end

        unless value[:cluster].nil? ^ value[:db].nil?
          key.failure('cluster or db are mutually exclusive')
        end
      end

    end
  end
end