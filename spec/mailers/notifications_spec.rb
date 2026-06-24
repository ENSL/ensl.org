# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notifications, type: :mailer do
  let(:user) { instance_double(User, email: 'user@example.com') }
  let(:mailer) do
    described_class.new.tap do |instance|
      allow(instance).to receive(:mail).and_return(:message)
    end
  end

  describe '#password' do
    subject(:deliver) { mailer.password(user, 'secret') }

    it 'addresses the mail and exposes the password' do
      expect(deliver).to eq(:message)
      expect(mailer).to have_received(:mail).with(hash_including(to: 'user@example.com',
                                                                 subject: 'ENSL account password'))
      expect(mailer.instance_variable_get(:@pass)).to eq('secret')
      expect(mailer.instance_variable_get(:@user)).to eq(user)
    end
  end

  describe '#pm' do
    let(:pm) { instance_double('PrivateMessage') }

    subject(:deliver) { mailer.pm(user, pm) }

    it 'builds the private message notification' do
      expect(deliver).to eq(:message)
      expect(mailer).to have_received(:mail).with(hash_including(to: 'user@example.com',
                                                                 subject: 'New ENSL private message'))
      expect(mailer.instance_variable_get(:@pm)).to eq(pm)
    end
  end

  describe '#gather' do
    let(:gather) { instance_double('Gather') }

    subject(:deliver) { mailer.gather(user, gather) }

    it 'builds the gather notification' do
      expect(deliver).to eq(:message)
      expect(mailer).to have_received(:mail).with(hash_including(to: 'user@example.com',
                                                                 subject: 'ENSL gather running'))
      expect(mailer.instance_variable_get(:@gather)).to eq(gather)
    end
  end

  describe '#comments' do
    let(:commentable) { instance_double('Commentable') }

    subject(:deliver) { mailer.comments(user, commentable) }

    it 'builds the comments notification' do
      expect(deliver).to eq(:message)
      expect(mailer).to have_received(:mail).with(hash_including(to: 'user@example.com', subject: 'New ENSL comments'))
      expect(mailer.instance_variable_get(:@object)).to eq(commentable)
    end
  end

  describe '#challenge' do
    let(:challenge) { instance_double('Challenge') }

    subject(:deliver) { mailer.challenge(user, challenge) }

    it 'builds the challenge notification' do
      expect(deliver).to eq(:message)
      expect(mailer).to have_received(:mail).with(hash_including(to: 'user@example.com', subject: 'New ENSL challenge'))
      expect(mailer.instance_variable_get(:@challenge)).to eq(challenge)
    end
  end

  describe '#match' do
    let(:match_record) { instance_double('Match') }

    subject(:deliver) { mailer.match(user, match_record) }

    it 'builds the match notification' do
      expect(deliver).to eq(:message)
      expect(mailer).to have_received(:mail).with(hash_including(to: 'user@example.com', subject: 'New ENSL match'))
      expect(mailer.instance_variable_get(:@match)).to eq(match_record)
    end
  end

  describe '#news' do
    let(:news) { instance_double('News', title: 'Weekly update') }

    subject(:deliver) { mailer.news(user, news) }

    it 'includes the news title in the subject' do
      expect(deliver).to eq(:message)
      expect(mailer).to have_received(:mail).with(hash_including(to: 'user@example.com',
                                                                 subject: 'News on ENSL: Weekly update'))
      expect(mailer.instance_variable_get(:@news)).to eq(news)
    end
  end

  describe '#article' do
    let(:article) { instance_double(Article, title: 'Feature article') }

    subject(:deliver) { mailer.article(user, article) }

    it 'includes the article title in the subject' do
      expect(deliver).to eq(:message)
      expect(mailer).to have_received(:mail).with(hash_including(to: 'user@example.com',
                                                                 subject: 'News on ENSL: Feature article'))
      expect(mailer.instance_variable_get(:@article)).to eq(article)
    end
  end
end
