defmodule MyApp.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router
  use MyApp.Cldr.Routes

  # Nested routes to an arbitrary level (testing with 3)
  localize do
    get "/pages/:page", PageController, :show, assigns: %{key: :value}
    resources "/users", UserController do
      resources "/faces", FaceController, except: [:delete] do
        resources "/#{locale}/visages", VisageController
      end
    end
  end

  # Interpolation
  localize do
    get "/#{locale}/locale/pages/:page", PageController, :show, as: "with_locale"
    get "/#{language}/language/pages/:page", PageController, :show, as: "with_language"
    get "/#{territory}/territory/pages/:page", PageController, :show, as: "with_territory"
  end

  # Specific set of locales
  localize [:en, :fr] do
    resources "/comments", PageController, except: [:delete]
    get "/pages/:page", PageController, :edit, assigns: %{key: :value}
  end

  # Test all verbs
  localize do
    get "/pages/:page", PageController, :show
    patch "/pages/:page", PageController, :update
    delete "/pages/:page", PageController, :delete
    post "/pages/:page", PageController, :create
    options "/pages/:page", PageController, :options
    head "/pages/:page", PageController, :head
  end

  # Routes with existing :as is honoured
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

  # Live routes
  live_session :non_auth_user do
    scope "/user/", MyAppWeb do
      localize do
        post("/#{locale}/login", UserSessionController, :create)
      end
    end
  end

  live_session :default do
    scope "/", MyAppWeb do
      localize do
        live("/#{locale}", HomeLive)
      end
    end
  end

  # Unlocalized route with translatable path
  # elements so we can confirm there is no translation
  get "/not_localized/:page", NotLocalizedController, :show
end
