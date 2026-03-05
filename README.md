# hytale-server-nix

NixOS module for running a [Hytale](https://hytale.com) dedicated server.

There is no official Hytale server module in nixpkgs yet. This provides a
`services.hytale-server` option set with systemd integration, firewall
rules, and security hardening.

## Requirements

- NixOS with flakes enabled
- Hytale server files (`HytaleServer.jar` + `Assets.zip`) — download with
  the [Hytale Downloader CLI](https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual)
- Java 25+ (provided automatically via `pkgs.jdk25_headless`)

## Usage

Add as a flake input in your NixOS configuration:

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
# configuration.nix
{
  services.hytale-server = {
    enable = true;
    serverJar = "/path/to/Server/HytaleServer.jar";
    assetsZip = "/path/to/Assets.zip";
  };
}
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `enable` | `false` | Enable the Hytale server service |
| `serverJar` | — | Path to `HytaleServer.jar` |
| `assetsZip` | — | Path to `Assets.zip` |
| `package` | `pkgs.jdk25_headless` | Java package |
| `dataDir` | `/var/lib/hytale-server` | State directory (worlds, config, backups) |
| `bind` | `0.0.0.0:5520` | Bind address and UDP port |
| `openFirewall` | `true` | Auto-open UDP port |
| `jvmOpts` | `-Xms4G -Xmx4G` | JVM memory/GC flags |
| `backup.enable` | `true` | Periodic world backups |
| `backup.frequency` | `30` | Backup interval (minutes) |
| `backup.maxCount` | `5` | Max backups retained |
| `extraArgs` | `[]` | Extra args to `HytaleServer.jar` |

## Authentication

On first run, you need to authenticate interactively:

1. Start the server (or run it manually in a `nix-shell -p jdk25`)
2. In the server console: `/auth login device`
3. Visit the URL shown, enter the code
4. Run `/auth persistence` to switch to encrypted on-disk storage

After that, credentials persist across restarts and auto-refresh.

## World Transfer

To bring a singleplayer world from your PC, copy the save into
`<dataDir>/universe/worlds/` and optionally `<dataDir>/universe/players/`
for character progress. Hytale uses the same format for single and
multiplayer.

## Networking

Hytale uses **UDP port 5520** (QUIC protocol) by default. Make sure your
router/firewall forwards UDP, not TCP. Use `--transport TCP` via
`extraArgs` if you need TCP instead.
