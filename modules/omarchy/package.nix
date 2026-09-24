# Upstream Omarchy (the `omarchy` flake input) as a package: the Quickshell
# shell, the omarchy-* commands, the default configs/templates and the
# themes, laid out under $out/share/omarchy — the OMARCHY_PATH everything
# upstream expects — with the commands also linked into $out/bin.
#
# NixOS adjustments, kept as small as possible so this tracks upstream:
#   - shebangs: #!/bin/bash and #!/usr/bin/python3 don't exist here.
#   - `replacements`: packages whose bin/omarchy-* are installed OVER the
#     upstream command of the same name. That's how the Arch-specific
#     commands (pacman installs, self-update, theme switching by copying
#     into ~/.local/state, …) get their declarative NixOS versions, with one
#     omarchy-<name> on PATH per name.
#   - the default bar layout drops widgets that only exist on Arch: the
#     separately-packaged omacom.elsewhen plugin and the pacman update
#     checker.
{ lib, stdenvNoCC, src, bash, python3, perl, jq, replacements ? [ ] }:

stdenvNoCC.mkDerivation {
  pname = "omarchy";
  version = "${lib.removeSuffix "\n" (builtins.readFile (src + "/version"))}-${builtins.substring 0 7 (src.rev or "dirty")}";
  inherit src;

  # patchShebangs resolves interpreters from the host inputs.
  buildInputs = [ bash (python3.withPackages (_: [ ])) perl ];
  nativeBuildInputs = [ jq ];
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    share=$out/share/omarchy
    mkdir -p $share $out/bin
    cp -r applications bin config default shell themes version icon.* logo.* $share/

    # Arch-only bar widgets out of the default layout.
    jq '.bar.layout |= with_entries(.value |= map(select(.id != "omacom.elsewhen" and .id != "omarchy.system-update")))' \
      config/omarchy/shell.json >$share/config/omarchy/shell.json

    for pkg in ${lib.escapeShellArgs replacements}; do
      for f in "$pkg"/bin/omarchy-*; do
        rm -f "$share/bin/$(basename "$f")"
        cp "$f" "$share/bin/"
      done
    done

    chmod -R u+w $share

    # Screensaver: ttfx (Omarchy's port of terminaltexteffects) isn't
    # packaged; tte takes the same flags. Track it by PID, since the
    # wrapped Python process isn't named ttfx for pgrep/pkill.
    substituteInPlace $share/bin/omarchy-screensaver \
      --replace-fail 'pkill -x ttfx' 'kill "''${tte_pid:-}"' \
      --replace-fail '  ttfx -i ' '  tte -i ' \
      --replace-fail 'while pgrep -t "''${tty#/dev/}" -x ttfx >/dev/null; do' \
                     'tte_pid=$!; while kill -0 "$tte_pid" 2>/dev/null; do'

    patchShebangs --host $share/bin $share/shell

    for f in $share/bin/*; do
      ln -s "$f" $out/bin/
    done

    runHook postInstall
  '';

  meta = {
    description = "Omarchy's Quickshell desktop shell, commands and themes, adapted for NixOS";
    homepage = "https://omarchy.org";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
