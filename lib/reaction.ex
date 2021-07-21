defmodule BnBBot.ReactionAwait do
  require Logger
  alias Nostrum.Api

  @reaction_nums [
    # 1
    "\u{31}\u{fe0f}\u{20e3}",
    # 2
    "\u{32}\u{fe0f}\u{20e3}",
    # 3
    "\u{33}\u{fe0f}\u{20e3}",
    # 4
    "\u{34}\u{fe0f}\u{20e3}",
    # 5
    "\u{35}\u{fe0f}\u{20e3}",
    # 6
    "\u{36}\u{fe0f}\u{20e3}",
    # 7
    "\u{37}\u{fe0f}\u{20e3}",
    # 8
    "\u{38}\u{fe0f}\u{20e3}",
    # 9
    "\u{39}\u{fe0f}\u{20e3}"
  ]

  @spec await_reaction_add(
          Nostrum.Struct.Message.t(),
          pos_integer(),
          Nostrum.Snowflake.t() | Nostrum.Snowflake.external_snowflake()
        ) ::
          map() | nil
  @doc """
  Waits for a reaction add on the given message by someone with the given user_id if given, else awaits a reaction by anyone
  """
  def await_reaction_add(%Nostrum.Struct.Message{} = msg, count \\ 9, user_id \\ nil)
      when count in 1..9 do
    {:ok, user_id} = Nostrum.Snowflake.cast(user_id)
    Registry.register(:REACTION_COLLECTOR, msg.id, user_id)
    res = await_reaction_add_inner(count)

    # Registry.unregister(:REACTION_COLLECTOR, msg.id) #unecessary? since dead processes are unregistered automatically
    res
  end

  @doc """
  Syncronously adds the reaction numbers to a message
  """
  @spec add_reaction_nums(Nostrum.Struct.Message.t(), pos_integer()) :: any()
  def add_reaction_nums(%Nostrum.Struct.Message{} = msg, count \\ 9) when count in 1..9 do
    try do
      number_emotes = Enum.take(@reaction_nums, count)

      Enum.each(number_emotes, fn num ->
        Api.create_reaction!(msg.channel_id, msg.id, num)
        Process.sleep(350)
      end)
    rescue
      e ->
        err_msg = Exception.format(:error, e)
        Logger.error("Failed in adding a reaction to a message\n#{err_msg}")

        Api.create_message(
          msg.channel_id,
          "An error occurred in creating a reaction to that message, please inform major"
        )
    end
  end

  @spec await_reaction_add_inner(pos_integer()) :: map() | nil
  defp await_reaction_add_inner(count) do
    number_emotes = Enum.take(@reaction_nums, count)

    receive do
      {:reaction, value} ->
        if Enum.member?(number_emotes, value.emoji.name) do
          value
        else
          # Logger.info("got a reaction, wasn't a valid one")
          await_reaction_add_inner(count)
        end
    after
      30_000 ->
        # return nil instead after 30 seconds
        nil
    end
  end
end
