# encoding: utf-8

class AvatarUploader < ImageUploader
  # Create different versions of your uploaded files:
  process :resize_to_limit => [120, 120]

  def store_dir
    File.join("local", "avatars")
  end

  # Provide a default URL as a default if there hasn't been a file uploaded:
  def default_url
    "/images/icons/noavatar.png"
  end
end
