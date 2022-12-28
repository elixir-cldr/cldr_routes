defmodule SigilQ.Test do
  use ExUnit.Case

  use MyApp.Router.VerifiedRoutes, router: MyApp.Router, endpoint: MyApp.Endpoint

  test "sigil_q" do
    assert ~q[/users] == "/users"
  end

end