{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.hytale-server;

  port = toInt (last (splitString ":" cfg.bind));

  backupArgs = optionalString cfg.backup.enable
    "--backup --backup-dir backups --backup-frequency ${toString cfg.backup.frequency} --backup-max-count ${toString cfg.backup.maxCount}";

  # Assets path is relative to Server/ working directory
  serverArgs = concatStringsSep " " ([
    "--assets ../Assets.zip"
    "--bind ${cfg.bind}"
  ] ++ optional cfg.backup.enable backupArgs
    ++ cfg.extraArgs);

  java = "${cfg.package}/bin/java";
  unzip = "${pkgs.unzip}/bin/unzip";

  # The Hytale directory layout:
  #   dataDir/
  #     Assets.zip
  #     updater/staging/     <-- server stages updates here
  #     Server/
  #       HytaleServer.jar
  #       config.json, universe/, backups/, ...

  # Apply staged update — run from dataDir
  applyUpdates = ''
    if [ -f "updater/staging/Server/HytaleServer.jar" ]; then
      echo "[hytale] Applying staged update..."

      mkdir -p updater/backup/Server
      cp -f Server/HytaleServer.jar updater/backup/Server/
      [ -f Assets.zip ] && cp -f Assets.zip updater/backup/

      cp -f updater/staging/Server/HytaleServer.jar Server/
      if [ -d "updater/staging/Server/Licenses" ]; then
        rm -rf Server/Licenses
        cp -r updater/staging/Server/Licenses Server/
      fi
      [ -f "updater/staging/Server/HytaleServer.aot" ] && \
        cp -f updater/staging/Server/HytaleServer.aot Server/

      if [ -f "updater/staging/Assets.zip" ]; then
        if ${unzip} -tq "updater/staging/Assets.zip" >/dev/null 2>&1; then
          cp -f updater/staging/Assets.zip ./
          echo "[hytale] Assets.zip updated."
        else
          echo "[hytale] WARNING: staged Assets.zip is corrupt — keeping current version."
        fi
      fi

      rm -rf updater/staging
      echo "[hytale] Update applied."
    fi
  '';

  # Interactive start script — run in tmux for console access
  startScript = pkgs.writeShellScriptBin "hytale-server" ''
    set -euo pipefail
    cd "${cfg.dataDir}"

    while true; do
      ${applyUpdates}

      echo "[hytale] Starting server..."
      cd Server
      set +e
      ${java} ${cfg.jvmOpts} --enable-native-access=ALL-UNNAMED \
        -jar HytaleServer.jar ${serverArgs} "$@"
      EXIT_CODE=$?
      set -e
      cd "${cfg.dataDir}"

      if [ $EXIT_CODE -eq 8 ]; then
        echo "[hytale] Restarting to apply update..."
        continue
      fi

      exit $EXIT_CODE
    done
  '';

in
{
  options = {
    services.hytale-server = {
      enable = mkEnableOption "Hytale dedicated game server";

      package = mkOption {
        type = types.package;
        default = pkgs.jdk25_headless;
        defaultText = literalExpression "pkgs.jdk25_headless";
        description = "Java package to use (Hytale requires Java 25+).";
      };

      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/hytale-server";
        description = ''
          Top-level directory containing the Hytale server installation.
          Must already contain Assets.zip and a Server/ subdirectory
          with HytaleServer.jar. Use hytale-downloader to populate it.
        '';
      };

      bind = mkOption {
        type = types.str;
        default = "0.0.0.0:5520";
        description = "Address and port to bind to.";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to open UDP port in the firewall.";
      };

      backup = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable periodic world backups.";
        };

        frequency = mkOption {
          type = types.int;
          default = 30;
          description = "Backup interval in minutes.";
        };

        maxCount = mkOption {
          type = types.int;
          default = 5;
          description = "Maximum number of backups to retain.";
        };
      };

      jvmOpts = mkOption {
        type = types.separatedString " ";
        default = "-Xms4G -Xmx4G";
        description = "JVM options (memory, GC, etc).";
      };

      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Extra command-line arguments passed to HytaleServer.jar.";
        example = [ "--transport" "TCP" ];
      };
    };
  };

  config = mkIf cfg.enable {
    # `hytale-server` on PATH for interactive use (e.g. in tmux)
    environment.systemPackages = [ startScript ];

    # systemd service for headless operation (no console access).
    # Disable auto-start with: systemd.services.hytale-server.wantedBy = lib.mkForce [];
    systemd.services.hytale-server = {
      description = "Hytale Dedicated Server";

      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      preStart = ''
        cd ${cfg.dataDir}
        ${applyUpdates}
      '';

      serviceConfig = {
        WorkingDirectory = "${cfg.dataDir}/Server";

        ExecStart = "${java} ${cfg.jvmOpts} --enable-native-access=ALL-UNNAMED -jar HytaleServer.jar ${serverArgs}";

        # Exit code 8 = restart for update; systemd re-runs preStart which
        # applies the staged files before the server comes back up.
        RestartForceExitStatus = [ 8 ];
        SuccessExitStatus = [ 0 8 ];
        Restart = "on-failure";
        RestartSec = 10;
      };
    };

    networking.firewall.allowedUDPPorts = mkIf cfg.openFirewall [ port ];
  };
}
