# SSHKit::Sudo ("next" version)

Fork of the [SSHKit::Sudo](https://github.com/kentaroi/sshkit-sudo.git) project, with significant cleanups and some improvements.

This gem provides sudo password handling for SSHKit: when a remote command emits a `[sudo] password for <user>:` prompt, the configured password is sent automatically, so commands invoking `sudo` (whether via `as :root do … end` blocks or by literally including `sudo` in the command) don't require interactive password entry.
