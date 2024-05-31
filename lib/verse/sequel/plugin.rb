# frozen_string_literal: true

require_relative "./repository"
require_relative "./config"

module Verse
  module Sequel
    class Plugin < Verse::Plugin::Base
      class << self
        attr_accessor :on_create_connection
      end

      attr_reader :config

      def description
        # :nocov:
        "Sequel adapter for Verse framework."
        # :nocov:
      end

      def init_db(config)

        case config.mode
        when :simple
          @database = ::Sequel.connect(
            config.db.uri,
            logger: Verse.logger,
            max_connections: config.db.max_connections,
          )
        when :cluster
          @database = ::Sequel.connect(
            config.master.uri,
            logger: Verse.logger,
            max_connections: config.master.max_connections,
            servers: {
              read_only: {
                uri: config.replica.uri,
                max_connections: config.replica.max_connections,
                logger: Verse.logger,
              }
            }
          )
          @database.extension :server_block
        else
          raise ArgumentError, "Invalid mode: #{config.mode}"
        end

        if @database.respond_to?(:wrap_json_primitives)
          @database.wrap_json_primitives = true
        end

        @database.extension(*config.extensions)
      end

      def validate_config!
        result = Verse::Sequel::ConfigSchema.validate(
          @config
        )
        return result.value unless result.fail?

        raise Verse::Config::SchemaError, "Config errors: #{result.errors}"
      end

      def on_init
        require "sequel"

        @config = validate_config!
        init_db(@config)

        # :nocov: #
        logger.debug{ "[DBAdapter] Sequel with #{@config.inspect}" }
        # :nocov: #
      rescue LoadError
        # :nocov: #
        raise LoadError, "`sequel` is not part of the bundle. Add it to your Gemfile."
        # :nocov: #
      end

      def simple_mode?
        @config.mode == :simple
      end

      # Create or reuse the existing thread connection for the database.
      def client(mode = :rw, &block)
        if simple_mode?
          block.call(@database)
        else
          case mode
          when :rw
            begin
              old_db = Thread.current[:"verse-sequel-db"]
              Thread.current[:"verse-sequel-db"] = :default

              @database.with_server(:default) do
                block.call(@database)
              end
            ensure
              Thread.current[:"verse-sequel-db"] = old_db
            end
          when :r
            # Continue on RW mode if we are already in RW due to transactions
            # basically, if we say:
            # client(:rw){ ... client(:r) { ... } }
            # the second client will be in RW mode.
            current_db = Thread.current[:"verse-sequel-db"] || :read_only

            @database.with_server(current_db) do
              block.call(@database)
            end
          end
        end
      end


    end
  end
end
