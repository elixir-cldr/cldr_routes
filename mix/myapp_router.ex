defmodule MyApp.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router
  use MyApp.Cldr.Routes

  localize do
    get "/pages/:page", PageController, :show, assigns: %{key: :value}
    resources "/users", UserController do
      resources "/faces", UserController
    end
  end

  # Interpolation
  localize do
    get "/#{locale}/locale/pages/:page", PageController, :show, as: "with_locale"
    get "/#{language}/language/pages/:page", PageController, :show, as: "with_language"
    get "/#{territory}/territory/pages/:page", PageController, :show, as: "with_territory"
  end

  localize [:en, :fr] do
    resources "/comments", PageController, except: [:delete]
    get "/pages/:page", PageController, :edit, assigns: %{key: :value}
  end

  localize do
    get "/pages/:page", PageController, :show
    patch "/pages/:page", PageController, :update
    delete "/pages/:page", PageController, :delete
    post "/pages/:page", PageController, :create
    options "/pages/:page", PageController, :options
    head "/pages/:page", PageController, :head
  end

  localize "fr" do
    get "/chapters/:page", PageController, :show, as: "chap"
    put "/pages/:page", PageController, :update
  end

  localize "de" do
    get "/kapitel/:page", PageController, :show
    put "/seite/:page", PageController, :update
  end

  localize "fr" do
    live "/columns/:page", PageController
  end

  # Unlocalized route with translatable path
  # elements so we can confirm there is no translation
  get "/not_localized/:page", NotLocalizedController, :show
end
