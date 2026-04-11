{ ... }: {
  imports = [ ./common.nix ];

  system.primaryUser = "rvadaga";

  users.users.rvadaga = {
    name = "rvadaga";
    home = "/Users/rvadaga";
  };
}
