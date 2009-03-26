require 'fileutils'
include Magick

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
          style = DEFAULT_STYLE.deep_merge(options[:style] || {})

          image = draw(name,
                       style[:font],
                       style[:background],
                       style[:stroke],
                       style[:spacing],
                       style[:shadow],
                       style[:rotate]
                    )

          if options[:highlight]
            images  = Magick::ImageList.new
            style   = style.deep_merge(options[:highlight])

            images << draw(name,
                        style[:font],
                        style[:background],
                        style[:stroke],
                        style[:spacing],
                        style[:shadow],
                        style[:rotate]
                      )
            images << image

            # Append vertically
            image = images.append(true)
          end

          # Make saucy dir
          FileUtils.mkdir_p(ABS_OUTPUT_DIR)

          image.write(File.join(ABS_OUTPUT_DIR, filename))

        end


        def draw(text, font, background, stroke, spacing, shadow, rotate)
          lines = text.split("\n")

          width = font[:size] * text.length + stroke[:width] * 2
          height = (font[:size] * 2 + stroke[:width] * 2) * lines.length

          # Creating image object
          image = Magick::Image.new(width, height) {
            self.background_color = (FileTest.exists?("#{RAILS_ROOT}/#{background}")) ? 'transparent' : background
          }

          font_file = font[:font].match(/\./) ? File.join(FONT_STORE, font[:font]) : font[:font]
          line_height = font[:height] || font[:size]
          y = 0

          # Writing text in image
          t = Magick::Draw.new
          lines.each do |line|
            t.annotate(image, 0, 0, 0, y, line) {
              self.gravity = Magick::WestGravity
              self.stroke = 'transparent'
              self.fill = font[:color]
              self.kerning = spacing[:letter]
              self.pointsize = font[:size]
              self.font = font_file
            }

            y += line_height
          end

          if rotate != 0
            image = rotate!(image, rotate)
          end

          if shadow[:render]
            image = shadow!(image, shadow)
          end

          image.trim!

          # Add background image
          if background != 'transparent' and FileTest.exists?("#{RAILS_ROOT}/#{background}")
            background_image = Magick::Image.read("#{RAILS_ROOT}/#{background}").first
            background_image.crop!(0,0,image.columns,image.rows)
            image = background_image.composite(image, Magick::CenterGravity, Magick::OverCompositeOp)
          end

          image

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