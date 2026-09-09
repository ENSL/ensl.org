# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnalysisHelper, type: :helper do
  describe '#tech_requirement_tree_nodes' do
    it 'aggregates a research across fragmented ordered prefixes before applying the sample threshold' do
      paths = [
        { path: %w[research_armorl1 research_jetpacks], rounds: 4, wins: 2, losses: 2 },
        { path: %w[research_weaponsl1 research_jetpacks], rounds: 4, wins: 3, losses: 1 },
        { path: %w[research_catalysts research_jetpacks], rounds: 4, wins: 1, losses: 3 }
      ]

      overall = helper.tech_requirement_tree_nodes(paths, 12, min_rounds: 10)
                      .dig('research_jetpacks', :stats, :overall)

      expect(overall).to include(rounds: 12)
      expect(overall[:win_ratio]).to be_within(0.01).of(50.0)
    end

    it 'applies the threshold independently to each observed next-research aggregate' do
      paths = [
        { path: %w[research_armorl1 research_weaponsl1], rounds: 6, wins: 3, losses: 3 },
        { path: %w[research_phasetech research_armorl1 research_weaponsl1], rounds: 6, wins: 4, losses: 2 },
        { path: %w[research_armorl1 research_jetpacks], rounds: 9, wins: 6, losses: 3 }
      ]

      next_choices = helper.tech_requirement_tree_nodes(paths, 21, min_rounds: 10)
                           .dig('research_armorl1', :stats, :next_choices)

      expect(next_choices).to contain_exactly(include(key: 'research_weaponsl1', rounds: 12))
    end

    it 'contains every tracked research except intentionally excluded Distress Beacon' do
      tracked_research = RoundsHelper::ROUND_TIMELINE_RESEARCH_NAMES.keys - MarineTechPathQuery::EXCLUDED_RESEARCH
      tree_research = AnalysisHelper::TECH_REQUIREMENT_TREE.values.flatten.grep(/\Aresearch_/).uniq

      expect(tree_research).to match_array(tracked_research)
    end
  end
end
