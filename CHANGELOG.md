# Changelog

## Cldr Routes v1.3.0

This is the changelog for Cldr Routes version 1.3.0 released on February 19th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_routes/tags)

### Enhancements

* Adds support for calling `url/{1,3,4}` with a `sigil_q` (localized verified route) parameter. The `Phoenix.VerifiedRoutes.url/1` macro checks that its parameter is a `sigil_p` call. Since `sigil_q` returns a `case` expression with one or more case clauses returning a `sigil_p` result, the `Phoenix.VerifiedRoutes.url/1` macro cannot be used directly. This release adds `url/{1,2,3}` to the `MyApp.Cldr.VerifiedRoutes` module so it is compatible with existing code and supports both `sigil_p` and `sigil_q` parameters. Thanks to @rigzad for the issue. Closes #16.

## Cldr Routes v1.2.0

This is the changelog for Cldr Routes version 1.2.0 released on January 3rd, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_routes/tags)

### Enhancements

* Configures `:phoenix_html_helpers` as a dependency rather than the full `:phoenix` app. `:ex_cldr_routes` only uses the tag helper which is now hosted in the new library. Whilst deprecated within Phoenix, its use here is to generate `hreflang` headers.

## Cldr Routes v1.1.0

This is the changelog for Cldr Routes version 1.1.0 released on May 9th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_routes/tags)

### Bug Fixes

* Fix Phoenix integration which was failing to compile when using Phoenix auth. Thanks to @rubas for the report and collaboration.

* Fix dialyzer error. Thanks to @rubas for the report.

### Deprecation

* The module `Cldr.Route` is renamed to `Cldr.Routes` to better match Phoenix naming.  As a result, the provider module to be added to a Cldr backend configuration is now `Cldr.Routes`, not `Cldr.Route`.  `Cldr.Route` remains for now and if used will issue a deprecation warning.

## Cldr Routes v1.0.0

This is the changelog for Cldr Routes version 1.0.0 released on May 3rd, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_routes/tags)

### Enhancements

* Supports localized verified routes with `~q` (`Sigil_q`).

* Supports Phoenix 1.7 and later only.

* Supports Elixir 1.11 and later only.

## Cldr Routes v0.6.4

This is the changelog for Cldr Routes version 0.6.4 released on April 29th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_routes/tags)

### Bug Fixes

* Fixes route `:as` option to correctly stringify atom names. Closes #14. Thanks to @krns for the report.

## Cldr Routes v0.6.3

This is the changelog for Cldr Routes version 0.6.2 released on April 27th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_routes/tags)

### Bug Fixes

* Fix readme example. Thanks to @krns for the PR. Closes #12.

* Support Phoenix 1.7.  NOTE: Doesn't yet include localized verified routes.

## Cldr Routes v0.6.2

This is the changelog for Cldr Routes version 0.6.2 released on August 6th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_routes/tags)

### Bug Fixes

* Uses the standard Phoenix `tag` helper to generate `hreflang` helpers.

## Cldr Routes v0.6.1

This is the changelog for Cldr Routes version 0.6.1 released on July 24th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_routes/tags)

### Bug Fixes

* Fix `LocalizedHelpers.hreflang_links/1` to return an empty string if links is `nil`.

## Cldr Routes v0.6.0

This is the changelog for Cldr Routes version 0.6.0 released on July 24th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_routes/tags)

### Enhancements

* Adds `MyApp.Router.LocalizedHelpers.<helper>_links` functions to the generated `LocalizedHelpers` module. These `_links` functions are 1:1 correspondents to the `_path` and `_url` helpers. The `_link` helpers generate link headers that help identify the other language versions of a page. They are used like this:
```elixir
iex> alias MyApp.Router.LocalizedHelpers, as: Routes
iex> Routes.user_links(conn, :show, 1) |> Routes.hreflang_links()
{
 :safe,
 [
   ["<link href=", "\"http://localhost/users_de/1\"", "; rel=alternate; hreflang=", "\"de\"", " />"],
   "\n",
   ["<link href=", "\"http://localhost/users/1\"", "; rel=alternate; hreflang=", "\"en\"", " />"],
   "\n",
   ["<link href=", "\"http://localhost/users_fr/1\"", "; rel=alternate; hreflang=", "\"fr\"", " />"]
  ]
}
```

## Cldr Routes v0.5.0

This is the changelog for Cldr Routes version 0.5.0 released on July 22nd, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_routes/tags)

### Bug Fixes

* Propogate locales on the `localize` macro to nested resources

### Breaking change

* The locale is now stored in the `:private` field of the `conn` for both live routes and other routes. It was previously stored in the `:assigns` field for non-live routes.

## Cldr Routes v0.4.0

This is the changelog for Cldr Routes version 0.4.0 released on July 19th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_routes/tags)

### Bug Fixes

* Fixed Localized route helpers were matching on the full locale, not on the `:gettext_locale_name` field. Thanks to @rubas for the report and collaboration. Closes #6.

* `mix phx.routes MyApp.Router.LocalizedRoutes` was attempting to "un"-translate the routes. This is no longer the case since doing so hides information required by developers. Closes #8.

## Cldr Routes v0.3.0

This is the changelog for Cldr Routes version 0.3.0 released on July 17th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_routes/tags)

### Enhancements

* Add support for `live` routes. Thanks to @ringofhealth for the report. Closes #1.

* Support interpolating `locale`, `language` and `territory` into a route. Thanks to @rubas for the suggestion. Closes #3. For example:

```elixir
  localize do
    get "/#{locale}/locale/pages/:page", PageController, :show, as: "with_locale"
    get "/#{language}/language/pages/:page", PageController, :show, as: "with_language"
    get "/#{territory}/territory/pages/:page", PageController, :show, as: "with_territory"
  end
```

* Uses the macros from Gettext rather than the functions when generating routes. This means that the mix tasks `gettext.extract` and `gettext.merge` now work as expected. Closes #3.

* Rewrite the `LocalizedHelpers` module that now proxies into the standard Phoenix `Helpers` module rather than maintaining a separate forked module.  As a result:
  * The standard `Helpers` module now generates helper names that have locale suffixes.  That is `user_path` becomes `user_en_path`, `user_fr_path` and so on.
  * The `LocalizedHelpers` module hosts the standard helper names (like `user_path`) which will then call the appropriate standard helper depending on the result of `Cldr.get_locale/1`.

* Add functions to output the localised routes. At compile time a module called `MyApp.Router.LocalizedRoutes` is created.  This module hosts a `__routes__/0` function which can be passed as an argument to the Phoenix standard ` Phoenix.Router.ConsoleFormatter.format/1` function that returns a string representation of configured localized routes. These can then be `IO.puts/1` as required.  In the next release a mix task will automate this process.

Thanks to @rubas and @ringofhealth for their extreme patience while I worked this through. Closes #1, and #4.

## Cldr Routes v0.2.0

This is the changelog for Cldr Routes version 0.2.0 released on March 26th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_routes/tags)

### Breaking Changes

* Changes the module name from `Cldr.Routes` to `Cldr.Route` to be consistent with the other `ex_cldr`-based libraries which use singular module names.

## Cldr Routes v0.1.0

This is the changelog for Cldr Routes version 0.1.0 released on March 26th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_routes/tags)

### Enhancements

* Initial release