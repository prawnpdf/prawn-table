# encoding: utf-8

# formatted/wrap.rb : Implements formatted table box
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

        module Wrap
          include Prawn::Text::Formatted::Wrap #:nodoc:
          
          # See the developer documentation for PDF::Core::Text#wrap
          #
          # Formatted#wrap should set the following variables:
          #   <tt>@line_height</tt>::
          #        the height of the tallest fragment in the last printed line
          #   <tt>@descender</tt>::
          #        the descender height of the tallest fragment in the last
          #        printed line
          #   <tt>@ascender</tt>::
          #        the ascender heigth of the tallest fragment in the last
          #        printed line
          #   <tt>@baseline_y</tt>::
          #       the baseline of the current line
          #   <tt>@nothing_printed</tt>::
          #       set to true until something is printed, then false
          #   <tt>@everything_printed</tt>::
          #       set to false until everything printed, then true
          #
          # Returns any formatted text that was not printed
          #
          def wrap(array) #:nodoc:
            initialize_wrap(array)

            stop = false
            while !stop
              # wrap before testing if enough height for this line because the
              # height of the highest fragment on this line will be used to
              # determine the line height
              begin
                cannot_fit = false
                @line_wrap.wrap_line(:document => @document,
                                     :kerning => @kerning,
                                     :width => available_width,
                                     :arranger => @arranger,
                                     :rotate => @rotate)
              rescue Prawn::Errors::CannotFit
                cannot_fit = true
              end

              if enough_height_for_this_line?
                move_baseline_down
                print_line unless cannot_fit
              elsif cannot_fit
                raise Prawn::Errors::CannotFit
              else
                stop = true
              end

              stop ||= @single_line || @arranger.finished?
            end
            @text = @printed_lines.join("\n")
            @everything_printed = @arranger.finished?
            @arranger.unconsumed
          end

        end

      end
    end
  end
end
