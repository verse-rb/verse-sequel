require "spec_helper"

require_relative "./sqlite_model"

RSpec.describe "sqlite setup" do
  before :all do
    uri = YAML.safe_load(
      File.read("spec/spec_data/config.sqlite.yml")
    ).dig('plugins', 0, 'config', 'uri')

    file = "tmp/test.sqlite"
    File.unlink(file) if File.exist?(file)

    # Connec on the real db and create the structure
    Sequel.connect(uri) do |db|
      # Setup a sample structure.
      File.read(File.join("spec", "spec_data", "sqlite", "sqlite_fixtures.sql")).split(";").each do |query|
        puts "Exec: #{query}"
        db.execute_ddl query
      end
    end
  end

  around :each do |example|
    Verse.start(
      :test,
      config_path: "./spec/spec_data/config.sqlite.yml"
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
    let(:question_repo){ Spec::Sqlite3::QuestionRepository.new(Verse::Auth::Context[:system]) }
    let(:topic_repo){ Spec::Sqlite3::TopicRepository.new(Verse::Auth::Context[:system]) }

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
        topics = topic_repo.index(included: ["questions"])
        expect(topics.first.questions.count).to eq(2)
        expect(topics.first.questions.map(&:id)).to eq([2001, 2003])
      end

      it "decodes correctly" do
        questions = question_repo.index()
        expect(questions.first.encoded).to eq("1234")
      end

      it "belongs_to with condition" do
        questions = question_repo.index(included: ["topic_with_condition"])

        questions.each do |q|
          if q.topic_id == 1001 # science topic
            expect(q.topic_with_condition).not_to be_nil
          else
            expect(q.topic_with_condition).to be_nil
          end
        end
      end


      context "with filtering" do
        it "can filter collection (simple)" do
          question = question_repo.index({ id: 2001 }).first
          expect(question.id).to be(2001)
        end

        it "can filter collection (lt, gt)" do
          questions = question_repo.index({ id__lt: 2003, id__gt: 2000 })
          expect(questions.count).to be(2)
        end

        it "can filter collection (match)" do
          questions = question_repo.index({ content__match: "Hydrogen" })
          expect(questions.count).to eq(1)
          expect(questions.first.content).to match(/Hydrogen/)
        end

        it "can use custom filter" do
          questions = question_repo.index({"content.starts_with": "Why"} )
          expect(questions.count).to be(3)
          expect(questions.first.content).to match(/^Why/)
        end

        it "paginates" do
          questions = question_repo.index(page: 1, items_per_page: 1)
          expect(questions.count).to be(1)
          questions = question_repo.index(page: 2, items_per_page: 1)
          expect(questions.count).to be(1)
          questions = question_repo.index(page: 3, items_per_page: 1)
          expect(questions.count).to be(1)
          questions = question_repo.index(page: 4, items_per_page: 1)
          expect(questions.count).to be(0)
        end
      end

    end

    context "#find_by" do
      it "can query the questions" do
        question = question_repo.find_by({id: 2002})
        expect(question.id).to be(2002)
      end

      it "can query the question with included" do
        question = question_repo.find_by({id: 2002}, included: ["topic"])
        expect(question.topic).not_to be(nil)
      end

      it "decodes correctly" do
        question = question_repo.find_by({id: 2002})
        expect(question.encoded).to eq("1234")
      end

      context "with filtering" do
        it "can filter collection (lt, gt)" do
          question = question_repo.find_by({id__lt: 2002, id__gt: 2000}) # should be id = 1
          expect(question.id).to be(2001)
        end

        it "can filter collection (match)" do
          question = question_repo.find_by({content__match: "Hydrogen"})
          expect(question.content).to match(/Hydrogen/)
        end

        it "can use custom filter" do
          question = question_repo.find_by({"content.starts_with": "Why"})
          expect(question.content).to match(/^Why/)
        end

        it "returns nil if not found" do
          question = question_repo.find_by({content__match: "This is not in the db"})
          expect(question).to be(nil)
        end

        it "raises error using the find_by! alternative and not found" do
          expect do
            question = question_repo.find_by!({content__match: "This is not in the db"})
          end.to raise_error(Verse::Error::RecordNotFound)
        end
      end
    end

    context "#update" do
      it "updates an existing model" do
        result = question_repo.update(2001, {content: "A new question?"})
        expect(result).to be(true)
      end

      it "encodes correctly" do
        result = question_repo.update(2001, {encoded: "2345"})
        encoded = question_repo.table.where(id: 2001).first[:encoded]
        expect(encoded).to eq("2.3.4.5")
      end

      it "returns false if the model doesn't exists" do
        # id not found
        result = question_repo.update(42, {content: "A new question?"})
        expect(result).to be(false)
      end

      it "raises error with update! when column is not found" do
        expect do
          question_repo.update!(42, {content: "A new question?"})
        end.to raise_error(Verse::Error::RecordNotFound)
      end

    end

    context "#create" do
      it "creates a new record" do
        result = question_repo.create(content: "A new subject", topic_id: 1001)
        expect(result).to eq("2004") # the newly added ID, in string format.
      end

      it "encodes correctly" do
        result = question_repo.create(content: "A new subject", topic_id: 1001, encoded: "hello world")
        encoded = question_repo.table.where(id: result).first[:encoded]
        expect(encoded).to eq("h.e.l.l.o. .w.o.r.l.d")
      end

      it "fails to create a new record if postgres throw an error" do
        # missing content field, but set to NOT NULL
        expect do
          result = question_repo.create(topic_id: 1001)
        end.to raise_error(Verse::Error::CannotCreateRecord)
      end
    end

    context '#delete' do
      it 'returns true if something is deleted' do
        result = question_repo.delete(2001)
        expect(result).to eq(true)
      end

      it 'returns false if nothing is deleted' do
        result = question_repo.delete(42)
        expect(result).to eq(false)
      end
    end
  end

end
