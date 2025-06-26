# frozen_string_literal: true
module Verse
  module Sequel
    module Spec
      module SpecHelper
        def self.included(base)
          base.around do |example|
            usage = %i<repository>.include?(example.metadata[:type])
            usage ||= example.metadata[:database]

            if usage
              plugins = Verse::Plugin.all.values.select{ |p| p.is_a?(Verse::Sequel::Plugin) }

              if plugins.any?
                nested_plugin_call = lambda do |plugins, &block|
                  plugin = plugins.shift
                  if plugin
                    plugin.client(:rw) do |db|
                      db.transaction do
                        db.rollback_on_exit
                        nested_plugin_call.call(plugins, &block)
                      end
                    end
                  else
                    block.call
                  end
                end

                nested_plugin_call.call(plugins) do
                  example.run
                end
              else
                example.run
              end
            else
              example.run
            end
          end
        end
      end
    end
  end
end

RSpec.configure do |c|
  c.include Verse::Sequel::Spec::SpecHelper
end
