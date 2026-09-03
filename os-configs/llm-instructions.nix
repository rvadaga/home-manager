{ config, lib, ... }:
let
  platforms = lib.unique config.llmInstructions.platforms;
  instructions = lib.concatMapStrings (
    platform: "\n\n" + builtins.readFile (../dotfiles/claude + "/CLAUDE-${platform}.md")
  ) platforms;
  settingsPieces = map (
    platform: builtins.fromJSON (builtins.readFile (../dotfiles/claude + "/settings-${platform}.json"))
  ) platforms;
in
{
  options.llmInstructions = {
    includePersonalRepoBanner = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "whether to prepend the personal-only scope banner to generated llm instruction files";
    };

    platforms = lib.mkOption {
      type = lib.types.listOf (
        lib.types.enum [
          "linux"
          "mac"
          "nixos"
        ]
      );
      default = [ ];
      description = "ordered os instruction and settings layers to append";
    };
  };

  config = {
    claude.settingsPieces = lib.mkAfter settingsPieces;
    home.file.".codex/AGENTS.md".text = lib.mkAfter instructions;
    home.file.".claude/CLAUDE.md".text = lib.mkAfter instructions;
  };
}
