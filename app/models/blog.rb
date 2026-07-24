# Site-wide settings. Override BLOG_NAME in the environment to rename the blog
# without touching code.
module Blog
  NAME = ENV.fetch("BLOG_NAME", "Myblog")
end
