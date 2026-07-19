# frozen_string_literal: true

require 'rails_helper'

# Regression safety net for app/views/polls/_show.html.erb
RSpec.describe 'polls/_show', type: :view do
  def build_poll(question: 'Best map?', options: %w[Dust2 Inferno])
    poll = Poll.new(question: question)
    options.each { |option| poll.options.build(option: option) }
    poll.save!
    poll
  end

  before do
    view.define_singleton_method(:cuser) { nil }
  end

  it 'renders the poll question and each option' do
    poll = build_poll(question: 'Best map?', options: %w[Dust2 Inferno])

    render partial: 'polls/show', locals: { poll: poll }

    expect(rendered).to include('Best map?')
    expect(rendered).to include('Dust2')
    expect(rendered).to include('Inferno')
  end

  it 'renders each option vote count' do
    poll = build_poll
    option = poll.options.first
    create(:vote, votable: option, votable_type: 'Option', user: create(:user))
    poll.reload

    render partial: 'polls/show', locals: { poll: poll }

    expect(rendered).to include(option.reload.votes.to_s)
  end

  context 'when a signed-in user has not voted yet' do
    it 'renders vote links for the options instead of plain text' do
      poll = build_poll
      user = create(:user)
      signed_in_user = user
      view.define_singleton_method(:cuser) { signed_in_user }

      render partial: 'polls/show', locals: { poll: poll }

      expect(rendered).to include('vote-link')
    end
  end

  context 'when using the @poll instance variable fallback' do
    it 'still renders the question' do
      poll = build_poll(question: 'Ivar fallback question?')
      assign(:poll, poll)

      render

      expect(rendered).to include('Ivar fallback question?')
    end
  end
end
