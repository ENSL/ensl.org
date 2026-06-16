require 'rails_helper'

RSpec.describe BracketsHelper, type: :helper do
  describe '#bracket_cell_class' do
    it 'returns disabled team classes for disabled team cells in view mode' do
      bracketer = instance_double('Bracketer', disabled: true)

      expect(helper.bracket_cell_class(double('Bracket'), bracketer, 1, 0, 3, false)).to eq('team disabled')
    end

    it 'returns the result class for enabled team cells in view mode' do
      bracketer = instance_double('Bracketer', disabled: false, result_class: 'winner')

      expect(helper.bracket_cell_class(double('Bracket'), bracketer, 1, 0, 3, false)).to eq('team winner')
    end

    it 'returns only team in edit mode' do
      bracketer = instance_double('Bracketer', disabled: true)

      expect(helper.bracket_cell_class(double('Bracket'), bracketer, 1, 0, 3, true)).to eq('team')
    end

    it 'returns connector for connector cells' do
      allow(helper).to receive(:render_connector?).and_return(true)

      expect(helper.bracket_cell_class(double('Bracket'), nil, 0, 0, 3, false)).to eq('connector')
    end

    it 'returns empty for cells with no content or connector' do
      allow(helper).to receive(:render_connector?).and_return(false)

      expect(helper.bracket_cell_class(double('Bracket'), nil, 0, 0, 3, false)).to eq('empty')
    end
  end

  describe '#bracket_cell_team?' do
    it 'identifies team rows' do
      expect(helper.bracket_cell_team?(1, 0)).to be(true)
    end

    it 'rejects non-team rows' do
      expect(helper.bracket_cell_team?(0, 0)).to be(false)
    end
  end

  describe '#bracket_show_content?' do
    it 'shows content for enabled bracketers' do
      expect(helper.bracket_show_content?(instance_double('Bracketer', disabled: false))).to be(true)
    end

    it 'hides content for disabled or missing bracketers' do
      expect(helper.bracket_show_content?(instance_double('Bracketer', disabled: true))).to be(false)
      expect(helper.bracket_show_content?(nil)).to be_nil
    end
  end

  describe '#render_connector?' do
    let(:relation) { instance_double('BracketerRelation') }
    let(:bracket) { instance_double('Bracket', bracketers: relation) }

    it 'returns the connector position directly in edit mode' do
      expect(helper.send(:render_connector?, bracket, 2, 0, 3, true)).to be(true)
      expect(helper.send(:render_connector?, bracket, 0, 0, 3, true)).to be(false)
    end

    it 'returns false in view mode when the cell is not a connector position' do
      expect(helper.send(:render_connector?, bracket, 0, 0, 3, false)).to be(false)
    end

    it 'returns true when both adjacent cells exist and are enabled' do
      above_scope = instance_double('BracketerScope', first: instance_double('Bracketer', disabled: false))
      below_scope = instance_double('BracketerScope', first: instance_double('Bracketer', disabled: false))

      allow(relation).to receive(:pos).with(1, 0).and_return(above_scope)
      allow(relation).to receive(:pos).with(3, 0).and_return(below_scope)

      expect(helper.send(:render_connector?, bracket, 2, 0, 3, false)).to be(true)
    end

    it 'returns false when one adjacent cell is disabled' do
      above_scope = instance_double('BracketerScope', first: instance_double('Bracketer', disabled: true))
      below_scope = instance_double('BracketerScope', first: instance_double('Bracketer', disabled: false))

      allow(relation).to receive(:pos).with(1, 0).and_return(above_scope)
      allow(relation).to receive(:pos).with(3, 0).and_return(below_scope)

      expect(helper.send(:render_connector?, bracket, 2, 0, 3, false)).to be(false)
    end
  end
end
