# encoding: utf-8

class TeamUploader < ImageUploader
  # Create different versions of your uploaded files:
  process :resize_to_limit => [500, 200]

  def store_dir
    File.join("local", "logos")
  end

  # Provide a default URL as a default if there hasn't been a file uploaded:
  def default_url
    "/images/icons/noavatar.jpg"
  end
end
