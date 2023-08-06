# frozen_string_literal: true

module Verse
  module Sequel
    module FilteringSqlite
      module_function

      OPERATIONS = {
        lt: ->(col, column, value) { col.where(::Sequel.lit("#{column} < ?", value)) },
        lte: ->(col, column, value) { col.where(::Sequel.lit("#{column} <= ?", value)) },
        gt: ->(col, column, value) { col.where(::Sequel.lit("#{column} > ?", value)) },
        gte: ->(col, column, value) { col.where(::Sequel.lit("#{column} >= ?", value)) },
        eq: ->(col, column, value) {
          case value
          when Array
            if value.empty?
              col.where(::Sequel.lit("false"))
            else
              col.where(::Sequel.lit("#{column} IN ?", value))
            end
          when ::Sequel::Dataset
            col.where(::Sequel.lit("#{column} IN ?", value))
          else
            col.where(::Sequel.lit("#{column} = ?", value))
          end
        },
        neq: ->(col, column, value) { col.where(::Sequel.lit("#{column} != ?", value)) },
        prefix: ->(col, column, value) { col.where(::Sequel.lit("LOWER(#{column}) LIKE ?", "#{escape_like(value.to_s.downcase)}%")) },
        suffix: ->(col, column, value) { col.where(::Sequel.lit("LOWER(#{column}) LIKE ?", "%#{escape_like(value.to_s.downcase)}")) },
        in: ->(col, column, value) { col.where(::Sequel.lit("#{column} IN ?", value)) },
        match: ->(col, column, value) { col.where(::Sequel.lit("LOWER(#{column}) LIKE ?", "%#{escape_like(value.to_s.downcase)}%")) }
      }

      def escape_like(value)
        value.gsub(/[\\%_]/, "\\\\\\0")
      end

      def expect_array?(operator)
        %i<contains in eq>.include?(operator.to_sym)
      end

      def filter_by(collection, filtering_parameters, custom_filters)
        return collection if filtering_parameters.nil? || filtering_parameters.empty?

        filtering_parameters.each do |key, value|
          custom_filter = custom_filters && custom_filters[key.to_s]

          if custom_filter
            collection = custom_filter.call(collection, value)
            next
          end

          column_name, operation = key.to_s.split("__")

          operation ||= "eq"

          # double quote the column name to make it a sane field and
          # avoid SQL injection
          sanitized_column_name =
            column_name.split(".")
                       .map { |s| collection.db.literal(s.to_sym) }
                       .join(".")

          collection = OPERATIONS.fetch(operation.to_sym).call(collection, sanitized_column_name, value)
        end

        collection
      end
    end
  end
end
