# vcr-kit

One-command setup of the VistaCreate engineering kit on macOS: Claude Code with the team's plugins, the
command-line tools they rely on, and access to the services they use.

```bash
curl -fsSL https://raw.githubusercontent.com/depositphotos/vcr-kit/master/install.sh | bash
```

This is **express** by default: it sets up a working VistaCreate project with the team's preset (every production
repository, the developer plugins, the optional parts) and asks only for the sign-ins and secrets only you can give.
To choose every step yourself, run it **detailed**:

```bash
curl -fsSL https://raw.githubusercontent.com/depositphotos/vcr-kit/master/install.sh | VCR_KIT_DETAILED=1 bash
```

This repository holds only the bootstrap. Its steps (detailed asks before each one):

1. checks that it runs on macOS;
2. installs Homebrew and the GitLab CLI if they are missing (Homebrew's formula list is updated before the install);
3. signs you in to GitLab in the browser;
4. fetches the rest of the kit (the released version, branch `release`) from a private repository and starts
   `vcr-kit setup`.

You need a VistaCreate GitLab account with access to that repository; without one the bootstrap stops at
step 4. Running the bootstrap again updates the kit. Later, `vcr-kit doctor` checks what is missing and
`vcr-kit update` updates the kit.

The kit is cloned into `~/.local/share/vcr-kit` (override with `VCR_KIT_HOME`) and the `vcr-kit` command is
linked into `~/.local/bin` (override with `VCR_KIT_BIN`). If that directory is not on your `PATH`, the bootstrap
offers to add it to your shell profile. `VCR_KIT_REF=master` fetches the newest, unreleased kit instead, to try it
before a release.

The bootstrap contains no credentials, and it never asks you to type a secret anywhere but your own terminal.
