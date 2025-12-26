# base instructions

* when writing ANY new content, always use lower case.
    * when editing, preserve case for code, variable names, identifiers, abbreviations and actual code
    * product names are lower case too
* when working on pull requests:
    * unless specifically asked not to, create a DRAFT pr
    * don't add ai generated prompt
    * always use pull request templates available in the repository
    * if it doesn't exist in the repo, please use the one in ~/development/.github/ folder
* when creating a branch
    * prefix the name with rahul/
* when making any home-manager config changes, always test that they work.
* running home-manager switch command is ok, but NEVER push to remote without getting the user's permission.

# updating CLAUDE.md, settings.json or settings.local.json in ~/.claude folder

* these files are managed by home-manager, so they are read only
* whenever you need to update user settings, please modify the files in ~/.config/home-manager instead
