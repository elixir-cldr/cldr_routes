defmodule MyApp.Router do
  use Phoenix.Router
  use MyApp.Cldr.Routes

  localize do
    get "/pages/:page", PageController, :show, assigns: %{key: :value}
    get "/chapters/:page", PageController, :show, as: "chap"
    resources "/users", UserController do
      resources "/faces", UserController
    end
  end

  localize [:en, :fr] do
    resources "/comments", PageController, except: [:delete]
    get "/pages/:page", PageController, :edit, assigns: %{key: :value}
  end

  localize do
    get "/pages/:page", PageController, :show
    put "/pages/:page", PageController, :update
    patch "/pages/:page", PageController, :update
    delete "/pages/:page", PageController, :delete
    post "/pages/:page", PageController, :create
    options "/pages/:page", PageController, :options
    head "/pages/:page", PageController, :head
  end
end