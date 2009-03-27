module Saucy
  module Helper

    # Arguments:
    # saucy_tag(name, :option1 => 'foo')
    # saucy_tag(name1, :option2 => 'foo', :highlight => {:font => {:color => 'blue'}})
    # saucy_tag(name1, :option2 => 'foo', :highlight => {:font => {:color => 'blue'}}, :render => 'draw')
    # saucy_tag(name1, :option2 => 'foo', :highlight => {:font => {:color => 'blue'}}, :line_width => 20)

    def saucy_tag(name, options = {}, &block)
      filename  = Digest::MD5.hexdigest(name + options.to_s) + '_' + name.gsub(/[^a-z0-9]+/i, '_') + '.png'

      unless File.exists?(File.join(ABS_OUTPUT_DIR, filename))

        name = word_wrap(name, :line_width => options[:line_width].to_i) if options[:line_width] && options[:line_width].to_i > 0

        if !options[:render].nil?
          case options[:render].to_s.downcase
          when 'draw'
            Saucy::Render::Draw.render(name, filename, options)
          else
            Saucy::Render::RVG.render(name, filename, options)
          end
        else
          # RVG is used by default (for backward compatibility)
          Saucy::Render::RVG.render(name, filename, options)
        end
      end

      size = Saucy::Image.cached_size(filename)
      # We divide by the number of images to get the height
      # of the first one (for sprites)
      real_height = size[1] / (options[:highlight] ? 2 : 1)
      height = size[1]

      src  = File.join(OUTPUT_DIR, filename)

      options[:html] ||= {}
      options[:html][:class] ||= []
      style = options[:html][:style] ||= {}

      style['text-indent'] = '-9999em'
      #style['color'] = 'transparent' #alternative (allows selecting of the text)
      style['background'] = "url('#{src}') no-repeat"

      style['width']      = "#{size[0]}px"
      style['height']     = "#{real_height}px"

      #style['overflow'] = "hidden"
      style['display'] = "block"

      ie_style = ""
      transparent = options[:style][:background] &&  options[:style][:background] != "transparent" #transparent by default
      if transparent
        ie_style += '_background: transparent;'
        ie_style += "_filter:progid:DXImageTransform.Microsoft.AlphaImageLoader(src='#{src}', sizingMethod='crop');"
      end

      if options[:highlight]
        style['margin-top'] = "#{real_height - height}px"
      end

      options[:tag] ||= :p

      options[:html][:style] = style.collect {|key, value| [key, value].join(': ') }.join('; ') + "; " + ie_style

      options[:html][:class] = ["saucy"].concat(options[:html][:class].split(" ")).join(" ")

      if block_given?
        concat(content_tag(options[:tag], capture(&block), options[:html] || {}))
      else
        if options[:highlight]
          inner_tag = "<a href='#{options[:html][:href]}' class='saucySprite' style=\"#{options[:html][:style]};height: #{height}px;\">#{name}</a>"
          options[:html][:style] = "display:block; overflow:hidden; height: #{real_height}px;"
          content_tag(options[:tag], inner_tag, options[:html] || {})
        else
          content_tag(options[:tag], name, options[:html] || {})
        end
      end

    end

  end
end
