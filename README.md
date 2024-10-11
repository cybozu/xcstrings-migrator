# xcstrings-migrator

Convert legacy strings files to xcstrings (String Catalog).
This tool can also revert xcstrings to legacy strings files.

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

**Installation**

```sh
git clone https://github.com/cybozu/xcstrings-migrator.git
cd xcstrings-migrator
swift build -c release
$ cp .build/release/xcstrings-migrator /usr/local/bin/xcstrings-migrator
```

**Migrate**

```sh
xcstrings-migrator -output-directory ~/result -path ~/original/en.lproj -path ~/original/ja.lproj
```

**Revert**

```sh
xcstrings-migrator revert -output-directory ~/result -path ~/Localizable.xcstrings
```
