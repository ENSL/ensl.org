class FileUploader < CarrierWave::Uploader::Base
  # Configure storage root to use FILES_ROOT env var
  # This allows files to be stored in public/files (dev) or external path (production)
  def root
    ENV['FILES_ROOT'] ||= File.join(Rails.root, 'public', 'files')
  end

  # Override the directory where uploaded files will be stored.
  # Returns path relative to the root directory (FILES_ROOT)
  def store_dir
    if model and model.directory
      # Use relative path from FILES_ROOT
      rel = model.directory.relative_path
      rel.empty? ? '' : rel
    else
      ''
    end
  end

  # Provide a default URL as a default if there hasn't been a file uploaded:
  # def default_url
  #   "/images/fallback/" + [version_name, "default.png"].compact.join('_')
  # end
end
