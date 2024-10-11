import ArgumentParser

struct Entrance: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "xcstrings-migrator",
        abstract: "A tool to migrate the legacy strings file to xcstrings file.",
        version: "1.0.0",
        subcommands: [Migrate.self, Revert.self],
        defaultSubcommand: Migrate.self
    )
}

Entrance.main()
