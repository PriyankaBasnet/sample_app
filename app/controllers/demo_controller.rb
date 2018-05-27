class DemoController < ApplicationController

  layout 'application'
  def index
  end

  def grid_layout
    @images = Image.all
  end

 def animation
 end
end
