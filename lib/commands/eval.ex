defmodule BnBBot.Commands.Eval do
  alias Nostrum.Api
  require Logger

  @behaviour BnBBot.CommandFn

  def help() do
    {"eval", :owner, "Evaluates the given string, warning: dangerous"}
  end

  def call(%Nostrum.Struct.Message{} = msg, args) do
    if BnBBot.Util.is_owner_msg?(msg) do
      to_eval = Enum.join(args, " ")
      do_eval(msg, to_eval)
    else
      BnBBot.Util.dm_owner("Unauthorized use of eval by #{msg.author.username}")
    end
  end

  defp do_eval(msg, fn_txt) do
    resp = try do
      {res, _} = Code.eval_string(fn_txt, [msg: msg], __ENV__)
      inspect(res, charlists: :as_lists)
    rescue
      e ->
        inspect(e, charlists: :as_lists)
    end

    unless String.length(resp) > 1850 do
      Api.create_message(msg.channel_id, "```elixir\n#{resp}```")
    else
      Api.create_message(msg.channel_id, file: %{name: "result.txt", body: resp})
    end
  end

end
