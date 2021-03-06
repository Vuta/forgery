defmodule Forgery do
  @moduledoc """
  Forgery is a slim though extensible test data generator in Elixir.

  Forgery provides a few simple APIs to work with. To get started, you
  need to implement the `make/2` callback:

      defmodule MyUser do
        defstruct [:id, :username, :password]
      end

      defmodule MyFactory do
        use Forgery

        def make(:user, fields) do
          fields
          |> put_new_field(:id, make_unique_integer())
          |> put_new_field(:username, "user" <> to_string(make_unique_integer()))
          |> create_struct(MyUser)
        end
      end

      iex> import MyFactory
      iex>
      iex> %MyUser{} = make(:user)
      iex> %MyUser{id: 42} = make(:user, id: 42)
      iex> [%MyUser{}, %MyUser{}] = make_many(:user, 2)

  And just as simple as that!

  ## Ecto integration

  Forgery was built with easy Ecto integration in mind, though not limiting to it.

  For example if you use Ecto and have `MyRepo`. You can add a function, says `insert!`, into the factory:

      defmodule MyFactory do
        def insert!(factory, fields \\ %{}) do
          :user
          |> make(fields)
          |> MyRepo.insert!()
        end

        def insert_many!(factory, amount, fields \\ %{}) when amount >= 1 do
          [%schema{} | _] = entities = make_many(:user, amount, fields)

          {_, persisted_entities} = MyRepo.insert_all(schema, entities, returning: true)

          persisted_entities
        end
      end

      user = insert!(:user)
      users = insert_many!(:user, 10, %{password: "1234567890"})

  """

  @type factory() :: atom()

  @doc """
  Makes data from the given factory.

  The implementation of this callback should take in the factory name, as well and `fields`.


  """

  @callback make(factory :: factory(), fields :: Enumerable.t()) :: any()

  @doc """
  Make multiple data from the given factory.

  This function is roughly equivalent to:

      Enum.map(1..amount, fn _ -> make(factory) end)

  ### Example

      make_many(:users, 3)
      [
        %MyUser{id: 3, password: nil, username: "user3"},
        %MyUser{id: 5, password: nil, username: "user4"},
        %MyUser{id: 7, password: nil, username: "user5"},
      ]


  """
  @callback make_many(factory :: factory(), amount :: integer(), fields :: Enumerable.t()) ::
              list(any())

  defmacro __using__(_) do
    quote location: :keep do
      import Forgery

      @behaviour Forgery

      def make(factory, fields \\ %{})

      def make_many(factory, amount, fields \\ %{}) when is_integer(amount) do
        for _ <- 1..amount, do: make(factory, fields)
      end
    end
  end

  @doc """
  Lazily evaluate and put `lazy_value` into `name` if `name` does not exist in `fields`.

      iex> import Forgery
      iex>
      iex> fields = %{foo: 1}
      iex> put_new_field(fields, :foo, 100 + 2)
      %{foo: 1}
      iex> put_new_field(fields, :bar, 100)
      %{foo: 1, bar: 100}

  Note that `lazy_value` is only evaluated when it is needed. For instance, in the
  following example, `make_foo.()` will not be invoked.

      iex> import Forgery
      iex>
      iex> make_foo = fn -> raise("I am invoked") end
      iex> fields = %{foo: 1}
      iex> put_new_field(fields, :foo, make_foo.())
      %{foo: 1}
  """

  @spec put_new_field(fields :: Enumerable.t(), name :: any(), lazy_value :: any()) :: map()
  defmacro put_new_field(fields, name, lazy_value) do
    quote do
      unquote(fields)
      |> Map.new()
      |> Map.put_new_lazy(unquote(name), fn -> unquote(lazy_value) end)
    end
  end

  @doc """
  Create struct of `module` from `fields`.

      iex> import Forgery
      iex>
      iex> create_struct(%{id: 1, username: "john", password: "123456"}, MyUser)
      %MyUser{id: 1, password: "123456", username: "john"}

  """

  @spec create_struct(fields :: Enumerable.t(), module :: atom()) :: struct()
  def create_struct(fields, module) do
    struct!(module, fields)
  end

  @doc """
  Returns monotonically increasing unique integer. It would be useful when it comes to
  generate unique serial IDs.
  """
  @spec make_unique_integer() :: pos_integer()
  def make_unique_integer() do
    System.unique_integer([:monotonic, :positive])
  end
end
