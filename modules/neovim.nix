{ config, pkgs, ... }: {
  programs.neovim = {
    enable = true;

    plugins = with pkgs.vimPlugins; [
      {
        plugin = tokyonight-nvim;
        type = "lua";
        config = ''
          require("tokyonight").setup({})
          vim.cmd[[colorscheme tokyonight]]
        '';
      }
    ];
  };
}
