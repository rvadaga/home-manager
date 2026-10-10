def deep_merge(a; b):
  a as $aa | b as $bb |
  if ($aa | type) == "object" and ($bb | type) == "object" then
    (($aa | keys_unsorted) + ($bb | keys_unsorted)) | unique |
    reduce .[] as $k ({};
      if ($aa | has($k)) and ($bb | has($k)) then
        . + {($k): deep_merge($aa[$k]; $bb[$k])}
      elif ($bb | has($k)) then . + {($k): $bb[$k]}
      else . + {($k): $aa[$k]}
      end
    )
  elif ($aa | type) == "array" and ($bb | type) == "array" then
    ($aa + $bb) | unique
  else $bb
  end;
deep_merge(.[0]; .[1]) * .[2]
