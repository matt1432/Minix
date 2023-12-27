{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.services.modded-minecraft-servers;

  # Server config rendering
  serverPropertiesFile = serverConfig:
    pkgs.writeText "server.properties"
    (mkOptionText serverConfig);

  encodeOptionValue = value: let
    encodeBool = value:
      if value
      then "true"
      else "false";
    encodeString = value: escape [":" "=" "'"] value;
    typeMap = {
      "bool" = encodeBool;
      "string" = encodeString;
    };
  in
    (typeMap.${builtins.typeOf value} or toString) value;

  mkOptionLine = name: value: let
    dotNames = ["query-port" "rcon-password" "rcon-port"];
    fixName = name:
      if elem name dotNames
      then
        stringAsChars
        (x:
          if x == "-"
          then "."
          else x)
        name
      else name;
  in "${fixName name}=${encodeOptionValue value}";

  mkOptionText = serverConfig: let
    # Merge declared options with extraConfig
    c =
      (builtins.removeAttrs serverConfig ["extra-options"])
      // serverConfig.extra-options;
  in
    concatStringsSep "\n"
    (mapAttrsToList mkOptionLine c);

  # Render EULA file
  eulaFile = builtins.toFile "eula.txt" ''
    # eula.txt managed by NixOS Configuration
    eula=true
  '';

  mkInstanceName = name: "mc-${name}";
in {
  options = {
    services.modded-minecraft-servers = {
      eula = mkOption {
        type = with types; bool;
        default = false;
        description = ''
          Whether or not you accept the Minecraft EULA
        '';
      };

      user = mkOption {
        default = "mc";
        type = types.str;
      };

      group = mkOption {
        default = "mc";
        type = types.str;
      };

      instances = mkOption {
        type = with types; attrsOf (submodule (import ./minecraft-instance-options.nix pkgs));
        default = {};
        description = ''
          Define instances of Minecraft servers to run.
        '';
      };
    };
  };

  config = let
    enabledInstances = filterAttrs (_: x: x.enable) cfg.instances;

    # Attrset options
    eachEnabledInstance = f: mapAttrs' (i: c: nameValuePair (mkInstanceName i) (f i c)) enabledInstances;

    serverPorts = mapAttrsToList (_: v: v.serverConfig.server-port) enabledInstances;
    rconPorts =
      mapAttrsToList
      (_: v: v.serverConfig.rcon-port)
      (filterAttrs (_: x: x.serverConfig.enable-rcon) enabledInstances);
    openRconPorts =
      mapAttrsToList
      (_: v: v.serverConfig.rcon-port)
      (filterAttrs (_: x: x.serverConfig.enable-rcon && x.openRcon) enabledInstances);
    queryPorts =
      mapAttrsToList
      (_: v: v.serverConfig.query-port)
      (filterAttrs (_: x: x.serverConfig.enable-query) enabledInstances);
  in {
    assertions = [
      {
        assertion = cfg.eula;
        message = "You must accept the Mojang EULA in order to run any servers.";
      }

      {
        assertion = (unique serverPorts) == serverPorts;
        message = "Your Minecraft instances have overlapping server ports. They must be unique.";
      }

      {
        assertion = (unique rconPorts) == rconPorts;
        message = "Your Minecraft instances have overlapping RCON ports. They must be unique.";
      }

      {
        assertion = (unique queryPorts) == queryPorts;
        message = "Your Minecraft instances have overlapping query ports. They must be unique.";
      }

      (
        let
          allPorts = serverPorts ++ rconPorts ++ queryPorts;
        in {
          assertion = (unique allPorts) == allPorts;
          message = "Your Minecraft instances have some overlapping ports among server, rcon and query ports. They must all be unique.";
        }
      )
    ];

    systemd.services =
      {
        tmuxServer = {
          description = "Master Tmux server that runs on boot";
          wantedBy = ["multi-user.target"];

          serviceConfig = {
            Type = "forking";
            User = cfg.user;
            ExecStart = "${pkgs.tmux}/bin/tmux new-session -s master -d";
            ExecStop = "${pkgs.tmux}/bin/tmux kill-session -t master";
          };
        };
      }
      // eachEnabledInstance (name: icfg: {
        description = "Minecraft Server ${name}";
        wantedBy = ["multi-user.target"];
        partOf = ["tmuxServer.service"];
        after = ["tmuxServer.service"];

        path = with pkgs; [icfg.jvmPackage bash];

        environment = {
          JVMOPTS = icfg.jvmOptString;
          MCRCON_PORT = toString icfg.serverConfig.rcon-port;
          MCRCON_PASS = "whatisloveohbabydonthurtmedonthurtmenomore";
        };

        # Add script option instead of running start.sh

        serviceConfig = let
          fullname = mkInstanceName name;
        in {
          Type = "oneshot";
          RemainAfterExit = true;
          KillMode = "none";
          KillSignal = "SIGCONT";
          ExecStart = concatStrings [
            "${pkgs.tmux}/bin/tmux new-session -s ${fullname} -d"
            " '/var/lib/minecraft/${fullname}/start.sh'"
          ];
          ExecStop = ''
            ${concatStrings [
              "${pkgs.tmux}/bin/tmux send-keys -t ${fullname}:0.0"
              " 'say SERVER SHUTTING DOWN. Saving map...' C-m"
              " 'save-all' C-m"
              " 'stop' C-m"
            ]}
            sleep 10
            ${pkgs.tmux}/bin/tmux kill-session -t ${fullname}
          '';
          User = cfg.user;
          Group = cfg.group;
          StateDirectory = fullname;
          WorkingDirectory = "/var/lib/minecraft/${fullname}";
        };

        preStart = ''
          # Ensure EULA is accepted
          ln -sf ${eulaFile} eula.txt

          # Ensure server.properties is present
          if [[ -f server.properties ]]; then
            mv -f server.properties server.properties.orig
          fi

          # This file must be writeable, because Mojang.
          cp ${serverPropertiesFile icfg.serverConfig} server.properties
          chmod 644 server.properties
        '';
      });

    users.users = optionalAttrs (cfg.user == "mc") {
      mc = {
        group = cfg.group;
        home = cfg.dataDir;
      };
    };

    users.groups = optionalAttrs (cfg.group == "mc") {
      mc = {};
    };

    networking.firewall.allowedUDPPorts = queryPorts;
    networking.firewall.allowedTCPPorts = serverPorts ++ queryPorts ++ openRconPorts;
  };
}
