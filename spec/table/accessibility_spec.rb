# encoding: utf-8

require 'spec_helper'

describe 'Table Accessibility' do
  let(:pdf) { Prawn::Document.new(marked: true, language: 'en-US', margin: 0) }

  describe 'tagged table rendering' do
    it 'wraps the table in a Table structure element' do
      data = [['Name', 'Age'], ['Alice', '30']]
      pdf.table(data, header: true)
      output = pdf.render

      expect(output).to include('/Table')
      expect(output).to include('/StructTreeRoot')
    end

    it 'creates TR structure elements for each row' do
      data = [['A', 'B'], ['C', 'D']]
      pdf.table(data)
      output = pdf.render

      expect(output).to include('/TR')
    end

    it 'creates TH elements for header cells' do
      data = [['Name', 'Age'], ['Alice', '30']]
      pdf.table(data, header: true)
      output = pdf.render

      expect(output).to include('/TH')
    end

    it 'creates TD elements for data cells' do
      data = [['Name', 'Age'], ['Alice', '30']]
      pdf.table(data, header: true)
      output = pdf.render

      expect(output).to include('/TD')
    end

    it 'sets Scope on TH elements' do
      data = [['Name', 'Age'], ['Alice', '30']]
      pdf.table(data, header: true)
      output = pdf.render

      expect(output).to include('/Scope /Column')
    end

    it 'marks all cells as TD when no header is set' do
      data = [['A', 'B'], ['C', 'D']]
      pdf.table(data)
      output = pdf.render

      expect(output).to include('/TD')
      expect(output).not_to include('/TH')
    end

    it 'supports multiple header rows' do
      data = [['Group', ''], ['Name', 'Age'], ['Alice', '30']]
      pdf.table(data, header: 2)
      output = pdf.render

      expect(output).to include('/TH')
    end
  end

  describe 'untagged table rendering' do
    it 'does not emit structure tags when not marked' do
      plain_pdf = Prawn::Document.new(margin: 0)
      data = [['Name', 'Age'], ['Alice', '30']]
      plain_pdf.table(data, header: true)
      output = plain_pdf.render

      expect(output).not_to include('/StructTreeRoot')
      expect(output).not_to include('/TH')
      expect(output).not_to include('/TD')
    end
  end

  describe 'Cell#header?' do
    it 'returns true for cells in header rows' do
      data = [['Name', 'Age'], ['Alice', '30']]
      table = pdf.make_table(data, header: true)

      header_cell = table.cells[0, 0]
      data_cell = table.cells[1, 0]

      expect(header_cell).to be_header
      expect(data_cell).not_to be_header
    end

    it 'returns false when no header is set' do
      data = [['A', 'B'], ['C', 'D']]
      table = pdf.make_table(data)

      expect(table.cells[0, 0]).not_to be_header
    end
  end
end
