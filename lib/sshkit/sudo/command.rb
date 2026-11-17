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
  
    # The SudoNetssh backend stores redacted output, while the interaction handler must see the raw
    # output (Command#on_stdout/on_stderr would pass it the redacted one).
    #
    def interact(stream_name, data, channel)
      call_interaction_handler(stream_name, data, channel)
    end

    def store_stdout(data)
      @stdout = data
      @full_stdout += data
    end

    def store_stderr(data)
      @stderr = data
      @full_stderr += data
    end
  end
end
