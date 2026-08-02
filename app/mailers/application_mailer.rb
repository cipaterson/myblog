class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("BLOG_FROM_EMAIL", "noreply@example.com")
  layout "mailer"
end
