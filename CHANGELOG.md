# Changelog

## Cldr Routes v0.3.0

This is the changelog for Cldr Routes version 0.3.0 released on July 10th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_routes/tags)

### Enhancements

* Add support for `live` routes. Thanks to @ringofhealth for the report. Closes #1.

* Uses the macros from Gettext rather than the functions when generating routes. This means that the mix tasks `gettext.extract` and `gettext.merge` now work as expected.

* Rewrite the `LocalizedHelpers` module that now proxies into the standard Phoenix `Helpers` module rather than maintaining a separate forked module.  As a result:
  * The standard `Helpers` module now generates helper names that have locale suffixes.  That is `user_path` becomes `user_en_path`, `user_fr_path` and so on.
  * The `LocalizedHelpers` module hosts the standard helper names (like `user_path`) which will then call the appropriate standard helper depending on the result of `Cldr.get_locale/1`.

Thanks to @rubas and @ringofhealth for their extreme patience while I worked this through. Closes #1, and #4.

## Cldr Routes v0.2.0

This is the changelog for Cldr Routes version 0.2.0 released on March 26th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_routes/tags)

### Breaking Changes

* Changes the module name from `Cldr.Routes` to `Cldr.Route` to be consistent with the other `ex_cldr`-based libraries which use singular module names.

## Cldr Routes v0.1.0

This is the changelog for Cldr Routes version 0.1.0 released on March 26th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_routes/tags)

### Enhancements

* Initial release