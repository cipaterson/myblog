# Idempotent: safe to run repeatedly.
#
# Set ADMIN_EMAIL and ADMIN_PASSWORD to control the admin account. The fallbacks
# below exist so `bin/rails db:seed` just works in development — always pass real
# values in production.

email = ENV.fetch("ADMIN_EMAIL", "admin@example.com")
password = ENV.fetch("ADMIN_PASSWORD", "password123")

admin = User.find_by(email_address: email)

if admin
  puts "Admin #{email} already exists."
else
  User.create!(email_address: email, password: password)
  puts "Created admin #{email} with password #{password.inspect} — change it before going live."
end

if Post.none?
  Post.create!(
    title: "Hello",
    published_at: Time.current,
    body: <<~HTML
      <div>This is the first post. Log in, hit <strong>New post</strong>, and write something.</div>
      <div>Drag an image straight into the editor — it uploads automatically and is served at 800px wide, no matter how big the original was.</div>
    HTML
  )
  puts "Created a sample post."
end
