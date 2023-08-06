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

      self.pkey   = :id
      self.plugin = :sequel

      attr_reader :auth_context

      # define expected primary key (default to `id`)
      def pkey
        self.class.pkey
      end

      def initialize(auth_context)
        @current_mode = :r

        super(auth_context)
      end

      def with_db_mode(mode, &block)
        # We don't care about mode with MongoDB.
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

      event("updated")
      def update(id, attributes, scope = scoped(:update))
        with_db_mode :rw do
          attributes = encode attributes

          scope = scope.where(pkey => id)
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
            raise "Currently unsupported database type `#{db.class.name}`." \
                  "Only SQLite and Postgres are supported." \
                  "Please raise issue if you need support for another database."
          end
        end
      end

      def index_impl(
        filters,
        scope: scoped(:read),
        included: [],
        page: 1,
        items_per_page: 1_000,
        sort: nil,
        record: self.class.model_class,
        query_count: true
      )
        filters = encode_filters(filters)

        with_db_mode :r do
          query = filtering.filter_by(scope, filters, self.class.custom_filters)

          query = query.offset( (page - 1) * items_per_page).limit(items_per_page) if page

          case sort
          when Array
            sort.each do |it|
              case it
              when Array
                key, dir = it
                query = query.order(dir == :desc ? Sequel.desc(key) : Sequel.asc(key))
              when Symbol, String
                query = query.order(Sequel.asc(it))
              end
            end
          when Symbol, String
            query = query.order(Sequel.asc(sort))
          end

          count = query_count ? query.count : nil

          prepare_included(included, query, record: record)

          [query.to_a, { count: count }.compact]
        end
      end

      def find_by(filters = {}, scope: scoped(:read), included: [], record: self.class.model_class)
        filters = encode_filters(filters)

        with_db_mode :r do
          result = filtering.filter_by(scope, filters, self.class.custom_filters).first

          return unless result

          result = decode(result)
          set = prepare_included(included, [result], record: record)
          record.new(result, include_set: set)
        end
      end

      def delete_impl(id)
        with_db_mode :rw do
          count = table.where(pkey => id).delete

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
    end
  end
end
