# frozen_string_literal: true

module Verse
  module Sequel
    DbConfig = Struct.new(
      :uri,
      :max_connections,
      keyword_init: true
    )

    DbConfigSchema = Verse::Schema.define do
      field(:uri,  String)
      field(:max_connections, Integer).default(5)

      transform do |hash|
        DbConfig.new(**hash)
      end
    end

    Config = Struct.new(
      :adapter,
      :mode,
      :master,
      :replica,
      :db,
      :extensions,
      keyword_init: true
    )

    # The configuration schema for the Verse::Sequel::Plugin
    # plugin configuration
    ConfigSchema = Verse::Schema.define do
      field?(:adapter, String).filled
      field(:mode, Symbol).in?(%i[cluster simple]).default(:simple)
      field(:extensions, Array, of: Symbol).default([])

      field?(:master, DbConfigSchema)
      field?(:replica, DbConfigSchema)
      field?(:db, DbConfigSchema)

      rule([:mode, :master, :replica, :db], "illegal configuration") do |values|
        if values[:mode] == :cluster
          if values[:master].nil? || values[:replica].nil?
            next false
          end

          if values[:db]
            next false
          end
        end

        if values[:mode] == :simple
          if values[:db].nil?
            next false
          end

          if values[:master] || values[:replica]
            next false
          end
        end

        true
      end

      transform do |hash|
        Config.new(**hash)
      end
    end
  end
end
