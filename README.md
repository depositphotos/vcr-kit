# vcr-kit

One-command setup of the VistaCreate engineering kit on macOS: Claude Code with the team's plugins, the
command-line tools they rely on, and access to the services they use.

```bash
curl -fsSL https://raw.githubusercontent.com/depositphotos/vcr-kit/master/install.sh | bash
```

> **Status: work in progress.** The bootstrap works; the kit's main script is not published yet, so for now it
> stops after fetching the kit.

This repository holds only the bootstrap. It asks before every step:

1. checks that it runs on macOS;
2. installs Homebrew and the GitLab CLI if they are missing;
3. signs you in to GitLab in the browser;
4. fetches the rest of the kit from a private repository and starts `vcr-kit setup`.

You need a VistaCreate GitLab account with access to that repository; without one the bootstrap stops at
step 4. Running the bootstrap again updates the kit. Later, `vcr-kit doctor` checks what is missing and
`vcr-kit update` updates the kit.

The kit is cloned into `~/.local/share/vcr-kit` (override with `VCR_KIT_HOME`) and the `vcr-kit` command is
linked into `~/.local/bin` (override with `VCR_KIT_BIN`). If that directory is not on your `PATH`, the bootstrap
offers to add it to your shell profile.

The bootstrap contains no credentials, and it never asks you to type a secret anywhere but your own terminal.
