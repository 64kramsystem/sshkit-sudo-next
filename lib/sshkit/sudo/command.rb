require 'sshkit'

# This is cosmetic, although it considerably improves the output. See  https://github.com/capistrano/sshkit/issues/490.
#
module SSHKit
  class Command
    def with(&_block)
      return yield if options[:user]
      env_string = environment_string
      return yield if env_string.empty?
      "( export #{env_string} ; #{yield} )"
    end
  end
end
