# Dev shell for Trace: pwsh, PowerShell Editor Services (for Emacs/eglot) and
# what archived/poc/attach needs (QEMU, ssh, python's http.server).
#   nix-shell            or, with direnv:  direnv allow   (.envrc: use nix)
{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShellNoCC {
  packages = with pkgs; [
    powershell                   # pwsh >= 7.4
    powershell-editor-services   # LSP + PSScriptAnalyzer
    qemu                         # qemu-system-aarch64, qemu-img, edk2 firmware
    openssh
    python3
  ];

  # nasr-powershell.el starts PSES from here.
  PSES_BUNDLE_PATH = "${pkgs.powershell-editor-services}/lib/powershell-editor-services";
  # archived/poc/attach/up.sh: UEFI firmware (Debian/Ubuntu keep it in /usr/share/qemu).
  QEMU_EFI = "${pkgs.qemu}/share/qemu/edk2-aarch64-code.fd";

  # Gallery modules (README: powershell-yaml; Pester for tests) go in a
  # project-local dir instead of the user scope.
  shellHook = ''
    mkdir -p "$PWD/.modules"
    export PSModulePath="$PWD/.modules''${PSModulePath:+:$PSModulePath}"
    for m in powershell-yaml Pester; do
      [ -d "$PWD/.modules/$m" ] || pwsh -NoLogo -NoProfile -Command \
        "Save-PSResource -Name $m -Path '$PWD/.modules' -TrustRepository -Quiet" \
        || echo "shell.nix: could not fetch $m" >&2
    done
  '';
}
