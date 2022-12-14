# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для модели Игры
# В идеале - все методы должны быть покрыты тестами,
# в этом классе содержится ключевая логика игры и значит работы сайта.
RSpec.describe Game, type: :model do
  # пользователь для создания игр
  let(:user) { FactoryBot.create(:user) }

  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user) }

  # Группа тестов на работу фабрики создания новых игр
  context 'Game Factory' do
    it 'Game.create_game! new correct game' do
      # генерим 60 вопросов с 4х запасом по полю level,
      # чтобы проверить работу RANDOM при создании игры
      generate_questions(60)

      game = nil
      # создaли игру, обернули в блок, на который накладываем проверки
      expect {
        game = Game.create_game_for_user!(user)
      }.to change(Game, :count).by(1).and(# проверка: Game.count изменился на 1 (создали в базе 1 игру)
        change(GameQuestion, :count).by(15).and(# GameQuestion.count +15
          change(Question, :count).by(0) # Game.count не должен измениться
        )
      )
      # проверяем статус и поля
      expect(game.user).to eq(user)
      expect(game.status).to eq(:in_progress)
      # проверяем корректность массива игровых вопросов
      expect(game.game_questions.size).to eq(15)
      expect(game.game_questions.map(&:level)).to eq (0..14).to_a
    end
  end


  # тесты на основную игровую логику
  context 'game mechanics' do

    # правильный ответ должен продолжать игру
    it 'answer correct continues game' do
      # текущий уровень игры и статус
      level = game_w_questions.current_level
      q = game_w_questions.current_game_question
      expect(game_w_questions.status).to eq(:in_progress)

      game_w_questions.answer_current_question!(q.correct_answer_key)

      # перешли на след. уровень
      expect(game_w_questions.current_level).to eq(level + 1)
      # ранее текущий вопрос стал предыдущим
      expect(game_w_questions.previous_game_question).to eq(q)
      expect(game_w_questions.current_game_question).not_to eq(q)
      # игра продолжается
      expect(game_w_questions.status).to eq(:in_progress)
      expect(game_w_questions.finished?).to be_falsey
    end
  end

  describe '#take_money' do
    it 'take_money! finishes the game' do
      question = game_w_questions.current_game_question
      game_w_questions.answer_current_question!(question.correct_answer_key)

      game_w_questions.take_money!

      prize = game_w_questions.prize

      expect(prize).to be >0

      expect(game_w_questions.status).to be :money
      expect(game_w_questions.finished?).to be_truthy
      expect(user.balance).to eq prize
    end
  end

  describe '#status' do
    before(:each) do
      game_w_questions.finished_at = Time.now
      expect(game_w_questions.finished?).to be_truthy
    end

    it "returns :won" do
      game_w_questions.current_level = Question::QUESTION_LEVELS.max + 1
      expect(game_w_questions.status).to eq(:won)
    end

    it "returns :fail" do
      game_w_questions.is_failed = true
      expect(game_w_questions.status).to eq(:fail)
    end

    it 'returns :timeout' do
      game_w_questions.created_at = 1.hour.ago
      game_w_questions.is_failed = true
      expect(game_w_questions.status).to eq(:timeout)
    end

    it 'returns :money' do
      expect(game_w_questions.status).to eq(:money)
    end
  end

  describe '#current_game_question' do
    it 'returns a question of current level' do
      expect(game_w_questions.current_game_question).to eq game_w_questions.game_questions[0]
    end
  end

  describe '#previous_level' do
    it 'returns previous level number' do
      game_w_questions.current_level = 2
      expect(game_w_questions.previous_level).to eq 1
    end
  end

  describe '#answer_current_question!' do
    it 'returns false when the game is finished' do
      game_w_questions.finished_at = Time.now
      expect(game_w_questions.answer_current_question!(
        game_w_questions.game_questions[0].correct_answer_key)).to be_falsey
    end

    it 'returns false when time is over' do
      game_w_questions.created_at = Time.now - Game::TIME_LIMIT - 1.second
      game_w_questions.time_out!
      expect(game_w_questions.answer_current_question!(
        game_w_questions.game_questions[0].correct_answer_key)).to be_falsey
    end

    context 'when answer is correct' do
      it 'increments current_level' do
        game_w_questions.answer_current_question!(
          game_w_questions.game_questions[0].correct_answer_key)
        expect(game_w_questions.current_level).to eq 1
      end

      context 'when the question is last' do
        before(:each) do
          game_w_questions.current_level = Question::QUESTION_LEVELS.max
          game_w_questions.answer_current_question!(
            game_w_questions.game_questions[0].correct_answer_key)
        end

        it 'ends the game' do
          expect(game_w_questions.finished_at).to be_present
        end

        it 'credits the maximum winnings to the player\'s account' do
          expect(user.balance).to eq Game::PRIZES[Question::QUESTION_LEVELS.max]
        end
      end
    end

    context 'when answer is incorrect' do
      it 'ends the game' do
        game_w_questions.answer_current_question!('c')
        expect(game_w_questions.finished_at).to be_present
      end

      it 'fires all the user\'s balance, if the user has not won a fireproof amount' do
        game_w_questions.answer_current_question!('c')
        expect(user.balance).to be 0
      end

      it 'fires the user\'s balance to a fireproof amount' do
        fireproof_level = Game::FIREPROOF_LEVELS[0]
        level_after_fireproof = fireproof_level + 1

        game_w_questions.current_level = level_after_fireproof
        game_w_questions.answer_current_question!('c')
        expect(user.balance).to eq Game::PRIZES[fireproof_level]
      end
    end
  end
end