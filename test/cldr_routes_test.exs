defmodule CldrRoutesTest do
  use ExUnit.Case
  use Plug.Test

  doctest Cldr.Routes
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
    test "localized path helper" do
      Gettext.put_locale MyAppWeb.Gettext, "en"
      assert MyApp.Router.LocalizedHelpers.page_path(%Plug.Conn{}, :show, 1) == "/pages/1"

      Gettext.put_locale MyAppWeb.Gettext, "fr"
      assert MyApp.Router.LocalizedHelpers.page_path(%Plug.Conn{}, :show, 1) == "/pages_fr/1"
    end

    test "no localized path helper" do
      Gettext.put_locale MyAppWeb.Gettext, "en"
      assert MyApp.Router.LocalizedHelpers.not_localized_path(%Plug.Conn{}, :show, 1) == "/not_localized/1"

      Gettext.put_locale MyAppWeb.Gettext, "fr"
      assert MyApp.Router.LocalizedHelpers.not_localized_path(%Plug.Conn{}, :show, 1) == "/not_localized/1"
    end
  end
end
