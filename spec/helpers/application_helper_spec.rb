# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#full_title' do
    it 'returns the base title when no page title is given' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))

      expect(helper.full_title('')).to eq('NSL')
    end

    it 'includes environment and page title outside production' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('test'))

      expect(helper.full_title('Forum')).to eq('NSL TEST | Forum')
    end
  end

  describe '#active_theme' do
    it 'returns the current layout when the current user has a profile' do
      user = instance_double(User, profile: true, current_layout: 'forest')
      helper.define_singleton_method(:cuser) { user }

      expect(helper.active_theme).to eq('forest')
    end

    it 'falls back to the default theme' do
      helper.define_singleton_method(:cuser) { nil }

      expect(helper.active_theme).to eq('default')
    end
  end

  describe '#namelink' do
    it 'returns nil for nil models' do
      expect(helper.namelink(nil)).to be_nil
    end

    it 'links to a data file movie when present' do
      movie = instance_double('Movie', to_s: 'Movie title')
      data_file = DataFile.new
      allow(data_file).to receive(:movie).and_return(movie)
      allow(helper).to receive(:link_to).and_return('linked')

      helper.namelink(data_file)

      expect(helper).to have_received(:link_to).with('Movie title', movie,
                                                     class: 'rspec::mocks::instanceverifyingdouble')
    end

    it 'links to a commentable target for comments' do
      commentable = Article.new
      allow(commentable).to receive(:to_s).and_return('Comment target')
      comment = Comment.new
      allow(comment).to receive(:commentable).and_return(commentable)
      allow(helper).to receive(:link_to).and_return('linked')

      helper.namelink(comment)

      expect(helper).to have_received(:link_to).with('Comment target', commentable, class: 'article')
    end

    it 'links to a post topic for posts' do
      topic = Topic.new
      allow(topic).to receive(:to_s).and_return('Topic title')
      post = Post.new
      allow(post).to receive(:topic).and_return(topic)
      allow(helper).to receive(:link_to).and_return('linked')

      helper.namelink(post)

      expect(helper).to have_received(:link_to).with('Topic title', topic, class: 'topic')
    end

    it 'adds turbo frame data for users' do
      user = build_stubbed(:user)

      result = helper.namelink(user)

      expect(result).to include('turbo-frame="_top"')
      expect(result).to include(user.to_s)
    end

    it 'truncates long labels when a length is given' do
      article = Article.new
      allow(article).to receive(:to_s).and_return('Very long article title')
      allow(helper).to receive(:link_to).and_return('linked')

      helper.namelink(article, 8)

      expect(helper).to have_received(:link_to).with('Very lon...', article, class: 'article')
    end
  end

  describe '#directory_links' do
    it 'adds separators between parent directories only' do
      root = instance_double('Directory')
      child = instance_double('Directory')
      allow(Directory).to receive(:directory_traverse).with(child).and_return([child, root])
      allow(helper).to receive(:namelink).with(root).and_return('ROOT')
      allow(helper).to receive(:namelink).with(child).and_return('CHILD')

      result = helper.directory_links(child)

      expect(result).to eq("ROOT\n \u00BB \nCHILD\n")
      expect(result).to be_html_safe
    end
  end

  describe '#shorten' do
    it 'truncates strings longer than the limit' do
      expect(helper.shorten('abcdefghij', 5)).to eq('abcde...')
    end

    it 'returns the original string when within the limit' do
      expect(helper.shorten('abcd', 5)).to eq('abcd')
    end
  end

  describe '#printtime' do
    it 'returns nil without a time' do
      expect(helper.printtime(nil, '%d %b %y')).to be_nil
    end

    it 'formats the time inside a span' do
      user = instance_double(User, time_zone: 'UTC')
      helper.define_singleton_method(:cuser) { user }
      time = Time.zone.parse('2024-05-01 10:30:00 UTC')

      result = helper.printtime(time, '%d %b %y')

      expect(result).to include('<span')
      expect(result).to include('01 May 24')
    end
  end

  describe '#flag' do
    it 'renders a country-specific flag when a country is present' do
      expect(helper.flag('Fi')).to include('flag-fi')
    end

    it 'renders the placeholder flag when no country is present' do
      expect(helper.flag(nil)).to include('flag-placeholder')
    end
  end

  describe '#add_comments' do
    it 'returns empty safe string for nil object' do
      result = helper.add_comments(nil)

      expect(result).to eq('')
      expect(result).to be_html_safe
    end

    it 'returns empty safe string for non-commentable object' do
      result = helper.add_comments(Object.new)

      expect(result).to eq('')
      expect(result).to be_html_safe
    end

    it 'builds comment state and renders the comments partial for commentable objects' do
      comments = instance_double('CommentsRelation')
      ordered_comments = instance_double('OrderedComments')
      object = instance_double('Commentable', comments: comments)
      new_comment = instance_double(Comment)

      allow(Comment).to receive(:new).with(commentable: object).and_return(new_comment)
      allow(comments).to receive(:ordered).and_return(ordered_comments)
      allow(ordered_comments).to receive(:with_userteam).and_return(%w[c1 c2])
      helper.define_singleton_method(:return_here) { nil }
      allow(helper).to receive(:render)
        .with(partial: 'comments/index', locals: { comment: new_comment, comments: %w[c1 c2] })
        .and_return('rendered comments')

      result = helper.add_comments(object)

      expect(result).to eq('rendered comments')
    end
  end

  describe '#cascade' do
    it 'returns an empty string for nil models' do
      expect(helper.cascade(nil, [:name])).to eq('')
    end

    it 'renders escaped values from array keys' do
      model = Class.new do
        def name
          'Alice <Admin>'
        end

        def [](key)
          key == :name ? name : nil
        end
      end.new

      result = helper.cascade(model, [['display_name', :name]])

      expect(result).to include('<dt>Display name</dt>')
      expect(result).to include('Alice &lt;Admin&gt;')
    end

    it 'renders linked values for symbol entries' do
      linked_user = build_stubbed(:user)
      model = Class.new do
        define_method(:owner) { linked_user }
        define_method(:[]) { |key| key == :owner ? linked_user : nil }
      end.new
      allow(helper).to receive(:namelink).with(linked_user).and_return('OWNER_LINK')

      result = helper.cascade(model, [:owner])

      expect(result).to include('OWNER_LINK')
    end

    it 'formats time values using long ordinal format' do
      timestamp = Time.zone.parse('2024-04-10 12:00:00 UTC')
      model = Class.new do
        define_method(:created_at) { timestamp }
        define_method(:[]) { |key| key == :created_at ? timestamp : nil }
      end.new

      result = helper.cascade(model, [:created_at])

      expect(result).to include(timestamp.to_formatted_s(:long_ordinal))
    end
  end

  describe 'matches list helpers' do
    let(:home_team) { build_stubbed(:team, name: 'Home Team') }
    let(:away_team) { build_stubbed(:team, name: 'Away Team') }
    let(:home_contester) { instance_double(Contester, team: home_team) }
    let(:away_contester) { instance_double(Contester, team: away_team) }
    let(:match) do
      instance_double(
        Match,
        contester1: home_contester,
        contester2: away_contester,
        score1: 3,
        score2: 1
      )
    end

    it 'returns away team as opponent by default' do
      expect(helper.match_list_opponent_team(match, nil)).to eq(away_team)
    end

    it 'returns home team as opponent when friendly is away' do
      expect(helper.match_list_opponent_team(match, away_team)).to eq(home_team)
    end

    it 'returns home-based score color and text' do
      expect(helper.match_list_score_color(match)).to eq('green')
      expect(helper.match_list_score_text(match)).to eq('3 - 1')
    end

    it 'returns red when home loses and yellow on draw' do
      losing_match = instance_double(Match, score1: 1, score2: 3)
      draw_match = instance_double(Match, score1: 2, score2: 2)

      expect(helper.match_list_score_color(losing_match)).to eq('red')
      expect(helper.match_list_score_color(draw_match)).to eq('yellow')
    end
  end

  describe '#timezone_offset' do
    it 'returns the current user timezone when available' do
      user = instance_double(User, time_zone: 'Europe/Helsinki')
      helper.define_singleton_method(:cuser) { user }

      expect(helper.timezone_offset).to eq('Europe/Helsinki')
    end

    it 'falls back to the application timezone' do
      helper.define_singleton_method(:cuser) { nil }
      allow(Time.zone).to receive(:name).and_return('UTC')

      expect(helper.timezone_offset).to eq('UTC')
    end
  end

  describe '#upcoming_matches' do
    around do |example|
      original = ENV['GOOGLE_CALENDAR']
      example.run
    ensure
      ENV['GOOGLE_CALENDAR'] = original
    end

    it 'returns calendar items when the integration is disabled' do
      ENV['GOOGLE_CALENDAR'] = 'disabled'
      allow(helper).to receive(:calendar).and_return(instance_double(GoogleCalendar, upcoming: %w[a b]))

      expect(helper.upcoming_matches).to eq(%w[a b])
    end

    it 'returns an empty array when the integration is enabled' do
      ENV['GOOGLE_CALENDAR'] = 'enabled'

      expect(helper.upcoming_matches).to eq([])
    end
  end

  describe '#gathers_url' do
    it 'returns the production gathers host in production' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))

      expect(helper.gathers_url).to eq('https://gathers.ensl.org')
    end

    it 'returns the staging gathers host outside production' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))

      expect(helper.gathers_url).to eq('https://gathers.staging.ensl.org')
    end
  end

  describe '#upcoming_nsltv' do
    around do |example|
      original = ENV['GOOGLE_CALENDAR']
      example.run
    ensure
      ENV['GOOGLE_CALENDAR'] = original
    end

    it 'returns calendar items when the integration is disabled' do
      ENV['GOOGLE_CALENDAR'] = 'disabled'
      allow(helper).to receive(:calendar).and_return(instance_double(GoogleCalendar, upcoming: ['stream']))

      expect(helper.upcoming_nsltv).to eq(['stream'])
    end

    it 'returns an empty array when the integration is enabled' do
      ENV['GOOGLE_CALENDAR'] = 'enabled'

      expect(helper.upcoming_nsltv).to eq([])
    end
  end

  describe '#sortable' do
    before do
      allow(helper).to receive(:link_to).and_return('sorted')
    end

    it 'marks the current ascending column and flips to descending' do
      helper.define_singleton_method(:sort_column) { 'name' }
      helper.define_singleton_method(:sort_direction) { 'asc' }

      helper.sortable('name')

      expect(helper).to have_received(:link_to).with('Name', { sort: 'name', direction: 'desc' },
                                                     { class: 'current asc' })
    end

    it 'leaves other columns unmarked and sorts ascending' do
      helper.define_singleton_method(:sort_column) { 'created_at' }
      helper.define_singleton_method(:sort_direction) { 'desc' }

      helper.sortable('name', 'Display Name')

      expect(helper).to have_received(:link_to).with('Display Name', { sort: 'name', direction: 'asc' }, { class: nil })
    end
  end
end
