defmodule JellyWeb.Components.Icons do
  use Phoenix.Component

  attr :height, :string, default: "0px"
  attr :width, :string, default: "0px"

  def jelly(assigns) do
    ~H"""
    <svg
      height={@height}
      width={@width}
      version="1.1"
      id="Layer_1"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink"
      viewBox="0 0 297 297"
      xml:space="preserve"
      fill="#000000"
    >
      <g id="SVGRepo_bgCarrier" stroke-width="0"></g>
      <g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g>
      <g id="SVGRepo_iconCarrier">
        <g>
          <g>
            <g>
              <circle fill="#7e22ce" cx="148.5" cy="148.5" r="148.5"></circle>
            </g>
          </g>

          <path
            fill="#581c87"
            d="M234.076,101.661L35.895,195.983l100.527,100.526c3.985,0.321,8.012,0.491,12.079,0.491 c76.847,0,140.059-58.372,147.719-133.196L234.076,101.661z"
          >
          </path>

          <g>
            <g>
              <path
                fill="#D85D72"
                d="M45,186h73.929l-12.799-74.81c-1.14-7.978-7.972-13.904-16.032-13.904H73.831 c-8.059,0-14.892,5.926-16.031,13.904L45,186z"
              >
              </path>
            </g>

            <g>
              <path
                fill="#C9576F"
                d="M178.071,186H252l-12.799-74.81c-1.14-7.978-7.972-13.904-16.032-13.904h-16.267 c-8.059,0-14.892,5.926-16.031,13.904L178.071,186z"
              >
              </path>
            </g>
          </g>

          <g>
            <g>
              <path
                fill="#D87788"
                d="M148.5,186h73.929L209.63,97.286c-1.14-7.978-7.972-13.904-16.032-13.904h-16.267 c-8.059,0-14.892,5.926-16.031,13.904L148.5,186z"
              >
              </path>
            </g>

            <g>
              <path
                fill="#ED808D"
                d="M74.571,186H148.5l-12.799-88.714c-1.14-7.978-7.972-13.904-16.032-13.904h-16.267 c-8.059,0-14.892,5.926-16.032,13.904L74.571,186z"
              >
              </path>
            </g>
          </g>

          <g>
            <path
              fill="#EFABBA"
              d="M111.536,186h73.929l-12.799-89.596c-1.14-7.978-7.972-13.904-16.031-13.904h-16.267 c-8.059,0-14.892,5.926-16.032,13.904L111.536,186z"
            >
            </path>
          </g>

          <g>
            <path
              fill="#D390A1"
              d="M172.665,96.404c-1.14-7.978-7.972-13.904-16.031-13.904h-7.466V186h36.297L172.665,96.404z"
            >
            </path>
          </g>

          <g>
            <path
              fill="#ECF0F1"
              d="M41.25,198h214.5c4.556,0,8.25-3.694,8.25-8.25l0,0c0-4.556-3.694-8.25-8.25-8.25H41.25 c-4.556,0-8.25,3.694-8.25,8.25l0,0C33,194.306,36.694,198,41.25,198z"
            >
            </path>
          </g>

          <g>
            <path
              fill="#D0D5D9"
              d="M255.75,181.5H149.167V198H255.75c4.556,0,8.25-3.694,8.25-8.25S260.306,181.5,255.75,181.5z"
            >
            </path>
          </g>
        </g>
      </g>
    </svg>
    """
  end
end
