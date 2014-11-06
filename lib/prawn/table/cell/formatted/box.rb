# encoding: utf-8

# formatted/box.rb : Implements formatted table box
#
# Copyright December 2009, Gregory Brown and Brad Ediger. All Rights Reserved.
#
# This is free software. Please see the LICENSE and COPYING files for details.
#

module Prawn
  class Table
    class Cell
      module Formatted
        # @group Stable API

        # Generally, one would use the Prawn::Text::Formatted#formatted_text_box
        # convenience method. However, using Table::Cell::Formatted::Box.new lets
        # you create a formatted box with the table cell rotation algorithm. In
        # conjunction with #render(:dry_run => true) you can do look-ahead
        # calculations prior to placing text on the page, or to determine how much
        # vertical space was consumed by the printed text
        #
        class Box < Prawn::Text::Formatted::Box
          include Prawn::Table::Cell::Formatted::Wrap

          @x_correction = @y_correction = nil

          def initialize(formatted_text, options={})
            super formatted_text, options
            # limit rotation to 0-90 until developed
            @rotate = 90 if @rotate > 90
            @rotate = 0  if @rotate < 0
          end

          def initialize_wrap(array)
            super array
            if @baseline_y == 0 && @rotate != 0 && @rotate != 90
              # adjust vertical positioning so the first word fits
              first_token = @line_wrap.tokenize(@arranger.preview_next_string).first
              first_width = @document.width_of first_token
              # find out how far down and left the first token
              # must be moved so its top edge fits in the corner
              hyp = -first_width * rotate_sin
              @baseline_y = hyp * rotate_cos - @font_size
              @x_correction = hyp * rotate_sin
              @y_correction = -@baseline_y
              # correct the height running over the bottom padding
              # why is this necessary?
              @height -= 5
            end
          end

          # The width available at this point in the box
          #
          def available_width(baseline_y = @baseline_y)
            if @rotate == 0
              @width
            elsif @rotate == 90
              @height
            else
              baseline_top = -baseline_y - @font_size
              # if the angle is smaller than the diagonal
              if @height > aspect_height
                if baseline_top < @width * rotate_sin
                  # in the top 'corner'
                  baseline_top / (rotate_sin * rotate_cos)
                elsif baseline_top < @height * rotate_cos
                  # in the middle section
                  @width / rotate_cos - @line_height * rotate_tan
                else
                  # the bottom 'corner'
                  (@height * rotate_cos + @width * rotate_sin + baseline_y) /
                    (rotate_cos * rotate_sin)
                end
              else # angle is larger than the diagonal
                if baseline_top < @height * rotate_cos
                  # in the top 'corner'
                  baseline_top * rotate_sin_inv * rotate_cos_inv
                elsif baseline_top < @width * rotate_sin
                  # in the middle section
                  @height * rotate_sin_inv - @line_height * rotate_tan_inv
                else
                  # the bottom 'corner'
                  (@height * rotate_cos + @width * rotate_sin + baseline_y) *
                    (rotate_cos_inv * rotate_sin_inv)
                end
              end
            end
          end

          # The height actually used during the previous <tt>render</tt>
          #
          def height(baseline_y = @baseline_y)
            return 0 if baseline_y.nil? || @descender.nil?
            if @rotate == 0 || @rotate == 90
              (baseline_y - @descender).abs
            else
              ((baseline_y - @descender).abs - @width/2) * rotate_cos_inv
            end
          end

          # The height available at this point in the box
          #
          def available_height(width = @width)
            if @rotate == 0
              @height
            elsif @rotate == 90
              @width
            else # outside corner to outside corner
              @height * rotate_cos + @width * rotate_sin
            end
          end

          # <tt>fragment</tt> is a Prawn::Text::Formatted::Fragment object
          #
          def draw_fragment(fragment, accumulated_width=0, line_width=0, word_spacing=0) #:nodoc:

            last_baseline = @baseline_y+@line_height
            case(@align)
            when :left
              x = @at[0]
            when :center
              x = @at[0] + (available_width(last_baseline) - line_width) * 0.5
            when :right
              x = @at[0] + available_width(last_baseline) - line_width
            when :justify
              if @direction == :ltr
                x = @at[0]
              else
                x = @at[0] + available_width(last_baseline) - line_width
              end
            end
            # @document.circle @at, 3
            # bottom_left = [@at[0]-@height*rotate_sin,@at[1]-@height*rotate_cos]
            # top_right = [@at[0]+@width*rotate_cos,@at[1]-@width*rotate_sin]
            # @document.circle bottom_left, 3
            # @document.circle top_right, 3
            # @document.circle [bottom_left[0]+top_right[0], bottom_left[1]-(@at[1]-top_right[1])], 3

            x += accumulated_width
            y = @at[1] + @baseline_y + fragment.y_offset
            # starting spot
            # @document.circle [x,y+@y_correction], 1
            # text location
            # @document.circle [x+last_baseline*rotate_tan+@font_size*rotate_tan,y+@y_correction], 2
            # uncorrected rectangle edge:
            # @document.circle [x+last_baseline*rotate_tan,y+@y_correction], 2

            if @rotate != 0 && @rotate != 90
              height_actual   = -last_baseline * rotate_cos_inv
              # @document.circle [x+last_baseline*rotate_tan+(height_actual-@height)*rotate_sin_inv,y+@y_correction], 2
              y += @y_correction
              # we have reached the bottom corner of the cell
              if height_actual > @height
                x += last_baseline*rotate_tan+(height_actual-@height)*rotate_sin_inv
                # check if the line overlaps the left side
                test_y = Math.tan((90-@rotate)* Math::PI / 180)*(x-@at[0]) + @at[1]
                if (y+@font_size) > test_y
                  x += (y+@font_size-test_y)*rotate_tan
                end
              else # move left
                x += (last_baseline + @y_correction) * rotate_tan + @x_correction
              end
            end

            fragment.left = x
            fragment.baseline = y

            if @inked
              draw_fragment_underlays(fragment)

              @document.word_spacing(word_spacing) {
                if @draw_text_callback
                  @draw_text_callback.call(fragment.text, :at => [x, y],
                                           :kerning => @kerning)
                else
                  @document.draw_text!(fragment.text, :at => [x, y],
                                       :kerning => @kerning)
                end
              }

              draw_fragment_overlays(fragment)
            end
          end

          def valid_options
            PDF::Core::Text::VALID_OPTIONS + [:at, :height, :width,
                                                :align, :valign,
                                                :rotate,
                                                :overflow, :min_font_size,
                                                :leading, :character_spacing,
                                                :mode, :single_line,
                                                :skip_encoding,
                                                :document,
                                                :direction,
                                                :fallback_fonts,
                                                :draw_text_callback]
          end

          private

          def render_rotated(text)
            unprinted_text = ''

            if @rotate == 90
              x = @at[0] + @height/2.0 - 1.0
              y = @at[1] - @height/2.0 + 4.0
            else
              x = @at[0]
              y = @at[1]
            end

            @document.rotate(@rotate, :origin => [x, y]) do
              unprinted_text = wrap(text)
            end
            unprinted_text
          end

          private

          def aspect_height
            @aspect_height ||= @width * rotate_tan 
          end

          def rotate_complement_rads
            @rotate_complement_rads ||= (90 - @rotate) * Math::PI / 180
          end

          def rotate_rads
            @rotate_rads ||= @rotate * Math::PI / 180
          end

          def rotate_atan
            Math.atan(@height/@width) * 180 / Math::PI
          end

          def rotate_tan
            @rotate_tan ||= Math.tan(rotate_rads)
          end

          def rotate_tan_inv
            @rotate_tan_inv ||= 1/rotate_tan
          end

          def rotate_cos
            @rotate_cos ||= Math.cos(rotate_rads)
          end

          def rotate_cos_inv
            @rotate_cos_inv ||= 1/rotate_cos
          end

          def rotate_sin
            @rotate_sin ||= Math.sin(rotate_rads)
          end

          def rotate_sin_inv
            @rotate_sin_inv ||= 1/rotate_sin
          end

        end

      end
    end
  end
end
