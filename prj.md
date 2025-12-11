# Project Requirements Document (prj.md)

## List Usage Rules
1. **Lists that require priority**: For workflows that guide the agent through prioritized reasoning steps, use numbered lists where smaller numbers mean higher priority.
2. **Lists without priority**: For structural content such as file trees or project overviews, use unordered lists or simple numbering that does not imply priority.
3. Prioritized lists should follow the logical order and importance of the task-processing steps.
4. Non-prioritized lists should use bullets or simple numbering strictly for organization.

## Project Overview
This is an automated server configuration tool that helps users set up a new cloud server quickly, including network proxy tools, remote access, developer environments, and similar common configurations for one-click provisioning.

## 1. Project Requirements
1.1 **Core feature requirements**:
1.1.1 Automatically install and configure a network proxy such as `clashctl`.
1.1.2 Automatically deploy remote access solutions such as `zerotier` or `frp`.
1.1.3 Automatically install and configure Docker.
1.1.4 Automatically initialize a `zsh` environment (e.g., `set -o vi`, custom prompts).
1.1.5 Allow users to clone the project from GitHub and run all configuration steps in one command.
1.1.6 Provide modular configuration options so users can choose which modules to run.
1.2 **Technical requirements**:
1.2.1 Use shell scripts as the primary implementation for cross-platform compatibility.
1.2.2 Adopt a modular design for easier maintenance and extensibility.
1.2.3 Target Ubuntu 22.04 and Ubuntu 24.04 as the initial supported Linux distributions.
1.2.4 Keep the distro detection and branching logic ready for future expansion to other distributions.
1.2.5 Implement error handling and logging for easier debugging.
1.3 **Security requirements**:
1.3.1 Protect data security.
1.3.2 Guard against common security vulnerabilities.
1.3.3 Follow secure development best practices.

## 2. Project Management
2.1 **Roles**:
2.1.1 Codex agent: executes the project according to `codex.md` while maintaining its own history and prompts.
2.1.2 User: provides requirements, feedback, and coordinates decisions.
2.2 **Communication**:
2.2.1 Collaborate directly with the user for clarifications and approvals.
2.2.2 Update `codex.md` and `prj.md` whenever major decisions or requirement changes happen.
2.2.3 Report progress proactively, especially after significant changes or blockers.

## 3. Technical Solution
3.1 **Project layout**:
```
./
├── prj.md               # Project requirements
├── codex/               # Codex history and prompts
│   ├── codex.md         # Task-handling rules and history
│   ├── prompt.md        # Codex agent prompt
│   └── log.template     # Log-entry template
├── tlnx                 # Main configuration script
├── lib/                 # Core library scripts
│   ├── common.sh        # Shared functions
│   ├── config.sh        # Configuration utilities
│   ├── module.sh        # Module management
│   └── remote.sh        # Remote execution helper
├── modules/             # Individual module scripts
│   ├── init.sh          # System bootstrap module
│   ├── git.sh           # Git module
│   ├── vim.sh           # Vim editor module
│   ├── zsh.sh           # ZSH module
│   ├── zerotier.sh      # ZeroTier networking module
│   ├── frp.sh           # FRP tunneling module
│   ├── clashctl.sh      # Clashctl proxy module
│   └── docker.sh        # Docker module
├── config/              # Configuration files
│   ├── default.conf     # Default config example
│   ├── default.conf.template  # Config template
│   └── enc.conf.enc     # Encrypted config
├── docker/              # Container assets
│   └── test-image/
│       └── Dockerfile   # Prebuilt test image used by the Docker harness
├── packages/            # Offline bundles (e.g., clash-for-linux-install.tar.gz)
├── scripts/             # Helper scripts
│   ├── decrypt.sh       # Decryption helper
│   └── encrypt.sh       # Encryption helper
├── logs/                # Log directory
└── .gitignore           # Git ignore rules
```
3.2 **Configuration management**:
- **Config file description**:
  - `config/default.conf.template`: Template listing every available variable, including encrypted and environment-detection variables.
  - `config/default.conf`: Default config used in development; contains all environment variables and is the base configuration.
  - `config/enc.conf.enc`: Sensitive config encrypted with AES-256 that stores secrets.
  - `config/enc.conf`: Decrypted plaintext config generated at runtime (not tracked by Git) to store decrypted values.

- **Config loading flow**:
  1. Load `config/default.conf` as the base.
  2. If an encryption key is provided via `CONFIG_KEY`, decrypt `config/enc.conf.enc` to `config/enc.conf`.
  3. Load `config/enc.conf` and override relevant base values.
  4. Allow CLI arguments to override any configuration value.

- **Git ignore policy**: Add the encrypted config (`config/enc.conf.enc`), decrypted config (`config/enc.conf`), and log files (`logs/`) to `.gitignore` to keep secrets and logs out of GitHub.

- **Environment variable guide**: Refer to `config/default.conf.template` for the full list of variables and explanations.
- **Module orchestration**:
  - `config/default.conf` seeds `CONFIG_MODULES=("init" "git" "vim" "zsh" "zerotier" "frp" "clashctl" "docker")` so networking, editor, and proxy tooling install automatically on new hosts.
  - Override the default list via `--modules`, `--select-modules`, or by editing the config when bespoke orderings are needed.
- **Offline package staging**:
  - Prebuilt archives (for example `clash-for-linux-install.tar.gz`) live under `packages/` so air-gapped installs stay reproducible.
  - `checkout_package_file` extracts each archive into `run/packages/<name>` before the owning module runs.
  - Modules consume the extracted content directly, minimizing external downloads except for explicit inputs such as subscription URLs.

3.3 **Execution flow**:
1. The user clones the project from GitHub.
2. Run `./tlnx` (or `bash tlnx`) with optional CLI arguments or environment variables.
3. The script loads the library files and logging configuration.
4. Parse CLI options (`-h/--help`, `-l/--log-level`, `-t/--test`, `-f/--force`, `--modules`, `--select-modules`, `-e VAR=value`, `-d/--decrypt`, `-c/--encrypt`, `--set-http-proxy`).
5. Before each module runs, check its timestamped mark inside `run/marks`. When the mark exists and the config files (`config/default.conf`, `config/enc.conf`) are newer, the mark is cleared so the module reruns; otherwise the module is skipped unless `-f/--force` is supplied.
6. If `-d/--decrypt` is specified:
   - Decrypt `config/enc.conf.enc` into `config/enc.conf`.
   - Exit after decryption completes.
7. If `-c/--encrypt` is specified:
   - Encrypt `config/enc.conf` into `config/enc.conf.enc`.
   - Exit after encryption completes.
8. Apply any CLI overrides passed via `-e VAR=value` after both configs load so the user can force values without editing files.
9. When a sudo command is required, try `TLNX_PASSWD` first, then `LOCAL_USER_PASSWD_X`, then `REMOTE_ENC_PASSWORD_X`; cache whichever password works in `TLNX_PASSWD` before falling back to an interactive prompt.
10. If running in remote mode (`REMOTE_RUN=false`):
   - Compress the project and transfer it to the target host via `rsync`.
   - Extract it on the target and run the script there.
   - Pass `SSH_CLIENT_HOST` to mark the remote session.
11. If running locally:
   - Detect the current OS (Linux or macOS).
   - Load the default configuration.
   - When `CONFIG_KEY` is available, decrypt and load the encrypted config.
   - When the `--select-modules` flag is used, list every available module script with numbers and prompt the user to choose modules by their indices (e.g., `1,3`).
   - When `-f/--force` is set, skip module "already installed" checks so install hooks rerun even if a module reports success previously.
   - Execute the selected modules in order.
12. Generate configuration logs.
13. Display the result and help information.

3.7 **Manual verification scripts**:
- `tests/manual_git_module.sh` provisions Git inside a disposable `HOME` so global config changes stay inside the repo.
- `tests/manual_init_bash_setup.sh`, `tests/manual_init_basic_info.sh`, and `tests/manual_init_ssh_keys.sh` exercise specific init subroutines.
- `tests/manual_zsh_module.sh` spins up a throwaway HOME directory, runs the ZSH module end-to-end, and prints the resulting `.zshrc` plus the log location so shell customization can be validated without touching the real workstation.

3.8 **Clashctl module**:
- Purpose: install the Clash/Clashctl proxy stack so outbound traffic respects the configured subscription as soon as the base environment is ready.
- Packaging flow:
  1. `_clashctl_install` calls `checkout_package_file clash-for-linux-install`, which extracts `packages/clash-for-linux-install.tar.gz` into `run/packages/clash-for-linux-install`.
  2. When `CLASHCTL_SUB_X` is set in the config, the module fetches the subscription YAML into `resources/config.yaml` inside the extracted directory.
  3. The module runs the bundled `uninstall.sh` and `install.sh` via `sudo $SHELL` to ensure a clean re-install each time.
  4. All stdout/stderr streams are tee'd into `logs/server_config-*.log` so proxy provisioning diagnostics stay captured.
- Because the tarball lives inside the repo, Clashctl installs succeed even on air-gapped machines; only the optional subscription download hits the network.

3.9 **ZeroTier module**:
- Installs the official ZeroTier package via the upstream bootstrap script.
- When `ZEROTIER_NETWORK_ID` (or its encrypted counterpart) is populated, the module automatically joins that network so the node becomes reachable over the virtual overlay.
- Skips the join step gracefully when no network ID is supplied.

3.10 **FRP module**:
- Extracts `packages/frp.tar.gz`, installs the `frpc` and `frps` binaries into `/usr/local/bin`, and copies template configs from `etc/.conf/frp/` into `~/.config/frp/`.
- Validates each TOML config with `frpc verify`/`frps verify` before generating systemd units that reference the extracted configs and binaries.
- Honors the `FRPC_AUTO_START` and `FRPS_AUTO_START` flags so services only start when explicitly requested, keeping air-gapped setups under user control.

3.11 **Vim module**:
- Installs Vim via apt when it is missing, then drops a conservative `.vimrc` if the user does not already have one.
- The generated config turns on syntax highlighting, indentation helpers, and a few quality-of-life defaults so machines without prior editor setup remain usable out of the box.

3.12 **Docker test harness**:
- When `DOCKER_TEST_ENABLED="true"` (default in `config/default.conf` during development), running `./tlnx` on the host spawns a disposable Ubuntu 24.04 container via Docker, bind-mounts the entire repository to `/root/tlnx`, overlays `/root/tlnx/run` with an in-memory tmpfs so host state is untouched, and re-invokes the script inside that container.
- The harness injects `TLNX_DOCKER_CHILD=1` so the inner run does not recursively start more containers, then streams the execution logs back to the host terminal.
- Each container receives a timestamped `DOCKER_TEST_CONTAINER_PREFIX` (default `tlnx-test-YYYYmmddHHMMSS`) and remains running after the test so the user can inspect it with `sudo docker exec -it <name> bash`.
- Before creating a new container, the harness prunes old ones labeled `tlnx.testcontainer=true`, keeping at most `DOCKER_TEST_MAX_CONTAINERS` (default 5) so local Docker does not accumulate stale runs.
- The harness builds a reusable image defined by `docker/test-image/Dockerfile` (default tag `tlnx/test:ubuntu24`) whenever it is missing; the file pre-installs `systemd`, `sudo`, `psmisc`, and certificates so repeated apt-get runs are unnecessary.
- `DOCKER_TEST_BUILD_CONTEXT` and `DOCKER_TEST_DOCKERFILE` point at the repo-managed Dockerfile so developers can tweak the sandbox without editing scripts; if these paths are empty the harness falls back to pulling the `DOCKER_TEST_IMAGE`.
- The Ubuntu base tag remains configurable through `DOCKER_TEST_IMAGE` should you want to test against another distro, and encryption/decryption helpers (`./tlnx -d/-c`) always run locally so password prompts remain interactive.
- Disable the harness by setting `DOCKER_TEST_ENABLED="false"` (or exporting `TLNX_DOCKER_CHILD=1`) when provisioning an actual host instead of the disposable Docker sandbox.
- Each container is named with the timestamped prefix and receives its hostname from `INIT_HOSTNAME` (falling back to the generated name) during `docker run`, avoiding in-container hostnamectl failures on bind-mounted `/etc/hostname`.
- The test image pre-installs util-linux (script), dialog, sshpass, libterm-readline-perl-perl, tzdata, and systemd-timesyncd; prerequisites verify timesyncd and tzdata are present before modules run.

3.4 **Remote execution flow**:
1. The local script sees `REMOTE_RUN=false`.
2. Collect target host information (user, hostname, port).
3. Archive the project directory into a `.tar.gz` file.
4. Use `rsync` to copy the archive to the target's temporary directory.
5. Extract the archive to the final target directory.
6. Update the remote config to set `REMOTE_RUN=true`.
7. Read the local hostname and pass it via `SSH_CLIENT_HOST`.
8. Use SSH to connect to the target and run the script.
9. Leave the project files on the remote machine after completion.

3.5 **Help message flow**:
1. The user runs `./tlnx -h` or `./tlnx --help`.
2. The script calls `display_usage`.
3. Show tool name and version.
4. Detect remote mode using the `SSH_CLIENT_HOST` environment variable.
5. Show the current execution mode and hostname.
6. List usage instructions, options, and examples, including `-f/--force`, `-e VAR=value`, the `-d/-c` flags, `--set-http-proxy`, and `--select-modules`, which lists modules by number and allows numeric selection (e.g., `1,3,4`).
7. When running remotely, show the client host information.

3.6 **Location of Codex documentation artifacts**:
- Codex documentation files live in the `codex/` directory.
- They include `codex/codex.md`, `codex/prompt.md`, and `codex/log.template`.
- These files are tracked in Git and serve as the living history of the project.
- After the project finishes, the files can remain for maintenance purposes.

## 4. Configuration Template Design
4.1 **Template**: `config/default.conf.template` lists every available configuration item; users can consult it for the supported environment variables.

4.2 **Encrypted variable naming convention**

Encrypted variables follow the format `${module}_ENC_${varname}`.

Examples:
- `CLASHCTL_ENC_URL`: Encrypted Clashctl binary download URL.
- `ZEROTIER_ENC_NETWORK_ID`: Encrypted Zerotier network ID.
- `FRP_ENC_AUTH_TOKEN`: Encrypted FRP auth token.

4.3 **Config encryption mechanism**:
- **Algorithm**: AES-256-CBC with PBKDF2 key derivation.
- **Security**:
  - PBKDF2 uses 100000 iterations for stronger security.
  - Every encrypted file includes a unique random salt.
  - Each encryption run uses an initialization vector (IV).
- Encryption script (`scripts/encrypt.sh`):
  - Accepts the key via environment variable or interactive input.
  - Sends prompts to stderr so ciphertext output stays clean.
  - Uses PBKDF2 for secure key derivation.
  - Allows custom key environment variable names.

- Decryption script (`scripts/decrypt.sh`):
  - Accepts the key via environment variable or interactive input.
  - Sends prompts to stderr to avoid corrupting decrypted output.
  - Uses PBKDF2 for secure key derivation.
  - Allows custom key environment variable names.
  - Returns 0 on success and 1 on failure.

- Main-script decryption flow:
  - Check whether `config/enc.conf.enc` exists.
  - When it exists, see if `config/enc.conf` is present and newer than the encrypted file.
  - If the decrypted file is missing or older, run the decryption step.
  - Log the reason for decrypting in detail.
  - After decrypting, source the config to load the variables.
  - If decryption fails, log the error and continue with the default configuration.
  - Support manual decryption with the `-d` flag.
  - Support manual encryption with the `-c` flag.

4.4 **Sensitive data handling**
- All sensitive entries use the `_ENC_` suffix following the `${module}_ENC_${varname}` pattern.
- Sensitive placeholders in `default.conf` can be set to `!!!!!!!ENCRYPTED!!!!!!!` or left blank.
- Encrypted configs are tracked by Git so teams can share them.
- Decrypted configs are untracked to keep secrets safe.

## 5. Codex Asset Handling
5.1 **File locations**:
- Store all Codex documentation files under `codex/`.
- Includes `codex/codex.md`, `codex/prompt.md`, and `codex/log.template`.

5.2 **Git ignore policy**:
```gitignore
# .gitignore

# Configuration
config/enc.conf.enc  # Encrypted config tracked by git
config/enc.conf       # Decrypted config generated at runtime (ignored)

# Logs
logs/

# Temp files
*.tmp
*.swp
```

## 6. Usage Examples
```bash
# Clone from GitHub
git clone https://github.com/user/tlnx.git
cd tlnx

# Run the default local configuration
./tlnx

# Run locally with encrypted config
CONFIG_KEY=your-secret-key ./tlnx

# Test mode (no side effects)
./tlnx -t

# Run with DEBUG log level
./tlnx -l DEBUG

# Show help
./tlnx -h

# Remote execution (configure the target in config/default.conf first)
# REMOTE_RUN=false
# TARGET_HOST=your-server-ip
# TARGET_USER=your-username
# TARGET_PORT=22  # optional
./tlnx

# Remote execution for specific modules
./tlnx --modules docker,zsh
# Refresh the Clashctl proxy tooling alone
./tlnx --modules clashctl

# Override configuration values at runtime (applied after configs load)
./tlnx -e REMOTE_RUN=true -e LOG_LEVEL=DEBUG
# Repeat `-e` flags to override multiple values; overrides are evaluated left-to-right so later flags win when they target the same variable.

# Provide the sudo password via config/`-e` to avoid interactive prompts
./tlnx -e LOCAL_USER_PASSWD_X='your-password'

# Use the -d flag to decrypt
./tlnx -d

# Use the -c flag to encrypt
./tlnx -c

# Decrypt using an env-var key
CONFIG_KEY=your-secret-key ./tlnx -d

# Encrypt using an env-var key
CONFIG_KEY=your-secret-key ./tlnx -c

# Run selected modules only
./tlnx --modules docker,zsh

# Interactively choose modules from the displayed list
./tlnx --select-modules

# Force re-running the docker module even if it reports as installed
./tlnx -f --modules docker

# Persist HTTP proxy settings and exit
./tlnx --set-http-proxy http://proxy:port
```
