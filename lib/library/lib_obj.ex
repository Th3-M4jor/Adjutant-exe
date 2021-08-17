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
