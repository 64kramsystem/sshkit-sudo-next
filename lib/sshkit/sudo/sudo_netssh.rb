require 'sshkit'
require_relative 'password_sending_interaction_handler'
require_relative 'stream_redactor'
require_relative 'command'

module SSHKit
  module Backend
    # Values that are static, like the filtered logging patterns, or the name of the env variables,
    # can be implemented, if needed, as Configuration attributes.
    #
    class SudoNetssh < Netssh

      SKIP_STDOUT_LOGGING_PATTERNS = [
        /^\r\n$/,
        # Skipping this removes context from the wrong password prompt, but it's still understandable.
        SSHKit::Sudo::PasswordSendingInteractionHandler::DEFAULT_PASSWORD_PROMPT_REGEX,
      ]

      class << self
        # `pool` is a class-level instance variable, so we can't use the superclass' attr_accessor.
        # The attribute is only read though, so we don't need to handle assignments.
        #
        def pool
          self.superclass.pool
        end

        # It's not possible to send a custom configuration class, so we need to create a custom one.
        # The :owner could be an instance variable, but it's a bit ugly to use a different setting
        # strategy.
        #
        def config
          @config ||= Class.new(Netssh::Configuration) do
            attr_accessor :owner, :servers_password, :commands_log, :password_prompt_regex
          end.new
        end
      end

      def initialize(*args, &block)
        super

        # A single snapshot, so that the sent and the redacted passwords can't diverge.
        @password = normalize_password(self.class.config.servers_password)
        @prompt_regex = self.class.config.password_prompt_regex ||
          SSHKit::Sudo::PasswordSendingInteractionHandler::DEFAULT_PASSWORD_PROMPT_REGEX
        @interaction_handler = SSHKit::Sudo::PasswordSendingInteractionHandler.new(
          @password + "\n", prompt_regex: @prompt_regex
        )
      end

      def capture(*args)
        # To ensure that we clean out the sudo part when the results are returned,
        # otherwise the commands will be corrupt.
        #
        super.gsub(/(?:#{@prompt_regex})[ \t]*/, '')
      end

      # Required because the uploaded file is owned by the SSH user, not the owner.
      #
      def upload!(local, remote, options = {})
        super

        # We can't check the user inside the :as block, because @user is root.
        #
        target_user = @user || self.class.config.owner

        as :root do
          execute :chown, target_user, remote
        end
      end

      private

      # The configured value may carry trailing newlines (once, one was required).
      #
      def normalize_password(value)
        password = value.to_s.sub(/[\r\n]+\z/, '')
        raise ArgumentError, "The servers password can't contain newlines" if password =~ /[\r\n]/

        password
      end

      def handle_stdout(cmd, data)
        return if data.empty?

        cmd.store_stdout(data)
        skip_stdout_logging = SKIP_STDOUT_LOGGING_PATTERNS.any? { |pattern| data =~ pattern }
        output.log_command_data(cmd, :stdout, data) unless skip_stdout_logging
      end

      def handle_stderr(cmd, data)
        return if data.empty?

        cmd.store_stderr(data)
        output.log_command_data(cmd, :stderr, data)
      end

      def command(args, options)
        options[:interaction_handler] ||= @interaction_handler

        env = (@env || {})

        if @user
          # As general Linux practice, switching user is not enough - some variables need to be updated
          # as well.
          # For an explanation, see https://saveriomiroddi.github.io/Chef-properly-run-a-resource-as-alternate-user.
          #
          user_home = @user == 'root' ? '/root' : "/home/#{@user}"
          env = env.merge(user: @user, home: user_home, rails_env: fetch(:rails_env))
        end

        SSHKit::Command.new(*args, options.merge(
          {
            in: pwd_path,
            env: env,
            host: @host,
            user: @user,
            group: @group,
          }
        ))
      end

      def execute_command(cmd)
        output.log_command_start(cmd)
        cmd.started = true
        exit_status = nil
        # Defense in depth: the password must never reach logs, captures or exception messages,
        # even if echoed back (PTY echo), so output is redacted before SSHKit stores or logs it.
        # The interaction handler is fed the raw output, on the live channel.
        stdout_redactor = SSHKit::Sudo::StreamRedactor.new(@password)
        stderr_redactor = SSHKit::Sudo::StreamRedactor.new(@password)
        begin
          with_ssh do |ssh|
            ssh.open_channel do |chan|
              chan.request_pty
              prepared_command = cmd.to_command

              if self.class.config.commands_log
                IO.write(self.class.config.commands_log, prepared_command + "\n", mode: 'a')
              end

              chan.exec prepared_command do |_ch, _success|
                chan.on_data do |ch, data|
                  cmd.interact(:stdout, data, ch)
                  handle_stdout(cmd, stdout_redactor.redact(data))
                end
                chan.on_extended_data do |ch, _type, data|
                  cmd.interact(:stderr, data, ch)
                  handle_stderr(cmd, stderr_redactor.redact(data))
                end
                chan.on_request("exit-status") do |_ch, data|
                  exit_status = data.read_long
                end
                #chan.on_request("exit-signal") do |ch, data|
                #  # TODO: This gets called if the program is killed by a signal
                #  # might also be a worthwhile thing to report
                #  exit_signal = data.read_string.to_i
                #  warn ">>> " + exit_signal.inspect
                #  output.log_command_killed(cmd, exit_signal)
                #end
                chan.on_open_failed do |_ch|
                  # TODO: What do do here?
                  # I think we should raise something
                end
                chan.on_process do |_ch|
                  # TODO: I don't know if this is useful
                end
                chan.on_eof do |_ch|
                  # TODO: chan sends EOF before the exit status has been
                  # writtend
                end
              end
              chan.wait
            end
            ssh.loop
          end
          handle_stdout(cmd, stdout_redactor.flush)
          handle_stderr(cmd, stderr_redactor.flush)
        ensure
          @interaction_handler.forget(cmd)
        end
        # Set exit_status and log the result upon completion
        if exit_status
          cmd.exit_status = exit_status
          output.log_command_exit(cmd)
        end
      end
    end # class SudoNetssh
  end # module Backend
end # module SSHKit
