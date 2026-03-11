struct ManualSnippetDraft: Equatable {
    var snippetID: String?
    var title = ""
    var description = ""
    var language = SnippetSyntaxLanguage.auto
    var code = ""
}
