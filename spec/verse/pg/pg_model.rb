# frozen_string_literal: true

module Spec
  module Pg
    class TopicRepository < Verse::Sequel::Repository
      self.table = "topics"
    end

    class TopicRecord < Verse::Model::Record::Base
      field :id, primary: true

      field :name

      has_many :questions, foreign_key: :topic_id, repository: "Spec::Pg::QuestionRepository"
    end

    # dumb encoder putting points everywhere.
    module PointEncoder
      module_function

      def encode(field)
        return nil if field.nil?

        field.split("").join(".")
      end

      def decode(field)
        return nil if field.nil?

        field.split(".").join
      end
    end

    class QuestionRepository < Verse::Sequel::Repository
      self.table = "questions"

      encoder :encoded, PointEncoder
      encoder :custom, Verse::Sequel::JsonEncoder
      encoder :labels, Verse::Sequel::PgArrayEncoder

      def cleanup_old_questions
        with_db_mode :rw do
          table.where(Sequel.lit("id < ?", 2000)).delete
        end
      end

      # just a simple test for custom filter
      custom_filter "content.starts_with" do |collection, value|
        collection.where(Sequel.lit("content LIKE ?", "#{value}%"))
      end
    end

    class QuestionRecord < Verse::Model::Record::Base
      field :id, primary: true

      field :content
      field :topic_id
      field :encoded
      field :custom

      belongs_to :topic, primary_key: :id, repository: "Spec::Pg::TopicRepository"

      belongs_to :topic_with_condition, primary_key: :id, foreign_key: :topic_id, repository: "Spec::Pg::TopicRepository", if: ->(record) {
        record[:content] =~ /Hydrogen/
      }
    end
  end
end
