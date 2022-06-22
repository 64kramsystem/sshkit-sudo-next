require 'sshkit/sudo/version'

# See https://piotrmurach.com/articles/writing-a-ruby-gem-specification for a good summary.
#
# The choice to include test files is arbitrary; they're not strictly required, and they don't necessarily
# provide value.
#
Gem::Specification.new do |spec|
  spec.name    = "sshkit-sudo-next"
  spec.version = SSHKit::Sudo::VERSION
  spec.summary = "SSHKit extension, for sudo operation with password input."
  spec.authors = ["Saverio Miroddi"]

  spec.email        = ["saverio.pub2@gmail.com"]
  spec.description  = "SSHKit extension, for sudo operation with password input."
  spec.homepage     = "https://github.com/saveriomiroddi/sshkit-sudo-next"
  spec.license      = "MIT"

  spec.files                 = Dir["lib/**/*"]
  # RDoc scans by default only `lib`.
  spec.extra_rdoc_files      = Dir["README.md", "CHANGELOG.md", "LICENSE.txt"]
  spec.require_paths         = ["lib"]
  # Binaries location; the contained files included automatically.
  spec.bindir                = "exe"
  spec.required_ruby_version = ">= 2.0.0"

  spec.add_dependency "sshkit", "~> 1.20.0"

  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", ">= 3.0"

  if spec.respond_to?(:metadata=)
    # There isn't a comprehensive reference; see https://guides.rubygems.org/specification-reference.
    #
    # Entries are optional; they'll show in the rubygems.org page.
    #
    spec.metadata = {
      # Restrict pushes to a single host (RubyGems 2.2.0+).
      "allowed_push_host" => "https://rubygems.org",

      "bug_tracker_uri"   => "https://github.com/saveriomiroddi/sshkit-sudo-next/issues",
      "changelog_uri"     => "https://github.com/saveriomiroddi/sshkit-sudo-next/blob/master/CHANGELOG.md",
      "documentation_uri" => "https://www.rubydoc.info/gems/sshkit-sudo-next",
      "homepage_uri"      => spec.homepage,
      "source_code_uri"   => "https://github.com/saveriomiroddi/sshkit-sudo-next"

      # Other entries:
      #
      #   "mailing_list_uri"
      #   "wiki_uri"
      #   "funding_uri"
    }
  end
end
