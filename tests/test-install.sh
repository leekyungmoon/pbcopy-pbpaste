#!/usr/bin/env bash
# End-to-end test of ./install and ./uninstall in a throwaway HOME.
# No sudo, no apt, no real clipboard: --prefix/--no-apt, and fake Wayland
# tools on PATH that keep the "clipboard" in a file.

set -uo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
home=$work/home prefix=$work/bin fake=$work/fake
mkdir -p "$home" "$prefix" "$fake"
fails=0
check() { if eval "$2"; then :; else echo "FAIL: $1"; fails=$((fails + 1)); fi; }

# rc files with the aliases prezto/oh-my-zsh define on Linux.
printf '%s\n' '# my zshrc' "alias pbcopy='xclip -selection clipboard -in'" \
  "alias pbpaste='xclip -selection clipboard -out'" >"$home/.zshrc"
printf '%s\n' '# my bashrc' "alias pbcopy='xsel -ib'" >"$home/.bashrc"
cp "$home/.zshrc" "$work/zshrc.orig"; cp "$home/.bashrc" "$work/bashrc.orig"

# A fake live Wayland clipboard backed by a file.
clip=$work/clipboard
printf 'precious\nclipboard' >"$clip"
cat >"$fake/wl-paste" <<FAKE
#!/bin/bash
case \${1:-} in
  --list-types) [[ -s "$clip" ]] && echo 'text/plain;charset=utf-8' || { echo 'Nothing is copied' >&2; exit 1; } ;;
  --no-newline) [[ -s "$clip" ]] && cat "$clip" || { echo 'Nothing is copied' >&2; exit 1; } ;;
esac
FAKE
cat >"$fake/wl-copy" <<FAKE
#!/bin/bash
[[ \${1:-} == --clear ]] && { : >"$clip"; exit 0; }
cat >"$clip"
FAKE
chmod 755 "$fake/wl-paste" "$fake/wl-copy"

run() {  # run a repo script in the throwaway environment
  env -i HOME="$home" PATH="$prefix:$fake:/usr/bin:/bin" WAYLAND_DISPLAY=wayland-0 \
    TERM=dumb NO_COLOR=1 "$@"
}

out=$(run "$repo/install" --prefix "$prefix" --no-apt 2>&1); rc=$?
check "install exits 0" '[[ $rc == 0 ]]'
check "commands installed" '[[ -x $prefix/pbcopy && -x $prefix/pbpaste ]]'
check "zsh alias removed" 'grep -q "zsh: pbcopy/pbpaste resolve to the installed commands (removed a shadowing alias" <<<"$out"'
check "bash alias removed" 'grep -q "bash: pbcopy/pbpaste resolve to the installed commands (removed a shadowing alias" <<<"$out"'
check "round trip reported" 'grep -q "round trip through the wayland clipboard" <<<"$out"'
check "clipboard restored" '[[ $(cat "$clip") == $'"'"'precious\nclipboard'"'"' ]]'
check "clipboard never printed" '! grep -q precious <<<"$out"'
check "all set" 'grep -q "All set" <<<"$out"'

# Idempotent: a second run adds nothing.
out2=$(run "$repo/install" --prefix "$prefix" --no-apt 2>&1); rc=$?
check "rerun exits 0" '[[ $rc == 0 ]]'
check "zshrc block added once" '[[ $(grep -c "^# >>> pbcopy-pbpaste >>>" "$home/.zshrc") == 1 ]]'
check "bashrc block added once" '[[ $(grep -c "^# >>> pbcopy-pbpaste >>>" "$home/.bashrc") == 1 ]]'

# The installed commands really win in both shells now.
check "zsh resolves" '[[ $(run zsh -ic "whence -p pbcopy" 2>/dev/null </dev/null) == "$prefix/pbcopy" ]]'
# (Ubuntu's /etc/bash.bashrc may print a sudo hint first; read only our line.)
check "bash resolves" '[[ $(run bash -ic "echo \"pb: \$(type -P pbcopy) \$(type -t pbcopy)\"" 2>/dev/null </dev/null | grep "^pb: ") == "pb: $prefix/pbcopy file" ]]'

# An empty clipboard: the self-check must leave it empty.
: >"$clip"
out3=$(run "$repo/install" --prefix "$prefix" --no-apt 2>&1)
check "empty clipboard stays empty" '[[ ! -s $clip ]]'

# Without a session: still a clean install, with an honest note.
out4=$(env -i HOME="$home" PATH="$prefix:/usr/bin:/bin" TERM=dumb NO_COLOR=1 \
  "$repo/install" --prefix "$prefix" --no-apt 2>&1); rc=$?
check "headless install exits 0" '[[ $rc == 0 ]]'
check "headless note" 'grep -q "no graphical session here" <<<"$out4"'

# Uninstall restores everything exactly.
run "$repo/uninstall" --prefix "$prefix" >/dev/null 2>&1
check "commands removed" '[[ ! -e $prefix/pbcopy && ! -e $prefix/pbpaste ]]'
check "zshrc restored byte for byte" 'cmp -s "$home/.zshrc" "$work/zshrc.orig"'
check "bashrc restored byte for byte" 'cmp -s "$home/.bashrc" "$work/bashrc.orig"'

# Another pbcopy that is not ours is never removed.
printf '#!/bin/sh\necho mine\n' >"$prefix/pbcopy"; chmod 755 "$prefix/pbcopy"
run "$repo/uninstall" --prefix "$prefix" >/dev/null 2>&1
check "foreign pbcopy kept" '[[ -x $prefix/pbcopy ]]'

if (( fails )); then echo "FAIL: $fails install check(s)"; exit 1; fi
echo "ok: install/uninstall end to end"
