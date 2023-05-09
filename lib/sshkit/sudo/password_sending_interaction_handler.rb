module SSHKit
  module Sudo
    # Slightly simplified version of the original:
    #
    # - assumed that there is a password
    # - assumes the same pwd for the hosts
    # - replaced the class/dead methods with constants
    # - removed the InteractionHandler subclass
    #
    class PasswordSendingInteractionHandler
      WRONG_PASSWORD_MESSAGE_REGEX = /Sorry.*\stry\sagain/
      PASSWORD_PROMPT_REGEX = /[Pp]assword.*:/

      def initialize(servers_password)
        @servers_password = servers_password
      end

      def on_data(command, stream_name, data, channel)
        raise "Wrong password!" if data =~ WRONG_PASSWORD_MESSAGE_REGEX

        if data =~ PASSWORD_PROMPT_REGEX
          pass = @servers_password
puts "CP>>> #{pass.inspect}"
          channel.send_data(pass)
        end
      end
    end
  end
end
