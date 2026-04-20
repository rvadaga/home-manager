{ lib, ... }: {
  options.llmInstructions.includePersonalRepoBanner = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "whether to prepend the personal-only scope banner to generated llm instruction files";
  };
}
