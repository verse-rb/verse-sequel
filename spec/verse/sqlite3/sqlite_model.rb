# frozen_string_literal: true

module Spec
  module Sqlite3
    class TopicRepository < Verse::Sequel::Repository
      self.table = "topics"
    end

    class TopicRecord < Verse::Model::Record::Base
      field :id, primary: true

      field :name

      has_many :questions, foreign_key: :topic_id, repository: "Spec::Sqlite3::QuestionRepository"
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

      belongs_to :topic, primary_key: :id, repository: "Spec::Sqlite3::TopicRepository"

      belongs_to :topic_with_condition, primary_key: :id, foreign_key: :topic_id, repository: "Spec::Sqlite3::TopicRepository", if: ->(record) {
        record[:content] =~ /Hydrogen/
      }
    end
  end
end
