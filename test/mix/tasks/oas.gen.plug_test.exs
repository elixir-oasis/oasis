Code.require_file("../../support/mix/mix_helper.exs", __DIR__)

defmodule Mix.Tasks.Oas.Gen.PlugTest do
  use ExUnit.Case
  import Oasis.MixHelper
  alias Mix.Tasks.Oas.Gen

  setup do
    Mix.Task.clear()
    :ok
  end

  test "run in root of an umbrella project", config do
    in_tmp_project(config.test, fn ->
      File.write!("mix.exs", umbrella_mixfile_contents())
      File.mkdir!("apps")

      Mix.Project.in_project(:my_umbrella_app, File.cwd!(), fn _module ->
        assert_raise Mix.Error,
                     ~s/mix oas.gen.plug can only be run inside an application directory/,
                     fn ->
                       Gen.Plug.run([
                         "--file",
                         Path.join([__DIR__, "file/petstore-expanded.yaml"])
                       ])
                     end
      end)
    end)
  end

  test "run in one of apps in an umbrella project", config do
    in_tmp_project(config.test, fn ->
      File.write!("mix.exs", umbrella_mixfile_contents())
      File.mkdir_p!("apps/other_app")
      File.cd!("apps/other_app")

      Mix.Project.in_project(:my_umbrella_app2, File.cwd!(), fn _module ->
        Gen.Plug.run([
          "--file",
          Path.join([__DIR__, "file/petstore-expanded.yaml"]),
          "--name-space",
          "Hello"
        ])

        assert_file("lib/hello/find_pet_by_id.ex")
        assert_file("lib/hello/find_pet_by_id.ex")
        assert_file("lib/hello/pre_delete_pet.ex")
        assert_file("lib/hello/delete_pet.ex")
        assert_file("lib/hello/pre_find_pets.ex")
        assert_file("lib/hello/find_pets.ex")
      end)
    end)
  end

  test "invalid mix argument", config do
    in_tmp_project(config.test, fn ->
      assert_raise Mix.Error,
                   ~r(Expected input `--file` option to be a valid path to a yaml/json file),
                   fn ->
                     Gen.Plug.run([])
                   end

      assert_raise Mix.Error, ~r(Could not find the file in `non_existance.yaml` path), fn ->
        Gen.Plug.run(["--file", "non_existance.yaml"])
      end
    end)
  end

  test "generates plugs", config do
    in_tmp_project(config.test, fn ->
      file_path = Path.join([__DIR__, "file/petstore-expanded.yaml"])
      Gen.Plug.run(["--file", file_path])

      assert_file("lib/oasis/gen/router.ex", fn file ->
        assert file =~ ~s|defmodule Oasis.Gen.Router do|
        assert file =~ ~s|use Oasis.Router|
        assert file =~ ~s|plug(:match)|
        assert file =~ ~s|plug(:dispatch)|
        assert file =~ ~s|get(\n    "/pets",\n    to: Oasis.Gen.PreFindPets|
        assert file =~ ~s|post(\n    "/pets",\n    to: Oasis.Gen.PreAddPet|
        assert file =~ ~s|delete(\n    "/pets/:id",\n    private: %{\n      path_schema: %{|
        assert file =~ ~s|to: Oasis.Gen.PreDeletePet|
        assert file =~ ~s|get(\n    "/pets/:id",\n    private: %{\n      path_schema: %{\n|
        assert file =~ ~s|to: Oasis.Gen.PreFindPetById|
        assert file =~ ~s|match _ do|
      end)

      assert_file("lib/oasis/gen/pre_add_pet.ex", fn file ->
        assert file =~ ~s|defmodule Oasis.Gen.PreAddPet do|
        assert file =~ ~s|use Oasis.Controller|
        assert file =~ ~s|plug(\n    Plug.Parsers,|
        assert file =~ ~s|"application/json" => %{\n          "schema" => %ExJsonSchema.Schema.Root{|
        assert file =~ ~s/conn |> super(opts) |> Oasis.Gen.AddPet.call(opts) |> halt()/
      end)

      assert_file("lib/oasis/gen/add_pet.ex", [
        ~s|defmodule Oasis.Gen.AddPet do|,
        ~s|use Oasis.Controller|,
        ~s|def call(conn, _opts) do|,
        ~s|def handle_errors(|
      ])

      assert_file(
        "lib/oasis/gen/pre_find_pet_by_id.ex",
        ~s|defmodule Oasis.Gen.PreFindPetById do|
      )

      assert_file("lib/oasis/gen/find_pet_by_id.ex")
      assert_file("lib/oasis/gen/pre_delete_pet.ex")
      assert_file("lib/oasis/gen/delete_pet.ex")
      assert_file("lib/oasis/gen/pre_find_pets.ex")
      assert_file("lib/oasis/gen/find_pets.ex")
    end)
  end
end
