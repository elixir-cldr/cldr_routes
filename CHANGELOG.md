# Changelog

## Cldr Routes v0.3.0

This is the changelog for Cldr Routes version 0.3.0 released on July 10th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_routes/tags)

### Enhancements

* Add support for `live` routes. Thanks to @ringofhealth for the report. Closes #1.

* Uses the macros from Gettext rather than the functions when generating routes. This means that the mix tasks `gettext.extract` and `gettext.merge` now work as expected.

## Cldr Routes v0.2.0

This is the changelog for Cldr Routes version 0.2.0 released on March 26th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_routes/tags)

### Breaking Changes

* Changes the module name from `Cldr.Routes` to `Cldr.Route` to be consistent with the other `ex_cldr`-based libraries which use singular module names.

## Cldr Routes v0.1.0

This is the changelog for Cldr Routes version 0.1.0 released on March 26th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_routes/tags)

### Enhancements

* Initial release