# frozen_string_literal: true

require_relative "./filtering_pg"
require_relative "./filtering_sqlite"

module Verse
  module Sequel
    class Repository < Verse::Model::Repository::Base
      class << self
        attr_accessor :pkey, :plugin

        def inherited(subklass)
          super

          subklass.pkey   = pkey
          subklass.plugin = plugin
        end
      end

      self.plugin = :sequel

      attr_reader :auth_context

      def initialize(auth_context)
        @current_mode = :r

        super(auth_context)
      end

      def with_db_mode(mode, &block)
        Verse::Plugin[self.class.plugin].client(mode) do |_db|
          old_mode, @current_mode = @current_mode, mode
          client(&block)
        ensure
          @current_mode = old_mode
        end
      end

      # /!\ be sure to call table within a with_db_mode block to have opened
      #     connection or any operation over the table will fail
      def table
        client{ |db| db.from(self.class.table) }
      end

      def client(&block)
        Verse::Plugin[self.class.plugin].client(@current_mode, &block)
      end

      def transaction(&block)
        client{ |db| db.transaction(&block) }
      end

      def after_commit(&block)
        client{ |c| c.after_commit(&block) }
      end

      def create_impl(data)
        with_db_mode :rw do
          begin
            id = table.insert(data)
          rescue ::Sequel::ConstraintViolation
            raise Verse::Error::CannotCreateRecord
          end

          id.to_s
        end
      end

      def update_impl(id, attributes, scope:)
        return true if attributes.empty?

        with_db_mode :rw do
          scope = scope.where(self.class.primary_key.to_sym => id)
          result = scope.update(attributes)

          return false if result == 0

          true
        end
      end

      def filtering
        with_db_mode :r do |db|
          case db.class.name
          when "Sequel::SQLite::Database"
            FilteringSqlite
          when "Sequel::Postgres::Database"
            FilteringPg
          else
            # :nocov:
            raise "Currently unsupported database type `#{db.class.name}`." \
                  "Only SQLite and Postgres are supported." \
                  "Please raise issue if you need support for another database."
            # :nocov:
          end
        end
      end

      def index_impl(
        filters,
        scope:,
        page:,
        items_per_page:,
        sort:,
        query_count:
      )
        with_db_mode :r do
          query = filtering.filter_by(scope, filters, self)

          sort ||= [
            [self.class.table, self.class.primary_key.to_s].join(".")
          ]
          query = prepare_ordering(query, sort)

          metadata = {}

          if page
            offset = (page - 1) * items_per_page
            query = query.offset(offset).limit(items_per_page)

            if query_count
              # For performance: count max 1000 rows from offset
              count_query = query.limit(1000)
              limited_count = count_query.count

              metadata.merge!(
                count: offset + limited_count,
                more: (limited_count == 1000)
              )
            end
          elsif query_count
            metadata.merge!(count: query.count)
          end

          [query.to_a, metadata.compact]
        end
      end

      def find_by_impl(filters = {}, scope: scoped(:read))
        with_db_mode :r do
          return filtering.filter_by(scope, filters, self).first
        end
      end

      def delete_impl(id)
        with_db_mode :rw do
          count = table.where(self.class.primary_key.to_sym => id).delete

          return count > 0
        end
      end

      protected

      # Basic scope filtering. Can be redefined in subclasses.
      # @param [Symbol] action the action to perform. Can be read, update, delete
      # @return [Sequel::Dataset] A subset collection
      def scoped(action)
        @auth_context.can!(action, self.class.resource) do |scope|
          scope.all?    { table }
          scope.custom? { |id| table.where(pkey => id) }
        end
      end

      def prepare_ordering(query, sort)
        sort = sort.split(",") if sort.is_a?(String)

        if !sort.is_a?(Array)
          # :nocov:
          raise ArgumentError, "incorrect ordering parameter type (must be Array or String, but got `#{sort.class}`)"
          # :nocov:
        end

        sort.each do |x|
          method = nil
          column = nil

          if x[0] == "-"
            method = :desc
            column = x[1..]
          else
            method = :asc
            column = x
          end

          if column.include?(".")
            table_name, column = column.split(".")
            expression = ::Sequel.qualify(table_name.to_sym, column.to_sym)
          else
            expression = column.to_sym
          end

          query = query.order(::Sequel.send(method, expression))
        end

        query
      end
    end
  end
end
