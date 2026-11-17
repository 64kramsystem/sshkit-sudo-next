module SSHKit
  module Sudo
    # Sends the password when a sudo prompt is the last thing a command printed.
    #
    # Output is matched per command/stream over a rolling tail, so prompts split across SSH chunks
    # are still recognized. The match is anchored at the end of the output (sudo waits for input
    # after printing the prompt), so ordinary output mentioning "password" (e.g. Chef's
    # "Disabling password aging … [15:19:27…") doesn't trigger a send; a spurious send would be
    # echoed by the PTY into the output.
    #
    class PasswordSendingInteractionHandler
      WRONG_PASSWORD_MESSAGE_REGEX = /Sorry.*\stry\sagain/

      # Classic sudo, and sudo-rs. Custom prompts (`sudo -p`, PAM's "Password:") can be configured via
      # the backend's `password_prompt_regex`; prefer patterns that can't match ordinary output.
      DEFAULT_PASSWORD_PROMPT_REGEX = /\[sudo\] password for [^:\s]+:|\[sudo: authenticate\] Password:/

      TAIL_SIZE = 256

      def initialize(servers_password, prompt_regex: nil)
        @servers_password = servers_password
        # Anchored at the end of the output, also for custom patterns.
        @prompt_regex = /(?:#{prompt_regex || DEFAULT_PASSWORD_PROMPT_REGEX})[ \t]*\z/
        @tails = {}
      end

      def on_data(command, stream_name, data, channel)
        key = [command.object_id, stream_name]
        tail = (@tails[key] || "".b) + data.b
        tail = tail.byteslice(-TAIL_SIZE, TAIL_SIZE) if tail.bytesize > TAIL_SIZE
        text = tail.dup.force_encoding(Encoding::UTF_8).scrub

        raise "Wrong password!" if text =~ WRONG_PASSWORD_MESSAGE_REGEX

        if text =~ @prompt_regex
          @tails.delete(key)
          channel.send_data(@servers_password)
        else
          @tails[key] = tail
        end
      end

      def forget(command)
        @tails.delete_if { |(command_id, _), _| command_id == command.object_id }
      end
    end
  end
end
