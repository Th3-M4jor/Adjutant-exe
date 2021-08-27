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
    duration: dice,
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
  @spec to_btn(t) :: button() | link_button()
  def to_btn(value)

  @spec to_btn(t, pos_integer()) :: button() | link_button()
  def to_btn(value, uuid)

end
