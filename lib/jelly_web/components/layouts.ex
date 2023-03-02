defmodule JellyWeb.Layouts do
  @moduledoc false
  use JellyWeb, :html
  import JellyWeb.Components.Icons

  embed_templates "layouts/*"
end
