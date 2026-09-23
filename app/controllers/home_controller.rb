class HomeController < ApplicationController
  # Serves the React SPA for client-side routes (e.g. /employees/123) in the
  # single-origin production setup. /api, /assets and /up are excluded.
  def index
    send_file Rails.public_path.join("index.html"), type: "text/html", disposition: "inline"
  end
end
