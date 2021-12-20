defmodule BnBBot.Library.Shared do
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
      to_string(elem) |> String.capitalize(),
      "): ",
      dice_to_io_list(dmg, " damage"),
      " for ",
      dice_to_io_list(duration, " rounds"),
      last
    ]
  end

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
    lower_name = String.downcase(name)

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
    lower_name = String.downcase(to_search)

    list
    |> Stream.map(fn {key, value} -> {String.jaro_distance(key, lower_name), value.name} end)
    |> Stream.filter(fn {dist, _} -> dist >= min_dist end)
    |> Enum.sort_by(fn {d, _} -> d end, &>=/2)
    |> Enum.take(25)
  end

  @spec return_autocomplete(GenServer.from(), [{String.t(), String.t()}], String.t(), float()) ::
          :ok
  def return_autocomplete(from, list, to_search, min_dist) do
    to_search = String.downcase(to_search)

    res =
      list
      |> Stream.map(fn {lower, upper} -> {String.jaro_distance(lower, to_search), upper} end)
      |> Stream.filter(fn {dist, _} -> dist >= min_dist end)
      |> Enum.sort_by(fn {d, _} -> d end, &>=/2)
      |> Enum.take(25)

    GenServer.reply(from, res)
  end
end

defprotocol BnBBot.Library.LibObj do
  @type button_style :: 1..4

  @type partial_emoji :: %{
          required(:name) => String.t(),
          optional(:id) => Nostrum.Snowflake.external_snowflake(),
          optional(:animated) => boolean()
        }

  @type button :: %{
          required(:type) => 2,
          required(:style) => button_style,
          required(:label) => String.t(),
          required(:custom_id) => String.t(),
          optional(:emoji) => partial_emoji(),
          optional(:disabled) => boolean()
        }

  @type link_button :: %{
          required(:type) => 2,
          required(:style) => 5,
          required(:label) => String.t(),
          required(:url) => String.t(),
          optional(:emoji) => partial_emoji()
        }

  @doc """
  Return the type of the libobj.
  """
  @spec type(t) :: :ncp | :chip | :virus
  def type(value)

  @doc """
  Return the libobj as a button.
  """
  @spec to_btn(t, boolean()) :: button() | link_button()
  def to_btn(value, disabled \\ false)

  @spec to_btn_with_uuid(t, boolean(), pos_integer()) :: button() | link_button()
  def to_btn_with_uuid(value, disabled \\ false, uuid)

  @spec to_persistent_btn(t, boolean()) :: button() | link_button()
  def to_persistent_btn(value, disabled \\ false)
end
