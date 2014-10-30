# encoding: utf-8

# run rspec -t issue:XYZ  to run tests for a specific github issue
# or  rspec -t unresolved to run tests for all unresolved issues

require File.join(File.expand_path(File.dirname(__FILE__)), "spec_helper")

require_relative "../lib/prawn/table"
require 'set'

# test suite for the functionality that enables us to split rows in a table
# if the last row on a single page does not fully fit onto that page
#
# beware that lots of possible rendering issues of lines are not covered
# by this test suite
# what it does try to cover is the rendering of the text
describe "Prawn::Table" do
  describe "split cells in the final row of a page (1)" do
    before(:each) do
      @pdf = Prawn::Document.new
      @data = []
      # just enough lines, so that the next one will break if it uses more than one line
      29.times do |i| 
        @data.push ["row #{i}/1", "row#{i}/2", "row#{i}/3", "row#{i}/4", "row#{i}/5", "row#{i}/6"]
      end

      # data with header
      @data_with_header = []
      3.times do |i|
        @data_with_header.push(["head #{i}/1", "head#{i}/2", "head#{i}/3", "head#{i}/4", "head#{i}/5", "head#{i}/6"])
      end
      26.times do |i|
        @data_with_header.push ["row #{i}/1", "row#{i}/2", "row#{i}/3", "row#{i}/4", "row#{i}/5", "row#{i}/6"]
      end
    end

    it 'should split the last row if the option is set' do
      @data.push ["this line is too long"]*6
      @pdf.table(@data, column_widths: 80, split_cells_across_pages: true)
      output = PDF::Inspector::Page.analyze(@pdf.render)
      output.pages[1][:strings].should eq ["too long"]*6
    end

    it 'should not split the last row if the option is unset' do
      @data.push ["this line is too long"]*6
      @pdf.table(@data, column_widths: 80)
      output = PDF::Inspector::Page.analyze(@pdf.render)
      output.pages[1][:strings].should eq  ["this line is", "too long", "this line is", "too long", "this line is", "too long", "this line is", "too long", "this line is", "too long", "this line is", "too long"]
    end

    it 'preserves header when splitting cells' do
      @data_with_header
      @data_with_header.push ["this line is too long"]*6

      # header: true
      @pdf.table(@data_with_header, column_widths: 80, split_cells_across_pages: true, header: true)
      output = PDF::Inspector::Page.analyze(@pdf.render)
      output.pages[1][:strings].should eq ["head 0/1", "head0/2", "head0/3", "head0/4", "head0/5", "head0/6", "too long", "too long", "too long", "too long", "too long", "too long"]
    end

    it 'preserves multiple header when splitting cells' do
      @data_with_header
      @data_with_header.push ["this line is too long"]*6
     
      # header: 3
      @pdf.table(@data_with_header, column_widths: 80, split_cells_across_pages: true, header: 3)
      output = PDF::Inspector::Page.analyze(@pdf.render)
      output.pages[1][:strings].should eq ["head 0/1", "head0/2", "head0/3", "head0/4", "head0/5", "head0/6", "head 1/1", "head1/2", "head1/3", "head1/4", "head1/5", "head1/6", "head 2/1", "head2/2", "head2/3", "head2/4", "head2/5", "head2/6", "too long", "too long", "too long", "too long", "too long", "too long"]
    end

    it 'preserves colspan when splitting cells' do
      @data.push [{content: "this line is too long to fit in two columns and only one row", colspan: 2}]*3
      @pdf.table(@data, column_widths: 80, split_cells_across_pages: true)
      output = PDF::Inspector::Page.analyze(@pdf.render)
      output.pages[1][:strings].should eq ["two columns and only one", "row", "two columns and only one", "row", "two columns and only one", "row"]
    end

    it 'preserves colspan and headers when splitting cells' do
      @data_with_header.push [{content: "this line is too long to fit in two columns and only one row", colspan: 2}]*3
      @pdf.table(@data_with_header, column_widths: 80, split_cells_across_pages: true, header: true)
      output = PDF::Inspector::Page.analyze(@pdf.render)
      output.pages[1][:strings].should eq  ["head 0/1", "head0/2", "head0/3", "head0/4", "head0/5", "head0/6", "two columns and only one", "row", "two columns and only one", "row", "two columns and only one", "row"]
    end

    it 'preserves colspanned rows and colspanned headers when splitting cells' do
      @data_with_header[0] = [{content: "head0/1", colspan: 2}, {content: "head0/2", colspan: 2}, {content: "head0/3", colspan: 2}]
      @data_with_header.push [{content: "this line is too long to fit in two columns and only one row", colspan: 2}]*3
      @pdf.table(@data_with_header, column_widths: 80, split_cells_across_pages: true, header: true)
      output = PDF::Inspector::Page.analyze(@pdf.render)
      output.pages[1][:strings].should eq  ["head0/1", "head0/2", "head0/3", "two columns and only one", "row", "two columns and only one", "row", "two columns and only one", "row"]
    end

    it 'preserves rowspanned header rows when splitting cells' do
      @data_with_header[0] = [{content: "head0/1", rowspan: 2, colspan: 2}, {content: "head0/2", colspan: 2}, {content: "head0/3", colspan: 2}]
      @data_with_header[1] = [{content: "head0/2", colspan: 2}, {content: "head0/3", colspan: 2}] 
      @data_with_header.push [{content: "this line is too long to fit in two columns and only one row", colspan: 2}]*3
      @pdf.table(@data_with_header, column_widths: 80, split_cells_across_pages: true, header: 2)
      output = PDF::Inspector::Page.analyze(@pdf.render)
      # puts @data_with_header
      output.pages[1][:strings].should eq ["head0/1", "head0/2", "head0/3", "head0/2", "head0/3", "two columns and only one", "row", "two columns and only one", "row", "two columns and only one", "row"]
    end

    it 'can split rowspanned rows' do
      # todo
    end
  end

  describe 'some complex scenarios trying to cover multiple points of failure' do
    it 'shows complex scenario 1', focus: true do
      @pdf = Prawn::Document.new
      @data = []
      # just enough lines, so that the next one will break if it uses more than one line
      @data.push [{content: 'header1', rowspan: 2, colspan: 2}, {content: 'header1', colspan: 2}, {content: 'header1', colspan: 2}]
      @data.push [{content: 'header2', colspan: 2}, {content: 'header2', colspan: 2}]
      25.times do |i| 
        @data.push ["row #{i}/1", "row#{i}/2", "row#{i}/3", "row#{i}/4", "row#{i}/5", "row#{i}/6"]
      end
      @data.push [{content: "this is a very long line that needs a lot of space", rowspan: 4}, "row26/2", "row26/3", "row26/4", "row26/5", "row26/6"]
      @data.push [ {content: 'foobar'}, {content: "this line is too long to fit in two columns and only one row", colspan: 2}, {content: 'final cell colspan 2', colspan: 2}]
      @data.push [  "row -2 /2", "row -2 /3", "row -2 /4", "row -2 /5", "row -2 /6"]
      @data.push [ "row -1 /2", "row -1 /3", "row -1 /4", "row -1 /5", "row -1 /6"]
      @data.push [ "row last/1", "row last/2", "row last/3", "row last/4", "row last/5", "row last/6"]
      @table = @pdf.table(@data, column_widths: 80, split_cells_across_pages: true, header: 3)
      output = PDF::Inspector::Page.analyze(@pdf.render)
      output.pages[1][:strings].should eq  ["header1", "header1", "header1", "header2", "header2", "row 0/1", "row0/2", "row0/3", "row0/4", "row0/5", "row0/6", "of space", "row", "row -2 /2", "row -2 /3", "row -2 /4", "row -2 /5", "row -2 /6", "row -1 /2", "row -1 /3", "row -1 /4", "row -1 /5", "row -1 /6", "row last/1", "row last/2", "row last/3", "row last/4", "row last/5", "row last/6"]
    end

    it 'shows complex scenario 2', focus: true do
      @pdf = Prawn::Document.new
      @data = []
      # just enough lines, so that the next one will break if it uses more than one line
      @data.push [{content: 'header1', rowspan: 2, colspan: 2}, {content: 'header1', colspan: 2}, {content: 'header1', colspan: 2}]
      @data.push [{content: 'header2', colspan: 2}, {content: 'header2', colspan: 2}]
      25.times do |i| 
        @data.push ["row #{i}/1", "row#{i}/2", "row#{i}/3", "row#{i}/4", "row#{i}/5", "row#{i}/6"]
      end
      @data.push ["row 25/1", {content: "row25/2"}, "row25/3", "row25/4", "row25/5", "row25/6"]
      @data.push [{content: "this is a very long line that needs a lot of space", rowspan: 4}, "row26/2", "row26/3", "row26/4", "row26/5", "row26/6"]
      @data.push [ {content: 'foobar'}, {content: "this line is too long to fit in two columns and only one row", colspan: 2}, {content: 'final cell colspan 2', colspan: 2}]
      @data.push [  "row -2 /2", "row -2 /3", "row -2 /4", "row -2 /5", "row -2 /6"]
      @data.push [ "row -1 /2", "row -1 /3", "row -1 /4", "row -1 /5", "row -1 /6"]
      @data.push [ "row last/1", "row last/2", "row last/3", "row last/4", "row last/5", "row last/6"]
      @table = @pdf.table(@data, column_widths: 80, split_cells_across_pages: true, header: 3)
      output = PDF::Inspector::Page.analyze(@pdf.render)
      output.pages[1][:strings].should eq ["header1", "header1", "header1", "header2", "header2", "row 0/1", "row0/2", "row0/3", "row0/4", "row0/5", "row0/6", "needs a lot", "of space", "two columns and only one", "row", "row -2 /2", "row -2 /3", "row -2 /4", "row -2 /5", "row -2 /6", "row -1 /2", "row -1 /3", "row -1 /4", "row -1 /5", "row -1 /6", "row last/1", "row last/2", "row last/3", "row last/4", "row last/5", "row last/6"]
    end

    it 'shows complex scenario 3', focus: true do
      @pdf = Prawn::Document.new
      rows = []
      50.times do |i|
        cols = []
        cols << "foo #{i} / 0"
        cols << {content: "very long cell", rowspan: 50} if i == 0
        cols << "foo #{i} / 2"
        rows << cols
      end
      @pdf.table(rows,
                split_cells_across_pages: true,
                cell_style: {inline_format: true})
      output = PDF::Inspector::Page.analyze(@pdf.render)
      output.pages[1][:strings].should eq  ["foo 30 / 0", "foo 30 / 2", "foo 31 / 0", "foo 31 / 2", "foo 32 / 0", "foo 32 / 2", "foo 33 / 0", "foo 33 / 2", "foo 34 / 0", "foo 34 / 2", "foo 35 / 0", "foo 35 / 2", "foo 36 / 0", "foo 36 / 2", "foo 37 / 0", "foo 37 / 2", "foo 38 / 0", "foo 38 / 2", "foo 39 / 0", "foo 39 / 2", "foo 40 / 0", "foo 40 / 2", "foo 41 / 0", "foo 41 / 2", "foo 42 / 0", "foo 42 / 2", "foo 43 / 0", "foo 43 / 2", "foo 44 / 0", "foo 44 / 2", "foo 45 / 0", "foo 45 / 2", "foo 46 / 0", "foo 46 / 2", "foo 47 / 0", "foo 47 / 2", "foo 48 / 0", "foo 48 / 2", "foo 49 / 0", "foo 49 / 2"]
    end
  end
end
