# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для игрового контроллера
# Самые важные здесь тесты:
#   1. на авторизацию (чтобы к чужим юзерам не утекли не их данные)
#   2. на четкое выполнение самых важных сценариев (требований) приложения
#   3. на передачу граничных/неправильных данных в попытке сломать контроллер
#
RSpec.describe GamesController, type: :controller do
  # обычный пользователь
  let(:user) { FactoryBot.create(:user) }
  # админ
  let(:admin) { FactoryBot.create(:user, is_admin: true) }
  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user) }

  # группа тестов для незалогиненного юзера (Анонимус)
  context 'User is not signed in' do
    it 'kicks from #show' do
      # вызываем экшен
      get :show, id: game_w_questions.id
      # проверяем ответ
      expect(response.status).not_to eq(200) # статус не 200 ОК
      expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
      expect(flash[:alert]).to be # во flash должен быть прописана ошибка
    end

    it 'kicks from #create' do
      # вызываем экшен
      post :create
      # проверяем ответ
      expect(response.status).not_to eq(200) # статус не 200 ОК
      expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
      expect(flash[:alert]).to be # во flash должен быть прописана ошибка
    end

    it 'kicks from #answer' do
      # вызываем экшен
      put :answer, id: game_w_questions.id
      # проверяем ответ
      expect(response.status).not_to eq(200) # статус не 200 ОК
      expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
      expect(flash[:alert]).to be # во flash должен быть прописана ошибка
    end

    it 'kicks from #take_money' do
      # вызываем экшен
      put :take_money, id: game_w_questions.id
      # проверяем ответ
      expect(response.status).not_to eq(200) # статус не 200 ОК
      expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
      expect(flash[:alert]).to be # во flash должен быть прописана ошибка
    end

    it 'kicks from #help' do
      # вызываем экшен
      put :help, id: game_w_questions.id
      # проверяем ответ
      expect(response.status).not_to eq(200) # статус не 200 ОК
      expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
      expect(flash[:alert]).to be # во flash должен быть прописана ошибка
    end
  end

  # группа тестов на экшены контроллера, доступных залогиненным юзерам
  context 'User is signed in' do
    # перед каждым тестом в группе
    before(:each) { sign_in user } # логиним юзера user с помощью спец. Devise метода sign_in

    # юзер может создать новую игру
    it 'allows to create a new game - #create' do
      # сперва накидаем вопросов, из чего собирать новую игру
      generate_questions(15)

      post :create
      game = assigns(:game) # вытаскиваем из контроллера поле @game

      # проверяем состояние этой игры
      expect(game.finished?).to be_falsey
      expect(game.user).to eq(user)
      # и редирект на страницу этой игры
      expect(response).to redirect_to(game_path(game))
      expect(flash[:notice]).to be
    end

    # юзер видит свою игру
    it 'shows own game - #show' do
      get :show, id: game_w_questions.id
      game = assigns(:game) # вытаскиваем из контроллера поле @game
      expect(game.finished?).to be_falsey
      expect(game.user).to eq(user)

      expect(response.status).to eq(200) # должен быть ответ HTTP 200
      expect(response).to render_template('show') # и отрендерить шаблон show
    end

    # юзер не видит чужую игру
    it "does not show someone else's game - #show" do
      alien_game = FactoryBot.create(:game_with_questions)
      get :show, id: alien_game.id
      expect(response.status).not_to eq(200) # статус не 200 ОК
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be_present # во flash должен быть прописана ошибка
    end

    # юзер отвечает на игру корректно - игра продолжается
    it 'continiues the game with a correct answer' do
      # передаем параметр params[:letter]
      put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key
      game = assigns(:game)

      expect(game.finished?).to be_falsey
      expect(game.current_level).to be > 0
      expect(response).to redirect_to(game_path(game))
      expect(flash.empty?).to be_truthy # удачный ответ не заполняет flash
    end

    # юзер отвечает на игру некорректно - игра заканчивается
    it 'ends the game with a wrong answer' do
      # передаем параметр params[:letter]
      put :answer, id: game_w_questions.id, letter: 'c'
      game = assigns(:game)

      expect(game.finished?).to be_truthy
      expect(game.current_level).to be 0
      expect(response).to redirect_to(user_path(user))
      expect(flash[:alert]).to be # неудачный ответ заполняет flash
    end

    describe '#help action' do
      # тест на отработку "помощи зала"
      it 'allows to use audience help' do
        # сперва проверяем что в подсказках текущего вопроса пусто
        expect(game_w_questions.current_game_question.help_hash[:audience_help]).not_to be
        expect(game_w_questions.audience_help_used).to be_falsey

        # отправляем запрос в контроллер с нужным типом
        put :help, id: game_w_questions.id, help_type: :audience_help
        game = assigns(:game)

        # проверяем, что игра не закончилась, что флажок установился, и подсказка записалась
        expect(game.finished?).to be_falsey
        expect(game.audience_help_used).to be_truthy
        expect(game.current_game_question.help_hash[:audience_help]).to be
        expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
        expect(response).to redirect_to(game_path(game))
      end

      it 'allows to use fifty-fifty help' do
        expect(game_w_questions.current_game_question.help_hash[:fifty_fifty]).not_to be
        expect(game_w_questions.fifty_fifty_used).to be_falsey

        # отправляем запрос в контроллер с нужным типом
        put :help, id: game_w_questions.id, help_type: :fifty_fifty
        game = assigns(:game)

        # проверяем, что игра не закончилась, что флажок установился, и подсказка записалась
        expect(game.finished?).to be_falsey
        expect(game.fifty_fifty_used).to be_truthy
        expect(game.current_game_question.help_hash[:fifty_fifty]).to be
        expect(game.current_game_question.help_hash[:fifty_fifty].size).to eq 2
        expect(response).to redirect_to(game_path(game))
      end
    end

    # юзер берет деньги
    it 'allows to take money' do
      # вручную поднимем уровень вопроса до выигрыша 200
      game_w_questions.update_attribute(:current_level, 2)

      put :take_money, id: game_w_questions.id
      game = assigns(:game)
      expect(game.finished?).to be_truthy
      expect(game.prize).to eq(200)

      # пользователь изменился в базе, надо в коде перезагрузить!
      user.reload
      expect(user.balance).to eq(200)

      expect(response).to redirect_to(user_path(user))
      expect(flash[:warning]).to be
    end

    it 'does not allow to create a second game' do
      # убедились что есть игра в работе
      expect(game_w_questions.finished?).to be_falsey

      # отправляем запрос на создание, убеждаемся что новых Game не создалось
      expect { post :create }.to change(Game, :count).by(0)

      game = assigns(:game) # вытаскиваем из контроллера поле @game
      expect(game).to be_nil

      # и редирект на страницу старой игры
      expect(response).to redirect_to(game_path(game_w_questions))
      expect(flash[:alert]).to be
    end
  end
end
