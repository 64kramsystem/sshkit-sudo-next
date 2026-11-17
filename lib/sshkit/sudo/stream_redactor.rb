module SSHKit
  module Sudo
    # Replaces a secret in a chunked byte stream, including occurrences split across chunks: a
    # trailing fragment that could be the start of the secret is held back until the next chunk
    # (or #flush) decides it.
    #
    class StreamRedactor
      REPLACEMENT = "[REDACTED]".b

      def initialize(secret)
        @secret = secret.to_s.b
        @pending = "".b
      end

      def redact(data)
        return data if @secret.empty?

        rest = @pending + data.b
        redacted = "".b

        while (index = rest.index(@secret))
          redacted << rest.byteslice(0, index) << REPLACEMENT
          rest = rest.byteslice(index + @secret.bytesize, rest.bytesize)
        end

        held = held_back_size(rest)
        @pending = rest.byteslice(rest.bytesize - held, held)

        redacted << rest.byteslice(0, rest.bytesize - held)
      end

      # A fragment pending at the end of the stream may be a truncated echo of the secret.
      #
      def flush
        pending, @pending = @pending, "".b
        pending.empty? ? pending : REPLACEMENT.dup
      end

      private

      def held_back_size(buffer)
        [@secret.bytesize - 1, buffer.bytesize].min.downto(1) do |size|
          return size if buffer.end_with?(@secret.byteslice(0, size))
        end

        0
      end
    end
  end
end
