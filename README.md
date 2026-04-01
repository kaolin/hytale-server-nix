# hytale-server-nix

NixOS module for running a [Hytale](https://hytale.com) dedicated server.

Provides a `services.hytale-server` option set that gives you:

- **`hytale-server` command** on PATH -- handles java, JVM args, update staging, and restart loop
- **systemd service** for headless operation with auto-restart on updates
- **Update integrity checking** -- validates Assets.zip before applying staged updates
- **Firewall rules** -- auto-opens UDP port

## Quick start

### 1. Download server files

```bash
mkdir -p ~/hytale && cd ~/hytale
# Get the downloader from https://support.hytale.com/hc/en-us/articles/45326769420827
./hytale-downloader-linux-amd64
unzip *.zip   # creates Server/ and Assets.zip
```

### 2. Add to your NixOS flake

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    hytale-server = {
      url = "github:kaolin/hytale-server-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, hytale-server, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        hytale-server.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

### 3. Configure

```nix
# configuration.nix
services.hytale-server = {
  enable = true;
  dataDir = "/home/you/hytale";  # directory containing Assets.zip and Server/
};
```

### 4. Rebuild and run

```bash
sudo nixos-rebuild switch

# Interactive (console access for /op, /update, etc.)
tmux new -s hytale
hytale-server

# Or headless via systemd
sudo systemctl start hytale-server
```

## Directory layout

The module expects the standard Hytale layout:

```
dataDir/
  Assets.zip                    # game assets
  updater/staging/              # server stages updates here
  updater/backup/               # pre-update backups (created automatically)
  Server/
    HytaleServer.jar            # server binary
    config.json                 # server config
    universe/                   # worlds and player data
    backups/                    # periodic world backups
```

## Updating

From the server console:

```
/update download        # download latest version
/update apply --confirm # apply and restart
/update status          # check update state
```

The wrapper script applies staged updates on restart and validates
Assets.zip integrity before replacing it. If a staged Assets.zip is
corrupt, the current version is kept and a warning is logged.

To re-download everything manually:

```bash
cd ~/hytale
./hytale-downloader-linux-amd64
```

## Interactive vs systemd

**Interactive** (`hytale-server` in tmux) gives you console access for
commands like `/op`, `/update`, `/auth`. The script handles the update
restart loop.

**Systemd** (`systemctl start hytale-server`) runs headless. Updates
are applied via `preStart` on restart. Exit code 8 triggers automatic
restart. View logs with `journalctl -u hytale-server -f`.

To disable auto-start on boot (interactive-only):

```nix
systemd.services.hytale-server.wantedBy = lib.mkForce [];
```

## First-time auth

On first boot, run these in the server console:

1. `/auth login device` -- gives you a URL + code
2. Open the URL in a browser, enter the code
3. `/auth persistence` -- switches to encrypted storage (persists across restarts)
4. `/auth status` -- verify it shows `Encrypted`

## Module options

| Option | Default | Description |
|--------|---------|-------------|
| `enable` | `false` | Enable the Hytale server |
| `dataDir` | `/var/lib/hytale-server` | Top-level directory (contains Assets.zip + Server/) |
| `package` | `pkgs.jdk25_headless` | Java package (requires 25+) |
| `bind` | `0.0.0.0:5520` | Bind address and UDP port |
| `openFirewall` | `true` | Auto-open UDP port |
| `jvmOpts` | `-Xms4G -Xmx4G` | JVM memory/GC flags |
| `backup.enable` | `true` | Periodic world backups |
| `backup.frequency` | `30` | Backup interval (minutes) |
| `backup.maxCount` | `5` | Max backups retained |
| `extraArgs` | `[]` | Extra args to `HytaleServer.jar` |

## Networking

Hytale uses **UDP port 5520** (QUIC protocol). Make sure your firewall
opens UDP, not TCP.
