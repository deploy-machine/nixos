{ config, lib, pkgs, username, ... }:
let
  # Databases the Omarchy menu (Install > Development > Docker DB) has
  # enabled. The menu edits dbs.json with jq and triggers a rebuild, so the
  # containers stay declarative — the NixOS analog of omarchy's raw
  # `docker run` in omarchy-install-docker-dbs. Images/ports/credentials
  # mirror omarchy upstream (dev-friendly: empty/known passwords, bound to
  # localhost only).
  dbState = builtins.fromJSON (builtins.readFile ./dbs.json);

  dbDefs = {
    mysql = {
      image = "mysql:8.4";
      ports = [ "127.0.0.1:3306:3306" ];
      environment = {
        MYSQL_ROOT_PASSWORD = "";
        MYSQL_ALLOW_EMPTY_PASSWORD = "true";
      };
      volumes = [ "omarchy-mysql:/var/lib/mysql" ];
    };
    mariadb = {
      image = "mariadb:11.8";
      ports = [ "127.0.0.1:3306:3306" ];
      environment = {
        MARIADB_ROOT_PASSWORD = "";
        MARIADB_ALLOW_EMPTY_ROOT_PASSWORD = "true";
      };
      volumes = [ "omarchy-mariadb:/var/lib/mysql" ];
    };
    postgres = {
      image = "postgres:18";
      ports = [ "127.0.0.1:5432:5432" ];
      environment.POSTGRES_HOST_AUTH_METHOD = "trust";
      volumes = [ "omarchy-postgres:/var/lib/postgresql" ];
    };
    redis = {
      image = "redis:7";
      ports = [ "127.0.0.1:6379:6379" ];
      volumes = [ "omarchy-redis:/data" ];
    };
    mongodb = {
      image = "mongo:noble";
      ports = [ "127.0.0.1:27017:27017" ];
      environment = {
        MONGO_INITDB_ROOT_USERNAME = "admin";
        MONGO_INITDB_ROOT_PASSWORD = "admin123";
      };
      volumes = [ "omarchy-mongodb:/data/db" ];
    };
    # Upstream image is x86_64-only; the menu labels it accordingly.
    mssql = {
      image = "mcr.microsoft.com/mssql/server:2022-CU12-ubuntu-22.04";
      ports = [ "127.0.0.1:1433:1433" ];
      environment = {
        MSSQL_PID = "Developer";
        ACCEPT_EULA = "Y";
        MSSQL_SA_PASSWORD = "@dmin123";
      };
      volumes = [ "omarchy-mssql:/var/opt/mssql" ];
    };
  };

  enabledDbs = lib.filter (n: dbDefs ? ${n}) dbState.enabled;
in
{
  # Docker backs the menu-managed database containers and the SUPER+SHIFT+D
  # lazydocker binding. Matches omarchy (docker, not podman). The channel's
  # default docker (28.5.2 on 25.11) carries a knownVulnerabilities marking;
  # docker_29 on the same channel is clean, so pin it explicitly.
  virtualisation.docker.enable = true;
  virtualisation.docker.package = pkgs.docker_29;
  users.users.${username}.extraGroups = [ "docker" ];

  virtualisation.oci-containers = {
    backend = "docker";
    containers = lib.genAttrs enabledDbs (name: dbDefs.${name});
  };

  environment.systemPackages = [ pkgs.lazydocker ];
}
