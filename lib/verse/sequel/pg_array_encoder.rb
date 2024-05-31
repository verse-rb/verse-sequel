# frozen_string_literal: true

module Verse
  module Sequel
    module PgArrayEncoder
      module_function

      def encode(value)
        return value unless value.is_a?(Array)

        ::Sequel.pg_array(value)
      end

      def decode(value)
        return value unless value.is_a?(::Sequel::Postgres::PGArray)

        value.to_a
      end
    end
  end
end