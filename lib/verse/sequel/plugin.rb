# frozen_string_literal: true

require_relative "./repository"
require_relative "./config"

module Verse
  module Sequel
    # https://docs.mongodb.com/ruby-driver/current/
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
        "Sequel adapter for Verse framework."
      end

      def create_connection_provider(config)
        if config[:uri]
          proc do |&block|
            ::Sequel.connect(config[:uri]) do |db|
              self.class.on_create_connection.call(db, config, &block)
            end
          end
        else
          hash = config.dup
          hash.delete(:mode)

          config[:adapter] = config[:adapter].to_sym

          proc do |&block|
            ::Sequel.connect(**config) do |db|
              self.class.on_create_connection.call(db, config, &block)
            end
          end
        end
      end

      def load_config
        case @config[:mode].to_sym
        when :simple
          @new_connection_r = create_connection_provider(@config)
          @new_connection_rw = @new_connection_r
        when :cluster
          @new_connection_r = create_connection_provider(@config[:replica])
          @new_connection_rw = create_connection_provider(@config[:master])
        else
          raise ArgumentError, "unknown mode `#{@config[:mode]}`"
        end
      end

      def on_init
        require "sequel"

        load_config

        logger.debug{
          "[DBAdapter] Sequel with #{@config.inspect}"
        }
      rescue LoadError
        raise LoadError, "`sequel` is not part of the bundle. Add it to your Gemfile."
      end

      def simple_mode?
        @new_connection_rw == @new_connection_r
      end

      def client(mode = :rw, &block)
        # Not a big fan of the switch between read and read-write connection...
        key = nil
        connection_block = nil

        if simple_mode?
          key = :"verse-sequel"
          connection_block = @new_connection_r
        else
          key = :"verse-sequel-#{mode}"
          connection_block = mode == :rw ? @new_connection_rw : @new_connection_r
        end

        db = Thread.current[key]
        if db
          block.call(db)
        else
          init_client(
            connection_block, key, &block
          )
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
