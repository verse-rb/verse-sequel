# frozen_string_literal: true

require_relative "./repository"
require_relative "./config"

module Verse
  module Sequel
    class Plugin < Verse::Plugin::Base
      class << self
        attr_accessor :on_create_connection
      end

      @on_create_connection = ->(db, config, &block){
        extensions = config[:extensions]
        db.extension(*extensions.map(&:to_sym)) if extensions

        if db.respond_to?(:wrap_json_primitives)
          db.wrap_json_primitives = true
        end

        block.call(db)
      }

      attr_reader :config

      def description
        # :nocov:
        "Sequel adapter for Verse framework."
        # :nocov:
      end

      def create_connection_provider(config)
        if config[:uri]
          proc do |&block|
            ::Sequel.connect(config[:uri], logger: Verse.logger) do |db|
              self.class.on_create_connection.call(db, config, &block)
            end
          end
        else
          hash = config.dup
          hash.delete(:mode)

          config[:adapter] = config[:adapter].to_sym

          proc do |&block|
            ::Sequel.connect(**config, logger: Verse.logger) do |db|
              self.class.on_create_connection.call(db, config, &block)
            end
          end
        end
      end

      def validate_config!
        result = Verse::Sequel::Config.validate(
          @config
        )
        return result.value unless result.fail?

        raise Verse::Config::SchemaError, "Config errors: #{result.errors}"
      end

      def load_config
        @config = validate_config!

        case @config[:mode].to_sym
        when :simple
          @new_connection_r = create_connection_provider(@config[:db])
          @new_connection_rw = @new_connection_r
        when :cluster
          @new_connection_r = create_connection_provider(@config[:replica])
          @new_connection_rw = create_connection_provider(@config[:master])
        else
          # :nocov:
          raise ArgumentError, "unknown mode `#{@config[:mode]}`"
          # :nocov:
        end
      end

      def on_init
        require "sequel"

        load_config

        # :nocov: #
        logger.debug{ "[DBAdapter] Sequel with #{@config.inspect}" }
        # :nocov: #
      rescue LoadError
        # :nocov: #
        raise LoadError, "`sequel` is not part of the bundle. Add it to your Gemfile."
        # :nocov: #
      end

      def simple_mode?
        @new_connection_rw == @new_connection_r
      end

      # Create or reuse the existing thread connection for the database.
      def client(mode = :rw, &block)
        if simple_mode?
          db = Thread.current[:"verse-sequel-db"]

          return block.call(db) if db

          init_client(
            @new_connection_rw, :"verse-sequel-db", &block
          )
        else
          case mode
          when :rw
            db = Thread.current[:"verse-sequel-db-rw"]
            return block.call(db) if db

            init_client(
              @new_connection_rw, :"verse-sequel-db-rw", &block
            )
          when :r
            # In the case we are already in read-write mode,
            # we get RW the connection to do the read operation.
            # This is to prevent weird issue occuring in transaction, when
            # two different connection are used.
            db = Thread.current[:"verse-sequel-db-rw"]
            return block.call(db) if db

            # Otherwise we move to the read-only connection:
            db = Thread.current[:"verse-sequel-db-r"]
            return block.call(db) if db

            init_client(
              @new_connection_r, :"verse-sequel-db-r"
            )
          end
        end
      end

      private

      def init_client(connection_block, key, &block)
        connection_block.call do |db|
          Thread.current[key] = db
          block.call(db)
        ensure
          Thread.current[key] = nil
        end
      end
    end
  end
end
