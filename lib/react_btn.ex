defmodule BnBBot.ButtonAwait do
  require Logger
  # alias Nostrum.Api

  @doc """
  First string in the tuple is the Name on the button
  Second string is the id of the button
  integer is the style of the button

  Raises if there are more than 10 buttons
  """
  @spec generate_msg_buttons([struct()]) ::
          [%{type: pos_integer(), components: [map()]}] | no_return()
  def generate_msg_buttons(content) when length(content) > 10 do
    raise "Too many buttons"
  end

  def generate_msg_buttons(content) do
    row_chunks = Enum.chunk_every(content, 5)

    Enum.map(row_chunks, fn row ->
      action_row = Enum.map(row, &BnBBot.Library.LibObj.to_btn/1)

      %{
        type: 1,
        components: action_row
      }
    end)
  end

  #  defp tuple_to_btn({name, id, style}) do
  #    %{
  #      type: 2,
  #      style: style,
  #      label: name,
  #      custom_id: id
  #    }
  #  end

  @doc """
  Awaits a button click on the given message from a user with the given ID (nil for any user)
  timeout is after 30 seconds
  """
  @spec await_btn_click(Nostrum.Struct.Message.t(), Nostrum.Snowflake.t() | nil) ::
          %Nostrum.Struct.Interaction{} | nil | no_return()
  def await_btn_click(%Nostrum.Struct.Message{} = msg, user_id \\ nil) do
    Registry.register(:BUTTON_COLLECTOR, msg.id, user_id)
    Logger.debug("Registering an await click on msg #{msg.id} for #{user_id}")
    btn = await_btn_click_inner()
    Logger.debug("Got a response to #{msg.id} of #{inspect(btn, pretty: true)}")
    btn
  end

  defp await_btn_click_inner() do
    receive do
      {:btn_click, value} ->
        # value.data.custom_id
        value

      _ ->
        raise "Inconcievable"
    after
      30_000 ->
        nil
    end
  end
end
