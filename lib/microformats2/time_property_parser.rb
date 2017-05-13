module Microformats2
  class TimePropertyParser < ParserCore

    def parse(element, base: nil, element_type: , format_class_array: [], backcompat:  nil)
      @base = base
      @duration_value = nil
      @date_value = nil
      @time_value = nil

      @property_type = element_type

      @fmt_classes = format_class_array
      @mode_backcompat = backcompat

      parse_value_class_pattern(element)

      if @duration_value.nil?  and @time_value.nil? and @date_value.nil?

        value = nil
        if ['time', 'ins', 'del'].include? element.name and not element.attribute('datetime').nil?
          value = element.attribute('datetime').value.strip
        elsif element.name == 'abbr' and not element.attribute('title').nil?
          value = element.attribute('title').value.strip
        elsif (element.name == 'data' or element.name == 'input') and not element.attribute('value').nil?
          value = element.attribute('value').value.strip
        else
          value = element.text.strip
        end

        parse_dt(value)

      end

      if not  @duration_value.nil?
        @duration_value
      elsif not @time_value.nil? and not @date_value.nil?
        @date_value + ' ' + @time_value
      elsif not @time_value.nil?
        @time_value
      elsif not @date_value.nil?
        @date_value
      else
        nil
      end
    end

    def parse_value_class_pattern(element)
      parse_node(element.children)
    end

    def parse_element(element)

      if @duration_value.nil? or (@time_value.nil? and @date_value.nil?)
        if value_title_classes(element).length >= 1
          value =  element.attribute('title').value.strip
        elsif value_classes(element).length >= 1
          if element.name == 'img' or element.name == 'area' and not element.attribute('alt').nil?
            value = element.attribute('alt').value.strip
          elsif element.name == 'data' and not element.attribute('value').nil?
            value = element.attribute('value').value.strip
          elsif element.name == 'abbr' and not element.attribute('title').nil?
            value = element.attribute('title').value.strip
          elsif ['time', 'ins', 'del'].include? element.name and not element.attribute('datetime').nil?
            value = element.attribute('datetime').value.strip
          else
            value = element.text.strip
          end
        end
        parse_dt(value, normalize: true) 

        p_classes = property_classes(element)
        p_classes = backcompat_property_classes(element) if @mode_backcompat
        if p_classes.length == 0 and format_classes(element).length == 0
          parse_node(element.children)
        end
      end

    end

    def parse_dt(data, normalize: false)
      # currently the value-class-pattern page lists to normalize  and remove :'s but not regular parsing, seems very odd
      # https://github.com/microformats/tests/issues/29
      #
      #TODO this still allows a lot of non correct values such as 39th day of the month, etc
      begin
        case data.strip
        when /^(\d{4}-[01]\d-[0-3]\d)[tT ]([0-2]\d:[0-5]\d(:[0-5]\d)?([zZ]|[-+][01]?\d:?[0-5]\d)?)$/
          @date_value = $1 if @date_value.nil?
          @time_value = $2.gsub(/z/, 'Z') if @time_value.nil?
        when /^(\d{4}-[01]\d-[0-3]\d)[tT ]([0-2]\d:[0-5]\d(:[0-5]\d)? ?[-+]\d\d)$/
          @date_value = $1 if @date_value.nil?
          @time_value = $2 if @time_value.nil?
        when /^(\d{4}-[01]\d-[0-3]\d)[tT ]([0-2]\d:[0-5]\d:[0-5]\d ?[-+]\d\d):?(\d\d)$/
          @date_value = $1 if @date_value.nil?
          if normalize
            @time_value = $2 + $3 if @time_value.nil?
          else
            @time_value = $2 + ':' + $3 if @time_value.nil?
          end
        when /^(\d{4}-[01]\d-[0-3]\d)[tT ]([0-2]\d:[0-5]\d)( ?[-+]\d\d:?\d\d)$/
          @date_value = $1 if @date_value.nil?
          if normalize
            @time_value = $2 + $3.gsub(/:/,'') if @time_value.nil?
          else
            @time_value = $2 + $3 if @time_value.nil?
          end
        when /^P\d*W$/
          @duration_value = data if @duration_value.nil?

        when /^P(\d+Y)?(\d+M)?(\d+D)?(T(\d+H)?(\d+M)?(\d+S)?)?$/
          @duration_value = data if @duration_value.nil?

        when /^(\d{4})-([01]?\d)-([0-3]?\d)$/
          @date_value = DateTime.new($1.to_i, $2.to_i, $3.to_i).strftime('%F') if @date_value.nil?

        when /^(\d{4})-([0-3]\d{2})$/
          @date_value = data if @date_value.nil?

        when /^(\d{4})-([01]?\d)$/
          @date_value = data if @date_value.nil?

        when /^[0-2]\d:[0-5]\d(:[0-5]\d)?([zZ]|[-+][01]\d:?\d\d)?$/
          if normalize
            @time_value = data.gsub(/z/, 'Z').gsub(/([+-]\d\d):(\d\d)/, '\1\2') if @time_value.nil?
          else
            @time_value = data.gsub(/z/, 'Z') if @time_value.nil?
          end

        when /^[0-2]\d:[0-5]\d[zZ]?$/
          @time_value = Time.parse(data).strftime('%H:%M') if @time_value.nil?
        when /^([0-2]\d:[0-5]\d:[0-5]\d[-+][01]\d:?[0-5]\d)$/
          Time.parse(data).strftime('%T') #to make sure this time doesn't throw an error
          @time_value = $1 if @time_value.nil?

        when /^([0-2][0-0]:[0-5]\d[-+][01]\d:?[0-5]\d)$/
          Time.parse(data).strftime('%H:%M') #to make sure this time doesn't throw an error
          @time_value = $1 if @time_value.nil?

        when /^([01]?\d):?([0-5]\d)?p\.?m\.?$/i
          @time_value = ($1.to_i + 12).to_s + ':' + $2.to_s.rjust(2,'0') if @time_value.nil?
        when /^([01]?\d):?([0-5]\d)?a\.?m\.?$/i
          @time_value = $1.to_s.rjust(2,'0') + ':' + $2.to_s.rjust(2,'0') if @time_value.nil?
        when /^([01]?\d):([0-5]\d):([0-5]\d)?p\.?m\.?$/i
          @time_value = ($1.to_i + 12).to_s + ':' + $2.to_s.rjust(2,'0') + ':'+ $3.to_s.rjust(2,'0') if @time_value.nil?
        when /^([01]?\d):([0-5]\d):([0-5]\d)?a\.?m\.?$/i
          @time_value = $1.to_s.rjust(2,'0') + ':' + $2.to_s.rjust(2,'0') + ':'+ $3.to_s.rjust(2,'0') if @time_value.nil?

        else
          t = Time.parse(data)
          @time_value = t.strftime('%T') if @time_value.nil?
          @date_value = t.strftime('%F') if @date_value.nil?
        end

      rescue
        nil
      end

    end

  end
end