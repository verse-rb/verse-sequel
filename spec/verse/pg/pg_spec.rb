# frozen_string_literal: true

require "spec_helper"

require_relative "./pg_model"

RSpec.describe "postgresql setup" do
  before :all do
    uri = YAML.safe_load(File.read("spec/spec_data/config.pg.simple.yml")).dig("plugins", 0, "config", "db", "uri")

    # Small trick: Connect to the pg database itself to drop and create database
    uri_pg = uri.gsub("verse_sequel_test", "postgres")

    Sequel.connect(uri_pg) do |db|
      db.execute "DROP DATABASE IF EXISTS verse_sequel_test"
      db.execute "CREATE DATABASE verse_sequel_test"
    end

    # Connec on the real db and create the structure
    Sequel.connect(uri) do |db|
      # Setup a sample structure.
      File.read(File.join("spec", "spec_data", "pg", "pg_fixtures.sql")).split(";").each do |query|
        db.execute query
      end
    end
  end

  %i<simple cluster>.each do |mode|
    context "mode #{mode}" do
      around :each do |example|
        Verse.start(
          :test,
          config_path: "./spec/spec_data/config.pg.#{mode}.yml"
        )

        Verse::Plugin[:sequel].client(:rw) do |db|
          db.transaction do
            example.run
          ensure
            raise Sequel::Rollback
          end
        end
      ensure
        Verse.stop
      end

      context "testing repository" do
        let(:question_repo){ Spec::Pg::QuestionRepository.new(Verse::Auth::Context[:system]) }
        let(:topic_repo){ Spec::Pg::TopicRepository.new(Verse::Auth::Context[:system]) }

        context "#index" do
          it "can query the questions" do
            questions = question_repo.index({})
            expect(questions.count).to be(3)
          end

          it "can query the question with included" do
            questions = question_repo.index({}, included: ["topic"])
            expect(questions.count).to be(3)
            expect(questions.first.topic).not_to be(nil)
          end

          it "can query the topics with included (has many link)" do
            topics = topic_repo.index({}, included: ["questions"])
            expect(topics.first.questions.count).to eq(2)
            expect(topics.first.questions.map(&:id)).to eq([2001, 2003])
          end

          it "decodes correctly" do
            questions = question_repo.index({})
            expect(questions.first.encoded).to eq("1234")
          end

          it "belongs_to with condition" do
            questions = question_repo.index({}, included: ["topic_with_condition"])

            questions.each do |q|
              if q.topic_id == 1001 # science topic
                expect(q.topic_with_condition).not_to be_nil
              else
                expect(q.topic_with_condition).to be_nil
              end
            end
          end

          context "with ordering" do
            it "can order collection (simple asc)" do
              questions = question_repo.index({}, sort: "id")
              expect(questions.first.id).to eq(2001)
            end

            it "can order collection (simple desc)" do
              questions = question_repo.index({}, sort: "-id")
              expect(questions.first.id).to eq(2003)
            end

            it "can order collection (multiple)" do
              questions = question_repo.index({}, sort: "-encoded,id") # ORDER BY encoded DESC, id ASC
              expect(questions.first.id).to eq(2001)
            end
          end

          context "with filtering" do
            it "can filter collection (simple)" do
              question = question_repo.index({ id: 2001 }).first
              expect(question.id).to eq(2001)
            end

            it "can filter collection (lt, gt)" do
              questions = question_repo.index({ id__lt: 2003, id__gt: 2001 })
              expect(questions.count).to eq(1)
            end

            it "can filter collection (lte, gte)" do
              questions = question_repo.index({ id__lte: 2003, id__gte: 2001 })
              expect(questions.count).to eq(3)
            end

            it "can filter collection (eq with nil)" do
              questions = question_repo.index({ custom: nil })
              expect(questions.count).to eq(1)
            end

            it "can filter collection (eq)" do
              questions = question_repo.index({ id__eq: 2002 })
              expect(questions.count).to eq(1)
            end

            context "eq with array" do
              it "can filter collection (eq with array)" do
                questions = question_repo.index({ id__eq: [2003, 2002] })
                expect(questions.count).to eq(2)
              end

              it "can filter collection (eq with empty array)" do
                questions = question_repo.index({ id__eq: [] })
                expect(questions.count).to eq(0)
              end

              it "can filter collection (eq with dataset)" do
                questions = question_repo.index({ id__eq: question_repo.table.where(id: [2003, 2002]).select(:id) })
                expect(questions.count).to eq(2)
              end
            end

            context "neq" do
              it "can filter out a result using a single value" do
                questions = question_repo.index({ id__neq: 2002 })
                expect(questions.count).to eq(2)
                expect(questions.map(&:id)).not_to include(2002)
              end

              it "can filter out results using an array of values" do
                questions = question_repo.index({ id__neq: [2001, 2003] })
                expect(questions.count).to eq(1)
                expect(questions.first.id).to eq(2002)
              end

              it "returns all records when neq is used with an empty array" do
                questions = question_repo.index({ id__neq: [] })
                expect(questions.count).to eq(3)
              end

              it "can filter out results using a dataset" do
                dataset = question_repo.table.where(id: [2001, 2003]).select(:id)
                questions = question_repo.index({ id__neq: dataset })
                expect(questions.count).to eq(1)
                expect(questions.first.id).to eq(2002)
              end

              it "can filter out null values" do
                questions = question_repo.index({ custom__neq: nil })
                expect(questions.count).to eq(2) # Assuming 2 records have non-null custom
                questions.each do |q|
                  expect(q.custom).not_to be_nil
                end
              end

              it "can filter out non-null values (i.e., keep only nulls)" do
                questions = question_repo.index({ custom__neq: { a: 1, b: 2 } })

                expect(questions.count).to eq(1)
                expect(questions.map(&:id)).to include(2002)
              end
            end

            it "can filter out result using prefix" do
              questions = question_repo.index({ content__prefix: "(C) Why is Hydro" })
              expect(questions.count).to eq(1)
              expect(questions.first.content).to match(/^\(C\) Why is Hydro/)
            end

            it "can filter out result using prefix (safe)" do
              questions = question_repo.index({ content__prefix: "(C) Why is Hydro%" })
              expect(questions.count).to eq(0)
            end

            it "can filter out result using suffix" do
              questions = question_repo.index({ content__suffix: "Argon?" })
              expect(questions.count).to eq(1)
              expect(questions.first.content).to match(/Argon?/)
            end

            it "can filter out result using suffix (safe)" do
              questions = question_repo.index({ content__suffix: "%Argon?" })
              expect(questions.count).to eq(0)
            end

            it "can filter collection (match)" do
              questions = question_repo.index({ content__match: "Hydrogen" })
              expect(questions.count).to eq(1)
              expect(questions.first.content).to match(/Hydrogen/)
            end

            context "contains" do
              it "contains in array" do
                questions = question_repo.index({ labels__contains: ["science", "sky"] })
                expect(questions.count).to eq(2)
              end

              it "contains in (empty) array" do
                questions = question_repo.index({ labels__contains: [] })
                expect(questions.count).to eq(0)
              end

              it "contains in jsonb" do
                questions = question_repo.index({ custom__contains: { a: 1 } })
                expect(questions.count).to eq(2)

                questions = question_repo.index({ custom__contains: { b: 2 } })
                expect(questions.count).to eq(1)
              end

              it "contains with string" do
                questions = question_repo.index({ labels__contains: "science" })
                expect(questions.count).to eq(2)
              end
            end

            it "can use custom filter" do
              questions = question_repo.index({ "content.starts_with": "(A) Why" } )
              expect(questions.count).to eq(1)
              expect(questions.first.content).to match(/^\(A\) Why/)
            end

            it "paginates" do
              questions = question_repo.index({}, page: 1, items_per_page: 1)
              expect(questions.count).to eq(1)
              questions = question_repo.index({}, page: 2, items_per_page: 1)
              expect(questions.count).to eq(1)
              questions = question_repo.index({}, page: 3, items_per_page: 1)
              expect(questions.count).to eq(1)
              questions = question_repo.index({}, page: 4, items_per_page: 1)
              expect(questions.count).to eq(0)

              questions = question_repo.index({}, page: 1, items_per_page: 2)
              expect(questions.count).to eq(2)
              questions = question_repo.index({}, page: 2, items_per_page: 2)
              expect(questions.count).to eq(1)
            end
          end
        end

        context "#find_by" do
          it "can query the questions" do
            question = question_repo.find_by({ id: 2002 })
            expect(question.id).to be(2002)
          end

          it "can query the question with array" do
            question = question_repo.find_by({ labels__contains: ["sky"] })
            expect(question.id).to be(2003)
          end

          it "can query the question with included" do
            question = question_repo.find_by({ id: 2002 }, included: ["topic"])
            expect(question.topic).not_to be(nil)
          end

          it "decodes correctly" do
            question = question_repo.find_by({ id: 2002 })
            expect(question.encoded).to eq("1234")
          end

          context "with filtering" do
            it "can filter collection (lt, gt)" do
              question = question_repo.find_by({ id__lt: 2002, id__gt: 2000 }) # should be id = 1
              expect(question.id).to be(2001)
            end

            it "can filter collection (match)" do
              question = question_repo.find_by({ content__match: "Hydrogen" })
              expect(question.content).to match(/Hydrogen/)
            end

            it "can use custom filter" do
              question = question_repo.find_by({ "content.starts_with": "(A) Why" })
              expect(question.content).to match(/^\(A\) Why/)
            end

            it "returns nil if not found" do
              question = question_repo.find_by({ content__match: "This is not in the db" })
              expect(question).to be(nil)
            end

            it "raises error using the find_by! alternative and not found" do
              expect do
                question_repo.find_by!({ content__match: "This is not in the db" })
              end.to raise_error(Verse::Error::RecordNotFound)
            end
          end
        end

        context "#update" do
          it "updates an existing model" do
            result = question_repo.update(2001, { content: "A new question?" })
            expect(result).to be(true)
          end

          it "encodes correctly" do
            question_repo.update(2001, { encoded: "2345" })
            encoded = question_repo.table.where(id: 2001).first[:encoded]
            expect(encoded).to eq("2.3.4.5")
            expect(question_repo.find_by({ id: 2001 }).encoded).to eq("2345")
          end

          it "encodes correctly (json)" do
            question_repo.update(2001, { custom: { a: 1 } })
            encoded = question_repo.find_by({ id: 2001 }).custom
            expect(encoded).to eq({ a: 1 })
          end

          it "returns false if the model doesn't exists" do
            # id not found
            result = question_repo.update(42, { content: "A new question?" })
            expect(result).to be(false)
          end

          it "raises error with update! when column is not found" do
            expect do
              question_repo.update!(42, { content: "A new question?" })
            end.to raise_error(Verse::Error::RecordNotFound)
          end

          it "handle update of empty array" do
            result = question_repo.update(2001, { labels: [] })
            expect(result).to be(true)
          end
        end

        context "#create" do
          it "creates a new record" do
            result = question_repo.create(content: "A new subject", topic_id: 1001)
            record = question_repo.find_by({ content: "A new subject" })
            expect(result).to eq(record.id.to_s) # the newly added ID, in string format.
          end

          it "encodes correctly" do
            result = question_repo.create(content: "A new subject", topic_id: 1001, encoded: "hello world")
            encoded = question_repo.table.where(id: result).first[:encoded]
            expect(encoded).to eq("h.e.l.l.o. .w.o.r.l.d")
          end

          it "encodes array correctly" do
            result = question_repo.create(content: "A new subject", topic_id: 1001, labels: ["science", "math"])
            labels = question_repo.table.where(id: result).first[:labels]

            expect(labels).to eq(::Sequel.pg_array(["science", "math"]))
          end

          it "fails to create a new record if postgres throw an error" do
            # missing content field, but set to NOT NULL
            expect do
              question_repo.create(topic_id: 1001)
            end.to raise_error(Verse::Error::CannotCreateRecord)
          end

          it "handle properly empty array" do
            result = question_repo.create(content: "A new subject", topic_id: 1001, labels: [])
            labels = question_repo.table.where(id: result).first[:labels]

            expect(labels).to eq(::Sequel.pg_array([]))
          end
        end

        context "#delete" do
          it "returns true if something is deleted" do
            result = question_repo.delete(2001)
            expect(result).to eq(true)
          end

          it "returns false if nothing is deleted" do
            result = question_repo.delete(42)
            expect(result).to eq(false)
          end
        end
      end
    end
  end
end
