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

      def starts_with_whitespace?(string)
        string =~ /^\s/
      end

      def ends_with_whitespace?(string)
        string =~ /\s$/
      end

    end # module helper


    class Draw
      extend Helper

      FONT_STORES = [
        File.join(File.dirname(__FILE__), *%w[ .. .. .. fonts ]),
        File.join(Rails.root, *%w[ lib fonts ])
      ]

      DEFAULT_STYLE = {
        :background => "transparent",
        :font       => {
          :size     => 18,
          :color    => "#000",
          :font     => "arial",
          :stretch  => "normal",
          :align    => "left"
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
          image = background_image(image, style[:background]) if (FileTest.exists?("#{RAILS_ROOT}/#{style[:background]}"))

          if options[:highlight] && !options[:highlight].empty?
            images  = Magick::ImageList.new
            style   = style.deep_merge(options[:highlight])
            span_style = (has_spans?(text) && options[:span_highlight] && !options[:span_highlight].empty?) ? span_style.deep_merge(options[:span_highlight]) : style

            highlight_image = draw(text, style, span_style)
            highlight_image = background_image(highlight_image, style[:background]) if (FileTest.exists?("#{RAILS_ROOT}/#{style[:background]}"))

            images << highlight_image
            images << image

            # Append vertically
            image = images.append(true)
          end

          # Specify image height
          if options[:alignment]
            # Create a string sample with b and p letters. This is the maximum size an image with this font can have
            string_sample_updown = draw("bp", style, span_style)
            # Apply this size to all generated images
            image_height = string_sample_updown.rows

            #Create two image samples, one with only a 'a', another with a 'b'
            string_sample_flat = draw("a", style, span_style)
            string_sample_up = draw("b", style, span_style)

            # Browse the text to detect up letters. If there is no up letter the margin will be equal to the difference of height betweem b and a image
            up_letters = ['b', 'd', 'f', 'h', 'i', 'k', 'l', 't']
            has_up_letter = false
            text.each_char do |c|
              if up_letters.member?(c)
                has_up_letter = true
                break
              end
            end
            if !has_up_letter
              up_margin = string_sample_up.rows - string_sample_flat.rows
            else
              up_margin = 0
            end
            background_color = (FileTest.exists?("#{RAILS_ROOT}/#{style[:background]}")) ? 'transparent' : style[:background]
            new_image = Magick::Image.new(image.columns, image_height) { self.background_color = background_color }
            image = new_image.composite(image, 0,up_margin, Magick::OverCompositeOp)
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
            x_margin, y_margin = 0, 0

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
              # (set above). Therefore, if a span fills multiple lines, its style will be used correctly.
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

                # Computing margins
                x_margin = current_style[:margin][3] + previous_style[:margin][1]
                y_margin = current_style[:margin][0]

                # Quick fix for whitespace (should be improved)
                x += current_style[:font][:size].to_i/2 if starts_with_whitespace?(text_element)

                # We need to adjust the coordinates of the current piece of text
                x = image.trim.columns

                # Annotate the picture
                annotate!(t, image, x + x_margin, y + y_margin, text_element, current_style[:font], current_style[:spacing])
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
          image = append_vertically(images, style[:font][:align])

          if style[:rotate] != 0
            image = rotate!(image, style[:rotate])
          end

          if style[:shadow][:render]
            image = shadow!(image, style[:shadow])
          end

          image.trim!
        end

        # Write text on image object
        def annotate!(draw, image, x, y, text, font, spacing)
          font_file = font[:font]
          FONT_STORES.each do |store|
            path = File.join(store, font[:font])
            if File.exist?(path)
              font_file = path
              break
            end
          end
          # puts "==> text = '#{text}', x = #{x}, y = #{y}"

          draw.annotate(image, 0, 0, x, y, text) {
            self.gravity = Magick::WestGravity
            self.stroke = 'transparent'
            self.fill = font[:color]
            self.kerning = spacing[:letter]
            self.pointsize = font[:size]
            self.font = font_file
          }
        end

        # Add background image
        def background_image(image, background_image)
          if FileTest.exists?("#{RAILS_ROOT}/#{background_image}")
            background_image = Magick::Image.read("#{RAILS_ROOT}/#{background_image}").first
            background_image.crop!(0,0,image.columns,image.rows)
            image = background_image.composite(image, Magick::CenterGravity, Magick::OverCompositeOp)
          end
          image
        end

        #
        def append_vertically(image_list, text_align)
          text_align = case text_align.strip.downcase
          when 'center': Magick::CenterGravity
          when 'right': Magick::EastGravity
          else
            Magick::WestGravity
          end

          # Because Magick::WestGravity corresponds to the default behaviour of ImageList::append
          if text_align != Magick::WestGravity
            largest_width = 0
            image_list.each { |image| largest_width = image.columns if largest_width < image.columns }
            image_list.collect! do |image|
              big_image= Magick::Image.new(largest_width, image.rows) {
                self.background_color = 'transparent'
              }
              big_image.composite(image, text_align, Magick::OverCompositeOp)
            end
          end

          image_list.append(true)
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