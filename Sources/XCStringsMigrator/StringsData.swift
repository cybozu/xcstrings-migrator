struct StringsData: Equatable {
    var tableName: String
    var language: String
    var items: [Item]

    struct Item: Equatable {
        var key: String
        var value: Value

        enum Value: Equatable {
            case singular(String)
            case plural([Plural])

            struct Plural: Equatable {
                var rule: Rule
                var value: String

                enum Rule: String {
                    case zero
                    case one
                    case two
                    case few
                    case many
                    case other
                }
            }
        }
    }
}
