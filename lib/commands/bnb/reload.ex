defmodule BnBBot.Commands.Reload do
  @moduledoc """
  Command for telling the bot to reload all chips/viruses/NCPs
  """

  alias BnBBot.Library
  alias Nostrum.Api

  require Logger

  use BnBBot.SlashCmdFn, permissions: [:owner, :admin]

  @impl true
  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    Logger.info("Recieved a reload slash command")

    Task.start(fn ->
      Api.create_interaction_response(inter, %{
        type: 5,
        data: %{
          # Because apparently deferring the response needs the ephemeral flag for the followup to be ephemeral
          flags: 64
        }
      })
    end)

    {lib_str, validation_msg} = do_reload()

    lib_str_len = byte_size(lib_str)
    validation_msg_len = IO.iodata_length(validation_msg)

    cond do
      lib_str_len + validation_msg_len <= 2000 ->
        # We can send the whole thing in one message
        msg = [lib_str, "\n", validation_msg] |> IO.iodata_to_binary()

        :ok =
          Api.create_followup_message(inter.application_id, inter.token, %{
            content: msg,
            flags: 64
          })
          |> elem(0)

      validation_msg_len > 2000 ->
        # The validation message is too long to send in one message, so just notify that it's too long
        msg = lib_str <> "\nToo many viruses have drops that don't exist"

        :ok =
          Api.create_followup_message(inter.application_id, inter.token, %{
            content: msg,
            flags: 64
          })
          |> elem(0)

      true ->
        # Both messages are too long to send in one message, so send them in two messages
        :ok =
          Api.create_followup_message(inter.application_id, inter.token, %{
            content: lib_str,
            flags: 64
          })
          |> elem(0)

        :ok =
          Api.create_followup_message(inter.application_id, inter.token, %{
            content: IO.iodata_to_binary(validation_msg),
            flags: 64
          })
          |> elem(0)
    end

    :ignore
  end

  @impl true
  def get_create_map do
    %{
      type: 1,
      name: "reload",
      description: "Reloads chips, ncps, viruses",
      default_permission: false
    }
  end

  @spec do_reload() :: {libstr :: String.t(), chip_validation :: iodata()}
  defp do_reload do
    ncp_task =
      Task.async(fn ->
        {:ok} = Library.NCP.load_ncps()
        Library.NCP.get_ncp_ct()
      end)

    chip_task =
      Task.async(fn ->
        {:ok} = Library.Battlechip.load_chips()
        Library.Battlechip.get_chip_ct()
      end)

    virus_task =
      Task.async(fn ->
        {:ok} = Library.Virus.load_viruses()
        Library.Virus.get_virus_ct()
      end)

    [ncp_len, chip_len, virus_len] = Task.await_many([ncp_task, chip_task, virus_task], :infinity)

    validation_msg =
      case Library.Virus.validate_virus_drops() do
        {:ok} -> "All virus drops exist"
        {:error, msg} -> ["missing chips:\n", msg]
      end

    {"#{chip_len} Battlechips loaded\n#{virus_len} Viruses loaded\n#{ncp_len} NCPs loaded",
     validation_msg}
  end
end
