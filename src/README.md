This folder contains a few of the erlang modules that the bot uses.
Why are they Erlang instead of Elixir? Because I'm experimenting with mnesia and calling qlc functions from Elixir
has speed issues and are a "won't fix". So I'm using Erlang for the mnesia stuff and Elixir for the rest.
