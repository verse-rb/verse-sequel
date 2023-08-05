RSpec.describe "SQLite setup" do
  before do
    Verse.start(
      :test,
      config_path: "./spec/spec_data/config.sqlite.yml"
    )
  end

  it "starts correctly" do
    raise "STOP"
  end
end