defmodule JellyWeb.GameLive do
  use JellyWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    cu
    """
  end
end
