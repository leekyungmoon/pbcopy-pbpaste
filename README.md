
# 🪶 pbcopy-pbpaste

**Featherweight `pbcopy` & `pbpaste` for Linux.**

Two plain bash scripts — **8 KB**, no daemon, no config, nothing else touched.


## Installation

```bash
git clone https://github.com/leekyungmoon/pbcopy-pbpaste.git && cd pbcopy-pbpaste && ./install
```

That's it. `./install` does the following, then checks that it all worked:
- installs `wl-clipboard` and `xclip` if they are missing;
- puts both commands in `/usr/local/bin`;
- makes sure bash and zsh pick them up, even when an alias (prezto, oh-my-zsh) used to shadow them;
- runs a copy → paste round trip and restores whatever was on your clipboard.

<details>
<summary>🤔 No sudo? (Click to expand)</summary>
<p>

```bash
$ ./install --user        # -> ~/.local/bin
```

</p>
</details>


## Usage

```bash
$ echo hello | pbcopy
$ pbpaste > note.txt
$ pbpaste --tmux-buffer   # read tmux's paste buffer instead
```

It works in bash, zsh and tmux, on Wayland and X11.
Over SSH, `pbcopy` copies through your terminal (OSC52). `pbpaste` has no clipboard to read there, so it fails clearly instead of guessing.


## Uninstall

```bash
$ ./uninstall
```

This removes the two commands and the one line `./install` may have added to your shell rc. Nothing else is left behind.


## License

[MIT](LICENSE). `pbcopy` started from [wookayin/dotfiles](https://github.com/wookayin/dotfiles) — thanks, [@wookayin](https://github.com/wookayin) 🙏
