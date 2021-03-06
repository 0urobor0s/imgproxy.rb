module Imgproxy
  # Formats and regroups processing options
  class Options < Hash
    STRING_OPTS = %i[resizing_type gravity crop_gravity watermark_position watermark_url style
                     cachebuster format].freeze
    INT_OPTS = %i[width height crop_width crop_height
                  quality brightness pixelate watermark_x_offset watermark_y_offset].freeze
    FLOAT_OPTS = %i[dpr gravity_x gravity_y crop_gravity_x crop_gravity_y contrast saturation
                    blur sharpen watermark_opacity watermark_scale].freeze
    BOOL_OPTS = %i[enlarge extend].freeze
    ARRAY_OPTS = %i[background preset].freeze
    ALL_OPTS = (STRING_OPTS + INT_OPTS + FLOAT_OPTS + BOOL_OPTS + ARRAY_OPTS).freeze

    OPTS_PRIORITY = %i[ crop resize size resizing_type width height dpr enlarge extend gravity
                        quality background blur sharpen pixelate watermark watermark_url preset
                        cachebuster ].freeze

    # @param options [Hash] raw processing options
    def initialize(options)
      merge!(options.slice(*ALL_OPTS))

      typecast

      group_options

      encode_style
      encode_watermark_url

      replace(Hash[sort_by { |k, _| OPTS_PRIORITY.index(k) || 99 }])

      freeze
    end

    private

    def typecast
      compact.each do |key, value|
        self[key] =
          case key
          when *STRING_OPTS then value.to_s
          when *INT_OPTS then value.to_i
          when *FLOAT_OPTS then value.to_f
          when *BOOL_OPTS then bool(value)
          when *ARRAY_OPTS then wrap_array(value)
          end
      end
    end

    def bool(value)
      value && value != 0 && value != "0" ? 1 : 0
    end

    def wrap_array(value)
      value.is_a?(Array) ? value : [value]
    end

    def group_options
      group_crop_opts
      group_resizing_opts
      group_gravity_opts
      group_adjust_opts
      group_watermark_opts
    end

    def group_crop_opts
      crop_width = delete(:crop_width)
      crop_height = delete(:crop_height)
      crop_gravity = extract_and_trim_nils(:crop_gravity, :crop_gravity_x, :crop_gravity_y)

      return unless crop_width || crop_height

      crop_gravity = nil if crop_gravity[0].nil?

      self[:crop] = [crop_width || 0, crop_height || 0, *crop_gravity]
    end

    def group_resizing_opts
      return unless self[:width] && self[:height]

      self[:size] = extract_and_trim_nils(:width, :height, :enlarge, :extend)

      self[:resize] = [delete(:resizing_type), *delete(:size)] if self[:resizing_type]
    end

    def group_gravity_opts
      gravity = extract_and_trim_nils(:gravity, :gravity_x, :gravity_y)

      self[:gravity] = gravity unless gravity[0].nil?
    end

    def group_adjust_opts
      return unless values_at(:brightness, :contrast, :saturation).count { |o| !o.nil? } > 1

      self[:adjust] = extract_and_trim_nils(:brightness, :contrast, :saturation)
    end

    def group_watermark_opts
      watermark = extract_and_trim_nils(
        :watermark_opacity,
        :watermark_position,
        :watermark_x_offset,
        :watermark_y_offset,
        :watermark_scale,
      )

      self[:watermark] = watermark unless watermark[0].nil?
    end

    def encode_style
      return if self[:style].nil?
      self[:style] = Base64.urlsafe_encode64(self[:style]).tr("=", "")
    end

    def encode_watermark_url
      return if self[:watermark_url].nil?
      self[:watermark_url] = Base64.urlsafe_encode64(self[:watermark_url]).tr("=", "")
    end

    def extract_and_trim_nils(*keys)
      trim_nils(keys.map { |k| delete(k) })
    end

    def trim_nils(value)
      value.delete_at(-1) while !value.empty? && value[-1].nil?
      value
    end
  end
end
