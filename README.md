# hytale-server-nix

NixOS module for running a [Hytale](https://hytale.com) dedicated server.

There is no official Hytale server module in nixpkgs yet. This provides a
`services.hytale-server` option set with systemd integration, firewall
rules, and security hardening.

## Quick Start (manual, no module)

```bash
cd ~/hytale/raw
nix-shell -p jdk25
cd Server
java -Xms4G -Xmx4G --enable-native-access=ALL-UNNAMED -jar HytaleServer.jar --assets ../Assets.zip --backup --backup-dir backups --backup-frequency 30
```

Run it in a tmux session so it survives SSH disconnects:

```bash
tmux new -s hytale
# run the above, then Ctrl-b d to detach
# tmux attach -t hytale to reattach
```

## Server Auth

On first boot the server has no credentials. In the server console:

1. `/auth login device` -- gives you a URL + code
2. Open the URL in a browser, enter the code
3. `/auth persistence` -- **important!** switches from `Memory` to `Encrypted` so tokens persist across reboots
4. `/auth status` -- verify it shows `Encrypted` store

Without step 3, you have to re-auth every time you restart.

## Admin / Operator

From the server console:

```
/op add <username>       # make someone an op
/op remove <username>    # remove op
```

Note: `/op self` only works from in-game, not the console.

## Password

Set in `Server/config.json`:

```json
"Password": "yourpassword"
```

Requires a server restart. Players are prompted to enter it on connect.
Set to `""` to disable.

## Whitelist

All from console or in-game as op, takes effect immediately:

```
whitelist enable             # only listed players + ops can join
whitelist disable            # anyone can join
whitelist add <username>     # allow a player (by username, not UUID)
whitelist remove <username>  # revoke
```

Ops bypass the whitelist automatically.

## World Transfer

Singleplayer saves are at:
- **Windows**: `%appdata%\Hytale\UserData\Saves\`
- **macOS**: `~/Library/Application Support/Hytale/UserData/Saves/`
- **Linux**: `~/.local/share/Hytale/UserData/Saves/`

Each save has a `universe/` folder. Copy it into your server's working
directory (`Server/universe/`). Player inventory is per-universe, stored
in `universe/players/`.

If the server says "failed to find instance" and generates a fresh world,
also copy the top-level `permissions.json`, `bans.json`, and
`whitelist.json` from the save into `Server/`.

## Multiple Worlds

Hytale supports multiple worlds in one universe under
`universe/worlds/<name>/`. However, player data is shared across all
worlds in the same universe (inventory carries over). If you want
separate inventories, run separate server instances with different
`--universe` paths and different ports (`--bind 0.0.0.0:5521`).

Useful commands:

```
/world add <name>            # create a new world
/tp world <name>             # teleport to another world
```

## Networking

Hytale uses **UDP port 5520** (QUIC protocol) by default. Make sure your
firewall opens UDP, not TCP.

On NixOS, add to your firewall config:

```nix
networking.firewall.allowedUDPPorts = [ 5520 ];
```

## NixOS Module Usage

Add as a flake input:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    hytale-server.url = "github:kaolin/hytale-server-nix";
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

Then in your configuration:

```nix
services.hytale-server = {
  enable = true;
  serverJar = "/path/to/Server/HytaleServer.jar";
  assetsZip = "/path/to/Assets.zip";
};
```

## Module Options

| Option | Default | Description |
|--------|---------|-------------|
| `enable` | `false` | Enable the Hytale server service |
| `serverJar` | -- | Path to `HytaleServer.jar` |
| `assetsZip` | -- | Path to `Assets.zip` |
| `package` | `pkgs.jdk25_headless` | Java package |
| `dataDir` | `/var/lib/hytale-server` | State directory (worlds, config, backups) |
| `bind` | `0.0.0.0:5520` | Bind address and UDP port |
| `openFirewall` | `true` | Auto-open UDP port |
| `jvmOpts` | `-Xms4G -Xmx4G` | JVM memory/GC flags |
| `backup.enable` | `true` | Periodic world backups |
| `backup.frequency` | `30` | Backup interval (minutes) |
| `backup.maxCount` | `5` | Max backups retained |
| `extraArgs` | `[]` | Extra args to `HytaleServer.jar` |

## Requirements

- NixOS with flakes enabled (for the module), or just `nix-shell -p jdk25` for manual use
- Hytale server files (`HytaleServer.jar` + `Assets.zip`) -- download with
  the [Hytale Downloader CLI](https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual)
- Java 25+ (provided automatically)
