# encoding: utf-8

class ImageUploader < CarrierWave::Uploader::Base
  include CarrierWave::RMagick

  storage :file

  def store_dir
    "images"
  end

  def filename
    model.id.to_s + File.extname(@filename) unless @filename.nil?
  end

  def extension_white_list
    %w(jpg jpeg gif png)
  end
end
