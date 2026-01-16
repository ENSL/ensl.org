RSpec.configure do |config|
  config.before(:suite) do
    # Clean the database to ensure a fresh state
    # because transactional fixtures are disabled
    DatabaseCleaner.clean_with(
      :truncation,
      except: %w[ar_internal_metadata]
    )
  end

  config.before(:each) do
    # Use transaction because it's faster
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each, js: true) do
    # Use deletion for JS tests because transaction doesn't work
    # with Capybara's JS driver
    DatabaseCleaner.strategy = :deletion
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.append_after(:each) do
    DatabaseCleaner.clean
  end
end
