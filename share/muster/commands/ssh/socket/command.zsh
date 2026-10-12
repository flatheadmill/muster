function :help:ssh:socket {
    help=$(<${functions_source[:help:ssh:socket]:A:h}/help.md)
}

function :args:ssh:socket {
    typeset parsed
    parsed=$(args -UC -bx h,help -- "$@") || return
    eval "$parsed"
}

function muster_ssh_socket_refresh {
    [[ $OSTYPE == darwin* ]] || abend 'fatal: ssh socket is supported only on macOS'
    (( ${+commands[launchctl]} )) || abend 'fatal: launchctl must be on PATH'

    typeset socket
    socket=$(launchctl asuser $EUID launchctl getenv SSH_AUTH_SOCK) ||
        abend 'fatal: unable to read the local launchd SSH agent'
    [[ -n $socket && -S $socket ]] ||
        abend 'fatal: the local launchd SSH agent is unavailable: %s' "$socket"

    typeset directory=$HOME/.ssh/agent
    typeset link=$directory/local
    typeset temporary=$directory/.local.$$
    [[ ! -e $link || -L $link ]] ||
        abend 'fatal: refusing to replace non-symlink: %s' "$link"

    mkdir -p "$directory" || return
    chmod 700 "$directory" || return
    {
        ln -s "$socket" "$temporary" || return
        mv -f "$temporary" "$link" || return
    } always {
        [[ -L $temporary ]] && rm -f "$temporary"
    }

    (( o_quiet )) || print -r -- "$link -> $socket"
}

function muster_ssh_socket_install {
    [[ $OSTYPE == darwin* ]] || abend 'fatal: ssh socket is supported only on macOS'
    [[ -x $HOME/.local/bin/muster ]] ||
        abend 'fatal: install muster at %s before installing the socket refresher' "$HOME/.local/bin/muster"

    typeset label=com.flatheadmill.muster.ssh-socket
    typeset agents=$HOME/Library/LaunchAgents
    muster_state_root
    typeset state=$REPLY
    typeset plist=$agents/$label.plist
    typeset temporary=$plist.$$
    mkdir -p "$agents" "$state" || return

    heredoc -f \
        "$label" \
        "$HOME/.local/bin/muster" \
        "$HOME/.local/bin:$HOME/.dotfiles/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" \
        "$state/ssh-socket.log" \
        > "$temporary" <<'    EOF'
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>%s</string>
            <key>ProgramArguments</key>
            <array>
                <string>%s</string>
                <string>ssh</string>
                <string>socket</string>
                <string>refresh</string>
                <string>--quiet</string>
            </array>
            <key>EnvironmentVariables</key>
            <dict>
                <key>PATH</key>
                <string>%s</string>
            </dict>
            <key>RunAtLoad</key>
            <true/>
            <key>StartInterval</key>
            <integer>60</integer>
            <key>StandardOutPath</key>
            <string>/dev/null</string>
            <key>StandardErrorPath</key>
            <string>%s</string>
        </dict>
        </plist>
    EOF
    {
        [[ $(grep -c '^<?xml version=' "$temporary") == 1 ]] \
            || abend 'fatal: generated more than one property list'
        plutil -lint "$temporary" >/dev/null || return
        chmod 644 "$temporary" || return
        mv -f "$temporary" "$plist" || return
    } always {
        [[ -f $temporary ]] && rm -f "$temporary"
    }

    typeset domain=gui/$EUID
    launchctl bootout "$domain/$label" 2>/dev/null || true
    launchctl bootstrap "$domain" "$plist" || return
    launchctl kickstart -k "$domain/$label" || return
    print -r -- "installed $label (60 seconds)"
}

function :execute:ssh:socket {
    delegate "$@"
}
