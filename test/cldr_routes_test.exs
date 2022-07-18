defmodule Cldr.Route.Test do
  use ExUnit.Case
  use Plug.Test
  import Cldr.Route.TestHelper

  import Phoenix.ConnTest,
    only: [
      build_conn: 0,
      get: 2
    ]

  doctest Cldr.Route
  doctest MyApp.Router.LocalizedHelpers

  describe "Routes" do
    test "Localized route generation" do
      assert Phoenix.Router.route_info(MyApp.Router, "GET", "/pages/1", "myhost") ==
               %{
                 log: :debug,
                 path_params: %{"page" => "1"},
                 pipe_through: [],
                 plug: PageController,
                 plug_opts: :show,
                 route: "/pages/:page"
               }

      assert Phoenix.Router.route_info(MyApp.Router, "GET", "/pages_fr/1", "myhost") ==
               %{
                 log: :debug,
                 path_params: %{"page" => "1"},
                 pipe_through: [],
                 plug: PageController,
                 plug_opts: :show,
                 route: "/pages_fr/:page"
               }
    end

    test "Not localized route generation" do
      assert Phoenix.Router.route_info(MyApp.Router, "GET", "/not_localized/:page", "myhost") ==
               %{
                 log: :debug,
                 path_params: %{"page" => ":page"},
                 pipe_through: [],
                 plug: NotLocalizedController,
                 plug_opts: :show,
                 route: "/not_localized/:page"
               }
    end
  end

  describe "Routing" do
    test "Localized routing" do
      opts = MyApp.Router.init([])

      conn =
        :get
        |> conn("/pages_fr/1")
        |> MyApp.Router.call(opts)

      assert Map.get(conn.private, :phoenix_action) == :show
      assert Map.get(conn.private, :phoenix_controller) == PageController
      assert conn.path_info == ["pages_fr", "1"]
      assert %{cldr_locale: %Cldr.LanguageTag{cldr_locale_name: :fr}} = conn.assigns
    end
  end

  describe "Helpers" do
    test "localized path helpers" do
      Cldr.put_locale(MyApp.Cldr, "en")
      assert MyApp.Router.LocalizedHelpers.page_path(%Plug.Conn{}, :show, 1) == "/pages/1"

      Cldr.put_locale(MyApp.Cldr, "fr")
      assert MyApp.Router.LocalizedHelpers.page_path(%Plug.Conn{}, :show, 1) == "/pages_fr/1"
    end

    test "localized path helper with configured :as" do
      Cldr.put_locale(MyApp.Cldr, "fr")
      assert MyApp.Router.LocalizedHelpers.chap_path(%Plug.Conn{}, :show, 1) == "/chapters_fr/1"
    end

    test "no localized path helper" do
      Cldr.put_locale(MyApp.Cldr, "en")

      assert MyApp.Router.LocalizedHelpers.not_localized_path(%Plug.Conn{}, :show, 1) ==
               "/not_localized/1"

      Cldr.with_locale("fr", MyApp.Cldr, fn ->
        assert MyApp.Router.LocalizedHelpers.not_localized_path(%Plug.Conn{}, :show, 1) ==
                 "/not_localized/1"

        assert MyApp.Router.LocalizedHelpers.user_face_path(%Plug.Conn{}, :index, 1, thing: :other) ==
                 "/users_fr/1/faces_fr?thing=other"
      end)
    end

    test "helper isn't localized to a locale" do
      Cldr.put_locale(MyApp.Cldr, "en")

      assert_raise ArgumentError, ~r/for locale/, fn ->
        MyApp.Router.LocalizedHelpers.chap_path(%Plug.Conn{}, :show, 1)
      end
    end

    test "that helpers match on the gettext locale name" do
      {:ok, locale} = MyApp.Cldr.validate_locale("en-GB")
      Cldr.put_locale(locale)
      assert MyApp.Router.LocalizedHelpers.user_path(%Plug.Conn{}, :index) == "/users"

      {:ok, locale} = MyApp.Cldr.validate_locale("en-AU")
      Cldr.put_locale locale
      assert MyApp.Router.LocalizedHelpers.user_path(%Plug.Conn{}, :index) == "/users"

      {:ok, locale} = MyApp.Cldr.validate_locale("es")
      Cldr.put_locale locale
      assert_raise ArgumentError, ~r/no function clause for MyApp.Router.LocalizedHelpers.user_path/, fn ->
        MyApp.Router.LocalizedHelpers.user_path(%Plug.Conn{}, :index)
      end
    end
  end

  describe "Interpolate during route generation" do
    test "interpolating a locale" do
      assert find_route(MyApp.Router, "/de/locale/pages_de/:page") ==
        %{
          helper: "with_locale_de",
          metadata: %{log: :debug},
          path: "/de/locale/pages_de/:page",
          plug: PageController,
          plug_opts: :show,
          verb: :get
        }
    end

    test "interpolating a language" do
      assert find_route(MyApp.Router, "/de/language/pages_de/:page") ==
        %{
          helper: "with_language_de",
          metadata: %{log: :debug},
          path: "/de/language/pages_de/:page",
          plug: PageController,
          plug_opts: :show,
          verb: :get
        }
    end

    test "interpolating a territory" do
      assert find_route(MyApp.Router, "/de/territory/pages_de/:page") ==
        %{
          helper: "with_territory_de",
          metadata: %{log: :debug},
          path: "/de/territory/pages_de/:page",
          plug: PageController,
          plug_opts: :show,
          verb: :get
        }
    end

    @endpoint MyApp.Router

    test "That assigns propogate to the connection" do
      {:ok, locale} = MyApp.Cldr.validate_locale(:en)
      conn = get(build_conn(), "/users/1")
      assert conn.assigns.cldr_locale == locale

      {:ok, locale} = MyApp.Cldr.validate_locale(:de)
      conn = get(build_conn(), "/users_de/1")
      assert conn.assigns.cldr_locale == locale
    end
  end
end
