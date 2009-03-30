require 'fileutils'
include Magick

module Saucy
  module Render
    module Helper

      def has_spans?(string)
        has_opening_spans?(string) or has_closing_spans?(string)
      end

      def has_opening_spans?(string)
        string.downcase.include?("<span>")
      end

      def has_closing_spans?(string)
        string.downcase.include?("</span>")
      end

      def first_span_is_opened?(string)
        (string.scan(/<\/?span>/i).first.downcase=="<span>") ? true : false
      end

      def string_starts_with_opening_span?(string)
        (string.downcase[0,6]=="<span>") ? true : false
      end

      # Check if the first segment of a string is within span
      def starts_with_span?(string)
        (string_starts_with_opening_span?(string) or !first_span_is_opened?(string)) ? true : false
      end

    end # module helper


    class Draw
      extend Helper

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
        :margin => [0,0,0,0],
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
        def render(text, filename, options = {})

          style = DEFAULT_STYLE.deep_merge(options[:style] || {})
          span_style = (has_spans?(text) && options[:span] && !options[:span].empty?) ? style.deep_merge(options[:span]) : style

          image = draw(text, style, span_style)
          background_image!(image, style[:background])

          if options[:highlight] && !options[:highlight].empty?
            images  = Magick::ImageList.new
            style   = style.deep_merge(options[:highlight])
            span_style = (has_spans?(text) && options[:span_highlight] && !options[:span_highlight].empty?) ? span_style.deep_merge(options[:span_highlight]) : style

            highlight_image = draw(text, style, span_style)
            background_image!(highlight_image, style[:background])

            images << highlight_image
            images << image

            # Append vertically
            image = images.append(true)
          end

          # Make saucy dir
          FileUtils.mkdir_p(ABS_OUTPUT_DIR)

          image.write(File.join(ABS_OUTPUT_DIR, filename))

        end

        #######
        protected
        #######

        # Draw some text
        def draw(text, style, span_style)
          lines = text.split("\n")

          # Computing some useful values
          larger_font = (span_style.nil? or style[:font][:size] > span_style[:font][:size]) ? style[:font][:size] : span_style[:font][:size]
          wider_stroke = (span_style.nil? or style[:stroke][:width] > span_style[:stroke][:width]) ? style[:stroke][:width] : span_style[:stroke][:width]
          background_color = (FileTest.exists?("#{RAILS_ROOT}/#{style[:background]}")) ? 'transparent' : style[:background]

          # Guessing one line size
          width = larger_font * text.length + wider_stroke * 2
          height = (larger_font * 2 + wider_stroke * 2)

          # Setting default value for objects used in the loop
          y = 0
          x = 0
          current_style, previous_style = style, style
          images = Magick::ImageList.new

          # Each line will be made of one image. All lines will then be merged.
          lines.each do |line|
            # Creating image object
            image = Magick::Image.new(width*2, height*2) {
              self.background_color = background_color
            }
            # Creating drawer.
            t = Magick::Draw.new
            # This will define the minimum height of a line
            line_height = larger_font

            # If this line has not spans, then we just writte it normally
            if !has_spans?(line)
              # Lines without spans will always use the previous style. Default is the normal style
              # (set above). Therefore, if a span fills multiple lines, its style will used correctly.
              annotate!(t, image, 0, y, line, previous_style[:font], previous_style[:spacing])
              line_height = previous_style[:font][:height] || previous_style[:font][:size]
            else
              # Guess which style we need to use.
              current_style = (starts_with_span?(line)) ? span_style : style
              # Now, let's split the string.
              text_elements = line.split(/<\/?span>/i)

              # Reinitialize previous style element
              previous_style = {:margin => [0,0,0,0]}

              # Sub pieces of text will be drawn separatly
              text_elements.each do |text_element|
                next if text_element.blank?

                # We need to adjust the x coordinate of the current piece of text
                x = image.trim.columns
                # Annotate the picture
                annotate!(t, image, x, y, text_element, current_style[:font], current_style[:spacing], current_style[:margin], previous_style[:margin])
                line_height = current_style[:font][:height] || larger_font

                # Save previous style for next iteration
                previous_style = current_style
                # Update style
                current_style = (current_style==span_style) ? style : span_style
              end
            end
            # Remove unused space.
            image.trim!

            # If the resulting image is smaller than it should, we add some empty space
            if image.rows < line_height
              new_image = Magick::Image.new(image.columns, line_height) { self.background_color = background_color }
              image = new_image.composite(image, Magick::CenterGravity, Magick::OverCompositeOp)
            end

            # Add image to imagelist
            images << image
          end

          # Append vertically
          image = images.append(true)

          if style[:rotate] != 0
            image = rotate!(image, style[:rotate])
          end

          if style[:shadow][:render]
            image = shadow!(image, style[:shadow])
          end

          image.trim!
        end

        # Write text on image object
        def annotate!(draw, image, x, y, text, font, spacing, margin=[0,0,0,0], previous_margin=[0,0,0,0])
          font_file = font[:font].match(/\./) ? File.join(FONT_STORE, font[:font]) : font[:font]
          #puts "==> text = '#{text}', x = #{x}, y = #{y}, margin = #{margin.to_s}, previous_margin = #{previous_margin.to_s}"

          draw.annotate(image, 0, 0, x + margin[3] + previous_margin[1], y + margin[0], text) {
            self.gravity = Magick::WestGravity
            self.stroke = 'transparent'
            self.fill = font[:color]
            self.kerning = spacing[:letter]
            self.pointsize = font[:size]
            self.font = font_file
          }
        end

        # Add background image
        def background_image!(image, background_image)
          if FileTest.exists?("#{RAILS_ROOT}/#{background_image}")
            background_image = Magick::Image.read("#{RAILS_ROOT}/#{background_image}").first
            background_image.crop!(0,0,image.columns,image.rows)
            image = background_image.composite(image, Magick::CenterGravity, Magick::OverCompositeOp)
          end
        end

        # Add shadow effect
        def shadow! input, shadow
          raise NotImplementedError, "This will implemented in the future..."
        end

        # Rotate text
        def rotate! input, angle
          raise NotImplementedError, "This will implemented in the future..."
        end

      end # self
    end # class draw
  end
end