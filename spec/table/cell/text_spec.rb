# encoding: utf-8

require File.join(File.expand_path(File.dirname(__FILE__)), "..", "..", "spec_helper")
require 'set'

describe Prawn::Table::Cell::Text do
  let(:pdf) { Prawn::Document.new }
  let(:data) { "Text data" }
  let(:options) { { :font_size => 12 } }
  let(:cell) { Prawn::Table::Cell::Text.new(pdf, [0, 0], :content => data, :text_options => options) }

  describe "#font_size=" do
    it "sets the font size in the text options" do
      new_font_size = 10
      cell.font_size = new_font_size
      expect(cell.instance_variable_get("@text_options")[:size]).to eq(new_font_size)
    end
  end
end
