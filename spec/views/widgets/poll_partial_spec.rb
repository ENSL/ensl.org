# frozen_string_literal: true

require 'rails_helper'

# Regression safety net for app/views/widgets/_poll.html.erb
# Rendered from the news sidebar (see app/views/layouts/application.html.erb) only
# when action_name == "news_index", showing the most recently created poll
# (Poll.recent.first).
RSpec.describe 'widgets/_poll', type: :view do
  def build_poll(question: 'Best map?', options: %w[Dust2 Inferno])
    poll = Poll.new(question: question)
    options.each { |option| poll.options.build(option: option) }
    poll.save!
    poll
  end

  before do
    view.define_singleton_method(:cuser) { nil }
    allow(view).to receive(:action_name).and_return('news_index')
  end

  it 'renders the sidebar poll widget heading and delegates to polls/show' do
    build_poll(question: 'Sidebar poll question?')

    render

    expect(rendered).to include(I18n.t('widget.poll'))
    expect(rendered).to include('Sidebar poll question?')
  end

  it 'shows only the most recently created poll' do
    build_poll(question: 'Older poll question?').update!(created_at: 2.days.ago)
    build_poll(question: 'Newest poll question?')

    render

    expect(rendered).to include('Newest poll question?')
    expect(rendered).not_to include('Older poll question?')
  end

  it 'renders nothing when there is no poll at all' do
    render

    expect(rendered).to include(I18n.t('widget.poll'))
    expect(rendered).not_to include('question')
  end

  it 'renders nothing at all outside of the news_index action' do
    allow(view).to receive(:action_name).and_return('show')
    build_poll(question: 'Should not appear')

    render

    expect(rendered.strip).to be_empty
  end
end
