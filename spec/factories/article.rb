FactoryGirl.define do
  sequence :title do |n|
    "Article #{n}"
  end

  sequence :text do |n|
    (0..100).map{ (0...8).map { (65 + rand(26)).chr }.join }.join(" ")
  end

  factory :article do
    title
    text
  end
end