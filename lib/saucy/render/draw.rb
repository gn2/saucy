require 'fileutils'

module Saucy
  module Render
    class Draw
      FONT_STORE = File.join(File.dirname(__FILE__), *%w[ .. .. .. fonts ])
    
      DEFAULT_STYLE = { 
        :background => "transparent",
        :font       => {
          :size     => 18, 
          :color    => "#000", 
          :font     => "arial", 
          :stretch  => "normal"
        },
        :stroke => {
          :width    => 0, 
          :color    => "#000", 
          :inner    => true 
        },
        :spacing    => {
          :letter   => 0, 
          :word     => 0
        },
        :rotate => 0,
        :shadow => {
          :color => "#000", 
          :opacity => 0.6, 
          :top => 2, 
          :left => 2, 
          :blur => 5.0, 
          :render => false 
        }
      }
    
      class << self
        def render(name, filename, options = {})
          raise NotImplementedError, "This will implemented soon!"
        end


        def draw(text, font, background, stroke, spacing, shadow, rotate)
          raise NotImplementedError, "This will implemented soon!"
        end
      
      
        def shadow! input, shadow
          raise NotImplementedError, "This will implemented in the future..."
        end


        def rotate! input, angle
          raise NotImplementedError, "This will implemented in the future..."
        end
      
      end # self
    end
  end
end