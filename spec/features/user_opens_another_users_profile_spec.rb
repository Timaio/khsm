require "rails_helper"

RSpec.feature "USER opens another user's profile", type: :feature do
  def helpers
    ActionController::Base.helpers
  end

  let(:user) { FactoryBot.create(:user, name: "Alice") }
  let(:another_user) { FactoryBot.create(:user, name: "Bob") }
  let!(:games) do
    [
      FactoryBot.create(:game_with_questions,
        user: another_user,
        current_level: 5,
        is_failed: true,
        prize: 1000,
        created_at: 45.minutes.ago,
        finished_at: 40.minutes.ago),

      FactoryBot.create(:game_with_questions,
        user: another_user,
        current_level: 11,
        is_failed: false,
        prize: 125000,
        created_at: 35.minutes.ago,
        finished_at: 30.minutes.ago)
    ]
  end

  before { login_as user }

  scenario "successfully" do
    visit "/"

    click_link "#{another_user.name}"

    expect(page).to have_current_path "/users/#{another_user.id}"
    expect(page).not_to have_content "Сменить имя и пароль"
    expect(page).to have_content helpers.number_to_currency(games[0].prize)
    expect(page).to have_content helpers.number_to_currency(games[1].prize)
    expect(page).to have_content I18n.l(games[0].created_at, format: :short)
    expect(page).to have_content I18n.l(games[1].created_at, format: :short)
  end
end
