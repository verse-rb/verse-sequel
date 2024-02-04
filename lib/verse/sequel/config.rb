# frozen_string_literal: true

module Verse
  module Sequel
    # The configuration schema for the Verse::Sequel::Plugin
    # plugin configuration
    Config = Verse::Schema.define do
      field?(:adapter, String).filled
      field?(:mode, Symbol).in?(%i[cluster simple])

      field?(:master, Hash)
      field?(:replica, Hash)
      field?(:db, Hash)

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
    end
  end
end
