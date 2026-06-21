# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Articles::VersionHistory, type: :service do
  let(:article) do
    create(:article, title: 'Initial title', text: '<p>Initial body</p>', text_coding: Article::CODING_HTML)
  end
  let(:service) { described_class.new(article) }

  def create_versioned_states!
    article.update!(title: 'First edit', text: '<p>First edit body</p>')
    article.update!(title: 'Second edit', text: '<p>Second edit body</p>')
    article.versions.reorder(:id)
  end

  describe '#versions' do
    it 'returns versions ordered newest first' do
      create_versioned_states!

      ids = service.versions.pluck(:id)

      expect(ids).to eq(ids.sort.reverse)
    end
  end

  describe '#snapshot_for' do
    it 'reifies the historical state for a version record' do
      versions = create_versioned_states!

      snapshot = service.snapshot_for(versions.first)

      expect(snapshot.title).to eq('Initial title')
      expect(snapshot.text).to eq('<p>Initial body</p>')
    end

    it 'returns the current article when reify raises' do
      broken_version = instance_double(PaperTrail::Version)
      allow(broken_version).to receive(:reify).and_raise(StandardError)

      snapshot = service.snapshot_for(broken_version)

      expect(snapshot).to eq(article)
    end
  end

  describe '#snapshots_for' do
    it 'returns snapshots keyed by version id' do
      versions = create_versioned_states!

      snapshots = service.snapshots_for(versions)

      expect(snapshots.keys).to match_array(versions.map(&:id))
      expect(snapshots[versions.first.id].title).to eq('Initial title')
      expect(snapshots[versions.last.id].title).to eq('First edit')
    end
  end

  describe '#version_numbers_for' do
    it 'numbers a newest-first list as descending display versions' do
      create_versioned_states!
      ordered = service.versions.to_a

      numbers = service.version_numbers_for(ordered)

      expect(numbers[ordered.first.id]).to eq(ordered.length)
      expect(numbers[ordered.last.id]).to eq(1)
    end
  end

  describe '#version_number_for' do
    it 'returns the historical version number for a specific record' do
      versions = create_versioned_states!

      expect(service.version_number_for(versions.first)).to eq(1)
      expect(service.version_number_for(versions.last)).to eq(2)
    end
  end

  describe '#revert_to!' do
    it 'restores article attributes from the selected snapshot' do
      versions = create_versioned_states!

      result = service.revert_to!(versions.first)

      expect(result).to eq(true)
      expect(article.reload.title).to eq('Initial title')
      expect(article.text).to eq('<p>Initial body</p>')
    end

    it 'returns false when saving restored attributes fails' do
      versions = create_versioned_states!
      allow(article).to receive(:save).and_return(false)

      expect(service.revert_to!(versions.first)).to eq(false)
    end

    it 'returns false when snapshot restoration raises an error' do
      versions = create_versioned_states!
      allow(article).to receive(:assign_attributes).and_raise(StandardError)

      expect(service.revert_to!(versions.first)).to eq(false)
    end
  end
end
