defmodule BnBBot.Library.Shared do
  @moduledoc """
  This module contains shared functions and types for the BnBBot library.
  """

  @type element ::
          :fire
          | :aqua
          | :elec
          | :wood
          | :wind
          | :sword
          | :break
          | :cursor
          | :recov
          | :invis
          | :object
          | :null

  @type skill ::
          :per
          | :inf
          | :tch
          | :str
          | :agi
          | :end
          | :chm
          | :vlr
          | :aff

  @type range ::
          :var
          | :far
          | :near
          | :close
          | :self

  @type dice :: %{
          dienum: pos_integer(),
          dietype: pos_integer()
        }

  @type blight :: %{
          elem: element,
          dmg: dice,
          duration: dice
        }

  @type kind :: :burst | :construct | :melee | :projectile | :wave | :recovery | :summon | :trap

  # credo:disable-for-lines:15 Credo.Check.Refactor.CyclomaticComplexity
  @spec element_to_string(element) :: String.t()
  def element_to_string(element) do
    case element do
      :fire -> "Fire"
      :aqua -> "Aqua"
      :elec -> "Elec"
      :wood -> "Wood"
      :wind -> "Wind"
      :sword -> "Sword"
      :break -> "Break"
      :cursor -> "Cursor"
      :recov -> "Recov"
      :invis -> "Invis"
      :object -> "Object"
      :null -> "Null"
    end
  end

  @spec skill_to_atom(String.t()) :: skill | nil
  def skill_to_atom(skill) do
    skill = String.downcase(skill, :ascii)

    case skill do
      "per" -> :per
      "inf" -> :inf
      "tch" -> :tch
      "str" -> :str
      "agi" -> :agi
      "end" -> :end
      "chm" -> :chm
      "vlr" -> :vlr
      "aff" -> :aff
      "none" -> nil
    end
  end

  @spec skill_to_string(skill() | nil) :: String.t()
  def skill_to_string(skill) do
    case skill do
      :per -> "Perception"
      :inf -> "Info"
      :tch -> "Tech"
      :str -> "Strength"
      :agi -> "Agility"
      :end -> "Endurance"
      :chm -> "Charm"
      :vlr -> "Valor"
      :aff -> "Affinity"
      nil -> "None"
    end
  end

  @spec dice_to_io_list(nil | dice(), iodata()) :: iolist()
  def dice_to_io_list(dice, last \\ "")

  def dice_to_io_list(nil, _last) do
    ["--"]
  end

  def dice_to_io_list(%{dienum: dienum, dietype: 1}, last) do
    [
      to_string(dienum),
      last
    ]
  end

  def dice_to_io_list(%{dienum: dienum, dietype: dietype}, last) do
    [
      to_string(dienum),
      "d",
      to_string(dietype),
      last
    ]
  end

  @spec blight_to_io_list(blight() | nil, iodata()) :: iolist()
  def blight_to_io_list(blight, last \\ "")

  def blight_to_io_list(nil, _last) do
    []
  end

  def blight_to_io_list(%{elem: elem, dmg: dmg, duration: duration}, last) do
    [
      "Blight (",
      to_string(elem) |> String.capitalize(:ascii),
      "): ",
      dice_to_io_list(dmg, " damage"),
      " for ",
      dice_to_io_list(duration, " rounds"),
      last
    ]
  end

  # credo:disable-for-lines:10 Credo.Check.Refactor.CyclomaticComplexity
  @spec skill_to_sort_pos(skill()) :: pos_integer()
  def skill_to_sort_pos(skill) do
    case skill do
      :per -> 0
      :inf -> 1
      :tch -> 2
      :str -> 3
      :agi -> 4
      :end -> 5
      :chm -> 6
      :vlr -> 7
      :aff -> 8
    end
  end

  @spec gen_suggestions(map() | [map()], String.t(), float()) :: [{float(), map()}]
  def gen_suggestions(map, name, min_dist) when is_map(map),
    do: gen_suggestions(Map.to_list(map), name, min_dist)

  def gen_suggestions(list, name, min_dist) when is_list(list) do
    lower_name = String.downcase(name, :ascii)

    list
    |> Stream.map(fn {key, value} -> {String.jaro_distance(key, lower_name), value} end)
    |> Stream.filter(fn {dist, _} -> dist >= min_dist end)
    |> Enum.sort_by(fn {d, _} -> d end, &>=/2)
    |> Enum.take(25)
  end

  @spec gen_autocomplete(map() | [map()], String.t(), float()) :: [{float(), String.t()}]
  def gen_autocomplete(map, to_search, min_dist) when is_map(map),
    do: gen_autocomplete(Map.to_list(map), to_search, min_dist)

  def gen_autocomplete(list, to_search, min_dist) when is_list(list) do
    lower_name = String.downcase(to_search, :ascii)

    list
    |> Stream.map(fn {key, value} -> {String.jaro_distance(key, lower_name), value.name} end)
    |> Stream.filter(fn {dist, _} -> dist >= min_dist end)
    |> Enum.sort_by(fn {d, _} -> d end, &>=/2)
    |> Enum.take(25)
  end

  @spec return_autocomplete(GenServer.from(), [{String.t(), String.t()}], String.t(), float()) ::
          :ok
  def return_autocomplete(from, list, to_search, min_dist) do
    to_search = String.downcase(to_search, :ascii)

    res =
      list
      |> Stream.map(fn {lower, upper} -> {String.jaro_distance(lower, to_search), upper} end)
      |> Stream.filter(fn {dist, _} -> dist >= min_dist end)
      |> Enum.sort_by(fn {d, _} -> d end, &>=/2)
      |> Enum.take(25)

    GenServer.reply(from, res)
  end
end

defmodule BnBBot.Library.Shared.Dice do
  @moduledoc """
  Ecto Type mapping for die rolls.
  """

  @enforce_keys [:dienum, :dietype]
  defstruct [:dienum, :dietype]

  @typedoc """
  Represents a dice roll. DieNum is the number of dice to roll, and DieType is the type of dice to roll.
  """
  @type t :: %__MODULE__{
          dienum: non_neg_integer(),
          dietype: non_neg_integer()
        }

  use Ecto.Type

  def type, do: :dice

  def cast(%__MODULE__{} = dice) do
    {:ok, dice}
  end

  def cast({dienum, dietype}) when is_integer(dienum) and is_integer(dietype) do
    {:ok, %__MODULE__{dienum: dienum, dietype: dietype}}
  end

  def cast(_) do
    :error
  end

  @spec load({integer(), integer()} | nil) :: {:ok, t() | nil} | :error
  def load({num, size}) when is_integer(num) and is_integer(size) do
    die = %__MODULE__{dienum: num, dietype: size}
    {:ok, die}
  end

  def load(nil) do
    {:ok, nil}
  end

  def load(_), do: :error

  @spec dump(t() | nil) :: :error | {:ok, {non_neg_integer(), non_neg_integer()} | nil}
  def dump(%__MODULE__{dienum: dienum, dietype: dietype}) do
    data = {dienum, dietype}
    {:ok, data}
  end

  def dump(nil) do
    {:ok, nil}
  end

  def dump(_), do: :error
end

defmodule BnBBot.Library.Shared.Element do
  @moduledoc """
  Ecto Type mapping for all the elements in the game.
  """
  use Ecto.Type

  @type t ::
          :fire
          | :aqua
          | :elec
          | :wood
          | :wind
          | :sword
          | :break
          | :cursor
          | :recov
          | :invis
          | :object
          | :null

  @elements [
    :fire,
    :aqua,
    :elec,
    :wood,
    :wind,
    :sword,
    :break,
    :cursor,
    :recov,
    :invis,
    :object,
    :null
  ]

  def type, do: :element

  def cast(elem) when is_list(elem) do
    deduped = Enum.dedup(elem)

    if Enum.all?(deduped, &(&1 in @elements)) do
      {:ok, deduped}
    else
      :error
    end
  end

  def cast(elem) when elem in @elements do
    {:ok, [elem]}
  end

  def cast(_elem), do: :error

  def load(elems) when is_list(elems) do
    res =
      Enum.reduce_while(elems, [], fn elem, acc ->
        case convert(elem) do
          # list append here is fine, since there are only 12 elements
          {:ok, elem} -> {:cont, acc ++ [elem]}
          :error -> {:halt, :error}
        end
      end)

    if res == :error do
      :error
    else
      {:ok, res}
    end
  end

  def load(_elem), do: :error

  def dump(elem) when is_list(elem) do
    as_strings =
      Enum.map(elem, fn element ->
        String.Chars.to_string(element) |> String.capitalize(:ascii)
      end)

    {:ok, as_strings}
  end

  def dump(elem) when elem in @elements do
    {:ok, [String.Chars.to_string(elem) |> String.capitalize(:ascii)]}
  end

  def dump(_elem), do: :error

  @spec convert(any) :: :error | {:ok, t()}
  def convert(elem) when elem in @elements do
    {:ok, elem}
  end

  def convert(elem) when is_binary(elem) do
    case String.downcase(elem, :ascii) do
      "fire" -> {:ok, :fire}
      "aqua" -> {:ok, :aqua}
      "elec" -> {:ok, :elec}
      "wood" -> {:ok, :wood}
      "wind" -> {:ok, :wind}
      "sword" -> {:ok, :sword}
      "break" -> {:ok, :break}
      "cursor" -> {:ok, :cursor}
      "recov" -> {:ok, :recov}
      "invis" -> {:ok, :invis}
      "object" -> {:ok, :object}
      "null" -> {:ok, :null}
      _ -> :error
    end
  end

  def convert(_elem), do: :error
end

defmodule BnBBot.Library.Shared.Blight do
  @moduledoc """
  Defines the Blight ecto type
  """

  use Ecto.Type

  alias BnBBot.Library.Shared.{Dice, Element}

  @enforce_keys [:elem, :dmg, :duration]
  defstruct [:elem, :dmg, :duration]

  @type t :: %__MODULE__{
          elem: Element.t(),
          dmg: Dice.t() | nil,
          duration: Dice.t() | nil
        }

  def type, do: :blight

  def cast(%__MODULE__{} = blight) do
    {:ok, blight}
  end

  def cast(nil) do
    {:ok, nil}
  end

  def cast({elem, dmg, duration}) do
    load({elem, dmg, duration})
  end

  def cast(_) do
    :error
  end

  def load({elem, dmg, duration}) do
    with {:ok, elem} <- Element.convert(elem),
         {:ok, dmg} <- Dice.load(dmg),
         {:ok, duration} <- Dice.load(duration) do
      {:ok, %__MODULE__{elem: elem, dmg: dmg, duration: duration}}
    else
      _ -> :error
    end
  end

  def load(nil) do
    {:ok, nil}
  end

  def load(_), do: :error

  def dump(%__MODULE__{} = blight) do
    elem = Atom.to_string(blight.elem) |> String.capitalize(:ascii)

    with {:ok, dmg} <- Dice.dump(blight.dmg),
         {:ok, duration} <- Dice.dump(blight.duration) do
      {:ok, {elem, dmg, duration}}
    else
      _ -> :error
    end
  end

  def dump(nil) do
    {:ok, nil}
  end

  def dump(_), do: :error
end

defprotocol BnBBot.Library.LibObj do
  @doc """
  Return the type of the libobj.
  """
  @spec type(t) :: :ncp | :chip | :virus
  def type(value)

  @doc """
  Return the libobj as a button.
  Custom ID is expected to be in the format of `"(kind)_(lowercase_name)"`.
  Where kind is a single letter that represents the type of the libobj
  and lowercase_name is the name of the libobj.
  """
  @spec to_btn(t, boolean()) :: Nostrum.Struct.Component.Button.t()
  def to_btn(value, disabled \\ false)

  @doc """
  Return the libobj as a button.
  Custom ID is expected to be in the format of `"(uuid)_(kind)_(lowercase_name)"`.
  Where the uuid is the given UUID as a 6 digit uppercase hex string,
  kind is a single letter that represents the type of the libobj,
  and lowercase_name is the name of the libobj.
  """
  @spec to_btn_with_uuid(t, boolean(), pos_integer()) :: Nostrum.Struct.Component.Button.t()
  def to_btn_with_uuid(value, disabled \\ false, uuid)

  @doc """
  Return the libobj as a semi-persistent button.
  Custom ID is expected to be in the format of `"(kind)r_(lowercase_name)"`.
  Where kind is a single letter that represents the type of the libobj,
  and lowercase_name is the name of the libobj.
  """
  @spec to_persistent_btn(t, boolean()) :: Nostrum.Struct.Component.Button.t()
  def to_persistent_btn(value, disabled \\ false)
end
