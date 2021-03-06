module Saucy
  module Helper

    # Arguments:
    # saucy_tag(name, :option1 => 'foo')
    # saucy_tag(name1, :option2 => 'foo', :highlight => {:font => {:color => 'blue'}})
    # saucy_tag(name1, :option2 => 'foo', :highlight => {:font => {:color => 'blue'}}, :render => 'draw')
    # saucy_tag(name1, :option2 => 'foo', :highlight => {:font => {:color => 'blue'}}, :line_width => 20)

    def saucy_tag(name, options = {}, &block)
      filename  = Digest::MD5.hexdigest(name + options.to_s) + '_' + name.gsub(/[^a-z0-9]+/i, '_')[0..20] + '.png'

      unless File.exists?(File.join(ABS_OUTPUT_DIR, filename))

        name = word_wrap_avoiding_spans(name, options[:line_width].to_i) if options[:line_width] && options[:line_width].to_i > 0

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
      real_height = size[1] / ((options[:highlight] && !options[:highlight].empty?) ? 2 : 1)
      height = size[1]
      width = size[0]
      
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

      if options[:highlight] && !options[:highlight].empty?
        style['margin-top'] = "#{real_height - height}px"
      end

      options[:tag] ||= :p

      options[:html][:style] = style.collect {|key, value| [key, value].join(': ') }.join('; ') + "; " + ie_style

      options[:html][:class] = ["saucy"].concat(options[:html][:class].split(" ")).join(" ")

      if block_given?
        concat(content_tag(options[:tag], capture(&block), options[:html] || {}))
      else
        if options[:highlight] && !options[:highlight].empty?
          if options[:facebox]
            inner_tag = link_to_function(name, "jQuery.facebox(function(){ #{remote_function(:url => options[:html][:href])} })", :href => options[:html][:href], :style => "#{options[:html][:style]};height: #{height}px; width:#{width}px;", :class => ["saucySprite"].concat(options[:html][:class].split(" ")).join(" "))
            options[:html][:style] = "display:block; overflow:hidden; height: #{real_height}px;; width:#{width}px;"
            content_tag(options[:tag], inner_tag, options[:html] || {})
          else
            inner_tag = "<a href='#{options[:html][:href]}' class='#{["saucySprite"].concat(options[:html][:class].split(" ")).join(" ")}' style=\"#{options[:html][:style]};height: #{height}px; width:#{width}px;\">#{name}</a>"
            options[:html][:style] = "display:block; overflow:hidden; height: #{real_height}px; width:#{width}px;"
            content_tag(options[:tag], inner_tag, options[:html] || {})
          end
        else
          content_tag(options[:tag], name, options[:html] || {})
        end
      end

    end

    private
    SPAN_RE = /(?i:<\/?span[^>]*>)/
    ALL_SPANS_RE = /(?:#{SPAN_RE}*(?!#{SPAN_RE}))/
    def word_wrap_avoiding_spans(str,width)
      full_re = /((?:#{ALL_SPANS_RE}.){1,#{width-1}}#{ALL_SPANS_RE}\S(?:#{SPAN_RE}+|\b))\s*/
      str.gsub(/\s*\n/, ' ').gsub(full_re, "\\1\n")
    end

  end
end
