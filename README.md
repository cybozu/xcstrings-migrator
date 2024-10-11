# xcstrings-migrator

Convert legacy strings files to xcstrings (String Catalog).

## Help

```sh
OVERVIEW: A tool to migrate the legacy strings file to xcstrings file.

USAGE: xcstrings-migrator <subcommand>

OPTIONS:
  --version               Show the version.
  -h, --help              Show help information.

SUBCOMMANDS:
  migrate (default)       Migrate legacy strings file to xcstrings file.
  revert                  Revert xcstrings file to legacy strings file.

  See 'xcstrings-migrator help <subcommand>' for detailed help.
```

## Usage

```sh
git clone https://github.com/Kyome22/xcstrings-migrator.git
cd xcstrings-migrator
swift run xcstrings-migrator -output-directory ~/result -path ~/original/en.lproj -path ~/original/ja.lproj
```
