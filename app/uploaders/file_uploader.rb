# encoding: utf-8

class FileUploader < CarrierWave::Uploader::Base
  # Override the directory where uploaded files will be stored.
  # This is a sensible default for uploaders that are meant to be mounted:
  def store_dir
    if model and model.directory
      model.directory.full_path
    else
      Directory.find(Directory::ROOT).full_path
    end
    # .gsub(/public\//, '')
  end

  # Provide a default URL as a default if there hasn't been a file uploaded:
  # def default_url
  #   "/images/fallback/" + [version_name, "default.png"].compact.join('_')
  # end
end