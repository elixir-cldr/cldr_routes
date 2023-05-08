defmodule Sigil_q.Test do
  use ExUnit.Case

  use MyApp.Cldr.VerifiedRoutes, router: MyApp.Router, endpoint: MyApp.Endpoint

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

  test "sigil_q with multiple path segments and interpolation" do
    MyApp.Cldr.put_locale(:fr)
    user_id = 1
    face_id = 2

    assert ~q[/users/#{user_id}/faces/#{face_id}/:locale/visages] ==
             "/users_fr/1/faces_fr/2/fr/visages"
  end

  test "sigil_q with query params" do
    MyApp.Cldr.put_locale(:en)
    assert ~q"/users/17?admin=true&active=false" == "/users/17?admin=true&active=false"
    assert ~q"/users/17?#{[admin: true]}" == "/users/17?admin=true"
  end
end
