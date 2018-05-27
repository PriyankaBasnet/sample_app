Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html


get "/index_page" => "demo#index"
get "/grid_layout" => "demo#grid_layout"
get "/animation" => "demo#animation"

end
