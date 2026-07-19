# frozen_string_literal: true

module MailBodyHelper
  def delivered_email_body(email)
    email.text_part&.decoded || email.html_part&.decoded || email.body.decoded
  end
end

RSpec.configure do |config|
  config.include MailBodyHelper
end
