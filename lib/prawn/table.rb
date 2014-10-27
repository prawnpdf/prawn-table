# encoding: utf-8
#
# table.rb: Table drawing functionality.
#
# Copyright December 2009, Brad Ediger. All rights reserved.
#
# This is free software. Please see the LICENSE and COPYING files for details.


require_relative 'table/column_width_calculator'
require_relative 'table/cell'
require_relative 'table/cells'
require_relative 'table/cell/in_table'
require_relative 'table/cell/text'
require_relative 'table/cell/subtable'
require_relative 'table/cell/image'
require_relative 'table/cell/span_dummy'

module Prawn
  module Errors
    # This error is raised when table data is malformed
    #
    InvalidTableData = Class.new(StandardError)

    # This error is raised when an empty or nil table is rendered
    #
    EmptyTable = Class.new(StandardError)
  end

  # Next-generation table drawing for Prawn.
  #
  # = Data
  #
  # Data, for a Prawn table, is a two-dimensional array of objects that can be
  # converted to cells ("cellable" objects). Cellable objects can be:
  #
  # String::
  #   Produces a text cell. This is the most common usage.
  # Prawn::Table::Cell::
  #   If you have already built a Cell or have a custom subclass of Cell you
  #   want to use in a table, you can pass through Cell objects.
  # Prawn::Table::
  #   Creates a subtable (a table within a cell). You can use
  #   Prawn::Document#make_table to create a table for use as a subtable
  #   without immediately drawing it. See examples/table/bill.rb for a
  #   somewhat complex use of subtables.
  # Array::
  #   Creates a simple subtable. Create a Table object using make_table (see
  #   above) if you need more control over the subtable's styling.
  #
  # = Options
  #
  # Prawn/Layout provides many options to control style and layout of your
  # table. These options are implemented with a uniform interface: the +:foo+
  # option always sets the +foo=+ accessor. See the accessor and method
  # documentation for full details on the options you can pass. Some
  # highlights:
  #
  # +cell_style+::
  #   A hash of style options to style all cells. See the documentation on
  #   Prawn::Table::Cell for all cell style options.
  # +header+::
  #   If set to +true+, the first row will be repeated on every page. If set
  #   to an Integer, the first +x+ rows will be repeated on every page. Row
  #   numbering (for styling and other row-specific options) always indexes
  #   based on your data array. Whether or not you have a header, row(n) always
  #   refers to the nth element (starting from 0) of the +data+ array.
  # +column_widths+::
  #   Sets widths for individual columns. Manually setting widths can give
  #   better results than letting Prawn guess at them, as Prawn's algorithm
  #   for defaulting widths is currently pretty boneheaded. If you experience
  #   problems like weird column widths or CannotFit errors, try manually
  #   setting widths on more columns.
  # +position+::
  #   Either :left (the default), :center, :right, or a number. Specifies the
  #   horizontal position of the table within its bounding box. If a number is
  #   provided, it specifies the distance in points from the left edge.
  #
  # = Initializer Block
  #
  # If a block is passed to methods that initialize a table
  # (Prawn::Table.new, Prawn::Document#table, Prawn::Document#make_table), it
  # will be called after cell setup but before layout. This is a very flexible
  # way to specify styling and layout constraints. This code sets up a table
  # where the second through the fourth rows (1-3, indexed from 0) are each one
  # inch (72 pt) wide:
  #
  #   pdf.table(data) do |table|
  #     table.rows(1..3).width = 72
  #   end
  #
  # As with Prawn::Document#initialize, if the block has no arguments, it will
  # be evaluated in the context of the object itself. The above code could be
  # rewritten as:
  #
  #   pdf.table(data) do
  #     rows(1..3).width = 72
  #   end
  #
  class Table
    module Interface 
      # @group Experimental API

      # Set up and draw a table on this document. A block can be given, which will
      # be run after cell setup but before layout and drawing.
      #
      # See the documentation on Prawn::Table for details on the arguments.
      #
      def table(data, options={}, &block)
        t = Table.new(data, self, options, &block)
        t.draw
        t
      end

      # Set up, but do not draw, a table. Useful for creating subtables to be
      # inserted into another Table. Call +draw+ on the resulting Table to ink it.
      #
      # See the documentation on Prawn::Table for details on the arguments.
      #
      def make_table(data, options={}, &block)
        Table.new(data, self, options, &block)
      end
    end

    # Set up a table on the given document. Arguments:
    #
    # +data+::
    #   A two-dimensional array of cell-like objects. See the "Data" section
    #   above for the types of objects that can be put in a table.
    # +document+::
    #   The Prawn::Document instance on which to draw the table.
    # +options+::
    #   A hash of attributes and values for the table. See the "Options" block
    #   above for details on available options.
    #
    def initialize(data, document, options={}, &block)
      @pdf = document
      @cells = make_cells(data)
      @header = false
      options.each { |k, v| send("#{k}=", v) }

      if block
        block.arity < 1 ? instance_eval(&block) : block[self]
      end

      set_column_widths
      set_row_heights
      position_cells
    end

    # Number of rows in the table.
    #
    attr_reader :row_length

    # Number of columns in the table.
    #
    attr_reader :column_length

    # Manually set the width of the table.
    #
    attr_writer :width

    # Position (:left, :right, :center, or a number indicating distance in
    # points from the left edge) of the table within its parent bounds.
    #
    attr_writer :position

    # Returns a Prawn::Table::Cells object representing all of the cells in
    # this table.
    #
    attr_reader :cells

    attr_accessor :split_cells_in_final_row

    # Specify a callback to be called before each page of cells is rendered.
    # The block is passed a Cells object containing all cells to be rendered on
    # that page. You can change styling of the cells in this block, but keep in
    # mind that the cells have already been positioned and sized.
    #
    def before_rendering_page(&block)
      @before_rendering_page = block
    end

    # Returns the width of the table in PDF points.
    #
    def width
      @width ||= [natural_width, @pdf.bounds.width].min
    end

    # Sets column widths for the table. The argument can be one of the following
    # types:
    #
    # +Array+::
    #   <tt>[w0, w1, w2, ...]</tt> (specify a width for each column)
    # +Hash+::
    #   <tt>{0 => w0, 1 => w1, ...}</tt> (keys are column names, values are
    #   widths)
    # +Numeric+::
    #   +72+ (sets width for all columns)
    #
    def column_widths=(widths)
      case widths
      when Array
        widths.each_with_index { |w, i| column(i).width = w }
      when Hash
        widths.each { |i, w| column(i).width = w }
      when Numeric
        cells.width = widths
      else
        raise ArgumentError, "cannot interpret column widths"
      end
    end

    # Returns the height of the table in PDF points.
    #
    def height
      cells.height
    end

    # If +true+, designates the first row as a header row to be repeated on
    # every page. If an integer, designates the number of rows to be treated
    # as a header Does not change row numbering -- row numbers always index
    # into the data array provided, with no modification.
    #
    attr_writer :header

    # Accepts an Array of alternating row colors to stripe the table.
    #
    attr_writer :row_colors

    # Sets styles for all cells.
    #
    #   pdf.table(data, :cell_style => { :borders => [:left, :right] })
    #
    def cell_style=(style_hash)
      cells.style(style_hash)
    end

    # Allows generic stylable content. This is an alternate syntax that some
    # prefer to the attribute-based syntax. This code using style:
    #
    #   pdf.table(data) do
    #     style(row(0), :background_color => 'ff00ff')
    #     style(column(0)) { |c| c.border_width += 1 }
    #   end
    #
    # is equivalent to:
    #
    #   pdf.table(data) do
    #     row(0).style :background_color => 'ff00ff'
    #     column(0).style { |c| c.border_width += 1 }
    #   end
    #
    def style(stylable, style_hash={}, &block)
      stylable.style(style_hash, &block)
    end

    # Draws the table onto the document at the document's current y-position.
    #
    def draw
      with_position do
        # Reference bounds are the non-stretchy bounds used to decide when to
        # flow to a new column / page.
        ref_bounds = @pdf.reference_bounds

        # Determine whether we're at the top of the current bounds (margin box or
        # bounding box). If we're at the top, we couldn't gain any more room by
        # breaking to the next page -- this means, in particular, that if the
        # first row is taller than the margin box, we will only move to the next
        # page if we're below the top. Some floating-point tolerance is added to
        # the calculation.
        #
        # Note that we use the actual bounds, not the reference bounds. This is
        # because even if we are in a stretchy bounding box, flowing to the next
        # page will not buy us any space if we are at the top.
        #
        # initial_row_on_initial_page may return 0 (already at the top OR created
        # a new page) or -1 (enough space)
        started_new_page_at_row = initial_row_on_initial_page

        # The cell y-positions are based on an infinitely long canvas. The offset
        # keeps track of how much we have to add to the original, theoretical
        # y-position to get to the actual position on the current page.
        offset = @pdf.y

        # Duplicate each cell of the header row into @header_row so it can be
        # modified in before_rendering_page callbacks.
        @header_row = header_rows if @header

        # Track cells to be drawn on this page. They will all be drawn when this
        # page is finished.
        cells_this_page = []

        split_cells = []
        split_cells_new_page = []

        row_to_split = -1
        splitting = false
        original_height = 0

        @cells.each do |cell|
          # puts "#{cell.row}/#{cell.column} #{cell.class} - height:#{cell.height} - #{cell.content}"
          if only_plain_text_cells(cell.row)
            # puts "#### only plain text cell" 
          else
            # puts "#### other cells included" 
          end
          if defined?(@split_cells_in_final_row) && @split_cells_in_final_row
            # puts "split_cells_in_final_row"
          else
            # puts "no split_cells_in_final_row"
          end
          if defined?(@split_cells_in_final_row) && @split_cells_in_final_row && only_plain_text_cells(cell.row)
            max_available_height = (cell.y + offset) - ref_bounds.absolute_bottom

            # should the row be split?
            if start_new_page?(cell, offset, ref_bounds, true) && max_available_height > 0
              # puts "@@@@ split cell #{cell.row}/#{cell.column} - #{cell.content}"
              row_to_split = cell.row
              original_height = cell.height
              splitting = true
            end

            # split cell content and adjust height of cell
            cell = split_cell_content(cell, row_to_split, max_available_height)

            # reset row_to_split variable if we're in the next row
            if row_to_split > -1 && cell.row > row_to_split && !cell.is_a?(Prawn::Table::Cell::SpanDummy)
              row_to_split = -1
            end

            cell_height = cell.calculate_height_ignoring_span
            if cell_height > max_available_height && cell.row > started_new_page_at_row && !cell.is_a?(Prawn::Table::Cell::SpanDummy)
              # recalculate / resplit content for split_cells array
              # this may be necessary because a cell that spans multiple rows did not
              # know anything about needed height changes in subsequent rows when the text was split
              # e.g. original n+1 lines where able to be printed in the remaining space, however
              # a splitting of a later row resulted in a table that was smaller than the theoretical
              # maximum that was used in the original calculation (for example due to the padding)
              # thus the last line can't be printed because there is only space for n lines
              
              recalculated_split_cells = []
              first_row = split_cells.first.row
              last_row = split_cells.last.row
              # O(n^2) on the cells about to be split
              # maybe we can improve this at some point in the future
              split_cells.each do |split_cell|
                old_height = split_cell.height
                old_y = split_cell.y
                split_cell.height = 0
                max_available_height = rows(first_row..last_row).height

                split_cell_content(split_cell, split_cell.row, max_available_height)
                
                split_cell.y_offset_new_page = (old_height - split_cell.height) if !split_cell.is_a?(Prawn::Table::Cell::SpanDummy)
                if !split_cell.is_a?(Prawn::Table::Cell::SpanDummy) && split_cell.y_offset_new_page > 0
                  # split_cell.y_offset_new_page = 0
                  # puts "cell #{split_cell.row}/#{split_cell.column} - old_height=#{old_height} split_cell.height=#{split_cell.height} y_offset_new_page = #{split_cell.y_offset_new_page}" if !split_cell.is_a?(Prawn::Table::Cell::SpanDummy) && split_cell.y_offset_new_page != 0
                  # puts "cell #{split_cell.row}/#{split_cell.column} - y:#{split_cell.y} - old_y:#{old_y}" if split_cell.y != old_y
                end
              end
              # puts "##### @@@@@ (1)"
              # draw cells on the current page and then start a new one
              # this will also add a header to the new page if a header is set
              # reset array of cells for the new page
              cells_this_page, offset = ink_and_draw_cells_and_start_new_page(cells_this_page, cell, split_cells, offset)

              # any remaining cells to be split will have been split by the ink_and_draw_cells_and_start_new_page command
              split_cells_new_page = calculate_split_cells_new_page(split_cells, cell.row)
              split_cells = []
              splitting=false
              
              # draw split cells on to the new page
              split_cell_height = print_split_cells(split_cells_new_page, cells_this_page, offset - original_height, new_page: true, current_row: cell.row)
              offset -= split_cell_height

              # remember the current row for background coloring
              started_new_page_at_row = cell.row
            end
          elsif start_new_page?(cell, offset, ref_bounds) 
            # puts "##### (2)"
            # draw cells on the current page and then start a new one
            # this will also add a header to the new page if a header is set
            # reset array of cells for the new page
            # puts "@@@@ (2)"
            #puts "#{cells_this_page}"
            cells_this_page, offset = ink_and_draw_cells_and_start_new_page(cells_this_page, cell)

            # remember the current row for background coloring
            started_new_page_at_row = cell.row
          end

          # Set background color, if any.
          cell = set_background_color(cell, started_new_page_at_row)


          
          if splitting
            # remember this cell
            split_cells.push cell
          else
            # add the current cell to the cells array for the current page
            # puts "@@@@@ adding cell #{cell.row}/#{cell.column} height #{cell.height}"
            cells_this_page << [cell, [cell.relative_x, cell.relative_y(offset)]]
          end

        end

        print_split_cells(split_cells, cells_this_page, offset)

        if splitting
          # draw cells on the current page and then start a new one
          # this will also add a header to the new page if a header is set
          # reset array of cells for the new page
          # puts "##### @@@@@ (3)"
          cells_this_page, offset = ink_and_draw_cells_and_start_new_page(cells_this_page, @cells.last)
          # draw split cells on to the new page
          split_cell_height = print_split_cells(split_cells, cells_this_page, offset, new_page: true, current_row: @cells.last.row)
        end

        # debug output
        # puts "##### @@@@@ (4)"
        # cells_this_page.each do |c_a|
        #   cell = c_a[0]
        #   puts "cell #{cell.row}/#{cell.column} height=#{cell.height}"
        # end
        # end debug output

        # ensure that each cell in each row is of equal height
        skip_header_rows = Hash.new(false)
        header_rows.each do |cell|
          skip_header_rows[cell.row] = true
        end

        cells_this_page.each do |cell, cell_array|
          next if cell.class == Prawn::Table::Cell::SpanDummy
          next if skip_header_rows[cell.row]
          old_height = cell.height
          cell.height = row(cell.row).height
          # puts "$$$ old_height=#{old_height} new_height=#{cell.height} content=#{cell.content}" if cell.height != old_height
        end
      
        # Draw the last page of cells
        ink_and_draw_cells(cells_this_page)

        @pdf.move_cursor_to(@cells.last.relative_y(offset) - @cells.last.height)
      end
    end

    # split the content of the cell
    def split_cell_content(cell, row_to_split, max_available_height)
      # the main work
      if row_to_split == cell.row && !cell.is_a?(Prawn::Table::Cell::SpanDummy)

        old_content = cell.content
        old_height = cell.height
        content_array = cell.content.split(' ')
        i = 0
        cell.content = content_array[0]
        height = cell.calculate_height_ignoring_span
        content_that_fits = ''
        while height <= max_available_height
          # content from last round
          content_that_fits = cell.content
          if content_array[i].nil?
            break
          end
          i += 1
          cell.content = content_array[0..i].join(' ')
          height = cell.recalculate_height_ignoring_span
        end
        
        # did anything fit at all?
        if content_that_fits && content_that_fits.length > 0
          cell.content = content_that_fits
          cell.content_new_page = (cell.content_new_page  || '' ) + content_array[i..-1].join(' ')
        else
          cell.content = old_content
        end
        
        # recalcualte height for the cell in question
        cell.recalculate_height_ignoring_span
        # if a height was set for this cell, use it if the text didn't have to be split
        # cell.height = cell.original_height if cell.content == old_content && !cell.original_height.nil?
        # and its dummy cells
        cell.dummy_cells.each do |dummy_cell|
          dummy_cell.recalculate_height_ignoring_span
        end
      end
      cell
    end

    # are all cells in this row normal text cells without any fancy formatting we can't easily handle when splitting cells
    def only_plain_text_cells(row_number)
      row(row_number).each do |cell|
        return true if cell.is_a?(Prawn::Table::Cell::SpanDummy)
        unless cell.is_a?(Prawn::Table::Cell::Text)
          # puts "#### not a Prawn::Table::Cell::Text"
          return false 
        end
        if cell.rotate
          # puts "##### cell.rotate"
          return false
        end
        if cell.rotate_around
          # puts "##### cell.rotate_around"
          return false
        end
        if cell.leading
          # puts "##### cell.leading"
          return false
        end
        if cell.single_line
          # puts "##### cell.single_line"
          return false
        end
        # if cell.valign
        #   puts "##### cell.valign = #{cell.valign}"
        #   return false
        # end
        # if cell.overflow
        #   puts "##### cell.overflow"
        #   return false
        # end
      end
      return true
    end

    # calculate which cells should be shown on the new page
    # -> which shows wheren't fully rendered on the last one
    def calculate_split_cells_new_page(split_cells, row_number)
      last_row_number_last_page = row_number - 1
      
      # is there some content to display coming from the last row on the last page?
      found_some_content_in_the_last_row_on_the_last_page = false
      split_cells.each do |split_cell|
        next unless split_cell.row == last_row_number_last_page
        found_some_content_in_the_last_row_on_the_last_page = true unless split_cell.content_new_page.nil? || split_cell.content_new_page.empty?
      end

      split_cells_new_page = []
      split_cells.each do |split_cell|
        # don't print cells that don't span anything and that 
        # aren't located in the last row
        next if split_cell.row < last_row_number_last_page &&
                split_cell.dummy_cells.empty? && 
                !split_cell.is_a?(Prawn::Table::Cell::SpanDummy)
        
        # if they do span multiple cells, check if at least one of them
        # is located in the last row of the last page
        if !split_cell.dummy_cells.empty?
          found_a_cell_in_the_last_row_on_the_last_page = false
          split_cell.dummy_cells.each do |dummy_cell|
            found_a_cell_in_the_last_row_on_the_last_page = true if dummy_cell.row == last_row_number_last_page
          end
          next unless found_a_cell_in_the_last_row_on_the_last_page
        end

        # if there's nothing to display from the last row of the last page,
        # don't add that row to the new page
        # unless we're dealing with a dummy cell (we need them to draw appropriate lines)
        if split_cell.row == last_row_number_last_page && 
                !found_some_content_in_the_last_row_on_the_last_page &&
                split_cell.is_a?(Prawn::Table::Cell::SpanDummy)


          # puts "removing cell #{split_cell.row}/#{split_cell.column}"  
        end

        # all tests passed. print it - add it to the array
        split_cells_new_page.push split_cell
      end

      split_cells_new_page
    end

    def print_split_cells(split_cells, cells_this_page, offset, hash={})
      puts "########"
      if hash[:new_page]
        puts "page 2"
      else
        puts "page 1" 
      end
      puts "########"
      split_cells.each do |cell|
        puts "#{cell.row}/#{cell.column}"
      end
      # puts "@@@@ !!!!! print_split_cells #{split_cells.first.row unless split_cells.empty? }-#{split_cells.last.row unless split_cells.empty?}"
      compensate_offset_for_height = 0
      extra_height_for_row_dummies = 0

      max_cell_height = Hash.new(0)
      split_cells.each do |split_cell|

        # if we are on the new page, change the content of the cell
        split_cell.content = split_cell.content_new_page if hash[:new_page]
        split_cell.on_new_page = true if hash[:new_page]

        new_page_string = 'new page' if hash[:new_page]
        # puts "@@@@@ split_cell(1) #{split_cell.row}/#{split_cell.column} - height: #{split_cell.height} - #{split_cell.content} - #{split_cell.content_new_page} #{new_page_string}" 

        # calculate the height of the cell includign any cells it may span
        respect_original_height = true unless hash[:new_page]
        cell_height = split_cell.calculate_height_ignoring_span(respect_original_height)

        cell_height = split_cell.original_height if !split_cell.original_height.nil?

        # account for the height of any rows this cell spans (new page)
        rows = split_cell.dummy_cells.map { |dummy_cell| dummy_cell.row if dummy_cell.row_dummy? }.uniq.compact
        rows.each do |row_number|
          cell_height -= row(row_number).height
        end

        max_cell_height[split_cell.row] = cell_height if max_cell_height[split_cell.row] < cell_height unless split_cell.content.nil? || split_cell.content.empty? 
      end

      split_cells.each do |split_cell|
        debug_string = 'new page' if hash[:new_page]
        # puts "@@@@@ split_cell(2) #{split_cell.row}/#{split_cell.column} - height: #{split_cell.height} - content: #{split_cell.content} #{debug_string}"   if split_cell.row == 18 && hash[:new_page]
        # next if split_cell.row == 18 && hash[:new_page]
        # puts "max_cell_height=#{max_cell_height}"
        unless split_cell.is_a?(Prawn::Table::Cell::SpanDummy)
          # if multiple cells of multiple rows are split it may happen that the cell
          # holding the text (and which will be rendered) is from an earlier row than
          # the last row on the last page (and thus the first row on the new page)
          # in this case set the height of this cell to the first line of the new page
          # otherwise just take the newely calculated row height
          first_row_new_page = max_cell_height.keys.min || 0
          old_height = split_cell.height
          if split_cell.row < first_row_new_page
            split_cell.height = max_cell_height[first_row_new_page]
          else
            split_cell.height = max_cell_height[split_cell.row]
          end
          # puts "§§§ old_height=#{old_height} new_height=#{split_cell.height}" if split_cell.row == 8
          # puts "@@@ cell #{split_cell.row}/#{split_cell.column} - height: #{split_cell.height} original_height: #{split_cell.original_height} content: #{split_cell.content}" if hash[:new_page]
        end
        # puts "@@@@@ split_cell(3) #{split_cell.row}/#{split_cell.column} - height: #{split_cell.height} - content: #{split_cell.content}" 
        # rows of dummy cells (may be on old or new page, that's what we filter for)
        row_numbers = split_cell.filtered_dummy_cells(split_cells.last.row, hash[:new_page]).map { |dummy_cell| dummy_cell.row if dummy_cell.row_dummy? }.uniq.compact

        original_height = row_numbers.map { |row_number| row(row_number).height }.inject(:+)
        extra_height_for_row_dummies = row_numbers.map { |row_number| row(row_number).recalculate_height }.inject(:+)
        compensate_offset_for_height = (original_height - extra_height_for_row_dummies) if extra_height_for_row_dummies && extra_height_for_row_dummies > 0
# puts "$$ row_numbers=#{row_numbers} extra_height_for_row_dummies=#{extra_height_for_row_dummies} original_height=#{original_height} - old_height=#{split_cell.height}"
        # the cell needs to be laid over the dummy cells, that's why we have to increase its height
        split_cell.height += extra_height_for_row_dummies || 0
        
        # compensate y if necessary
        # split_cell.y += (split_cell.y_offset_new_page || 0) if hash[:new_page] && old_height == split_cell.height && !split_cell.is_a?(Prawn::Table::Cell::SpanDummy)
        # split_cell.y += (split_cell.y_offset_new_page || 0) if hash[:new_page] && !split_cell.is_a?(Prawn::Table::Cell::SpanDummy)

        # ensure that the cells are positioned correctly 
        row_numbers.each do |row_number|
          row(row_number).reduce_y(compensate_offset_for_height)
        end

        # debug
        unless old_height == split_cell.height
          # puts "height changed for cell #{split_cell.row}/#{split_cell.column} - old_height:#{old_height} new_height:#{split_cell.height}"
        end

        #
        # add the split_cell to the cells_this_page array
        #

        # special treatment for a very special case
        if hash[:new_page] && 
           !split_cell.is_a?(Prawn::Table::Cell::SpanDummy) &&
           !split_cell.dummy_cells.empty? && 
           split_cell.row < split_cells.last.row
           # puts "&&&&&& special case #{split_cell.row}/#{split_cell.column} content:#{split_cell.content}"
           # puts "&&&&&& rows #{(split_cell.row+1)} to #{split_cells.last.row}"

          # add it to the cells_this_page array and adjust the position accordingly
          # we need to take into account any rows that have already been printed
          height_of_additional_already_printed_rows = rows((split_cell.row+1)..(split_cells.last.row)).height
          
          # puts "split_cell.row+1=#{split_cell.row+1} split_cells.last.row=#{split_cells.last.row}"
          # puts "row(27).height=#{row(27).height}"
          # puts "row(28).height=#{row(28).height}"
          # puts "row(29).height=#{row(29).height}"
          # puts "&&&&&& height_of_additional_already_printed_rows=#{height_of_additional_already_printed_rows}"
          # foo= split_cell.y_offset_new_page
          foo = 0
          # puts "foo #{split_cell.row}/#{split_cell.column}=#{foo}"
          # puts "##### #{split_cell.row}/#{split_cell.column} height_of_additional_already_printed_rows=#{height_of_additional_already_printed_rows} height=#{split_cell.height} check_sum=#{split_cell.height - height_of_additional_already_printed_rows}"
          cells_this_page << [split_cell, [split_cell.relative_x, split_cell.relative_y(offset - height_of_additional_already_printed_rows + foo)]]

          # move the rest of the row of the canvas
          row(split_cell.row).reduce_y(-2000)

        # standard treatment
        else
          # puts "split_cell.height = #{split_cell.height}"
          cells_this_page << [split_cell, [split_cell.relative_x, split_cell.relative_y(offset)]] #unless split_cell.content.nil? || split_cell.content.empty?
          #next unless split_cell.row == 28 || split_cell.row == 29
          # puts "$$$$ split_cell #{split_cell.row}/#{split_cell.column}: relative_x=#{split_cell.relative_x} relative_y=#{split_cell.relative_y(offset)} #{split_cell.content} height=#{split_cell.height}"
        end
        # puts "final height for cell #{split_cell.row}/#{split_cell.column}: #{split_cell.height}"
      end


      #FIXXME find out what this return value is used for
      #FIXXME it used to be max_cell_height over all cells, not only a single row
      #FIXXME neither the new, nor the old solution can possibly be correct

      return (max_cell_height.values.max || 0) - (compensate_offset_for_height || 0)
    end

    # Calculate and return the constrained column widths, taking into account
    # each cell's min_width, max_width, and any user-specified constraints on
    # the table or column size.
    #
    # Because the natural widths can be silly, this does not always work so well
    # at guessing a good size for columns that have vastly different content. If
    # you see weird problems like CannotFit errors or shockingly bad column
    # sizes, you should specify more column widths manually.
    #
    def column_widths
      @column_widths ||= begin
        if width - cells.min_width < -Prawn::FLOAT_PRECISION
          raise Errors::CannotFit,
            "Table's width was set too small to contain its contents " +
            "(min width #{cells.min_width}, requested #{width})"
        end

        if width - cells.max_width > Prawn::FLOAT_PRECISION
          raise Errors::CannotFit,
            "Table's width was set larger than its contents' maximum width " +
            "(max width #{cells.max_width}, requested #{width})"
        end

        if width - natural_width < -Prawn::FLOAT_PRECISION
          # Shrink the table to fit the requested width.
          f = (width - cells.min_width).to_f / (natural_width - cells.min_width)

          (0...column_length).map do |c|
            min, nat = column(c).min_width, natural_column_widths[c]
            (f * (nat - min)) + min
          end
        elsif width - natural_width > Prawn::FLOAT_PRECISION
          # Expand the table to fit the requested width.
          f = (width - cells.width).to_f / (cells.max_width - cells.width)

          (0...column_length).map do |c|
            nat, max = natural_column_widths[c], column(c).max_width
            (f * (max - nat)) + nat
          end
        else
          natural_column_widths
        end
      end
    end

    # Returns an array with the height of each row.
    #
    def row_heights
      @natural_row_heights ||=
        begin
          heights_by_row = Hash.new(0)
          cells.each do |cell|
            next if cell.is_a?(Cell::SpanDummy)

            # Split the height of row-spanned cells evenly by rows
            height_per_row = cell.height.to_f / cell.rowspan
            cell.rowspan.times do |i|
              heights_by_row[cell.row + i] =
                [heights_by_row[cell.row + i], height_per_row].max
            end
          end
          heights_by_row.sort_by { |row, _| row }.map { |_, h| h }
        end
    end

    protected
    
    # sets the background color (if necessary) for the given cell
    def set_background_color(cell, started_new_page_at_row)
      if defined?(@row_colors) && @row_colors && (!@header || cell.row > 0)
        # Ensure coloring restarts on every page (to make sure the header
        # and first row of a page are not colored the same way).
        rows = number_of_header_rows

        index = cell.row - [started_new_page_at_row, rows].max

        cell.background_color ||= @row_colors[index % @row_colors.length]
      end
      cell
    end

    # number of rows of the header
    # @return [Integer] the number of rows of the header
    def number_of_header_rows
      # header may be set to any integer value -> number of rows
      if @header.is_a? Integer
        return @header
      # header may be set to true -> first row is repeated
      elsif @header
        return 1
      end
      # defaults to 0 header rows
      0
    end

    # should we start a new page? (does the current row fail to fit on this page)
    def start_new_page?(cell, offset, ref_bounds, allow_first_row=false)
      # we need to run it on every column to ensure it won't break on rowspans
      # check if the rows height fails to fit on the page
      # check if the row is not the first on that page (wouldn't make sense to go to next page in this case)
      ((cell.row > 0 || allow_first_row) &&
       !row(cell.row).fits_on_current_page?(offset, ref_bounds))
    end

    # ink cells and then draw them
    def ink_and_draw_cells(cells_this_page, draw_cells = true)
      #debug output only
      new_cells_this_page = Array.new
      cells_this_page.each do |cell_array|
        cell=cell_array[0]
        # puts "cell #{cell.row}/#{cell.column} - height: #{cell.height} - #{cell.content}"
        # cell_array[0].content = cell.height.to_s unless cell.content.nil? or cell.content.length < 1
        new_cells_this_page.push cell_array
      end
      cells_this_page = new_cells_this_page
      # end debug output

      ink_cells(cells_this_page)
      Cell.draw_cells(cells_this_page) if draw_cells
    end

    # ink and draw cells, then start a new page
    def ink_and_draw_cells_and_start_new_page(cells_this_page, cell, split_cells=false, offset=false)
      # don't draw only a header
      draw_cells = (@header_row.nil? || cells_this_page.size > @header_row.size)
      
      # print any remaining cells to be split
      print_split_cells(split_cells, cells_this_page, offset) if offset
      
      ink_and_draw_cells(cells_this_page, draw_cells)

      # puts '###### starting a new page (1)'
      # start a new page or column
      @pdf.bounds.move_past_bottom

      offset = (@pdf.y - cell.y)

      cells_next_page = []

      header_height = add_header(cell.row, cells_next_page)
      # puts "adding header_height=#{header_height}"

      # account for header height in newly generated offset
      offset -= header_height

      # reset cells_this_page in calling function and return new offset
      return cells_next_page, offset
    end

    # Ink all cells on the current page
    def ink_cells(cells_this_page)
      if defined?(@before_rendering_page) && @before_rendering_page
        c = Cells.new(cells_this_page.map { |ci, _| ci })
        @before_rendering_page.call(c)
      end
    end

    # Determine whether we're at the top of the current bounds (margin box or
    # bounding box). If we're at the top, we couldn't gain any more room by
    # breaking to the next page -- this means, in particular, that if the
    # first row is taller than the margin box, we will only move to the next
    # page if we're below the top. Some floating-point tolerance is added to
    # the calculation.
    #
    # Note that we use the actual bounds, not the reference bounds. This is
    # because even if we are in a stretchy bounding box, flowing to the next
    # page will not buy us any space if we are at the top.
    # @return [Integer] 0 (already at the top OR created a new page) or -1 (enough space)
    def initial_row_on_initial_page
      # we're at the top of our bounds
      return 0 if fits_on_page?(@pdf.bounds.height)

      needed_height = row(0..number_of_header_rows).height

      # have we got enough room to fit the first row (including header row(s))
      use_reference_bounds = true
      return -1 if fits_on_page?(needed_height, use_reference_bounds)

      # If there isn't enough room left on the page to fit the first data row
      # (including the header), start the table on the next page.
      @pdf.bounds.move_past_bottom

      # we are at the top of a new page
      0
    end

    # do we have enough room to fit a given height on to the current page?
    def fits_on_page?(needed_height, use_reference_bounds = false)
      if use_reference_bounds
        bounds = @pdf.reference_bounds
      else
        bounds = @pdf.bounds
      end
      needed_height < @pdf.y - (bounds.absolute_bottom - Prawn::FLOAT_PRECISION)
    end

    # return the header rows
    # @api private
    def header_rows
      header_rows = Cells.new
      number_of_header_rows.times do |r|
        row(r).each { |cell| header_rows[cell.row, cell.column] = cell.dup }
      end
      header_rows
    end

    # Converts the array of cellable objects given into instances of
    # Prawn::Table::Cell, and sets up their in-table properties so that they
    # know their own position in the table.
    #
    def make_cells(data)
      assert_proper_table_data(data)

      cells = Cells.new

      row_number = 0
      data.each do |row_cells|
        column_number = 0
        row_cells.each do |cell_data|
          # If we landed on a spanned cell (from a rowspan above), continue
          # until we find an empty spot.
          column_number += 1 until cells[row_number, column_number].nil?

          # Build the cell and store it in the Cells collection.
          cell = Cell.make(@pdf, cell_data)
          cells[row_number, column_number] = cell

          # Add dummy cells for the rest of the cells in the span group. This
          # allows Prawn to keep track of the horizontal and vertical space
          # occupied in each column and row spanned by this cell, while still
          # leaving the master (top left) cell in the group responsible for
          # drawing. Dummy cells do not put ink on the page.
          cell.rowspan.times do |i|
            cell.colspan.times do |j|
              next if i == 0 && j == 0

              # It is an error to specify spans that overlap; catch this here
              if cells[row_number + i, column_number + j]
                raise Prawn::Errors::InvalidTableSpan,
                  "Spans overlap at row #{row_number + i}, " +
                  "column #{column_number + j}."
              end

              dummy = Cell::SpanDummy.new(@pdf, cell)
              cells[row_number + i, column_number + j] = dummy
              cell.dummy_cells << dummy
            end
          end

          column_number += cell.colspan
        end

        row_number += 1
      end

      # Calculate the number of rows and columns in the table, taking into
      # account that some cells may span past the end of the physical cells we
      # have.
      @row_length = cells.map do |cell|
        cell.row + cell.rowspan
      end.max

      @column_length = cells.map do |cell|
        cell.column + cell.colspan
      end.max

      cells
    end

    def add_header(row_number, cells_this_page)
      x_offset = @pdf.bounds.left_side - @pdf.bounds.absolute_left
      header_height = 0
      if row_number > 0 && @header
        y_coord = @pdf.cursor
        number_of_header_rows.times do |h|
          additional_header_height = add_one_header_row(cells_this_page, x_offset, y_coord-header_height, row_number-1, h)
          header_height += additional_header_height
        end        
      end
      header_height
    end

    # Add the header row(s) to the given array of cells at the given y-position.
    # Number the row with the given +row+ index, so that the header appears (in
    # any Cells built for this page) immediately prior to the first data row on
    # this page.
    #
    # Return the height of the header.
    #
    def add_one_header_row(page_of_cells, x_offset, y, row, row_of_header=nil)
      rows_to_operate_on = @header_row
      rows_to_operate_on = @header_row.rows(row_of_header) if row_of_header
      rows_to_operate_on.each do |cell|
        cell.row = row
        cell.dummy_cells.each {|c| 
          if cell.rowspan > 1
            # be sure to account for cells that span multiple rows
            # in this case you need multiple row numbers
            c.row += row
          else
            c.row = row
          end
        }
        page_of_cells << [cell, [cell.x + x_offset, y]]
      end
      rows_to_operate_on.height
    end

    # Raises an error if the data provided cannot be converted into a valid
    # table.
    #
    def assert_proper_table_data(data)
        if data.nil? || data.empty?
          raise Prawn::Errors::EmptyTable,
          "data must be a non-empty, non-nil, two dimensional array " +
          "of cell-convertible objects"
      end

      unless data.all? { |e| Array === e }
        raise Prawn::Errors::InvalidTableData,
          "data must be a two dimensional array of cellable objects"
      end
    end

    # Returns an array of each column's natural (unconstrained) width.
    #
    def natural_column_widths
      @natural_column_widths ||= ColumnWidthCalculator.new(cells).natural_widths
    end

    # Returns the "natural" (unconstrained) width of the table. This may be
    # extremely silly; for example, the unconstrained width of a paragraph of
    # text is the width it would assume if it were not wrapped at all. Could be
    # a mile long.
    #
    def natural_width
      @natural_width ||= natural_column_widths.inject(0, &:+)
    end

    # Assigns the calculated column widths to each cell. This ensures that each
    # cell in a column is the same width. After this method is called,
    # subsequent calls to column_widths and width should return the finalized
    # values that will be used to ink the table.
    #
    def set_column_widths
      column_widths.each_with_index do |w, col_num|
        column(col_num).width = w
      end
    end

    # Assigns the row heights to each cell. This ensures that every cell in a
    # row is the same height.
    #
    def set_row_heights
      row_heights.each_with_index { |h, row_num| row(row_num).height = h }
    end

    # Set each cell's position based on the widths and heights of cells
    # preceding it.
    #
    def position_cells
      # Calculate x- and y-positions as running sums of widths / heights.
      x_positions = column_widths.inject([0]) { |ary, x|
        ary << (ary.last + x); ary }[0..-2]
      x_positions.each_with_index { |x, i| column(i).x = x }

      # y-positions assume an infinitely long canvas starting at zero -- this
      # is corrected for in Table#draw, and page breaks are properly inserted.
      y_positions = row_heights.inject([0]) { |ary, y|
        ary << (ary.last - y); ary}[0..-2]
      y_positions.each_with_index { |y, i| row(i).y = y }
    end

    # Sets up a bounding box to position the table according to the specified
    # :position option, and yields.
    #
    def with_position
      x = case defined?(@position) && @position || :left
          when :left   then return yield
          when :center then (@pdf.bounds.width - width) / 2.0
          when :right  then  @pdf.bounds.width - width
          when Numeric then  @position
          else raise ArgumentError, "unknown position #{@position.inspect}"
          end
      dy = @pdf.bounds.absolute_top - @pdf.y
      final_y = nil

      @pdf.bounding_box([x, @pdf.bounds.top], :width => width) do
        @pdf.move_down dy
        yield
        final_y = @pdf.y
      end

      @pdf.y = final_y
    end

  end
end

Prawn::Document.extensions << Prawn::Table::Interface
