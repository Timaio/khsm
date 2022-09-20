require 'rails_helper'

RSpec.describe 'users/show', type: :view do
  let(:user) { FactoryBot.create(:user, name: 'Вадик', balance: 5000) }
  let(:game) { FactoryBot.create(:game_with_questions, user: user) }

  before(:each) do
    assign(:user, user)
    assign(:games, [game])
    render
  end

  it 'renders player\'s name' do
    expect(rendered).to match 'Вадик'
  end

  it 'renders games list' do
    stub_template 'users/_game.html.erb' =>
      '<%= game.id %>
      <%= game_label(game) %>
      <%= l game.created_at, format: :short %>
      <%= content_tag :span, "50/50", class: "label label-primary" %>'

    expect(rendered).to match game.id.to_s
    expect(rendered).to match 'в процессе'
    expect(rendered).to match l(game.created_at, format: :short)
    expect(rendered).to match '0 ₽'
    expect(rendered).to match '<span class="label label-primary ">50/50</span>'
  end

  it 'does not render change password button' do
    expect(rendered).not_to match 'Сменить имя и пароль'
  end

  context 'When signed in user sees his own profile' do
    before(:each) do
      sign_in user
      render
    end

    it 'renders change password button' do
      expect(rendered).to match 'Сменить имя и пароль'
    end
  end
end
