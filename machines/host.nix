{
  configurationName,
  lib,
  machine,
  ...
}:
{
  home = {
    username = machine.user;
    homeDirectory = machine.home;
    stateVersion = machine.stateVersion;
    sessionVariables.HM_CONFIG_NAME = configurationName;
  };

  programs.git.signing.key = lib.mkIf (machine ? gitSigningKey) machine.gitSigningKey;
}
