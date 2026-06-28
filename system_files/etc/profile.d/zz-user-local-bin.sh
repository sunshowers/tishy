# Ensure ~/.local/bin is on PATH for login shells.
#
# The niri Wayland session is started by niri-session, which re-execs as a
# non-interactive *login* shell and then runs `systemctl --user
# import-environment`, baking that PATH into the systemd user manager (and thus
# niri and DMS). Login shells source /etc/profile.d but NOT ~/.zshrc/~/.bashrc,
# where users typically add ~/.local/bin -- so without this, session apps like
# DMS can't find user-installed binaries such as zed (DMS reports them "Not
# detected" and skips their matugen templates). Runs last (zz-) and is
# idempotent.
case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *) PATH="${HOME}/.local/bin:${PATH}" ; export PATH ;;
esac
