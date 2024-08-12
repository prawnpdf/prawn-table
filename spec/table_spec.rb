# encoding: utf-8

# run rspec -t issue:XYZ  to run tests for a specific github issue
# or  rspec -t unresolved to run tests for all unresolved issues


require File.join(File.expand_path(File.dirname(__FILE__)), "spec_helper")

require_relative "../lib/prawn/table"
require 'set'

describe "Prawn::Table" do

  describe "converting data to Cell objects" do
    before(:each) do
      @pdf = Prawn::Document.new
      @table = @pdf.table([%w[R0C0 R0C1], %w[R1C0 R1C1]])
    end

    it "should return a Prawn::Table" do
      expect(@table).to be_a_kind_of Prawn::Table
    end

    it "should flatten the data into the @cells array in row-major order" do
      expect(@table.cells.map { |c| c.content }).to eq %w[R0C0 R0C1 R1C0 R1C1]
    end

    it "should add row and column numbers to each cell" do
      c = @table.cells.to_a.first
      expect(c.row).to eq 0
      expect(c.column).to eq 0
    end

    it "should allow empty fields" do
      expect {
        data = [["foo","bar"],["baz",""]]
        @pdf.table(data)
      }.to_not raise_error
    end

    it "should allow a table with a header but no body" do
      expect { @pdf.table([["Header"]], :header => true) }.to_not raise_error
    end

    it "should accurately count columns from data" do
      # First data row may contain colspan which would hide true column count
      data = [["Name:", {:content => "Some very long name", :colspan => 5}]]
      pdf = Prawn::Document.new
      table = Prawn::Table.new data, pdf
      expect(table.column_widths.length).to eq 6
    end
  end

  describe "headers should allow for rowspan" do
    it "should remember rowspans accross multiple pages", :issue => 721 do
      pdf = Prawn::Document.new({:page_size => "A4", :page_layout => :portrait})
      rows = [ [{:content=>"The\nNumber", :rowspan=>2}, {:content=>"Prefixed", :colspan=>2} ],
           ["A's", "B's"] ]

      (1..50).each do |n|
        rows.push( ["#{n}", "A#{n}", "B#{n}"] )
      end

      pdf.table( rows, :header=>2 ) do
         row(0..1).style :background_color=>"FFFFCC"
      end

      #ensure that the header on page 1 is identical to the header on page 0
      output = PDF::Inspector::Page.analyze(pdf.render)
      expect(output.pages[0][:strings][0..4]).to eq output.pages[1][:strings][0..4]
    end

    it "should respect an explicit set table with", :issue => 6 do
      data = [[{ :content => "Current Supplier: BLINKY LIGHTS COMPANY", :colspan => 4 }],
        ["Current Supplier: BLINKY LIGHTS COMPANY", "611 kWh X $.090041", "$", "55.02"]]
      pdf = Prawn::Document.new
      table = Prawn::Table.new data, pdf, :width => pdf.bounds.width
      expect(table.column_widths.inject{|sum,x| sum + x }).to eq pdf.bounds.width
    end
  end

  describe "Text may be longer than the available space in a row on a single page" do
    it "should not glitch the layout if there is too much text to fit onto a single row on a single page", :unresolved, :issue => 562 do
      pdf = Prawn::Document.new({:page_size => "A4", :page_layout => :portrait})

      table_data = Array.new
      text = 'This will be a very long text. ' * 5
      table_data.push([{:content => text, :rowspan => 2}, 'b', 'c'])
      table_data.push(['b','c'])

      column_widths = [50, 60, 400]

      table = Prawn::Table.new table_data, pdf,:column_widths => column_widths

      #render the table onto the pdf
      table.draw

      #expected behavior would be for the long text to be cut off or an exception to be raised
      #thus we only expect a single page
      expect(pdf.page_count).to eq 1
    end
  end

  describe "You can explicitly set the column widths and use a colspan > 1" do

    it "should tolerate floating point rounding errors < 0.000000001" do
      data=[["a", "b ", "c ", "d", "e", "f", "g", "h", "i", "j", "k", "l"],
            [{:content=>"Foobar", :colspan=>12}]
          ]
      #we need values with lots of decimals so that arithmetic errors will occur
      #the values are not arbitrary but where found converting mm to pdf pt
      column_widths=[137, 40, 40, 54.69291338582678, 54.69291338582678,
                     54.69291338582678, 54.69291338582678, 54.69291338582678,
                     54.69291338582678, 54.69291338582678, 54.69291338582678,
                     54.69291338582678]

      pdf = Prawn::Document.new({:page_size => 'A4', :page_layout => :landscape})
      table = Prawn::Table.new data, pdf, :column_widths => column_widths
      expect(table.column_widths).to eq column_widths
    end

    it "should work with two different given colspans", :issue => 628 do
      data = [
              [" ", " ", " "],
              [{:content=>" ", :colspan=>3}],
              [" ", {:content=>" ", :colspan=>2}]
            ]
      column_widths = [60, 240, 60]
      pdf = Prawn::Document.new
      #the next line raised an Prawn::Errors::CannotFit exception before issue 628 was fixed
      table = Prawn::Table.new data, pdf, :column_widths => column_widths
      expect(table.column_widths).to eq column_widths
    end

    it "should work with a colspan > 1 with given column_widths (issue #407)" do
      #normal entries in line 1
      data = [
        [ '','',''],
        [ { :content => "", :colspan => 3 } ],
        [ "", "", "" ],
      ]
      pdf = Prawn::Document.new
      table = Prawn::Table.new data, pdf, :column_widths => [100 , 200, 240]

      #colspan entry in line 1
      data = [
        [ { :content => "", :colspan => 3 } ],
        [ "", "", "" ],
      ]
      pdf = Prawn::Document.new
      table = Prawn::Table.new data, pdf, :column_widths => [100 , 200, 240]

      #mixed entries in line 1
      data = [
        [ { :content => "", :colspan =>2 }, "" ],
        [ "", "", "" ],
      ]
      pdf = Prawn::Document.new
      table = Prawn::Table.new data, pdf, :column_widths => [100 , 200, 240]

      data = [['', '', {:content => '', :colspan => 2}, '',''],
              ['',{:content => '', :colspan => 5}]
              ]
      pdf = Prawn::Document.new
      table = Prawn::Table.new data, pdf, :column_widths => [50 , 100, 50, 50, 50, 50]

    end

    it "should not increase column width when rendering a subtable",
       :unresolved, :issue => 612 do

      pdf = Prawn::Document.new

      first = {:content=>"Foooo fo foooooo",:width=>50,:align=>:center}
      second = {:content=>"Foooo",:colspan=>2,:width=>70,:align=>:center}
      third = {:content=>"fooooooooooo, fooooooooooooo, fooo, foooooo fooooo",:width=>50,:align=>:center}
      fourth = {:content=>"Bar",:width=>20,:align=>:center}

      table_content = [[
      first,
      [[second],[third,fourth]]
      ]]

      table = Prawn::Table.new table_content, pdf
      expect(table.column_widths).to eq [50.0, 70.0]
    end

    it "illustrates issue #710", :issue => 710 do
      partial_width = 40
      pdf = Prawn::Document.new({page_size: "LETTER", page_layout: :portrait})
      col_widths = [
        50,
        partial_width, partial_width, partial_width, partial_width
      ]

      day_header = [{
          content: "Monday, August 5th, A.S. XLIX",
          colspan: 5,
      }]

      times = [{
        content: "Loc",
        colspan: 1,
      }, {
        content: "8:00",
        colspan: 4,
      }]

      data = [ day_header ] + [ times ]

      #raised a Prawn::Errors::CannotFit:
      #Table's width was set larger than its contents' maximum width (max width 210, requested 218.0)
      table = Prawn::Table.new data, pdf, :column_widths => col_widths
    end

    it "illustrate issue #533" do
      data = [['', '', '', '', '',''],
              ['',{:content => '', :colspan => 5}]]
      pdf = Prawn::Document.new
      table = Prawn::Table.new data, pdf, :column_widths => [50, 200, 40, 40, 50, 50]
    end

    it "illustrates issue #502" do
      pdf = Prawn::Document.new
      first = {:content=>"Foooo fo foooooo",:width=>50,:align=>:center}
      second = {:content=>"Foooo",:colspan=>2,:width=>70,:align=>:center}
      third = {:content=>"fooooooooooo, fooooooooooooo, fooo, foooooo fooooo",:width=>50,:align=>:center}
      fourth = {:content=>"Bar",:width=>20,:align=>:center}
      table_content = [[
      first,
      [[second],[third,fourth]]
      ]]
      pdf.move_down(20)
      table = Prawn::Table.new table_content, pdf
      pdf.table(table_content)
    end

    #https://github.com/prawnpdf/prawn/issues/407#issuecomment-28556698
    it "correctly computes column widths with empty cells + colspan" do
      data = [['', ''],
              [{:content => '', :colspan => 2}]
              ]
      pdf = Prawn::Document.new

      table = Prawn::Table.new data, pdf, :column_widths => [50, 200]
      expect(table.column_widths).to eq [50.0, 200.0]
    end

    it "illustrates a variant of problem in issue #407 - comment 28556698" do
      pdf = Prawn::Document.new
      table_data = [["a", "b", "c"], [{:content=>"d", :colspan=>3}]]
      column_widths = [50, 60, 400]

      # Before we fixed #407, this line incorrectly raise a CannotFit error
      pdf.table(table_data, :column_widths => column_widths)
    end

    it "should not allow oversized subtables when parent column width is constrained" do
      pdf = Prawn::Document.new
      child_1 = pdf.make_table([['foo'*100]])
      child_2 = pdf.make_table([['foo']])
      expect {
        pdf.table([[child_1], [child_2]], column_widths: [pdf.bounds.width/2] * 2)
      }.to raise_error(Prawn::Errors::CannotFit)
    end
  end

  describe "#initialize" do
    before(:each) do
      @pdf = Prawn::Document.new
    end

    it "should instance_eval a 0-arg block" do
      initializer = double
      expect(initializer).to receive(:kick).once

      @pdf.table([["a"]]) do
        initializer.kick
      end
    end

    it "should call a 1-arg block with the document as the argument" do
      initializer = double
      expect(initializer).to receive(:kick).once

      @pdf.table([["a"]]) do |doc|
        expect(doc).to be_a_kind_of(Prawn::Table)
        initializer.kick
      end
    end

    it "should proxy cell methods to #cells" do
      table = @pdf.table([["a"]], :cell_style => { :padding => 11 })
      expect(table.cells[0, 0].padding).to eq [11, 11, 11, 11]
    end

    it "should set row and column length" do
      table = @pdf.table([["a", "b", "c"], ["d", "e", "f"]])
      expect(table.row_length).to eq 2
      expect(table.column_length).to eq 3
    end

    it "should generate a text cell based on a String" do
      t = @pdf.table([["foo"]])
      expect(t.cells[0,0]).to be_a_kind_of(Prawn::Table::Cell::Text)
    end

    it "should pass through a text cell" do
      c = Prawn::Table::Cell::Text.new(@pdf, [0,0], :content => "foo")
      t = @pdf.table([[c]])
      expect(t.cells[0,0]).to eq c
    end
  end

  describe "cell accessors" do
    before(:each) do
      @pdf = Prawn::Document.new
      @table = @pdf.table([%w[R0C0 R0C1], %w[R1C0 R1C1]])
    end

    it "should select rows by number or range" do
      expect(@table.row(0).map(&:content)).to match_array %w[R0C0 R0C1]
      expect(@table.rows(0..1).map(&:content)).to match_array %w[R0C0 R0C1 R1C0 R1C1]
    end

    it "should select rows by array" do
      expect(@table.rows([0, 1]).map(&:content)).to match_array %w[R0C0 R0C1 R1C0 R1C1]
    end

    it "should allow negative row selectors" do
      expect(@table.row(-1).map(&:content)).to match_array %w[R1C0 R1C1]
      expect(@table.rows(-2..-1).map(&:content)).to match_array %w[R0C0 R0C1 R1C0 R1C1]
      expect(@table.rows(0..-1).map(&:content)).to match_array %w[R0C0 R0C1 R1C0 R1C1]
    end

    it "should select columns by number or range" do
      expect(@table.column(0).map(&:content)).to match_array %w[R0C0 R1C0]
      expect(@table.columns(0..1).map(&:content)).to match_array %w[R0C0 R0C1 R1C0 R1C1]
    end

    it "should select columns by array" do
      expect(@table.columns([0, 1]).map(&:content)).to match_array %w[R0C0 R0C1 R1C0 R1C1]
    end

    it "should allow negative column selectors" do
      expect(@table.column(-1).map(&:content)).to match_array %w[R0C1 R1C1]
      expect(@table.columns(-2..-1).map(&:content)).to match_array %w[R0C0 R0C1 R1C0 R1C1]
      expect(@table.columns(0..-1).map(&:content)).to match_array %w[R0C0 R0C1 R1C0 R1C1]
    end

    it "should allow rows and columns to be combined" do
      expect(@table.row(0).column(1).map { |c| c.content }).to eq ["R0C1"]
    end

    it "should accept a filter block, returning a cell proxy" do
      expect(@table.cells.filter { |c| c.content =~ /R0/ }.column(1).map{ |c|
        c.content }).to eq ["R0C1"]
    end

    it "should accept the [] method, returning a Cell or nil" do
      expect(@table.cells[0, 0].content).to eq "R0C0"
      expect(@table.cells[12, 12]).to be_nil
    end

    it "should proxy unknown methods to the cells" do
      @table.cells.height = 200
      @table.row(1).height = 100

      expect(@table.cells[0, 0].height).to eq 200
      expect(@table.cells[1, 0].height).to eq 100
    end

    it "should ignore non-setter methods" do
      expect {
        @table.cells.content_width
      }.to raise_error(NoMethodError)
    end

    it "skips cells that don't respond to the given method" do
      table = @pdf.make_table([[{:content => "R0", :colspan => 2}],
                               %w[R1C0 R1C1]])
      expect {
        table.row(0).font_style = :bold
      }.to_not raise_error
    end

    it "should accept the style method, proxying its calls to the cells" do
      @table.cells.style(:height => 200, :width => 200)
      @table.column(0).style(:width => 100)

      expect(@table.cells[0, 1].width).to eq 200
      expect(@table.cells[1, 0].height).to eq 200
      expect(@table.cells[1, 0].width).to eq 100
    end

    it "style method should accept a block, passing each cell to be styled" do
      @table.cells.style { |c| c.height = 200 }
      expect(@table.cells[0, 1].height).to eq 200
    end

    it "should return the width of selected columns for #width" do
      c0_width = @table.column(0).map{ |c| c.width }.max
      c1_width = @table.column(1).map{ |c| c.width }.max

      expect(@table.column(0).width).to eq c0_width
      expect(@table.column(1).width).to eq c1_width

      expect(@table.columns(0..1).width).to eq c0_width + c1_width
      expect(@table.cells.width).to eq c0_width + c1_width
    end

    it "should return the height of selected rows for #height" do
      r0_height = @table.row(0).map{ |c| c.height }.max
      r1_height = @table.row(1).map{ |c| c.height }.max

      expect(@table.row(0).height).to eq r0_height
      expect(@table.row(1).height).to eq r1_height

      expect(@table.rows(0..1).height).to eq r0_height + r1_height
      expect(@table.cells.height).to eq r0_height + r1_height
    end
  end

  describe "layout" do
    before(:each) do
      @pdf = Prawn::Document.new
      @long_text = "The quick brown fox jumped over the lazy dogs. " * 5
    end

    describe "width" do
      it "should raise_error an error if the given width is outside of range" do
        expect {
          @pdf.table([["foo"]], :width => 1)
        }.to raise_error(Prawn::Errors::CannotFit)

        expect {
          @pdf.table([[@long_text]], :width => @pdf.bounds.width + 100)
        }.to raise_error(Prawn::Errors::CannotFit)
      end

      it "should accept the natural width for small tables" do
        pad = 10 # default padding
        @table = @pdf.table([["a"]])
        expect(@table.width).to eq @table.cells[0, 0].natural_content_width + pad
      end

      it "width should == sum(column_widths)" do
        table = Prawn::Table.new([%w[ a b c ], %w[d e f]], @pdf) do
          column(0).width = 50
          column(1).width = 100
          column(2).width = 150
        end
        expect(table.width).to eq 300
      end

      it "should accept Numeric for column_widths" do
        table = Prawn::Table.new([%w[ a b c ], %w[d e f]], @pdf) do |t|
          t.column_widths = 50
        end
        expect(table.width).to eq 150
      end

      it "should calculate unspecified column widths as "+
         "(max(string_width) + 2*horizontal_padding)" do
        hpad, fs = 3, 12
        columns = 2
        table = Prawn::Table.new( [%w[ foo b ], %w[d foobar]], @pdf,
          :cell_style => { :padding => hpad, :size => fs } )

        col0_width = @pdf.width_of("foo", :size => fs)
        col1_width = @pdf.width_of("foobar", :size => fs)

        expect(table.width).to eq col0_width + col1_width + 2*columns*hpad
      end

      it "should allow mixing autocalculated and preset"+
         "column widths within a single table" do
        hpad, fs = 10, 6
        stretchy_columns = 2

        col0_width = 50
        col1_width = @pdf.width_of("foo", :size => fs)
        col2_width = @pdf.width_of("foobar", :size => fs)
        col3_width = 150

        table = Prawn::Table.new( [%w[snake foo b apple],
                                   %w[kitten d foobar banana]], @pdf,
          :cell_style => { :padding => hpad, :size => fs }) do

          column(0).width = col0_width
          column(3).width = col3_width
        end

        expect(table.width).to eq col1_width + col2_width +
                              2*stretchy_columns*hpad +
                              col0_width + col3_width
      end

      it "should preserve all manually requested column widths" do
        col0_width = 50
        col1_width = 20
        col3_width = 60

        table = Prawn::Table.new( [["snake", "foo", "b",
                                      "some long, long text that will wrap"],
                                   %w[kitten d foobar banana]], @pdf,
                                 :width => 150) do

          column(0).width = col0_width
          column(1).width = col1_width
          column(3).width = col3_width
        end

        table.draw

        expect(table.column(0).width).to eq col0_width
        expect(table.column(1).width).to eq col1_width
        expect(table.column(3).width).to eq col3_width
      end

      it "should_not exceed the maximum width of the margin_box" do
        expected_width = @pdf.margin_box.width
        data = [
          ['This is a column with a lot of text that should comfortably exceed '+
          'the width of a normal document margin_box width', 'Some more text',
          'and then some more', 'Just a bit more to be extra sure']
        ]
        table = Prawn::Table.new(data, @pdf)

        expect(table.width).to eq expected_width
      end

      it "should_not exceed the maximum width of the margin_box even with" +
        "manual widths specified" do
        expected_width = @pdf.margin_box.width
        data = [
          ['This is a column with a lot of text that should comfortably exceed '+
          'the width of a normal document margin_box width', 'Some more text',
          'and then some more', 'Just a bit more to be extra sure']
        ]
        table = Prawn::Table.new(data, @pdf) { column(1).width = 100 }

        expect(table.width).to eq expected_width
      end

      it "scales down only the non-preset column widths when the natural width" +
        "exceeds the maximum width of the margin_box" do
        expected_width = @pdf.margin_box.width
        data = [
          ['This is a column with a lot of text that should comfortably exceed '+
          'the width of a normal document margin_box width', 'Some more text',
          'and then some more', 'Just a bit more to be extra sure']
        ]
        table = Prawn::Table.new(data, @pdf) { column(1).width = 100; column(3).width = 50 }

        expect(table.width).to eq expected_width
        expect(table.column_widths[1]).to eq 100
        expect(table.column_widths[3]).to eq 50
      end

      it "should allow width to be reset even after it has been calculated" do
        @table = @pdf.table([[@long_text]])
        @table.width
        @table.width = 100
        expect(@table.width).to eq 100
      end

      it "should shrink columns evenly when two equal columns compete" do
        @table = @pdf.table([["foo", @long_text], [@long_text, "foo"]])
        expect(@table.cells[0, 0].width).to eq @table.cells[0, 1].width
      end

      it "should grow columns evenly when equal deficient columns compete" do
        @table = @pdf.table([["foo", "foobar"], ["foobar", "foo"]], :width => 500)
        expect(@table.cells[0, 0].width).to eq @table.cells[0, 1].width
      end

      it "should respect manual widths" do
        @table = @pdf.table([%w[foo bar baz], %w[baz bar foo]], :width => 500) do
          column(1).width = 60
        end
        expect(@table.column(1).width).to eq 60
        expect(@table.column(0).width).to eq @table.column(2).width
      end

      it "should allow table cells to be resized in block" do
        # if anything goes wrong, a CannotFit error will be raised

        @pdf.table([%w[1 2 3 4 5]]) do |t|
          t.width = 40
          t.cells.size = 8
          t.cells.padding = 0
        end
      end

      it "should be the width of the :width parameter" do
        expected_width = 300
        table = Prawn::Table.new( [%w[snake foo b apple],
                                   %w[kitten d foobar banana]], @pdf,
                                 :width => expected_width)

        expect(table.width).to eq expected_width
      end

      it "should_not exceed the :width option" do
        expected_width = 400
        data = [
          ['This is a column with a lot of text that should comfortably exceed '+
          'the width of a normal document margin_box width', 'Some more text',
          'and then some more', 'Just a bit more to be extra sure']
        ]
        table = Prawn::Table.new(data, @pdf, :width => expected_width)

        expect(table.width).to eq expected_width
      end

      it "should_not exceed the :width option even with manual widths specified" do
        expected_width = 400
        data = [
          ['This is a column with a lot of text that should comfortably exceed '+
          'the width of a normal document margin_box width', 'Some more text',
          'and then some more', 'Just a bit more to be extra sure']
        ]
        table = Prawn::Table.new(data, @pdf, :width => expected_width) do
          column(1).width = 100
        end

        expect(table.width).to eq expected_width
      end

      it "should calculate unspecified column widths even " +
         "with colspan cells declared" do
        pdf = Prawn::Document.new
        hpad, fs = 3, 5
        columns  = 3

        data = [ [ { :content => 'foo', :colspan => 2 }, "foobar" ],
                 [ "foo", "foo", "foo" ] ]
        table = Prawn::Table.new( data, pdf,
          :cell_style => {
            :padding_left => hpad, :padding_right => hpad,
            :size => fs
          })

        col0_width = pdf.width_of("foo",    :size => fs) # cell 1, 0
        col1_width = pdf.width_of("foo",    :size => fs) # cell 1, 1
        col2_width = pdf.width_of("foobar", :size => fs) # cell 0, 1 (at col 2)

        expect(table.width).to eq col0_width + col1_width +
                              col2_width + 2*columns*hpad
      end
    end

    describe "height" do
      it "should set all cells in a row to the same height" do
        @table = @pdf.table([["foo", @long_text]])
        expect(@table.cells[0, 0].height).to eq @table.cells[0, 1].height
      end

      it "should move y-position to the bottom of the table after drawing" do
        old_y = @pdf.y
        table = @pdf.table([["foo"]])
        expect(@pdf.y).to eq old_y - table.height
      end

      it "should_not wrap unnecessarily" do
        # Test for FP errors and glitches
        t = @pdf.table([["Bender Bending Rodriguez"]])
        h = @pdf.height_of("one line")
        expect(t.height - 10).to be < h*1.5
      end

      it "should have a height of n rows" do
        data = [["foo"],["bar"],["baaaz"]]

        vpad = 4
        origin = @pdf.y
        @pdf.table data, :cell_style => { :padding => vpad }

        table_height = origin - @pdf.y
        font_height = @pdf.font.height
        line_gap = @pdf.font.line_gap

        num_rows = data.length
        expect(table_height).to be_within(0.001).of(
          num_rows * font_height + 2*vpad*num_rows )
      end

    end

    describe "position" do
      it "should center tables with :position => :center" do
        expect(@pdf).to receive(:bounding_box).with([(@pdf.bounds.width - 500) / 2.0, anything], kind_of(Hash))

        @pdf.table([["foo"]], :column_widths => 500, :position => :center)
      end

      it "should right-align tables with :position => :right" do
        expect(@pdf).to receive(:bounding_box).with([@pdf.bounds.width - 500, anything], kind_of(Hash))

        @pdf.table([["foo"]], :column_widths => 500, :position => :right)
      end

      it "should accept a Numeric" do
        expect(@pdf).to receive(:bounding_box).with([123, anything], kind_of(Hash))

        @pdf.table([["foo"]], :column_widths => 500, :position => 123)
      end

      it "should raise_error an ArgumentError on unknown :position" do
        expect {
          @pdf.table([["foo"]], :position => :bratwurst)
        }.to raise_error(ArgumentError)
      end
    end

  end

  describe "Multi-page tables" do
    it "should flow to the next page when hitting the bottom of the bounds" do
      expect(Prawn::Document.new { table([["foo"]] * 30) }.page_count).to eq 1
      expect(Prawn::Document.new { table([["foo"]] * 31) }.page_count).to eq 2
      expect(
        Prawn::Document.new { table([["foo"]] * 31); table([["foo"]] * 35) }.page_count
      ).to eq 3
    end

    it "should respect the containing bounds" do
      expect(
        Prawn::Document.new do
          bounding_box([0, cursor], :width => bounds.width, :height => 72) do
            table([["foo"]] * 4)
          end
        end.page_count
      ).to eq 2
    end

    it "should_not start a new page before finishing out a row" do
      expect(
        Prawn::Document.new do
          table([[ (1..80).map{ |i| "Line #{i}" }.join("\n"), "Column 2" ]])
        end.page_count
      ).to eq 1
    end

    it "should only start new page on long cells if it would gain us height" do
      expect(
        Prawn::Document.new do
          text "Hello"
          table([[ (1..80).map{ |i| "Line #{i}" }.join("\n"), "Column 2" ]])
        end.page_count
      ).to eq 2
    end

    it "should_not start a new page to gain height when at the top of " +
       "a bounding box, even if stretchy" do
      expect(
        Prawn::Document.new do
          bounding_box([bounds.left, bounds.top - 20], :width => 400) do
            table([[ (1..80).map{ |i| "Line #{i}" }.join("\n"), "Column 2" ]])
          end
        end.page_count
      ).to eq 1
    end

    it "should still break to the next page if in a stretchy bounding box " +
       "but not at the top" do
      expect(
        Prawn::Document.new do
          bounding_box([bounds.left, bounds.top - 20], :width => 400) do
            text "Hello"
            table([[ (1..80).map{ |i| "Line #{i}" }.join("\n"), "Column 2" ]])
          end
        end.page_count
      ).to eq 2
    end

    it "should only draw first-page header if the first body row fits" do
      pdf = Prawn::Document.new

      pdf.y = 60 # not enough room for a table row
      pdf.table [["Header"], ["Body"]], :header => true

      output = PDF::Inspector::Page.analyze(pdf.render)
      # Ensure we only drew the header once, on the second page
      expect(output.pages[0][:strings]).to be_empty
      expect(output.pages[1][:strings]).to eq ["Header", "Body"]
    end

    it 'should only draw first-page header if the first multi-row fits',
        :issue => 707 do
      pdf = Prawn::Document.new

      pdf.y = 100 # not enough room for the header and multirow cell
      pdf.table [
          [{content: 'Header', colspan: 2}],
          [{content: 'Multirow cell', rowspan: 3}, 'Line 1'],
      ] + (2..3).map { |i| ["Line #{i}"] }, :header => true

      output = PDF::Inspector::Page.analyze(pdf.render)
      # Ensure we only drew the header once, on the second page
      expect(output.pages[0][:strings]).to eq []
      expect(output.pages[1][:strings]).to eq ['Header', 'Multirow cell', 'Line 1',
          'Line 2', 'Line 3']
    end

    context 'when the last row of first page of a table has a rowspan > 1' do
      it 'should move the cells below that rowspan cell to the next page' do
        pdf = Prawn::Document.new

        pdf.y = 100 # not enough room for the rowspan cell
        pdf.table [
            ['R0C0', 'R0C1', 'R0C2'],
            ['R1C0', {content: 'R1C1', rowspan: 2}, 'R1C2'],
            ['R2C0', 'R2C2'],
        ]

        output = PDF::Inspector::Page.analyze(pdf.render)
        # Ensure we output the cells of row 2 on the new page only
        expect(output.pages[0][:strings]).to eq ['R0C0', 'R0C1', 'R0C2']
        expect(output.pages[1][:strings]).to eq ['R1C0', 'R1C1', 'R1C2', 'R2C0', 'R2C2']
      end
    end

    it "should draw background before borders, but only within pages" do
      @pdf = Prawn::Document.new

      # give enough room for only the first row
      @pdf.y = @pdf.bounds.absolute_bottom + 30
      t = @pdf.make_table([["A", "B"],
                           ["C", "D"]],
            :cell_style => {:background_color => 'ff0000'})

      ca = t.cells[0, 0]
      cb = t.cells[0, 1]
      cc = t.cells[1, 0]
      cd = t.cells[1, 1]

      # All backgrounds should draw before any borders on page 1...
      expect(ca).to receive(:draw_background).ordered
      expect(cb).to receive(:draw_background).ordered
      expect(ca).to receive(:draw_borders).ordered
      expect(cb).to receive(:draw_borders).ordered
      # ...and page 2
      expect(@pdf).to receive(:start_new_page).ordered
      expect(cc).to receive(:draw_background).ordered
      expect(cd).to receive(:draw_background).ordered
      expect(cc).to receive(:draw_borders).ordered
      expect(cd).to receive(:draw_borders).ordered

      t.draw
    end

    describe "before_rendering_page callback" do
      before(:each) { @pdf = Prawn::Document.new }

      it "is passed all cells to be rendered on that page" do
        kicked = 0

        @pdf.table([["foo"]] * 100) do |t|
          t.before_rendering_page do |page|
            expect(page.row_count).to eq ((kicked < 3) ? 30 : 10)
            expect(page.column_count).to eq 1
            expect(page.row(0).first.content).to eq "foo"
            expect(page.row(-1).first.content).to eq "foo"
            kicked += 1
          end
        end

        expect(kicked).to eq 4
      end

      it "numbers cells relative to their position on page" do
        @pdf.table([["foo"]] * 100) do |t|
          t.before_rendering_page do |page|
            expect(page[0, 0].content).to eq "foo"
          end
        end
      end

      it "changing cells in the callback affects their rendering" do
        t = @pdf.make_table([["foo"]] * 40) do |table|
          table.before_rendering_page do |page|
            page[0, 0].background_color = "ff0000"
          end
        end

        expect(t.cells[30, 0]).to receive(:draw_background)
          .and_wrap_original do |original_method, *args, &block|
            expect(t.cells[30, 0].background_color).to eq 'ff0000'
            original_method.call(*args, &block)
          end

        expect(t.cells[31, 0]).to receive(:draw_background)
          .and_wrap_original do |original_method, *args, &block|
            expect(t.cells[31, 0].background_color).to eq nil
            original_method.call(*args, &block)
          end

        t.draw
      end

      it "passes headers on page 2+" do
        @pdf.table([["header"]] + [["foo"]] * 100, :header => true) do |t|
          t.before_rendering_page do |page|
            expect(page[0, 0].content).to eq "header"
          end
        end
      end

      it "updates dummy cell header rows" do
        header = [[{:content => "header", :colspan => 2}]]
        data   = [["foo", "bar"]] * 31
        @pdf.table(header + data, :header => true) do |t|
          t.before_rendering_page do |page|
            cell = page[0, 0]
            cell.dummy_cells.each {|dc| expect(dc.row).to eq cell.row }
          end
        end
      end

      it "allows headers to be changed" do
        expect(@pdf).to receive(:draw_text!).with("hdr1", anything).ordered
        expect(@pdf).to receive(:draw_text!).with("foo", anything).exactly(29).times.ordered
        # Verify that the changed cell doesn't mutate subsequent pages
        expect(@pdf).to receive(:draw_text!).with("header", anything).ordered
        expect(@pdf).to receive(:draw_text!).with("foo", anything).exactly(11).times.ordered

        set_first_page_headers = false
        @pdf.table([["header"]] + [["foo"]] * 40, :header => true) do |t|
          t.before_rendering_page do |page|
            # only change first page header
            page[0, 0].content = "hdr1" unless set_first_page_headers
            set_first_page_headers = true
          end
        end
      end
    end
  end

  describe "#style" do
    it "should send #style to its first argument, passing the style hash and" +
        " block" do

      stylable = double
      expect(stylable).to receive(:style).with({:foo => :bar}).once.and_yield

      block = double
      expect(block).to receive(:kick).once

      Prawn::Document.new do
        table([["x"]]) do
          style(stylable, {:foo => :bar}) { block.kick }
        end
      end
    end

    it "should default to {} for the hash argument" do
      stylable = double
      expect(stylable).to receive(:style).with({}).once

      Prawn::Document.new do
        table([["x"]]) { style(stylable) }
      end
    end

    it "ignores unknown values on a cell-by-cell basis" do
      Prawn::Document.new do
        table([["x", [["y"]]]], :cell_style => {:overflow => :shrink_to_fit})
      end
    end
  end

  describe "row_colors" do
    it "should allow array syntax for :row_colors" do
      data = [["foo"], ["bar"], ["baz"]]
      pdf = Prawn::Document.new
      t = pdf.table(data, :row_colors => ['cccccc', 'ffffff'])
      expect(t.cells.map{|x| x.background_color}).to eq %w[cccccc ffffff cccccc]
    end

    it "should ignore headers" do
      data = [["header"], ["foo"], ["bar"], ["baz"]]
      pdf = Prawn::Document.new
      t = pdf.table(data,
                    { :header => true,
                      :row_colors => ['cccccc', 'ffffff']}) do
        row(0).background_color = '333333'
      end

      expect(t.cells.map{|x| x.background_color}).to eq %w[333333 cccccc ffffff cccccc]
    end

    it "stripes rows consistently from page to page, skipping header rows" do
      data = [["header"]] + [["foo"]] * 70
      pdf = Prawn::Document.new
      t = pdf.make_table(data,
                         { :header => true,
                           :row_colors => ['cccccc', 'ffffff']}) do
        cells.padding = 0
        cells.size = 9
        row(0).size = 11
      end

      # page 1: header + 67 cells (odd number -- verifies that the next
      # page disrupts the even/odd coloring, since both the last data cell
      # on this page and the first one on the next are colored cccccc)
      expect(Prawn::Table::Cell).to receive(:draw_cells)
        .and_wrap_original do |original_method, *args, &block|
          cells = args.first
          expect(cells.map { |c, _| c.background_color }).to eq [nil] + (%w[cccccc ffffff] * 33) + %w[cccccc]
          original_method.call(*args, &block)
        end
      # page 2: header and 3 data cells
      expect(Prawn::Table::Cell).to receive(:draw_cells)
        .and_wrap_original do |original_method, *args, &block|
          cells = args.first
          expect(cells.map { |c, _| c.background_color }).to eq [nil] + %w[cccccc ffffff cccccc]
          original_method.call(*args, &block)
        end

      t.draw
    end

    it "should_not override an explicit background_color" do
      data = [["foo"], ["bar"], ["baz"]]
      pdf = Prawn::Document.new
      table = pdf.table(data, :row_colors => ['cccccc', 'ffffff']) { |t|
        t.cells[0, 0].background_color = 'dddddd'
      }
      expect(table.cells.map{|x| x.background_color}).to eq %w[dddddd ffffff cccccc]
    end
  end

  describe "inking" do
    before(:each) do
      @pdf = Prawn::Document.new
    end

    it "should set the x-position of each cell based on widths" do
      @table = @pdf.table([["foo", "bar", "baz"]])

      x = 0
      (0..2).each do |col|
        cell = @table.cells[0, col]
        expect(cell.x).to eq x
        x += cell.width
      end
    end

    it "should set the y-position of each cell based on heights" do
      y = 0
      @table = @pdf.make_table([["foo"], ["bar"], ["baz"]])

      (0..2).each do |row|
        cell = @table.cells[row, 0]
        expect(cell.y).to be_within(0.01).of(y)
        y -= cell.height
      end
    end

    it "should output content cell by cell, row by row" do
      data = [["foo","bar"],["baz","bang"]]
      @pdf = Prawn::Document.new
      @pdf.table(data)
      output = PDF::Inspector::Text.analyze(@pdf.render)
      expect(output.strings).to eq data.flatten
    end

    it "should_not cause an error if rendering the very first row causes a " +
      "page break" do
      Prawn::Document.new do |pdf|
        arr = Array(1..5).collect{|i| ["cell #{i}"] }

        pdf.move_down( pdf.y - (pdf.bounds.absolute_bottom + 3) )

        expect {
          pdf.table(arr)
        }.to_not raise_error
      end
    end

    it "should draw all backgrounds before any borders" do
      # lest backgrounds overlap borders:
      # https://github.com/sandal/prawn/pull/226

      t = @pdf.make_table([["A", "B"]],
            :cell_style => {:background_color => 'ff0000'})
      ca = t.cells[0, 0]
      cb = t.cells[0, 1]

      # XXX Not a perfectly general test, because it would still be acceptable
      # if we drew B then A
      expect(ca).to receive(:draw_background).ordered
      expect(cb).to receive(:draw_background).ordered
      expect(ca).to receive(:draw_borders).ordered
      expect(cb).to receive(:draw_borders).ordered

      t.draw
    end

    it "should allow multiple inkings of the same table" do
      pdf = Prawn::Document.new
      t = Prawn::Table.new([["foo"]], pdf)

      expect(pdf).to receive(:bounding_box).with([anything, 495], kind_of(Hash)).and_yield
      expect(pdf).to receive(:bounding_box).with([anything, 395], kind_of(Hash)).and_yield
      expect(pdf).to receive(:draw_text!).with("foo", anything).twice

      pdf.move_cursor_to(500)
      t.draw

      pdf.move_cursor_to(400)
      t.draw
    end

    describe "in stretchy bounding boxes" do
      it "should draw all cells on a row at the same y-position" do
        pdf = Prawn::Document.new

        text_y = pdf.y.to_i - 5 # text starts 5pt below current y pos (padding)

        pdf.bounding_box([0, pdf.cursor], :width => pdf.bounds.width) do
          expect(pdf).to receive(:draw_text!).exactly(3).times
            .and_wrap_original do |original_method, *args, &block|
              expect(pdf.bounds.absolute_top).to eq text_y
              original_method.call(*args, &block)
            end

          pdf.table([%w[a b c]])
        end
      end
    end
  end

  describe "headers" do
    context "single row header" do
      it "should add headers to output when specified" do
        data = [["a", "b"], ["foo","bar"],["baz","bang"]]
        @pdf = Prawn::Document.new
        @pdf.table(data, :header => true)
        output = PDF::Inspector::Text.analyze(@pdf.render)
        expect(output.strings).to eq data.flatten
      end

      it "should repeat headers across pages" do
        data = [["foo","bar"]] * 30
        headers = ["baz","foobar"]
        @pdf = Prawn::Document.new
        @pdf.table([headers] + data, :header => true)
        output = PDF::Inspector::Text.analyze(@pdf.render)
        expect(output.strings).to eq headers + data.flatten[0..-3] + headers +
          data.flatten[-2..-1]
      end

      it "should repeat defined headers across pages" do
        data = [["foo","bar"]] * 30
        first_page_headers = [["bazbar", "foobaz"]]
        repeating_headers = [["baz","foobar"]]
        @pdf = Prawn::Document.new
        @pdf.table(first_page_headers + data, :header => true, :headers => repeating_headers)
        output = PDF::Inspector::Text.analyze(@pdf.render)
        expect(@pdf.page_count).to eq 2
        expect(output.strings).to eq first_page_headers.flatten + data.flatten[0..-3] + repeating_headers.flatten +
                                       data.flatten[-2..-1]
      end

      it "draws headers at the correct position" do
        data = [["header"]] + [["foo"]] * 40

        expect(Prawn::Table::Cell).to receive(:draw_cells).twice
          .and_wrap_original do |original_method, *args, &block|
            cells = args.first
            cells.each do |cell, pt|
              if cell.content == "header"
                # Assert that header text is drawn at the same location on each page
                if @header_location
                  expect(pt).to eq @header_location
                else
                  @header_location = pt
                end
              end
            end
            original_method.call(*args, &block)
          end
        @pdf = Prawn::Document.new
        @pdf.table(data, :header => true)
      end

      it "draws headers at the correct position with column box" do
        data = [["header"]] + [["foo"]] * 40

        expect(Prawn::Table::Cell).to receive(:draw_cells).twice
          .and_wrap_original do |original_method, *args, &block|
            cells = args.first
            cells.each do |cell, pt|
              if cell.content == "header"
                expect(pt[0]).to eq @pdf.bounds.left
              end
            end
            original_method.call(*args, &block)
          end
        @pdf = Prawn::Document.new
        @pdf.column_box [0, @pdf.cursor], :width => @pdf.bounds.width, :columns => 2 do
            @pdf.table(data, :header => true)
          end
      end

      it "should_not draw header twice when starting new page" do
        @pdf = Prawn::Document.new
        @pdf.y = 0
        @pdf.table([["Header"], ["Body"]], :header => true)
        output = PDF::Inspector::Text.analyze(@pdf.render)
        expect(output.strings).to eq ["Header", "Body"]
      end
    end

    context "multiple row header" do
      it "should add headers to output when specified" do
        data = [["a", "b"], ["c", "d"], ["foo","bar"],["baz","bang"]]
        @pdf = Prawn::Document.new
        @pdf.table(data, :header => 2)
        output = PDF::Inspector::Text.analyze(@pdf.render)
        expect(output.strings).to eq data.flatten
      end

      it "should repeat headers across pages" do
        data = [["foo","bar"]] * 30
        headers = ["baz","foobar"] + ["bas", "foobaz"]
        @pdf = Prawn::Document.new
        @pdf.table([headers] + data, :header => 2)
        output = PDF::Inspector::Text.analyze(@pdf.render)
        expect(output.strings).to eq headers + data.flatten[0..-3] + headers +
          data.flatten[-4..-1]
      end

      it "draws headers at the correct position" do
        data = [["header"]] + [["header2"]] + [["foo"]] * 40

        expect(Prawn::Table::Cell).to receive(:draw_cells).twice
          .and_wrap_original do |original_method, *args, &block|
            cells = args.first
            cells.each do |cell, pt|
              if cell.content == "header"
                # Assert that header text is drawn at the same location on each page
                if @header_location
                  expect(pt).to eq @header_location
                else
                  @header_location = pt
                end
              end

              if cell.content == "header2"
                # Assert that header text is drawn at the same location on each page
                if @header2_location
                  expect(pt).to eq @header2_location
                else
                  @header2_location = pt
                end
              end
            end

            original_method.call(*args, &block)
          end

        @pdf = Prawn::Document.new
        @pdf.table(data, :header => 2)
      end

      it "should_not draw header twice when starting new page" do
        @pdf = Prawn::Document.new
        @pdf.y = 0
        @pdf.table([["Header"], ["Header2"], ["Body"]], :header => 2)
        output = PDF::Inspector::Text.analyze(@pdf.render)
        expect(output.strings).to eq ["Header", "Header2", "Body"]
      end
    end
  end

  describe "nested tables" do
    before(:each) do
      @pdf = Prawn::Document.new
      @subtable = Prawn::Table.new([["foo"]], @pdf)
      @table = @pdf.table([[@subtable, "bar"], ['', { content: @subtable, padding: 10 }]])
    end

    it "can be created from an Array" do
      cell = Prawn::Table::Cell.make(@pdf, [["foo"]])
      expect(cell).to be_a_kind_of(Prawn::Table::Cell::Subtable)
      expect(cell.subtable).to be_a_kind_of(Prawn::Table)
    end

    it "defaults its padding to zero" do
      expect(@table.cells[0, 0].padding).to eq [0, 0, 0, 0]
    end

    it "has a subtable accessor" do
      expect(@table.cells[0, 0].subtable).to eq @subtable
    end

    it "determines its dimensions from the subtable" do
      expect(@table.cells[0, 0].width).to eq @subtable.width
      expect(@table.cells[0, 0].height).to eq @subtable.height
    end

    it "pads the holding cell with padding options" do
      expect(@table.cells[1, 1].padding).to eq [10, 10, 10, 10]
    end
  end

  it "Prints table on one page when using subtable with colspan > 1", :unresolved, issue: 10 do
    pdf = Prawn::Document.new(margin: [ 30, 71, 55, 71])

    lines = "one\ntwo\nthree\nfour"

    sub_table_lines = lines.split("\n").map do |line|
      if line == "one"
        [ { content: "#{line}", colspan: 2, size: 11} ]
      else
        [ { content: "\u2022"}, { content: "#{line}"} ]
      end
    end

    sub_table = pdf.make_table(sub_table_lines,
                               cell_style: { border_color: '00ff00'})

    #outer table
    pdf.table [[
      { content: "Placeholder text", width: 200 },
      { content: sub_table }
    ]], width: 515, cell_style: { border_width: 1, border_color: 'ff0000' }

    pdf.render
    expect(pdf.page_count).to eq 1
  end

  describe "An invalid table" do

    before(:each) do
      @pdf = Prawn::Document.new
      @bad_data = ["Single Nested Array"]
    end

    it "should raise_error error when invalid table data is given" do
      expect {
        @pdf.table(@bad_data)
      }.to raise_error(Prawn::Errors::InvalidTableData)
    end

    it "should raise_error an EmptyTableError with empty table data" do
      expect {
        data = []
        @pdf = Prawn::Document.new
        @pdf.table(data)
      }.to raise_error( Prawn::Errors::EmptyTable )
    end

    it "should raise_error an EmptyTableError with nil table data" do
      expect {
        data = nil
        @pdf = Prawn::Document.new
        @pdf.table(data)
      }.to raise_error( Prawn::Errors::EmptyTable )
    end

  end

end

describe "colspan / rowspan" do
  before(:each) { create_pdf }

  it "doesn't raise an error" do
    expect {
      @pdf.table([[{:content => "foo", :colspan => 2, :rowspan => 2}]])
    }.to_not raise_error
  end

  it "colspan is properly counted" do
    t = @pdf.make_table([[{:content => "foo", :colspan => 2}]])
    expect(t.column_length).to eq 2
  end

  it "rowspan is properly counted" do
    t = @pdf.make_table([[{:content => "foo", :rowspan => 2}]])
    expect(t.row_length).to eq 2
  end

  it "raises if colspan or rowspan are called after layout" do
    expect {
      @pdf.table([["foo"]]) { cells[0, 0].colspan = 2 }
    }.to raise_error(Prawn::Errors::InvalidTableSpan)

    expect {
      @pdf.table([["foo"]]) { cells[0, 0].rowspan = 2 }
    }.to raise_error(Prawn::Errors::InvalidTableSpan)
  end

  it "raises when spans overlap" do
    expect {
      @pdf.table([["foo", {:content => "bar", :rowspan => 2}],
                  [{:content => "baz", :colspan => 2}]])
    }.to raise_error(Prawn::Errors::InvalidTableSpan)
  end

  it "table and cell width account for colspan" do
    t = @pdf.table([["a", {:content => "b", :colspan => 2}]],
                   :column_widths => [100, 100, 100])
    spanned = t.cells[0, 1]
    expect(spanned.colspan).to eq 2
    expect(t.width).to eq 300
    expect(t.cells.min_width).to eq 300
    expect(t.cells.max_width).to eq 300
    expect(spanned.width).to eq 200
  end

  it "table and cell height account for rowspan" do
    t = @pdf.table([["a"], [{:content => "b", :rowspan => 2}]]) do
      row(0..2).height = 100
    end
    spanned = t.cells[1, 0]
    expect(spanned.rowspan).to eq 2
    expect(t.height).to eq 300
    expect(spanned.height).to eq 200
  end

  it "provides the full content_width as drawing space" do
    w = @pdf.make_table([["foo"]]).cells[0, 0].content_width

    t = @pdf.make_table([[{:content => "foo", :colspan => 2}]])
    expect(t.cells[0, 0].spanned_content_width).to eq w
  end

  it "dummy cells are not drawn" do
    # make a fake master cell for the dummy cell to slave to
    t = @pdf.make_table([[{:content => "foo", :colspan => 2}]])

    # drawing just a dummy cell should_not ink
    expect(@pdf).to_not receive(:stroke_line)
    expect(@pdf).to_not receive(:draw_text!)
    Prawn::Table::Cell.draw_cells([t.cells[0, 1]])
  end

  it "dummy cells do not add any height or width" do
    t1 = @pdf.table([["foo"]])

    t2 = @pdf.table([[{:content => "foo", :colspan => 2}]])
    expect(t2.width).to eq t1.width

    t3 = @pdf.table([[{:content => "foo", :rowspan => 2}]])
    expect(t3.height).to eq t1.height
  end

  it "dummy cells ignored by #style" do
    t = @pdf.table([[{:content => "blah", :colspan => 2}]],
                   :cell_style => { :size => 9 })
    expect(t.cells[0, 0].size).to eq 9
  end

  context "inheriting master cell styles from dummy cell" do
    # Relatively full coverage for all these attributes that should be
    # inherited.
    [["border_X_width", 20],
     ["border_X_color", "123456"],
     ["padding_X", 20]].each do |attribute, val|
      attribute_right  = attribute.sub("X", "right")
      attribute_left   = attribute.sub("X", "left")
      attribute_bottom = attribute.sub("X", "bottom")
      attribute_top    = attribute.sub("X", "top")

      specify "#{attribute_right} of right column is inherited" do
        t = @pdf.table([[{:content => "blah", :colspan => 2}]]) do |table|
          table.column(1).send("#{attribute_right}=", val)
        end

        expect(t.cells[0, 0].send(attribute_right)).to eq val
      end

      specify "#{attribute_bottom} of bottom row is inherited" do
        t = @pdf.table([[{:content => "blah", :rowspan => 2}]]) do |table|
          table.row(1).send("#{attribute_bottom}=", val)
        end

        expect(t.cells[0, 0].send(attribute_bottom)).to eq val
      end

      specify "#{attribute_left} of right column is not inherited" do
        t = @pdf.table([[{:content => "blah", :colspan => 2}]]) do |table|
          table.column(1).send("#{attribute_left}=", val)
        end

        expect(t.cells[0, 0].send(attribute_left)).to_not eq val
      end

      specify "#{attribute_right} of interior column is not inherited" do
        t = @pdf.table([[{:content => "blah", :colspan => 3}]]) do |table|
          table.column(1).send("#{attribute_right}=", val)
        end

        expect(t.cells[0, 0].send(attribute_right)).to_not eq val
      end

      specify "#{attribute_bottom} of interior row is not inherited" do
        t = @pdf.table([[{:content => "blah", :rowspan => 3}]]) do |table|
          table.row(1).send("#{attribute_bottom}=", val)
        end

        expect(t.cells[0, 0].send(attribute_bottom)).to_not eq val
      end

      specify "#{attribute_top} of bottom row is not inherited" do
        t = @pdf.table([[{:content => "blah", :rowspan => 2}]]) do |table|
          table.row(1).send("#{attribute_top}=", val)
        end

        expect(t.cells[0, 0].send(attribute_top)).to_not eq val
      end
    end
  end

  it "splits natural width between cols in the group" do
    t = @pdf.table([[{:content => "foo", :colspan => 2}]])
    widths = t.column_widths
    expect(widths[0]).to eq widths[1]
  end

  it "splits natural width between cols when width is increased" do
    t = @pdf.table([[{:content => "foo", :colspan => 2}]],
                   :width => @pdf.bounds.width)
    widths = t.column_widths
    expect(widths[0]).to eq widths[1]
  end

  it "splits min-width between cols in the group" do
    # Since column_widths, when reducing column widths, reduces proportional to
    # the remaining width after each column's min width, we must ensure that the
    # min-width is split proportionally in order to ensure the width is still
    # split evenly when the width is reduced. (See "splits natural width between
    # cols when width is reduced".)
    t = @pdf.table([[{:content => "foo", :colspan => 2}]],
                   :width => 20)
    expect(t.column(0).min_width).to eq t.column(1).min_width
  end

  it "splits natural width between cols when width is reduced" do
    t = @pdf.table([[{:content => "foo", :colspan => 2}]],
                   :width => 20)
    widths = t.column_widths
    expect(widths[0]).to eq widths[1]
  end

  it "honors a large, explicitly set table width" do
    t = @pdf.table([[{:content => "AAAAAAAAAA", :colspan => 3}],
                    ["A", "B", "C"]],
                   :width => 400)

    expect(t.column_widths.inject(0) { |sum, w| sum + w }).to be_within(0.01).of(400)
  end

  it "honors a small, explicitly set table width" do
    t = @pdf.table([[{:content => "Lorem ipsum dolor sit amet " * 20,
                      :colspan => 3}],
                    ["A", "B", "C"]],
                   :width => 200)
    expect(t.column_widths.inject(0) { |sum, w| sum + w }).to be_within(0.01).of(200)
  end

  it "splits natural_content_height between rows in the group" do
    t = @pdf.table([[{:content => "foo", :rowspan => 2}]])
    heights = t.row_heights
    expect(heights[0]).to eq heights[1]
  end

  it "skips column numbers that have been col-spanned" do
    t = @pdf.table([["a", "b", {:content => "c", :colspan => 3}, "d"]])
    expect(t.cells[0, 0].content).to eq "a"
    expect(t.cells[0, 1].content).to eq "b"
    expect(t.cells[0, 2].content).to eq "c"
    expect(t.cells[0, 3]).to be_a_kind_of(Prawn::Table::Cell::SpanDummy)
    expect(t.cells[0, 4]).to be_a_kind_of(Prawn::Table::Cell::SpanDummy)
    expect(t.cells[0, 5].content).to eq "d"
  end

  it "skips row/col positions that have been row-spanned" do
    t = @pdf.table([["a", {:content => "b", :colspan => 2, :rowspan => 2}, "c"],
                    ["d",                                                  "e"],
                    ["f",               "g",              "h",             "i"]])
    expect(t.cells[0, 0].content).to eq "a"
    expect(t.cells[0, 1].content).to eq "b"
    expect(t.cells[0, 2]).to be_a_kind_of(Prawn::Table::Cell::SpanDummy)
    expect(t.cells[0, 3].content).to eq "c"

    expect(t.cells[1, 0].content).to eq "d"
    expect(t.cells[1, 1]).to be_a_kind_of(Prawn::Table::Cell::SpanDummy)
    expect(t.cells[1, 2]).to be_a_kind_of(Prawn::Table::Cell::SpanDummy)
    expect(t.cells[1, 3].content).to eq "e"

    expect(t.cells[2, 0].content).to eq "f"
    expect(t.cells[2, 1].content).to eq "g"
    expect(t.cells[2, 2].content).to eq "h"
    expect(t.cells[2, 3].content).to eq "i"
  end

  it 'illustrates issue #20', issue: 20 do
    pdf = Prawn::Document.new
    description = "one\ntwo\nthree"
    bullets = description.split("\n")
    bullets.each_with_index do |bullet, ndx|
      rows = [[]]

      if ndx < 1
        rows << [ { content: "blah blah blah", colspan: 2, font_style: :bold, size: 12, padding_bottom: 1 }]
      else
        rows << [ { content: bullet, width: 440, padding_top: 0, align: :justify } ]
      end
      pdf.table(rows, header: true, cell_style: { border_width: 0, inline_format: true })
    end
    pdf.render
  end

  it 'illustrates issue #20 (2) and #22', issue: 22 do
    pdf = Prawn::Document.new
    pdf.table [['one', 'two']], position: :center
    pdf.table [['three', 'four']], position: :center
    pdf.render
    expect(pdf.page_count).to eq 1
  end

  it 'illustrates issue #56 cell style should not be overwritten by table style', issue: 56 do
    t = @pdf.table([['col1', 'col2'],
                    ['val1', { content: 'val2', align: :left }]],
                   cell_style: { align: :center })
    expect(t.cells[0, 0].align).to eq :center
    expect(t.cells[0, 1].align).to eq :center
    expect(t.cells[1, 0].align).to eq :center
    expect(t.cells[1, 1].align).to eq :left
  end
end
