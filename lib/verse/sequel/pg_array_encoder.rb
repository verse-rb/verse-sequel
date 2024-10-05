# frozen_string_literal: true

module Verse
  module Sequel
    module PgArrayEncoder
      module_function

      def encode(value)
        return value unless value.is_a?(Array)

        # BUGFIX: PostgreSQL is confused by an empty array.
        # This occurs because Sequel casts an empty array to Array([]),
        # but it doesn't retain the type of the column, leading to the issue.
        return ::Sequel.lit("'{}'") if value.empty?

        ::Sequel.pg_array(value)
      end

      def decode(value)
        return value unless value.is_a?(::Sequel::Postgres::PGArray)

        value.to_a
      end
    end
  end
end
