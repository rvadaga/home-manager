{ bash }:

assert bash.stdenv.hostPlatform.isDarwin;
bash.overrideAttrs (old: {
  pname = "${old.pname}-darwin-pipe-fallback";
  patches = (old.patches or []) ++ [ ./bash-darwin-pipe-fallback.patch ];
  env = (old.env or {}) // {
    # the unpatched build shell must run configure before the fixed bash exists.
    BASH_COMPAT = "5.0";
    # runtime capacity checks make this threshold independent of build-host pressure.
    NIX_CFLAGS_COMPILE = (old.env.NIX_CFLAGS_COMPILE or "") + " -DHEREDOC_PIPESIZE=16384";
  };
})
