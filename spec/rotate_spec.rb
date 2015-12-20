# encoding: utf-8

require File.join(File.expand_path(File.dirname(__FILE__)), "spec_helper")

describe "Table::Cell::Box#render with :rotate option)" do
  before(:each) do
    create_pdf
    @lorem = "Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Aenean commodo ligula eget dolor. Aenean massa. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Donec quam felis, ultricies nec, pellentesque eu, pretium quis, sem. Nulla consequat massa quis enim. Donec pede justo, fringilla vel, aliquet nec, vulputate eget, arcu. In enim justo, rhoncus ut, imperdiet a, venenatis vitae, justo. Nullam dictum felis eu pede mollis pretium."
  end

  it "should rotate table cell content" do
    table = nil
    @pdf.bounding_box([20,@pdf.bounds.height-100], :width => @pdf.bounds.width-40, :height => @pdf.bounds.height-20) do
      # lorem = "| "*300
      data = [
        [
          {content: "01 #{@lorem}", rotate: -5}, #coerced back to zero
          {content: "02 #{@lorem}", rotate: 15},
          {content: "03 #{@lorem}", rotate: 30},
          {content: "04 #{@lorem}", rotate: 45},
          {content: "05 #{@lorem}", rotate: 60},
          {content: "06 #{@lorem}", rotate: 75},
          {content: "07 #{@lorem}", rotate: 95}, #coerced back to 90
        ],
      ]
      column_widths = {}
      table = @pdf.table data, :header => false, :row_colors => ["EEEEEE", "FFFFFF"], :width => @pdf.bounds.width, :cell_style => {:padding => 3, :size => 8, :align => :left} do |t|
        t.column(1).align = :center
        t.column(2).align = :right
        t.column(4).align = :right
      end
    end

    matrices = PDF::Inspector::Graphics::Matrix.analyze(@pdf.render)
    # matrices.matrices.should == [[1.0, 0.0, 0.0, 1.0, 181.2142, -3.71449], [0.96593, 0.25882, -0.25882, 0.96593, 0.0, 0.0], [1.0, 0.0, 0.0, 1.0, 368.16269, -1.25787], [0.86603, 0.5, -0.5, 0.86603, 0.0, 0.0], [1.0, 0.0, 0.0, 1.0, 563.87552, 11.42807], [0.70711, 0.70711, -0.70711, 0.70711, 0.0, 0.0], [1.0, 0.0, 0.0, 1.0, 769.34416, 40.20083], [0.5, 0.86603, -0.86603, 0.5, 0.0, 0.0], [1.0, 0.0, 0.0, 1.0, 982.85696, 91.85987], [0.25882, 0.96593, -0.96593, 0.25882, 0.0, 0.0], [1.0, 0.0, 0.0, 1.0, 1202.65771, -115.5087], [0.0, 1.0, -1.0, 0.0, 0.0, 0.0]]
    matrices.matrices[0].should == [1.0, 0.0, 0.0, 1.0, 181.2142, -3.71449]
    matrices.matrices[2].should == [1.0, 0.0, 0.0, 1.0, 368.16269, -1.25787]
    matrices.matrices[4].should == [1.0, 0.0, 0.0, 1.0, 563.87552, 11.42807]
    [15,30,45].each_with_index do |rotate, i|
       cos = reduce_precision(Math.cos(rotate * Math::PI / 180))
       sin = reduce_precision(Math.sin(rotate * Math::PI / 180))
       matrices.matrices[i*2+1].should == [cos, sin, -sin, cos, 0, 0]
     end

    text = PDF::Inspector::Text.analyze(@pdf.render)
    text.strings.length.should == 134

    # @pdf.render_file "rotate.pdf"
  end
end

def reduce_precision(float)
  ("%.5f" % float).to_f
end
