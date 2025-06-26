module Verse
  module Sequel
    module SpecHelper
      def self.included(base)
        base.around do |example|
          usage = %i<repository>.include?(example.metadata[:type])
          usage ||= example.metadata[:database]

          if usage
            Verse::Plugin[:sequel].client(:rw) do |db|
              db.transaction do
                db.rollback_on_exit
                example.run
              end
            end
          else
            example.run
          end
        end
      end
    end
  end
end