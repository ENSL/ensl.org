Dir.glob(File.join(Rails.root, 'lib/plugins/*')).sort.each do |directory|
  next unless File.directory?(directory)

  lib = File.join(directory, 'lib')

  if File.directory?(lib)
    $:.unshift lib
    ActiveSupport::Dependencies.autoload_paths += [lib]
  end

  initializer = File.join(directory, 'init.rb')

  next unless File.file?(initializer)

  # Load legacy plugin initializer. Using `load` avoids evaluating
  # the file via string `eval`, which is dangerous. Legacy initializers
  # should reference `Rails.application.config` instead of a local `config`.
  begin
    load initializer
  rescue StandardError => e
    Rails.logger.warn "Failed to load legacy initializer #{initializer}: #{e.message}"
  end
end
