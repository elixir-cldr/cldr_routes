defmodule Sigil_q.Test do
  use ExUnit.Case

  use MyApp.Router.VerifiedRoutes, router: MyApp.Router, endpoint: MyApp.Endpoint

  test "sigil_q for default locale" do
    assert ~q[/users] == "/users"
  end

  test "sigil_q for :fr locale" do
    MyApp.Cldr.put_locale(:fr)
    assert ~q[/users] == "/users_fr"
  end

  test "sigil_q with locale interpolation" do
    MyApp.Cldr.put_locale(:de)
    assert ~q[/users/:locale] == "/users_de/de"
  end

  test "sigil_q with language interpolation" do
    MyApp.Cldr.put_locale(:de)
    assert ~q[/users/:language] == "/users_de/de"
  end

  test "sigil_q with territory interpolation" do
    MyApp.Cldr.put_locale("de")
    assert ~q[/users/:territory] == "/users_de/de"
  end

  test "sigil_q with interpolations" do
    MyApp.Cldr.put_locale(:fr)
    assert ~q[/users/:user] == "/users_fr/:user"
  end

  test "sigil_q with multiple path segments" do
   MyApp.Cldr.put_locale(:fr)
   assert ~q[/users/:user_id/faces/:face_id/:locale/visages] == "/users_fr/:user_id/faces_fr/:face_id/fr/visages"
 end
end