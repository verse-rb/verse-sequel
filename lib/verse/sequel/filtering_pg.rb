# frozen_string_literal: true

module Verse
  module Sequel
    module FilteringPg
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
          when nil, ::Sequel::Postgres::JSONNull # I really don't get those wrappers in Sequel, they are soooooo ugly
            col.where(::Sequel.lit("#{column} IS NULL"))
          else
            col.where(::Sequel.lit("#{column} = ?", value))
          end
        },
        exists: ->(col, column, value) {
          case value
          when "", "0", "false", false
            col.where(::Sequel.lit("#{column} IS NULL"))
          else
            col.where(::Sequel.lit("#{column} IS NOT NULL"))
          end
        },
        neq: ->(col, column, value) {
          case value
          when Array
            if value.empty?
              col
            else
              col.where(::Sequel.lit("#{column} NOT IN ?", value))
            end
          when ::Sequel::Dataset
            col.where(::Sequel.lit("#{column} NOT IN ?", value))
          when nil, ::Sequel::Postgres::JSONNull # I really don't get those wrappers in Sequel, they are soooooo ugly
            col.where(::Sequel.lit("#{column} IS NOT NULL"))
          else
            col.where(::Sequel.lit("#{column} != ?", value))
          end
        },
        prefix: ->(col, column, value) { col.where(::Sequel.lit("#{column} ILIKE ?", "#{escape_like(value)}%")) },
        suffix: ->(col, column, value) { col.where(::Sequel.lit("#{column} ILIKE ?", "%#{escape_like(value)}")) },
        in: ->(col, column, value) { col.where(::Sequel.lit("#{column} IN ?", value)) },
        match: ->(col, column, value) { col.where(::Sequel.lit("#{column} ILIKE ?", "%#{escape_like(value)}%")) },
        contains: ->(col, column, value) {
          value = [value] unless value.is_a?(Array) || value.is_a?(Hash) ||
                                 value.is_a?(::Sequel::Postgres::JSONBObject) ||
                                 value.is_a?(::Sequel::Dataset) ||
                                 value.is_a?(::Sequel::Postgres::JSONBOp)

          case value
          when ::Sequel::Dataset
            col.where(::Sequel.lit("#{column} @> ?", value.select_map(column)))
          when ::Sequel::Postgres::JSONBOp
            col.where(::Sequel.lit("#{column} @> ?", value))
          when Array
            if value.empty?
              col.where(::Sequel.lit("false"))
            else
              col.where(::Sequel.lit("#{column} && '{#{value.map(&:to_json).join(",")}}'"))
            end
          when Hash, ::Sequel::Postgres::JSONBObject
            col.where(::Sequel.lit("#{column} @> ?", value.to_json))
          else
            # :nocov:
            raise "unreachable"
            # :nocov:
          end
        },
      }.freeze

      def escape_like(value)
        value.gsub(/[\\%_]/, "\\\\\\0")
      end

      def expect_array?(operator)
        %i<contains in eq>.include?(operator.to_sym)
      end

      def filter_by(collection, filtering_parameters, repo_instance)
        return collection if filtering_parameters.nil? || filtering_parameters.empty?

        filtering_parameters.each do |key, value|
          custom_filters = repo_instance.class.custom_filters
          custom_filter = custom_filters&.fetch(key.to_s, nil)

          if custom_filter
            collection = repo_instance.instance_exec(
              collection, value, &custom_filter
            )
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
